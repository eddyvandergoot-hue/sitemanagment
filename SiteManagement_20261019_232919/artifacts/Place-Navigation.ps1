$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot
function Property([string]$name,[string]$key,[string]$value) {
    $head=[regex]::Match($script:source,'(?m)^( +)- '+[regex]::Escape($name)+':\r?$')
    if(!$head.Success) { throw "Control ontbreekt: $name" }
    $indent=$head.Groups[1].Value
    $pattern='(?ms)^'+$indent+'- '+[regex]::Escape($name)+':.*?(?=^'+$indent+'- |\z)'
    $script:source=[regex]::Replace($script:source,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m)
        $block=$m.Value
        $propIndent=$indent+'      '
        $propPattern='(?m)^'+$propIndent+[regex]::Escape($key)+':[^\r\n]*(?:\r?\n'+$propIndent+'  [^\r\n]*)*'
        $line=$propIndent+$key+': '+$value
        if([regex]::IsMatch($block,$propPattern)) {
            return [regex]::Replace($block,$propPattern,[Text.RegularExpressions.MatchEvaluator]{param($p) $line})
        }
        # Insert into Properties before any nested Children/Variant declarations.
        $children=[regex]::Match($block,'(?m)^'+$indent+'    Children:')
        if($children.Success) { return $block.Insert($children.Index,$line+"`n") }
        return $block.TrimEnd()+"`n"+$line+"`n"
    })
}
function Add-Root([string]$block) {
    $script:source=$script:source.TrimEnd()+"`n"+(($block.TrimEnd() -split '\r?\n' | ForEach-Object {$script:rootIndent+$_}) -join "`n")+"`n"
}
function Footer([string]$name,[string[]]$buttons,[string]$extra='') {
    $children=''
    foreach($button in $buttons) {
        $pattern='(?ms)^'+$script:rootIndent+'- '+[regex]::Escape($button)+':.*?(?=^'+$script:rootIndent+'- |\z)'
        $match=[regex]::Match($script:source,$pattern)
        if(!$match.Success) { throw "Navigatieknop ontbreekt: $button" }
        $children+=(($match.Value.TrimEnd() -split '\r?\n' | ForEach-Object {'      '+$_}) -join "`n")+"`n"
        $script:source=$script:source.Remove($match.Index,$match.Length)
    }
    $bar=@"
- ${name}:
    Control: GroupContainer@1.5.0
    Variant: ManualLayout
    Properties:
      X: =0
      Y: =Parent.Height-Self.Height
      Width: =Parent.Width
      Height: =72
      Fill: =RGBA(244,246,250,1)
    Children:
"@
    Add-Root $bar
    $script:source+=$children
    if($extra) { $script:source+=(($extra.TrimEnd() -split '\r?\n' | ForEach-Object {$script:rootIndent+'      '+$_}) -join "`n")+"`n" }
}
function Title([string]$name,[string]$text) {
    Property $name 'Text' ('="'+$text+'"')
    foreach($pair in @(@('X','=40'),@('Y','=24'),@('Width','=Parent.Width-80'),@('Height','=56'),@('Size','=22'),@('PaddingLeft','=16'),@('Fill','=RGBA(25,66,150,1)'),@('Color','=Color.White'),@('Font',"=Font.'Segoe UI'"),@('FontWeight','=FontWeight.Semibold'))) { Property $name $pair[0] $pair[1] }
}

$script:rootIndent='      '
$path=Join-Path $projectRoot 'Src/Screen1.pa.yaml'
$script:source=[IO.File]::ReadAllText($path)
Add-Root @'
- lblProjectTeamTitle:
    Control: Label@2.5.1
    Properties:
      Text: ="Project / team"
'@
Title 'lblProjectTeamTitle' 'Project / team'
Property 'conSelection' 'X' '=40'
Property 'conSelection' 'Y' '=104'
Property 'conSelection' 'Width' '=Parent.Width-80'
foreach($control in @('ddProject','ddTeam')) { Property $control 'Width' '=Min(419,Parent.Width-200)'; Property $control 'Height' '=40' }
foreach($control in @('lblProject','lblTeam')) { Property $control 'Height' '=40' }
Property 'Gallery1' 'X' '=40'
Property 'Gallery1' 'Y' '=240'
Property 'Gallery1' 'Width' '=Parent.Width-80'
Property 'Gallery1' 'Height' '=Max(0,Label2.Y-12-Self.Y)'
Property 'Workercard' 'Width' '=Parent.TemplateWidth-8'
Property 'Label2' 'X' '=40'
Property 'Label2' 'Y' '=navProjectTeam.Y-56'
Property 'Label2' 'Width' '=Parent.Width-280'
Property 'Label2' 'Height' '=40'
Property 'btnAddtoTeam' 'X' '=Parent.Width-200'
Property 'btnAddtoTeam' 'Y' '=Label2.Y'
Property 'btnGotoHours' 'X' '=40'
Property 'btnGotoHours' 'Y' '=16'
Property 'btnGotoHoursSummary' 'X' '=btnGotoHours.X+btnGotoHours.Width+12'
Property 'btnGotoHoursSummary' 'Y' '=btnGotoHours.Y'
Footer 'navProjectTeam' @('btnGotoHours','btnGotoHoursSummary')
[IO.File]::WriteAllText($path,$script:source,(New-Object Text.UTF8Encoding($false)))

