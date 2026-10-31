# Layout test for the admin screens scrContractors and scrProjects (31-10-2026, step 3b).
# Evaluates every X/Y/Width/Height formula of the screen tree in the Power Fx interpreter (same approach as Test-FooterRow/Test-AdminScreens:
# Parent./Self. are bound, sibling and global rectangles are published as variables, several passes until stable) at screen widths 1366, 1000
# and 700 (height 768) and with the message bar hidden and shown. Checks, per container:
#   (1) every visible control/instance lies inside its parent: X >= 0, Y >= 0, X+Width <= parent Width; vertically inside the parent too,
#       except inside the scrolling body (conXxxBody, LayoutOverflowY = Scroll) where the content may be taller than the viewport;
#   (2) no two visible siblings overlap (explicit exceptions below: the switch knob lies on its track);
#   (3) every cmpField instance has no Visible formula (or Visible = true);
#   (4) the scrolling body ends at the footer and starts directly under the message bar.
# Proves source geometry only: component internals are covered by Test-Components/Test-FooterRow; no Studio rendering is verified.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$lay = New-Object Microsoft.PowerFx.RecalcEngine
$layOpt = New-Object Microsoft.PowerFx.ParserOptions
$layOpt.Culture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
function Assert-True($cond, $label) { if (!$cond) { throw "FAIL $label" }; Write-Output "PASS $label" }

function Publish-Var([string]$name, [string]$literal) { $v = $lay.Eval($literal, $null, $layOpt); if ($v -is [Microsoft.PowerFx.Types.ErrorValue]) { throw "publish $name : $($v.ToExpression())" }; $lay.UpdateVariable($name, $v) }
function Eval-Layout([string]$expr, $parent, $self) {
    $fx = $expr.Trim().TrimStart('=').Replace('Parent.', 'LayoutParent.').Replace('Self.', 'LayoutSelf.')
    $lit = 'With({LayoutParent:{X:0,Y:0,Width:' + $parent.Width + ',Height:' + $parent.Height + '},LayoutSelf:{X:' + $self.X + ',Y:' + $self.Y + ',Width:' + $self.Width + ',Height:' + $self.Height + '}},' + $fx + ')'
    $v = $lay.Eval($lit, $null, $layOpt)
    if ($v -is [Microsoft.PowerFx.Types.ErrorValue]) { throw $v.ToExpression() }
    return [double]$v.Value
}
function Eval-Bool([string]$expr) {
    try { $v = $lay.Eval($expr.Trim().TrimStart('='), $null, $layOpt); if ($v -is [Microsoft.PowerFx.Types.ErrorValue]) { return $true }; return [bool]$v.Value } catch { return $true }
}

function Walk-Children($children, $parentRect, $parentProps, $state) {
    # one evaluation pass over a container's children; stores rectangles in $state.Rects and publishes them as variables
    $auto = ($parentProps -and $parentProps.IsAuto); $cursorY = 0
    foreach ($entry in $children) {
        $name = @($entry.Keys)[0]; $ctl = $entry[$name]; $props = $ctl['Properties']
        if (-not $state.Rects.ContainsKey($name)) { $state.Rects[$name] = @{ X = 0; Y = 0; Width = 0; Height = 0 } }
        $r = $state.Rects[$name]
        for ($rep = 0; $rep -lt 2; $rep++) {
            foreach ($key in @('Width', 'Height', 'X', 'Y')) {
                if ($props.ContainsKey($key)) {
                    try { $r[$key] = Eval-Layout ([string]$props[$key]) $parentRect $r } catch { $state.Errors[$name + '.' + $key] = $_.Exception.Message }
                }
            }
        }
        if ($auto) { $r.X = 0; $r.Y = $cursorY; $cursorY += $r.Height }
        $extra = ''
        if ($ctl['ComponentName'] -eq 'cmpMessageBar') { $extra = ',BarHeight:' + $(if ($state.Kind -in @('Error', 'Warning', 'Success')) { 40 } else { 0 }) }
        Publish-Var $name ('{X:' + $r.X + ',Y:' + $r.Y + ',Width:' + $r.Width + ',Height:' + $r.Height + ',Visible:true' + $extra + '}')
        if ($ctl['Children']) {
            $cp = @{ IsAuto = ($ctl['Variant'] -eq 'AutoLayout'); ScrollY = ([string]$props['LayoutOverflowY'] -eq '=LayoutOverflow.Scroll') }
            Walk-Children $ctl['Children'] $r $cp $state
        }
    }
}

