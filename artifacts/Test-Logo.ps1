# GEA logo rule (26-10-2026): one Image@2.2.3 per screen in the 56 px title bar, official white SVG inside the .msapr.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-SaveRegression.ps1')
function Flat-Children($entries){foreach($e in $entries){$e;Flat-Children $e[@($e.Keys)[0]]['Children']}}
$svgText=[IO.File]::ReadAllText((Join-Path $projectRoot 'Assets\GEA_logo_white.svg'))
if($svgText -notmatch 'viewBox="0 0 ([0-9.]+) ([0-9.]+)"'){throw 'SVG viewBox not found'}
$svgAspect=[double]::Parse($Matches[1],[Globalization.CultureInfo]::InvariantCulture)/[double]::Parse($Matches[2],[Globalization.CultureInfo]::InvariantCulture)
$cfg=@(@('Screen1','lblProjectTeamTitle','imgLogoScreen1'),@('scrHours','lblWeeklyHoursEntryTitle','imgLogoHours'),@('scrWeeklyHours','lblWeeklyHoursTitle','imgLogoSummary'))
foreach($c in $cfg){
 $screen,$title,$logo=$c
 $doc=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot ('Src/'+$screen+'.pa.yaml'))))
 $order=@(Flat-Children $doc['Screens'][$screen]['Children'] | ForEach-Object {@($_.Keys)[0]})
 $imgs=@($indexes[$screen].Keys | Where-Object {$indexes[$screen][$_]['Control'] -like 'Image@*'})
 if($imgs.Count -ne 1 -or $imgs[0] -ne $logo){throw "$screen : expected exactly one Image ($logo), found $($imgs -join ',')"}
 $i=$indexes[$screen][$logo];$p=$i['Properties'];$t=$indexes[$screen][$title]['Properties']
 if($i['Control'] -ne 'Image@2.2.3'){throw "$screen logo control $($i['Control'])"}
 if($p['Image'] -ne '=GEA_logo_white'){throw "$screen Image"}
 if($p['ImagePosition'] -ne '=ImagePosition.Fit'){throw "$screen ImagePosition"}
 if($p['Height'] -ne '=30' -or $p['Width'] -ne '=99'){throw "$screen size"}
 if([Math]::Abs(([double]$p['Width'].TrimStart('='))/([double]$p['Height'].TrimStart('='))-$svgAspect) -gt 0.02){throw "$screen aspect differs from the SVG viewBox ($svgAspect)"}
 foreach($bad in 'Fill','OnSelect'){if($p.ContainsKey($bad)){throw "$screen logo has $bad"}}
 if($p['X'] -ne "=$title.X+15"){throw "$screen X formula"}
 if($p['Y'] -ne "=$title.Y+($title.Height-Self.Height)/2"){throw "$screen Y formula"}
 if($t['Height'] -ne '=56' -or $t['Y'] -ne '=24' -or $t['X'] -ne '=40'){throw "$screen title geometry"}
 if($t['Fill'] -ne '=ColorValue("#0303B8")'){throw "$screen title fill"}
 if($t['PaddingLeft'] -ne '=129'){throw "$screen title PaddingLeft (needs 15+99+15)"}
 if($order.IndexOf($logo) -ne $order.IndexOf($title)+1){throw "$screen logo must directly follow the title in Children (above it)"}
 Write-Output "PASS $screen : $logo Image@2.2.3 99x30 Fit, X=title+15, centred in 56 px bar (13 px top/bottom), title PaddingLeft 129 (text starts 15 px after logo), directly after title."
}
$w=[double]($indexes['scrWeeklyHours']['lblWeeklyHoursTitle']['Properties']['Width'].TrimStart('='))
if($w -lt 129+235+16){throw "Hours Summary title too narrow ($w)"}
Write-Output "PASS lblWeeklyHoursTitle Width $w >= 129 + 235 (Inter/Arial worst case 22 pt Semibold) + 16."
# msapr
Add-Type -AssemblyName System.IO.Compression.FileSystem
$msapr=Join-Path $projectRoot 'Site Managment_VS.msapr'
$ref=(Get-FileHash (Join-Path $projectRoot 'Assets\GEA_logo_white.svg') -Algorithm SHA256).Hash
if($ref -ne '5D460376D030AF075E004E50191C8BE0C8DB05C5E0A9E593F53612DA52606087'){throw "Assets/GEA_logo_white.svg changed: $ref"}
$zip=[IO.Compression.ZipFile]::OpenRead($msapr)
try{
 $svgs=@($zip.Entries | Where-Object {$_.FullName -replace '/','\' -like 'msapp\Assets\Images\*.svg' -or $_.FullName -replace '/','\' -like 'Assets\Images\*.svg'})
 if(-not $svgs){throw 'no Assets/Images svg in msapr'}
 $match=$false
 foreach($e in $svgs){$s=$e.Open();$sha=[Security.Cryptography.SHA256]::Create();$h=([BitConverter]::ToString($sha.ComputeHash($s))).Replace('-','');$s.Dispose();if($h -eq $ref){$match=$true}}
 if(-not $match){throw 'no svg in msapr equals the official GEA_logo_white.svg'}
 $bad=@($zip.Entries | Where-Object {$_.Name -match '\.(ai|eps|pdf)$' -or $_.Name -match 'Claim'});if($bad){throw "claim/print logo in msapr: $($bad.FullName -join ',')"}
 $res=$zip.Entries | Where-Object {$_.Name -eq 'Resources.json'} | Select-Object -First 1
 $r=New-Object IO.StreamReader($res.Open());$txt=$r.ReadToEnd();$r.Dispose()
 $j=$txt|ConvertFrom-Json
 $it=@($j.Resources | Where-Object {$_.Name -eq 'GEA_logo_white'})
 if($it.Count -ne 1 -or $it[0].ResourceKind -ne 'LocalFile' -or $it[0].Content -ne 'Image'){throw 'Resources.json GEA_logo_white entry'}
 # The resource must point at the svg that carries the official hash (not just any svg).
 if($it[0].Path -ne ('Assets\Images\'+$it[0].FileName)){throw "Resources.json Path/FileName mismatch: $($it[0].Path) vs $($it[0].FileName)"}
 $target=@($svgs | Where-Object {($_.FullName -replace '/','\') -like ('*\'+$it[0].FileName)})
 if($target.Count -ne 1){throw "Resources.json GEA_logo_white points at $($it[0].FileName), which is not exactly one svg in the msapr"}
 $s=$target[0].Open();$sha=[Security.Cryptography.SHA256]::Create();$th=([BitConverter]::ToString($sha.ComputeHash($s))).Replace('-','');$s.Dispose()
 if($th -ne $ref){throw "svg referenced by GEA_logo_white is not the official logo ($th)"}
 foreach($e in $zip.Entries){if($e.Length -gt 0 -and $e.Length -lt 5MB -and $e.Name -match '\.(json|xml|yaml|svg|txt)$'){$r=New-Object IO.StreamReader($e.Open());$x=$r.ReadToEnd();$r.Dispose();if($x -match 'sig=|skoid|sktid|\?sv='){throw "signed-URL material in $($e.FullName)"}}}
}finally{$zip.Dispose()}
Write-Output 'PASS msapr: svg identical to Assets/GEA_logo_white.svg, Resources.json GEA_logo_white (LocalFile/Image), no signed-URL material, no .ai/.eps/.pdf/claim file.'
Write-Output 'Not verified locally: SVG rendering and title clipping (Studio/browser).'
