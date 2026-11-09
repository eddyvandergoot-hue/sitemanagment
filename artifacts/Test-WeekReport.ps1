# Week Report phase A (WEEKREPORT_PLAN.md par. 3-5 and 7; DECISIONS.md WR1, E6-E8, E10, E11): static and Power Fx interpreter checks of
# Src\scrWeekReport.pa.yaml. Style of Test-AdminScreens.ps1: Check-WeeklySource.ps1 is dot-sourced (syntax + templates), the real formula
# texts are read from the YAML and evaluated in the Power Fx interpreter with synthetic fixtures (no real names; TEST-000 style data).
# Proves source structure and local calculation only: NO Studio import, Canvas binding, delegation (Monitor) or functional result.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$wrEngine = New-Object Microsoft.PowerFx.RecalcEngine
$wrOpt = New-Object Microsoft.PowerFx.ParserOptions
$wrOpt.Culture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
$wrOpt.AllowsSideEffects = $true
function Assert-True($cond, $label) { if (!$cond) { throw "FAIL $label" }; Write-Output "PASS $label" }
function Eval-Fx([string]$fx) {
    try { $v = $wrEngine.Eval($fx, $null, $wrOpt) } catch { throw "FAIL evaluation error in: $($fx.Substring(0,[Math]::Min(300,$fx.Length))) :: $($_.Exception.InnerException.Message) $($_.Exception.Message)" }
    if ($v -is [Microsoft.PowerFx.Types.ErrorValue]) { throw "FAIL evaluation returned an error: $($v.ToExpression()) :: $($fx.Substring(0,[Math]::Min(300,$fx.Length)))" }
    return $v
}
function Assert-Eval([string]$fx, $expected, [string]$label) {
    $v = Eval-Fx $fx
    if ($v.Value -ne $expected) { throw "FAIL $label : got '$($v.ToExpression())', expected '$expected'" }
    Write-Output "PASS $label"
}
function Set-Var([string]$name, [string]$literal) { $wrEngine.UpdateVariable($name, (Eval-Fx $literal)) }
function Get-Balanced([string]$text, [int]$open) {
    # $open = index of '('; returns the inner text between the matching parentheses
    $depth = 0; $inS = $false
    for ($j = $open; $j -lt $text.Length; $j++) {
        $ch = $text[$j]
        if ($ch -eq '"') { $inS = -not $inS; continue }
        if ($inS) { continue }
        if ($ch -eq '(') { $depth++ } elseif ($ch -eq ')') { $depth--; if ($depth -eq 0) { return $text.Substring($open + 1, $j - $open - 1) } }
    }
    throw "FAIL unbalanced expression at $open"
}
function Split-Args([string]$inner) {
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
function Strip-Strings([string]$fx) { return [regex]::Replace($fx, '"(?:[^"]|"")*"', '""') }
function Norm([string]$s) { return ($s -replace '\s+', '') }

$srcDir = Join-Path $projectRoot 'Src'
$scr = 'scrWeekReport'
$doc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir "$scr.pa.yaml")))
$appDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'App.pa.yaml')))
$script:formulas = 0; $script:failures = 0
Check-Node $doc $scr; Check-Node $appDoc 'App'
if ($script:failures -gt 0) { throw 'FAIL Power Fx syntax in scrWeekReport/App' }
Assert-True $true "Power Fx syntax: $script:formulas formulas in scrWeekReport + App parsed"
$script:names = @{}; $script:controlCount = 0
foreach ($entry in $doc['Screens'][$scr]['Children']) { Check-Control $entry }
Assert-True ($script:controlCount -gt 0) "scrWeekReport control templates/properties valid ($script:controlCount controls)"
$idx = @{}; function Index-Wr($entries) { foreach ($e in $entries) { $n = @($e.Keys)[0]; $idx[$n] = $e[$n]; Index-Wr $e[$n]['Children'] } }; Index-Wr $doc['Screens'][$scr]['Children']
$all = [ordered]@{}
foreach ($n in $idx.Keys) { foreach ($p in $idx[$n]['Properties'].Keys) { $all["$n.$p"] = ([string]$idx[$n]['Properties'][$p]).Trim() } }
foreach ($p in $doc['Screens'][$scr]['Properties'].Keys) { $all["$scr.$p"] = ([string]$doc['Screens'][$scr]['Properties'][$p]).Trim() }
function P([string]$key) { if (!$all.Contains($key)) { throw "FAIL missing $key" }; return [string]$all[$key] }
$loader = P 'btnWrLoad.OnSelect'
$loaderN = Norm $loader
$screenText = ($all.Values) -join "`n"

# (1) Structure: admin screen pattern, read-only report, phase A footer -------------------------------------------------
Assert-True ((P "$scr.Fill") -eq '=ColorValue("#F5F6F8")') 'page #F5F6F8 (admin screen pattern)'
Assert-True ($idx['cmpWrTitle']['ComponentName'] -eq 'cmpTitleBar' -and (P 'cmpWrTitle.Height') -eq '=60' -and (P 'cmpWrTitle.Logo') -eq '=GEA_logo_white' -and (P 'cmpWrTitle.Title').Contains('T.wrTitle.en') -and (P 'cmpWrTitle.Busy') -eq '=Coalesce(varWrBusy,false) || varWrLoadState="Loading"') 'title bar = cmpTitleBar "Week Report", spinner (Busy) while loading'
Assert-True ($idx['cmpWrMsgBar']['ComponentName'] -eq 'cmpMessageBar' -and (P 'cmpWrMsgBar.Y') -eq '=cmpWrTitle.Y+cmpWrTitle.Height' -and (P 'cmpWrMsgBar.Height') -eq '=If(IsBlank(varAdmMsgKind),0,40)' -and (P 'cmpWrMsgBar.Kind') -eq '=varAdmMsgKind') 'message bar = cmpMessageBar directly under the title (varAdmMsgKind/Head/Body), no Notify'
Assert-True ($screenText -notmatch '\bNotify\(') 'no Notify on scrWeekReport (messages via cmpMessageBar)'
Assert-True ($idx['conWrBody']['Variant'] -eq 'AutoLayout' -and (P 'conWrBody.LayoutOverflowY') -eq '=LayoutOverflow.Scroll' -and (P 'conWrBody.Height') -eq '=Max(0,cmpWrFooter.Y-Self.Y)') 'scrolling body between message bar and footer'
Assert-True ($idx['cmpWrFooter']['ComponentName'] -eq 'cmpReportFooter' -and (P 'cmpWrFooter.Height') -eq '=68' -and (P 'cmpWrFooter.Y') -eq '=Parent.Height-Self.Height' -and (P 'cmpWrFooter.X') -eq '=0' -and (P 'cmpWrFooter.Width') -eq '=Parent.Width') 'footer = cmpReportFooter h68 anchored at the bottom'
Assert-True ((P 'cmpWrFooter.ExportVisible') -eq '=false' -and (P 'cmpWrFooter.ExportEnabled') -eq '=false' -and (P 'cmpWrFooter.OnExport').StartsWith('=If(false,') -and (P 'cmpWrFooter.OnExport') -notmatch '\.Run\(|Patch\(|Launch\(') 'phase A: Export hidden and disabled; OnExport gated by the same (false) guard and does nothing'
Assert-True (@([IO.File]::ReadAllText((Join-Path $srcDir '_EditorState.pa.yaml')) -split "`n" | Where-Object { $_.Trim() -eq '- scrWeekReport' }).Count -eq 1) 'scrWeekReport registered in _EditorState ScreensOrder'
$homeDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'scrHome.pa.yaml')))
$hIdx = @{}; function Index-H($entries) { foreach ($e in $entries) { $n = @($e.Keys)[0]; $hIdx[$n] = $e[$n]; Index-H $e[$n]['Children'] } }; Index-H $homeDoc['Screens']['scrHome']['Children']
Assert-True (([string]$hIdx['cmpTileWeekReport']['Properties']['Active']).Trim() -eq '=true' -and ([string]$hIdx['cmpTileWeekReport']['Properties']['OnSelect']).Trim() -ceq '=Navigate(scrWeekReport); true') 'Home tile Week report active, navigates to scrWeekReport'
foreach ($c in @('cmpWrProject', 'cmpWrContractor')) { Assert-True ($idx[$c]['ComponentName'] -eq 'cmpField' -and (P "$c.InputType") -eq '="dropdown"' -and (P "$c.Height") -eq '=58') "$c = cmpField dropdown (admin pattern)" }
Assert-True ((P 'cmpWrContractor.Items') -eq '=colWrContractorItems' -and (P 'cmpWrContractor.DefaultValue').Contains('T.wrAllContractors.en') -and $loader.Contains('ClearCollect(colWrPendContractorItems,{Value:If(LangNl && !IsBlank(T.wrAllContractors.nl),T.wrAllContractors.nl,T.wrAllContractors.en)});')) 'Contractor dropdown: "All contractors" first, then the contractors of the loaded week'

