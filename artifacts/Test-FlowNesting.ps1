# Test-FlowNesting: max action nesting level of every flow definition (Power Automate limit 8; import of
# "SiteManagement - Import rows" v1 failed at level 9 on 17-11-2026). Top-level actions = level 0.
# Checks flows/*.definition.json and definition.json inside artifacts/flows/*.zip and Incoming/Flows/*.zip.
# Also checks that every runAfter target is a sibling and every outputs/body/items('X') reference exists.
# ASCII only (Windows PowerShell 5.1). Exit 1 on FAIL.
param([int]$Max = 8)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path -Parent $PSScriptRoot
$fail = 0

function Get-Subs($a) {
    $subs = @()
    if ($a.PSObject.Properties['actions'] -and $a.actions) { $subs += ,$a.actions }
    if ($a.PSObject.Properties['else'] -and $a.else -and $a.else.actions) { $subs += ,$a.else.actions }
    if ($a.PSObject.Properties['default'] -and $a.default -and $a.default.actions) { $subs += ,$a.default.actions }
    if ($a.PSObject.Properties['cases'] -and $a.cases) { foreach ($c in $a.cases.PSObject.Properties) { if ($c.Value.actions) { $subs += ,$c.Value.actions } } }
    return ,$subs
}
function Get-Depth($acts, [int]$level, [System.Collections.ArrayList]$names, [System.Collections.ArrayList]$errs) {
    $m = $level
    foreach ($p in $acts.PSObject.Properties) {
        [void]$names.Add($p.Name)
        $a = $p.Value
        if ($a.PSObject.Properties['runAfter'] -and $a.runAfter) {
            foreach ($t in $a.runAfter.PSObject.Properties) { if (-not $acts.PSObject.Properties[$t.Name]) { [void]$errs.Add("runAfter " + $p.Name + " -> " + $t.Name + " (not a sibling)") } }
        }
        foreach ($s in (Get-Subs $a)) { $d = Get-Depth $s ($level + 1) $names $errs; if ($d -gt $m) { $m = $d } }
    }
    return $m
}
# Expression syntax (Eddy 19-11-2026: Mail draft import failed on the key "@odata.type"). Workflow Definition Language
# evaluates every string that starts with @ - property names included - as an expression: a literal leading @ must be
# written @@. Checked here: keys and values starting with @ (not @@) must be @{...} or @<function>(...), and every
# expression (whole value or @{...} part) has balanced parentheses/brackets and single quotes ('' = escaped quote).
function Test-ExprBalance([string]$e) {
    $d = 0; $inQ = $false
    for ($i = 0; $i -lt $e.Length; $i++) {
        $c = $e[$i]
        if ($inQ) { if ($c -eq "'") { if ($i + 1 -lt $e.Length -and $e[$i + 1] -eq "'") { $i++ } else { $inQ = $false } }; continue }
        if ($c -eq "'") { $inQ = $true } elseif ($c -eq '(' -or $c -eq '[') { $d++ } elseif ($c -eq ')' -or $c -eq ']') { $d--; if ($d -lt 0) { return $false } }
    }
    return (-not $inQ) -and ($d -eq 0)
}
function Test-ExprString([string]$s, [string]$where, [System.Collections.ArrayList]$errs) {
    if ($s.StartsWith('@') -and -not $s.StartsWith('@@') -and -not $s.StartsWith('@{')) {
        if ($s -notmatch '^@[A-Za-z_][A-Za-z0-9_]*\(') { [void]$errs.Add("invalid expression at " + $where + ": '" + $s.Substring(0, [Math]::Min(60, $s.Length)) + "' (literal leading @ must be @@)") }
        elseif (-not (Test-ExprBalance $s.Substring(1))) { [void]$errs.Add("unbalanced expression at " + $where) }
    }
    $i = 0
    while (($i = $s.IndexOf('@{', $i)) -ge 0) {
        if ($i -gt 0 -and $s[$i - 1] -eq '@') { $i += 2; continue }
        $d = 0; $inQ = $false; $end = -1
        for ($k = $i + 1; $k -lt $s.Length; $k++) {
            $c = $s[$k]
            if ($inQ) { if ($c -eq "'") { if ($k + 1 -lt $s.Length -and $s[$k + 1] -eq "'") { $k++ } else { $inQ = $false } }; continue }
            if ($c -eq "'") { $inQ = $true } elseif ($c -eq '{') { $d++ } elseif ($c -eq '}') { $d--; if ($d -eq 0) { $end = $k; break } }
        }
        if ($end -lt 0) { [void]$errs.Add("unclosed @{ at " + $where); break }
        if (-not (Test-ExprBalance $s.Substring($i + 2, $end - $i - 2))) { [void]$errs.Add("unbalanced @{...} at " + $where) }
        $i = $end + 1
    }
}
function Test-Exprs($node, [string]$path, [System.Collections.ArrayList]$errs) {
    if ($null -eq $node) { return }
    if ($node -is [string]) { Test-ExprString $node $path $errs; return }
    if ($node -is [System.Array]) { $n = 0; foreach ($x in $node) { Test-Exprs $x ($path + '[' + $n + ']') $errs; $n++ }; return }
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $node.PSObject.Properties) {
            if ($p.Name.StartsWith('@') -and -not $p.Name.StartsWith('@@')) { [void]$errs.Add("key '" + $p.Name + "' at " + $path + " starts with @: write @@ for a literal @") }
            Test-Exprs $p.Value ($path + '/' + $p.Name) $errs
        }
    }
}
function Test-Definition([string]$label, [string]$json) {
    $d = $json | ConvertFrom-Json
    $def = $d.properties.definition
    $names = New-Object System.Collections.ArrayList
    $errs = New-Object System.Collections.ArrayList
    Test-Exprs $def.actions 'actions' $errs
    Test-Exprs $def.triggers 'triggers' $errs
    $depth = Get-Depth $def.actions 0 $names $errs
    foreach ($tr in $def.triggers.PSObject.Properties) { [void]$names.Add($tr.Name) }
    $refs = [regex]::Matches($json, "(?:outputs|body|items|actions|result)\('([^']+)'\)") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    foreach ($r in $refs) { if ($names -notcontains $r) { [void]$errs.Add("reference to unknown action '" + $r + "'") } }
    $ok = ($depth -le $Max) -and ($errs.Count -eq 0)
    $tag = if ($ok) { 'PASS' } else { 'FAIL' }
    Write-Output ("{0}  {1}: nesting {2} (max {3}), {4} actions" -f $tag, $label, $depth, $Max, $names.Count)
    foreach ($e in $errs) { Write-Output ("      " + $e) }
    if (-not $ok) { $script:fail++ }
}

