# Test-CollectionColumns.ps1 - every column used on a collection exists in that collection's schema (Eddy 14-11-2026, after
# the Studio import of build c4: 'Pos'/'DayIndex'/'HourID' not recognized in SortByColumns in cmpWrFooter.OnExport).
# (A) Schema: per collection the union of the record fields of every ClearCollect/Collect in Src (record literals, ForAll/With
#     bodies, Table(...), copies of other collections, Filter/Sort/FirstN/... of a collection, AddColumns/ShowColumns/
#     DropColumns/RenameColumns, Distinct/Sequence = Value). A definition that cannot be resolved locally (e.g. a SharePoint read)
#     makes the collection "open": it is not checked and is listed.
# (B) Uses: SortByColumns/Filter/LookUp/CountIf/Sort/Sum/ForAll whose first argument is a collection (optionally "As alias"):
#     SortByColumns column identifiers, bare field names and alias.Field in the formulas must be in the schema.
# (C) Conservative project rule: SortByColumns only on a plain collection/data source name. Observed once (c4 import, Filter(... As f)
#     as first argument: column identifiers not recognized; root cause unknown). Use Sort(table, formula key) instead.
# Names never checked as columns: control/screen/component names, named formulas, enum roots, all aliases (As x) and With names
# in the app; a column with the same name as one of those is not reported. 'Open' collections are not checked at all.
# LIMIT: local text analysis, no Power Fx binder; it proves nothing about Studio binding (Studio import stays the acceptance check).
# ASCII-only, PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$fails = 0
function Check($cond, $label) { if ($cond) { Write-Output "PASS $label" } else { Write-Output "FAIL $label"; $script:fails++ } }

# ---- text helpers -------------------------------------------------------------------------------------------------------
function Remove-Strings([string]$t) { [regex]::Replace($t, '"(?:[^"]|"")*"', '""') }
function Get-Close([string]$t, [int]$open) {
    # index of the bracket closing the one at $open; -1 if unbalanced
    $d = 0; $q = $false
    for ($i = $open; $i -lt $t.Length; $i++) {
        $c = $t[$i]
        if ($c -eq "'") { $q = -not $q; continue }
        if ($q) { continue }
        if ($c -eq '(' -or $c -eq '{' -or $c -eq '[') { $d++ } elseif ($c -eq ')' -or $c -eq '}' -or $c -eq ']') { $d--; if ($d -eq 0) { return $i } }
    }
    return -1
}
function Split-Top([string]$t) {
    # split on top-level commas
    $out = New-Object System.Collections.Generic.List[string]; $d = 0; $q = $false; $start = 0
    for ($i = 0; $i -lt $t.Length; $i++) {
        $c = $t[$i]
        if ($c -eq "'") { $q = -not $q; continue }
        if ($q) { continue }
        if ('({['.Contains($c)) { $d++ } elseif (')}]'.Contains($c)) { $d-- } elseif ($c -eq ',' -and $d -eq 0) { $out.Add($t.Substring($start, $i - $start).Trim()); $start = $i + 1 }
    }
    $out.Add($t.Substring($start).Trim()); return , $out.ToArray()
}
function Get-CallArgs([string]$t, [int]$parenIdx) {
    $close = Get-Close $t $parenIdx
    if ($close -lt 0) { return $null }
    return , (Split-Top $t.Substring($parenIdx + 1, $close - $parenIdx - 1))
}
function Get-RecordKeys([string]$rec) {
    # top-level keys of a record literal {a:..,'b c':..}
    $inner = $rec.Trim(); if (-not ($inner.StartsWith('{') -and $inner.EndsWith('}'))) { return $null }
    $keys = @()
    foreach ($part in (Split-Top $inner.Substring(1, $inner.Length - 2))) {
        $m = [regex]::Match($part, "^\s*('[^']+'|[A-Za-z_]\w*)\s*:")
        if ($m.Success) { $keys += $m.Groups[1].Value.Trim("'") } elseif ($part.Trim() -ne '') { return $null }
    }
    return , $keys
}
function Strip-Alias([string]$a) { $m = [regex]::Match($a, '^(?s)(.*?)\s+As\s+([A-Za-z_]\w*)\s*$'); if ($m.Success) { return @($m.Groups[1].Value.Trim(), $m.Groups[2].Value) } return @($a.Trim(), '') }

