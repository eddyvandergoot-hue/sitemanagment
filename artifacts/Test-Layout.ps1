# Layout test for the admin screens scrContractors and scrProjects (31-10-2026, step 3b), scrWorkers (08-11-2026, Workers build) and scrWeekReport (09-11-2026, Week Report phase A).
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
        $visLit = $(if ($name -in @('btnWrkSaveAnywaySwitch','btnWrkSaveAnywayKnob','lblWrkSaveAnywayState') -and $state.ContainsKey('Any') -and -not $state.Any) { 'false' } else { 'true' })
        Publish-Var $name ('{X:' + $r.X + ',Y:' + $r.Y + ',Width:' + $r.Width + ',Height:' + $r.Height + ',Visible:' + $visLit + $extra + '}')
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
        if ($name -in @('btnWrkSaveAnywaySwitch','btnWrkSaveAnywayKnob','lblWrkSaveAnywayState') -and $state.ContainsKey('Any')) { $vis = [bool]$state.Any }   # Visible formula depends on runtime state; the test drives it explicitly (row shown / hidden)
        if (-not $vis) { continue }
        $r = $state.Rects[$name]
        # size 0 controls (message bar without message) take no space and are not checked
        if ($r.Width -le 0 -or $r.Height -le 0) { if ($ctl['Children']) { } ; continue }
        $kids += @{ Name = $name; R = $r; Ctl = $ctl }
        if ($r.X -lt -0.01 -or $r.Y -lt -0.01) { throw "FAIL $label : $name starts outside its parent $parentName (X=$($r.X), Y=$($r.Y))" }
        if ($r.X + $r.Width -gt $parentRect.Width + 0.01) { throw "FAIL $label : $name exceeds the width of $parentName (X+W=$($r.X + $r.Width) > $($parentRect.Width))" }
        if (-not $scrollParent -and $r.Y + $r.Height -gt $parentRect.Height + 0.01) { throw "FAIL $label : $name exceeds the height of $parentName (Y+H=$($r.Y + $r.Height) > $($parentRect.Height))" }
    }
    $allowedOverlap = @('btnEmpActiveSwitch|btnEmpActiveKnob', 'btnWrkActiveSwitch|btnWrkActiveKnob', 'btnWrkSaveAnywaySwitch|btnWrkSaveAnywayKnob')   # knob lies on its switch track by design
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
    @{ Name = 'scrProjects'; P = 'Prj'; Mode = 'varPrjMode' },
    @{ Name = 'scrWorkers'; P = 'Wrk'; Mode = 'varWrkMode' }
)
$H = 768
foreach ($s in $screens) {
    $doc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot ('Src/' + $s.Name + '.pa.yaml'))))
    $children = $doc['Screens'][$s.Name]['Children']
    $names = @{}; function Index-Names($entries) { foreach ($e in $entries) { $n = @($e.Keys)[0]; $names[$n] = $e[$n]; Index-Names $e[$n]['Children'] } }
    Index-Names $children
    $p = $s.P
    foreach ($W in 1366, 1000, 700) {
        # string states, not $null: foreach over $null runs zero times and silently skipped scrContractors/scrProjects
        foreach ($anyMode in $(if ($s.Name -eq 'scrWorkers') { @('visible', 'hidden') } else { @('na') })) {
        $anyState = $(if ($anyMode -eq 'na') { $null } else { $anyMode -eq 'visible' })
        foreach ($kind in '', 'Error') {
            $label = "$($s.Name) $W x $H (message '$kind'" + $(if ($null -ne $anyState) { ", Save anyway row $anyMode" } else { "" }) + ")"
            $state = @{ Rects = @{}; Errors = @{}; Kind = $kind }; if ($null -ne $anyState) { $state.Any = $anyState }
            Publish-Var 'varAdmMsgKind' ('"' + $kind + '"')
            Publish-Var $s.Mode '"Edit"'; Publish-Var 'varEmpActiveDraft' 'true'; Publish-Var 'varEmpShowInactive' 'false'; Publish-Var 'varPrjShowInactive' 'false'; Publish-Var 'varWrkActiveDraft' 'true'; Publish-Var 'varWrkShowInactive' 'false'; Publish-Var 'varWrkDupConfirmed' 'false'
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
            # 1-11-2026: the scrolling body may show a 16 px scrollbar; both cards must end >= 24 px + 16 px before the body's right edge, and every input (X+1 .. W-2 inside the component, 2 px focus border) lies fully inside the card
            $bodyR = $state.Rects["con${p}Body"]
            Assert-True (($formR.X + $formR.Width) -le ($bodyR.Width - 40 + 0.01) -and ($listR.X + $listR.Width) -le ($bodyR.Width - 40 + 0.01)) "$label : cards keep 24 px margin plus a 16 px scrollbar reserve at the right edge"
            foreach ($f in $fields) { $fr = $state.Rects[$f]; $inL = $fr.X + 1 - 2; $inR = $fr.X + $fr.Width - 1 + 2; if ($inL -lt 0 -or $inR -gt $formR.Width - 16) { throw "FAIL $label : input of $f (incl. 2 px border) leaves the card ($inL..$inR of $($formR.Width))" } }
            Write-Output "PASS $label : $($script:layoutChecked) visible controls inside their parents, no sibling overlaps, $($fields.Count) cmpField instances always rendered inside the card padding (columns: $([math]::Round($state.Rects["lbl${p}Grid"].Width,1)) px)."
            if ($s.Name -eq 'scrWorkers') { $sa = $state.Rects["btnWrkSaveAnywaySwitch"]; $ac = $state.Rects["btnWrkActiveSwitch"]; $md = $state.Rects["lblWrkModified"]; $sg = $state.Rects["lblWrkSecWork"]; $lastField = $state.Rects["cmpWrkLanguage"]
                Assert-True (($sa.Y -ge $lastField.Y + $lastField.Height + 16 - 0.01) -and $(if ($anyState) { $ac.Y -ge $sa.Y + $sa.Height + 12 - 0.01 } else { $ac.Y -eq $sa.Y }) -and ($md.Y + $md.Height + 24 -le $formR.Height + 0.01)) "$label : Save anyway row below the last field row, Active/Last changed row directly below it (or in its place when hidden), form card ends 24 px below the last row" }
        }
        }
    }
}
# --- scrWeekReport (09-11-2026, Week Report phase A): admin-pattern page (title, message bar, scrolling body) with a selection card and a table
# card, footer = cmpReportFooter (68 px). The table is one gallery of display lines (contractor header / worker row / subtotal / grand total); the
# template controls of the four line types share the same area and are mutually exclusive by Visible on ThisItem.LineType, so the whole screen is
# checked once per line type with ThisItem published as a variable (overlap and bounds of the visible template controls of that type).
$wrDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrWeekReport.pa.yaml')))
$wrKids = $wrDoc['Screens']['scrWeekReport']['Children']
$wrNames = @{}; function Index-WrNames($entries) { foreach ($e in $entries) { $n = @($e.Keys)[0]; $wrNames[$n] = $e[$n]; Index-WrNames $e[$n]['Children'] } }; Index-WrNames $wrKids
$wrLines = 'Table({LineType:"Header",ContractorID:10},{LineType:"Row",ContractorID:10},{LineType:"Row",ContractorID:10},{LineType:"Subtotal",ContractorID:10},{LineType:"Header",ContractorID:20},{LineType:"Row",ContractorID:20},{LineType:"Subtotal",ContractorID:20},{LineType:"Grand",ContractorID:-1})'
foreach ($W in 1366, 1344, 1343, 1000, 848, 700) {  # 1344 and 848 are exact-fit widths (0 px slack, reviewer 11-11-2026)
    foreach ($kind in '', 'Error') {
        foreach ($lt in 'Header', 'Row', 'Subtotal', 'Grand') {
            $label = "scrWeekReport $W x $H (message '$kind', line type $lt)"
            $state = @{ Rects = @{}; Errors = @{}; Kind = $kind }
            Publish-Var 'varAdmMsgKind' ('"' + $kind + '"'); Publish-Var 'varWrLoadState' '"Loaded"'; Publish-Var 'varWrContractorID' '0'; Publish-Var 'varWrBusy' 'false'; Publish-Var 'varWrMastersReady' 'true'
            Publish-Var 'colWrLines' $wrLines
            Publish-Var 'ThisItem' ('{LineType:"' + $lt + '",Zebra:false,Name:"x",Code:"c",Lang:"Polish",Trade:"Fitter",D1:8,D2:0,D3:0,D4:0,D5:0,D6:0,D7:0,WeekTotal:8}')
            $screenRect = @{ X = 0; Y = 0; Width = $W; Height = $H }
            for ($pass = 0; $pass -lt 8; $pass++) { $state.Errors = @{}; Walk-Children $wrKids $screenRect $null $state }
            if ($state.Errors.Count -gt 0) { throw "FAIL $label : unresolved geometry formulas: $(($state.Errors.GetEnumerator() | ForEach-Object { $_.Key + ' -> ' + $_.Value }) -join '; ')" }
            $script:layoutChecked = 0
            Collect-Checks $wrKids 'screen' $screenRect $false $null $state 'scrWeekReport' $label
            $R = $state.Rects
            $barH = $(if ($kind -eq '') { 0 } else { 40 })
            Assert-True (($R.cmpWrTitle.Y -eq 0) -and ($R.cmpWrTitle.Height -eq 60) -and ($R.cmpWrTitle.Width -eq $W) -and ($R.cmpWrMsgBar.Y -eq 60) -and ($R.cmpWrMsgBar.Height -eq $barH) -and ($R.conWrBody.Y -eq 60 + $barH) -and ($R.conWrBody.Y + $R.conWrBody.Height -eq $R.cmpWrFooter.Y) -and ($R.cmpWrFooter.Y + $R.cmpWrFooter.Height -eq $H) -and ($R.cmpWrFooter.Height -eq 68) -and ($R.cmpWrFooter.Width -eq $W)) "$label : title 60, message bar $barH, body from $($R.conWrBody.Y) to the footer ($($R.cmpWrFooter.Y)), cmpReportFooter 68 at the bottom"
            $sel = $R.conWrSelCard; $tab = $R.conWrTableCard
            Assert-True (($sel.X -eq 24) -and ($sel.Y -eq 24) -and ($tab.X -eq 24) -and ($tab.Y -eq $sel.Y + $sel.Height + 24) -and ($sel.Width -eq $tab.Width) -and ($sel.X + $sel.Width -le $R.conWrBody.Width - 40 + 0.01) -and ($R.conWrCanvas.Height -eq $tab.Y + $tab.Height + 24)) "$label : selection card and table card stacked (24 margin and gap), 16 px scrollbar reserve at the right, canvas ends 24 below the table card"
            foreach ($f in 'lblWrWeekLabel', 'btnWrPrev', 'dpWrWeek', 'btnWrNext', 'lblWrWeekKW', 'cmpWrProject', 'cmpWrContractor') { $fr = $R[$f]; if ($fr.X -lt 24 - 0.01 -or $fr.Y -lt 24 - 0.01 -or $fr.X + $fr.Width -gt $sel.Width - 24 + 0.01 -or $fr.Y + $fr.Height -gt $sel.Height - 24 + 0.01) { throw "FAIL $label : $f outside the 24 px padding of the selection card (X=$($fr.X) Y=$($fr.Y) W=$($fr.Width) H=$($fr.Height), card $($sel.Width) x $($sel.Height))" } }
            $wide = ($W -ge 1344)
            Assert-True ($(if ($wide) { ($R.cmpWrProject.Y -eq 24) -and ($R.cmpWrContractor.Y -eq 24) -and ($R.cmpWrProject.X -ge $R.lblWrWeekKW.X + $R.lblWrWeekKW.Width + 24 - 0.01) } else { ($R.cmpWrProject.Y -ge $R.dpWrWeek.Y + $R.dpWrWeek.Height + 16 - 0.01) -and ($R.cmpWrContractor.Y -eq $R.cmpWrProject.Y) -and ($R.cmpWrContractor.X -ge $R.cmpWrProject.X + $R.cmpWrProject.Width + 16 - 0.01) })) "$label : selection $(if ($wide) { 'in one row: Week | Project | Contractor' } else { 'in two rows: Week, then Project | Contractor' })"
            $a = $W - 112; $expCols = $(if ($a -ge 928) { @(240, 96, 72, 88) } elseif ($a -ge 736) { @(200, 80, 56, 64) } else { @(140, 72, 44, 64) })
            $tableW = $expCols[0] + $expCols[1] + 7 * $expCols[2] + $expCols[3]
            Assert-True (($R.lblWrHdrName.Width -eq $expCols[0]) -and ($R.lblWrHdrTrade.Width -eq $expCols[1]) -and ($R.lblWrHdrMon.Width -eq $expCols[2]) -and ($R.lblWrHdrTotal.Width -eq $expCols[3]) -and ($tableW -le $tab.Width - 48 + 0.01)) "$label : fixed column widths name $($expCols[0]) | trade $($expCols[1]) | day $($expCols[2]) | total $($expCols[3]) (table $tableW, no stretch to the card edge $($tab.Width - 48); Eddy 11-11-2026)"
            $hdr = @('lblWrHdrName', 'lblWrHdrTrade', 'lblWrHdrMon', 'lblWrHdrTue', 'lblWrHdrWed', 'lblWrHdrThu', 'lblWrHdrFri', 'lblWrHdrSat', 'lblWrHdrSun', 'lblWrHdrTotal')
            $x = 24; foreach ($hn in $hdr) { if ([math]::Abs($R[$hn].X - $x) -gt 0.01 -or $R[$hn].Y -ne 88 -or $R[$hn].Height -ne 48) { throw "FAIL $label : header $hn not contiguous at X $x (X=$($R[$hn].X))" }; $x += $R[$hn].Width }
            Assert-True ([math]::Abs($x - (24 + $tableW)) -lt 0.01 -and $R.lblWrHdrName.Width -ge 140 -and $R.lblWrHdrMon.Width -ge 44) "$label : header Name | Trade | Mon..Sun | Week total contiguous, total width $tableW (name $($R.lblWrHdrName.Width), day $($R.lblWrHdrMon.Width))"
            $cells = @('lblWrCellName', 'lblWrCellTrade', 'lblWrCellMon', 'lblWrCellTue', 'lblWrCellWed', 'lblWrCellThu', 'lblWrCellFri', 'lblWrCellSat', 'lblWrCellSun', 'lblWrCellTotal')
            $x = 0; foreach ($c in $cells) { if ([math]::Abs($R[$c].X - $x) -gt 0.01) { throw "FAIL $label : cell $c not under its header (X=$($R[$c].X), expected $x)" }; $x += $R[$c].Width }
            Assert-True (($R.galWrLines.X -eq 24) -and ($R.galWrLines.Y -eq 136) -and ([math]::Abs($R.galWrLines.Width - $tableW) -lt 0.01) -and ([math]::Abs($x - $tableW) -lt 0.01) -and ($R.galWrLines.Height -eq 44 * 8) -and ($tab.Height -eq 136 + 44 * 8 + 24)) "$label : line gallery under the header, cells aligned with the header columns, 44 px per line, card ends 24 below the last line"
            Write-Output "PASS $label : $($script:layoutChecked) visible controls inside their parents, no sibling overlaps."
        }
    }
}
# --- scrHome (3-11-2026 Home redesign): five stacked categories, cmpTile grid, tiles 150 (>=1000) / 130 (700-999) / 110 or smaller (<700), at least 3 per row from 390 px (TP-HOME-02 point 7) ---------
$homeDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrHome.pa.yaml')))
$homeKids = $homeDoc['Screens']['scrHome']['Children']
$homeScroll = ($homeKids | Where-Object { @($_.Keys)[0] -eq 'conHomeScroll' })['conHomeScroll']
Assert-True (([string]$homeScroll['Properties']['LayoutOverflowY'] -eq '=LayoutOverflow.Scroll') -and ([string]$homeScroll['Properties']['LayoutGap'] -eq '=32') -and ([string]$homeScroll['Properties']['PaddingTop'] -eq '=32') -and ([string]$homeScroll['Properties']['Fill'] -eq '=Color.White')) 'scrHome: white page, vertical scroll, category gap 32, padding top 32'
$homeCats = @($homeScroll['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($homeCats -join ',') -ceq 'conHomeTeamHours,conHomeMasterData,conHomeInventory,conHomeCadTools,conHomeKnowledge') 'scrHome: categories in order Team & hours, Master data, Inventory, CAD tools, Knowledge'
foreach ($c in @(@(1366, 768), @(1280, 720), @(1000, 768), @(999, 768), @(900, 768), @(700, 768), @(699, 768), @(414, 800), @(390, 844), @(360, 640))) {
    $W = $c[0]; $Hh = $c[1]; $label = "scrHome $W x $Hh"
    $state = @{ Rects = @{}; Errors = @{}; Kind = '' }
    $screenRect = @{ X = 0; Y = 0; Width = $W; Height = $Hh }
    for ($pass = 0; $pass -lt 8; $pass++) { $state.Errors = @{}; Walk-Children $homeKids $screenRect $null $state }
    if ($state.Errors.Count -gt 0) { throw "FAIL $label : unresolved geometry formulas: $(($state.Errors.GetEnumerator() | ForEach-Object { $_.Key + ' -> ' + $_.Value }) -join '; ')" }
    $script:layoutChecked = 0
    Collect-Checks $homeKids 'screen' $screenRect $false $null $state 'scrHome' $label
    $m = $state.Rects['lblHomeMetrics']; $pad = $m.X; $contentW = $m.Y; $tile = $m.Width; $perRow = $m.Height; $title = $state.Rects['cmpHomeTitle']
    $expTile = if ($W -ge 1000) { 150 } elseif ($W -ge 700) { 130 } else { [math]::Min(110, [math]::Floor(($W - 2 * 16 - 16 - 20) / 3)) }
    Assert-True (($title.Height -eq 60) -and ($title.Width -eq $W) -and ($tile -eq $expTile) -and ($pad -eq $(if ($W -lt 700) { 16 } else { 40 })) -and ($pad + $contentW + 16 + $pad -eq $W)) "$label : title 60, tile $tile, side padding $pad, content width $contentW (16 px scrollbar reserve)"
    Assert-True (($perRow -ge 3) -and ($perRow * $tile + ($perRow - 1) * 10 -le $contentW)) "$label : $perRow tiles of $tile per row (at least 3) fit the content width $contentW"
    $y = 32
    foreach ($cn in $homeCats) {
        $cr = $state.Rects[$cn]; $cdef = ($homeScroll['Children'] | Where-Object { @($_.Keys)[0] -eq $cn })[$cn]
        $tiles = @($cdef['Children'] | ForEach-Object { @($_.Keys)[0] } | Where-Object { $_ -like 'cmpTile*' })
        $rows = [math]::Ceiling($tiles.Count / $perRow)
        Assert-True (($cr.Width -eq $contentW) -and ($cr.Height -eq 46 + $rows * $tile + ($rows - 1) * 10)) "$label : $cn $($tiles.Count) tiles in $rows row(s), height $($cr.Height) fits header + line + 12 + rows"
        $hdr = $state.Rects[(@($cdef['Children'] | ForEach-Object { @($_.Keys)[0] } | Where-Object { $_ -like 'lblHomeHeader*' })[0])]; $ln = $state.Rects[(@($cdef['Children'] | ForEach-Object { @($_.Keys)[0] } | Where-Object { $_ -like 'recHomeLine*' })[0])]
        Assert-True (($ln.Y - ($hdr.Y + $hdr.Height) -eq 8) -and ($ln.Height -eq 2) -and ($ln.Width -eq $contentW)) "$label : $cn line 8 px under the header, 2 px, full content width"
        $firstRowY = $null
        foreach ($tn in $tiles) {
            $tr = $state.Rects[$tn]
            if (($tr.Width -ne $tile) -or ($tr.Height -ne $tile)) { throw "FAIL $label : $tn is $($tr.Width) x $($tr.Height), expected $tile square" }
            if ($tr.X + $tr.Width -gt $contentW + 0.01) { throw "FAIL $label : $tn exceeds the content width ($($tr.X + $tr.Width) > $contentW)" }
            if ($tr.Y + $tr.Height -gt $cr.Height + 0.01) { throw "FAIL $label : $tn exceeds its category height" }
            if ($null -eq $firstRowY) { $firstRowY = $tr.Y }
        }
        Assert-True ($firstRowY -eq $ln.Y + $ln.Height + 12) "$label : $cn tile row starts 12 px under the line"
        $y += $cr.Height + 32
    }
    $contentH = $y - 32 + 32
    Write-Output "PASS $label : $($script:layoutChecked) visible controls inside their parents, no sibling overlaps; five categories stacked with gap 32, content height $contentH vs viewport $($Hh - 60) ($(if ($contentH -gt $Hh - 60) { 'scrolls' } else { 'fits' }))."
}
Write-Output 'Test-Layout covers: bounds (X>=0, Y>=0, right edge inside the parent; bottom edge inside the parent except in the scrolling body), sibling overlaps among visible controls and instances, no Visible formula on cmpField instances, the title/message bar/body/footer stack and the two-card arrangement, for scrContractors, scrProjects and scrWorkers at 1366, 1000 and 700 x 768 with and without a message; scrWeekReport (cmpReportFooter, selection card, table card, table columns, one pass per gallery line type) at the same sizes. NOT covered: component internals (see Test-Components/Test-FooterRow), text clipping and rendering in Studio.'
