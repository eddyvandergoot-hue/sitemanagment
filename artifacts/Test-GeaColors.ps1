# GEA colours (22-10-2026): only GEA tokens as colour literals; roles for title bars, table headers, navigation, primary/secondary actions,
# disabled buttons, inputs, week totals and errors.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-SaveRegression.ps1')
function CV($hex){ '=ColorValue("'+$hex+'")' }
$W='=Color.White'
$tokens=@('000000','0303B8','000F41','1AFF80','18DD6E','D5EDFF','F0F0F0','DCDCDC','E6E6E6','787878','DB1E28','FFFFFF')
$old=@('#7040A0','#593080','#194296','#123273','#E8EDF5','#EEE7F5','#193F83','#EAF1FC','#F4F6FA','#E5E7EB','#6B7280','#596579','#E1E6EF','RGBA(','Color.Red')
$src=(Get-ChildItem (Join-Path $projectRoot 'Src') -Filter *.pa.yaml | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n"
foreach($o in $old){ $c=([regex]::Matches($src,[regex]::Escape($o),'IgnoreCase')).Count; if($c){throw "Old colour literal $o still present ($c x)"} }
$bad=@([regex]::Matches($src,'ColorValue\("#([0-9A-Fa-f]{6})"\)') | Where-Object { $_.Groups[1].Value.ToUpper() -notin $tokens } | ForEach-Object { $_.Value })
$named=@([regex]::Matches($src,'\bColor\.(\w+)') | Where-Object { $_.Groups[1].Value -notin @('White','Black','Transparent') } | ForEach-Object { $_.Value })
if($bad.Count -or $named.Count){throw "Non-GEA colours: $(($bad+$named) -join ',')"}
Write-Output "PASS colour literals: 0x each of $($old -join ' '); only GEA tokens #$($tokens -join ' #') and Color.White/Black/Transparent."

$disabled=@{DisabledFill=(CV '#E6E6E6');DisabledColor=(CV '#787878');DisabledBorderColor=(CV '#E6E6E6')}
$roles=@{
 nav=@{Fill=(CV '#0303B8');Color=$W;BorderColor=(CV '#0303B8');HoverFill=(CV '#000F41');PressedFill=(CV '#000F41');HoverColor=$W;PressedColor=$W;HoverBorderColor=(CV '#000F41');PressedBorderColor=(CV '#000F41')}
 primary=@{Fill=(CV '#1AFF80');Color=(CV '#000F41');BorderColor=(CV '#1AFF80');HoverFill=(CV '#18DD6E');PressedFill=(CV '#18DD6E');HoverColor=(CV '#000F41');PressedColor=(CV '#000F41');HoverBorderColor=(CV '#18DD6E');PressedBorderColor=(CV '#18DD6E')}
 secondary=@{Fill=$W;Color=(CV '#0303B8');BorderColor=(CV '#0303B8');BorderThickness='=1';HoverFill=(CV '#D5EDFF');PressedFill=(CV '#D5EDFF');HoverColor=(CV '#0303B8');PressedColor=(CV '#0303B8');HoverBorderColor=(CV '#0303B8');PressedBorderColor=(CV '#0303B8')}
}
$assign=@(
 @('Screen1','btnGotoHours','nav'),@('Screen1','btnGotoHoursSummary','nav'),@('scrHours','btnWeeklyProjectTeam','nav'),@('scrWeeklyHours','btnSummaryProjectTeam','nav'),
 @('scrHours','btnSaveWeek','primary'),@('Screen1','btnAddtoTeam','primary'),
 @('Screen1','btnRefreshTeam','secondary'),@('scrHours','btnRefreshWeek','secondary'),@('scrWeeklyHours','btnRefreshReport','secondary'),@('scrWeeklyHours','btnReportPreviousWeeks','secondary'),@('scrWeeklyHours','btnReportNextWeeks','secondary'))
foreach($a in $assign){
 $p=$indexes[$a[0]][$a[1]]['Properties']
 foreach($kv in @($roles[$a[2]].GetEnumerator())+@($disabled.GetEnumerator())){ if($p[$kv.Key] -ne $kv.Value){throw "$($a[0]).$($a[1]).$($kv.Key) = $($p[$kv.Key]) (expected $($kv.Value) for $($a[2]))"} }
}
foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){ if($indexes[$screen][$name]['Control'] -like 'Classic/Button@*' -and $indexes[$screen][$name]['Properties']['Visible'] -ne '=false' -and !($assign | Where-Object { $_[1] -eq $name })){throw "Visible button without GEA role: $screen.$name"} }}
Write-Output 'PASS buttons: navigation #0303B8/white (hover/pressed #000F41); primary Save/Save team #1AFF80 with #000F41 text (hover/pressed #18DD6E, never white text); secondary Refresh/arrows white with 1px #0303B8 border and text (hover #D5EDFF); disabled #E6E6E6/#787878.'

