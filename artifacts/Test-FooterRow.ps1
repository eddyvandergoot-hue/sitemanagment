param([switch]$GeometryOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-SaveRegression.ps1')
$backup=Join-Path $projectRoot (Get-Content (Join-Path $PSScriptRoot 'footer-row-backup.txt') -Raw).Trim()
if(!$GeometryOnly){
$allowed=@('X','Y','Width','Height','Font','Size','FontWeight','Align','VerticalAlign','PaddingTop','PaddingBottom','PaddingLeft','PaddingRight','RadiusTopLeft','RadiusTopRight','RadiusBottomLeft','RadiusBottomRight','LayoutDirection','LayoutAlignItems','LayoutJustifyContent','LayoutWrap','LayoutOverflowX','LayoutOverflowY','LayoutGap')
foreach($screen in $indexes.Keys){ if($screen -eq 'scrHome'){continue}
 $old=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $backup ('Src/'+$screen+'.pa.yaml'))));$oldIndex=@{};Index-RegressionControls $old['Screens'][$screen]['Children'] $oldIndex
 foreach($name in $oldIndex.Keys){
  if(!$indexes[$screen].ContainsKey($name)){throw "Removed control $name"}
  foreach($key in @($oldIndex[$name]['Properties'].Keys)+@($indexes[$screen][$name]['Properties'].Keys)|Select-Object -Unique){
   if($key -notin $allowed -and $oldIndex[$name]['Properties'][$key] -cne $indexes[$screen][$name]['Properties'][$key]){throw "Behavior/color change $screen.$name.$key"}
  }
 }
 $current=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot ('Src/'+$screen+'.pa.yaml'))))
 foreach($key in @($old['Screens'][$screen]['Properties'].Keys)+@($current['Screens'][$screen]['Properties'].Keys)|Select-Object -Unique){if($old['Screens'][$screen]['Properties'][$key] -cne $current['Screens'][$screen]['Properties'][$key]){throw 'Screen behavior changed'}}
}
foreach($name in @('App.pa.yaml','_EditorState.pa.yaml')){if((Get-FileHash (Join-Path $backup ('Src/'+$name))).Hash -ne (Get-FileHash (Join-Path $projectRoot ('Src/'+$name))).Hash){throw 'Unexpected app change'}}
Write-Output 'PASS only layout/style properties differ; colors, texts, all actions, data/loading/saving, Visible and DisplayMode unchanged.'
}else{Write-Output 'GeometryOnly: diff against footer-row checkpoint skipped (later Hours Summary style change is checked by Test-SummaryStyle.ps1).'}
$layoutEngine=New-Object Microsoft.PowerFx.RecalcEngine
$layoutOptions=New-Object Microsoft.PowerFx.ParserOptions;$layoutOptions.Culture=[Globalization.CultureInfo]::GetCultureInfo('en-US')
function Publish-Rect($name,$rect){$literal='{X:'+$rect.X+',Y:'+$rect.Y+',Width:'+$rect.Width+',Height:'+$rect.Height+',Visible:true}';$v=$layoutEngine.Eval($literal,$null,$layoutOptions);$layoutEngine.UpdateVariable($name,$v)}
function Publish-Rows($count){$v=$layoutEngine.Eval('ForAll(Sequence('+$count+'),{WorkerID:Value})',$null,$layoutOptions);$layoutEngine.UpdateVariable('colReportRows',$v)}
function Layout-Number($expr,$parent,$self){
 $literal='With({LayoutParent:{X:0,Y:0,Width:'+$parent.Width+',Height:'+$parent.Height+'},LayoutSelf:{X:'+$self.X+',Y:'+$self.Y+',Width:'+$self.Width+',Height:'+$self.Height+',Text:"status"}},'+$expr.TrimStart('=').Replace('Parent.','LayoutParent.').Replace('Self.','LayoutSelf.')+')'
 $v=$layoutEngine.Eval($literal,$null,$layoutOptions);if($v -is [Microsoft.PowerFx.Types.ErrorValue]){throw $v.ToExpression()};return [double]$v.Value
}
function Measure-Rect($name,$props,$parent){
 $rect=@{X=0;Y=0;Width=0;Height=0}
 for($pass=0;$pass -lt 2;$pass++){foreach($key in @('Width','Height','X','Y')){if($props.ContainsKey($key)){$rect[$key]=Layout-Number $props[$key] $parent $rect}}}
 Publish-Rect $name $rect;return $rect
}
$metric=Measure-Rect 'lblFooterButtonMetrics' $indexes.Screen1['lblFooterButtonMetrics']['Properties'] @{Width=1366;Height=768}
if($metric.Y -ne 16 -or $metric.Height -ne 40 -or $metric.Width -ne 12){throw 'Shared metrics invalid'}
$configs=@(
 @{Screen='Screen1';Bar='navProjectTeam';Row='conProjectButtonRow';Nav=@('btnHomeScreen1','btnGotoHours','btnGotoHoursSummary');Actions=@('btnMigratePreview','btnMigrateConfirm','btnRefreshTeam','btnAddtoTeam')},
 @{Screen='scrHours';Bar='navWeeklyHours';Row='conWeekButtonRow';Nav=@('btnHomeHours','btnWeeklyProjectTeam');Actions=@('btnRefreshWeek','btnDiscardWeek','btnSaveWeek')},
 @{Screen='scrWeeklyHours';Bar='navHoursSummary';Row='conSummaryButtonRow';Nav=@('btnHomeSummary','btnSummaryProjectTeam');Actions=@('btnReportPreviousWeeks','btnReportNextWeeks','btnRefreshReport')},
 @{Screen='scrProjects';Bar='navPrj';Row='conPrjButtonRow';Nav=@('btnPrjHome');Actions=@('btnPrjNew','btnPrjRefresh','btnPrjDiscard','btnPrjSave');P='Prj'}
)
# 30-10-2026 (Projects build): admin-pattern screens share the white 68 px footer, Home icon and message-bar checks.
$adminFooter=@('scrContractors','scrProjects')
foreach($case in @(@(320,600),@(480,600),@(600,600),@(768,600),@(1024,768),@(1366,768),@(1920,1080))){
 foreach($cfg in $configs){
  $w=$case[0];$h=$case[1];$screen=@{Width=$w;Height=$h};$index=$indexes[$cfg.Screen];$rects=@{}
  $buttons=$cfg.Nav+$cfg.Actions
  foreach($name in $buttons){
   $p=$index[$name]['Properties'];if($p['Y'] -ne $(if($cfg.Screen -in $adminFooter){'=(Parent.Height-Self.Height)/2'}else{'=lblFooterButtonMetrics.Y'}) -or $p['Height'] -ne '=lblFooterButtonMetrics.Height'){throw 'Nonshared vertical alignment'}
   $rects[$name]=@{X=0;Y=$metric.Y;Width=(Layout-Number $p['Width'] $screen @{X=0;Y=0;Width=0;Height=0});Height=$metric.Height};Publish-Rect $name $rects[$name]
  }
  $bar=Measure-Rect $cfg.Bar $index[$cfg.Bar]['Properties'] $screen
  $row=Measure-Rect $cfg.Row $index[$cfg.Row]['Properties'] $bar
  foreach($name in $cfg.Nav){$rects[$name]=Measure-Rect $name $index[$name]['Properties'] $row}
  for($i=$cfg.Actions.Count-1;$i -ge 0;$i--){$name=$cfg.Actions[$i];$rects[$name]=Measure-Rect $name $index[$name]['Properties'] $row}
  $previous=$null
  foreach($name in $buttons){$r=$rects[$name];if($r.Y -ne $(if($cfg.Screen -in $adminFooter){14}else{16}) -or $r.Height -ne 40 -or $r.X -lt 40 -or $r.X+$r.Width -gt $row.Width-40){throw 'Button outside one row'};if($previous -and $r.X-($previous.X+$previous.Width) -lt 12){throw 'Overlap/gap under 12'};$previous=$r}
  foreach($group in @($cfg.Nav,$cfg.Actions)){for($i=1;$i -lt $group.Count;$i++){if($rects[$group[$i]].X-($rects[$group[$i-1]].X+$rects[$group[$i-1]].Width) -ne 12){throw 'Incorrect group gap'}}}
  if($cfg.Screen -in $adminFooter -and ($bar.Height -ne 68 -or $row.Height -ne 68 -or $index[$cfg.Bar]['Properties']['Fill'] -ne '=Color.White')){throw 'Admin footer must be white and 68 px high (bar and row)'}
  if($cfg.Screen -in $adminFooter){$pp=$cfg.P;$kidsRow=@($index[$cfg.Row]['Children']|ForEach-Object {@($_.Keys)[0]}); if($kidsRow[1] -ne "ico${pp}Home" -or $index["ico${pp}Home"]['Control'] -ne 'Classic/Icon@2.5.0' -or $index["ico${pp}Home"]['Properties']['Icon'] -ne '=Icon.Home' -or $index["ico${pp}Home"]['Properties']['OnSelect'] -ne "=Select(btn${pp}Home)" -or $index["rec${pp}FooterLine"]['Properties']['Fill'] -ne '=ColorValue("#DCDCDC")' -or $index["rec${pp}FooterLine"]['Properties']['Y'] -ne "=nav${pp}.Y" -or $index["rec${pp}FooterLine"]['Properties']['Height'] -ne '=1'){throw 'Admin footer: Home icon (direct row child after the Home button) or 1 px #DCDCDC top line missing'}}
  if($bar.Y+$bar.Height -ne $h -or $index[$cfg.Bar]['Properties']['LayoutWrap'] -ne '=false' -or $index[$cfg.Bar]['Properties']['LayoutOverflowX'] -ne '=LayoutOverflow.Scroll'){throw 'Footer not fixed/single row/scrollable'}
  $children=@($index[$cfg.Row]['Children']|ForEach-Object {@($_.Keys)[0]});foreach($name in $buttons){if($name -notin $children){throw 'Button in separate parent'}}
  # 26-10-2026 (powerfx-logic): Home has its own guard, identical in DisplayMode and OnSelect (If(<guard>,Navigate(scrHome))); the guard values are checked in Test-SaveRegression.ps1.
  $homeBtn=$cfg.Nav[0];$homeDm=[string]$index[$homeBtn]['Properties']['DisplayMode'];$homeOs=[string]$index[$homeBtn]['Properties']['OnSelect']
  $homeGuardOk=$homeDm.StartsWith('=If(') -and $homeDm.EndsWith(',DisplayMode.Edit,DisplayMode.Disabled)') -and $homeOs -ceq ('=If('+$homeDm.Substring(4,$homeDm.Length-4-',DisplayMode.Edit,DisplayMode.Disabled)'.Length)+',Navigate(scrHome))')
  $homeText=if($cfg.Screen -eq 'scrContractors'){'=If(LangNl && !IsBlank(T.empHome.nl),T.empHome.nl,T.empHome.en)'}elseif($cfg.Screen -eq 'scrProjects'){'=If(LangNl && !IsBlank(T.prjHome.nl),T.prjHome.nl,T.prjHome.en)'}else{'="Home"'}; $homeGap=if($cfg.Nav.Count -gt 1){$rects[$cfg.Nav[1]].X-($rects[$homeBtn].X+$rects[$homeBtn].Width) -ne 12}else{$false}; if($children[0] -ne $homeBtn -or !$homeGuardOk -or $index[$homeBtn]['Properties']['Text'] -ne $homeText -or $rects[$homeBtn].X -ne 40 -or $homeGap){throw "Home button must be first (X=40, 12 px before next nav button) and navigate to scrHome behind the same guard in DisplayMode and OnSelect: $($cfg.Screen)"}
  if($cfg.Screen -eq 'Screen1'){
   foreach($name in @('ddTeam','ddProject','lblTeamWeek','dpTeamWeek','lblProject','lblTeam')){Publish-Rect $name @{X=0;Y=0;Width=0;Height=0}}
   foreach($name in @('conSelection','lblProject','lblTeam','ddProject','ddTeam','lblTeamWeek','dpTeamWeek','lblTeamWeekKW','lblSelectionLoadStatus','Label2','Gallery1')){$rects[$name]=Measure-Rect $name $index[$name]['Properties'] $screen}
   if($rects.Gallery1.Y+$rects.Gallery1.Height -gt $rects.Label2.Y-12 -or $rects.Label2.Y+$rects.Label2.Height -gt $bar.Y){throw 'Team content behind footer'}
   # 26-10-2026 week picker group: label "Week" 28 px directly above the picker (4 px gap), KW label in the label row, same box; wide = right of the dropdowns, narrow = stacked under Team.
   $rects['conSelection']=Measure-Rect 'conSelection' $index['conSelection']['Properties'] $screen
   $wk=$rects.lblTeamWeek;$dp=$rects.dpTeamWeek;$kw=$rects.lblTeamWeekKW
   if($dp.Y -ne $wk.Y+$wk.Height+4 -or $dp.X -ne $wk.X -or $dp.Width -ne $wk.Width -or $kw.X -ne $wk.X -or $kw.Y -ne $wk.Y -or $kw.Width -ne $wk.Width -or $kw.Height -ne $wk.Height){throw "Week group misaligned at $w"}
   if($w -ge 336 -and $dp.Width -ne 256){throw "Week picker not 256 at $w"}
   if($dp.X+$dp.Width -gt $w-40 -or $dp.X -lt 40){throw "Week picker outside margins at $w"}
   foreach($other in @('lblProject','lblTeam','ddProject','ddTeam')){foreach($grp in @($wk,$dp)){$o=$rects[$other];if($grp.X -lt $o.X+$o.Width -and $o.X -lt $grp.X+$grp.Width -and $grp.Y -lt $o.Y+$o.Height -and $o.Y -lt $grp.Y+$grp.Height){throw "Week group overlaps $other at $w"}}}
   if($w -ge 899 -and $dp.Y -ne $rects.ddTeam.Y){throw "Wide: picker must share the Team row at $w"}
   if($w -lt 899 -and $wk.Y -lt $rects.ddTeam.Y+$rects.ddTeam.Height+12){throw "Narrow: week group must stack under Team at $w"}
   if($dp.Y+$dp.Height+12 -gt $rects.lblSelectionLoadStatus.Y -or $dp.Y+$dp.Height+20 -gt $rects.conSelection.Y+$rects.conSelection.Height -or $dp.Y -lt $rects.conSelection.Y){throw "Week group outside selection block/behind status at $w"}
  }elseif($cfg.Screen -eq 'scrHours'){
   foreach($name in @('dpHoursWeek','lblWeekLoadStatus','galHours','lblHeaderMon')){$rects[$name]=Measure-Rect $name $index[$name]['Properties'] $screen}
   if($rects.galHours.Y+$rects.galHours.Height -gt $bar.Y-12 -or $rects.lblHeaderMon.Y+$rects.lblHeaderMon.Height -gt $rects.galHours.Y){throw 'Hours content behind footer'}
  }elseif($cfg.Screen -in $adminFooter){$pp=$cfg.P
   # 29-10-2026 (Eddy): no on-screen status/error lines on Contractors. 30-10-2026 (admin pattern A1): shared message bar conEmpMsgBar
   # directly under the title bar (full title width, 40 px with a message, 0 px without); body 12 px under the bar, above the footer.
   # Projects build (30-10-2026): same checks for scrProjects (prefix Prj).
   if($index.ContainsKey("lbl${pp}Status") -or $index.ContainsKey("lbl${pp}Errors")){throw "$($cfg.Screen) must not have lbl${pp}Status/lbl${pp}Errors"}
   $tName="lbl${pp}Title"; $rects[$tName]=Measure-Rect $tName $index[$tName]['Properties'] $screen
   Publish-Rect "nav$pp" $bar
   foreach($kind in @('""','"Error"')){
    $layoutEngine.UpdateVariable('varAdmMsgKind',$layoutEngine.Eval($kind,$null,$layoutOptions))
    $msgBar=Measure-Rect "con${pp}MsgBar" $index["con${pp}MsgBar"]['Properties'] $screen
    $expH=if($kind -eq '""'){0}else{40}
    if($msgBar.Y -ne $rects[$tName].Y+$rects[$tName].Height -or $msgBar.X -ne $rects[$tName].X -or $msgBar.Width -ne $rects[$tName].Width -or $msgBar.Height -ne $expH){throw "$($cfg.Screen) message bar not directly under the title bar at full title width with height $expH (kind $kind)"}
    $body=Measure-Rect "con${pp}Body" $index["con${pp}Body"]['Properties'] $screen
    if($body.Y -ne $msgBar.Y+$msgBar.Height -or $body.Y+$body.Height -gt $bar.Y){throw "$($cfg.Screen) body not directly under the message bar or behind footer (kind $kind)"}
   }
  }elseif($cfg.Screen -eq 'scrWeeklyHours'){
   # Worst-case viewport height: larger selector content reaches the existing viewport cap.
   Publish-Rect 'conSummaryFiltersContent' @{X=0;Y=0;Width=512;Height=1000}
   # 22-10-2026: floating grand total replaced by a Total row directly under the rows (outside the gallery, above the footer).
   foreach($rowCount in @(1,100)){
    Publish-Rows $rowCount
    foreach($name in @('conSummarySelectors','lblReportProjectDetails','lblReportStatus','lblReportNameHeader','galReportRows','recReportTotalRow')){Publish-Rect $name @{X=0;Y=0;Width=0;Height=0}}
    foreach($name in @('lblWeeklyHoursTitle','conSummarySelectors','lblReportProjectDetails','lblReportStatus','lblReportNameHeader','lblReportEmployerHeader','galReportWeekHeaders','lblReportTotalHeader','galReportRows','recReportTotalRow','galReportTotalWeeks','lblReportTotalRowValue')){$rects[$name]=Measure-Rect $name $index[$name]['Properties'] $screen}
    foreach($header in @('lblReportEmployerHeader','galReportWeekHeaders','lblReportTotalHeader')){if($rects[$header].Y -ne $rects.lblReportNameHeader.Y){throw 'Header misaligned after footer move'}}
    $rowsBottom=$rects.galReportRows.Y+$rects.galReportRows.Height
    if($rects.recReportTotalRow.Y -ne $rowsBottom){throw "Total row not directly under the rows ($rowCount rows) at $w"}
    if($rects.recReportTotalRow.Y+$rects.recReportTotalRow.Height -gt $bar.Y-12){throw "Total row behind footer ($rowCount rows) at $w"}
    if($rowCount -eq 100 -and $rects.galReportRows.Height -lt 44){throw "Rows gallery shorter than one row at $w"}
    if($rowCount -eq 1 -and $rects.galReportRows.Height -ne 44 -and $rects.galReportRows.Height -ne [Math]::Max(0,$bar.Y-12-44-$rects.galReportRows.Y)){throw "Rows gallery not sized to its rows at $w"}
    $right=$rects.lblReportTotalHeader.X+$rects.lblReportTotalHeader.Width
    if($right -ne $w-56 -or $rects.recReportTotalRow.X+$rects.recReportTotalRow.Width -ne $right -or $rects.lblReportTotalRowValue.X+$rects.lblReportTotalRowValue.Width -ne $right -or $rects.galReportRows.X+$rects.galReportRows.Width-16 -ne $right -or $rects.galReportWeekHeaders.X+$rects.galReportWeekHeaders.Width -ne $rects.lblReportTotalHeader.X -or $rects.galReportTotalWeeks.X -ne $rects.galReportWeekHeaders.X -or $rects.galReportTotalWeeks.Width -ne $rects.galReportWeekHeaders.Width){throw "Header/rows/total right edges differ at $w"}
   }
  }
  Write-Output "PASS $($cfg.Screen) $w x $h : same Y/40px, 12px gaps, fixed footer, row width $($row.Width), content/total above footer."
 }
}
Write-Output 'Geometry and source invariants only; native AutoLayout scrollbar, visual rendering, Studio import and online data tests remain open. Small-width table redesign is outside this footer change.'

