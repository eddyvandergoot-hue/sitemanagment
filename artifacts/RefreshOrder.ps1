# Shared static helper (dot-sourced by Test-AdminScreens.ps1 and Test-SaveRegression.ps1).
# Rule (TP-CONTRACTORS-01 step 12, 29-10-2026): every read of a SharePoint list in a behaviour formula
# (pre-read, verify read, reload) is preceded by Refresh(<that list>) in the same branch, so the
# connector cache can never serve values from before a change made directly in SharePoint.
# Proves source order only: not that the connector really bypasses its cache (Studio/Monitor).
$script:RefreshSources = @('Employers', 'Workers', 'Projects', 'Hours', "'Project Workers'", "'Assignment Periods'")
$script:RefreshSourcePattern = '(Employers|Workers|Projects|Hours|''Project Workers''|''Assignment Periods'')'

function Get-FxParens([string]$fx) {
    # Pairs of (open, close) parenthesis positions and direct commas per open parenthesis; strings skipped.
    $opens = New-Object System.Collections.Generic.List[int]
    $close = @{}; $commas = @{}; $stack = New-Object System.Collections.Generic.Stack[int]; $inS = $false
    for ($i = 0; $i -lt $fx.Length; $i++) {
        $ch = $fx[$i]
        if ($ch -eq '"') { $inS = -not $inS; continue }
        if ($inS) { continue }
        if ($ch -eq '(') { $stack.Push($i); $opens.Add($i); $commas[$i] = New-Object System.Collections.Generic.List[int] }
        elseif ($ch -eq ')') { if ($stack.Count -eq 0) { throw "Unbalanced ')' at $i" }; $close[$stack.Pop()] = $i }
        elseif ($ch -eq ',' -and $stack.Count -gt 0) { $commas[$stack.Peek()].Add($i) }
    }
    if ($stack.Count -ne 0) { throw 'Unbalanced (' }
    return @{ Opens = $opens; Close = $close; Commas = $commas }
}
function Get-FxStack($info, [int]$pos) { return @($info.Opens | Where-Object { $_ -lt $pos -and $info.Close[$_] -gt $pos }) }
function Get-FxCallName([string]$fx, [int]$open) { $m = [regex]::Match($fx.Substring(0, $open), '(\w+)\s*$'); if ($m.Success) { return $m.Groups[1].Value }; return '' }
function Get-FxFirstArg([string]$fx, $info, [int]$open) {
    $end = if ($info.Commas[$open].Count -gt 0) { $info.Commas[$open][0] } else { $info.Close[$open] }
    return $fx.Substring($open + 1, $end - $open - 1).Trim()
}
function Get-FxArgIndex($info, [int]$open, [int]$pos) { return @($info.Commas[$open] | Where-Object { $_ -lt $pos }).Count }

function Get-SharePointReads([string]$fx) {
    $reads = @()
    $p1 = '\b(?:Filter|Sort|SortByColumns|ForAll|LookUp|Search|CountRows|CountIf|First|Last|Distinct|ShowColumns|AddColumns|Sum)\(\s*' + $script:RefreshSourcePattern + '(?![\w.''])'
    $p2 = '\b(?:ClearCollect|Collect)\(\s*\w+\s*,\s*' + $script:RefreshSourcePattern + '(?![\w.''(])'
    foreach ($p in @($p1, $p2)) { foreach ($m in [regex]::Matches($fx, $p)) { $reads += [pscustomobject]@{ Source = $m.Groups[1].Value; Pos = $m.Groups[1].Index } } }
    return @($reads | Sort-Object Pos)
}

function Test-RefreshBeforeReads([string]$fx) {
    # Returns one object per SharePoint read: Status Refreshed (Refresh in the same branch), Forced (Refresh only under
    # If(Coalesce(<force>,false),...) and the read under a condition containing the same force flag: first/invalidated
    # load without Refresh, by design) or Missing.
    $info = Get-FxParens $fx
    $out = @()
    foreach ($rd in (Get-SharePointReads $fx)) {
        $best = 'Missing'
        $sp = Get-FxStack $info $rd.Pos
        foreach ($rm in [regex]::Matches($fx.Substring(0, $rd.Pos), '\bRefresh\(\s*' + [regex]::Escape($rd.Source) + '\s*\)')) {
            $r0 = $rm.Index
            $sr = Get-FxStack $info $r0
            if ($sr.Count -gt 0) {
                $inner = $sr[$sr.Count - 1]
                if ((Get-FxCallName $fx $inner) -eq 'IfError' -and (Get-FxArgIndex $info $inner $r0) -eq 0) { $r0 = $inner - 'IfError'.Length; $sr = @($sr | Select-Object -First ($sr.Count - 1)) }
            }
            $common = 0; while ($common -lt $sr.Count -and $common -lt $sp.Count -and $sr[$common] -eq $sp[$common]) { $common++ }
            if ($common -gt 0) {
                $c = $sr[$common - 1]
                if ((Get-FxArgIndex $info $c $r0) -ne (Get-FxArgIndex $info $c $rd.Pos)) { continue }   # other argument = other branch
            }
            $status = 'Refreshed'; $ok = $true
            foreach ($e in @($sr | Select-Object -Skip $common)) {
                # an enclosing call of the Refresh that closes before the read: only an If gate, Refresh in its then-branch
                if ((Get-FxCallName $fx $e) -ne 'If' -or (Get-FxArgIndex $info $e $r0) -ne 1) { $ok = $false; break }
                $cond = Get-FxFirstArg $fx $info $e
                # the read must sit in the then-branch of an If (not shared with the Refresh) whose condition also contains
                # the same (non-negated) gate
                $gatePattern = '(?<![!\w])' + [regex]::Escape($cond)
                $gates = @($sp | Select-Object -Skip $common | Where-Object { (Get-FxCallName $fx $_) -eq 'If' -and (Get-FxArgIndex $info $_ $rd.Pos) -eq 1 -and (Get-FxFirstArg $fx $info $_) -match $gatePattern })
                if ($cond -match '^IsEmpty\(\w+\)$') {
                    # error gate: Refresh ran when the error collection was empty; the read only runs while it is still empty
                    if ($gates.Count -eq 0) { $ok = $false; break }
                } elseif ($cond -match '^Coalesce\(\w+,false\)$') {
                    if ($gates.Count -eq 0) { $ok = $false; break }
                    $status = 'Forced'
                } else { $ok = $false; break }
            }
            if (!$ok) { continue }
            if ($status -eq 'Refreshed') { $best = 'Refreshed'; break }
            if ($best -eq 'Missing') { $best = 'Forced' }
        }
        $line = ($fx.Substring(0, $rd.Pos) -split "`n").Count
        $out += [pscustomobject]@{ Source = $rd.Source; Pos = $rd.Pos; Line = $line; Status = $best }
    }
    return $out
}

function Get-BehaviourFormulas($entries, [string]$screen, $result) {
    foreach ($entry in $entries) {
        $name = @($entry.Keys)[0]; $props = $entry[$name]['Properties']
        if ($props) { foreach ($p in $props.Keys) { if ($p -like 'On*') { $result["$screen.$name.$p"] = [string]$props[$p] } } }
        Get-BehaviourFormulas $entry[$name]['Children'] $screen $result
    }
}
