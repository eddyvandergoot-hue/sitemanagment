param([switch]$HistoricalDiff)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-SaveRegression.ps1')
$new=$indexes['scrWeeklyHours']
$font='="Inter, Arial, sans-serif"'
$technical=@('btnBuildReport','btnLoadReport','lblSummaryFieldWidth')

if($HistoricalDiff){
# Historical (20-10-2026): diff against checkpoint summary-style. Fails since later commissions (dates, labels, fonts, GEA colours); kept for reference.
$backup=Join-Path $projectRoot (Get-Content (Join-Path $PSScriptRoot 'summary-style-backup.txt') -Raw).Trim()
$laterDateChange=@('lblddReportStartYear','ddReportStartYear','lblddReportStartWeek','ddReportStartWeek','lblddReportEndYear','ddReportEndYear','lblddReportEndWeek','ddReportEndWeek','lblReportFrom','dpReportFrom','lblReportUntil','dpReportUntil','lblReportIsoPeriod','btnBuildReport','btnLoadReport','conSummaryFiltersContent','lblReportContractor','ddReportContractor',
 'lblWeeklyHoursTitle','lblReportProjectDetails','lblReportTotalHeader','lblReportWorkerTotal','lblReportGrandTotal','lblReportProject')
$styleKeys=@('Font','Color','Fill','FontWeight','VerticalAlign','PaddingLeft','PaddingRight')
$explicit=@{'lblReportStatus'=@('Text','Y','Height');'galReportRows'=@('Items','TemplateFill');'conSummarySelectors'=@('Y');'btnSummaryProjectTeam'=@('Width');'btnRefreshReport'=@('Width')}
foreach($name in @('App.pa.yaml','_EditorState.pa.yaml')){if((Get-FileHash (Join-Path $backup ('Src/'+$name))).Hash -ne (Get-FileHash (Join-Path $projectRoot ('Src/'+$name))).Hash){throw "Unexpected change $name"}}
$old=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $backup 'Src/scrWeeklyHours.pa.yaml')));$oldIndex=@{};Index-RegressionControls $old['Screens']['scrWeeklyHours']['Children'] $oldIndex
foreach($name in $oldIndex.Keys){
 if($name -in $laterDateChange){continue}
 if(!$new.ContainsKey($name)){if($name -eq 'lblSummaryPurpose'){continue};throw "Removed control $name"}
 foreach($key in @($oldIndex[$name]['Properties'].Keys)+@($new[$name]['Properties'].Keys)|Select-Object -Unique){
  $a=$oldIndex[$name]['Properties'][$key];$b=$new[$name]['Properties'][$key]
  if($a -ceq $b){continue}
  if($explicit.ContainsKey($name) -and $key -in $explicit[$name]){continue}
  if($key -notin $styleKeys){throw "Non-style change $name.$key"}
 }
}
Write-Output 'PASS historical diff against summary-style checkpoint.'
}

# Fonts and text colours (GEA): Inter/Arial; labels black, white on blue, Period total values Navy #000F41.
$fontless=@($new.Keys|Where-Object {$_ -notin $technical -and $new[$_]['Properties'].ContainsKey('Font') -and $new[$_]['Properties']['Font'] -ne $font})
if($fontless.Count){throw "Controls not Inter/Arial: $($fontless -join ',')"}
$buttons=@('btnSummaryProjectTeam','btnReportPreviousWeeks','btnReportNextWeeks','btnRefreshReport')
$odd=@($new.Keys|Where-Object {$_ -notin $technical -and $_ -notin $buttons -and $new[$_]['Properties']['Color'] -and $new[$_]['Properties']['Color'] -notin @('=ColorValue("#000000")','=Color.White','=ColorValue("#000F41")')})
if($odd.Count){throw "Unexpected text colour: $($odd -join ',')"}
Write-Output 'PASS fonts Inter/Arial; text black, white on blue, Period total values #000F41 (buttons checked by Test-GeaColors.ps1).'

