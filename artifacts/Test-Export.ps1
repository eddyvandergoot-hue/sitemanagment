# Week Report phase C (WEEKREPORT_PLAN.md par. 6.1-6.6; DECISIONS.md H24, H25, E2, E10): static and Power Fx interpreter checks of the
# Export button on scrWeekReport (cmpWrFooter.ExportEnabled / OnExport). Style of Test-WeekReport.ps1: Check-WeeklySource.ps1 is dot-sourced
# (syntax + templates), the real formula texts are read from the YAML and evaluated in the Power Fx interpreter with synthetic fixtures.
# The PDF Content built by the real formula is compared with templates/sample-body.html (same synthetic TEST data and texts).
# Proves source structure and local calculation only: NO Studio import, binding of the flow (optional parameter syntax), User().FullName,
# delegation of the Translations reads (Monitor), flow behaviour or functional result. ASCII-only, PowerShell 5.1.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$xEngine = New-Object Microsoft.PowerFx.RecalcEngine
$xOpt = New-Object Microsoft.PowerFx.ParserOptions
$xOpt.Culture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
$xOpt.AllowsSideEffects = $true
function Assert-True($cond, $label) { if (!$cond) { throw "FAIL $label" }; Write-Output "PASS $label" }
function Invoke-Fx([string]$fx) {
    $fx = $fx.Replace('[$-en-US]', '')  # format tag (Studio) stripped for the interpreter, as in Test-WeekReport
    try { $v = $xEngine.Eval($fx, $null, $xOpt) } catch { throw "FAIL evaluation error in: $($fx.Substring(0,[Math]::Min(300,$fx.Length))) :: $($_.Exception.InnerException.Message) $($_.Exception.Message)" }
    if ($v -is [Microsoft.PowerFx.Types.ErrorValue]) { throw "FAIL evaluation returned an error: $($v.ToExpression()) :: $($fx.Substring(0,[Math]::Min(300,$fx.Length)))" }
    return $v
}
function Assert-Eval([string]$fx, $expected, [string]$label) {
    $v = Invoke-Fx $fx
    if ($v.Value -ne $expected) { throw "FAIL $label : got '$($v.ToExpression())', expected '$expected'" }
    Write-Output "PASS $label"
}
function Set-FxValue([string]$name, $v) { try { $xEngine.DeleteFormula($name) } catch { }; $xEngine.UpdateVariable($name, $v) }
function Set-FxVar([string]$name, [string]$literal) { Set-FxValue $name (Invoke-Fx $literal) }
function Get-Balanced([string]$text, [int]$open) {
    $depth = 0; $inS = $false
    for ($j = $open; $j -lt $text.Length; $j++) {
        $ch = $text[$j]
        if ($ch -eq '"') { $inS = -not $inS; continue }
        if ($inS) { continue }
        if ($ch -eq '(') { $depth++ } elseif ($ch -eq ')') { $depth--; if ($depth -eq 0) { return $text.Substring($open + 1, $j - $open - 1) } }
    }
    throw "FAIL unbalanced expression at $open"
}
function Split-FxArgs([string]$inner) {
    $out = @(); $depth = 0; $inS = $false; $last = 0
    for ($j = 0; $j -lt $inner.Length; $j++) {
        $ch = $inner[$j]
        if ($ch -eq '"') { $inS = -not $inS; continue }
        if ($inS) { continue }
        if ($ch -in @('(', '{', '[')) { $depth++ } elseif ($ch -in @(')', '}', ']')) { $depth-- }
        elseif ($ch -eq ',' -and $depth -eq 0) { $out += $inner.Substring($last, $j - $last); $last = $j + 1 }
    }
    $out += $inner.Substring($last)
    return , $out
}
function Remove-FxStrings([string]$fx) { return [regex]::Replace($fx, '"(?:[^"]|"")*"', '""') }
function Get-Norm([string]$s) { return ($s -replace '\s+', '') }
function Get-CallArg([string]$text, [string]$prefix, [int]$argIndex, [switch]$Last) {
    # argument $argIndex of the call that starts with $prefix (e.g. 'Set(varX,'); -Last = last occurrence
    $i = if ($Last) { $text.LastIndexOf($prefix) } else { $text.IndexOf($prefix) }
    if ($i -lt 0) { throw "FAIL call not found: $prefix" }
    $open = $text.IndexOf('(', $i)
    return (Split-FxArgs (Get-Balanced $text $open))[$argIndex].Trim()
}
function ConvertTo-FxString([string]$s) { return '"' + $s.Replace('"', '""') + '"' }

$projectRoot = Split-Path $PSScriptRoot
$srcDir = Join-Path $projectRoot 'Src'
$tplDir = Join-Path $projectRoot 'templates'
$scr = 'scrWeekReport'
$doc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir "$scr.pa.yaml")))
$appDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'App.pa.yaml')))
$idx = @{}; function Add-WrIndex($entries) { foreach ($e in $entries) { $n = @($e.Keys)[0]; $idx[$n] = $e[$n]; Add-WrIndex $e[$n]['Children'] } }; Add-WrIndex $doc['Screens'][$scr]['Children']
$all = [ordered]@{}
foreach ($n in $idx.Keys) { foreach ($p in $idx[$n]['Properties'].Keys) { $all["$n.$p"] = ([string]$idx[$n]['Properties'][$p]).Trim() } }
foreach ($p in $doc['Screens'][$scr]['Properties'].Keys) { $all["$scr.$p"] = ([string]$doc['Screens'][$scr]['Properties'][$p]).Trim() }
function P([string]$key) { if (!$all.Contains($key)) { throw "FAIL missing $key" }; return [string]$all[$key] }
$onExp = P 'cmpWrFooter.OnExport'
$onExpN = Get-Norm $onExp
$onExpBare = Get-Norm (Remove-FxStrings $onExp)
$guard = (P 'cmpWrFooter.ExportEnabled').Substring(1)
$screenText = ($all.Values) -join "`n"
$loader = P 'btnWrLoad.OnSelect'
$loaderN = Get-Norm $loader

