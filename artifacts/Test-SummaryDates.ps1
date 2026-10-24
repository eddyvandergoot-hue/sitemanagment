param([switch]$HistoricalDiff)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-SaveRegression.ps1')
$new=$indexes['scrWeeklyHours']
$source=[IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrWeeklyHours.pa.yaml'))

if($HistoricalDiff){
# Historical (21-10-2026): diff against checkpoint summary-dates. Fails since later, unrelated commissions changed Screen1/scrHours; kept for reference only.
$backup=Join-Path $projectRoot (Get-Content (Join-Path $PSScriptRoot 'summary-dates-backup.txt') -Raw).Trim()
$removed=@('lblddReportStartYear','ddReportStartYear','lblddReportStartWeek','ddReportStartWeek','lblddReportEndYear','ddReportEndYear','lblddReportEndWeek','ddReportEndWeek')
$added=@('lblReportFrom','dpReportFrom','lblReportUntil','dpReportUntil')
$laterLabelChange=@('lblWeeklyHoursTitle','lblReportProjectDetails','lblReportStatus','lblReportTotalHeader','lblReportWorkerTotal','lblReportGrandTotal','lblReportProject','lblReportContractor','lblReportFrom','lblReportUntil','dpReportFrom','dpReportUntil','conSummaryFiltersContent','btnBuildReport')
$changed=@{'btnBuildReport'=@('OnSelect');'btnLoadReport'=@('OnSelect');'conSummaryFiltersContent'=@('Height');'lblReportContractor'=@('Y');'ddReportContractor'=@('X')}
foreach($name in @('App.pa.yaml','Screen1.pa.yaml','scrHours.pa.yaml','_EditorState.pa.yaml')){if((Get-FileHash (Join-Path $backup ('Src/'+$name))).Hash -ne (Get-FileHash (Join-Path $projectRoot ('Src/'+$name))).Hash){throw "Unexpected change $name"}}
$old=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $backup 'Src/scrWeeklyHours.pa.yaml')));$oldIndex=@{};Index-RegressionControls $old['Screens']['scrWeeklyHours']['Children'] $oldIndex
foreach($name in $oldIndex.Keys){
 if($name -in $removed){if($new.ContainsKey($name)){throw "Old control still present $name"};continue}
 if(!$new.ContainsKey($name)){throw "Removed control $name"}
 if($name -in $laterLabelChange){continue}
 foreach($key in @($oldIndex[$name]['Properties'].Keys)+@($new[$name]['Properties'].Keys)|Select-Object -Unique){
  if($oldIndex[$name]['Properties'][$key] -cne $new[$name]['Properties'][$key] -and !($changed.ContainsKey($name) -and $key -in $changed[$name])){throw "Unexpected change $name.$key"}
 }
}
foreach($name in $new.Keys){if(!$oldIndex.ContainsKey($name) -and $name -notin $added+@('lblReportFromWeek','lblReportUntilWeek')){throw "Unexpected new control $name"}}
Write-Output 'PASS historical diff against summary-dates checkpoint.'
}

