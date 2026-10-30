# GEA typography (22-10-2026), replaces Test-OpenSans.ps1. Fonts and weight roles only; colours are checked by Test-GeaColors.ps1.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-SaveRegression.ps1')
$font='="Inter, Arial, sans-serif"'
$technical=@('btnApplyTeamWeek','lblHomeLayout','lblHomeRows','lblHomeColumns','btnBuildReport','btnLoadReport','btnReadTeam','btnReadWeek','lblFooterButtonMetrics','lblSummaryFieldWidth','btnEmpLoad','btnEmpFormReset','lblEmpLayout','lblEmpMetrics')
$textTypes='^(Label@|Classic/Button@|Classic/DropDown@|Classic/TextInput@|Classic/CheckBox@|ModernDatePicker@)'
$homeTiles=@('ProjectTeam','WeeklyHours','HoursSummary','WeekReport','Workers','Contractors','Projects','Viewer3D','PIDTracker','ComponentLibrary','SkidConfigurator','StockOverview','Locations','Usage','Requests')
$semibold=@{
 'scrHome'=@('lblHomeTitle','lblHomeHeaderAdmin','lblHomeHeaderCad','lblHomeHeaderInventory')+@($homeTiles|ForEach-Object {'btnTile'+$_})
 'Screen1'=@('lblProjectTeamTitle','btnHomeScreen1','btnGotoHours','btnGotoHoursSummary','btnMigratePreview','btnMigrateConfirm','btnRefreshTeam','btnAddtoTeam')
 'scrHours'=@('lblWeeklyHoursEntryTitle','lblHeaderWorker','lblHeaderMon','lblHeaderTue','lblHeaderWed','lblHeaderThu','lblHeaderFri','lblHeaderSat','lblHeaderSun','lblHeaderTotal','btnHomeHours','btnWeeklyProjectTeam','btnRefreshWeek','btnDiscardWeek','btnSaveWeek')
 'scrContractors'=@('lblEmpTitle','btnEmpHome','btnEmpNew','btnEmpRefresh','btnEmpDiscard','btnEmpSave')
 'scrWeeklyHours'=@('lblWeeklyHoursTitle','lblReportNameHeader','lblReportEmployerHeader','lblReportWeekHeader','btnHomeSummary','btnSummaryProjectTeam','btnReportPreviousWeeks','btnReportNextWeeks','btnRefreshReport')
}
$bold=@{'scrContractors'=@('lblEmpMsgHead');'scrHome'=@();'Screen1'=@();'scrHours'=@();'scrWeeklyHours'=@('lblReportProject','lblReportContractor','lblReportFrom','lblReportUntil','lblReportTotalHeader','lblReportTotalRowLabel')}
# Conditional weights: Screen1 selection feedback; Hours Summary values that show an en dash (Normal) for 0 and Bold otherwise.
$conditional=@{
 'Screen1'=@{'Subtitle4'='=If(ThisItem.IsSelected, FontWeight.Semibold, FontWeight.Normal)'}
 'scrHours'=@{}
 'scrHome'=@{}
 'scrContractors'=@{}
 'scrWeeklyHours'=@{'lblReportWorkerTotal'='=If(ThisItem.PeriodTotal=0,FontWeight.Normal,FontWeight.Bold)';'lblReportTotalWeekHours'='=If(ThisItem.WeekSum=0,FontWeight.Normal,FontWeight.Bold)';'lblReportTotalRowValue'='=If(Sum(colReportRows,PeriodTotal)=0,FontWeight.Normal,FontWeight.Bold)'}
}
$fonts=0;$checked=0
foreach($screen in @('scrHome','Screen1','scrHours','scrWeeklyHours','scrContractors')){
 $new=$indexes[$screen]
 foreach($name in $new.Keys){
  $b=$new[$name]['Properties'];$type=[string]$new[$name]['Control']
  if($b.ContainsKey('Font')){ $fonts++; if($b['Font'] -ne $font){throw "Font not Inter/Arial: $screen.$name = $($b['Font'])"} }
  elseif($type -match $textTypes -and $name -notin $technical){throw "Visible text control without Font: $screen.$name"}
  if($name -in $technical -or $type -notmatch $textTypes){continue}
  $expected=if($name -in $semibold[$screen]){'=FontWeight.Semibold'}elseif($name -in $bold[$screen]){'=FontWeight.Bold'}elseif($conditional[$screen].ContainsKey($name)){$conditional[$screen][$name]}else{'=FontWeight.Normal'}
  if($b['FontWeight'] -ne $expected){throw "Wrong weight $screen.$name : $($b['FontWeight']) (expected $expected)"}
  $checked++
 }
 foreach($name in $semibold[$screen]+$bold[$screen]){if(!$new.ContainsKey($name)){throw "Missing $name"}}
}
$src=(Get-ChildItem (Join-Path $projectRoot 'Src') -Filter *.pa.yaml | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n"
if($src -match "Font\.'"){throw 'Font enum (Font.''…'') still present'}
if($src -match 'GEA Sans'){throw 'GEA Sans must not be used in the app'}
if($src -match 'Montserrat|Open Sans|Segoe UI'){throw 'Old font name still present'}
Write-Output "PASS $fonts Font properties = ""Inter, Arial, sans-serif"" (incl. hidden technical btnBuildReport); no Font enum, Open Sans, Segoe UI, Montserrat or GEA Sans in Src."
Write-Output "PASS weight roles on $checked text controls: Semibold titles/column headers/all buttons; Bold Project/Contractor/From/Till, Period total header and 'Total'; Period total values and Total row Bold except the en dash for 0 (Normal); Normal body/fields/table data; Subtitle4 conditional selection weight kept."
Write-Output 'Not verified locally: actual rendering of Inter vs Arial fallback per device/browser; Studio import of a text Font value on ModernDatePicker.'
