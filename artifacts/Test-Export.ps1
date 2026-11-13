# Week Report phase C (WEEKREPORT_PLAN.md par. 6.1-6.7; DECISIONS.md H24-H27, E2, E10): static and Power Fx interpreter checks of the
# Export button on scrWeekReport (cmpWrFooter.ExportEnabled / OnExport). Style of Test-WeekReport.ps1: Check-WeeklySource.ps1 is dot-sourced
# (syntax + templates), the real formula texts are read from the YAML and evaluated in the Power Fx interpreter with synthetic fixtures.
# The PDF Content built by the real formula is compared with templates/sample-body.html (same synthetic TEST data and texts).
# Proves source structure and local calculation only: NO Studio import, binding of the flow (optional parameter syntax), User().FullName,
# delegation of the Translations reads (Monitor), flow behaviour or functional result. ASCII-only, PowerShell 5.1.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
# MaxCallDepth: the interpreter default (20) is a local harness limit; the per-contractor HTML (ForAll > With > With > Concat > With > Substitute chain)
# nests deeper than the old single-file build. Studio import is the real check for this nesting (TP-EXPORT-02).
$xCfg = New-Object Microsoft.PowerFx.PowerFxConfig
$xCfg.MaxCallDepth = 60
$xEngine = New-Object Microsoft.PowerFx.RecalcEngine -ArgumentList $xCfg
$xOpt = New-Object Microsoft.PowerFx.ParserOptions
$xOpt.Culture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
$xOpt.AllowsSideEffects = $true
function Assert-True($cond, $label) { if (!$cond) { throw "FAIL $label" }; Write-Output "PASS $label" }
function Invoke-Fx([string]$fx) {
    $fx = $fx.Replace('[$-en-US]', '')  # format tag (Studio) stripped for the interpreter, as in Test-WeekReport
    try { $v = $xEngine.Eval($fx, $null, $xOpt) } catch { $chk = ''; try { $chk = (@($xEngine.Check($fx, $xOpt).Errors) | ForEach-Object { $_.ToString() }) -join ' | ' } catch { }; throw "FAIL evaluation error in: $($fx.Substring(0,[Math]::Min(300,$fx.Length))) :: $($_.Exception.InnerException.Message) $($_.Exception.Message) :: $chk" }
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
foreach ($part in '!Coalesce(varWrBusy,false)', '!Coalesce(varWrExporting,false)', 'varWrLoadState="Loaded"', 'IsEmpty(colWrLoadErrors)', '!IsBlank(varWrLoadedProject.ID)', '!IsBlank(varWrLoadedMonday)', 'varWrLoadedProjectID=varWrProjectID', 'varWrLoadedMonday=varWrMonday', 'If(Coalesce(varWrContractorID,0)=0,IsBlank(varWrContractorDisplay),CountIf(colWrGroups,ContractorID=varWrContractorID&&Display=varWrContractorDisplay)=1)', 'CountIf(colWrRows,Coalesce(varWrContractorID,0)=0||ContractorID=varWrContractorID)>0') {
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
Test-Guard 'varWrContractorID:0|||varWrContractorDisplay:"Beta (B-1)"' $false 'L6: contractor ID 0 but a remembered contractor display (not "All") blocks'
$blocked = $onExp.Substring($onExp.LastIndexOf('Skipped:CountIf(colWrExpResults,Status="NoHours")}),'))
Assert-True ($blocked.Contains('Set(varAdmMsgKind,"Error")') -and $blocked.Contains('T.admHeadBlocked.en') -and $blocked.Contains('T.wrMsgExportBlocked.en') -and $blocked -notmatch '\.Run\(') 'guard false: red "Blocked." message, no flow call'

# (2) Busy flag, no mutations, texts ------------------------------------------------------------------------------------------
Assert-True ($onExpN.StartsWith("=If($gN,Set(varWrExporting,true);Set(varWrBusy,true);")) 'export sets varWrExporting and varWrBusy first (spinner in cmpTitleBar; navigation, Refresh and week change blocked)'
Assert-True ($onExpN.Contains(');Set(varWrBusy,false);Set(varWrExporting,false);Trace("DIAG|Export|End",') -and ([regex]::Matches($onExpN, 'Set\(varWrExporting,false\)')).Count -eq 1 -and $onExpN.IndexOf('Set(varWrBusy,false);Set(varWrExporting,false);') -gt $onExpN.LastIndexOf("'SiteManagment-Exportfile'.Run(")) 'busy flags reset once, unconditionally after the message step (not inside any If), before the end trace'
Assert-True ((P 'cmpWrTitle.Busy') -eq '=Coalesce(varWrBusy,false) || varWrLoadState="Loading"') 'title spinner follows varWrBusy (also during export)'
foreach ($k in 'cmpWrFooter.HomeEnabled', 'cmpWrFooter.RefreshEnabled', 'dpWrWeek.DisplayMode', 'btnWrPrev.DisplayMode', 'btnWrNext.DisplayMode', 'cmpWrProject.Enabled', 'cmpWrContractor.Enabled') { Assert-True ((P $k).Contains('!Coalesce(varWrBusy,false)')) "$k blocked while busy (export sets varWrBusy)" }
Assert-True ((P 'btnWrLoad.OnSelect').StartsWith('=If(Coalesce(varWrBusy,false),')) 'loader refuses while busy (no reload during export)'
$bare = Remove-FxStrings $screenText
Assert-True ($bare -notmatch '\b(Patch|Remove|RemoveIf|Update|UpdateIf|SubmitForm|Defaults|Launch|Download|Notify|Choices)\(') 'no Patch/Remove/Update/SubmitForm/Launch/Download/Notify/Choices on scrWeekReport (the app does not open the file, H26)'
$colTargets = @([regex]::Matches((Remove-FxStrings $onExp), '\b(Collect|ClearCollect|Clear)\(\s*([^,\)]+)') | ForEach-Object { $_.Groups[2].Value.Trim() } | Sort-Object -Unique)
Assert-True (@($colTargets | Where-Object { $_ -notmatch '^col[A-Z]\w*$' }).Count -eq 0 -and $colTargets -notcontains 'Translations') "OnExport collection functions only target local collections ($($colTargets -join ', '))"
$tKeys = @([regex]::Matches($formulas, '(?m)^\s*(\w+):\s*\{en:') | ForEach-Object { $_.Groups[1].Value })
$used = @([regex]::Matches($onExp + $guard, '\bT\.(\w+)\.en\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True (@($used | Where-Object { $tKeys -notcontains $_ }).Count -eq 0 -and $used.Count -ge 18) "all $($used.Count) T keys used by the export exist in App.Formulas T (English UI texts)"
Assert-Eval 'T.wrErrExportPdf.en' '{0}: PDF not confirmed ({1}). Check Exports/{2}.' 'N2: flow failure says "not confirmed" with a hint to check Exports/<ProjectNumber>'
Assert-Eval 'T.wrErrExportCsv.en' '{0}: PDF saved, CSV not confirmed ({1}). Check Exports/{2}.' 'N2: CSV failure says the PDF was saved and the CSV is not confirmed'
Assert-Eval 'T.wrMsgExportedN.en' 'Exported {0} of {1} contractors to Exports/{2}.' 'summary "Exported x of y contractors" (UI term Contractor)'
Assert-Eval 'T.wrMsgExportNoHours.en' '{0}: no hours, skipped.' 'N4: contractor without hours is skipped with its code'
$trace = [regex]::Match($onExp, 'Trace\("DIAG\|Export\|End",TraceSeverity\.Information,\{([^}]*)\}\)')
Assert-True ($trace.Success -and $trace.Groups[1].Value.Contains('Files:varWrExpFiles') -and $trace.Groups[1].Value.Contains('ElapsedMs:DateDiff(varWrExpT0,Now(),TimeUnit.Milliseconds)') -and $trace.Groups[1].Value.Contains('Errors:CountRows(colWrExportErrors)') -and $trace.Groups[1].Value -notmatch 'Name|User|Folder|Base|Message|Code') 'trace DIAG|Export|End with Files, ElapsedMs, Errors and no names or codes'

# (3) Flow calls (6.5): 2 calls inside one ForAll over the built files; PDF 5 args with TemplateName, CSV 4 args, CSV only after PDF OK
$runs = @([regex]::Matches($onExp, "'SiteManagment-Exportfile'\.Run\("))
Assert-True ($runs.Count -eq 2 -and ([regex]::Matches($bare, '\.Run\(')).Count -eq 2) "exactly 2 calls of 'SiteManagment-Exportfile'.Run (PDF + CSV) on the screen"
$pdfArgs = Split-FxArgs (Get-Balanced $onExp ($runs[0].Index + $runs[0].Length - 1))
$csvArgs = Split-FxArgs (Get-Balanced $onExp ($runs[1].Index + $runs[1].Length - 1))
Assert-True ($pdfArgs.Count -eq 5 -and ($pdfArgs | ForEach-Object { $_.Trim() }) -join '|' -ceq 'varWrExpFolder|b.Base|"pdf"|b.Html|{text_4:"weekreport.html"}') 'PDF call: Run(Folder, FileName, "pdf", Content, {text_4: "weekreport.html"}) per contractor'
Assert-True ($csvArgs.Count -eq 4 -and ($csvArgs | ForEach-Object { $_.Trim() }) -join '|' -ceq 'varWrExpFolder|b.Base|"csv"|b.Csv') 'CSV call: Run(Folder, FileName, "csv", Content) (same base name, no TemplateName)'
Assert-True ($onExpN.Contains("If(IsEmpty(colWrExportErrors),ClearCollect(colWrExpResults,") -and $onExpN.Contains("ForAll(colWrExpBuiltAsb,With({pdf:IfError(With({rr:'SiteManagment-Exportfile'.Run(") -and $onExpN.Contains("With({csv:If(pdf.Ok,IfError(With({rr:'SiteManagment-Exportfile'.Run(")) 'one PDF + CSV pair per built contractor file; flow calls only without collected errors; each call in IfError; CSV only after PDF OK'
$flowResFx = '{Ok:Lower(Trim(rr.status & ""))="ok" && !IsBlank(Trim(rr.fileurl & "")),Msg:Trim(rr.message & "")}'
Assert-True (([regex]::Matches($onExp, [regex]::Escape($flowResFx))).Count -eq 2 -and ([regex]::Matches($onExp, [regex]::Escape('{Ok:false,Msg:Coalesce(FirstError.Message,"?")}'))).Count -eq 2) 'both results: OK only with status ok (case-insensitive) and a non-empty fileurl; an error gives Ok false with the error text'
foreach ($c in @(@('{status:"OK",fileurl:"https://x/f",message:""}', $true, 'status OK + url'), @('{status:"ok",fileurl:"u",message:""}', $true, 'status lower-case ok'), @('{status:"Error",fileurl:"u",message:"m"}', $false, 'status Error'), @('{status:"OK",fileurl:"  ",message:""}', $false, 'status OK but empty fileurl (not confirmed)'), @('If(false,{status:"",fileurl:"",message:""})', $false, 'blank result'))) {
    Assert-Eval "With({rr:$($c[0])},$flowResFx).Ok" $c[1] "flow result OK = $($c[1]) for $($c[2])"
}
$iPdf = $onExpN.IndexOf("'SiteManagment-Exportfile'.Run(")
Assert-True ($onExpN.IndexOf('ClearCollect(colWrExpBuilt,') -lt $iPdf -and $onExpN.IndexOf('ForAll(TranslationsAstr,') -lt $iPdf) 'order: Translations read and all local building first, then the flow calls'
Assert-True ($onExp -notmatch '"ALL"' -and $onExp -notmatch '_ALL') 'H26: no _ALL file any more (one file pair per contractor)'

# (4) Translations: one read of all languages with a 500 guard; no fallback language ----------------------------------------------
Assert-True ($onExpN.Contains('IfError(CountRows(ClearCollect(colWrDocAll,ForAll(TranslationsAstr,{Lang:Trim(tr.Language&""),Key:Trim(tr.Title&""),Txt:TrimEnds(tr.Text&"")})))>=0,Collect(colWrExportErrors,')) 'one Translations read (all languages, about 138 rows) in IfError; no remote call inside a ForAll body'
Assert-True ($onExpN.Contains('If(CountRows(colWrDocAll)>=500,Collect(colWrExportErrors,')) '500 guard on the Translations read (500+ = error, no export)'
Assert-True ($onExpN.Contains('IfError(Refresh(Translations),Collect(colWrExportErrors,') -and ([regex]::Matches((Remove-FxStrings $onExp), '\bTranslations\b')).Count -eq 2 -and ([regex]::Matches((Remove-FxStrings ($screenText.Replace($onExp, ''))), '\bTranslations\b')).Count -eq 0) 'Translations referenced only by Refresh + the one read in OnExport'
Assert-True (([regex]::Matches($onExp, '"English"')).Count -eq 1 -and $onExp.Contains('Switch(pg.L,"Dutch","nl","English","en",')) 'H27: no English fallback anywhere (the only "English" is the lang-code mapping)'
Assert-True ($onExpN.Contains('Set(varWrDocLang1,Trim(ReportPrimaryLanguage&""))') -and $formulas.Contains('ReportPrimaryLanguage = "Dutch";') -and $onExpN.Contains('If(IsBlank(varWrDocLang1),Collect(colWrExportErrors,')) 'H27: page 1 = ReportPrimaryLanguage (one setting, default Dutch; AppSettings after MS-033); empty = blocked'
Assert-True ($loader -notmatch 'ReportLanguage' -and $loader -notmatch 'w\.Language' -and $loaderN.Contains('Language:If(Trim(emp.Language.Value&"")="Nederlands","Dutch",Trim(emp.Language.Value&""))') -and $loaderN.Contains('Country:Trim(p.Country.Value&"")')) 'H27: worker-majority language removed from the loader; Employers.Language and Projects.Country in the existing master projections (no extra read)'

# (5) Keys (23) from templates/translations-weekreport.csv -------------------------------------------------------------------
$csvLines = [IO.File]::ReadAllLines((Join-Path $tplDir 'translations-weekreport.csv'), [Text.Encoding]::UTF8) | Select-Object -Skip 1 | Where-Object { $_.Trim() }
$tr = @($csvLines | ForEach-Object { $p = $_.Split(';'); [pscustomobject]@{ Key = $p[0]; Lang = $p[1]; Text = ($p[2..($p.Count - 1)] -join ';') } })
$keys = @($tr | ForEach-Object Key | Select-Object -Unique)
Assert-True ($keys.Count -eq 23) "translations-weekreport.csv: 23 doc.* keys"
$unused = @('doc.contractorAll', 'doc.total')  # review 13-11: no _ALL file and no grand total any more (H26); not required, so an empty value never blocks
foreach ($k in $keys) { if ($unused -contains $k) { Assert-True (-not $onExp.Contains('"' + $k + '"')) "key $k no longer required in OnExport" } else { Assert-True ($onExp.Contains('"' + $k + '"')) "key $k used in OnExport" } }
foreach ($k in $keys) { foreach ($lg in 'Dutch', 'English', 'Polish', 'Romanian', 'German', 'Ukrainian') { if (-not ($tr | Where-Object { $_.Key -eq $k -and $_.Lang -eq $lg -and $_.Text.Trim() })) { throw "FAIL $k missing for $lg in the CSV" } } }
Assert-True $true 'every key has a text in all six languages in the CSV (a delivered language never blocks)'

# (6) Interpreter: jobs per contractor, document texts, status ---------------------------------------------------------------
function Get-DocAll([string[]]$langs) { return 'Table(' + ((@($tr | Where-Object { $langs -contains $_.Lang }) | ForEach-Object { '{Lang:' + (ConvertTo-FxString $_.Lang) + ',Key:' + (ConvertTo-FxString $_.Key) + ',Txt:' + (ConvertTo-FxString $_.Text) + '}' }) -join ',') + ')' }
$jobsFx = Get-CallArg $onExp 'ClearCollect(colWrExpJobs,' 1
$jobs2Fx = Get-CallArg $onExp 'ClearCollect(colWrExpJobs2,' 1
$textsFx = Get-CallArg $onExp 'ClearCollect(colWrDocTexts,' 1
$langsFx = Get-CallArg $onExp '; Collect(colWrDocLangs,' 1
$linesFx = Get-CallArg $onExp 'ClearCollect(colWrExpLines,' 1
$csvRowsFx = Get-CallArg $onExp 'ClearCollect(colWrExpCsvRows,' 1
$builtFx = Get-CallArg $onExp 'ClearCollect(colWrExpBuilt,' 1
$resultsFx = Get-CallArg $onExp 'ClearCollect(colWrExpResults,' 1
$isoYFx = Get-CallArg $onExp 'Set(varWrExpIsoYear,' 1
$isoWFx = Get-CallArg $onExp 'Set(varWrExpIsoWeek,' 1
$labelFx = Get-CallArg $onExp 'Set(varWrExpWeekLabel,' 1
$folderFx = Get-CallArg $onExp 'Set(varWrExpFolder,' 1
$tArgs = Split-FxArgs (Get-Balanced $textsFx $textsFx.IndexOf('('))
Assert-True ($textsFx.StartsWith('Ungroup(ForAll(Distinct(colWrDocLangs,L) As lg,{LangTexts:') -and $tArgs.Count -eq 2 -and $tArgs[1].Trim() -ceq 'LangTexts') 'doc texts = Ungroup(ForAll(languages used, {LangTexts: ForAll(21 required keys)}), LangTexts) (column as identifier)'
$textsInnerFx = $tArgs[0].Trim()
function Set-DocTexts([string]$langsTable) {
    # Ungroup is not supported by the local interpreter (Studio supports it): evaluate the inner ForAll and flatten here (max 3 languages)
    Set-FxVar 'colWrDocLangs' $langsTable
    Set-FxValue 'wrL' (Invoke-Fx $textsInnerFx)
    Set-FxValue 'colWrDocTexts' (Invoke-Fx 'With({a:Index(wrL,1).LangTexts,b:If(CountRows(wrL)>=2,Index(wrL,2).LangTexts,Filter(Index(wrL,1).LangTexts,false)),c:If(CountRows(wrL)>=3,Index(wrL,3).LangTexts,Filter(Index(wrL,1).LangTexts,false))},ForAll(Sequence(CountRows(a)+CountRows(b)+CountRows(c)) As i,If(i.Value<=CountRows(a),Index(a,i.Value),i.Value<=CountRows(a)+CountRows(b),Index(b,i.Value-CountRows(a)),Index(c,i.Value-CountRows(a)-CountRows(b)))))')
}
function Set-Week([string]$mondayFx) { Set-FxVar 'varWrLoadedMonday' $mondayFx; Set-FxVar 'varWrExpIsoYear' $isoYFx; Set-FxVar 'varWrExpIsoWeek' $isoWFx; Set-FxVar 'varWrExpWeekLabel' $labelFx }
Set-Week 'Date(2026,11,9)'
Set-FxVar 'varWrLoadedProject' '{ID:1,Title:"Test project",Country:"Netherlands",Number:"TEST-000",Reference:"Test project reference",Display:"x"}'
Set-FxVar 'varWrLoadedIsTest' 'true'; Set-FxVar 'varWrExpFolder' $folderFx; Set-FxVar 'varWrDocLang1' '"Dutch"'
Set-FxVar 'colWrGroups' 'Table({ContractorID:902,ContractorName:"TEST Contractor B",EmployerCode:"EMP-902",SortName:"test contractor b|0000000902",WeekTotal:16},{ContractorID:901,ContractorName:"TEST Employer",EmployerCode:"EMP-901",SortName:"test employer|0000000901",WeekTotal:82},{ContractorID:903,ContractorName:"TEST Zero",EmployerCode:"EMP-903",SortName:"test zero|0000000903",WeekTotal:0},{ContractorID:904,ContractorName:"TEST NoLang",EmployerCode:"EMP-904",SortName:"test nolang|0000000904",WeekTotal:5},{ContractorID:905,ContractorName:"TEST Polish",EmployerCode:"EMP-905",SortName:"test polish|0000000905",WeekTotal:7})'
Set-FxVar 'colWrEmployers' 'Table({ID:901,Language:"English"},{ID:902,Language:"Dutch"},{ID:903,Language:"German"},{ID:904,Language:""},{ID:905,Language:"Polish"})'
Set-FxVar 'varWrExpContractorID' '0'
Set-FxVar 'colWrExpJobs' $jobsFx
Assert-Eval 'Concat(colWrExpJobs,Code & "=" & Base & "|" & Lang2 & "|" & Text(HoursTotal),", ")' 'EMP-902=TEST_WeekReport_TEST-000_2026KW46_EMP-902|Dutch|16, EMP-901=TEST_WeekReport_TEST-000_2026KW46_EMP-901|English|82, EMP-904=TEST_WeekReport_TEST-000_2026KW46_EMP-904||5, EMP-905=TEST_WeekReport_TEST-000_2026KW46_EMP-905|Polish|7, EMP-903=TEST_WeekReport_TEST-000_2026KW46_EMP-903|German|0' 'H26: All contractors = one job per contractor (sorted as the report), base name _<EmployerCode>, page-2 language = Employers.Language only (empty stays empty, no fallback)'
Set-FxVar 'varWrExpContractorID' '905'
Assert-Eval "Concat($jobsFx,Code,`",`")" 'EMP-905' 'one contractor chosen = one job'
Set-FxVar 'varWrExpContractorID' '0'
Set-FxVar 'colWrDocLangs' '{L:varWrDocLang1}'
Assert-Eval "Concat(ForAll($langsFx As x,x.L),Value,`",`")" 'English,Polish' 'languages read: page 1 language + every other page-2 language of contractors with hours and a language'
# Translations without the Polish doc.colName and with an empty Dutch doc.week -> both missing (no fallback to English or to the key)
Set-FxVar 'colWrDocAll' ('Filter(' + (Get-DocAll @('Dutch', 'English', 'Polish')) + ',!(Lang="Polish" && Key="doc.colName"))')
Set-FxVar 'colWrDocAll' 'ForAll(colWrDocAll As d,{Lang:d.Lang,Key:d.Key,Txt:If(d.Lang="Dutch" && d.Key="doc.week","",d.Txt)})'
Set-DocTexts 'Table({L:"Dutch"},{L:"English"},{L:"Polish"})'
Assert-Eval 'CountRows(colWrDocTexts)' 63 'doc texts: 21 required keys x 3 languages'
Assert-Eval 'Concat(Filter(colWrDocTexts,Missing),Lang & ":" & Key & "=" & Txt,",")' 'Dutch:doc.week=,Polish:doc.colName=' 'N5: a key that is missing or empty is flagged Missing with an empty text (no key name, no other language)'
Set-FxVar 'colWrExpJobs2' $jobs2Fx
Assert-Eval 'Concat(colWrExpJobs2,Code & "=" & Status,", ")' 'EMP-902=MissingTexts, EMP-901=MissingTexts, EMP-904=NoLanguage, EMP-905=MissingTexts, EMP-903=NoHours' 'status: 0 hours -> NoHours (before any other check); no Employers.Language -> NoLanguage; missing text on page 1 blocks every contractor'
Assert-Eval 'LookUp(colWrExpJobs2,Code="EMP-905").MissingKeys' 'Dutch: doc.week, Polish: doc.colName' 'N5: the message lists the missing keys per language'
Set-FxVar 'colWrDocAll' ('Filter(' + (Get-DocAll @('Dutch', 'English', 'Polish')) + ',!(Lang="Dutch" && Key in ["doc.title","doc.projectName","doc.country","doc.projectNumber","doc.projectReference"]))')
Set-DocTexts 'Table({L:"Dutch"},{L:"English"},{L:"Polish"})'
Set-FxVar 'colWrExpJobs2' $jobs2Fx
Assert-Eval 'LookUp(colWrExpJobs2,Code="EMP-901").MissingKeys' 'Dutch: doc.title, Dutch: doc.projectName, Dutch: doc.country (+2 more)' 'review 6: missing keys listed max 3 + "(+n more)" (one-line message bar)'
Set-FxVar 'colWrDocAll' ('Filter(' + (Get-DocAll @('Dutch', 'English', 'Polish')) + ',!(Lang="Polish" && Key="doc.colName"))')
Set-DocTexts 'Table({L:"Dutch"},{L:"English"},{L:"Polish"})'
Set-FxVar 'colWrExpJobs2' $jobs2Fx
Assert-Eval 'Concat(colWrExpJobs2,Code & "=" & Status,", ")' 'EMP-902=Ready, EMP-901=Ready, EMP-904=NoLanguage, EMP-905=MissingTexts, EMP-903=NoHours' 'missing Polish text blocks only the Polish contractor; Dutch = Dutch -> needs only page-1 texts'
Set-FxVar 'colWrExpResults' $resultsFx
Assert-Eval 'Concat(colWrExpResults,Msg," ")' 'EMP-904: no report language (column Report Language in the Employers list). Not exported. EMP-905: texts missing in Translations (Polish: doc.colName). Not exported. EMP-903: no hours, skipped.' 'messages for blocked and skipped contractors (red text for blocked, skipped note for 0 hours)'
Assert-True ($onExpN.Contains('If(IsEmpty(colWrExportErrors)&&(IsEmpty(colWrExpJobs)||CountRows(Distinct(colWrExpJobs,Base))<>CountRows(colWrExpJobs)),Collect(colWrExportErrors,')) 'two contractors with the same file name after "-" replacement = build error, zero flow calls'

# (7) Interpreter: PDF Content per contractor = templates/sample-body.html --------------------------------------------------------
Set-FxVar 'varWrExpNow' 'DateTime(2026,11,12,10,0,0)'; Set-FxVar 'varWrExpUser' '"Test User"'
$nb = 'If(false,0)'
function Get-Line($type, $sk, $cid, $name, $code, $trade, $zebra, $d, $tot) { $dd = @(1..7 | ForEach-Object { "D$($_):$($d[$_-1])" }) -join ','; return "{LineType:`"$type`",SortKey:$sk,ContractorID:$cid,Name:`"$name`",Code:`"$code`",Trade:`"$trade`",Zebra:$zebra,$dd,WeekTotal:$tot}" }
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
Set-FxVar 'colWrRows' 'Table({WorkerID:1,ContractorID:901,WorkerCode:"WKR-001",WorkerName:"Test Worker A",EmployerCode:"EMP-901",WeekTotal:38},{WorkerID:2,ContractorID:901,WorkerCode:"WKR-002",WorkerName:"Test Worker B",EmployerCode:"EMP-901",WeekTotal:44},{WorkerID:3,ContractorID:902,WorkerCode:"WKR-003",WorkerName:"Test Worker C",EmployerCode:"EMP-902",WeekTotal:16})'
Set-FxVar 'colWrExportFacts' 'Table({HourID:1,WorkerID:1,ContractorID:901,EmployerName:"TEST Employer",DayIndex:0,WorkDay:Date(2026,11,9),HourValue:8,Trade:"Fitter",Pos:1},{HourID:2,WorkerID:2,ContractorID:901,EmployerName:"TEST Employer",DayIndex:0,WorkDay:Date(2026,11,9),HourValue:10,Trade:"Welder",Pos:2},{HourID:3,WorkerID:3,ContractorID:902,EmployerName:"TEST Contractor B",DayIndex:0,WorkDay:Date(2026,11,9),HourValue:8,Trade:"Fitter",Pos:3})'
Set-FxVar 'colWrGroups' 'Table({ContractorID:901,ContractorName:"TEST Employer",EmployerCode:"EMP-901",SortName:"a",WeekTotal:82},{ContractorID:902,ContractorName:"TEST Contractor B",EmployerCode:"EMP-902",SortName:"b",WeekTotal:16})'
Set-FxVar 'colWrEmployers' 'Table({ID:901,Language:"English"},{ID:902,Language:"Dutch"})'
Set-FxVar 'colWrExpJobs' $jobsFx
Set-FxVar 'colWrDocAll' (Get-DocAll @('Dutch', 'English'))
Set-DocTexts 'Table({L:"Dutch"},{L:"English"})'
Set-FxVar 'colWrExpJobs2' $jobs2Fx
Set-FxVar 'colWrExpLines' $linesFx
Assert-Eval 'Concat(colWrExpLines,Text(ContractorID) & LineType,",")' '901Header,901Row,901Row,901Subtotal,902Header,902Row,902Subtotal' 'H26: PDF lines only of contractors that are exported; no Grand total line'
Set-FxVar 'colWrExpCsvRows' $csvRowsFx
Set-FxVar 'colWrExpBuilt' $builtFx
Assert-Eval 'Concat(colWrExpBuilt,Code & ":" & Text(Pages) & ":" & If(Ok,"ok","BAD"),",")' 'EMP-901:2:ok,EMP-902:1:ok' 'one file pair per contractor; page 2 only when the contractor language differs from page 1 (Dutch contractor = 1 page); integrity Ok'
$html = (Invoke-Fx 'LookUp(colWrExpBuilt,Code="EMP-901").Html').Value
$sample = ([IO.File]::ReadAllText((Join-Path $tplDir 'sample-body.html'))).Replace("`r`n", "`n")
$sample = $sample.Substring($sample.IndexOf("`n") + 1)  # drop the leading comment line
if ($html.TrimEnd() -cne $sample.TrimEnd()) {
    $a = $html.TrimEnd().Split("`n"); $b = $sample.TrimEnd().Split("`n")
    for ($i = 0; $i -lt [Math]::Max($a.Count, $b.Count); $i++) { if ($a[$i] -cne $b[$i]) { throw "FAIL PDF Content differs from sample-body.html at line $($i+2):`n  app:    $($a[$i])`n  sample: $($b[$i])" } }
}
Assert-True $true 'PDF Content (EMP-901, nl + en) is byte-identical to templates/sample-body.html: named page + @page footer + {{HEADER}} + doc-title + meta (contractor "name &middot; code") + colgroup + day headers + group/alt/subtotal rows, we on Sat/Sun, &ndash; for 0/empty'
Assert-True (([regex]::Matches($html, '\{\{HEADER\}\}')).Count -eq 2 -and $html -notmatch '\{\{BODY\}\}' -and $html -notmatch '<script|<img|<link|url\(' -and $html -notmatch 'TEST Contractor B|EMP-902|class="total"') 'H26 privacy: the EMP-901 file holds no data of another contractor and no grand total'
$html1 = (Invoke-Fx 'LookUp(colWrExpBuilt,Code="EMP-902").Html').Value
Assert-True (([regex]::Matches($html1, '<section ')).Count -eq 1 -and $html1.Contains('<tr><th>Aannemer</th><td>TEST Contractor B &middot; EMP-902</td></tr>') -and $html1 -notmatch 'TEST Employer|EMP-901|class="total"' -and ([regex]::Matches($html1, '<tr class="subtotal">')).Count -eq 1) 'contractor language Dutch = page-1 language: 1 page, only its own group + subtotal'
# escaping: data and texts HTML-escaped, "{" as &#123;; footer as a CSS string
Set-FxVar 'colWrLines' ('Table(' + (Get-Line 'Header' 100000 901 'A&B <x> "q" {{HEADER}}' 'E{1}' '' 'false' @(0, 0, 0, 0, 0, 0, 0) 0).Replace('"A&B <x> "q" {{HEADER}}"', '"A&B <x> ""q"" {{HEADER}}"') + ',' + (Get-Line 'Row' 100001 901 'Test <W>' 'WKR-1' 'Fit;ter' 'false' @(7.5, 0, $nb, 2.25, 10, $nb, $nb) 19.75) + ',' + (Get-Line 'Subtotal' 199999 901 'Subtotal' 'E{1}' '' 'false' @(7.5, 0, 0, 2.25, 10, 0, 0) 19.75) + ')')
Set-FxVar 'colWrExpLines' $linesFx
Set-FxVar 'varWrExpUser' "`"Q `"`"B`"`" \ <x> {y}`" & Char(10) & `"z`""
Set-FxVar 'varWrLoadedProject' '{ID:1,Title:"P & <Q>",Country:"",Number:"P{1}",Reference:"R\"" ",Display:"x"}'.Replace('R\"" "', 'R"" "')
Set-FxVar 'colWrDocAll' ((Get-DocAll @('Dutch', 'English')).Replace('"Pagina {page} van {pages}"', '"{page}/{pages}"'))
Set-DocTexts 'Table({L:"Dutch"},{L:"English"})'
Set-FxVar 'colWrExpBuilt' $builtFx
$h2 = (Invoke-Fx 'LookUp(colWrExpBuilt,Code="EMP-901").Html').Value
Assert-True ($h2.Contains('<tr class="group"><td colspan="10">A&amp;B &lt;x&gt; &quot;q&quot; &#123;&#123;HEADER}} &middot; E&#123;1}</td></tr>') -and ([regex]::Matches($h2, '\{\{HEADER\}\}')).Count -eq 2) 'HTML escaping of data: & < > " and { as &#123; (a name can never form a token)'
Assert-True ($h2.Contains('<td>Test &lt;W&gt;</td><td>Fit;ter</td><td class="num">7,5</td><td class="num">&ndash;</td><td class="num">&ndash;</td><td class="num">2,25</td><td class="num">10</td><td class="num we">&ndash;</td><td class="num we">&ndash;</td><td class="num total-col">19,75</td>') -and $h2.Contains('<td>P &amp; &lt;Q&gt;</td>') -and $h2.Contains('<td>P&#123;1}</td>')) 'N3: numbers with decimal comma, whole hours without separator, 0 and empty as &ndash;; project fields escaped'
Assert-True ($h2.Contains('@bottom-left { content: "Gegenereerd 12-11-2026 10:00 door Q \"B\" \\ \3C x> \7B y} z"; }')) 'footer CSS string: {date}/{user} filled, \ -> \\, " -> \", < -> \3C, { -> \7B, line break removed'
Assert-True ($h2.Contains('@bottom-right { content: counter(page) "/" counter(pages); }')) 'page footer "{page}/{pages}" -> counter(page) "/" counter(pages) (empty leading/trailing strings dropped)'

# (8) Interpreter: file names and folder (6.4, H26) ---------------------------------------------------------------------------------
Set-FxVar 'varWrLoadedProject' '{ID:1,Number:"TEST-000"}'; Set-FxVar 'varWrLoadedIsTest' 'true'
Set-FxVar 'varWrExpFolder' $folderFx
Assert-Eval 'varWrExpFolder' 'TEST-000' 'folder = Project Number'
Set-Week 'Date(2026,12,28)'
Set-FxVar 'varWrLoadedProject' '{ID:1,Number:" P/1:2 "}'; Set-FxVar 'varWrLoadedIsTest' 'false'; Set-FxVar 'varWrExpContractorID' '10'
Set-FxVar 'colWrGroups' 'Table({ContractorID:10,ContractorName:"X",SortName:"x",WeekTotal:1,EmployerCode:"E*1?""<>|#%\x"})'
Set-FxVar 'varWrExpFolder' $folderFx
Assert-Eval "First($jobsFx).Base" 'WeekReport_P-1-2_2026KW53_E-1--------x' 'N3: real project, ISO week 53: no TEST_ prefix, EmployerCode suffix, \ / : * ? " < > | # % replaced by "-"'
Set-Week 'Date(2027,1,4)'
Assert-Eval "First($jobsFx).Base" 'WeekReport_P-1-2_2027KW01_E-1--------x' 'ISO week 2027 KW01 (two digits)'
Assert-True ($onExpN.Contains('If(IsBlank(varWrExpFolder),Collect(colWrExportErrors,')) 'empty Project Number blocks the export (no flow call)'
Assert-True ($loaderN.Contains('Set(varWrLoadedIsTest,varWrPendIsTest)') -and $loaderN.Contains('Set(varWrPendIsTest,Left(Trim(varWrPendProject.Number&""),5)="TEST-")')) 'TEST_ prefix follows the loaded project (Project Number starts with TEST-)'

# (9) Interpreter: CSV per contractor (6.1) ----------------------------------------------------------------------------------------
Assert-True ($builtFx.Contains('csv:UniChar(65279) & "ProjectNumber;ProjectReference;EmployerCode;EmployerName;WorkerID;WorkerName;Trade;WorkDate;ISOYear;ISOWeek;Hours" & Char(13) & Char(10) & Concat(rows,Line & Char(13) & Char(10))') -and $builtFx.Contains('rows:Filter(colWrExpCsvRows,ContractorID=j.ContractorID)')) 'CSV per contractor: UTF-8 BOM via UniChar(65279), exact header, CRLF, only that contractor''s lines'
Assert-True ($csvRowsFx.Contains('"nl-NL"') -and $csvRowsFx.Contains('Text(f.WorkDay,"yyyy-mm-dd")') -and $csvRowsFx.Contains('Text(varWrExpIsoWeek,"00")') -and $csvRowsFx -notmatch 'Choices\(|LookUp\((Hours|Workers|Employers)') 'CSV fields: decimal comma (nl-NL), yyyy-mm-dd, ISOWeek two digits; local data only'
Assert-True ($loaderN.Contains('ClearCollect(colWrPendExportFacts,ForAll(colWrPendFactsAsf,') -and $loaderN.Contains('ClearCollect(colWrExportFacts,colWrPendExportFacts)') -and $loaderN.IndexOf('ClearCollect(colWrExportFacts,') -gt $loaderN.IndexOf('If(IsEmpty(colWrLoadErrors),ClearCollect(colWrRows,colWrPendRowsShown);')) 'hour facts per Hours record kept from staging, committed with the report (no extra Hours read at export)'
Set-Week 'Date(2026,12,28)'
Set-FxVar 'varWrLoadedProject' '{ID:1,Title:"T",Country:"",Number:"P-1000",Reference:"Ref; A"}'; Set-FxVar 'varWrExpFolder' $folderFx
Set-FxVar 'colWrRows' 'Table({WorkerID:1,ContractorID:10,WorkerCode:"WKR-001",WorkerName:"Anna \"Q\" Test",EmployerCode:"EMP-010",WeekTotal:15.5},{WorkerID:2,ContractorID:10,WorkerCode:"WKR-002",WorkerName:"Bram Test",EmployerCode:"EMP-010",WeekTotal:10},{WorkerID:3,ContractorID:20,WorkerCode:"WKR-003",WorkerName:"Cees Test",EmployerCode:"B-1",WeekTotal:0},{WorkerID:2,ContractorID:20,WorkerCode:"WKR-002",WorkerName:"Bram Test",EmployerCode:"B-1",WeekTotal:3})'.Replace('\"Q\"', '""Q""')
Set-FxVar 'colWrExportFacts' 'Table({HourID:11,WorkerID:1,ContractorID:10,EmployerName:"Alpha;Old",DayIndex:1,WorkDay:Date(2026,12,29),HourValue:7.5,Trade:"Welder",Pos:2},{HourID:10,WorkerID:1,ContractorID:10,EmployerName:"Alpha;Old",DayIndex:0,WorkDay:Date(2026,12,28),HourValue:8,Trade:"Welder",Pos:2},{HourID:12,WorkerID:2,ContractorID:10,EmployerName:"Alpha",DayIndex:2,WorkDay:Date(2026,12,30),HourValue:0,Trade:"Fitter",Pos:1},{HourID:13,WorkerID:2,ContractorID:10,EmployerName:"Alpha",DayIndex:3,WorkDay:Date(2026,12,31),HourValue:10,Trade:"Fitter",Pos:1},{HourID:14,WorkerID:3,ContractorID:20,EmployerName:"Beta",DayIndex:0,WorkDay:Date(2026,12,28),HourValue:0,Trade:"Fitter",Pos:3},{HourID:15,WorkerID:5,ContractorID:99,EmployerName:"TEST Employer",DayIndex:0,WorkDay:Date(2026,12,28),HourValue:8,Trade:"Fitter",Pos:0},{HourID:16,WorkerID:2,ContractorID:20,EmployerName:"Beta",DayIndex:6,WorkDay:Date(2027,1,3),HourValue:3,Trade:"Welder",Pos:4})'
Set-FxVar 'colWrLines' ('Table(' + ((Get-Line 'Header' 100000 10 'Alpha' 'EMP-010' '' 'false' @(0, 0, 0, 0, 0, 0, 0) 0), (Get-Line 'Row' 100001 10 'Bram Test' 'WKR-002' 'Fitter' 'false' @($nb, $nb, 0, 10, $nb, $nb, $nb) 10), (Get-Line 'Subtotal' 199999 10 'Subtotal' 'EMP-010' '' 'false' @(8, 7.5, 0, 10, 0, 0, 0) 25.5), (Get-Line 'Header' 200000 20 'Beta' 'B-1' '' 'false' @(0, 0, 0, 0, 0, 0, 0) 0), (Get-Line 'Row' 200001 20 'Bram Test' 'WKR-002' 'Welder' 'false' @($nb, $nb, $nb, $nb, $nb, $nb, 3) 3), (Get-Line 'Subtotal' 299999 20 'Subtotal' 'B-1' '' 'false' @(0, 0, 0, 0, 0, 0, 3) 3) -join ',') + ')')
Set-FxVar 'colWrGroups' 'Table({ContractorID:10,ContractorName:"Alpha",EmployerCode:"EMP-010",SortName:"a",WeekTotal:25.5},{ContractorID:20,ContractorName:"Beta",EmployerCode:"B-1",SortName:"b",WeekTotal:3})'
Set-FxVar 'colWrEmployers' 'Table({ID:10,Language:"Dutch"},{ID:20,Language:"Dutch"})'
Set-FxVar 'varWrExpContractorID' '0'
Set-FxVar 'colWrDocAll' (Get-DocAll @('Dutch'))
Set-DocTexts 'Table({L:"Dutch"})'
Set-FxVar 'colWrExpJobs' $jobsFx; Set-FxVar 'colWrExpJobs2' $jobs2Fx; Set-FxVar 'colWrExpLines' $linesFx; Set-FxVar 'colWrExpCsvRows' $csvRowsFx; Set-FxVar 'colWrExpBuilt' $builtFx
$crlf = "`r`n"; $bom = [string][char]0xFEFF
$hdr = 'ProjectNumber;ProjectReference;EmployerCode;EmployerName;WorkerID;WorkerName;Trade;WorkDate;ISOYear;ISOWeek;Hours'
$exp10 = $bom + $hdr + $crlf +
    'P-1000;"Ref; A";EMP-010;Alpha;WKR-002;Bram Test;Fitter;2026-12-30;2026;53;0' + $crlf +
    'P-1000;"Ref; A";EMP-010;Alpha;WKR-002;Bram Test;Fitter;2026-12-31;2026;53;10' + $crlf +
    'P-1000;"Ref; A";EMP-010;"Alpha;Old";WKR-001;"Anna ""Q"" Test";Welder;2026-12-28;2026;53;8' + $crlf +
    'P-1000;"Ref; A";EMP-010;"Alpha;Old";WKR-001;"Anna ""Q"" Test";Welder;2026-12-29;2026;53;7,5' + $crlf
$csv10 = (Invoke-Fx 'LookUp(colWrExpBuilt,ContractorID=10).Csv').Value
if ($csv10 -cne $exp10) { throw "FAIL CSV EMP-010:`n$($csv10.Replace($crlf,'<CRLF>'))`nexpected:`n$($exp10.Replace($crlf,'<CRLF>'))" }
Assert-True $true 'CSV EMP-010: one line per stored Hours record incl. stored 0, sorted as the report (row position, day); historical EmployerName; RFC 4180 quoting only for ; " or line break; decimal comma; ISO 2026 KW53 across the year end; no line of another contractor'
Assert-Eval 'LookUp(colWrExpBuilt,ContractorID=20).Csv' ($bom + $hdr + $crlf + 'P-1000;"Ref; A";B-1;Beta;WKR-002;Bram Test;Welder;2027-01-03;2026;53;3' + $crlf) 'CSV B-1: only its lines; its worker with week total 0 dropped; TEST Employer facts (not in the report rows) dropped'
Assert-Eval 'Concat(colWrExpBuilt,Base,",")' 'WeekReport_P-1000_2026KW53_EMP-010,WeekReport_P-1000_2026KW53_B-1' 'All contractors: N file pairs with _<EmployerCode>'

# (10) Every local build step in IfError; integrity check before the first flow call ------------------------------------------------
$errC = 'Collect(colWrExportErrors,{Message:If(LangNl&&!IsBlank(T.wrErrExportBuild.nl),T.wrErrExportBuild.nl,T.wrErrExportBuild.en)&""&FirstError.Message});false)'
foreach ($s in 'IfError(CountRows(ClearCollect(colWrExpJobs,', 'IfError(CountRows(ClearCollect(colWrDocTexts,Ungroup(', 'IfError(CountRows(ClearCollect(colWrExpJobs2,', 'IfError(CountRows(ClearCollect(colWrExpLines,', 'IfError(CountRows(ClearCollect(colWrExpCsvRows,', 'IfError(CountRows(ClearCollect(colWrExpBuilt,') {
    $i = $onExpN.IndexOf($s); Assert-True ($i -ge 0 -and $onExpN.IndexOf($errC, $i) -gt $i -and $i -lt $iPdf) "build step in IfError with Collect(colWrExportErrors, build error) before the first flow call: $s"
}
Assert-True ($onExpN.Contains('If(IsEmpty(colWrExportErrors)&&IfError(CountRows(colWrExpBuilt)<>CountIf(colWrExpJobs2,Status="Ready")||CountIf(colWrExpBuilt,!Ok)>0,true),Collect(colWrExportErrors,') -and $onExpN.IndexOf('CountIf(colWrExpBuilt,!Ok)>0') -lt $iPdf) 'integrity check before the first flow call: one built file per Ready contractor and every file Ok; an error inside the check counts as a mismatch'
$okFx = $builtFx.Substring($builtFx.IndexOf(',Ok:') + 4); $okFx = $okFx.Substring(0, $okFx.LastIndexOf('})'))
foreach ($c in @(
        @('lns:FirstN(lns,2)', 'fewer than 3 table lines (header, row, subtotal)'),
        @('rows:Filter(rows,false)', 'no CSV line for a contractor with hours'),
        @('rows:FirstN(rows,CountRows(rows)-1)', 'review 1: one CSV line fewer than the expected Hours records of this contractor'),
        @('colWrLines:Table(First(colWrLines),First(colWrLines),First(colWrLines),First(colWrLines))', 'review 1: PDF table has fewer lines than the report lines of this contractor'),
        @('csv:Left(csv,Len(csv)-1)', 'CSV text shorter than BOM + header + rows'),
        @('html:Substitute(html,"{{HEADER}}","",1)', 'one {{HEADER}} missing'),
        @('html:Substitute(html,"</section>","",1)', 'one </section> missing'))) {
    Assert-Eval "With({j:LookUp(colWrExpJobs2,ContractorID=10)},With({pages:Table({Page:1,L:`"Dutch`"}),rows:Filter(colWrExpCsvRows,ContractorID=10),lns:Filter(colWrExpLines,ContractorID=10)},With({csv:LookUp(colWrExpBuilt,ContractorID=10).Csv,html:LookUp(colWrExpBuilt,ContractorID=10).Html},With({$($c[0])},$okFx))))" $false "integrity: mismatch detected (error, zero flow calls): $($c[1])"
}

# (11) Interpreter: result message (green / amber / red) ---------------------------------------------------------------------------
$sumFx = $onExp.Substring($onExp.LastIndexOf('Set(varWrExpOkN,'))
$sumFx = $sumFx.Substring(0, $sumFx.IndexOf('Set(varWrBusy,false);')).Trim().TrimEnd(';')
function Test-Msg([string]$results, [string]$jobs, [string]$errors, [string]$kind, [string]$headKey, [string]$body, [string]$label) {
    Set-FxVar 'colWrExpResults' $results; Set-FxVar 'colWrExpJobs2' $jobs; Set-FxVar 'colWrExportErrors' $errors
    Set-FxVar 'colWrExpBuilt' 'Table({Base:"TEST_WeekReport_TEST-000_2026KW46_EMP-901"})'; Set-FxVar 'varWrExpFolder' '"TEST-000"'
    foreach ($v in 'varAdmMsgKind', 'varAdmMsgHead', 'varAdmMsgBody', 'varWrExpOkN', 'varWrExpFiles', 'varWrExpFailN', 'varWrExpNotes') { Set-FxVar $v $(if ($v -like 'varWrExp*N' -or $v -eq 'varWrExpFiles') { '0' } else { '""' }) }
    Invoke-FxStatements $sumFx
    Assert-Eval 'varAdmMsgKind & "|" & varAdmMsgHead & "|" & varAdmMsgBody' "$kind|$((Invoke-Fx "T.$headKey.en").Value)|$body" "message: $label"
}
function Invoke-FxStatements([string]$fx) {
    # top-level ';' statements run in order; If(...) with ';' in a branch picks its branch when reached (after the earlier Sets);
    # Set() is not enabled in this interpreter: Set(name, expr) is evaluated here and stored with UpdateVariable
    $out = @(); $depth = 0; $inS = $false; $last = 0
    for ($j = 0; $j -lt $fx.Length; $j++) { $ch = $fx[$j]; if ($ch -eq '"') { $inS = -not $inS; continue }; if ($inS) { continue }; if ($ch -in @('(', '{', '[')) { $depth++ } elseif ($ch -in @(')', '}', ']')) { $depth-- } elseif ($ch -eq ';' -and $depth -eq 0) { $out += $fx.Substring($last, $j - $last).Trim(); $last = $j + 1 } }
    $out += $fx.Substring($last).Trim()
    foreach ($s in $out) {
        if (-not $s) { continue }
        if ($s.StartsWith('If(')) {
            $a = Split-FxArgs (Get-Balanced $s 2)
            $k = 0; $chosen = $null
            while ($k + 1 -lt $a.Count) { if ((Invoke-Fx $a[$k].Trim()).Value) { $chosen = $a[$k + 1]; break }; $k += 2 }
            if ($null -eq $chosen -and ($a.Count % 2) -eq 1) { $chosen = $a[$a.Count - 1] }
            if ($chosen) { Invoke-FxStatements $chosen.Trim() }
        } elseif ($s -match '^Set\((\w+),') { Set-FxValue $Matches[1] (Invoke-Fx (Split-FxArgs (Get-Balanced $s 3))[1].Trim()) }
        else { throw "FAIL unexpected statement in the message step: $s" }
    }
}
$noErr = 'Filter(Table({Message:""}),false)'
$j1 = 'Table({Code:"EMP-901"})'; $j3 = 'Table({Code:"EMP-901"},{Code:"EMP-902"},{Code:"EMP-903"})'
Test-Msg 'Table({Code:"EMP-901",Status:"Ready",PdfOk:true,CsvOk:true,Msg:""})' $j1 $noErr 'Success' 'admHeadExported' 'Saved in Exports/TEST-000: TEST_WeekReport_TEST-000_2026KW46_EMP-901.pdf and TEST_WeekReport_TEST-000_2026KW46_EMP-901.csv' 'one contractor exported -> green, folder + both file names'
Test-Msg 'Table({Code:"EMP-901",Status:"Ready",PdfOk:true,CsvOk:true,Msg:""},{Code:"EMP-902",Status:"Ready",PdfOk:true,CsvOk:true,Msg:""},{Code:"EMP-903",Status:"NoHours",PdfOk:false,CsvOk:false,Msg:"EMP-903: no hours, skipped."})' $j3 $noErr 'Success' 'admHeadExported' 'Exported 2 of 3 contractors to Exports/TEST-000. EMP-903: no hours, skipped.' 'All: 2 exported + 1 without hours -> green with the skip note'
Test-Msg 'Table({Code:"EMP-901",Status:"NoHours",PdfOk:false,CsvOk:false,Msg:"EMP-901: no hours, skipped."})' $j1 $noErr 'Warning' 'admHeadAttention' 'Nothing exported. EMP-901: no hours, skipped.' 'only a contractor without hours -> amber "Attention.", nothing exported'
Test-Msg 'Table({Code:"EMP-901",Status:"Ready",PdfOk:true,CsvOk:true,Msg:""},{Code:"EMP-902",Status:"NoLanguage",PdfOk:false,CsvOk:false,Msg:"EMP-902: no report language (column Report Language in the Employers list). Not exported."},{Code:"EMP-903",Status:"Ready",PdfOk:true,CsvOk:false,Msg:"EMP-903: PDF saved, CSV not confirmed (x). Check Exports/TEST-000."})' $j3 $noErr 'Warning' 'admHeadPartExported' 'Exported 1 of 3 contractors to Exports/TEST-000. EMP-902: no report language (column Report Language in the Employers list). Not exported. EMP-903: PDF saved, CSV not confirmed (x). Check Exports/TEST-000.' 'partial -> amber "Partly exported." with the list of failed contractors'
Test-Msg 'Table({Code:"EMP-901",Status:"NoLanguage",PdfOk:false,CsvOk:false,Msg:"EMP-901: no report language (column Report Language in the Employers list). Not exported."})' $j1 $noErr 'Error' 'admHeadNotExported' 'Nothing exported. EMP-901: no report language (column Report Language in the Employers list). Not exported.' 'missing report language (one contractor) -> red, nothing exported'
Test-Msg 'Table({Code:"EMP-905",Status:"NoLanguage",PdfOk:false,CsvOk:false,Msg:"E5."},{Code:"EMP-901",Status:"NoLanguage",PdfOk:false,CsvOk:false,Msg:"E1."},{Code:"EMP-904",Status:"NoLanguage",PdfOk:false,CsvOk:false,Msg:"E4."},{Code:"EMP-902",Status:"NoLanguage",PdfOk:false,CsvOk:false,Msg:"E2."},{Code:"EMP-903",Status:"NoLanguage",PdfOk:false,CsvOk:false,Msg:"E3."})' 'Table({Code:"EMP-901"},{Code:"EMP-902"},{Code:"EMP-903"},{Code:"EMP-904"},{Code:"EMP-905"})' $noErr 'Error' 'admHeadNotExported' 'Nothing exported. E1. E2. E3. (+2 more)' 'review 6: notes sorted by Contractor Code, max 3 + "(+n more)" (parallel ForAll order does not matter)'Test-Msg 'Filter(Table({Code:"",Status:"",PdfOk:false,CsvOk:false,Msg:""}),false)' $j1 'Table({Message:"Project has no Project Number. Fix in Projects, then Refresh."})' 'Error' 'admHeadNotExported' 'Nothing exported. Project has no Project Number. Fix in Projects, then Refresh.' 'collected error before any flow call -> red, zero flow calls'

Write-Output 'Test-Export: admission guard (parity + cases), busy flag, flow calls (per contractor: PDF 5 args with TemplateName, CSV 4 args after PDF OK, results checked), one Translations read (500 guard), 23 keys, no fallback (missing text blocks), page languages (primary setting + Employers.Language), jobs per contractor (H26), statuses NoHours/NoLanguage/MissingTexts, PDF Content = sample-body.html, escaping, CSS footer, file names, CSV per contractor, integrity, result messages verified locally.'
Write-Output 'NOT verified locally: Studio import and binding (flow optional parameter record {text_4:...}, flow calls inside ForAll, Ungroup, User().FullName, Text(...,"nl-NL") in Studio, UniChar), delegation/Monitor of the Translations read, flow run and PDF rendering, real SharePoint data.'
