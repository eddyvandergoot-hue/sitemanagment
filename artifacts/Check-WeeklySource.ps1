$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$pacDir = Split-Path (Get-Command pac).Source
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Reflection;
public static class WeeklyAssemblyResolver {
    public static string Directory;
    public static Assembly Resolve(object sender, ResolveEventArgs args) {
        string path = Path.Combine(Directory, new AssemblyName(args.Name).Name + ".dll");
        return File.Exists(path) ? Assembly.LoadFrom(path) : null;
    }
    public static void Install(string directory) {
        Directory = directory;
        AppDomain.CurrentDomain.AssemblyResolve += Resolve;
    }
}
'@
[WeeklyAssemblyResolver]::Install($pacDir)
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Core.dll')) | Out-Null
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'YamlDotNet.dll')) | Out-Null
$builder = New-Object YamlDotNet.Serialization.DeserializerBuilder
$yaml = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrWeeklyHours.pa.yaml')))
$options = New-Object Microsoft.PowerFx.ParserOptions
$options.AllowsSideEffects = $true
$options.Culture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
$engine = New-Object Microsoft.PowerFx.Engine
$script:formulas = 0
$script:failures = 0
function Check-Node($node,[string]$path) {
    if ($node -is [System.Collections.IDictionary]) {
        foreach($key in $node.Keys) { Check-Node $node[$key] "$path.$key" }
    } elseif ($node -is [System.Collections.IEnumerable] -and $node -isnot [string]) {
        $index=0
        foreach($item in $node) { Check-Node $item "$path[$index]"; $index++ }
    } elseif ($node -is [string] -and $node.StartsWith('=')) {
        $script:formulas++
        $result = $engine.Parse($node.Substring(1),$options)
        if (!$result.IsSuccess) {
            $script:failures++
            Write-Output $path
            $result.Errors | ForEach-Object ToString
        }
    }
}
Check-Node $yaml 'WeeklyHours'
Write-Output "Power Fx parser: $script:formulas formules, $script:failures met syntaxfouten."
if ($script:failures -gt 0) { throw 'Power Fx syntaxcontrole mislukt.' }
Write-Output 'Dit controleert syntaxis, niet Canvas-binding, delegatie of functioneel gedrag.'