function Collect-Checks($children, $parentName, $parentRect, $scrollParent, $ctx, $state, $screen, $label) {
    $kids = @()
    foreach ($entry in $children) {
        $name = @($entry.Keys)[0]; $ctl = $entry[$name]; $props = $ctl['Properties']
        $vis = $true
        if ($props.ContainsKey('Visible')) { $vf = ([string]$props['Visible']).Trim(); if ($vf -eq '=false') { $vis = $false } elseif ($vf -ne '=true') { $vis = Eval-Bool $vf } }
        if ($ctl['ComponentName'] -eq 'cmpField') { Assert-True ((-not $props.ContainsKey('Visible')) -or ([string]$props['Visible']).Trim() -eq '=true') "$label : $name (cmpField) has no Visible formula (always rendered)" }
        if (-not $vis) { continue }
        $r = $state.Rects[$name]
        # size 0 controls (message bar without message) take no space and are not checked
        if ($r.Width -le 0 -or $r.Height -le 0) { if ($ctl['Children']) { } ; continue }
        $kids += @{ Name = $name; R = $r; Ctl = $ctl }
        if ($r.X -lt -0.01 -or $r.Y -lt -0.01) { throw "FAIL $label : $name starts outside its parent $parentName (X=$($r.X), Y=$($r.Y))" }
        if ($r.X + $r.Width -gt $parentRect.Width + 0.01) { throw "FAIL $label : $name exceeds the width of $parentName (X+W=$($r.X + $r.Width) > $($parentRect.Width))" }
        if (-not $scrollParent -and $r.Y + $r.Height -gt $parentRect.Height + 0.01) { throw "FAIL $label : $name exceeds the height of $parentName (Y+H=$($r.Y + $r.Height) > $($parentRect.Height))" }
    }
    $allowedOverlap = @('btnEmpActiveSwitch|btnEmpActiveKnob')   # knob lies on its switch track by design
    for ($i = 0; $i -lt $kids.Count; $i++) {
        for ($j = $i + 1; $j -lt $kids.Count; $j++) {
            $a = $kids[$i].R; $b = $kids[$j].R
            if ($a.X -lt $b.X + $b.Width - 0.01 -and $b.X -lt $a.X + $a.Width - 0.01 -and $a.Y -lt $b.Y + $b.Height - 0.01 -and $b.Y -lt $a.Y + $a.Height - 0.01) {
                if (($kids[$i].Name + '|' + $kids[$j].Name) -in $allowedOverlap) { continue }
                throw "FAIL $label : $($kids[$i].Name) and $($kids[$j].Name) overlap in $parentName"
            }
        }
    }
    $script:layoutChecked += $kids.Count
    foreach ($k in $kids) {
        if ($k.Ctl['Children']) {
            $sp = ([string]$k.Ctl['Properties']['LayoutOverflowY'] -eq '=LayoutOverflow.Scroll')
            Collect-Checks $k.Ctl['Children'] $k.Name $k.R $sp $ctx $state $screen $label
        }
    }
}

