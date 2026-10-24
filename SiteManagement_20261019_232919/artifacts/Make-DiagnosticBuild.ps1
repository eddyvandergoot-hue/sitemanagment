param([Parameter(Mandatory)][string]$OutDir)
# Builds a separate diagnostic copy of the app with Trace markers for Live Monitor.
# Src itself is never modified. Only Trace(...) calls and Set(varDiag...,Now()) timers are inserted at fixed anchors;
# removing the inserted snippets must give back the original source exactly.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$stamp=Split-Path $OutDir -Leaf
$source=Join-Path $OutDir 'source'
if(Test-Path $source){throw "Target exists: $source"}
New-Item -ItemType Directory -Force (Join-Path $source 'Src') | Out-Null
# Only app sources: stray files in Src (e.g. browser downloads) are not copied.
Copy-Item (Join-Path $root 'Src\*.pa.yaml') (Join-Path $source 'Src')
Copy-Item (Join-Path $root 'Site Managment_VS.msapr') $source

function Tr([string]$scenario,[string]$step,[string]$timer,[string]$fields=''){
 $elapsed=if($timer){",ElapsedMs:DateDiff($timer,Now(),TimeUnit.Milliseconds)"}else{''}
 "Trace(`"DIAG|$scenario|$step`",TraceSeverity.Information,{Scenario:`"$scenario`",Step:`"$step`"$elapsed$fields}); "
}
function TrStart([string]$scenario,[string]$timer,[string]$fields=''){"Set($timer,Now()); "+(Tr $scenario 'Start' $timer $fields)}
$errTeam=',Errors:CountRows(colSelectionLoadErrors)';$errWeek=',Errors:CountRows(colWeekLoadErrors)';$errRep=',Errors:CountRows(colReportLoadErrors)'
# Each entry: file, anchor with one § marking the insertion point (anchor must occur exactly once), inserted text.
$inserts=@(
 @('App.pa.yaml','OnStart: =§',(Tr 'App' 'OnStart' '' ",Build:`"$stamp`"")),
 @('Screen1.pa.yaml','OnVisible: =§',(Tr 'Screen1' 'OnVisible' '' ',Dirty:Coalesce(varTeamDirty,false),LoadState:Coalesce(varTeamLoadState,"")')),
 @('Screen1.pa.yaml','Set(varSelectionBusy,true); Set(varTeamLoadState,"Loading");§',(TrStart 'Team' 'varDiagTeamT0' ',ProjectID:Coalesce(ddProject.Selected.Id,0),Team:Coalesce(ddTeam.Selected.Value,""),Forced:Coalesce(varForceTeamRefresh,false),MastersCached:Coalesce(varMastersReady,false)')),
 @('Screen1.pa.yaml','§If(!Coalesce(varMastersReady,false) || Coalesce(varForceTeamRefresh,false),',(Tr 'Team' 'AfterRefresh' 'varDiagTeamT0' $errTeam)),
 @('Screen1.pa.yaml','§Set(varForceTeamRefresh,false);',(Tr 'Team' 'AfterMasters' 'varDiagTeamT0' (',Projects:CountRows(colSelectionProjects),TeamChoices:CountRows(colTeamChoices)'+$errTeam))),
 @('Screen1.pa.yaml','                 §Set(varSelectionProjectID,ddProject.Selected.Id); Set(varSelectionProjectKey,Text(varSelectionProjectID));',(Tr 'Team' 'AfterWorkersCheck' 'varDiagTeamT0' $errTeam)),
 @('Screen1.pa.yaml','§If(CountRows(colPendingTeamAssignments)>=500,',(Tr 'Team' 'AfterAssignments' 'varDiagTeamT0' (',Assignments:CountRows(colPendingTeamAssignments)'+$errTeam))),
 @('Screen1.pa.yaml','§ClearCollect(colCurrentTeamAssignments,colPendingTeamAssignments);',(Tr 'Team' 'AfterWorkerLookups' 'varDiagTeamT0' (',Workers:CountRows(colPendingSelectedWorkers)'+$errTeam))),
 @('Screen1.pa.yaml','§Set(varSelectionBusy,false)',(Tr 'Team' 'End' 'varDiagTeamT0' (',State:Coalesce(varTeamLoadState,""),Assignments:CountRows(colCurrentTeamAssignments)'+$errTeam))),
 @('Screen1.pa.yaml','Set(varReportReady,false); Set(varReportValid,false); Set(varSaving, true);§',(TrStart 'SaveTeam' 'varDiagSaveTeamT0' ',Selected:CountRows(colSelectedWorkers),Removed:CountRows(colTeamRemovedIDs),Original:CountRows(colTeamOriginalSelection)')),
 @('Screen1.pa.yaml','§Set(varSaving, false)',(Tr 'SaveTeam' 'BeforeReload' 'varDiagSaveTeamT0' ',Errors:CountRows(colAssignmentErrors)')),
 @('Screen1.pa.yaml','§Set(varForceTeamRefresh,true); Select(btnReadTeam))',(Tr 'Team' 'RefreshClick' '')),
 @('Screen1.pa.yaml','OnSelect: =§Navigate(scrWeeklyHours,ScreenTransition.Fade)',(Tr 'Nav' 'ToHoursSummary' '')),
 @('Screen1.pa.yaml','§Navigate(scrHours, ScreenTransition.Fade)',(Tr 'Nav' 'ToWeeklyHours' '')),
 @('scrHours.pa.yaml','OnVisible: =§',(Tr 'Week' 'OnVisible' '' ',LoadState:Coalesce(varWeekLoadState,"")')),
 @('scrHours.pa.yaml','§Notify("Niet geladen: onopgeslagen uren behouden.',(Tr 'Week' 'BlockedUnsaved' '')),
 @('scrHours.pa.yaml','Set(varWeekLoading,true); Set(varWeekLoadState,"Loading");§',(TrStart 'Week' 'varDiagWeekT0' ',Year:Coalesce(ddHoursYear.Selected.Value,0),KW:Coalesce(ddHoursWeek.Selected.Value,0),ProjectID:Coalesce(varProject.Id,ddProject.Selected.Id,0),Team:Coalesce(varTeam.Value,ddTeam.Selected.Value,"")')),
 @('scrHours.pa.yaml','                  §Set(varEntryFirstISOYear,IfError(',(Tr 'Week' 'AfterRefresh' 'varDiagWeekT0' $errWeek)),
 @('scrHours.pa.yaml','                  §IfError(CountRows(ClearCollect(colPendingWeekAssignments,',(Tr 'Week' 'AfterYearBounds' 'varDiagWeekT0' (',FirstISOYear:Coalesce(varEntryFirstISOYear,0),LastISOYear:Coalesce(varEntryLastISOYear,0)'+$errWeek))),
 @('scrHours.pa.yaml','                  §ForAll(colPendingWeekAssignments As member,',(Tr 'Week' 'AfterAssignments' 'varDiagWeekT0' (',Assignments:CountRows(colPendingWeekAssignments)'+$errWeek))),
 @('scrHours.pa.yaml','§If(CountIf(colPendingWeekStored,IsBlank(HourValue))>0,',(Tr 'Week' 'AfterHoursQueries' 'varDiagWeekT0' (',DayRows:CountRows(colPendingWeekStored)'+$errWeek))),
 @('scrHours.pa.yaml','§ClearCollect(colWeekAssignments,colPendingWeekAssignments);',(Tr 'Week' 'AfterLocalBuild' 'varDiagWeekT0' (',Rows:CountRows(colPendingWeekRows)'+$errWeek))),
 @('scrHours.pa.yaml','§If(varWeekLoadState="Loading",Set(varWeekLoadState,"NotLoaded")); Set(varWeekLoading,false)',(Tr 'Week' 'End' 'varDiagWeekT0' (',State:Coalesce(varWeekLoadState,""),Rows:CountRows(colWeekRows)'+$errWeek))),
 @('scrHours.pa.yaml','NotificationType.Warning,15000),§Select(btnReadWeek))',(Tr 'Week' 'RefreshClick' '')),
 @('scrHours.pa.yaml','Set(varReportReady,false); Set(varReportValid,false); Set(varWeekSaving, true);§',(TrStart 'SaveWeek' 'varDiagSaveWeekT0' ',Rows:CountRows(colWeekRows)')),
 @('scrHours.pa.yaml','§IfError(Refresh(Hours),Collect(colHoursErrors,',(Tr 'SaveWeek' 'AfterWrites' 'varDiagSaveWeekT0' ',Changes:CountRows(colHoursChanges),Written:CountRows(colHoursWritten),Errors:CountRows(colHoursErrors)')),
 @('scrHours.pa.yaml','§Set(varWeekSaving, false);',(Tr 'SaveWeek' 'End' 'varDiagSaveWeekT0' ',Changes:CountRows(colHoursChanges),Written:CountRows(colHoursWritten),Errors:CountRows(colHoursErrors)')),
 @('scrHours.pa.yaml','OnSelect: =§Navigate(Screen1,ScreenTransition.Fade)',(Tr 'Nav' 'WeeklyHoursToProjectTeam' '')),
 @('scrWeeklyHours.pa.yaml','OnVisible: =§',(Tr 'Summary' 'OnVisible' '' ',Ready:Coalesce(varReportReady,false),LoadedProjectID:Coalesce(varReportProjectID,0),SelectedProjectID:Coalesce(ddReportProject.Selected.ID,0),WillLoad:!Coalesce(varReportReady,false) || Coalesce(varReportProjectID,0)<>Coalesce(ddReportProject.Selected.ID,0)')),
 @('scrWeeklyHours.pa.yaml','Set(varReportBusy,true); Set(varReportLoadState,"Loading");§',(TrStart 'Report' 'varDiagReportT0' ',ProjectID:Coalesce(ddReportProject.Selected.ID,0)')),
 @('scrWeeklyHours.pa.yaml','If(IsEmpty(colReportLoadErrors),Reset(ddReportProject); Set(varReportProjectID,ddReportProject.Selected.ID));§',(Tr 'Report' 'AfterProjects' 'varDiagReportT0' (',Projects:CountRows(colReportProjects)'+$errRep))),
 @('scrWeeklyHours.pa.yaml','               §IfError(CountRows(ClearCollect(colReportAssignments,',(Tr 'Report' 'AfterRefresh' 'varDiagReportT0' $errRep)),
 @('scrWeeklyHours.pa.yaml','§If(CountRows(colReportAssignments)>=500,',(Tr 'Report' 'AfterAssignments' 'varDiagReportT0' (',Assignments:CountRows(colReportAssignments)'+$errRep))),
 @('scrWeeklyHours.pa.yaml','               §ForAll(colReportAssignments As member,',(Tr 'Report' 'AfterWorkerLookups' 'varDiagReportT0' (',Workers:CountRows(colReportWorkers)'+$errRep))),
 @('scrWeeklyHours.pa.yaml','               §IfError(CountRows(ClearCollect(colReportPeriods,',(Tr 'Report' 'AfterHoursQueries' 'varDiagReportT0' (',Facts:CountRows(colReportFacts)'+$errRep))),
 @('scrWeeklyHours.pa.yaml','§Set(varReportStartMonday,First(colReportPeriods).Monday);',(Tr 'Report' 'AfterLocalPeriods' 'varDiagReportT0' (',Periods:CountRows(colReportPeriods),Contractors:CountRows(colReportContractors)'+$errRep))),
 @('scrWeeklyHours.pa.yaml','§Set(varReportBusy,false);',(Tr 'Report' 'End' 'varDiagReportT0' (',State:Coalesce(varReportLoadState,""),Facts:CountRows(colReportFacts)'+$errRep))),
 @('scrWeeklyHours.pa.yaml','§Set(varReportValid,false); Clear(colReportBuildErrors);',(TrStart 'Build' 'varDiagBuildT0' ',ContractorID:Coalesce(ddReportContractor.Selected.ID,0),From:Text(varReportStartMonday,"yyyy-mm-dd"),Till:Text(varReportEndSunday,"yyyy-mm-dd"),Facts:CountRows(colReportFacts)')),
 @('scrWeeklyHours.pa.yaml','§Set(varReportColumnOffset,1); Set(varReportValid,true);',(Tr 'Build' 'End' 'varDiagBuildT0' ',Rows:CountRows(colReportRows),Columns:CountRows(colReportColumns),SelectedHours:CountRows(colReportSelectedHours),Errors:CountRows(colReportBuildErrors)')),
 @('scrWeeklyHours.pa.yaml','§Set(varReportMessage,"Rapport gestopt: " & First(colReportBuildErrors).Message);',(Tr 'Build' 'Stopped' 'varDiagBuildT0' ',Errors:CountRows(colReportBuildErrors)')),
 @('scrWeeklyHours.pa.yaml','OnChange: =§If(!varReportBusy,Set(varReportValid,false); Select(btnBuildReport))',(Tr 'Summary' 'ContractorChange' '' ',ContractorID:Coalesce(Self.Selected.ID,0)')),
 @('scrWeeklyHours.pa.yaml','§If(IsBlank(Self.SelectedDate),Reset(dpReportFrom),',(Tr 'Summary' 'FromChange' '' ',Selected:Text(Self.SelectedDate,"yyyy-mm-dd")')),
 @('scrWeeklyHours.pa.yaml','§If(IsBlank(Self.SelectedDate),Reset(dpReportUntil),',(Tr 'Summary' 'TillChange' '' ',Selected:Text(Self.SelectedDate,"yyyy-mm-dd")')),
 @('scrWeeklyHours.pa.yaml','OnSelect: =§If(!Coalesce(varReportBusy,false),Select(btnLoadReport))',(Tr 'Summary' 'RefreshClick' '')),
 @('scrWeeklyHours.pa.yaml','OnSelect: =§Navigate(Screen1,ScreenTransition.Fade)',(Tr 'Nav' 'SummaryToProjectTeam' ''))
)
$original=@{};$texts=@{};$added=@{}
foreach($f in Get-ChildItem (Join-Path $source 'Src') -File){$original[$f.Name]=[IO.File]::ReadAllText($f.FullName);$texts[$f.Name]=$original[$f.Name];$added[$f.Name]=@()}
foreach($i in $inserts){
 $file,$marked,$snippet=$i
 if(($marked.ToCharArray()|Where-Object {$_ -eq [char]0xA7}).Count -ne 1){throw "Anchor needs exactly one insertion mark: $marked"}
 $anchor=$marked.Replace([string][char]0xA7,'')
 $count=([regex]::Matches($texts[$file],[regex]::Escape($anchor))).Count
 if($count -ne 1){throw "Anchor found $count times in ${file}: $anchor"}
 if($snippet -match '\b(Patch|Remove|RemoveIf|Update|UpdateIf|Collect|ClearCollect|Clear|Refresh|Select|Navigate|Reset|Notify|SubmitForm|SaveData|LoadData)\('){throw "Unsafe snippet: $snippet"}
 $texts[$file]=$texts[$file].Replace($anchor,$marked.Replace([string][char]0xA7,$snippet));$added[$file]+=$snippet
}foreach($file in $texts.Keys){
 $restored=$texts[$file];foreach($s in ($added[$file]|Sort-Object Length -Descending)){$restored=$restored.Replace($s,'')}
 if($restored -cne $original[$file]){throw "Removing inserted Trace snippets does not restore $file"}
 [IO.File]::WriteAllText((Join-Path $source "Src\$file"),$texts[$file],(New-Object Text.UTF8Encoding $false))
}
foreach($s in $added.Values|ForEach-Object {$_}){if($s -notmatch '^(Set\(varDiag\w+T0,Now\(\)\); )?Trace\("DIAG\|'){throw "Snippet is not a pure Trace/timer: $s"}}
Write-Output "PASS $($inserts.Count) Trace markers inserted; removing them restores the original source exactly; snippets contain only Trace and Set(varDiag...,Now())."
# Syntax: parse every formula of the diagnostic copy.
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1') | Out-Null  # sets up the Power Fx/YamlDotNet assemblies, $builder and $engine
$opt=$options;$script:n=0;$script:bad=0
function Walk($node,$path){if($node -is [Collections.IDictionary]){foreach($k in $node.Keys){Walk $node[$k] "$path.$k"}}elseif($node -is [Collections.IEnumerable] -and $node -isnot [string]){foreach($x in $node){Walk $x $path}}elseif($node -is [string] -and $node.StartsWith('=')){$script:n++;$r=$engine.Parse($node.Substring(1),$opt);if(!$r.IsSuccess){$script:bad++;Write-Output "SYNTAX $path";$r.Errors|ForEach-Object ToString}}}
foreach($f in Get-ChildItem (Join-Path $source 'Src') -File){Walk ($builder.Build().Deserialize($texts[$f.Name])) $f.Name}
if($script:bad){throw 'Syntax errors in diagnostic source'}
Write-Output "PASS $script:n formulas in the diagnostic source parse without syntax errors."
# Save guards: both Save OnSelect formulas must still start with the unchanged guard.
foreach($pair in @(@('Screen1.pa.yaml','=If(And(varTeamLoadState="Loaded",'),@('scrHours.pa.yaml','=If(And(varWeekLoadState="Loaded",'))){
 $o=([regex]::Matches($original[$pair[0]],[regex]::Escape($pair[1]))).Count;$d=([regex]::Matches($texts[$pair[0]],[regex]::Escape($pair[1]))).Count
 if($o -ne $d -or $o -lt 2){throw "Save guard occurrences changed in $($pair[0])"}
}
Write-Output 'PASS Save guards (DisplayMode and start of OnSelect) unchanged; markers sit after the guard.'
