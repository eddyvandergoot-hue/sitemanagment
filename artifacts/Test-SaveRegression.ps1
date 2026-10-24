$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$regressionEngine=New-Object Microsoft.PowerFx.RecalcEngine
$regressionOptions=New-Object Microsoft.PowerFx.ParserOptions
$regressionOptions.Culture=[Globalization.CultureInfo]::GetCultureInfo('en-US')
function Index-RegressionControls($entries,$index){foreach($entry in $entries){$name=@($entry.Keys)[0];$index[$name]=$entry[$name];Index-RegressionControls $entry[$name]['Children'] $index}}
$indexes=@{};$count=0
foreach($screen in @('Screen1','scrHours','scrWeeklyHours')){
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
Assert-Regression ('With({'+$teamFixture.Replace('colSelectedWorkers:Table({ID:1})','colSelectedWorkers:Filter(Table({ID:1}),false)')+'},'+$guards.team+')') $false 'Empty team selection blocks all deactivation'
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
foreach($fx in @($team,$week,$indexes.scrWeeklyHours['btnLoadReport']['Properties']['OnSelect'],$indexes.scrWeeklyHours['btnBuildReport']['Properties']['OnSelect'])){
 if($fx -match '\b(Patch|UpdateIf|RemoveIf|SubmitForm)\s*\('){throw 'Mutation in loader'}
}
if($team -notmatch 'If\(Coalesce\(varTeamDirty,false\)' -or $week -notmatch '^=If\(JSON\(ShowColumns'){throw 'Dirty input gate missing'}
if($team -notmatch 'ClearCollect\(colCurrentTeamAssignments,colPendingTeamAssignments\)' -or $week -notmatch 'ClearCollect\(colWeekRows,colPendingWeekRows\)'){throw 'Staged commit missing'}
if($team -match 'Clear\(colSelectedWorkers\)|Clear\(colCurrentTeamAssignments\)' -or $week -match 'Clear\(colWeekRows\)|Clear\(colWeekOriginal\)'){throw 'Loader clears committed user data'}
if($indexes.Screen1['btnAddtoTeam']['Properties']['OnSelect'] -notmatch 'assignment.Worker.Id in ShowColumns\(colTeamRemovedIDs,WorkerID\)'){throw 'Explicit removal gate absent'}
$allowedWrites=@('btnAddtoTeam','btnSaveWeek')
foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){foreach($prop in $indexes[$screen][$name]['Properties'].Keys){
 $fx=[string]$indexes[$screen][$name]['Properties'][$prop]
 if($fx -match '\bPatch\(\s*(?:''Project Workers''|Hours)\s*,' -and ($name -notin $allowedWrites -or $prop -ne 'OnSelect')){throw "Unexpected source write: $name.$prop"}
 if($fx -match '\b(?:Remove|RemoveIf|Update|UpdateIf)\(\s*(?:''Project Workers''|Hours)\s*,' -or $fx -match '\.Run\('){throw "Unexpected external mutation/flow: $name.$prop"}
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
 Assert-True ($oldDm -ceq $new['DisplayMode']) "$($pair[1]) DisplayMode equal to checkpoint (Save week: only ISO year/KW -> picked week)"
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
foreach($msg in @('Open eerst een project, team en werkweek.','Geen gewijzigde uren.','Gebruik 0 t/m 24 uur, met maximaal twee decimalen.','Gebruik 0 om eerder ingevulde uren te corrigeren naar geen gewerkte uren.',
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
Assert-True ((Count-Of $teamSave "Filter('Project Workers',") -eq 1 -and $teamSave.Contains("ClearCollect(colTeamSaveCheck,Filter('Project Workers',ProjectKey=varTeamSaveProjectKey))")) 'Save team single pre-read: ProjectKey = global var (incl. inactive), no StartsWith'
Assert-True ($teamSave -notmatch 'StartsWith\(' -and $teamSave.IndexOf('Set(varTeamSaveProjectKey,Text(varTeamLoadedProjectID));') -ge 0 -and $teamSave.IndexOf('Set(varTeamSaveProjectKey') -lt $teamSave.IndexOf("Filter('Project Workers'")) 'Save team key var set before pre-read'
Assert-True ($teamSave.Contains('CountRows(colTeamSaveCheck)>=500') -and $teamSave.Contains('CountIf(colTeamSaveCheck,Project.Id<>varTeamLoadedProjectID)>0')) 'Save team 500 guard and Project.Id cross-check'
Assert-True ($teamSave.Contains('stored.AssignmentKey = varTeamSaveProjectKey & "|" & Text(person.ID)') -and $teamSave.Contains('AssignmentKey = varTeamSaveProjectKey & "|" & Text(person.ID)) > 1')) 'Save team local AssignmentKey match on global key'
Assert-True ((Count-Of $teamSave "ClearCollect(colTeamPatched,Patch(") -eq 1 -and (Count-Of $teamSave "ClearCollect(colTeamDeactivated,Patch(") -eq 1 -and ([regex]::Matches($teamSave,'\bPatch\(')).Count -eq 2) 'Save team exactly two table Patch calls (upsert / deactivate)'
Assert-True ($teamSave.IndexOf('ClearCollect(colTeamPatched') -gt $teamSave.IndexOf('Collect(colTeamToDeactivate')) 'Removal checks before any team write'
foreach($msg in @('De koppeling leverde geen SharePoint-ID op.','Een bestaande koppeling is niet meer beschikbaar.','Een koppeling is ondertussen naar een ander project of team gewijzigd. Kies het team opnieuw.','De toewijzing kon niet worden gedeactiveerd.','Teamwijzigingen opgeslagen. Bestaande koppelingen worden opnieuw gelezen.','Niet alle wijzigingen zijn opgeslagen: ','Team opslaan gestopt: ')){
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
$allowedScoped=@{'scrWeeklyHours.btnLoadReport.OnSelect'=@('monthFrom','monthUntil','dayFrom','dayUntil')}
$strNl=0;$sites=0
foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){foreach($prop in $indexes[$screen][$name]['Properties'].Keys){
 $fx=[string]$indexes[$screen][$name]['Properties'][$prop];$where="$screen.$name.$prop"
 $in=$false;for($i=0;$i -lt $fx.Length;$i++){$ch=$fx[$i];if($ch -eq '"'){if($in -and $i+1 -lt $fx.Length -and $fx[$i+1] -eq '"'){$i++;continue};$in=-not $in;continue};if($in -and ($ch -eq "`n" -or $ch -eq "`r")){$strNl++;Write-Output "NEWLINE IN STRING: $where";$in=$false}}
 foreach($m in [regex]::Matches($fx,"\b(Filter|LookUp)\(\s*(Hours|'Project Workers')\s*,")){
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
Write-Output 'PASS batch save structure. Studio binding (table Patch on collection base records, lookup/choice records), delegation and online behaviour NOT verified.'
Write-Output 'LIVE STILL OPEN: actual incident edits, connector auth, Studio binding/delegation, failure injection and online loading.'



