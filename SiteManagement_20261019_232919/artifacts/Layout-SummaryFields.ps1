$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot
$path=Join-Path $projectRoot 'Src/scrWeeklyHours.pa.yaml'
$source=[IO.File]::ReadAllText($path)
function Property([string]$name,[string]$key,[string]$value) {
    $head=[regex]::Match($script:source,'(?m)^( +)- '+[regex]::Escape($name)+':\r?$')
    if(!$head.Success) { throw "Control ontbreekt: $name" }
    $indent=$head.Groups[1].Value
    $pattern='(?ms)^'+$indent+'- '+[regex]::Escape($name)+':.*?(?=^'+$indent+'- |\z)'
    $script:source=[regex]::Replace($script:source,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m)
        $block=$m.Value; $pi=$indent+'      '
        $pattern='(?m)^'+$pi+[regex]::Escape($key)+':[^\r\n]*(?:\r?\n(?:'+$pi+'  [^\r\n]*|[ \t]*(?=\r?$)))*'
        $line=$pi+$key+': '+$value
        if([regex]::IsMatch($block,$pattern)) { return [regex]::Replace($block,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($p) $line}).TrimEnd()+"`n" }
        $child=[regex]::Match($block,'(?m)^'+$indent+'    Children:')
        if($child.Success) { return $block.Insert($child.Index,$line+"`n") }
        return $block.TrimEnd()+"`n"+$line+"`n"
    })
}
Property 'ddReportProject' 'Width' '=2*lblSummaryFieldWidth.Width'
Property 'ddReportProject' 'X' '=0'
Property 'ddReportProject' 'Y' '=lblReportProject.Y+lblReportProject.Height+4'
Property 'lblReportProject' 'X' '=ddReportProject.X'
Property 'lblReportProject' 'Y' '=0'
Property 'lblReportProject' 'Width' '=ddReportProject.Width'
Property 'lblReportProject' 'Height' '=24'
Property 'ddReportContractor' 'Width' '=2*lblSummaryFieldWidth.Width'
Property 'ddReportContractor' 'X' '=If(Parent.Width>=ddReportProject.Width+12+Self.Width,ddReportProject.Width+12,0)'
Property 'ddReportContractor' 'Y' '=lblReportContractor.Y+lblReportContractor.Height+4'
Property 'lblReportContractor' 'X' '=ddReportContractor.X'
Property 'lblReportContractor' 'Y' '=If(ddReportContractor.X=0,ddReportProject.Y+ddReportProject.Height+12,lblReportProject.Y)'
Property 'lblReportContractor' 'Width' '=ddReportContractor.Width'
Property 'lblReportContractor' 'Height' '=24'
Property 'btnRefreshReport' 'X' '=If(ddReportContractor.X+ddReportContractor.Width+12+Self.Width<=Parent.Width,ddReportContractor.X+ddReportContractor.Width+12,0)'
Property 'btnRefreshReport' 'Y' '=If(Self.X>0,ddReportContractor.Y,ddReportContractor.Y+ddReportContractor.Height+12)'
$periods=@('ddReportStartYear','ddReportStartWeek','ddReportEndYear','ddReportEndWeek')
$columns='Max(1,RoundDown((Parent.Width+12)/(lblSummaryFieldWidth.Width+12),0))'
for($i=0;$i -lt 4;$i++) {
    $field=$periods[$i]; $label='lbl'+$field
    Property $field 'Width' '=lblSummaryFieldWidth.Width'
    Property $field 'X' ('=Mod('+$i+','+$columns+')*(lblSummaryFieldWidth.Width+12)')
    Property $field 'Y' ('='+$label+'.Y+'+$label+'.Height+4')
    Property $label 'X' ('='+$field+'.X')
    Property $label 'Width' ('='+$field+'.Width')
    Property $label 'Height' '=24'
    if($i -eq 0) { Property $label 'Y' '=Max(ddReportProject.Y+ddReportProject.Height,ddReportContractor.Y+ddReportContractor.Height,btnRefreshReport.Y+btnRefreshReport.Height)+12' }
    else { Property $label 'Y' ('=lblddReportStartYear.Y+RoundDown('+$i+'/'+$columns+',0)*(lblddReportStartYear.Height+4+ddReportStartYear.Height+12)') }
}
Property 'lblReportProjectDetails' 'Y' '=conSummarySelectors.Y+conSummarySelectors.Height+12'
Property 'lblReportStatus' 'Y' '=lblReportProjectDetails.Y+lblReportProjectDetails.Height+8'
foreach($name in @('btnReportPreviousWeeks','btnReportNextWeeks')) { Property $name 'Y' '=lblReportStatus.Y+lblReportStatus.Height+12' }
foreach($name in @('lblReportNameHeader','lblReportEmployerHeader','galReportWeekHeaders','lblReportTotalHeader')) { Property $name 'Y' '=btnReportPreviousWeeks.Y+btnReportPreviousWeeks.Height+12' }
Property 'galReportRows' 'Y' '=lblReportNameHeader.Y+lblReportNameHeader.Height'