# (1) Admission (6.6): visible, same guard in ExportEnabled and as first OnExport condition, fail-closed contents -----------
Assert-True ($idx['cmpWrFooter']['ComponentName'] -eq 'cmpReportFooter' -and (P 'cmpWrFooter.ExportVisible') -eq '=true') 'Export button visible (cmpReportFooter.ExportVisible = true; component unchanged)'
Assert-True ($onExp.StartsWith("=If($guard,")) 'guard parity: OnExport starts with If(<ExportEnabled>, (same text)'
$gN = Get-Norm $guard
foreach ($part in '!Coalesce(varWrBusy,false)', '!Coalesce(varWrExporting,false)', 'varWrLoadState="Loaded"', 'IsEmpty(colWrLoadErrors)', '!IsBlank(varWrLoadedProject.ID)', '!IsBlank(varWrLoadedMonday)', 'varWrLoadedProjectID=varWrProjectID', 'varWrLoadedMonday=varWrMonday', '(Coalesce(varWrContractorID,0)=0||CountIf(colWrGroups,ContractorID=varWrContractorID&&Display=varWrContractorDisplay)=1)', 'CountIf(colWrRows,Coalesce(varWrContractorID,0)=0||ContractorID=varWrContractorID)>0') {
    Assert-True ($gN.Contains($part)) "export guard contains: $part"
}
$formulas = [string]$appDoc['App']['Properties']['Formulas']
$tStart = $formulas.IndexOf('T = {'); $tEnd = $formulas.IndexOf('};', $tStart)
Set-FxVar 'T' $formulas.Substring($tStart + 4, $tEnd - $tStart - 3)
Set-FxVar 'LangNl' 'false'
$okCtx = [ordered]@{ varWrBusy = 'false'; varWrExporting = 'false'; varWrLoadState = '"Loaded"'; colWrLoadErrors = 'Filter(Table({Message:"x"}),false)'; varWrLoadedProject = '{ID:7}'; varWrLoadedMonday = 'Date(2026,11,9)'; varWrLoadedProjectID = '7'; varWrProjectID = '7'; varWrMonday = 'Date(2026,11,9)'; varWrContractorID = '0'; varWrContractorDisplay = '""'; colWrGroups = 'Table({ContractorID:10,Display:"Alpha (EMP-010)"},{ContractorID:20,Display:"Beta (B-1)"})'; colWrRows = 'Table({ContractorID:10,WorkerID:1},{ContractorID:20,WorkerID:2})' }
function Test-Guard([string]$override, $expected, [string]$label) {
    $ctx = [ordered]@{}; foreach ($k in $okCtx.Keys) { $ctx[$k] = $okCtx[$k] }
    foreach ($kv in ($override -split '\|\|\|')) { if ($kv) { $i = $kv.IndexOf(':'); $ctx[$kv.Substring(0, $i)] = $kv.Substring($i + 1) } }
    $rec = (@($ctx.Keys | ForEach-Object { "$($_):$($ctx[$_])" })) -join ','
    Assert-Eval "With({$rec},$guard)" $expected "export guard = $expected : $label"
}
Test-Guard '' $true 'Loaded, no errors, same project/week, All contractors, rows present'
Test-Guard 'varWrBusy:true' $false 'busy (loading or exporting)'
Test-Guard 'varWrExporting:true' $false 'export running'
Test-Guard 'varWrLoadState:"Failed"' $false 'load failed'
Test-Guard 'varWrLoadState:"Loading"' $false 'loading'
Test-Guard 'colWrLoadErrors:Table({Message:"x"})' $false 'load errors present (incl. 500 / truncated batch)'
Test-Guard 'varWrProjectID:8' $false 'project selection differs from the loaded project'
Test-Guard 'varWrMonday:Date(2026,11,16)' $false 'week selection differs from the loaded week'
Test-Guard 'varWrContractorID:20|||varWrContractorDisplay:"Beta (B-1)"' $true 'one contractor of the loaded report'
Test-Guard 'varWrContractorID:20|||varWrContractorDisplay:"Alpha (EMP-010)"' $false 'contractor ID and remembered display text disagree'
Test-Guard 'varWrContractorID:30|||varWrContractorDisplay:"Gamma"' $false 'contractor not in the loaded report'
Assert-True ($guard -notmatch 'cmpWr\w+\.Value') 'guard reads no component output (Test-Components instance rule; dropdown and variables are kept in step by cmpWrContractor.OnChange)'
Test-Guard 'colWrRows:Filter(Table({ContractorID:10,WorkerID:1}),false)' $false 'no report rows'
Test-Guard 'varWrContractorID:20|||varWrContractorDisplay:"Beta (B-1)"|||colWrRows:Table({ContractorID:10,WorkerID:1})' $false 'chosen contractor has no rows'
$blocked = $onExp.Substring($onExp.LastIndexOf('Set(varWrBusy,false); Set(varWrExporting,false),'))
Assert-True ($blocked.Contains('Set(varAdmMsgKind,"Error")') -and $blocked.Contains('T.admHeadBlocked.en') -and $blocked.Contains('T.wrMsgExportBlocked.en') -and $blocked -notmatch '\.Run\(') 'guard false: red "Blocked." message, no flow call'

