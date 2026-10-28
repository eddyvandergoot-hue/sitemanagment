$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$regressionEngine=New-Object Microsoft.PowerFx.RecalcEngine
$regressionOptions=New-Object Microsoft.PowerFx.ParserOptions
$regressionOptions.Culture=[Globalization.CultureInfo]::GetCultureInfo('en-US')
function Index-RegressionControls($entries,$index){foreach($entry in $entries){$name=@($entry.Keys)[0];$index[$name]=$entry[$name];Index-RegressionControls $entry[$name]['Children'] $index}}
$indexes=@{};$count=0
foreach($screen in @('scrHome','Screen1','scrHours','scrWeeklyHours','scrContractors')){
 $doc=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot ('Src/'+$screen+'.pa.yaml'))))
 if($screen -ne 'scrWeeklyHours'){Check-Node $doc $screen}
 $index=@{};Index-RegressionControls $doc['Screens'][$screen]['Children'] $index;$indexes[$screen]=$index
 $script:names=@{};$script:controlCount=0;foreach($entry in $doc['Screens'][$screen]['Children']){Check-Control $entry};$count+=$script:controlCount
}
$app=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/App.pa.yaml')));Check-Node $app 'App'
if($script:failures -gt 0){throw 'Formula syntax failed'}
Write-Output "PASS $script:formulas formulas parsed, $count controls checked; no Canvas binding claim."
function Assert-Regression($fx,$expected,$label){
 try { $v=$regressionEngine.Eval($fx,$null,$regressionOptions) } catch { Write-Output $_.Exception.InnerException.ToString(); throw }
 if($v -is [Microsoft.PowerFx.Types.ErrorValue] -or $v.Value -ne $expected){throw "FAIL $label : $($v.ToExpression())"}
 Write-Output "PASS $label"
}
$guards=@{}
foreach($pair in @(@('Screen1','btnAddtoTeam','team'),@('scrHours','btnSaveWeek','week'))){
 $control=$indexes[$pair[0]][$pair[1]]
 $predicate=$control['Properties']['DisplayMode'].Trim().Substring(4)
 $suffix=',DisplayMode.Edit,DisplayMode.Disabled)'
 if(!$predicate.EndsWith($suffix)){throw 'Invalid DisplayMode shape'}
 $predicate=$predicate.Substring(0,$predicate.Length-$suffix.Length)
 if(!$control['Properties']['OnSelect'].StartsWith('=If('+$predicate+',')){throw 'DisplayMode and OnSelect differ'}
 $guards[$pair[2]]=$predicate
}
Write-Output 'PASS same fail-closed predicate at start of both Save OnSelect and DisplayMode.'
$teamFixture=@'
varTeamLoadState:"Loaded",varSelectionLoaded:true,varSelectionKeysValid:true,varSelectionBusy:false,varSaving:false,
colSelectionLoadErrors:Filter(Table({Message:"error"}),false),ddProject:{Selected:{Id:7}},ddTeam:{Selected:{Value:"2"}},
varTeamLoadedProjectID:7,varTeamLoadedTeam:"2",varTeamLoadedAssignmentCount:1,
varTeamLoadedWeekMonday:Date(2026,10,26),varHoursWeekMonday:Date(2026,10,26),varTeamMigrationBlocksSave:false,varTeamPeriodsValid:true,
colCurrentTeamAssignments:Table({ID:12,Worker:{Id:1},Project:{Id:7},Team:{Value:"2"},Active:true}),
colTeamOriginalSelection:Table({ID:1}),colSelectedWorkers:Table({ID:1}),colTeamRemovedIDs:Filter(Table({WorkerID:1}),false)
'@
$weekFixture=@'
varWeekLoadState:"Loaded",varWeekReady:true,varWeekKeyIssue:false,varWeekLoading:false,varWeekSaving:false,
colWeekLoadErrors:Filter(Table({Message:"error"}),false),varLoadedWeekMonday:Date(2020,12,28),varWeekLoadedProjectID:7,varWeekLoadedTeam:"2",
varProject:{Id:7},ddProject:{Selected:{Id:7}},varTeam:{Value:"2"},ddTeam:{Selected:{Value:"2"}},
varWeekLoadedISOYear:2020,varWeekLoadedKW:53,varHoursWeekMonday:Date(2020,12,28),varWeekLoadedAssignmentCount:1,
colWeekRows:Table({ID:12,Project:{Id:7},Team:{Value:"2"},Active:true}),colWeekOriginal:Table({ID:12}),colWeekAssignments:Table({ID:12})
'@
foreach($kind in @('team','week')){
 $fixture=if($kind -eq 'team'){$teamFixture}else{$weekFixture}
 Assert-Regression ('With({'+$fixture+'},'+$guards[$kind]+')') $true "$kind complete matching selection allowed"
 foreach($state in @('NotLoaded','Loading','Failed')){
  Assert-Regression ('With({'+$fixture.Replace('LoadState:"Loaded"',('LoadState:"'+$state+'"'))+'},'+$guards[$kind]+')') $false "$kind $state blocks Save"
 }
 $mismatch=if($kind -eq 'team'){$fixture.Replace('varTeamLoadedProjectID:7','varTeamLoadedProjectID:8')}else{$fixture.Replace('varWeekLoadedProjectID:7','varWeekLoadedProjectID:8')}
 Assert-Regression ('With({'+$mismatch+'},'+$guards[$kind]+')') $false "$kind other project blocks Save"
 $failed=$fixture.Replace('Filter(Table({Message:"error"}),false)','Table({Message:"error"})')
 Assert-Regression ('With({'+$failed+'},'+$guards[$kind]+')') $false "$kind error collection blocks Save even if state stale Loaded"
}
Assert-Regression ('With({'+$teamFixture.Replace('colSelectedWorkers:Table({ID:1})','colSelectedWorkers:Filter(Table({ID:1}),false)')+'},'+$guards.team+')') $false 'Empty team selection without explicit unchecks blocks all deactivation'
# Eddy 26-10-2026: empty selection allowed only if every originally loaded worker was explicitly unchecked (valid, fully loaded week).
$emptyAll=$teamFixture.Replace('colSelectedWorkers:Table({ID:1})','colSelectedWorkers:Filter(Table({ID:1}),false)').Replace('colTeamRemovedIDs:Filter(Table({WorkerID:1}),false)','colTeamRemovedIDs:Table({WorkerID:1})')
Assert-Regression ('With({'+$emptyAll+'},'+$guards.team+')') $true 'Empty selection allowed: all originally loaded workers explicitly unchecked'
Assert-Regression ('With({'+$emptyAll.Replace('varTeamPeriodsValid:true','varTeamPeriodsValid:false')+'},'+$guards.team+')') $false 'Empty selection blocked: periods not valid'
Assert-Regression ('With({'+$emptyAll.Replace('varHoursWeekMonday:Date(2026,10,26)','varHoursWeekMonday:Date(2026,11,2)')+'},'+$guards.team+')') $false 'Empty selection blocked: loaded week differs from picked week'
Assert-Regression ('With({'+$emptyAll.Replace('colSelectionLoadErrors:Filter(Table({Message:"error"}),false)','colSelectionLoadErrors:Table({Message:"error"})')+'},'+$guards.team+')') $false 'Empty selection blocked: load error'
$emptyNothing=$emptyAll.Replace('colTeamOriginalSelection:Table({ID:1})','colTeamOriginalSelection:Filter(Table({ID:1}),false)').Replace('colTeamRemovedIDs:Table({WorkerID:1})','colTeamRemovedIDs:Filter(Table({WorkerID:1}),false)').Replace('varTeamLoadedAssignmentCount:1','varTeamLoadedAssignmentCount:0').Replace('colCurrentTeamAssignments:Table({ID:12,Worker:{Id:1},Project:{Id:7},Team:{Value:"2"},Active:true})','colCurrentTeamAssignments:Filter(Table({ID:12,Worker:{Id:1},Project:{Id:7},Team:{Value:"2"},Active:true}),false)')
Assert-Regression ('With({'+$emptyNothing+'},'+$guards.team+')') $false 'Empty selection blocked: nothing loaded for this week (empty original selection)'
Assert-Regression ('With({'+$emptyNothing.Replace('varTeamLoadState:"Loaded"','varTeamLoadState:"NotLoaded"').Replace('varSelectionLoaded:true','varSelectionLoaded:false')+'},'+$guards.team+')') $false 'Empty selection blocked: never loaded'
$emptyPartial=$emptyAll.Replace('colTeamOriginalSelection:Table({ID:1})','colTeamOriginalSelection:Table({ID:1},{ID:2})').Replace('varTeamLoadedAssignmentCount:1','varTeamLoadedAssignmentCount:2').Replace('colCurrentTeamAssignments:Table({ID:12,Worker:{Id:1},Project:{Id:7},Team:{Value:"2"},Active:true})','colCurrentTeamAssignments:Table({ID:12,Worker:{Id:1},Project:{Id:7},Team:{Value:"2"},Active:true},{ID:13,Worker:{Id:2},Project:{Id:7},Team:{Value:"2"},Active:true})')
Assert-Regression ('With({'+$emptyPartial+'},'+$guards.team+')') $false 'Empty selection blocked: a missing original worker was not explicitly unchecked'
Assert-Regression ('With({'+$emptyAll.Replace('colTeamRemovedIDs:Table({WorkerID:1})','colTeamRemovedIDs:Table({WorkerID:1},{WorkerID:9})')+'},'+$guards.team+')') $false 'Empty selection blocked: removal list contains a worker that was not originally loaded'
Assert-Regression ('With({'+$teamFixture.Replace('colSelectedWorkers:Table({ID:1})','colSelectedWorkers:Table({ID:2})')+'},'+$guards.team+')') $false 'Missing original worker without explicit removal blocks Save'
Assert-Regression ('With({'+$weekFixture.Replace('colWeekOriginal:Table({ID:12})','colWeekOriginal:Filter(Table({ID:12}),false)')+'},'+$guards.week+')') $false 'Missing original hours baseline blocks Save'
Assert-Regression ('With({'+$weekFixture.Replace('varWeekLoadedKW:53','varWeekLoadedKW:52')+'},'+$guards.week+')') $false 'Other loaded week blocks Save'
Assert-Regression ('With({'+$teamFixture.Replace('varTeamLoadedTeam:"2"','varTeamLoadedTeam:"3"')+'},'+$guards.team+')') $false 'Other loaded team blocks Save'
Assert-Regression ('With({'+$weekFixture.Replace('varLoadedWeekMonday:Date(2020,12,28)','varLoadedWeekMonday:Date(2020,12,21)')+'},'+$guards.week+')') $false 'Monday must match loaded ISO year and KW'
Assert-Regression ('With({'+$weekFixture.Replace('varWeekKeyIssue:false','varWeekKeyIssue:true')+'},'+$guards.week+')') $false 'Invalid technical keys block Save'
$explicitRemoval=$teamFixture.Replace('colSelectedWorkers:Table({ID:1})','colSelectedWorkers:Table({ID:2})').Replace('colTeamRemovedIDs:Filter(Table({WorkerID:1}),false)','colTeamRemovedIDs:Table({WorkerID:1})')
Assert-Regression ('With({'+$explicitRemoval+'},'+$guards.team+')') $true 'Explicit user removal with nonempty replacement selection allowed'
$coldTeam=$teamFixture.Replace('varTeamLoadState:"Loaded"','varTeamLoadState:Blank()').Replace('varSelectionLoaded:true','varSelectionLoaded:Blank()').Replace('varTeamLoadedProjectID:7','varTeamLoadedProjectID:Blank()').Replace('Selected:{Id:7}','Selected:{Id:Blank()}')
Assert-Regression ('With({'+$coldTeam+'},'+$guards.team+')') $false 'Cold start team flags and selection cannot enable Save'
$coldWeek=$weekFixture.Replace('varWeekLoadState:"Loaded"','varWeekLoadState:Blank()').Replace('varWeekReady:true','varWeekReady:Blank()').Replace('varLoadedWeekMonday:Date(2020,12,28)','varLoadedWeekMonday:Blank()').Replace('varWeekLoadedISOYear:2020','varWeekLoadedISOYear:Blank()').Replace('varWeekLoadedKW:53','varWeekLoadedKW:Blank()')
Assert-Regression ('With({'+$coldWeek+'},'+$guards.week+')') $false 'Cold start week flags and ISO values cannot enable Save'
Assert-Regression ('With({'+$weekFixture.Replace('colWeekRows:Table({ID:12,Project:{Id:7},Team:{Value:"2"},Active:true})','colWeekRows:Filter(Table({ID:12,Project:{Id:7},Team:{Value:"2"},Active:true}),false)')+'},'+$guards.week+')') $false 'Empty hours rows block Save'
Assert-Regression 'With({colTeamAssignmentsToCheck:Table({Worker:{Id:1}},{Worker:{Id:2}}),colTeamSelectionToSave:Filter(Table({ID:1}),false)},CountRows(Filter(colTeamAssignmentsToCheck As assignment,!(assignment.Worker.Id in ShowColumns(colTeamSelectionToSave,ID)))))' 2 'PREVIOUS code risk reproduced locally: empty selection nominates every loaded assignment for deactivation'
Assert-Regression 'CountRows(Filter(Table({NewHours:8,OldHours:8},{NewHours:Blank(),OldHours:Blank()}),IsBlank(NewHours)<>IsBlank(OldHours) || Coalesce(NewHours,0)<>Coalesce(OldHours,0)))' 0 'Unchanged/blank hours do not become zero changes automatically'
$team=$indexes.Screen1['btnReadTeam']['Properties']['OnSelect'];$week=$indexes.scrHours['btnReadWeek']['Properties']['OnSelect']
foreach($fx in @($team,$week,$indexes.scrWeeklyHours['btnLoadReport']['Properties']['OnSelect'],$indexes.scrWeeklyHours['btnBuildReport']['Properties']['OnSelect'],$indexes.Screen1['btnApplyTeamWeek']['Properties']['OnSelect'],$indexes.Screen1['btnMigratePreview']['Properties']['OnSelect'])){
 if($fx -match '\b(Patch|UpdateIf|RemoveIf|SubmitForm)\s*\('){throw 'Mutation in loader'}
}
if($team -notmatch 'If\(Coalesce\(varTeamDirty,false\)' -or $week -notmatch '^=If\(JSON\(ShowColumns'){throw 'Dirty input gate missing'}
# 26-10-2026 Assignment periods: the team loader stages all project assignments + periods and commits them together.
if($team -notmatch 'ClearCollect\(colTeamProjectAssignments,colPendingTeamProjectAssignments\); ClearCollect\(colTeamPeriods,colPendingTeamPeriods\)' -or $week -notmatch 'ClearCollect\(colWeekRows,colPendingWeekRows\)'){throw 'Staged commit missing'}
if($team -match 'Clear\(colSelectedWorkers\)|Clear\(colCurrentTeamAssignments\)' -or $week -match 'Clear\(colWeekRows\)|Clear\(colWeekOriginal\)'){throw 'Loader clears committed user data'}
if($indexes.Screen1['btnAddtoTeam']['Properties']['OnSelect'] -notmatch 'assignment.Worker.Id in ShowColumns\(colTeamRemovedIDs,WorkerID\)'){throw 'Explicit removal gate absent'}
$allowedWrites=@('btnAddtoTeam','btnSaveWeek')
# 26-10-2026: 'Assignment Periods' is written only by Save team (btnAddtoTeam) and the explicit migration confirm (btnMigrateConfirm); never deleted.
$allowedPeriodWrites=@('btnAddtoTeam','btnMigrateConfirm')
foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){foreach($prop in $indexes[$screen][$name]['Properties'].Keys){
 $fx=[string]$indexes[$screen][$name]['Properties'][$prop]
 if($fx -match '\bPatch\(\s*(?:''Project Workers''|Hours)\s*,' -and ($name -notin $allowedWrites -or $prop -ne 'OnSelect')){throw "Unexpected source write: $name.$prop"}
 if($fx -match '\bPatch\(\s*''Assignment Periods''\s*,' -and ($name -notin $allowedPeriodWrites -or $prop -ne 'OnSelect')){throw "Unexpected period write: $name.$prop"}
 if($fx -match '\b(?:Remove|RemoveIf|Update|UpdateIf)\(\s*(?:''Project Workers''|Hours|''Assignment Periods'')\s*,' -or $fx -match '\.Run\('){throw "Unexpected external mutation/flow: $name.$prop"}
 if($fx -match '\bcol(?:Week|Report)Cache\b'){throw 'Nested cache still active'}
}}}
Write-Output 'PASS staged loads, dirty gates, explicit removals, no automatic external writes, nested caches removed.'

