param([switch]$HistoricalDiff)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-SaveRegression.ps1')
$n=$indexes['scrWeeklyHours']

if($HistoricalDiff){
# Historical (21-10-2026): diff against checkpoint summary-labels. Fails since later commissions (dates, fonts, GEA colours, total row); kept for reference.
$backup=Join-Path $projectRoot (Get-Content (Join-Path $PSScriptRoot 'summary-labels-backup.txt') -Raw).Trim()
$old=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $backup 'Src/scrWeeklyHours.pa.yaml')));$o=@{};Index-RegressionControls $old['Screens']['scrWeeklyHours']['Children'] $o
foreach($name in @('App.pa.yaml','Screen1.pa.yaml','scrHours.pa.yaml','_EditorState.pa.yaml')){if((Get-FileHash (Join-Path $backup ('Src/'+$name))).Hash -ne (Get-FileHash (Join-Path $projectRoot ('Src/'+$name))).Hash){throw "Unexpected change $name"}}
$b=$n['btnBuildReport']['Properties']['OnSelect'].Replace('"Selecteer From en Till."','"Selecteer Van en Tot en met."').Replace('"Till ligt vóór From.','"Tot en met ligt vóór Van.')
if($b -cne $o['btnBuildReport']['Properties']['OnSelect']){throw 'btnBuildReport changed beyond the two label names in messages'}
Write-Output 'PASS historical diff against summary-labels checkpoint.'
}

if([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrWeeklyHours.pa.yaml')) -match 'lblReportIsoPeriod|lblReportGrandTotal'){throw 'Removed ISO line or floating grand total still present'}
# Project details: Number before Reference, same LookUp binding.
$d=$n['lblReportProjectDetails']['Properties']['Text']
foreach($needle in @("LookUp(","colReportProjects","ID = ddReportProject.Selected.ID","'Project Number'","'Project Reference'",'"Project Number: "','" | Project Reference: "','"Select a project."')){if(!$d.Contains($needle)){throw "Project details binding lost $needle"}}
if($d.IndexOf("'Project Number'") -gt $d.IndexOf("'Project Reference'") -or $d.IndexOf('"Project Number: "') -gt $d.IndexOf('" | Project Reference: "')){throw 'Project Number/Reference order swapped'}
foreach($pair in @(@('lblReportProject','="Project"'),@('lblReportContractor','="Contractor"'),@('lblReportFrom','="From"'),@('lblReportUntil','="Till"'))){
 $p=$n[$pair[0]]['Properties'];if($p['Text'] -ne $pair[1] -or $p['FontWeight'] -ne '=FontWeight.Bold' -or $p['Font'] -ne '="Inter, Arial, sans-serif"' -or $p['Color'] -ne '=ColorValue("#000000")'){throw "Label $($pair[0])"}
}
$p=$n['lblReportProjectDetails']['Properties'];if($p['Color'] -ne '=Color.White' -or $p['Fill'] -ne $n['lblWeeklyHoursTitle']['Properties']['Fill'] -or $p['Fill'] -ne '=ColorValue("#0303B8")' -or $p['Align'] -ne '=Align.Right' -or $p['VerticalAlign'] -ne '=VerticalAlign.Middle' -or $p['Y'] -ne '=lblWeeklyHoursTitle.Y' -or $p['Height'] -ne '=lblWeeklyHoursTitle.Height' -or $p['PaddingRight'] -ne '=24'){throw 'Title bar details style'}
$p=$n['lblReportTotalHeader']['Properties'];if($p['FontWeight'] -ne '=FontWeight.Bold' -or $p['Color'] -ne '=Color.White' -or $p['Fill'] -ne '=ColorValue("#0303B8")' -or $p['Text'] -ne '="Period total"'){throw 'Period total header'}
$p=$n['lblReportWorkerTotal']['Properties'];if($p['Fill'] -ne '=Color.Transparent' -or $p['Color'] -ne '=ColorValue("#000F41")' -or $p['Align'] -ne '=Align.Center'){throw 'Period total column style'}
Write-Output 'PASS labels: Project/Contractor/From/Till Bold black Inter/Arial; title bar Vibrant Blue with white project line (Number before Reference); Period total header Bold white on blue; column values #000F41 without fill.'

function Get-V($expr,$w,$ctx){$fx='With({'+$ctx+'LayoutParent:{Width:'+$w+'}},'+$expr.TrimStart('=').Replace('Parent.','LayoutParent.')+')';$v=$regressionEngine.Eval($fx,$null,$regressionOptions);if($v -is [Microsoft.PowerFx.Types.ErrorValue]){throw $expr};[double]$v.Value}
$t=$n['lblWeeklyHoursTitle']['Properties'];$dp=$n['lblReportProjectDetails']['Properties'];$tv=$n['lblReportTotalRowValue']['Properties'];$tr=$n['recReportTotalRow']['Properties'];$c=$n['lblReportWorkerTotal']['Properties']
foreach($w in @(320,480,600,768,1024,1366,1920)){
 $tx=Get-V $t['X'] $w '';$tw=Get-V $t['Width'] $w ''
 $ctx='lblWeeklyHoursTitle:{X:'+$tx+',Y:24,Width:'+$tw+',Height:56},'
 $dx=Get-V $dp['X'] $w $ctx;$dw=Get-V $dp['Width'] $w $ctx
 if($dx -lt $tx+$tw){throw "Details overlap title at $w"}
 if($dw -gt 0 -and $dx+$dw -ne $w-40){throw "Details not right-aligned to bar edge at $w"}
 $colRight=40+(Get-V ('='+$c['X'].TrimStart('=').Replace('scrWeeklyHours.Width',[string]$w)) $w '')+(Get-V $c['Width'] $w '')
 $valRight=(Get-V $tv['X'] $w '')+(Get-V $tv['Width'] $w '');$rowRight=(Get-V $tr['X'] $w '')+(Get-V $tr['Width'] $w '')
 if($valRight -ne $colRight -or $rowRight -ne $colRight){throw "Total row not aligned with Period total column at $w"}
 # Example text 'Project Number: 2026-0001 | Project Reference: Example reference text' measures 516 px (Inter 11pt, Measure-FontFit.ps1); 2 lines fit in 56px.
 $lines=if($dw -le 36){99}else{[Math]::Ceiling(516/($dw-36))}
 $note=if($lines -eq 1){'example project details on one line'}elseif($lines -eq 2){'example project details wrap to two lines, fits'}else{'example project details need '+$(if($lines -ge 99){'more'}else{$lines})+' lines: clipped (narrow-window limitation)'}
 Write-Output ("PASS {0}px: title 40..{1}, details {2}..{3} ({4}), no overlap; Total row and its period total end at the Period total column ({5})." -f $w,($tx+$tw),$dx,($dx+$dw),$note,$colRight)
}
Write-Output 'Local source/formula/geometry checks only. Visual result requires Studio/browser feedback.'
