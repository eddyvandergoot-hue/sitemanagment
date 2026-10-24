$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'Src/scrWeeklyHours.pa.yaml'
$source = [IO.File]::ReadAllText($sourcePath)
function Set-ControlProperty([string]$name,[string]$property,[string]$value) {
    $pattern = '(?ms)(^    - ' + [regex]::Escape($name) + ':\r?\n.*?)(?=^    - |\z)'
    $script:source = [regex]::Replace($script:source, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match)
        $block = $match.Value
        $propertyPattern = '(?m)^          ' + [regex]::Escape($property) + ':[^\r\n]*(?:\r?\n            [^\r\n]*)*'
        if ($block -match $propertyPattern) {
            return [regex]::Replace($block,$propertyPattern,[System.Text.RegularExpressions.MatchEvaluator]{ param($line) '          ' + $property + ': ' + $value })
        }
        return $block.TrimEnd() + "`n          ${property}: $value`n"
    })
}
foreach($pair in @(@('btnRefreshReport','weekly-refresh.fx'),@('btnBuildReport','weekly-build.fx'))) {
    $formulaLines = Get-Content (Join-Path $PSScriptRoot $pair[1]) -Encoding UTF8
    $block = '|-' + "`n" + (($formulaLines | ForEach-Object { '            ' + $_ }) -join "`n")
    Set-ControlProperty $pair[0] 'OnSelect' $block
}
Set-ControlProperty 'btnBuildReport' 'DisplayMode' '=DisplayMode.Edit'
Set-ControlProperty 'ddReportProject' 'Items' '=colReportProjects'
Set-ControlProperty 'ddReportProject' 'Items.Value' '=Title'
Set-ControlProperty 'ddReportProject' 'Default' '=Coalesce(LookUp(colReportProjects,ID=varReportProjectID,Title),ddProject.Selected.Value)'
Set-ControlProperty 'ddReportProject' 'OnChange' '=If(!varReportBusy && Coalesce(Self.Selected.ID,0)<>Coalesce(varReportProjectID,0),Set(varReportValid,false); Set(varReportReady,false); Select(btnRefreshReport))'
Set-ControlProperty 'ddReportContractor' 'Items' '=Sort(colReportContractors,Value,SortOrder.Ascending)'
Set-ControlProperty 'ddReportContractor' 'Default' '="Alle contractors"'
Set-ControlProperty 'ddReportContractor' 'AllowEmptySelection' '=false'
Set-ControlProperty 'ddReportContractor' 'OnChange' '=If(!varReportBusy,Set(varReportValid,false); Select(btnBuildReport))'
Set-ControlProperty 'ddReportStartYear' 'OnChange' '=If(!varReportBusy,Set(varReportValid,false); ClearCollect(colReportStartWeeks,Sort(Distinct(Filter(colReportPeriods,ISOYear=Self.Selected.Value),KW),Value,SortOrder.Ascending)); Reset(ddReportStartWeek); Select(btnBuildReport))'
Set-ControlProperty 'ddReportEndYear' 'OnChange' '=If(!varReportBusy,Set(varReportValid,false); ClearCollect(colReportEndWeeks,Sort(Distinct(Filter(colReportPeriods,ISOYear=Self.Selected.Value),KW),Value,SortOrder.Ascending)); Reset(ddReportEndWeek); Select(btnBuildReport))'
Set-ControlProperty 'ddReportStartWeek' 'OnChange' '=If(!varReportBusy,Set(varReportValid,false); Select(btnBuildReport))'
Set-ControlProperty 'ddReportEndWeek' 'OnChange' '=If(!varReportBusy,Set(varReportValid,false); Select(btnBuildReport))'
foreach($name in @('ddReportStartYear','ddReportStartWeek','ddReportEndYear','ddReportEndWeek')) {
    Set-ControlProperty $name 'DisplayMode' '=If(varReportBusy || !varReportReady || IsEmpty(colReportPeriods),DisplayMode.Disabled,DisplayMode.Edit)'
}
Set-ControlProperty 'lblReportGrandTotal' 'Visible' '=varReportValid && !varReportBusy'
$pagingButtons = @'
    - btnReportPreviousWeeks:
        Control: Classic/Button@2.2.0
        Properties:
          Text: ="<"
          X: =440
          Y: =338
          Width: =44
          Height: =32
          Visible: =varReportValid && CountRows(colReportColumns)>varReportVisibleWeeks
          DisplayMode: =If(Min(Coalesce(varReportColumnOffset,1),Max(1,CountRows(colReportColumns)-varReportVisibleWeeks+1))<=1,DisplayMode.Disabled,DisplayMode.Edit)
          OnSelect: =Set(varReportColumnOffset,Max(1,Min(Coalesce(varReportColumnOffset,1),Max(1,CountRows(colReportColumns)-varReportVisibleWeeks+1))-1))
    - btnReportNextWeeks:
        Control: Classic/Button@2.2.0
        Properties:
          Text: =">"
          X: =496
          Y: =338
          Width: =44
          Height: =32
          Visible: =varReportValid && CountRows(colReportColumns)>varReportVisibleWeeks
          DisplayMode: =If(Coalesce(varReportColumnOffset,1)>=Max(1,CountRows(colReportColumns)-varReportVisibleWeeks+1),DisplayMode.Disabled,DisplayMode.Edit)
          OnSelect: =Set(varReportColumnOffset,Min(Max(1,CountRows(colReportColumns)-varReportVisibleWeeks+1),Coalesce(varReportColumnOffset,1)+1))
'@
$source = [regex]::Replace($source,'(?ms)^    - sldReportWeeks:.*?(?=^    - )',$pagingButtons + "`n")
$source = $source.Replace('WeekIndex>=Coalesce(varReportColumnOffset,1)','WeekIndex>=Min(Coalesce(varReportColumnOffset,1),Max(1,CountRows(colReportColumns)-varReportVisibleWeeks+1))')
$source = $source.Replace('ddReportProject.Selected.Id','ddReportProject.Selected.ID')
$source = $source.Replace('OnVisible: =Set(varReportVisibleWeeks,Max(1,RoundDown((Self.Width-600)/90,0))); Select(btnRefreshReport)','OnVisible: =Set(varReportValid,false); Select(btnRefreshReport)')
$source = $source.Replace('varReportVisibleWeeks','Max(1,RoundDown((scrWeeklyHours.Width-600)/90,0))')
# The format language and output language must be independent of the maker locale.
$source = $source.Replace('\"0\",\"0.00\"','\"[$-en-US]0\",\"[$-en-US]0.00\"')
$source = $source.Replace('"0","0.00"','"[$-en-US]0","[$-en-US]0.00"')
$source = $source.Replace('WeekHours,Sum(Filter(workerHours,Monday=week.Monday),HourValue)','WeekHours,Coalesce(Sum(Filter(workerHours,Monday=week.Monday),HourValue),0)')
[IO.File]::WriteAllText($sourcePath,$source,(New-Object Text.UTF8Encoding($false)))