$statusFx=$new['lblReportStatus']['Properties']['Text'].TrimStart('=')
$note='Geen opgeslagen uren voor dit project; medewerkers met een periode in de huidige week staan op 0.'
foreach($c in @(
 @('varReportBusy:true,varReportValid:false,varReportMessage:"x",varReportProjectID:7,varReportHasPeriod:true','Uren ophalen...','busy'),
 @('varReportBusy:false,varReportValid:false,varReportMessage:"Ophalen gestopt: fout",varReportProjectID:7,varReportHasPeriod:true','Ophalen gestopt: fout','load error kept'),
 @('varReportBusy:false,varReportValid:false,varReportMessage:"Rapport gestopt: fout",varReportProjectID:7,varReportHasPeriod:true','Rapport gestopt: fout','build error kept'),
 @('varReportBusy:false,varReportValid:true,varReportMessage:"8 medewerkers/contractors | 3 weken | 178 uur",varReportProjectID:7,varReportHasPeriod:true','','statistics hidden'),
 @('varReportBusy:false,varReportValid:true,varReportMessage:"Geen opgeslagen uren voor dit project; medewerkers met een periode in de huidige week staan op 0. 2 medewerkers/contractors | 0 weken | 0 uur",varReportProjectID:7,varReportHasPeriod:false',$note,'empty-project note kept'),
 @('varReportBusy:false,varReportValid:true,varReportMessage:"x",varReportProjectID:Blank(),varReportHasPeriod:false','','no project: details label shows selection prompt'))){
 Assert-Regression ('With({'+$c[0]+'},'+$statusFx+')') $c[1] ('Status '+$c[2])
}

$rowsFx=$new['galReportRows']['Properties']['Items'].TrimStart('=')
$fixture='colReportRows:Table({WorkerID:4,ContractorID:1,WorkerName:"Cees",ContractorName:"A",PeriodTotal:5,WorkerEntries:Table({HourValue:5})},{WorkerID:2,ContractorID:2,WorkerName:"Anna",ContractorName:"B",PeriodTotal:0,WorkerEntries:Table({HourValue:0})},{WorkerID:8,ContractorID:1,WorkerName:"Bob",ContractorName:"A",PeriodTotal:7.5,WorkerEntries:Table({HourValue:7.5})},{WorkerID:6,ContractorID:3,WorkerName:"Bob",ContractorName:"C",PeriodTotal:1,WorkerEntries:Table({HourValue:1})})'
Assert-Regression ('With({'+$fixture+'},Concat('+$rowsFx+',WorkerName&":"&ContractorName&":"&RowNumber,"|"))') 'Anna:B:1|Bob:A:2|Bob:C:3|Cees:A:4' 'Rows keep sort order and get consecutive row numbers'
Assert-Regression ('With({'+$fixture+'},Sum('+$rowsFx+',PeriodTotal)&"/"&CountRows('+$rowsFx+'))') '13.5/4' 'Rows keep totals and count'
$fillFx=$new['galReportRows']['Properties']['TemplateFill'].TrimStart('=')
$fills=@(1..4|ForEach-Object {$v=$regressionEngine.Eval('With({ThisItem:{RowNumber:'+$_+'}},'+$fillFx+')',$null,$regressionOptions);'{0:X2}{1:X2}{2:X2}' -f $v.Value.R,$v.Value.G,$v.Value.B})
if(($fills -join ',') -ne 'FFFFFF,F0F0F0,FFFFFF,F0F0F0'){throw "Row fills $($fills -join ',')"};Write-Output 'PASS zebra FFFFFF/F0F0F0 by visible row position.'

# Zero shown as an en dash with Normal weight; data stays numeric (only the Text formula branches).
$dash=[string][char]0x2013
$weekText=$new['lblReportWeekHours']['Properties']['Text'];$totText=$new['lblReportWorkerTotal']['Properties']['Text']
if(!$weekText.StartsWith('=If(ThisItem.WeekHours=0,"'+$dash+'",') -or !$totText.StartsWith('=If(ThisItem.PeriodTotal=0,"'+$dash+'",')){throw 'Zero not shown as en dash'}
if($new['lblReportWeekHours']['Properties']['FontWeight'] -ne '=FontWeight.Normal' -or $new['lblReportWorkerTotal']['Properties']['FontWeight'] -ne '=If(ThisItem.PeriodTotal=0,FontWeight.Normal,FontWeight.Bold)'){throw 'Zero weight not Normal'}
foreach($c in @(@('0',$dash),@('8','8'),@('7.5','7.5'))){
 Assert-Regression ('With({ThisItem:{WeekHours:'+$c[0]+'}},If(ThisItem.WeekHours=0,"'+$dash+'",Text(ThisItem.WeekHours)))') $c[1] "Week cell display $($c[0])"
}
$p=$new['lblReportWorkerTotal']['Properties']
if($p['Fill'] -ne '=Color.Transparent' -or $p['Color'] -ne '=ColorValue("#000F41")'){throw 'Period total column: no fill and #000F41 text expected'}
foreach($n in @('recReportRowLine','recReportRowTotalLine')){if($new[$n]['Properties']['Fill'] -ne '=ColorValue("#DCDCDC")'){throw "$n line colour"}}
if($new['recReportRowTotalLine']['Properties']['X'] -ne $p['X'] -or $new['recReportRowTotalLine']['Properties']['Width'] -ne '=1'){throw 'Period total left line not at the column edge'}
Write-Output 'PASS zero -> en dash (Normal); Period total column no fill, #000F41 Bold, 1px #DCDCDC left line; row lines #DCDCDC.'