# Structure: selectors and week labels live in the selector content container; removed period dropdowns stay removed.
$parentOf=@{};foreach($entry in $new['conSummaryFiltersContent']['Children']){$parentOf[@($entry.Keys)[0]]='conSummaryFiltersContent'}
foreach($name in @('lblReportFrom','lblReportFromWeek','dpReportFrom','lblReportUntil','lblReportUntilWeek','dpReportUntil','lblReportProject','ddReportProject','lblReportContractor','ddReportContractor')){if($parentOf[$name] -ne 'conSummaryFiltersContent'){throw "$name not in the selector content container"}}
foreach($ref in @('lblddReportStartYear','ddReportStartYear','lblddReportStartWeek','ddReportStartWeek','lblddReportEndYear','ddReportEndYear','lblddReportEndWeek','ddReportEndWeek','colReportYears','colReportStartWeeks','colReportEndWeeks','varReportDefaultStartYear','varReportDefaultEndYear','lblReportIsoPeriod')){if($source -match "\b$ref\b"){throw "Reference to removed $ref"}}
foreach($name in @('dpReportFrom','dpReportUntil')){
 $p=$new[$name]['Properties']
 if($new[$name]['Control'] -ne 'ModernDatePicker@1.0.0' -or $p['Format'] -ne '="dd-mm-yyyy"' -or $p['StartOfWeek'] -ne '=StartOfWeek.Monday' -or $p['Font'] -ne '="Inter, Arial, sans-serif"' -or $p['FontWeight'] -ne '=FontWeight.Normal' -or $p['Color'] -ne '=ColorValue("#000000")'){throw "$name settings"}
 if($p['DisplayMode'] -ne '=If(varReportBusy || !varReportReady || IsEmpty(colReportPeriods),DisplayMode.Disabled,DisplayMode.Edit)'){throw "$name DisplayMode changed"}
}
if($new['dpReportFrom']['Properties']['DefaultDate'] -ne '=Coalesce(varReportFromPickedDay,varReportStartMonday)' -or $new['dpReportUntil']['Properties']['DefaultDate'] -ne '=Coalesce(varReportUntilPickedDay,varReportEndSunday)'){throw 'DefaultDate must show the picked day, else the normalized date'}
if($new['dpReportUntil']['Properties']['ValidationState'] -ne '=If(!IsBlank(varReportStartMonday) && !IsBlank(varReportEndSunday) && varReportEndSunday<varReportStartMonday,ValidationState.Error,ValidationState.None)'){throw 'Till-before-From ValidationState changed'}
$load=$new['btnLoadReport']['Properties']['OnSelect']
foreach($needle in @('CountRows(colReportAssignments)>=500','CountRows(colReportProjects)>=500','CountRows(colReportContractors)>500','Set(varReportLoadState,"Failed")','Set(varReportReady,true); Set(varReportLoadState,"Loaded")','Set(varReportStartMonday,First(colReportPeriods).Monday)','Set(varReportEndSunday,DateAdd(Last(colReportPeriods).Monday,6,TimeUnit.Days))',
 'Set(varReportFromPickedDay,Blank()); Set(varReportUntilPickedDay,Blank()); Reset(dpReportFrom); Reset(dpReportUntil);')){if(!$load.Contains($needle)){throw "Loader lost $needle"}}
if($load -notmatch [regex]::Escape('Set(varReportFromPickedDay,Blank()); Set(varReportUntilPickedDay,Blank());')+'\s*'+[regex]::Escape('Reset(ddReportContractor); Reset(dpReportFrom); Reset(dpReportUntil);')){throw 'Loader must clear picked days before resetting to the default period'}
if($load -match 'Patch|Remove\(|Update\(|SubmitForm'){throw 'Loader writes to a data source'}
# Reset of the pickers only in the loader (default period / failed load) and in the blocked (blank) change.
foreach($screenName in $indexes.Keys){foreach($cn in $indexes[$screenName].Keys){foreach($pn in $indexes[$screenName][$cn]['Properties'].Keys){
 $fx=[string]$indexes[$screenName][$cn]['Properties'][$pn]
 foreach($m in [regex]::Matches($fx,'Reset\((dpReportFrom|dpReportUntil)\)')){
  $ok=($cn -eq 'btnLoadReport' -and $pn -eq 'OnSelect') -or ($cn -eq $m.Groups[1].Value -and $pn -eq 'OnChange')
  if(!$ok){throw "Unexpected Reset($($m.Groups[1].Value)) in $cn.$pn"}
 }
}}}
foreach($pair in @(@('dpReportFrom','varReportFromPickedDay'),@('dpReportUntil','varReportUntilPickedDay'))){
 $fx=$new[$pair[0]]['Properties']['OnChange']
 if(([regex]::Matches($fx,'Reset\(')).Count -ne 1 -or !$fx.Contains("If(IsBlank(Self.SelectedDate),Set($($pair[1]),Blank()); Reset($($pair[0])),")){throw "$($pair[0]): Reset only for a blank (blocked) change"}
 if($fx -match 'If\(selectedDay<>'){throw "$($pair[0]): visible normalization reset still present"}
 if(!$fx.Contains("Set($($pair[1]),selectedDay);")){throw "$($pair[0]): picked day not stored"}
}
Write-Output 'PASS structure: pickers + week labels in the selector container; DefaultDate = picked day, else normalized date; Reset only in the loader and for a cleared field; Till-before-From ValidationState unchanged; loader safety checks kept.'

