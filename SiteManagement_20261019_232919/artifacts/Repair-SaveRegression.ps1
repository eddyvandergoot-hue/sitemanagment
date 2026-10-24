# Historisch eenmalig tussenstapscript. Niet opnieuw uitvoeren: eindbron is aanvullend gecorrigeerd en getest in Src.
$ErrorActionPreference='Stop'
$installer=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Optimize-Loading.ps1'))
Invoke-Expression ($installer.Substring(0,$installer.IndexOf("Read-Screen 'Screen1'")).Replace('$PSScriptRoot',("'"+$PSScriptRoot+"'")))
$baseline=Join-Path $root 'checkpoints/performance-20261020_201156/Src'
$teamDirty='Coalesce(varTeamDirty,false)'
$weekDirty='JSON(ShowColumns(colWeekRows,ID,MonHours,TueHours,WedHours,ThuHours,FriHours,SatHours,SunHours))<>JSON(ShowColumns(colWeekOriginal,ID,MonHours,TueHours,WedHours,ThuHours,FriHours,SatHours,SunHours))'
$teamGuard=@'
varTeamLoadState="Loaded" && Coalesce(varSelectionLoaded,false) && Coalesce(varSelectionKeysValid,false) &&
!Coalesce(varSelectionBusy,false) && !Coalesce(varSaving,false) && IsEmpty(colSelectionLoadErrors) &&
!IsBlank(ddProject.Selected.Id) && !IsBlank(ddTeam.Selected.Value) &&
varTeamLoadedProjectID=ddProject.Selected.Id && varTeamLoadedTeam=ddTeam.Selected.Value &&
CountRows(colCurrentTeamAssignments)=varTeamLoadedAssignmentCount &&
CountRows(colTeamOriginalSelection)=varTeamLoadedAssignmentCount &&
CountIf(colCurrentTeamAssignments,Project.Id<>varTeamLoadedProjectID || Team.Value<>varTeamLoadedTeam || Active<>true)>-1 &&
CountIf(colCurrentTeamAssignments,Project.Id<>varTeamLoadedProjectID || Team.Value<>varTeamLoadedTeam || Active<>true)=0 &&
!IsEmpty(colSelectedWorkers) && CountIf(colSelectedWorkers,IsBlank(ID))=0 &&
CountRows(Distinct(colSelectedWorkers,ID))=CountRows(colSelectedWorkers) &&
CountIf(colTeamOriginalSelection,!(ID in colSelectedWorkers.ID) && !(ID in colTeamRemovedIDs.WorkerID))=0
'@
$weekGuard=@'
varWeekLoadState="Loaded" && Coalesce(varWeekReady,false) && !Coalesce(varWeekKeyIssue,true) &&
!Coalesce(varWeekLoading,false) && !Coalesce(varWeekSaving,false) && IsEmpty(colWeekLoadErrors) &&
!IsBlank(varLoadedWeekMonday) && !IsBlank(varWeekLoadedProjectID) && !IsBlank(varWeekLoadedTeam) &&
varWeekLoadedProjectID=varProject.Id && varWeekLoadedProjectID=ddProject.Selected.Id &&
varWeekLoadedTeam=varTeam.Value && varWeekLoadedTeam=ddTeam.Selected.Value &&
varWeekLoadedISOYear=Value(ddHoursYear.Selected.Value) && varWeekLoadedKW=Value(ddHoursWeek.Selected.Value) &&
!IsEmpty(colWeekRows) && CountRows(colWeekRows)=varWeekLoadedAssignmentCount &&
CountRows(colWeekOriginal)=varWeekLoadedAssignmentCount && CountRows(colWeekAssignments)=varWeekLoadedAssignmentCount &&
CountRows(Distinct(colWeekRows,ID))=varWeekLoadedAssignmentCount &&
CountRows(Distinct(colWeekOriginal,ID))=varWeekLoadedAssignmentCount &&
CountIf(colWeekRows,!(ID in colWeekOriginal.ID) || !(ID in colWeekAssignments.ID) || Project.Id<>varWeekLoadedProjectID || Team.Value<>varWeekLoadedTeam || Active<>true)=0
'@
Set-Content (Join-Path $PSScriptRoot 'team-save-guard.fx') $teamGuard
Set-Content (Join-Path $PSScriptRoot 'week-save-guard.fx') $weekGuard
Read-Screen 'Screen1'
$oldDoc=$deserializer.Deserialize([IO.File]::ReadAllText((Join-Path $baseline 'Screen1.pa.yaml')))
$oldControls=@{};Index-Controls $oldDoc['Screens']['Screen1']['Children'] $oldControls
$teamLoad=@'
=If(!Coalesce(varSelectionBusy,false) && !Coalesce(varSaving,false),
 If(Coalesce(varTeamDirty,false),
  Notify("Niet opnieuw geladen: onopgeslagen teamselectie behouden. Rond de selectie af of noteer deze voordat u de sessie opnieuw opent.",NotificationType.Warning,15000),
  Set(varSelectionBusy,true); Set(varTeamLoadState,"Loading"); Set(varSelectionLoaded,false); Set(varSelectionKeysValid,false);
  Set(varSelectionProjectID,ddProject.Selected.Id); Set(varSelectionTeam,ddTeam.Selected.Value);
  Set(varSelectionProjectKey,Text(varSelectionProjectID));
  Clear(colSelectionLoadErrors); Clear(colPendingTeamAssignments); Clear(colPendingSelectedWorkers);
  If(Coalesce(varForceTeamRefresh,false),
   IfError(Refresh(Projects),Collect(colSelectionLoadErrors,{Message:FirstError.Message});false);
   IfError(Refresh(Workers),Collect(colSelectionLoadErrors,{Message:FirstError.Message});false);
   IfError(Refresh('Project Workers'),Collect(colSelectionLoadErrors,{Message:FirstError.Message});false)
  );
  If(!Coalesce(varMastersReady,false) || Coalesce(varForceTeamRefresh,false),
   IfError(CountRows(ClearCollect(colPendingProjects,ForAll(Sort(Projects,Title,SortOrder.Ascending) As project,{Id:project.ID,Value:project.Title})))>=0,
    Collect(colSelectionLoadErrors,{Message:"Projects: " & FirstError.Message});false);
   IfError(CountRows(ClearCollect(colPendingTeamChoices,Choices('Project Workers'.Team)))>=0,
    Collect(colSelectionLoadErrors,{Message:"Teamkeuzes: " & FirstError.Message});false);
   If(CountRows(colPendingProjects)>=500 || CountRows(colPendingTeamChoices)>=500,
    Collect(colSelectionLoadErrors,{Message:"Keuzelijst bereikt rijlimiet; laden niet volledig."}));
   If(IsEmpty(colPendingProjects),Collect(colSelectionLoadErrors,{Message:"Geen projecten teruggelezen. Controleer SharePoint-verbinding en rechten; geen gegevens opnieuw aanmaken."}));
   If(IsEmpty(colPendingTeamChoices),Collect(colSelectionLoadErrors,{Message:"Geen Team-keuzes ontvangen uit Project Workers. Controleer connector/schema/rechten."}));
   If(IsEmpty(colSelectionLoadErrors),
    ClearCollect(colSelectionProjects,colPendingProjects); ClearCollect(colTeamChoices,colPendingTeamChoices);
    Set(varMastersReady,true); Reset(ddProject)
   )
  );
  Set(varForceTeamRefresh,false);
  If(IsEmpty(colSelectionLoadErrors),
   Set(varSelectionHasWorkers,IfError(!IsBlank(First(Workers).ID),Collect(colSelectionLoadErrors,{Message:"Workers: " & FirstError.Message});false));
   Set(varSelectionProjectID,ddProject.Selected.Id); Set(varSelectionProjectKey,Text(varSelectionProjectID));
   Set(varSelectionTeam,ddTeam.Selected.Value);
   If(!IsBlank(varSelectionProjectID) && !IsBlank(varSelectionTeam),
    IfError(CountRows(ClearCollect(colPendingTeamAssignments,
     Filter('Project Workers',Project.Id=varSelectionProjectID && Team.Value=varSelectionTeam && Active=true)))>=0,
     Collect(colSelectionLoadErrors,{Message:FirstError.Message});false);
    If(CountRows(colPendingTeamAssignments)>=500,Collect(colSelectionLoadErrors,{Message:"500 koppelingen geladen; volledigheid niet gegarandeerd."}));
    If(CountRows(Distinct(colPendingTeamAssignments,Worker.Id))<>CountRows(colPendingTeamAssignments),Collect(colSelectionLoadErrors,{Message:"Dubbele actieve medewerkerkoppelingen; opslaan geblokkeerd."}));
    If(IsEmpty(colSelectionLoadErrors),
     ForAll(colPendingTeamAssignments As member,
      IfError(With({person:LookUp(Workers,ID=member.Worker.Id)},
       If(IsBlank(person.ID),Collect(colSelectionLoadErrors,{Message:"Medewerker ontbreekt bij koppeling " & Text(member.ID)});false,
        CountRows(Collect(colPendingSelectedWorkers,person))>=0)),Collect(colSelectionLoadErrors,{Message:FirstError.Message});false)
     )
    );
    If(IsEmpty(colSelectionLoadErrors),
     ClearCollect(colCurrentTeamAssignments,colPendingTeamAssignments); ClearCollect(colSelectedWorkers,colPendingSelectedWorkers);
     ClearCollect(colTeamOriginalSelection,colPendingSelectedWorkers); Clear(colTeamRemovedIDs);
     Set(varTeamLoadedProjectID,varSelectionProjectID); Set(varTeamLoadedTeam,varSelectionTeam);
     Set(varTeamLoadedAssignmentCount,CountRows(colPendingTeamAssignments)); Set(varTeamDirty,false);
     Set(varSelectionKeysValid,CountIf(colPendingTeamAssignments,AssignmentKey<>Text(varSelectionProjectID) & "|" & Text(Worker.Id) || ProjectKey<>Text(varSelectionProjectID))=0);
     Set(varSelectionLoaded,true); Set(varTeamLoadState,"Loaded");
     Set(varSelectionMessage,Text(varTeamLoadedAssignmentCount) & " actieve koppelingen volledig geladen." & If(!varSelectionKeysValid," Alleen lezen: afwijkende sleutels; opslaan geblokkeerd.",""))
    ),
    Set(varTeamLoadState,"NotLoaded"); Set(varSelectionMessage,"Projecten en teamkeuzes geladen. Kies project en team. Opslaan blijft geblokkeerd tot de selectie volledig is gelezen.")
   )
  );
  If(!IsEmpty(colSelectionLoadErrors),
   Set(varTeamLoadState,"Failed"); Set(varSelectionLoaded,false); Set(varSelectionKeysValid,false);
   Set(varSelectionMessage,"Laden mislukt; opslaan geblokkeerd. Vorige selectie behouden. " & First(colSelectionLoadErrors).Message);
   Notify(varSelectionMessage,NotificationType.Error,15000)
  );
  Set(varSelectionBusy,false)
 )
)
'@
Replace-Property 'btnReadTeam' 'OnSelect' $teamLoad
Replace-Property 'ddTeam' 'Items' '=colTeamChoices'
Screen-Event 'Screen1' 'OnVisible' '=If(IsBlank(varTeamLoadState),Set(varTeamLoadState,"NotLoaded")); If(!Coalesce(varTeamDirty,false),Select(btnReadTeam))'
Replace-Property 'btnRefreshTeam' 'DisplayMode' '=If(Coalesce(varSelectionBusy,false) || Coalesce(varSaving,false) || Coalesce(varTeamDirty,false),DisplayMode.Disabled,DisplayMode.Edit)'
Replace-Property 'btnRefreshTeam' 'OnSelect' '=If(Coalesce(varSelectionBusy,false) || Coalesce(varSaving,false) || Coalesce(varTeamDirty,false),Notify("Refresh geblokkeerd: laadactie/opslag bezig of onopgeslagen selectie aanwezig.",NotificationType.Warning),Set(varForceTeamRefresh,true); Select(btnReadTeam))'
Replace-Property 'Checkbox1' 'OnCheck' '=If(varTeamLoadState="Loaded" && !Coalesce(varSelectionBusy,false) && varTeamLoadedProjectID=ddProject.Selected.Id && varTeamLoadedTeam=ddTeam.Selected.Value,If(!(ThisItem.ID in colSelectedWorkers.ID),Collect(colSelectedWorkers,ThisItem)); RemoveIf(colTeamRemovedIDs,WorkerID=ThisItem.ID); Set(varTeamDirty,true))'
Replace-Property 'Checkbox1' 'OnUncheck' '=If(varTeamLoadState="Loaded" && !Coalesce(varSelectionBusy,false) && varTeamLoadedProjectID=ddProject.Selected.Id && varTeamLoadedTeam=ddTeam.Selected.Value,RemoveIf(colSelectedWorkers,ID=ThisItem.ID); If(ThisItem.ID in colTeamOriginalSelection.ID && !(ThisItem.ID in colTeamRemovedIDs.WorkerID),Collect(colTeamRemovedIDs,{WorkerID:ThisItem.ID})); Set(varTeamDirty,true))'
Replace-Property 'Checkbox1' 'DisplayMode' '=If(varTeamLoadState="Loaded" && !Coalesce(varSelectionBusy,false) && !Coalesce(varSaving,false) && varTeamLoadedProjectID=ddProject.Selected.Id && varTeamLoadedTeam=ddTeam.Selected.Value,DisplayMode.Edit,DisplayMode.Disabled)'
foreach($name in @('ddProject','ddTeam')){Replace-Property $name 'DisplayMode' '=If(Coalesce(varSelectionBusy,false) || Coalesce(varSaving,false) || Coalesce(varTeamDirty,false),DisplayMode.Disabled,DisplayMode.Edit)'}
Replace-Property 'Gallery1' 'Visible' '=Coalesce(varMastersReady,false)'
$save=$oldControls['btnAddtoTeam']['Properties']['OnSelect'].TrimStart('=')
$save=$save.Replace('!(assignment.Worker.Id in colTeamSelectionToSave.ID)','!(assignment.Worker.Id in colTeamSelectionToSave.ID) && assignment.Worker.Id in colTeamRemovedIDs.WorkerID')
$start=$save.IndexOf("Refresh('Project Workers');")
$finish=$save.IndexOf('Notify(',$start)
if($start -lt 0 -or $finish -lt 0){throw 'Save team reload block not found'}
$save=$save.Substring(0,$start)+$save.Substring($finish)
$save=$save.Replace('"Team opslaan gestopt: " &','"Team opslaan gestopt: " &')
$save=$save.Replace('Notify('+"`r`n"+'            "Team opslaan gestopt:', 'Notify('+"`r`n"+'            "Team opslaan gestopt:')
# Add an error marker to the outer error handler before it notifies.
$err=$save.IndexOf('"Team opslaan gestopt: "')
$notify=$save.LastIndexOf('Notify(',$err)
$save=$save.Insert($notify,'Collect(colAssignmentErrors,{WorkerID:0,Message:FirstError.Message}); ')
$teamAfter='Set(varSelectionLoaded,false); Set(varSelectionKeysValid,false); If(IsEmpty(colAssignmentErrors),Set(varTeamDirty,false); Set(varTeamLoadState,"NotLoaded"); Select(btnReadTeam),Set(varTeamLoadState,"Failed"); Notify("Opslag mogelijk gedeeltelijk uitgevoerd. Selectie behouden; opslaan geblokkeerd. Controleer SharePoint-versies voordat u opnieuw laadt.",NotificationType.Error,15000))'
Replace-Property 'btnAddtoTeam' 'OnSelect' ("=If($teamGuard,`n$save;`n$teamAfter,`nNotify(`"Save team geblokkeerd: selectie niet volledig geladen, gewijzigd, leeg of niet passend bij huidig project/team.`",NotificationType.Error,15000))")
Replace-Property 'btnAddtoTeam' 'DisplayMode' ("=If($teamGuard,DisplayMode.Edit,DisplayMode.Disabled)")
Write-Screen

Read-Screen 'scrHours'
$oldDoc=$deserializer.Deserialize([IO.File]::ReadAllText((Join-Path $baseline 'scrHours.pa.yaml')))
$oldControls=@{};Index-Controls $oldDoc['Screens']['scrHours']['Children'] $oldControls
$week=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'read-week.fx'))
foreach($name in @('colWeekAssignments','colWeekOriginal','colWeekStored','colWeekRows','colWeekKeys')){
 $week=$week.Replace($name,($name.Replace('colWeek','colPendingWeek')))
}
foreach($name in @('varHoursProjectID','varHoursProjectKey','varHoursTeam','varWeekMonday','varLoadedWeekMonday','varWeekKeyIssue')){
 $week=$week.Replace($name,($name.Replace('var','varPending')))
}
$week=$week.TrimStart('=')
$week=$week.Replace('Set(varWeekLoading,true);','Set(varWeekLoading,true); Set(varWeekLoadState,"Loading");')
$commit=@'
ClearCollect(colWeekAssignments,colPendingWeekAssignments); ClearCollect(colWeekKeys,colPendingWeekKeys);
ClearCollect(colWeekStored,colPendingWeekStored); ClearCollect(colWeekRows,colPendingWeekRows); ClearCollect(colWeekOriginal,colPendingWeekOriginal);
Set(varHoursProjectID,varPendingHoursProjectID); Set(varHoursProjectKey,varPendingHoursProjectKey); Set(varHoursTeam,varPendingHoursTeam);
Set(varWeekMonday,varPendingWeekMonday); Set(varLoadedWeekMonday,varPendingWeekMonday); Set(varWeekKeyIssue,varPendingWeekKeyIssue);
Set(varWeekLoadedProjectID,varPendingHoursProjectID); Set(varWeekLoadedTeam,varPendingHoursTeam);
Set(varWeekLoadedISOYear,Value(ddHoursYear.Selected.Value)); Set(varWeekLoadedKW,Value(ddHoursWeek.Selected.Value));
Set(varWeekLoadedAssignmentCount,CountRows(colPendingWeekAssignments)); Set(varWeekLoadState,"Loaded"); Set(varWeekReady,true);
'@
$week=$week.Replace('Set(varWeekReady,true);',$commit)
$week=$week.Replace('Set(varWeekMessage,"Week laden gestopt: " & First(colWeekLoadErrors).Message);','Set(varWeekLoadState,"Failed"); Set(varWeekMessage,"Week laden mislukt; opslaan geblokkeerd. Vorige invoer behouden. " & First(colWeekLoadErrors).Message);')
$week=$week.Replace('Set(varWeekLoading,false)','If(varWeekLoadState="Loading",Set(varWeekLoadState,"NotLoaded")); Set(varWeekLoading,false)')
Replace-Property 'btnReadWeek' 'OnSelect' ("=If($weekDirty,Notify(`"Niet geladen: onopgeslagen uren behouden. Refresh en opnieuw laden zijn geblokkeerd.`",NotificationType.Warning,15000),`n$week)")
Screen-Event 'scrHours' 'OnVisible' '=If(IsBlank(varWeekLoadState),Set(varWeekLoadState,"NotLoaded")); Select(btnReadWeek)'
Replace-Property 'btnRefreshWeek' 'OnSelect' ("=If(Coalesce(varWeekLoading,false) || Coalesce(varWeekSaving,false) || $weekDirty,Notify(`"Refresh geblokkeerd: laadactie/opslag bezig of onopgeslagen uren aanwezig.`",NotificationType.Warning,15000),Select(btnReadWeek))")
Replace-Property 'btnRefreshWeek' 'DisplayMode' ("=If(Coalesce(varWeekLoading,false) || Coalesce(varWeekSaving,false) || $weekDirty,DisplayMode.Disabled,DisplayMode.Edit)")
Replace-Property 'galHours' 'Visible' '=!IsEmpty(colWeekRows)'
foreach($name in @('txtMon','txtTue','txtWed','txtThu','txtFri','txtSat','txtSun')){
 Replace-Property $name 'DisplayMode' '=If(varWeekLoadState="Loaded" && Coalesce(varWeekReady,false) && !Coalesce(varWeekLoading,false) && !Coalesce(varWeekSaving,false) && !Coalesce(varWeekKeyIssue,true),DisplayMode.Edit,DisplayMode.Disabled)'
 $edit=$controls[$name]['Properties']['OnChange'].TrimStart('=')
 Replace-Property $name 'OnChange' ("=If(varWeekLoadState=`"Loaded`" && Coalesce(varWeekReady,false) && !Coalesce(varWeekLoading,false) && !Coalesce(varWeekSaving,false),$edit)")
}
$save=$oldControls['btnSaveWeek']['Properties']['OnSelect'].TrimStart('=')
$save=$save.Replace('Refresh(Hours);','IfError(Refresh(Hours),Collect(colHoursErrors,{WorkerName:"",KeyValue:"",Message:FirstError.Message});false);')
$err=$save.IndexOf('"Opslagfout: "'); $notify=$save.LastIndexOf('Notify(',$err)
$save=$save.Insert($notify,'Collect(colHoursErrors,{WorkerName:"",KeyValue:"",Message:FirstError.Message}); ')
Replace-Property 'btnSaveWeek' 'OnSelect' ("=If($weekGuard,`n$save;`nIf(!IsEmpty(colHoursErrors),Set(varWeekLoadState,`"Failed`" ); Set(varWeekReady,false); Notify(`"Opslag niet volledig bevestigd. Invoer behouden; controleer SharePoint-versies voordat u verdergaat.`",NotificationType.Error,15000)),`nNotify(`"Save week geblokkeerd: week niet volledig geladen, laadfout of selectie komt niet overeen.`",NotificationType.Error,15000))")
Replace-Property 'btnSaveWeek' 'DisplayMode' ("=If($weekGuard,DisplayMode.Edit,DisplayMode.Disabled)")
# Ensure choices exist before any successful hours load, independent of cached state.
Replace-Property 'ddHoursWeek' 'Items' '=Sequence(ISOWeekNum(Date(Coalesce(Value(ddHoursYear.Selected.Value),Year(DateAdd(Today(),4-Weekday(Today(),StartOfWeek.Monday),TimeUnit.Days))),12,28)))'
Write-Screen

Read-Screen 'scrWeeklyHours'
$report=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'weekly-refresh.fx'))
$report=$report.Replace('Set(varReportBusy,true);','Set(varReportBusy,true); Set(varReportLoadState,"Loading");')
$report=$report.Replace('Set(varReportReady,true)','Set(varReportReady,true); Set(varReportLoadState,"Loaded")')
$report=$report.Replace('Set(varReportMessage,"Ophalen gestopt: "','Set(varReportLoadState,"Failed"); Set(varReportMessage,"Ophalen gestopt: "')
Replace-Property 'btnLoadReport' 'OnSelect' $report
Replace-Property 'btnRefreshReport' 'OnSelect' '=If(!Coalesce(varReportBusy,false),Select(btnLoadReport))'
Screen-Event 'scrWeeklyHours' 'OnVisible' '=If(!Coalesce(varReportReady,false) || Coalesce(varReportProjectID,0)<>Coalesce(ddReportProject.Selected.ID,0),Select(btnLoadReport))'
Write-Screen
