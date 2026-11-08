# GEA colours (22-10-2026): only GEA tokens as colour literals; roles for title bars, table headers, navigation, primary/secondary actions,
# disabled buttons, inputs, week totals and errors.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-SaveRegression.ps1')
function CV($hex){ '=ColorValue("'+$hex+'")' }
$W='=Color.White'
$tokens=@('000000','0303B8','000F41','1AFF80','18DD6E','D5EDFF','F0F0F0','DCDCDC','E6E6E6','787878','DB1E28','FFFFFF')
$old=@('#7040A0','#593080','#194296','#123273','#E8EDF5','#EEE7F5','#193F83','#EAF1FC','#F4F6FA','#E5E7EB','#6B7280','#596579','#E1E6EF','RGBA(','Color.Red')
$src=(Get-ChildItem (Join-Path $projectRoot 'Src') -Filter *.pa.yaml -Recurse | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n"
foreach($o in $old){ $c=([regex]::Matches($src,[regex]::Escape($o),'IgnoreCase')).Count; if($c){throw "Old colour literal $o still present ($c x)"} }
# 30-10-2026 (admin pattern spec): extra literals allowed ONLY on the admin-pattern screens (scrContractors; later scrProjects/scrWorkers).
$adminScreens=@('scrContractors','scrProjects','scrWorkers')
$adminTokens=@('F5F6F8','9B9B9B','5A5A5A','EDEDED','6B6B6B','B4B4B4','F29400')
$bad=@()
foreach($file in Get-ChildItem (Join-Path $projectRoot 'Src') -Filter *.pa.yaml -Recurse){
 $baseName=($file.Name -replace '\.pa\.yaml$','')
 $componentExtra=@{cmpTile=@('6B6B6B','5A5A5A');cmpMessageBar=@('F29400');cmpField=@('9B9B9B','5A5A5A');cmpListCard=@('9B9B9B','5A5A5A','EDEDED','6B6B6B','B4B4B4')}
 $allowedHex=if($baseName -in $adminScreens){$tokens+$adminTokens}elseif($componentExtra.ContainsKey($baseName)){$tokens+$componentExtra[$baseName]}else{$tokens}
 if($file.DirectoryName -like '*\Src\Components'){
  # Components: every #RRGGBB literal (ColorValue and inline CSS in HtmlText) must be a palette token; admin-pattern greys only in cmpField/cmpListCard, amber only in the message bar.
  $bad+=@([regex]::Matches([IO.File]::ReadAllText($file.FullName),'#([0-9A-Fa-f]{6})') | Where-Object { $_.Groups[1].Value.ToUpper() -notin $allowedHex } | ForEach-Object { "$($file.Name): $($_.Value)" })
 }
 $bad+=@([regex]::Matches([IO.File]::ReadAllText($file.FullName),'ColorValue\("#([0-9A-Fa-f]{6})"\)') | Where-Object { $_.Groups[1].Value.ToUpper() -notin $allowedHex } | ForEach-Object { "$($file.Name): $($_.Value)" })
}
$named=@([regex]::Matches($src,'\bColor\.(\w+)') | Where-Object { $_.Groups[1].Value -notin @('White','Black','Transparent') } | ForEach-Object { $_.Value })
if($bad.Count -or $named.Count){throw "Non-GEA colours: $(($bad+$named) -join ',')"}
Write-Output "PASS colour literals: 0x each of $($old -join ' '); only GEA tokens #$($tokens -join ' #') and Color.White/Black/Transparent; admin-pattern extras #$($adminTokens -join ' #') only on $($adminScreens -join ', ')."

$disabled=@{DisabledFill=(CV '#E6E6E6');DisabledColor=(CV '#787878');DisabledBorderColor=(CV '#E6E6E6')}
$roles=@{
 nav=@{Fill=(CV '#0303B8');Color=$W;BorderColor=(CV '#0303B8');HoverFill=(CV '#000F41');PressedFill=(CV '#000F41');HoverColor=$W;PressedColor=$W;HoverBorderColor=(CV '#000F41');PressedBorderColor=(CV '#000F41')}
 primary=@{Fill=(CV '#1AFF80');Color=(CV '#000F41');BorderColor=(CV '#1AFF80');HoverFill=(CV '#18DD6E');PressedFill=(CV '#18DD6E');HoverColor=(CV '#000F41');PressedColor=(CV '#000F41');HoverBorderColor=(CV '#18DD6E');PressedBorderColor=(CV '#18DD6E')}
 secondary=@{Fill=$W;Color=(CV '#0303B8');BorderColor=(CV '#0303B8');BorderThickness='=1';HoverFill=(CV '#D5EDFF');PressedFill=(CV '#D5EDFF');HoverColor=(CV '#0303B8');PressedColor=(CV '#0303B8');HoverBorderColor=(CV '#0303B8');PressedBorderColor=(CV '#0303B8')}
}
$assign=@(
 @('Screen1','btnHomeScreen1','nav'),@('scrHours','btnHomeHours','nav'),@('scrWeeklyHours','btnHomeSummary','nav'),
 @('Screen1','btnGotoHours','nav'),@('Screen1','btnGotoHoursSummary','nav'),@('scrHours','btnWeeklyProjectTeam','nav'),@('scrWeeklyHours','btnSummaryProjectTeam','nav'),
 @('scrHours','btnSaveWeek','primary'),@('Screen1','btnAddtoTeam','primary'),
 
 @('Screen1','btnRefreshTeam','secondary'),@('Screen1','btnMigratePreview','secondary'),@('Screen1','btnMigrateConfirm','secondary'),@('scrHours','btnRefreshWeek','secondary'),@('scrHours','btnDiscardWeek','secondary'),@('scrWeeklyHours','btnRefreshReport','secondary'),@('scrWeeklyHours','btnReportPreviousWeeks','secondary'),@('scrWeeklyHours','btnReportNextWeeks','secondary'))
foreach($a in $assign){
 $p=$indexes[$a[0]][$a[1]]['Properties']
 foreach($kv in @($roles[$a[2]].GetEnumerator())+@($disabled.GetEnumerator())){ if($p[$kv.Key] -ne $kv.Value){throw "$($a[0]).$($a[1]).$($kv.Key) = $($p[$kv.Key]) (expected $($kv.Value) for $($a[2]))"} }
}
# 30-10-2026 (admin pattern spec): emulated switches on admin screens = Classic/Button track (#0303B8 on / #B4B4B4 off) + white knob button.
$switches=@(@('scrContractors','btnEmpActiveSwitch','btnEmpActiveKnob','Coalesce(varEmpActiveDraft,true)'),@('scrWorkers','btnWrkActiveSwitch','btnWrkActiveKnob','Coalesce(varWrkActiveDraft,true)'),@('scrWorkers','btnWrkSaveAnywaySwitch','btnWrkSaveAnywayKnob','Coalesce(varWrkDupConfirmed,false)'))
foreach($s in $switches){
 $tp=$indexes[$s[0]][$s[1]]['Properties'];$kp=$indexes[$s[0]][$s[2]]['Properties']
 $track='=If('+$s[3]+',ColorValue("#0303B8"),ColorValue("#B4B4B4"))'
 foreach($k in 'Fill','HoverFill','PressedFill','DisabledFill'){if($tp[$k] -ne $track){throw "Switch track $($s[1]).$k = $($tp[$k]) (expected $track)"}}
 foreach($k in 'Fill','HoverFill','PressedFill','DisabledFill'){if($kp[$k] -ne $W){throw "Switch knob $($s[2]).$k must be white"}}
}
$switchNames=@($switches | ForEach-Object { $_[1]; $_[2] })
foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){ if($indexes[$screen][$name]['Control'] -like 'Classic/Button@*' -and $indexes[$screen][$name]['Properties']['Visible'] -ne '=false' -and $name -notlike 'btnTile*' -and !($screen -in $adminScreens -and ($name -in $switchNames -or $name -in @('btnEmpRowInactive','btnEmpFormChip','btnPrjRowStatus','btnPrjFormChip','btnWrkFormChip'))) -and !($assign | Where-Object { $_[1] -eq $name })){throw "Visible button without GEA role: $screen.$name"} }}
Write-Output 'PASS buttons: navigation #0303B8/white (hover/pressed #000F41); primary Save/Save team/Contractors Save #1AFF80 with #000F41 text (hover/pressed #18DD6E, never white text); secondary Refresh/arrows white with 1px #0303B8 border and text (hover #D5EDFF); disabled #E6E6E6/#787878.'

