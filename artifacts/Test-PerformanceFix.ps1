$ErrorActionPreference='Stop'
# Local checks for the loading fix of 21 Oct 2026 (worker/project cache, ProjectKey/EntryKey prefix filters, cache reuse).
# Parser/regression first, then: (A) diff against the checkpoint, (B) source invariants, (C) Power Fx logic with synthetic data.
# No SharePoint, Studio, delegation or timing claim: the server queries must be confirmed in Monitor.
. (Join-Path $PSScriptRoot 'Test-SaveRegression.ps1')
$backup=Join-Path $projectRoot (Get-Content (Join-Path $PSScriptRoot 'performance-fix-backup.txt') -Raw).Trim()
function Fail($m){throw "FAIL $m"}
function Pass($m){Write-Output "PASS $m"}

# (A) Diff: only the loaders, navigation traces, refresh flags, worker gallery and title-bar lookup may change.
$allowed=@{
 'Screen1'=@{'Gallery1'=@('Items');'btnReadTeam'=@('OnSelect');'btnAddtoTeam'=@('OnSelect');'btnGotoHours'=@('OnSelect');'btnGotoHoursSummary'=@('OnSelect')}
 'scrHours'=@{'btnReadWeek'=@('OnSelect');'btnRefreshWeek'=@('OnSelect')}
 'scrWeeklyHours'=@{'btnLoadReport'=@('OnSelect');'btnBuildReport'=@('OnSelect');'lblReportProjectDetails'=@('Text');'btnRefreshReport'=@('OnSelect')}
}
foreach($name in @('App.pa.yaml','_EditorState.pa.yaml')){if((Get-FileHash (Join-Path $backup "Src/$name")).Hash -ne (Get-FileHash (Join-Path $projectRoot "Src/$name")).Hash){Fail "unexpected change $name"}}
$olds=@{};$oldScreens=@{}
foreach($screen in $allowed.Keys){
 $doc=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $backup "Src/$screen.pa.yaml")))
 $oldScreens[$screen]=$doc['Screens'][$screen]['Properties']
 $o=@{};Index-RegressionControls $doc['Screens'][$screen]['Children'] $o;$olds[$screen]=$o;$n=$indexes[$screen]
 foreach($name in @($o.Keys)+@($n.Keys)|Select-Object -Unique){
  if(!$o.ContainsKey($name) -or !$n.ContainsKey($name)){Fail "control added/removed $screen.$name"}
  foreach($key in @($o[$name]['Properties'].Keys)+@($n[$name]['Properties'].Keys)|Select-Object -Unique){
   if($o[$name]['Properties'][$key] -cne $n[$name]['Properties'][$key] -and !($allowed[$screen].ContainsKey($name) -and $key -in $allowed[$screen][$name])){Fail "unexpected change $screen.$name.$key"}
  }
 }
 $newDoc=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot "Src/$screen.pa.yaml")))
 foreach($key in @($oldScreens[$screen].Keys)+@($newDoc['Screens'][$screen]['Properties'].Keys)|Select-Object -Unique){
  if($oldScreens[$screen][$key] -cne $newDoc['Screens'][$screen]['Properties'][$key] -and $key -ne 'OnVisible'){Fail "unexpected screen change $screen.$key"}
 }
}
Pass 'diff limited to loaders, OnVisible, refresh flags, navigation traces, worker gallery Items and title-bar lookup; App/_EditorState byte-equal.'
function P($s,$c,$p){[string]$indexes[$s][$c]['Properties'][$p]}
function OldP($s,$c,$p){[string]$olds[$s][$c]['Properties'][$p]}
# Save week byte-equal; Save team differs only by no longer forcing a master reload after a successful save.
if((P 'scrHours' 'btnSaveWeek' 'OnSelect') -cne (OldP 'scrHours' 'btnSaveWeek' 'OnSelect')){Fail 'Save week changed'}
if((OldP 'Screen1' 'btnAddtoTeam' 'OnSelect').Replace('Set(varTeamDirty,false); Set(varForceTeamRefresh,true); Set(varTeamLoadState,"NotLoaded")','Set(varTeamDirty,false); Set(varTeamLoadState,"NotLoaded")') -cne (P 'Screen1' 'btnAddtoTeam' 'OnSelect')){Fail 'Save team changed beyond the post-save reload flag'}
if((P 'Screen1' 'btnAddtoTeam' 'DisplayMode') -cne (OldP 'Screen1' 'btnAddtoTeam' 'DisplayMode')){Fail 'Save team guard changed'}
Pass 'Save week byte-equal; Save team guard equal, only Set(varForceTeamRefresh,true) after success removed (reload re-reads Project Workers, not all masters).'
$traceRx='Trace\("DIAG\|[^"]+",TraceSeverity\.Information,\{[^{}]*\}\);\s*'
$b=[regex]::Replace((P 'scrWeeklyHours' 'btnBuildReport' 'OnSelect'),'\r?\n[ ]*Trace\("DIAG\|[^"]+",TraceSeverity\.Information,\{[^{}]*\}\);','').Replace(' Set(varDiagBuildT0,Now());','')
if($b -cne (OldP 'scrWeeklyHours' 'btnBuildReport' 'OnSelect')){Fail 'Build changed beyond trace/timer'}
foreach($pair in @(@('Screen1','btnGotoHoursSummary'),@('Screen1','btnGotoHours'))){
 $x=[regex]::Replace((P $pair[0] $pair[1] 'OnSelect'),$traceRx,'').Replace("`n                              Navigate","`n                              `n                              Navigate").Replace("Set(varTeam, ddTeam.Selected);`n                              `n","Set(varTeam, ddTeam.Selected);`n                              `n")
 if(([regex]::Replace($x,'\s','')) -cne ([regex]::Replace((OldP $pair[0] $pair[1] 'OnSelect'),'\s',''))){Fail "$($pair[1]) changed beyond trace"}
}
if((P 'scrWeeklyHours' 'lblReportProjectDetails' 'Text').Replace('colReportProjects,','Projects,') -cne (OldP 'scrWeeklyHours' 'lblReportProjectDetails' 'Text')){Fail 'title-bar text changed beyond the lookup source'}
if((P 'scrWeeklyHours' 'lblReportProjectDetails' 'Text') -notmatch "'Project Number'[\s\S]*'Project Reference'"){Fail 'Project Number/Reference order'}
Pass 'Build, navigation and title-bar formulas equal apart from Trace/timer and the local lookup (Number before Reference kept).'