# ---- source --------------------------------------------------------------------------------------------------------------
$files = Get-ChildItem (Join-Path $root 'Src') -Recurse -Filter '*.pa.yaml' | Where-Object Name -ne '_EditorState.pa.yaml'
$raw = ($files | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
$raw = (($raw -split "`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
$src = Remove-Strings $raw

# ---- (A) schema per collection -------------------------------------------------------------------------------------------
# result of Get-Fields: @{ Keys = list; Refs = list of collection names; Open = bool }
function New-F { @{ Keys = New-Object System.Collections.Generic.List[string]; Refs = New-Object System.Collections.Generic.List[string]; Open = $false } }
function Add-F($a, $b) { foreach ($k in $b.Keys) { $a.Keys.Add($k) }; foreach ($r in $b.Refs) { $a.Refs.Add($r) }; if ($b.Open) { $a.Open = $true } }
function Get-Fields([string]$e, [int]$depth = 0) {
    $f = New-F; $e = $e.Trim()
    if ($depth -gt 25 -or $e -eq '') { $f.Open = $true; return $f }
    $e = (Strip-Alias $e)[0]
    if ($e -match '^Blank\(\)$') { return $f }
    if ($e.StartsWith('{')) { $k = Get-RecordKeys $e; if ($null -eq $k) { $f.Open = $true } else { foreach ($x in $k) { $f.Keys.Add($x) } }; return $f }
    if ($e -match '^col\w+$' -or $e -match '^loc\w+$') { $f.Refs.Add($e); return $f }
    $m = [regex]::Match($e, '^([A-Za-z]\w*)\(')
    if (-not $m.Success) { $f.Open = $true; return $f }
    $fn = $m.Groups[1].Value; $cargs = Get-CallArgs $e ($m.Length - 1)
    if ($null -eq $cargs -or (Get-Close $e ($m.Length - 1)) -ne $e.Length - 1) { $f.Open = $true; return $f }
    switch -regex ($fn) {
        '^(ForAll|With)$' { return Get-Fields $cargs[$cargs.Count - 1] ($depth + 1) }
        '^Table$' { foreach ($a in $cargs) { Add-F $f (Get-Fields $a ($depth + 1)) }; return $f }
        '^(Filter|Sort|SortByColumns|FirstN|LastN|Shuffle|First|Last|LookUp|Index)$' { if ($fn -eq 'LookUp' -and $cargs.Count -gt 2) { $f.Open = $true; return $f }; return Get-Fields $cargs[0] ($depth + 1) }
        '^(If|Switch|Coalesce|IfError)$' {
            $idx = if ($fn -eq 'If') { @(for ($i = 1; $i -lt $cargs.Count; $i += 2) { $i }) + @($cargs.Count - 1) } elseif ($fn -eq 'Switch') { @(for ($i = 2; $i -lt $cargs.Count; $i += 2) { $i }) + @($cargs.Count - 1) } else { 0..($cargs.Count - 1) }
            foreach ($i in ($idx | Sort-Object -Unique)) { Add-F $f (Get-Fields $cargs[$i] ($depth + 1)) }; return $f }
        '^AddColumns$' { Add-F $f (Get-Fields $cargs[0] ($depth + 1)); for ($i = 1; $i -lt $cargs.Count; $i += 2) { $f.Keys.Add($cargs[$i].Trim("'")) }; return $f }
        '^ShowColumns$' { for ($i = 1; $i -lt $cargs.Count; $i++) { $f.Keys.Add($cargs[$i].Trim("'")) }; return $f }
        '^(Distinct|Sequence)$' { $f.Keys.Add('Value'); return $f }
        default { $f.Open = $true; return $f }   # data source reads, DropColumns/RenameColumns/Ungroup/GroupBy etc.: not resolved
    }
}
$defs = @{}
foreach ($m in [regex]::Matches($src, '(?<![\w.])(ClearCollect|Collect)\(\s*(col\w+)\s*,')) {
    $cargs = Get-CallArgs $src ($m.Index + $m.Groups[1].Length)
    $name = $m.Groups[2].Value
    if (-not $defs.ContainsKey($name)) { $defs[$name] = New-F }
    if ($null -eq $cargs) { $defs[$name].Open = $true; continue }
    for ($i = 1; $i -lt $cargs.Count; $i++) { Add-F $defs[$name] (Get-Fields $cargs[$i]) }
}
# resolve copies of other collections
$schema = @{}; $open = @{}
function Resolve-Col([string]$n, $seen) {
    if ($schema.ContainsKey($n)) { return }
    if (-not $defs.ContainsKey($n) -or $seen.Contains($n)) { $open[$n] = $true; $schema[$n] = @(); return }
    [void]$seen.Add($n); $keys = New-Object System.Collections.Generic.HashSet[string]; $isOpen = $defs[$n].Open
    foreach ($k in $defs[$n].Keys) { [void]$keys.Add($k) }
    foreach ($r in $defs[$n].Refs) { Resolve-Col $r $seen; if ($open[$r]) { $isOpen = $true }; foreach ($k in $schema[$r]) { [void]$keys.Add($k) } }
    $schema[$n] = @($keys); $open[$n] = $isOpen
}
foreach ($n in @($defs.Keys)) { Resolve-Col $n (New-Object System.Collections.Generic.HashSet[string]) }
$closed = @($schema.Keys | Where-Object { -not $open[$_] } | Sort-Object)
$openCols = @($schema.Keys | Where-Object { $open[$_] } | Sort-Object)
function Get-TableSchema([string]$e) {
    # schema of a table expression used as first argument, or $null when not a (filtered/sorted) collection with a known schema
    $f = Get-Fields $e
    if ($f.Open -or $f.Refs.Count -eq 0) { if ($f.Refs.Count -eq 0) { return $null } }
    $keys = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in $f.Keys) { [void]$keys.Add($k) }
    foreach ($r in $f.Refs) { Resolve-Col $r (New-Object System.Collections.Generic.HashSet[string]); if ($open[$r]) { return $null }; foreach ($k in $schema[$r]) { [void]$keys.Add($k) } }
    if ($f.Open) { return $null }
    return , $keys
}

# ---- names that are not columns ------------------------------------------------------------------------------------------
$globals = New-Object System.Collections.Generic.HashSet[string]
foreach ($w in 'true', 'false', 'And', 'Or', 'Not', 'in', 'exactin', 'As', 'Self', 'Parent', 'ThisItem', 'ThisRecord', 'FirstError', 'AllErrors', 'User', 'Host', 'App', 'Connection',
    'SortOrder', 'TimeUnit', 'Color', 'DisplayMode', 'TraceSeverity', 'StartOfWeek', 'Align', 'VerticalAlign', 'FontWeight', 'ErrorKind', 'Icon', 'ValidationState', 'DropShadow', 'Transition', 'ScreenTransition', 'LayoutDirection', 'LayoutJustifyContent', 'LayoutAlignItems', 'LayoutOverflow', 'ImagePosition', 'TextFormat', 'Font', 'BorderStyle', 'DateTimeFormat', 'Zoom', 'Direction', 'TextMode', 'Overflow', 'NotificationType', 'JSONFormat', 'MatchOptions', 'Match', 'RequestHide', 'DataSourceInfo', 'TextPosition', 'ButtonAppearance') { [void]$globals.Add($w) }
foreach ($m in [regex]::Matches($raw, '(?m)^\s*-\s+([A-Za-z_]\w*):\s*$')) { [void]$globals.Add($m.Groups[1].Value) }          # controls
foreach ($m in [regex]::Matches($raw, '(?m)^  ([A-Za-z_]\w*):\s*$')) { [void]$globals.Add($m.Groups[1].Value) }               # screens/components
foreach ($m in [regex]::Matches($raw, '(?m)^\s+=?([A-Za-z_]\w*)\s*=\s')) { [void]$globals.Add($m.Groups[1].Value) }             # named formulas
foreach ($m in [regex]::Matches($src, '\bAs\s+([A-Za-z_]\w*)')) { [void]$globals.Add($m.Groups[1].Value) }                       # aliases (checked separately for their own call)
foreach ($m in [regex]::Matches($src, 'With\(\s*\{')) { $k = Get-RecordKeys $src.Substring($m.Index + 5, (Get-Close $src ($m.Index + 5)) - $m.Index - 4); if ($k) { foreach ($x in $k) { [void]$globals.Add($x) } } }
# data source names (bare and quoted) from the .msapr
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $root 'Site Managment_VS.msapr'))
try { $en = $zip.Entries | Where-Object FullName -eq 'msapp\References\DataSources.json'; $sr = New-Object IO.StreamReader($en.Open()); $dsJson = $sr.ReadToEnd(); $sr.Close() } finally { $zip.Dispose() }
# data source names are NOT excluded (review N2): a bare data source name inside a collection formula is reported

