$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
$backup=Join-Path $projectRoot (Get-Content (Join-Path $PSScriptRoot 'read-existing-backup.txt') -Raw -Encoding UTF8).Trim()
function Index-ReadControls($entries,$out) {
    foreach($entry in $entries) { $name=@($entry.Keys)[0]; $out[$name]=$entry[$name]; Index-ReadControls $entry[$name]['Children'] $out }
}
$currentIndexes=@{}
$totalControls=0
foreach($screenName in @('Screen1','scrHours','scrWeeklyHours')) {
    $document=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot ('Src/'+$screenName+'.pa.yaml'))))
    $index=@{}; Index-ReadControls $document['Screens'][$screenName]['Children'] $index
    $currentIndexes[$screenName]=$index
    if($screenName -ne 'scrWeeklyHours') { Check-Node $document $screenName }
    $script:names=@{}; $script:controlCount=0
    foreach($entry in $document['Screens'][$screenName]['Children']) { Check-Control $entry }
    $totalControls+=$script:controlCount
}
$app=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/App.pa.yaml')))
Check-Node $app 'App'
if($script:failures -gt 0) { throw 'Syntaxcontrole mislukt' }
Write-Output "PASS $script:formulas appformules zonder syntaxfouten; $totalControls controls tegen structuur/templates gecontroleerd."
foreach($pair in @(@('Screen1','btnAddtoTeam'),@('scrHours','btnSaveWeek'))) {
    $oldDoc=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $backup ($pair[0]+'.pa.yaml'))))
    $oldIndex=@{}; Index-ReadControls $oldDoc['Screens'][$pair[0]]['Children'] $oldIndex
    if($oldIndex[$pair[1]]['Properties']['OnSelect'] -cne ($currentIndexes[$pair[0]][$pair[1]]['Properties']['OnSelect'].Replace('Set(varDataEpoch,Coalesce(varDataEpoch,0)+1); Clear(colWeekCache); Clear(colReportCache);',''))) { throw 'Bestaande expliciete opslagactie gewijzigd' }
}
Write-Output 'PASS bestaande expliciete Save/Save team-opslagkern exact behouden; uitsluitend cache-invalidering vooraf toegevoegd.'
foreach($pair in @(@('Screen1','btnReadTeam'),@('scrHours','btnReadWeek'),@('scrWeeklyHours','btnLoadReport'),@('scrWeeklyHours','btnRefreshReport'),@('scrWeeklyHours','btnBuildReport'))) {
    $formula=$currentIndexes[$pair[0]][$pair[1]]['Properties']['OnSelect']
    if($formula -match '\b(Patch|Remove|RemoveIf|Update|UpdateIf|SubmitForm)\s*\(') { throw "Mutatie in laadactie: $($pair[1])" }
    foreach($match in [regex]::Matches($formula,'\b(?:Collect|ClearCollect|Clear)\s*\(\s*([^,)]+)')) {
        if($match.Groups[1].Value.Trim() -notmatch '^col[A-Za-z0-9_]+$') { throw 'Collectieactie op externe bron' }
    }
}
Write-Output 'PASS vijf laad-/rapportacties bevatten geen Patch/Update/Remove/SubmitForm; Collect/Clear gebruiken uitsluitend col-collections.'
if($app['App']['Properties']['StartScreen'] -ne '=Screen1') { throw 'Koude start niet op project/team' }
if($app['App']['Properties']['OnStart'] -match '\b(Patch|Collect|ClearCollect|Remove|Update|SubmitForm)\s*\(') { throw 'Datamutatie tijdens App.OnStart' }
$week=$currentIndexes.scrHours['btnReadWeek']['Properties']['OnSelect']
$team=$currentIndexes.Screen1['btnReadTeam']['Properties']['OnSelect']
if($week -notmatch 'Filter\(''Project Workers'',Project.Id=varHoursProjectID' -or $team -notmatch 'Filter\(''Project Workers'',Project.Id=varSelectionProjectID') { throw 'Projectlookupfilter ontbreekt' }
if($week -notmatch 'Filter\(Hours,Assignment.Id=assignmentID' -or $week -notmatch 'MonKey:Coalesce\(mon.EntryKey,member.MonKey\)') { throw 'Dagregels of bestaande sleutels niet behouden' }
Write-Output 'PASS koude start, projectlookupfilters, dagregelophaling en behoud bestaande EntryKey aanwezig in actuele bron.'

# Local synthetic calculations only; no connector access or fixture writes.
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$readEngine=New-Object Microsoft.PowerFx.RecalcEngine
$readOptions=New-Object Microsoft.PowerFx.ParserOptions
$readOptions.Culture=[Globalization.CultureInfo]::GetCultureInfo('en-US')
function Expect-Read([string]$formula,$expected,[string]$label) {
    $value=$readEngine.Eval($formula,$null,$readOptions)
    if($value -is [Microsoft.PowerFx.Types.ErrorValue] -or $value.Value -ne $expected) { throw "Referentie mislukt: $label" }
    Write-Output "PASS $label = $expected"
}
Expect-Read 'With({varSelectionProjectID:7,varSelectionTeam:"2",''Project Workers'':Table({Project:{Id:7},ProjectKey:"",Team:{Value:"2"},Active:true},{Project:{Id:8},ProjectKey:"7",Team:{Value:"2"},Active:true},{Project:{Id:7},ProjectKey:"7",Team:{Value:"3"},Active:true},{Project:{Id:7},ProjectKey:"7",Team:{Value:"2"},Active:false})},CountRows(Filter(''Project Workers'',Project.Id=varSelectionProjectID && Team.Value=varSelectionTeam && Active=true)))' 1 'Correct project/team ondanks lege ProjectKey; andere projecten/teams/inactieve koppelingen uitgesloten'
Expect-Read 'With({assignmentID:12,dateFrom:Date(2020,12,28),dateUntil:Date(2021,1,4),Hours:Table({Assignment:{Id:12},''Work Date'':Date(2020,12,28),EntryKey:"bestaande-sleutel",Hours:8},{Assignment:{Id:13},''Work Date'':Date(2020,12,28),EntryKey:"andere",Hours:99},{Assignment:{Id:12},''Work Date'':Date(2021,1,4),EntryKey:"volgende-week",Hours:99})},Sum(Filter(Hours,Assignment.Id=assignmentID && ''Work Date''>=dateFrom && ''Work Date''<dateUntil),Hours))' 8 'Week 53 over jaargrens leest juiste assignment/dag, onafhankelijk van sleuteltekst'
Expect-Read 'With({mon:{EntryKey:"bestaande-sleutel"},member:{MonKey:"nieuwe-berekening"}},Coalesce(mon.EntryKey,member.MonKey))' 'bestaande-sleutel' 'Opgeslagen EntryKey heeft voorrang'
Expect-Read 'With({varEntryFirstISOYear:2010,varEntryLastISOYear:2026},Min(Year(Today())-5,varEntryFirstISOYear))' 2010 'Ouder opgeslagen ISO-jaar blijft selecteerbaar'
Write-Output 'LIVE CONTROLES OPEN: connectorauthenticatie, gebruikersrechten, werkelijke lijstinhoud, serverdelegatie en Studio-import zijn niet uitgevoerd.'