foreach($t in @(@('Screen1','lblProjectTeamTitle'),@('scrHours','lblWeeklyHoursEntryTitle'),@('scrWeeklyHours','lblWeeklyHoursTitle'),@('scrWeeklyHours','lblReportProjectDetails'))){$p=$indexes[$t[0]][$t[1]]['Properties'];if($p['Fill'] -ne (CV '#0303B8') -or $p['Color'] -ne $W){throw "Title bar $($t[1])"}}
foreach($t in @(@('scrHours',@('lblHeaderWorker','lblHeaderMon','lblHeaderTue','lblHeaderWed','lblHeaderThu','lblHeaderFri','lblHeaderSat','lblHeaderSun','lblHeaderTotal')),@('scrWeeklyHours',@('lblReportNameHeader','lblReportEmployerHeader','lblReportWeekHeader','lblReportTotalHeader')))){foreach($h in $t[1]){$p=$indexes[$t[0]][$h]['Properties'];if($p['Fill'] -ne (CV '#0303B8') -or $p['Color'] -ne $W){throw "Table header $h"}}}
if($indexes.scrHours['recHoursHeaderBar']['Properties']['Fill'] -ne (CV '#0303B8') -or $indexes.scrWeeklyHours['galReportWeekHeaders']['Properties']['Fill'] -ne (CV '#0303B8')){throw 'Header bar background'}
Write-Output 'PASS title bars and table headers (Weekly Hours and Hours Summary): #0303B8 with white text; continuous header bar behind the Weekly Hours columns.'

foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){
 $c=$indexes[$screen][$name];$p=$c['Properties']
 if($c['Control'] -like 'Classic/DropDown@*' -or $c['Control'] -like 'Classic/TextInput@*'){
  foreach($kv in @(@('Fill','#F0F0F0'),@('BorderColor','#DCDCDC'),@('HoverBorderColor','#0303B8'),@('FocusedBorderColor','#0303B8'))){ if($p[$kv[0]] -ne (CV $kv[1])){throw "Input $screen.$name.$($kv[0])"} }
  if($p['BorderThickness'] -ne '=1'){throw "Input $screen.$name border thickness"}
  if($c['Control'] -like 'Classic/DropDown@*'){ foreach($kv in @(@('HoverFill','#D5EDFF'),@('HoverColor','#000F41'),@('SelectionFill','#0303B8'),@('PressedFill','#D5EDFF'),@('PressedColor','#000F41'),@('Color','#000000'),@('ChevronBackground','#F0F0F0'),@('ChevronFill','#0303B8'),@('ChevronHoverBackground','#D5EDFF'))){ if($p[$kv[0]] -ne (CV $kv[1])){throw "Dropdown state $screen.$name.$($kv[0])"} }; if($p['SelectionColor'] -ne $W){throw "Dropdown selection colour $screen.$name"} }
 }
 if($c['Control'] -like 'ModernDatePicker@*' -and ($p['Fill'] -ne (CV '#F0F0F0') -or $p['BorderColor'] -ne (CV '#DCDCDC') -or $p['BorderThickness'] -ne '=1')){throw "Date picker $screen.$name"}
}}
$expectedDropdowns=@('Screen1.ddProject','Screen1.ddTeam','scrWeeklyHours.ddReportProject','scrWeeklyHours.ddReportContractor')
$foundDropdowns=@(foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){ if($indexes[$screen][$name]['Control'] -like 'Classic/DropDown@*'){"$screen.$name"} }})
if((($foundDropdowns|Sort-Object) -join ',') -ne (($expectedDropdowns|Sort-Object) -join ',')){throw "Dropdown set changed: found [$($foundDropdowns -join ', ')], expected [$($expectedDropdowns -join ', ')]"}
Write-Output 'PASS dropdown set: exactly ddProject, ddTeam, ddReportProject, ddReportContractor (each pinned above).'
$p=$indexes.scrHours['lblWeekTotal']['Properties'];if($p['Fill'] -ne (CV '#D5EDFF') -or $p['Color'] -ne (CV '#000F41')){throw 'Week total cell'}
if($indexes['Screen1']['lblSelectionLoadStatus']['Properties']['Color'] -ne '=If(!IsEmpty(colSelectionLoadErrors),ColorValue("#DB1E28"),ColorValue("#000000"))'){throw 'Error colour lblSelectionLoadStatus'}
if($indexes['scrHours']['lblWeekLoadStatus']['Properties']['Color'] -ne '=If(!IsEmpty(colWeekLoadErrors) || (Coalesce(varWeekLoadState,"NotLoaded")<>"Loading" && !Coalesce(varWeekSaving,false) && !IsEmpty(colHoursErrors)),ColorValue("#DB1E28"),ColorValue("#000000"))'){throw 'Error colour lblWeekLoadStatus'}
Write-Output 'PASS inputs/dropdowns/date pickers #F0F0F0 with 1px #DCDCDC border, hover/focus border #0303B8, selection #0303B8/white; dropdown row hover/pressed #D5EDFF/#000F41, chevron states; week total cells #D5EDFF/#000F41; errors #DB1E28, body black.'
