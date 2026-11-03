# Structural checks for the canvas components in Src\Components (stap 2, 30-10-2026): cmpTitleBar, cmpMessageBar, cmpFooter, cmpField, cmpListCard.
# Proves source structure only: no Studio import, binding of component properties, rendering of HtmlViewer/ModernSpinner or event wiring.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
function Assert-True($cond, $label) { if (!$cond) { throw "FAIL $label" }; Write-Output "PASS $label" }
function Index-CmpControls($entries, $index) { foreach ($entry in $entries) { $name = @($entry.Keys)[0]; $index[$name] = $entry[$name]; Index-CmpControls $entry[$name]['Children'] $index } }
$dir = Join-Path $projectRoot 'Src\Components'
$files = @{}
foreach ($f in Get-ChildItem $dir -Filter *.pa.yaml) { $files[$f.Name -replace '\.pa\.yaml$', ''] = [IO.File]::ReadAllText($f.FullName) }
Assert-True (($files.Keys | Sort-Object) -join ',' -eq 'cmpField,cmpFooter,cmpListCard,cmpMessageBar,cmpTile,cmpTitleBar') 'exactly six component files, one component per file (cmpTitleBar, cmpMessageBar, cmpFooter, cmpField, cmpListCard, cmpTile)'
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
    cmpField      = @{ Label = 'Input:Text'; Required = 'Input:Boolean'; InputType = 'Input:Text'; DefaultValue = 'Input:Text'; Items = 'Input:Table'; Invalid = 'Input:Boolean'; Enabled = 'Input:Boolean'; HintText = 'Input:Text'; MaxLength = 'Input:Number'
                       Value = 'Output:Text'; OnChange = 'Event:Boolean' }
    cmpTile       = @{ Label = 'Input:Text'; Icon = 'Input:Image'; Arrow = 'Input:Image'; Active = 'Input:Boolean'; IconSize = 'Input:Number'; LabelSize = 'Input:Number'; Padding = 'Input:Number'; SoonText = 'Input:Text'; OnSelect = 'Event:Boolean' }
    cmpListCard   = @{ Items = 'Input:Table'; SelectedID = 'Input:Number'; SearchHint = 'Input:Text'; CountFormat = 'Input:Text'; ShowInactiveLabel = 'Input:Text'; OnText = 'Input:Text'; OffText = 'Input:Text'; ShowInactive = 'Input:Boolean'; Enabled = 'Input:Boolean'
                       SearchText = 'Output:Text'; ShowInactiveValue = 'Output:Boolean'; SelectedRowID = 'Output:Number'; OnSelectRow = 'Event:Boolean'; OnToggleShowInactive = 'Event:Boolean' }
}
foreach ($c in $contract.Keys) {
    $cps = $defs[$c]['CustomProperties']
    Assert-True ($cps.Count -eq $contract[$c].Count) "$c has exactly $($contract[$c].Count) custom properties"
    foreach ($p in $contract[$c].Keys) {
        $kind, $type = $contract[$c][$p] -split ':'
        $cp = $cps[$p]
        Assert-True ($null -ne $cp -and $cp['PropertyKind'] -eq $kind) "$c.$p is $kind"
        if ($kind -eq 'Event') { Assert-True ($cp['ReturnType'] -eq $type) "$c.$p ReturnType $type" } else { Assert-True ($cp['DataType'] -eq $type) "$c.$p DataType $type" }
        # Studio PA2231 (import 30-10-2026): every Input and Event custom property needs a non-empty Default formula.
        if ($kind -in @('Input', 'Event')) { Assert-True ($cp.ContainsKey('Default') -and ([string]$cp['Default']).StartsWith('=') -and ([string]$cp['Default']).Trim().Length -gt 1) "$c.$p has a non-empty Default formula (PA2231)" }
    }
    Assert-True (!$defs[$c].ContainsKey('AccessAppScope') -or $defs[$c]['AccessAppScope'] -eq $false) "$c does not use app scope (pure presentation, no app variables)"
    foreach ($bad in 'X', 'Y', 'Visible') { Assert-True (!$defs[$c]['Properties'].ContainsKey($bad)) "$c Properties has no reserved $bad" }
}
foreach ($p in 'HomeEnabled', 'NewEnabled', 'RefreshEnabled', 'DiscardEnabled', 'SaveEnabled') { Assert-True ($defs['cmpFooter']['CustomProperties'][$p]['Default'] -eq '=false') "cmpFooter.$p default is fail-closed (=false)" }
Assert-True ($defs['cmpTitleBar']['CustomProperties']['Busy']['Default'] -eq '=false') 'cmpTitleBar.Busy default =false'
# 02-11-2026: cmpField and cmpListCard follow the shape Eddy built and tested in Studio (Incoming 20261102Components): DisplayName = property name, events ReturnType Boolean with Default =true.
foreach ($c in 'cmpField', 'cmpListCard', 'cmpTile') { foreach ($p in $defs[$c]['CustomProperties'].Keys) { $cp = $defs[$c]['CustomProperties'][$p]; Assert-True ($cp['DisplayName'] -ceq $p) "$c.$p DisplayName = $p (Studio shape)"; if ($cp['PropertyKind'] -eq 'Event') { Assert-True ($cp['ReturnType'] -eq 'Boolean' -and $cp['Default'] -eq '=true') "$c.$p event ReturnType Boolean, Default =true (Studio shape)" } } }

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
Assert-True (!$fd['CustomProperties']['DefaultValue'].ContainsKey('RaiseOnReset') -and $fd['CustomProperties'].Values.Where({ $_.ContainsKey('RaiseOnReset') }).Count -eq 0 -and $fdp['OnReset'] -eq '=Reset(txtFieldValue); Reset(ddFieldValue)') 'cmpField reset contract (Studio shape 02-11-2026): no RaiseOnReset; a changed DefaultValue updates the inner Default, Reset(instance) runs OnReset (text input and dropdown)'
Assert-True ($fd['CustomProperties']['Enabled']['Default'] -eq '=false' -and $fd['CustomProperties']['InputType']['Default'] -eq '="text"' -and $fd['CustomProperties']['Invalid']['Default'] -eq '=false') 'cmpField: Enabled fail-closed =false, InputType default text, Invalid default false'
Assert-True ($fd['CustomProperties']['Items']['Default'] -eq '=Filter(Table({Value: ""}),false)' -and $fd['CustomProperties']['MaxLength']['Default'] -eq '=255') 'cmpField: Items default is an empty table with column Value, MaxLength 255'
Assert-True ($fdp['Value'] -eq '=Switch(cmpField.InputType,"dropdown",Coalesce(ddFieldValue.Selected.Value,""),"readonly",cmpField.DefaultValue,txtFieldValue.Text)') 'cmpField output Value (Studio shape: Value = txtFieldValue.Text): dropdown = selection or empty string, readonly = DefaultValue, otherwise the typed text'
# TP-STEP3-02 (01-11-2026): CurrentValue was blank in Studio. The output must read the live inner control properties, never an inner Default or Blank().
Assert-True ($fdp['Value'] -cmatch 'txtFieldValue\.Text' -and $fdp['Value'] -cmatch 'ddFieldValue\.Selected\.Value' -and $fdp['Value'] -notmatch '\.Default\b' -and $fdp['Value'] -notmatch 'Blank\(') 'cmpField output Value references the inner controls (txtFieldValue.Text, ddFieldValue.Selected.Value), not a Default or Blank()'
Assert-True ($fi['txtFieldValue']['Properties']['Default'] -eq '=cmpField.DefaultValue' -and $fi['ddFieldValue']['Properties']['Default'] -eq '=cmpField.DefaultValue' -and $fd['CustomProperties']['DefaultValue']['PropertyKind'] -eq 'Input' -and $fd['CustomProperties']['Value']['PropertyKind'] -eq 'Output') 'cmpField (Studio shape): Input DefaultValue -> inner Default; Output Value is the separate live value'
$itemsF = [string]$fi['ddFieldValue']['Properties']['Items']
# Column names as identifiers (app flag supportcolumnnamesasidentifiers): "Value"/"t" as text made Items an error, which made CurrentValue blank for every instance.
Assert-True ($itemsF -eq '=If(IsBlank(cmpField.DefaultValue) || !IsBlank(LookUp(cmpField.Items,Value=cmpField.DefaultValue)),cmpField.Items,Ungroup(Table({t: ShowColumns(cmpField.Items,Value)},{t: Table({Value: cmpField.DefaultValue})}),t))') 'cmpField dropdown Items: host Items plus one extra row {Value: DefaultValue} when DefaultValue is filled and not in Items (shown as-is); column names as identifiers'
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
$lp2 = $fi['htmlFieldLabel']['Properties']; $lh = [string]$lp2['HtmlText']
foreach ($css in 'font-family:Inter,Arial,sans-serif', 'font-size:13px', 'font-weight:600', 'color:#000000', 'white-space:nowrap', 'overflow:hidden', 'text-overflow:ellipsis', 'width:100%') { Assert-True ($lh.Contains($css)) "cmpField label HtmlText contains $css" }
$starLit = "If(cmpField.Required,""<span style='color:#DB1E28'>&nbsp;*</span>"","""")"
Assert-True ($lh.Contains($starLit)) 'cmpField label: red star <span style=color:#DB1E28>&nbsp;*</span> only when Required'
Assert-True ($lh.IndexOf("</span>"" & " + $starLit) -gt 0) 'cmpField label: the star follows directly after the (ellipsis) label text span'
$esc = 'Substitute(Substitute(Substitute(Substitute(Substitute(cmpField.Label,"&","&amp;"),"<","&lt;"),">","&gt;"),"""","&quot;"),"' + "'" + '","&#39;")'
Assert-True ($lh.Contains($esc) -and ([regex]::Matches($lh, [regex]::Escape('cmpField.Label'))).Count -eq 1) 'cmpField label: Label only through the escape (& first, then < > double quote single quote)'
Assert-True ($lp2['Height'] -eq '=20' -and $lp2['Y'] -eq '=0' -and $lp2['Width'] -eq '=Parent.Width-2' -and $lp2['Size'] -eq '=13' -and $lp2['Font'] -eq '="Inter, Arial, sans-serif"') 'cmpField label: height 20 (line 18, no scrollbar) at Y 0, width Parent-2, Inter 13'
$tx = $fi['txtFieldValue']; $dd = $fi['ddFieldValue']; $tp2 = $tx['Properties']; $dp2 = $dd['Properties']
Assert-True ($tx['Control'] -eq 'Classic/TextInput@2.3.2' -and $dd['Control'] -eq 'Classic/DropDown@2.3.1') 'cmpField inputs: Classic/TextInput@2.3.2 and Classic/DropDown@2.3.1'
Assert-True ($tp2['Visible'] -eq '=cmpField.InputType<>"dropdown"' -and $dp2['Visible'] -eq '=cmpField.InputType="dropdown"') 'cmpField: text input visible unless dropdown, dropdown visible only for dropdown'
foreach ($k in 'txtFieldValue', 'ddFieldValue') {
    $p = $fi[$k]['Properties']
    Assert-True ($p['Height'] -eq '=36' -and $p['Y'] -eq '=htmlFieldLabel.Y+htmlFieldLabel.Height+1' -and $p['X'] -eq '=1' -and $p['Width'] -eq '=Parent.Width-2' -and $p['Fill'] -eq '=Color.White' -and $p['Font'] -eq '="Inter, Arial, sans-serif"' -and $p['FontWeight'] -eq '=FontWeight.Normal' -and $p['Size'] -eq '=14' -and $p['Color'] -eq '=ColorValue("#000000")') "$k : 36 high, 1 px under the label, 1 px inside the component (2 px border never clipped), white, Inter 14 Normal black"
    Assert-True ($p['FocusedBorderThickness'] -eq '=2' -and $p['DisabledColor'] -eq '=ColorValue("#000000")') "$k : focus 2 px, disabled text black"
    foreach ($bp in 'BorderColor', 'HoverBorderColor', 'FocusedBorderColor', 'PressedBorderColor', 'DisabledBorderColor') { Assert-True (([string]$p[$bp]).Contains('If(cmpField.Invalid,ColorValue("#DB1E28")')) "$k.$bp is red #DB1E28 when Invalid" }
    Assert-True (([string]$p['BorderThickness']).StartsWith('=If(cmpField.Invalid,2,')) "$k.BorderThickness is 2 when Invalid"
    Assert-True ($p['OnChange'] -eq '=If(cmpField.Enabled,cmpField.OnChange())') "$k.OnChange raises the event only while Enabled"
    Assert-True ($p['AccessibleLabel'] -eq '=cmpField.Label') "$k has AccessibleLabel = Label"
}
Assert-True ($tp2['BorderColor'] -match '"#9B9B9B"' -and $tp2['HoverBorderColor'] -match '"#5A5A5A"' -and $tp2['FocusedBorderColor'] -match '"#0303B8"' -and $tp2['PressedBorderColor'] -match '"#0303B8"' -and $tp2['RadiusTopLeft'] -eq '=4' -and $tp2['RadiusBottomRight'] -eq '=4') 'cmpField text: white, border #9B9B9B, hover #5A5A5A, focus/pressed #0303B8, radius 4'
Assert-True ($tp2['BorderThickness'] -eq '=If(cmpField.Invalid,2,If(cmpField.InputType="readonly",0,1))' -and $tp2['BorderColor'] -match 'If\(cmpField.InputType="readonly",Color.Transparent' -and $tp2['DisabledFill'] -eq '=If(cmpField.InputType="readonly",ColorValue("#F0F0F0"),Color.White)') 'cmpField readonly: #F0F0F0 without border; other disabled states white with border #9B9B9B'
Assert-True ($tp2['DisabledBorderColor'] -match '"#9B9B9B"' -and $tp2['DisplayMode'] -eq '=If(cmpField.Enabled && cmpField.InputType="text",DisplayMode.Edit,DisplayMode.Disabled)') 'cmpField text: disabled border #9B9B9B; readonly (and unknown InputType) is always Disabled, text only Edit while Enabled'
Assert-True ($tp2['Default'] -eq '=cmpField.DefaultValue' -and $tp2['HintText'] -eq '=cmpField.HintText' -and $tp2['MaxLength'] -eq '=cmpField.MaxLength') 'cmpField text: Default = DefaultValue, HintText, MaxLength from the inputs'
Assert-True ($dp2['Fill'] -eq '=Color.White' -and $dp2['DisabledFill'] -eq '=Color.White' -and $dp2['BorderColor'] -match '"#9B9B9B"' -and $dp2['DisabledBorderColor'] -match '"#9B9B9B"' -and $dp2['DisplayMode'] -eq '=If(cmpField.Enabled && cmpField.InputType="dropdown",DisplayMode.Edit,DisplayMode.Disabled)') 'cmpField dropdown: white, border #9B9B9B (decision c), Edit only while Enabled'
$ddStyle = @{ HoverFill = '=ColorValue("#D5EDFF")'; HoverColor = '=ColorValue("#000F41")'; PressedFill = '=ColorValue("#D5EDFF")'; PressedColor = '=ColorValue("#000F41")'; SelectionFill = '=ColorValue("#0303B8")'; SelectionColor = '=Color.White'; ChevronBackground = '=Color.White'; ChevronFill = '=ColorValue("#0303B8")'; ChevronHoverBackground = '=ColorValue("#D5EDFF")' }
foreach ($k in $ddStyle.Keys) { Assert-True ($dp2[$k] -eq $ddStyle[$k]) "cmpField dropdown $k per the GEA dropdown style" }
Assert-True ($dp2['HoverFill'] -ne $dp2['Fill'] -and $dp2['Items.Value'] -eq '=Value' -and $dp2['Default'] -eq '=cmpField.DefaultValue' -and $dp2['HoverBorderColor'] -match '"#5A5A5A"' -and $dp2['ChevronBackground'] -eq '=Color.White' -and $dp2['Items.Value'] -eq '=Value') 'cmpField dropdown: HoverFill differs from Fill, Default = Value, hover border #5A5A5A like the text field, chevron background white (hover #D5EDFF)'
Assert-True ($fd['Children'].Count -eq 3) 'cmpField: three children (label, text input, dropdown), no stacked or hidden extra controls'

