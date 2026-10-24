$ErrorActionPreference='Stop'
$installer=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Optimize-Loading.ps1'))
Invoke-Expression ($installer.Substring(0,$installer.IndexOf("Read-Screen 'Screen1'")).Replace('$PSScriptRoot',("'"+$PSScriptRoot+"'")))
Read-Screen 'scrWeeklyHours'
$original=$controls['btnLoadReport']['Properties']['OnSelect'].TrimStart('=')
$restore=@'
ClearCollect(colReportFacts,cached.Facts); ClearCollect(colReportWorkers,cached.Workers);
ClearCollect(colReportAssignments,cached.Assignments); ClearCollect(colReportPeriods,cached.Periods);
ClearCollect(colReportYears,cached.Years); ClearCollect(colReportContractors,cached.Contractors);
Set(varReportProjectID,cached.ProjectID); Set(varReportEpoch,cached.Epoch);
Set(varReportDefaultStartYear,First(colReportPeriods).ISOYear); Set(varReportDefaultEndYear,Last(colReportPeriods).ISOYear);
ClearCollect(colReportStartWeeks,Sort(Distinct(Filter(colReportPeriods,ISOYear=varReportDefaultStartYear),KW),Value,SortOrder.Ascending));
ClearCollect(colReportEndWeeks,Sort(Distinct(Filter(colReportPeriods,ISOYear=varReportDefaultEndYear),KW),Value,SortOrder.Ascending));
Set(varReportBusy,true); Set(varReportValid,false);
Reset(ddReportContractor); Reset(ddReportStartYear); Reset(ddReportEndYear); Reset(ddReportStartWeek); Reset(ddReportEndWeek);
Clear(colReportLoadErrors); Set(varReportReady,true); Set(varReportBusy,false); Select(btnBuildReport)
'@
$formula=@"
=If(!varReportBusy && (!varReportReady || Coalesce(varReportEpoch,-1)<>Coalesce(varDataEpoch,0) || Coalesce(varReportProjectID,0)<>Coalesce(ddReportProject.Selected.ID,0)),
 With({cached:LookUp(colReportCache,ProjectID=ddReportProject.Selected.ID && Epoch=Coalesce(varDataEpoch,0))},
  If(!varForceReportRefresh && !IsBlank(cached.ProjectID),
   $restore,
   $original;
   If(varReportReady,
    Collect(colReportCache,{ProjectID:varReportProjectID,Epoch:Coalesce(varDataEpoch,0),Facts:colReportFacts,Workers:colReportWorkers,Assignments:colReportAssignments,Periods:colReportPeriods,Years:colReportYears,Contractors:colReportContractors})
   )
  )
 )
)
"@
Replace-Property 'btnLoadReport' 'OnSelect' $formula
Write-Screen
# Explicit projection after the delegated filter; never move date/assignment filtering to a collection.
foreach($screen in @('scrHours','scrWeeklyHours')) {
 Read-Screen $screen
 $name=if($screen -eq 'scrHours'){'btnReadWeek'}else{'btnLoadReport'}
 $fx=$controls[$name]['Properties']['OnSelect']
 $filter="Filter(Hours,Assignment.Id=assignmentID && 'Work Date'>=dateFrom && 'Work Date'<dateUntil)"
 $columns=if($screen -eq 'scrHours'){"ID,'Work Date',EntryKey,Hours"}else{"ID,'Work Date',Employer,Hours"}
 $fx=$fx.Replace($filter,"ShowColumns($filter,$columns)")
 Replace-Property $name 'OnSelect' $fx
 Write-Screen
}
# All invalidation sites clear both nested caches to release memory and prevent stale reuse.
foreach($screen in @('Screen1','scrHours','scrWeeklyHours')) {
 $file=Join-Path $root ('Src/'+$screen+'.pa.yaml')
 $text=[IO.File]::ReadAllText($file).Replace('Clear(colWeekCache);','Clear(colWeekCache); Clear(colReportCache);')
 [IO.File]::WriteAllText($file,$text,(New-Object Text.UTF8Encoding($false)))
}
