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
 @('Screen1','btnHomeScreen1','nav'),@('scrHours','btnHomeHours','nav'),@('scrWeeklyHours','btnHomeSummary','nav'),
 @('Screen1','btnGotoHours','nav'),@('Screen1','btnGotoHoursSummary','nav'),@('scrHours','btnWeeklyProjectTeam','nav'),@('scrWeeklyHours','btnSummaryProjectTeam','nav'),
 @('scrHours','btnSaveWeek','primary'),@('Screen1','btnAddtoTeam','primary'),@('scrContractors','btnEmpSave','primary'),@('scrContractors','btnEmpHome','nav'),@('scrContractors','btnEmpNew','secondary'),@('scrContractors','btnEmpRefresh','secondary'),@('scrContractors','btnEmpDiscard','secondary'),
 @('Screen1','btnRefreshTeam','secondary'),@('Screen1','btnMigratePreview','secondary'),@('Screen1','btnMigrateConfirm','secondary'),@('scrHours','btnRefreshWeek','secondary'),@('scrHours','btnDiscardWeek','secondary'),@('scrWeeklyHours','btnRefreshReport','secondary'),@('scrWeeklyHours','btnReportPreviousWeeks','secondary'),@('scrWeeklyHours','btnReportNextWeeks','secondary'))
foreach($a in $assign){
 $p=$indexes[$a[0]][$a[1]]['Properties']
 foreach($kv in @($roles[$a[2]].GetEnumerator())+@($disabled.GetEnumerator())){ if($p[$kv.Key] -ne $kv.Value){throw "$($a[0]).$($a[1]).$($kv.Key) = $($p[$kv.Key]) (expected $($kv.Value) for $($a[2]))"} }
}
foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){ if($indexes[$screen][$name]['Control'] -like 'Classic/Button@*' -and $indexes[$screen][$name]['Properties']['Visible'] -ne '=false' -and $name -notlike 'btnTile*' -and !($assign | Where-Object { $_[1] -eq $name })){throw "Visible button without GEA role: $screen.$name"} }}
Write-Output 'PASS buttons: navigation #0303B8/white (hover/pressed #000F41); primary Save/Save team/Contractors Save #1AFF80 with #000F41 text (hover/pressed #18DD6E, never white text); secondary Refresh/arrows white with 1px #0303B8 border and text (hover #D5EDFF); disabled #E6E6E6/#787878.'

foreach($t in @(@('scrHome','lblHomeTitle'),@('Screen1','lblProjectTeamTitle'),@('scrHours','lblWeeklyHoursEntryTitle'),@('scrWeeklyHours','lblWeeklyHoursTitle'),@('scrWeeklyHours','lblReportProjectDetails'),@('scrContractors','lblEmpTitle'))){$p=$indexes[$t[0]][$t[1]]['Properties'];if($p['Fill'] -ne (CV '#0303B8') -or $p['Color'] -ne $W){throw "Title bar $($t[1])"}}
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

# Home screen (26-10-2026): active tiles = navigation role, placeholder tiles = disabled look, headers Navy with a #0303B8 line.
$activeTiles=@('ProjectTeam','WeeklyHours','HoursSummary','Contractors')
$placeholderTiles=@('WeekReport','Workers','Projects','Viewer3D','PIDTracker','ComponentLibrary','SkidConfigurator','StockOverview','Locations','Usage','Requests')
# Every btnTile* on scrHome must be a listed active or placeholder tile (the general role check skips btnTile*).
$tileSet=@($homeIdx.Keys | Where-Object { $_ -like 'btnTile*' } | Sort-Object)
$tileExpected=@(($activeTiles+$placeholderTiles) | ForEach-Object { 'btnTile'+$_ } | Sort-Object)
if(($tileSet -join ',') -ne ($tileExpected -join ',')){throw "scrHome tile set changed: found [$($tileSet -join ', ')], expected [$($tileExpected -join ', ')]"}
$homeIdx=$indexes['scrHome']
foreach($t in $activeTiles){
 $p=$homeIdx['btnTile'+$t]['Properties']
 foreach($kv in @($roles['nav'].GetEnumerator())+@($disabled.GetEnumerator())){ if($p[$kv.Key] -ne $kv.Value){throw "scrHome.btnTile$t.$($kv.Key) = $($p[$kv.Key]) (expected $($kv.Value) for active tile)"} }
 if(!$p.ContainsKey('OnSelect')){throw "Active tile $t without OnSelect"}
 $ic=$homeIdx['icoTile'+$t]['Properties'];if($ic['Color'] -ne $W -or $ic['Fill'] -ne '=Color.Transparent'){throw "Tile icon $t must be white on transparent"}
}
foreach($t in $placeholderTiles){
 $c=$homeIdx['btnTile'+$t];$p=$c['Properties']
 $ph=@{Fill=(CV '#E6E6E6');Color=(CV '#787878');BorderColor=(CV '#E6E6E6');HoverFill=(CV '#E6E6E6');PressedFill=(CV '#E6E6E6');HoverColor=(CV '#787878');PressedColor=(CV '#787878');DisplayMode='=DisplayMode.Disabled'}
 foreach($kv in @($ph.GetEnumerator())+@($disabled.GetEnumerator())){ if($p[$kv.Key] -ne $kv.Value){throw "scrHome.btnTile$t.$($kv.Key) = $($p[$kv.Key]) (expected $($kv.Value) for placeholder)"} }
 if($p.ContainsKey('OnSelect')){throw "Placeholder tile $t must have no OnSelect"}
 $s=$homeIdx['lblTileSub'+$t]['Properties'];if($s['Color'] -ne (CV '#787878') -or $s['Text'] -ne '="Coming soon"'){throw "Placeholder subtext $t"}
}
foreach($h in 'Admin','Cad','Inventory'){
 if($homeIdx['lblHomeHeader'+$h]['Properties']['Color'] -ne (CV '#000F41')){throw "Home header $h colour"}
 if($homeIdx['recHomeLine'+$h]['Properties']['Fill'] -ne (CV '#0303B8') -or $homeIdx['recHomeLine'+$h]['Properties']['Height'] -ne '=2'){throw "Home header line $h"}
}
foreach($pair in @(@('btnTileProjectTeam','=Navigate(Screen1)'),@('btnTileHoursSummary','=Navigate(scrWeeklyHours)'))){if($homeIdx[$pair[0]]['Properties']['OnSelect'] -ne $pair[1]){throw "Home navigation $($pair[0])"}}
# Weekly Hours tile: conditional navigation (loaded -> scrHours, else Screen1 + Notify); exact logic checked in Test-SaveRegression.ps1.
$tileWh=[string]$homeIdx['btnTileWeeklyHours']['Properties']['OnSelect'];if(!$tileWh.StartsWith('=If(') -or !$tileWh.Contains('Navigate(scrHours)') -or !$tileWh.Contains('Navigate(Screen1)')){throw 'Home navigation btnTileWeeklyHours'}
Write-Output 'PASS Home tiles: 4 active (Fill/border #0303B8, white text/icon, hover/pressed #000F41, OnSelect present), 11 placeholders (#E6E6E6 / #787878, DisplayMode.Disabled, no OnSelect, subtext "Coming soon"); headers #000F41 with 2 px #0303B8 line; Home footer buttons = navigation role.'