# (8) cmpListCard ------------------------------------------------------------------------------------------
$ld = $defs['cmpListCard']; $li = $idx['cmpListCard']; $ldp = $ld['Properties']
Assert-True ($ld['CustomProperties']['Enabled']['Default'] -eq '=false' -and $ld['CustomProperties']['ShowInactive']['Default'] -eq '=false') 'cmpListCard: Enabled fail-closed =false, ShowInactive default false'
Assert-True ($ld['CustomProperties']['Items']['Default'] -eq '=Table({ID: 0, Title: "", Subtitle: "", Inactive: false, ChipText: ""})' -and $ld['CustomProperties']['CountFormat']['Default'] -eq '="{0}"' -and $ld['CustomProperties']['SelectedID']['Default'] -eq '=0') 'cmpListCard: Items default is a plain typed table (ID, Title, Subtitle, Inactive, ChipText; no Filter trick, D7 import failure 30-10-2026), SelectedID default 0, CountFormat default {0}'
$sr = $ld['CustomProperties']['OnSelectRow']
Assert-True (!$sr.ContainsKey('Parameters') -and $ldp['SelectedRowID'] -eq '=galRows.Selected.ID') 'cmpListCard selection contract (Studio shape: SelectedRowID = galRows.Selected.ID): OnSelectRow has no parameters (AGENTS: no event parameters); the row ID is Output SelectedRowID'
Assert-True ($ldp['SearchText'] -eq '=txtSearch.Text' -and $ldp['ShowInactiveValue'] -eq '=cmpListCard.ShowInactive' -and !$ldp.ContainsKey('OnReset') -and $ld['CustomProperties'].Values.Where({ $_.ContainsKey('RaiseOnReset') }).Count -eq 0) 'cmpListCard outputs: SearchText from the search field, ShowInactiveValue echoes the input, no OnReset or RaiseOnReset'
$card = $li['conCmpListCard']; $cp3 = $card['Properties']
Assert-True ($card['Control'] -eq 'GroupContainer@1.5.0' -and $card['Variant'] -eq 'ManualLayout' -and $cp3['DropShadow'] -eq '=DropShadow.Light' -and $cp3['Fill'] -eq '=Color.White' -and $cp3['RadiusTopLeft'] -eq '=8' -and $cp3['RadiusBottomRight'] -eq '=8' -and $cp3['Width'] -eq '=Parent.Width' -and $cp3['Height'] -eq '=Parent.Height' -and $ldp['Fill'] -eq '=Color.Transparent') 'cmpListCard card: white GroupContainer radius 8, DropShadow.Light (component fill transparent so the corners show)'
$se = $li['txtSearch']['Properties']
Assert-True ($li['txtSearch']['Control'] -eq 'Classic/TextInput@2.3.2' -and $se['X'] -eq '=24' -and $se['Y'] -eq '=24' -and $se['Width'] -eq '=Parent.Width-48' -and $se['Height'] -eq '=36' -and $se['Fill'] -eq '=Color.White' -and $se['BorderColor'] -eq '=ColorValue("#9B9B9B")' -and $se['HintText'] -eq '=cmpListCard.SearchHint' -and $se['PaddingLeft'] -eq '=40' -and $se['DisplayMode'] -eq '=If(cmpListCard.Enabled,DisplayMode.Edit,DisplayMode.Disabled)') 'cmpListCard search: padding 24, 36 high, white, border #9B9B9B, hint from SearchHint, Edit only while Enabled'
$ic = $li['icoCmpListSearch']['Properties']
Assert-True ($li['icoCmpListSearch']['Control'] -eq 'Classic/Icon@2.5.0' -and $ic['Icon'] -eq '=Icon.Search' -and $ic['AccessibleLabel'] -eq '=""') 'cmpListCard search icon: Classic/Icon Icon.Search, decorative (AccessibleLabel empty)'
$inf = $li['htmlCmpListInfo']; $ih = [string]$inf['Properties']['HtmlText']
Assert-True ($inf['Control'] -eq 'HtmlViewer@2.1.0') 'cmpListCard info row: one HtmlViewer@2.1.0 (count left, Show inactive label right, one line)'
foreach ($css in 'display:flex', 'white-space:nowrap', 'overflow:hidden', 'text-overflow:ellipsis', 'flex:1 1 0', 'flex:none', 'text-align:right') { Assert-True ($ih.Contains($css)) "cmpListCard info HtmlText contains $css" }
$lcPred = '(cmpListCard.ShowInactive || !Inactive) && (IsBlank(Trim(txtSearch.Text)) || Trim(txtSearch.Text) in Title || Trim(txtSearch.Text) in Subtitle)'
$cntInner = 'Substitute(cmpListCard.CountFormat,"{0}",Text(CountRows(galRows.AllItems)))'
$eCnt = 'Substitute(Substitute(Substitute(Substitute(Substitute(' + $cntInner + ',"&","&amp;"),"<","&lt;"),">","&gt;"),"""","&quot;"),"' + "'" + '","&#39;")'
Assert-True ($ih.Contains($eCnt) -and ([regex]::Matches($ih, [regex]::Escape('cmpListCard.CountFormat'))).Count -eq 1 -and $ih -notmatch 'CountText') 'cmpListCard info: count = CountFormat with {0} = rows shown by the gallery (CountRows(galRows.AllItems): after Show inactive and search), escaped; no host CountText'
foreach ($field in 'cmpListCard.ShowInactiveLabel') {
    $e2 = 'Substitute(Substitute(Substitute(Substitute(Substitute(' + $field + ',"&","&amp;"),"<","&lt;"),">","&gt;"),"""","&quot;"),"' + "'" + '","&#39;")'
    Assert-True ($ih.Contains($e2) -and ([regex]::Matches($ih, [regex]::Escape($field))).Count -eq 1) "cmpListCard info escapes $field"
}
$sw = $li['btnCmpListSwitch']; $swp = $sw['Properties']; $kn = $li['btnCmpListKnob']['Properties']
Assert-True ($sw['Control'] -eq 'Classic/Button@2.2.0' -and !$swp.ContainsKey('AccessibleLabel') -and $swp['Width'] -eq '=44' -and $swp['Height'] -eq '=24' -and $swp['RadiusTopLeft'] -eq '=12' -and $swp['Fill'] -eq '=If(cmpListCard.ShowInactive,ColorValue("#0303B8"),ColorValue("#B4B4B4"))' -and $swp['Tooltip'] -eq '=cmpListCard.ShowInactiveLabel & ": " & If(cmpListCard.ShowInactive,cmpListCard.OnText,cmpListCard.OffText)') 'cmpListCard switch: track 44x24 radius 12, #0303B8 on / #B4B4B4 off, tooltip with label and state'
Assert-True ($swp['OnSelect'] -eq '=If(cmpListCard.Enabled,cmpListCard.OnToggleShowInactive())' -and $swp['DisplayMode'] -eq '=If(cmpListCard.Enabled,DisplayMode.Edit,DisplayMode.Disabled)' -and $kn['OnSelect'] -eq '=Select(btnCmpListSwitch)' -and $kn['DisplayMode'] -eq '=btnCmpListSwitch.DisplayMode' -and $kn['Fill'] -eq '=Color.White' -and $kn['Width'] -eq '=18') 'cmpListCard switch contract: only raises OnToggleShowInactive while Enabled, never flips state; white 18 px knob selects the track'
$ga = $li['galRows']; $gp = $ga['Properties']
Assert-True ($ga['Control'] -eq 'Gallery@2.15.0' -and $gp['TemplateSize'] -eq '=64' -and $gp['TemplatePadding'] -eq '=0' -and $gp['Items'] -eq ('=Filter(cmpListCard.Items,' + $lcPred + ')') -and $gp['OnSelect'] -eq '=cmpListCard.OnSelectRow()' -and !$gp.ContainsKey('Default')) 'cmpListCard gallery (Studio shape): Gallery@2.15.0 fixed row height 64, Items filtered INSIDE the component (Show inactive, search in Title or Subtitle), OnSelect = cmpListCard.OnSelectRow() (guard in the host handler), no Default (as tested in Studio)'
$rowN = @($ga['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($rowN -join ',') -eq 'recCmpRowFill,recCmpRowBar,recCmpRowLine,htmlCmpRowTitle,htmlCmpRowSub,btnCmpRowChip,btnCmpRowHit') 'cmpListCard row: fill, selection bar, divider, title, subtitle, chip, transparent click target on top'
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
foreach ($n in 'btnCmpRowHit') { Assert-True ($row[$n]['Properties']['OnSelect'] -eq '=Select(Parent)') "cmpListCard row $n selects the row" }

# (9) Geometry: no overlaps inside the components at widths 200/280/360/512 -------------------------------------
foreach ($w in 200, 280, 360, 512) {
    $env = @{ pw = $w; ph = 58; tw = 0; th = 0; chip = $false; show = $false }
    $a = Rect $fi 'htmlFieldLabel' $env; $b = Rect $fi 'txtFieldValue' $env; $c = Rect $fi 'ddFieldValue' $env
    Assert-True (!(Overlap $a $b) -and !(Overlap $a $c) -and ($b.y + $b.h) -le 58 -and ($a.y + $a.h + 1) -eq $b.y -and $b.x -eq 1 -and ($b.x + $b.w) -eq ($w - 1) -and $a.w -eq ($w - 2)) "cmpField width ${w}: label (0..20), 1 px gap, input (21..57), 1 px inside both sides, no overlap"
    foreach ($show in $false, $true) {
        $env = @{ pw = $w; ph = 600; tw = 0; th = 0; chip = $false; show = $show }
        $s = Rect $li 'txtSearch' $env; $i = Rect $li 'htmlCmpListInfo' $env; $t = Rect $li 'btnCmpListSwitch' $env; $k = Rect $li 'btnCmpListKnob' $env; $g = Rect $li 'galRows' $env
        $ok = !(Overlap $s $i) -and !(Overlap $s $t) -and !(Overlap $i $t) -and !(Overlap $i $g) -and !(Overlap $t $g) -and !(Overlap $s $g) -and $i.w -ge 0 -and $g.h -gt 0 -and ($t.x + $t.w) -eq ($w - 24) -and $k.x -ge $t.x -and ($k.x + $k.w) -le ($t.x + $t.w) -and $k.y -ge $t.y -and ($k.y + $k.h) -le ($t.y + $t.h) -and ($i.y + $i.h) -le $g.y -and ($g.y + $g.h) -le 600 -and $t.y -ge $i.y -and ($t.y + $t.h) -le ($i.y + $i.h)
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
# Every custom property of kind Input/Event (all components, not only the contract list) has a non-empty Default (PA2231).
foreach ($c in $defs.Keys) { foreach ($p in $defs[$c]['CustomProperties'].Keys) { $cp = $defs[$c]['CustomProperties'][$p]; if ($cp['PropertyKind'] -in @('Input', 'Event', 'InputFunction')) { Assert-True (([string]$cp['Default']).Trim() -match '^=.+') "$c.$p ($($cp['PropertyKind'])) has a non-empty Default" } } }
# No control version older than its template in the .msapr (Studio PA2105 on ModernDatePicker@1.0.0, 30-10-2026).
$tplVer = @{}; foreach ($tp in $templates) { $tplVer[$tp.Name.ToLowerInvariant()] = [version]$tp.Version }
$older = @()
foreach ($f in Get-ChildItem (Join-Path $projectRoot 'Src') -Recurse -Filter *.pa.yaml) {
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), '(?m)^\s*Control:\s*([\w/]+)@([\d.]+)\s*$')) {
        $t = ($m.Groups[1].Value -split '/')[-1].ToLowerInvariant(); if ($t -eq 'textinput') { $t = 'text' }
        if ($tplVer.ContainsKey($t) -and [version]$m.Groups[2].Value -lt $tplVer[$t]) { $older += "$($f.Name): $($m.Groups[1].Value)@$($m.Groups[2].Value) < template $($tplVer[$t])" }
    }
}
Assert-True ($older.Count -eq 0) "No control version older than its template in the .msapr ($($older -join '; '))"
# AGENTS (D7 import failure 30-10-2026): no event parameters in any component.
foreach ($c in $defs.Keys) { foreach ($p in $defs[$c]['CustomProperties'].Keys) { $cp = $defs[$c]['CustomProperties'][$p]; Assert-True (!$cp.ContainsKey('Parameters')) "$c.$p has no Parameters (no event parameters)" } }
# (12) Instance wiring on the screens (Studio FAIL 01-11-2026, build components-20261031_074310: dirty right after load, Discard/Save without effect) ------
# Microsoft Learn (create-component, Known limitations): a custom input property of an instance must not reference a custom output property of the
# same or another instance of the same component (circular reference). Rule here, stricter: no non-event property of an instance references ANY
# output of ANY component instance, and no instance property references its own instance (except in event handlers, which may read outputs such as
# SelectedRowID). Screen formulas outside instances (labels, buttons) may read outputs.
$cmpOutputs = @{}; $cmpEvents = @{}
foreach ($c in $defs.Keys) { $cps = $defs[$c]['CustomProperties']; $cmpOutputs[$c] = @($cps.Keys | Where-Object { $cps[$_]['PropertyKind'] -eq 'Output' }); $cmpEvents[$c] = @($cps.Keys | Where-Object { $cps[$_]['PropertyKind'] -eq 'Event' }) }
function Get-Instances($entries, $list) { foreach ($e in $entries) { $n = @($e.Keys)[0]; $v = $e[$n]; if ($v['Control'] -eq 'CanvasComponent') { $list.Add([pscustomobject]@{ Name = $n; Comp = [string]$v['ComponentName']; Props = $v['Properties'] }) | Out-Null }; if ($v['Children']) { Get-Instances $v['Children'] $list } } }
function Find-InstanceCycles($instances) {
    $bad = @()
    foreach ($i in $instances) {
        foreach ($k in @($i.Props.Keys)) {
            if ($cmpEvents[$i.Comp] -contains $k) { continue }
            $fx = [string]$i.Props[$k]
            if ($fx -match ('\b' + [regex]::Escape($i.Name) + '\.\w')) { $bad += "$($i.Name).$k references its own instance" }
            foreach ($j in $instances) { foreach ($o in $cmpOutputs[$j.Comp]) { if ($fx -match ('\b' + [regex]::Escape($j.Name) + '\.' + $o + '\b')) { $bad += "$($i.Name).$k references output $($j.Name).$o" } } }
        }
    }
    return , $bad
}
$dbgRx = '^=Set\(varDbgEvent,"(On\w+) " & Text\(Now\(\),"hh:mm:ss"\)\); '
function Strip-Debug([string]$fx, [string]$ev) { if ([regex]::IsMatch($fx, $dbgRx) -or $fx -match '\bvarDbg\w*|\bvarDebug\b') { throw "FAIL $ev still has a debug prefix (debug line removed for the approval build)" }; return $fx }
# self-test of the cycle finder on the two patterns of build 074310 and on a clean instance
$fake = [System.Collections.ArrayList]@()
$fake.Add([pscustomobject]@{ Name = 'cmpXList'; Comp = 'cmpListCard'; Props = [ordered]@{ Items = '=Filter(colX,Lower(cmpXList.SearchText) in Name)'; CountText = '=Text(CountRows(cmpXList.Items))'; OnSelectRow = '=Set(v,cmpXList.SelectedRowID)' } }) | Out-Null
$fake.Add([pscustomobject]@{ Name = 'cmpXBar'; Comp = 'cmpMessageBar'; Props = [ordered]@{ Height = '=cmpXBar.BarHeight' } }) | Out-Null
$fake.Add([pscustomobject]@{ Name = 'cmpXFoot'; Comp = 'cmpFooter'; Props = [ordered]@{ SaveEnabled = '=Trim(cmpXName.Value)<>""'; OnSave = '=Patch(L,{a:cmpXName.Value})' } }) | Out-Null
$fake.Add([pscustomobject]@{ Name = 'cmpXName'; Comp = 'cmpField'; Props = [ordered]@{ DefaultValue = '=varX.Name' } }) | Out-Null
$fb = Find-InstanceCycles $fake
Assert-True (($fb -join ';').Contains('cmpXList.Items references output cmpXList.SearchText') -and ($fb -join ';').Contains('cmpXList.CountText references its own instance') -and ($fb -join ';').Contains('cmpXBar.Height references output cmpXBar.BarHeight') -and ($fb -join ';').Contains('cmpXFoot.SaveEnabled references output cmpXName.Value') -and !($fb -join ';').Contains('OnSelectRow') -and !($fb -join ';').Contains('OnSave') -and !($fb -join ';').Contains('cmpXName.DefaultValue')) "cycle finder self-test: flags Items->own SearchText, CountText->own Items, Height->own BarHeight, an Enabled input->another instance's Value; event handlers and clean inputs pass ($($fb.Count) findings)"
$scrFiles = @(Get-ChildItem (Join-Path $projectRoot 'Src') -Filter *.pa.yaml | Where-Object { $_.Name -notin @('App.pa.yaml', '_EditorState.pa.yaml') })
$instTotal = 0
foreach ($sf in $scrFiles) {
    $sd = $builder.Build().Deserialize([IO.File]::ReadAllText($sf.FullName))
    if (-not $sd['Screens']) { continue }
    foreach ($sn in $sd['Screens'].Keys) {
        $inst = [System.Collections.ArrayList]@(); Get-Instances $sd['Screens'][$sn]['Children'] $inst
        if ($inst.Count -eq 0) { continue }
        $instTotal += $inst.Count
        $cyc = Find-InstanceCycles $inst
        Assert-True ($cyc.Count -eq 0) "${sn}: no instance input/size property references a component output or its own instance ($($inst.Count) instances; $($cyc -join '; '))"
        foreach ($i in $inst) {
            foreach ($k in @($i.Props.Keys)) { if ($k -clike 'On*' -and @($defs[$i.Comp]['CustomProperties'].Keys) -notcontains $k) { throw "FAIL ${sn}: $($i.Name).$k is not an Event of $($i.Comp) (event names must equal the definition)" } }
            if ($i.Comp -eq 'cmpTile') {
                $act = ([string]$i.Props['Active']).Trim(); $hasOn = @($i.Props.Keys) -contains 'OnSelect'
                Assert-True (($act -eq '=true' -and $hasOn -and ([string]$i.Props['OnSelect']).Trim().EndsWith('; true')) -or ($act -eq '=false' -and -not $hasOn)) "${sn}: $($i.Name) cmpTile: Active true has an OnSelect handler ending in ; true (Studio component shape), Active false (Soon) has none"
                Assert-True (($i.Props['Width'] -eq $i.Props['Height']) -and $i.Props.ContainsKey('Icon') -and $i.Props.ContainsKey('Label')) "${sn}: $($i.Name) cmpTile: square (Width = Height), Icon and Label passed by the host"
            }
            $req = switch ($i.Comp) { 'cmpFooter' { @('OnHome', 'OnNew', 'OnRefresh', 'OnDiscard', 'OnSave') } 'cmpListCard' { @('OnSelectRow', 'OnToggleShowInactive') } 'cmpMessageBar' { @('OnClose') } default { @() } }
            foreach ($ev in $req) {
                Assert-True ((@($i.Props.Keys) -contains $ev) -and ([string]$i.Props[$ev]).Trim().Length -gt 1) "${sn}: $($i.Name).$ev is set on the instance (name equal to the $($i.Comp) definition; the definition Default =false is only a fallback)"
                $h = Strip-Debug (([string]$i.Props[$ev]).Trim()) $ev
                if ($i.Comp -eq 'cmpFooter') {
                    $en = ([string]$i.Props[$ev.Substring(2) + 'Enabled']).Trim()
                    Assert-True ($en.StartsWith('=') -and $h.StartsWith('=If(' + $en.Substring(1) + ',')) "${sn}: $($i.Name).$ev starts with If(<$($ev.Substring(2))Enabled>, : same guard text as the input"
                } elseif ($i.Comp -eq 'cmpListCard') {
                    $en = ([string]$i.Props['Enabled']).Trim()
                    Assert-True ($en.StartsWith('=') -and $h.StartsWith('=If(' + $en.Substring(1) + ',')) "${sn}: $($i.Name).$ev starts with If(<Enabled>, : same guard text as the input"
                } else {
                    Assert-True ($h.Contains('Set(varAdmMsgKind,"")')) "${sn}: $($i.Name).OnClose clears the message (no guard needed: local only)"
                }
            }
        }
    }
}
Assert-True ($instTotal -gt 0) "instance wiring checked on $instTotal component instances"
# the component side of the event contract: each footer button raises exactly its own event, gated by its own Enabled input
foreach ($b in @(@('btnCmpHome', 'Home'), @('btnCmpNew', 'New'), @('btnCmpRefresh', 'Refresh'), @('btnCmpDiscard', 'Discard'), @('btnCmpSave', 'Save'))) {
    Assert-True ($idx['cmpFooter'][$b[0]]['Properties']['OnSelect'] -ceq "=If(cmpFooter.$($b[1])Enabled,cmpFooter.On$($b[1])())" -and $defs['cmpFooter']['CustomProperties']["On$($b[1])"]['PropertyKind'] -eq 'Event') "cmpFooter.$($b[0]).OnSelect = If(cmpFooter.$($b[1])Enabled,cmpFooter.On$($b[1])()) and On$($b[1]) is an Event of the definition"
}
# cmpListCard filter and count (interpreter): the component filters the host rows on Show inactive and on its own search text (in Title or Subtitle)
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$cEng = New-Object Microsoft.PowerFx.RecalcEngine; $cOpt = New-Object Microsoft.PowerFx.ParserOptions; $cOpt.Culture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
function Eval-C([string]$fx) { $v = $cEng.Eval($fx, $null, $cOpt); if ($v -is [Microsoft.PowerFx.Types.ErrorValue]) { throw "FAIL eval: $($v.ToExpression())" }; return $v.Value }
$rowsFx = 'Table({ID:1,Title:"Alpha BV",Subtitle:"EMP-001 - Delft",Inactive:false,ChipText:""},{ID:2,Title:"Beta",Subtitle:"EMP-002 - Ede",Inactive:false,ChipText:""},{ID:3,Title:"Gamma",Subtitle:"",Inactive:true,ChipText:"Inactive"})'
$galFx = ([string]$idx['cmpListCard']['galRows']['Properties']['Items']).TrimStart('='); $htmlFx = ([string]$idx['cmpListCard']['htmlCmpListInfo']['Properties']['HtmlText']).TrimStart('=')
foreach ($c in @(@('""', 'false', '1,2', 2), @('"   "', 'false', '1,2', 2), @('" EDE "', 'false', '2', 1), @('"emp-00"', 'false', '1,2', 2), @('"alpha bv"', 'false', '1', 1), @('"nomatch"', 'false', '', 0), @('If(false,"x")', 'false', '1,2', 2), @('"gamma"', 'false', '', 0), @('""', 'true', '1,2,3', 3), @('"gamma"', 'true', '3', 1))) {
    $env = "With({cmpListCard:{Items:$rowsFx,ShowInactive:$($c[1]),CountFormat:`"{0} contractors`",ShowInactiveLabel:`"Show inactive`"},txtSearch:{Text:$($c[0])}},"
    Assert-True ((Eval-C ($env + "Concat($galFx,Text(ID),`",`"))")) -eq $c[2]) "cmpListCard filter search $($c[0]) ShowInactive $($c[1]): gallery shows IDs '$($c[2])' (trim, case-insensitive, Title or Subtitle; inactive rows only with ShowInactive)"
    Assert-True ((Eval-C ($env + "With({galRows:{AllItems:$galFx}},$htmlFx))")).Contains(">$($c[3]) contractors</span>")) "cmpListCard filter search $($c[0]) ShowInactive $($c[1]): info row shows '$($c[3]) contractors' (count of the shown rows)"
}
Write-Output 'Not verified locally: Studio import, rendering, chip text in the real browser font.'

# (11) Presentation fixes 1-11-2026 (Studio test): scrollbars, overlays, clipping, focus border ------------------
foreach ($c in $idx.Keys) {
    foreach ($n in $idx[$c].Keys) {
        $ctl = $idx[$c][$n]
        if ($ctl['Control'] -ne 'HtmlViewer@2.1.0') { continue }
        $pp = $ctl['Properties']; $ht = [string]$pp['HtmlText']
        Assert-True ($ht.Contains('<style>html,body{margin:0;padding:0;overflow:hidden}</style>') -and $ht.Contains("style='margin:0;padding:0;overflow:hidden;")) "$c.$n : HtmlViewer resets body margin/padding and hides overflow (no scrollbar)"
        Assert-True ($pp['PaddingTop'] -eq '=0' -and $pp['PaddingBottom'] -eq '=0' -and $pp['PaddingLeft'] -eq '=0' -and $pp['PaddingRight'] -eq '=0') "$c.$n : HtmlViewer padding 0"
        $lh = [regex]::Match($ht, 'line-height:(\d+)px'); $hh = [string]$pp['Height']
        if ($lh.Success) { Assert-True ($hh -match '^=\d+$' -and [int]$hh.TrimStart('=') -gt [int]$lh.Groups[1].Value) "$c.$n : control height $hh is greater than the content line height $($lh.Groups[1].Value)px (no scrollbar)" }
        else { Assert-True ($ht -match 'line-height:" & Parent.Height' -and $hh -eq '=Parent.Height') "$c.$n : line height follows the control height exactly" }
    }
    # TP-STEP3-02 (Eddy 01-11-2026): the only semi-transparent colour is the row hover on the cmpListCard click target (#F0F0F099).
    $src = $files[$c]; if ($c -eq 'cmpListCard') { $src = $src.Replace('HoverFill: =If(cmpListCard.Enabled && ThisItem.ID<>cmpListCard.SelectedID,ColorValue("#F0F0F099"),Color.Transparent)', '') }
    Assert-True ($src -notmatch 'RGBA\(' -and $src -notmatch '#[0-9A-Fa-f]{8}\b' -and $src -notmatch 'ColorFade\(') "$c : no semi-transparent colour (RGBA, #RRGGBBAA, ColorFade) except the cmpListCard row hover"
}
Assert-True ($rowN[0] -eq 'recCmpRowFill' -and $rowN[-1] -eq 'btnCmpRowHit') 'cmpListCard row: background first (behind the text), click target last (top layer)'
$hit = $row['btnCmpRowHit']['Properties']
$allT = $true; foreach ($k in 'Fill', 'PressedFill', 'DisabledFill', 'BorderColor', 'HoverBorderColor', 'PressedBorderColor', 'DisabledBorderColor') { if ($hit[$k] -ne '=Color.Transparent') { $allT = $false } }
Assert-True ($allT -and $hit['Text'] -eq '=""' -and $hit['TabIndex'] -eq '=-1' -and $hit['OnSelect'] -eq '=Select(Parent)' -and $hit['Width'] -eq '=Parent.TemplateWidth' -and $hit['Height'] -eq '=Parent.TemplateHeight' -and $hit['DisplayMode'] -eq '=If(cmpListCard.Enabled,DisplayMode.Edit,DisplayMode.Disabled)') 'cmpListCard click target: transparent (except hover, also disabled), no text, TabIndex -1, whole row, Select(Parent); disabled while the list is not Enabled'
Assert-True ($hit['HoverFill'] -eq '=If(cmpListCard.Enabled && ThisItem.ID<>cmpListCard.SelectedID,ColorValue("#F0F0F099"),Color.Transparent)') 'cmpListCard click target: HoverFill semi-transparent #F0F0F0 (alpha 0x99 = 0.6) only while the list is enabled and not on the selected row (no clickable look when guarded, selected row stays #D5EDFF), text readable'
Assert-True ($row['recCmpRowFill']['Properties']['Fill'] -notmatch 'Transparent' -and $row['recCmpRowFill']['Properties']['HoverFill'] -match '#F0F0F0' -and $li['galRows']['Properties']['DisplayMode'] -eq '=DisplayMode.Edit') 'cmpListCard row: opaque background (white / #D5EDFF), gallery not in Disabled mode (no dimming overlay)'
foreach ($k in 'txtFieldValue', 'ddFieldValue') { $q = $fi[$k]['Properties']; Assert-True ($q['FocusedBorderThickness'] -eq '=2' -and $q['FocusedBorderColor'] -match '#0303B8' -and $q['FocusedBorderColor'] -match '#DB1E28') "cmpField.$k : focus border 2 px #0303B8 (red when Invalid)" }
Assert-True ($li['txtSearch']['Properties']['FocusedBorderThickness'] -eq '=2' -and $li['txtSearch']['Properties']['Width'] -eq '=Parent.Width-48') 'cmpListCard search: focus border 2 px, 24 px margins inside the card'

# (12) cmpTile (Home redesign, 3-11-2026) ------------------------------------------------------------------
$tp = $defs['cmpTile']['Properties']; $ti = $idx['cmpTile']; $tcp = $defs['cmpTile']['CustomProperties']
Assert-True ($tcp['Active']['Default'] -eq '=false') 'cmpTile.Active default =false (fail-closed: a tile without Active is an inert Soon tile)'
Assert-True ($tcp['Icon']['Default'] -eq '=SampleImage' -and $tcp['Arrow']['Default'] -eq '=SampleImage') 'cmpTile Icon/Arrow: Image inputs with Default =SampleImage (same proven shape as cmpTitleBar.Logo)'
Assert-True ($tp['Width'] -eq '=190' -and $tp['Height'] -eq '=190') 'cmpTile: default size 190 x 190 (the host passes the responsive size)'
Assert-True ((@($defs['cmpTile']['Children'] | ForEach-Object { @($_.Keys)[0] }) -join ',') -eq 'btnCmpTile,imgCmpTileIcon,imgCmpTileArrow,lblCmpTileSoon') 'cmpTile children: click target/label first, icon, arrow, SOON corner on top'
$cb = $ti['btnCmpTile']['Properties']
Assert-True ($ti['btnCmpTile']['Control'] -eq 'Classic/Button@2.2.0' -and -not $cb.ContainsKey('AccessibleLabel')) 'cmpTile.btnCmpTile: Classic/Button@2.2.0 without AccessibleLabel (PA2108)'
Assert-True ($cb['OnSelect'] -ceq '=If(cmpTile.Active,cmpTile.OnSelect())' -and $cb['DisplayMode'] -ceq '=If(cmpTile.Active,DisplayMode.Edit,DisplayMode.Disabled)') 'cmpTile click target raises OnSelect only while Active; Soon = DisplayMode.Disabled (inert)'
Assert-True ($cb['Text'] -eq '=cmpTile.Label' -and $cb['Align'] -eq '=Align.Left' -and $cb['VerticalAlign'] -eq '=VerticalAlign.Bottom' -and $cb['Size'] -eq '=cmpTile.LabelSize' -and $cb['FontWeight'] -eq '=FontWeight.Semibold') 'cmpTile label: bottom left, LabelSize, Semibold'
Assert-True ($cb['PaddingLeft'] -eq '=cmpTile.Padding' -and $cb['PaddingBottom'] -eq '=cmpTile.Padding' -and $cb['PaddingRight'] -eq '=cmpTile.Padding+If(cmpTile.Active,28+8,0)' -and $cb['PaddingTop'] -eq '=cmpTile.Padding+cmpTile.IconSize+8') 'cmpTile label area: padding left/bottom, right clears the 28 px arrow (active tiles only), top clears the icon (a long label can never overlap them)'
foreach ($r in 'RadiusTopLeft', 'RadiusTopRight', 'RadiusBottomLeft', 'RadiusBottomRight') { Assert-True ($cb[$r] -eq '=0') "cmpTile $r = 0 (square)" }
$ci = $ti['imgCmpTileIcon']['Properties']; $ca = $ti['imgCmpTileArrow']['Properties']
Assert-True ($ci['Image'] -eq '=cmpTile.Icon' -and $ci['Width'] -eq '=cmpTile.IconSize' -and $ci['Height'] -eq '=cmpTile.IconSize' -and $ci['X'] -eq '=cmpTile.Padding' -and $ci['Y'] -eq '=cmpTile.Padding') 'cmpTile icon: top left at the padding, IconSize square'
Assert-True ($ca['Image'] -eq '=cmpTile.Arrow' -and $ca['Width'] -eq '=28' -and $ca['Height'] -eq '=20' -and $ca['Visible'] -eq '=cmpTile.Active' -and $ca['X'] -eq '=Parent.Width-cmpTile.Padding-Self.Width' -and $ca['Y'] -eq '=Parent.Height-cmpTile.Padding-Self.Height') 'cmpTile arrow: 28x20 bottom right at the padding, only while Active'
foreach ($k in $ci, $ca) { Assert-True ($k['OnSelect'] -ceq '=If(cmpTile.Active,Select(btnCmpTile))' -and $k['TabIndex'] -eq '=-1' -and !$k.ContainsKey('AccessibleLabel')) 'cmpTile image: click forwards to the tile button only while Active, decorative (TabIndex -1)' }
Assert-True ($ti['imgCmpTileIcon']['Control'] -eq 'Image@2.2.3' -and $ti['imgCmpTileArrow']['Control'] -eq 'Image@2.2.3') 'cmpTile images use Image@2.2.3 (template present in the .msapr)'
$cs = $ti['lblCmpTileSoon']['Properties']
Assert-True ($cs['Text'] -eq '=Upper(cmpTile.SoonText)' -and $cs['Visible'] -eq '=!cmpTile.Active' -and $cs['Size'] -eq '=11' -and $cs['FontWeight'] -eq '=FontWeight.Semibold' -and $cs['Align'] -eq '=Align.Right') 'cmpTile SOON corner: capitals, 11 Semibold, top right, only while not Active'
# Soon tiles are inert for the host too: a handler on the instance of a Soon tile would still never run (button disabled, OnSelect guarded by Active)