$screens = @(
    @{ Name = 'scrContractors'; P = 'Emp'; Mode = 'varEmpMode' },
    @{ Name = 'scrProjects'; P = 'Prj'; Mode = 'varPrjMode' }
)
$H = 768
foreach ($s in $screens) {
    $doc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot ('Src/' + $s.Name + '.pa.yaml'))))
    $children = $doc['Screens'][$s.Name]['Children']
    $names = @{}; function Index-Names($entries) { foreach ($e in $entries) { $n = @($e.Keys)[0]; $names[$n] = $e[$n]; Index-Names $e[$n]['Children'] } }
    Index-Names $children
    $p = $s.P
    foreach ($W in 1366, 1000, 700) {
        foreach ($kind in '', 'Error') {
            $label = "$($s.Name) $W x $H (message '$kind')"
            $state = @{ Rects = @{}; Errors = @{}; Kind = $kind }
            Publish-Var 'varAdmMsgKind' ('"' + $kind + '"')
            Publish-Var $s.Mode '"Edit"'; Publish-Var 'varEmpActiveDraft' 'true'; Publish-Var 'varEmpShowInactive' 'false'; Publish-Var 'varPrjShowInactive' 'false'
            Publish-Var "var${p}Edit" '{Active:true,Status:"Active",Name:"A",Number:"N"}'
            $screenRect = @{ X = 0; Y = 0; Width = $W; Height = $H }
            for ($pass = 0; $pass -lt 8; $pass++) { $state.Errors = @{}; Walk-Children $children $screenRect $null $state }
            if ($state.Errors.Count -gt 0) { throw "FAIL $label : unresolved geometry formulas: $(($state.Errors.GetEnumerator() | ForEach-Object { $_.Key + ' -> ' + $_.Value }) -join '; ')" }
            $script:layoutChecked = 0
            Collect-Checks $children 'screen' $screenRect $false $null $state $s.Name $label
            # structure: title 60, message bar directly under it, scrolling body between message bar and footer, footer at the bottom
            $title = $state.Rects["cmp${p}Title"]; $bar = $state.Rects["cmp${p}MsgBar"]; $body = $state.Rects["con${p}Body"]; $foot = $state.Rects["cmp${p}Footer"]
            $barH = $(if ($kind -eq '') { 0 } else { 40 })
            Assert-True (($title.Y -eq 0) -and ($title.Height -eq 60) -and ($title.Width -eq $W) -and ($bar.Y -eq 60) -and ($bar.Height -eq $barH) -and ($body.Y -eq 60 + $barH) -and ($body.Y + $body.Height -eq $foot.Y) -and ($foot.Y + $foot.Height -eq $H) -and ($foot.Height -eq 68)) "$label : title 60, message bar $barH, body from $($body.Y) to the footer ($($foot.Y)), footer 68 at the bottom"
            $layoutX = $state.Rects["lbl${p}Layout"]
            $cards = @($names.Keys | Where-Object { $_ -in @("cmp${p}List", "con${p}FormCard") })
            $listR = $state.Rects["cmp${p}List"]; $formR = $state.Rects["con${p}FormCard"]
            if ($W -ge 1000) { Assert-True (($listR.Width -eq 360) -and ($formR.X -ge $listR.X + $listR.Width + 24 - 0.01) -and ($listR.Y -eq $formR.Y)) "$label : wide: list card 360 left, form card right with a 24 px gap, tops equal" }
            else { Assert-True ($formR.Y -ge $listR.Y + $listR.Height + 24 - 0.01) "$label : narrow: form card stacked under the list card with a 24 px gap" }
            # every field instance inside the form card, none outside the card content
            $fields = @($names.Keys | Where-Object { $names[$_]['ComponentName'] -eq 'cmpField' })
            foreach ($f in $fields) { $fr = $state.Rects[$f]; if ($fr.X -lt 24 - 0.01 -or $fr.X + $fr.Width -gt $formR.Width - 24 + 0.01) { throw "FAIL $label : $f outside the 24 px card padding (X=$($fr.X), W=$($fr.Width), card $($formR.Width))" } }
            Write-Output "PASS $label : $($script:layoutChecked) visible controls inside their parents, no sibling overlaps, $($fields.Count) cmpField instances always rendered inside the card padding (columns: $([math]::Round($state.Rects["lbl${p}Grid"].Width,1)) px)."
        }
    }
}
Write-Output 'Test-Layout covers: bounds (X>=0, Y>=0, right edge inside the parent; bottom edge inside the parent except in the scrolling body), sibling overlaps among visible controls and instances, no Visible formula on cmpField instances, the title/message bar/body/footer stack and the two-card arrangement, for scrContractors and scrProjects at 1366, 1000 and 700 x 768 with and without a message. NOT covered: component internals (see Test-Components/Test-FooterRow), text clipping and rendering in Studio.'