foreach($t in @(@('Screen1','lblProjectTeamTitle'),@('scrHours','lblWeeklyHoursEntryTitle'),@('scrWeeklyHours','lblWeeklyHoursTitle'),@('scrWeeklyHours','lblReportProjectDetails'))){$p=$indexes[$t[0]][$t[1]]['Properties'];if($p['Fill'] -ne (CV '#0303B8') -or $p['Color'] -ne $W){throw "Title bar $($t[1])"}}
foreach($t in @(@('scrHours',@('lblHeaderWorker','lblHeaderMon','lblHeaderTue','lblHeaderWed','lblHeaderThu','lblHeaderFri','lblHeaderSat','lblHeaderSun','lblHeaderTotal')),@('scrWeeklyHours',@('lblReportNameHeader','lblReportEmployerHeader','lblReportWeekHeader','lblReportTotalHeader')))){foreach($h in $t[1]){$p=$indexes[$t[0]][$h]['Properties'];if($p['Fill'] -ne (CV '#0303B8') -or $p['Color'] -ne $W){throw "Table header $h"}}}
if($indexes.scrHours['recHoursHeaderBar']['Properties']['Fill'] -ne (CV '#0303B8') -or $indexes.scrWeeklyHours['galReportWeekHeaders']['Properties']['Fill'] -ne (CV '#0303B8')){throw 'Header bar background'}
Write-Output 'PASS title bars and table headers (Weekly Hours and Hours Summary): #0303B8 with white text; continuous header bar behind the Weekly Hours columns.'