# Total row: same week paging as the header, sums from the selected hours, period total = sum of rows.
$hdrItems=$new['galReportWeekHeaders']['Properties']['Items'].TrimStart('=')
$totItems=$new['galReportTotalWeeks']['Properties']['Items'].TrimStart('=')
if(!$totItems.StartsWith('AddColumns('+$hdrItems+' As week,WeekSum,')){throw 'Total row week paging differs from the header'}
$hours='colReportSelectedHours:Table({Monday:Date(2026,10,5),HourValue:8},{Monday:Date(2026,10,5),HourValue:7.5},{Monday:Date(2026,10,19),HourValue:4})'
$cols='colReportColumns:Table({WeekIndex:1,Monday:Date(2026,10,5)},{WeekIndex:2,Monday:Date(2026,10,12)},{WeekIndex:3,Monday:Date(2026,10,19)})'
Assert-Regression ('With({scrWeeklyHours:{Width:1366},varReportColumnOffset:1,'+$hours+','+$cols+'},Concat('+$totItems+',Text(WeekSum),"|"))') '15.5|0|4' 'Total row sums per visible week (0 for empty week)'
Assert-Regression ('With({scrWeeklyHours:{Width:800},varReportColumnOffset:3,'+$hours+','+$cols+'},Concat('+$totItems+',Text(WeekIndex)&"="&Text(WeekSum),"|"))') '2=0|3=4' 'Total row follows the header paging/offset'
foreach($n in @('recReportTotalRow','recReportTotalRowLine','lblReportTotalRowLabel','galReportTotalWeeks','recReportTotalRowColumnLine','lblReportTotalRowValue')){if($new[$n]['Properties']['Visible'] -ne '=varReportValid && !varReportBusy'){throw "$n visibility"}}
if($new['recReportTotalRow']['Properties']['Fill'] -ne '=ColorValue("#D5EDFF")' -or $new['recReportTotalRowLine']['Properties']['Fill'] -ne '=ColorValue("#0303B8")' -or $new['recReportTotalRowLine']['Properties']['Height'] -ne '=2'){throw 'Total row fill/line'}
if($new['lblReportTotalRowLabel']['Properties']['Text'] -ne '="Total"' -or $new['lblReportTotalRowLabel']['Properties']['FontWeight'] -ne '=FontWeight.Bold' -or $new['lblReportTotalRowLabel']['Properties']['Color'] -ne '=ColorValue("#000000")'){throw 'Total label'}
if(!$new['lblReportTotalRowValue']['Properties']['Text'].Contains('Sum(colReportRows,PeriodTotal)')){throw 'Total row period total source'}
Write-Output 'PASS Total row: #D5EDFF with 2px #0303B8 top line, "Total" Bold black, week sums with the header paging, period total = sum of rows, visible only for a valid report.'

