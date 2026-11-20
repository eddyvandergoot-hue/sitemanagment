# Test-ControlProperties.ps1 (Eddy 20-11-2026): catches Studio import error PA2108 "Unknown property 'X' for control type 'T'" before pack.
# Build v1.0.2-20261120_000059 failed on Classic/ComboBox@2.4.0 SearchItems: the property exists in the control template but is not
# settable in SourceCode YAML. A template property list therefore proves nothing; this check uses PROOF instead:
#   a property is allowed on a control type (incl. version) only when it was set on that type in a build Studio imported without errors
#   (git refs in artifacts/studio-proven.txt) or in Src written by Studio itself (only the Incoming\*.msapp files listed as incoming:<name>).
# documented:<Control@version> <Learn URL> <props> lines (Eddy 20-11-2026: check Microsoft Learn first) add properties that are on the Learn page
#   AND declared settable in the .msapr Templates.json of that exact version (not hidden="true" - Classic ComboBox SearchItems is hidden -, not direction="out").
# LIMIT: checks property NAMES per control type/version only; not formula references to hidden properties, not binding or PA2231.
# Canvas component instances are checked by Check-WeeklySource (custom properties). FAIL = unproven property or unproven control type;
# fix: use a proven property, or let Eddy import a small test build and add its ref to studio-proven.txt. ASCII only, PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$pacDir = Split-Path (Get-Command pac).Source
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'YamlDotNet.dll')) | Out-Null
$des = (New-Object YamlDotNet.Serialization.DeserializerBuilder).Build()
$fails = 0
function Check($cond, $label) { if ($cond) { Write-Output "PASS $label" } else { Write-Output "FAIL $label"; $script:fails++ } }

function Add-Controls($node, $map, [string]$src) {
    if ($node -is [System.Collections.IDictionary]) {
        foreach ($k in @($node.Keys)) {
            $v = $node[$k]
            if ($v -is [System.Collections.IDictionary] -and $v.ContainsKey('Control')) {
                $t = [string]$v['Control']
                if ($t -ne 'CanvasComponent') {
                    if (-not $map.ContainsKey($t)) { $map[$t] = @{} }
                    if ($v.ContainsKey('Properties') -and $v['Properties']) { foreach ($p in @($v['Properties'].Keys)) { if (-not $map[$t].ContainsKey([string]$p)) { $map[$t][[string]$p] = "$src ($k)" } } }
                    if ($v.ContainsKey('Variant')) { $map[$t]['@Variant:' + [string]$v['Variant']] = $src }
                }
            }
            Add-Controls $v $map $src
        }
    } elseif ($node -is [System.Collections.IList]) { foreach ($x in $node) { Add-Controls $x $map $src } }
}

