# Structural checks for the canvas components in Src\Component (stap 2, 30-10-2026): cmpTitleBar, cmpMessageBar, cmpFooter, cmpField, cmpListCard.
# Proves source structure only: no Studio import, binding of component properties, rendering of HtmlViewer/ModernSpinner or event wiring.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
function Assert-True($cond, $label) { if (!$cond) { throw "FAIL $label" }; Write-Output "PASS $label" }
function Index-CmpControls($entries, $index) { foreach ($entry in $entries) { $name = @($entry.Keys)[0]; $index[$name] = $entry[$name]; Index-CmpControls $entry[$name]['Children'] $index } }
$dir = Join-Path $projectRoot 'Src\Component'
$files = @{}
foreach ($f in Get-ChildItem $dir -Filter *.pa.yaml) { $files[$f.Name -replace '\.pa\.yaml$', ''] = [IO.File]::ReadAllText($f.FullName) }
Assert-True (($files.Keys | Sort-Object) -join ',' -eq 'cmpField,cmpFooter,cmpListCard,cmpMessageBar,cmpTitleBar') 'exactly five component files, one component per file (cmpTitleBar, cmpMessageBar, cmpFooter, cmpField, cmpListCard)'
foreach ($n in $files.Keys) { Assert-True (!$files[$n].Contains("`r")) "$n.pa.yaml uses LF line endings" }
$defs = $script:componentDefs
$idx = @{}
foreach ($n in $defs.Keys) { $idx[$n] = @{}; Index-CmpControls $defs[$n]['Children'] $idx[$n] }

# (1) Property contracts ---------------------------------------------------------------------------------
$contract = @{
    cmpTitleBar   = @{ Title = 'Input:Text'; Busy = 'Input:Boolean'; BusyLabel = 'Input:Text'; Logo = 'Input:Image' }
    cmpMessageBar = @{ Kind = 'Input:Text'; Head = 'Input:Text'; Body = 'Input:Text'; CloseLabel = 'Input:Text'; BarHeight = 'Output:Number'; OnClose = 'Event:None' }
    cmpFooter     = @{ HomeText = 'Input:Text'; NewText = 'Input:Text'; RefreshText = 'Input:Text'; DiscardText = 'Input:Text'; SaveText = 'Input:Text'
                       HomeEnabled = 'Input:Boolean'; NewEnabled = 'Input:Boolean'; RefreshEnabled = 'Input:Boolean'; DiscardEnabled = 'Input:Boolean'; SaveEnabled = 'Input:Boolean'
                       OnHome = 'Event:None'; OnNew = 'Event:None'; OnRefresh = 'Event:None'; OnDiscard = 'Event:None'; OnSave = 'Event:None' }
    cmpField      = @{ Label = 'Input:Text'; Required = 'Input:Boolean'; InputType = 'Input:Text'; Value = 'Input:Text'; Items = 'Input:Table'; Invalid = 'Input:Boolean'; Enabled = 'Input:Boolean'; HintText = 'Input:Text'; MaxLength = 'Input:Number'
                       CurrentValue = 'Output:Text'; OnChange = 'Event:None' }
    cmpListCard   = @{ Items = 'Input:Table'; SelectedID = 'Input:Number'; SearchHint = 'Input:Text'; CountText = 'Input:Text'; ShowInactiveText = 'Input:Text'; OnText = 'Input:Text'; OffText = 'Input:Text'; ShowInactive = 'Input:Boolean'; Enabled = 'Input:Boolean'
                       SearchText = 'Output:Text'; ShowInactiveValue = 'Output:Boolean'; OnSelectRow = 'Event:None'; OnToggleShowInactive = 'Event:None' }
}
foreach ($c in $contract.Keys) {
    $cps = $defs[$c]['CustomProperties']
    Assert-True ($cps.Count -eq $contract[$c].Count) "$c has exactly $($contract[$c].Count) custom properties"
    foreach ($p in $contract[$c].Keys) {
        $kind, $type = $contract[$c][$p] -split ':'
        $cp = $cps[$p]
        Assert-True ($null -ne $cp -and $cp['PropertyKind'] -eq $kind) "$c.$p is $kind"
        if ($kind -eq 'Event') { Assert-True ($cp['ReturnType'] -eq $type) "$c.$p ReturnType None" } else { Assert-True ($cp['DataType'] -eq $type) "$c.$p DataType $type" }
        if ($kind -eq 'Input' -and $type -ne 'Image') { Assert-True ($cp.ContainsKey('Default') -and ([string]$cp['Default']).StartsWith('=')) "$c.$p has a Default formula" }
    }
    Assert-True (!$defs[$c].ContainsKey('AccessAppScope') -or $defs[$c]['AccessAppScope'] -eq $false) "$c does not use app scope (pure presentation, no app variables)"
    foreach ($bad in 'X', 'Y', 'Visible') { Assert-True (!$defs[$c]['Properties'].ContainsKey($bad)) "$c Properties has no reserved $bad" }
}
foreach ($p in 'HomeEnabled', 'NewEnabled', 'RefreshEnabled', 'DiscardEnabled', 'SaveEnabled') { Assert-True ($defs['cmpFooter']['CustomProperties'][$p]['Default'] -eq '=false') "cmpFooter.$p default is fail-closed (=false)" }
Assert-True ($defs['cmpTitleBar']['CustomProperties']['Busy']['Default'] -eq '=false') 'cmpTitleBar.Busy default =false'