function Get-Num($expr,$w,$extra){$fx='With({scrWeeklyHours:{Width:'+$w+'},LayoutParent:{Width:'+$w+'}'+$extra+'},'+$expr.TrimStart('=').Replace('Parent.','LayoutParent.')+')';$v=$regressionEngine.Eval($fx,$null,$regressionOptions);if($v -is [Microsoft.PowerFx.Types.ErrorValue]){throw $v.ToExpression()};[double]$v.Value}
$h=@{};foreach($n in @('lblReportNameHeader','lblReportEmployerHeader','galReportWeekHeaders','lblReportTotalHeader','galReportRows','lblReportWorkerName','lblReportWorkerEmployer','galReportWorkerWeeks','lblReportWorkerTotal','lblReportWeekHeader','lblReportWeekHours')){$h[$n]=$new[$n]['Properties']}
foreach($n in @('lblReportEmployerHeader','galReportWeekHeaders','lblReportTotalHeader')){if($h[$n]['Y'] -ne '=lblReportNameHeader.Y' -or $h[$n]['Height'] -ne '=40'){throw "Header $n not on same row"}}
foreach($n in @('lblReportNameHeader','lblReportEmployerHeader','lblReportWeekHeader','lblReportTotalHeader')){if($h[$n]['VerticalAlign'] -ne '=VerticalAlign.Middle' -or $h[$n]['FontWeight'] -ne $(if($n -eq 'lblReportTotalHeader'){'=FontWeight.Bold'}else{'=FontWeight.Semibold'}) -or $h[$n]['Fill'] -ne '=ColorValue("#0303B8")' -or $h[$n]['Color'] -ne '=Color.White'){throw "Header $n style"}}
if($h['galReportWeekHeaders']['Fill'] -ne '=ColorValue("#0303B8")'){throw 'Week header gallery has no blue background'}
foreach($w in @(320,480,600,666,768,1024,1366,1920)){
 $name=@((Get-Num $h['lblReportNameHeader']['X'] $w ''),(Get-Num $h['lblReportNameHeader']['Width'] $w ''))
 $emp=@((Get-Num $h['lblReportEmployerHeader']['X'] $w ''),(Get-Num $h['lblReportEmployerHeader']['Width'] $w ''))
 $gal=@((Get-Num $h['galReportWeekHeaders']['X'] $w ''),(Get-Num $h['galReportWeekHeaders']['Width'] $w ''))
 $tot=@((Get-Num $h['lblReportTotalHeader']['X'] $w ''),(Get-Num $h['lblReportTotalHeader']['Width'] $w ''))
 $visible=Get-Num 'Max(1,RoundDown((scrWeeklyHours.Width-616)/90,0))' $w ''
 $cell=Get-Num $h['galReportWeekHeaders']['TemplateSize'] $w ''
 $segments=@($name,$emp,$gal,$tot)
 # 16 px scrollbar reserve: header ends at width - 56.
 $contiguous=($name[0] -eq 40) -and ($tot[0]+$tot[1] -eq $w-56) -and ($gal[1] -ge 0);for($i=1;$i -lt 4;$i++){if($segments[$i][0] -ne $segments[$i-1][0]+$segments[$i-1][1]){$contiguous=$false}}
 $rx=Get-Num $h['galReportRows']['X'] $w '';$rw=Get-Num $h['galReportRows']['Width'] $w ''
 $rowCells=@(@(($rx+(Get-Num $h['lblReportWorkerName']['X'] $w '')),(Get-Num $h['lblReportWorkerName']['Width'] $w '')),@(($rx+(Get-Num $h['lblReportWorkerEmployer']['X'] $w '')),(Get-Num $h['lblReportWorkerEmployer']['Width'] $w '')),@(($rx+(Get-Num $h['galReportWorkerWeeks']['X'] $w '')),(Get-Num $h['galReportWorkerWeeks']['Width'] $w '')),@(($rx+(Get-Num $h['lblReportWorkerTotal']['X'] $w '')),(Get-Num $h['lblReportWorkerTotal']['Width'] $w '')))
 $aligned=$true;for($i=0;$i -lt 4;$i++){if($rowCells[$i][0] -ne $segments[$i][0] -or $rowCells[$i][1] -ne $segments[$i][1]){$aligned=$false}}
 if((Get-Num $h['lblReportWeekHours']['Width'] $w '') -ne $cell -or (Get-Num $h['lblReportWeekHeader']['Width'] $w '') -ne $cell -or (Get-Num $h['galReportWorkerWeeks']['TemplateSize'] $w '') -ne $cell){$aligned=$false}
 $scrollbarFree=($rx -eq 40) -and ($rw -eq $w-80) -and ($rx+$rw-16 -eq $tot[0]+$tot[1])
 if($gal[1] -ge 50){
  if(!$contiguous -or !$aligned -or !$scrollbarFree){throw "Header/rows not continuous, aligned or scrollbar-free at $w"}
  foreach($weeks in @(1,3,$visible,$visible+5)){$shown=[Math]::Min($weeks,$visible);if($shown*$cell -gt $gal[1]+0.001){throw "Week cells overflow at $w/$weeks"}}
  Write-Output ("PASS {0}px: blue header 40..{1} (16 px scrollbar reserve), rows and columns aligned; {2} week(s) x {3:0.#}px inside the header." -f $w,($w-56),$visible,$cell)
 }else{
  Write-Output ("LIMIT {0}px: week area {1}px (<50px week cell). Existing table is not a phone layout." -f $w,$gal[1])
 }
}
Write-Output 'Local source/formula/geometry checks only. Actual colours, gallery scrollbar width and browser rendering require Studio/browser feedback.'
