param([Parameter(Mandatory)][string]$InterDir,[string]$ArialDir=(Join-Path $env:WINDIR 'Fonts'))
# Measures text widths from TrueType advance widths (cmap format 4 + hmtx); no font is installed or loaded.
# Size is in points (px = pt * 96/72). Kerning is ignored, which adds a 3% safety margin.
$ErrorActionPreference='Stop'
function Read-U16($b,$o){[int]$b[$o]*256+$b[$o+1]}
function Read-U32($b,$o){[long](Read-U16 $b $o)*65536+(Read-U16 $b ($o+2))}
function Read-Font($path){
 $b=[IO.File]::ReadAllBytes($path);$tables=@{};$n=Read-U16 $b 4
 for($i=0;$i -lt $n;$i++){$r=12+16*$i;$tag=[Text.Encoding]::ASCII.GetString($b,$r,4);$tables[$tag]=Read-U32 $b ($r+8)}
 $upm=Read-U16 $b ($tables['head']+18);$numH=Read-U16 $b ($tables['hhea']+34)
 $adv=New-Object 'int[]' $numH;for($i=0;$i -lt $numH;$i++){$adv[$i]=Read-U16 $b ($tables['hmtx']+4*$i)}
 $cmap=$tables['cmap'];$sub=$null
 for($i=0;$i -lt (Read-U16 $b ($cmap+2));$i++){$r=$cmap+4+8*$i;$platform=Read-U16 $b $r;$eid=Read-U16 $b ($r+2);$off=$cmap+(Read-U32 $b ($r+4));if((Read-U16 $b $off) -eq 4 -and ($platform -eq 3 -and $eid -eq 1 -or $platform -eq 0)){$sub=$off;break}}
 $seg=(Read-U16 $b ($sub+6))/2;$map=@{}
 for($s=0;$s -lt $seg;$s++){
  $end=Read-U16 $b ($sub+14+2*$s);$start=Read-U16 $b ($sub+16+2*$seg+2*$s);$delta=Read-U16 $b ($sub+16+4*$seg+2*$s);$roOff=$sub+16+6*$seg+2*$s;$ro=Read-U16 $b $roOff
  if($start -gt 0x24F){continue}
  for($c=$start;$c -le [Math]::Min($end,0x24F);$c++){
   if($ro -eq 0){$g=($c+$delta) % 65536}else{$g=Read-U16 $b ($roOff+$ro+2*($c-$start));if($g -ne 0){$g=($g+$delta) % 65536}}
   $map[$c]=$g
  }
 }
 @{Upm=$upm;Adv=$adv;Map=$map}
}
function Measure-Text($font,$text,$pt){$u=0;foreach($ch in $text.ToCharArray()){$g=$font.Map[[int]$ch];if($null -eq $g){$g=0};$u+=$font.Adv[[Math]::Min($g,$font.Adv.Length-1)]};[Math]::Round($u/$font.Upm*$pt*96/72*1.03,1)}
# GEA typography (22-10-2026): Font = "Inter, Arial, sans-serif". Inter where installed, Arial as GEA fallback.
# Arial has no 600 weight; browsers then render Semibold with Arial Bold, so Semibold is measured with arialbd.ttf.
$fonts=@{
 'IN.Normal'=Read-Font (Join-Path $InterDir 'Inter-Regular.ttf');'IN.Semibold'=Read-Font (Join-Path $InterDir 'Inter-SemiBold.ttf');'IN.Bold'=Read-Font (Join-Path $InterDir 'Inter-Bold.ttf')
 'AR.Normal'=Read-Font (Join-Path $ArialDir 'arial.ttf');'AR.Semibold'=Read-Font (Join-Path $ArialDir 'arialbd.ttf');'AR.Bold'=Read-Font (Join-Path $ArialDir 'arialbd.ttf')
}
# Name, text, pt, weight (Normal/Semibold/Bold), available content width in px (control width minus padding).
$cases=@(
 @('Screen1.btnGotoHours','Weekly Hours',14,'Semibold',(170-32)),
 @('Screen1.btnAddtoTeam','Save team',14,'Semibold',(160-32)),@('Screen1.btnAddtoTeam','Saving...',14,'Semibold',(160-32)),
 @('Screen1.btnGotoHoursSummary','Hours Summary',14,'Semibold',(190-32)),
 @('Screen1.btnRefreshTeam','Refresh',14,'Semibold',(110-32)),
 @('scrHours.btnWeeklyProjectTeam','Project / team',14,'Semibold',(180-32)),
 @('scrHours.btnRefreshWeek','Refresh',14,'Semibold',(110-32)),
 @('scrHours.btnDiscardWeek','Discard changes',14,'Semibold',(188-32)),
 @('scrHours.btnSaveWeek','Saving...',14,'Semibold',(140-32)),
 @('scrWeeklyHours.btnSummaryProjectTeam','Project / team',14,'Semibold',(180-32)),
 @('scrWeeklyHours.btnRefreshReport','Refresh',14,'Semibold',(110-32)),
 @('scrWeeklyHours.btnReportPreviousWeeks','<',14,'Semibold',(48-32)),
 @('scrWeeklyHours.btnReportNextWeeks','>',14,'Semibold',(48-32)),
 @('scrHours.btnSaveWeek','Save',14,'Semibold',(140-32)),
 @('scrWeeklyHours.lblReportFromWeek (beside Bold "From", 256 box)','2026 KW53',12,'Normal',(256-10-10-48)),
 @('scrWeeklyHours.lblReportUntilWeek (beside Bold "Till", 256 box)','2026 KW53',12,'Normal',(256-10-10-48)),
 @('Screen1.lblProjectTeamTitle @320','Project / team',22,'Semibold',(320-80-16-5)),
 @('scrHours.lblWeeklyHoursEntryTitle @320','Weekly Hours',22,'Semibold',(320-80-16-5)),
 @('scrWeeklyHours.lblWeeklyHoursTitle @320','Hours Summary',22,'Semibold',(320-80-16-5)),
 @('Screen1.lblProject','Project',12,'Normal',(100-10)),@('Screen1.lblTeam','Team',12,'Normal',(100-10)),
 @('Screen1.Label2 @768','Geselecteerd: 500',13,'Normal',(768-280-10)),
 @('Screen1.lblSelectionLoadStatus @1024','Nog niet geladen. Opslaan geblokkeerd; kies project en team.',11,'Normal',(1024-80-10)),
 @('Screen1.lblSelectionLoadStatus @1024','Projecten, teamkeuzes en bestaande koppelingen ophalen...',11,'Normal',(1024-80-10)),
 @('scrHours.lblHoursWeek','Week',13,'Normal',(256-10)),@('scrHours.lblHoursWeekKW (beside picker, 120px)','2026 KW53',12,'Normal',(120-10)),
 @('scrHours.lblHeaderWorker','Worker',12,'Semibold',(270-10)),@('scrHours.lblHeaderTotal','Total',12,'Semibold',(80-10)),
 @('scrHours.lblHeaderWed @1024 (line)','Wed',11,'Semibold',((1024-80-390)/7-8-10)),@('scrHours.lblHeaderWed @1024 (line)','28-12',11,'Semibold',((1024-80-390)/7-8-10)),
 @('scrHours.lblHeaderWed @768 (line)','Wed',11,'Semibold',((768-80-390)/7-8-10)),@('scrHours.lblHeaderWed @768 (line)','28-12',11,'Semibold',((768-80-390)/7-8-10)),
 @('scrHours.lblWeekTotal','168.5',12,'Normal',(80-10)),
 @('scrHours.txtMon @1024','10.5',12,'Normal',((1024-80-390)/7-8-8)),@('scrHours.txtMon @768','10.5',12,'Normal',((768-80-390)/7-8-8)),
 @('scrHours.lblWeekLoadStatus @1024','Nog niet geladen. Kies project, team, ISO-jaar en KW; opslaan geblokkeerd.',11,'Normal',(1024-80-10)),
 @('scrHours.lblWeekLoadStatus @1024','Opgeslagen week ophalen; vorige invoer blijft behouden tot laden slaagt...',11,'Normal',(1024-80-10)),
 @('scrHours.dpHoursWeek (text + calendar icon)','28-12-2026',12,'Normal',(256-12-40)),
 @('scrWeeklyHours.lblReportNameHeader','Name',11,'Semibold',(220-8-5)),
 @('scrWeeklyHours.lblReportEmployerHeader','Contractor',11,'Semibold',(180-10)),
 @('scrWeeklyHours.lblReportTotalHeader','Period total',11,'Bold',(120-10)),
 @('scrWeeklyHours.lblReportWeekHeader @1920 (94px)','2026 KW53',10,'Semibold',(94.3)),
 @('scrWeeklyHours.lblReportWeekHeader min 90px','2026 KW53',10,'Semibold',(90)),
 @('scrWeeklyHours.lblReportWeekHeader @650 (50px)','2026 KW53',10,'Semibold',(50)),
 @('scrWeeklyHours.lblReportWeekHours min 90px','168,25',11,'Normal',(90-10)),
 @('scrWeeklyHours.lblReportWorkerTotal','12345,25',11,'Bold',(120-10)),
 @('scrWeeklyHours.lblReportProject','Project',12,'Bold',(512-10)),
 @('scrWeeklyHours.lblReportFrom','From',12,'Bold',(256-10)),
 @('scrWeeklyHours.lblReportUntil','Till',12,'Bold',(256-10)),
 @('scrWeeklyHours.dpReportFrom (text + calendar icon)','28-12-2026',12,'Normal',(256-12-40)),
 @('scrWeeklyHours.lblReportContractor','Contractor',12,'Bold',(512-10)),
 @('scrWeeklyHours.ddReportContractor','Alle contractors',12,'Normal',(512-10-40)),
 @('scrWeeklyHours.lblReportTotalRowLabel','Total',11,'Bold',(220-8-5)),@('scrWeeklyHours.lblReportTotalRowValue','123456,25',11,'Bold',(120-10)),@('scrWeeklyHours.lblReportTotalWeekHours min 90px','12345,25',11,'Bold',(90-10)),
 @('scrWeeklyHours.lblWeeklyHoursTitle (280px)','Hours Summary',22,'Semibold',(280-16-5)),
 @('scrWeeklyHours.lblReportStatus @1024','Geen opgeslagen uren voor dit project; actieve medewerkers staan op 0.',11,'Normal',(1024-80-10)),
 @('scrWeeklyHours.lblReportStatus @768','Geen opgeslagen uren voor dit project; actieve medewerkers staan op 0.',11,'Normal',(768-80-10)),
 @('scrWeeklyHours.lblReportProjectDetails title bar @1366 (example)','Project Number: 2026-0001 | Project Reference: Example reference text',11,'Normal',(1366-80-280-12-24)),
 @('scrWeeklyHours.lblReportProjectDetails title bar @1024 (example)','Project Number: 2026-0001 | Project Reference: Example reference text',11,'Normal',(1024-80-280-12-24)),
 @('scrWeeklyHours.lblReportProjectDetails title bar @768 (one line)','Project Number: 2026-0001 | Project Reference: Example reference text',11,'Normal',(768-80-280-12-24))
)
$fail=0
foreach($c in $cases){
 $in=Measure-Text $fonts["IN.$($c[3])"] $c[1] $c[2];$ar=Measure-Text $fonts["AR.$($c[3])"] $c[1] $c[2];$avail=[Math]::Round($c[4],1)
 $worst=[Math]::Max($in,$ar);$state=if($worst -le $avail){'FITS'}else{$fail++;'OVERFLOW'}
 '{0,-9} {1,-62} "{2}" {3}pt {4}: Inter {5}px / Arial {6}px / available {7}px' -f $state,$c[0],$c[1],$c[2],$c[3],$in,$ar,$avail
}
"Overflows (worst of Inter and Arial): $fail"