# (2) Busy flag, no mutations, messages ----------------------------------------------------------------------------------
Assert-True ($onExpN.StartsWith("=If($gN,Set(varWrExporting,true);Set(varWrBusy,true);")) 'export sets varWrExporting and varWrBusy first (spinner in cmpTitleBar; navigation, Refresh and week change blocked)'
Assert-True ($onExpN.Contains('Set(varWrBusy,false);Set(varWrExporting,false),Set(varAdmMsgKind,"Error")') -and ([regex]::Matches($onExpN, 'Set\(varWrExporting,false\)')).Count -eq 1) 'busy flags reset once, at the end of the export branch'
Assert-True ((P 'cmpWrTitle.Busy') -eq '=Coalesce(varWrBusy,false) || varWrLoadState="Loading"') 'title spinner follows varWrBusy (also during export)'
foreach ($k in 'cmpWrFooter.HomeEnabled', 'cmpWrFooter.RefreshEnabled', 'dpWrWeek.DisplayMode', 'btnWrPrev.DisplayMode', 'btnWrNext.DisplayMode', 'cmpWrProject.Enabled', 'cmpWrContractor.Enabled') { Assert-True ((P $k).Contains('!Coalesce(varWrBusy,false)')) "$k blocked while busy (export sets varWrBusy)" }
Assert-True ((P 'btnWrLoad.OnSelect').StartsWith('=If(Coalesce(varWrBusy,false),')) 'loader refuses while busy (no reload during export)'
$bare = Remove-FxStrings $screenText
Assert-True ($bare -notmatch '\b(Patch|Remove|RemoveIf|Update|UpdateIf|SubmitForm|Defaults|Launch|Download|Notify|Choices)\(') 'no Patch/Remove/Update/SubmitForm/Launch/Download/Notify/Choices on scrWeekReport'
$colTargets = @([regex]::Matches((Remove-FxStrings $onExp), '\b(Collect|ClearCollect|Clear)\(\s*([^,\)]+)') | ForEach-Object { $_.Groups[2].Value.Trim() } | Sort-Object -Unique)
Assert-True (@($colTargets | Where-Object { $_ -notmatch '^col[A-Z]\w*$' }).Count -eq 0 -and $colTargets -notcontains 'Translations') "OnExport collection functions only target local collections ($($colTargets -join ', '))"
Assert-True ($onExpN.Contains('Set(varAdmMsgKind,"Success");Set(varAdmMsgHead,If(LangNl&&!IsBlank(T.admHeadExported.nl),T.admHeadExported.nl,T.admHeadExported.en));') -and $onExpN.Contains('If(IsEmpty(colWrExportErrors)&&varWrExpPdfOk&&varWrExpCsvOk,Set(varAdmMsgKind,"Success")')) 'green "Exported." only when both files are OK and no error was collected'
Assert-True ($onExpN.Contains('Set(varAdmMsgHead,If(varWrExpFiles>0,If(LangNl&&!IsBlank(T.admHeadPartExported.nl),T.admHeadPartExported.nl,T.admHeadPartExported.en),If(LangNl&&!IsBlank(T.admHeadNotExported.nl),T.admHeadNotExported.nl,T.admHeadNotExported.en)))')) 'failure: red "Partly exported." (PDF saved, CSV failed) or "Not exported."'
$tKeys = @([regex]::Matches($formulas, '(?m)^\s*(\w+):\s*\{en:') | ForEach-Object { $_.Groups[1].Value })
$used = @([regex]::Matches($onExp + $guard, '\bT\.(\w+)\.en\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True (@($used | Where-Object { $tKeys -notcontains $_ }).Count -eq 0 -and $used.Count -ge 14) "all $($used.Count) T keys used by the export exist in App.Formulas T (English UI texts)"
Assert-Eval 'T.wrMsgExported.en' 'Saved in Exports/{0}: {1}.pdf and {1}.csv' 'success body names the folder and both file names'
Assert-Eval 'T.wrErrExportCsv.en' 'PDF {0}.pdf saved, but CSV {0}.csv not saved: {1}' 'CSV failure says the PDF was saved'
$trace = [regex]::Match($onExp, 'Trace\("DIAG\|Export\|End",TraceSeverity\.Information,\{([^}]*)\}\)')
Assert-True ($trace.Success -and $trace.Groups[1].Value.Contains('Files:varWrExpFiles') -and $trace.Groups[1].Value.Contains('ElapsedMs:DateDiff(varWrExpT0,Now(),TimeUnit.Milliseconds)') -and $trace.Groups[1].Value.Contains('Errors:CountRows(colWrExportErrors)') -and $trace.Groups[1].Value -notmatch 'Name|User|Folder|Base|Message') 'trace DIAG|Export|End with Files, ElapsedMs, Errors and no names'

# (3) Flow calls (6.5): 2 calls, PDF 5 arguments with TemplateName, CSV 4 arguments, each checked ---------------------------
$runs = @([regex]::Matches($onExp, "'SiteManagment-Exportfile'\.Run\("))
Assert-True ($runs.Count -eq 2 -and ([regex]::Matches($bare, '\.Run\(')).Count -eq 2) "exactly 2 calls of 'SiteManagment-Exportfile'.Run (PDF + CSV) on the screen"
$pdfArgs = Split-FxArgs (Get-Balanced $onExp ($runs[0].Index + $runs[0].Length - 1))
$csvArgs = Split-FxArgs (Get-Balanced $onExp ($runs[1].Index + $runs[1].Length - 1))
Assert-True ($pdfArgs.Count -eq 5 -and ($pdfArgs | ForEach-Object { $_.Trim() }) -join '|' -ceq 'varWrExpFolder|varWrExpBase|"pdf"|varWrExpHtml|{text_4:"weekreport.html"}') 'PDF call: Run(Folder, FileName, "pdf", Content, {text_4: "weekreport.html"}) (TemplateName as optional record)'
Assert-True ($csvArgs.Count -eq 4 -and ($csvArgs | ForEach-Object { $_.Trim() }) -join '|' -ceq 'varWrExpFolder|varWrExpBase|"csv"|varWrExpCsvText') 'CSV call: Run(Folder, FileName, "csv", Content) (same base name, no TemplateName)'
Assert-True ($onExpN.Contains("IfError(Set(varWrExpPdfResult,'SiteManagment-Exportfile'.Run(") -and $onExpN.Contains("IfError(Set(varWrExpCsvResult,'SiteManagment-Exportfile'.Run(")) 'each flow call inside IfError'
foreach ($f in 'Pdf', 'Csv') { Assert-True ($onExpN.Contains("Set(varWrExp${f}Ok,IsBlank(varWrExp${f}Error)&&Lower(Trim(varWrExp${f}Result.status&`"`"))=`"ok`"&&!IsBlank(Trim(varWrExp${f}Result.fileurl&`"`")));")) "$f result: OK only without error, status ok (case-insensitive) and a non-empty fileurl" }
Assert-True ($onExpN.Contains("If(IsEmpty(colWrExportErrors)&&varWrExpPdfOk,Set(varWrExpCsvResult,Blank());")) 'CSV only after a successful PDF and without collected errors'
$iPdf = $onExpN.IndexOf("'SiteManagment-Exportfile'.Run("); $iCsv = $onExpN.LastIndexOf("'SiteManagment-Exportfile'.Run(")
Assert-True ($onExpN.IndexOf('Set(varWrExpHtml,Concat(') -lt $iPdf -and $onExpN.IndexOf('Set(varWrExpCsvText,UniChar(65279)') -lt $iPdf -and $onExpN.LastIndexOf('Filter(Translations,') -lt $iPdf -and $iPdf -lt $iCsv) 'order: Translations reads and all local building first, then PDF, then CSV'
Assert-True ($onExpN.Contains('If(IsEmpty(colWrExportErrors),Set(varWrExpPdfResult,Blank());')) 'PDF call only when no local/Translations error was collected (any error = zero flow calls)'

# (4) Translations reads (6.3): three reads with global predicate variables, 500 guards, read errors block -----------------
$reads = @([regex]::Matches($onExpN, 'IfError\(CountRows\(ClearCollect\((colWrDoc\w+),ForAll\(Filter\(Translations,Language=(varWrDocQuery\w+)\)Astr,\{Key:Trim\(tr\.Title&""\),Txt:TrimEnds\(tr\.Text&""\)\}\)\)\)>=0,Collect\(colWrExportErrors,'))
Assert-True ($reads.Count -eq 3 -and (($reads | ForEach-Object { $_.Groups[1].Value + '=' + $_.Groups[2].Value }) -join ',') -ceq 'colWrDocNl=varWrDocQueryNl,colWrDocEn=varWrDocQueryEn,colWrDoc2=varWrDocQuery2') 'three Translations reads Filter(Translations, Language = <global var>) (Dutch, English, second language), each in IfError'
Assert-True (([regex]::Matches($onExpBare, '\bTranslations\b')).Count -eq 4 -and ([regex]::Matches((Remove-FxStrings ($screenText.Replace($onExp, ''))), '\bTranslations\b')).Count -eq 0) 'Translations referenced only by Refresh + the 3 reads in OnExport'
foreach ($c in @(@('Nl', '"Dutch"'), @('En', '"English"'), @('2', 'varWrDocLang2'))) {
    $iSet = $onExpN.IndexOf("Set(varWrDocQuery$($c[0]),$($c[1]))"); $iRead = $onExpN.IndexOf("Language=varWrDocQuery$($c[0]))")
    Assert-True ($iSet -ge 0 -and $iSet -lt $iRead) "predicate variable varWrDocQuery$($c[0]) set before its read"
}
foreach ($c in 'Nl', 'En', '2') { Assert-True ($onExpN.Contains("If(CountRows(colWrDoc$c)>=500,Collect(colWrExportErrors,")) "500 guard on colWrDoc$c (500+ = error, no export)" }
Assert-True ($onExpN.Contains('If(varWrDocQuery2<>"Dutch"&&varWrDocQuery2<>"English",IfError(CountRows(ClearCollect(colWrDoc2,') -and $onExpN.Contains('If(varWrDocQuery2="English",ClearCollect(colWrDoc2,colWrDocEn))')) 'second-language read only when it is not Dutch/English (English reuses the English read)'
Assert-True ($onExpN.Contains('IfError(Refresh(Translations),Collect(colWrExportErrors,')) 'Refresh(Translations) in IfError before the reads'

# (5) Keys (23) from templates/translations-weekreport.csv -------------------------------------------------------------------
$csvLines = [IO.File]::ReadAllLines((Join-Path $tplDir 'translations-weekreport.csv'), [Text.Encoding]::UTF8) | Select-Object -Skip 1 | Where-Object { $_.Trim() }
$tr = @($csvLines | ForEach-Object { $p = $_.Split(';'); [pscustomobject]@{ Key = $p[0]; Lang = $p[1]; Text = ($p[2..($p.Count - 1)] -join ';') } })
$keys = @($tr | ForEach-Object Key | Select-Object -Unique)
Assert-True ($keys.Count -eq 23) "translations-weekreport.csv: 23 doc.* keys"
foreach ($k in $keys) { Assert-True ($onExp.Contains('"' + $k + '"')) "key $k used in OnExport" }
foreach ($k in $keys) { foreach ($lg in 'Dutch', 'English') { if (-not ($tr | Where-Object { $_.Key -eq $k -and $_.Lang -eq $lg -and $_.Text.Trim() })) { throw "FAIL $k missing for $lg in the CSV" } } }
Assert-True $true 'every key has a Dutch and an English text in the CSV (fallback to the key never needed for the delivered texts)'

# (6) Interpreter: texts with fallback ----------------------------------------------------------------------------------------
function Get-TrTable([string]$lang) { return 'Table(' + ((@($tr | Where-Object Lang -eq $lang) | ForEach-Object { '{Key:' + (ConvertTo-FxString $_.Key) + ',Txt:' + (ConvertTo-FxString $_.Text) + '}' }) -join ',') + ')' }
$pageListFx = Get-CallArg $onExp 'ClearCollect(colWrDocPageList,' 1
$textsFx = Get-CallArg $onExp 'Collect(colWrDocTexts,' 1
$lang2Fx = Get-CallArg $onExp 'Set(varWrDocLang2,' 1
$code2Fx = Get-CallArg $onExp 'Set(varWrDocCode2,' 1
function Set-DocTexts() {
    $pages = Invoke-Fx $pageListFx; Set-FxValue 'colWrDocPageList' $pages
    $n = (Invoke-Fx 'CountRows(colWrDocPageList)').Value
    Set-FxValue 'colWrDocTexts' (Invoke-Fx "With({pg:First(colWrDocPageList)},$textsFx)")
    if ($n -gt 1) {
        Set-FxValue 'wrTxt2' (Invoke-Fx "With({pg:Last(colWrDocPageList)},$textsFx)")
        Set-FxValue 'colWrDocTexts' (Invoke-Fx 'With({a:colWrDocTexts,b:wrTxt2},ForAll(Sequence(CountRows(a)+CountRows(b)) As i,If(i.Value<=CountRows(a),Index(a,i.Value),Index(b,i.Value-CountRows(a)))))')
    }
}
Set-FxVar 'colWrDocNl' (Get-TrTable 'Dutch'); Set-FxVar 'colWrDocEn' (Get-TrTable 'English')
Set-FxVar 'colWrDoc2' 'Table({Key:"doc.title",Txt:"Raport X"},{Key:"doc.colName",Txt:""})'
Set-FxVar 'colWrDocNl' 'Filter(colWrDocNl,Key<>"doc.weekRangeSep")'
Set-FxVar 'varWrDocLang2' '"Polish"'; Set-FxVar 'varWrDocCode2' '"pl"'
Set-DocTexts
Assert-Eval 'Concat(colWrDocPageList,Text(Page) & Lang,",")' '1nl,2pl' 'second language Polish: page 1 nl + page 2 pl'
Assert-Eval 'Concat(Filter(colWrDocTexts,Key in ["doc.title","doc.colName","doc.week","doc.weekRangeSep"]),Text(Page) & ":" & Key & "=" & Txt & If(Missing,"!",""),"; ")' '1:doc.title=Weekrapport; 1:doc.week=Week; 1:doc.weekRangeSep=doc.weekRangeSep!; 1:doc.colName=Naam; 2:doc.title=Raport X; 2:doc.week=Week; 2:doc.weekRangeSep=to; 2:doc.colName=Name' 'fallback: second language missing or empty -> English; missing in Dutch -> the key itself (flagged Missing for the trace)'
Assert-True ($onExpN.Contains('If(CountIf(colWrDocTexts,Missing)>0,Trace("DIAG|Export|MissingText",TraceSeverity.Warning,')) 'missing texts only traced (not shown in the UI)'
Set-FxVar 'varWrDocLang2' '"Dutch"'; Set-FxVar 'varWrDocCode2' '"nl"'
Assert-Eval "CountRows($pageListFx)" 1 'second language Dutch: only page 1'
# language choice (H24/WR1): Employers.Language first, else the group ReportLanguage; All contractors: one common outcome or English
Set-FxVar 'colWrGroups' 'Table({ContractorID:10,ReportLanguage:"Romanian",ContractorName:"Alpha",EmployerCode:"EMP-010"},{ContractorID:20,ReportLanguage:"German",ContractorName:"Beta",EmployerCode:"B-1"},{ContractorID:30,ReportLanguage:"Polish",ContractorName:"Gamma",EmployerCode:"G-1"})'
Set-FxVar 'colWrEmployers' 'Table({ID:10,Language:"Polish"},{ID:20,Language:""},{ID:30,Language:""})'
foreach ($c in @(@(10, 'Polish'), @(20, 'German'), @(30, 'Polish'), @(0, 'English'))) { Assert-Eval "With({varWrExpContractorID:$($c[0])},$lang2Fx)" $c[1] "second language for contractor $($c[0]) = $($c[1]) (Employers.Language, else majority language of the group; All with mixed outcomes = English)" }
Set-FxVar 'colWrGroups' 'Table({ContractorID:10,ReportLanguage:"Romanian"},{ContractorID:30,ReportLanguage:"Polish"})'
Assert-Eval "With({varWrExpContractorID:0},$lang2Fx)" 'Polish' 'All contractors with one common outcome (Polish) = Polish'
foreach ($c in @(@('Dutch', 'nl'), @('English', 'en'), @('Polish', 'pl'), @('Romanian', 'ro'), @('German', 'de'), @('Ukrainian', 'uk'), @('Spanish', 'und'))) { Assert-Eval "With({varWrDocLang2:`"$($c[0])`"},$code2Fx)" $c[1] "lang code $($c[0]) -> $($c[1])" }
Assert-True ($loaderN.Contains('Language:If(Trim(emp.Language.Value&"")="Nederlands","Dutch",Trim(emp.Language.Value&""))') -and $loaderN.Contains('Country:Trim(p.Country.Value&"")') -and $loaderN.Contains('Country:p.Country,Display:')) 'Employers.Language and Projects.Country added to the existing master projections (no extra read)'

# (7) Interpreter: PDF Content equals templates/sample-body.html ---------------------------------------------------------------
$linesFx = Get-CallArg $onExp 'ClearCollect(colWrExpLines,' 1
$htmlFx = Get-CallArg $onExp 'Set(varWrExpHtml,' 1 -Last
$isoYFx = Get-CallArg $onExp 'Set(varWrExpIsoYear,' 1
$isoWFx = Get-CallArg $onExp 'Set(varWrExpIsoWeek,' 1
$labelFx = Get-CallArg $onExp 'Set(varWrExpWeekLabel,' 1
$folderFx = Get-CallArg $onExp 'Set(varWrExpFolder,' 1
$baseFx = Get-CallArg $onExp 'Set(varWrExpBase,' 1
function Set-Week([string]$mondayFx) { Set-FxVar 'varWrLoadedMonday' $mondayFx; Set-FxVar 'varWrExpIsoYear' $isoYFx; Set-FxVar 'varWrExpIsoWeek' $isoWFx; Set-FxVar 'varWrExpWeekLabel' $labelFx }
Set-Week 'Date(2026,11,9)'
Set-FxVar 'varWrLoadedProject' '{ID:1,Title:"Test project",Country:"Netherlands",Number:"TEST-000",Reference:"Test project reference",Display:"x"}'
Set-FxVar 'varWrExpNow' 'DateTime(2026,11,12,10,0,0)'; Set-FxVar 'varWrExpUser' '"Test User"'; Set-FxVar 'varWrExpContractorID' '0'
Set-FxVar 'colWrDocNl' (Get-TrTable 'Dutch'); Set-FxVar 'colWrDoc2' (Get-TrTable 'English')
Set-FxVar 'varWrDocLang2' '"English"'; Set-FxVar 'varWrDocCode2' '"en"'
Set-DocTexts
$nb = 'If(false,0)'
function Get-Line($type, $sk, $cid, $name, $code, $trade, $zebra, $d, $tot) { $dd = @(1..7 | ForEach-Object { "D$($_):$($d[$_-1])" }) -join ','; return "{LineType:`"$type`",SortKey:$sk,ContractorID:$cid,Name:`"$name`",Code:`"$code`",Lang:`"`",Trade:`"$trade`",Zebra:$zebra,$dd,WeekTotal:$tot}" }
$sampleLines = @(
    (Get-Line 'Header' 100000 901 'TEST Employer' 'EMP-901' '' 'false' @(0, 0, 0, 0, 0, 0, 0) 0),
    (Get-Line 'Row' 100001 901 'Test Worker A' 'WKR-001' 'Fitter' 'false' @(8, 8, 8, 8, 6, $nb, $nb) 38),
    (Get-Line 'Row' 100002 901 'Test Worker B' 'WKR-002' 'Welder' 'true' @(10, 10, 10, 10, $nb, 4, $nb) 44),
    (Get-Line 'Subtotal' 199999 901 'Subtotal' 'EMP-901' '' 'false' @(18, 18, 18, 18, 6, 4, 0) 82),
    (Get-Line 'Header' 200000 902 'TEST Contractor B' 'EMP-902' '' 'false' @(0, 0, 0, 0, 0, 0, 0) 0),
    (Get-Line 'Row' 200003 902 'Test Worker C' 'WKR-003' 'Fitter' 'false' @(8, 8, $nb, $nb, $nb, $nb, $nb) 16),
    (Get-Line 'Subtotal' 299999 902 'Subtotal' 'EMP-902' '' 'false' @(8, 8, 0, 0, 0, 0, 0) 16),
    (Get-Line 'Grand' 999999999 -1 'Total' '' '' 'false' @(26, 26, 18, 18, 6, 4, 0) 98))
Set-FxVar 'colWrLines' ('Table(' + ($sampleLines -join ',') + ')')
Set-FxVar 'colWrGroups' 'Table({ContractorID:901,ContractorName:"TEST Employer",EmployerCode:"EMP-901",ReportLanguage:"English"},{ContractorID:902,ContractorName:"TEST Contractor B",EmployerCode:"EMP-902",ReportLanguage:"English"})'
Set-FxVar 'colWrExpLines' $linesFx
$html = (Invoke-Fx $htmlFx).Value
$sample = ([IO.File]::ReadAllText((Join-Path $tplDir 'sample-body.html'))).Replace("`r`n", "`n")
$sample = $sample.Substring($sample.IndexOf("`n") + 1)  # drop the leading comment line
if ($html.TrimEnd() -cne $sample.TrimEnd()) {
    $a = $html.TrimEnd().Split("`n"); $b = $sample.TrimEnd().Split("`n")
    for ($i = 0; $i -lt [Math]::Max($a.Count, $b.Count); $i++) { if ($a[$i] -cne $b[$i]) { throw "FAIL PDF Content differs from sample-body.html at line $($i+2):`n  app:    $($a[$i])`n  sample: $($b[$i])" } }
}
Assert-True $true 'PDF Content (All contractors, nl + en) is byte-identical to templates/sample-body.html: named page + @page footer style + {{HEADER}} + doc-title + meta (6 rows) + colgroup + day headers with daydate + group/alt/subtotal/total rows, we on Sat/Sun, &ndash; for 0/empty'
Assert-True (([regex]::Matches($html, '\{\{HEADER\}\}')).Count -eq 2 -and $html -notmatch '\{\{BODY\}\}' -and $html -notmatch '<script|<img|<link|url\(') 'one {{HEADER}} per page, no {{BODY}}, no script/image/link in Content'
# one contractor: no total row, contractor "name &middot; code" in the info block, Dutch only
Set-FxVar 'varWrExpContractorID' '902'; Set-FxVar 'varWrDocLang2' '"Dutch"'; Set-FxVar 'varWrDocCode2' '"nl"'
Set-DocTexts
Set-FxVar 'colWrExpLines' $linesFx
$html1 = (Invoke-Fx $htmlFx).Value
Assert-True (([regex]::Matches($html1, '<section ')).Count -eq 1 -and $html1.Contains('<tr><th>Aannemer</th><td>TEST Contractor B &middot; EMP-902</td></tr>') -and $html1 -notmatch 'class="total"' -and $html1 -notmatch 'TEST Employer' -and ([regex]::Matches($html1, '<tr class="subtotal">')).Count -eq 1) 'one contractor, second language Dutch: 1 page, info block "name &middot; code", only its group + subtotal, no total row (as on screen)'
# escaping: data and texts HTML-escaped, "{" as &#123;; footer as a CSS string
Set-FxVar 'varWrExpContractorID' '0'
Set-FxVar 'colWrLines' ('Table(' + (Get-Line 'Header' 100000 901 'A&B <x> "q" {{HEADER}}' 'E{1}' '' 'false' @(0, 0, 0, 0, 0, 0, 0) 0).Replace('"A&B <x> "q" {{HEADER}}"', '"A&B <x> ""q"" {{HEADER}}"') + ',' + (Get-Line 'Row' 100001 901 'Test <W>' 'WKR-1' 'Fit;ter' 'false' @(7.5, 0, $nb, 2.25, 10, $nb, $nb) 19.75) + ')')
Set-FxVar 'colWrExpLines' $linesFx
Set-FxVar 'varWrExpUser' "`"Q `"`"B`"`" \ <x> {y}`" & Char(10) & `"z`""
Set-FxVar 'varWrLoadedProject' '{ID:1,Title:"P & <Q>",Country:"",Number:"P{1}",Reference:"R\"" ",Display:"x"}'.Replace('R\"" "', 'R"" "')
$colNl = (Get-TrTable 'Dutch').Replace('"Pagina {page} van {pages}"', '"{page}/{pages}"')
Set-FxVar 'colWrDocNl' $colNl
Set-DocTexts
$h2 = (Invoke-Fx $htmlFx).Value
Assert-True ($h2.Contains('<tr class="group"><td colspan="10">A&amp;B &lt;x&gt; &quot;q&quot; &#123;&#123;HEADER}} &middot; E&#123;1}</td></tr>') -and ([regex]::Matches($h2, '\{\{HEADER\}\}')).Count -eq 1) 'HTML escaping of data: & < > " and { as &#123; (a name can never form a token)'
Assert-True ($h2.Contains('<td>Test &lt;W&gt;</td><td>Fit;ter</td><td class="num">7,5</td><td class="num">&ndash;</td><td class="num">&ndash;</td><td class="num">2,25</td><td class="num">10</td><td class="num we">&ndash;</td><td class="num we">&ndash;</td><td class="num total-col">19,75</td>') -and $h2.Contains('<td>P &amp; &lt;Q&gt;</td>') -and $h2.Contains('<td>P&#123;1}</td>')) 'numbers with decimal comma, whole hours without separator, 0 and empty as &ndash;; project fields escaped'
Assert-True ($h2.Contains('@bottom-left { content: "Gegenereerd 12-11-2026 10:00 door Q \"B\" \\ \3C x> \7B y} z"; }')) 'footer CSS string: {date}/{user} filled, \ -> \\, " -> \", < -> \3C, { -> \7B, line break removed'
Assert-True ($h2.Contains('@bottom-right { content: counter(page) "/" counter(pages); }')) 'page footer "{page}/{pages}" -> counter(page) "/" counter(pages) (empty leading/trailing strings dropped)'

# (8) Interpreter: file names and folder (6.4) ---------------------------------------------------------------------------------
Set-FxVar 'varWrLoadedProject' '{ID:1,Number:"TEST-000"}'; Set-FxVar 'varWrLoadedIsTest' 'true'; Set-FxVar 'varWrExpContractorID' '0'
Set-FxVar 'varWrExpFolder' $folderFx
Assert-Eval $baseFx 'TEST_WeekReport_TEST-000_2026KW46_ALL' 'TEST project, All contractors: TEST_WeekReport_TEST-000_2026KW46_ALL'
Assert-Eval 'varWrExpFolder' 'TEST-000' 'folder = Project Number'
Set-Week 'Date(2026,12,28)'
Set-FxVar 'varWrLoadedProject' '{ID:1,Number:" P/1:2 "}'; Set-FxVar 'varWrLoadedIsTest' 'false'; Set-FxVar 'varWrExpContractorID' '10'
Set-FxVar 'colWrGroups' 'Table({ContractorID:10,EmployerCode:"E*1?""<>|#%\x"})'
Set-FxVar 'varWrExpFolder' $folderFx
Assert-Eval $baseFx 'WeekReport_P-1-2_2026KW53_E-1--------x' 'real project, one contractor, ISO week 53: no TEST_ prefix, EmployerCode suffix, \ / : * ? " < > | # % replaced by "-"'
Set-Week 'Date(2027,1,4)'
Assert-Eval $baseFx 'WeekReport_P-1-2_2027KW01_E-1--------x' 'ISO week 2027 KW01 (two digits)'
Assert-True ($onExpN.Contains('If(IsBlank(varWrExpFolder),Collect(colWrExportErrors,')) 'empty Project Number blocks the export (no flow call)'
Assert-True ($loaderN.Contains('Set(varWrLoadedIsTest,varWrPendIsTest)') -and $loaderN.Contains('Set(varWrPendIsTest,Left(Trim(varWrPendProject.Number&""),5)="TEST-")')) 'TEST_ prefix follows the loaded project (Project Number starts with TEST-)'

# (9) Interpreter: CSV (6.1) ------------------------------------------------------------------------------------------------------
$csvRowsFx = Get-CallArg $onExp 'ClearCollect(colWrExpCsvRows,' 1
$csvTextFx = Get-CallArg $onExp 'Set(varWrExpCsvText,' 1 -Last
Assert-True ($csvTextFx.StartsWith('UniChar(65279) & "ProjectNumber;ProjectReference;EmployerCode;EmployerName;WorkerID;WorkerName;Trade;WorkDate;ISOYear;ISOWeek;Hours" & Char(13) & Char(10) & Concat(colWrExpCsvRows,Line & Char(13) & Char(10))')) 'CSV: UTF-8 BOM via UniChar(65279), exact header, CRLF line ends'
Assert-True ($csvRowsFx.Contains('"nl-NL"') -and $csvRowsFx.Contains('Text(f.WorkDay,"yyyy-mm-dd")') -and $csvRowsFx.Contains('Text(varWrExpIsoWeek,"00")') -and $csvRowsFx -notmatch 'Choices\(|LookUp\((Hours|Workers|Employers)') 'CSV fields: decimal comma (nl-NL), yyyy-mm-dd, ISOWeek two digits; local data only'
Assert-True ($loaderN.Contains('ClearCollect(colWrPendExportFacts,ForAll(colWrPendFacts Asf,'.Replace(' ', '')) -and $loaderN.Contains('ClearCollect(colWrExportFacts,colWrPendExportFacts)') -and $loaderN.IndexOf('ClearCollect(colWrExportFacts,') -gt $loaderN.IndexOf('If(IsEmpty(colWrLoadErrors),ClearCollect(colWrRows,colWrPendRowsShown);')) 'hour facts per Hours record kept from staging, committed with the report (no extra Hours read at export)'
Set-Week 'Date(2026,12,28)'
Set-FxVar 'varWrLoadedProject' '{ID:1,Number:"P-1000",Reference:"Ref; A"}'
Set-FxVar 'colWrRows' 'Table({WorkerID:1,ContractorID:10,WorkerCode:"WKR-001",WorkerName:"Anna \"Q\" Test",EmployerCode:"EMP-010",WeekTotal:15.5},{WorkerID:2,ContractorID:10,WorkerCode:"WKR-002",WorkerName:"Bram Test",EmployerCode:"EMP-010",WeekTotal:10},{WorkerID:3,ContractorID:20,WorkerCode:"WKR-003",WorkerName:"Cees Test",EmployerCode:"B-1",WeekTotal:0},{WorkerID:2,ContractorID:20,WorkerCode:"WKR-002",WorkerName:"Bram Test",EmployerCode:"B-1",WeekTotal:3})'.Replace('\"Q\"', '""Q""')
Set-FxVar 'colWrExportFacts' 'Table({HourID:11,WorkerID:1,ContractorID:10,EmployerName:"Alpha;Old",DayIndex:1,WorkDay:Date(2026,12,29),HourValue:7.5,Trade:"Welder",Pos:2},{HourID:10,WorkerID:1,ContractorID:10,EmployerName:"Alpha;Old",DayIndex:0,WorkDay:Date(2026,12,28),HourValue:8,Trade:"Welder",Pos:2},{HourID:12,WorkerID:2,ContractorID:10,EmployerName:"Alpha",DayIndex:2,WorkDay:Date(2026,12,30),HourValue:0,Trade:"Fitter",Pos:1},{HourID:13,WorkerID:2,ContractorID:10,EmployerName:"Alpha",DayIndex:3,WorkDay:Date(2026,12,31),HourValue:10,Trade:"Fitter",Pos:1},{HourID:14,WorkerID:3,ContractorID:20,EmployerName:"Beta",DayIndex:0,WorkDay:Date(2026,12,28),HourValue:0,Trade:"Fitter",Pos:3},{HourID:15,WorkerID:5,ContractorID:99,EmployerName:"TEST Employer",DayIndex:0,WorkDay:Date(2026,12,28),HourValue:8,Trade:"Fitter",Pos:0},{HourID:16,WorkerID:2,ContractorID:20,EmployerName:"Beta",DayIndex:6,WorkDay:Date(2027,1,3),HourValue:3,Trade:"Welder",Pos:4})'
$crlf = "`r`n"; $bom = [string][char]0xFEFF
$hdr = 'ProjectNumber;ProjectReference;EmployerCode;EmployerName;WorkerID;WorkerName;Trade;WorkDate;ISOYear;ISOWeek;Hours'
$expAll = $bom + $hdr + $crlf +
    '"P-1000";"Ref; A";EMP-010;Alpha;WKR-002;Bram Test;Fitter;2026-12-30;2026;53;0'.Replace('"P-1000"', 'P-1000') + $crlf +
    'P-1000;"Ref; A";EMP-010;Alpha;WKR-002;Bram Test;Fitter;2026-12-31;2026;53;10' + $crlf +
    'P-1000;"Ref; A";EMP-010;"Alpha;Old";WKR-001;"Anna ""Q"" Test";Welder;2026-12-28;2026;53;8' + $crlf +
    'P-1000;"Ref; A";EMP-010;"Alpha;Old";WKR-001;"Anna ""Q"" Test";Welder;2026-12-29;2026;53;7,5' + $crlf +
    'P-1000;"Ref; A";B-1;Beta;WKR-002;Bram Test;Welder;2027-01-03;2026;53;3' + $crlf
Set-FxVar 'varWrExpContractorID' '0'
Set-FxVar 'colWrExpCsvRows' $csvRowsFx
$csvAll = (Invoke-Fx $csvTextFx).Value
if ($csvAll -cne $expAll) { throw "FAIL CSV All contractors:`n$($csvAll.Replace($crlf,'<CRLF>'))`nexpected:`n$($expAll.Replace($crlf,'<CRLF>'))" }
Assert-True $true 'CSV (All contractors): one line per stored Hours record incl. stored 0, sorted as the report (row position, day); worker with week total 0 dropped; TEST Employer facts (not in the report rows) dropped; historical EmployerName; RFC 4180 quoting only for ; " or line break; decimal comma; ISO 2026 KW53 across the year end'
Set-FxVar 'varWrExpContractorID' '20'
Set-FxVar 'colWrExpCsvRows' $csvRowsFx
Assert-Eval $csvTextFx ($bom + $hdr + $crlf + 'P-1000;"Ref; A";B-1;Beta;WKR-002;Bram Test;Welder;2027-01-03;2026;53;3' + $crlf) 'CSV (one contractor): only its lines; its worker with total 0 dropped'

Write-Output 'Test-Export: admission guard (parity + cases), busy flag, flow calls (PDF 5 args with TemplateName, CSV 4 args, results checked), Translations reads (3, global predicate vars, 500 guards), 23 keys, text fallback, language choice, PDF Content = sample-body.html, escaping, CSS footer, file names, CSV verified locally.'
Write-Output 'NOT verified locally: Studio import and binding (flow optional parameter record {text_4:...}, User().FullName, Text(...,"nl-NL") in Studio, UniChar), delegation of the Translations reads (Monitor), flow run and PDF rendering, real SharePoint data.'
