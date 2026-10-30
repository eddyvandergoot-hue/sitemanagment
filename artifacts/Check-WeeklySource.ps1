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
# Canvas component definitions (App components) live in Src\Component (docs: power-apps-yaml "File structure"); one file per component.
$script:componentDefs=@{}
$componentDir=Join-Path $projectRoot 'Src\Component'
$componentDocs=@{}
if(Test-Path $componentDir) {
    foreach($componentFile in Get-ChildItem $componentDir -Filter '*.pa.yaml') {
        $componentDoc = $builder.Build().Deserialize([IO.File]::ReadAllText($componentFile.FullName))
        foreach($docKey in $componentDoc.Keys) { if($docKey -ne 'ComponentDefinitions') { throw "Componentbestand $($componentFile.Name): onverwachte topniveausleutel $docKey" } }
        foreach($componentName in $componentDoc['ComponentDefinitions'].Keys) {
            if($componentName -ne ($componentFile.Name -replace '\.pa\.yaml$','')) { throw "Componentbestand $($componentFile.Name) moet precies de component met dezelfde naam bevatten." }
            $script:componentDefs[$componentName] = $componentDoc['ComponentDefinitions'][$componentName]
        }
        $componentDocs[$componentFile.Name] = $componentDoc
    }
}
function Check-Control($entry,[bool]$autoLayoutChild=$false) {
    if ($entry.Count -ne 1) { throw 'Een control-entry moet exact één naam bevatten.' }
    $name = @($entry.Keys)[0]
    if ($script:names.ContainsKey($name)) { throw "Dubbele controlnaam: $name" }
    $script:names[$name]=$true
    $control = $entry[$name]
    if ($control['Control'] -eq 'CanvasComponent') {
        # Canvas component instance (schema pa.schema.yaml v3.0, Control-instance): ComponentName required, no Variant/Children.
        foreach($key in $control.Keys) {
            if($key -notin @('Control','ComponentName','ComponentLibraryUniqueName','Group','Properties')) { throw "Ongeldig veld voor CanvasComponent-instantie: $name.$key" }
        }
        $def = $script:componentDefs[[string]$control['ComponentName']]
        if(!$def) { throw "CanvasComponent-instantie $name verwijst naar onbekende ComponentName '$($control['ComponentName'])'." }
        $instanceAllowed = @('X','Y','Width','Height','Visible','Fill','ContentLanguage','ChildTabPriority','EnableChildFocus')
        foreach($cp in $def['CustomProperties'].Keys) { if($def['CustomProperties'][$cp]['PropertyKind'] -in @('Input','Event','InputFunction')) { $instanceAllowed += $cp } }
        foreach($property in $control['Properties'].Keys) {
            if($property -notin $instanceAllowed) { throw "Onbekende of niet-instelbare eigenschap op CanvasComponent-instantie: $name.$property" }
        }
        $script:controlCount++
        return
    }
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
    if($control['Control'] -eq 'ModernDatePicker@1.0.0') { throw "ModernDatePicker@1.0.0 is older than the template in the .msapr (1.0.2; Studio warning PA2105): $name" }
    if($control['Control'] -eq 'ModernDatePicker@1.0.2') {
        # Template 1.0.2 is in the .msapr (Studio rewrote 1.0.0 -> 1.0.2, PA2105 on 30-10-2026); the modern template lists
        # only its own properties, common ones come from the Microsoft Learn reference (modern-control-date-picker).
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
# Every screen file: validate all CanvasComponent instances (also in screens that Check-Control does not walk completely).
function Check-Instances($entries, $where) {
    foreach($entry in $entries) {
        $iname = @($entry.Keys)[0]; $ictl = $entry[$iname]
        if($ictl['Control'] -eq 'CanvasComponent') {
            $saved = $script:names; $script:names = @{}; $savedCount = $script:controlCount
            Check-Control ([ordered]@{ $iname = $ictl }); $script:names = $saved; $script:controlCount = $savedCount
        }
        if($ictl['Children']) { Check-Instances $ictl['Children'] $where }
    }
}
$instanceScreens = 0
foreach($screenFile in Get-ChildItem (Join-Path $projectRoot 'Src') -Filter '*.pa.yaml') {
    if($screenFile.Name -like '_*') { continue }
    $screenDoc = $builder.Build().Deserialize([IO.File]::ReadAllText($screenFile.FullName))
    foreach($screenName in $screenDoc['Screens'].Keys) { Check-Instances $screenDoc['Screens'][$screenName]['Children'] $screenFile.Name; $instanceScreens++ }
}
Write-Output "Component-instanties: $instanceScreens schermen gecontroleerd op CanvasComponent-instanties."
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
foreach($srcFile in Get-ChildItem (Join-Path $projectRoot 'Src') -Filter '*.pa.yaml' -Recurse) {
    foreach($iconMatch in [regex]::Matches([IO.File]::ReadAllText($srcFile.FullName),'(?<![\w.%])Icon\.(\w+)')) {
        $iconUses++
        if($iconMatch.Groups[1].Value -cnotin $iconEnum) { throw "Onbekende Icon-naam in $($srcFile.Name): Icon.$($iconMatch.Groups[1].Value)" }
    }
}
if($iconUses -eq 0) { throw 'Geen Icon.<Naam>-verwijzingen gevonden in Src.' }
Write-Output "Icon-namen: $iconUses verwijzingen in Src bestaan in de Classic/Icon 2.5.0-enum ($($iconEnum.Count) namen)."
# Canvas component definitions (Src\Component): schema subset of pa.schema.yaml v3.0 (ComponentDefinition-instance, ComponentDefinition-CustomProperty) plus control templates.
$pfxDataTypes=@('Text','Number','Boolean','DateAndTime','Screen','Record','Table','Image','VideoOrAudio','Color','Currency')
$propertyKinds=@('Input','Output','InputFunction','OutputFunction','Event','Action')
$componentChecked=0
$editorState=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $projectRoot 'Src/_EditorState.pa.yaml')))
$orderList=@($editorState['EditorState']['ComponentDefinitionsOrder'] | ForEach-Object { [string]$_ } | Sort-Object)
$fileList=@($componentDocs.Keys | ForEach-Object { $_ -replace '\.pa\.yaml$','' } | Sort-Object)
if(($orderList -join ',') -ne ($fileList -join ',')) { throw "_EditorState ComponentDefinitionsOrder ($($orderList -join ',')) is niet gelijk aan de bestanden in Src\Component ($($fileList -join ','))." }
foreach($componentFileName in $componentDocs.Keys) {
    $componentDoc=$componentDocs[$componentFileName]
    $script:formulas=0; $script:failures=0
    Check-Node $componentDoc "Component.$componentFileName"
    if($script:failures -gt 0) { throw "Power Fx syntaxcontrole mislukt in componentbestand $componentFileName." }
    foreach($componentName in $componentDoc['ComponentDefinitions'].Keys) {
        $def=$componentDoc['ComponentDefinitions'][$componentName]
        if($def['DefinitionType'] -ne 'CanvasComponent') { throw "$componentName : DefinitionType moet CanvasComponent zijn." }
        foreach($key in $def.Keys) { if($key -notin @('DefinitionType','Description','AllowCustomization','AccessAppScope','CustomProperties','Properties','Children')) { throw "$componentName : ongeldig veld $key" } }
        $behaviourNames=@($def['CustomProperties'].Keys | Where-Object { $def['CustomProperties'][$_]['PropertyKind'] -in @('Output','OutputFunction','Action') })
        $fixedProps=@('Fill','Height','Width','OnReset','ContentLanguage','ChildTabPriority','EnableChildFocus')
        foreach($propName in $def['Properties'].Keys) {
            if($propName -in @('X','Y','Visible')) { throw "$componentName : Properties mag $propName niet bevatten (gereserveerd in het schema)." }
            if($propName -notin $fixedProps -and $propName -notin $behaviourNames) { throw "$componentName.$propName : Properties mag alleen $($fixedProps -join '/') en de namen van Output/OutputFunction/Action bevatten." }
            if(([string]$def['Properties'][$propName]) -notmatch '^=') { throw "$componentName.$propName : formule moet met = beginnen." }
        }
        foreach($cpName in $def['CustomProperties'].Keys) {
            $cp=$def['CustomProperties'][$cpName]
            $kind=$cp['PropertyKind']
            if($kind -notin $propertyKinds) { throw "$componentName.$cpName : ongeldige PropertyKind $kind" }
            if($kind -eq 'Input') {
                if($cp['DataType'] -notin $pfxDataTypes) { throw "$componentName.$cpName : DataType '$($cp['DataType'])' is niet geldig in het schema." }
                foreach($key in $cp.Keys) { if($key -notin @('PropertyKind','DisplayName','Description','DataType','RaiseOnReset','Default')) { throw "$componentName.$cpName : ongeldig veld $key voor Input" } }
            } elseif($kind -eq 'Output') {
                if($cp['DataType'] -notin $pfxDataTypes) { throw "$componentName.$cpName : DataType '$($cp['DataType'])' is niet geldig in het schema." }
                foreach($key in $cp.Keys) { if($key -notin @('PropertyKind','DisplayName','Description','DataType')) { throw "$componentName.$cpName : ongeldig veld $key voor Output" } }
                if(!$def['Properties'].ContainsKey($cpName) -or ([string]$def['Properties'][$cpName]) -notmatch '^=') { throw "$componentName.$cpName : Output moet een formule in Properties hebben." }
            } else {
                if(!$cp.ContainsKey('ReturnType')) { throw "$componentName.$cpName : ReturnType is verplicht voor $kind." }
                if($cp['ReturnType'] -ne 'None' -and $cp['ReturnType'] -notin $pfxDataTypes) { throw "$componentName.$cpName : ongeldig ReturnType $($cp['ReturnType'])" }
                $okKeys=@('PropertyKind','DisplayName','Description','ReturnType','Parameters')
                if($kind -in @('Event','InputFunction')) { $okKeys+='Default' }
                foreach($key in $cp.Keys) { if($key -notin $okKeys) { throw "$componentName.$cpName : ongeldig veld $key voor $kind" } }
                # AGENTS (Studio import failure D7, 30-10-2026): no event parameters on component properties.
                if($cp.ContainsKey('Parameters')) { throw "$componentName.$cpName : Parameters zijn niet toegestaan (geen event-parameters; Studio-import faalde)." }
            }
            if($cp.ContainsKey('Default') -and ([string]$cp['Default']) -notmatch '^=') { throw "$componentName.$cpName : Default moet met = beginnen." }
        }
        foreach($entry in $def['Children']) { Check-Control $entry }
        $componentChecked++
    }
}
Write-Output "Canvas-componenten: $componentChecked definitie(s) in Src\Component gecontroleerd (DefinitionType, CustomProperties/PropertyKind/DataType, Power Fx-syntaxis, kinderen tegen Templates.json); HtmlViewer@2.1.0 en ModernSpinner@1.1.0 komen uit de templates."
