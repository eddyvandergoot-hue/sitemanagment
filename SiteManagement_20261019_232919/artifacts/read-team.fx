=If(!varSelectionBusy && !varSaving,
 Set(varSelectionBusy,true); Set(varSelectionLoaded,false); Set(varSelectionKeysValid,false);
 Set(varSelectionProjectID,ddProject.Selected.Id); Set(varSelectionTeam,ddTeam.Selected.Value);
 Set(varSelectionProjectKey,Text(varSelectionProjectID));
 Clear(colSelectionLoadErrors); Clear(colSelectedWorkers); Clear(colCurrentTeamAssignments);
 IfError(Refresh(Projects),Collect(colSelectionLoadErrors,{Message:FirstError.Message});false);
 IfError(Refresh(Workers),Collect(colSelectionLoadErrors,{Message:FirstError.Message});false);
 IfError(Refresh('Project Workers'),Collect(colSelectionLoadErrors,{Message:FirstError.Message});false);
 If(IsEmpty(colSelectionLoadErrors),
  Set(varSelectionHasWorkers,IfError(!IsBlank(First(Workers).ID),Collect(colSelectionLoadErrors,{Message:FirstError.Message});false))
 );
 If(IsEmpty(colSelectionLoadErrors),
  IfError(CountRows(ClearCollect(colSelectionProjects,
   ForAll(Sort(Projects,Title,SortOrder.Ascending) As project,{Id:project.ID,Value:project.Title})))>=0,
   Collect(colSelectionLoadErrors,{Message:FirstError.Message});false);
  If(CountRows(colSelectionProjects)>=500,
   Collect(colSelectionLoadErrors,{Message:"Projectkeuze mogelijk onvolledig (500 projecten). Laden gestopt."})
  )
 );
 If(IsEmpty(colSelectionLoadErrors),
  Reset(ddProject); Set(varSelectionProjectID,ddProject.Selected.Id); Set(varSelectionProjectKey,Text(varSelectionProjectID));
  If(!IsBlank(varSelectionProjectID) && !IsBlank(varSelectionTeam),
   IfError(CountRows(ClearCollect(colCurrentTeamAssignments,
    Filter('Project Workers',Project.Id=varSelectionProjectID && Team.Value=varSelectionTeam && Active=true)))>=0,
    Collect(colSelectionLoadErrors,{Message:FirstError.Message});false);
   If(CountRows(colCurrentTeamAssignments)>=500,
    Collect(colSelectionLoadErrors,{Message:"500 actieve project-/teamkoppelingen geladen; volledigheid niet gegarandeerd."})
   );
   If(IsEmpty(colSelectionLoadErrors),
    ForAll(colCurrentTeamAssignments As member,
     IfError(With({person:LookUp(Workers,ID=member.Worker.Id)},
      If(IsBlank(person.ID),
       Collect(colSelectionLoadErrors,{Message:"Medewerker ontbreekt of is niet toegankelijk bij koppeling " & Text(member.ID)});false,
       CountRows(Collect(colSelectedWorkers,person))>=0
      )),Collect(colSelectionLoadErrors,{Message:FirstError.Message});false
     )
    )
   );
   If(CountRows(Distinct(colCurrentTeamAssignments,Worker.Id))<>CountRows(colCurrentTeamAssignments),
    Collect(colSelectionLoadErrors,{Message:"Dubbele actieve medewerkerkoppelingen in dit project/team. Laat de koppelingen controleren; voer geen nieuwe in."})
   )
  )
 );
 If(IsEmpty(colSelectionLoadErrors),
  Set(varSelectionLoaded,true);
  Set(varSelectionKeysValid,CountIf(colCurrentTeamAssignments,
   AssignmentKey<>Text(varSelectionProjectID) & "|" & Text(Worker.Id) || ProjectKey<>Text(varSelectionProjectID))=0);
  Set(varSelectionMessage,
   If(!varSelectionHasWorkers,"Geen medewerkers gevonden op de gekoppelde SharePoint-site. Controleer lijstinhoud en toegang; maak geen vervangende gegevens aan.",
    IsEmpty(colSelectionProjects),"Geen projecten gevonden op de gekoppelde SharePoint-site.",
    IsBlank(varSelectionProjectID) || IsBlank(varSelectionTeam),"Bestaande medewerkers geladen. Kies project en team om opgeslagen koppelingen terug te lezen.",
    IsEmpty(colCurrentTeamAssignments),"Geen actieve koppelingen gevonden voor dit project/team. Historische uren blijven beschikbaar in Hours Summary.",
    Text(CountRows(colCurrentTeamAssignments)) & " opgeslagen project-/teamkoppelingen teruggelezen." &
     If(!varSelectionKeysValid," Opslaan geblokkeerd: bestaande technische sleutels moeten worden gecontroleerd; niets opnieuw aanmaken.",""))
  ),
  Clear(colSelectedWorkers); Clear(colCurrentTeamAssignments);
  Set(varSelectionMessage,"Laden gestopt: " & First(colSelectionLoadErrors).Message);
  Notify(varSelectionMessage,NotificationType.Error,15000)
 );
 Set(varSelectionBusy,false)
)
