# Home icons (3-11-2026): every icon named formula in App.pa.yaml must be literally equal to its source SVG in Assets\Icons
# (white for active tiles, grey for Soon tiles, white arrow), and every Home tile must use the icon of the README.txt mapping in the right variant.
# Source structure only: no Studio rendering of the data URIs is verified.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
function Assert-True($cond, $label) { if (!$cond) { throw "FAIL $label" }; Write-Output "PASS $label" }
$iconDir = Join-Path $projectRoot 'Assets\Icons'
$app = [IO.File]::ReadAllText((Join-Path $projectRoot 'Src\App.pa.yaml'))
$forms = @{}
# Grey (Soon) formulas = data-URI images; white (active, TP-HOME-03 item 5) = RAW SVG text, literally the file content (cmpTile builds the composite SVG).
foreach ($m in [regex]::Matches($app, '(?m)^\s+(Icon\w+Grey) = "data:image/svg\+xml;utf8," & EncodeUrl\("(.*)"\);\s*$')) { $forms[$m.Groups[1].Value] = $m.Groups[2].Value.Replace('""', '"') }
foreach ($m in [regex]::Matches($app, '(?m)^\s+(Icon\w+White) = "(<svg .*</svg>)";\s*$')) { $forms[$m.Groups[1].Value] = $m.Groups[2].Value.Replace('""', '"') }
Assert-True ($app -notmatch '(?m)^\s+Icon\w+White = "data:') 'white icon formulas are raw SVG text (no data: prefix, no EncodeUrl)'
# formula name -> source file (variant folder / file)
$map = [ordered]@{
    IconTeamWhite = 'white/icon-team'; IconWeeklyHoursWhite = 'white/icon-weekly-hours'; IconHoursSummaryWhite = 'white/icon-hours-summary'; IconContractorsWhite = 'white/icon-contractors'; IconProjectsWhite = 'white/icon-projects'; IconWorkersWhite = 'white/icon-workers'; IconArrowWhite = 'white/icon-arrow'
    IconWeekReportGrey = 'grey/icon-week-report'; IconStockOverviewGrey = 'grey/icon-stock-overview'; IconLocationsGrey = 'grey/icon-locations'; IconRequestsGrey = 'grey/icon-requests'
    Icon3dViewerGrey = 'grey/icon-3d-viewer'; IconPidTrackerGrey = 'grey/icon-pid-tracker'; IconComponentLibraryGrey = 'grey/icon-component-library'; IconKnowledgeBaseGrey = 'grey/icon-knowledge-base'
}
Assert-True ($forms.Count -eq $map.Count -and (($forms.Keys | Sort-Object) -join ',') -ceq (($map.Keys | Sort-Object) -join ',')) "App.Formulas has exactly the $($map.Count) icon formulas (7 white incl. arrow, 8 grey; Workers active since the Workers build 08-11-2026)"
foreach ($k in $map.Keys) {
    $file = Join-Path $iconDir (($map[$k] -replace '/', '\') + '.svg')
    $svg = ([IO.File]::ReadAllText($file)).Trim()
    Assert-True ($forms[$k] -ceq $svg) "$k is literally equal to Assets\Icons\$($map[$k] -replace '/','\').svg ($($svg.Length) chars)"
    Assert-True ($svg -notmatch "[\r\n]" -and $svg.StartsWith('<svg ') -and $svg.EndsWith('</svg>')) "$k : single-line SVG (no line break in the Power Fx string literal)"
    $stroke = if ($k -like '*White') { '#FFFFFF' } else { '#9B9B9B' }
    Assert-True ($svg.Contains('stroke="' + $stroke + '"')) "$k : stroke $stroke ($(if ($k -like '*White') { 'white variant' } else { 'grey variant' }))"
}
$tileIcon = [ordered]@{
    cmpTileProjectTeam = 'IconTeamWhite'; cmpTileWeeklyHours = 'IconWeeklyHoursWhite'; cmpTileHoursSummary = 'IconHoursSummaryWhite'; cmpTileWeekReport = 'IconWeekReportGrey'
    cmpTileContractors = 'IconContractorsWhite'; cmpTileProjects = 'IconProjectsWhite'; cmpTileWorkers = 'IconWorkersWhite'
    cmpTileStockOverview = 'IconStockOverviewGrey'; cmpTileLocations = 'IconLocationsGrey'; cmpTileRequests = 'IconRequestsGrey'
    cmpTileViewer3D = 'Icon3dViewerGrey'; cmpTilePIDTracker = 'IconPidTrackerGrey'; cmpTileComponentLibrary = 'IconComponentLibraryGrey'; cmpTileKnowledgeBase = 'IconKnowledgeBaseGrey'
}
$doc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src\scrHome.pa.yaml')))
$idx = @{}; function Index-H($entries) { foreach ($e in $entries) { $n = @($e.Keys)[0]; $idx[$n] = $e[$n]; Index-H $e[$n]['Children'] } }; Index-H $doc['Screens']['scrHome']['Children']
foreach ($t in $tileIcon.Keys) {
    $p = $idx[$t]['Properties']
    if ($p['Active'] -eq '=true') {
        Assert-True ($tileIcon[$t] -like '*White' -and $p['IconSvg'] -ceq ('=' + $tileIcon[$t]) -and $p['ArrowSvg'] -ceq '=IconArrowWhite' -and !$p.ContainsKey('Icon') -and !$p.ContainsKey('Arrow')) "$t : active tile passes IconSvg = $($tileIcon[$t]) ($($map[$tileIcon[$t]]).svg) + ArrowSvg = IconArrowWhite, no Icon/Arrow"
    } else {
        Assert-True ($tileIcon[$t] -like '*Grey' -and $p['Icon'] -ceq ('=' + $tileIcon[$t]) -and !$p.ContainsKey('ArrowSvg') -and !$p.ContainsKey('IconSvg') -and !$p.ContainsKey('Arrow')) "$t : Soon tile passes Icon = $($tileIcon[$t]) ($($map[$tileIcon[$t]]).svg), no ArrowSvg/IconSvg"
    }
}
$cmpTiles = @($idx.Keys | Where-Object { $idx[$_]['ComponentName'] -eq 'cmpTile' })
Assert-True ($cmpTiles.Count -eq $tileIcon.Count -and @($cmpTiles | Where-Object { -not $tileIcon.Contains($_) }).Count -eq 0) "scrHome has exactly the $($tileIcon.Count) mapped tiles (no Skid configurator, Usage or Employers tile)"
Write-Output 'Not verified locally: rendering of the data URIs and of the composite tile SVG (nested svg, Arial text) in Studio/browser, hover behaviour of the Image HoverFill.'
