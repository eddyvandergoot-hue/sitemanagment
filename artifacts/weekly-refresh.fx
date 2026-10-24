=If(!varReportBusy,
 Set(varReportBusy,true); Set(varReportReady,false); Set(varReportValid,false);
 Set(varReportProjectID,ddReportProject.Selected.ID);
 Clear(colReportLoadErrors); Clear(colReportFacts); Clear(colReportRows);
 Clear(colReportColumns); Clear(colReportSelectedHours); Clear(colReportAssignments);
 Clear(colReportWorkers); Clear(colReportPeriods); Clear(colReportYears);
 Clear(colReportStartWeeks); Clear(colReportEndWeeks); Clear(colReportContractors); Clear(colReportContractorCandidates);
 IfError(Refresh(Projects),Collect(colReportLoadErrors,{Message:FirstError.Message});false);
 If(IsEmpty(colReportLoadErrors),
  IfError(CountRows(ClearCollect(colReportProjects,Sort(Projects,Title,SortOrder.Ascending)))>=0,
   Collect(colReportLoadErrors,{Message:FirstError.Message});false)
 );
 If(CountRows(colReportProjects)>=500,
  Collect(colReportLoadErrors,{Message:"Projectkeuze mogelijk onvolledig (500 projecten). Rapportage gestopt; een zoekbare projectselectie is nodig."})
 );
 If(IsEmpty(colReportLoadErrors),Reset(ddReportProject); Set(varReportProjectID,ddReportProject.Selected.ID));
 If(IsEmpty(colReportLoadErrors) && !IsBlank(varReportProjectID),
  IfError(Refresh(Hours),Collect(colReportLoadErrors,{Message:FirstError.Message});false);
  IfError(Refresh('Project Workers'),Collect(colReportLoadErrors,{Message:FirstError.Message});false);
  IfError(Refresh(Workers),Collect(colReportLoadErrors,{Message:FirstError.Message});false);
  If(IsEmpty(colReportLoadErrors),
   IfError(CountRows(ClearCollect(colReportAssignments,
    Filter('Project Workers',Project.Id=varReportProjectID)))>=0,
    Collect(colReportLoadErrors,{Message:FirstError.Message});false)
  );
  If(CountRows(colReportAssignments)>=500,
   Collect(colReportLoadErrors,{Message:"500 projectkoppelingen geladen. Volledigheid niet gegarandeerd; rapportage gestopt."})
  );
  If(IsEmpty(colReportLoadErrors),
   ForAll(Distinct(colReportAssignments,Worker.Id) As person,
    IfError(
     With({profile:LookUp(Workers,ID=person.Value),
           activeMember:CountIf(colReportAssignments,Worker.Id=person.Value && Active=true)>0},
      If(IsBlank(person.Value) || (activeMember && (IsBlank(profile.ID) || IsBlank(profile.Employer.Id))),
       Collect(colReportLoadErrors,{Message:"Actieve medewerker of werkgever ontbreekt bij worker-ID " & Text(person.Value)});false,
       CountRows(Collect(colReportWorkers,{WorkerID:person.Value,
        WorkerName:Coalesce(Trim(profile.'First Name' & " " & profile.Surname),LookUp(colReportAssignments,Worker.Id=person.Value,Worker.Value)),
        ContractorID:profile.Employer.Id,ContractorName:profile.Employer.Value,IsActive:activeMember}))>=0
      )
     ),Collect(colReportLoadErrors,{Message:FirstError.Message});false
    )
   )
  );
  If(IsEmpty(colReportLoadErrors),
   ForAll(colReportAssignments As member,
    IfError(
     With({firstHour:First(Sort(Filter(Hours,Assignment.Id=member.ID),'Work Date',SortOrder.Ascending)),
           lastHour:First(Sort(Filter(Hours,Assignment.Id=member.ID),'Work Date',SortOrder.Descending))},
      If(IsBlank(firstHour.ID),true,
       If(IsBlank(firstHour.'Work Date') || IsBlank(lastHour.'Work Date') || Year(lastHour.'Work Date')-Year(firstHour.'Work Date')>499,
        Collect(colReportLoadErrors,{Message:"Ongeldig datumbereik bij koppeling " & Text(member.ID)});false,
        CountRows(ForAll(Sequence(Year(lastHour.'Work Date')-Year(firstHour.'Work Date')+1,Year(firstHour.'Work Date')) As calendarYear,
         With({dateFrom:Date(calendarYear.Value,1,1),dateUntil:Date(calendarYear.Value+1,1,1),assignmentID:member.ID},
          IfError(
           With({batch:ForAll(Filter(Hours,Assignment.Id=assignmentID && 'Work Date'>=dateFrom && 'Work Date'<dateUntil) As entry,
            {HourID:entry.ID,WorkDay:entry.'Work Date',ContractorID:entry.Employer.Id,
             ContractorName:entry.Employer.Value,HourValue:entry.Hours})},
            If(CountRows(batch)>=500,
             Collect(colReportLoadErrors,{Message:"Limiet bereikt bij koppeling " & Text(assignmentID) & ", jaar " & Text(calendarYear.Value) & ". Geen totalen getoond."});false,
             If(CountIf(batch,IsBlank(WorkDay) || IsBlank(ContractorID) || IsBlank(HourValue))>0,
              Collect(colReportLoadErrors,{Message:"Urenregel zonder datum, historische werkgever of uren bij koppeling " & Text(assignmentID)});false,
              CountRows(Collect(colReportFacts,ForAll(batch As entry,
               With({workDay:Date(Year(entry.WorkDay),Month(entry.WorkDay),Day(entry.WorkDay))},
                With({monday:DateAdd(workDay,1-Weekday(workDay,StartOfWeek.Monday),TimeUnit.Days)},
                 With({isoYearValue:Year(DateAdd(monday,3,TimeUnit.Days))},
                  {HourID:entry.HourID,WorkerID:member.Worker.Id,
                   WorkerName:LookUp(colReportWorkers,WorkerID=member.Worker.Id,WorkerName),
                   ContractorID:entry.ContractorID,ContractorName:entry.ContractorName,
                   WorkDay:workDay,Monday:monday,ISOYear:isoYearValue,
                   KW:1+RoundDown(DateDiff(DateAdd(Date(isoYearValue,1,4),1-Weekday(Date(isoYearValue,1,4),StartOfWeek.Monday),TimeUnit.Days),monday,TimeUnit.Days)/7,0),
                   HourValue:entry.HourValue}
                 )
                )
               )
              )))>=0
             )
            )
           ),Collect(colReportLoadErrors,{Message:FirstError.Message});false
          )
         )
        ))>=0
       )
      )
     ),Collect(colReportLoadErrors,{Message:FirstError.Message});false
    )
   )
  );
  If(IsEmpty(colReportLoadErrors),
   IfError(CountRows(ClearCollect(colReportPeriods,
    Sort(AddColumns(GroupBy(colReportFacts,ISOYear,KW,Monday,PeriodRecords),PeriodKey,ISOYear*100+KW),PeriodKey,SortOrder.Ascending)))>=0,
    Collect(colReportLoadErrors,{Message:FirstError.Message});false);
   IfError(CountRows(ClearCollect(colReportYears,Sort(Distinct(colReportPeriods,ISOYear),Value,SortOrder.Ascending)))>=0,
    Collect(colReportLoadErrors,{Message:FirstError.Message});false);
   Collect(colReportContractorCandidates,{ID:0,Value:"Alle contractors"});
   ForAll(Distinct(colReportFacts,ContractorID) As contractor,
    Collect(colReportContractorCandidates,{ID:contractor.Value,Value:Coalesce(LookUp(colReportFacts,ContractorID=contractor.Value,ContractorName),"Werkgever " & Text(contractor.Value))})
   );
   ForAll(Filter(colReportWorkers,IsActive=true) As person,
    Collect(colReportContractorCandidates,{ID:person.ContractorID,Value:Coalesce(person.ContractorName,"Werkgever " & Text(person.ContractorID))})
   );
   ClearCollect(colReportContractors,DropColumns(AddColumns(GroupBy(colReportContractorCandidates,ID,ContractorRecords),Value,First(ContractorRecords).Value),ContractorRecords));
   If(CountRows(colReportContractors)>500 || CountRows(colReportYears)>500,
    Collect(colReportLoadErrors,{Message:"Meer dan 500 keuzewaarden. Rapportage gestopt om onvolledige keuzes te voorkomen."})
   )
  );
  If(IsEmpty(colReportLoadErrors),
   Set(varReportDefaultStartYear,First(colReportPeriods).ISOYear);
   Set(varReportDefaultEndYear,Last(colReportPeriods).ISOYear);
   ClearCollect(colReportStartWeeks,Sort(Distinct(Filter(colReportPeriods,ISOYear=varReportDefaultStartYear),KW),Value,SortOrder.Ascending));
   ClearCollect(colReportEndWeeks,Sort(Distinct(Filter(colReportPeriods,ISOYear=varReportDefaultEndYear),KW),Value,SortOrder.Ascending));
   Reset(ddReportContractor); Reset(ddReportStartYear); Reset(ddReportEndYear); Reset(ddReportStartWeek); Reset(ddReportEndWeek);
   Set(varReportReady,true)
  )
 );
 If(!IsEmpty(colReportLoadErrors),
  Set(varReportReady,false); Set(varReportValid,false);
  Clear(colReportFacts); Clear(colReportRows); Clear(colReportColumns); Clear(colReportSelectedHours);
  Clear(colReportPeriods); Clear(colReportYears); Clear(colReportStartWeeks); Clear(colReportEndWeeks); Clear(colReportContractors);
  Set(varReportMessage,"Ophalen gestopt: " & First(colReportLoadErrors).Message);
  Notify(varReportMessage,NotificationType.Error),
  If(IsBlank(varReportProjectID),Set(varReportMessage,"Selecteer een project."))
 );
 Set(varReportBusy,false);
 If(varReportReady,Select(btnBuildReport))
)
