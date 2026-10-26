$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$regressionEngine=New-Object Microsoft.PowerFx.RecalcEngine
$regressionOptions=New-Object Microsoft.PowerFx.ParserOptions
$regressionOptions.Culture=[Globalization.CultureInfo]::GetCultureInfo('en-US')
function Index-RegressionControls($entries,$index){foreach($entry in $entries){$name=@($entry.Keys)[0];$index[$name]=$entry[$name];Index-RegressionControls $entry[$name]['Children'] $index}}
$indexes=@{};$count=0
foreach($screen in @('scrHome','Screen1','scrHours','scrWeeklyHours')){
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
 foreach($sel in [regex]::Matches($fx,'\bSelect\(\s*(\w+)\s*\)')){ Assert-True ($sel.Groups[1].Value -in @('btnTileProjectTeam','btnTileWeeklyHours','btnTileHoursSummary')) "scrHome.$name.$prop selects only a navigation tile ($($sel.Groups[1].Value))" }
 foreach($nav in [regex]::Matches($fx,'\bNavigate\(\s*(\w+)')){ Assert-True ($nav.Groups[1].Value -in @('Screen1','scrHours','scrWeeklyHours')) "scrHome.$name.$prop navigates to a known screen ($($nav.Groups[1].Value))" }
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
Write-Output 'PASS batch save structure. Studio binding (table Patch on collection base records, lookup/choice records), delegation and online behaviour NOT verified.'
Write-Output 'LIVE STILL OPEN: actual incident edits, connector auth, Studio binding/delegation, failure injection and online loading.'