# Batch save (22-10-2026): 1 pre-read + table Patch + 1 verify read; guards byte-identical to checkpoint save-batch-20261021_222721.
$baseDir=Join-Path $projectRoot 'checkpoints\save-batch-20261021_222721'
function Assert-True($cond,$label){ if(!$cond){throw "FAIL $label"}; Write-Output "PASS $label" }
function Count-Of($text,$literal){ ([regex]::Matches($text,[regex]::Escape($literal))).Count }
# 22-10-2026 week picker: in the Save week guard the two dropdown checks (ISO year, KW) became one week check. The checkpoint guard with
# exactly this rewrite must equal the current guard byte for byte; fixtures below prove a different picked week blocks.
$weekGuardRewrite=@("varWeekLoadedISOYear=Value(ddHoursYear.Selected.Value),`nvarWeekLoadedKW=Value(ddHoursWeek.Selected.Value),","varLoadedWeekMonday=varHoursWeekMonday,")
# Presentation properties changed by the GEA font/colour steps (checked by Test-Fonts.ps1 / Test-GeaColors.ps1).
$presentationKeys=@('OnSelect','Font','Fill','Color','BorderColor','BorderStyle','BorderThickness','HoverFill','HoverColor','HoverBorderColor','PressedFill','PressedColor','PressedBorderColor','DisabledFill','DisabledColor','DisabledBorderColor','FocusedBorderColor')
foreach($pair in @(@('Screen1','btnAddtoTeam'),@('scrHours','btnSaveWeek'))){
 $doc=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $baseDir ($pair[0]+'.pa.yaml'))))
 $baseIndex=@{};Index-RegressionControls $doc['Screens'][$pair[0]]['Children'] $baseIndex
 $old=$baseIndex[$pair[1]]['Properties'];$new=$indexes[$pair[0]][$pair[1]]['Properties']
 $oldDm=$old['DisplayMode'];$oldOs=$old['OnSelect']
 if($pair[1] -eq 'btnSaveWeek'){
  if(([regex]::Matches($oldDm,[regex]::Escape($weekGuardRewrite[0]))).Count -ne 1 -or ([regex]::Matches($oldOs,[regex]::Escape($weekGuardRewrite[0]))).Count -ne 1){throw 'FAIL checkpoint week guard shape'}
  $oldDm=$oldDm.Replace($weekGuardRewrite[0],$weekGuardRewrite[1]);$oldOs=$oldOs.Replace($weekGuardRewrite[0],$weekGuardRewrite[1])
 }
 # 26-10-2026 Assignment periods (DECISIONS.md H9): documented guard rewrites, each applied exactly once to the checkpoint guard.
 # Rows may now be inactive Project Workers (period overlap or stored hours), so "Active<>true" is dropped from both guards;
 # Save team additionally requires the selection to be computed for the picked week and no pending migration.
 $periodRewrites=@()
 if($pair[1] -eq 'btnSaveWeek'){ $periodRewrites+=,@(' || Team.Value<>varWeekLoadedTeam || Active<>true)=0,',' || Team.Value<>varWeekLoadedTeam)=0,') }else{
  $periodRewrites+=,@(' || Team.Value<>varTeamLoadedTeam || Active<>true)=0,',' || Team.Value<>varTeamLoadedTeam)=0,')
  $periodRewrites+=,@("varTeamLoadedTeam=ddTeam.Selected.Value,`nCountRows(colCurrentTeamAssignments)","varTeamLoadedTeam=ddTeam.Selected.Value,`n!IsBlank(varTeamLoadedWeekMonday),`nvarTeamLoadedWeekMonday=varHoursWeekMonday,`n!Coalesce(varTeamMigrationBlocksSave,true),`nCountRows(colCurrentTeamAssignments)")
  # Eddy 26-10-2026: an empty selection is allowed only when every originally loaded worker was explicitly unchecked.
  $periodRewrites+=,@("`n!IsEmpty(colSelectedWorkers),`n","`n!IsEmpty(colSelectedWorkers) || (!IsEmpty(colTeamOriginalSelection) && Coalesce(varTeamPeriodsValid,false) && CountRows(Distinct(colTeamRemovedIDs,WorkerID))=CountRows(colTeamRemovedIDs) && CountRows(colTeamRemovedIDs)=CountRows(colTeamOriginalSelection) && CountIf(colTeamRemovedIDs,!(WorkerID in ShowColumns(colTeamOriginalSelection,ID)))=0),`n") }
 foreach($rw in $periodRewrites){
  if(([regex]::Matches($oldDm,[regex]::Escape($rw[0]))).Count -ne 1){throw "FAIL checkpoint guard shape for period rewrite: $($rw[0])"}
  $oldDm=$oldDm.Replace($rw[0],$rw[1])
 }
 Assert-True ($oldDm -ceq $new['DisplayMode']) "$($pair[1]) DisplayMode equal to checkpoint (Save week: only ISO year/KW -> picked week; periods: Active check dropped, Save team week/migration terms added)"
 $oldPred=$oldDm.Trim().Substring(4);$oldPred=$oldPred.Substring(0,$oldPred.Length-',DisplayMode.Edit,DisplayMode.Disabled)'.Length)
 Assert-True ($new['OnSelect'].StartsWith('=If('+$oldPred+',')) "$($pair[1]) OnSelect guard equal to checkpoint guard (same rewrite)"
 Assert-True ($oldOs.Split("`n")[-1] -ceq $new['OnSelect'].Split("`n")[-1]) "$($pair[1]) blocked-save Notify unchanged"
 foreach($p in $old.Keys){ if($p -notin $presentationKeys -and $p -ne 'DisplayMode'){ Assert-True ($old[$p] -ceq $new[$p]) "$($pair[1]).$p unchanged" } }
}
Assert-True ($guards.week -notmatch 'ddHours') 'Save week guard has no dropdown references'
Assert-Regression ('With({'+$weekFixture+'},'+$guards.week+')') $true 'Week guard: loaded Monday = picked Monday allows Save'
Assert-Regression ('With({'+$weekFixture.Replace('varHoursWeekMonday:Date(2020,12,28)','varHoursWeekMonday:Date(2021,1,4)')+'},'+$guards.week+')') $false 'Week guard: other picked week blocks Save'
Assert-Regression ('With({'+$weekFixture.Replace('varHoursWeekMonday:Date(2020,12,28)','varHoursWeekMonday:If(false,Date(2000,1,1))')+'},'+$guards.week+')') $false 'Week guard: no picked week blocks Save'
$week=$indexes.scrHours['btnSaveWeek']['Properties']['OnSelect']
# 25-10-2026: the global range Notify 'Gebruik 0 t/m 24 uur, met maximaal twee decimalen.' was replaced by a per-cell collected error (checked in the incident section below).
foreach($msg in @('Open eerst een project, team en werkweek.','Geen gewijzigde uren.','Gebruik 0 om eerder ingevulde uren te corrigeren naar geen gewerkte uren.',
 'De opgeslagen sleutel hoort bij een andere koppeling of werkdatum. Opslaan gestopt; gegevens laten controleren.','Deze uren zijn sinds het laden gewijzigd. Open de week opnieuw.','Deze registratie hoort bij een ander team.',
 'Assignment, Employer, Team of Trade ontbreekt.','Opslaan leverde geen SharePoint-record-ID op.','De opgeslagen registratie kon niet correct worden teruggelezen.','Werkweek opgeslagen en gecontroleerd. ','Niet alles kon worden opgeslagen en gecontroleerd. ','Opslag niet volledig bevestigd. Invoer behouden; controleer SharePoint-versies voordat u verdergaat.')){
 Assert-True ($week.Contains($msg)) "Save week message kept: $msg"
}
Assert-True ($week -notmatch '\bChoices\(') 'Save week has no Choices()'
Assert-True ($week -notmatch "LookUp\(\s*(?:Hours|Workers|'Project Workers'|Employers|Projects)\s*,") 'Save week has no remote LookUp'
Assert-True ((Count-Of $week 'Filter(Hours,') -eq 16) 'Save week Hours reads: pre-read + 7 unrolled day fallbacks + verify + 7 unrolled day fallbacks (16 Filter sites, fallback only at >=500)'
Assert-True ((Count-Of $week 'ClearCollect(colSaveCheckRaw,Filter(Hours,StartsWith(EntryKey,varSaveQueryPrefix) && ''Work Date''>=varSaveQueryFrom && ''Work Date''<varSaveQueryUntil))') -eq 1) 'Single delegable pre-read on EntryKey prefix + week (global vars)'
Assert-True ((Count-Of $week 'ClearCollect(colSaveVerifyRaw,Filter(Hours,StartsWith(EntryKey,varSaveQueryPrefix) && ''Work Date''>=varSaveQueryFrom && ''Work Date''<varSaveQueryUntil))') -eq 1) 'Single delegable verify read with same filter (global vars)'
Assert-True ($week.Contains('Set(varSaveQueryPrefix,Text(varWeekLoadedProjectID) & "|");')) 'Prefix ends with separator and is a global var'
Assert-True ($week.IndexOf('Set(varSaveQueryPrefix') -lt $week.IndexOf('Filter(Hours,')) 'Query vars set before first Hours read'
Assert-True ($week.Contains('CountRows(colSaveCheckRaw)>=500') -and $week.Contains('CountIf(colSaveCheckRaw,''Work Date''>=dayFrom && ''Work Date''<dayUntil)>=500') -and $week.Contains('CountRows(colSaveVerifyRaw)>=500')) '500 guards on pre-read and verify'
Assert-True ((Count-Of $week 'Patch(Hours,') -eq 2 -and (Count-Of $week 'ClearCollect(colHoursPatchedExisting,Patch(Hours,') -eq 1 -and (Count-Of $week 'ClearCollect(colHoursPatchedNew,Patch(Hours,') -eq 1) 'Exactly two table Patch calls (existing / new), no per-cell Patch'
Assert-True ($week.Contains('ForAll(existingRows As u,{Title:u.Title,Hours:u.NewHours})')) 'Existing rows change only Title + Hours (Employer/Team/Trade untouched)'
Assert-True ($week.Contains('Assignment:{Id:n.AssignmentID,Value:n.AssignmentTitle}') -and $week.Contains('Employer:{Id:n.EmployerID,Value:n.EmployerValue}') -and $week.Contains('Team:{Value:n.TeamValue},Trade:{Value:n.TradeValue}')) 'New rows use local {Id,Value}/{Value} records'
Assert-True ($week.Contains('LookUp(colWeekAssignments, ID = c.AssignmentID)') -and $week.Contains('LookUp(colWorkersCache, ID = c.WorkerID)')) 'Lookups from session collections'
$firstPatch=$week.IndexOf('Patch(Hours,')
Assert-True ($week.IndexOf('If(IsEmpty(colHoursErrors) && CountRows(colHoursWritePlan) = CountRows(colHoursChanges),') -lt $firstPatch -and $week.IndexOf('Deze uren zijn sinds het laden gewijzigd.') -lt $firstPatch -and $week.IndexOf('ClearCollect(colSaveCheckRaw') -lt $firstPatch) 'All validation before any write; any error => zero writes'
Assert-True ($week.IndexOf('ClearCollect(colSaveVerifyRaw') -gt $week.LastIndexOf('Patch(Hours,') -and $week.IndexOf('UpdateIf(colWeekOriginal') -gt $week.IndexOf('ClearCollect(colSaveVerifyRaw')) 'Baseline only updated after verify read'
Assert-True ($week.Contains('Trace("DIAG|SaveWeek|End"') -and $week -match 'ElapsedMs:DateDiff\(varDiagSaveT0' -and $week -match 'Changes:CountRows\(colHoursChanges\)' -and $week -match 'Reads:' -and $week -match 'Writes:') 'DIAG trace with ElapsedMs, Changes, Reads, Writes'
# Source predicates evaluated against fixtures (literal text taken from the save formula).
$keyPred='!IsBlank(existing.HourID) && (existing.AssignmentID<>c.AssignmentID || IsBlank(existing.WorkDay) || existing.WorkDay<>workDate)'
Assert-True ($week.Contains($keyPred)) 'Key/date predicate present'
$hoursPredFull='IsBlank(existing.HourValue) <> IsBlank(c.OldHours) || Coalesce(existing.HourValue, 0) <> Coalesce(c.OldHours, 0)'
Assert-True ($week -match [regex]::Escape('IsBlank(existing.HourValue) <> IsBlank(c.OldHours) ||') + '\s*' + [regex]::Escape('Coalesce(existing.HourValue, 0) <> Coalesce(c.OldHours, 0)')) 'Stored-hours predicate present'
$fx='With({existing:{HourID:5,AssignmentID:12,WorkDay:Date(2021,1,4),HourValue:8},c:{AssignmentID:12,OldHours:8},workDate:Date(2021,1,4)},'
Assert-Regression ($fx+$keyPred+')') $false 'Matching assignment/date passes key check'
Assert-Regression ($fx.Replace('AssignmentID:12,W','AssignmentID:13,W')+$keyPred+')') $true 'Other assignment on same EntryKey blocks'
Assert-Regression ($fx.Replace('workDate:Date(2021,1,4)','workDate:Date(2021,1,5)')+$keyPred+')') $true 'Other work date on same EntryKey blocks'
Assert-Regression ($fx+$hoursPredFull+')') $false 'Unchanged stored hours pass'
Assert-Regression ($fx.Replace('HourValue:8','HourValue:7.5')+$hoursPredFull+')') $true 'Hours changed by someone else block'
Assert-Regression ('With({existing:{HourID:Blank(),HourValue:Blank()},c:{OldHours:8}},'+$hoursPredFull+')') $true 'Row deleted by someone else blocks'
Assert-Regression ('With({existing:{HourID:Blank(),HourValue:Blank()},c:{OldHours:Blank()}},'+$hoursPredFull+')') $false 'New cell without stored row passes'
Assert-Regression 'CountRows(Filter(Table({IsNew:true},{IsNew:false},{IsNew:true}),!IsNew))+CountRows(Filter(Table({IsNew:true},{IsNew:false},{IsNew:true}),IsNew))' 3 'Plan split covers every change once'