# (B) Source invariants of the loaders.
$team=P 'Screen1' 'btnReadTeam' 'OnSelect';$week=P 'scrHours' 'btnReadWeek' 'OnSelect';$report=P 'scrWeeklyHours' 'btnLoadReport' 'OnSelect'
foreach($pair in @(@('team',$team),@('week',$week),@('report',$report))){
 $fx=$pair[1]
 if($fx -match 'LookUp\(\s*(Workers|Projects|Hours|''Project Workers'')'){Fail "$($pair[0]) loader still has a remote LookUp"}
 if($fx -match 'First\(\s*Workers' -or $fx -match 'Project\.Id\s*=\s*var' -or $fx -match 'Assignment\.Id\s*=\s*(member|assignmentID)'){Fail "$($pair[0]) loader still has a non-delegable source filter"}
 foreach($m in [regex]::Matches($fx,"Filter\('Project Workers',([^\r\n]+)")){if($m.Groups[1].Value -notmatch '^ProjectKey=var\w+ProjectKey( && Team\.Value=var\w+ && Active=true)?\)' -or $m.Groups[1].Value -match 'StartsWith|\|\|'){Fail "$($pair[0]) assignment filter not the plain delegable ProjectKey filter: $($m.Groups[1].Value)"}}
 # 22-10-2026: prefix is a global Set variable (var...QueryPrefix) instead of a With name (delegation warning in Studio).
 foreach($m in [regex]::Matches($fx,'Filter\(Hours,([^\r\n]{0,60})')){if($m.Groups[1].Value -notmatch '^StartsWith\(EntryKey,var\w+QueryPrefix\)'){Fail "$($pair[0]) hours filter not on EntryKey prefix: $($m.Value)"}}
 if($fx -match 'Filter\(Hours' -and $fx -notmatch 'Set\(var\w+QueryPrefix,var\w+ProjectKey & "\|"\)'){Fail "$($pair[0]) project prefix without closing separator"}
}
if(([regex]::Matches($team+$week+$report,"Filter\('Project Workers'")).Count -ne 3){Fail 'expected exactly three assignment queries'}
Pass 'loaders: no remote LookUp/First(Workers); assignments via plain ProjectKey = precomputed key (no OR/StartsWith); hours via EntryKey prefix "<projectID>|" (+ Work Date where a window is used).'
foreach($pair in @(@('team',$team,'colPendingTeamAssignments'),@('week',$week,'colPendingWeekAssignments'),@('report',$report,'colReportAssignments'))){
 if($pair[1] -notmatch "CountRows\($($pair[2])\)>=500"){Fail "$($pair[0]) 500 guard on assignments missing"}
 if($pair[1] -notmatch "CountIf\($($pair[2]),Project\.Id<>var\w+\)>0"){Fail "$($pair[0]) Project.Id cross-check missing"}
}
foreach($g in @('CountRows(batch)<500','CountIf(colPendingWeekProjectHours,WorkDay>=dayFrom && WorkDay<dayUntil)>=500')){if($week.IndexOf($g) -lt 0){Fail "week batch guard $g missing"}}
foreach($g in @('CountRows(batch)<500','CountRows(monthBatch)<500','CountRows(dayBatch)>=500','!(AssignmentID in ShowColumns(colReportAssignments,ID))','CountRows(Distinct(colReportHourStaging,HourID))')){if($report.IndexOf($g) -lt 0){Fail "report guard $g missing"}}
foreach($pair in @(@('team',$team),@('report',$report))){if($pair[1] -notmatch 'CountRows\(colPendingWorkers\)>=500'){Fail "$($pair[0]) worker cache 500 guard missing"}}
Pass '500 guards: assignments, workers, week batch -> 7 day batches, report batch -> month -> day batches; full batch at the last level blocks; Project.Id, assignment membership and HourID cross-checks present.'
if(($team+$report) -match 'ShowColumns\((Workers|Sort\(Projects)'){Fail 'ShowColumns on a SharePoint source would give logical column names (field_2...) in the cache'}
$wsel=[regex]::Matches($team+$report,"ForAll\(Workers As worker,\{[^}]*\}\)")|ForEach-Object Value|Select-Object -Unique
if(!$wsel){Fail 'worker cache projection not found'}
$psel=[regex]::Matches($team+$report,"ForAll\(Sort\(Projects,Title,SortOrder\.Ascending\) As project,\{[^}]*\}\)")|ForEach-Object Value|Select-Object -Unique
if(@($wsel).Count -ne 1 -or @($psel).Count -ne 1){Fail 'worker/project cache columns differ between Screen1 and Hours Summary'}
foreach($c in @("ID:worker.ID","'First Name':worker.'First Name'","Surname:worker.Surname","'Employer Name':worker.'Employer Name'","Employer:worker.Employer")){if($wsel -notmatch [regex]::Escape($c)){Fail "worker cache misses $c"}}
foreach($c in @('ID:project.ID','Title:project.Title',"'Project Number':project.'Project Number'","'Project Reference':project.'Project Reference'")){if($psel -notmatch [regex]::Escape($c)){Fail "project cache misses $c"}}
if((P 'Screen1' 'Gallery1' 'Items') -ne '=colWorkersCache'){Fail 'Gallery1 not on worker cache'}
Pass "one worker cache shape ($wsel) and one project cache shape used by both screens; Gallery1 shows the cache."
# Cache reuse: skip only for a complete Loaded state of the same selection and not on explicit refresh.
if($team -notmatch '^=If\(!Coalesce\(varSelectionBusy,false\) && !Coalesce\(varSaving,false\),\s*If\(!Coalesce\(varForceTeamRefresh,false\) && Coalesce\(varMastersReady,false\) && Coalesce\(varWorkersCacheReady,false\) && varTeamLoadState="Loaded" && Coalesce\(varSelectionLoaded,false\) && IsEmpty\(colSelectionLoadErrors\)'){Fail 'team cache-hit gate'}
if($week -notmatch '^=If\(JSON\(ShowColumns' -or $week -notmatch 'If\(!varWeekLoading && !varWeekSaving,\s*If\(!Coalesce\(varWeekForceRefresh,false\) && varWeekLoadState="Loaded" && Coalesce\(varWeekReady,false\) && IsEmpty\(colWeekLoadErrors\)[\s\S]*Coalesce\(varWeekLoadedTeamVersion,-1\)=Coalesce\(varTeamDataVersion,0\),'){Fail 'week cache-hit gate'}
if($team -notmatch 'Set\(varTeamDataVersion,Coalesce\(varTeamDataVersion,0\)\+1\)' -or $week -notmatch 'Set\(varWeekLoadedTeamVersion,Coalesce\(varTeamDataVersion,0\)\)'){Fail 'team version link'}
if((P 'scrHours' 'btnRefreshWeek' 'OnSelect') -notmatch 'Set\(varWeekForceRefresh,true\); Select\(btnReadWeek\)' -or (P 'scrWeeklyHours' 'btnRefreshReport' 'OnSelect') -notmatch 'Set\(varReportForceRefresh,true\); Select\(btnLoadReport\)'){Fail 'explicit refresh flags'}
if((P 'Screen1' 'btnRefreshTeam' 'OnSelect') -notmatch 'Set\(varForceTeamRefresh,true\); Select\(btnReadTeam\)'){Fail 'team refresh flag'}
if($week -notmatch 'If\(IsEmpty\(colWeekLoadErrors\) && \(Coalesce\(varWeekForceRefresh,false\) \|\| !Coalesce\(varEntryYearsLoaded,false\)\)'){Fail 'year range cache'}
if($report -notmatch 'If\(IsEmpty\(colReportLoadErrors\) && \(Coalesce\(varReportForceRefresh,false\) \|\| !Coalesce\(varWorkersCacheReady,false\)\)'){Fail 'report worker cache reuse'}
$s1=[string]$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/Screen1.pa.yaml')))['Screens']['Screen1']['Properties']['OnVisible']
if($s1 -notmatch 'If\(!Coalesce\(varTeamDirty,false\) && !cacheValid,Select\(btnReadTeam\)\)'){Fail 'Screen1.OnVisible still reloads a valid selection'}
Pass 'cache reuse: same complete Loaded selection is skipped (Screen1.OnVisible and the loaders); Refresh buttons force; team reload bumps a version that invalidates Weekly Hours; Weekly Hours dirty gate stays first.'
foreach($pair in @(@('team',$team),@('week',$week),@('report',$report))){foreach($w in @('Patch','UpdateIf','RemoveIf','Remove','SubmitForm')){if($pair[1] -match "\b$w\s*\("){Fail "$($pair[0]) loader mutates ($w)"}}}
$traces=([regex]::Matches(($team+$week+$report+(P 'scrWeeklyHours' 'btnBuildReport' 'OnSelect')+$s1),'Trace\("DIAG\|')).Count
Pass "no Patch/Update/Remove in loaders; $traces DIAG Trace markers in the loaders/OnVisible (plus navigation)."