# Move only selectors and Refresh into plain layout containers. Unlike a Gallery,
# these keep existing Reset()/Select() calls in the original control context.
$move=@('lblReportProject','ddReportProject','lblReportContractor','ddReportContractor','btnRefreshReport',
 'lblddReportStartYear','ddReportStartYear','lblddReportStartWeek','ddReportStartWeek',
 'lblddReportEndYear','ddReportEndYear','lblddReportEndWeek','ddReportEndWeek')
$blocks=''
foreach($name in $move) {
    $pattern='(?ms)^    - '+[regex]::Escape($name)+':.*?(?=^    - |\z)'
    $m=[regex]::Match($source,$pattern)
    if(!$m.Success) { throw "Selectiecontrol ontbreekt: $name" }
    $blocks+=(($m.Value.TrimEnd() -split '\r?\n' | ForEach-Object {'            '+$_}) -join "`n")+"`n"
    $source=$source.Remove($m.Index,$m.Length)
}
$layout=@'
    - lblSummaryFieldWidth:
        Control: Label@2.5.1
        Properties:
          Text: =""
          Visible: =false
          X: =0
          Y: =0
          Width: =256
          Height: =1
    - conSummarySelectors:
        Control: GroupContainer@1.5.0
        Variant: AutoLayout
        Properties:
          X: =40
          Y: =116
          Width: =Parent.Width-80
          Height: =Min(conSummaryFiltersContent.Height,Max(64,Min(220,navHoursSummary.Y-Self.Y-284)))
          Fill: =Color.Transparent
          LayoutDirection: =LayoutDirection.Vertical
          LayoutAlignItems: =LayoutAlignItems.Start
          LayoutJustifyContent: =LayoutJustifyContent.Start
          LayoutGap: =0
          LayoutWrap: =false
          LayoutOverflowX: =LayoutOverflow.Scroll
          LayoutOverflowY: =LayoutOverflow.Scroll
          PaddingTop: =0
          PaddingBottom: =0
          PaddingLeft: =0
          PaddingRight: =0
        Children:
          - conSummaryFiltersContent:
              Control: GroupContainer@1.5.0
              Variant: ManualLayout
              Properties:
                Width: =Max(2*lblSummaryFieldWidth.Width,Parent.Width-16)
                Height: =Max(ddReportStartYear.Y+ddReportStartYear.Height,ddReportStartWeek.Y+ddReportStartWeek.Height,ddReportEndYear.Y+ddReportEndYear.Height,ddReportEndWeek.Y+ddReportEndWeek.Height)+12
                FillPortions: =0
                Fill: =Color.Transparent
              Children:
'@
$source=$source.TrimEnd()+"`n"+$layout+"`n"+$blocks
[IO.File]::WriteAllText($path,$source,(New-Object Text.UTF8Encoding($false)))