# Structural subset of the downloaded official schema plus the app's control templates.
$schema = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'pa.schema.json')))
$controlPattern = $schema['definitions']['ControlTypeId-pattern']['pattern'].Trim()
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Join-Path $projectRoot 'Site Managment_VS.msapr'))
try {
    $reader = New-Object IO.StreamReader(($archive.Entries | Where-Object FullName -eq 'msapp\References\Templates.json').Open())
    $templates = ($reader.ReadToEnd() | ConvertFrom-Json).UsedTemplates
    $reader.Dispose()
    $reader = New-Object IO.StreamReader(($archive.Entries | Where-Object FullName -eq 'msapp\Properties.json').Open())
    $settings = $reader.ReadToEnd() | ConvertFrom-Json
    $reader.Dispose()
} finally { $archive.Dispose() }
if ($settings.DefaultConnectedDataSourceMaxGetRowsCount -ne 500 -or !$settings.AppPreviewFlagsMap.errorhandling) {
    throw 'Laadbeveiliging vereist datarijlimiet 500 en formulefoutafhandeling.'
}
$script:controlCount=0
$script:names=@{}
function Check-Control($entry,[bool]$autoLayoutChild=$false) {
    if ($entry.Count -ne 1) { throw 'Een control-entry moet exact één naam bevatten.' }
    $name = @($entry.Keys)[0]
    if ($script:names.ContainsKey($name)) { throw "Dubbele controlnaam: $name" }
    $script:names[$name]=$true
    $control = $entry[$name]
    if ($control['Control'] -eq 'Classic/Button@2.2.0' -and $control['Properties'].ContainsKey('AccessibleLabel')) {
        throw "PA2108: AccessibleLabel is ongeldig voor Classic/Button@2.2.0: $name"
    }
    foreach($key in $control.Keys) {
        if($key -notin @('Control','Variant','Properties','Children','Layout','Group','MetadataKey','IsLocked')) { throw "Ongeldig controlveld: $name.$key" }
    }
    if($control['Control'] -notmatch $controlPattern) { throw "Ongeldig controltype: $name" }
    $type,$version = $control['Control'] -split '@'
    $type = ($type -split '/')[-1].ToLowerInvariant()
    # Classic/TextInput is stored as 'text' in the original control templates.
    if($type -eq 'textinput') { $type='text' }
    if($control['Control'] -eq 'ModernDatePicker@1.0.0') {
        # Not in the original app templates; property list from the Microsoft Learn reference
        # (modern-control-date-picker, updated 2026-10-13). Studio import must confirm the template.
        $allowed = @('Placeholder','DefaultDate','Format','DateTimeZone','OnChange','IsEditable','StartDate','EndDate','StartOfWeek','ValidationState','PaddingTop','PaddingBottom','PaddingLeft','PaddingRight','Appearance','BasePaletteColor','Font','Size','Color','FontWeight','Italic','Underline','Strikethrough','Fill','BorderColor','BorderStyle','BorderThickness','RadiusTopLeft','RadiusTopRight','RadiusBottomLeft','RadiusBottomRight','AccessibleLabel','ContentLanguage')
    } else {
    $template = $templates | Where-Object { $_.Name -eq $type -and $_.Version -eq $version }
    if(!$template) { throw "Controlversie ontbreekt in bestaande templates: $name" }
    $allowed = @([regex]::Matches($template.Template,'<(?:\w+:)?(?:property|includeProperty)\b[^>]*\bname="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    }
    # Standard common properties are supplied by the Canvas base control.
    $allowed += @('X','Y','Width','Height','Visible','DisplayMode','TabIndex','Tooltip')
    # Fill portions is a documented child-layout property supplied by the
    # auto-layout parent, rather than by the original manual control template.
    if($autoLayoutChild) { $allowed += 'FillPortions' }
    foreach($property in $control['Properties'].Keys) {
        if($property -notin $allowed -and ($property -split '\.')[-1] -notin $allowed) { throw "Onbekende eigenschap: $name.$property" }
    }
    $script:controlCount++
    foreach($child in $control['Children']) { Check-Control $child ($control['Variant'] -eq 'AutoLayout') }
}
foreach($entry in $yaml['Screens']['scrWeeklyHours']['Children']) { Check-Control $entry }
$homeYaml = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrHome.pa.yaml')))
foreach($entry in $homeYaml['Screens']['scrHome']['Children']) { Check-Control $entry }
$contractorsYaml = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrContractors.pa.yaml')))
foreach($entry in $contractorsYaml['Screens']['scrContractors']['Children']) { Check-Control $entry }
# Projects build (30-10-2026): admin screen scrProjects, same templates as scrContractors.
$projectsYaml = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/scrProjects.pa.yaml')))
foreach($entry in $projectsYaml['Screens']['scrProjects']['Children']) { Check-Control $entry }
Write-Output "Structuur en bestaande templates: $script:controlCount controls gecontroleerd; rijlimiet 500 en errorhandling bevestigd."
# 26-10-2026: every Icon.<Name> in Src must exist in the Classic/Icon 2.5.0 template enum of the .msapr (read-only).
$iconTemplate = $templates | Where-Object { $_.Name -eq 'icon' -and $_.Version -eq '2.5.0' }
if(!$iconTemplate) { throw 'Classic/Icon 2.5.0-template ontbreekt in Templates.json.' }
$iconEnum = @([regex]::Matches($iconTemplate.Template,'Icon\.RESERVED%\.(\w+)') | ForEach-Object { $_.Groups[1].Value })
$iconFold = [regex]::Match($iconTemplate.Template,'foldVariants="([^"]+)"')
if($iconFold.Success) { $iconEnum += $iconFold.Groups[1].Value.Split('|') }
$iconEnum = @($iconEnum | Sort-Object -Unique)
if($iconEnum.Count -lt 100) { throw "Icon-enumlijst niet gevonden in template ($($iconEnum.Count) namen)." }
$iconUses = 0
foreach($srcFile in Get-ChildItem (Join-Path $projectRoot 'Src') -Filter '*.pa.yaml') {
    foreach($iconMatch in [regex]::Matches([IO.File]::ReadAllText($srcFile.FullName),'(?<![\w.%])Icon\.(\w+)')) {
        $iconUses++
        if($iconMatch.Groups[1].Value -cnotin $iconEnum) { throw "Onbekende Icon-naam in $($srcFile.Name): Icon.$($iconMatch.Groups[1].Value)" }
    }
}
if($iconUses -eq 0) { throw 'Geen Icon.<Naam>-verwijzingen gevonden in Src.' }
Write-Output "Icon-namen: $iconUses verwijzingen in Src bestaan in de Classic/Icon 2.5.0-enum ($($iconEnum.Count) namen)."
