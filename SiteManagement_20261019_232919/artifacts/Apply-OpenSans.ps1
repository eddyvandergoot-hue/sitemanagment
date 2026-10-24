# One-time script (20 Oct 2026): app-wide Font.'Open Sans' with Normal/Semibold weights and wider buttons where Open Sans text did not fit.
# Do not rerun on a later modified source without restoring checkpoints\open-sans-20261020_235054 first.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$normal=@{
 'Screen1'=@('lblProject','lblTeam','Label2','lblSelectionLoadStatus','ddProject','ddTeam','Checkbox1','Title4')
 'scrHours'=@('lblItemTitle','lblWeekTotal','lblISOYears','lblKW','lblWeekLoadStatus','ddHoursWeek','ddHoursYear','txtMon','txtTue','txtWed','txtThu','txtFri','txtSat','txtSun')
 'scrWeeklyHours'=@('lblReportProjectDetails','lblReportStatus','lblReportProject','lblReportContractor','lblddReportStartYear','lblddReportStartWeek','lblddReportEndYear','lblddReportEndWeek','ddReportProject','ddReportContractor','ddReportStartYear','ddReportStartWeek','ddReportEndYear','ddReportEndWeek','lblReportWorkerName','lblReportWorkerEmployer','lblReportWeekHours','lblReportWorkerTotal','lblReportGrandTotal')
}
$widths=@{'Screen1'=@{'btnGotoHours'=170;'btnGotoHoursSummary'=190};'scrHours'=@{'btnWeeklyProjectTeam'=180};'scrWeeklyHours'=@{'btnRefreshReport'=110}}
$technical=@('btnBuildReport')
function Get-Block($lines,$name){
 for($i=0;$i -lt $lines.Count;$i++){if($lines[$i] -match "^(\s*)- $([regex]::Escape($name)):\s*$"){$indent=$Matches[1].Length;$j=$i+1;while($j -lt $lines.Count -and !($lines[$j] -match '^(\s*)- \S' -and $Matches[1].Length -le $indent)){$j++};return @($i,$j)}}
 throw "Control $name not found"
}
foreach($screen in @('Screen1','scrHours','scrWeeklyHours')){
 $path=Join-Path $root "Src\$screen.pa.yaml"
 $lines=[Collections.Generic.List[string]]([IO.File]::ReadAllLines($path))
 # Font on every control that already declares one, except hidden technical buttons.
 $skip=@{};foreach($t in $technical){if($screen -eq 'scrWeeklyHours'){$b=Get-Block $lines $t;for($k=$b[0];$k -lt $b[1];$k++){$skip[$k]=$true}}}
 for($k=0;$k -lt $lines.Count;$k++){if(!$skip[$k] -and $lines[$k] -match '^(\s*)Font: =(Font\.''Segoe UI''|"Montserrat, ''Segoe UI'', sans-serif")\s*$'){$lines[$k]=$Matches[1]+"Font: =Font.'Open Sans'"}}
 foreach($name in $normal[$screen]){
  $b=Get-Block $lines $name;$font=-1;$weight=-1
  for($k=$b[0];$k -lt $b[1];$k++){if($lines[$k] -match '^\s*(Font|FontWeight):'){if($Matches[1] -eq 'Font' -and $font -lt 0){$font=$k}elseif($Matches[1] -eq 'FontWeight' -and $weight -lt 0){$weight=$k}}}
  if($font -lt 0){throw "$name has no Font"}
  $indent=($lines[$font] -replace '^(\s*).*','$1')
  if($weight -ge 0){$lines[$weight]=$indent+'FontWeight: =FontWeight.Normal'}else{$lines.Insert($font+1,$indent+'FontWeight: =FontWeight.Normal')}
 }
 foreach($name in $widths[$screen].Keys){
  $b=Get-Block $lines $name;$done=$false
  for($k=$b[0];$k -lt $b[1];$k++){if($lines[$k] -match '^(\s*)Width: =\d+\s*$'){$lines[$k]=$Matches[1]+'Width: ='+$widths[$screen][$name];$done=$true;break}}
  if(!$done){throw "$name has no numeric Width"}
 }
 [IO.File]::WriteAllText($path,(($lines -join "`n")+"`n"),(New-Object Text.UTF8Encoding $false))
 Write-Output "Updated $screen"
}
