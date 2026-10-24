$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot
$pacDir=Split-Path (Get-Command pac).Source
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'YamlDotNet.dll')) | Out-Null
$deserializer=(New-Object YamlDotNet.Serialization.DeserializerBuilder).Build()
function Property([string]$name,[string]$key,[string]$value) {
    $head=[regex]::Match($script:source,'(?m)^( +)- '+[regex]::Escape($name)+':\r?$')
    if(!$head.Success) { throw "Control ontbreekt: $name" }
    $indent=$head.Groups[1].Value
    $pattern='(?ms)^'+$indent+'- '+[regex]::Escape($name)+':.*?(?=^'+$indent+'- |\z)'
    $script:source=[regex]::Replace($script:source,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m)
        $block=$m.Value
        $propIndent=$indent+'      '
        $propPattern='(?m)^'+$propIndent+[regex]::Escape($key)+':[^\r\n]*(?:\r?\n(?:'+$propIndent+'  [^\r\n]*|[ \t]*(?=\r?$)))*'
        if($value -match '[\r\n]') { $value='|-' + "`n" + (($value.TrimEnd() -split '\r?\n' | ForEach-Object {$propIndent+'  '+$_}) -join "`n") }
        $line=$propIndent+$key+': '+$value
        if([regex]::IsMatch($block,$propPattern)) { return [regex]::Replace($block,$propPattern,[Text.RegularExpressions.MatchEvaluator]{param($p) $line}) }
        $children=[regex]::Match($block,'(?m)^'+$indent+'    Children:')
        if($children.Success) { return $block.Insert($children.Index,$line+"`n") }
        return $block.TrimEnd()+"`n"+$line+"`n"
    })
}
function Screen-Event([string]$name,[string]$key,[string]$value) {
    $pattern='(?ms)(^  '+[regex]::Escape($name)+':\r?\n    Properties:\r?\n)(.*?)(?=^    Children:)'
    $script:source=[regex]::Replace($script:source,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m)
        $body=$m.Groups[2].Value
        $propPattern='(?m)^      '+[regex]::Escape($key)+':[^\r\n]*(?:\r?\n(?:        [^\r\n]*|[ \t]*(?=\r?$)))*'
        $line='      '+$key+': '+$value
        if([regex]::IsMatch($body,$propPattern)) { $body=[regex]::Replace($body,$propPattern,[Text.RegularExpressions.MatchEvaluator]{param($p) $line}) }
        else { $body=$body.TrimEnd()+"`n"+$line+"`n" }
        return $m.Groups[1].Value+$body.TrimEnd()+"`n"
    })
}
function Add-Root([string]$block) {
    $script:source=$script:source.TrimEnd()+"`n"+(($block.TrimEnd() -split '\r?\n' | ForEach-Object {'      '+$_}) -join "`n")+"`n"
}
function Hidden-Reader([string]$name,[string]$file) {
    $formula=Get-Content (Join-Path $PSScriptRoot $file) -Encoding UTF8
    $block="- ${name}:`n    Control: Classic/Button@2.2.0`n    Properties:`n      Text: =`"Read`"`n      Visible: =false`n      DisplayMode: =DisplayMode.Edit`n      X: =0`n      Y: =0`n      Width: =1`n      Height: =1`n      OnSelect: |-`n"+(($formula | ForEach-Object {'        '+$_}) -join "`n")
    Add-Root $block
}
function Index-Controls($entries,$out) {
    foreach($entry in $entries) { $name=@($entry.Keys)[0]; $out[$name]=$entry[$name]; Index-Controls $entry[$name]['Children'] $out }
}

$path=Join-Path $projectRoot 'Src/App.pa.yaml'
$app=[IO.File]::ReadAllText($path)
$app=$app.Replace('OnStart: =Set(varSaving, false)','OnStart: =Set(varSaving, false); Set(varWeekSaving, false)')
$app=$app.Replace('    Theme: =PowerAppsTheme',"    StartScreen: =Screen1`n    Theme: =PowerAppsTheme")
[IO.File]::WriteAllText($path,$app,(New-Object Text.UTF8Encoding($false)))