# 30-10-2026 (Projects build): same admin-pattern field rules on scrProjects (error field from colPrjSaveErrors.Field).
$prjErrField=@{txtPrjName='Name';txtPrjNumber='Number';txtPrjReference='Reference';txtPrjCustomer='Customer';txtPrjStreet='Street';txtPrjHouseNumber='HouseNumber';txtPrjPostalCode='PostalCode';txtPrjCity='City';txtPrjUrl='Url'}
$prjDdField=@{ddPrjStatus='Status';ddPrjCountry='Country'}
$empErrField=@{}  # txtEmp* inputs were replaced by cmpField components; no such control exists
foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){
 $c=$indexes[$screen][$name];$p=$c['Properties']
 if($c['Control'] -like 'Classic/DropDown@*' -or $c['Control'] -like 'Classic/TextInput@*'){
  # 29-10-2026 (Eddy): Contractors form inputs show an invalid field only by a red #DB1E28 border (Border/Hover/Focused) bound to colEmpSaveErrors.Field.
  if($screen -eq 'scrProjects' -and $name -in @('txtPrjLeader','txtPrjSiteManager')){ foreach($kv in @(@('Fill','#F0F0F0'),@('DisabledFill','#F0F0F0'),@('Color','#000000'),@('DisabledColor','#000000'))){ if($p[$kv[0]] -ne (CV $kv[1])){throw "Read-only person field $name.$($kv[0])"} }; foreach($k in 'BorderColor','DisabledBorderColor'){ if($p[$k] -ne '=Color.Transparent'){throw "Read-only person field $name.$k (no border)"} }; if($p['DisplayMode'] -ne '=DisplayMode.Disabled' -or $p['BorderThickness'] -ne '=0'){throw "$name must stay Disabled without border"}; continue }
  if($screen -eq 'scrProjects' -and $prjErrField.ContainsKey($name)){ $er='CountIf(colPrjSaveErrors,Field="'+$prjErrField[$name]+'")>0'; foreach($kv in @(@('BorderColor','#9B9B9B'),@('HoverBorderColor','#5A5A5A'),@('FocusedBorderColor','#0303B8'),@('PressedBorderColor','#0303B8'))){ $exp='=If('+$er+',ColorValue("#DB1E28"),'+(CV $kv[1]).TrimStart('=')+')'; if($p[$kv[0]] -ne $exp){throw "Project field $name.$($kv[0])"} }; foreach($k in 'Fill','HoverFill','PressedFill'){ if($p[$k] -ne '=Color.White'){throw "Project field $name.$k must be white"} }; if($p['BorderThickness'] -ne ('=If('+$er+',2,1)') -or $p['FocusedBorderThickness'] -ne '=2' -or $p['RadiusTopLeft'] -ne '=4' -or $p['Height'] -ne '=36'){throw "Project field $name thickness/radius/height"}; continue }
  if($screen -eq 'scrProjects' -and $prjDdField.ContainsKey($name)){ $er='CountIf(colPrjSaveErrors,Field="'+$prjDdField[$name]+'")>0'; if($p['Fill'] -ne (CV '#F0F0F0')){throw "Dropdown $name Fill"}; foreach($kv in @(@('BorderColor','#DCDCDC'),@('HoverBorderColor','#0303B8'),@('FocusedBorderColor','#0303B8'),@('PressedBorderColor','#0303B8'))){ $exp='=If('+$er+',ColorValue("#DB1E28"),'+(CV $kv[1]).TrimStart('=')+')'; if($p[$kv[0]] -ne $exp){throw "Project dropdown $name.$($kv[0])"} }; if($p['BorderThickness'] -ne ('=If('+$er+',2,1)')){throw "Project dropdown $name border thickness"}; foreach($kv in @(@('HoverFill','#D5EDFF'),@('HoverColor','#000F41'),@('SelectionFill','#0303B8'),@('PressedFill','#D5EDFF'),@('PressedColor','#000F41'),@('Color','#000000'),@('ChevronBackground','#F0F0F0'),@('ChevronFill','#0303B8'),@('ChevronHoverBackground','#D5EDFF'))){ if($p[$kv[0]] -ne (CV $kv[1])){throw "Dropdown state $screen.$name.$($kv[0])"} }; if($p['SelectionColor'] -ne $W){throw "Dropdown selection colour $screen.$name"}; if($p['HoverFill'] -eq $p['Fill']){throw "Dropdown $name HoverFill equals Fill"}; continue }
  if($screen -eq 'scrContractors' -and $name -eq 'txtEmpCode'){ foreach($kv in @(@('Fill','#F0F0F0'),@('DisabledFill','#F0F0F0'),@('Color','#000000'),@('DisabledColor','#000000'))){ if($p[$kv[0]] -ne (CV $kv[1])){throw "Read-only code field $($kv[0])"} }; foreach($k in 'BorderColor','DisabledBorderColor'){ if($p[$k] -ne '=Color.Transparent'){throw "Read-only code field $k (admin pattern A2: no border)"} }; if($p['DisplayMode'] -ne '=DisplayMode.Disabled'){throw 'txtEmpCode must stay Disabled'}; if($p['BorderThickness'] -ne '=0'){throw 'txtEmpCode border (A2: none)'}; continue }
  # 30-10-2026 (admin pattern A2): editable contractor form fields = white, 1px #9B9B9B (hover #5A5A5A, focus/pressed #0303B8, focus 2px), invalid = red #DB1E28 2px.
  if($screen -eq 'scrContractors' -and $empErrField.ContainsKey($name)){ $ef=$empErrField[$name]; $er='CountIf(colEmpSaveErrors,Field="'+$ef+'")>0'; foreach($kv in @(@('BorderColor','#9B9B9B'),@('HoverBorderColor','#5A5A5A'),@('FocusedBorderColor','#0303B8'),@('PressedBorderColor','#0303B8'))){ $exp='=If('+$er+',ColorValue("#DB1E28"),'+(CV $kv[1]).TrimStart('=')+')'; if($p[$kv[0]] -ne $exp){throw "Contractor field $name.$($kv[0])"} }; foreach($k in 'Fill','HoverFill','PressedFill'){ if($p[$k] -ne '=Color.White'){throw "Contractor field $name.$k must be white"} }; if($p['BorderThickness'] -ne ('=If('+$er+',2,1)') -or $p['FocusedBorderThickness'] -ne '=2' -or $p['RadiusTopLeft'] -ne '=4' -or $p['Height'] -ne '=36'){throw "Contractor field $name thickness/radius/height"}; continue }
  # 30-10-2026 (admin pattern): list-card search field = white, 1px #9B9B9B (hover #5A5A5A, focus #0303B8), radius 4, h36.
  if($screen -in $adminScreens -and $name -in @('txtEmpSearch','txtPrjSearch')){ foreach($kv in @(@('Fill','=Color.White'),@('HoverFill','=Color.White'),@('BorderColor',(CV '#9B9B9B')),@('HoverBorderColor',(CV '#5A5A5A')),@('FocusedBorderColor',(CV '#0303B8')),@('BorderThickness','=1'),@('RadiusTopLeft','=4'),@('Height','=36'))){ if($p[$kv[0]] -ne $kv[1]){throw "Search field $($kv[0])"} }; continue }
  foreach($kv in @(@('Fill','#F0F0F0'),@('BorderColor','#DCDCDC'),@('HoverBorderColor','#0303B8'),@('FocusedBorderColor','#0303B8'))){ $exp=CV $kv[1]; if($screen -eq 'scrContractors' -and $empErrField.ContainsKey($name) -and $kv[0] -ne 'Fill'){ $exp='=If(CountIf(colEmpSaveErrors,Field="'+$empErrField[$name]+'")>0,ColorValue("#DB1E28"),'+$exp.TrimStart('=')+')' }; if($p[$kv[0]] -ne $exp){throw "Input $screen.$name.$($kv[0])"} }
  if($p['BorderThickness'] -ne '=1'){throw "Input $screen.$name border thickness"}
  if($c['Control'] -like 'Classic/DropDown@*'){ foreach($kv in @(@('HoverFill','#D5EDFF'),@('HoverColor','#000F41'),@('SelectionFill','#0303B8'),@('PressedFill','#D5EDFF'),@('PressedColor','#000F41'),@('Color','#000000'),@('ChevronBackground','#F0F0F0'),@('ChevronFill','#0303B8'),@('ChevronHoverBackground','#D5EDFF'))){ if($p[$kv[0]] -ne (CV $kv[1])){throw "Dropdown state $screen.$name.$($kv[0])"} }; if($p['SelectionColor'] -ne $W){throw "Dropdown selection colour $screen.$name"} }
 }
 if($c['Control'] -like 'ModernDatePicker@*' -and ($p['Fill'] -ne (CV '#F0F0F0') -or $p['BorderColor'] -ne (CV '#DCDCDC') -or $p['BorderThickness'] -ne '=1')){throw "Date picker $screen.$name"}
}}
$expectedDropdowns=@('Screen1.ddProject','Screen1.ddTeam','scrWeeklyHours.ddReportProject','scrWeeklyHours.ddReportContractor')
$foundDropdowns=@(foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){ if($indexes[$screen][$name]['Control'] -like 'Classic/DropDown@*'){"$screen.$name"} }})
if((($foundDropdowns|Sort-Object) -join ',') -ne (($expectedDropdowns|Sort-Object) -join ',')){throw "Dropdown set changed: found [$($foundDropdowns -join ', ')], expected [$($expectedDropdowns -join ', ')]"}
Write-Output 'PASS dropdown set: exactly ddProject, ddTeam, ddReportProject, ddReportContractor (the Projects dropdowns are cmpField instances now).'
$p=$indexes.scrHours['lblWeekTotal']['Properties'];if($p['Fill'] -ne (CV '#D5EDFF') -or $p['Color'] -ne (CV '#000F41')){throw 'Week total cell'}
if($indexes['Screen1']['lblSelectionLoadStatus']['Properties']['Color'] -ne '=If(!IsEmpty(colSelectionLoadErrors),ColorValue("#DB1E28"),ColorValue("#000000"))'){throw 'Error colour lblSelectionLoadStatus'}
if($indexes['scrHours']['lblWeekLoadStatus']['Properties']['Color'] -ne '=If(!IsEmpty(colWeekLoadErrors) || (Coalesce(varWeekLoadState,"NotLoaded")<>"Loading" && !Coalesce(varWeekSaving,false) && !IsEmpty(colHoursErrors)),ColorValue("#DB1E28"),ColorValue("#000000"))'){throw 'Error colour lblWeekLoadStatus'}
# 30-10-2026 (admin pattern A2): form header chip = green #1AFF80/#000F41 (Active) or grey #E6E6E6/#000000 (Inactive); red star label; blue section headers.
$chip=$indexes.scrContractors['btnEmpFormChip']['Properties']; $cf='=If(Coalesce(varEmpMode,"")="New",ColorValue("#D5EDFF"),Coalesce(varEmpEdit.Active,true),ColorValue("#1AFF80"),ColorValue("#E6E6E6"))'; $cc='=If(Coalesce(varEmpMode,"")="New",ColorValue("#0303B8"),Coalesce(varEmpEdit.Active,true),ColorValue("#000F41"),ColorValue("#000000"))'; foreach($k in 'Fill','HoverFill','PressedFill','DisabledFill'){ if($chip[$k] -ne $cf){throw "Chip $k"} }; foreach($k in 'Color','HoverColor','PressedColor','DisabledColor'){ if($chip[$k] -ne $cc){throw "Chip $k"} }; if($chip['DisplayMode'] -ne '=DisplayMode.Disabled'){throw 'Chip must be static'}
# 30-10-2026 (step 3a): Contractors title bar, footer, list card and form fields are component instances; colour roles are pinned on the component definitions.
$cmpDefs=@{}
foreach($cf in 'cmpTitleBar','cmpFooter','cmpListCard','cmpField','cmpMessageBar'){ $cmpDefs[$cf]=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot "Src/Components/$cf.pa.yaml")))['ComponentDefinitions'][$cf] }
function Get-CmpIdx($def){ $r=@{}; Index-RegressionControls $def['Children'] $r; return $r }
$tb=Get-CmpIdx $cmpDefs.cmpTitleBar; if($tb['lblCmpTitleText']['Properties']['Fill'] -ne (CV '#0303B8') -or $tb['lblCmpTitleText']['Properties']['Color'] -ne $W -or $cmpDefs.cmpTitleBar['Properties']['Fill'] -ne (CV '#0303B8')){throw 'cmpTitleBar fill/colour'}
$ft=Get-CmpIdx $cmpDefs.cmpFooter
foreach($a in @(@('btnCmpSave','primary'),@('btnCmpHome','nav'),@('btnCmpNew','secondary'),@('btnCmpRefresh','secondary'),@('btnCmpDiscard','secondary'))){
 $p=$ft[$a[0]]['Properties']
 foreach($kv in @($roles[$a[1]].GetEnumerator())+@($disabled.GetEnumerator())){ if($p[$kv.Key] -ne $kv.Value){throw "cmpFooter.$($a[0]).$($kv.Key) = $($p[$kv.Key]) (expected $($kv.Value) for $($a[1]))"} }
}
$lc=Get-CmpIdx $cmpDefs.cmpListCard; $tp=$lc['btnCmpListSwitch']['Properties']; $kp=$lc['btnCmpListKnob']['Properties']; $track='=If(cmpListCard.ShowInactive,ColorValue("#0303B8"),ColorValue("#B4B4B4"))'
foreach($k in 'Fill','HoverFill','PressedFill','DisabledFill'){ if($tp[$k] -ne $track){throw "cmpListCard switch track $k"}; if($kp[$k] -ne $W){throw "cmpListCard knob $k must be white"} }
$sp=$lc['txtSearch']['Properties']; foreach($kv in @(@('Fill','=Color.White'),@('HoverFill','=Color.White'),@('BorderColor',(CV '#9B9B9B')),@('HoverBorderColor',(CV '#5A5A5A')),@('FocusedBorderColor',(CV '#0303B8')),@('BorderThickness','=1'),@('RadiusTopLeft','=4'),@('Height','=36'))){ if($sp[$kv[0]] -ne $kv[1]){throw "cmpListCard search $($kv[0])"} }
if($lc['recCmpRowFill']['Properties']['Fill'] -notmatch '#D5EDFF' -or $lc['recCmpRowBar']['Properties']['Fill'] -ne (CV '#0303B8')){throw 'cmpListCard selected row colours'}
$fi=Get-CmpIdx $cmpDefs.cmpField; $fp=$fi['txtFieldValue']['Properties']
foreach($kv in @(@('BorderColor','#9B9B9B'),@('HoverBorderColor','#5A5A5A'),@('FocusedBorderColor','#0303B8'),@('PressedBorderColor','#0303B8'))){ if($fp[$kv[0]] -notmatch ('^=If\(cmpField\.Invalid,ColorValue\("#DB1E28"\)') -or $fp[$kv[0]] -notmatch [regex]::Escape($kv[1])){throw "cmpField input $($kv[0]) (Invalid -> #DB1E28, else $($kv[1]))"} }
if($fp['BorderThickness'] -notmatch '^=If\(cmpField\.Invalid,2,' -or $fp['FocusedBorderThickness'] -ne '=2' -or $fp['RadiusTopLeft'] -ne '=4' -or $fp['Height'] -ne '=36'){throw 'cmpField input thickness/radius/height'}
foreach($k in 'Fill','HoverFill','PressedFill'){ if($fp[$k] -ne '=Color.White'){throw "cmpField input $k must be white"} }
if($fp['DisabledFill'] -notmatch '#F0F0F0'){throw 'cmpField read-only fill #F0F0F0'}
if($fi['htmlFieldLabel']['Properties']['HtmlText'] -notmatch 'color:#DB1E28'){throw 'cmpField required star must be #DB1E28'}
$mb=Get-CmpIdx $cmpDefs.cmpMessageBar; $mf=[string]$mb['recCmpMsgFill']['Properties']['Fill']; foreach($t in '#DB1E28','#F29400','#1AFF80'){ if($mf -notmatch [regex]::Escape($t)){throw "cmpMessageBar fill $t"} }
Write-Output 'PASS components used by Contractors: title bar #0303B8/white; footer Save primary, Home navigation, New/Refresh/Discard secondary (disabled #E6E6E6/#787878); list card switch #0303B8/#B4B4B4 with white knob, search field #9B9B9B/#5A5A5A/#0303B8, selected row #D5EDFF with #0303B8 bar; field input white/#9B9B9B, invalid #DB1E28 2px, read-only #F0F0F0, red star; message bar #DB1E28/#F29400/#1AFF80.'
foreach($n in 'lblEmpSecGeneral','lblEmpSecAddress','lblEmpSecContact'){ if($indexes.scrContractors[$n]['Properties']['Color'] -ne (CV '#0303B8')){throw "Section header $n must be #0303B8"} }; if($indexes.scrContractors['lblEmpFormTitle']['Properties']['Color'] -ne (CV '#000F41')){throw 'Form title #000F41'}
# 30-10-2026 (Projects build): status chip from the Status draft (Active green #1AFF80/#000F41, On hold/Closed grey #E6E6E6/#000000), list-row status chip grey, red stars, blue section headers.
$pc=$indexes.scrProjects['btnPrjFormChip']['Properties']; $pcf='=If(Coalesce(varPrjMode,"")="New",ColorValue("#D5EDFF"),varPrjEdit.Status="Active",ColorValue("#1AFF80"),ColorValue("#E6E6E6"))'; $pcc='=If(Coalesce(varPrjMode,"")="New",ColorValue("#0303B8"),varPrjEdit.Status="Active",ColorValue("#000F41"),ColorValue("#000000"))'; foreach($k in 'Fill','HoverFill','PressedFill','DisabledFill'){ if($pc[$k] -ne $pcf){throw "Project chip $k"} }; foreach($k in 'Color','HoverColor','PressedColor','DisabledColor'){ if($pc[$k] -ne $pcc){throw "Project chip $k"} }; if($pc['DisplayMode'] -ne '=DisplayMode.Disabled'){throw 'Project chip must be static'}
foreach($n in 'lblPrjSecGeneral','lblPrjSecAddress','lblPrjSecPeople','lblPrjSecLinks'){ if($indexes.scrProjects[$n]['Properties']['Color'] -ne (CV '#0303B8')){throw "Section header $n must be #0303B8"} }; if($indexes.scrProjects['lblPrjFormTitle']['Properties']['Color'] -ne (CV '#000F41')){throw 'Project form title #000F41'}
if($indexes.scrProjects['lblPrjModified']['Properties']['Color'] -ne (CV '#787878')){throw 'lblPrjModified colour'}
Write-Output 'PASS Projects form: fields white/#9B9B9B with red error border, dropdowns GEA style with red error border, read-only person fields #F0F0F0 without border, chip green (Active) / grey, row chip grey, red stars, blue section headers.'
# 08-11-2026 (Workers build): same admin form colours on scrWorkers (chip from the saved Active, New light blue; blue section headers; grey "Last changed").
$wc=$indexes.scrWorkers['btnWrkFormChip']['Properties']; $wcf='=If(Coalesce(varWrkMode,"")="New",ColorValue("#D5EDFF"),Coalesce(varWrkEdit.Active,true),ColorValue("#1AFF80"),ColorValue("#E6E6E6"))'; $wcc='=If(Coalesce(varWrkMode,"")="New",ColorValue("#0303B8"),Coalesce(varWrkEdit.Active,true),ColorValue("#000F41"),ColorValue("#000000"))'; foreach($k in 'Fill','HoverFill','PressedFill','DisabledFill'){ if($wc[$k] -ne $wcf){throw "Workers chip $k"} }; foreach($k in 'Color','HoverColor','PressedColor','DisabledColor'){ if($wc[$k] -ne $wcc){throw "Workers chip $k"} }; if($wc['DisplayMode'] -ne '=DisplayMode.Disabled'){throw 'Workers chip must be static'}
foreach($n in 'lblWrkSecGeneral','lblWrkSecWork'){ if($indexes.scrWorkers[$n]['Properties']['Color'] -ne (CV '#0303B8')){throw "Section header $n must be #0303B8"} }; if($indexes.scrWorkers['lblWrkFormTitle']['Properties']['Color'] -ne (CV '#000F41')){throw 'Workers form title #000F41'}
if($indexes.scrWorkers['lblWrkModified']['Properties']['Color'] -ne (CV '#787878') -or $indexes.scrWorkers['lblWrkActiveState']['Properties']['Color'] -ne (CV '#000000') -or $indexes.scrWorkers['lblWrkSaveAnywayState']['Properties']['Color'] -ne (CV '#000000')){throw 'Workers label colours (Last changed #787878, switch labels black)'}
Write-Output 'PASS Workers form: chip green (Active) / grey / light blue New, blue section headers, Navy form title, Last changed #787878, switch tracks #0303B8/#B4B4B4 with white knobs (Active, Save anyway), switch labels black.'
Write-Output 'PASS admin form A2: fields white/#9B9B9B (hover #5A5A5A, focus #0303B8), invalid #DB1E28, read-only code #F0F0F0 without border, chip green/grey, red star, blue section headers.'
# 29-10-2026 (Eddy): grey text #787878 is allowed ONLY for scrContractors.lblEmpModified (small meta line); everywhere else text stays black/white.
foreach($screen in $indexes.Keys){foreach($name in $indexes[$screen].Keys){ $c=$indexes[$screen][$name]; if($c['Control'] -like 'Label@*' -and $c['Properties']['Color'] -eq (CV '#787878') -and -not (($screen -eq 'scrContractors' -and $name -eq 'lblEmpModified') -or ($screen -eq 'scrProjects' -and $name -eq 'lblPrjModified') -or ($screen -eq 'scrWorkers' -and $name -eq 'lblWrkModified')) -and $name -notlike 'lblTileSub*'){throw "Grey text #787878 not allowed: $screen.$name"} }}
if($indexes.scrContractors['lblEmpModified']['Properties']['Color'] -ne (CV '#787878')){throw 'lblEmpModified colour'}
Write-Output 'PASS inputs/dropdowns/date pickers #F0F0F0 with 1px #DCDCDC border, hover/focus border #0303B8, selection #0303B8/white; dropdown row hover/pressed #D5EDFF/#000F41, chevron states; week total cells #D5EDFF/#000F41; errors #DB1E28, body black.'