# Normalization: a pick stores the day, rebuilds only when the week boundary changes, and never resets (no visible jump, no loop).
function Get-Fx($name){$new[$name]['Properties']['OnChange']}
$mondayFx=[regex]::Match((Get-Fx 'dpReportFrom'),'monday:(DateAdd\(selectedDay,[^}]+)\}').Groups[1].Value
$sundayFx=[regex]::Match((Get-Fx 'dpReportUntil'),'sunday:(DateAdd\(selectedDay,[^}]+)\}').Groups[1].Value
foreach($pair in @(@('dpReportFrom',$mondayFx,'varReportStartMonday','monday',1),@('dpReportUntil',$sundayFx,'varReportEndSunday','sunday',7))){
 $fx=Get-Fx $pair[0]
 if(!$fx.Contains("If($($pair[3])<>$($pair[2]),Set($($pair[2]),$($pair[3])); Set(varReportValid,false); Select(btnBuildReport))") -or !$fx.StartsWith('=If(!varReportBusy,')){throw "$($pair[0]) OnChange shape"}
 if(([regex]::Matches($fx,'Select\(')).Count -ne 1){throw "$($pair[0]) has more than one Select"}
 foreach($day in @('2026,10,21','2026,10,19','2026,10,25','2026,12,31','2027,1,3','2021,1,1','2020,12,28','2021,1,3')){
  $state='Date(2026,1,5)'
  $first=$regressionEngine.Eval('With({selectedDay:Date('+$day+'),current:'+$state+'},With({n:'+$pair[1]+'},{Build:n<>current,Next:n,Wd:Weekday(n,StartOfWeek.Monday)}))',$null,$regressionOptions)
  if($first.GetField('Wd').Value -ne $pair[4]){throw "$($pair[0]) $day not normalized to weekday $($pair[4])"}
  $next=$first.GetField('Next').Value;$nd='Date('+$next.Year+','+$next.Month+','+$next.Day+')'
  # The control keeps showing the picked day: DefaultDate = picked day, so a re-evaluation of OnChange with the same day does nothing.
  $again=$regressionEngine.Eval('With({selectedDay:Date('+$day+'),current:'+$nd+'},With({n:'+$pair[1]+'},n<>current))',$null,$regressionOptions)
  if($again.Value){throw "$($pair[0]) $day re-fires a build (loop)"}
  foreach($offset in 0..6){
   $other=$regressionEngine.Eval('With({selectedDay:DateAdd('+$nd+','+($offset-($pair[4]-1))+',TimeUnit.Days),current:'+$nd+'},With({n:'+$pair[1]+'},n<>current))',$null,$regressionOptions)
   if($other.Value){throw "$($pair[0]) other day in the same week would rebuild"}
  }
 }
}
Write-Output 'PASS normalization: From -> Monday, Till -> Sunday (incl. 2020 KW53 and year change); no Reset after a normal pick; repeated or same-week picks do not rebuild; only a changed week boundary selects Build once.'