# (2) Week picker: dpHoursWeek pattern (B6/E11) ------------------------------------------------------------------------
$hoursDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'scrHours.pa.yaml')))
$hoursIdx = @{}; function Index-Hr($entries) { foreach ($e in $entries) { $n = @($e.Keys)[0]; $hoursIdx[$n] = $e[$n]; Index-Hr $e[$n]['Children'] } }; Index-Hr $hoursDoc['Screens']['scrHours']['Children']
$dpH = $hoursIdx['dpHoursWeek']['Properties']; $dpW = $idx['dpWrWeek']['Properties']
Assert-True ($idx['dpWrWeek']['Control'] -eq 'ModernDatePicker@1.0.2' -and $hoursIdx['dpHoursWeek']['Control'] -eq 'ModernDatePicker@1.0.2') 'dpWrWeek = ModernDatePicker@1.0.2 like dpHoursWeek'
foreach ($k in 'Format', 'StartOfWeek', 'Width', 'Height', 'Font', 'FontWeight', 'Size', 'Color', 'Fill', 'BorderColor', 'BorderThickness') { Assert-True (([string]$dpW[$k]).Trim() -ceq ([string]$dpH[$k]).Trim()) "dpWrWeek.$k equals dpHoursWeek.$k ($(([string]$dpW[$k]).Trim()))" }
Assert-True ((P 'dpWrWeek.DefaultDate') -eq '=Coalesce(varWrPickedDay,Today())' -and !$dpW.ContainsKey('StartDate') -and !$dpW.ContainsKey('EndDate')) 'dpWrWeek: DefaultDate = picked day or today (default today''s week), unbounded (no StartDate/EndDate)'
$G = '!Coalesce(varWrBusy,false) && varWrLoadState<>"Loading"'
$pickOc = P 'dpWrWeek.OnChange'
Assert-True ((P 'dpWrWeek.DisplayMode') -ceq "=If($G,DisplayMode.Edit,DisplayMode.Disabled)" -and $pickOc.StartsWith("=If($G,")) 'picker guard parity: DisplayMode condition = first OnChange condition (disabled while loading)'
Assert-True ((Norm $pickOc).Contains('If(monday=varWrMonday,Set(varWrPickedDay,selectedDay),Set(varWrPickedDay,selectedDay);Set(varWrMonday,monday);Select(btnWrLoad))') -and ([regex]::Matches($pickOc, 'Reset\(dpWrWeek\)')).Count -eq 1 -and (Norm $pickOc).Contains('If(IsBlank(Self.SelectedDate),Reset(dpWrWeek),')) 'picker OnChange: other week -> keep day + Monday + load; same week -> keep day only; Reset only for an empty date (never after a normal pick)'
Assert-True ($screenText -notmatch '\bvar(Hours|Week|Team)\w*' -and $screenText -notmatch '\bdpHoursWeek\b|\bdpTeamWeek\b') 'week state is own (varWr*), independent of Screen1 / Weekly Hours'
Assert-True ((P 'lblWrWeekKW.X') -eq '=dpWrWeek.X+dpWrWeek.Width+12' -and (P 'lblWrWeekKW.Y') -eq '=dpWrWeek.Y' -and (P 'lblWrWeekLabel.Text').Contains('T.wrFieldWeek.en')) 'label "Week" above the picker and "YYYY KWxx" beside it'

# (3) No mutations --------------------------------------------------------------------------------------------------------
$bare = Strip-Strings $screenText
Assert-True ($bare -notmatch '\b(Patch|Remove|RemoveIf|Update|UpdateIf|SubmitForm|Defaults|Launch|Download|Choices)\(' -and $bare -notmatch '\.Run\(') 'no Patch/Remove/RemoveIf/Update/UpdateIf/SubmitForm/Defaults/flow/Launch and no Choices() on scrWeekReport'
$colTargets = @([regex]::Matches($bare, '\b(Collect|ClearCollect|Clear)\(\s*([^,\)]+)') | ForEach-Object { $_.Groups[2].Value.Trim() } | Sort-Object -Unique)
Assert-True (@($colTargets | Where-Object { $_ -notmatch '^col[A-Z]\w*$' }).Count -eq 0) "Collect/ClearCollect/Clear only target local collections ($($colTargets.Count) targets, all col*)"
Assert-True ($bare -notmatch "\b(Collect|ClearCollect|Clear|Patch|Remove|RemoveIf|Update|UpdateIf)\(\s*(Hours|Workers|Employers|Projects|'Project Workers'|'Assignment Periods')\b") 'no collection function is applied to a SharePoint list'

