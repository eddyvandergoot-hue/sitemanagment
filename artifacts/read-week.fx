=If(!varWeekLoading && !varWeekSaving,
 Set(varWeekLoading,true); Set(varWeekReady,false); Set(varWeekKeyIssue,false);
 Set(varLoadedWeekMonday,Blank());
 Set(varHoursProjectID,Coalesce(varProject.Id,ddProject.Selected.Id));
 Set(varHoursProjectKey,Text(varHoursProjectID)); Set(varHoursTeam,Coalesce(varTeam.Value,ddTeam.Selected.Value));
 Clear(colWeekLoadErrors); Clear(colWeekAssignments); Clear(colWeekKeys);
 Clear(colWeekRows); Clear(colWeekOriginal); Clear(colWeekStored);
 If(IsBlank(varHoursProjectID) || IsBlank(varHoursTeam),
  Set(varWeekMessage,"Kies eerst project en team via Project / team. Uren zijn opgeslagen in SharePoint, niet in deze lege schermselectie."),
  If(IsBlank(ddHoursYear.Selected.Value) || IsBlank(ddHoursWeek.Selected.Value),
   Set(varWeekMessage,"Kies ISO-jaar en KW om de opgeslagen week terug te lezen."),
   With({isoYear:Value(ddHoursYear.Selected.Value),kw:Value(ddHoursWeek.Selected.Value)},
    Set(varWeekMonday,DateAdd(Date(isoYear,1,4),1-Weekday(Date(isoYear,1,4),StartOfWeek.Monday)+7*(kw-1),TimeUnit.Days))
   );
   IfError(Refresh(Hours),Collect(colWeekLoadErrors,{Message:FirstError.Message});false);
   IfError(Refresh('Project Workers'),Collect(colWeekLoadErrors,{Message:FirstError.Message});false);
   If(IsEmpty(colWeekLoadErrors),
    Set(varEntryFirstISOYear,IfError(
     With({firstHour:First(Sort(Hours,'Work Date',SortOrder.Ascending))},
      If(IsBlank(firstHour.ID),Year(Today()),IsBlank(firstHour.'Work Date'),
       Collect(colWeekLoadErrors,{Message:"Een opgeslagen urenregel heeft geen werkdatum; jaarbereik niet betrouwbaar."});Year(Today()),
       Year(DateAdd(firstHour.'Work Date',4-Weekday(firstHour.'Work Date',StartOfWeek.Monday),TimeUnit.Days))
      )),Collect(colWeekLoadErrors,{Message:FirstError.Message});Year(Today())
    ));
    Set(varEntryLastISOYear,IfError(
     With({lastHour:First(Sort(Hours,'Work Date',SortOrder.Descending))},
      If(IsBlank(lastHour.ID),Year(Today()),IsBlank(lastHour.'Work Date'),
       Collect(colWeekLoadErrors,{Message:"Een opgeslagen urenregel heeft geen werkdatum; jaarbereik niet betrouwbaar."});Year(Today()),
       Year(DateAdd(lastHour.'Work Date',4-Weekday(lastHour.'Work Date',StartOfWeek.Monday),TimeUnit.Days))
      )),Collect(colWeekLoadErrors,{Message:FirstError.Message});Year(Today())
    ));
    If(Max(Year(Today())+5,Coalesce(varEntryLastISOYear,Year(Today())))-Min(Year(Today())-5,Coalesce(varEntryFirstISOYear,Year(Today())))+1>500,
     Collect(colWeekLoadErrors,{Message:"Meer dan 500 invoerjaren; jaarselectie kan niet volledig worden getoond."})
    )
   );
   If(IsEmpty(colWeekLoadErrors),
    IfError(CountRows(ClearCollect(colWeekAssignments,
     Filter('Project Workers',Project.Id=varHoursProjectID && Team.Value=varHoursTeam && Active=true)))>=0,
     Collect(colWeekLoadErrors,{Message:FirstError.Message});false);
    If(CountRows(colWeekAssignments)>=500,
     Collect(colWeekLoadErrors,{Message:"500 actieve koppelingen geladen; weekoverzicht gestopt om onvolledige uren te voorkomen."})
    );
    If(CountRows(Distinct(colWeekAssignments,Worker.Id))<>CountRows(colWeekAssignments),
     Collect(colWeekLoadErrors,{Message:"Dubbele actieve medewerkerkoppelingen in dit project/team. Laden gestopt; bestaande koppelingen laten controleren."})
    )
   );
   If(IsEmpty(colWeekLoadErrors),
    ForAll(colWeekAssignments As member,
     With({assignmentID:member.ID,dateFrom:varWeekMonday,dateUntil:DateAdd(varWeekMonday,7,TimeUnit.Days)},
      IfError(With({batch:ForAll(Filter(Hours,Assignment.Id=assignmentID && 'Work Date'>=dateFrom && 'Work Date'<dateUntil) As entry,
       {HourID:entry.ID,AssignmentID:assignmentID,WorkDay:Date(Year(entry.'Work Date'),Month(entry.'Work Date'),Day(entry.'Work Date')),EntryKey:entry.EntryKey,HourValue:entry.Hours})},
       If(CountRows(batch)>=500,
        Collect(colWeekLoadErrors,{Message:"Limiet bereikt bij uren voor koppeling " & Text(assignmentID)});false,
        CountRows(Collect(colWeekStored,batch))>=0
       )),Collect(colWeekLoadErrors,{Message:FirstError.Message});false
      )
     )
    );
    If(CountIf(colWeekStored,IsBlank(HourValue))>0,
     Collect(colWeekLoadErrors,{Message:"Een opgeslagen urenregel heeft een lege urenwaarde. Laden gestopt; voer geen vervangende uren in."})
    );
    If(CountIf(GroupBy(colWeekStored,AssignmentID,WorkDay,DailyRecords),CountRows(DailyRecords)>1)>0,
     Collect(colWeekLoadErrors,{Message:"Meerdere urenregels voor dezelfde koppeling en werkdag. Laat de bestaande gegevens controleren; niets opnieuw invoeren."})
    );
    Set(varWeekKeyIssue,CountIf(colWeekStored,IsBlank(EntryKey))>0 || CountRows(Distinct(colWeekStored,EntryKey))<>CountRows(colWeekStored) ||
     CountIf(colWeekAssignments,!IsBlank(AssignmentKey) && AssignmentKey<>(Text(varHoursProjectID) & "|" & Text(Worker.Id)))>0)
   );
   If(IsEmpty(colWeekLoadErrors),
    IfError(CountRows(ClearCollect(colWeekKeys,
     AddColumns(colWeekAssignments As member,
      MonKey,Coalesce(member.AssignmentKey,Text(varHoursProjectID) & "|" & Text(member.Worker.Id)) & "|" & Text(varWeekMonday,"[$-en-US]yyyymmdd"),
      TueKey,Coalesce(member.AssignmentKey,Text(varHoursProjectID) & "|" & Text(member.Worker.Id)) & "|" & Text(DateAdd(varWeekMonday,1,TimeUnit.Days),"[$-en-US]yyyymmdd"),
      WedKey,Coalesce(member.AssignmentKey,Text(varHoursProjectID) & "|" & Text(member.Worker.Id)) & "|" & Text(DateAdd(varWeekMonday,2,TimeUnit.Days),"[$-en-US]yyyymmdd"),
      ThuKey,Coalesce(member.AssignmentKey,Text(varHoursProjectID) & "|" & Text(member.Worker.Id)) & "|" & Text(DateAdd(varWeekMonday,3,TimeUnit.Days),"[$-en-US]yyyymmdd"),
      FriKey,Coalesce(member.AssignmentKey,Text(varHoursProjectID) & "|" & Text(member.Worker.Id)) & "|" & Text(DateAdd(varWeekMonday,4,TimeUnit.Days),"[$-en-US]yyyymmdd"),
      SatKey,Coalesce(member.AssignmentKey,Text(varHoursProjectID) & "|" & Text(member.Worker.Id)) & "|" & Text(DateAdd(varWeekMonday,5,TimeUnit.Days),"[$-en-US]yyyymmdd"),
      SunKey,Coalesce(member.AssignmentKey,Text(varHoursProjectID) & "|" & Text(member.Worker.Id)) & "|" & Text(DateAdd(varWeekMonday,6,TimeUnit.Days),"[$-en-US]yyyymmdd")
     )))>=0,Collect(colWeekLoadErrors,{Message:FirstError.Message});false);
    IfError(CountRows(ClearCollect(colWeekRows,
     ForAll(colWeekKeys As member,
      With({mon:LookUp(colWeekStored,AssignmentID=member.ID && WorkDay=varWeekMonday),
            tue:LookUp(colWeekStored,AssignmentID=member.ID && WorkDay=DateAdd(varWeekMonday,1,TimeUnit.Days)),
            wed:LookUp(colWeekStored,AssignmentID=member.ID && WorkDay=DateAdd(varWeekMonday,2,TimeUnit.Days)),
            thu:LookUp(colWeekStored,AssignmentID=member.ID && WorkDay=DateAdd(varWeekMonday,3,TimeUnit.Days)),
            fri:LookUp(colWeekStored,AssignmentID=member.ID && WorkDay=DateAdd(varWeekMonday,4,TimeUnit.Days)),
            sat:LookUp(colWeekStored,AssignmentID=member.ID && WorkDay=DateAdd(varWeekMonday,5,TimeUnit.Days)),
            sun:LookUp(colWeekStored,AssignmentID=member.ID && WorkDay=DateAdd(varWeekMonday,6,TimeUnit.Days))},
       {ID:member.ID,Worker:member.Worker,Project:member.Project,Team:member.Team,Active:member.Active,
        AssignmentKey:member.AssignmentKey,ProjectKey:member.ProjectKey,Title:member.Title,
        MonKey:Coalesce(mon.EntryKey,member.MonKey),TueKey:Coalesce(tue.EntryKey,member.TueKey),WedKey:Coalesce(wed.EntryKey,member.WedKey),
        ThuKey:Coalesce(thu.EntryKey,member.ThuKey),FriKey:Coalesce(fri.EntryKey,member.FriKey),SatKey:Coalesce(sat.EntryKey,member.SatKey),SunKey:Coalesce(sun.EntryKey,member.SunKey),
        MonHours:mon.HourValue,TueHours:tue.HourValue,WedHours:wed.HourValue,ThuHours:thu.HourValue,FriHours:fri.HourValue,SatHours:sat.HourValue,SunHours:sun.HourValue}
      )
     )))>=0,Collect(colWeekLoadErrors,{Message:FirstError.Message});false)
   );
   If(IsEmpty(colWeekLoadErrors),
    IfError(CountRows(ClearCollect(colWeekOriginal,colWeekRows))>=0,Collect(colWeekLoadErrors,{Message:FirstError.Message});false)
   );
   If(IsEmpty(colWeekLoadErrors),
    Set(varWeekReady,true); Set(varLoadedWeekMonday,varWeekMonday);
    Set(varWeekMessage,
     If(IsEmpty(colWeekAssignments),"Geen actieve koppelingen voor dit project/team. Bekijk historische uren in Hours Summary.",
      Text(CountRows(colWeekStored)) & " opgeslagen dagregels teruggelezen voor de gekozen week; " & Text(CountRows(colWeekAssignments)) & " actieve medewerkers." &
      If(varWeekKeyIssue," Alleen lezen: ontbrekende, dubbele of afwijkende technische sleutels; opslaan geblokkeerd om duplicaten te voorkomen.",""))
    )
   )
  )
 );
 If(!IsEmpty(colWeekLoadErrors),
  Clear(colWeekRows); Clear(colWeekOriginal); Set(varWeekReady,false);
  Set(varWeekMessage,"Week laden gestopt: " & First(colWeekLoadErrors).Message);
  Notify(varWeekMessage,NotificationType.Error,15000)
 );
 Set(varWeekLoading,false)
)