# Week labels "YYYY KWxx": ISO year = Year(Monday+3), two-digit week.
# The local interpreter has no ISOWeekNum (canvas function, also used by Weekly Hours). Substitute the Thursday rule and validate it
# day by day against .NET ISOWeek for 2000-2040 before using it.
# Day count via hours/24 rounded: the local interpreter truncates DateDiff(...,Days) across a DST change (23-hour day).
function Expand-IsoWeekNum([string]$fx){[regex]::Replace($fx,'ISOWeekNum\((\w+)\)','With({isoTh:DateAdd($1,4-Weekday($1,StartOfWeek.Monday),TimeUnit.Days)},RoundDown(Round(DateDiff(Date(Year(isoTh),1,1),isoTh,TimeUnit.Hours)/24,0)/7,0)+1)')}
$probe=Expand-IsoWeekNum 'ISOWeekNum(d)'
$d=[datetime]'2000-01-01';$mismatch=0
while($d -le [datetime]'2040-12-31'){
 $v=$regressionEngine.Eval('With({d:Date('+$d.Year+','+$d.Month+','+$d.Day+')},'+$probe+')',$null,$regressionOptions).Value
 # .NET Framework reference: shift Mon-Wed by 3 days, then FirstFourDayWeek/Monday (ISO 8601 incl. week 53).
 $ref=$d;if($ref.DayOfWeek -ge [DayOfWeek]::Monday -and $ref.DayOfWeek -le [DayOfWeek]::Wednesday){$ref=$ref.AddDays(3)}
 $refWeek=[Globalization.CultureInfo]::InvariantCulture.Calendar.GetWeekOfYear($ref,[Globalization.CalendarWeekRule]::FirstFourDayWeek,[DayOfWeek]::Monday)
 if([int]$v -ne $refWeek){$mismatch++}
 $d=$d.AddDays(1)
}
if($mismatch -gt 0){throw "ISOWeekNum substitute differs from .NET ISOWeek on $mismatch days"}
Write-Output 'PASS ISOWeekNum substitute equals .NET ISOWeek for every day 2000-2040 (local interpreter lacks ISOWeekNum).'
$fromText=Expand-IsoWeekNum $new['lblReportFromWeek']['Properties']['Text'].TrimStart('=')
$untilText=Expand-IsoWeekNum $new['lblReportUntilWeek']['Properties']['Text'].TrimStart('=')
foreach($case in @(
 @('Date(2026,10,19)','Date(2026,10,25)','2026 KW43','2026 KW43'),
 @('Date(2020,12,28)','Date(2021,1,3)','2020 KW53','2020 KW53'),
 @('Date(2026,12,28)','Date(2027,1,3)','2026 KW53','2026 KW53'),
 @('Date(2024,12,30)','Date(2025,1,5)','2025 KW01','2025 KW01'),
 @('Date(2027,1,4)','Date(2027,1,10)','2027 KW01','2027 KW01'),
 @('Date(2026,1,5)','Date(2026,3,1)','2026 KW02','2026 KW09'),
 @('Date(2026,3,2)','Date(2026,1,11)','2026 KW10','2026 KW02'))){
 $f=$regressionEngine.Eval('With({varReportStartMonday:'+$case[0]+'},'+$fromText+')',$null,$regressionOptions).Value
 $u=$regressionEngine.Eval('With({varReportEndSunday:'+$case[1]+'},'+$untilText+')',$null,$regressionOptions).Value
 if($f -ne $case[2] -or $u -ne $case[3]){throw "Week label $($case[0])/$($case[1]): got '$f'/'$u', expected '$($case[2])'/'$($case[3])'"}
}
if($regressionEngine.Eval('With({varReportStartMonday:If(false,Date(2000,1,1))},'+$fromText+')',$null,$regressionOptions).Value -ne ''){throw 'Blank start must give empty label'}
foreach($n in @('lblReportFromWeek','lblReportUntilWeek')){$p=$new[$n]['Properties'];if($p['Align'] -ne '=Align.Right' -or $p['Font'] -ne '="Inter, Arial, sans-serif"' -or $p['FontWeight'] -ne '=FontWeight.Normal' -or $p['Size'] -ne '=12' -or $p['Color'] -ne '=ColorValue("#000000")'){throw "$n style"}}
Write-Output 'PASS week labels: YYYY KWxx with ISO year of Monday+3 (2020 KW53, 2026 KW53 across New Year, 2025 KW01 starting 30-12-2024); Till-before-From still shows both weeks; right-aligned Inter/Arial 12 black.'