$count = 0
Get-ChildItem (Join-Path $root 'flows') -Filter '*.definition.json' -ErrorAction SilentlyContinue | ForEach-Object {
    Test-Definition ("flows/" + $_.Name) ([IO.File]::ReadAllText($_.FullName)); $count++
}
foreach ($dir in @((Join-Path $root 'artifacts\flows'), (Join-Path $root 'Incoming\Flows'))) {
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem $dir -Filter '*.zip' | ForEach-Object {
        $z = [IO.Compression.ZipFile]::OpenRead($_.FullName)
        try {
            foreach ($e in $z.Entries) {
                if ($e.FullName -like '*/definition.json') {
                    $sr = New-Object IO.StreamReader($e.Open(), [Text.Encoding]::UTF8)
                    $txt = $sr.ReadToEnd(); $sr.Close()
                    Test-Definition ((Split-Path $dir -Leaf) + "/" + $_.Name) $txt; $count++
                }
            }
        } finally { $z.Dispose() }
    }
}
if ($count -eq 0) { Write-Output 'FAIL  no flow definitions found'; exit 1 }
if ($fail -gt 0) { Write-Output ("Test-FlowNesting: {0} FAIL" -f $fail); exit 1 }
Write-Output ("Test-FlowNesting: all PASS ({0} definitions)" -f $count)
