$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$e=New-Object Microsoft.PowerFx.RecalcEngine
$options.AllowsSideEffects=$false
function Eval-Fx([string]$expression) {
    $value=$e.Eval($expression,$null,$options)
    if($value -is [Microsoft.PowerFx.Types.ErrorValue]) { throw ($value.Errors | Out-String) }
    return $value
}
function Assert-Equal($actual,$expected,[string]$label) {
    if($actual -ne $expected) { throw "$label : verwacht $expected, gevonden $actual" }
    Write-Output "PASS $label = $actual"
}
function Find-SummaryControl($entries,[string]$target) {
    foreach($entry in $entries) {
        $name=@($entry.Keys)[0]
        if($name -eq $target) { return $entry[$name] }
        $found=Find-SummaryControl $entry[$name]['Children'] $target
        if($found) { return $found }
    }
}
$controls=$yaml['Screens']['scrWeeklyHours']['Children']
$refresh=(Find-SummaryControl $controls 'btnLoadReport')['Properties']['OnSelect']
$build=(Find-SummaryControl $controls 'btnBuildReport')['Properties']['OnSelect']
if(!$refresh -or !$build) { throw 'Actuele OnSelect-formules ontbreken in de YAML-bron.' }
$kw=[regex]::Match($refresh,'KW:(1\+RoundDown\([^\r\n]+)').Groups[1].Value.TrimEnd(',')
foreach($case in @(@(2019,12,30,2020,1),@(2020,12,28,2020,53),@(2021,1,1,2020,53),@(2021,1,3,2020,53),@(2021,1,4,2021,1),@(2022,1,1,2021,52),@(2024,12,30,2025,1),@(2026,12,31,2026,53),@(2027,1,4,2027,1))) {
    $fx='With({workDay:Date('+($case[0..2] -join ',')+')},With({monday:DateAdd(workDay,1-Weekday(workDay,StartOfWeek.Monday),TimeUnit.Days)},With({isoYearValue:Year(DateAdd(monday,3,TimeUnit.Days))},{ISOYear:isoYearValue,KW:'+$kw+'})))'
    $value=Eval-Fx $fx
    Assert-Equal $value.GetField('ISOYear').Value $case[3] "ISO-jaar $($case[0..2] -join '-')"
    Assert-Equal $value.GetField('KW').Value $case[4] "ISO-week $($case[0..2] -join '-')"
}
# Van/Tot en met date pickers: normalization formulas are read from the actual OnChange sources.
$fromChange=(Find-SummaryControl $controls 'dpReportFrom')['Properties']['OnChange']
$untilChange=(Find-SummaryControl $controls 'dpReportUntil')['Properties']['OnChange']
$mondayFx=[regex]::Match($fromChange,'monday:(DateAdd\(selectedDay,[^}]+)\}').Groups[1].Value
$sundayFx=[regex]::Match($untilChange,'sunday:(DateAdd\(selectedDay,[^}]+)\}').Groups[1].Value
if(!$mondayFx -or !$sundayFx){ throw 'Normalisatieformules ontbreken in dpReportFrom/dpReportUntil.OnChange.' }
foreach($case in @(@('2026,10,21','2026,10,19'),@('2026,10,19','2026,10,19'),@('2026,12,31','2026,12,28'),@('2027,1,3','2026,12,28'),@('2021,1,1','2020,12,28'),@('2027,1,4','2027,1,4'))) {
    Assert-Equal (Eval-Fx ('Text(With({selectedDay:Date('+$case[0]+')},'+$mondayFx+'),"yyyy-mm-dd")')).Value (Eval-Fx ('Text(Date('+$case[1]+'),"yyyy-mm-dd")')).Value "Van $($case[0]) -> maandag"
}
foreach($case in @(@('2026,12,28','2027,1,3'),@('2027,1,3','2027,1,3'),@('2021,1,4','2021,1,10'),@('2026,10,21','2026,10,25'))) {
    Assert-Equal (Eval-Fx ('Text(With({selectedDay:Date('+$case[0]+')},'+$sundayFx+'),"yyyy-mm-dd")')).Value (Eval-Fx ('Text(Date('+$case[1]+'),"yyyy-mm-dd")')).Value "Tot en met $($case[0]) -> zondag"
}
foreach($needle in @('Set(varReportFrom,varReportStartMonday)','Set(varReportUntil,DateAdd(varReportEndSunday,1,TimeUnit.Days))','If(varReportFrom>=varReportUntil,')) {
    if(!$build.Contains($needle)) { throw "Rapportperiode in btnBuildReport wijkt af: $needle" }
}
Write-Output 'PASS rapport gebruikt Van-maandag t/m Tot en met-zondag (exclusief volgende maandag) en blokkeert eind vóór begin.'
foreach($case in @(@('2020,12,28','2021,1,3',1,$false),@('2020,12,21','2021,1,17',4,$false),@('2026,12,21','2027,1,10',3,$false),@('2026,10,19','2026,10,25',1,$false),@('2026,10,26','2026,10,25',0,$true))) {
    $fx='With({varReportFrom:Date('+$case[0]+'),varReportUntil:DateAdd(Date('+$case[1]+'),1,TimeUnit.Days)},{Weeks:DateDiff(varReportFrom,varReportUntil,TimeUnit.Days)/7,Blocked:varReportFrom>=varReportUntil})'
    $v=Eval-Fx $fx
    Assert-Equal $v.GetField('Blocked').Value $case[3] "Periode $($case[0]) t/m $($case[1]) geblokkeerd"
    if(!$case[3]) { Assert-Equal $v.GetField('Weeks').Value $case[2] "Aantal weken $($case[0]) t/m $($case[1])" }
}
# The separate ISO period line was removed on 21 Oct 2026; the ISO year/KW table headers show the period.
$facts='Table({WorkerID:1,ContractorID:10,WorkerName:"A",ContractorName:"Oud",HourValue:8,WorkDay:Date(2020,12,28)},{WorkerID:1,ContractorID:10,WorkerName:"A",ContractorName:"Oud",HourValue:7.5,WorkDay:Date(2021,1,3)},{WorkerID:1,ContractorID:20,WorkerName:"A",ContractorName:"Nieuw",HourValue:6,WorkDay:Date(2021,1,4)},{WorkerID:2,ContractorID:10,WorkerName:"B",ContractorName:"Oud",HourValue:4,WorkDay:Date(2021,1,5)})'
$selectedFilter=[regex]::Match($build,'(?s)Filter\(colReportFacts,.*?ddReportContractor.Selected.ID\)\)').Value
foreach($case in @(@(0,2021,1,11,25.5),@(10,2021,1,11,19.5),@(0,2021,1,4,15.5),@(20,2021,1,11,6))) {
    $fx='With({colReportFacts:'+$facts+',varReportFrom:Date(2020,12,28),varReportUntil:Date('+($case[1..3] -join ',')+'),ddReportContractor:{Selected:{ID:'+$case[0]+'}}},Sum('+$selectedFilter+',HourValue))'
    Assert-Equal (Eval-Fx $fx).Value $case[4] "Periode- en contractorfilter ID $($case[0]), einddatum $($case[1..3] -join '-')"
}
Write-Output 'GroupBy/AddColumns-binding is Canvas-specifiek en wordt in Studio gecontroleerd.'
Assert-Equal (Eval-Fx 'Coalesce(Sum(Filter(Table({HourValue:8}),false),HourValue),0)').Value 0 'Lege week toont nul'
foreach($count in @(499,500,501)) {
    Assert-Equal (Eval-Fx ('With({batch:Sequence('+$count+')},CountRows(batch)>=500)')).Value ($count -ge 500) "Batchbeveiliging $count regels"
}
$projectFixture='Table({Assignment:{Id:100},Hours:8},{Assignment:{Id:200},Hours:99},{Assignment:{Id:100},Hours:7.5})'
Assert-Equal (Eval-Fx ('With({Hours:'+$projectFixture+',member:{ID:100}},Sum(Filter(Hours,Assignment.Id=member.ID),Hours))')).Value 15.5 'Koppelingsfilter sluit andere projectkoppeling uit'
Write-Output 'Canvas GroupBy/AddColumns-binding en Text-taalplaceholders worden in Studio gecontroleerd; de losse interpreter ondersteunt deze niet volledig.'

