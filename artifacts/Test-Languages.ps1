# Test-Languages.ps1 - language consistency (Eddy 14-11-2026; DECISIONS.md H27, H29, MS-035; MANUAL_STEPS "Nieuwe taal").
# Workers.Language, Employers.Language (report language) and Translations.Language must be choice columns with the same
# six spellings: Dutch, English, Polish, Romanian, German, Ukrainian. Checks the metadata in Site Managment_VS.msapr
# (column type IsChoice, filter eq), the repo CSV templates/translations-weekreport.csv and the language-code mapping in Src.
# LIMIT: the .msapr metadata does not contain the choice VALUES of a SharePoint choice column (verified 14-11-2026), so equal
# spelling of the choice lists themselves can only be checked online (MANUAL_STEPS procedure). ASCII-only, PowerShell 5.1.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$fails = 0
function Check($cond, $label) { if ($cond) { Write-Output "PASS $label" } else { Write-Output "FAIL $label"; $script:fails++ } }
$languages = @('Dutch', 'English', 'Polish', 'Romanian', 'German', 'Ukrainian')

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $projectRoot 'Site Managment_VS.msapr'))
try {
    $entry = $zip.Entries | Where-Object FullName -eq 'msapp\References\DataSources.json'
    $sr = New-Object IO.StreamReader($entry.Open()); $dsRaw = $sr.ReadToEnd(); $sr.Close()
} finally { $zip.Dispose() }
$ds = $dsRaw | ConvertFrom-Json
foreach ($list in 'Workers', 'Employers', 'Translations') {
    $d = $ds.DataSources | Where-Object Name -eq $list
    Check ($null -ne $d) "metadata: list $list present"
    if ($null -eq $d) { continue }
    $s = $d | ConvertTo-Json -Depth 80 -Compress
    $m = [regex]::Match($s, '\\"Language\\":\{\\"title\\":\\"([^\\]*)\\",\\"type\\":\\"(\w+)\\"(.{0,400})')
    Check $m.Success "metadata: $list has column Language (internal name)"
    if (-not $m.Success) { continue }
    Check ($m.Groups[1].Value -eq 'Language') "metadata: $list.Language display name = Language (found '$($m.Groups[1].Value)')"
    Check ($m.Groups[3].Value -match 'IsChoice\\":true') "metadata: $list.Language is a choice column (found type '$($m.Groups[2].Value)'; a text column means the .msapr metadata is not refreshed: Studio Data > $list > Refresh, save to Incoming, merge)"
}

$csv = [IO.File]::ReadAllLines((Join-Path $projectRoot 'templates\translations-weekreport.csv'), [Text.Encoding]::UTF8) | Select-Object -Skip 1 | Where-Object { $_.Trim() }
$csvLangs = @($csv | ForEach-Object { $_.Split(';')[1] } | Sort-Object -Unique)
Check ((($csvLangs | Sort-Object) -join ',') -ceq (($languages | Sort-Object) -join ',')) "translations CSV: exactly the six spellings, case-sensitive, no spaces ($($csvLangs -join ', '))"
$bad = @($csv | Where-Object { $p = $_.Split(';'); $p[1] -cne $p[1].Trim() })
Check ($bad.Count -eq 0) 'translations CSV: no leading/trailing spaces in Language'

$wr = [IO.File]::ReadAllText((Join-Path $projectRoot 'Src\scrWeekReport.pa.yaml'))
$sw = [regex]::Match($wr, 'Switch\(pg\.L,("Dutch","nl","English","en","Polish","pl","Romanian","ro","German","de","Ukrainian","uk"),"und"\)')
Check $sw.Success 'Src: lang-code mapping covers exactly the six languages (unknown = und)'
Check ($wr.Contains('Filter(Translations,Language.Value=varWrDocQ1)') -and $wr -notmatch 'Filter\(Translations,Language=') 'Src: Translations read on the choice value (Language.Value = global variable, delegable)'

Write-Output 'NOT verified locally: the choice values of Workers.Language, Employers.Language and Translations.Language in SharePoint (not in the .msapr metadata); use the MANUAL_STEPS procedure "Nieuwe taal" and compare the three lists online.'
if ($fails -gt 0) { Write-Output "Test-Languages: $fails FAIL"; exit 1 }
Write-Output 'Test-Languages: all PASS'
