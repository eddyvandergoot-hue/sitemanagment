param([switch]$LayoutOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$evalEngine=New-Object Microsoft.PowerFx.RecalcEngine
$layoutOptions=New-Object Microsoft.PowerFx.ParserOptions
$layoutOptions.Culture=[Globalization.CultureInfo]::GetCultureInfo('en-US')
$backup=Join-Path $projectRoot (Get-Content (Join-Path $PSScriptRoot 'navigation-backup.txt') -Raw -Encoding UTF8).Trim()
$indexes=@{}
function Index-Controls($entries,$out,[string]$parentName) {
    foreach($entry in $entries) {
        $controlName=@($entry.Keys)[0]
        $out[$controlName]=@{Node=$entry[$controlName];Parent=$parentName}
        Index-Controls $entry[$controlName]['Children'] $out $controlName
    }
}
$protected=@('OnSelect','OnChange','OnCheck','OnUncheck','Visible','DisplayMode','Text','Items','Items.Value','Default')
foreach($screenName in @('Screen1','scrHours','scrWeeklyHours')) {
    $document=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot ('Src/'+$screenName+'.pa.yaml'))))
    $previous=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $backup ($screenName+'.pa.yaml'))))
    $index=@{}; $oldIndex=@{}
    Index-Controls $document['Screens'][$screenName]['Children'] $index $screenName
    Index-Controls $previous['Screens'][$screenName]['Children'] $oldIndex $screenName
    if(!$LayoutOnly) { foreach($controlName in $oldIndex.Keys) {
        if(!$index.ContainsKey($controlName)) { throw "Control verdwenen: $controlName" }
        foreach($prop in $protected) {
            if($index[$controlName].Node['Properties'][$prop] -cne $oldIndex[$controlName].Node['Properties'][$prop]) { throw "Gedrag gewijzigd: $controlName.$prop" }
        }
    }
    if($document['Screens'][$screenName]['Properties']['OnVisible'] -cne $previous['Screens'][$screenName]['Properties']['OnVisible']) { throw 'OnVisible gewijzigd' }
    }
    foreach($controlName in $index.Keys) {
        $node=$index[$controlName].Node
        if($node['Properties']['OnSelect'] -match '\b(Navigate|Back)\s*\(') {
            if($index[$controlName].Parent -notin @('navProjectTeam','navWeeklyHours','navHoursSummary')) { throw "Navigatie buiten onderbalk: $controlName" }
        }
    }
    if($screenName -ne 'scrWeeklyHours') { Check-Node $document $screenName }
    $script:names=@{}; $script:controlCount=0
    foreach($entry in $document['Screens'][$screenName]['Children']) { Check-Control $entry }
    $indexes[$screenName]=$index
    if($LayoutOnly) { Write-Output "PASS $screenName : navigatie in vaste onderbalk; $script:controlCount controls gecontroleerd (zonder historische gedragsvergelijking)." }
    else { Write-Output "PASS $screenName : bestaande acties/validaties/Visible/DisplayMode behouden; navigatie in vaste onderbalk; $script:controlCount controls gecontroleerd." }
}
if($script:failures -gt 0) { throw 'Syntaxcontrole mislukt' }
Write-Output "PASS $script:formulas appformules zonder syntaxfouten."
function Eval-Position([string]$formula,$self,$rects,[double]$width,[double]$height) {
    $symbols=@('LayoutParent:{Width:'+$width+',Height:'+$height+'}')
    $symbols+=('LayoutSelf:{X:'+$self.X+',Y:'+$self.Y+',Width:'+$self.Width+',Height:'+$self.Height+'}')
    foreach($key in $rects.Keys) {
        $r=$rects[$key]
        $symbols+=($key+':{X:'+$r.X+',Y:'+$r.Y+',Width:'+$r.Width+',Height:'+$r.Height+'}')
    }
    $numericFormula=$formula.Trim().TrimStart('=').Replace('Parent.','LayoutParent.').Replace('Self.','LayoutSelf.')
    $expression='With({'+($symbols -join ',')+'},'+$numericFormula+')'
    try { $value=$evalEngine.Eval($expression,$null,$layoutOptions) }
    catch { throw ($expression + "`n" + $_.Exception.InnerException.InnerException.Message) }
    if($value -is [Microsoft.PowerFx.Types.ErrorValue]) { throw ($value.Errors | Out-String) }
    return [double]$value.Value
}
function Measure-Control([string]$controlName,$index,$rects,[double]$width,[double]$height) {
    $props=$index[$controlName].Node['Properties']
    $r=@{X=0;Y=0;Width=100;Height=40}
    for($pass=0;$pass -lt 3;$pass++) {
        foreach($prop in @('Width','Height','X','Y')) {
            if($props.ContainsKey($prop)) { $r[$prop]=Eval-Position $props[$prop] $r $rects $width $height }
        }
    }
    if($r.X -lt 0 -or $r.Y -lt 0 -or $r.Width -lt 0 -or $r.Height -lt 0 -or $r.X+$r.Width -gt $width+0.01 -or $r.Y+$r.Height -gt $height+0.01) { throw "Buiten scherm: $controlName bij $width x $height" }
    $rects[$controlName]=$r
}
function Gap($left,$right,[double]$gap) {
    if([Math]::Abs(($right.X-$left.X-$left.Width)-$gap) -gt 0.01 -or $left.Y -ne $right.Y) { throw 'Knopafstand of Y ongelijk' }
}
foreach($size in @(@(768,600),@(1024,768),@(1280,720),@(1366,768),@(1920,1080))) {
    $w=$size[0]; $h=$size[1]
    $rects=@{}; $idx=$indexes.Screen1
    foreach($name in @('navProjectTeam','lblProjectTeamTitle','conSelection','lblProject','lblTeam','ddProject','ddTeam','Label2','btnAddtoTeam','Gallery1')) { Measure-Control $name $idx $rects $w $h }
    if($idx.ContainsKey('lblSelectionLoadStatus')) { Measure-Control 'lblSelectionLoadStatus' $idx $rects $w $h; if($rects.lblSelectionLoadStatus.Y+$rects.lblSelectionLoadStatus.Height -gt $rects.Gallery1.Y) { throw 'Selectiestatus overlapt gallery' } }
    if($rects.Gallery1.Y+$rects.Gallery1.Height -gt $rects.Label2.Y-12+0.01 -or $rects.btnAddtoTeam.Y+$rects.btnAddtoTeam.Height -gt $rects.navProjectTeam.Y) { throw 'Projectinhoud onder navigatie' }
    foreach($name in @('btnGotoHours','btnGotoHoursSummary')) { Measure-Control $name $idx $rects $w 72 }
    Gap $rects.btnGotoHours $rects.btnGotoHoursSummary 12
    $rects=@{}; $idx=$indexes.scrHours
    foreach($name in @('navWeeklyHours','lblWeeklyHoursEntryTitle','lblISOYears','lblKW','ddHoursYear','ddHoursWeek','btnSaveWeek','galHours')) { Measure-Control $name $idx $rects $w $h }
    if($idx.ContainsKey('lblWeekLoadStatus')) { Measure-Control 'lblWeekLoadStatus' $idx $rects $w $h; if($rects.lblWeekLoadStatus.Y+$rects.lblWeekLoadStatus.Height -gt $rects.galHours.Y-50) { throw 'Weekstatus overlapt tabelkop' } }
    if($rects.galHours.Y+$rects.galHours.Height -gt $rects.navWeeklyHours.Y-12+0.01 -or $rects.btnSaveWeek.Y -lt 80) { throw 'Weekinvoer overlapt navigatie/titel' }
    Measure-Control 'btnWeeklyProjectTeam' $idx $rects $w 72
    $rects=@{}; $idx=$indexes.scrWeeklyHours
    foreach($name in @('navHoursSummary','lblWeeklyHoursTitle','lblSummaryPurpose','btnRefreshReport','lblReportProject','ddReportProject','lblReportContractor','ddReportContractor','lblReportProjectDetails','lblddReportStartYear','ddReportStartYear','lblddReportStartWeek','ddReportStartWeek','lblddReportEndYear','ddReportEndYear','lblddReportEndWeek','ddReportEndWeek','lblReportGrandTotal','galReportRows')) { Measure-Control $name $idx $rects $w $h }
    if($rects.galReportRows.Height -lt 44 -or $rects.galReportRows.Y+$rects.galReportRows.Height -gt $rects.lblReportGrandTotal.Y-12+0.01 -or $rects.lblReportGrandTotal.Y+$rects.lblReportGrandTotal.Height -gt $rects.navHoursSummary.Y-12+0.01) { throw 'Rapportinhoud overlapt totaal/navigatie' }
    if($rects.ddReportContractor.X+$rects.ddReportContractor.Width -gt $rects.btnRefreshReport.X-12+0.01) { throw 'Refresh overlapt rapportselecties' }
    Measure-Control 'btnSummaryProjectTeam' $idx $rects $w 72
    Write-Output "PASS layoutformules $w x $h : inhoud boven onderbalk, rapporttotaal vrij, navigatie past, Refresh vrij van selecties, 12 px knopafstand."
}
Write-Output 'Alleen lokale formule-/rechthoekcontroles: Studio-import, browserrendering, tekstpassing en echt scrollgedrag staan open.'
