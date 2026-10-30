# Structural checks for the canvas components in Src\Component (stap 2, 30-10-2026): cmpTitleBar, cmpMessageBar, cmpFooter.
# Proves source structure only: no Studio import, binding of component properties, rendering of HtmlViewer/ModernSpinner or event wiring.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
function Assert-True($cond, $label) { if (!$cond) { throw "FAIL $label" }; Write-Output "PASS $label" }
function Index-CmpControls($entries, $index) { foreach ($entry in $entries) { $name = @($entry.Keys)[0]; $index[$name] = $entry[$name]; Index-CmpControls $entry[$name]['Children'] $index } }
$dir = Join-Path $projectRoot 'Src\Component'
$files = @{}
foreach ($f in Get-ChildItem $dir -Filter *.pa.yaml) { $files[$f.Name -replace '\.pa\.yaml$', ''] = [IO.File]::ReadAllText($f.FullName) }
Assert-True (($files.Keys | Sort-Object) -join ',' -eq 'cmpFooter,cmpMessageBar,cmpTitleBar') 'exactly three component files, one component per file (cmpTitleBar, cmpMessageBar, cmpFooter)'
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
    foreach ($pat in '\bvar[A-Z]\w*', '\bcol[A-Z]\w*', '\bT\.\w+', '\bLangNl\b', '\bNavigate\(', '\bPatch\(', '\bNotify\(', '\bSet\(', '\bCollect\(', '\bRefresh\(', '\bUpdateContext\(', 'GEA_logo_white') {
        Assert-True ($body -cnotmatch $pat) "$c has no app-level reference ($pat)"
    }
    Assert-True ($body -notmatch 'Len\([^)]*\)\s*\*\s*\d') "$c has no estimated text widths (Len(...)*n)"
    Assert-True ($body -notmatch 'AutoWidth') "$c has no measured/auto widths"
}

# (3) cmpTitleBar -----------------------------------------------------------------------------------------
$t = $idx['cmpTitleBar']; $tp = $defs['cmpTitleBar']['Properties']
Assert-True ($tp['Fill'] -eq '=ColorValue("#0303B8")' -and $tp['Height'] -eq '=60') 'cmpTitleBar: Fill #0303B8, height 60'
$title = $t['lblCmpTitleText']['Properties']
Assert-True ($title['Text'] -eq '=cmpTitleBar.Title' -and $title['Color'] -eq '=Color.White' -and $title['Size'] -eq '=22' -and $title['FontWeight'] -eq '=FontWeight.Semibold' -and $title['PaddingLeft'] -eq '=129' -and $title['Width'] -eq '=Parent.Width' -and $title['Height'] -eq '=Parent.Height') 'cmpTitleBar title: white 22 Semibold Inter, PaddingLeft 129, full width'
$logo = $t['imgCmpTitleLogo']; $lp = $logo['Properties']
Assert-True ($logo['Control'] -eq 'Image@2.2.3' -and $lp['Width'] -eq '=99' -and $lp['Height'] -eq '=30' -and $lp['ImagePosition'] -eq '=ImagePosition.Fit' -and $lp['Image'] -eq '=cmpTitleBar.Logo' -and $lp['X'] -eq '=lblCmpTitleText.X+15' -and $lp['Y'] -eq '=lblCmpTitleText.Y+(lblCmpTitleText.Height-Self.Height)/2') 'cmpTitleBar logo: Image@2.2.3 99x30 Fit, X title+15, centred, Image = Logo input (media passed by host)'
Assert-True (!$lp.ContainsKey('Fill') -and !$lp.ContainsKey('OnSelect') -and $lp['AccessibleLabel'] -eq '="GEA"') 'cmpTitleBar logo: no Fill/OnSelect, AccessibleLabel GEA'
$order = @($defs['cmpTitleBar']['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True ($order.IndexOf('imgCmpTitleLogo') -eq $order.IndexOf('lblCmpTitleText') + 1) 'cmpTitleBar: logo directly after the title label'
$sp = $t['spnCmpTitleBusy']; $spp = $sp['Properties']
Assert-True ($sp['Control'] -eq 'ModernSpinner@1.1.0' -and $spp['SpinnerColor'] -eq '=Color.White' -and $spp['TrackColor'] -eq '=ColorValue("#0303B8")' -and $spp['Width'] -eq '=24' -and $spp['Height'] -eq '=24' -and $spp['Visible'] -eq '=cmpTitleBar.Busy' -and $spp['X'] -eq '=Parent.Width-24-Self.Width') 'cmpTitleBar spinner: ModernSpinner@1.1.0 white on #0303B8, 24x24, right margin 24, Visible = Busy'

# (4) cmpMessageBar ---------------------------------------------------------------------------------------
$m = $idx['cmpMessageBar']; $mp = $defs['cmpMessageBar']['Properties']
Assert-True ($mp['Height'] -eq '=40' -and $mp['BarHeight'] -eq '=If(IsBlank(cmpMessageBar.Kind),0,40)') 'cmpMessageBar: height 40, BarHeight output 0 when Kind empty'
$fill = $m['recCmpMsgFill']['Properties']['Fill']
Assert-True ($fill -eq '=Switch(cmpMessageBar.Kind,"Error",ColorValue("#DB1E28"),"Warning",ColorValue("#F29400"),"Success",ColorValue("#1AFF80"),Color.Transparent)') 'cmpMessageBar fill: Error #DB1E28, Warning #F29400, Success #1AFF80, otherwise transparent'
Assert-True ($m['recCmpMsgFill']['Properties']['Visible'] -eq '=!IsBlank(cmpMessageBar.Kind)') 'cmpMessageBar fill hidden when Kind empty'
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
foreach ($n in 'htmlCmpMsgText', 'icoCmpMsgClose') { Assert-True ($m[$n]['Properties']['Visible'] -eq '=!IsBlank(cmpMessageBar.Kind)') "cmpMessageBar $n hidden when Kind empty" }

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

# (6) Instance validation (Check-WeeklySource accepts valid CanvasComponent instances and rejects invalid ones)
$script:names = @{}; $script:controlCount = 0
Check-Control ([ordered]@{ cmpTestOk = [ordered]@{ Control = 'CanvasComponent'; ComponentName = 'cmpFooter'; Properties = [ordered]@{ X = '=0'; Y = '=0'; Width = '=Parent.Width'; HomeEnabled = '=true'; OnHome = '=Navigate(scrHome)' } } })
Assert-True ($script:controlCount -eq 1) 'Check-Control accepts a valid CanvasComponent instance (ComponentName, custom Input/Event properties)'
foreach ($case in @(
        @{ n = 'cmpTestUnknown'; v = [ordered]@{ Control = 'CanvasComponent'; ComponentName = 'cmpNope'; Properties = [ordered]@{} } },
        @{ n = 'cmpTestBadProp'; v = [ordered]@{ Control = 'CanvasComponent'; ComponentName = 'cmpFooter'; Properties = [ordered]@{ BarHeight = '=1' } } },
        @{ n = 'cmpTestNoName'; v = [ordered]@{ Control = 'CanvasComponent'; Variant = 'x'; ComponentName = 'cmpFooter'; Properties = [ordered]@{} } })) {
    $rejected = $false
    try { Check-Control ([ordered]@{ $case.n = $case.v }) } catch { $rejected = $true }
    Assert-True $rejected "Check-Control rejects invalid instance $($case.n)"
}
Write-Output 'Not verified locally: Studio import of ComponentDefinitions, rendering of HtmlViewer/ModernSpinner, property binding and event wiring.'