# (2) Pure presentation: no app state, navigation or writes ----------------------------------------------
foreach ($c in $files.Keys) {
    $body = ($files[$c] -split "`n" | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*Description:' }) -join "`n"
    foreach ($pat in '\bvar[A-Z]\w*', '\bcol[A-Z]\w*', '\bT\.\w+', '\bLangNl\b', '\bNavigate\(', '\bPatch\(', '\bNotify\(', '\bSet\(', '\bCollect\(', '\bRefresh\(', '\bUpdateContext\(', '\bClearCollect\(', '\bRemove\(', '\bRemoveIf\(', '\bUpdate\(', '\bUpdateIf\(', '\bSubmitForm\(', '\bLaunch\(', '\bBack\(', '\bExit\(', 'GEA_logo_white') {
        Assert-True ($body -cnotmatch $pat) "$c has no app-level reference ($pat)"
    }
    Assert-True ($body -notmatch 'Len\([^)]*\)\s*\*\s*\d') "$c has no estimated text widths (Len(...)*n)"
    Assert-True ($body -notmatch 'AutoWidth') "$c has no measured/auto widths"
}

# (3) cmpTitleBar -----------------------------------------------------------------------------------------
$t = $idx['cmpTitleBar']; $tp = $defs['cmpTitleBar']['Properties']
Assert-True ($tp['Fill'] -eq '=ColorValue("#0303B8")' -and $tp['Height'] -eq '=60') 'cmpTitleBar: Fill #0303B8, height 60'
$title = $t['lblCmpTitleText']['Properties']
Assert-True ($title['Text'] -eq '=cmpTitleBar.Title' -and $title['Color'] -eq '=Color.White' -and $title['Size'] -eq '=22' -and $title['FontWeight'] -eq '=FontWeight.Semibold' -and $title['PaddingLeft'] -eq '=129' -and $title['PaddingRight'] -eq '=72' -and $title['Wrap'] -eq '=false' -and $title['Width'] -eq '=Parent.Width' -and $title['Height'] -eq '=Parent.Height') 'cmpTitleBar title: white 22 Semibold Inter, PaddingLeft 129, full width'
$logo = $t['imgCmpTitleLogo']; $lp = $logo['Properties']
Assert-True ($logo['Control'] -eq 'Image@2.2.3' -and $lp['Width'] -eq '=99' -and $lp['Height'] -eq '=30' -and $lp['ImagePosition'] -eq '=ImagePosition.Fit' -and $lp['Image'] -eq '=cmpTitleBar.Logo' -and $lp['X'] -eq '=lblCmpTitleText.X+15' -and $lp['Y'] -eq '=lblCmpTitleText.Y+(lblCmpTitleText.Height-Self.Height)/2') 'cmpTitleBar logo: Image@2.2.3 99x30 Fit, X title+15, centred, Image = Logo input (media passed by host)'
Assert-True (!$lp.ContainsKey('Fill') -and !$lp.ContainsKey('OnSelect') -and $lp['AccessibleLabel'] -eq '="GEA"') 'cmpTitleBar logo: no Fill/OnSelect, AccessibleLabel GEA'
$order = @($defs['cmpTitleBar']['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True ($order.IndexOf('imgCmpTitleLogo') -eq $order.IndexOf('lblCmpTitleText') + 1) 'cmpTitleBar: logo directly after the title label'
$sp = $t['spnCmpTitleBusy']; $spp = $sp['Properties']
Assert-True ($sp['Control'] -eq 'ModernSpinner@1.1.0' -and $spp['SpinnerColor'] -eq '=Color.White' -and $spp['TrackColor'] -eq '=ColorValue("#0303B8")' -and $spp['Width'] -eq '=24' -and $spp['Height'] -eq '=24' -and $spp['Visible'] -eq '=cmpTitleBar.Busy' -and $spp['X'] -eq '=Parent.Width-24-Self.Width') 'cmpTitleBar spinner: ModernSpinner@1.1.0 white on #0303B8, 24x24, right margin 24, Visible = Busy'

# (4) cmpMessageBar ---------------------------------------------------------------------------------------
$m = $idx['cmpMessageBar']; $mp = $defs['cmpMessageBar']['Properties']
Assert-True ($mp['Height'] -eq '=40' -and $mp['BarHeight'] -eq '=If(cmpMessageBar.Kind in ["Error","Warning","Success"],40,0)') 'cmpMessageBar: height 40, BarHeight 0 unless Kind is Error/Warning/Success (unknown Kind shows nothing)'
$fill = $m['recCmpMsgFill']['Properties']['Fill']
Assert-True ($fill -eq '=Switch(cmpMessageBar.Kind,"Error",ColorValue("#DB1E28"),"Warning",ColorValue("#F29400"),"Success",ColorValue("#1AFF80"),Color.Transparent)') 'cmpMessageBar fill: Error #DB1E28, Warning #F29400, Success #1AFF80, otherwise transparent'
Assert-True ($m['recCmpMsgFill']['Properties']['Visible'] -eq '=(cmpMessageBar.Kind in ["Error","Warning","Success"])') 'cmpMessageBar fill hidden unless Kind is Error/Warning/Success'
$texts = @($m.Keys | Where-Object { $m[$_]['Control'] -like 'Label@*' -or $m[$_]['Control'] -like 'HtmlViewer@*' })
Assert-True ($texts.Count -eq 1 -and $m[$texts[0]]['Control'] -eq 'HtmlViewer@2.1.0') 'cmpMessageBar: the text is exactly one HtmlViewer@2.1.0 (no separate head/body labels)'
$h = $m[$texts[0]]['Properties']; $html = [string]$h['HtmlText']
foreach ($css in 'width:100%', 'white-space:nowrap', 'overflow:hidden', 'text-overflow:ellipsis', 'font-family:Inter,Arial,sans-serif', 'font-size:14px', '<b>', '</b>') { Assert-True ($html.Contains($css)) "cmpMessageBar HtmlText contains $css" }
Assert-True ($h['Size'] -eq '=14' -and $h['Font'] -eq '="Inter, Arial, sans-serif"' -and $h['Width'] -eq '=Max(0,Parent.Width-Self.X-56)') 'cmpMessageBar text: Inter 14, width = bar - left 24 - right 56 (icon), no measured width'
$colorOk = $h['Color'] -eq '=If(cmpMessageBar.Kind="Error",Color.White,ColorValue("#000F41"))' -and $html.Contains('If(cmpMessageBar.Kind="Error","#FFFFFF","#000F41")')
Assert-True $colorOk 'cmpMessageBar text colour: white on Error, #000F41 on Warning/Success (control and inline CSS)'
$subs = @{ 'cmpMessageBar.Head' = $null; 'cmpMessageBar.Body' = $null }
foreach ($field in @($subs.Keys)) {
    $expect = 'Substitute(Substitute(Substitute(Substitute(Substitute(' + $field + ',"&","&amp;"),"<","&lt;"),">","&gt;"),"""","&quot;"),"' + "'" + '","&#39;")'
    Assert-True ($html.Contains($expect)) "cmpMessageBar HtmlText escapes $field (& first, then < > double quote single quote)"
    Assert-True (([regex]::Matches($html, [regex]::Escape($field))).Count -eq 1) "cmpMessageBar HtmlText uses $field only through the escape"
}
$ico = $m['icoCmpMsgClose']; $ip = $ico['Properties']
Assert-True ($ico['Control'] -eq 'Classic/Icon@2.5.0' -and $ip['Icon'] -eq '=Icon.Cancel' -and $ip['OnSelect'] -eq '=cmpMessageBar.OnClose()' -and $ip['X'] -eq '=Parent.Width-Self.Width-16') 'cmpMessageBar close: Classic/Icon Icon.Cancel at the right, OnSelect = OnClose()'
foreach ($n in 'htmlCmpMsgText', 'icoCmpMsgClose') { Assert-True ($m[$n]['Properties']['Visible'] -eq '=(cmpMessageBar.Kind in ["Error","Warning","Success"])') "cmpMessageBar $n hidden unless Kind is Error/Warning/Success" }
Assert-True ($m['htmlCmpMsgText']['Properties']['Tooltip'] -eq '=cmpMessageBar.Head & " " & cmpMessageBar.Body') 'cmpMessageBar text has Tooltip = Head and Body (full text when the line is cut)'

# (5) cmpFooter -------------------------------------------------------------------------------------------
$f = $idx['cmpFooter']; $fp = $defs['cmpFooter']['Properties']
Assert-True ($fp['Fill'] -eq '=Color.White' -and $fp['Height'] -eq '=68') 'cmpFooter: white, height 68'
$line = $f['recCmpFooterLine']['Properties']
Assert-True ($line['Fill'] -eq '=ColorValue("#DCDCDC")' -and $line['Height'] -eq '=1' -and $line['Y'] -eq '=0' -and $line['Width'] -eq '=Parent.Width') 'cmpFooter top line 1 px #DCDCDC'
$met = $f['lblCmpFooterMetrics']['Properties']
Assert-True ($met['X'] -eq '=40' -and $met['Width'] -eq '=12' -and $met['Height'] -eq '=40') 'cmpFooter metrics: margin 40, gap 12, button height 40'
$row = $f['conCmpFooterRow']
$rowKids = @($row['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($rowKids -join ',') -eq 'btnCmpHome,icoCmpHome,btnCmpNew,btnCmpRefresh,btnCmpDiscard,btnCmpSave') 'cmpFooter: Home (with icon) left, New, Refresh, Discard, Save right, all direct children of one row'
Assert-True ($f['conCmpFooter']['Properties']['LayoutWrap'] -eq '=false' -and $f['conCmpFooter']['Properties']['LayoutOverflowX'] -eq '=LayoutOverflow.Scroll' -and $f['conCmpFooter']['Properties']['LayoutOverflowY'] -eq '=LayoutOverflow.Hide') 'cmpFooter: LayoutWrap false, horizontal overflow Scroll, vertical Hide'
$events = @{ btnCmpHome = @('HomeText', 'HomeEnabled', 'OnHome', 110); btnCmpNew = @('NewText', 'NewEnabled', 'OnNew', 90); btnCmpRefresh = @('RefreshText', 'RefreshEnabled', 'OnRefresh', 110); btnCmpDiscard = @('DiscardText', 'DiscardEnabled', 'OnDiscard', 188); btnCmpSave = @('SaveText', 'SaveEnabled', 'OnSave', 140) }
foreach ($b in $events.Keys) {
    $p = $f[$b]['Properties']; $txt, $en, $ev, $w = $events[$b]
    Assert-True ($f[$b]['Control'] -eq 'Classic/Button@2.2.0' -and !$p.ContainsKey('AccessibleLabel')) "$b is Classic/Button@2.2.0 without AccessibleLabel"
    Assert-True ($p['Text'] -eq "=cmpFooter.$txt" -and $p['DisplayMode'] -eq "=If(cmpFooter.$en,DisplayMode.Edit,DisplayMode.Disabled)" -and $p['OnSelect'] -eq "=If(cmpFooter.$en,cmpFooter.$ev())") "${b} contract: Text=$txt, DisplayMode and OnSelect both gated by $en, OnSelect only raises $ev"
    Assert-True ($p['Height'] -eq '=lblCmpFooterMetrics.Height' -and $p['Y'] -eq '=(Parent.Height-Self.Height)/2' -and $p['Width'] -eq "=$w" -and $p['Size'] -eq '=14' -and $p['FontWeight'] -eq '=FontWeight.Semibold' -and $p['Align'] -eq '=Align.Center' -and $p['VerticalAlign'] -eq '=VerticalAlign.Middle' -and $p['PaddingTop'] -eq '=0' -and $p['PaddingBottom'] -eq '=0' -and $p['RadiusTopLeft'] -eq '=8') "${b}: height 40, vertical centre (Y14), width $w, Inter 14 Semibold, radius 8"
    Assert-True ($p['DisabledFill'] -eq '=ColorValue("#E6E6E6")' -and $p['DisabledColor'] -eq '=ColorValue("#787878")' -and $p['DisabledBorderColor'] -eq '=ColorValue("#E6E6E6")') "$b disabled #E6E6E6/#787878"
}
$nav = $f['btnCmpHome']['Properties']
Assert-True ($nav['Fill'] -eq '=ColorValue("#0303B8")' -and $nav['Color'] -eq '=Color.White' -and $nav['HoverFill'] -eq '=ColorValue("#000F41")' -and $nav['PressedFill'] -eq '=ColorValue("#000F41")') 'cmpFooter Home: navigation role (#0303B8 white, hover/pressed #000F41)'
foreach ($b in 'btnCmpNew', 'btnCmpRefresh', 'btnCmpDiscard') {
    $p = $f[$b]['Properties']
    Assert-True ($p['Fill'] -eq '=Color.White' -and $p['Color'] -eq '=ColorValue("#0303B8")' -and $p['BorderColor'] -eq '=ColorValue("#0303B8")' -and $p['BorderThickness'] -eq '=1' -and $p['HoverFill'] -eq '=ColorValue("#D5EDFF")' -and $p['PressedFill'] -eq '=ColorValue("#D5EDFF")') "$b secondary: white, 1 px #0303B8 border/text, hover #D5EDFF"
}
$pri = $f['btnCmpSave']['Properties']
Assert-True ($pri['Fill'] -eq '=ColorValue("#1AFF80")' -and $pri['Color'] -eq '=ColorValue("#000F41")' -and $pri['HoverFill'] -eq '=ColorValue("#18DD6E")' -and $pri['PressedFill'] -eq '=ColorValue("#18DD6E")') 'cmpFooter Save: primary green #1AFF80 / #18DD6E, text #000F41'
$xs = @{ btnCmpHome = $f['btnCmpHome']['Properties']['X']; btnCmpNew = $f['btnCmpNew']['Properties']['X']; btnCmpRefresh = $f['btnCmpRefresh']['Properties']['X']; btnCmpDiscard = $f['btnCmpDiscard']['Properties']['X']; btnCmpSave = $f['btnCmpSave']['Properties']['X'] }
Assert-True ($xs['btnCmpHome'] -eq '=lblCmpFooterMetrics.X' -and $xs['btnCmpSave'] -eq '=Parent.Width-lblCmpFooterMetrics.X-Self.Width' -and $xs['btnCmpDiscard'] -eq '=btnCmpSave.X-lblCmpFooterMetrics.Width-Self.Width' -and $xs['btnCmpRefresh'] -eq '=btnCmpDiscard.X-lblCmpFooterMetrics.Width-Self.Width' -and $xs['btnCmpNew'] -eq '=btnCmpRefresh.X-lblCmpFooterMetrics.Width-Self.Width') 'cmpFooter: right buttons chained with 12 px gaps, margins 40'
Assert-True ($f['icoCmpHome']['Properties']['Icon'] -eq '=Icon.Home' -and $f['icoCmpHome']['Properties']['OnSelect'] -eq '=Select(btnCmpHome)') 'cmpFooter: Home icon selects the Home button (so the guard stays in the gated OnSelect)'
Assert-True ($f['icoCmpHome']['Properties']['TabIndex'] -eq '=-1' -and $f['icoCmpHome']['Properties']['AccessibleLabel'] -eq '=""') 'cmpFooter: Home icon is decorative (TabIndex -1, AccessibleLabel empty); the button carries the label'

# Geometry helper: evaluates the simple X/Y/Width/Height formulas of one component for a given Parent size (no measured text).
function Get-Geo($ctrls, $name, $prop, $env) {
    $f = [string]$ctrls[$name]['Properties'][$prop]
    if ($f -eq '') { throw "Geo: $name.$prop missing" }
    $s = $f.Substring(1)
    $s = $s -replace 'Parent\.TemplateWidth', "$($env.tw)" -replace 'Parent\.TemplateHeight', "$($env.th)" -replace 'Parent\.Width', "$($env.pw)" -replace 'Parent\.Height', "$($env.ph)"
    $s = [regex]::Replace($s, '\bSelf\.(X|Y|Width|Height)\b', [Text.RegularExpressions.MatchEvaluator] { param($m) '(' + (Get-Geo $ctrls $name $m.Groups[1].Value $env) + ')' })
    $s = [regex]::Replace($s, '\b([A-Za-z]\w*)\.(X|Y|Width|Height)\b', [Text.RegularExpressions.MatchEvaluator] { param($m) if ($ctrls.ContainsKey($m.Groups[1].Value)) { '(' + (Get-Geo $ctrls $m.Groups[1].Value $m.Groups[2].Value $env) + ')' } else { $m.Value } })
    $s = $s -replace 'IsBlank\(ThisItem\.ChipText\)', $(if ($env.chip) { '$false' } else { '$true' }) -replace 'cmpListCard\.ShowInactive', $(if ($env.show) { '$true' } else { '$false' })
    $s = $s -creplace '\bMax\(', '[Math]::Max('
    $prev = ''
    while ($s -cmatch '\bIf\(') {
        $s = [regex]::Replace($s, '\bIf\(([^(),]+),((?:[^,()]|\([^()]*\))+),((?:[^,()]|\([^()]*\))+)\)', '$$(if($1){$2}else{$3})')
        if ($s -ceq $prev) { throw "Geo: cannot evaluate $f" }
        $prev = $s
    }
    return [double](Invoke-Expression $s)
}
function Rect($ctrls, $name, $env) { [pscustomobject]@{ n = $name; x = (Get-Geo $ctrls $name 'X' $env); y = (Get-Geo $ctrls $name 'Y' $env); w = (Get-Geo $ctrls $name 'Width' $env); h = (Get-Geo $ctrls $name 'Height' $env) } }
function Overlap($a, $b) { $a.x -lt ($b.x + $b.w) -and $b.x -lt ($a.x + $a.w) -and $a.y -lt ($b.y + $b.h) -and $b.y -lt ($a.y + $a.h) }

# (7) cmpField ---------------------------------------------------------------------------------------------
$fd = $defs['cmpField']; $fi = $idx['cmpField']; $fdp = $fd['Properties']
Assert-True ($fdp['Height'] -eq '=58' -and $fdp['Fill'] -eq '=Color.Transparent') 'cmpField: component height 58, transparent'
Assert-True ($fd['CustomProperties']['Value']['RaiseOnReset'] -eq $true -and $fdp['OnReset'] -eq '=Reset(txtCmpFieldInput); Reset(ddCmpFieldInput)') 'cmpField reset contract: Value RaiseOnReset, OnReset resets the text input and the dropdown'
Assert-True ($fd['CustomProperties']['Enabled']['Default'] -eq '=false' -and $fd['CustomProperties']['InputType']['Default'] -eq '="text"' -and $fd['CustomProperties']['Invalid']['Default'] -eq '=false') 'cmpField: Enabled fail-closed =false, InputType default text, Invalid default false'
Assert-True ($fd['CustomProperties']['Items']['Default'] -eq '=Filter(Table({Value: ""}),false)' -and $fd['CustomProperties']['MaxLength']['Default'] -eq '=255') 'cmpField: Items default is an empty table with column Value, MaxLength 255'
Assert-True ($fdp['CurrentValue'] -eq '=If(cmpField.InputType="dropdown",Coalesce(ddCmpFieldInput.Selected.Value,""),Coalesce(txtCmpFieldInput.Text,""))') 'cmpField output CurrentValue: dropdown selection or empty string (an explicit empty choice never returns the old value), otherwise the text'
$itemsF = [string]$fi['ddCmpFieldInput']['Properties']['Items']
Assert-True ($itemsF -eq '=If(IsBlank(cmpField.Value) || !IsBlank(LookUp(cmpField.Items,Value=cmpField.Value)),cmpField.Items,Ungroup(Table({t: ShowColumns(cmpField.Items,"Value")},{t: Table({Value: cmpField.Value})}),"t"))') 'cmpField dropdown Items: host Items plus one extra row {Value: Value} when Value is filled and not in Items (shown as-is)'
# Interpreter fixtures: the same rules evaluated in PowerShell (dropdown rows and CurrentValue), proving the intended behaviour of the formulas above.
function Fx-Rows($items, $value) { if ([string]::IsNullOrEmpty($value) -or ($items -contains $value)) { return @($items) } else { return @($items) + @($value) } }
function Fx-Current($rows, $selected) { if ($null -eq $selected -or $selected -eq '') { return '' } else { return $selected } }
$fxRows = Fx-Rows @('Active', 'On hold', 'Closed') 'Legacy'
Assert-True ($fxRows -contains 'Legacy' -and $fxRows.Count -eq 4) 'fixture: a Value outside the list is shown as an extra row (as-is)'
Assert-True ((Fx-Current $fxRows 'Legacy') -eq 'Legacy') 'fixture: the as-is value is the default selection, CurrentValue equals Value so it is not dirty'
Assert-True ((Fx-Rows @('Active', 'Closed') 'Active').Count -eq 2 -and (Fx-Rows @('Active', 'Closed') '').Count -eq 2) 'fixture: no extra row when Value is in the list or empty'
Assert-True ((Fx-Current $fxRows $null) -eq '') 'fixture: an explicit empty choice gives an empty string, not the old value'
$lblN = @($fi.Keys | Where-Object { $fi[$_]['Control'] -like 'Label@*' -or $fi[$_]['Control'] -like 'HtmlViewer@*' })
Assert-True ($lblN.Count -eq 1 -and $fi[$lblN[0]]['Control'] -eq 'HtmlViewer@2.1.0') 'cmpField: exactly one HtmlViewer@2.1.0 for the label (no separate star control)'
$lp2 = $fi['htmlCmpFieldLabel']['Properties']; $lh = [string]$lp2['HtmlText']
foreach ($css in 'font-family:Inter,Arial,sans-serif', 'font-size:13px', 'font-weight:600', 'color:#000000', 'white-space:nowrap', 'overflow:hidden', 'text-overflow:ellipsis', 'width:100%') { Assert-True ($lh.Contains($css)) "cmpField label HtmlText contains $css" }
$starLit = "If(cmpField.Required,""<span style='color:#DB1E28'>&nbsp;*</span>"","""")"
Assert-True ($lh.Contains($starLit)) 'cmpField label: red star <span style=color:#DB1E28>&nbsp;*</span> only when Required'
Assert-True ($lh.IndexOf("</span>"" & " + $starLit) -gt 0) 'cmpField label: the star follows directly after the (ellipsis) label text span'
$esc = 'Substitute(Substitute(Substitute(Substitute(Substitute(cmpField.Label,"&","&amp;"),"<","&lt;"),">","&gt;"),"""","&quot;"),"' + "'" + '","&#39;")'
Assert-True ($lh.Contains($esc) -and ([regex]::Matches($lh, [regex]::Escape('cmpField.Label'))).Count -eq 1) 'cmpField label: Label only through the escape (& first, then < > double quote single quote)'
Assert-True ($lp2['Height'] -eq '=18' -and $lp2['Y'] -eq '=0' -and $lp2['Width'] -eq '=Parent.Width' -and $lp2['Size'] -eq '=13' -and $lp2['Font'] -eq '="Inter, Arial, sans-serif"') 'cmpField label: height 18 at Y 0, full width, Inter 13'
$tx = $fi['txtCmpFieldInput']; $dd = $fi['ddCmpFieldInput']; $tp2 = $tx['Properties']; $dp2 = $dd['Properties']
Assert-True ($tx['Control'] -eq 'Classic/TextInput@2.3.2' -and $dd['Control'] -eq 'Classic/DropDown@2.3.1') 'cmpField inputs: Classic/TextInput@2.3.2 and Classic/DropDown@2.3.1'
Assert-True ($tp2['Visible'] -eq '=cmpField.InputType<>"dropdown"' -and $dp2['Visible'] -eq '=cmpField.InputType="dropdown"') 'cmpField: text input visible unless dropdown, dropdown visible only for dropdown'
foreach ($k in 'txtCmpFieldInput', 'ddCmpFieldInput') {
    $p = $fi[$k]['Properties']
    Assert-True ($p['Height'] -eq '=36' -and $p['Y'] -eq '=htmlCmpFieldLabel.Y+htmlCmpFieldLabel.Height+4' -and $p['X'] -eq '=0' -and $p['Width'] -eq '=Parent.Width' -and $p['Fill'] -eq '=Color.White' -and $p['Font'] -eq '="Inter, Arial, sans-serif"' -and $p['FontWeight'] -eq '=FontWeight.Normal' -and $p['Size'] -eq '=14' -and $p['Color'] -eq '=ColorValue("#000000")') "$k : 36 high, 4 px under the label, full width, white, Inter 14 Normal black"
    Assert-True ($p['FocusedBorderThickness'] -eq '=2' -and $p['DisabledColor'] -eq '=ColorValue("#000000")') "$k : focus 2 px, disabled text black"
    foreach ($bp in 'BorderColor', 'HoverBorderColor', 'FocusedBorderColor', 'PressedBorderColor', 'DisabledBorderColor') { Assert-True (([string]$p[$bp]).Contains('If(cmpField.Invalid,ColorValue("#DB1E28")')) "$k.$bp is red #DB1E28 when Invalid" }
    Assert-True (([string]$p['BorderThickness']).StartsWith('=If(cmpField.Invalid,2,')) "$k.BorderThickness is 2 when Invalid"
    Assert-True ($p['OnChange'] -eq '=If(cmpField.Enabled,cmpField.OnChange())') "$k.OnChange raises the event only while Enabled"
    Assert-True ($p['AccessibleLabel'] -eq '=cmpField.Label') "$k has AccessibleLabel = Label"
}
Assert-True ($tp2['BorderColor'] -match '"#9B9B9B"' -and $tp2['HoverBorderColor'] -match '"#5A5A5A"' -and $tp2['FocusedBorderColor'] -match '"#0303B8"' -and $tp2['PressedBorderColor'] -match '"#0303B8"' -and $tp2['RadiusTopLeft'] -eq '=4' -and $tp2['RadiusBottomRight'] -eq '=4') 'cmpField text: white, border #9B9B9B, hover #5A5A5A, focus/pressed #0303B8, radius 4'
Assert-True ($tp2['BorderThickness'] -eq '=If(cmpField.Invalid,2,If(cmpField.InputType="readonly",0,1))' -and $tp2['BorderColor'] -match 'If\(cmpField.InputType="readonly",Color.Transparent' -and $tp2['DisabledFill'] -eq '=If(cmpField.InputType="readonly",ColorValue("#F0F0F0"),Color.White)') 'cmpField readonly: #F0F0F0 without border; other disabled states white with border #9B9B9B'
Assert-True ($tp2['DisabledBorderColor'] -match '"#9B9B9B"' -and $tp2['DisplayMode'] -eq '=If(cmpField.Enabled && cmpField.InputType="text",DisplayMode.Edit,DisplayMode.Disabled)') 'cmpField text: disabled border #9B9B9B; readonly (and unknown InputType) is always Disabled, text only Edit while Enabled'
Assert-True ($tp2['Default'] -eq '=cmpField.Value' -and $tp2['HintText'] -eq '=cmpField.HintText' -and $tp2['MaxLength'] -eq '=cmpField.MaxLength') 'cmpField text: Default = Value, HintText, MaxLength from the inputs'
Assert-True ($dp2['Fill'] -eq '=Color.White' -and $dp2['DisabledFill'] -eq '=Color.White' -and $dp2['BorderColor'] -match '"#9B9B9B"' -and $dp2['DisabledBorderColor'] -match '"#9B9B9B"' -and $dp2['DisplayMode'] -eq '=If(cmpField.Enabled && cmpField.InputType="dropdown",DisplayMode.Edit,DisplayMode.Disabled)') 'cmpField dropdown: white, border #9B9B9B (decision c), Edit only while Enabled'
$ddStyle = @{ HoverFill = '=ColorValue("#D5EDFF")'; HoverColor = '=ColorValue("#000F41")'; PressedFill = '=ColorValue("#D5EDFF")'; PressedColor = '=ColorValue("#000F41")'; SelectionFill = '=ColorValue("#0303B8")'; SelectionColor = '=Color.White'; ChevronBackground = '=Color.White'; ChevronFill = '=ColorValue("#0303B8")'; ChevronHoverBackground = '=ColorValue("#D5EDFF")' }
foreach ($k in $ddStyle.Keys) { Assert-True ($dp2[$k] -eq $ddStyle[$k]) "cmpField dropdown $k per the GEA dropdown style" }
Assert-True ($dp2['HoverFill'] -ne $dp2['Fill'] -and $dp2['Items.Value'] -eq '=Value' -and $dp2['Default'] -eq '=cmpField.Value' -and $dp2['HoverBorderColor'] -match '"#5A5A5A"' -and $dp2['ChevronBackground'] -eq '=Color.White' -and $dp2['Items.Value'] -eq '=Value') 'cmpField dropdown: HoverFill differs from Fill, Default = Value, hover border #5A5A5A like the text field, chevron background white (hover #D5EDFF)'
Assert-True ($fd['Children'].Count -eq 3) 'cmpField: three children (label, text input, dropdown), no stacked or hidden extra controls'

# (8) cmpListCard ------------------------------------------------------------------------------------------
$ld = $defs['cmpListCard']; $li = $idx['cmpListCard']; $ldp = $ld['Properties']
Assert-True ($ld['CustomProperties']['Enabled']['Default'] -eq '=false' -and $ld['CustomProperties']['ShowInactive']['Default'] -eq '=false') 'cmpListCard: Enabled fail-closed =false, ShowInactive default false'
Assert-True ($ld['CustomProperties']['Items']['Default'] -eq '=Filter(Table({ID: 0, Title: "", Subtitle: "", Inactive: false, ChipText: ""}),false)') 'cmpListCard: Items default is an empty table with columns ID, Title, Subtitle, Inactive, ChipText'
$sr = $ld['CustomProperties']['OnSelectRow']
Assert-True ($sr['Parameters'].Count -eq 1 -and @($sr['Parameters'][0].Keys)[0] -eq 'RowID' -and $sr['Parameters'][0]['RowID']['DataType'] -eq 'Number') 'cmpListCard selection contract: OnSelectRow has exactly one parameter RowID (Number)'
Assert-True ($ldp['SearchText'] -eq '=txtCmpListSearch.Text' -and $ldp['ShowInactiveValue'] -eq '=cmpListCard.ShowInactive' -and $ldp['OnReset'] -eq '=Reset(txtCmpListSearch)') 'cmpListCard outputs: SearchText from the search field, ShowInactiveValue echoes the input, OnReset clears the search'
$card = $li['conCmpListCard']; $cp3 = $card['Properties']
Assert-True ($card['Control'] -eq 'GroupContainer@1.5.0' -and $card['Variant'] -eq 'ManualLayout' -and $cp3['DropShadow'] -eq '=DropShadow.Light' -and $cp3['Fill'] -eq '=Color.White' -and $cp3['RadiusTopLeft'] -eq '=8' -and $cp3['RadiusBottomRight'] -eq '=8' -and $cp3['Width'] -eq '=Parent.Width' -and $cp3['Height'] -eq '=Parent.Height' -and $ldp['Fill'] -eq '=Color.Transparent') 'cmpListCard card: white GroupContainer radius 8, DropShadow.Light (component fill transparent so the corners show)'
$se = $li['txtCmpListSearch']['Properties']
Assert-True ($li['txtCmpListSearch']['Control'] -eq 'Classic/TextInput@2.3.2' -and $se['X'] -eq '=24' -and $se['Y'] -eq '=24' -and $se['Width'] -eq '=Parent.Width-48' -and $se['Height'] -eq '=36' -and $se['Fill'] -eq '=Color.White' -and $se['BorderColor'] -eq '=ColorValue("#9B9B9B")' -and $se['HintText'] -eq '=cmpListCard.SearchHint' -and $se['PaddingLeft'] -eq '=40' -and $se['DisplayMode'] -eq '=If(cmpListCard.Enabled,DisplayMode.Edit,DisplayMode.Disabled)') 'cmpListCard search: padding 24, 36 high, white, border #9B9B9B, hint from SearchHint, Edit only while Enabled'
$ic = $li['icoCmpListSearch']['Properties']
Assert-True ($li['icoCmpListSearch']['Control'] -eq 'Classic/Icon@2.5.0' -and $ic['Icon'] -eq '=Icon.Search' -and $ic['AccessibleLabel'] -eq '=""') 'cmpListCard search icon: Classic/Icon Icon.Search, decorative (AccessibleLabel empty)'
$inf = $li['htmlCmpListInfo']; $ih = [string]$inf['Properties']['HtmlText']
Assert-True ($inf['Control'] -eq 'HtmlViewer@2.1.0') 'cmpListCard info row: one HtmlViewer@2.1.0 (count left, Show inactive label right, one line)'
foreach ($css in 'display:flex', 'white-space:nowrap', 'overflow:hidden', 'text-overflow:ellipsis', 'flex:1 1 0', 'flex:none', 'text-align:right') { Assert-True ($ih.Contains($css)) "cmpListCard info HtmlText contains $css" }
foreach ($field in 'cmpListCard.CountText', 'cmpListCard.ShowInactiveText') {
    $e2 = 'Substitute(Substitute(Substitute(Substitute(Substitute(' + $field + ',"&","&amp;"),"<","&lt;"),">","&gt;"),"""","&quot;"),"' + "'" + '","&#39;")'
    Assert-True ($ih.Contains($e2) -and ([regex]::Matches($ih, [regex]::Escape($field))).Count -eq 1) "cmpListCard info escapes $field"
}
$sw = $li['btnCmpListSwitch']; $swp = $sw['Properties']; $kn = $li['btnCmpListKnob']['Properties']
Assert-True ($sw['Control'] -eq 'Classic/Button@2.2.0' -and !$swp.ContainsKey('AccessibleLabel') -and $swp['Width'] -eq '=44' -and $swp['Height'] -eq '=24' -and $swp['RadiusTopLeft'] -eq '=12' -and $swp['Fill'] -eq '=If(cmpListCard.ShowInactive,ColorValue("#0303B8"),ColorValue("#B4B4B4"))' -and $swp['Tooltip'] -eq '=cmpListCard.ShowInactiveText & ": " & If(cmpListCard.ShowInactive,cmpListCard.OnText,cmpListCard.OffText)') 'cmpListCard switch: track 44x24 radius 12, #0303B8 on / #B4B4B4 off, tooltip with label and state'
Assert-True ($swp['OnSelect'] -eq '=If(cmpListCard.Enabled,cmpListCard.OnToggleShowInactive())' -and $swp['DisplayMode'] -eq '=If(cmpListCard.Enabled,DisplayMode.Edit,DisplayMode.Disabled)' -and $kn['OnSelect'] -eq '=Select(btnCmpListSwitch)' -and $kn['DisplayMode'] -eq '=btnCmpListSwitch.DisplayMode' -and $kn['Fill'] -eq '=Color.White' -and $kn['Width'] -eq '=18') 'cmpListCard switch contract: only raises OnToggleShowInactive while Enabled, never flips state; white 18 px knob selects the track'
$ga = $li['galCmpList']; $gp = $ga['Properties']
Assert-True ($ga['Control'] -eq 'Gallery@2.15.0' -and $gp['TemplateSize'] -eq '=64' -and $gp['TemplatePadding'] -eq '=0' -and $gp['Items'] -eq '=cmpListCard.Items' -and $gp['OnSelect'] -eq '=If(cmpListCard.Enabled && !IsBlank(galCmpList.Selected.ID),cmpListCard.OnSelectRow(galCmpList.Selected.ID))') 'cmpListCard gallery: Gallery@2.15.0 fixed row height 64, Items = Items input, OnSelect raises OnSelectRow(ID) only while Enabled (no own guard)'
$rowN = @($ga['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($rowN -join ',') -eq 'recCmpRowFill,recCmpRowBar,recCmpRowLine,htmlCmpRowTitle,htmlCmpRowSub,btnCmpRowChip') 'cmpListCard row: fill, selection bar, divider, title, subtitle, chip'
$row = @{}; Index-CmpControls $ga['Children'] $row
Assert-True ($row['recCmpRowFill']['Properties']['Fill'] -eq '=If(ThisItem.ID=cmpListCard.SelectedID,ColorValue("#D5EDFF"),Color.White)' -and $row['recCmpRowFill']['Properties']['HoverFill'] -match '#F0F0F0' -and $row['recCmpRowBar']['Properties']['Fill'] -eq '=ColorValue("#0303B8")' -and $row['recCmpRowBar']['Properties']['Width'] -eq '=3' -and $row['recCmpRowBar']['Properties']['Visible'] -eq '=ThisItem.ID=cmpListCard.SelectedID' -and $row['recCmpRowLine']['Properties']['Fill'] -eq '=ColorValue("#EDEDED")') 'cmpListCard row: selected (ID = SelectedID) #D5EDFF with 3 px #0303B8 bar, hover #F0F0F0, divider #EDEDED'
$th = [string]$row['htmlCmpRowTitle']['Properties']['HtmlText']; $sh = [string]$row['htmlCmpRowSub']['Properties']['HtmlText']
foreach ($css in 'white-space:nowrap', 'overflow:hidden', 'text-overflow:ellipsis', 'font-size:15px', 'font-weight:600', 'width:100%') { Assert-True ($th.Contains($css)) "cmpListCard row title contains $css" }
Assert-True ($th.Contains('If(ThisItem.Inactive,"#6B6B6B","#000F41")') -and $row['htmlCmpRowTitle']['Properties']['Color'] -eq '=If(ThisItem.Inactive,ColorValue("#6B6B6B"),ColorValue("#000F41"))') 'cmpListCard row title: #000F41, inactive #6B6B6B'
foreach ($css in 'white-space:nowrap', 'text-overflow:ellipsis', 'font-size:13px', 'color:#5A5A5A') { Assert-True ($sh.Contains($css)) "cmpListCard row subtitle contains $css" }
foreach ($pair in @(@($th, 'ThisItem.Title'), @($sh, 'ThisItem.Subtitle'))) {
    $e3 = 'Substitute(Substitute(Substitute(Substitute(Substitute(' + $pair[1] + ',"&","&amp;"),"<","&lt;"),">","&gt;"),"""","&quot;"),"' + "'" + '","&#39;")'
    Assert-True ($pair[0].Contains($e3) -and ([regex]::Matches($pair[0], [regex]::Escape($pair[1]))).Count -eq 1) "cmpListCard row escapes $($pair[1])"
}
$ch = $row['btnCmpRowChip']; $chp = $ch['Properties']
Assert-True ($ch['Control'] -eq 'Classic/Button@2.2.0' -and !$chp.ContainsKey('AccessibleLabel') -and $chp['DisplayMode'] -eq '=DisplayMode.Disabled' -and $chp['Visible'] -eq '=!IsBlank(ThisItem.ChipText)' -and $chp['Fill'] -eq '=ColorValue("#E6E6E6")' -and $chp['Text'] -eq '=ThisItem.ChipText') 'cmpListCard chip: Classic/Button Disabled #E6E6E6, only when ChipText is not empty'
Assert-True ($row['htmlCmpRowTitle']['Properties']['Width'] -match 'If\(IsBlank\(ThisItem.ChipText\),16,16\+btnCmpRowChip.Width\+8\)') 'cmpListCard row: the title gets less width when a chip is shown'
foreach ($n in 'htmlCmpRowTitle', 'htmlCmpRowSub', 'recCmpRowFill', 'recCmpRowBar', 'recCmpRowLine') { Assert-True ($row[$n]['Properties']['OnSelect'] -eq '=Select(Parent)') "cmpListCard row $n selects the row" }

# (9) Geometry: no overlaps inside the components at widths 200/280/360/512 -------------------------------------
foreach ($w in 200, 280, 360, 512) {
    $env = @{ pw = $w; ph = 58; tw = 0; th = 0; chip = $false; show = $false }
    $a = Rect $fi 'htmlCmpFieldLabel' $env; $b = Rect $fi 'txtCmpFieldInput' $env; $c = Rect $fi 'ddCmpFieldInput' $env
    Assert-True (!(Overlap $a $b) -and !(Overlap $a $c) -and ($b.y + $b.h) -eq 58 -and ($a.y + $a.h + 4) -eq $b.y -and $b.w -eq $w -and $a.w -eq $w) "cmpField width ${w}: label (0..18), 4 px gap, input (22..58), no overlap, full width"
    foreach ($show in $false, $true) {
        $env = @{ pw = $w; ph = 600; tw = 0; th = 0; chip = $false; show = $show }
        $s = Rect $li 'txtCmpListSearch' $env; $i = Rect $li 'htmlCmpListInfo' $env; $t = Rect $li 'btnCmpListSwitch' $env; $k = Rect $li 'btnCmpListKnob' $env; $g = Rect $li 'galCmpList' $env
        $ok = !(Overlap $s $i) -and !(Overlap $s $t) -and !(Overlap $i $t) -and !(Overlap $i $g) -and !(Overlap $t $g) -and !(Overlap $s $g) -and $i.w -ge 0 -and $g.h -gt 0 -and ($t.x + $t.w) -eq ($w - 24) -and $k.x -ge $t.x -and ($k.x + $k.w) -le ($t.x + $t.w) -and $k.y -ge $t.y -and ($k.y + $k.h) -le ($t.y + $t.h) -and ($i.y + $i.h) -le $g.y -and ($g.y + $g.h) -le 600 -and $i.y -eq $t.y -and $i.h -eq $t.h
        Assert-True $ok "cmpListCard width ${w} (switch on=$show): search, info row, switch and gallery do not overlap; knob inside the track; switch vertically aligned with the info row; right margin 24"
    }
    foreach ($chip in $false, $true) {
        $env = @{ pw = $w; ph = 600; tw = $w; th = 64; chip = $chip; show = $false }
        $t1 = Rect $row 'htmlCmpRowTitle' $env; $s1 = Rect $row 'htmlCmpRowSub' $env; $c1 = Rect $row 'btnCmpRowChip' $env
        $ok = !(Overlap $t1 $s1) -and $t1.w -ge 0 -and $s1.w -ge 0 -and ($s1.y + $s1.h) -le 64 -and ($t1.x + $t1.w) -le ($w - 16) -and ($s1.x + $s1.w) -le ($w - 16)
        if ($chip) { $ok = $ok -and !(Overlap $t1 $c1) -and !(Overlap $s1 $c1) -and ($t1.x + $t1.w + 8) -le $c1.x -and ($c1.x + $c1.w) -eq ($w - 16) }
        Assert-True $ok "cmpListCard row width ${w} (chip=$chip): title, subtitle and chip do not overlap and stay inside the row"
    }
}

# (6) Instance validation (Check-WeeklySource accepts valid CanvasComponent instances and rejects invalid ones)
$script:names = @{}; $script:controlCount = 0
Check-Control ([ordered]@{ cmpTestOk = [ordered]@{ Control = 'CanvasComponent'; ComponentName = 'cmpFooter'; Properties = [ordered]@{ X = '=0'; Y = '=0'; Width = '=Parent.Width'; HomeEnabled = '=true'; OnHome = '=Navigate(scrHome)' } } })
Assert-True ($script:controlCount -eq 1) 'Check-Control accepts a valid CanvasComponent instance (ComponentName, custom Input/Event properties)'
foreach ($case in @(
        @{ n = 'cmpTestUnknown'; v = [ordered]@{ Control = 'CanvasComponent'; ComponentName = 'cmpNope'; Properties = [ordered]@{} } },
        @{ n = 'cmpTestOutputOnInstance'; v = [ordered]@{ Control = 'CanvasComponent'; ComponentName = 'cmpMessageBar'; Properties = [ordered]@{ BarHeight = '=40' } } },
        @{ n = 'cmpTestOnResetOnInstance'; v = [ordered]@{ Control = 'CanvasComponent'; ComponentName = 'cmpField'; Properties = [ordered]@{ OnReset = '=false' } } },
        @{ n = 'cmpTestBadProp'; v = [ordered]@{ Control = 'CanvasComponent'; ComponentName = 'cmpFooter'; Properties = [ordered]@{ BarHeight = '=1' } } },
        @{ n = 'cmpTestNoName'; v = [ordered]@{ Control = 'CanvasComponent'; Variant = 'x'; ComponentName = 'cmpFooter'; Properties = [ordered]@{} } })) {
    $rejected = $false
    try { Check-Control ([ordered]@{ $case.n = $case.v }) } catch { $rejected = $true }
    Assert-True $rejected "Check-Control rejects invalid instance $($case.n)"
}
Write-Output 'Not verified locally: Studio import of ComponentDefinitions, rendering of HtmlViewer/ModernSpinner, property binding and event wiring.'

# (10) Accessibility: decorative/emulated parts are not tab stops --------------------------------------------
Assert-True ($li['btnCmpListSwitch']['Properties']['TabIndex'] -eq '=-1' -and $li['btnCmpListKnob']['Properties']['TabIndex'] -eq '=-1') 'cmpListCard: switch track and knob TabIndex -1 (the row/host handles keyboard access)'
foreach ($n in 'recCmpRowFill', 'recCmpRowBar', 'recCmpRowLine') { Assert-True ($row[$n]['Properties']['TabIndex'] -eq '=-1') "cmpListCard row $n TabIndex -1" }

# (11) Chip text widths (worst case Inter/Arial at the chip font size, Measure-FontFit.ps1 with C:\Windows\Fonts) --
$chipSize = [int](([string]$row['btnCmpRowChip']['Properties']['Size']).TrimStart('='))
$fitText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Measure-FontFit.ps1'))
$fitHead = $fitText.Substring(0, $fitText.IndexOf('# Name, text, pt, weight'))
$InterDir = Join-Path $env:WINDIR 'Fonts'; $ArialDir = Join-Path $env:WINDIR 'Fonts'
$fitHead = $fitHead -replace '^param\([^\r\n]*\)', ''
Invoke-Expression $fitHead
$chipDesc = [string]$defs['cmpListCard']['CustomProperties']['Items']['Description']
foreach ($chipText in 'Inactive', 'On hold', 'Closed') {
    Assert-True ($chipDesc.Contains($chipText)) "cmpListCard Items description records the allowed chip text '$chipText'"
    $wIn = Measure-Text $fonts['IN.Normal'] $chipText $chipSize; $wAr = Measure-Text $fonts['AR.Normal'] $chipText $chipSize
    Assert-True ([Math]::Max($wIn, $wAr) -le 64) "chip '$chipText' at size ${chipSize}: Inter $wIn px / Arial $wAr px (worst case <= 64 px in the 80 px chip)"
}
Write-Output 'Not verified locally: Studio import, rendering, chip text in the real browser font.'