# Home screen (3-11-2026 redesign): white page, cmpTitleBar, headers Navy 16 Semibold with a 2 px #0303B8 line, tiles = cmpTile instances.
# Active tiles show the white icon variant and arrow; Soon tiles the grey variant, no OnSelect; cmpTile colours are checked in the component section below.
$homeIdx=$indexes['scrHome']
if($homeIdx['conHomeScroll']['Properties']['Fill'] -ne '=Color.White'){throw 'Home content must be white'}
$activeTiles=@('ProjectTeam','WeeklyHours','HoursSummary','Contractors','Projects','Workers')
$soonTiles=@('WeekReport','StockOverview','Locations','Requests','Viewer3D','PIDTracker','ComponentLibrary','KnowledgeBase')
$tileSet=@($homeIdx.Keys | Where-Object { $homeIdx[$_]['Control'] -eq 'CanvasComponent' -and $homeIdx[$_]['ComponentName'] -eq 'cmpTile' } | Sort-Object)
$tileExpected=@(($activeTiles+$soonTiles) | ForEach-Object { 'cmpTile'+$_ } | Sort-Object)
if(($tileSet -join ',') -ne ($tileExpected -join ',')){throw "scrHome tile set changed: found [$($tileSet -join ', ')], expected [$($tileExpected -join ', ')]"}
foreach($t in $activeTiles){ $p=$homeIdx['cmpTile'+$t]['Properties']
 if($p['Active'] -ne '=true' -or !$p.ContainsKey('OnSelect') -or $p['ArrowSvg'] -ne '=IconArrowWhite' -or $p['IconSvg'] -notmatch '^=Icon\w+White$' -or $p.ContainsKey('Icon') -or $p.ContainsKey('Arrow')){throw "Active tile $t (Active/OnSelect/ArrowSvg/white IconSvg, no Icon/Arrow)"} }
