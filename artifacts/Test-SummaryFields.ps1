param([switch]$GeometryOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
$backup=Join-Path $projectRoot (Get-Content (Join-Path $PSScriptRoot 'summary-fields-backup.txt') -Raw -Encoding UTF8).Trim()
function Index-Fields($entries,$out,[string]$parentName) {
    foreach($entry in $entries) { $name=@($entry.Keys)[0]; $out[$name]=@{Node=$entry[$name];Parent=$parentName}; Index-Fields $entry[$name]['Children'] $out $name }
}
$current=@{}; Index-Fields $yaml['Screens']['scrWeeklyHours']['Children'] $current 'scrWeeklyHours'
$oldDoc=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $backup 'scrWeeklyHours.pa.yaml')))
$previous=@{}; Index-Fields $oldDoc['Screens']['scrWeeklyHours']['Children'] $previous 'scrWeeklyHours'
$allowed=@('X','Y','Width','Height')
if(!$GeometryOnly) {
foreach($name in $previous.Keys) {
    if(!$current.ContainsKey($name)) { throw "Control verwijderd: $name" }
    foreach($prop in $previous[$name].Node['Properties'].Keys) {
        if($prop -notin $allowed -and $previous[$name].Node['Properties'][$prop] -cne $current[$name].Node['Properties'][$prop]) { throw "Niet-layout-eigenschap gewijzigd: $name.$prop" }
    }
    foreach($prop in $current[$name].Node['Properties'].Keys) {
        if(!$previous[$name].Node['Properties'].ContainsKey($prop) -and $prop -notin $allowed) { throw "Niet-layout-eigenschap toegevoegd: $name.$prop" }
    }
}
if($yaml['Screens']['scrWeeklyHours']['Properties']['OnVisible'] -cne $oldDoc['Screens']['scrWeeklyHours']['Properties']['OnVisible']) { throw 'OnVisible gewijzigd' }
foreach($file in Get-ChildItem (Join-Path $projectRoot 'Src') -Filter '*.pa.yaml') {
    if($file.Name -ne 'scrWeeklyHours.pa.yaml' -and (Get-FileHash $file.FullName).Hash -ne (Get-FileHash (Join-Path $backup $file.Name)).Hash) { throw "Andere bron gewijzigd: $($file.Name)" }
}
Write-Output 'PASS uitsluitend X/Y/Width/Height van bestaande controls gewijzigd; Items, Default, OnChange, acties, limieten, Visible, DisplayMode en OnVisible exact behouden. Andere appbronnen bytegelijk.'
}
if($current['lblSummaryFieldWidth'].Node['Properties']['Width'] -ne '=256') { throw 'Gedeelde veldbreedte onjuist' }
if($current['conSummarySelectors'].Node['Properties']['LayoutOverflowY'] -ne '=LayoutOverflow.Scroll' -or $current['conSummarySelectors'].Parent -ne 'scrWeeklyHours') { throw 'Selectieviewport onjuist' }
if($current['navHoursSummary'].Parent -ne 'scrWeeklyHours') { throw 'Navigatie niet vast op scherm' }

