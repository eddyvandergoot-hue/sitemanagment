# GEA typography (22-10-2026), replaces Test-OpenSans.ps1. Fonts and weight roles only; colours are checked by Test-GeaColors.ps1.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-SaveRegression.ps1')
$font='="Inter, Arial, sans-serif"'
$technical=@('btnApplyTeamWeek','lblHomeLayout','lblHomeRows','lblHomeColumns','btnBuildReport','btnLoadReport','btnReadTeam','btnReadWeek','lblFooterButtonMetrics','lblSummaryFieldWidth','btnEmpLoad','btnEmpFormReset','lblEmpLayout','lblEmpMetrics','lblEmpGrid','btnPrjLoad','btnPrjFormReset','lblPrjLayout','lblPrjMetrics','lblPrjGrid')
$textTypes='^(Label@|Classic/Button@|Classic/DropDown@|Classic/TextInput@|Classic/CheckBox@|ModernDatePicker@)'
$homeTiles=@('ProjectTeam','WeeklyHours','HoursSummary','WeekReport','Workers','Contractors','Projects','Viewer3D','PIDTracker','ComponentLibrary','SkidConfigurator','StockOverview','Locations','Usage','Requests','KnowledgeBase')
$semibold=@{
 'scrHome'=@('lblHomeTitle','lblHomeHeaderAdmin','lblHomeHeaderCad','lblHomeHeaderInventory','lblHomeHeaderKnowledge')+@($homeTiles|ForEach-Object {'btnTile'+$_})
 'Screen1'=@('lblProjectTeamTitle','btnHomeScreen1','btnGotoHours','btnGotoHoursSummary','btnMigratePreview','btnMigrateConfirm','btnRefreshTeam','btnAddtoTeam')
 'scrHours'=@('lblWeeklyHoursEntryTitle','lblHeaderWorker','lblHeaderMon','lblHeaderTue','lblHeaderWed','lblHeaderThu','lblHeaderFri','lblHeaderSat','lblHeaderSun','lblHeaderTotal','btnHomeHours','btnWeeklyProjectTeam','btnRefreshWeek','btnDiscardWeek','btnSaveWeek')
 'scrContractors'=@('lblEmpFormTitle')  # 30-10-2026 step 3a: title, labels, list rows and footer buttons live in the components (checked in the component section below)
 'scrProjects'=@('lblPrjFormTitle')  # step 3b: title, labels, list rows and footer buttons live in the components
 'scrWeeklyHours'=@('lblWeeklyHoursTitle','lblReportNameHeader','lblReportEmployerHeader','lblReportWeekHeader','btnHomeSummary','btnSummaryProjectTeam','btnReportPreviousWeeks','btnReportNextWeeks','btnRefreshReport')
}
$bold=@{'scrContractors'=@('lblEmpSecGeneral','lblEmpSecAddress','lblEmpSecContact');'scrProjects'=@('lblPrjSecGeneral','lblPrjSecAddress','lblPrjSecPeople','lblPrjSecLinks');'scrHome'=@();'Screen1'=@();'scrHours'=@();'scrWeeklyHours'=@('lblReportProject','lblReportContractor','lblReportFrom','lblReportUntil','lblReportTotalHeader','lblReportTotalRowLabel')}
# Conditional weights: Screen1 selection feedback; Hours Summary values that show an en dash (Normal) for 0 and Bold otherwise.
$conditional=@{
 'Screen1'=@{'Subtitle4'='=If(ThisItem.IsSelected, FontWeight.Semibold, FontWeight.Normal)'}
 'scrHours'=@{}
 'scrHome'=@{}
 'scrContractors'=@{}
 'scrProjects'=@{}
 'scrWeeklyHours'=@{'lblReportWorkerTotal'='=If(ThisItem.PeriodTotal=0,FontWeight.Normal,FontWeight.Bold)';'lblReportTotalWeekHours'='=If(ThisItem.WeekSum=0,FontWeight.Normal,FontWeight.Bold)';'lblReportTotalRowValue'='=If(Sum(colReportRows,PeriodTotal)=0,FontWeight.Normal,FontWeight.Bold)'}
}
$fonts=0;$checked=0
foreach($screen in @('scrHome','Screen1','scrHours','scrWeeklyHours','scrContractors','scrProjects')){
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
# Canvas components (Src\Component): every control with text carries the Inter font; weights per role.
$componentTextTypes='^(Label@|Classic/Button@|Classic/TextInput@|HtmlViewer@|ModernSpinner@)'
$componentSemibold=@('lblCmpTitleText','btnCmpHome','btnCmpNew','btnCmpRefresh','btnCmpDiscard','btnCmpSave')
$componentTechnical=@('lblCmpFooterMetrics')
$componentFonts=0
foreach($componentFile in Get-ChildItem (Join-Path $projectRoot 'Src\Component') -Filter *.pa.yaml){
 $componentDoc=$builder.Build().Deserialize([IO.File]::ReadAllText($componentFile.FullName))
 foreach($componentName in $componentDoc['ComponentDefinitions'].Keys){
  $componentIndex=@{};Index-RegressionControls $componentDoc['ComponentDefinitions'][$componentName]['Children'] $componentIndex
  foreach($name in $componentIndex.Keys){
   $type=[string]$componentIndex[$name]['Control'];$b=$componentIndex[$name]['Properties']
   if($type -notmatch $componentTextTypes){continue}
   if($b['Font'] -ne $font){throw "Component font not Inter/Arial: $componentName.$name = $($b['Font'])"}
   $componentFonts++
   if($type -like 'HtmlViewer@*' -or $type -like 'ModernSpinner@*' -or $name -in $componentTechnical){continue}
   $expected=if($name -in $componentSemibold){'=FontWeight.Semibold'}else{'=FontWeight.Normal'}
   if($b['FontWeight'] -ne $expected){throw "Wrong component weight $componentName.$name : $($b['FontWeight']) (expected $expected)"}
  }
  foreach($name in $componentIndex.Keys){ if($componentIndex[$name]['Control'] -like 'HtmlViewer@*'){ if(([string]$componentIndex[$name]['Properties']['HtmlText']) -notmatch 'font-family:Inter,Arial,sans-serif'){throw "Component HtmlText without Inter/Arial font-family: $componentName.$name"} } }
 }
}
if($componentFonts -eq 0){throw 'No component text controls found in Src\Component.'}
Write-Output "PASS components: $componentFonts text controls in Src\Component use Font Inter/Arial (HtmlText CSS font-family Inter, Arial, sans-serif); titles/buttons Semibold, other labels Normal."
$src=(Get-ChildItem (Join-Path $projectRoot 'Src') -Filter *.pa.yaml -Recurse | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n"
if($src -match "Font\.'"){throw 'Font enum (Font.''…'') still present'}
if($src -match 'GEA Sans'){throw 'GEA Sans must not be used in the app'}
if($src -match 'Montserrat|Open Sans|Segoe UI'){throw 'Old font name still present'}
Write-Output "PASS $fonts Font properties = ""Inter, Arial, sans-serif"" (incl. hidden technical btnBuildReport); no Font enum, Open Sans, Segoe UI, Montserrat or GEA Sans in Src."
Write-Output "PASS weight roles on $checked text controls: Semibold titles/column headers/all buttons; Bold Project/Contractor/From/Till, Period total header and 'Total'; Period total values and Total row Bold except the en dash for 0 (Normal); Normal body/fields/table data; Subtitle4 conditional selection weight kept."
Write-Output 'Not verified locally: actual rendering of Inter vs Arial fallback per device/browser; Studio import of a text Font value on ModernDatePicker.'