$teamSave=$indexes.Screen1['btnAddtoTeam']['Properties']['OnSelect']
Assert-True ($teamSave -notmatch "LookUp\(\s*'Project Workers'") 'Save team has no remote LookUp per person/removal'
# 26-10-2026 Assignment periods: Save team = 1 pre-read (Project Workers + Assignment Periods, both by ProjectKey) + up to 4 table Patches
# (PW upsert, new periods, period Until updates, PW deactivation; one schema each) + 1 verify read of both lists.
Assert-True ((Count-Of $teamSave "Filter('Project Workers',") -eq 2 -and $teamSave.Contains("ClearCollect(colTeamSaveCheck,Filter('Project Workers',ProjectKey=varTeamSaveProjectKey))") -and $teamSave.Contains("ClearCollect(colTeamVerifyRaw,Filter('Project Workers',ProjectKey=varTeamSaveProjectKey))")) 'Save team Project Workers: one pre-read + one verify read, ProjectKey = global var (incl. inactive)'
Assert-True ((Count-Of $teamSave "Filter('Assignment Periods',") -eq 2 -and $teamSave.Contains("ClearCollect(colPeriodSaveCheckRaw,Filter('Assignment Periods',ProjectKey=varTeamSaveProjectKey))") -and $teamSave.Contains("ClearCollect(colPeriodVerify,ForAll(Filter('Assignment Periods',ProjectKey=varTeamSaveProjectKey) As p,")) 'Save team Assignment Periods: one pre-read + one verify read, ProjectKey = global var'
Assert-True ($teamSave -notmatch "Filter\('(?:Project Workers|Assignment Periods)',[^)]*StartsWith" -and $teamSave.IndexOf('Set(varTeamSaveProjectKey,Text(varTeamLoadedProjectID));') -ge 0 -and $teamSave.IndexOf('Set(varTeamSaveProjectKey') -lt $teamSave.IndexOf("Filter('Project Workers'") -and $teamSave.IndexOf('Set(varTeamSaveWeekMonday,varTeamLoadedWeekMonday);') -lt $teamSave.IndexOf("Filter('Project Workers'")) 'Save team key/week vars set before pre-read; no StartsWith in source predicates'
Assert-True ($teamSave.Contains('CountRows(colTeamSaveCheck)>=500') -and $teamSave.Contains('CountRows(colPeriodSaveCheckRaw)>=500') -and $teamSave.Contains('CountRows(colTeamVerifyRaw)>=500 || CountRows(colPeriodVerify)>=500') -and $teamSave.Contains('CountIf(colTeamSaveCheck,Project.Id<>varTeamLoadedProjectID)>0')) 'Save team 500 guards (pre-read and verify, both lists) and Project.Id cross-check'
Assert-True ($teamSave.Contains('stored.AssignmentKey = varTeamSaveProjectKey & "|" & Text(row.WorkerID)') -and $teamSave.Contains('AssignmentKey = varTeamSaveProjectKey & "|" & Text(person.ID)) > 1') -and $teamSave.Contains('Filter(colPeriodSaveCheck,AssignmentKey=varTeamSaveProjectKey & "|" & Text(candidate.WorkerID))')) 'Save team local AssignmentKey match on global key (assignments and periods)'
$patchSites=@([regex]::Matches($teamSave,'\bPatch\('))
Assert-True ($patchSites.Count -eq 4 -and (Count-Of $teamSave "ClearCollect(colTeamPatched,Patch(") -eq 1 -and (Count-Of $teamSave "ClearCollect(colTeamDeactivated,Patch(") -eq 1 -and (Count-Of $teamSave "ClearCollect(colPeriodsCreated,Patch('Assignment Periods',") -eq 1 -and (Count-Of $teamSave "ClearCollect(colPeriodsUpdated,Patch('Assignment Periods',") -eq 1) 'Save team exactly four table Patch calls (PW upsert / new periods / period updates / PW deactivate)'
Assert-True ($teamSave.Contains("ForAll(newPeriods As row,Defaults('Assignment Periods')),") -and $teamSave.Contains('ForAll(newPeriods As row,{AssignmentKey:varTeamSaveProjectKey & "|" & Text(row.WorkerID),ProjectKey:varTeamSaveProjectKey,From:varTeamSaveWeekMonday})')) 'New periods: Defaults base, schema {AssignmentKey, ProjectKey, From} (Until blank = open), keys from global project key'
Assert-True ($teamSave.Contains('ForAll(periodUpdates As row,LookUp(colPeriodSaveCheckRaw As stored,stored.ID = row.PeriodID)),') -and $teamSave.Contains('ForAll(periodUpdates As row,{Until:row.NewUntil})')) 'Period updates: pre-read base records, schema {Until} only (set or cleared)'
Assert-True ($teamSave.Contains('ForAll(deactivateRows As removed,{Active: false})') -and $teamSave.Contains('Active: row.ActiveAfter')) 'PW deactivation schema {Active:false}; PW upsert sets Active = has open period after save'
Assert-True ($teamSave -notmatch "\b(?:Remove|RemoveIf)\(\s*'Assignment Periods'") 'Periods are never deleted'
$firstTeamWrite=$teamSave.IndexOf('Set(varDiagTeamSaveWrites,varDiagTeamSaveWrites+1)')
$firstTeamPatch=$teamSave.IndexOf('Patch(')
Assert-True ($firstTeamWrite -gt 0 -and $firstTeamWrite -lt $firstTeamPatch) 'Save team write counter incremented before the first Patch'
foreach($needle in @('Collect(colTeamToDeactivate','JSON(Sort(colTeamPWSnapshot,ID,SortOrder.Ascending))','JSON(Sort(colTeamPeriods,ID,SortOrder.Ascending))','With({decision:With({weekSunday:','With({problem:With({farDate:','If(decision.Action="BLOCK",','Na opslaan zouden 500 of meer periodes bestaan')){
 $i=$teamSave.IndexOf($needle)
 Assert-True ($i -gt 0 -and $i -lt $firstTeamWrite -and $i -lt $firstTeamPatch) "Save team validation before first write: $needle"
}
foreach($gate in @("With({upsertRows:","With({newPeriods:","With({periodUpdates:","With({deactivateRows:")){
 $i=$teamSave.IndexOf($gate);$pre=$teamSave.Substring(0,$i).TrimEnd()
 Assert-True ($i -gt 0 -and $pre.EndsWith('If(IsEmpty(colAssignmentErrors),')) "Save team write step gated on zero collected errors: $gate"
}
Assert-True ($teamSave.IndexOf('ClearCollect(colTeamVerifyRaw') -gt $teamSave.LastIndexOf('Patch(') -and $teamSave.IndexOf('If(varDiagTeamSaveWrites>0,') -gt $teamSave.LastIndexOf('Patch(')) 'Save team verify read after the last write, only when something was written'
$teamLast=$teamSave.Split("`n")
$teamOutcome=@($teamLast | Where-Object { $_.Contains('Set(varTeamLoadState,"Failed")') })
Assert-True ($teamOutcome.Count -eq 1 -and $teamOutcome[0].Trim().StartsWith('If(IsEmpty(colAssignmentErrors),Set(varSelectionLoaded,false); Set(varSelectionKeysValid,false); Set(varTeamDirty,false); Set(varTeamLoadState,"NotLoaded"); Select(btnReadTeam),Coalesce(varDiagTeamSaveWrites,0)=0,Set(varTeamLoadState,"Loaded"),Set(varSelectionLoaded,false); Set(varSelectionKeysValid,false); Set(varTeamLoadState,"Failed");')) 'Save team outcome: success -> reload; errors with zero writes -> stays Loaded (input kept, can be corrected); any write + error -> Failed, input kept, saving blocked'
Assert-True ($teamSave.Contains('Trace("DIAG|SaveTeam|End"') -and $teamSave -match 'Reads:Coalesce\(varDiagTeamSaveReads,0\),Writes:Coalesce\(varDiagTeamSaveWrites,0\)' -and $teamSave.Contains('CreatedPeriods:CountRows(colPeriodsCreated),UpdatedPeriods:CountRows(colPeriodsUpdated)')) 'DIAG|SaveTeam|End trace with Reads, Writes and period counts'
foreach($msg in @('De koppeling leverde geen SharePoint-ID op.','Een bestaande koppeling is niet meer beschikbaar.','Een koppeling is ondertussen naar een ander project of team gewijzigd. Kies het team opnieuw.','De toewijzing kon niet worden gedeactiveerd.','Teamwijzigingen opgeslagen. Bestaande koppelingen worden opnieuw gelezen.','Niet alle wijzigingen zijn opgeslagen: ','Team opslaan gestopt: ','Niet opgeslagen; er is niets naar SharePoint geschreven. ','de opgeslagen koppeling of periode kon niet correct worden teruggelezen.')){
 Assert-True ($teamSave.Contains($msg)) "Save team message kept: $msg"
}
$readTeam=$indexes.Screen1['btnReadTeam']['Properties']['OnSelect']
$cStart=$readTeam.IndexOf('Concurrent(');$cEnd=$readTeam.IndexOf('Collect(colSelectionLoadErrors,colProjectsLoadErrors,colTeamChoicesLoadErrors,colWorkersLoadErrors)')
Assert-True ($cStart -gt 0 -and $cEnd -gt $cStart) 'Masters loaded in Concurrent, errors merged afterwards'
$cBody=$readTeam.Substring($cStart,$cEnd-$cStart)
Assert-True ($cBody -notmatch 'colSelectionLoadErrors' -and $cBody.Contains('colProjectsLoadErrors') -and $cBody.Contains('colTeamChoicesLoadErrors') -and $cBody.Contains('colWorkersLoadErrors')) 'Concurrent branches write only their own error collection'
foreach($msg in @('"Projects: " & FirstError.Message','"Teamkeuzes: " & FirstError.Message','"Workers: " & FirstError.Message')){ Assert-True ($cBody.Contains($msg)) "Branch error message kept: $msg" }
# Delegation hygiene (22-10-2026): predicates on Hours / 'Project Workers' only use columns, functions and global vars.
# Documented exception: report month/day paging inside ForAll(Sequence(monthCount)) (Set is not allowed inside ForAll).
$known=@('EntryKey','ProjectKey','AssignmentKey','Team','Active','Value','Id','Project','Worker','Assignment','ID','Hours','TimeUnit','Days','true','false')
# 26-10-2026: the migration preview (Screen1.btnMigratePreview) reuses the same proven Hours month/day paging pattern (documented exception, DECISIONS.md H9 build).
$allowedScoped=@{'scrWeeklyHours.btnLoadReport.OnSelect'=@('monthFrom','monthUntil','dayFrom','dayUntil');'Screen1.btnMigratePreview.OnSelect'=@('monthFrom','monthUntil','dayFrom','dayUntil')}
$strNl=0;$sites=0
foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){foreach($prop in $indexes[$screen][$name]['Properties'].Keys){
 $fx=[string]$indexes[$screen][$name]['Properties'][$prop];$where="$screen.$name.$prop"
 $in=$false;for($i=0;$i -lt $fx.Length;$i++){$ch=$fx[$i];if($ch -eq '"'){if($in -and $i+1 -lt $fx.Length -and $fx[$i+1] -eq '"'){$i++;continue};$in=-not $in;continue};if($in -and ($ch -eq "`n" -or $ch -eq "`r")){$strNl++;Write-Output "NEWLINE IN STRING: $where";$in=$false}}
 foreach($m in [regex]::Matches($fx,"\b(Filter|LookUp)\(\s*(Hours|'Project Workers'|'Assignment Periods')\s*,")){
  $sites++;$i=$m.Index+$m.Length;$depth=1;$j=$i;$inS=$false
  while($j -lt $fx.Length -and $depth -gt 0){$ch=$fx[$j];if($ch -eq '"'){$inS=-not $inS}elseif(-not $inS){if($ch -eq '('){$depth++}elseif($ch -eq ')'){$depth--}};$j++}
  $pred=[regex]::Replace([regex]::Replace($fx.Substring($i,$j-1-$i),'"(?:[^"]|"")*"','""'),"'[^']*'",'COL')
  $ids=@([regex]::Matches($pred,'(?<![\.\w])[A-Za-z_]\w*\b(?!\s*\()') | ForEach-Object {$_.Value} | Where-Object {$_ -notin $known -and $_ -ne 'COL' -and $_ -notmatch '^(var|col)' -and !($allowedScoped.ContainsKey($where) -and $_ -in $allowedScoped[$where])} | Sort-Object -Unique)
  if($ids.Count -gt 0){throw "FAIL non-global name in $($m.Groups[2].Value) predicate at ${where}: $($ids -join ',')"}
  foreach($sw in [regex]::Matches($pred,'StartsWith\(\s*\w+\s*,\s*([^)]*)\)')){ if($sw.Groups[1].Value.Trim() -notmatch '^var\w+$'){throw "FAIL StartsWith 2nd argument is not a single global var at ${where}: $($sw.Groups[1].Value)"} }
 }
}}}
Assert-True ($strNl -eq 0) 'No string literal contains a line break (all screens)'
Assert-True ($sites -gt 0) "All $sites Hours/'Project Workers' predicates use only columns + global vars; StartsWith 2nd arg is a global var (report month/day paging documented exception)"
# Incident 25-10-2026 (Save week with empty Workers.Trade): local pre-save validation of every change, zero-write outcome
# kept usable, persistent error detail in lblWeekLoadStatus, Trade snapshot on new Hours records, MS-008 hint.
function Norm($s){ [regex]::Replace([string]$s,'\s+',' ') }
$weekN=Norm $week
$firstWriteInc=$week.IndexOf('Set(varDiagSaveWrites,varDiagSaveWrites+1)')
$firstPatch=$week.IndexOf('Patch(Hours,')
$preRead=$week.IndexOf('ClearCollect(colSaveCheckRaw')
Assert-True ($firstWriteInc -gt 0 -and $firstWriteInc -lt $firstPatch) 'Write counter incremented before (each) Patch attempt: any attempted Patch counts as a write'
# New-record path present and complete
Assert-True ($week.Contains('ClearCollect(colHoursPatchedNew,Patch(Hours,') -and $week.Contains('ForAll(newRows As n,Defaults(Hours))')) 'New-record path: table Patch with Defaults(Hours) base records'
Assert-True ($week.Contains('Trade:{Value:n.TradeValue}') -and $week.Contains('TradeValue:workerRecord.Trade.Value') -and $week.Contains('EmployerID:workerRecord.Employer.Id,EmployerValue:workerRecord.Employer.Value')) 'New records snapshot Trade {Value} and Employer {Id,Value} from colWorkersCache at save time'
Assert-True ($week -notmatch '\bChoices\(' -and $week -notmatch "\bLookUp\(\s*Workers\s*,") 'Trade/Employer snapshot without Choices() or remote Workers LookUp'
# Local validation (all changes, new and existing) before any read/write
Assert-True ($weekN.Contains('ForAll( colHoursChanges As c, With( { assignmentRecord: LookUp(colWeekAssignments, ID = c.AssignmentID), workerRecord: LookUp(colWorkersCache, ID = c.WorkerID),')) 'Local validation loops over every change (new and existing), lookups from session collections'
foreach($msg in @('koppeling ontbreekt in Project Workers (Refresh op Project / team)','koppelingssleutel (AssignmentKey/EntryKey) wijkt af in Project Workers; gegevens laten controleren','medewerker ontbreekt in Workers (Refresh op Project / team)','Employer ontbreekt in Workers (aanvullen in SharePoint, daarna Refresh op Project / team)','Trade ontbreekt in Workers (aanvullen in SharePoint, daarna Refresh op Project / team)','team ontbreekt in Project Workers',' ongeldig (0-24, max. 2 decimalen)')){
 $i=$week.IndexOf($msg)
 Assert-True ($i -gt 0 -and $i -lt $preRead -and $i -lt $firstWriteInc -and $i -lt $firstPatch) "Validation error collected before pre-read and before first write: $msg"
}
Assert-True ($week.Contains('If(IsEmpty(colHoursErrors),IfError(Refresh(Hours),') -and $week.IndexOf('If(IsEmpty(colHoursErrors),IfError(Refresh(Hours),') -lt $preRead) 'Validation errors skip the pre-read (Refresh + Filter guarded by IsEmpty(colHoursErrors))'
Assert-True ($week.IndexOf('If(IsEmpty(colHoursErrors) && CountRows(colHoursWritePlan) = CountRows(colHoursChanges),') -lt $firstWriteInc) 'Any collected error => zero writes (write gate precedes first write counter)'
$tradePred='IsBlank(workerRecord.Trade.Value)'
$empPred='IsBlank(workerRecord.Employer.Id) || IsBlank(workerRecord.Employer.Value)'
Assert-True ($week.Contains($tradePred) -and $week.Contains($empPred)) 'Trade and Employer (Id and Value) predicates present'
Assert-Regression ('With({workerRecord:{Trade:{Value:Blank()}}},'+$tradePred+')') $true 'Trade blank blocks'
Assert-Regression ('With({workerRecord:{Trade:If(false,{Value:"Fitter"})}},'+$tradePred+')') $true 'Trade record missing blocks'
foreach($t in @('Fitter','Welder','Unknown')){ Assert-Regression ('With({workerRecord:{Trade:{Value:"'+$t+'"}}},'+$tradePred+')') $false "Trade '$t' allowed" }
Assert-Regression ('With({workerRecord:{Employer:{Id:3,Value:Blank()}}},'+$empPred+')') $true 'Employer without Value blocks'
Assert-Regression ('With({workerRecord:{Employer:{Id:3,Value:"EMP-001"}}},'+$empPred+')') $false 'Employer with Id and Value allowed'
# Trade "Unknown" never blocked: the only "Unknown" literal is the MS-008 hint after a failed new-row Patch
Assert-True ((Count-Of $week '"Unknown"') -eq 1 -and $week.Contains('If(CountIf(newRows,TradeValue="Unknown")>0,Collect(colHoursErrors,{WorkerName:"",KeyValue:"",Message:"Mogelijk ontbreekt Trade ''Unknown'' in de Hours-lijst (MS-008)"}));')) 'No rule rejects Trade "Unknown"; only MS-008 hint uses the literal'
$ms8=$week.IndexOf("Mogelijk ontbreekt Trade 'Unknown' in de Hours-lijst (MS-008)")
Assert-True ($ms8 -gt $week.IndexOf('ClearCollect(colHoursPatchedNew,Patch(Hours,') -and $ms8 -lt $week.IndexOf('If(CountRows(colHoursPatchedNew)<>CountRows(newRows)')) 'MS-008 hint only in the IfError fallback of the new-row Patch'
# Hours range / decimals; explicit 0 allowed, blank cell handled by the unchanged clear-cell rule
$rangePred='!IsBlank(c.NewHours) && ( c.NewHours < 0 || c.NewHours > 24 || Abs( c.NewHours * 100 - Round(c.NewHours * 100, 0) ) > 0.000001 )'
Assert-True ($weekN.Contains($rangePred)) 'Hours range/decimals predicate present (per change)'
foreach($case in @(@('0',$false),@('24',$false),@('7.25',$false),@('Blank()',$false),@('-1',$true),@('24.01',$true),@('7.255',$true))){
 Assert-Regression ('With({c:{NewHours:'+$case[0]+'}},'+$rangePred+')') $case[1] "Hours $($case[0]) -> blocked=$($case[1])"
}
Assert-True ($week -notmatch 'NewHours\s*(=|<=)\s*0\b' -and $week -notmatch '\b0\s*=\s*\w*\.?NewHours') 'No rule rejects NewHours = 0 (explicit 0 on a new record allowed)'
Assert-True ($week.Contains('IsBlank(NewHours) && !IsBlank(OldHours)')) 'Cleared-cell rule unchanged (blank needs explicit 0)'
$keyPredN='assignmentRecord.Worker.Id <> c.WorkerID || IsBlank(assignmentRecord.AssignmentKey) || assignmentRecord.AssignmentKey <> Text(varWeekLoadedProjectID) & "|" & Text(c.WorkerID) || c.KeyValue <> assignmentRecord.AssignmentKey & "|" & Text(workDate, "[$-en-US]yyyymmdd")'
Assert-True ($weekN.Contains($keyPredN)) 'AssignmentKey = projectID|workerID and EntryKey = AssignmentKey|yyyymmdd checked per change'
# The standalone interpreter rejects the Canvas language tag '[$-en-US]' (also used by the existing loaders); strip it for evaluation only.
$keyPredN=$keyPredN.Replace('[$-en-US]','')
$kfx='With({varWeekLoadedProjectID:7,c:{WorkerID:3,KeyValue:"7|3|20261020"},assignmentRecord:{Worker:{Id:3},AssignmentKey:"7|3"},workDate:Date(2026,10,20)},'
Assert-Regression ($kfx+$keyPredN+')') $false 'Consistent AssignmentKey/EntryKey passes'
Assert-Regression ($kfx.Replace('KeyValue:"7|3|20261020"','KeyValue:"7|3|20261021"')+$keyPredN+')') $true 'EntryKey with other date blocks'
Assert-Regression ($kfx.Replace('AssignmentKey:"7|3"','AssignmentKey:"8|3"')+$keyPredN+')') $true 'AssignmentKey of other project blocks'
# Outcomes: zero writes keep the week usable; uncertainty only after >=1 write
$lastLines=$week.Split("`n")
$failLine=@($lastLines | Where-Object { $_.Contains('Opslag niet volledig bevestigd') })
Assert-True ($failLine.Count -eq 1 -and $failLine[0].Trim().StartsWith('If(!IsEmpty(colHoursErrors) && Coalesce(varDiagSaveWrites,0)>0,Set(varWeekLoadState,"Failed" ); Set(varWeekReady,false);')) '"Opslag niet volledig bevestigd" + Failed only when varDiagSaveWrites > 0'
Assert-True ((Count-Of $week 'Set(varWeekLoadState,"Failed"') -eq 1) 'Save week sets Failed in exactly one place'
Assert-True ($weekN.Contains('!IsEmpty(colHoursErrors) && Coalesce(varDiagSaveWrites, 0) = 0, Notify( "Niet opgeslagen; er is niets naar SharePoint geschreven. " &')) 'Zero-write outcome shows the real first error (no SharePoint uncertainty)'
# Persistent error detail
$lbl=$indexes.scrHours['lblWeekLoadStatus']['Properties']
$lblText=[string]$lbl['Text']
Assert-True ($lblText.Contains('First(colHoursErrors).WorkerName') -and $lblText.Contains('First(colHoursErrors).Message') -and $lblText.Contains('First(colHoursErrors).KeyValue') -and $lblText.Contains('CountRows(colHoursErrors)>1')) 'lblWeekLoadStatus shows first save error WorkerName/Message/KeyValue (+N meer)'
Assert-True ($lblText.Contains('"Opgeslagen week ophalen; vorige invoer blijft behouden tot laden slaagt..."') -and $lblText.Contains('"Nog niet geladen. Kies project, team en week; opslaan geblokkeerd."') -and $lblText.Contains('IsEmpty(colWeekLoadErrors) && !IsEmpty(colHoursErrors)')) 'lblWeekLoadStatus keeps load texts; load errors take precedence over save errors'
$readWeek=$indexes.scrHours['btnReadWeek']['Properties']['OnSelect']
$dirtyEnd=$readWeek.IndexOf('Set(varWeekForceRefresh,false),')
Assert-True ((Count-Of $readWeek 'Clear(colHoursErrors)') -eq 2 -and $readWeek.IndexOf('Clear(colHoursErrors)') -gt $dirtyEnd -and $readWeek.Contains('Rows:CountRows(colWeekRows)}); Clear(colHoursErrors),') -and $readWeek.Contains('Clear(colWeekLoadErrors); Clear(colHoursErrors);')) 'Save error detail cleared on cache hit and at start of a real load (incl. no project/team), never when blocked by unsaved input'
# Discard changes (26-10-2026): btnDiscardWeek throws away unsaved local week input; local only, same guard in DisplayMode and OnSelect.
$discard=$indexes.scrHours['btnDiscardWeek']
Assert-True ($null -ne $discard -and $discard['Control'] -eq 'Classic/Button@2.2.0' -and $discard['Properties']['Text'] -ceq '="Discard changes"') 'btnDiscardWeek exists: Classic/Button@2.2.0, Text "Discard changes"'
Assert-True (!$discard['Properties'].ContainsKey('AccessibleLabel')) 'btnDiscardWeek has no AccessibleLabel (PA2108)'
$rowChildren=@($indexes.scrHours['conWeekButtonRow']['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True ($rowChildren -contains 'btnDiscardWeek' -and $rowChildren -contains 'btnRefreshWeek' -and $rowChildren -contains 'btnSaveWeek') 'btnDiscardWeek is a direct child of conWeekButtonRow (same row as Refresh/Save)'
$dDm=$discard['Properties']['DisplayMode'].Trim();$dOs=[string]$discard['Properties']['OnSelect']
Assert-True ($dDm.StartsWith('=If(') -and $dDm.EndsWith(',DisplayMode.Edit,DisplayMode.Disabled)')) 'Discard DisplayMode shape If(<guard>,Edit,Disabled)'
$dGuard=$dDm.Substring(4,$dDm.Length-4-',DisplayMode.Edit,DisplayMode.Disabled)'.Length)
Assert-True ($dOs.StartsWith('=If('+$dGuard+',')) 'Discard: same guard text in DisplayMode and as first OnSelect condition'
$weekDirty='JSON(ShowColumns(colWeekRows,ID,MonHours,TueHours,WedHours,ThuHours,FriHours,SatHours,SunHours))<>JSON(ShowColumns(colWeekOriginal,ID,MonHours,TueHours,WedHours,ThuHours,FriHours,SatHours,SunHours))'
Assert-True ($dGuard.Contains($weekDirty) -and ([string]$indexes.scrHours['btnRefreshWeek']['Properties']['DisplayMode']).Contains($weekDirty)) 'Discard guard uses the existing Weekly Hours dirty check (identical to Refresh)'
Assert-True ($dGuard.Contains('!Coalesce(varWeekLoading,false)') -and $dGuard.Contains('!Coalesce(varWeekSaving,false)')) 'Discard guard excludes loading and saving'
# The interpreter has no JSON(); the dirty check is supplied as a boolean (same approach as Test-WeeklyCalculations).
$dGuardFx=$dGuard.Replace($weekDirty,'isDirty')
foreach($case in @(
 @('"Loaded"','false','false','true',$true,'Loaded + dirty allows Discard'),
 @('"Failed"','false','false','true',$true,'Failed (partial save) + dirty allows Discard'),
 @('"Loaded"','false','false','false',$false,'Loaded without unsaved input: Discard disabled'),
 @('"Failed"','false','false','false',$false,'Failed without unsaved input: Discard disabled (Refresh available)'),
 @('"Loading"','true','false','true',$false,'Loading blocks Discard'),
 @('"Loaded"','false','true','true',$false,'Saving blocks Discard'),
 @('"Loaded"','true','false','true',$false,'Loading flag blocks Discard even with stale Loaded state'),
 @('"NotLoaded"','false','false','true',$false,'NotLoaded blocks Discard'),
 @('Blank()','Blank()','Blank()','true',$false,'Cold start blocks Discard'))){
 Assert-Regression ('With({varWeekLoadState:'+$case[0]+',varWeekLoading:'+$case[1]+',varWeekSaving:'+$case[2]+',isDirty:'+$case[3]+'},'+$dGuardFx+')') $case[4] $case[5]
}
Assert-True ($dOs -notmatch '\b(Patch|Update|UpdateIf|Remove|RemoveIf|Refresh|SubmitForm|Defaults)\s*\(' -and $dOs -notmatch '\.Run\(') 'Discard OnSelect: no Patch/Update/Remove/RemoveIf/Refresh/flow'
Assert-True ($dOs -notmatch "\b(?:Collect|ClearCollect|Clear)\(\s*(?:Hours|'Project Workers'|Workers|Projects|Employers)\b" -and $dOs -notmatch "\b(?:Filter|LookUp)\(\s*(?:Hours|'Project Workers'|Workers|Projects|Employers)\s*,") 'Discard OnSelect: no Collect into or read from SharePoint sources'
$dSets=@([regex]::Matches($dOs,'\bSet\(\s*(\w+)\s*,') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True ($dSets.Count -eq 1 -and $dSets[0] -eq 'varWeekForceRefresh') 'Discard sets only varWeekForceRefresh (no load state, loaded selection, project/team/week or version variables)'
$dFailed=$dOs.IndexOf('If(varWeekLoadState="Failed",');$dElse=$dOs.IndexOf('Select(btnReadWeek),')
Assert-True ($dFailed -gt 0 -and $dElse -gt $dFailed) 'Discard branches on varWeekLoadState="Failed"'
$failedBranch=$dOs.Substring($dFailed,$dElse-$dFailed);$loadedBranch=$dOs.Substring($dElse+'Select(btnReadWeek),'.Length)
Assert-True ($failedBranch.Contains('ClearCollect(colWeekRows,colWeekOriginal); Set(varWeekForceRefresh,true);') -and $failedBranch.IndexOf('ClearCollect(colWeekRows,colWeekOriginal)') -lt $failedBranch.IndexOf('Set(varWeekForceRefresh,true)')) 'Failed branch: input reset to baseline first (dirty gate of loader passes), then force refresh'
Assert-True ($failedBranch.Contains('Notify(') -and $failedBranch -notmatch 'Select\(|Clear\(colWeekOriginal\)' -and $dOs.Substring($dElse).StartsWith('Select(btnReadWeek),') -and (Count-Of $dOs 'Select(btnReadWeek)') -eq 1)'Failed branch reloads from SharePoint through btnReadWeek (staged loader; no own read)'
Assert-True ($loadedBranch.Contains('ClearCollect(colWeekRows,colWeekOriginal); Clear(colHoursErrors);') -and $loadedBranch.Contains('Notify("Wijzigingen ongedaan gemaakt.",NotificationType.Information)') -and $loadedBranch -notmatch 'Select\(') 'Loaded branch: colWeekRows restored from colWeekOriginal, save errors cleared, no reload'
Assert-True ($dOs.Contains('Trace("DIAG|Week|Discard",TraceSeverity.Information,{Scenario:"Week",Step:"Discard",State:Coalesce(varWeekLoadState,""),Rows:CountRows(colWeekRows)})') -and $dOs.IndexOf('Trace("DIAG|Week|Discard"') -lt $dFailed) 'Discard DIAG trace before the action'
Assert-True ($dOs.Contains('Notify("Discard geblokkeerd: laden/opslaan bezig of geen onopgeslagen uren.",NotificationType.Warning,15000))')) 'Discard blocked path notifies, no action'
$readWeekNow=[string]$indexes.scrHours['btnReadWeek']['Properties']['OnSelect']
Assert-True ($readWeekNow.StartsWith('=If('+$weekDirty+',') -and $readWeekNow.Contains('If(!Coalesce(varWeekForceRefresh,false) && varWeekLoadState="Loaded"')) 'Loader still gated on the same dirty check; force flag bypasses cache hit (used by Discard Failed branch)'
Write-Output 'PASS Discard changes structure/guard (local only). Studio behaviour of the inputs after restore NOT verified.'
# Home screen (26-10-2026): scrHome is the start screen; tiles and Home buttons only navigate (no data actions).
Assert-True (([string]$app['App']['Properties']['StartScreen']).Trim() -ceq '=scrHome') 'App.StartScreen = scrHome'
$homeIdx=$indexes.scrHome
$homeOn=0
foreach($name in $homeIdx.Keys){foreach($prop in @($homeIdx[$name]['Properties'].Keys)){
 if($prop -notlike 'On*'){continue}
 $fx=[string]$homeIdx[$name]['Properties'][$prop];$homeOn++
 Assert-True ($fx -notmatch '\b(Patch|Update|UpdateIf|Remove|RemoveIf|Collect|ClearCollect|Clear|Refresh|SubmitForm|Defaults|Concurrent|Reset)\s*\(' -and $fx -notmatch '\.Run\(') "scrHome.$name.$prop has no data mutation, refresh, reset or flow"
 Assert-True ($fx -notmatch "(?<![\w])(?:Hours|Workers|Projects|Employers)\b\s*[,)]" -and $fx -notmatch "'Project Workers'" -and $fx -notmatch '\bChoices\(') "scrHome.$name.$prop reads no SharePoint source"
 $homeSets=@([regex]::Matches($fx,'\bSet\(\s*(\w+)\s*,') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
 Assert-True (@($homeSets | Where-Object { $_ -notin @('varProject','varTeam') }).Count -eq 0) "scrHome.$name.$prop sets no state other than varProject/varTeam"
 foreach($sel in [regex]::Matches($fx,'\bSelect\(\s*(\w+)\s*\)')){ Assert-True ($sel.Groups[1].Value -in @('btnTileProjectTeam','btnTileWeeklyHours','btnTileHoursSummary','btnTileContractors')) "scrHome.$name.$prop selects only a navigation tile ($($sel.Groups[1].Value))" }
 foreach($nav in [regex]::Matches($fx,'\bNavigate\(\s*(\w+)')){ Assert-True ($nav.Groups[1].Value -in @('Screen1','scrHours','scrWeeklyHours','scrContractors')) "scrHome.$name.$prop navigates to a known screen ($($nav.Groups[1].Value))" }
}}
Assert-True ($homeOn -gt 0) "scrHome event formulas checked: $homeOn"
# Non-event properties (Text, Visible, DisplayMode, layout...) on scrHome must not read SharePoint either.
$homeAll=0
foreach($name in $homeIdx.Keys){foreach($prop in @($homeIdx[$name]['Properties'].Keys)){
 if($prop -like 'On*'){continue}
 $fx=[string]$homeIdx[$name]['Properties'][$prop];$homeAll++
 Assert-True ($fx -notmatch "(?<![\w`"])(?:Hours|Workers|Projects|Employers)\b\s*[,)]" -and $fx -notmatch "'Project Workers'" -and $fx -notmatch '\b(Choices|LookUp|Filter|Search|First|CountRows)\(\s*(Hours|Workers|Projects|Employers|''Project Workers'')\b') "scrHome.$name.$prop reads no SharePoint source"
}}
Assert-True ($homeAll -gt 0) "scrHome non-event formulas checked: $homeAll"
# Weekly Hours tile: 'loaded' = exactly the btnGotoHours (Screen1) DisplayMode predicate + its OnSelect blank checks.
$gotoDm=$indexes.Screen1['btnGotoHours']['Properties']['DisplayMode'].Trim()
$navSuffix=',DisplayMode.Edit,DisplayMode.Disabled)'
Assert-True ($gotoDm.StartsWith('=If(') -and $gotoDm.EndsWith($navSuffix)) 'btnGotoHours DisplayMode shape If(<pred>,Edit,Disabled)'
$gotoPred=$gotoDm.Substring(4,$gotoDm.Length-4-$navSuffix.Length)
Assert-True ($gotoPred -ceq 'varTeamLoadState="Loaded" && !Coalesce(varTeamDirty,false) && !Coalesce(varSelectionBusy,false) && !Coalesce(varSaving,false) && varTeamLoadedProjectID=ddProject.Selected.Id && varTeamLoadedTeam=ddTeam.Selected.Value') 'Screen1 btnGotoHours guard unchanged'
$tileLoaded=$gotoPred+' && !IsBlank(ddProject.Selected.Id) && !IsBlank(ddTeam.Selected.Value)'
$tile=([string]$homeIdx['btnTileWeeklyHours']['Properties']['OnSelect']).Trim()
$tileElse=',Navigate(Screen1); Notify("Choose project and team first",NotificationType.Warning))'
Assert-True ($tile.StartsWith('=If('+$tileLoaded+',') -and $tile.EndsWith($tileElse)) 'Weekly Hours tile: If(<btnGotoHours guard + project/team not blank>, ..., Navigate(Screen1); Notify("Choose project and team first"))'
$tileThen=$tile.Substring(('=If('+$tileLoaded+',').Length);$tileThen=$tileThen.Substring(0,$tileThen.Length-$tileElse.Length)
Assert-True ($tileThen.StartsWith('Set(varProject,ddProject.Selected); Set(varTeam,ddTeam.Selected);') -and $tileThen.EndsWith('Navigate(scrHours)') -and (Count-Of $tileThen 'Navigate(') -eq 1 -and $tileThen -notmatch 'Notify\(') 'Weekly Hours tile loaded branch: same varProject/varTeam as btnGotoHours, then Navigate(scrHours) only'
Assert-True ($tile -notmatch 'Select\(') 'Weekly Hours tile does not trigger a load (scrHours.OnVisible loads)'
$navFx='With({varTeamLoadState:"Loaded",varTeamDirty:false,varSelectionBusy:false,varSaving:false,varTeamLoadedProjectID:7,varTeamLoadedTeam:"2",ddProject:{Selected:{Id:7}},ddTeam:{Selected:{Value:"2"}}},'
Assert-Regression ($navFx+$tileLoaded+')') $true 'Tile: loaded matching selection -> scrHours'
foreach($state in @('"NotLoaded"','"Loading"','"Failed"','Blank()')){ Assert-Regression ($navFx.Replace('varTeamLoadState:"Loaded"','varTeamLoadState:'+$state)+$tileLoaded+')') $false "Tile: team state $state -> Screen1 + Notify" }
foreach($flag in @('varTeamDirty','varSelectionBusy','varSaving')){ Assert-Regression ($navFx.Replace($flag+':false',$flag+':true')+$tileLoaded+')') $false "Tile: $flag -> Screen1 + Notify" }
Assert-Regression ($navFx.Replace('ddProject:{Selected:{Id:7}}','ddProject:{Selected:{Id:8}}')+$tileLoaded+')') $false 'Tile: dropdown project differs from loaded -> Screen1'
Assert-Regression ($navFx.Replace('ddTeam:{Selected:{Value:"2"}}','ddTeam:{Selected:{Value:"3"}}')+$tileLoaded+')') $false 'Tile: dropdown team differs from loaded -> Screen1'
Assert-Regression ($navFx.Replace('varTeamLoadedProjectID:7','varTeamLoadedProjectID:Blank()').Replace('ddProject:{Selected:{Id:7}}','ddProject:{Selected:{Id:Blank()}}')+$tileLoaded+')') $false 'Tile: blank project (Blank=Blank) with stale Loaded -> Screen1'
Assert-Regression ($navFx.Replace('varTeamLoadedTeam:"2"','varTeamLoadedTeam:Blank()').Replace('ddTeam:{Selected:{Value:"2"}}','ddTeam:{Selected:{Value:Blank()}}')+$tileLoaded+')') $false 'Tile: blank team with stale Loaded -> Screen1'
# Home buttons: identical guard in DisplayMode and as (only) OnSelect condition.
$weekClean=$weekDirty.Replace(')<>JSON(',')=JSON(')
$homeButtons=@(
 @('Screen1','btnHomeScreen1','!Coalesce(varSaving,false) && !Coalesce(varSelectionBusy,false) && !Coalesce(varTeamDirty,false)'),
 @('scrHours','btnHomeHours',('!Coalesce(varWeekLoading,false) && !Coalesce(varWeekSaving,false) && '+$weekClean)),
 @('scrWeeklyHours','btnHomeSummary','!Coalesce(varReportBusy,false)'))
foreach($hb in $homeButtons){
 $hp=$indexes[$hb[0]][$hb[1]]['Properties']
 Assert-True (([string]$hp['DisplayMode']).Trim() -ceq ('=If('+$hb[2]+$navSuffix)) "$($hb[1]) DisplayMode = If(<home guard>,Edit,Disabled)"
 Assert-True (([string]$hp['OnSelect']).Trim() -ceq ('=If('+$hb[2]+',Navigate(scrHome))')) "$($hb[1]) OnSelect = If(<same guard>,Navigate(scrHome))"
}
$h1=$homeButtons[0][2]
Assert-True ($h1 -notmatch 'varTeamLoadState|varTeamLoaded|ddProject|ddTeam') 'Screen1 Home does not require a successful load (no trap after failed/empty load)'
foreach($case in @(@('false','false','false',$true,'idle'),@('Blank()','Blank()','Blank()',$true,'cold start / failed load'),@('true','false','false',$false,'saving'),@('false','true','false',$false,'loading'),@('false','false','true',$false,'unsaved team selection'))){
 Assert-Regression ('With({varSaving:'+$case[0]+',varSelectionBusy:'+$case[1]+',varTeamDirty:'+$case[2]+'},'+$h1+')') $case[3] "Screen1 Home: $($case[4]) -> allowed=$($case[3])"
}
foreach($sib in @('btnGotoHours','btnGotoHoursSummary')){ Assert-True (([string]$indexes.Screen1[$sib]['Properties']['DisplayMode']).Trim() -ceq $gotoDm) "Screen1 $sib DisplayMode unchanged (requires Loaded)" }
$h2=$homeButtons[1][2].Replace($weekClean,'!isDirty')
$sibWeek=([string]$indexes.scrHours['btnWeeklyProjectTeam']['Properties']['DisplayMode']).Trim().Substring(1).Replace($weekDirty,'isDirty').Replace('DisplayMode.Edit','true').Replace('DisplayMode.Disabled','false')
foreach($l in @('false','true')){foreach($s in @('false','true')){foreach($d in @('false','true')){
 $fxw='With({varWeekLoading:'+$l+',varWeekSaving:'+$s+',isDirty:'+$d+'},'
 $exp=($l -eq 'false' -and $s -eq 'false' -and $d -eq 'false')
 Assert-Regression ($fxw+$h2+')') $exp "scrHours Home: loading=$l saving=$s unsaved=$d -> allowed=$exp"
 Assert-Regression ($fxw+$sibWeek+')') $exp "scrHours Project / team (sibling) same outcome: loading=$l saving=$s unsaved=$d"
}}}
Assert-Regression ('With({varWeekLoading:Blank(),varWeekSaving:Blank(),isDirty:false},'+$h2+')') $true 'scrHours Home: cold flags without input allowed'
$h3=$homeButtons[2][2]
$sibSum=([string]$indexes.scrWeeklyHours['btnSummaryProjectTeam']['Properties']['DisplayMode']).Trim().Substring(1).Replace('DisplayMode.Edit','true').Replace('DisplayMode.Disabled','false')
foreach($b in @('false','true')){
 Assert-Regression ('With({varReportBusy:'+$b+'},'+$h3+')') ($b -eq 'false') "Hours Summary Home: busy=$b"
 Assert-Regression ('With({varReportBusy:'+$b+'},'+$sibSum+')') ($b -eq 'false') "Hours Summary Project / team (sibling) same outcome: busy=$b"
}
Assert-Regression ('With({varReportBusy:Blank()},'+$h3+')') $true 'Hours Summary Home: cold flag allowed'
Write-Output 'PASS Home screen navigation and guards (local). Studio navigation, Notify and OnVisible loads NOT verified.'

# ---------------------------------------------------------------------------------------------------------------------------
# Assignment periods (26-10-2026, DECISIONS.md H9, MS-010). Decision logic is evaluated with the bundled interpreter on the
# exact formula text taken from Src (balanced-parenthesis extraction); fixtures use week Monday 26-10-2026 (Sunday 01-11-2026).
function Get-Balanced([string]$text,[string]$marker){
 $s=$text.IndexOf($marker);if($s -lt 0){throw "FAIL marker not found: $marker"}
 $k=$text.IndexOf('(',$s);$depth=0;$inS=$false
 for($j=$k;$j -lt $text.Length;$j++){$ch=$text[$j]
  if($ch -eq '"'){$inS=-not $inS;continue}
  if($inS){continue}
  if($ch -eq '('){$depth++}elseif($ch -eq ')'){$depth--;if($depth -eq 0){return $text.Substring($s,$j-$s+1)}}
 }
 throw "FAIL unbalanced expression at: $marker"
}
$Bd='If(false,Date(2000,1,1))'
function Get-PeriodTable($rows){ if($rows.Count -eq 0){return 'Filter(Table({ID:0,AssignmentKey:"",From:Date(2000,1,3),Until:Date(2000,1,9)}),false)'}; 'Table('+(($rows|ForEach-Object { '{ID:'+$_[0]+',AssignmentKey:"'+$_[1]+'",From:Date('+$_[2]+'),Until:'+$(if($_[3]){'Date('+$_[3]+')'}else{$Bd})+'}' }) -join ',')+')' }
$all=@{};foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){foreach($prop in $indexes[$screen][$name]['Properties'].Keys){$all["$screen.$name.$prop"]=[string]$indexes[$screen][$name]['Properties'][$prop]}}}
# Delegation: every 'Assignment Periods' read is Filter(...,ProjectKey=<global var>) only.
$apSites=0
foreach($k in $all.Keys){foreach($m in [regex]::Matches($all[$k],"Filter\('Assignment Periods',")){$apSites++
 $rest=$all[$k].Substring($m.Index+$m.Length)
 if($rest -notmatch '^ProjectKey=var\w+\)'){throw "FAIL non-delegable or non-global 'Assignment Periods' predicate at ${k}: $($rest.Substring(0,[Math]::Min(60,$rest.Length)))"}
}}
Assert-True ($apSites -eq 8) "All $apSites 'Assignment Periods' reads use Filter(...,ProjectKey=<global var>) (delegable text equality, indexed column)"
$readWeekFx=$indexes.scrHours['btnReadWeek']['Properties']['OnSelect'];$loadReport=$indexes.scrWeeklyHours['btnLoadReport']['Properties']['OnSelect'];$buildReport=$indexes.scrWeeklyHours['btnBuildReport']['Properties']['OnSelect']
$applyWeek=$indexes.Screen1['btnApplyTeamWeek']['Properties']['OnSelect'];$migPrev=$indexes.Screen1['btnMigratePreview']['Properties']['OnSelect'];$migConf=$indexes.Screen1['btnMigrateConfirm']['Properties']['OnSelect']
foreach($case in @(
 @($readTeam,"Set(varSelectionProjectKey,Text(varSelectionProjectID))","Filter('Assignment Periods',ProjectKey=varSelectionProjectKey)",'CountRows(colPendingTeamPeriods)>=500','!StartsWith(AssignmentKey,varSelectionProjectKey & "|")','ClearCollect(colTeamPeriods,colPendingTeamPeriods)','Screen1 team load'),
 @($readWeekFx,'Set(varPendingHoursProjectKey,Text(varPendingHoursProjectID))',"Filter('Assignment Periods',ProjectKey=varPendingHoursProjectKey)",'CountRows(colPendingWeekPeriods)>=500','!StartsWith(AssignmentKey,varPendingHoursProjectKey & "|")','ClearCollect(colWeekAssignments,colPendingWeekAssignments)','Weekly Hours load'),
 @($loadReport,'Set(varReportProjectKey,Text(varReportProjectID))',"Filter('Assignment Periods',ProjectKey=varReportProjectKey)",'CountRows(colReportAssignmentPeriods)>=500','!StartsWith(AssignmentKey,varReportProjectKey & "|")','Set(varReportReady,true)','Hours Summary load'))){
 $fx=$case[0];$q=$fx.IndexOf($case[2])
 Assert-True ($fx.IndexOf($case[1]) -ge 0 -and $fx.IndexOf($case[1]) -lt $q) "$($case[6]): global ProjectKey var set before the period query"
 Assert-True ($q -gt 0 -and $fx.IndexOf($case[3]) -gt $q -and $fx.IndexOf($case[4]) -gt $q) "$($case[6]): 500 guard and local ProjectKey/AssignmentKey-prefix validation after the period query"
 Assert-True ($fx.IndexOf($case[5]) -gt $fx.IndexOf($case[3])) "$($case[6]): commit/ready only after the period guards (staged, fail closed)"
 Assert-True ($fx -notmatch '\b(Patch|Remove|RemoveIf|Update|UpdateIf|Defaults)\s*\(') "$($case[6]): no writes"
}
# Screen1 checkbox state = PW record for this project with Team = selected team AND a period overlapping the picked week.
$tw0='Set(varTeamWeekMonday,varHoursWeekMonday);';$tw1='Set(varTeamLoadedWeekMonday,varTeamWeekMonday)'
$twLoad=$readTeam.Substring($readTeam.IndexOf($tw0),$readTeam.IndexOf($tw1)+$tw1.Length-$readTeam.IndexOf($tw0))
$twApply=$applyWeek.Substring($applyWeek.IndexOf($tw0),$applyWeek.IndexOf($tw1)+$tw1.Length-$applyWeek.IndexOf($tw0))
Assert-True ($twLoad -ceq $twApply) 'Week recompute block is byte-identical in the team loader and btnApplyTeamWeek'
Assert-True ($twLoad -notmatch "'Project Workers'|'Assignment Periods'|\bPatch\(|\bRefresh\(" -and $applyWeek -notmatch "'Project Workers'|'Assignment Periods'|\bPatch\(|\bRefresh\(") 'A clean week change recomputes locally from the loaded periods (no reload, no writes)'
Assert-True ($applyWeek.StartsWith('=If(varTeamLoadState="Loaded" && Coalesce(varSelectionLoaded,false) && !Coalesce(varSelectionBusy,false) && !Coalesce(varSaving,false) && !Coalesce(varTeamDirty,false) && !IsBlank(varHoursWeekMonday),')) 'btnApplyTeamWeek only with a loaded, clean selection'
$cbRule=Get-Balanced $twLoad 'Filter(colTeamProjectAssignments As member,'
$cbData='colTeamProjectAssignments:Table({ID:11,Worker:{Id:1},Team:{Value:"2"}},{ID:12,Worker:{Id:2},Team:{Value:"2"}},{ID:13,Worker:{Id:3},Team:{Value:"3"}},{ID:14,Worker:{Id:4},Team:{Value:"2"}},{ID:15,Worker:{Id:5},Team:{Value:"2"}}),colTeamPeriods:'+(Get-PeriodTable @(@(1,'7|1','2026,10,5',$null),@(2,'7|2','2026,9,7','2026,10,25'),@(3,'7|3','2026,10,5',$null),@(4,'7|4','2026,10,26','2026,11,1'),@(5,'8|5','2026,10,5',$null)))+',varTeamLoadedProjectID:7,varTeamLoadedTeam:"2"'
foreach($c in @(@('2026,10,26','2026,11,1','11,14','picked week: open period + exact-week period; other team, ended period and other-project key excluded'),@('2026,11,2','2026,11,8','11','next week: only the open period'),@('2026,10,19','2026,10,25','11,12','previous week: period ending Sunday 25-10 still included'))){
 Assert-Regression ('With({'+$cbData+',varTeamWeekMonday:Date('+$c[0]+'),varTeamWeekSunday:Date('+$c[1]+')},Concat('+$cbRule+',Text(ID),","))') $c[2] "Checkbox rule $($c[3])"
}
# Team guard: selection must be computed for the picked week; pending migration blocks.
Assert-Regression ('With({'+$teamFixture.Replace('varHoursWeekMonday:Date(2026,10,26)','varHoursWeekMonday:Date(2026,11,2)')+'},'+$guards.team+')') $false 'Team guard: selection computed for another week blocks Save'
Assert-Regression ('With({'+$teamFixture.Replace('varTeamLoadedWeekMonday:Date(2026,10,26)','varTeamLoadedWeekMonday:'+$Bd)+'},'+$guards.team+')') $false 'Team guard: no computed week blocks Save'
Assert-Regression ('With({'+$teamFixture.Replace('varTeamMigrationBlocksSave:false','varTeamMigrationBlocksSave:true')+'},'+$guards.team+')') $false 'Team guard: pending migration blocks Save'
Assert-Regression ('With({'+$teamFixture.Replace('varTeamMigrationBlocksSave:false','varTeamMigrationBlocksSave:Blank()')+'},'+$guards.team+')') $false 'Team guard: unknown migration state blocks Save'
Assert-Regression ('With({'+$teamFixture.Replace('Team:{Value:"2"},Active:true','Team:{Value:"2"},Active:false')+'},'+$guards.team+')') $true 'Team guard: worker with a closed period overlapping the week (Active=false) is a valid selected row'
Assert-Regression ('With({'+$weekFixture.Replace('Team:{Value:"2"},Active:true','Team:{Value:"2"},Active:false')+'},'+$guards.week+')') $true 'Week guard: inactive Project Workers row shown because of period/hours may be saved'
# Save team decision per worker (exact Src text).
$dec=Get-Balanced $teamSave 'With({weekSunday:DateAdd(weekMonday,6,TimeUnit.Days)}'
function Get-DecisionFx($rows,$isSel,$wasSel,$isRem){ 'With({workerPeriods:'+(Get-PeriodTable $rows)+',weekMonday:Date(2026,10,26),isSel:'+$isSel+',wasSel:'+$wasSel+',isRem:'+$isRem+'},With({d:'+$dec+'},d.Action & "|" & If(IsBlank(d.PeriodID),"-",Text(d.PeriodID)) & "|" & If(IsBlank(d.NewUntil),"-",Text(d.NewUntil,"yyyy-mm-dd"))))' }
foreach($c in @(
 @(@(),'true','false','false','NEW|-|-','check, no periods -> NEW from Monday, open'),
 @(@(,@(1,'7|1','2026,9,7','2026,10,25')),'true','false','false','REOPEN|1|-','check, latest period ended Sunday before -> REOPEN (Until cleared)'),
 @(@(,@(1,'7|1','2026,9,7','2026,10,18')),'true','false','false','NEW|-|-','check, latest period ended earlier -> NEW'),
 @(@(@(1,'7|1','2026,1,5','2026,3,1'),@(2,'7|1','2026,9,7','2026,10,25')),'true','false','false','REOPEN|2|-','check, reopen uses the latest period (max From)'),
 @(@(,@(1,'7|1','2026,11,9',$null)),'true','false','false','BLOCK|-|-','check, a later period exists -> BLOCK'),
 @(@(,@(1,'7|1','2026,10,5',$null)),'true','false','false','TEAM|-|-','check, overlapping period in another team -> TEAM only, no period change'),
 @(@(,@(1,'7|1','2026,10,5',$null)),'true','true','false','NONE|-|-','still checked -> NONE'),
 @(@(,@(1,'7|1','2026,10,5',$null)),'false','true','true','CLOSE|1|2026-11-01','uncheck, open period -> Until = Sunday of picked week'),
 @(@(,@(1,'7|1','2026,10,5','2026,11,1')),'false','true','true','NONE|-|-','uncheck, period already ends this Sunday -> NONE'),
 @(@(,@(1,'7|1','2026,10,5','2026,11,29')),'false','true','true','SHORTEN|1|2026-11-01','uncheck, latest closed period ending later -> SHORTEN'),
 @(@(@(1,'7|1','2026,10,5','2026,11,29'),@(2,'7|1','2026,12,7',$null)),'false','true','true','BLOCK|-|-','uncheck, period before a later period -> BLOCK'),
 @(@(),'false','true','true','BLOCK|-|-','uncheck, no overlapping period -> BLOCK'),
 @(@(,@(1,'7|1','2026,10,5','2026,10,28')),'false','true','true','BLOCK|-|-','uncheck, period ending mid-week (not Sunday) -> BLOCK'),
 @(@(),'false','false','false','NONE|-|-','not involved -> NONE'))){
 Assert-Regression (Get-DecisionFx $c[0] $c[1] $c[2] $c[3]) $c[4] "Period decision: $($c[5])"
}
$chk=Get-Balanced $teamSave 'With({farDate:Date(9999,12,31),target:LookUp(workerPeriods,ID=decision.PeriodID)}'
function Get-CheckFx($rows,$decision){ 'With({workerPeriods:'+(Get-PeriodTable $rows)+',weekMonday:Date(2026,10,26),decision:'+$decision+'},'+$chk+')' }
$dNone='{Action:"NONE",PeriodID:If(false,0),NewUntil:'+$Bd+',Message:""}'
$dNew='{Action:"NEW",PeriodID:If(false,0),NewUntil:'+$Bd+',Message:""}'
foreach($c in @(
 @(@(,@(1,'7|1','2026,10,5','2026,9,27')),$dNone,("bestaande periode zonder From of met Until v$([char]0xF3)$([char]0xF3)r From; gegevens laten controleren."),'existing Until < From blocks'),
 @(@(@(1,'7|1','2026,1,5','2026,3,1'),@(2,'7|1','2026,2,2',$null)),$dNone,'bestaande periodes overlappen; gegevens laten controleren.','existing overlap blocks'),
 @(@(,@(1,'7|1','2026,9,7',$null)),$dNew,'een nieuwe periode vanaf deze week zou overlappen met een bestaande periode.','NEW overlapping an open period blocks'),
 @(@(@(1,'7|1','2026,9,7','2026,10,25'),@(2,'7|1','2026,11,9',$null)),('{Action:"REOPEN",PeriodID:1,NewUntil:'+$Bd+',Message:""}'),'heropenen zou overlappen met een latere periode.','REOPEN before a later period blocks'),
 @(@(,@(1,'7|1','2026,11,9',$null)),'{Action:"CLOSE",PeriodID:1,NewUntil:Date(2026,11,1),Message:""}',("Until zou v$([char]0xF3)$([char]0xF3)r From komen te liggen."),'Until < From after change blocks'),
 @(@(@(1,'7|1','2026,10,5','2026,11,29'),@(2,'7|1','2026,10,19','2026,10,25')),'{Action:"SHORTEN",PeriodID:1,NewUntil:Date(2026,11,1),Message:""}','bestaande periodes overlappen; gegevens laten controleren.','pre-existing overlap reported before the change'),
 @(@(,@(1,'7|1','2026,10,5',$null)),'{Action:"CLOSE",PeriodID:1,NewUntil:Date(2026,11,1),Message:""}','','valid CLOSE passes'),
 @(@(,@(1,'7|1','2026,9,7','2026,10,25')),('{Action:"REOPEN",PeriodID:1,NewUntil:'+$Bd+',Message:""}'),'','valid REOPEN passes'),
 @(@(,@(1,'7|1','2026,9,7','2026,10,18')),$dNew,'','valid NEW after a gap passes'))){
 Assert-Regression (Get-CheckFx $c[0] $c[1]) $c[2] "Validation after change: $($c[3])"
}
$act=Get-Balanced $teamSave 'If(decision.Action="NEW" || decision.Action="REOPEN",true,'
foreach($c in @(@('NEW',@(),$true),@('REOPEN',@(,@(1,'7|1','2026,9,7','2026,10,25')),$true),@('CLOSE',@(,@(1,'7|1','2026,10,5',$null)),$false),@('SHORTEN',@(,@(1,'7|1','2026,10,5','2026,11,29')),$false),@('TEAM',@(,@(1,'7|1','2026,10,5',$null)),$true),@('TEAM',@(,@(1,'7|1','2026,10,5','2026,11,29')),$false))){
 Assert-Regression ('With({workerPeriods:'+(Get-PeriodTable $c[1])+',decision:{Action:"'+$c[0]+'"}},'+$act+')') $c[2] "Active after save = open period: $($c[0]) -> $($c[2])"
}
# Weekly Hours rows = team PW records (incl. inactive) with a period overlapping Mon..Sun OR stored hours in that week.
Assert-True ($readWeekFx.Contains("Filter('Project Workers',ProjectKey=varPendingHoursProjectKey && Team.Value=varPendingHoursTeam)") -and $readWeekFx -notmatch "Filter\('Project Workers',[^)]*Active") 'Weekly Hours loads all team assignments incl. inactive (no Active filter in the source query)'
$rowRule=Get-Balanced $readWeekFx 'Filter(colPendingWeekTeamAssignments As member,'
$rowData='colPendingWeekTeamAssignments:Table({ID:11,Worker:{Id:1}},{ID:12,Worker:{Id:2}},{ID:14,Worker:{Id:4}}),colPendingWeekPeriods:'+(Get-PeriodTable @(@(1,'7|1','2026,10,5',$null),@(2,'7|2','2026,9,7','2026,10,25'),@(4,'7|4','2026,10,26','2026,11,1')))+',varPendingHoursProjectID:7'
Assert-Regression ('With({'+$rowData+',colPendingWeekProjectHours:Table({AssignmentID:12,HourValue:8}),varPendingWeekMonday:Date(2026,11,2),varPendingWeekSunday:Date(2026,11,8)},Concat('+$rowRule+',Text(ID),","))') '11,12' 'Weekly row rule: open period + inactive worker with stored hours; ended period without hours hidden'
Assert-Regression ('With({'+$rowData+',colPendingWeekProjectHours:Filter(Table({AssignmentID:12,HourValue:8}),false),varPendingWeekMonday:Date(2026,10,26),varPendingWeekSunday:Date(2026,11,1)},Concat('+$rowRule+',Text(ID),","))') '11,14' 'Weekly row rule: period overlap without hours shown (blank days stay blank)'
Assert-True ($readWeekFx.IndexOf('ClearCollect(colPendingWeekStored,') -gt $readWeekFx.IndexOf('ClearCollect(colPendingWeekAssignments,Filter(colPendingWeekTeamAssignments As member,') -and $readWeekFx.Contains('ClearCollect(colWeekAssignments,colPendingWeekAssignments)')) 'colWeekAssignments holds the PW records of all shown rows (incl. inactive); stored hours mapped after the row rule'
Assert-True ($readWeekFx.Contains('MonHours:mon.HourValue,TueHours:tue.HourValue') -and $readWeekFx -notmatch 'Coalesce\(\w+\.HourValue' -and $readWeekFx -notmatch '\bPatch\(') 'Loader keeps blank days blank (no automatic 0, no writes)'
# Hours Summary: rows with 0 for workers with a period overlapping the chosen report range (27-10-2026: no Today() fallback; no range = no report).
$sumRule=Get-Balanced $buildReport 'Filter(colReportWorkers As candidate,'
$sumData='colReportWorkers:Table({WorkerID:1,HasPeriod:true},{WorkerID:2,HasPeriod:true},{WorkerID:3,HasPeriod:false}),colReportAssignmentPeriods:'+(Get-PeriodTable @(@(1,'7|1','2026,1,5','2026,3,1'),@(2,'7|2','2026,6,1',$null)))+',varReportProjectKey:"7"'
foreach($c in @(@('2026,2,2','2026,2,16','1'),@('2026,5,4','2026,7,6','2'),@('2026,3,2','2026,3,9',''),@('2026,2,23','2026,6,8','1,2'))){
 Assert-Regression ('With({'+$sumData+',varReportZeroFrom:Date('+$c[0]+'),varReportZeroUntil:Date('+$c[1]+')},Concat('+$sumRule+',Text(WorkerID),","))') $c[2] "Hours Summary zero-row rule range $($c[0]) .. $($c[1]) (exclusive) -> [$($c[2])]"
}
Assert-True ($buildReport.Contains('Set(varReportZeroFrom,varReportFrom); Set(varReportZeroUntil,varReportUntil)') -and $buildReport -notmatch 'IsActive=true') 'Hours Summary zero rows use the report range; the old "active" rule is gone'
# Migration (explicit, per project, never on load).
foreach($pair in @(@('btnMigratePreview',$migPrev),@('btnMigrateConfirm',$migConf))){
 $dm=([string]$indexes.Screen1[$pair[0]]['Properties']['DisplayMode']).Trim()
 Assert-True ($dm.StartsWith('=If(') -and $dm.EndsWith(',DisplayMode.Edit,DisplayMode.Disabled)')) "$($pair[0]) DisplayMode shape"
 $g=$dm.Substring(4,$dm.Length-4-',DisplayMode.Edit,DisplayMode.Disabled)'.Length)
 Assert-True ($pair[1].StartsWith('=If('+$g+',')) "$($pair[0]): same guard in DisplayMode and as first OnSelect condition"
 Assert-True ($indexes.Screen1[$pair[0]]['Control'] -eq 'Classic/Button@2.2.0' -and !$indexes.Screen1[$pair[0]]['Properties'].ContainsKey('AccessibleLabel')) "$($pair[0]) Classic/Button without AccessibleLabel (PA2108)"
 Set-Variable -Name ('guard'+$pair[0]) -Value $g
}
Assert-True ($guardbtnMigrateConfirm.StartsWith($guardbtnMigratePreview+' && Coalesce(varMigrationPreviewOK,false) && varMigrationPreviewProjectID=varTeamLoadedProjectID')) 'Confirm guard = preview guard + successful preview of the same loaded project'
$migFx='varTeamLoadState:"Loaded",varSelectionLoaded:true,varTeamNeedsMigration:true,varSelectionBusy:false,varSaving:false,varTeamDirty:false,colSelectionLoadErrors:Filter(Table({Message:"e"}),false),varTeamLoadedProjectID:7,ddProject:{Selected:{Id:7}},varMigrationPreviewOK:true,varMigrationPreviewProjectID:7,colMigrationPlan:Table({HasPeriod:true},{HasPeriod:false})'
Assert-Regression ('With({'+$migFx+'},'+$guardbtnMigrateConfirm+')') $true 'Confirm allowed after preview of the same project'
foreach($c in @(@('varMigrationPreviewOK:true','varMigrationPreviewOK:false','no preview'),@('varMigrationPreviewProjectID:7','varMigrationPreviewProjectID:8','preview of another project'),@('varTeamNeedsMigration:true','varTeamNeedsMigration:false','project already has periods'),@('varTeamDirty:false','varTeamDirty:true','unsaved selection'),@('varSaving:false','varSaving:true','saving'),@('ddProject:{Selected:{Id:7}}','ddProject:{Selected:{Id:8}}','other project selected'),@('colMigrationPlan:Table({HasPeriod:true},{HasPeriod:false})','colMigrationPlan:Table({HasPeriod:false})','nothing to write'),@('varTeamLoadState:"Loaded"','varTeamLoadState:"Failed"','load failed'))){
 Assert-Regression ('With({'+$migFx.Replace($c[0],$c[1])+'},'+$guardbtnMigrateConfirm+')') $false "Confirm blocked: $($c[2])"
}
Assert-True (($all.Values | Where-Object { $_ -match 'Select\(\s*btnMigrate' }).Count -eq 0 -and $readTeam -notmatch 'btnMigrate|colMigrationPlan') 'Migration never runs on load (no Select of migration buttons anywhere)'
Assert-True ($migPrev.Contains('Eerst op TEST-000 uitvoeren.') -and $migPrev.Contains("ClearCollect(colMigrationPeriodsCheck,Filter('Assignment Periods',ProjectKey=varMigrationProjectKey))") -and $migPrev.Contains('Geen actieve koppelingen zonder periode; migratie is niet (meer) nodig.') -and $migPrev.Contains('If(CountRows(colMigrationPeriodsCheck)>=500,')) 'Preview: re-reads periods (500 guard), needs an active assignment without period, shows counts and the TEST-000 hint'
# N1 (reviewer 26-10-2026): migration is per assignment: only Project Workers without any period are planned (also after a partial migration).
$migCand=Get-Balanced $migPrev 'Filter(colMigrationPWRaw As candidate,'
Assert-Regression ('With({colMigrationPWRaw:Table({ID:11,Worker:{Id:1}},{ID:12,Worker:{Id:2}},{ID:13,Worker:{Id:3}}),colMigrationPeriodsCheck:Table({AssignmentKey:"7|2"},{AssignmentKey:"8|3"}),varMigrationProjectKey:"7"},Concat('+$migCand+',Text(ID),","))') '11,13' 'Migration plans only assignments without a period of this project (per PW)'
Assert-True ($migPrev.Contains('ForAll(Filter(colMigrationPWRaw As candidate,') -and $migPrev.Contains('AssignmentKey:varMigrationProjectKey & "|" & Text(member.Worker.Id),Category:rule.Category') -and $migPrev.Contains('If(CountRows(colMigrationPeriodsCheck)+CountIf(colMigrationPlan,HasPeriod)>=500,')) 'Preview plan rows carry their AssignmentKey; 500 guard covers existing + new periods'
Assert-True ($migPrev.Contains('Set(varMigrationHoursCount,CountRows(colMigrationHours)); Set(varMigrationHoursMaxID,First(Sort(colMigrationHours,HourID,SortOrder.Descending)).HourID); Set(varMigrationHoursMaxModified,First(Sort(colMigrationHours,Modified,SortOrder.Descending)).Modified);') -and (Count-Of $migPrev 'Modified:entry.Modified') -eq 3) 'Preview stores an Hours snapshot (count, max ID, max Modified) from all three Hours projections (N8)'
Assert-True ($migPrev.Contains("First(Sort(Filter(Hours,StartsWith(EntryKey,varMigrationPrefix)),'Work Date',SortOrder.Ascending))") -and $migPrev.Contains("First(Sort(Filter(Hours,StartsWith(EntryKey,varMigrationPrefix)),'Work Date',SortOrder.Descending))") -and $migPrev.Contains('If(CountRows(batch)<500,') -and $migPrev.Contains('If(CountRows(monthBatch)<500,') -and $migPrev.Contains('If(CountRows(dayBatch)>=500,')) 'Preview Hours: single batch, else earliest/latest via one sorted query each + month/day paging; a full day blocks'
Assert-True ((Count-Of $migConf 'Patch(') -eq 1 -and $migConf.Contains("ForAll(migrationRows As row,Defaults('Assignment Periods')),") -and $migConf.IndexOf('Set(varDiagMigrationWrites,varDiagMigrationWrites+1)') -lt $migConf.IndexOf('Patch(') -and $migConf.IndexOf('ClearCollect(colMigrationVerify') -gt $migConf.IndexOf('Patch(')) 'Confirm: one table Patch with Defaults, write counter first, verify read afterwards'
# 27-10-2026: Confirm migration invalidates Hours Summary like Save team and Save week, only on the path that writes (write branch, before the Patch);
# scrWeeklyHours.OnVisible then reloads because varReportReady is false.
$migInv='Set(varReportReady,false); Set(varReportValid,false);'
Assert-True ((Count-Of $migConf $migInv) -eq 1 -and $migConf.IndexOf($migInv) -gt $migConf.IndexOf('With({migrationRows:Filter(colMigrationPlan,HasPeriod)},') -and $migConf.IndexOf($migInv) -gt $migConf.IndexOf('Uren gewijzigd sinds preview') -and $migConf.IndexOf($migInv) -lt $migConf.IndexOf('Set(varDiagMigrationWrites,varDiagMigrationWrites+1)') -and $migConf.IndexOf($migInv) -lt $migConf.IndexOf('Patch(')) 'Confirm migration sets varReportReady/varReportValid false in the write branch, before its Patch'
$summaryOnVisible=[regex]::Match([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrWeeklyHours.pa.yaml')),'(?m)^\s+OnVisible: (.+)$').Groups[1].Value
Assert-True ($indexes.Screen1['btnAddtoTeam']['Properties']['OnSelect'].Contains($migInv) -and $indexes.scrHours['btnSaveWeek']['Properties']['OnSelect'].Contains($migInv) -and $summaryOnVisible.Contains('If(!Coalesce(varReportReady,false) || Coalesce(varReportProjectID,0)<>Coalesce(ddReportProject.Selected.ID,0),Select(btnLoadReport))')) 'Save team, Save week and Confirm migration share the invalidation; Hours Summary OnVisible reloads when not ready'
foreach($needle in @('If(IsEmpty(colMigrationErrors) && CountIf(colMigrationPeriodsCheck,AssignmentKey in ShowColumns(Filter(colMigrationPlan,HasPeriod),AssignmentKey))>0,','JSON(Sort(colMigrationPWSnapshot,ID,SortOrder.Ascending))','If(CountRows(colMigrationPWCheck)>=500,','If(CountRows(colMigrationPeriodsCheck)>=500,','Uren gewijzigd sinds preview; voer Preview opnieuw uit.',"First(Sort(Filter(Hours,StartsWith(EntryKey,varMigrationPrefix)),ID,SortOrder.Descending))","First(Sort(Filter(Hours,StartsWith(EntryKey,varMigrationPrefix)),Modified,SortOrder.Descending))")){ Assert-True ($migConf.IndexOf($needle) -gt 0 -and $migConf.IndexOf($needle) -lt $migConf.IndexOf('Patch(')) "Confirm validation before write: $needle" }
Assert-True ($migConf.Contains('Coalesce(varDiagMigrationWrites,0)=0,') -and (Count-Of $migConf 'Set(varTeamLoadState,"Failed")') -eq 1 -and $migConf.IndexOf('Coalesce(varDiagMigrationWrites,0)=0,') -lt $migConf.IndexOf('Set(varTeamLoadState,"Failed")')) 'Confirm: Failed only after a write (partial), zero writes keep state'
$migRule=Get-Balanced $migPrev 'If(migActive && migHasHours,'
function Get-MigrationFx($a,$h){ 'With({migActive:'+$a+',migHasHours:'+$h+',migFirstMonday:Date(2026,3,2),migLastSunday:Date(2026,5,10),migTodayMonday:Date(2026,10,26)},With({r:'+$migRule+'},r.Category & "|" & Text(r.HasPeriod) & "|" & If(IsBlank(r.From),"-",Text(r.From,"yyyy-mm-dd")) & "|" & If(IsBlank(r.Until),"-",Text(r.Until,"yyyy-mm-dd"))))' }
foreach($c in @(@('true','true','ActiveWithHours|true|2026-03-02|-'),@('true','false','ActiveWithoutHours|true|2026-10-26|-'),@('false','true','InactiveWithHours|true|2026-03-02|2026-05-10'),@('false','false','InactiveWithoutHours|false|-|-'))){
 Assert-Regression (Get-MigrationFx $c[0] $c[1]) $c[2] "Migration category active=$($c[0]) hours=$($c[1])"
}
$migFirst=Get-Balanced $migPrev 'If(IsEmpty(memberHours),Blank(),DateAdd(Date(Year(firstDay)';$migLast=Get-Balanced $migPrev 'If(IsEmpty(memberHours),Blank(),DateAdd(Date(Year(lastDay)'
foreach($c in @(@('2026,3,4','2026-03-02','2026-03-08'),@('2026,3,2','2026-03-02','2026-03-08'),@('2026,3,8','2026-03-02','2026-03-08'),@('2027,1,1','2026-12-28','2027-01-03'))){
 $mh='memberHours:Table({WorkDay:Date(2026,1,1)}),firstDay:Date('+$c[0]+'),lastDay:Date('+$c[0]+')'
 Assert-Regression ('Text(With({'+$mh+'},'+$migFirst+'),"yyyy-mm-dd")') $c[1] "Migration From = Monday of week of $($c[0])"
 Assert-Regression ('Text(With({'+$mh+'},'+$migLast+'),"yyyy-mm-dd")') $c[2] "Migration Until = Sunday of week of $($c[0])"
}
# Screen1 week picker (shared week state with Weekly Hours): real OnChange with actions replaced by tags.
$tp=$indexes.Screen1['dpTeamWeek'];$hp=$indexes.scrHours['dpHoursWeek']
Assert-True ($tp['Control'] -eq 'ModernDatePicker@1.0.0' -and $tp['Properties']['DefaultDate'] -ceq '=Coalesce(varHoursPickedDay,Today())' -and $tp['Properties']['Format'] -ceq $hp['Properties']['Format'] -and $tp['Properties']['StartOfWeek'] -ceq $hp['Properties']['StartOfWeek'] -and !$tp['Properties'].ContainsKey('StartDate') -and !$tp['Properties'].ContainsKey('EndDate')) 'dpTeamWeek = dpHoursWeek settings, shared varHoursPickedDay'
Assert-True ($indexes.Screen1['lblTeamWeekKW']['Properties']['Text'] -ceq $indexes.scrHours['lblHoursWeekKW']['Properties']['Text']) 'lblTeamWeekKW uses the same YYYY KWxx formula as lblHoursWeekKW (shared varHoursWeekMonday)'
Assert-True (([string]$tp['Properties']['DisplayMode']) -ceq ('=If(Coalesce(varSelectionBusy,false) || Coalesce(varSaving,false) || Coalesce(varTeamDirty,false) || '+$weekDirty+',DisplayMode.Disabled,DisplayMode.Edit)')) 'dpTeamWeek disabled while loading/saving, with an unsaved selection or with unsaved Weekly Hours hours (same dirty term as OnChange/dpHoursWeek/btnRefreshWeek) (N7)'
$tpDm=([string]$tp['Properties']['DisplayMode']).Trim().Substring(1).Replace($weekDirty,'weekDirty').Replace('DisplayMode.Disabled','"Disabled"').Replace('DisplayMode.Edit','"Edit"')
foreach($c in @(@('false','false','Edit'),@('true','false','Disabled'),@('false','true','Disabled'))){
 Assert-Regression ('With({varSelectionBusy:false,varSaving:false,varTeamDirty:'+$c[0]+',weekDirty:'+$c[1]+'},'+$tpDm+')') $c[2] "dpTeamWeek DisplayMode: teamDirty=$($c[0]) weekDirty=$($c[1]) -> $($c[2])"
}
$tchg=([string]$tp['Properties']['OnChange']).TrimStart('=')
foreach($pair in @(
 @('Set(varHoursPickedDay,selectedDay); Set(varHoursWeekMonday,monday); Select(btnApplyTeamWeek)','"APPLY"'),
 @('Set(varHoursPickedDay,selectedDay)','"PICK"'),
 @('Reset(dpTeamWeek); Notify("Week niet gewisseld: onopgeslagen selectie of uren behouden. Sla eerst op.",NotificationType.Warning,15000)','"RESET+NOTIFY"'),
 @('Reset(dpTeamWeek)','"RESET"'))){
 if(!$tchg.Contains($pair[0])){ throw "FAIL dpTeamWeek.OnChange mist actie: $($pair[0])" }
 $tchg=$tchg.Replace($pair[0],$pair[1])
}
Assert-True ($tchg -notmatch '\b(Set|Select|Reset|Notify)\(' -and $tchg.Contains($weekDirty)) 'dpTeamWeek.OnChange: only tagged actions; Weekly Hours dirty check identical to scrHours'
$tchg=$tchg.Replace('Self.SelectedDate','pickerSelf.SelectedDate').Replace($weekDirty,'weekDirty')
function Get-TeamPickFx($sel,$picked,$monday,$dirty,$wdirty='false',$busy='false'){ 'With({pickerSelf:{SelectedDate:'+$sel+'},varSelectionBusy:'+$busy+',varSaving:false,varHoursPickedDay:'+$picked+',varHoursWeekMonday:'+$monday+',varTeamDirty:'+$dirty+',weekDirty:'+$wdirty+'},Coalesce('+$tchg+',"NONE"))' }
Assert-Regression (Get-TeamPickFx 'Date(2026,10,28)' 'Date(2026,10,20)' 'Date(2026,10,19)' 'false') 'APPLY' 'Screen1 week: clean change of week recomputes locally'
Assert-Regression (Get-TeamPickFx 'Date(2026,10,22)' 'Date(2026,10,20)' 'Date(2026,10,19)' 'false') 'PICK' 'Screen1 week: other day same week only stores the day'
Assert-Regression (Get-TeamPickFx 'Date(2026,10,20)' 'Date(2026,10,20)' 'Date(2026,10,19)' 'true') 'NONE' 'Screen1 week: OnChange after Reset (same day) is a no-op'
Assert-Regression (Get-TeamPickFx 'Date(2026,10,28)' 'Date(2026,10,20)' 'Date(2026,10,19)' 'true') 'RESET+NOTIFY' 'Screen1 week: unsaved team selection blocks the week change (reset + message)'
Assert-Regression (Get-TeamPickFx 'Date(2026,10,28)' 'Date(2026,10,20)' 'Date(2026,10,19)' 'false' 'true') 'RESET+NOTIFY' 'Screen1 week: unsaved Weekly Hours input blocks the week change'
Assert-Regression (Get-TeamPickFx 'Date(2026,10,28)' 'Date(2026,10,20)' 'Date(2026,10,19)' 'false' 'false' 'true') 'NONE' 'Screen1 week: skipped while loading'
Assert-Regression (Get-TeamPickFx $Bd 'Date(2026,10,20)' 'Date(2026,10,19)' 'false') 'RESET' 'Screen1 week: emptied field is reset'
$s1OnVisible=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/Screen1.pa.yaml')))['Screens']['Screen1']['Properties']['OnVisible']
Assert-True ($s1OnVisible.Contains('If(IsBlank(varHoursPickedDay),Set(varHoursPickedDay,Today())); Set(varHoursWeekMonday,DateAdd(varHoursPickedDay,1-Weekday(varHoursPickedDay,StartOfWeek.Monday),TimeUnit.Days));') -and $s1OnVisible.Contains('!Coalesce(varTeamDirty,false) && varTeamLoadedWeekMonday<>varHoursWeekMonday,Select(btnApplyTeamWeek)')) 'Screen1.OnVisible: shared week initialised like scrHours; a week changed on Weekly Hours is applied locally when clean'
# Reviewer fixes 26-10-2026.
# N1: invariant Active = open period (only for assignments that have periods) and per-assignment migration need.
$needFx=Get-Balanced $readTeam 'CountIf(colTeamProjectAssignments As pw,pw.Active=true'
Assert-True ($readTeam.Contains('Set(varTeamNeedsMigration,'+$needFx+'>0);')) 'varTeamNeedsMigration = at least one active assignment of the project without any period (per PW)'
$mismatchFx=Get-Balanced $readTeam 'CountIf(colTeamProjectAssignments As pw,With({periodCount:'
$n1Pw='colTeamProjectAssignments:Table({ID:11,Worker:{Id:1},Active:true},{ID:12,Worker:{Id:2},Active:false},{ID:13,Worker:{Id:3},Active:true},{ID:14,Worker:{Id:4},Active:false}),varSelectionProjectID:7'
$n1Ok=(Get-PeriodTable @(@(1,'7|1','2026,10,5',$null),@(2,'7|2','2026,9,7','2026,10,25'),@(3,'7|3','2026,9,7',$null)))
Assert-Regression ('With({'+$n1Pw+',colTeamPeriods:'+$n1Ok+'},'+$mismatchFx+')') 0 'Invariant: Active=true with open period, Active=false with closed/no period -> no mismatch'
Assert-Regression ('With({'+$n1Pw+',colTeamPeriods:'+$n1Ok+'},'+$needFx+')') 0 'Migration need: every active assignment has a period -> 0 assignments need migration'
$n1Bad=(Get-PeriodTable @(@(1,'7|1','2026,9,7','2026,10,25'),@(2,'7|2','2026,10,5',$null),@(3,'7|3','2026,9,7',$null)))
Assert-Regression ('With({'+$n1Pw+',colTeamPeriods:'+$n1Bad+'},'+$mismatchFx+')') 2 'Invariant: Active=true without open period and Active=false with open period -> 2 mismatches (read-only)'
$n1Partial=(Get-PeriodTable @(,@(2,'7|2','2026,9,7','2026,10,25')))
Assert-Regression ('With({'+$n1Pw+',colTeamPeriods:'+$n1Partial+'},'+$needFx+')') 2 'Migration need: 2 active assignments without any period (e.g. after a partial migration) -> needed'
Assert-Regression ('With({'+$n1Pw+',colTeamPeriods:'+$n1Partial+'},'+$mismatchFx+')') 0 'Invariant: active assignment without any period is a migration case, not a mismatch'
Assert-True ($readTeam.Contains('Set(varSelectionKeysValid,varTeamPeriodsValid && varTeamActiveMismatchCount=0 && ') -and $twLoad.Contains('Active komt bij " & Text(varTeamActiveMismatchCount) & " koppeling(en) niet overeen met een open periode')) 'Invariant mismatch makes Screen1 read-only (keys invalid) with a clear message'
# R2: Weekly Hours migration hint uses the same per-assignment rule (active PW of the loaded team without any period).
$weekNeedFx=Get-Balanced $readWeekFx 'CountIf(colPendingWeekTeamAssignments As pw,pw.Active=true'
Assert-True ($readWeekFx.Contains('Set(varPendingWeekNeedsMigration,'+$weekNeedFx+'>0);') -and $weekNeedFx.Replace('colPendingWeekTeamAssignments','colTeamProjectAssignments').Replace('colPendingWeekPeriods','colTeamPeriods').Replace('varPendingHoursProjectID','varSelectionProjectID') -ceq $needFx) 'Weekly Hours migration need = Screen1 per-PW rule (same formula on the week collections)'
$wn='colPendingWeekTeamAssignments:Table({ID:11,Worker:{Id:1},Active:true},{ID:12,Worker:{Id:2},Active:false}),varPendingHoursProjectID:7'
foreach($c in @(@((Get-PeriodTable @(,@(1,'7|1','2026,10,5',$null))),0,'active PW has a period -> no hint'),@((Get-PeriodTable @(,@(2,'7|2','2026,9,7','2026,10,25'))),1,'active PW without any period (other PW has one) -> hint'),@((Get-PeriodTable @()),1,'no periods at all, one active PW -> hint'),@((Get-PeriodTable @(,@(1,'8|1','2026,10,5',$null))),1,'period of another project does not count'))){
 Assert-Regression ('With({'+$wn+',colPendingWeekPeriods:'+$c[0]+'},'+$weekNeedFx+')') $c[1] "Weekly Hours migration need: $($c[2])"
}
# N2: Save team blocked while any assignment still needs migration.
Assert-True ($readTeam.Contains('Set(varTeamMigrationBlocksSave,varTeamNeedsMigration);')) 'varTeamMigrationBlocksSave = varTeamNeedsMigration (N2)'
Assert-True ([string]$indexes.Screen1['btnMigratePreview']['Properties']['Visible'] -ceq '=Coalesce(varTeamNeedsMigration,false) && varTeamLoadState="Loaded" && varTeamLoadedProjectID=ddProject.Selected.Id') 'Migration visible exactly while an active assignment has no period'
# N4: exactly one success message; CLOSE/SHORTEN adds the end-of-week note.
$okMsg=Get-Balanced $teamSave 'If(varDiagTeamSaveWrites=0,'
Assert-True ($okMsg.Contains('"Geen wijzigingen nodig; niets geschreven."') -and $teamSave -notmatch [regex]::Escape('"Geen wijzigingen nodig; niets geschreven. ","") &')) 'Success message is If(no writes, "Geen wijzigingen nodig", "Teamwijzigingen opgeslagen ...") - never both'
foreach($c in @(
 @('0','Table({Action:"NONE"})','Geen wijzigingen nodig; niets geschreven.'),
 @('2','Table({Action:"NEW"},{Action:"TEAM"})','Teamwijzigingen opgeslagen. Bestaande koppelingen worden opnieuw gelezen.'),
 @('2','Table({Action:"CLOSE"},{Action:"SHORTEN"},{Action:"NEW"})','Teamwijzigingen opgeslagen. Bestaande koppelingen worden opnieuw gelezen. 2 medewerker(s) afgemeld per einde van deze week; vanaf volgende week niet meer geselecteerd.'))){
 Assert-Regression ('With({varDiagTeamSaveWrites:'+$c[0]+',colTeamPlan:'+$c[1]+'},'+$okMsg+')') $c[2] "Save team success message (writes=$($c[0]))"
}
# N8: Confirm blocks when the project's Hours changed since the preview (max ID, max Modified, count when not paged).
$hoursChanged=Get-Balanced $migConf '(Coalesce(varMigrationCheckMaxID,0)'
$h8='varMigrationCheckMaxID:120,varMigrationHoursMaxID:120,varMigrationCheckMaxModified:DateTime(2026,10,26,9,0,0),varMigrationHoursMaxModified:DateTime(2026,10,26,9,0,0),varMigrationHoursPaged:false,varMigrationHoursCount:2,colMigrationHoursCheck:Table({HourID:1},{HourID:120})'
foreach($c in @(
 @('','',$false,'unchanged Hours -> allowed'),
 @('varMigrationCheckMaxID:120','varMigrationCheckMaxID:121',$true,'new Hours row (higher ID) -> blocked'),
 @('varMigrationCheckMaxModified:DateTime(2026,10,26,9,0,0)','varMigrationCheckMaxModified:DateTime(2026,10,26,10,0,0)',$true,'edited Hours row (later Modified) -> blocked'),
 @('colMigrationHoursCheck:Table({HourID:1},{HourID:120})','colMigrationHoursCheck:Table({HourID:120})',$true,'deleted Hours row (count differs, not paged) -> blocked'),
 @('varMigrationCheckMaxID:120','varMigrationCheckMaxID:Blank()',$true,'all Hours gone -> blocked'))){
 $fx=if($c[0]){$h8.Replace($c[0],$c[1])}else{$h8}
 Assert-Regression ('With({'+$fx+'},'+$hoursChanged+')') $c[2] "Confirm Hours-changed check: $($c[3])"
}
Assert-True ($migConf.IndexOf('Uren gewijzigd sinds preview') -lt $migConf.IndexOf('Patch(') -and $migConf.Contains('CountRows(colMigrationVerify)<>CountRows(colMigrationPeriodsCheck)+CountIf(colMigrationPlan,HasPeriod)')) 'Confirm: Hours check before the write; verify count = existing + written periods'
# N6 (Eddy 26-10-2026): rows shown only because of stored hours (no period overlapping the week): existing day records stay
# correctable (also to 0); a NEW day (no stored record = blank OldHours) is blocked in the local pre-save validation (zero writes).
$saveWeekFx=$indexes.scrHours['btnSaveWeek']['Properties']['OnSelect']
$n6Pred='!Coalesce(c.HasPeriod,false) && IsBlank(c.OldHours)'
$n6Msg='geen periode in deze week; nieuwe dag niet toegestaan (periode regelen op Project / team)'
$n6i=$saveWeekFx.IndexOf($n6Msg)
Assert-True ($saveWeekFx.Contains($n6Pred) -and $n6i -gt 0 -and $n6i -lt $saveWeekFx.IndexOf('ClearCollect(colSaveCheckRaw') -and $n6i -lt $saveWeekFx.IndexOf('Set(varDiagSaveWrites,varDiagSaveWrites+1)') -and $n6i -lt $saveWeekFx.IndexOf('Patch(Hours,')) 'N6 rule collected in the local validation before pre-read and before any write (zero writes; message shown as "<Worker>: ...")'
Assert-True ($saveWeekFx.Contains('HasPeriod: r.HasPeriod,') -and $readWeekFx.Contains('HasPeriod:CountIf(colPendingWeekPeriods,')) 'HasPeriod comes from the already loaded periods (row field set by the loader, carried into colHoursChanges; no remote read in ForAll)'
foreach($c in @(
 @('{HasPeriod:false,OldHours:8,NewHours:0}',$false,'no period + existing record corrected to 0 -> allowed'),
 @('{HasPeriod:false,OldHours:8,NewHours:7.5}',$false,'no period + existing record changed -> allowed'),
 @('{HasPeriod:false,OldHours:Blank(),NewHours:8}',$true,'no period + new day -> blocked'),
 @('{HasPeriod:false,OldHours:Blank(),NewHours:0}',$true,'no period + new day with 0 -> blocked'),
 @('{HasPeriod:Blank(),OldHours:Blank(),NewHours:8}',$true,'unknown period state + new day -> blocked (fail closed)'),
 @('{HasPeriod:true,OldHours:Blank(),NewHours:8}',$false,'overlapping period + new day -> allowed'))){
 Assert-Regression ('With({c:'+$c[0]+'},'+$n6Pred+')') $c[1] "N6: $($c[2])"
}
$hpFx=(Get-Balanced $readWeekFx 'HasPeriod:CountIf(colPendingWeekPeriods,').Substring('HasPeriod:'.Length)+'>0'
Assert-True ($readWeekFx.Contains('HasPeriod:'+$hpFx+',')) 'Row HasPeriod = CountIf(loaded periods overlapping Mon..Sun)>0'
$hpData='colPendingWeekPeriods:'+(Get-PeriodTable @(@(1,'7|1','2026,10,5',$null),@(2,'7|2','2026,9,7','2026,10,25')))+',varPendingHoursProjectID:7,varPendingWeekMonday:Date(2026,10,26),varPendingWeekSunday:Date(2026,11,1)'
foreach($c in @(@(1,$true,'open period'),@(2,$false,'period ended before the week (row shown only for stored hours)'),@(3,$false,'no period at all'))){
 Assert-Regression ('With({'+$hpData+',member:{Worker:{Id:'+$c[0]+'}}},'+$hpFx+')') $c[1] "Row HasPeriod: $($c[2])"
}
# Workers columns removed in SharePoint by Eddy (26-10-2026): Employer Code (field_4), Employer Name (field_5), Phone (field_7), Email (field_8).
# The cache keeps the record field 'Employer Name', filled from the Employer lookup; Src must not reference the removed columns.
$workerProj="ForAll(Workers As worker,{ID:worker.ID,'First Name':worker.'First Name',Surname:worker.Surname,'Employer Name':worker.Employer.Value,Employer:worker.Employer,Trade:worker.Trade})"
Assert-True ($readTeam.Contains($workerProj) -and $loadReport.Contains($workerProj)) 'Workers cache projection identical in Screen1 and Hours Summary; Employer Name taken from the Employer lookup'
$srcAll=(Get-ChildItem (Join-Path $projectRoot 'Src') -Filter *.pa.yaml | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n"
foreach($bad in @("worker.'Employer Name'",'worker.Phone','worker.Email',"worker.'Employer Code'")){ Assert-True (!$srcAll.Contains($bad)) "Src does not reference removed Workers column: $bad" }
Assert-True ($srcAll -notmatch '\bfield_\d+\b') 'Src has no internal SharePoint field_<n> names'
# Every display name used in Src for these sources exists in the project's data-source metadata (read-only; .msapr is not modified).
Add-Type -AssemblyName System.IO.Compression.FileSystem
$msaprZip=[IO.Compression.ZipFile]::OpenRead((Join-Path $projectRoot 'Site Managment_VS.msapr'))
try { $dsReader=New-Object IO.StreamReader(($msaprZip.Entries | Where-Object FullName -eq 'msapp\References\DataSources.json').Open()); $dsJson=$dsReader.ReadToEnd() | ConvertFrom-Json; $dsReader.Dispose() } finally { $msaprZip.Dispose() }
$usedColumns=@{
 'Workers'=@('ID','First Name','Surname','Employer','Trade','Active')
 'Employers'=@('ID','Title','Employer Code','Address','Postalcode','City','Country','Contact Name','Contact Email','Contact Phone','Active')
 'Projects'=@('ID','Title','Project Number','Project Reference')
 'Hours'=@('ID','Title','EntryKey','Work Date','Assignment','Employer','Team','Trade','Hours','Modified')
 'Project Workers'=@('ID','Title','ProjectKey','AssignmentKey','Project','Worker','Team','Active')
 'Assignment Periods'=@('ID','AssignmentKey','ProjectKey','From','Until')
}
foreach($ds in $usedColumns.Keys){
 $entry=$dsJson.DataSources | Where-Object Name -eq $ds
 Assert-True ($null -ne $entry) "Data source '$ds' present in metadata"
 $display=@($entry.ConnectedDataSourceInfoNameMapping.PSObject.Properties | ForEach-Object { [string]$_.Value })
 foreach($col in $usedColumns[$ds]){ Assert-True ($col -cin $display) "Metadata: $ds has display name '$col'" }
}
# R4: Assignment Periods From (internal From) and Until (internal Till) are date-only columns in the refreshed metadata.
$apMeta=($dsJson.DataSources | Where-Object Name -eq 'Assignment Periods').DataEntityMetadataJson
$apText=($apMeta.PSObject.Properties | ForEach-Object { [string]$_.Value }) -join ''
foreach($col in @('From','Till')){ Assert-True ($apText -match ('"'+$col+'":\{[^{}]*"format":"date"[,}]')) "Metadata: Assignment Periods.$col has format date (date only)" }
# Contractors build (28-10-2026): only scrContractors reads/writes Employers; Employer Code (internal EmployerCode1) is only read in its projection, never written (flow MS-019).
$srcNonAdmin=(Get-ChildItem (Join-Path $projectRoot 'Src') -Filter *.pa.yaml | Where-Object Name -ne 'scrContractors.pa.yaml' | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n"
Assert-True ($srcNonAdmin -notmatch "\bEmployers\b\s*[,)]" -and $srcAll -notmatch "EmployerCode1") 'Only scrContractors reads the Employers list; internal name EmployerCode1 not used'
Assert-True (([regex]::Matches($srcAll,"'Employer Code'")).Count -eq ([regex]::Matches($srcAll,"emp\.'Employer Code'")).Count) "Employer Code only read as emp.'Employer Code' in the Contractors projection (never a Patch field)"
Assert-True ($srcAll -notmatch "\b(?:Remove|RemoveIf|Clear)\(\s*(?:Employers|Workers|Projects|Hours|'Project Workers'|'Assignment Periods')\b") 'No Remove/RemoveIf/Clear on SharePoint lists anywhere in Src'
Write-Output 'PASS Assignment periods: delegable period reads with global ProjectKey, 500 guards, staging, decision fixtures, checkbox/row/summary rules, migration guards/categories, Screen1 week picker. Studio binding, delegation in Monitor and functional tests NOT verified.'
Write-Output 'PASS batch save structure. Studio binding (table Patch on collection base records, lookup/choice records), delegation and online behaviour NOT verified.'
Write-Output 'LIVE STILL OPEN: actual incident edits, connector auth, Studio binding/delegation, failure injection and online loading.'