$path=Join-Path $projectRoot 'Src/scrHours.pa.yaml'
$script:source=[IO.File]::ReadAllText($path)
Title 'lblWeeklyHoursEntryTitle' 'Weekly Hours'
foreach($pair in @(@('lblISOYears','40'),@('lblKW','212'))) {
    Property $pair[0] 'X' ('='+$pair[1]); Property $pair[0] 'Y' '=104'
    Property $pair[0] 'Width' '=160'; Property $pair[0] 'Height' '=28'
}
foreach($pair in @(@('ddHoursYear','40'),@('ddHoursWeek','212'))) {
    Property $pair[0] 'X' ('='+$pair[1]); Property $pair[0] 'Y' '=136'
    Property $pair[0] 'Width' '=160'; Property $pair[0] 'Height' '=40'
}
Property 'btnSaveWeek' 'Y' '=136'
Property 'galHours' 'Y' '=244'
Property 'galHours' 'Height' '=Max(0,navWeeklyHours.Y-12-Self.Y)'
$back=@'
- btnWeeklyProjectTeam:
    Control: Classic/Button@2.2.0
    Properties:
      Text: ="Project / team"
      OnSelect: =Navigate(Screen1,ScreenTransition.Fade)
      DisplayMode: =If(varWeekSaving || (JSON(ShowColumns(colWeekRows,ID,MonHours,TueHours,WedHours,ThuHours,FriHours,SatHours,SunHours))<>JSON(ShowColumns(colWeekOriginal,ID,MonHours,TueHours,WedHours,ThuHours,FriHours,SatHours,SunHours))),DisplayMode.Disabled,DisplayMode.Edit)
      Tooltip: ="Sla gewijzigde uren op voordat u naar project / team gaat."
      X: =40
      Y: =16
      Width: =160
      Height: =40
      Font: =Font.'Segoe UI'
      Size: =14
      FontWeight: =FontWeight.Semibold
      Align: =Align.Center
      VerticalAlign: =VerticalAlign.Middle
      PaddingTop: =0
      PaddingBottom: =0
      PaddingLeft: =16
      PaddingRight: =16
      RadiusTopLeft: =8
      RadiusTopRight: =8
      RadiusBottomLeft: =8
      RadiusBottomRight: =8
'@
Footer 'navWeeklyHours' @() $back
[IO.File]::WriteAllText($path,$script:source,(New-Object Text.UTF8Encoding($false)))

$script:rootIndent='    '
$path=Join-Path $projectRoot 'Src/scrWeeklyHours.pa.yaml'
$script:source=[IO.File]::ReadAllText($path)
Title 'lblWeeklyHoursTitle' 'Hours Summary'
Property 'lblSummaryPurpose' 'Y' '=84'
Property 'lblSummaryPurpose' 'Height' '=28'
Property 'btnSummaryProjectTeam' 'X' '=40'
Property 'btnSummaryProjectTeam' 'Y' '=16'
Property 'btnRefreshReport' 'Y' '=148'
Property 'lblReportProject' 'Y' '=116'
Property 'lblReportContractor' 'Y' '=116'
foreach($control in @('lblReportProject','ddReportProject','lblReportContractor','ddReportContractor')) { Property $control 'Width' '=(Parent.Width-226)/2' }
foreach($control in @('lblReportContractor','ddReportContractor')) { Property $control 'X' '=40+(Parent.Width-226)/2+24' }
foreach($control in @('ddReportProject','ddReportContractor')) { Property $control 'Y' '=148'; Property $control 'Height' '=36' }
Property 'lblReportProjectDetails' 'Y' '=192'
Property 'lblReportProjectDetails' 'Height' '=28'
$periods=@('ddReportStartYear','ddReportStartWeek','ddReportEndYear','ddReportEndWeek')
for($i=0;$i -lt $periods.Count;$i++) {
    foreach($control in @($periods[$i],('lbl'+$periods[$i]))) {
        Property $control 'X' ('=40+'+$i+'*((Parent.Width-116)/4+12)')
        Property $control 'Width' '=(Parent.Width-116)/4'
    }
}
Property 'lblReportGrandTotal' 'Y' '=navHoursSummary.Y-44'
Property 'galReportRows' 'Height' '=Max(0,lblReportGrandTotal.Y-12-Self.Y)'
Footer 'navHoursSummary' @('btnSummaryProjectTeam')
[IO.File]::WriteAllText($path,$script:source,(New-Object Text.UTF8Encoding($false)))