# 1) proven property sets
$proven = @{}
$lines = @(Get-Content (Join-Path $PSScriptRoot 'studio-proven.txt') | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object { ($_ -split '\s+')[0] })
$refs = @($lines | Where-Object { -not $_.StartsWith('incoming:') -and -not $_.StartsWith('documented:') }); $trusted = @($lines | Where-Object { $_.StartsWith('incoming:') } | ForEach-Object { $_.Substring(9) })
Check ($refs.Count -gt 0) "studio-proven.txt lists $($refs.Count) Studio-imported build(s)"
Push-Location $projectRoot
try {
    foreach ($r in $refs) {
        $files = @(git ls-tree -r --name-only $r -- Src | Where-Object { $_ -like '*.pa.yaml' })
        Check ($files.Count -gt 0) "proven ref $r has Src files ($($files.Count))"
        foreach ($f in $files) { $txt = (git show "${r}:$f") -join "`n"; Add-Controls ($des.Deserialize([string]$txt)) $proven "$r/$f" }
    }
} finally { Pop-Location }
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Web.Extensions
$inc = Join-Path $projectRoot 'Incoming'
$studioFiles = 0
if (Test-Path $inc) {
    foreach ($m in Get-ChildItem $inc -Filter *.msapp | Where-Object { $trusted -contains $_.Name }) {
        $z = [IO.Compression.ZipFile]::OpenRead($m.FullName)
        try {
            foreach ($e in $z.Entries) {
                $n = $e.FullName.Replace('\', '/')
                if ($n -like 'Src/*.pa.yaml') { $sr = New-Object IO.StreamReader($e.Open()); $txt = $sr.ReadToEnd(); $sr.Close(); Add-Controls ($des.Deserialize([string]$txt)) $proven "$($m.Name)/$n"; $studioFiles++ }
            }
        } finally { $z.Dispose() }
    }
}
# documented properties: each must be settable in the .msapr template of that exact control version
$docLines = @(Get-Content (Join-Path $PSScriptRoot 'studio-proven.txt') | Where-Object { $_.StartsWith('documented:') })
$aprZ = [IO.Compression.ZipFile]::OpenRead((Join-Path $projectRoot 'Site Managment_VS.msapr'))
try { $te = @($aprZ.Entries | Where-Object { $_.FullName.Replace('\', '/') -eq 'msapp/References/Templates.json' })[0]; $sr = New-Object IO.StreamReader($te.Open()); $tplJson = $sr.ReadToEnd(); $sr.Close() } finally { $aprZ.Dispose() }
$tpls = (New-Object System.Web.Script.Serialization.JavaScriptSerializer -Property @{ MaxJsonLength = 2147483647 }).DeserializeObject($tplJson)['UsedTemplates']
$docCount = 0
foreach ($dl in $docLines) {
    $parts = $dl -split '\s+'
    $ctl = $parts[0].Substring(11); $url = $parts[1]; $props = @($parts[2] -split ',')
    Check ($url -like 'https://learn.microsoft.com/*') "documented $ctl cites a Microsoft Learn page ($url)"
    $tn = ($ctl -split '@')[0]; $tn = ($tn -split '/')[-1]; $tv = ($ctl -split '@')[1]
    $tp = @($tpls | Where-Object { $_['Name'] -ieq $tn -and $_['Version'] -eq $tv })
    Check ($proven.ContainsKey($ctl)) "documented $ctl control type itself was saved or imported by Studio (listed source)"
    Check ($tp.Count -eq 1) "documented $ctl has its template in the .msapr Templates.json"
    if ($tp.Count -ne 1) { continue }
    $x = [string]$tp[0]['Template']
    $hiddenStart = $x.IndexOf('<!--Hidden properties')
    $bad = New-Object System.Collections.ArrayList
    foreach ($p in $props) {
        $m = [regex]::Match($x, '<property name="' + [regex]::Escape($p) + '"[^>]*>')
        $mi = [regex]::Match($x, '<appMagic:includeProperty name="' + [regex]::Escape($p) + '"[^>]*/>')
        $ok = ($m.Success -and $m.Value -notmatch 'hidden="true"' -and $m.Value -notmatch 'direction="out"') -or ($mi.Success -and $mi.Value -notmatch 'hidden="true"' -and ($hiddenStart -lt 0 -or $mi.Index -lt $hiddenStart))
        if ($ok) { if (-not $proven.ContainsKey($ctl)) { $proven[$ctl] = @{} }; if (-not $proven[$ctl].ContainsKey($p)) { $proven[$ctl][$p] = "documented $url" }; $docCount++ } else { [void]$bad.Add($p) }
    }
    Check ($bad.Count -eq 0) "documented $ctl properties are settable in the template (not hidden, not output)$(if ($bad.Count) { ' - not settable: ' + ($bad -join ', ') })"
}
Check (@($trusted | Where-Object { -not (Test-Path (Join-Path $inc $_)) }).Count -eq 0) "every listed Studio-saved Incoming file exists ($($trusted -join '; '))"
Write-Output "INFO proven sources: $($refs.Count) git ref(s) + $studioFiles Studio-written Src file(s) from $($trusted.Count) listed Incoming file(s) + $docCount documented template propert(ies); $($proven.Count) control types"

# 2) current Src
$script:unprovenTypes = New-Object System.Collections.ArrayList
$script:unprovenProps = New-Object System.Collections.ArrayList
$script:checked = 0
foreach ($f in Get-ChildItem (Join-Path $projectRoot 'Src') -Recurse -Filter *.pa.yaml) {
    function Walk($node, [string]$file) {
        if ($node -is [System.Collections.IDictionary]) {
            foreach ($k in @($node.Keys)) {
                $v = $node[$k]
                if ($v -is [System.Collections.IDictionary] -and $v.ContainsKey('Control') -and [string]$v['Control'] -ne 'CanvasComponent') {
                    $t = [string]$v['Control']
                    if (-not $proven.ContainsKey($t)) { [void]$script:unprovenTypes.Add("$file $k ($t)") }
                    else {
                        if ($v.ContainsKey('Properties') -and $v['Properties']) { foreach ($p in @($v['Properties'].Keys)) { if (-not $proven[$t].ContainsKey([string]$p)) { [void]$script:unprovenProps.Add("$file $k.$p ($t)") } } }
                        if ($v.ContainsKey('Variant') -and -not $proven[$t].ContainsKey('@Variant:' + [string]$v['Variant'])) { [void]$script:unprovenProps.Add("$file $k Variant $($v['Variant']) ($t)") }
                    }
                    $script:checked++
                }
                Walk $v $file
            }
        } elseif ($node -is [System.Collections.IList]) { foreach ($x in $node) { Walk $x $file } }
    }
    Walk ($des.Deserialize([string][IO.File]::ReadAllText($f.FullName))) $f.Name
}
Check ($script:unprovenTypes.Count -eq 0) "every control type in Src was imported by Studio before (proven)$(if ($script:unprovenTypes.Count) { ' - unproven: ' + ($script:unprovenTypes -join '; ') })"
Check ($script:unprovenProps.Count -eq 0) "every property set in Src is proven for its control type and version ($($script:checked) controls; PA2108 class)$(if ($script:unprovenProps.Count) { ' - unproven: ' + ($script:unprovenProps -join '; ') })"
if ($fails -gt 0) { Write-Output "Test-ControlProperties: $fails FAIL"; exit 1 }
Write-Output 'Test-ControlProperties: all PASS (proves only that the properties were accepted by Studio before; not binding or behaviour)'