# (4) Reads and predicates: only columns + global variables, set beforehand --------------------------------------------
$sources = "Hours|Workers|Employers|Projects|'Project Workers'|'Assignment Periods'"
$hits = @([regex]::Matches($bare, "(?<![\w.'])($sources)(?![\w'])") | ForEach-Object { $bare.Substring([Math]::Max(0, $_.Index - 16), [Math]::Min(16, $_.Index)) + '>' + $_.Value })
$hrec = '{HourID:entry.ID,EntryKey:Trim(entry.EntryKey&""),AssignmentID:entry.Assignment.Id,WorkDay:Date(Year(entry.''WorkDate''),Month(entry.''WorkDate''),Day(entry.''WorkDate'')),ContractorID:entry.Employer.Id,ContractorName:Trim(entry.Employer.Value&""),TradeRaw:Trim(entry.Trade.Value&""),HourValue:entry.Hours}'
$allowedReads = @(
    'Refresh(Projects)', 'Refresh(Employers)', 'Refresh(Workers)', 'Refresh(Hours)', "Refresh('ProjectWorkers')", "Refresh('AssignmentPeriods')",
    'ForAll(ProjectsAsp,{ID:p.ID,Title:Trim(p.Title&""),Number:Trim(p.''ProjectNumber''&""),Reference:Trim(p.''ProjectReference''&"")})',
    'ForAll(EmployersAsemp,{ID:emp.ID,Name:Trim(emp.Title&""),Code:Trim(emp.''EmployerCode''&""),Active:Coalesce(emp.Active,true)})',
    'ForAll(WorkersAsw,{ID:w.ID,FirstName:Trim(w.''FirstName''&""),Surname:Trim(w.Surname&""),Code:Trim(w.''WorkerCode''&""),Trade:Trim(w.Trade.Value&""),EmployerID:w.Employer.Id,EmployerName:Trim(w.Employer.Value&""),Language:If(Trim(w.Language.Value&"")="Nederlands","Dutch",Trim(w.Language.Value&""))})',
    "Filter('ProjectWorkers',ProjectKey=varWrProjectKey)", "Filter('AssignmentPeriods',ProjectKey=varWrProjectKey)",
    "ForAll(Filter(Hours,StartsWith(EntryKey,varWrQueryPrefix)&&'WorkDate'>=varWrMonday&&'WorkDate'<varWrNextMonday)Asentry,$hrec)"
)
$dayPreds = @(0..6 | ForEach-Object { "ForAll(Filter(Hours,StartsWith(EntryKey,varWrQueryPrefix)&&'WorkDate'>=DateAdd(varWrMonday,$_,TimeUnit.Days)&&'WorkDate'<DateAdd(varWrMonday,$($_+1),TimeUnit.Days))Asentry,$hrec)" })
$loaderN2 = Norm $loader
foreach ($r in $allowedReads + $dayPreds) { Assert-True (([regex]::Matches($loaderN2, [regex]::Escape($r))).Count -eq 1) "read present exactly once: $($r.Substring(0,[Math]::Min(110,$r.Length)))" }
Assert-True ($hits.Count -eq 6 + 3 + 2 + 1 + 7) "SharePoint lists are referenced only by these 19 reads (6 Refresh, 3 master reads, 2 ProjectKey reads, 1 week + 7 written-out day Hours reads; found $($hits.Count))"
Assert-True ($loader -notmatch '\bLookUp\(\s*(Hours|Workers|Employers|Projects|''Project Workers''|''Assignment Periods'')' -and $bare -notmatch "(LookUp|Filter|CountIf|CountRows|First|Search|Sum)\(\s*(Workers|Employers|Projects)\b") 'no remote LookUp/Filter/CountIf on a list (masters are read once, everything else is local)'
$iFirstRead = $loaderN2.IndexOf("Filter('ProjectWorkers'")
foreach ($v in 'Set(varWrProjectKey,Text(varWrPendProjectID))', 'Set(varWrQueryPrefix,varWrProjectKey&"|")', 'Set(varWrNextMonday,DateAdd(varWrMonday,7,TimeUnit.Days))') { $iv = $loaderN2.IndexOf($v); Assert-True ($iv -ge 0 -and $iv -lt $iFirstRead) "predicate variable set before the first ProjectKey/Hours read: $v" }
Assert-True ($loaderN2.IndexOf('Set(varWrProjectKey,') -lt $loaderN2.IndexOf("ForAll(Filter(Hours,") -and $loaderN2.IndexOf('Set(varWrQueryPrefix,') -lt $loaderN2.IndexOf("ForAll(Filter(Hours,")) 'Hours predicate variables (prefix ends with "|") set before the Hours reads'
$hoursPreds = @([regex]::Matches($loaderN2, "Filter\(Hours,(.*?)\)Asentry") | ForEach-Object { $_.Groups[1].Value })
Assert-True ($hoursPreds.Count -eq 8 -and @($hoursPreds | Where-Object { $_ -notmatch "^StartsWith\(EntryKey,varWrQueryPrefix\)&&'WorkDate'>=(varWrMonday|DateAdd\(varWrMonday,\d,TimeUnit\.Days\))&&'WorkDate'<(varWrNextMonday|DateAdd\(varWrMonday,\d,TimeUnit\.Days\))$" }).Count -eq 0) 'all 8 Hours predicates use only EntryKey/Work Date + global variables (no With names, no ForAll record fields)'

# (5) 500 guards ----------------------------------------------------------------------------------------------------------
foreach ($gd in @(
    @('If(CountRows(colWrPendProjects)>=500,Collect(colWrLoadErrors', 'Projects'), @('If(CountRows(colWrPendEmployers)>=500,Collect(colWrLoadErrors', 'Employers'), @('If(CountRows(colWrPendWorkers)>=500,Collect(colWrLoadErrors', 'Workers'),
    @('If(CountRows(colWrPendPW)>=500,Collect(colWrLoadErrors', 'Project Workers'), @('If(CountRows(colWrPendPeriods)>=500,Collect(colWrLoadErrors', 'Assignment Periods'),
    @('If(CountRows(batch)<500,CountRows(Collect(colWrPendHours,batch))>=0,Set(varWrQueryPaged,true);true)', 'Hours week batch (full batch -> 7 day batches, not collected)'),
    @('ForAll(Sequence(7)AsdayIndex,If(CountIf(colWrPendHours,WorkDay=DateAdd(varWrMonday,dayIndex.Value-1,TimeUnit.Days))>=500,Collect(colWrLoadErrors', 'Hours day batch (a full day blocks)'))) {
    Assert-True ($loaderN2.Contains($gd[0])) "500 guard: $($gd[1])"
}
Assert-True ($loaderN2.IndexOf('If(IsEmpty(colWrLoadErrors)&&varWrQueryPaged,Clear(colWrPendHours);') -gt $loaderN2.IndexOf('Set(varWrQueryPaged,true)')) 'day batches only after a full week batch (varWrQueryPaged)'