$path=Join-Path $projectRoot 'Src/Screen1.pa.yaml'
$script:source=[IO.File]::ReadAllText($path)
$doc=$deserializer.Deserialize($script:source); $controls=@{}; Index-Controls $doc['Screens']['Screen1']['Children'] $controls
Screen-Event 'Screen1' 'OnVisible' '=Select(btnReadTeam)'
Property 'ddProject' 'Items' '=colSelectionProjects'
Property 'ddProject' 'Default' '=LookUp(colSelectionProjects,Id=varSelectionProjectID,Value)'
foreach($name in @('ddProject','ddTeam')) {
    Property $name 'OnChange' '=If(!varSelectionBusy && !varSaving,Select(btnReadTeam))'
    Property $name 'DisplayMode' '=If(varSelectionBusy || varSaving,DisplayMode.Disabled,DisplayMode.Edit)'
}
Property 'Gallery1' 'Visible' '=varSelectionLoaded && !varSelectionBusy'
Property 'Gallery1' 'Y' '=272'
Property 'Checkbox1' 'DisplayMode' '=If(varSelectionBusy || varSaving || !varSelectionLoaded,DisplayMode.Disabled,DisplayMode.Edit)'
Property 'btnAddtoTeam' 'DisplayMode' ('=If(varSelectionBusy || !varSelectionLoaded || !varSelectionKeysValid,DisplayMode.Disabled,'+$controls['btnAddtoTeam']['Properties']['DisplayMode'].TrimStart('=')+')')
foreach($name in @('btnGotoHours','btnGotoHoursSummary')) {
    Property $name 'DisplayMode' ('=If(varSelectionBusy || !varSelectionLoaded,DisplayMode.Disabled,'+$controls[$name]['Properties']['DisplayMode'].TrimStart('=')+')')
}
Hidden-Reader 'btnReadTeam' 'read-team.fx'
Add-Root @'
- lblSelectionLoadStatus:
    Control: Label@2.5.1
    Properties:
      Text: =If(varSelectionBusy,"Bestaande medewerkers, projecten en teamkoppelingen ophalen...",varSelectionMessage)
      X: =40
      Y: =230
      Width: =Parent.Width-80
      Height: =34
      Font: =Font.'Segoe UI'
      Size: =11
      Color: =If(!IsEmpty(colSelectionLoadErrors),Color.Red,RGBA(35,45,60,1))
'@
[IO.File]::WriteAllText($path,$script:source,(New-Object Text.UTF8Encoding($false)))

$path=Join-Path $projectRoot 'Src/scrHours.pa.yaml'
$script:source=[IO.File]::ReadAllText($path)
$doc=$deserializer.Deserialize($script:source); $controls=@{}; Index-Controls $doc['Screens']['scrHours']['Children'] $controls
Screen-Event 'scrHours' 'OnVisible' '=Select(btnReadWeek)'
Property 'ddHoursYear' 'OnChange' '=If(!varWeekLoading,Reset(ddHoursWeek); Select(btnReadWeek))'
Property 'ddHoursWeek' 'OnChange' '=If(!varWeekLoading,Select(btnReadWeek))'
Property 'ddHoursYear' 'Items' '=Sequence(Min(500,Max(Year(Today())+5,Coalesce(varEntryLastISOYear,Year(Today())))-Min(Year(Today())-5,Coalesce(varEntryFirstISOYear,Year(Today())))+1),Min(Year(Today())-5,Coalesce(varEntryFirstISOYear,Year(Today()))))'
foreach($name in @('ddHoursYear','ddHoursWeek','btnWeeklyProjectTeam')) {
    Property $name 'DisplayMode' ('=If(varWeekLoading,DisplayMode.Disabled,'+$controls[$name]['Properties']['DisplayMode'].TrimStart('=')+')')
}
Property 'btnSaveWeek' 'DisplayMode' ('=If(varWeekLoading || !varWeekReady || varWeekKeyIssue,DisplayMode.Disabled,'+$controls['btnSaveWeek']['Properties']['DisplayMode'].TrimStart('=')+')')
foreach($name in @('txtMon','txtTue','txtWed','txtThu','txtFri','txtSat','txtSun')) {
    Property $name 'DisplayMode' ('=If(varWeekLoading || !varWeekReady || varWeekKeyIssue,DisplayMode.Disabled,'+$controls[$name]['Properties']['DisplayMode'].TrimStart('=')+')')
}
Property 'galHours' 'Visible' '=varWeekReady && !varWeekLoading'
Property 'galHours' 'Y' '=276'
Hidden-Reader 'btnReadWeek' 'read-week.fx'
Add-Root @'
- lblWeekLoadStatus:
    Control: Label@2.5.1
    Properties:
      Text: =If(varWeekLoading,"Opgeslagen weekuren uit SharePoint ophalen...",varWeekMessage)
      X: =40
      Y: =184
      Width: =Parent.Width-80
      Height: =32
      Font: =Font.'Segoe UI'
      Size: =11
      Color: =If(!IsEmpty(colWeekLoadErrors),Color.Red,RGBA(35,45,60,1))
'@
[IO.File]::WriteAllText($path,$script:source,(New-Object Text.UTF8Encoding($false)))