# Weekly Hours week picker (22-10-2026): the real dpHoursWeek.OnChange with its actions replaced by text tags.
$hoursYaml=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrHours.pa.yaml')))
$hoursControls=$hoursYaml['Screens']['scrHours']['Children']
$picker=Find-SummaryControl $hoursControls 'dpHoursWeek'
$weekLabel=(Find-SummaryControl $hoursControls 'lblHoursWeekKW')['Properties']['Text'].TrimStart('=')
if(!$picker -or (Find-SummaryControl $hoursControls 'ddHoursYear') -or (Find-SummaryControl $hoursControls 'ddHoursWeek')){ throw 'dpHoursWeek ontbreekt of oude dropdowns staan er nog.' }
if($picker['Control'] -ne 'ModernDatePicker@1.0.2' -or $picker['Properties']['DefaultDate'] -ne '=Coalesce(varHoursPickedDay,Today())' -or $picker['Properties'].ContainsKey('StartDate') -or $picker['Properties'].ContainsKey('EndDate')){ throw 'dpHoursWeek instellingen' }
$change=$picker['Properties']['OnChange'].TrimStart('=')
$tagged=$change
foreach($pair in @(
 @('Set(varHoursPickedDay,selectedDay); Set(varHoursWeekMonday,monday); Select(btnReadWeek)','"LOAD"'),
 @('Set(varHoursPickedDay,selectedDay)','"PICK"'),
 @('Reset(dpHoursWeek); Notify("Week niet gewisseld: onopgeslagen uren behouden. Sla eerst op.",NotificationType.Warning,15000)','"RESET+NOTIFY"'),
 @('Reset(dpHoursWeek)','"RESET"'))){
 if(!$tagged.Contains($pair[0])){ throw "OnChange mist actie: $($pair[0])" }
 $tagged=$tagged.Replace($pair[0],$pair[1])
}
if($tagged -match '\b(Set|Select|Reset|Notify)\('){ throw 'Onverwachte actie in dpHoursWeek.OnChange' }
# 'Self' is reserved in the standalone interpreter; the fixture supplies the picker as pickerSelf.
$tagged=$tagged.Replace('Self.SelectedDate','pickerSelf.SelectedDate')
# The interpreter has no JSON(); the dirty check must be the exact same text as on btnRefreshWeek and is then supplied as a boolean.
$dirtyCheck='JSON(ShowColumns(colWeekRows,ID,MonHours,TueHours,WedHours,ThuHours,FriHours,SatHours,SunHours))<>JSON(ShowColumns(colWeekOriginal,ID,MonHours,TueHours,WedHours,ThuHours,FriHours,SatHours,SunHours))'
$refreshDm=(Find-SummaryControl $hoursControls 'btnRefreshWeek')['Properties']['DisplayMode']
if(!$tagged.Contains($dirtyCheck) -or !$refreshDm.Contains($dirtyCheck) -or !$picker['Properties']['DisplayMode'].Contains($dirtyCheck)){ throw 'Dirty check differs from the existing Weekly Hours check' }
$tagged=$tagged.Replace($dirtyCheck,'isDirty')
$clean='false'
$dirtyRows='true'
function Picker-Action($selected,$picked,$monday,$rows,$loading='false'){
 $fx='With({pickerSelf:{SelectedDate:'+$selected+'},varWeekLoading:'+$loading+',varWeekSaving:false,varHoursPickedDay:'+$picked+',varHoursWeekMonday:'+$monday+',isDirty:'+$rows+'},Coalesce('+$tagged+',"NONE"))'
 (Eval-Fx $fx).Value
}
Assert-Equal (Picker-Action 'Date(2026,10,22)' 'Date(2026,10,20)' 'Date(2026,10,19)' $clean) 'PICK' 'Weekkiezer: andere dag zelfde week laadt niet opnieuw'
Assert-Equal (Picker-Action 'Date(2026,10,20)' 'Date(2026,10,20)' 'Date(2026,10,19)' $clean) 'NONE' 'Weekkiezer: OnChange na Reset (zelfde dag) doet niets'
Assert-Equal (Picker-Action 'Date(2026,10,28)' 'Date(2026,10,20)' 'Date(2026,10,19)' $clean) 'LOAD' 'Weekkiezer: andere week laadt'
Assert-Equal (Picker-Action 'Date(2026,10,28)' 'Date(2026,10,20)' 'Date(2026,10,19)' $dirtyRows) 'RESET+NOTIFY' 'Weekkiezer: andere week met onopgeslagen uren wordt teruggezet, geen load'
Assert-Equal (Picker-Action 'Date(2026,10,22)' 'Date(2026,10,20)' 'Date(2026,10,19)' $dirtyRows) 'PICK' 'Weekkiezer: zelfde week met onopgeslagen uren alleen gekozen dag'
Assert-Equal (Picker-Action 'Date(2026,10,28)' 'Date(2026,10,20)' 'Date(2026,10,19)' $clean 'true') 'NONE' 'Weekkiezer: tijdens laden overgeslagen'
Assert-Equal (Picker-Action 'If(false,Date(2000,1,1))' 'Date(2026,10,20)' 'Date(2026,10,19)' $clean) 'RESET' 'Weekkiezer: leeg veld wordt teruggezet'
Assert-Equal (Picker-Action 'Date(2027,1,1)' 'Date(2026,12,20)' 'Date(2026,12,14)' $clean) 'LOAD' 'Weekkiezer: 01-01-2027 laadt week van maandag 28-12-2026'
$mondayOf=[regex]::Match($change,'monday:(DateAdd\(selectedDay,[^}]+)\}').Groups[1].Value
foreach($case in @(@('2027,1,1','2026,12,28'),@('2026,10,25','2026,10,19'),@('2021,1,3','2020,12,28'),@('2027,1,4','2027,1,4'))){
 Assert-Equal (Eval-Fx ('Text(With({selectedDay:Date('+$case[0]+')},'+$mondayOf+'),"yyyy-mm-dd")')).Value (Eval-Fx ('Text(Date('+$case[1]+'),"yyyy-mm-dd")')).Value "Weekkiezer $($case[0]) -> maandag"
}
# The local interpreter has no ISOWeekNum; substitute the Thursday rule (day count via hours, DST-safe) — validated in Test-SummaryDates.ps1.
$labelFx=[regex]::Replace($weekLabel,'ISOWeekNum\((\w+)\)','With({isoTh:DateAdd($1,4-Weekday($1,StartOfWeek.Monday),TimeUnit.Days)},RoundDown(Round(DateDiff(Date(Year(isoTh),1,1),isoTh,TimeUnit.Hours)/24,0)/7,0)+1)')
foreach($case in @(@('2026,12,28','2026 KW53'),@('2020,12,28','2020 KW53'),@('2024,12,30','2025 KW01'),@('2026,10,19','2026 KW43'),@('2027,1,4','2027 KW01'))){
 Assert-Equal (Eval-Fx ('With({varHoursWeekMonday:Date('+$case[0]+')},'+$labelFx+')')).Value $case[1] "Weeklabel maandag $($case[0])"
}
$hoursSrc=[IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrHours.pa.yaml'))
if($hoursSrc -match 'ddHours(Year|Week)|varEntry(First|Last)ISOYear|varEntryYearsLoaded'){ throw "Oude weekselectie nog aanwezig: $($Matches[0])" }
$read=(Find-SummaryControl $hoursControls 'btnReadWeek')['Properties']['OnSelect']
foreach($needle in @('Set(varPendingWeekMonday,varHoursWeekMonday);','varLoadedWeekMonday=varHoursWeekMonday && Coalesce(varWeekLoadedTeamVersion,-1)','Set(varWeekLoadedISOYear,Year(DateAdd(varPendingWeekMonday,3,TimeUnit.Days))); Set(varWeekLoadedKW,ISOWeekNum(varPendingWeekMonday));')){ if(!$read.Contains($needle)){ throw "btnReadWeek mist: $needle" } }
if($read -match 'Sort\(Hours'){ throw 'Jaarbereik-sortering op Hours nog aanwezig' }
Write-Output 'PASS Weekly Hours weekkiezer: echte OnChange; dezelfde week laadt niet opnieuw, OnChange na Reset is een no-op, onopgeslagen uren blokkeren wisselen; 01-01-2027 -> 2026 KW53; geen dropdowns of jaarbereik-queries meer; cache-hit en geladen ISO-jaar/KW afgeleid van de maandag.'
Write-Output 'Dit zijn lokale tests van Power Fx-berekeningen met synthetische gegevens; geen SharePoint- of Studio-tests.'