foreach($t in $soonTiles){ $p=$homeIdx['cmpTile'+$t]['Properties']
 if($p['Active'] -ne '=false' -or $p.ContainsKey('OnSelect') -or $p.ContainsKey('ArrowSvg') -or $p.ContainsKey('IconSvg') -or $p['Icon'] -notmatch '^=Icon\w+Grey$'){throw "Soon tile $t (Active false, no OnSelect, no ArrowSvg/IconSvg, grey icon)"} }
foreach($h in 'TeamHours','MasterData','Inventory','CadTools','Knowledge'){
 if($homeIdx['lblHomeHeader'+$h]['Properties']['Color'] -ne (CV '#000F41') -or $homeIdx['lblHomeHeader'+$h]['Properties']['Size'] -ne '=16'){throw "Home header $h colour/size"}
 if($homeIdx['recHomeLine'+$h]['Properties']['Fill'] -ne (CV '#0303B8') -or $homeIdx['recHomeLine'+$h]['Properties']['Height'] -ne '=2'){throw "Home header line $h"}
}
foreach($pair in @(@('cmpTileProjectTeam','=Navigate(Screen1); true'),@('cmpTileHoursSummary','=Navigate(scrWeeklyHours); true'),@('cmpTileContractors','=Navigate(scrContractors); true'),@('cmpTileProjects','=Navigate(scrProjects); true'),@('cmpTileWorkers','=Navigate(scrWorkers); true'))){if($homeIdx[$pair[0]]['Properties']['OnSelect'] -ne $pair[1]){throw "Home navigation $($pair[0])"}}
# Weekly Hours tile: conditional navigation (loaded -> scrHours, else Screen1 + Notify); exact logic checked in Test-SaveRegression.ps1.
$tileWh=[string]$homeIdx['cmpTileWeeklyHours']['Properties']['OnSelect'];if(!$tileWh.StartsWith('=If(') -or !$tileWh.Contains('Navigate(scrHours)') -or !$tileWh.Contains('Navigate(Screen1)')){throw 'Home navigation cmpTileWeeklyHours'}
# cmpTile component colours (TP-HOME-02 fixes, Eddy 3-11-2026): background rectangle #0303B8 active / #E6E6E6 Soon; label white / #6B6B6B; SOON #5A5A5A.
# Soon tiles: btnCmpTile is a disabled transparent top layer (accessible name). Active tiles: one Image imgCmpTile, checked below (TP-HOME-03 item 5).
$tileDoc=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/Components/cmpTile.pa.yaml')));$tc=@{};Index-RegressionControls $tileDoc['ComponentDefinitions']['cmpTile']['Children'] $tc
if($tc['recCmpTileBg']['Properties']['Fill'] -ne '=ColorValue("#E6E6E6")'){throw 'cmpTile Soon background #E6E6E6'}
if($tc['lblCmpTileLabel']['Properties']['Color'] -ne '=ColorValue("#6B6B6B")'){throw 'cmpTile Soon label #6B6B6B'}
$tb=$tc['btnCmpTile']['Properties']; $TR='=Color.Transparent'
foreach($kv in @(@('Fill',$TR),@('Color',$TR),@('HoverFill',$TR),@('PressedFill',$TR),@('HoverColor',$TR),@('PressedColor',$TR),@('DisabledFill',$TR),@('DisabledColor',$TR),@('DisabledBorderColor',$TR),@('RadiusTopLeft','=0'),@('RadiusBottomRight','=0'))){ if($tb[$kv[0]] -ne $kv[1]){throw "cmpTile.btnCmpTile.$($kv[0]) = $($tb[$kv[0]]) (expected $($kv[1]))"} }
if($tc['lblCmpTileSoon']['Properties']['Color'] -ne (CV '#5A5A5A') -or $tc['lblCmpTileSoon']['Properties']['Size'] -ne '=If(cmpTile.Width>=130,11,9)'){throw 'cmpTile SOON label #5A5A5A / 11 (9 on the smallest tiles)'}
foreach($i in 'imgCmpTileIcon'){ if($tc[$i]['Properties']['HoverFill'] -ne '=Color.Transparent' -or $tc[$i]['Properties']['PressedFill'] -ne '=Color.Transparent'){throw "cmpTile.$i hover/pressed fill must be transparent (Soon icon)"} }
# TP-HOME-03 item 5: an active tile is ONE Image (imgCmpTile): Fill #0303B8, HoverFill #000F41 (whole tile), PressedFill darker, focus 3 px #000F41; no overlay.
$ti2=$tc['imgCmpTile']['Properties']
if($ti2['Fill'] -ne (CV '#0303B8') -or $ti2['HoverFill'] -ne (CV '#000F41') -or $ti2['PressedFill'] -ne '=ColorFade(ColorValue("#000F41"),-0.4)' -or $ti2['FocusedBorderColor'] -ne (CV '#000F41') -or $ti2['FocusedBorderThickness'] -ne '=3'){throw 'cmpTile.imgCmpTile colours: Fill #0303B8, HoverFill #000F41, PressedFill ColorFade(#000F41,-0.4), focus 3 px #000F41'}
Write-Output 'PASS Home tiles (cmpTile): 6 active (white icon + arrow, OnSelect, navigation only) and 8 Soon (grey icon, no arrow, no OnSelect); headers #000F41 16 with 2 px #0303B8 line; active tile = one Image (imgCmpTile) Fill #0303B8 / HoverFill #000F41 / PressedFill ColorFade(#000F41,-0.4), focus 3 px #000F41, Soon #E6E6E6 / #6B6B6B / SOON #5A5A5A, radius 0.'