# (C) Logic with synthetic data (interpreter; Text language placeholders replaced, Canvas collections replaced by tables).
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$e=New-Object Microsoft.PowerFx.RecalcEngine;$opt=New-Object Microsoft.PowerFx.ParserOptions;$opt.Culture=[Globalization.CultureInfo]::GetCultureInfo('en-US')
function Ev($fx){$v=$e.Eval($fx,$null,$opt);if($v -is [Microsoft.PowerFx.Types.ErrorValue]){throw ($v.Errors|Out-String)};$v.Value}
function Eq($fx,$exp,$label){$v=Ev $fx;if($v -ne $exp){Fail "$label : expected $exp, got $v"};Pass "$label = $v"}
Eq 'StartsWith("10|5|20261019","1" & "|")' $false 'project 1 prefix does not match project 10'
Eq 'StartsWith("1|5|20261019","1" & "|")' $true 'project 1 prefix matches its own key'
Eq 'StartsWith("11|1|20261019","1" & "|")' $false 'project 1 prefix does not match project 11'
$data=@'
assignments:Table({ID:101,Project:{Id:1},Worker:{Id:5},AssignmentKey:"1|5",Active:true},{ID:102,Project:{Id:1},Worker:{Id:6},AssignmentKey:"1|6",Active:false},{ID:110,Project:{Id:10},Worker:{Id:5},AssignmentKey:"10|5",Active:true}),
hours:Table({ID:1,Assignment:{Id:101},EntryKey:"1|5|20261019",WorkDate:Date(2026,10,19),Hours:8},{ID:2,Assignment:{Id:101},EntryKey:"1|5|20261020",WorkDate:Date(2026,10,20),Hours:7.5},{ID:3,Assignment:{Id:102},EntryKey:"1|6|20251231",WorkDate:Date(2025,12,31),Hours:4},{ID:4,Assignment:{Id:110},EntryKey:"10|5|20261019",WorkDate:Date(2026,10,19),Hours:9},{ID:5,Assignment:{Id:110},EntryKey:"10|5|20270104",WorkDate:Date(2027,1,4),Hours:3})
'@
$old='Sum(Filter(hours,Assignment.Id in ShowColumns(Filter(assignments,Project.Id=1),ID)),Hours)'
$new='Sum(Filter(hours,StartsWith(EntryKey,"1" & "|")),Hours)'
Eq "With({$data},$old)" 19.5 'old per-assignment total project 1 (incl. inactive history)'
Eq "With({$data},$new)" 19.5 'new EntryKey-prefix total project 1'
Eq "With({$data},Sum(Filter(hours,StartsWith(EntryKey,""10"" & ""|"")),Hours))" 12 'new EntryKey-prefix total project 10'
Eq "With({$data},CountRows(Filter(hours,StartsWith(EntryKey,""1|"") && WorkDate>=Date(2026,10,19) && WorkDate<Date(2026,10,26))))" 2 'project 1 week 2026 KW43 window'
$bad=$data.Replace('{ID:5,Assignment:{Id:110},EntryKey:"10|5|20270104"','{ID:5,Assignment:{Id:110},EntryKey:"1|5|20270104"')
Eq "With({$bad},CountIf(Filter(hours,StartsWith(EntryKey,""1|"")),!(Assignment.Id in ShowColumns(Filter(assignments,StartsWith(AssignmentKey,""1|"")),ID))))" 1 'report blocks a project-1 key on a project-10 assignment'
$mc=[regex]::Match($report,'monthCount:([^}\r\n]+)\}').Groups[1].Value
if(!$mc){Fail 'monthCount formula not found'}
foreach($c in @(@('2026,10,5','2026,10,20',1),@('2026,12,28','2027,1,3',2),@('2025,11,15','2027,2,1',16),@('2020,12,31','2021,1,1',2))){
 $fx="With({firstHour:{'Work Date':Date($($c[0]))},lastHour:{'Work Date':Date($($c[1]))}},With({firstMonth:Date(Year(firstHour.'Work Date'),Month(firstHour.'Work Date'),1),monthCount:$mc},"
 Eq ($fx+'monthCount))') $c[2] "months $($c[0]) .. $($c[1])"
 Eq ($fx+"CountRows(Filter(Sequence(monthCount) As m,lastHour.'Work Date'>=DateAdd(firstMonth,m.Value-1,TimeUnit.Months) && lastHour.'Work Date'<DateAdd(firstMonth,m.Value,TimeUnit.Months)))+CountRows(Filter(Sequence(monthCount) As m,firstHour.'Work Date'>=DateAdd(firstMonth,m.Value-1,TimeUnit.Months) && firstHour.'Work Date'<DateAdd(firstMonth,m.Value,TimeUnit.Months)))))") 2 "first and last day each in exactly one month window $($c[0]) .. $($c[1])"
}
Eq 'With({monthFrom:Date(2028,2,1),monthUntil:Date(2028,3,1)},CountRows(Sequence(DateDiff(monthFrom,monthUntil,TimeUnit.Days))))' 29 'leap February gives 29 day windows'
Eq 'With({dateFrom:Date(2026,12,28)},CountRows(Filter(Sequence(7) As d,DateAdd(dateFrom,d.Value,TimeUnit.Days)=DateAdd(dateFrom,d.Value-1,TimeUnit.Days)+1)))' 7 'week paging: 7 consecutive one-day windows'
$keyFx=[regex]::Match($week,'CountIf\(colPendingWeekStored As stored,[^\r\n]+?\)>0').Value.Replace('"[$-en-US]yyyymmdd"','"yyyymmdd"')
if(!$keyFx){Fail 'week key cross-check not found'}
$keyData='colPendingWeekAssignments:Table({ID:101,AssignmentKey:"1|5"}),colPendingWeekStored:Table({AssignmentID:101,WorkDay:Date(2026,10,19),EntryKey:"1|5|20261019"})'
Eq "With({$keyData},$keyFx)" $false 'week key cross-check accepts AssignmentKey|yyyymmdd'
Eq "With({$($keyData.Replace('EntryKey:"1|5|20261019"','EntryKey:"1|5|20261020"'))},$keyFx)" $true 'week key cross-check flags key with another date (read-only)'
Eq "With({$($keyData.Replace('EntryKey:"1|5|20261019"','EntryKey:Blank()'))},$keyFx)" $true 'week key cross-check flags missing key'
# Worker chain: Workers -> projection in the loader -> gallery/selection -> Save team title, with the projection taken from the source.
$wfx=[string]$wsel
$src='Table({ID:5,''First Name'':"Jan",Surname:"de Vries",''Employer Name'':"Alfa BV",Employer:{Id:3,Value:"Alfa BV"},Trade:{Value:"F"}})'
Eq ("With({Workers:$src},With({cache:$wfx},Left(Trim(First(cache).'First Name' & "" "" & First(cache).Surname) & "" | "" & ""P1"",255)))") 'Jan de Vries | P1' 'Save team title from cached worker record'
Eq ("With({Workers:$src},With({cache:$wfx},First(cache).'Employer Name' & ""/"" & Text(First(cache).Employer.Id)))") 'Alfa BV/3' 'employer name and employer ID kept separately'
Eq ("With({Workers:$src},With({cache:$wfx},With({selected:Filter(cache,ID=5)},CountRows(Filter(cache,ID in ShowColumns(selected,ID))))))") 1 'selection by worker ID from the same cache'
$pfx=[string]$psel
Eq ("With({Projects:Table({ID:7,Title:""B"",'Project Number':""PN-7"",'Project Reference':""REF-7""},{ID:2,Title:""A"",'Project Number':""PN-2"",'Project Reference':""REF-2""})},With({cache:$pfx},First(cache).Title & "" "" & LookUp(cache,ID=7).'Project Number' & "" "" & LookUp(cache,ID=7).'Project Reference'))") 'A PN-7 REF-7' 'project cache sorted on Title with Number/Reference by display name'
Write-Output 'Local only: delegation ($filter in the request), server paging, Studio binding, real totals and timing must be confirmed with Monitor/online.'
