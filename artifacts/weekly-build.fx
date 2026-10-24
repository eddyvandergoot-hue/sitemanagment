=If(varReportReady && !varReportBusy && varReportProjectID=ddReportProject.Selected.ID,
 Set(varReportValid,false); Clear(colReportBuildErrors);
 Clear(colReportRows); Clear(colReportColumns); Clear(colReportSelectedHours);
 Set(varReportHasPeriod,!IsEmpty(colReportPeriods));
 If(varReportHasPeriod,
  If(IsBlank(ddReportStartYear.Selected.Value) || IsBlank(ddReportEndYear.Selected.Value) || IsBlank(ddReportStartWeek.Selected.Value) || IsBlank(ddReportEndWeek.Selected.Value),
   Collect(colReportBuildErrors,{Message:"Selecteer beginjaar, beginweek, eindjaar en eindweek."}),
   With({startYear:ddReportStartYear.Selected.Value,endYear:ddReportEndYear.Selected.Value,startWeek:ddReportStartWeek.Selected.Value,endWeek:ddReportEndWeek.Selected.Value},
    Set(varReportFrom,DateAdd(Date(startYear,1,4),1-Weekday(Date(startYear,1,4),StartOfWeek.Monday)+7*(startWeek-1),TimeUnit.Days));
    Set(varReportUntil,DateAdd(Date(endYear,1,4),1-Weekday(Date(endYear,1,4),StartOfWeek.Monday)+7*endWeek,TimeUnit.Days))
   );
   If(varReportFrom>=varReportUntil || DateDiff(varReportFrom,varReportUntil,TimeUnit.Days)/7>50000,
    Collect(colReportBuildErrors,{Message:"Kies een eindweek vanaf de beginweek en maximaal 50000 weken."}),
    IfError(CountRows(ClearCollect(colReportSelectedHours,Filter(colReportFacts,
     WorkDay>=varReportFrom && WorkDay<varReportUntil &&
     (Coalesce(ddReportContractor.Selected.ID,0)=0 || ContractorID=ddReportContractor.Selected.ID))))>=0,
     Collect(colReportBuildErrors,{Message:FirstError.Message});false);
    IfError(CountRows(ClearCollect(colReportColumns,
     ForAll(Sequence(DateDiff(varReportFrom,varReportUntil,TimeUnit.Days)/7) As weekIndex,
      With({monday:DateAdd(varReportFrom,7*(weekIndex.Value-1),TimeUnit.Days)},
       With({isoYearValue:Year(DateAdd(monday,3,TimeUnit.Days))},
        {WeekIndex:weekIndex.Value,Monday:monday,ISOYear:isoYearValue,
         KW:1+RoundDown(DateDiff(DateAdd(Date(isoYearValue,1,4),1-Weekday(Date(isoYearValue,1,4),StartOfWeek.Monday),TimeUnit.Days),monday,TimeUnit.Days)/7,0)}
       )
      )
     )))>=0,Collect(colReportBuildErrors,{Message:FirstError.Message});false)
   )
  )
 );
 If(IsEmpty(colReportBuildErrors),
  IfError(CountRows(ClearCollect(colReportRows,
   AddColumns(GroupBy(colReportSelectedHours,WorkerID,ContractorID,WorkerEntries) As reportRow,
    WorkerName,First(reportRow.WorkerEntries).WorkerName,
    ContractorName,First(reportRow.WorkerEntries).ContractorName,
    PeriodTotal,Sum(reportRow.WorkerEntries,HourValue))))>=0,
   Collect(colReportBuildErrors,{Message:FirstError.Message});false);
  ForAll(Filter(colReportWorkers,IsActive=true) As person,
   If((Coalesce(ddReportContractor.Selected.ID,0)=0 || person.ContractorID=ddReportContractor.Selected.ID) &&
      IsBlank(LookUp(colReportRows,WorkerID=person.WorkerID && ContractorID=person.ContractorID)),
    IfError(CountRows(Collect(colReportRows,{WorkerID:person.WorkerID,ContractorID:person.ContractorID,
     WorkerName:person.WorkerName,ContractorName:person.ContractorName,
     PeriodTotal:0,WorkerEntries:Filter(colReportSelectedHours,false)}))>=0,
     Collect(colReportBuildErrors,{Message:FirstError.Message});false)
   )
  )
 );
 If(IsEmpty(colReportBuildErrors),
  Set(varReportColumnOffset,1); Set(varReportValid,true);
  Set(varReportMessage,If(!varReportHasPeriod,"Geen opgeslagen uren voor dit project; actieve medewerkers staan op 0. ","") &
   Text(CountRows(colReportRows)) & " medewerkers/contractors | " & Text(CountRows(colReportColumns)) & " weken | " &
   Text(Sum(colReportRows,PeriodTotal),If(Sum(colReportRows,PeriodTotal)=Round(Sum(colReportRows,PeriodTotal),0),"[$-en-US]0","[$-en-US]0.00"),"nl-NL") & " uur"),
  Clear(colReportRows); Clear(colReportColumns); Clear(colReportSelectedHours);
  Set(varReportMessage,"Rapport gestopt: " & First(colReportBuildErrors).Message);
  Notify(varReportMessage,NotificationType.Error)
 )
)