# ---- (B)/(C) uses -------------------------------------------------------------------------------------------------------
$scopeFns = 'Filter|LookUp|CountIf|Sort|SortByColumns|Sum|ForAll|Average|Max|Min|Concat|AddColumns|RemoveIf|UpdateIf|Distinct|GroupBy'
function Mask-Nested([string]$t) {
    # blank out every argument except the first of nested record-scope calls (their fields belong to another table)
    $sb = New-Object System.Text.StringBuilder $t
    foreach ($m in [regex]::Matches($t, "(?<![\w.])($scopeFns|ShowColumns|DropColumns|RenameColumns|Ungroup|Search)\(")) {
        $p = $m.Index + $m.Length - 1; $c = Get-Close $t $p; if ($c -lt 0) { continue }
        $parts = Split-Top $t.Substring($p + 1, $c - $p - 1); $firstEnd = $p + 1 + $t.Substring($p + 1).IndexOf($parts[0]) + $parts[0].Length
        for ($i = $firstEnd; $i -lt $c; $i++) { $sb[$i] = ' ' }
    }
    $sb.ToString()
}
function Find-Problems([string]$text) {
    $problems = New-Object System.Collections.Generic.List[string]; $checkedCalls = 0; $sbcBad = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($text, "(?<![\w.])($scopeFns)\(")) {
        $fn = $m.Groups[1].Value; if ($fn -in 'AddColumns', 'RemoveIf', 'UpdateIf', 'Distinct', 'GroupBy', 'Concat', 'Average', 'Max', 'Min') { continue }
        $cargs = Get-CallArgs $text ($m.Index + $m.Length - 1); if ($null -eq $cargs -or $cargs.Count -lt 2) { continue }
        $ta = Strip-Alias $cargs[0]; $tbl = $ta[0]; $alias = $ta[1]
        $line = ($text.Substring(0, $m.Index) -split "`n").Count
        if ($fn -eq 'SortByColumns' -and $tbl -notmatch "^([A-Za-z_]\w*|'[^']+')$") { $sbcBad.Add("line ~$line : SortByColumns(" + $tbl.Substring(0, [Math]::Min(60, $tbl.Length)) + "...") }
        $keys = Get-TableSchema $tbl; if ($null -eq $keys) { continue }
        $checkedCalls++
        $where = "$fn(" + $tbl.Substring(0, [Math]::Min(40, $tbl.Length)) + ") line ~$line"
        if ($fn -eq 'SortByColumns') {
            for ($i = 1; $i -lt $cargs.Count; $i += 2) { $c = $cargs[$i].Trim("'"); if (-not $keys.Contains($c)) { $problems.Add("$where : column '$c' not in schema") } }
            continue
        }
        $lambdas = if ($fn -eq 'ForAll') { @($cargs[$cargs.Count - 1]) } else { @($cargs[1..($cargs.Count - 1)]) }
        foreach ($l in $lambdas) {
            $t = Mask-Nested $l
            $t = [regex]::Replace($t, "(?<=[{,]\s*)('[^']+'|[A-Za-z_]\w*)\s*:", ' ')            # record literal keys
            foreach ($tk in [regex]::Matches($t, "(?<![\w.'])('[^']+'|[A-Za-z_]\w*\b)(?!\s*\()(?:\s*\.\s*('[^']+'|[A-Za-z_]\w*))?")) {
                $name = $tk.Groups[1].Value; $sub = $tk.Groups[2].Value
            if ($sub -ne '' -and $t.Substring($tk.Index + $tk.Length).TrimStart().StartsWith('(')) { continue }   # method call such as 'Flow'.Run(
                if ($alias -ne '' -and $name -eq $alias) { if ($sub -ne '' -and -not $keys.Contains($sub.Trim("'"))) { $problems.Add("$where : $alias.$($sub.Trim("'")) not in schema") }; continue }
                if ($name -eq 'ThisRecord') { if ($sub -ne '' -and -not $keys.Contains($sub.Trim("'"))) { $problems.Add("$where : ThisRecord.$($sub.Trim("'")) not in schema") }; continue }
                $bare = $name.Trim("'")
                if ($globals.Contains($bare) -or $bare -match '^(var|col|loc)[A-Z]' -or $bare -match '^\d') { continue }
                if (-not $keys.Contains($bare)) { $problems.Add("$where : '$bare' not in schema") }
            }
        }
    }
    return @{ Problems = $problems; Checked = $checkedCalls; SortByColumnsBad = $sbcBad }
}
$res = Find-Problems $src; $problems = $res.Problems; $checkedCalls = $res.Checked; $sbcBad = $res.SortByColumnsBad

# ---- self-test on synthetic formulas -------------------------------------------------------------------------------------
$st = Get-Fields 'ForAll(colA As f,{HourID:f.ID,Pos:1,''Work Date'':f.D})'
Check (($st.Keys -join ',') -eq 'HourID,Pos,Work Date' -and -not $st.Open) 'self-test: fields of ForAll(...{record}) incl. quoted name'
$st2 = Get-Fields 'Filter(Hours,StartsWith(EntryKey,varQ))'
Check ($st2.Open) 'self-test: a SharePoint read makes the collection open (not checked)'
Check ((Mask-Nested 'X=1 && CountIf(colB,Y=2)>0').Contains('CountIf(colB') -and -not (Mask-Nested 'X=1 && CountIf(colB,Y=2)>0').Contains('Y=2')) 'self-test: nested record scope masked'
# mutation tests on the real source: an unknown column must be found, the c4 formula must be refused
$mut = Find-Problems ($src + "`n=Filter(colWrExportFacts,NoSuchColumn=1); LookUp(colWrExportFacts As x,x.NoSuchField=1); SortByColumns(colWrExportFacts,NoSuchSortCol,SortOrder.Ascending)")
Check (@($mut.Problems | Where-Object { $_ -match "'NoSuchColumn'|x\.NoSuchField|'NoSuchSortCol'" }).Count -eq 3 -and $mut.SortByColumnsBad.Count -eq $res.SortByColumnsBad.Count) 'self-test: a bare column, alias.column and SortByColumns column missing from the schema are each reported'
$dsm = Find-Problems ($src + "`n=Sort(colWrExportFacts,Text(Hours,""0""),SortOrder.Ascending)")
Check ($dsm.Problems.Count -eq $res.Problems.Count + 1) 'self-test: a data source name used as a column on a collection is reported (review N2)'
$c4 = Find-Problems ($src + "`n=ForAll(SortByColumns(Filter(colWrExportFacts As f,f.ContractorID>0),Pos,SortOrder.Ascending,DayIndex,SortOrder.Ascending,HourID,SortOrder.Ascending) As f,{Pos:f.Pos})")
Check ($c4.SortByColumnsBad.Count -eq $res.SortByColumnsBad.Count + 1) 'self-test: the build c4 formula (SortByColumns on Filter(... As f)) is refused'

# ---- report ---------------------------------------------------------------------------------------------------------------
Write-Output "Collections with a resolved schema: $($closed.Count); open (SharePoint read or not resolvable, not checked): $($openCols.Count) ($($openCols -join ', '))"
Check ($closed.Count -ge 20) "schema resolved for at least 20 collections (found $($closed.Count))"
Check ($checkedCalls -ge 50) "uses checked: $checkedCalls calls on collections with a known schema"
Check ($problems.Count -eq 0) "every column used in SortByColumns/Filter/LookUp/CountIf/Sort/Sum/ForAll on a collection exists in its ClearCollect/Collect schema"
foreach ($p in ($problems | Select-Object -Unique)) { Write-Output "  - $p" }
Check ($sbcBad.Count -eq 0) 'SortByColumns only on a plain collection/data source name (conservative rule after the c4 import error on Filter(... As f), root cause unknown; use Sort with a formula key)'
foreach ($p in $sbcBad) { Write-Output "  - $p" }
Write-Output 'NOT verified locally: Studio binding/type inference (no Power Fx binder); collections filled from SharePoint reads are listed as open.'
if ($fails -gt 0) { Write-Output "Test-CollectionColumns: $fails FAIL"; exit 1 }
Write-Output 'Test-CollectionColumns: all PASS'
