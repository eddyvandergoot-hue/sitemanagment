$ErrorActionPreference='Stop'
$installer=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Optimize-Loading.ps1'))
Invoke-Expression ($installer.Substring(0,$installer.IndexOf("Read-Screen 'Screen1'")).Replace('$PSScriptRoot',("'"+$PSScriptRoot+"'")))
function Refresh-Steps($flag,$errors,$sources) {
 $steps=($sources|ForEach-Object {"IfError(Refresh($_),Collect($errors,{Message:FirstError.Message});false);"}) -join "`n"
 return "If($flag,`n$steps`n Set($flag,false)`n);"
}
Read-Screen 'Screen1'
$team=$controls['btnReadTeam']['Properties']['OnSelect']
$team=$team.Replace('Clear(colSelectionLoadErrors);',('Clear(colSelectionLoadErrors);'+(Refresh-Steps 'varForceTeamRefresh' 'colSelectionLoadErrors' @('Projects','Workers',"'Project Workers'"))))
$team=$team.Replace('If(IsEmpty(colSelectionLoadErrors),'+"`n"+'  IfError(CountRows(ClearCollect(colSelectionProjects,','If(IsEmpty(colSelectionLoadErrors) && Coalesce(varSelectionProjectsEpoch,-1)<>Coalesce(varDataEpoch,0),'+"`n"+'  IfError(CountRows(ClearCollect(colSelectionProjects,')
$team=$team.Replace("If(IsEmpty(colSelectionLoadErrors),`r`n  IfError(CountRows(ClearCollect(colSelectionProjects,","If(IsEmpty(colSelectionLoadErrors) && Coalesce(varSelectionProjectsEpoch,-1)<>Coalesce(varDataEpoch,0),`r`n  IfError(CountRows(ClearCollect(colSelectionProjects,")
$team=$team.Replace('Set(varSelectionLoaded,true);','Set(varSelectionLoaded,true); Set(varSelectionProjectsEpoch,Coalesce(varDataEpoch,0));')
Replace-Property 'btnReadTeam' 'OnSelect' $team
Replace-Property 'btnRefreshTeam' 'OnSelect' ('='+$invalidate+' Set(varSelectionLoaded,false); Set(varForceTeamRefresh,true); Select(btnReadTeam)')
# Place Refresh below project/team fields, above status; no overlap with the fields.
Replace-Property 'btnRefreshTeam' 'Y' '=184'
Write-Screen
Read-Screen 'scrHours'
$week=$controls['btnReadWeek']['Properties']['OnSelect']
$week=$week.Replace('Clear(colWeekLoadErrors); Clear(colWeekAssignments);',('Clear(colWeekLoadErrors);'+(Refresh-Steps 'varForceWeekRefresh' 'colWeekLoadErrors' @('Hours',"'Project Workers'"))+' Clear(colWeekAssignments);'))
# A cached week must restore save-validation context as well as displayed rows.
$week=$week.Replace('ClearCollect(colWeekRows,cached.Rows);', 'Set(varHoursProjectID,Coalesce(varProject.Id,ddProject.Selected.Id)); Set(varHoursProjectKey,Text(varHoursProjectID)); Set(varHoursTeam,Coalesce(varTeam.Value,ddTeam.Selected.Value)); ClearCollect(colWeekAssignments,cached.Assignments); ClearCollect(colWeekStored,cached.Stored); ClearCollect(colWeekRows,cached.Rows);')
$week=$week.Replace('Rows:colWeekRows,Monday:', 'Rows:colWeekRows,Assignments:colWeekAssignments,Stored:colWeekStored,Monday:')
Replace-Property 'btnReadWeek' 'OnSelect' $week
Replace-Property 'btnRefreshWeek' 'OnSelect' ('='+$invalidate+' Set(varWeekReady,false); Set(varForceWeekRefresh,true); Select(btnReadWeek)')
Write-Screen
Read-Screen 'scrWeeklyHours'
$report=$controls['btnLoadReport']['Properties']['OnSelect']
$report=$report.Replace('Clear(colReportLoadErrors);',('Clear(colReportLoadErrors);'+(Refresh-Steps 'varForceReportRefresh' 'colReportLoadErrors' @('Projects','Hours',"'Project Workers'",'Workers'))))
Replace-Property 'btnLoadReport' 'OnSelect' $report
Replace-Property 'btnRefreshReport' 'OnSelect' ('='+$invalidate+' Set(varReportReady,false); Set(varForceReportRefresh,true); Select(btnLoadReport)')
Write-Screen