# (6) Staging: commit only after full success --------------------------------------------------------------------------
$commits = @('ClearCollect(colWrRows,colWrPendRowsShown)', 'ClearCollect(colWrGroups,colWrPendGroups)', 'ClearCollect(colWrLines,Sort(colWrPendLines,SortKey,SortOrder.Ascending))', 'ClearCollect(colWrContractorItems,colWrPendContractorItems)', 'Set(varWrLoadState,"Loaded")', 'Set(varWrLoadedMonday,varWrMonday)', 'Set(varWrLoadedProjectID,varWrPendProjectID)')
$lastErr = $loaderN2.LastIndexOf('Collect(colWrLoadErrors')
$commitBlock = $loaderN2.IndexOf('If(IsEmpty(colWrLoadErrors),ClearCollect(colWrRows,colWrPendRowsShown);')
Assert-True ($commitBlock -gt $lastErr) 'report commit block = If(IsEmpty(colWrLoadErrors), ...) after the last error check'
foreach ($c in $commits) { $i = $loaderN2.IndexOf($c); Assert-True ($i -gt $commitBlock -and ([regex]::Matches((Norm $screenText), [regex]::Escape($c))).Count -eq 1) "commit once, inside the success block: $c" }
foreach ($v in 'colWrRows', 'colWrGroups', 'colWrLines', 'colWrContractorItems', 'colWrProjects', 'colWrEmployers', 'colWrWorkers') { Assert-True (([regex]::Matches($bare, "\b(Clear|Collect|ClearCollect)\($v\b")).Count -eq 1) "$v is written once (only by its commit)" }
$mCommit = $loaderN2.IndexOf('If(IsEmpty(colWrLoadErrors),ClearCollect(colWrProjects,')
Assert-True ($mCommit -gt $loaderN2.IndexOf('If(CountRows(colWrPendWorkers)>=500') -and $mCommit -lt $loaderN2.IndexOf("Filter('ProjectWorkers'") -and $loaderN2.Contains('ClearCollect(colWrEmployers,colWrPendEmployers);ClearCollect(colWrWorkers,colWrPendWorkers);Set(varWrMastersReady,true)')) 'masters (Projects/Employers/Workers) are their own staging unit: committed only after their reads and 500 guards succeeded'
Assert-True ($loaderN2.Contains('If(IsEmpty(colWrLoadErrors)&&(Coalesce(varWrForceRefresh,false)||!Coalesce(varWrMastersReady,false)),Set(varWrMastersReady,false);') -and (P "$scr.OnVisible").Contains('Set(varWrMastersReady,false)')) 'masters read once per visit (OnVisible) and again only on Refresh (force)'
Assert-True ($loaderN2.Contains('If(!IsEmpty(colWrLoadErrors),Set(varWrLoadState,"Failed");') -and $loaderN2.StartsWith('=If(Coalesce(varWrBusy,false),') -and $loaderN2.Contains('Set(varWrBusy,true);Set(varWrLoadState,"Loading");')) 'load states Loading -> Loaded/Failed/NotLoaded; loader refuses while busy'
Assert-True ($loaderN2.Contains('Concurrent(IfError(CountRows(ClearCollect(colWrPendProjects,') -and $loaderN2.Contains('Collect(colWrProjectsErrors,') -and $loaderN2.Contains('Collect(colWrEmployersErrors,') -and $loaderN2.Contains('Collect(colWrWorkersErrors,') -and $loaderN2.Contains('Collect(colWrLoadErrors,colWrProjectsErrors,colWrEmployersErrors,colWrWorkersErrors)')) 'Concurrent master reads: each branch its own error collection, merged afterwards'