# Layout inside conSummaryFiltersContent for several content widths.
$names=@('lblReportProject','ddReportProject','lblReportContractor','ddReportContractor','lblReportFrom','lblReportFromWeek','dpReportFrom','lblReportUntil','lblReportUntilWeek','dpReportUntil')
$sharedBox=@(@('lblReportFrom','lblReportFromWeek'),@('lblReportUntil','lblReportUntilWeek'))
function Measure-Selectors($contentWidth){
 $r=@{};foreach($n in $names){$r[$n]=@{X=0;Y=0;Width=0;Height=0}}
 for($pass=0;$pass -lt 5;$pass++){
  foreach($n in $names){foreach($k in @('Width','Height','X','Y')){
   $expr=$new[$n]['Properties'][$k];if(!$expr){continue}
   $ctx=($names|ForEach-Object {$_+':{X:'+$r[$_].X+',Y:'+$r[$_].Y+',Width:'+$r[$_].Width+',Height:'+$r[$_].Height+'}'}) -join ','
   $fx='With({'+$ctx+',lblSummaryFieldWidth:{Width:256},LayoutParent:{Width:'+$contentWidth+'},LayoutSelf:{X:'+$r[$n].X+',Y:'+$r[$n].Y+',Width:'+$r[$n].Width+',Height:'+$r[$n].Height+'}},'+$expr.TrimStart('=').Replace('Parent.','LayoutParent.').Replace('Self.','LayoutSelf.')+')'
   $v=$regressionEngine.Eval($fx,$null,$regressionOptions);if($v -is [Microsoft.PowerFx.Types.ErrorValue]){throw "$n.$k"};$r[$n][$k]=[double]$v.Value
  }}
 }
 $h=$new['conSummaryFiltersContent']['Properties']['Height'].TrimStart('=')
 $ctx=($names|ForEach-Object {$_+':{X:'+$r[$_].X+',Y:'+$r[$_].Y+',Width:'+$r[$_].Width+',Height:'+$r[$_].Height+'}'}) -join ','
 $r['content']=[double]$regressionEngine.Eval('With({'+$ctx+'},'+$h+')',$null,$regressionOptions).Value
 $r
}
function Test-Overlap($a,$b){($a.X -lt $b.X+$b.Width) -and ($b.X -lt $a.X+$a.Width) -and ($a.Y -lt $b.Y+$b.Height) -and ($b.Y -lt $a.Y+$a.Height)}
# Text fit of field label (left, Bold) + week label (right, Normal) in one 256 px box. Conservative upper bound, not a font measurement:
# 0.75 em per character at 12 pt (16 px) plus 2x5 px default label padding per label.
$widest=12*(9*0.75)+10 + 12*(4*0.75)+10
if($widest -ge 256){throw "Field label + week label may not fit: $widest px"}
foreach($screen in @(320,480,768,888,1024,1366,1920)){
 $content=[Math]::Max(512,$screen-80-16)
 $r=Measure-Selectors $content
 foreach($pair in @(@('lblReportProject','ddReportProject'),@('lblReportContractor','ddReportContractor'),@('lblReportFrom','dpReportFrom'),@('lblReportUntil','dpReportUntil'))){
  $l=$r[$pair[0]];$f=$r[$pair[1]];if($l.X -ne $f.X -or $l.Width -ne $f.Width -or $f.Y -ne $l.Y+$l.Height+4){throw "Label $($pair[0]) not directly above its field at $screen"}
 }
 foreach($pair in $sharedBox){$a=$r[$pair[0]];$b=$r[$pair[1]];if($a.X -ne $b.X -or $a.Y -ne $b.Y -or $a.Width -ne $b.Width -or $a.Height -ne $b.Height -or $b.Width -ne 256){throw "$($pair[1]) not in the 256 px label row of $($pair[0]) at $screen"}}
 if($r.ddReportProject.Width -ne 512 -or $r.ddReportContractor.Width -ne 512 -or $r.ddReportProject.X -ne 0 -or $r.ddReportContractor.X -ne 0){throw "Left column not fixed 512/0 at $screen"}
 if($r.dpReportFrom.Width -ne 256 -or $r.dpReportUntil.Width -ne 256 -or $r.dpReportFrom.X -ne $r.dpReportUntil.X){throw "Date pickers not equal compact width at $screen"}
 $side=$r.dpReportFrom.X -gt 0
 if($side){
  if($r.dpReportFrom.X -ne 512+24){throw "Column gap not 24 at $screen"}
  if($r.dpReportFrom.Y -ne $r.ddReportProject.Y -or $r.dpReportUntil.Y -ne $r.ddReportContractor.Y){throw "Date pickers not aligned with project/contractor at $screen"}
  if($r.dpReportFrom.X+$r.dpReportFrom.Width -gt $content){throw "Right column outside content at $screen"}
 }elseif($r.lblReportFrom.Y -lt $r.ddReportContractor.Y+$r.ddReportContractor.Height+12){throw "Stacked columns overlap at $screen"}
 for($i=0;$i -lt $names.Count;$i++){for($j=$i+1;$j -lt $names.Count;$j++){
  $shared=$false;foreach($pair in $sharedBox){if(($names[$i] -eq $pair[0] -and $names[$j] -eq $pair[1]) -or ($names[$i] -eq $pair[1] -and $names[$j] -eq $pair[0])){$shared=$true}}
  if(!$shared -and (Test-Overlap $r[$names[$i]] $r[$names[$j]])){throw "Overlap $($names[$i])/$($names[$j]) at $screen"}
 }}
 $bottom=($names|ForEach-Object {$r[$_].Y+$r[$_].Height}|Measure-Object -Maximum).Maximum
 if($r.content -lt $bottom){throw "Content height cuts off fields at $screen"}
 Write-Output ("PASS screen {0}px (content {1}px): {2}; Project/Contractor 512 at X=0, From/Till 256 at X={3}, week labels right-aligned in the 256 px label row, content height {4}px, no overlap." -f $screen,$content,$(if($side){'two columns, 24px gap'}else{'stacked, date group below Contractor'}),$r.dpReportFrom.X,$r.content)
}
Write-Output "Local source/formula/geometry checks only (text fit by conservative estimate $widest px < 256 px, not measured). ModernDatePicker import, calendar display of the picked day, Reset/OnChange timing and the real report require Studio/browser feedback."