# 30-10-2026 (step 3a): scrContractors footer = cmpFooter instance (68 px, anchored at the bottom); geometry pinned on the instance and the component definition, evaluated numerically.
$ci=$indexes['scrContractors']; $inst=$ci['cmpEmpFooter']['Properties']
if($ci['cmpEmpFooter']['Control'] -ne 'CanvasComponent' -or $ci['cmpEmpFooter']['ComponentName'] -ne 'cmpFooter' -or $inst['X'] -ne '=0' -or $inst['Y'] -ne '=Parent.Height-Self.Height' -or $inst['Width'] -ne '=Parent.Width' -or $inst['Height'] -ne '=68'){throw 'scrContractors cmpEmpFooter instance geometry (X 0, Y Parent.Height-Self.Height, Width Parent.Width, Height 68)'}
$fd=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/Component/cmpFooter.pa.yaml')))['ComponentDefinitions']['cmpFooter']
$fi=@{}; Index-RegressionControls $fd['Children'] $fi
if($fd['Properties']['Height'] -ne '=68' -or $fd['Properties']['Fill'] -ne '=Color.White' -or $fi['lblCmpFooterMetrics']['Properties']['X'] -ne '=40' -or $fi['lblCmpFooterMetrics']['Properties']['Width'] -ne '=12' -or $fi['lblCmpFooterMetrics']['Properties']['Height'] -ne '=40'){throw 'cmpFooter metrics (X 40, gap 12, button height 40, bar 68 white)'}
$bw=@{Home=110;New=90;Refresh=110;Discard=188;Save=140}
foreach($b in $bw.Keys){ $bp=$fi["btnCmp$b"]['Properties']; if($bp['Width'] -ne ('='+$bw[$b]) -or $bp['Height'] -ne '=lblCmpFooterMetrics.Height' -or $bp['Y'] -ne '=(Parent.Height-Self.Height)/2'){throw "cmpFooter btnCmp$b width/height/Y"} }
if($fi['btnCmpHome']['Properties']['X'] -ne '=lblCmpFooterMetrics.X' -or $fi['btnCmpNew']['Properties']['X'] -ne '=btnCmpRefresh.X-lblCmpFooterMetrics.Width-Self.Width' -or $fi['btnCmpRefresh']['Properties']['X'] -ne '=btnCmpDiscard.X-lblCmpFooterMetrics.Width-Self.Width' -or $fi['btnCmpDiscard']['Properties']['X'] -ne '=btnCmpSave.X-lblCmpFooterMetrics.Width-Self.Width' -or $fi['btnCmpSave']['Properties']['X'] -ne '=Parent.Width-lblCmpFooterMetrics.X-Self.Width'){throw 'cmpFooter button X chain (Home 40; New, Refresh, Discard, Save right-aligned with 12 px gaps)'}
$rowKids=@($fi['conCmpFooterRow']['Children'] | ForEach-Object {@($_.Keys)[0]})
if(($rowKids -join ',') -ne 'btnCmpHome,icoCmpHome,btnCmpNew,btnCmpRefresh,btnCmpDiscard,btnCmpSave'){throw "cmpFooter: all buttons are direct children of one row (Home icon right after Home): $($rowKids -join ',')"}
if($fi['icoCmpHome']['Properties']['Icon'] -ne '=Icon.Home' -or $fi['icoCmpHome']['Properties']['OnSelect'] -ne '=Select(btnCmpHome)' -or $fi['recCmpFooterLine']['Properties']['Fill'] -ne '=ColorValue("#DCDCDC")' -or $fi['recCmpFooterLine']['Properties']['Y'] -ne '=0' -or $fi['recCmpFooterLine']['Properties']['Height'] -ne '=1'){throw 'cmpFooter Home icon / 1 px #DCDCDC top line'}
if($fi['conCmpFooter']['Properties']['LayoutWrap'] -ne '=false' -or $fi['conCmpFooter']['Properties']['LayoutOverflowX'] -ne '=LayoutOverflow.Scroll' -or $fi['conCmpFooterRow']['Properties']['Width'] -ne '=Max(Parent.Width,2*lblCmpFooterMetrics.X+btnCmpHome.Width+btnCmpNew.Width+btnCmpRefresh.Width+btnCmpDiscard.Width+btnCmpSave.Width+4*lblCmpFooterMetrics.Width)'){throw 'cmpFooter single row, scroll, minimum row width'}
$minRow=2*40+($bw.Values | Measure-Object -Sum).Sum+4*12
if($minRow -ne 766){throw "Contractors minimum footer row width changed ($minRow; unchanged by step 3a: 80 + 638 button widths + 48 gaps = 766; AGENTS still says 746)"}
# screen layout formulas (title 60, message bar BarHeight, body above the footer)
if($ci['cmpEmpMsgBar']['Properties']['Y'] -ne '=cmpEmpTitle.Y+cmpEmpTitle.Height' -or $ci['cmpEmpMsgBar']['Properties']['Height'] -ne '=cmpEmpMsgBar.BarHeight' -or $ci['cmpEmpMsgBar']['Properties']['Width'] -ne '=cmpEmpTitle.Width' -or $ci['cmpEmpMsgBar']['Properties']['X'] -ne '=cmpEmpTitle.X'){throw 'cmpEmpMsgBar not directly under the title bar at full title width with Height = BarHeight'}
if($ci['conEmpBody']['Properties']['Y'] -ne '=cmpEmpMsgBar.Y+cmpEmpMsgBar.Height' -or $ci['conEmpBody']['Properties']['Height'] -ne '=Max(0,cmpEmpFooter.Y-Self.Y)'){throw 'conEmpBody not directly under the message bar / above the footer'}
foreach($case in @(@(320,600),@(600,600),@(768,600),@(1024,768),@(1366,768),@(1920,1080))){
 $w=$case[0];$h=$case[1]; $rowW=[Math]::Max($w,$minRow)
 $x=@{Save=$rowW-40-140}; $x.Discard=$x.Save-12-188; $x.Refresh=$x.Discard-12-110; $x.New=$x.Refresh-12-90; $x.Home=40
 if($x.Home+110+12 -gt $x.New){ if($w -ge $minRow){throw "Home/New overlap at $w"} }
 if($w -ge $minRow -and ($x.New-$x.Home-110 -lt 12)){throw "Home-New gap under 12 at $w"}
 if($w -eq $minRow -and ($x.New-$x.Home-110 -ne 12)){throw "At the minimum width all gaps are 12"}
 foreach($mh in 0,40){ $bodyY=60+$mh; $footerY=$h-68; if($bodyY -gt $footerY){continue}; if($footerY-$bodyY -lt 0){throw "Body behind footer at $w x $h"} }
 Write-Output "PASS scrContractors footer (cmpFooter) $w x $h : one row $rowW wide, Y 14/40 px, 12 px gaps (New/Refresh/Discard/Save), Save ends at row-40, bar anchored at the bottom, body between message bar and footer."
}

if(@($indexes['scrHome'].Keys | Where-Object {$indexes['scrHome'][$_]['Control'] -like 'Classic/Button@*' -and $_ -notlike 'btnTile*'}).Count){throw 'Home has a non-tile button (no footer on Home)'}
Write-Output 'PASS Home screen has no footer/action row; Home button is first (X=40) in each footer, 12 px before the next navigation button, OnSelect If(<guard>,Navigate(scrHome)) with the same guard as its DisplayMode (guard values: Test-SaveRegression.ps1).'