[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$engineFields=New-Object Microsoft.PowerFx.RecalcEngine
$optionsFields=New-Object Microsoft.PowerFx.ParserOptions
$optionsFields.Culture=[Globalization.CultureInfo]::GetCultureInfo('en-US')
$periods=@('ddReportStartYear','ddReportStartWeek','ddReportEndYear','ddReportEndWeek')
$measure=@('lblSummaryFieldWidth','navHoursSummary','conSummarySelectors','conSummaryFiltersContent','lblReportProject','ddReportProject','lblReportContractor','ddReportContractor','btnRefreshReport',
 'lblddReportStartYear','ddReportStartYear','lblddReportStartWeek','ddReportStartWeek','lblddReportEndYear','ddReportEndYear','lblddReportEndWeek','ddReportEndWeek',
 'lblReportProjectDetails','lblReportStatus','btnReportPreviousWeeks','btnReportNextWeeks','lblReportNameHeader','lblReportEmployerHeader','galReportWeekHeaders','lblReportTotalHeader','galReportRows','lblReportGrandTotal','btnSummaryProjectTeam')
function Numeric-Field([string]$formula,$self,$parent,$rects) {
    $symbols=@('LayoutParent:{X:'+$parent.X+',Y:'+$parent.Y+',Width:'+$parent.Width+',Height:'+$parent.Height+'}')
    $symbols+=('LayoutSelf:{X:'+$self.X+',Y:'+$self.Y+',Width:'+$self.Width+',Height:'+$self.Height+'}')
    foreach($key in $rects.Keys) { $r=$rects[$key]; $symbols+=($key+':{X:'+$r.X+',Y:'+$r.Y+',Width:'+$r.Width+',Height:'+$r.Height+'}') }
    $f=$formula.Trim().TrimStart('=').Replace('Parent.','LayoutParent.').Replace('Self.','LayoutSelf.')
    $expression='With({'+($symbols -join ',')+'},'+$f+')'
    try { $value=$engineFields.Eval($expression,$null,$optionsFields) }
    catch { throw ($f+"`n"+$_.Exception.InnerException.InnerException.Message+"`n"+$expression) }
    if($value -is [Microsoft.PowerFx.Types.ErrorValue]) { throw ($value.Errors | Out-String) }
    return [double]$value.Value
}
function No-Overlap($a,$b,[string]$label) {
    if($a.X -lt $b.X+$b.Width-0.01 -and $a.X+$a.Width -gt $b.X+0.01 -and $a.Y -lt $b.Y+$b.Height-0.01 -and $a.Y+$a.Height -gt $b.Y+0.01) { throw "Overlap: $label" }
}
foreach($size in @(@(320,600),@(600,600),@(768,600),@(1024,768),@(1132,768),@(1156,768),@(1254,720),@(1280,720),@(1366,768),@(1920,1080))) {
    $w=$size[0]; $h=$size[1]
    $rects=@{scrWeeklyHours=@{X=0;Y=0;Width=$w;Height=$h}}
    foreach($name in $measure) { $rects[$name]=@{X=0;Y=0;Width=0;Height=0} }
    for($pass=0;$pass -lt 10;$pass++) {
        foreach($name in $measure) {
            $props=$current[$name].Node['Properties']; $self=$rects[$name]; $parent=$rects[$current[$name].Parent]
            foreach($prop in @('Width','Height','X','Y')) { if($props.ContainsKey($prop)) { $self[$prop]=Numeric-Field $props[$prop] $self $parent $rects } }
        }
    }
    $content=$rects.conSummaryFiltersContent
    $pairs=@(@('lblReportProject','ddReportProject'),@('lblReportContractor','ddReportContractor'))
    foreach($p in $periods) { $pairs+=,@(('lbl'+$p),$p) }
    foreach($pair in $pairs) {
        $label=$rects[$pair[0]]; $field=$rects[$pair[1]]
        $expected=if($pair[1] -in $periods) {256} else {512}
        if($field.Width -ne $expected -or $label.Width -ne $field.Width -or $label.X -ne $field.X -or $label.Y+$label.Height+4 -ne $field.Y) { throw "Breedte/label onjuist: $($pair[1])" }
        if($field.X -lt 0 -or $field.X+$field.Width -gt $content.Width+0.01 -or $field.Y+$field.Height -gt $content.Height+0.01) { throw "Veld buiten scrollinhoud: $($pair[1])" }
    }
    $fields=@('ddReportProject','ddReportContractor','btnRefreshReport')+$periods
    for($a=0;$a -lt $fields.Count;$a++) { for($b=$a+1;$b -lt $fields.Count;$b++) { No-Overlap $rects[$fields[$a]] $rects[$fields[$b]] ($fields[$a]+'/'+$fields[$b]) } }
    foreach($p in $periods) {
        if($rects[$p].X -ne 0 -and $rects[$p].X % 268 -ne 0) { throw 'Geen vaste 12 px veldtussenruimte' }
    }
    if($rects.conSummarySelectors.Y -lt 80 -or $rects.conSummarySelectors.Y+$rects.conSummarySelectors.Height -gt $rects.navHoursSummary.Y -or $rects.lblReportGrandTotal.Y+$rects.lblReportGrandTotal.Height -gt $rects.navHoursSummary.Y-12+0.01 -or $rects.galReportRows.Y+$rects.galReportRows.Height -gt $rects.lblReportGrandTotal.Y-12+0.01) { throw 'Selecties/totaal/navigatie overlappen' }
    if($rects.galReportRows.Height -lt 44) { throw 'Geen volledige rapportregel boven de navigatie' }
    if($w -ge 1254 -and ($rects.ddReportProject.Y -ne $rects.ddReportContractor.Y -or $rects.ddReportStartYear.Y -ne $rects.ddReportEndWeek.Y)) { throw 'Brede weergave heeft niet de gewenste twee rijen' }
    Write-Output "PASS $w x $h : vaste 256/512-breedtes, labels uitgelijnd, velden/Refresh zonder overlap, regelomloop en scrollruimte, totaal boven vaste navigatie."
}
Write-Output 'Dit modelleert layoutformules en inhoudsgrenzen; Studio-import, AutoLayout-scrollgedrag en browserweergave zijn nog niet getest. Onder 768 px is alleen het selectieblok gemodelleerd, niet de bestaande rapporttabelbreedte.'