# (7) Guard parity (footer, dropdowns): same text in Enabled and as first OnXxx condition ------------------------------
foreach ($b in 'Home', 'Prev', 'Next', 'Refresh', 'Export') {
    $en = (P "cmpWrFooter.${b}Enabled").Substring(1); $on = P "cmpWrFooter.On$b"
    Assert-True ($on.StartsWith("=If($en,")) "footer $b : On$b starts with If(<${b}Enabled>,"
}
foreach ($b in 'Home', 'Refresh') { Assert-True ((P "cmpWrFooter.${b}Enabled") -ceq "=$G") "footer $b disabled while loading/busy" }
foreach ($b in 'Prev', 'Next') { Assert-True ((P "cmpWrFooter.${b}Enabled") -ceq "=$G && !IsBlank(varWrMonday)" -and (Norm (P "cmpWrFooter.On$b")).Contains('Reset(dpWrWeek);Select(btnWrLoad)')) "footer $b disabled while loading; moves the week by 7 days and loads" }
foreach ($c in 'cmpWrProject', 'cmpWrContractor') { $en = (P "$c.Enabled").Substring(1); Assert-True ((P "$c.OnChange").StartsWith("=If($en,") -and (P "$c.OnChange").EndsWith('; true') -and $en.StartsWith($G)) "$c : OnChange starts with If(<Enabled>, (busy/loading blocks) and ends with ; true" }
foreach ($case in @(@('false', '"Loaded"', 'Date(2026,11,9)', $true), @('true', '"Loaded"', 'Date(2026,11,9)', $false), @('false', '"Loading"', 'Date(2026,11,9)', $false), @('Blank()', '"Failed"', 'Date(2026,11,9)', $true))) {
    Assert-Eval "With({varWrBusy:$($case[0]),varWrLoadState:$($case[1]),varWrMonday:$($case[2])},$((P 'cmpWrFooter.RefreshEnabled').Substring(1)))" $case[3] "footer Refresh/Home enabled = $($case[3]) for busy $($case[0]), state $($case[1])"
}
Assert-Eval "With({varWrBusy:false,varWrLoadState:`"Loaded`",varWrMonday:If(false,Date(2026,1,1))},$((P 'cmpWrFooter.PrevEnabled').Substring(1)))" $false 'footer Prev blocked without a week'
Assert-Eval "With({varWrBusy:false,varWrLoadState:`"Failed`",varWrMastersReady:true},$((P 'cmpWrProject.Enabled').Substring(1)))" $true 'Project dropdown usable after a failed report load when the project list is ready (no dead end)'
Assert-Eval "With({varWrBusy:false,varWrLoadState:`"Failed`"},$((P 'cmpWrContractor.Enabled').Substring(1)))" $false 'Contractor filter only on a Loaded report'
Assert-True ((Norm (P 'cmpWrProject.OnChange')).Contains('LookUp(colWrProjects,Display=Trim(cmpWrProject.Value&"")).ID<>Coalesce(varWrProjectID,0),Set(varWrProjectID,') -and (Norm (P 'cmpWrProject.OnChange')).Contains('CountIf(colWrProjects,Display=Trim(cmpWrProject.Value&""))<>1,') -and (P 'cmpWrContractor.OnChange') -notmatch 'Select\(btnWrLoad\)') 'project change loads only for another, unique project; contractor change is local (no read)'

# (8) Interpreter: the real loader formulas on synthetic fixtures ----------------------------------------------------------
$formulas = [string]$appDoc['App']['Properties']['Formulas']
$tStart = $formulas.IndexOf('T = {'); $tEnd = $formulas.IndexOf('};', $tStart)
Set-Var 'T' $formulas.Substring($tStart + 4, $tEnd - $tStart - 3)
Set-Var 'LangNl' 'false'
$steps = New-Object System.Collections.ArrayList
foreach ($m in [regex]::Matches($loader, '\b(ClearCollect|Collect|Set)\((colWrPend(?:Facts|PeriodWorkers|Keys|Rows|RowsShown|Groups|GroupRank|RowRank|Lines|ContractorItems)|varWrPendExcluded|varWrPendIsTest),')) {
    $open = $m.Index + $m.Groups[1].Value.Length
    $a = Split-Args (Get-Balanced $loader $open)
    if ($a.Count -ne 2) { throw "FAIL unexpected argument count in $($m.Value)" }
    if ($m.Groups[1].Value -eq 'Set' -and $a[1].Trim() -in @('false', '0')) { continue }  # initialisation at the start of the loader
    $pre = $loader.Substring([Math]::Max(0, $m.Index - 30), [Math]::Min(30, $m.Index))
    $steps.Add([pscustomobject]@{ Fn = $m.Groups[1].Value; Target = $m.Groups[2].Value; Expr = $a[1].Trim(); Cond = $(if ($pre.TrimEnd().EndsWith('If(!IsEmpty(colWrPendGroups),')) { '!IsEmpty(colWrPendGroups)' } else { '' }) }) | Out-Null
}
Assert-True (($steps | ForEach-Object { "$($_.Fn):$($_.Target)" }) -join ' ' -ceq 'Set:varWrPendIsTest ClearCollect:colWrPendFacts ClearCollect:colWrPendPeriodWorkers ClearCollect:colWrPendKeys Collect:colWrPendKeys ClearCollect:colWrPendRows Set:varWrPendExcluded ClearCollect:colWrPendRowsShown ClearCollect:colWrPendGroups ClearCollect:colWrPendGroupRank ClearCollect:colWrPendRowRank ClearCollect:colWrPendLines Collect:colWrPendLines Collect:colWrPendLines Collect:colWrPendLines ClearCollect:colWrPendContractorItems Collect:colWrPendContractorItems') "pipeline steps extracted from the loader in source order ($($steps.Count))"
Assert-True ($steps[14].Cond -eq '!IsEmpty(colWrPendGroups)') 'grand total line only when at least one contractor group exists'
$script:appendN = 0
function Run-Pipeline([string]$projectNumber) {
    Set-Var 'varWrPendProject' "{ID:7,Number:`"$projectNumber`",Title:`"Test project`",Reference:`"REF-1`",Display:`"x`"}"
    foreach ($s in $steps) {
        if ($s.Cond -and -not (Eval-Fx $s.Cond).Value) { continue }
        $e = $s.Expr; if ($e.StartsWith('{')) { $e = "Table($e)" }
        $v = Eval-Fx $e
        if ($s.Fn -eq 'Collect') {
            $script:appendN++; $bName = "wrAppend$($script:appendN)"; $wrEngine.UpdateVariable($bName, $v)
            $v = Eval-Fx "With({a:$($s.Target),b:$bName},ForAll(Sequence(CountRows(a)+CountRows(b)) As i,If(i.Value<=CountRows(a),Index(a,i.Value),Index(b,i.Value-CountRows(a)))))"
        }
        $wrEngine.UpdateVariable($s.Target, $v)
    }
}
# Fixture (project 7, ISO week 2026 KW46 = 09-11-2026 .. 15-11-2026). Workers 1..6 synthetic; contractors 10 (code empty), 20, 99 = TEST Employer.
Set-Var 'varWrMonday' 'Date(2026,11,9)'; Set-Var 'varWrPendSunday' 'Date(2026,11,15)'; Set-Var 'varWrProjectKey' '"7"'; Set-Var 'varWrQueryPrefix' '"7|"'; Set-Var 'varWrPendProjectID' '7'
Set-Var 'colWrWorkers' 'Table({ID:1,FirstName:"Anna",Surname:"Test",Code:"",Trade:"Welder",EmployerID:10,EmployerName:"Alpha BV",Language:"Polish"},{ID:2,FirstName:"Bram",Surname:"Test",Code:"WKR-002",Trade:"Fitter",EmployerID:20,EmployerName:"Beta",Language:"Polish"},{ID:3,FirstName:"Cees",Surname:"Test",Code:"",Trade:"Fitter",EmployerID:10,EmployerName:"Alpha BV",Language:"Dutch"},{ID:4,FirstName:"Dirk",Surname:"Test",Code:"",Trade:"Fitter",EmployerID:10,EmployerName:"Alpha BV",Language:"Romanian"},{ID:5,FirstName:"Eva",Surname:"Test",Code:"",Trade:"Fitter",EmployerID:99,EmployerName:"TEST Employer",Language:"English"},{ID:6,FirstName:"Fay",Surname:"Test",Code:"",Trade:"Unknown",EmployerID:20,EmployerName:"Beta",Language:"Romanian"})'
Set-Var 'colWrEmployers' 'Table({ID:10,Name:"Alpha BV",Code:"",Active:true},{ID:20,Name:"Beta",Code:"BETA-1",Active:true},{ID:99,Name:"TEST Employer",Code:"EMP-099",Active:true})'
Set-Var 'colWrPendPW' 'Table({ID:101,WorkerID:1,ProjectID:7,AssignmentKey:"7|1"},{ID:102,WorkerID:2,ProjectID:7,AssignmentKey:"7|2"},{ID:103,WorkerID:3,ProjectID:7,AssignmentKey:"7|3"},{ID:104,WorkerID:4,ProjectID:7,AssignmentKey:"7|4"},{ID:105,WorkerID:5,ProjectID:7,AssignmentKey:"7|5"},{ID:106,WorkerID:6,ProjectID:7,AssignmentKey:"7|6"})'
Set-Var 'colWrPendPeriods' 'Table({ID:1,AssignmentKey:"7|1",From:Date(2026,11,1),Until:If(false,Date(2026,1,1))},{ID:2,AssignmentKey:"7|2",From:Date(2026,10,1),Until:Date(2026,11,10)},{ID:3,AssignmentKey:"7|4",From:Date(2026,10,1),Until:Date(2026,11,8)},{ID:4,AssignmentKey:"7|5",From:Date(2026,11,12),Until:If(false,Date(2026,1,1))},{ID:5,AssignmentKey:"7|6",From:Date(2026,11,15),Until:Date(2026,11,15)})'
Set-Var 'colWrPendHours' 'Table({HourID:1,EntryKey:"7|2|20261109",AssignmentID:102,WorkDay:Date(2026,11,9),ContractorID:10,ContractorName:"Alpha BV",TradeRaw:"F",HourValue:8},{HourID:2,EntryKey:"7|2|20261110",AssignmentID:102,WorkDay:Date(2026,11,10),ContractorID:20,ContractorName:"Beta",TradeRaw:"W",HourValue:7.5},{HourID:3,EntryKey:"7|2|20261111",AssignmentID:102,WorkDay:Date(2026,11,11),ContractorID:20,ContractorName:"Beta",TradeRaw:"W",HourValue:2.25},{HourID:4,EntryKey:"7|3|20261111",AssignmentID:103,WorkDay:Date(2026,11,11),ContractorID:10,ContractorName:"Alpha BV",TradeRaw:"Fitter",HourValue:0},{HourID:5,EntryKey:"7|3|20261112",AssignmentID:103,WorkDay:Date(2026,11,12),ContractorID:10,ContractorName:"Alpha BV",TradeRaw:"",HourValue:10})'
Run-Pipeline 'P-1000'
$rowFx = 'Concat(Sort(colWrPendRowsShown,Text(WorkerID) & "|" & Text(ContractorID)),Text(WorkerID) & "/" & Text(ContractorID) & ":" & WorkerName & "|" & WorkerCode & "|" & ContractorName & "|" & EmployerCode & "|" & Trade & "|" & Concat(Table({d:D1},{d:D2},{d:D3},{d:D4},{d:D5},{d:D6},{d:D7}),If(IsBlank(d),"_",Text(d)),",") & "=" & Text(WeekTotal),"; ")'
$rowsExp = '1/10:Anna Test|WKR-001|Alpha BV|EMP-010|Welder|_,_,_,_,_,_,_=0; 2/10:Bram Test|WKR-002|Alpha BV|EMP-010|Fitter|8,_,_,_,_,_,_=8; 2/20:Bram Test|WKR-002|Beta|BETA-1|Welder|_,7.5,2.25,_,_,_,_=9.75; 3/10:Cees Test|WKR-003|Alpha BV|EMP-010|Fitter|_,_,0,10,_,_,_=10; 6/20:Fay Test|WKR-006|Beta|BETA-1|Unknown|_,_,_,_,_,_,_=0'
Assert-Eval $rowFx $rowsExp 'rows (real project): period-only workers 1/6 with the current contractor and Workers.Trade; worker 2 with hours under two contractors = two rows (historical Hours.Employer); worker 3 hours without period; worker 4 (period ended Sunday before) absent; F->Fitter, W->Welder; blank trade lines ignored; stored 0 kept as 0; codes WKR-/EMP- fallback'
Assert-Eval 'varWrPendExcluded' 1 'TEST rule: on a real project the TEST Employer row (worker 5, period only) is excluded and counted (Attention message)'
Assert-Eval 'Concat(Sort(colWrPendGroups,SortName),Display & "=" & ReportLanguage & "/" & Text(Rows) & "/" & Text(WeekTotal),"; ")' 'Alpha BV (EMP-010)=Polish/3/18; Beta (BETA-1)=English/2/9.75' 'report language per contractor group: majority Polish (2 of 3); tie Polish/Romanian -> English; subtotals per contractor'
$lineFx = 'Concat(Sort(colWrPendLines,SortKey),LineType & ":" & Name & If(LineType="Row",If(Zebra,"#z",""),"") & "=" & Text(WeekTotal),"; ")'
Assert-Eval $lineFx 'Header:Alpha BV=0; Row:Anna Test=0; Row:Bram Test#z=8; Row:Cees Test=10; Subtotal:Subtotal=18; Header:Beta=0; Row:Bram Test=9.75; Row:Fay Test#z=0; Subtotal:Subtotal=9.75; Grand:Total=27.75' 'display lines: per contractor (sorted by name) header, rows (sorted by name, zebra from the 2nd row of each group), subtotal; grand total last'
Assert-Eval 'Concat(Filter(colWrPendLines,LineType="Grand"),Concat(Table({d:D1},{d:D2},{d:D3},{d:D4},{d:D5},{d:D6},{d:D7}),Text(d),","))' '8,7.5,2.25,10,0,0,0' 'grand total per day'
Assert-Eval 'Concat(colWrPendContractorItems,Value,"; ")' 'All contractors; Alpha BV (EMP-010); Beta (BETA-1)' 'Contractor dropdown items: All contractors first, then the contractors of the week (TEST Employer not on a real project)'
Run-Pipeline 'TEST-000'
Assert-Eval 'varWrPendExcluded' 0 'TEST rule: on a TEST- project nothing is excluded'
Assert-Eval 'Concat(Sort(colWrPendGroups,SortName),Display & "=" & ReportLanguage,"; ")' 'Alpha BV (EMP-010)=Polish; Beta (BETA-1)=English; TEST Employer (EMP-099)=English' 'TEST project: TEST Employer group shown; its single English worker -> English'
foreach ($c in @(@('TEST-000', $true), @(' TEST-001', $true), @('P-1000', $false), @('test-000', $false), @('XTEST-000', $false))) {
    $isTestFx = ($steps | Where-Object Target -eq 'varWrPendIsTest').Expr
    Assert-Eval "With({varWrPendProject:{Number:`"$($c[0])`"}},$isTestFx)" $c[1] "TEST project detection '$($c[0])' -> $($c[1]) (Project Number starts with TEST-, trimmed)"
}
# report language edge cases on the real group formula
$grpStep = ($steps | Where-Object Target -eq 'colWrPendGroups').Expr
foreach ($c in @(@('"Dutch","Dutch",""', 'Dutch'), @('"","",""', 'English'), @('"Polish","Romanian","Ukrainian"', 'English'), @('"Ukrainian","Ukrainian","Dutch"', 'Ukrainian'), @('"Dutch","Dutch","German"', 'Dutch'))) {
    $langs = $c[0] -split ','
    $rows = (0..2 | ForEach-Object { "{ContractorID:10,ContractorName:`"Alpha BV`",EmployerCode:`"EMP-010`",WorkerID:$($_+1),Language:$($langs[$_]),D1:If(false,0),D2:If(false,0),D3:If(false,0),D4:If(false,0),D5:If(false,0),D6:If(false,0),D7:If(false,0),WeekTotal:0}" }) -join ','
    Assert-Eval "With({colWrPendRowsShown:Table($rows)},First($grpStep).ReportLanguage)" $c[1] "report language for worker languages [$($c[0])] -> $($c[1]) (texts compared, no fixed language list; blank ignored; tie or none -> English)"
}
$langFx = (P 'lblWrGrpLang.Text').Substring(1)
Assert-Eval "With({ThisItem:{Lang:`"Polish`"}},$langFx)" 'Report language: Dutch + Polish' 'group header: Report language: Dutch + <second language>'
Assert-Eval "With({ThisItem:{Lang:`"Dutch`"}},$langFx)" 'Report language: Dutch' 'group header: Dutch result -> Dutch only'
Assert-Eval "With({ThisItem:{Name:`"Alpha BV`",Code:`"EMP-010`"}},$((P 'lblWrGrpName.Text').Substring(1)))" "Alpha BV  $([char]0xB7)  EMP-010" 'group header: contractor name + Contractor Code'
# error checks of the loader on bad fixtures (fail closed)
$bad = @([regex]::Matches($loader, 'With\(\{badRows:') | ForEach-Object { $open = $_.Index + 4; $inner = Get-Balanced $loader $open; $a = Split-Args $inner; $rec = $a[0].Trim(); $rec.Substring('{badRows:'.Length, $rec.Length - '{badRows:'.Length - 1) })
Assert-True ($bad.Count -eq 9) "9 badRows checks in the loader (PW other project, PW link key, period other project, period data, period without link, hour data, hour assignment, hour key, worker data)"
Assert-Eval "CountRows(With({colWrPendPW:Table({ID:1,ProjectID:8})},$($bad[0])))" 1 'check: Project Workers row with this ProjectKey but another Project.Id blocks'
Assert-Eval "CountRows(With({colWrPendPeriods:Table({ID:1,AssignmentKey:`"70|1`"},{ID:2,AssignmentKey:`"7|1`"})},$($bad[2])))" 1 'check: period whose AssignmentKey does not start with "<project>|" blocks'
Assert-Eval "CountRows(With({colWrPendHours:Table({HourID:1,EntryKey:`"a`",ContractorID:If(false,1),HourValue:8,AssignmentID:102,WorkDay:Date(2026,11,9)},{HourID:2,EntryKey:`"b`",ContractorID:10,HourValue:If(false,1),AssignmentID:102,WorkDay:Date(2026,11,9)},{HourID:3,EntryKey:`"c`",ContractorID:10,HourValue:1,AssignmentID:102,WorkDay:Date(2026,11,16)},{HourID:4,EntryKey:`"d`",ContractorID:10,HourValue:0,AssignmentID:102,WorkDay:Date(2026,11,15)})},$($bad[5])))" 3 'check: hour line without contractor or hours, or outside the week, blocks (stored 0 is valid)'
Assert-Eval "CountRows(With({colWrPendHours:Table({HourID:1,EntryKey:`"a`",AssignmentID:999},{HourID:2,EntryKey:`"b`",AssignmentID:101})},$($bad[6])))" 1 'check: hour line whose assignment is not a Project Workers row of this project blocks'
Assert-Eval "CountRows(With({colWrPendKeys:Table({WorkerID:1,ContractorID:10},{WorkerID:77,ContractorID:10},{WorkerID:1,ContractorID:If(false,1)})},$($bad[8])))" 2 'check: worker missing in Workers, or period worker without contractor, blocks (no reconstruction)'
Assert-Eval "Concat(With({colWrPendPW:Table({ID:101,WorkerID:1,ProjectID:7,AssignmentKey:`"7|1`"},{ID:102,WorkerID:2,ProjectID:7,AssignmentKey:`"7|3`"},{ID:103,WorkerID:3,ProjectID:7,AssignmentKey:`"`"},{ID:104,WorkerID:4,ProjectID:7,AssignmentKey:`"70|4`"},{ID:105,WorkerID:If(false,1),ProjectID:7,AssignmentKey:`"7|5`"})},$($bad[1])),Text(ID),`",`")" '102,103,104,105' 'check (re-review 2): Project Workers AssignmentKey must equal project|worker (other worker, blank key, other project prefix, blank worker block)'
Assert-Eval "Concat(With({colWrPendPeriods:Table({ID:1,AssignmentKey:`"`",From:Date(2026,11,1)},{ID:2,AssignmentKey:`"70|1`",From:Date(2026,11,1)},{ID:3,AssignmentKey:`"7|1`",From:Date(2026,11,1)})},$($bad[2])),Text(ID),`",`")" '2' 'check (re-review 1): other-project period check skips blank keys (a blank key is reported by the period-data check)'
Assert-Eval "Concat(With({colWrPendPeriods:Table({ID:1,AssignmentKey:`"7|1`",From:If(false,Date(2026,1,1))},{ID:2,AssignmentKey:`"`",From:Date(2026,11,1)},{ID:3,AssignmentKey:`"7|2`",From:Date(2026,11,1)})},$($bad[3])),Text(ID),`",`")" '1,2' 'check (review 3): period with blank From or blank AssignmentKey blocks'
Assert-Eval "Concat(With({colWrPendPW:Table({ID:101,WorkerID:1,AssignmentKey:`"7|1`"},{ID:102,WorkerID:2,AssignmentKey:`"7|2`"}),colWrPendPeriods:Table({ID:1,AssignmentKey:`"7|1`"},{ID:2,AssignmentKey:`"7|9`"},{ID:3,AssignmentKey:`"`"},{ID:4,AssignmentKey:`"7|2`"})},$($bad[4])),AssignmentKey,`",`")" '7|9' 'check (review 1): period without a Project Workers link (no link with project|worker = AssignmentKey) blocks and names the key; blank keys are left to the period-data check'
Assert-Eval "Concat(With({colWrPendPW:Table({ID:102,WorkerID:2,AssignmentKey:`"7|2`"},{ID:200,WorkerID:8,AssignmentKey:`"`"}),colWrPendHours:Table({HourID:1,EntryKey:`"7|2|20261109`",AssignmentID:102,WorkDay:Date(2026,11,9)},{HourID:2,EntryKey:`"7|3|20261109`",AssignmentID:102,WorkDay:Date(2026,11,9)},{HourID:3,EntryKey:`"7|20|20261109`",AssignmentID:102,WorkDay:Date(2026,11,9)},{HourID:4,EntryKey:`"7|8|20261109`",AssignmentID:200,WorkDay:Date(2026,11,9)},{HourID:5,EntryKey:`"7|9|20261109`",AssignmentID:999,WorkDay:Date(2026,11,9)},{HourID:6,EntryKey:`"7|2|20261110`",AssignmentID:102,WorkDay:Date(2026,11,9)},{HourID:7,EntryKey:`"7|2|20261109|x`",AssignmentID:102,WorkDay:Date(2026,11,9)},{HourID:8,EntryKey:`"7|2|20261115`",AssignmentID:102,WorkDay:Date(2026,11,15)})},$($bad[7])),Text(HourID),`",`")" '2,3,4,6,7' 'check (review 2 + re-review 3): EntryKey must equal link AssignmentKey & "|" & yyyymmdd of Work Date (other worker, look-alike 7|20, blank link key, wrong date suffix, extra suffix block); an unknown assignment is left to the assignment check'
$pwFx = ($steps | Where-Object Target -eq 'colWrPendPeriodWorkers').Expr
Assert-Eval "Concat(With({colWrPendPW:Table({ID:101,WorkerID:1},{ID:102,WorkerID:2}),colWrPendPeriods:Table({AssignmentKey:`"7|1`",From:If(false,Date(2026,1,1)),Until:If(false,Date(2026,1,1))},{AssignmentKey:`"7|2`",From:Date(2026,11,1),Until:If(false,Date(2026,1,1))})},$pwFx),Text(WorkerID),`",`")" '2' 'review 3: a period with blank From never counts as overlapping'
$wkOpen = $loader.IndexOf('ForAll(Workers As w,') + 'ForAll'.Length
$wkRec = (Split-Args (Get-Balanced $loader $wkOpen))[1].Trim()
foreach ($c in @(@('Nederlands', 'Dutch'), @(' Nederlands ', 'Dutch'), @('Dutch', 'Dutch'), @('Polish', 'Polish'), @('', ''))) {
    Assert-Eval "With({w:{ID:1,'First Name':`"A`",Surname:`"B`",'Worker Code':`"`",Trade:{Value:`"Fitter`"},Employer:{Id:10,Value:`"Alpha BV`"},Language:{Value:`"$($c[0])`"}}},$wkRec).Language" $c[1] "review 4: Workers.Language '$($c[0])' read as '$($c[1])' (legacy Nederlands = Dutch, never 'Dutch + Nederlands')"
}
# ISO year/week label (same formula as Hours Summary colReportFacts) and the picker Monday
$kwFx = (P 'lblWrWeekKW.Text').Substring(1)
$mondayFx = [regex]::Match($pickOc, 'monday:(DateAdd\(selectedDay,1-Weekday\(selectedDay,StartOfWeek\.Monday\),TimeUnit\.Days\))').Groups[1].Value
Assert-True ($mondayFx.Length -gt 0) 'picker Monday formula found'
foreach ($c in @(@('Date(2027,1,1)', '2026 KW53'), @('Date(2026,12,28)', '2026 KW53'), @('Date(2027,1,3)', '2026 KW53'), @('Date(2027,1,4)', '2027 KW01'), @('Date(2026,1,1)', '2026 KW01'), @('Date(2025,12,29)', '2026 KW01'), @('Date(2021,1,3)', '2020 KW53'), @('Date(2026,11,12)', '2026 KW46'))) {
    Assert-Eval "With({varWrMonday:With({selectedDay:$($c[0])},$mondayFx)},$kwFx)" $c[1] "week label for $($c[0]) = $($c[1])"
}
$subFx = (P 'lblWrTableSub.Text').Substring(1)
Assert-Eval "With({varWrLoadState:`"Loaded`",varWrLoadedMonday:Date(2026,12,28),varWrLoadedProject:{Reference:`"REF-1`"}},$subFx)" "2026 KW53  $([char]0xB7)  28-12-2026 $([char]0x2013) 03-01-2027  $([char]0xB7)  Project Reference: REF-1" 'table subtitle: loaded week label + date range + project reference'
# zero and empty shown as an en dash; whole hours without separator; max 2 decimals (the [$-en-US] format tag is stripped for the interpreter)
$cellFx = (P 'lblWrCellMon.Text').Substring(1)
Assert-True ($cellFx -ceq 'If(Coalesce(ThisItem.D1,0)=0,"' + [char]0x2013 + '",Text(ThisItem.D1,If(ThisItem.D1=Round(ThisItem.D1,0),"[$-en-US]0","[$-en-US]0.##"),"nl-NL"))') 'day cell format: "–" for 0/empty; whole hours without separator, max 2 decimals ("0.##" per AGENTS; Hours Summary itself uses "0.00"); nl-NL with the [$-en-US] format tag as in Hours Summary'
$cellI = $cellFx.Replace('[$-en-US]', '')
foreach ($c in @(@('0', [string][char]0x2013), @('If(false,0)', [string][char]0x2013), @('8', '8'), @('7.5', '7,5'), @('7.25', '7,25'), @('10', '10'), @('2.333', '2,33'))) { Assert-Eval "With({ThisItem:{D1:$($c[0])}},$cellI)" $c[1] "day value $($c[0]) shown as '$($c[1])'" }
$totFx = (P 'lblWrCellTotal.Text').Substring(1).Replace('[$-en-US]', '')
Assert-Eval "With({ThisItem:{WeekTotal:0}},$totFx)" ([string][char]0x2013) 'week total 0 shown as "–" (the row itself stays)'
for ($k = 1; $k -le 7; $k++) { $d = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')[$k - 1]; Assert-True ((P "lblWrCell$d.Text").Contains("ThisItem.D$k") -and (P "lblWrHdr$d.Text").Contains("T.wrDay$d.en") -and (P "lblWrHdr$d.Text").Contains("DateAdd(varWrLoadedMonday,$($k-1),TimeUnit.Days),""dd-mm"")") -and (P "lblWrCell$d.Align") -eq '=Align.Center') "column $d : header day + dd-mm of the loaded week, value D$k centred" }
# contractor filter on the committed lines (gallery Items and Height use the same filter)
$wrEngine.UpdateVariable('colWrLines', (Eval-Fx 'Sort(colWrPendLines,SortKey)'))
Run-Pipeline 'P-1000'; $wrEngine.UpdateVariable('colWrLines', (Eval-Fx 'Sort(colWrPendLines,SortKey)'))
$itemsFx = (P 'galWrLines.Items').Substring(1)
Assert-True ((P 'galWrLines.Height') -ceq "=44*CountRows($itemsFx)") 'gallery Height = 44 x the same filtered lines (no internal scroll)'
Assert-Eval "With({varWrContractorID:0},CountRows($itemsFx))" 10 'All contractors: all groups + grand total (10 lines)'
Assert-Eval "With({varWrContractorID:20},Concat($itemsFx,LineType,`",`"))" 'Header,Row,Row,Subtotal' 'one contractor: its header, rows and subtotal, no grand total'
Assert-True ((P 'galWrLines.TemplateFill') -ceq '=Switch(ThisItem.LineType,"Header",Color.White,"Subtotal",ColorValue("#D5EDFF"),"Grand",ColorValue("#D5EDFF"),If(ThisItem.Zebra,ColorValue("#F0F0F0"),ColorValue("#FFFFFF")))' -and (P 'recWrLineRule.Fill') -eq '=ColorValue("#DCDCDC")' -and (P 'lblWrHdrName.Fill') -eq '=ColorValue("#0303B8")' -and (P 'lblWrHdrName.Color') -eq '=Color.White') 'table styling: header #0303B8 white, zebra #FFFFFF/#F0F0F0, lines #DCDCDC, subtotal/total #D5EDFF'
Assert-True ((P 'lblWrCellName.Tooltip') -eq '=If(ThisItem.LineType="Row",ThisItem.Code,"")' -and $loader.Contains('WorkerCode:If(IsBlank(w.Code),"WKR-" & Text(k.WorkerID,"000"),w.Code)') -and $loader.Contains('EmployerCode:If(IsBlank(e.Code),"EMP-" & Text(k.ContractorID,"000"),e.Code)')) 'WorkerID/EmployerCode kept in the row record (phase C), Worker Code as tooltip on the name'
Write-Output 'Test-WeekReport: structure, no mutations, reads/predicates, 500 guards, staging commit, guard parity and the row/language/TEST/ISO/format rules verified locally.'
Write-Output 'NOT verified locally: Studio import and binding, delegation of the reads (Monitor), ModernDatePicker Reset/DefaultDate behaviour, rendering and text clipping, real SharePoint data.'
