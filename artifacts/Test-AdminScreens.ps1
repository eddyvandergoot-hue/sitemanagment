# Static checks for the admin screens (ADMIN_PLAN.md par. 6). Build 1: Contractors (scrContractors, list Employers); build 2: Projects (scrProjects, list Projects, section at the end).
# Proves source structure only: no Studio import, Canvas binding, delegation (Monitor) or functional result.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
. (Join-Path $PSScriptRoot 'RefreshOrder.ps1')
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'Microsoft.PowerFx.Interpreter.dll')) | Out-Null
$adminEngine = New-Object Microsoft.PowerFx.RecalcEngine
$adminOptions = New-Object Microsoft.PowerFx.ParserOptions
$adminOptions.Culture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
$adminOptions.AllowsSideEffects = $true
function Assert-True($cond, $label) { if (!$cond) { throw "FAIL $label" }; Write-Output "PASS $label" }
function Assert-Eval([string]$fx, $expected, [string]$label) {
    try { $v = $adminEngine.Eval($fx, $null, $adminOptions) } catch { Write-Output $_.Exception.ToString(); throw "FAIL $label (evaluation error)" }
    if ($v -is [Microsoft.PowerFx.Types.ErrorValue] -or $v.Value -ne $expected) { throw "FAIL $label : $($v.ToExpression())" }
    Write-Output "PASS $label"
}
function Get-Balanced([string]$text, [int]$start) {
    # $start = index of the opening parenthesis; returns the text up to and including the matching ')'
    $depth = 0; $inS = $false
    for ($j = $start; $j -lt $text.Length; $j++) {
        $ch = $text[$j]
        if ($ch -eq '"') { $inS = -not $inS; continue }
        if ($inS) { continue }
        if ($ch -eq '(') { $depth++ } elseif ($ch -eq ')') { $depth--; if ($depth -eq 0) { return $text.Substring($start, $j - $start + 1) } }
    }
    throw "FAIL unbalanced expression at $start"
}
function Split-Args([string]$inner) {
    # top-level comma split of a function argument list (without the outer parentheses)
    $out = @(); $depth = 0; $inS = $false; $last = 0
    for ($j = 0; $j -lt $inner.Length; $j++) {
        $ch = $inner[$j]
        if ($ch -eq '"') { $inS = -not $inS; continue }
        if ($inS) { continue }
        if ($ch -in @('(', '{', '[')) { $depth++ } elseif ($ch -in @(')', '}', ']')) { $depth-- }
        elseif ($ch -eq ',' -and $depth -eq 0) { $out += $inner.Substring($last, $j - $last); $last = $j + 1 }
    }
    $out += $inner.Substring($last)
    return , $out
}
function Index-Controls($entries, $index) { foreach ($entry in $entries) { $name = @($entry.Keys)[0]; $index[$name] = $entry[$name]; Index-Controls $entry[$name]['Children'] $index } }
function Norm([string]$s) { return ($s -replace '\s+', '') }

$srcDir = Join-Path $projectRoot 'Src'
$screenName = 'scrContractors'
$doc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir "$screenName.pa.yaml")))
$appDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'App.pa.yaml')))
$script:formulas = 0; $script:failures = 0
Check-Node $doc $screenName; Check-Node $appDoc 'App'
if ($script:failures -gt 0) { throw 'FAIL Power Fx syntax in scrContractors/App' }
Assert-True $true "Power Fx syntax: $script:formulas formulas in scrContractors + App parsed"
$script:names = @{}; $script:controlCount = 0
foreach ($entry in $doc['Screens'][$screenName]['Children']) { Check-Control $entry }
Assert-True ($script:controlCount -gt 0) "Control templates/properties valid ($script:controlCount controls)"
$idx = @{}; Index-Controls $doc['Screens'][$screenName]['Children'] $idx
$screenProps = $doc['Screens'][$screenName]['Properties']
function Get-Prop([string]$ctl, [string]$prop) { $v = $idx[$ctl]['Properties'][$prop]; if ($null -eq $v) { throw "FAIL missing $ctl.$prop" }; return ([string]$v).Trim() }
$all = @{}
foreach ($n in $idx.Keys) { foreach ($p in $idx[$n]['Properties'].Keys) { $all["$n.$p"] = ([string]$idx[$n]['Properties'][$p]) } }
foreach ($p in $screenProps.Keys) { $all["$screenName.$p"] = [string]$screenProps[$p] }
$screenText = ($all.Values) -join "`n"
$srcAll = (Get-ChildItem $srcDir -Filter *.pa.yaml | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
# --- Step 3a (30-10-2026): footer, list card, title bar, message bar and form fields are component instances. -----------------------------
# (1a) Guard parity per instance, checked on the real properties: <Xxx>Enabled is textually the first If-condition of On<Xxx>.
# (1b) Compatibility layer: the behavioural checks below keep their historical control names (btnEmpSave.OnSelect, btnEmpSave.DisplayMode,
#      galEmpList.OnSelect/DisplayMode, ...). They now read the same formula text from the instance properties, so every check still tests
#      the formula that the screen really contains (DisplayMode is synthesized as If(<Enabled>,Edit,Disabled) from the Boolean input).
$cmpFooterMap = [ordered]@{ btnEmpHome = 'Home'; btnEmpNew = 'New'; btnEmpRefresh = 'Refresh'; btnEmpDiscard = 'Discard'; btnEmpSave = 'Save' }
$inst = $doc['Screens'][$screenName]['Children'] | Where-Object { @($_.Keys)[0] -eq 'cmpEmpFooter' }
Assert-True ($null -ne $inst -and $idx['cmpEmpFooter']['Control'] -eq 'CanvasComponent' -and $idx['cmpEmpFooter']['ComponentName'] -eq 'cmpFooter') 'Footer = cmpFooter instance (cmpEmpFooter)'
foreach ($k in $cmpFooterMap.Keys) {
    $v = $cmpFooterMap[$k]; $en = ([string]$all["cmpEmpFooter.${v}Enabled"]).Trim(); $os = ([string]$all["cmpEmpFooter.On$v"]).Trim()
    Assert-True ($en.StartsWith('=') -and $en.Length -gt 3) "cmpEmpFooter.${v}Enabled is a Boolean expression"
    $g = $en.Substring(1)
    Assert-True ($os.StartsWith('=If(' + $g + ',')) "cmpEmpFooter.On$v starts with the same guard text as ${v}Enabled (fail-closed: guard in the input and as first condition in the handler)"
    $all["$k.OnSelect"] = $all["cmpEmpFooter.On$v"]; $all["$k.DisplayMode"] = '=If(' + $g + ',DisplayMode.Edit,DisplayMode.Disabled)'
    $all.Remove("cmpEmpFooter.On$v"); $all.Remove("cmpEmpFooter.${v}Enabled")
}
$lcEn = ([string]$all['cmpEmpList.Enabled']).Trim(); $lcOs = ([string]$all['cmpEmpList.OnSelectRow']).Trim(); $lcTg = ([string]$all['cmpEmpList.OnToggleShowInactive']).Trim()
Assert-True ($idx['cmpEmpList']['Control'] -eq 'CanvasComponent' -and $idx['cmpEmpList']['ComponentName'] -eq 'cmpListCard') 'List card = cmpListCard instance (cmpEmpList)'
Assert-True ($lcOs.StartsWith('=If(' + $lcEn.Substring(1) + ',') -and $lcTg.StartsWith('=If(' + $lcEn.Substring(1) + ',')) 'cmpEmpList: Enabled is the first If-condition of OnSelectRow and of OnToggleShowInactive (same guard text)'
$all['galEmpList.OnSelect'] = $all['cmpEmpList.OnSelectRow']; $all['galEmpList.DisplayMode'] = '=If(' + $lcEn.Substring(1) + ',DisplayMode.Edit,DisplayMode.Disabled)'
$all['galEmpList.Items'] = $all['cmpEmpList.Items']; $all['btnEmpShowInactiveSwitch.OnSelect'] = $all['cmpEmpList.OnToggleShowInactive']
$all['icoEmpMsgClose.OnSelect'] = $all['cmpEmpMsgBar.OnClose']; $all.Remove('cmpEmpMsgBar.OnClose')
$all.Remove('cmpEmpList.OnSelectRow'); $all.Remove('cmpEmpList.Enabled'); $all.Remove('cmpEmpList.Items'); $all.Remove('cmpEmpList.OnToggleShowInactive')
$screenText = ($all.Values) -join "`n"
function Get-Prop([string]$ctl, [string]$prop) { $v = $all["$ctl.$prop"]; if ($null -eq $v) { throw "FAIL missing $ctl.$prop" }; return ([string]$v).Trim() }

# (1) Identical fail-closed guard in DisplayMode and as first OnSelect condition --------------------------
$guards = @{}
foreach ($ctl in @('btnEmpSave', 'btnEmpHome', 'btnEmpNew', 'btnEmpRefresh', 'btnEmpDiscard', 'galEmpList')) {
    $dm = Get-Prop $ctl 'DisplayMode'; $os = Get-Prop $ctl 'OnSelect'
    $suffix = ',DisplayMode.Edit,DisplayMode.Disabled)'
    Assert-True ($dm.StartsWith('=If(') -and $dm.EndsWith($suffix)) "$ctl DisplayMode has shape If(<guard>,Edit,Disabled)"
    $g = $dm.Substring(4, $dm.Length - 4 - $suffix.Length)
    Assert-True ($os.StartsWith('=If(' + $g + ',')) "$ctl OnSelect starts with the same guard text as DisplayMode"
    $guards[$ctl] = $g
}
$dirtyStart = $guards.btnEmpSave.IndexOf('(Coalesce(varEmpMode,"") in ["New","Edit"]')
Assert-True ($dirtyStart -ge 0) 'Save guard contains the dirty expression'
$dirty = Get-Balanced $guards.btnEmpSave $dirtyStart
foreach ($f in @('Name', 'Address', 'Postalcode', 'City', 'Country', 'ContactName', 'ContactEmail', 'ContactPhone')) {
    Assert-True ($dirty.Contains("Trim(cmpEmp$f.CurrentValue & """")<>Trim(varEmpEdit.$f & """")")) "Dirty compares cmpEmp$f.CurrentValue directly with varEmpEdit, both sides Trim(x & """") (no OnChange dependency, blank = empty)"
}
Assert-True ($dirty.Contains('Coalesce(varEmpActiveDraft,true)<>Coalesce(varEmpEdit.Active,true)')) 'Dirty compares the Active switch draft varEmpActiveDraft with varEmpEdit.Active, both sides Coalesce(x,true) (blank Active = active)'
Assert-True ($guards.btnEmpSave.EndsWith('&& ' + $dirty)) 'Save requires dirty'
foreach ($ctl in @('btnEmpHome', 'btnEmpNew', 'galEmpList')) { Assert-True ($guards[$ctl].EndsWith('!' + $dirty)) "$ctl blocked while dirty (same dirty text)" }
Assert-True ($guards.btnEmpRefresh -ceq ('!Coalesce(varEmpBusy,false) && !Coalesce(varEmpSaving,false) && (Coalesce(varEmpSaveFailed,false) || !' + $dirty + ')')) 'Refresh: blocked while loading/saving; allowed when clean or after a failed save (same dirty text)'
Assert-True ($guards.btnEmpDiscard.Contains('|| ' + $dirty + ')')) 'Discard requires dirty or SaveFailed (same dirty text)'
Assert-True ($guards.btnEmpHome -ceq ('!Coalesce(varEmpBusy,false) && !Coalesce(varEmpSaving,false) && !' + $dirty) -and $guards.btnEmpNew -ceq $guards.galEmpList) 'Home guard = not busy/saving/dirty (unchanged rule); New = gallery-selection guard'
foreach ($k in @('varEmpLoadState="Loaded"', 'IsEmpty(colEmpLoadErrors)', '!Coalesce(varEmpBusy,false)', '!Coalesce(varEmpSaving,false)', '!Coalesce(varEmpSaveFailed,false)')) {
    Assert-True ($guards.btnEmpSave.Contains($k) -and $guards.btnEmpNew.Contains($k)) "Save and New guards contain $k"
}
Assert-True ($guards.btnEmpSave.Contains('(varEmpMode="New" || (varEmpMode="Edit" && !IsBlank(varEmpSelectedID)))')) 'Save guard: New, or Edit with an ID'
foreach ($ctl in @('btnEmpHome', 'btnEmpRefresh', 'btnEmpDiscard')) { Assert-True ($guards[$ctl].StartsWith('!Coalesce(varEmpBusy,false) && !Coalesce(varEmpSaving,false)')) "$ctl blocked while loading/saving" }
Assert-True ((Get-Prop 'btnEmpHome' 'OnSelect') -match 'Navigate\(scrHome\)' -and ([regex]::Matches((Get-Prop 'btnEmpHome' 'OnSelect'), 'Navigate\(')).Count -eq 1) 'Home navigates only to scrHome, inside the guard'
# Evaluate the guards with fixtures (interpreter; controls supplied as records)
$fix = 'varEmpLoadState:"Loaded",colEmpLoadErrors:Filter(Table({Message:""}),false),varEmpBusy:false,varEmpSaving:false,varEmpSaveFailed:false,varEmpMode:"Edit",varEmpSelectedID:5,' +
'varEmpEdit:{ID:5,Name:"A",Code:"",Address:"",Postalcode:"",City:"",Country:"",ContactName:"",ContactEmail:"",ContactPhone:"",Active:true},' +
'cmpEmpName:{CurrentValue:"B"},cmpEmpAddress:{CurrentValue:""},cmpEmpPostalcode:{CurrentValue:""},cmpEmpCity:{CurrentValue:""},cmpEmpCountry:{CurrentValue:""},cmpEmpContactName:{CurrentValue:""},cmpEmpContactEmail:{CurrentValue:""},cmpEmpContactPhone:{CurrentValue:""},varEmpActiveDraft:true'
$clean = $fix.Replace('cmpEmpName:{CurrentValue:"B"}', 'cmpEmpName:{CurrentValue:"A"}')
function Get-GuardFx($name, $fixture) { return 'With({' + $fixture + '},' + $guards[$name] + ')' }
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix) $true 'Save allowed: Loaded, Edit with ID, dirty'
Assert-Eval (Get-GuardFx 'btnEmpSave' $clean) $false 'Save blocked: not dirty'
Assert-Eval (Get-GuardFx 'btnEmpSave' $clean.Replace('varEmpActiveDraft:true', 'varEmpActiveDraft:false')) $true 'Save allowed: only Active unchecked (dirty)'
foreach ($s in @('NotLoaded', 'Loading', 'Failed')) { Assert-Eval (Get-GuardFx 'btnEmpSave' $fix.Replace('varEmpLoadState:"Loaded"', "varEmpLoadState:""$s""")) $false "Save blocked: $s" }
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix.Replace('varEmpLoadState:"Loaded"', 'varEmpLoadState:Blank()')) $false 'Save blocked: cold start'
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix.Replace('varEmpBusy:false', 'varEmpBusy:true')) $false 'Save blocked: loading busy'
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix.Replace('varEmpSaving:false', 'varEmpSaving:true')) $false 'Save blocked: saving'
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix.Replace('varEmpSaveFailed:false', 'varEmpSaveFailed:true')) $false 'Save blocked: after a failed save'
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix.Replace('Filter(Table({Message:""}),false)', 'Table({Message:"x"})')) $false 'Save blocked: load error collection not empty (stale Loaded)'
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix.Replace('varEmpSelectedID:5', 'varEmpSelectedID:Blank()')) $false 'Save blocked: Edit without ID'
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix.Replace('varEmpMode:"Edit"', 'varEmpMode:""')) $false 'Save blocked: no item in the form'
$newFix = $fix.Replace('varEmpMode:"Edit"', 'varEmpMode:"New"').Replace('varEmpSelectedID:5', 'varEmpSelectedID:Blank()').Replace('varEmpEdit:{ID:5,Name:"A"', 'varEmpEdit:{ID:Blank(),Name:""')
Assert-Eval (Get-GuardFx 'btnEmpSave' $newFix) $true 'Save allowed: New with a typed name'
Assert-Eval (Get-GuardFx 'btnEmpSave' $newFix.Replace('cmpEmpName:{CurrentValue:"B"}', 'cmpEmpName:{CurrentValue:""}')) $false 'Save blocked: New without input'
Assert-Eval (Get-GuardFx 'btnEmpHome' $clean) $true 'Home allowed: clean'
Assert-Eval (Get-GuardFx 'btnEmpHome' $fix) $false 'Home blocked: dirty'
Assert-Eval (Get-GuardFx 'btnEmpHome' $clean.Replace('varEmpSaving:false', 'varEmpSaving:true')) $false 'Home blocked: saving'
Assert-Eval (Get-GuardFx 'btnEmpHome' $clean.Replace('varEmpLoadState:"Loaded"', 'varEmpLoadState:"Failed"')) $true 'Home allowed after a failed load (not dirty)'
Assert-Eval (Get-GuardFx 'btnEmpRefresh' $clean.Replace('varEmpLoadState:"Loaded"', 'varEmpLoadState:"Failed"')) $true 'Refresh allowed after a failed load (not dirty)'
Assert-Eval (Get-GuardFx 'btnEmpRefresh' $clean) $true 'Refresh allowed: clean'
Assert-Eval (Get-GuardFx 'btnEmpRefresh' $fix) $false 'Refresh blocked: dirty (no failed save)'
$failedFix = $fix.Replace('varEmpSaveFailed:false', 'varEmpSaveFailed:true').Replace('varEmpLoadState:"Loaded"', 'varEmpLoadState:"Failed"')
Assert-Eval (Get-GuardFx 'btnEmpRefresh' $failedFix) $true 'Refresh allowed after a failed save, even with the kept (dirty) input'
Assert-Eval (Get-GuardFx 'btnEmpRefresh' $failedFix.Replace('varEmpSaving:false', 'varEmpSaving:true')) $false 'Refresh blocked: saving (also after a failed save)'
Assert-Eval (Get-GuardFx 'btnEmpRefresh' $failedFix.Replace('varEmpBusy:false', 'varEmpBusy:true')) $false 'Refresh blocked: loading (also after a failed save)'
Assert-Eval (Get-GuardFx 'btnEmpDiscard' $failedFix) $true 'Discard allowed after a failed save with kept input'
Assert-Eval (Get-GuardFx 'btnEmpHome' $failedFix) $false 'Home blocked after a failed save while the kept input is present (allowed again after the reload resets the form)'
Assert-Eval (Get-GuardFx 'btnEmpSave' $failedFix) $false 'Save blocked after a failed save'
Assert-Eval (Get-GuardFx 'btnEmpNew' $failedFix) $false 'New blocked after a failed save'
Assert-Eval (Get-GuardFx 'galEmpList' $failedFix) $false 'Gallery selection blocked after a failed save'
Assert-Eval (Get-GuardFx 'btnEmpNew' $fix) $false 'New blocked: dirty'
Assert-Eval (Get-GuardFx 'btnEmpNew' $clean.Replace('varEmpLoadState:"Loaded"', 'varEmpLoadState:"Failed"')) $false 'New/gallery blocked: load Failed'
Assert-Eval (Get-GuardFx 'galEmpList' $clean) $true 'Gallery selection allowed: Loaded and clean'
Assert-Eval (Get-GuardFx 'btnEmpDiscard' $fix) $true 'Discard allowed: dirty'
Assert-Eval (Get-GuardFx 'btnEmpDiscard' $clean) $false 'Discard disabled: clean'
Assert-Eval (Get-GuardFx 'btnEmpDiscard' $clean.Replace('varEmpSaveFailed:false', 'varEmpSaveFailed:true')) $true 'Discard allowed after a failed save (reloads)'
Assert-Eval (Get-GuardFx 'btnEmpDiscard' $fix.Replace('varEmpSaving:false', 'varEmpSaving:true')) $false 'Discard blocked: saving'

function TT0([string]$k) { return "If(LangNl && !IsBlank(T.$k.nl),T.$k.nl,T.$k.en)" }
# Form is bound to varEmpEdit (cmpField.Value), never to the list selection. Step 3a: cmpField instances replace txtEmp* + labels + star.
$inputMap = [ordered]@{ cmpEmpName = 'Name'; cmpEmpAddress = 'Address'; cmpEmpPostalcode = 'Postalcode'; cmpEmpCity = 'City'; cmpEmpCountry = 'Country'; cmpEmpContactName = 'ContactName'; cmpEmpContactEmail = 'ContactEmail'; cmpEmpContactPhone = 'ContactPhone' }
$fieldEnabled = '=varEmpLoadState="Loaded" && IsEmpty(colEmpLoadErrors) && !Coalesce(varEmpBusy,false) && !Coalesce(varEmpSaving,false) && !Coalesce(varEmpSaveFailed,false) && Coalesce(varEmpMode,"") in ["New","Edit"]'
$fieldLabels = @{ cmpEmpName = 'empFieldName'; cmpEmpCode = 'empFieldCode'; cmpEmpAddress = 'empFieldAddress'; cmpEmpPostalcode = 'empFieldPostalcode'; cmpEmpCity = 'empFieldCity'; cmpEmpCountry = 'empFieldCountry'; cmpEmpContactName = 'empFieldContactName'; cmpEmpContactEmail = 'empFieldContactEmail'; cmpEmpContactPhone = 'empFieldContactPhone' }
foreach ($k in $inputMap.Keys) {
    Assert-True ($idx[$k]['Control'] -eq 'CanvasComponent' -and $idx[$k]['ComponentName'] -eq 'cmpField') "${k} is a cmpField instance"
    $ip = $idx[$k]['Properties']
    Assert-True (([string]$ip['Value']).Trim() -ceq "=varEmpEdit.$($inputMap[$k])") "${k}.Value = varEmpEdit.$($inputMap[$k])"
    Assert-True (([string]$ip['Enabled']).Trim() -ceq $fieldEnabled) "${k}.Enabled = the edit guard (Loaded, no load error, not busy/saving/failed, Mode New or Edit), as Boolean"
    Assert-True ($ip['Invalid'] -ceq ('=CountIf(colEmpSaveErrors,Field="' + $inputMap[$k] + '")>0')) "${k}.Invalid = CountIf(colEmpSaveErrors,Field=""$($inputMap[$k])"")>0 (red border rule)"
    Assert-True ($ip['InputType'] -ceq '="text"' -and $ip['MaxLength'] -ceq '=255' -and $ip['HintText'] -ceq '=""' -and -not $ip.ContainsKey('OnChange')) "${k}: InputType text, MaxLength 255, HintText, no OnChange logic"
    Assert-True ($ip['Label'] -ceq ('=' + (TT0 $fieldLabels[$k]))) "${k}.Label from T.$($fieldLabels[$k])"
    Assert-True (($ip.ContainsKey('Required') -and $ip['Required'] -eq '=true') -eq ($k -eq 'cmpEmpName')) "${k}.Required only on Contractor Name"
    Assert-True ($ip['Height'] -ceq '=58' -and $ip['Width'] -ceq '=lblEmpGrid.Width') "${k}: height 58 (label 18 + 4 + field 36), grid cell width"
}
$cp = $idx['cmpEmpCode']['Properties']
Assert-True ($idx['cmpEmpCode']['ComponentName'] -eq 'cmpField' -and $cp['InputType'] -ceq '="readonly"' -and $cp['Enabled'] -ceq '=false' -and -not $cp.ContainsKey('Required') -and -not $cp.ContainsKey('Invalid')) 'cmpEmpCode: read-only, never enabled, no star, never written (not in the dirty check or Save record)'
Assert-True ($cp['Label'] -ceq ('=' + (TT0 $fieldLabels['cmpEmpCode'])) -and ([string]$cp['Value']).Contains('varEmpEdit.Code') -and ([string]$cp['Value']).Contains((TT0 'empCodeAuto'))) 'cmpEmpCode.Value = saved code, or the automatic text in New/Edit without code'
Assert-True ($srcAll -notmatch '\btxtEmp\w*\b|\bgalEmpList\b|\blblEmp\w*Label\b|\blblEmpNameRequired\b|\bconEmpMsgBar\b|\bnavEmp\b|\bconEmpListCard\b|\bimgEmpSpinner\b|\bimgLogoContractors\b|\blblEmpTitle\b') 'No replaced hand-built control (txtEmp*, galEmpList, field labels/star, conEmpMsgBar, navEmp, spinner, logo) is left in Src'
foreach ($n in @('cmpEmpTitle', 'cmpEmpMsgBar', 'cmpEmpList', 'cmpEmpFooter') + @($inputMap.Keys) + 'cmpEmpCode') { Assert-True ($idx[$n]['Control'] -eq 'CanvasComponent') "${n} is a component instance" }
Assert-True ($srcAll -notmatch '\bchkEmpActive\b|\bchkEmpShowInactive\b') 'chkEmpActive and chkEmpShowInactive no longer exist in Src'
Assert-True (@($idx.Keys | Where-Object { $idx[$_]['Control'] -like 'Classic/CheckBox@*' }).Count -eq 0) 'No Classic/CheckBox left on scrContractors'
$draftSet = 'Set(varEmpActiveDraft,Coalesce(varEmpEdit.Active,true))'
$draftSets = @($all.Keys | Where-Object { $all[$_] -match 'Set\(varEmpActiveDraft,' } | Sort-Object)
Assert-True (($draftSets -join ',') -ceq 'btnEmpActiveSwitch.OnSelect,btnEmpDiscard.OnSelect,btnEmpFormReset.OnSelect,btnEmpLoad.OnSelect,btnEmpNew.OnSelect,btnEmpSave.OnSelect,galEmpList.OnSelect,scrContractors.OnVisible') "varEmpActiveDraft set only by the form fills (load, form reset, selection, New, Discard, verified save), the switch toggle and the OnVisible init ($($draftSets -join ', '))"
foreach ($k in @('btnEmpLoad.OnSelect', 'btnEmpFormReset.OnSelect', 'galEmpList.OnSelect', 'btnEmpNew.OnSelect', 'btnEmpDiscard.OnSelect', 'btnEmpSave.OnSelect')) { Assert-True (([regex]::Matches($all[$k], 'Set\(varEmpActiveDraft,')).Count -eq 1 -and $all[$k].Contains($draftSet)) "$k fills the switch draft from the snapshot: $draftSet" }
Assert-True ((Get-Prop 'btnEmpActiveSwitch' 'OnSelect').Contains('Set(varEmpActiveDraft,!Coalesce(varEmpActiveDraft,true));') -and ([regex]::Matches((Get-Prop 'btnEmpActiveSwitch' 'OnSelect'), 'Set\(varEmpActiveDraft,')).Count -eq 1) 'Switch OnSelect toggles the draft once: Set(varEmpActiveDraft,!Coalesce(varEmpActiveDraft,true))'
$vis0 = [string]$screenProps['OnVisible']
Assert-True ($vis0.Contains('If(IsBlank(varEmpLoadState),') -and $vis0.Contains('Set(varEmpActiveDraft,true); Set(varEmpShowInactive,false);') -and $vis0.IndexOf('Set(varEmpActiveDraft,true)') -lt $vis0.IndexOf('Select(btnEmpLoad)')) 'OnVisible first-visit init: varEmpActiveDraft = true (New snapshot), varEmpShowInactive = false'
$draftReaders = @($all.Keys | Where-Object { $all[$_] -match '\bvarEmpActiveDraft\b' -and $_ -notmatch '\.On\w+$' } | Sort-Object)
$draftCmp = 'Coalesce(varEmpActiveDraft,true)<>Coalesce(varEmpEdit.Active,true)'
$draftOther = @($draftReaders | Where-Object { $_ -notmatch '^(btnEmpActiveSwitch|btnEmpActiveKnob|lblEmpActiveState|btnEmpFormChip)\.' -and ([regex]::Matches($all[$_], '\bvarEmpActiveDraft\b')).Count -ne ([regex]::Matches($all[$_], [regex]::Escape($draftCmp))).Count })
Assert-True ($draftOther.Count -eq 0) "Outside the switch controls varEmpActiveDraft is only read in the dirty comparison ($($draftOther -join ', '))"
foreach ($k in @('btnEmpSave.DisplayMode', 'btnEmpHome.DisplayMode', 'btnEmpNew.DisplayMode', 'btnEmpRefresh.DisplayMode', 'btnEmpDiscard.DisplayMode', 'galEmpList.DisplayMode')) { Assert-True ($all[$k].Contains($draftCmp)) "$k dirty check reads the switch draft ($draftCmp)" }
$selUses = @($all.Keys | Where-Object { $all[$_] -match 'cmpEmpList\.SelectedRowID' })
Assert-True ($selUses.Count -eq 1 -and $selUses[0] -eq 'galEmpList.OnSelect') 'cmpEmpList.SelectedRowID only read in the guarded OnSelectRow handler'

# (2) Loader: staging, reuse, dirty block, no mutations ---------------------------------------------------
$load = Get-Prop 'btnEmpLoad' 'OnSelect'; $loadN = Norm $load
$vis = [string]$screenProps['OnVisible']
foreach ($k in @('btnEmpLoad.OnSelect', "$screenName.OnVisible")) {
    $fx = $all[$k]
    Assert-True ($fx -notmatch '\b(Patch|Update|UpdateIf|Remove|RemoveIf|SubmitForm|Defaults)\s*\(' -and $fx -notmatch '\.Run\(') "$k has no Patch/Update/Remove/SubmitForm/Defaults/flow"
    Assert-True ($fx -notmatch "\b(?:Collect|ClearCollect)\(\s*(?:Employers|Workers|Projects|Hours|'Project Workers'|'Assignment Periods')\b") "$k does not Collect into a SharePoint list"
}
Assert-True ($load.Contains('If(' + $dirty + ' && !Coalesce(varEmpSaveFailed,false),')) 'Loader refuses to reload over unsaved input (except the explicit Discard after a failed save)'
Assert-True ($load.Contains('If(!Coalesce(varEmpForceRefresh,false) && varEmpLoadState="Loaded" && IsEmpty(colEmpLoadErrors) && !Coalesce(varEmpSaveFailed,false),')) 'Loader reuses a valid Loaded list unless forced'
Assert-True ($loadN.Contains((Norm 'Clear(colPendingEmpWorkers);IfError(Refresh(Employers),')) -and $loadN.Contains((Norm 'IfError(Refresh(Workers),')) -and $load -notmatch 'If\(Coalesce\(varEmpForceRefresh,false\),') 'Every load (first load, Refresh, Discard after a failed save) refreshes the Employers and Workers connector cache, not only a forced one'
$refreshOs = Get-Prop 'btnEmpRefresh' 'OnSelect'
Assert-True ($refreshOs.Contains('Set(varEmpForceRefresh,true); Select(btnEmpLoad)')) 'Refresh forces the staged loader'
Assert-True ($refreshOs.Contains('If(Coalesce(varEmpSaveFailed,false),Clear(colEmpSaveErrors));') -and $refreshOs -notmatch '\b(Patch|Refresh|Collect|ClearCollect|Remove|RemoveIf|Reset)\(') 'Refresh after a failed save behaves like Discard (clears the local save errors, forced reload through btnEmpLoad, no mutation)'
Assert-True ($load.Contains('varEmpMode="New" && !Coalesce(varEmpSaveFailed,false),') -and $load.Contains('Set(varEmpSaveFailed,false); Clear(colEmpSaveErrors); Set(varEmpLoadState,"Loaded");')) 'Forced reload after a failed save discards local input (New -> no item; SaveFailed cleared only after a successful load)'
# The SaveFailed reset must sit inside the success branch: after the last If(IsEmpty(colEmpLoadErrors), and with no Failed state set in between.
$clearAt = $load.IndexOf('Set(varEmpSaveFailed,false); Clear(colEmpSaveErrors); Set(varEmpLoadState,"Loaded");')
$branchAt = $load.LastIndexOf('If(IsEmpty(colEmpLoadErrors),', $clearAt)
Assert-True ($branchAt -ge 0 -and $load.Substring($branchAt, $clearAt - $branchAt).IndexOf('Set(varEmpLoadState,"Failed")') -lt 0) 'SaveFailed is cleared only inside the successful-load branch of the loader'
Assert-True ($vis.Contains('If(varEmpLoadState<>"Loaded" && !Coalesce(varEmpBusy,false) && !Coalesce(varEmpSaving,false) && !' + $dirty + ',Select(btnEmpLoad))')) 'OnVisible loads only when not Loaded, idle and not dirty'
$conc = Get-Balanced $load $load.IndexOf('Concurrent(')
$branches = Split-Args $conc.Substring('Concurrent('.Length, $conc.Length - 'Concurrent('.Length - 1)
Assert-True ($branches.Count -eq 2) 'Loader runs two independent reads in Concurrent'
Assert-True ($branches[0].Contains('ClearCollect(colPendingEmpRaw,Sort(Employers,Title,SortOrder.Ascending))') -and $branches[0] -notmatch 'colEmpWorkersLoadErrors|colEmpLoadErrors\b' -and $branches[0].Contains('Collect(colEmpEmployersLoadErrors,')) 'Concurrent branch 1 writes only its own error collection'
Assert-True ($branches[1].Contains('ClearCollect(colPendingEmpWorkers,') -and $branches[1] -notmatch 'colEmpEmployersLoadErrors|colEmpLoadErrors\b' -and $branches[1].Contains('Collect(colEmpWorkersLoadErrors,')) 'Concurrent branch 2 writes only its own error collection'
$iMerge = $loadN.IndexOf('Collect(colEmpLoadErrors,colEmpEmployersLoadErrors,colEmpWorkersLoadErrors)')
$iLimitE = $loadN.IndexOf('If(CountRows(colPendingEmpRaw)>=500,Collect(colEmpLoadErrors,')
$iLimitW = $loadN.IndexOf('If(CountRows(colPendingEmpWorkers)>=500,Collect(colEmpLoadErrors,')
$iGate = $loadN.IndexOf('If(IsEmpty(colEmpLoadErrors),ClearCollect(colAdminEmployers,colPendingAdminEmployers);ClearCollect(colEmpWorkers,colPendingEmpWorkers);')
Assert-True ($iMerge -gt 0 -and $iLimitE -gt $iMerge -and $iLimitW -gt $iMerge -and $iGate -gt $iLimitE -and $iGate -gt $iLimitW) 'Errors merged and 500 guards applied before the staged list replaces colAdminEmployers'
Assert-True (([regex]::Matches($screenText, 'ClearCollect\(colAdminEmployers,')).Count -eq 1) 'colAdminEmployers is only replaced by the loader staging step'
Assert-True ($loadN.Contains((Norm 'Set(varEmpLoadState,"Failed");')) -and $loadN.Contains((Norm 'Set(varEmpLoadState,"Loaded");'))) 'Loader sets Loaded or Failed'
Assert-True ($loadN.IndexOf('Set(varEmpLoadState,"Loaded")') -gt $iGate) 'Loaded only inside the no-error branch'

# (3) No Remove/RemoveIf/Clear on SharePoint lists anywhere ---------------------------------------------------
Assert-True ($srcAll -notmatch "\b(?:Remove|RemoveIf|Clear|UpdateIf|Update)\(\s*(?:Employers|Workers|Projects|Hours|'Project Workers'|'Assignment Periods')\b") 'No Remove/RemoveIf/Clear/Update on SharePoint lists in Src'
Assert-True ($screenText -notmatch '\.Run\(') 'No flow calls on scrContractors'

# (4) 500 guard after every collection read from a SharePoint list ------------------------------------------
$reads = 0
foreach ($k in $all.Keys) {
    $fx = $all[$k]
    foreach ($m in [regex]::Matches($fx, '\b(?:ClearCollect|Collect)\(\s*(\w+)\s*,')) {
        $call = Get-Balanced $fx ($m.Index + $m.Value.IndexOf('('))
        $arg = $call.Substring($m.Value.Length - $m.Value.IndexOf('('))
        if ($arg -notmatch "(?<![\w.'])(?:Employers|Workers|Projects|Hours)\b(?!\.)|'(?:Project Workers|Assignment Periods)'") { continue }
        if ($arg.TrimStart().StartsWith('Patch(')) { continue }
        $reads++
        $col = $m.Groups[1].Value
        $after = $fx.Substring($m.Index)
        Assert-True ($after.Contains("CountRows($col)>=500") -or $after.Contains("CountRows($col)<>1") -or $after.Contains("CountRows($col)=1")) "$k : SharePoint read into $col is followed by a 500 guard (or exact-one check for an ID read)"
    }
}
Assert-True ($reads -ge 5) "SharePoint reads checked: $reads"

# (5) Delegable predicates: column = global variable only ---------------------------------------------------
$filters = 0
foreach ($k in $all.Keys) {
    $fx = $all[$k]
    foreach ($m in [regex]::Matches($fx, "\b(Filter|LookUp)\(\s*(Employers|Workers|Projects|Hours|'Project Workers'|'Assignment Periods')\s*,")) {
        $filters++
        Assert-True ($m.Groups[1].Value -eq 'Filter') "$k : no remote LookUp on $($m.Groups[2].Value)"
        $call = Get-Balanced $fx ($m.Index + $m.Groups[1].Value.Length)
        $pred = (Split-Args $call.Substring(1, $call.Length - 2))[1]
        Assert-True ($pred.Trim() -match '^(?:ID|Title)\s*=\s*var\w+$') "$k : predicate '$($pred.Trim())' uses a column and a global variable only"
    }
}
Assert-True ($filters -ge 3) "Server predicates checked: $filters"
Assert-True ($screenText -notmatch '\bSearch\(' -and $screenText -notmatch '\bChoices\(') 'No Search() or Choices() on scrContractors'
Assert-True ($screenText -notmatch "ForAll\([^)]*\b(?:Employers|Workers)\b[^)]*\)[^;]*\b(?:LookUp|Filter)\(\s*(?:Employers|Workers)") 'No remote LookUp/Filter inside ForAll'

# (6)-(8) Save: validation, duplicate block, conflict check, one Patch, verify read, local update after verify ----
$save = Get-Prop 'btnEmpSave' 'OnSelect'; $saveN = Norm $save
Assert-True (([regex]::Matches($srcAll, '\bPatch\(\s*Employers\b')).Count -eq 1 -and $save -match '\bPatch\(\s*Employers\b') 'Exactly one Patch(Employers) in Src, in btnEmpSave.OnSelect'
foreach ($k in $all.Keys) { if ($k -ne 'btnEmpSave.OnSelect') { Assert-True ($all[$k] -notmatch '\bPatch\(') "$k has no Patch" } }
$pm = [regex]::Match($save, '\bPatch\(\s*Employers\s*,')
$patch = Get-Balanced $save ($pm.Index + 5)
$pargs = Split-Args $patch.Substring(1, $patch.Length - 2)
Assert-True ($pargs.Count -eq 3 -and $pargs[1].Trim() -ceq 'If(varEmpSaveMode="New",Defaults(Employers),First(colEmpPreRaw))') 'Patch base: Defaults(Employers) for New, the pre-read record for Edit'
$rec = $pargs[2].Trim()
$keys = @((Split-Args $rec.Substring(1, $rec.Length - 2)) | ForEach-Object { ($_ -split ':', 2)[0].Trim() })
$allowedKeys = @('Title', 'Address', 'Postalcode', 'City', 'Country', "'Contact Name'", "'Contact Email'", "'Contact Phone'", 'Active')
Assert-True (@($keys | Where-Object { $_ -cnotin $allowedKeys }).Count -eq 0 -and $keys.Count -eq $allowedKeys.Count) "Patch writes exactly the app fields: $($keys -join ', ')"
Assert-True ($patch -notmatch "Employer Code|EmployerCode1|'Employer Code'") 'Patch never writes Contractor Code (Employer Code / EmployerCode1)'
foreach ($f in @('Name', 'Address', 'Postalcode', 'City', 'Country', 'ContactName', 'ContactEmail', 'ContactPhone')) {
    Assert-True ($save -match "$f\s*:\s*Trim\(cmpEmp$f\.CurrentValue & """"\)") "Save record trims $f (Trim(x & """"): blank input = empty text)"
    Assert-True ($saveN.Contains("If(Len(varEmpSaveRec.$f)>255,Collect(colEmpSaveErrors,")) "Length check <= 255 for $f"
}
Assert-True ($saveN.Contains('If(IsBlank(varEmpSaveRec.Name),Collect(colEmpSaveErrors,{Field:"Name"')) 'Name required (after Trim)'
Assert-True ($saveN.Contains('!IsMatch(varEmpSaveRec.ContactEmail,Match.Email)')) 'Email: empty or IsMatch(Match.Email)'
Assert-True ($saveN.Contains('Lower(Trim(Name))=varEmpDupKey&&(varEmpSaveMode="New"||ID<>varEmpSaveID)') -and ([regex]::Matches($saveN, [regex]::Escape('Lower(Trim(Name))=varEmpDupKey&&(varEmpSaveMode="New"||ID<>varEmpSaveID)'))).Count -eq 2) 'Duplicate name: trim + case-insensitive, own ID excluded, local list and server read'
Assert-True ($saveN.Contains('CountIf(colAdminEmployers,Lower(Trim(Name))=varEmpDupKey') -and $saveN.Contains('ClearCollect(colEmpDup,ForAll(Filter(Employers,Title=varEmpDupName)Asemp,')) 'Duplicate check on the loaded list and a delegable server read (Title = global var)'
Assert-True ($saveN.Contains('Set(varEmpDupName,varEmpSaveRec.Name);Set(varEmpDupKey,Lower(varEmpSaveRec.Name));')) 'Duplicate predicate variables set before the reads'
$proj = [regex]::Match($load, 'As emp,(\{ID:emp\.ID,[^}]*\})').Groups[1].Value
Assert-True ($proj.Length -gt 0 -and ([regex]::Matches($screenText, [regex]::Escape($proj))).Count -eq 4) 'One projection text for load, pre-read, duplicate read and verify read'
foreach ($f in @('Name', 'Address', 'Postalcode', 'City', 'Country', 'ContactName', 'ContactEmail', 'ContactPhone')) {
    Assert-True ($saveN.Contains("Trim(p.$f&`"`")<>Trim(varEmpEdit.$f&`"`")")) "Conflict check compares $f (pre-read vs loaded snapshot, both Trim(x & `"`"))"
    Assert-True ($saveN.Contains("D:Trim(v.$f&`"`")<>Trim(varEmpSaveRec.$f&`"`")")) "Verify read compares $f with the written value (both Trim(x & `"`"))"
}
Assert-True ($saveN.Contains('Coalesce(p.Active,true)<>Coalesce(varEmpEdit.Active,true)')) 'Conflict check compares Active (both Coalesce(x,true))'
Assert-True ($saveN.Contains('D:Coalesce(v.Active,true)<>Coalesce(varEmpSaveRec.Active,true)')) 'Verify read compares Active (both Coalesce(x,true))'
Assert-True ($save.Contains('Active:Coalesce(varEmpActiveDraft,true)});')) 'Save record: Active = Coalesce(varEmpActiveDraft,true) (switch draft)'
$modDisplayN = Norm 'RemoveIf(colEmpModified,ID=varEmpPatchedID); Collect(colEmpModified,{ID:varEmpPatchedID,Modified:First(colEmpVerifyRaw).Modified});'
Assert-True (([regex]::Matches($saveN, [regex]::Escape($modDisplayN))).Count -eq 1) 'Save updates the display-only Modified copy (colEmpModified) from the verify read, once'
Assert-True ($saveN.Replace($modDisplayN, '') -notmatch 'p\.Code|v\.Code|Modified') 'Conflict/verify ignore Contractor Code (flow MS-019) and Modified (Modified only in the display copy update)'
$iVal = $saveN.IndexOf('If(IsBlank(varEmpSaveRec.Name)')
$iDupLocal = $saveN.IndexOf('CountIf(colAdminEmployers,')
$iGateRead = $saveN.IndexOf('If(IsEmpty(colEmpSaveErrors),IfError(Refresh(Employers),')
$iPre = $saveN.IndexOf('ClearCollect(colEmpPreRaw,Filter(Employers,ID=varEmpSaveID))')
$iDup = $saveN.IndexOf('ClearCollect(colEmpDup,')
$iConf = $saveN.IndexOf('Set(varEmpSaveConflict,true)')
$iWriteGate = $saveN.IndexOf('If(IsEmpty(colEmpSaveErrors),Set(varEmpPatchError,false);IfError(CountRows(ClearCollect(colEmpPatched,Patch(Employers,')
$iPatch = $saveN.IndexOf('Patch(Employers,')
$iVerify = $saveN.IndexOf('ClearCollect(colEmpVerifyRaw,Filter(Employers,ID=varEmpPatchedID))')
$iOk = $saveN.IndexOf('Set(varEmpSaveVerified,true)')
$iLocal = $saveN.IndexOf('If(varEmpSaveVerified&&IsEmpty(colEmpSaveErrors),RemoveIf(colAdminEmployers,ID=varEmpPatchedID);Collect(colAdminEmployers,First(colEmpVerify));')
Assert-True ($iVal -gt 0 -and $iDupLocal -gt $iVal -and $iGateRead -gt $iDupLocal -and $iPre -gt $iGateRead -and $iDup -gt $iPre -and $iConf -gt $iDup -and $iWriteGate -gt $iConf -and $iPatch -gt $iWriteGate -and $iVerify -gt $iPatch -and $iOk -gt $iVerify -and $iLocal -gt $iOk) 'Order: validation -> (no errors) pre-read -> duplicate read -> conflict -> (no errors) one Patch -> verify read -> local update'
Assert-True (([regex]::Matches($screenText, '(?<!Clear)Collect\(colAdminEmployers,')).Count -eq 1 -and ([regex]::Matches($screenText, 'RemoveIf\(colAdminEmployers,')).Count -eq 1) 'colAdminEmployers changed only by the loader and after a verified save'
Assert-True ($saveN.Contains('Set(varEmpEdit,First(colEmpVerify))')) 'Snapshot updated only from the verify read'
Assert-True ($saveN.Contains('varEmpSaveWrites=0,Set(varAdmMsgKind,"Error");') -and $saveN.Contains('Set(varEmpSaveFailed,true);Set(varEmpLoadState,"Failed");')) 'Zero writes + error stays Loaded; write + error -> Failed and SaveFailed (input kept, save blocked)'
Assert-True (([regex]::Matches($saveN, 'Set\(varEmpSaveFailed,true\)')).Count -eq 1) 'SaveFailed set in exactly one place'
Assert-True ($saveN.Contains('Set(varEmpSaveWarnWorkers,If(varEmpSaveMode="Edit"&&Coalesce(varEmpEdit.Active,true)&&!varEmpSaveRec.Active,CountIf(colEmpWorkers,EmployerID=varEmpSaveID')) 'Deactivation with active workers is counted (warning)'
Assert-True ($screenText -notmatch 'Collect\(colEmpSaveErrors,\{[^}]*empWarnActiveWorkers') 'Active-worker warning never blocks the save'
Assert-True ($load.Contains('ClearCollect(colPendingEmpWorkers,ForAll(Workers As wrk,{ID:wrk.ID,EmployerID:wrk.Employer.Id,WorkerActive:wrk.Active}))')) 'Workers read for the warning: explicit projection (lookup ID filtered locally)'
$reset = 'Reset(cmpEmpName); Reset(cmpEmpAddress); Reset(cmpEmpPostalcode); Reset(cmpEmpCity); Reset(cmpEmpCountry); Reset(cmpEmpContactName); Reset(cmpEmpContactEmail); Reset(cmpEmpContactPhone); Set(varEmpActiveDraft,Coalesce(varEmpEdit.Active,true))'
foreach ($k in @('btnEmpLoad.OnSelect', 'btnEmpSave.OnSelect', 'btnEmpNew.OnSelect', 'btnEmpDiscard.OnSelect', 'galEmpList.OnSelect')) { Assert-True ($all[$k].Contains($reset)) "$k resets all form inputs" }
$disc = Get-Prop 'btnEmpDiscard' 'OnSelect'
Assert-True ($disc -notmatch '\b(Patch|Refresh|Collect|ClearCollect|Remove|RemoveIf)\(' -and $disc.Contains('If(Coalesce(varEmpSaveFailed,false),') -and $disc.Contains('Set(varEmpForceRefresh,true); Select(btnEmpLoad)')) 'Discard is local; after a failed save it reloads through the staged loader'

# (9) Cache invalidation after a verified save ------------------------------------------------------------
$okBranch = $saveN.Substring($iLocal)
foreach ($k in @('Set(varWorkersCacheReady,false)', 'Set(varMastersReady,false)', 'Set(varReportReady,false)', 'If(varEmpSaveRenamed,IfError(Refresh(Workers),')) {
    Assert-True ($okBranch.Contains($k)) "Verified save invalidates: $k"
}
Assert-True ($okBranch.IndexOf('Set(varWorkersCacheReady,false)') -lt $okBranch.IndexOf('varEmpSaveWrites=0,')) 'Invalidation only in the verified-success branch'
Assert-True ($saveN.Contains('IfError(Refresh(Employers),Collect(colEmpSaveErrors,{Field:"",Message:If(LangNl&&!IsBlank(T.empErrVerify.nl)')) 'Employers connector refreshed before the verify read'

# (10) Traces: no names, no FirstError.Message ---------------------------------------------------------------
$traces = 0
foreach ($k in $all.Keys) {
    $fx = $all[$k]
    foreach ($m in [regex]::Matches($fx, '\bTrace\(')) {
        $traces++
        $t = Get-Balanced $fx ($m.Index + 5)
        Assert-True ($t.StartsWith('("DIAG|Contractors|')) "$k : trace name DIAG|Contractors|..."
        Assert-True ($t -notmatch 'FirstError|cmpEmp|varEmpSaveRec|varEmpDupName|varEmpDupKey|varEmpEdit\.|\.Name\b|Title|Message') "$k : trace has no names, values or FirstError.Message"
    }
}
Assert-True ($traces -ge 7) "Traces checked: $traces"
Assert-True ($saveN.Contains('Trace("DIAG|Contractors|SaveEnd",TraceSeverity.Information,{Screen:"Contractors",Mode:varEmpSaveMode,ItemID:Coalesce(varEmpPatchedID,varEmpSaveID,0),ElapsedMs:')) 'SaveEnd trace with Mode/ItemID/ElapsedMs/Reads/Writes/Verified/DupFound/Errors'

# (11) User texts via T -----------------------------------------------------------------------------------
$formulas = [string]$appDoc['App']['Properties']['Formulas']
$tKeys = @([regex]::Matches($formulas, '(?m)^\s*(\w+):\s*\{en:\s*"([^"]*)",\s*nl:\s*"([^"]*)"\}') | ForEach-Object { $_.Groups[1].Value })
$tEmpty = @([regex]::Matches($formulas, '(?m)^\s*(\w+):\s*\{en:\s*"",') | ForEach-Object { $_.Groups[1].Value })
Assert-True ($tKeys.Count -gt 20 -and $tEmpty.Count -eq 0) "T has $($tKeys.Count) keys, each with an English text"
Assert-True (@($tKeys | Group-Object | Where-Object Count -gt 1).Count -eq 0) 'T keys are unique'
$used = @([regex]::Matches($srcAll, '\bT\.(\w+)\.(?:en|nl)\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$missing = @($used | Where-Object { $_ -cnotin $tKeys })
Assert-True ($missing.Count -eq 0) "All T keys used in Src exist ($($used.Count) used; missing: $($missing -join ', '))"
Assert-True (@([regex]::Matches($srcAll, '\bT\.(\w+)\.en\b') | Where-Object { $srcAll.Substring([Math]::Max(0, $_.Index - 160), [Math]::Min(160, $_.Index)) -notmatch 'IsBlank\(T\.\w+\.nl\),T\.\w+\.nl,$' }).Count -eq 0) 'Every T text uses the LangNl fallback pattern'
$hardCoded = @()
foreach ($k in $all.Keys) {
    $fx = $all[$k]
    if ($k -like '*.Font' -or $k -eq 'imgEmpSpinner.Image') { continue }
    if ($k -like '*.OnVisible' -or $k -like '*.OnSelect') { $fx = [regex]::Replace($fx, 'Trace\("[^"]*"', 'Trace(') }
    foreach ($lit in [regex]::Matches($fx, '"([^"]*)"')) {
        if ($lit.Groups[1].Value -match '[A-Za-z]{2,}\s+[A-Za-z]') { $hardCoded += "$k : `"$($lit.Groups[1].Value)`"" }
    }
}
Assert-True ($hardCoded.Count -eq 0) "No hard-coded sentences on scrContractors (all user texts via T) $($hardCoded -join '; ')"
$literalCaptions = @(); $captions = 0
foreach ($n in $idx.Keys) {
    $props = $idx[$n]['Properties']
    $hidden = ([string]$props['Visible']).Trim() -eq '=false'
    foreach ($p in @('Text', 'HintText', 'AccessibleLabel', 'Tooltip')) {
        if (!$props.ContainsKey($p) -or $hidden) { continue }
        # The logo label "GEA" is a brand name fixed by AGENTS.md (not translated).
        if ($n -like 'imgLogo*' -and $p -eq 'AccessibleLabel') { continue }
        $captions++
        $v = ([string]$props[$p]).Trim()
        if ($v -match '^="[^"]*[A-Za-z][^"]*"$') { $literalCaptions += "$n.$p" }
    }
}
Assert-True ($literalCaptions.Count -eq 0) "Visible captions use T, no literal text ($captions checked) $($literalCaptions -join ', ')"

# (12) Identifier trap: bare ProjectName (internal name of 'Project Number') ----------------------------------
Assert-True ($srcAll -notmatch "(?<!['\w])ProjectName\b") 'No bare ProjectName identifier in Src'

# (13) Blank versus empty text (bug TP-CONTRACTORS-01 steps 8/9: every Save ended in "Save not confirmed") ---------------
# Root cause, reproduced in the Power Fx interpreter: Coalesce(x,"") returns Blank when x is blank, and Blank() = "" is false,
# so a SharePoint field that is empty after the save never equalled the written "" in the verify read.
Assert-Eval 'IsBlank(Coalesce(If(false,"x"),""))' $true 'Root cause: Coalesce(<blank text>,"") is still Blank (not "")'
Assert-Eval 'Coalesce(If(false,"x"),"")=""' $false 'Root cause: Coalesce(<blank text>,"") = "" is false'
Assert-Eval 'Trim(If(false,"x") & "")=""' $true 'Fix: Trim(<blank text> & "") = "" is true'
Assert-Eval 'Coalesce(If(false,true),true)=true' $true 'Fix: Coalesce(<blank boolean>,true) = true (blank Active = active)'
Assert-Eval '"Test"="test"' $false 'Text comparison is case-sensitive (Name verify is exact after Trim)'
# Static: no Coalesce(<Employers field / input / snapshot>,"") left in projections or compare expressions
$badCoalesce = @([regex]::Matches($screenText, 'Coalesce\(\s*(?:emp|p|v|varEmpEdit|varEmpSaveRec|cmpEmp\w+)\.[^,()]+,\s*""\s*\)') | ForEach-Object { $_.Value })
Assert-True ($badCoalesce.Count -eq 0) "No Coalesce(<field>,`"`") on Employers projections, inputs or compare expressions $($badCoalesce -join '; ')"
Assert-True ($proj -notmatch 'Coalesce\([^)]*,""\)' -and $proj.Contains('Name:Trim(emp.Title & "")') -and $proj.Contains('Active:Coalesce(emp.Active,true)')) 'Projection: text = Trim(x & ""), Active = Coalesce(x,true)'
foreach ($c in @("'Employer Code'", 'Address', 'Postalcode', 'City', 'Country', "'Contact Name'", "'Contact Email'", "'Contact Phone'")) { Assert-True ($proj.Contains("Trim(emp.$c & `"`")")) "Projection normalizes $c with Trim(x & `"`")" }
# Expressions taken from the source
$tRec = [regex]::Match($formulas, '(?s)\bT\s*=\s*(\{.*\})\s*;\s*$').Groups[1].Value
Assert-True ($tRec.Length -gt 0) 'Translation table T extracted from App.Formulas'
$iSr = $save.IndexOf('Set(varEmpSaveRec,')
$saveRecFx = (Get-Balanced $save ($iSr + 3)); $saveRecFx = $saveRecFx.Substring('(varEmpSaveRec,'.Length, $saveRecFx.Length - '(varEmpSaveRec,'.Length - 1)
$iTab = $save.IndexOf('With({d:Filter(Table(')
Assert-True ($iTab -gt 0) 'Verify builds a per-field difference table'
$tableFx = 'Table' + (Get-Balanced $save ($iTab + 'With({d:Filter(Table'.Length))
$mCf = [regex]::Match($save, 'With\(\{p:First\(colEmpPre\)\},\s*If\(')
Assert-True $mCf.Success 'Conflict check located (With({p:First(colEmpPre)},If(...)'
$cfCall = Get-Balanced $save ($mCf.Index + $mCf.Length - 1)
$conflictFx = (Split-Args $cfCall.Substring(1, $cfCall.Length - 2))[0]
$fNames = @([regex]::Matches($tableFx, '\{F:"(\w+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-True (($fNames -join ',') -ceq 'Name,Address,Postalcode,City,Country,ContactName,ContactEmail,ContactPhone,Active') "Verify compares exactly the app-written fields: $($fNames -join ',')"
Assert-True ($tableFx -cnotmatch '\.Code\b|"Code"|Employer Code|EmployerCode1|Modified' -and $conflictFx -cnotmatch '\.Code\b|Employer Code|EmployerCode1|Modified') 'Verify and conflict ignore Contractor Code (EmployerCode1, flow MS-019) and Modified'
# Fixtures: a SharePoint row as returned after the save (typed blanks for empty fields), and the form inputs
$blankT = 'If(false,"x")'; $blankB = 'If(false,true)'
function Raw([string]$name, [string]$city, [string]$code, [string]$active, [string]$empty) {
    return "{ID:7,Title:$name,'Employer Code':$code,Address:$empty,Postalcode:$empty,City:$city,Country:$empty,'Contact Name':$empty,'Contact Email':$empty,'Contact Phone':$empty,Active:$active,Modified:DateTime(2026,10,28,9,0,0)}"
}
function Inputs([string]$name, [string]$city, [string]$empty, [string]$active) {
    return "cmpEmpName:{CurrentValue:$name},cmpEmpAddress:{CurrentValue:$empty},cmpEmpPostalcode:{CurrentValue:$empty},cmpEmpCity:{CurrentValue:$city},cmpEmpCountry:{CurrentValue:$empty},cmpEmpContactName:{CurrentValue:$empty},cmpEmpContactEmail:{CurrentValue:$empty},cmpEmpContactPhone:{CurrentValue:$empty},varEmpActiveDraft:$active"
}
function Proj([string]$raw) { return "With({emp:$raw},$proj)" }
function SaveRec([string]$inputs) { return "With({$inputs},$saveRecFx)" }
function VerifyDiff([string]$raw, [string]$inputs, [string]$col) { return "With({LangNl:false,T:$tRec},With({v:$(Proj $raw),varEmpSaveRec:$(SaveRec $inputs)},Concat(Filter($tableFx,D),$col,`",`")))" }
$rawBlank = Raw '"TEST Contractor 2"' '"Test Stad2"' $blankT $blankB $blankT
$rawEmpty = Raw '"TEST Contractor 2"' '"Test Stad2"' '""' 'true' '""'
$inEmpty = Inputs '"TEST Contractor 2"' '"Test Stad2"' '""' 'true'
$inBlank = Inputs '"TEST Contractor 2"' '"Test Stad2"' $blankT 'true'
Assert-Eval (VerifyDiff $rawBlank $inEmpty 'F') '' 'Verify passes: SharePoint returns Blank for empty fields, inputs are "" (step 8/9 scenario)'
Assert-Eval (VerifyDiff $rawEmpty $inBlank 'F') '' 'Verify passes: SharePoint returns "" , inputs are Blank'
Assert-Eval (VerifyDiff $rawBlank $inBlank 'F') '' 'Verify passes: both Blank'
Assert-Eval (VerifyDiff $rawBlank (Inputs '"  TEST Contractor 2 "' '" Test Stad2"' '"  "' 'true') 'F') '' 'Verify passes: inputs with surrounding spaces are trimmed before writing'
Assert-Eval (VerifyDiff $rawBlank (Inputs '"TEST Contractor 2"' '"Test Stad2"' '""' $blankB) 'F') '' 'Verify passes: Active blank in SharePoint and blank checkbox value (both = active)'
Assert-Eval (VerifyDiff (Raw '"TEST Contractor 2"' '"Test Stad2"' '"EMP-005"' 'true' $blankT) $inEmpty 'F') '' 'Verify passes: flow MS-019 filled EmployerCode1 and changed Modified after the create'
Assert-Eval (VerifyDiff $rawBlank (Inputs '"TEST Contractor 2"' '"Test Stad2"' '""' 'false') 'F') 'Active' 'Verify fails on Active: blank (= active) in SharePoint, written false'
Assert-Eval (VerifyDiff (Raw '"TEST Contractor 2"' '"Other"' $blankT 'true' $blankT) $inEmpty 'F') 'City' 'Verify fails and names only the differing field (City)'
Assert-Eval (VerifyDiff (Raw '"TEST Contractor 2"' '"Other"' $blankT 'true' $blankT) $inEmpty 'L') 'City' 'Notification difference list uses the field label (no values)'
Assert-Eval (VerifyDiff (Raw '"test contractor 2"' '"Test Stad2"' $blankT 'true' $blankT) $inEmpty 'F') 'Name' 'Verify on Name is exact after Trim (case is part of the written value)'
# Conflict check: loaded snapshot vs pre-read, both through the same projection
function Conflict([string]$preRaw, [string]$snapRaw) { return "With({p:$(Proj $preRaw),varEmpEdit:$(Proj $snapRaw),varEmpSaveID:7},$conflictFx)" }
Assert-Eval (Conflict $rawBlank $rawBlank) $false 'Conflict does not fire: unchanged row with blank fields'
Assert-Eval (Conflict (Raw '"TEST Contractor 2"' '"Test Stad2"' '"EMP-005"' 'true' $blankT) $rawBlank) $false 'Conflict does not fire on a flow MS-019 change (EmployerCode1 filled, Modified changed, Active blank vs true)'
Assert-Eval (Conflict $rawEmpty $rawBlank) $false 'Conflict does not fire: "" versus Blank in SharePoint'
Assert-Eval (Conflict (Raw '"TEST Contractor 2"' '"Other"' $blankT 'true' $blankT) $rawBlank) $true 'Conflict fires: another user changed City'
Assert-Eval (Conflict (Raw '"TEST Contractor 2"' '"Test Stad2"' $blankT 'false' $blankT) $rawBlank) $true 'Conflict fires: another user deactivated the contractor'
# Dirty: form inputs vs loaded snapshot (no false dirty for Blank versus "")
function Dirty([string]$snapRaw, [string]$inputs) { return "With({varEmpMode:`"Edit`",varEmpEdit:$(Proj $snapRaw),$inputs},$dirty)" }
Assert-Eval (Dirty $rawBlank $inEmpty) $false 'Not dirty: snapshot from Blank fields, inputs ""'
Assert-Eval (Dirty $rawBlank $inBlank) $false 'Not dirty: snapshot from Blank fields, inputs Blank'
Assert-Eval (Dirty $rawEmpty $inBlank) $false 'Not dirty: snapshot from "" fields, inputs Blank'
Assert-Eval (Dirty $rawBlank (Inputs '"TEST Contractor 2"' '"Test Stad2"' '"  "' 'true')) $false 'Not dirty: only spaces typed in empty fields (Save would write the same)'
Assert-Eval (Dirty $rawBlank (Inputs '"TEST Contractor 2"' '"Test Stad3"' '""' 'true')) $true 'Dirty: City changed'
Assert-Eval (Dirty $rawBlank (Inputs '"TEST Contractor 2"' '"Test Stad2"' '""' 'false')) $true 'Dirty: Active unchecked (snapshot Active blank = active)'
$newSnap = '{ID:Blank(),Name:"",Code:"",Address:"",Postalcode:"",City:"",Country:"",ContactName:"",ContactEmail:"",ContactPhone:"",Active:true}'
Assert-Eval ('With({varEmpMode:"New",varEmpEdit:' + $newSnap + ',' + (Inputs '""' '""' $blankT 'true') + '},' + $dirty + ')') $false 'Not dirty: New form untouched (inputs Blank)'
Assert-Eval ('With({varEmpMode:"New",varEmpEdit:' + $newSnap + ',' + (Inputs '"TEST Contractor 3"' '""' $blankT 'true') + '},' + $dirty + ')') $true 'Dirty: New form with a typed name'
# Diagnosability: verify mismatch in the notification (labels only) and in Trace (field names only); Patch reason in the notification only
Assert-True ($saveN.Contains((Norm 'Trace("DIAG|Contractors|VerifyMismatch",TraceSeverity.Warning,{Screen:"Contractors",ItemID:Coalesce(varEmpPatchedID,0),Rows:CountRows(colEmpVerifyRaw),Fields:varEmpVerifyDiff})'))) 'Trace DIAG|Contractors|VerifyMismatch with field names only'
Assert-True ($saveN.Contains((Norm 'Set(varEmpVerifyDiff,If(rowOk,Concat(d,F,","),"Rows"));')) -and $saveN.Contains((Norm 'Substitute(If(LangNl && !IsBlank(T.empErrVerifyFields.nl),T.empErrVerifyFields.nl,T.empErrVerifyFields.en),"{0}",Concat(d,L,", "))'))) 'Verify mismatch: technical names to Trace, labels in the notification (never values)'
Assert-True ($saveN.Contains((Norm 'Set(varEmpPatchError,true); Collect(colEmpSaveErrors,{Field:"",Message:If(LangNl && !IsBlank(T.empErrSharePoint.nl),T.empErrSharePoint.nl,T.empErrSharePoint.en) & " " & FirstError.Message});false);'))) 'Patch error: flag set, SharePoint reason (FirstError.Message) appended to the shown error only (never Trace)'
$feAll = @([regex]::Matches($screenText, 'FirstError\.Message'))
$feOk = @($feAll | Where-Object { $screenText.Substring([Math]::Max(0, $_.Index - 220), [Math]::Min(220, $_.Index)) -match 'Collect\(col\w*Errors,\{[^{}]*$' })
Assert-True ($feAll.Count -ge 5 -and $feOk.Count -eq $feAll.Count) "FirstError.Message only inside notified error collections ($($feAll.Count) uses: load errors + Patch error)"

# (14) Stale values after Refresh (TP-CONTRACTORS-01 step 12, 29-10-2026) --------------------------------------------
# (a) Every SharePoint read in a behaviour formula of scrContractors (load, pre-read, duplicate read, verify read) is
#     preceded by Refresh(<that list>) in the same branch (shared helper RefreshOrder.ps1; no forced-only Refresh left).
$beh = @{}
foreach ($p in $screenProps.Keys) { if ($p -like 'On*') { $beh["$screenName.$p"] = [string]$screenProps[$p] } }
Get-BehaviourFormulas $doc['Screens'][$screenName]['Children'] $screenName $beh
$spReads = @()
foreach ($k in ($beh.Keys | Sort-Object)) { foreach ($r in (Test-RefreshBeforeReads $beh[$k])) { $spReads += $r; Assert-True ($r.Status -eq 'Refreshed') "$k : read of $($r.Source) (formula line $($r.Line)) preceded by Refresh($($r.Source)) in the same branch [$($r.Status)]" } }
Assert-True (@($spReads | Where-Object Source -eq 'Employers').Count -eq 4 -and @($spReads | Where-Object Source -eq 'Workers').Count -eq 1) "SharePoint reads on scrContractors: 4 x Employers (load, pre-read, duplicate, verify), 1 x Workers (load)"
# Self-test of the helper on synthetic formulas (forced-only Refresh, other branch, error gate, Concurrent sibling)
Assert-True ((Test-RefreshBeforeReads '=IfError(Refresh(Employers),false);ClearCollect(c,Sort(Employers,Title))')[0].Status -eq 'Refreshed') 'Helper: Refresh then read = Refreshed'
Assert-True ((Test-RefreshBeforeReads '=If(Coalesce(f,false),IfError(Refresh(Employers),false));If(x,a,ClearCollect(c,Sort(Employers,Title)))')[0].Status -eq 'Missing') 'Helper: forced-only Refresh does not cover an unconditional (first) load'
Assert-True ((Test-RefreshBeforeReads '=If(x,IfError(Refresh(Employers),false),ClearCollect(c,Filter(Employers,ID=v)))')[0].Status -eq 'Missing') 'Helper: Refresh in the other If branch does not count'
Assert-True ((Test-RefreshBeforeReads '=If(IsEmpty(e),IfError(Refresh(Employers),Collect(e,{M:1});false));If(IsEmpty(e),ClearCollect(c,Filter(Employers,ID=v)))')[0].Status -eq 'Refreshed') 'Helper: error-gated Refresh covers a read gated by the same empty error collection'
Assert-True ((Test-RefreshBeforeReads '=If(IsEmpty(e),IfError(Refresh(Employers),false));If(!IsEmpty(e),ClearCollect(c,Filter(Employers,ID=v)))')[0].Status -eq 'Missing') 'Helper: a negated error gate does not count'
Assert-True ((Test-RefreshBeforeReads '=Concurrent(IfError(Refresh(Workers),false),ClearCollect(c,ForAll(Workers As w,{ID:w.ID})))')[0].Status -eq 'Missing') 'Helper: Refresh in a sibling Concurrent branch does not count'
Assert-True ((Test-RefreshBeforeReads '=ClearCollect(c,Sort(Employers,Title))')[0].Status -eq 'Missing') 'Helper: read without any Refresh = Missing'
# (c) Form shows the reloaded values: inputs keep Default = varEmpEdit (classic TextInput, template text 2.3.2 has Default
#     and a Reset property; the Reset property is not used). After a load or a verified save the inputs are reset again in a
#     separate behaviour formula (Select of the hidden btnEmpFormReset, queued after the current formula), so the reset never
#     depends on a Default that is recalculated inside the same formula as Set(varEmpEdit).
Assert-True ($idx.ContainsKey('btnEmpFormReset') -and $idx['btnEmpFormReset']['Control'] -eq 'Classic/Button@2.2.0' -and (Get-Prop 'btnEmpFormReset' 'Visible') -eq '=false') 'btnEmpFormReset exists (hidden Classic/Button@2.2.0, like btnEmpLoad)'
$fr = Get-Prop 'btnEmpFormReset' 'OnSelect'
Assert-True ($fr.StartsWith('=If(varEmpLoadState="Loaded" && IsEmpty(colEmpLoadErrors) && !Coalesce(varEmpBusy,false) && !Coalesce(varEmpSaving,false) && !Coalesce(varEmpSaveFailed,false),')) 'Form reset only when Loaded, no load errors, not busy/saving, no failed save (kept input after a failed save stays)'
Assert-True ($fr.Contains($reset)) 'Form reset resets all 8 inputs and refills the Active switch draft from varEmpEdit'
Assert-True ($fr.Replace($draftSet, '') -notmatch '\b(Patch|Refresh|Collect|ClearCollect|Remove|RemoveIf|Clear|Set|UpdateContext|Select|Navigate)\(' -and $fr -notmatch '\.Run\(') 'Form reset is local only (no mutation, no variable change except the switch draft refill, no further Select: no cycle)'
Assert-True (([regex]::Matches($screenText, 'Select\(btnEmpFormReset\)')).Count -eq 2) 'btnEmpFormReset selected exactly twice (end of loader, verified save)'
$iBusyOff = $load.LastIndexOf('Set(varEmpForceRefresh,false); Set(varEmpBusy,false);')
Assert-True ($iBusyOff -gt 0 -and $load.IndexOf('If(varEmpLoadState="Loaded",Select(btnEmpFormReset))') -gt $iBusyOff) 'Loader selects the form reset at its end, after busy is cleared, only when Loaded'
$iSaveReset = $saveN.IndexOf('Select(btnEmpFormReset)')
Assert-True ($iSaveReset -gt $iLocal -and $iSaveReset -lt $saveN.IndexOf('varEmpSaveWrites=0,') -and $iSaveReset -gt $saveN.IndexOf((Norm $reset), $iLocal)) 'Verified save selects the form reset after the snapshot update and in-formula resets (success branch only)'
foreach ($k in $inputMap.Keys) { Assert-True (!$idx[$k]['Properties'].ContainsKey('Reset')) "$k has no Reset property (single approach: Reset() calls)" }
# (d) Diagnostics: load time in the status message, SharePoint Modified of the selected item (display only)
Assert-True ($load.Contains('Set(varEmpLoadedAt,Now());') -and $load.Contains('Substitute(Substitute(If(LangNl && !IsBlank(T.empMsgLoaded.nl),T.empMsgLoaded.nl,T.empMsgLoaded.en),"{0}",Text(CountRows(colAdminEmployers))),"{1}",Text(varEmpLoadedAt,"hh:mm:ss"))')) 'Loaded message shows the number of contractors and the load time (hh:mm:ss)'
Assert-True ($load.IndexOf('Set(varEmpLoadedAt,Now());') -gt $iGate) 'Load time set only in the successful-load branch'
Assert-True (([regex]::Matches($screenText, 'Set\(varEmpLoadedAt,')).Count -eq 1) 'varEmpLoadedAt set only by the loader'
Assert-Eval 'Text(DateTime(2026,10,29,21,5,7),"hh:mm:ss")' '21:05:07' 'Time format hh:mm:ss is 24-hour (interpreter)'
Assert-True ($formulas -match 'empMsgLoaded:\s*\{en:\s*"[^"]*\{0\}[^"]*\{1\}' -and $formulas -match 'empLastChanged:\s*\{en:\s*"Last changed in SharePoint: \{0\}"') 'T: empMsgLoaded has {0} (count) and {1} (time); empLastChanged = "Last changed in SharePoint: {0}"'
Assert-True ($load.Contains('ClearCollect(colPendingEmpModified,ForAll(colPendingEmpRaw As emp,{ID:emp.ID,Modified:emp.Modified}));') -and $loadN.Contains((Norm 'ClearCollect(colEmpModified,colPendingEmpModified);')) -and $loadN.IndexOf((Norm 'ClearCollect(colEmpModified,colPendingEmpModified);')) -gt $iGate) 'Modified staged from the same load read and published only after a successful load'
Assert-True ($proj -notmatch 'Modified') 'The shared projection (snapshot varEmpEdit, pre-read, duplicate, verify) has no Modified field'
$modUses = @($all.Keys | Where-Object { $all[$_] -match 'Modified' } | Sort-Object)
Assert-True (($modUses -join ',') -ceq 'btnEmpLoad.OnSelect,btnEmpSave.OnSelect,lblEmpMetrics.Y,lblEmpModified.Text') "Modified used only in the loader, the save display update, lblEmpModified.Text and the height carrier lblEmpMetrics.Y (reads lblEmpModified.Y) ($($modUses -join ', '))"
foreach ($k in @('btnEmpSave.DisplayMode', 'btnEmpRefresh.DisplayMode', 'btnEmpDiscard.DisplayMode', 'btnEmpHome.DisplayMode', 'btnEmpNew.DisplayMode', 'galEmpList.DisplayMode')) { Assert-True ($all[$k] -notmatch 'Modified|colEmpModified') "$k guard does not use Modified" }
Assert-True ($tableFx -notmatch 'Modified|colEmpModified' -and $conflictFx -notmatch 'Modified|colEmpModified' -and $dirty -notmatch 'Modified') 'Modified never in verify, conflict or dirty comparison'
$modFx = (Get-Prop 'lblEmpModified' 'Text').TrimStart('=')
Assert-True ($idx['lblEmpModified']['Control'] -eq 'Label@2.5.1' -and $modFx.Contains('LookUp(colEmpModified,ID=varEmpSelectedID).Modified') -and $modFx -notmatch "\b(Employers|Filter)\b") 'lblEmpModified: read-only label from the local copy (no SharePoint call)'
$modFix = 'LangNl:false,T:' + $tRec + ',colEmpModified:Table({ID:7,Modified:DateTime(2026,10,29,21,5,0)},{ID:8,Modified:DateTime(2026,1,2,9,4,0)})'
Assert-Eval ('With({' + $modFix + ',varEmpMode:"Edit",varEmpSelectedID:7},' + $modFx + ')') 'Last changed in SharePoint: 29-10-2026 21:05' 'Modified line (Edit, item 7): dd-mm-yyyy hh:mm'
Assert-Eval ('With({' + $modFix + ',varEmpMode:"Edit",varEmpSelectedID:8},' + $modFx + ')') 'Last changed in SharePoint: 02-01-2026 09:04' 'Modified line (Edit, item 8): leading zeros, 24-hour'
Assert-Eval ('With({' + $modFix + ',varEmpMode:"New",varEmpSelectedID:Blank()},' + $modFx + ')') '' 'Modified line empty for New'
Assert-Eval ('With({' + $modFix + ',varEmpMode:"Edit",varEmpSelectedID:9},' + $modFx + ')') '' 'Modified line empty when the item has no loaded Modified'

# (15) Messages only via the shared admin message bar (A1, 30-10-2026; spec "Message model", replaces Notify on admin screens) -------
# Global state shared by the admin screens: varAdmMsgKind ("" | "Error" | "Warning" | "Success"), varAdmMsgHead (bold head word, T admHead*),
# varAdmMsgBody (the former notification text). One message at a time: every message sets kind + head + body; Close (icoEmpMsgClose) and
# OnVisible clear all three. Kind mapping as DECISIONS.md H17: Error = red (blocked, load failed, nothing saved, save not confirmed),
# Warning = amber (empWarn* texts: live switch Active on -> off, verified save with a warning), Success = green (loaded, saved, discarded).
# No timeouts (no Timer template): a message stays until it is closed or replaced. An invalid field is still shown by a red #DB1E28 border.
foreach ($gone in @('lblEmpStatus', 'lblEmpErrors')) { Assert-True (!$idx.ContainsKey($gone)) "$gone removed (no status line; messages only in the message bar)" }
Assert-True ($srcAll -notmatch '\bvarEmpMsg(Error)?\b') 'varEmpMsg/varEmpMsgError no longer exist in Src'
Assert-True ($screenText -notmatch '\bNotify\(' -and $screenText -notmatch 'NotificationType\.') 'No Notify() and no NotificationType on scrContractors'
$msgProps = @($all.Keys | Where-Object { $_ -notmatch '\.On\w+$' -and $all[$_] -match '\.Message\b|\bT\.(emp(Msg|Err|Warn)|admHead)\w*\.' } | Sort-Object)
Assert-True ($msgProps.Count -eq 0) "No non-behaviour property composes a message text; the bar only shows the variables ($($msgProps -join ', '))"
function TT([string]$k) { return "If(LangNl && !IsBlank(T.$k.nl),T.$k.nl,T.$k.en)" }
function Triple([string]$kind, [string]$head, [string]$body) { return 'Set(varAdmMsgKind,"' + $kind + '"); Set(varAdmMsgHead,' + (TT $head) + '); Set(varAdmMsgBody,' + $body + ')' }
function Get-SetArg([string]$text, [int]$parenAt, [string]$var) { $c = Get-Balanced $text $parenAt; return @($c, $c.Substring($var.Length + 2, $c.Length - $var.Length - 3)) }
$msgs = @()
foreach ($k in ($all.Keys | Sort-Object)) {
    $fx = $all[$k]
    foreach ($m in [regex]::Matches($fx, '\bSet\(varAdmMsgKind,')) {
        $kc = Get-SetArg $fx ($m.Index + 3) 'varAdmMsgKind'
        $rest = $fx.Substring($m.Index + 3 + $kc[0].Length)
        $mh = [regex]::Match($rest, '^;\s*Set\(varAdmMsgHead,')
        Assert-True ($k -match '\.On\w+$' -and $mh.Success) "$k : Set(varAdmMsgKind,$($kc[1])) in a behaviour formula, directly followed by Set(varAdmMsgHead,...)"
        $hc = Get-SetArg $rest ($mh.Index + $mh.Length - 'varAdmMsgHead,'.Length - 1) 'varAdmMsgHead'
        $rest2 = $rest.Substring($mh.Index + $mh.Length - 'varAdmMsgHead,'.Length - 1 + $hc[0].Length)
        $mb = [regex]::Match($rest2, '^;\s*Set\(varAdmMsgBody,')
        Assert-True $mb.Success "$k : Set(varAdmMsgHead,...) directly followed by Set(varAdmMsgBody,...)"
        $bc = Get-SetArg $rest2 ($mb.Index + $mb.Length - 'varAdmMsgBody,'.Length - 1) 'varAdmMsgBody'
        $msgs += [pscustomobject]@{ Key = $k; Pos = $m.Index; Kind = $kc[1].Trim(); Head = $hc[1].Trim(); Body = $bc[1].Trim() }
    }
}
foreach ($v in @('varAdmMsgKind', 'varAdmMsgHead', 'varAdmMsgBody')) { Assert-True (([regex]::Matches($screenText, "\bSet\($v,")).Count -eq $msgs.Count) "Set($v,...) only inside a kind/head/body triple ($($msgs.Count) triples)" }
$warnKeys = @('empWarnActiveWorkers', 'empWarnWorkersRefresh')
$successKeys = @('empMsgLoaded', 'empMsgSavedRename', 'empMsgDiscarded')
$headsByKind = @{ '"Error"' = @('admHeadNotSaved', 'admHeadNotLoaded', 'admHeadBlocked'); '"Warning"' = @('admHeadAttention'); '"Success"' = @('admHeadLoaded', 'admHeadSaved', 'admHeadDiscarded') }
$kinds = @{}
foreach ($c in $msgs) {
    $kinds[$c.Kind] = 1 + [int]$kinds[$c.Kind]
    if ($c.Kind -eq '""') {
        Assert-True ($c.Head -eq '""' -and $c.Body -eq '""' -and $c.Key -in @('icoEmpMsgClose.OnSelect', 'scrContractors.OnVisible')) "$($c.Key) : clear (kind/head/body all empty) only in Close and OnVisible"
        continue
    }
    Assert-True ($headsByKind.ContainsKey($c.Kind)) "$($c.Key) : kind $($c.Kind) is Error, Warning or Success"
    $hm = [regex]::Match($c.Head, '^If\(LangNl && !IsBlank\(T\.(admHead\w+)\.nl\),T\.\1\.nl,T\.\1\.en\)$')
    Assert-True ($hm.Success -and $hm.Groups[1].Value -in $headsByKind[$c.Kind]) "$($c.Key) : $($c.Kind) head from T ($($hm.Groups[1].Value)) is one of $($headsByKind[$c.Kind] -join '/')"
    $head = $hm.Groups[1].Value
    $bk = @([regex]::Matches($c.Body, '\bT\.(\w+)\.en\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $lbl = "$($c.Key) : $($c.Kind)/$head body (T: $($bk -join ','))"
    switch ($c.Kind) {
        '"Error"' { Assert-True (@($bk | Where-Object { $_ -in $warnKeys -or $_ -in $successKeys }).Count -eq 0) "$lbl has no warning or success text" }
        '"Warning"' { Assert-True (@($bk | Where-Object { $_ -in $warnKeys }).Count -ge 1 -and @($bk | Where-Object { $_ -notin ($warnKeys + 'empMsgSavedRename' + 'admMsgSavedPrefix') }).Count -eq 0) "$lbl carries a warning text (empWarn*), nothing else except the Saved. prefix and the rename note" }
        '"Success"' { Assert-True (@($bk | Where-Object { $_ -notin $successKeys }).Count -eq 0 -and @($bk | Where-Object { $_ -in $warnKeys }).Count -eq 0) "$lbl has only success texts, no warning" }
    }
    switch ($head) {
        'admHeadBlocked' { Assert-True ($c.Body -ceq (TT 'empMsgActionBlocked') -or $c.Body -ceq (TT 'empMsgReloadBlocked')) "$lbl = action blocked / reload blocked" }
        'admHeadNotLoaded' { Assert-True ($bk -contains 'empMsgLoadFailed' -and $c.Body.Contains('First(colEmpLoadErrors).Message')) "$lbl = load failed + first load error" }
        'admHeadLoaded' { Assert-True ($bk -contains 'empMsgLoaded') "$lbl = loaded count/time" }
        'admHeadDiscarded' { Assert-True ($c.Body -ceq (TT 'empMsgDiscarded')) "$lbl = changes discarded" }
        'admHeadAttention' {
            if ($c.Key -eq 'btnEmpSave.OnSelect') { Assert-True ($c.Body.StartsWith('Trim(' + (TT 'admMsgSavedPrefix') + ' & " " & ')) "$lbl = verified save with a warning: body starts with Saved." }
            else { Assert-True (($bk -join ',') -ceq 'empWarnActiveWorkers') "$lbl = active-worker warning only" }
        }
        'admHeadNotSaved' { Assert-True ($c.Body.Contains('First(colEmpSaveErrors).Message')) "$lbl = first save error (+n more)" }
        'admHeadSaved' { Assert-True ($c.Key -eq 'btnEmpSave.OnSelect') "$lbl only after a verified save" }
    }
}
Assert-True ($kinds['"Error"'] -eq 9 -and $kinds['"Warning"'] -eq 2 -and $kinds['"Success"'] -eq 3 -and $kinds['""'] -eq 2) "Message kinds: 9 x Error, 2 x Warning (live switch + save), 3 x Success (loaded, saved, discarded), 2 x clear ($(($kinds.Keys | Sort-Object | ForEach-Object { "$_=$($kinds[$_])" }) -join ' '))"
$expMsg = [ordered]@{ 'btnEmpActiveSwitch.OnSelect' = 1; 'btnEmpDiscard.OnSelect' = 2; 'btnEmpLoad.OnSelect' = 3; 'btnEmpNew.OnSelect' = 1; 'btnEmpRefresh.OnSelect' = 1; 'btnEmpSave.OnSelect' = 5; 'galEmpList.OnSelect' = 1; 'icoEmpMsgClose.OnSelect' = 1; 'scrContractors.OnVisible' = 1 }
$gotMsg = (($msgs | Group-Object Key | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ';')
Assert-True ($gotMsg -ceq (($expMsg.Keys | Sort-Object | ForEach-Object { "$_=$($expMsg[$_])" }) -join ';')) "Messages per formula as expected: $gotMsg"
$blockedN = Norm (',' + (Triple 'Error' 'admHeadBlocked' (TT 'empMsgActionBlocked')) + ')')
foreach ($ctl in @('btnEmpSave', 'btnEmpNew', 'btnEmpRefresh', 'btnEmpDiscard', 'galEmpList')) { Assert-True ((Norm (Get-Prop $ctl 'OnSelect')).EndsWith($blockedN)) "$ctl : the guard's else branch shows 'Blocked.' + action blocked as an error (no mutation)" }
Assert-True ($load.Contains((Triple 'Error' 'admHeadBlocked' (TT 'empMsgReloadBlocked')) + ',')) 'Loader: reload over unsaved input shows Blocked. + reload blocked (error) and does nothing else'
foreach ($k in @('btnEmpLoad.OnSelect', 'btnEmpSave.OnSelect', 'btnEmpActiveSwitch.OnSelect')) { foreach ($m in [regex]::Matches($all[$k], '\bTrace\(')) { Assert-True ((Get-Balanced $all[$k] ($m.Index + 5)) -notmatch 'varAdmMsg') "$k : no message variable inside a Trace" } }
# Texts (T): head words, unchanged message texts; the body no longer repeats the head word "Saved."
$fixTexts = [ordered]@{ empErrNameRequired = 'Fix: Contractor Name empty'; empErrEmail = 'Fix: Contact Email invalid'; empErrPhone = 'Fix: Contact Phone invalid'; empErrTooLong = 'Fix: {0} too long'; empErrDuplicate = 'Fix: Contractor Name already exists'
    admHeadNotSaved = 'Not saved.'; admHeadNotLoaded = 'Not loaded.'; admHeadBlocked = 'Blocked.'; admHeadAttention = 'Attention.'; admHeadSaved = 'Saved.'; admHeadLoaded = 'Loaded.'; admHeadDiscarded = 'Discarded.'; admMsgClose = 'Close message'
    empMsgSavedRename = 'The new name also shows on past hours.' }
foreach ($k in $fixTexts.Keys) { Assert-True ($formulas.Contains("$($k): {en: ""$($fixTexts[$k])"", nl: """"}")) "T.$k = '$($fixTexts[$k])'" }
Assert-True ($formulas -notmatch '\bempMsgSaved:' -and $formulas -notmatch 'en: "(Saved|Not saved)\.\s') 'T.empMsgSaved removed; no body text starts with the head word "Saved." / "Not saved."'
$conflictMsg = 'Changed in SharePoint by someone else. Nothing saved. Click Discard, then Refresh.'
Assert-True ($formulas.Contains("empErrConflict: {en: ""$conflictMsg"", nl: """"}")) 'T.empErrConflict exact text'
# Keys delivered by powerfx-logic for the form header that powerfx-ui builds next (30-10-2026); remove a key from this list once the header uses it.
$pendingUiT = @('prjNoSelection')
foreach ($k in $pendingUiT) { Assert-True ($tKeys -ccontains $k) "T.$k exists (header 'no record selected')"; if ($used -cnotcontains $k) { Write-Output "WARN T.$k not yet used in Src (pending powerfx-ui header)" } }
$unusedT = @($tKeys | Where-Object { $_ -cnotin $used -and $_ -cnotin $pendingUiT })
Assert-True ($unusedT.Count -eq 0) "No unused T keys ($($unusedT -join ', '))"
function Msg([string]$fixture, [string]$fx) { return "With({LangNl:false,T:$tRec},With({$fixture},$fx))" }
$saveMsg = @($msgs | Where-Object Key -eq 'btnEmpSave.OnSelect' | Sort-Object Pos)
$loadMsg = @($msgs | Where-Object Key -eq 'btnEmpLoad.OnSelect' | Sort-Object Pos)
Assert-True ((($saveMsg | ForEach-Object { $_.Kind }) -join ',') -ceq '"Warning","Success","Error","Error","Error"') 'Save messages in order: warning, success, zero-write error, failed-save error, blocked'
Assert-True ($saveN.Contains('varEmpSaveWrites=0,Set(varAdmMsgKind,"Error");') -and $saveN.Contains('Set(varEmpSaveFailed,true);Set(varEmpLoadState,"Failed");Set(varAdmMsgKind,"Error");')) 'Save outcome: zero-write error directly in the varEmpSaveWrites=0 branch, failed-save error directly after SaveFailed/Failed'
# Verified save: one message, amber (Warning) when there is a warning, else green (Success); head "Saved." in both
$outHead = 'If(varEmpSaveWarnWorkers>0 || varEmpSaveWorkersRefreshFailed,'
$iOutcome = $save.IndexOf($outHead)
Assert-True ($iOutcome -gt 0 -and ([regex]::Matches($save, [regex]::Escape($outHead))).Count -eq 1) 'Verified save: outcome If(<warning>, Warning, Success) exists once'
$outCall = Get-Balanced $save ($iOutcome + 2)
$outArgs = Split-Args $outCall.Substring(1, $outCall.Length - 2)
Assert-True ($outArgs.Count -eq 3 -and $outArgs[1].Trim().StartsWith('Set(varAdmMsgKind,"Warning"); Set(varAdmMsgHead,' + (TT 'admHeadAttention') + '); Set(varAdmMsgBody,Trim(' + (TT 'admMsgSavedPrefix') + ' & " " & ') -and $outArgs[2].Trim().StartsWith('Set(varAdmMsgKind,"Success"); Set(varAdmMsgHead,' + (TT 'admHeadSaved') + ');')) 'Verified save: exactly one message per outcome (warning: amber, head "Attention.", body "Saved. ..."; else green, head "Saved.")'
$iOutN = $saveN.IndexOf((Norm $outHead))
Assert-True ($iOutN -gt $iLocal -and $iOutN -gt $saveN.IndexOf('If(varEmpSaveRenamed,IfError(Refresh(Workers),') -and $iOutN -lt $saveN.IndexOf('Select(btnEmpFormReset)') -and $iOutN -lt $saveN.IndexOf('varEmpSaveWrites=0,')) 'Verified save: outcome message after the Workers refresh (its result is known), before the form reset, success branch only'
$condFx = $outArgs[0].Trim()
Assert-Eval "With({varEmpSaveWarnWorkers:0,varEmpSaveWorkersRefreshFailed:false},$condFx)" $false 'No warning: green Success'
Assert-Eval "With({varEmpSaveWarnWorkers:2,varEmpSaveWorkersRefreshFailed:false},$condFx)" $true 'Active workers on deactivation: amber Warning'
Assert-Eval "With({varEmpSaveWarnWorkers:0,varEmpSaveWorkersRefreshFailed:true},$condFx)" $true 'Workers refresh failed after rename: amber Warning'
Assert-Eval (Msg 'x:0' $saveMsg[0].Head) 'Attention.' 'Save-with-warning message head: Attention.'
Assert-Eval (Msg 'varEmpSaveRenamed:false,varEmpSaveWarnWorkers:2,varEmpSaveWorkersRefreshFailed:false' $saveMsg[0].Body) 'Saved. 2 active worker(s) still have this contractor.' 'Saved. + active-worker warning in one amber message (no leading space)'
Assert-Eval (Msg 'varEmpSaveRenamed:false,varEmpSaveWarnWorkers:0,varEmpSaveWorkersRefreshFailed:true' $saveMsg[0].Body) 'Saved. Workers not refreshed: open Project / team and click Refresh.' 'Saved. + Workers-refresh warning'
Assert-Eval (Msg 'varEmpSaveRenamed:true,varEmpSaveWarnWorkers:0,varEmpSaveWorkersRefreshFailed:true' $saveMsg[0].Body) 'Saved. The new name also shows on past hours. Workers not refreshed: open Project / team and click Refresh.' 'Saved. + rename + Workers-refresh warning in one amber message'
Assert-Eval (Msg 'varEmpSaveRenamed:true,varEmpSaveWarnWorkers:3,varEmpSaveWorkersRefreshFailed:true' $saveMsg[0].Body) 'Saved. The new name also shows on past hours. 3 active worker(s) still have this contractor. Workers not refreshed: open Project / team and click Refresh.' 'Both warnings in one amber message'
Assert-Eval (Msg 'varEmpSaveRenamed:false' $saveMsg[1].Body) '' 'Green message without rename: only the head "Saved."'
Assert-Eval (Msg 'varEmpSaveRenamed:true' $saveMsg[1].Body) 'The new name also shows on past hours.' 'Green message with rename: Saved. + rename note'
Assert-Eval (Msg 'colEmpSaveErrors:Table({Field:"Name",Message:T.empErrNameRequired.en},{Field:"",Message:"y"})' $saveMsg[2].Body) 'Fix: Contractor Name empty (+1 more)' 'Zero-write error: Not saved. + first error (+n more)'
Assert-Eval (Msg 'varEmpSaveMode:"New",colEmpSaveErrors:Table({Field:"",Message:T.empErrPatch.en})' $saveMsg[3].Body) 'Save not confirmed by SharePoint. Maybe created: click Discard, then search the name before retrying.' 'Failed-save error (New): first error + SaveFailedNew text'
Assert-Eval (Msg 'varEmpSaveMode:"Edit",colEmpSaveErrors:Table({Field:"",Message:T.empErrVerify.en})' $saveMsg[3].Body) 'Save not confirmed: read-back failed. Check SharePoint, then click Discard.' 'Failed-save error (Edit): first error + SaveFailed text'
Assert-True ((($loadMsg | ForEach-Object { $_.Kind }) -join ',') -ceq '"Error","Success","Error"') 'Loader messages in order: reload blocked, loaded, load failed'
Assert-Eval (Msg 'colAdminEmployers:Table({ID:1},{ID:2},{ID:3}),varEmpLoadedAt:DateTime(2026,10,29,21,5,7)' $loadMsg[1].Body) '3 contractors loaded at 21:05:07' 'Load success message: count and time'
Assert-Eval (Msg 'colEmpLoadErrors:Table({Message:T.empErrLoadEmployers.en & " " & "Network error"},{Message:T.empErrLimitWorkers.en})' $loadMsg[2].Body) 'Loading failed. Click Refresh. Contractors not read: Network error (+1 more)' 'Load failure message: first error + (+n more)'
Assert-True ($load.IndexOf('Set(varEmpLoadedAt,Now());') -lt $load.IndexOf('Set(varAdmMsgKind,"Success")') -and $load.IndexOf('Set(varAdmMsgKind,"Success")') -gt $load.IndexOf('If(IsEmpty(colEmpLoadErrors),') -and $load.IndexOf('Set(varAdmMsgKind,"Success")') -lt $load.IndexOf('Set(varEmpLoadState,"Failed")')) 'Loaded message only in the successful-load branch, after the load time'
# New: no instruction message (Eddy 29-10-2026); the only message in btnEmpNew is the blocked else branch
$newMsg = @($msgs | Where-Object Key -eq 'btnEmpNew.OnSelect')
Assert-True ($newMsg.Count -eq 1 -and $newMsg[0].Kind -eq '"Error"' -and $newMsg[0].Body -ceq (TT 'empMsgActionBlocked')) 'btnEmpNew: no message in the success path (only the blocked error)'
Assert-True ($srcAll -notmatch '\bempMsgNew\b') 'T.empMsgNew removed (no instruction message)'

# Message bar (step 3a): cmpEmpMsgBar = cmpMessageBar instance directly under the title bar at full title width; Height = BarHeight output (40 with a message, else 0).
$mbi = $idx['cmpEmpMsgBar']
Assert-True ($mbi['Control'] -eq 'CanvasComponent' -and $mbi['ComponentName'] -eq 'cmpMessageBar') 'cmpEmpMsgBar is a cmpMessageBar instance'
$cmpBarExp = [ordered]@{ X = '=cmpEmpTitle.X'; Y = '=cmpEmpTitle.Y+cmpEmpTitle.Height'; Width = '=cmpEmpTitle.Width'; Height = '=cmpEmpMsgBar.BarHeight'; Kind = '=varAdmMsgKind'; Head = '=varAdmMsgHead'; Body = '=varAdmMsgBody'; CloseLabel = ('=' + (TT 'admMsgClose')) }
foreach ($k in $cmpBarExp.Keys) { Assert-True ([string]$mbi['Properties'][$k] -ceq $cmpBarExp[$k]) "cmpEmpMsgBar.$k = $($cmpBarExp[$k])" }
$kids3 = @($doc['Screens'][$screenName]['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True ($kids3[0] -eq 'cmpEmpTitle' -and $kids3[1] -eq 'cmpEmpMsgBar') 'Children: cmpEmpTitle, then cmpEmpMsgBar directly under it'
$mbDef = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'Component/cmpMessageBar.pa.yaml')))['ComponentDefinitions']['cmpMessageBar']
$mbIdx = @{}; Index-Controls $mbDef['Children'] $mbIdx
$barHeightFx = ([string]$mbDef['Properties']['BarHeight']).TrimStart('=')
$cmpBarFillFx = ([string]$mbIdx['recCmpMsgFill']['Properties']['Fill']).TrimStart('=') -replace 'ColorValue\("(#[0-9A-F]{6})"\)', '"$1"' -replace 'Color\.Transparent', '"none"' -replace 'cmpMessageBar\.Kind', 'varAdmMsgKind'
$textColFx = '=If(varAdmMsgKind="Error",Color.White,ColorValue("#000F41"))'  # shared with the Projects section (hand-built message bar)
$cmpTextColFx = '=If(cmpMessageBar.Kind="Error",Color.White,ColorValue("#000F41"))'
foreach ($case in @(@('"Error"', '#DB1E28', 'white', $true), @('"Warning"', '#F29400', '#000F41', $true), @('"Success"', '#1AFF80', '#000F41', $true), @('""', 'none', '#000F41', $false), @('If(false,"x")', 'none', '#000F41', $false), @('"Other"', 'none', '#000F41', $false))) {
    Assert-Eval "With({varAdmMsgKind:$($case[0])},$cmpBarFillFx)" $case[1] "Bar fill for kind $($case[0]) = $($case[1])"
    Assert-Eval "With({cmpMessageBar:{Kind:$($case[0])}},$barHeightFx)" $(if ($case[3]) { 40 } else { 0 }) "BarHeight for kind $($case[0])"
    Assert-Eval "With({cmpMessageBar:{Kind:$($case[0])}},$($cmpTextColFx.TrimStart('=').Replace('Color.White', '"white"').Replace('ColorValue("#000F41")', '"#000F41"')))" $case[2] "Bar text colour for kind $($case[0]) = $($case[2])"
}
Assert-True ((Get-Prop 'icoEmpMsgClose' 'OnSelect') -ceq '=Set(varAdmMsgKind,""); Set(varAdmMsgHead,""); Set(varAdmMsgBody,"")') 'cmpEmpMsgBar.OnClose clears kind, head and body'
Assert-True ($mbIdx['icoCmpMsgClose']['Properties']['Icon'] -ceq '=Icon.Cancel' -and $mbIdx['icoCmpMsgClose']['Properties']['OnSelect'] -ceq '=cmpMessageBar.OnClose()' -and $mbIdx['icoCmpMsgClose']['Properties']['Color'] -ceq $cmpTextColFx) 'Component close icon: Icon.Cancel, raises OnClose, white on red / #000F41 on amber and green'
Assert-True ($vis.StartsWith('=Set(varAdmMsgKind,""); Set(varAdmMsgHead,""); Set(varAdmMsgBody,"");') -and $vis.IndexOf('Set(varAdmMsgKind,"")') -lt $vis.IndexOf('Select(btnEmpLoad)')) 'OnVisible clears the message first, before the load'
$cmpBarReaders = @($all.Keys | Where-Object { $_ -notmatch '\.On\w+$' -and $all[$_] -match '\bvarAdmMsg(Kind|Head|Body)\b' } | ForEach-Object { ($_ -split '\.')[0] } | Sort-Object -Unique)
Assert-True (($cmpBarReaders -join ',') -ceq 'cmpEmpMsgBar') "Message variables are only displayed by the bar instance ($($cmpBarReaders -join ', '))"

# Active switch (btnEmpActiveSwitch): same guard as the former checkbox, toggles varEmpActiveDraft, live amber warning only on -> off
$swDm = Get-Prop 'btnEmpActiveSwitch' 'DisplayMode'; $swSuffix = ',DisplayMode.Edit,DisplayMode.Disabled)'
Assert-True ($swDm -ceq ('=If(' + $fieldEnabled.Substring(1) + ',DisplayMode.Edit,DisplayMode.Disabled)') -and $swDm.StartsWith('=If(') -and $swDm.EndsWith($swSuffix)) 'Switch DisplayMode = the form-input guard of the former checkbox (Loaded, no load errors, not busy/saving/SaveFailed, New/Edit; else Disabled)'
$swGuard = $swDm.Substring(4, $swDm.Length - 4 - $swSuffix.Length)
$sw = Get-Prop 'btnEmpActiveSwitch' 'OnSelect'
Assert-True ($sw.StartsWith('=If(' + $swGuard + ',')) 'Switch OnSelect starts with the same guard as its DisplayMode (fail-closed)'
$swFx = $sw.TrimStart('=')
$swCall = Get-Balanced $swFx 2
$swArgs = Split-Args $swCall.Substring(1, $swCall.Length - 2)
Assert-True ($swArgs.Count -eq 2 -and $swArgs[1].Trim().StartsWith('Set(varEmpActiveDraft,!Coalesce(varEmpActiveDraft,true));')) 'Switch: toggle first, no else branch (a blocked click does nothing, like the former checkbox in View mode)'
$liveCount = 'CountIf(colEmpWorkers,EmployerID=varEmpSelectedID && Coalesce(WorkerActive,true))'
$liveGuard = 'Coalesce(varEmpMode,"")="Edit" && !IsBlank(varEmpSelectedID) && varEmpLoadState="Loaded" && IsEmpty(colEmpLoadErrors) && !Coalesce(varEmpBusy,false) && !Coalesce(varEmpSaving,false) && !Coalesce(varEmpSaveFailed,false) && Coalesce(varEmpEdit.Active,true) && ' + $liveCount + '>0'
$iLive = $swFx.IndexOf('If(!varEmpActiveDraft && ' + $liveGuard + ',')
Assert-True ($iLive -gt $swFx.IndexOf('Set(varEmpActiveDraft,!Coalesce(varEmpActiveDraft,true));')) 'Live warning after the toggle, only when the switch went on -> off (!varEmpActiveDraft), with the former OnUncheck guard unchanged'
$liveCall = Get-Balanced $swFx ($iLive + 2)
$liveArgs = Split-Args $liveCall.Substring(1, $liveCall.Length - 2)
$liveMsg = @($msgs | Where-Object Key -eq 'btnEmpActiveSwitch.OnSelect')
Assert-True ($liveArgs.Count -eq 2 -and $liveMsg.Count -eq 1 -and $liveMsg[0].Kind -eq '"Warning"' -and $liveMsg[0].Head -ceq (TT 'admHeadAttention') -and $liveArgs[1].Trim().StartsWith('Set(varAdmMsgKind,"Warning")')) 'Live warning: amber (Warning), head Attention., inside the on -> off condition only'
Assert-True ($sw -notmatch '\b(Patch|Refresh|Collect|ClearCollect|Remove|RemoveIf|Clear|UpdateContext|Select|Navigate|Reset)\(' -and $sw -notmatch '\.Run\(' -and $sw -notmatch '\b(Employers|Workers)\b' -and @([regex]::Matches($sw, '\bSet\((\w+),') | Where-Object { $_.Groups[1].Value -notin @('varEmpActiveDraft', 'varAdmMsgKind', 'varAdmMsgHead', 'varAdmMsgBody') }).Count -eq 0) 'Switch OnSelect is local only (draft + message variables; no mutation, no Reset, no SharePoint call)'
Assert-True ($save.Contains('CountIf(colEmpWorkers,EmployerID=varEmpSaveID && Coalesce(WorkerActive,true))') -and $liveMsg[0].Body.Replace($liveCount, '#').Contains('Text(#)')) 'Live and save warning use the same count (EmployerID = selected/saved ID && Coalesce(WorkerActive,true))'
$wrk = 'colEmpWorkers:Table({ID:1,EmployerID:5,WorkerActive:true},{ID:2,EmployerID:5,WorkerActive:If(false,true)},{ID:3,EmployerID:5,WorkerActive:false},{ID:4,EmployerID:6,WorkerActive:true},{ID:5,EmployerID:If(false,1),WorkerActive:true})'
$liveFix = 'varEmpActiveDraft:false,varEmpMode:"Edit",varEmpSelectedID:5,varEmpLoadState:"Loaded",colEmpLoadErrors:Filter(Table({Message:""}),false),varEmpBusy:false,varEmpSaving:false,varEmpSaveFailed:false,varEmpEdit:{Active:true},' + $wrk
function Live([string]$fixture) { return "With({LangNl:false,T:$tRec},With({$fixture},If($($liveArgs[0]),`"N:`" & ($($liveMsg[0].Body)),`"none`")))" }
Assert-Eval (Live $liveFix) 'N:2 active worker(s) still have this contractor.' 'Live warning: 2 active workers (Active blank = active; inactive and other contractors not counted)'
Assert-Eval (Live $liveFix.Replace('varEmpEdit:{Active:true}', 'varEmpEdit:{Active:If(false,true)}')) 'N:2 active worker(s) still have this contractor.' 'Live warning: loaded record with blank Active counts as active'
$liveNo = @(
    @('varEmpActiveDraft:false', 'varEmpActiveDraft:true', 'switch turned on (off -> on)'),
    @('varEmpMode:"Edit"', 'varEmpMode:"New"', 'New contractor'),
    @('varEmpSelectedID:5', 'varEmpSelectedID:Blank()', 'no selected ID (would match workers without contractor)'),
    @('varEmpLoadState:"Loaded"', 'varEmpLoadState:"Failed"', 'load Failed'),
    @('Filter(Table({Message:""}),false)', 'Table({Message:"x"})', 'load errors present'),
    @('varEmpBusy:false', 'varEmpBusy:true', 'loading'),
    @('varEmpSaving:false', 'varEmpSaving:true', 'saving'),
    @('varEmpSaveFailed:false', 'varEmpSaveFailed:true', 'after a failed save'),
    @('varEmpEdit:{Active:true}', 'varEmpEdit:{Active:false}', 'loaded record already inactive'),
    @('varEmpSelectedID:5', 'varEmpSelectedID:7', 'no workers for this contractor'))
foreach ($c in $liveNo) { Assert-Eval (Live $liveFix.Replace($c[0], $c[1])) 'none' "Live warning: nothing when $($c[2])" }
$saveCountFx = (Get-Balanced $save ($save.IndexOf('Set(varEmpSaveWarnWorkers,') + 3)); $saveCountFx = $saveCountFx.Substring('(varEmpSaveWarnWorkers,'.Length, $saveCountFx.Length - '(varEmpSaveWarnWorkers,'.Length - 1)
Assert-Eval ("With({varEmpSaveMode:`"Edit`",varEmpSaveID:5,varEmpEdit:{Active:true},varEmpSaveRec:{Active:false},$wrk},$saveCountFx)") 2 'Save warning counts the same 2 active workers as the live warning'
$gf = 'varEmpLoadState:"Loaded",colEmpLoadErrors:Filter(Table({Message:""}),false),varEmpBusy:false,varEmpSaving:false,varEmpSaveFailed:false,varEmpMode:"Edit"'
$gCases = @(
    @($gf, $true, 'Loaded, Edit'), @($gf.Replace('varEmpMode:"Edit"', 'varEmpMode:"New"'), $true, 'Loaded, New'),
    @($gf.Replace('varEmpLoadState:"Loaded"', 'varEmpLoadState:"Failed"'), $false, 'load Failed'), @($gf.Replace('varEmpLoadState:"Loaded"', 'varEmpLoadState:Blank()'), $false, 'cold start'),
    @($gf.Replace('Filter(Table({Message:""}),false)', 'Table({Message:"x"})'), $false, 'load errors'), @($gf.Replace('varEmpBusy:false', 'varEmpBusy:true'), $false, 'loading'),
    @($gf.Replace('varEmpSaving:false', 'varEmpSaving:true'), $false, 'saving'), @($gf.Replace('varEmpSaveFailed:false', 'varEmpSaveFailed:true'), $false, 'after a failed save'),
    @($gf.Replace('varEmpMode:"Edit"', 'varEmpMode:""'), $false, 'no item in the form'))
foreach ($g in $gCases) { Assert-Eval ('With({' + $g[0] + '},' + $swGuard + ')') $g[1] "Switch guard: $($g[2]) -> $($g[1])" }
# Switch controls: track (Classic/Button) + knob (Classic/Button on top of the track, same DisplayMode, click forwards to the track) + state text
$swCfg = @(
    @{ Track = 'btnEmpActiveSwitch'; Knob = 'btnEmpActiveKnob'; State = 'Coalesce(varEmpActiveDraft,true)'; Parent = 'conEmpFormCard' })
foreach ($s in $swCfg) {
    $t = $s.Track; $kn = $s.Knob
    Assert-True ($idx[$t]['Control'] -eq 'Classic/Button@2.2.0' -and $idx[$kn]['Control'] -eq 'Classic/Button@2.2.0') "$t / $kn are Classic/Button@2.2.0 (no new control types)"
    $trackFill = '=If(' + $s.State + ',ColorValue("#0303B8"),ColorValue("#B4B4B4"))'
    foreach ($p in @('Fill', 'HoverFill', 'PressedFill', 'DisabledFill')) { Assert-True ((Get-Prop $t $p) -ceq $trackFill) "$t.$p = $trackFill (track #0303B8 on / #B4B4B4 off)" }
    Assert-True ((Get-Prop $t 'Text') -ceq '=""' -and (Get-Prop $t 'Tooltip') -match '^=.*\bT\.\w+\.en\b') "$($t): no caption, tooltip from T"
    Assert-True ((Get-Prop $kn 'DisplayMode') -ceq "=$t.DisplayMode" -and (Get-Prop $kn 'OnSelect') -ceq "=Select($t)" -and (Get-Prop $kn 'Fill') -ceq '=Color.White') "$($kn): white knob, same DisplayMode as $t, a click forwards to $t (its guard applies)"
    Assert-True ((Get-Prop $kn 'X') -ceq "=$t.X+If($($s.State),$t.Width-Self.Width-3,3)" -and (Get-Prop $kn 'Y') -ceq "=$t.Y+3") "$kn right when on, left when off"
    $sib = @($idx[$s.Parent]['Children'] | ForEach-Object { @($_.Keys)[0] })
    Assert-True ($sib.IndexOf($kn) -eq $sib.IndexOf($t) + 1) "$kn directly after $t in $($s.Parent).Children (drawn on top)"
}
Assert-True ((Get-Prop 'btnEmpShowInactiveSwitch' 'OnSelect') -ceq ('=If(' + $lcEn.Substring(1) + ',Set(varEmpShowInactive,!Coalesce(varEmpShowInactive,false)))') -and (Get-Prop 'cmpEmpList' 'ShowInactive') -ceq '=Coalesce(varEmpShowInactive,false)') 'Show inactive switch (cmpListCard): OnToggleShowInactive = guard, then flip the local filter variable; the component never flips the state itself'
$siSets = @($all.Keys | Where-Object { $all[$_] -match 'Set\(varEmpShowInactive,' } | Sort-Object)
Assert-True (($siSets -join ',') -ceq 'btnEmpShowInactiveSwitch.OnSelect,scrContractors.OnVisible') "varEmpShowInactive set only by its switch and the OnVisible init ($($siSets -join ', '))"
$items = (Get-Prop 'galEmpList' 'Items').TrimStart('=')
Assert-True ($items.Contains('(Coalesce(varEmpShowInactive,false) || Active)') -and $items.Contains('cmpEmpList.SearchText') -and $items -notmatch 'txtEmpSearch') 'List filter reads varEmpShowInactive (blank = hide inactive) and the cmpListCard SearchText output'
$itemFix = 'colAdminEmployers:Table({ID:1,Name:"A",Code:"",City:"",Active:true},{ID:2,Name:"B",Code:"",City:"",Active:false},{ID:3,Name:"C",Code:"",City:"",Active:If(false,true)}),cmpEmpList:{SearchText:""},LangNl:false,T:' + $tRec
foreach ($c in @(@('false', 2), @('true', 3), @('If(false,true)', 2))) { Assert-Eval "With({$itemFix,varEmpShowInactive:$($c[0])},CountRows($items))" ($c[1]) "List rows with varEmpShowInactive = $($c[0]): $($c[1])" }
# Items projection for cmpListCard: ID, Title (name), Subtitle (code and city, no duplicate text), Inactive, ChipText (Inactive or empty)
Assert-Eval "With({$itemFix,varEmpShowInactive:true},Concat($items,Title & ""|"" & Subtitle & ""|"" & Text(Inactive) & ""|"" & ChipText & ""/""))" 'A||false|/B||true|Inactive/C||false|/' 'Items projection: Title, empty Subtitle without code and city, Inactive flag and ChipText Inactive'
Assert-Eval "With({colAdminEmployers:Table({ID:1,Name:""A"",Code:""C1"",City:""X"",Active:true},{ID:2,Name:""B"",Code:""C2"",City:"""",Active:true},{ID:3,Name:""D"",Code:"""",City:""Y"",Active:true}),cmpEmpList:{SearchText:""""},LangNl:false,T:$tRec,varEmpShowInactive:false},Concat($items,Subtitle & ""/""))" ('C1 ' + [char]0x00B7 + ' X/C2/Y/') 'Subtitle = code and city joined once (middle dot), no dangling separator'
$stateFx = (Get-Prop 'lblEmpActiveState' 'Text').TrimStart('=')
foreach ($c in @(@('true', 'Active'), @('false', 'Inactive'), @('If(false,true)', 'Active'))) { Assert-Eval "With({LangNl:false,T:$tRec,varEmpActiveDraft:$($c[0])},$stateFx)" $c[1] "lblEmpActiveState shows the state as text ($($c[0]) -> $($c[1])), not only colour" }
Assert-True ((Get-Prop 'btnEmpActiveSwitch' 'Tooltip') -ceq (Get-Prop 'lblEmpActiveState' 'Text')) 'Active switch tooltip = state text'
# Red border per field: cmpField.Invalid is bound to colEmpSaveErrors.Field (the component draws the 2 px #DB1E28 border, pinned in Test-GeaColors)
$fieldsCollected = @([regex]::Matches($save, 'Collect\(colEmpSaveErrors,\{Field:"(\w*)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True (@($fieldsCollected | Where-Object { $_ -ne '' -and $_ -cnotin @($inputMap.Values) }).Count -eq 0) "Every collected error Field is one of the 8 inputs or '' ($($fieldsCollected -join ','))"
foreach ($k in $inputMap.Keys) {
    $f = $inputMap[$k]; $inv = ([string]$idx[$k]['Properties']['Invalid']).TrimStart('=')
    Assert-Eval "With({colEmpSaveErrors:Table({Field:`"City`",Message:`"x`"},{Field:`"`",Message:`"y`"})},$inv)" ($f -eq 'City') "$k.Invalid with a City error"
    Assert-Eval "With({colEmpSaveErrors:Filter(Table({Field:`"$f`",Message:`"x`"}),false)},$inv)" $false "$k.Invalid without errors"
}
Assert-True ((Get-Prop 'cmpEmpList' 'SearchHint') -ceq ('=' + (TT 'empSearchHint'))) 'List card search hint from T (the search box and its border live in cmpListCard)'


function Get-FormGeom([int]$layW) {
    $cw = $layW - 48; $c = if ($cw -ge 572) { 3 } elseif ($cw -ge 376) { 2 } else { 1 }
    $colW = ($cw - 16 * ($c - 1)) / $c
    $div = 24 + 30 + 16; $g = $div + 1 + 20
    $a = $g + 38 + [Math]::Ceiling(2 / $c) * 74; $k = $a + 38 + [Math]::Ceiling(4 / $c) * 74; $row = $k + 38 + [Math]::Ceiling(3 / $c) * 74
    $modWide = $cw -ge 480; $modY = if ($modWide) { $row } else { $row + 32 }
    return @{ Cols = $c; ColW = $colW; CW = $cw; Gen = $g; Addr = $a; Cont = $k; Row = $row; ModWide = $modWide; ModY = $modY; MetY = $modY + 24 + 24 }
}
# Geometry (admin pattern, 30-10-2026): two white cards on #F5F6F8, 24 px margin/gap/padding; wide (>=1000): list card 360 left, form card right, tops equal; narrow: stacked.
# The carriers' formulas are pinned by exact text, then mirrored here for each width.
$expLay = @{ X='=If(Parent.Width>=1000,1,0)'; Y='=If(Self.X=1,408,24)'; Width='=If(Self.X=1,Max(0,Parent.Width-432),Parent.Width-48)'; Height='=If(Self.X=1,24,500)' }
foreach ($k in $expLay.Keys) { Assert-True ((Get-Prop 'lblEmpLayout' $k) -eq $expLay[$k]) "Layout carrier lblEmpLayout.$k formula as mirrored" }
Assert-True ((Get-Prop 'lblEmpMetrics' 'Width') -eq '=If(lblEmpLayout.X=1,Self.Height-48,452)' -and (Get-Prop 'lblEmpMetrics' 'Height') -eq '=If(lblEmpLayout.X=1,Max(conEmpBody.Height,Self.Y+48,568),lblEmpLayout.Height+Self.Y+24)') 'Layout carrier lblEmpMetrics Width/Height formulas as mirrored (X = columns, Y = content height: see grid tests)'
$li = $idx['cmpEmpList']
Assert-True ($li['Control'] -eq 'CanvasComponent' -and $li['ComponentName'] -eq 'cmpListCard') 'List card = cmpListCard instance (replaces conEmpListCard, search, count, Show inactive switch and gallery)'
foreach ($card in @(@('cmpEmpList', 'X', '=24'), @('cmpEmpList', 'Y', '=24'), @('cmpEmpList', 'Width', '=If(lblEmpLayout.X=1,360,Parent.Width-48)'), @('cmpEmpList', 'Height', '=lblEmpMetrics.Width'),
        @('cmpEmpList', 'SelectedID', '=Coalesce(varEmpSelectedID,0)'), @('cmpEmpList', 'ShowInactive', '=Coalesce(varEmpShowInactive,false)'),
        @('cmpEmpList', 'SearchHint', ('=' + (TT 'empSearchHint'))), @('cmpEmpList', 'ShowInactiveText', ('=' + (TT 'empShowInactive'))), @('cmpEmpList', 'OnText', ('=' + (TT 'admOn'))), @('cmpEmpList', 'OffText', ('=' + (TT 'admOff'))),
        @('cmpEmpList', 'CountText', ('=Substitute(' + (TT 'empCount') + ',"{0}",Text(CountRows(cmpEmpList.Items)))')),
        @('conEmpFormCard', 'Fill', '=Color.White'), @('conEmpFormCard', 'DropShadow', '=DropShadow.Light'), @('conEmpFormCard', 'RadiusTopLeft', '=8'), @('conEmpFormCard', 'X', '=lblEmpLayout.Y'), @('conEmpFormCard', 'Y', '=lblEmpLayout.Height'), @('conEmpFormCard', 'Width', '=lblEmpLayout.Width'), @('conEmpFormCard', 'Height', '=If(lblEmpLayout.X=1,lblEmpMetrics.Height-48,lblEmpMetrics.Y)'))) {
    Assert-True ((Get-Prop $card[0] $card[1]) -ceq $card[2]) "$($card[0]).$($card[1]) = $($card[2])"
}
Assert-True ($srcAll -match 'empSearchHint: \{en: "Search name, code or city"' -and $srcAll -match 'empCount: \{en: "\{0\} contractors"') 'T: search hint "Search name, code or city", count "{0} contractors"'
$canvKids = @($idx['conEmpCanvas']['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($canvKids -join ',') -ceq 'cmpEmpList,conEmpFormCard') 'conEmpCanvas holds exactly the list card instance and the form card'
# cmpListCard internals that fix the list geometry (white card, radius 8, shadow, search 24/36, info row 24, gallery rows 64)
$lcDef = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'Component/cmpListCard.pa.yaml')))['ComponentDefinitions']['cmpListCard']
$lci = @{}; Index-Controls $lcDef['Children'] $lci
function GetLcProp([string]$c, [string]$p) { return ([string]$lci[$c]['Properties'][$p]).Trim() }
Assert-True (((GetLcProp 'conCmpListCard' 'Fill') -ceq '=Color.White') -and ((GetLcProp 'conCmpListCard' 'DropShadow') -ceq '=DropShadow.Light') -and ((GetLcProp 'conCmpListCard' 'RadiusTopLeft') -ceq '=8') -and ((GetLcProp 'conCmpListCard' 'Height') -ceq '=Parent.Height')) 'cmpListCard: white card, DropShadow.Light, radius 8, full component height'
$lcKids = @($lci['conCmpListCard']['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($lcKids -join ',') -ceq 'txtCmpListSearch,icoCmpListSearch,htmlCmpListInfo,btnCmpListSwitch,btnCmpListKnob,galCmpList') "cmpListCard children: $($lcKids -join ',')"
$sY = [int](GetLcProp 'txtCmpListSearch' 'Y').TrimStart('='); $sH = [int](GetLcProp 'txtCmpListSearch' 'Height').TrimStart('='); $cH = [int](GetLcProp 'htmlCmpListInfo' 'Height').TrimStart('=')
Assert-True (($sY -eq 24) -and ($sH -eq 36) -and ((GetLcProp 'txtCmpListSearch' 'Width') -eq '=Parent.Width-48') -and ((GetLcProp 'txtCmpListSearch' 'PaddingLeft') -eq '=40') -and ((GetLcProp 'txtCmpListSearch' 'RadiusTopLeft') -eq '=4') -and ((GetLcProp 'txtCmpListSearch' 'Fill') -eq '=Color.White')) 'Search field (cmpListCard): white, radius 4, h36 at Y 24, PaddingLeft 40 (room for the magnifier)'
Assert-True (((GetLcProp 'icoCmpListSearch' 'Icon') -eq '=Icon.Search') -and ($lci['icoCmpListSearch']['Control'] -eq 'Classic/Icon@2.5.0') -and ((GetLcProp 'icoCmpListSearch' 'X') -eq '=txtCmpListSearch.X+12') -and ((GetLcProp 'icoCmpListSearch' 'Width') -eq '=18')) 'Magnifier = Classic/Icon Icon.Search inside the search field (X+12, 18 wide)'
Assert-True (((GetLcProp 'htmlCmpListInfo' 'Y') -eq '=txtCmpListSearch.Y+txtCmpListSearch.Height+12') -and ($cH -eq 24) -and ((GetLcProp 'btnCmpListSwitch' 'Y') -eq '=htmlCmpListInfo.Y') -and ((GetLcProp 'btnCmpListSwitch' 'X') -eq '=Parent.Width-24-Self.Width') -and ((GetLcProp 'htmlCmpListInfo' 'X') -eq '=24')) 'One info row under the search (item 1): count left, Show inactive text + switch right on the same line (one HtmlViewer row, switch at the same Y)'
Assert-True (((GetLcProp 'galCmpList' 'Y') -eq '=htmlCmpListInfo.Y+htmlCmpListInfo.Height+12') -and ((GetLcProp 'galCmpList' 'X') -eq '=0') -and ((GetLcProp 'galCmpList' 'Width') -eq '=Parent.Width') -and ((GetLcProp 'galCmpList' 'Height') -eq '=Max(0,Parent.Height-Self.Y-12)') -and ((GetLcProp 'galCmpList' 'TemplateSize') -eq '=64')) 'Gallery below the info row, full card width, fixed row height 64'
$rowT = GetLcProp 'htmlCmpRowTitle' 'HtmlText'; $rowS = GetLcProp 'htmlCmpRowSub' 'HtmlText'
Assert-True ((($rowT -match 'white-space:nowrap') -and ($rowT -match 'text-overflow:ellipsis') -and ($rowS -match 'white-space:nowrap') -and ($rowS -match 'text-overflow:ellipsis')) -and ((GetLcProp 'htmlCmpRowTitle' 'Height') -eq '=22') -and ((GetLcProp 'htmlCmpRowSub' 'Height') -eq '=18') -and ((GetLcProp 'htmlCmpRowSub' 'Y') -eq '=34')) 'List row (item 6): name on line 1 and subtitle on line 2, each one line with ellipsis, fixed positions in the 64 px row'
$gY = $sY + $sH + 12 + $cH + 12
Assert-True (((Get-Prop 'conEmpBody' 'Y') -eq '=cmpEmpMsgBar.Y+cmpEmpMsgBar.Height') -and ((Get-Prop 'conEmpBody' 'Height') -eq '=Max(0,cmpEmpFooter.Y-Self.Y)')) 'Body starts directly under the message bar (bar directly under the title bar, height 0 when no message) and ends at the footer'
foreach ($W in 320, 768, 900, 1000, 1280, 1366, 1920) {
    $wide = $W -ge 1000
    $layX = [int]$wide; $layY = if ($wide) { 408 } else { 24 }
    $layW = if ($wide) { [Math]::Max(0, $W - 432) } else { $W - 48 }
    $layH = if ($wide) { 24 } else { 500 }
    $fg = Get-FormGeom $layW
    $metY = $fg.MetY
    foreach ($bodyH in 300, 700) {
        $metH = if ($wide) { [Math]::Max($bodyH, [Math]::Max($metY + 48, 568)) } else { $layH + $metY + 24 }
        $listH = if ($wide) { $metH - 48 } else { 452 }
        $listW = if ($wide) { 360 } else { $W - 48 }
        $formH = if ($wide) { $metH - 48 } else { $metY }
        $galH = $listH - $gY - 12
        $lbl = "W=$W body=$bodyH"
        Assert-True ($galH -ge 200 -and $gY + $galH + 12 -eq $listH) "$lbl : gallery $galH px tall inside the list card ($listH)"
        Assert-True ($formH -ge $metY) "$lbl : form card $formH >= form content $metY"
        Assert-True ($layY + $layW + 24 -le $W -or $layW -le 0) "$lbl : form card (X=$layY, w=$layW) keeps the 24 px right margin"
        Assert-True (24 + $listW + 24 -le $W) "$lbl : list card inside the screen"
        if ($wide) {
            Assert-True ($layH -eq 24 -and 24 + $listW + 24 -eq $layY) "$lbl : wide: both card tops 24, 24 px gap between the cards"
            Assert-True (24 + $listH + 24 -eq $metH -and $listH -eq $formH) "$lbl : wide: equal card heights, 24 px bottom margin in the canvas ($metH)"
        } else {
            Assert-True ($layH -ge 24 + $listH + 24) "$lbl : narrow: form top $layH >= list bottom $(24 + $listH) + 24 (stacked, no overlap)"
            Assert-True ($layH + $formH + 24 -eq $metH) "$lbl : narrow: canvas $metH ends 24 px below the form card"
        }
    }
}
# 29-10-2026: Contractor Code = read-only TextInput (txtEmpCode, always Disabled). A2 (30-10-2026): form card = header (name + status chip + divider), sections GENERAL/ADDRESS/CONTACT on a 1-3 column grid, bottom row switch + "Last changed".
Assert-True (($null -eq $idx['lblEmpCodeValue']) -and ($idx['cmpEmpCode']['ComponentName'] -eq 'cmpField')) 'Contractor Code value is a read-only cmpField (cmpEmpCode); lblEmpCodeValue is gone'
Assert-True (($dirty -notmatch 'cmpEmpCode') -and ($saveN -notmatch 'cmpEmpCode') -and ($load -notmatch 'cmpEmpCode')) 'cmpEmpCode is not part of dirty/Save/Load logic (the app never writes Employer Code)'
# Grid carriers (pinned) and numeric mirror
Assert-True ((Get-Prop 'lblEmpMetrics' 'X') -eq '=If(lblEmpLayout.Width-48>=572,3,If(lblEmpLayout.Width-48>=376,2,1))' -and (Get-Prop 'lblEmpGrid' 'Width') -eq '=(lblEmpLayout.Width-48-16*(lblEmpMetrics.X-1))/lblEmpMetrics.X' -and (Get-Prop 'lblEmpGrid' 'Visible') -eq '=false') 'Grid: columns = 3 (content >= 572), 2 (>= 376), else 1; column width = (content - 16*(cols-1))/cols (gap 16, min ~180 per column); lblEmpGrid is a hidden label'
Assert-True ((Get-Prop 'lblEmpMetrics' 'Y') -eq '=lblEmpModified.Y+lblEmpModified.Height+24') 'lblEmpMetrics.Y = bottom of the last row (lblEmpModified) + 24 padding'
Assert-True ((Get-Prop 'lblEmpSecGeneral' 'Y') -eq '=lblEmpFormDivider.Y+1+20' -and (Get-Prop 'lblEmpSecAddress' 'Y') -eq '=lblEmpSecGeneral.Y+38+RoundUp(2/lblEmpMetrics.X,0)*74' -and (Get-Prop 'lblEmpSecContact' 'Y') -eq '=lblEmpSecAddress.Y+38+RoundUp(4/lblEmpMetrics.X,0)*74' -and (Get-Prop 'btnEmpActiveSwitch' 'Y') -eq '=lblEmpSecContact.Y+38+RoundUp(3/lblEmpMetrics.X,0)*74') 'Section tops: previous top + 38 + rows*74 (label 18 + 4 + field 36 + 16 row gap; header 18 + 12; 24 between sections); bottom row below CONTACT'
$grid = @{ GENERAL = @('Name', 'Code'); ADDRESS = @('Address', 'Postalcode', 'City', 'Country'); CONTACT = @('ContactName', 'ContactEmail', 'ContactPhone') }
$secCtl = @{ GENERAL = 'lblEmpSecGeneral'; ADDRESS = 'lblEmpSecAddress'; CONTACT = 'lblEmpSecContact' }
foreach ($s in $grid.Keys) {
    Assert-True ($idx[$secCtl[$s]]['Control'] -eq 'Label@2.5.1' -and (Get-Prop $secCtl[$s] 'Size') -eq '=12' -and (Get-Prop $secCtl[$s] 'FontWeight') -eq '=FontWeight.Bold' -and (Get-Prop $secCtl[$s] 'Color') -eq '=ColorValue("#0303B8")' -and (Get-Prop $secCtl[$s] 'Text') -match 'T\.emp' -and (Get-Prop $secCtl[$s] 'Height') -eq '=18') "$($secCtl[$s]): section header 12 Bold #0303B8 from T, h18"
    for ($n = 0; $n -lt $grid[$s].Count; $n++) {
        $f = $grid[$s][$n]; $tx = "cmpEmp$f"
        $xx = if ($n -eq 0) { '=24' } else { "=24+Mod($n,lblEmpMetrics.X)*(lblEmpGrid.Width+16)" }
        $yy = if ($n -eq 0) { "=$($secCtl[$s]).Y+30" } else { "=$($secCtl[$s]).Y+30+RoundDown($n/lblEmpMetrics.X,0)*74" }
        Assert-True (((Get-Prop $tx 'X') -ceq $xx) -and ((Get-Prop $tx 'Y') -ceq $yy) -and ((Get-Prop $tx 'Width') -eq '=lblEmpGrid.Width') -and ((Get-Prop $tx 'Height') -eq '=58')) "$s field $n ($f): cmpField grid cell X/Y by column/row, 58 high (label 18 + 4 + field 36), grid column width"
    }
}
# header (item 2, 30-10-2026): fixed text "Contractor details" (New: "New contractor"; no selection: T.empNoSelection), no name in the header (it stood twice); status chip right-aligned on the card padding, SAVED status
$ftx = (Get-Prop 'lblEmpFormTitle' 'Text')
Assert-True (((Get-Prop 'lblEmpFormTitle' 'Size') -eq '=22') -and ((Get-Prop 'lblEmpFormTitle' 'FontWeight') -eq '=FontWeight.Semibold') -and ((Get-Prop 'lblEmpFormTitle' 'Color') -eq '=ColorValue("#000F41")') -and (-not $idx['lblEmpFormTitle']['Properties'].ContainsKey('Visible')) -and $ftx.Contains('T.empNewContractor') -and $ftx.Contains('T.empFormDetails') -and $ftx.Contains('T.empNoSelection') -and ($ftx -notmatch 'varEmpEdit\.Name')) 'Header: 22 Semibold #000F41, always visible; New = T.empNewContractor, Edit = T.empFormDetails, no selection = T.empNoSelection; the record name is not repeated'
foreach ($c in @(@('"New"', 'New contractor'), @('"Edit"', 'Contractor details'), @('""', 'No contractor selected'), @('If(false,"x")', 'No contractor selected'))) { Assert-Eval "With({LangNl:false,T:$tRec,varEmpMode:$($c[0])},$($ftx.TrimStart('=')))" $c[1] "Header text for Mode $($c[0]) = $($c[1])" }
Assert-True ($formulas.Contains('empFormDetails: {en: "Contractor details", nl: ""}')) 'T.empFormDetails = Contractor details'
$chipFill = 'If(Coalesce(varEmpEdit.Active,true),ColorValue("#1AFF80"),ColorValue("#E6E6E6"))'; $chipCol = 'If(Coalesce(varEmpEdit.Active,true),ColorValue("#000F41"),ColorValue("#000000"))'
Assert-True (($idx['btnEmpFormChip']['Control'] -eq 'Classic/Button@2.2.0') -and ((Get-Prop 'btnEmpFormChip' 'DisplayMode') -eq '=DisplayMode.Disabled') -and (-not $idx['btnEmpFormChip']['Properties'].ContainsKey('OnSelect')) -and ((Get-Prop 'btnEmpFormChip' 'Visible') -eq '=Coalesce(varEmpMode,"") in ["New","Edit"]')) 'Status chip btnEmpFormChip: hand-built Classic/Button, static (Disabled with identical disabled colours), no OnSelect, hidden when Mode is empty'
foreach ($p in 'Fill', 'HoverFill', 'PressedFill', 'DisabledFill') { Assert-True ((Get-Prop 'btnEmpFormChip' $p) -ceq "=$chipFill") "btnEmpFormChip.$p = green #1AFF80 when the SAVED status is Active (varEmpEdit.Active), grey #E6E6E6 when Inactive (not the switch draft)" }
foreach ($p in 'Color', 'HoverColor', 'PressedColor', 'DisabledColor') { Assert-True ((Get-Prop 'btnEmpFormChip' $p) -ceq "=$chipCol") "btnEmpFormChip.$p = #000F41 on green, #000000 on grey" }
Assert-True (((Get-Prop 'btnEmpFormChip' 'Text').Contains('T.empFieldActive')) -and ((Get-Prop 'btnEmpFormChip' 'Text').Contains('T.empInactive')) -and ((Get-Prop 'btnEmpFormChip' 'Text') -notmatch 'varEmpActiveDraft') -and ((Get-Prop 'btnEmpFormChip' 'X') -eq '=Parent.Width-24-Self.Width') -and ((Get-Prop 'btnEmpFormChip' 'Height') -eq '=24') -and ((Get-Prop 'btnEmpFormChip' 'RadiusTopLeft') -eq '=12') -and ((Get-Prop 'btnEmpFormChip' 'Size') -eq '=12')) 'Chip text is the saved state (not colour only), right-aligned on the card padding (24), h24, radius 12'
Assert-True (((Get-Prop 'lblEmpFormTitle' 'Width') -eq '=Max(0,Parent.Width-48-84)') -and ((Get-Prop 'lblEmpFormTitle' 'X') -eq '=24')) 'Header title leaves room for the chip (72 + 12) and never overlaps it'
Assert-True (((Get-Prop 'lblEmpFormDivider' 'Fill') -eq '=ColorValue("#EDEDED")') -and ((Get-Prop 'lblEmpFormDivider' 'Height') -eq '=1') -and ((Get-Prop 'lblEmpFormDivider' 'Width') -eq '=lblEmpLayout.Width-48') -and ((Get-Prop 'lblEmpFormDivider' 'Y') -eq '=lblEmpFormTitle.Y+lblEmpFormTitle.Height+16')) 'Divider: 1 px #EDEDED under the header, full content width'
$formKids = @($idx['conEmpFormCard']['Children'] | ForEach-Object { @($_.Keys)[0] })
$expKids = 'lblEmpFormTitle,btnEmpFormChip,lblEmpFormDivider,lblEmpSecGeneral,cmpEmpName,cmpEmpCode,lblEmpSecAddress,cmpEmpAddress,cmpEmpPostalcode,cmpEmpCity,cmpEmpCountry,lblEmpSecContact,cmpEmpContactName,cmpEmpContactEmail,cmpEmpContactPhone,btnEmpActiveSwitch,btnEmpActiveKnob,lblEmpActiveState,lblEmpModified'
Assert-True (($formKids -join ',') -ceq $expKids) "conEmpFormCard children (final structure): $($formKids -join ',')"
# numeric mirror of the grid
foreach ($W in 320, 768, 900, 1000, 1280, 1366, 1920) {
    $wide = $W -ge 1000; $layW = if ($wide) { [Math]::Max(0, $W - 432) } else { $W - 48 }
    if ($layW -lt 100) { continue }
    $g = Get-FormGeom $layW
    if ($g.Cols -ge 2) { Assert-True ($g.ColW -ge 180) "W=$W (card $layW): $($g.Cols) columns of $([Math]::Round($g.ColW,1)) px (>= 180)" }
    Assert-True ($g.Cols * $g.ColW + 16 * ($g.Cols - 1) -eq $g.CW) "W=$W : columns + 16 px gaps fill the content width exactly (inside the 24 px padding)"
    $secStep = 18 + 12
    foreach ($pair in @(@('GENERAL', $g.Gen, 2, $g.Addr), @('ADDRESS', $g.Addr, 4, $g.Cont), @('CONTACT', $g.Cont, 3, $g.Row))) {
        $rows = [Math]::Ceiling($pair[2] / $g.Cols); $endY = $pair[1] + $secStep + ($rows - 1) * 74 + 58
        Assert-True ($endY + 24 -eq $pair[3]) "W=$W : $($pair[0]) last field ends $endY, next block starts 24 px lower ($($pair[3]))"
    }
    if ($g.ModWide) { Assert-True (24 + 44 + 12 + 80 + 16 -le 24 + 152) "W=$W : modified label (right aligned, content-152 wide) clear of switch + state" }
    else { Assert-True ($g.ModY -ge $g.Row + 24 + 8) "W=$W : narrow: modified label on its own line 8 px under the switch row" }
    Assert-True ($g.MetY -eq $g.ModY + 48) "W=$W : form content height $($g.MetY) = last row + 24 + 24 padding"
}
$mdCols = [ordered]@{ Align = '=If(lblEmpLayout.Width-48>=480,Align.Right,Align.Left)'; Width = '=If(lblEmpLayout.Width-48>=480,lblEmpLayout.Width-48-152,lblEmpLayout.Width-48)'; X = '=If(lblEmpLayout.Width-48>=480,24+lblEmpLayout.Width-48-Self.Width,24)'; Y = '=If(lblEmpLayout.Width-48>=480,btnEmpActiveSwitch.Y,btnEmpActiveSwitch.Y+32)'; Size = '=12'; FontWeight = '=FontWeight.Normal'; Color = '=ColorValue("#787878")'; Height = '=24' }
foreach ($k in $mdCols.Keys) { Assert-True ((Get-Prop 'lblEmpModified' $k) -ceq $mdCols[$k]) "lblEmpModified.$k = $($mdCols[$k]) (same row as the switch, right aligned, 12 #787878)" }
Assert-True ((Get-Prop 'lblEmpActiveState' 'Y') -eq '=btnEmpActiveSwitch.Y' -and (Get-Prop 'lblEmpActiveState' 'Height') -eq '=24' -and (Get-Prop 'lblEmpActiveState' 'Width') -eq '=80' -and (Get-Prop 'btnEmpActiveSwitch' 'X') -eq '=24') 'Switch row: switch X 24, state label on the same Y (h24, 80 wide)'
# (16) Load/save spinner in the title bar: cmpTitleBar (modern Spinner inside the component, D4 confirmed) ---------------------------------------------------------------
Assert-True (((Get-Prop 'cmpEmpTitle' 'Busy') -eq '=Coalesce(varEmpBusy,false) || Coalesce(varEmpSaving,false) || varEmpLoadState="Loading"') -and ((Get-Prop 'cmpEmpTitle' 'BusyLabel') -eq ('=' + (TT 'empBusy'))) -and ((Get-Prop 'cmpEmpTitle' 'Title') -eq ('=' + (TT 'empTitle')))) 'cmpEmpTitle: Busy = busy || saving || LoadState="Loading" (the former spinner Visible), BusyLabel from T.empBusy, Title from T.empTitle'
$tbDef = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'Component/cmpTitleBar.pa.yaml')))['ComponentDefinitions']['cmpTitleBar']
$tbi = @{}; Index-Controls $tbDef['Children'] $tbi
$sp = $tbi['spnCmpTitleBusy']['Properties']
Assert-True (($tbi['spnCmpTitleBusy']['Control'] -eq 'ModernSpinner@1.1.0') -and ($sp['Visible'] -eq '=cmpTitleBar.Busy') -and ($sp['Width'] -eq '=24') -and ($sp['Height'] -eq '=24') -and ($sp['SpinnerColor'] -eq '=Color.White') -and ($sp['AccessibleLabel'] -eq '=cmpTitleBar.BusyLabel') -and ($sp['X'] -eq '=Parent.Width-24-Self.Width') -and ($sp['Y'] -eq '=(Parent.Height-Self.Height)/2')) 'Component spinner: Visible = Busy, 24x24, white on #0303B8, AccessibleLabel = BusyLabel, 24 px right margin, centred in the 60 px bar'
foreach ($W in 320, 480, 768, 1280) {
    $sX = $W - 48; $lX = 15
    Assert-True (($sX -ge $lX + 99) -and ($sX + 24 -le $W)) "W=$W : spinner (X $sX..$($sX + 24)) inside the title bar and clear of the logo (ends $($lX + 99))"
}
$kids = @($doc['Screens'][$screenName]['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($kids[0] -eq 'cmpEmpTitle') -and ($kids[1] -eq 'cmpEmpMsgBar')) 'Children order: title bar instance (logo and spinner inside the component), message bar directly after'

# (17) Studio FAIL build adminpattern-20261030_071949 (Eddy 30-10-2026): items 4, 5 and d (shared helpers, reused for Projects) --
# Item 4 cause: the form inputs fell back to DisplayMode.View when no record was in the form (Mode ""). A Classic/TextInput in
# View mode renders as read-only text without field box or border (white on the white card): with an empty Default it was
# invisible; the dropdowns kept their grey fill. Fix: the fallback is DisplayMode.Disabled, so the field box always renders.
function Test-FormInputsRender($index, [string[]]$editable, [string[]]$readOnly, [string]$card, [string]$guardFix, [string]$scr) {
    $kidsOf = @($index[$card]['Children'] | ForEach-Object { @($_.Keys)[0] })
    foreach ($c in @($editable) + @($readOnly)) {
        $props = $index[$c]['Properties']
        $vis = if ($props.ContainsKey('Visible')) { ([string]$props['Visible']).Trim() } else { $null }
        Assert-True ($null -eq $vis -or $vis -eq '=true') "$scr : $c has no Visible formula (always rendered)"
        Assert-True ($kidsOf -ccontains $c -and ([string]$props['Height']).Trim() -eq '=36' -and ([string]$props['DisplayMode']) -notmatch 'DisplayMode\.View') "$scr : $c is a direct child of $card, h36, never DisplayMode.View"
    }
    foreach ($c in $readOnly) { Assert-True (([string]$index[$c]['Properties']['DisplayMode']).Trim() -eq '=DisplayMode.Disabled') "$scr : read-only $c always Disabled" }
    $dm0 = ([string]$index[$editable[0]]['Properties']['DisplayMode']).Trim(); $sfx = ',DisplayMode.Edit,DisplayMode.Disabled)'
    Assert-True ($dm0.StartsWith('=If(') -and $dm0.EndsWith($sfx)) "$scr : form DisplayMode = If(<guard>,Edit,Disabled)"
    foreach ($c in $editable) { Assert-True (([string]$index[$c]['Properties']['DisplayMode']).Trim() -ceq $dm0) "$scr : $c uses the same form DisplayMode" }
    $g = $dm0.Substring(4, $dm0.Length - 4 - $sfx.Length)
    Assert-Eval "With({$guardFix},$g)" $true "$scr : inputs editable: Loaded, idle, Edit"
    foreach ($m in @('""', 'If(false,"x")')) { Assert-Eval "With({$($guardFix -replace 'Mode:"Edit"', "Mode:$m")},$g)" $false "$scr : no record in the form (Mode $m, e.g. empty list): all inputs Disabled (rendered, not editable)" }
}
# Item 5: after a successful load, Mode empty (or the selected ID vanished) -> select the first row of the visible (filtered,
# sorted) list exactly like the gallery OnSelect; empty visible list -> Mode "" (no selection). The loader itself refuses to run
# over unsaved input (dirty block above), so the auto-selection never replaces typed input.
function Test-AutoSelect([string]$load, [string]$itemsFx, [string]$defaultFx, [string]$onSelect, [string]$p, [string]$col, [string]$emptySnap, [string]$dirtyFx, [string]$scr) {
    $lN = Norm $load
    $sel = "Set(var${p}SelectedID,First($itemsFx).ID);"
    $branch = "If(!IsBlank(var${p}SelectedID) && !IsBlank(LookUp($col,ID=var${p}SelectedID).ID),Set(var${p}Edit,LookUp($col,ID=var${p}SelectedID)); Set(var${p}Mode,`"Edit`"),Set(var${p}Mode,`"`"); Set(var${p}SelectedID,Blank()); Set(var${p}Edit,$emptySnap))"
    Assert-True ($lN.Contains((Norm ($sel + $branch)))) "$scr : loader auto-selects the first visible row (gallery Items text), else no selection with an empty snapshot"
    Assert-True (([regex]::Matches($lN, [regex]::Escape((Norm $sel)))).Count -eq 1 -and ([regex]::Matches((Norm $onSelect), [regex]::Escape((Norm "Set(var${p}Edit,LookUp($col,ID=var${p}SelectedID)); Set(var${p}Mode,`"Edit`");")))).Count -eq 1) "$scr : auto-selection fills var${p}SelectedID/var${p}Edit/Mode Edit like the gallery OnSelect"
    $iDirty = $lN.IndexOf((Norm ('If(' + $dirtyFx + " && !Coalesce(var${p}SaveFailed,false),"))); $iGate = $lN.IndexOf((Norm "If(IsEmpty(col${p}LoadErrors),ClearCollect("))
    $iNew = $lN.IndexOf((Norm "var${p}Mode=`"New`" && !Coalesce(var${p}SaveFailed,false),")); $iSel = $lN.IndexOf((Norm $sel)); $iOk = $lN.IndexOf((Norm "Set(var${p}SaveFailed,false); Clear(col${p}SaveErrors); Set(var${p}LoadState,`"Loaded`");"))
    Assert-True ($iDirty -ge 0 -and $iGate -gt $iDirty -and $iNew -gt $iGate -and $iSel -gt $iNew -and $iOk -gt $iSel) "$scr : auto-selection only after the dirty block, in the successful-load branch, as the last branch (Mode empty or the selected ID no longer exists), before Loaded + form reset"
    if ($defaultFx -ne '') { Assert-True ($defaultFx -ceq "=LookUp($itemsFx,ID=var${p}SelectedID)") "$scr : gallery Default = the selected record within the visible list" }
}
# Item d: "nothing written" (SharePoint refused: Patch error AND no record with ID) -> Not saved., state stays Loaded, input kept,
# retry possible; a returned ID with an error, no ID without an error (uncertain), an ID mismatch or a verify read/mismatch
# after a successful Patch -> Failed + SaveFailed (locked, Refresh = Discard).
function Test-WriteCounter([string]$save, [string]$p, [string]$list, [string]$scr) {
    $sN = Norm $save
    $wFx = "If(var${p}PatchError && IsBlank(var${p}PatchedID),0,1)"
    $iInit = $sN.IndexOf("Set(var${p}SaveWrites,0);"); $iF0 = $sN.IndexOf((Norm "Set(var${p}PatchError,false);IfError(CountRows(ClearCollect(col${p}Patched,Patch($list,"))
    $iPatch = $sN.IndexOf("Patch($list,"); $iF1 = $sN.IndexOf((Norm "Set(var${p}PatchError,true); Collect(col${p}SaveErrors,{"))
    $iId = $sN.IndexOf((Norm "Set(var${p}PatchedID,First(col${p}Patched).ID);")); $iW = $sN.IndexOf((Norm "Set(var${p}SaveWrites,$wFx);"))
    $iVer = $sN.IndexOf("ClearCollect(col${p}VerifyRaw,")
    Assert-True ($iInit -gt 0 -and $iF0 -gt $iInit -and $iPatch -gt $iF0 -and $iF1 -gt $iPatch -and $iId -gt $iF1 -and $iW -gt $iId -and $iVer -gt $iW) "$scr : write counter set only after the Patch from its result: $wFx (flag reset before the Patch, set in its error branch)"
    Assert-True (([regex]::Matches($sN, "Set\(var${p}SaveWrites,")).Count -eq 2 -and ([regex]::Matches($sN, "Set\(var${p}PatchError,")).Count -eq 2) "$scr : var${p}SaveWrites set twice (init 0, after the Patch); var${p}PatchError twice"
    $iOut = $sN.IndexOf((Norm "If(var${p}SaveVerified && IsEmpty(col${p}SaveErrors),RemoveIf(")); $iZero = $sN.IndexOf("var${p}SaveWrites=0,"); $iFail = $sN.IndexOf((Norm "Set(var${p}SaveFailed,true); Set(var${p}LoadState,`"Failed`");"))
    Assert-True ($iOut -gt $iVer -and $iZero -gt $iOut -and $iFail -gt $iZero) "$scr : outcome If(verified, saved; writes = 0, Not saved (Loaded); else Failed + SaveFailed)"
    $zb = $sN.Substring($iZero, $iFail - $iZero)
    Assert-True ($zb -notmatch 'Reset\(|Select\(|Clear\(|Set\(var\w*(Edit|Mode|LoadState|SelectedID|SaveFailed),' -and $zb.Contains('T.admHeadNotSaved.en')) "$scr : zero-write branch only shows Not saved. + reason: input, selection and Loaded state kept (retry possible)"
    $out = "If(var${p}SaveVerified && IsEmpty(col${p}SaveErrors),`"Saved`",var${p}SaveWrites=0,`"Loaded`",`"Failed`")"
    $err = 'Table({Field:"",Message:"x"})'; $none = 'Filter(Table({Field:"",Message:""}),false)'
    foreach ($c in @(@('true', 'If(false,0)', $err, 'false', 'Loaded', 'Patch error without a returned record (SharePoint refused): nothing written'),
                    @('true', '7', $err, 'false', 'Failed', 'Patch error but a record with ID returned: possibly written'),
                    @('false', 'If(false,0)', $err, 'false', 'Failed', 'no error and no record (uncertain): counted as a write'),
                    @('false', '7', $err, 'false', 'Failed', 'Patch returned ID 7, then verify read error or mismatch'),
                    @('false', '7', $none, 'true', 'Saved', 'Patch ID 7 and verify OK'))) {
        Assert-Eval "With({var${p}PatchError:$($c[0]),var${p}PatchedID:$($c[1])},With({var${p}SaveWrites:$wFx},With({col${p}SaveErrors:$($c[2]),var${p}SaveVerified:$($c[3])},$out)))" $c[4] "$scr : $($c[5]) -> $($c[4])"
    }
}
$empEditable = @($inputMap.Keys)
$kidsOfForm = @($idx['conEmpFormCard']['Children'] | ForEach-Object { @($_.Keys)[0] })
foreach ($c in @($empEditable) + 'cmpEmpCode') {
    $fp = $idx[$c]['Properties']
    Assert-True ((-not $fp.ContainsKey('Visible')) -and ($kidsOfForm -ccontains $c) -and ($fp['Height'] -eq '=58')) "Contractors : $c is always rendered (no Visible formula), a direct child of conEmpFormCard, height 58 (item 4: fields always visible)"
}
$empFieldGuard = $fieldEnabled.Substring(1)
$empFieldFix = 'varEmpLoadState:"Loaded",colEmpLoadErrors:Filter(Table({Message:""}),false),varEmpBusy:false,varEmpSaving:false,varEmpSaveFailed:false,varEmpMode:"Edit"'
Assert-Eval "With({$empFieldFix},$empFieldGuard)" $true 'Contractors : cmpField.Enabled true: Loaded, idle, Edit'
foreach ($m in @('""', 'If(false,"x")')) { Assert-Eval "With({$($empFieldFix -replace 'Mode:"Edit"', "Mode:$m")},$empFieldGuard)" $false "Contractors : no record in the form (Mode $m, e.g. empty list): all fields Disabled (rendered, not editable)" }
Assert-True ((Get-Prop 'btnEmpActiveSwitch' 'DisplayMode') -ceq ('=If(' + $fieldEnabled.Substring(1) + ',DisplayMode.Edit,DisplayMode.Disabled)') -and !$idx['btnEmpActiveSwitch']['Properties'].ContainsKey('Visible') -and !$idx['btnEmpActiveKnob']['Properties'].ContainsKey('Visible')) 'Contractors: Active switch always rendered, Disabled like the inputs when no record is in the form'
Assert-True ($screenText -notmatch 'DisplayMode\.View') 'Contractors: no DisplayMode.View on the screen'
$empItemsAll = (Get-Prop 'galEmpList' 'Items').TrimStart('=')
$empItems = 'Sort' + (Get-Balanced $empItemsAll ($empItemsAll.IndexOf('Sort(Filter(') + 4))
Assert-True ($empItemsAll.StartsWith('ForAll(' + $empItems + ' As r,{ID:r.ID,Title:r.Name,Subtitle:')) 'cmpListCard Items = the filtered, sorted list (same text as the loader auto-select) projected to ID, Title, Subtitle, Inactive, ChipText'
$empEmpty = '{ID:Blank(),Name:"",Code:"",Address:"",Postalcode:"",City:"",Country:"",ContactName:"",ContactEmail:"",ContactPhone:"",Active:true}'
Test-AutoSelect $load $empItems $null (Get-Prop 'galEmpList' 'OnSelect') 'Emp' 'colAdminEmployers' $empEmpty $dirty 'Contractors'
Assert-True ((Get-Prop 'cmpEmpList' 'SelectedID') -ceq '=Coalesce(varEmpSelectedID,0)') 'Contractors auto-select: the selected ID goes to cmpListCard.SelectedID (row highlight), Coalesce to 0 without selection'
$empSelFix = 'colAdminEmployers:Table({ID:1,Name:"Zeta",Code:"EMP-001",City:"Ede",Active:true},{ID:2,Name:"alpha",Code:"EMP-002",City:"",Active:false},{ID:3,Name:"Beta",Code:"",City:"Delft",Active:If(false,true)})'
foreach ($c in @(@('false', '""', '3', 'first active row by name (inactive alpha hidden; blank Active = active)'), @('true', '""', '2', 'Show inactive on: alpha first'), @('false', '" ZET "', '1', 'search filter applied'))) {
    Assert-Eval "With({$empSelFix,varEmpShowInactive:$($c[0]),cmpEmpList:{SearchText:$($c[1])}},Text(First($empItems).ID))" $c[2] "Contractors auto-select: $($c[3]) -> ID $($c[2])"
}
Assert-Eval "With({$empSelFix,varEmpShowInactive:false,cmpEmpList:{SearchText:`"nomatch`"}},IsBlank(First($empItems).ID))" $true 'Contractors auto-select: empty visible list -> no ID -> Mode "" (no selection)'
Assert-Eval "With({colAdminEmployers:Filter(Table({ID:1,Name:`"`",Code:`"`",City:`"`",Active:true}),false),varEmpShowInactive:false,cmpEmpList:{SearchText:`"`"}},IsBlank(First($empItems).ID))" $true 'Contractors auto-select: empty list -> no selection'
Test-WriteCounter $save 'Emp' 'Employers' 'Contractors'
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix) $true 'Contractors: after a refused save (Loaded, SaveFailed false, input kept) Save is allowed again (retry)'
$empPatchErr = Get-Balanced $save ($save.IndexOf('Set(varEmpPatchError,true); Collect(colEmpSaveErrors,') + 'Set(varEmpPatchError,true); Collect'.Length)
$empPatchErrRec = (Split-Args $empPatchErr.Substring(1, $empPatchErr.Length - 2))[1].Replace('FirstError.Message', 'fe')
Assert-Eval "With({LangNl:false,T:$tRec,fe:`"Access denied.`"},$empPatchErrRec.Field & `"|`" & $empPatchErrRec.Message)" '|SharePoint error: Access denied.' 'Contractors: refused Patch -> red message with the SharePoint reason'
# Item f (statuschip = saved status): varEmpEdit.Active comes only from the loaded/verified rows or the New default
function Get-SetValues([string]$text, [string]$var) { return @([regex]::Matches($text, "Set\($var,") | ForEach-Object { $b = Get-Balanced $text ($_.Index + 3); $b.Substring($var.Length + 2, $b.Length - $var.Length - 3).Trim() } | Sort-Object -Unique) }
$empEditSets = Get-SetValues $screenText 'varEmpEdit'
Assert-True ($empEditSets.Count -ge 3 -and @($empEditSets | Where-Object { $_ -notmatch '^(LookUp\(colAdminEmployers,ID=varEmpSelectedID\)|First\(colEmpVerify\)|\{ID:Blank\(\),.*Active:true\})$' }).Count -eq 0) "Contractors: varEmpEdit (saved status source for the chip) only from the loaded list, the verify read or the empty/New snapshot ($($empEditSets -join ' | '))"
Write-Output 'PASS Test-AdminScreens (Contractors): static structure only. Studio import, binding, delegation (Monitor), SharePoint case-sensitivity of Title = and functional tests NOT verified.'
# =====================================================================================================================
# Build 2 (30-10-2026): Projects (scrProjects, list Projects). Same admin pattern as Contractors; only fields and rules differ.
# Fields: Project Name (Title), Project Number ('Project Number', internal ProjectName), Project Reference, Customer Name,
# Status (choice), Street, House Number, Postal Code, City, Country (choice), Project Leader / Site Managers (read-only),
# ProjectHomeSite URL. Proves source structure only: no Studio import, binding, delegation (Monitor) or functional result.
# =====================================================================================================================
$pScreen = 'scrProjects'
$pDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir "$pScreen.pa.yaml")))
$script:formulas = 0; $script:failures = 0
Check-Node $pDoc $pScreen
if ($script:failures -gt 0) { throw 'FAIL Power Fx syntax in scrProjects' }
Assert-True $true "Projects: Power Fx syntax: $script:formulas formulas in scrProjects parsed"
# Check-Node counts in $script:formulas (= $formulas at script scope): restore the App.Formulas text used below.
$formulas = [string]$appDoc['App']['Properties']['Formulas']
$script:names = @{}; $script:controlCount = 0
foreach ($entry in $pDoc['Screens'][$pScreen]['Children']) { Check-Control $entry }
Assert-True ($script:controlCount -gt 0) "Projects: control templates/properties valid ($script:controlCount controls)"
$pIdx = @{}; Index-Controls $pDoc['Screens'][$pScreen]['Children'] $pIdx
$pScreenProps = $pDoc['Screens'][$pScreen]['Properties']
function PGet([string]$ctl, [string]$prop) { $v = $pIdx[$ctl]['Properties'][$prop]; if ($null -eq $v) { throw "FAIL missing $ctl.$prop" }; return ([string]$v).Trim() }
$pAll = @{}
foreach ($n in $pIdx.Keys) { foreach ($p in $pIdx[$n]['Properties'].Keys) { $pAll["$n.$p"] = ([string]$pIdx[$n]['Properties'][$p]) } }
foreach ($p in $pScreenProps.Keys) { $pAll["$pScreen.$p"] = [string]$pScreenProps[$p] }
$pText = ($pAll.Values) -join "`n"
$pTextFields = [ordered]@{ txtPrjName = 'Name'; txtPrjNumber = 'Number'; txtPrjReference = 'Reference'; txtPrjCustomer = 'Customer'; txtPrjStreet = 'Street'; txtPrjHouseNumber = 'HouseNumber'; txtPrjPostalCode = 'PostalCode'; txtPrjCity = 'City'; txtPrjUrl = 'Url' }
$pDropFields = [ordered]@{ ddPrjStatus = 'Status'; ddPrjCountry = 'Country' }
$pWritten = @('Name', 'Number', 'Reference', 'Customer', 'Status', 'Street', 'HouseNumber', 'PostalCode', 'City', 'Country', 'Url')
function PInputOf([string]$f) { foreach ($k in $pTextFields.Keys) { if ($pTextFields[$k] -eq $f) { return "$k.Text" } }; foreach ($k in $pDropFields.Keys) { if ($pDropFields[$k] -eq $f) { return "$k.Selected.Value" } }; throw "no input for $f" }

# (P1) Identical fail-closed guard in DisplayMode and as first OnSelect condition ---------------------------------------
$pGuards = @{}
foreach ($ctl in @('btnPrjSave', 'btnPrjHome', 'btnPrjNew', 'btnPrjRefresh', 'btnPrjDiscard', 'galPrjList')) {
    $dm = PGet $ctl 'DisplayMode'; $os = PGet $ctl 'OnSelect'
    $suffix = ',DisplayMode.Edit,DisplayMode.Disabled)'
    Assert-True ($dm.StartsWith('=If(') -and $dm.EndsWith($suffix)) "Projects: $ctl DisplayMode has shape If(<guard>,Edit,Disabled)"
    $g = $dm.Substring(4, $dm.Length - 4 - $suffix.Length)
    Assert-True ($os.StartsWith('=If(' + $g + ',')) "Projects: $ctl OnSelect starts with the same guard text as DisplayMode"
    $pGuards[$ctl] = $g
}
$pDirtyStart = $pGuards.btnPrjSave.IndexOf('(Coalesce(varPrjMode,"") in ["New","Edit"]')
Assert-True ($pDirtyStart -ge 0) 'Projects: Save guard contains the dirty expression'
$pDirty = Get-Balanced $pGuards.btnPrjSave $pDirtyStart
foreach ($f in $pWritten) { Assert-True ($pDirty.Contains("Trim($(PInputOf $f) & """")<>Trim(varPrjEdit.$f & """")")) "Projects: dirty compares $(PInputOf $f) directly with varPrjEdit.$f, both sides Trim(x & """")" }
Assert-True (([regex]::Matches($pDirty, '<>')).Count -eq $pWritten.Count -and $pDirty -notmatch 'Leader|SiteManager|txtPrjSearch|Modified') 'Projects: dirty covers exactly the 11 app-written fields (not the read-only person fields, search or Modified)'
Assert-True ($pGuards.btnPrjSave.EndsWith('&& ' + $pDirty)) 'Projects: Save requires dirty'
foreach ($ctl in @('btnPrjHome', 'btnPrjNew', 'galPrjList')) { Assert-True ($pGuards[$ctl].EndsWith('!' + $pDirty)) "Projects: $ctl blocked while dirty (same dirty text)" }
Assert-True ($pGuards.btnPrjRefresh -ceq ('!Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && (Coalesce(varPrjSaveFailed,false) || !' + $pDirty + ')')) 'Projects: Refresh blocked while loading/saving; allowed when clean or after a failed save (H15)'
Assert-True ($pGuards.btnPrjDiscard -ceq ('!Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && (Coalesce(varPrjSaveFailed,false) || ' + $pDirty + ')')) 'Projects: Discard requires dirty or SaveFailed'
Assert-True ($pGuards.btnPrjHome -ceq ('!Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && !' + $pDirty) -and $pGuards.btnPrjNew -ceq $pGuards.galPrjList) 'Projects: Home = not busy/saving/dirty; New = gallery-selection guard'
foreach ($k in @('varPrjLoadState="Loaded"', 'IsEmpty(colPrjLoadErrors)', '!Coalesce(varPrjBusy,false)', '!Coalesce(varPrjSaving,false)', '!Coalesce(varPrjSaveFailed,false)')) { Assert-True ($pGuards.btnPrjSave.Contains($k) -and $pGuards.btnPrjNew.Contains($k)) "Projects: Save and New guards contain $k" }
Assert-True ($pGuards.btnPrjSave.Contains('(varPrjMode="New" || (varPrjMode="Edit" && !IsBlank(varPrjSelectedID)))')) 'Projects: Save guard: New, or Edit with an ID'
Assert-True ((PGet 'btnPrjHome' 'OnSelect') -ceq ('=If(' + $pGuards.btnPrjHome + ',Navigate(scrHome))')) 'Projects: Home navigates only to scrHome, inside the guard'
function PIn([string]$name, [string]$num, [string]$city, [string]$status, [string]$country, [string]$empty) {
    return "txtPrjName:{Text:$name},txtPrjNumber:{Text:$num},txtPrjReference:{Text:$empty},txtPrjCustomer:{Text:$empty},ddPrjStatus:{Selected:{Value:$status}},txtPrjStreet:{Text:$empty},txtPrjHouseNumber:{Text:$empty},txtPrjPostalCode:{Text:$empty},txtPrjCity:{Text:$city},ddPrjCountry:{Selected:{Value:$country}},txtPrjUrl:{Text:$empty}"
}
$pSnap = '{ID:5,Name:"A",Number:"TEST-002",Reference:"",Customer:"",Status:"Active",Street:"",HouseNumber:"",PostalCode:"",City:"",Country:"Netherlands",Leader:"",SiteManager:"",Url:""}'
$pBase = 'varPrjLoadState:"Loaded",colPrjLoadErrors:Filter(Table({Message:""}),false),varPrjBusy:false,varPrjSaving:false,varPrjSaveFailed:false,varPrjMode:"Edit",varPrjSelectedID:5,varPrjEdit:' + $pSnap + ','
$pFix = $pBase + (PIn '"B"' '"TEST-002"' '""' '"Active"' '"Netherlands"' '""')
$pClean = $pBase + (PIn '"A"' '"TEST-002"' '""' '"Active"' '"Netherlands"' '""')
function PG($name, $fixture) { return 'With({' + $fixture + '},' + $pGuards[$name] + ')' }
Assert-Eval (PG 'btnPrjSave' $pFix) $true 'Projects: Save allowed: Loaded, Edit with ID, dirty'
Assert-Eval (PG 'btnPrjSave' $pClean) $false 'Projects: Save blocked: not dirty'
Assert-Eval (PG 'btnPrjSave' $pClean.Replace('ddPrjStatus:{Selected:{Value:"Active"}}', 'ddPrjStatus:{Selected:{Value:"Closed"}}')) $true 'Projects: Save allowed: only Status changed (dirty)'
Assert-Eval (PG 'btnPrjSave' $pClean.Replace('ddPrjCountry:{Selected:{Value:"Netherlands"}}', 'ddPrjCountry:{Selected:{Value:"Germany"}}')) $true 'Projects: Save allowed: only Country changed (dirty)'
foreach ($s in @('NotLoaded', 'Loading', 'Failed')) { Assert-Eval (PG 'btnPrjSave' $pFix.Replace('varPrjLoadState:"Loaded"', "varPrjLoadState:""$s""")) $false "Projects: Save blocked: $s" }
Assert-Eval (PG 'btnPrjSave' $pFix.Replace('varPrjLoadState:"Loaded"', 'varPrjLoadState:Blank()')) $false 'Projects: Save blocked: cold start'
Assert-Eval (PG 'btnPrjSave' $pFix.Replace('varPrjBusy:false', 'varPrjBusy:true')) $false 'Projects: Save blocked: loading busy'
Assert-Eval (PG 'btnPrjSave' $pFix.Replace('varPrjSaving:false', 'varPrjSaving:true')) $false 'Projects: Save blocked: saving'
Assert-Eval (PG 'btnPrjSave' $pFix.Replace('varPrjSaveFailed:false', 'varPrjSaveFailed:true')) $false 'Projects: Save blocked: after a failed save'
Assert-Eval (PG 'btnPrjSave' $pFix.Replace('Filter(Table({Message:""}),false)', 'Table({Message:"x"})')) $false 'Projects: Save blocked: load errors present'
Assert-Eval (PG 'btnPrjSave' $pFix.Replace('varPrjSelectedID:5', 'varPrjSelectedID:Blank()')) $false 'Projects: Save blocked: Edit without ID'
Assert-Eval (PG 'btnPrjSave' $pFix.Replace('varPrjMode:"Edit"', 'varPrjMode:""')) $false 'Projects: Save blocked: no item in the form'
$pNewSnap = '{ID:Blank(),Name:"",Number:"",Reference:"",Customer:"",Status:"Active",Street:"",HouseNumber:"",PostalCode:"",City:"",Country:"Netherlands",Leader:"",SiteManager:"",Url:""}'
$pNewBase = $pBase.Replace('varPrjMode:"Edit"', 'varPrjMode:"New"').Replace('varPrjSelectedID:5', 'varPrjSelectedID:Blank()').Replace($pSnap, $pNewSnap)
Assert-Eval (PG 'btnPrjSave' ($pNewBase + (PIn 'If(false,"x")' 'If(false,"x")' 'If(false,"x")' '"Active"' '"Netherlands"' 'If(false,"x")'))) $false 'Projects: New form untouched (defaults Active / Netherlands, inputs Blank) is not dirty: Save blocked'
Assert-Eval (PG 'btnPrjSave' ($pNewBase + (PIn '""' '"TEST-003"' '""' '"Active"' '"Netherlands"' '""'))) $true 'Projects: Save allowed: New with a typed Project Number'
Assert-Eval (PG 'btnPrjHome' $pClean) $true 'Projects: Home allowed: clean'
Assert-Eval (PG 'btnPrjHome' $pFix) $false 'Projects: Home blocked: dirty'
Assert-Eval (PG 'btnPrjHome' $pClean.Replace('varPrjSaving:false', 'varPrjSaving:true')) $false 'Projects: Home blocked: saving'
Assert-Eval (PG 'btnPrjRefresh' $pClean.Replace('varPrjLoadState:"Loaded"', 'varPrjLoadState:"Failed"')) $true 'Projects: Refresh allowed after a failed load (not dirty)'
Assert-Eval (PG 'btnPrjRefresh' $pFix) $false 'Projects: Refresh blocked: dirty (no failed save)'
$pFailed = $pFix.Replace('varPrjSaveFailed:false', 'varPrjSaveFailed:true').Replace('varPrjLoadState:"Loaded"', 'varPrjLoadState:"Failed"')
Assert-Eval (PG 'btnPrjRefresh' $pFailed) $true 'Projects: Refresh allowed after a failed save (= Discard, H15)'
Assert-Eval (PG 'btnPrjDiscard' $pFailed) $true 'Projects: Discard allowed after a failed save'
Assert-Eval (PG 'btnPrjSave' $pFailed) $false 'Projects: Save blocked after a failed save'
Assert-Eval (PG 'btnPrjNew' $pFailed) $false 'Projects: New blocked after a failed save'
Assert-Eval (PG 'galPrjList' $pFailed) $false 'Projects: gallery selection blocked after a failed save'
Assert-Eval (PG 'btnPrjNew' $pFix) $false 'Projects: New blocked: dirty'
Assert-Eval (PG 'galPrjList' $pClean) $true 'Projects: gallery selection allowed: Loaded and clean'
Assert-Eval (PG 'btnPrjDiscard' $pClean) $false 'Projects: Discard disabled: clean'
Assert-Eval (PG 'btnPrjDiscard' $pFix.Replace('varPrjSaving:false', 'varPrjSaving:true')) $false 'Projects: Discard blocked: saving'
# A loaded project with an empty Status/Country: dropdowns allow an empty selection, so the form is not falsely dirty
$pEmptyChoice = $pBase.Replace('Status:"Active"', 'Status:""').Replace('Country:"Netherlands"', 'Country:""') + (PIn '"A"' '"TEST-002"' '""' 'If(false,"x")' 'If(false,"x")' '""')
Assert-Eval (PG 'btnPrjHome' $pEmptyChoice) $true 'Projects: empty Status/Country in SharePoint and empty dropdown selection: not dirty'
foreach ($d in $pDropFields.Keys) { Assert-True ((PGet $d 'AllowEmptySelection') -eq '=true') "Projects: $d.AllowEmptySelection = true (blank SharePoint value stays blank, no false dirty)" }

# Form bound to varPrjEdit, never to the gallery selection
foreach ($k in @($pTextFields.Keys) + @($pDropFields.Keys)) { $f = if ($pTextFields.Contains($k)) { $pTextFields[$k] } else { $pDropFields[$k] }; Assert-True ((PGet $k 'Default') -ceq "=varPrjEdit.$f") "Projects: $k.Default = varPrjEdit.$f" }
foreach ($k in @('txtPrjLeader', 'txtPrjSiteManager')) { $f = @{ txtPrjLeader = 'Leader'; txtPrjSiteManager = 'SiteManager' }[$k]; Assert-True ((PGet $k 'Default') -ceq "=varPrjEdit.$f" -and (PGet $k 'DisplayMode') -eq '=DisplayMode.Disabled' -and $pIdx[$k]['Control'] -eq 'Classic/TextInput@2.3.2') "Projects: $k read-only (Classic/TextInput, always Disabled) showing varPrjEdit.$f (DisplayName)" }
$pSelUses = @($pAll.Keys | Where-Object { $pAll[$_] -match 'galPrjList\.Selected' })
Assert-True ($pSelUses.Count -eq 1 -and $pSelUses[0] -eq 'galPrjList.OnSelect') 'Projects: galPrjList.Selected only read in the guarded gallery OnSelect'
Assert-True (@($pIdx.Keys | Where-Object { $pIdx[$_]['Control'] -like 'Classic/CheckBox@*' -or $pIdx[$_]['Control'] -like '*ComboBox*' }).Count -eq 0) 'Projects: no CheckBox/ComboBox (Status replaces Active; person fields read-only)'
Assert-True ($pText -notmatch '\bvarPrjActiveDraft\b|btnPrjActiveSwitch') 'Projects: no Active switch (Status replaces Active)'

# (P2) Loader: staging, reuse, dirty block, no mutations, H16 Refresh first -----------------------------------------------
$pLoad = PGet 'btnPrjLoad' 'OnSelect'; $pLoadN = Norm $pLoad
$pVis = [string]$pScreenProps['OnVisible']
foreach ($k in @('btnPrjLoad.OnSelect', "$pScreen.OnVisible", 'btnPrjFormReset.OnSelect')) {
    $fx = $pAll[$k]
    Assert-True ($fx -notmatch '\b(Patch|Update|UpdateIf|Remove|RemoveIf|SubmitForm|Defaults)\s*\(' -and $fx -notmatch '\.Run\(') "Projects: $k has no Patch/Update/Remove/SubmitForm/Defaults/flow"
    Assert-True ($fx -notmatch "\b(?:Collect|ClearCollect)\(\s*(?:Employers|Workers|Projects|Hours|'Project Workers'|'Assignment Periods')\b") "Projects: $k does not Collect into a SharePoint list"
}
Assert-True ($pLoad.Contains('If(' + $pDirty + ' && !Coalesce(varPrjSaveFailed,false),')) 'Projects: loader refuses to reload over unsaved input (except after a failed save)'
Assert-True ($pLoad.Contains('If(!Coalesce(varPrjForceRefresh,false) && varPrjLoadState="Loaded" && IsEmpty(colPrjLoadErrors) && !Coalesce(varPrjSaveFailed,false),')) 'Projects: loader reuses a valid Loaded list unless forced (cache hit)'
$iPRefresh = $pLoadN.IndexOf((Norm 'IfError(Refresh(Projects),Collect(colPrjLoadErrors,'))
$iPRead = $pLoadN.IndexOf((Norm 'ClearCollect(colPendingPrjRaw,Sort(Projects,Title,SortOrder.Ascending))'))
Assert-True ($iPRefresh -gt 0 -and $iPRead -gt $iPRefresh -and $pLoad -notmatch 'If\(Coalesce\(varPrjForceRefresh,false\),') 'Projects: every load refreshes Projects first (H16), then reads raw Projects (not only when forced)'
Assert-True ($pLoad.Contains('ClearCollect(colPendingAdminProjects,ForAll(colPendingPrjRaw As prj,')) 'Projects: projection is local, from the raw staging collection'
$pRefreshOs = PGet 'btnPrjRefresh' 'OnSelect'
Assert-True ($pRefreshOs.Contains('Set(varPrjForceRefresh,true); Select(btnPrjLoad)') -and $pRefreshOs.Contains('If(Coalesce(varPrjSaveFailed,false),Clear(colPrjSaveErrors));') -and $pRefreshOs -notmatch '\b(Patch|Refresh|Collect|ClearCollect|Remove|RemoveIf|Reset)\(') 'Projects: Refresh forces the staged loader; after a failed save it works as Discard (no mutation)'
Assert-True ($pLoad.Contains('varPrjMode="New" && !Coalesce(varPrjSaveFailed,false),') -and $pLoad.Contains('Set(varPrjSaveFailed,false); Clear(colPrjSaveErrors); Set(varPrjLoadState,"Loaded");')) 'Projects: forced reload after a failed save discards local input; SaveFailed cleared only after a successful load'
$pClearAt = $pLoad.IndexOf('Set(varPrjSaveFailed,false); Clear(colPrjSaveErrors); Set(varPrjLoadState,"Loaded");')
$pBranchAt = $pLoad.LastIndexOf('If(IsEmpty(colPrjLoadErrors),', $pClearAt)
Assert-True ($pBranchAt -ge 0 -and $pLoad.Substring($pBranchAt, $pClearAt - $pBranchAt).IndexOf('Set(varPrjLoadState,"Failed")') -lt 0) 'Projects: SaveFailed cleared only inside the successful-load branch'
Assert-True ($pVis.Contains('If(varPrjLoadState<>"Loaded" && !Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && !' + $pDirty + ',Select(btnPrjLoad))')) 'Projects: OnVisible loads only when not Loaded, idle and not dirty'
$iPLimit = $pLoadN.IndexOf('If(CountRows(colPendingPrjRaw)>=500,Collect(colPrjLoadErrors,')
$iPGate = $pLoadN.IndexOf('If(IsEmpty(colPrjLoadErrors),ClearCollect(colAdminProjects,colPendingAdminProjects);ClearCollect(colPrjModified,colPendingPrjModified);')
Assert-True ($iPLimit -gt $iPRead -and $iPGate -gt $iPLimit) 'Projects: 500 guard on the raw read applied before the staged list replaces colAdminProjects (fail-closed)'
Assert-True (([regex]::Matches($pText, 'ClearCollect\(colAdminProjects,')).Count -eq 1) 'Projects: colAdminProjects only replaced by the loader staging step'
Assert-True ($pLoadN.IndexOf('Set(varPrjLoadState,"Loaded")') -gt $iPGate -and $pLoadN.Contains('Set(varPrjLoadState,"Failed");')) 'Projects: Loaded only inside the no-error branch, else Failed'
Assert-True ($pLoad -notmatch '\bConcurrent\(' -and $pLoad -notmatch '\bChoices\(') 'Projects: loader reads only Projects (no Concurrent, no Choices)'
Assert-True ($pLoad.Contains('ClearCollect(colPendingPrjModified,ForAll(colPendingPrjRaw As prj,{ID:prj.ID,Modified:prj.Modified}));') -and $pLoadN.IndexOf((Norm 'ClearCollect(colPrjModified,colPendingPrjModified);')) -gt $iPGate) 'Projects: Modified staged from the same read, published only after a successful load'
Assert-True ($pText -notmatch '\.Run\(') 'Projects: no flow calls'

# (P4) 500 guard after every collection read from a SharePoint list ---------------------------------------------------------
$pReads = 0
foreach ($k in $pAll.Keys) {
    $fx = $pAll[$k]
    foreach ($m in [regex]::Matches($fx, '\b(?:ClearCollect|Collect)\(\s*(\w+)\s*,')) {
        $call = Get-Balanced $fx ($m.Index + $m.Value.IndexOf('('))
        $arg = $call.Substring($m.Value.Length - $m.Value.IndexOf('('))
        if ($arg -notmatch "(?<![\w.'@\[])(?:Employers|Workers|Projects|Hours)\b(?!\.)|'(?:Project Workers|Assignment Periods)'") { continue }
        if ($arg.TrimStart().StartsWith('Patch(')) { continue }
        $pReads++
        $col = $m.Groups[1].Value; $after = $fx.Substring($m.Index)
        Assert-True ($after.Contains("CountRows($col)>=500") -or $after.Contains("CountRows($col)<>1") -or $after.Contains("CountRows($col)=1")) "Projects: $k : SharePoint read into $col is followed by a 500 guard (or exact-one check for an ID read)"
    }
}
Assert-True ($pReads -eq 5) "Projects: SharePoint reads into collections: $pReads (load, pre-read, number check, open periods, verify)"

# (P5) Delegable predicates: column = global variable only; Choices only on the dropdown Items and once in Save ---------------
$pPreds = @()
foreach ($k in $pAll.Keys) {
    $fx = $pAll[$k]
    foreach ($m in [regex]::Matches($fx, "\b(Filter|LookUp|Search)\(\s*(Employers|Workers|Projects|Hours|'Project Workers'|'Assignment Periods')\s*,")) {
        Assert-True ($m.Groups[1].Value -eq 'Filter') "Projects: $k : no remote LookUp/Search on $($m.Groups[2].Value)"
        $call = Get-Balanced $fx ($m.Index + $m.Groups[1].Value.Length)
        $pPreds += "$($m.Groups[2].Value)|" + (Split-Args $call.Substring(1, $call.Length - 2))[1].Trim()
    }
}
$pPredExp = @('Projects|ID=varPrjSaveID', "Projects|'Project Number'=varPrjSaveNumber", 'Projects|ID=varPrjPatchedID', "'Assignment Periods'|ProjectKey=varPrjSaveKey")
Assert-True ((($pPreds | Sort-Object) -join ';') -ceq (($pPredExp | Sort-Object) -join ';')) "Projects: server predicates are exactly column = global variable ($($pPreds -join '; '))"
Assert-True ($pText -notmatch "\bProjectName\b" -and $pText -notmatch "'Project Name'") "Projects: no bare ProjectName and no 'Project Name' column (Project Name = Title; Project Number = 'Project Number')"
$pSave = PGet 'btnPrjSave' 'OnSelect'; $pSaveN = Norm $pSave
foreach ($v in @(@('Set(varPrjSaveNumber,varPrjSaveRec.Number)', "Filter(Projects,'Project Number'=varPrjSaveNumber)"), @('Set(varPrjSaveKey,If(varPrjSaveMode="Edit",Text(varPrjSaveID),""))', "Filter('Assignment Periods',ProjectKey=varPrjSaveKey)"), @('Set(varPrjSaveID,', 'Filter(Projects,ID=varPrjSaveID)'), @('Set(varPrjPatchedID,', 'Filter(Projects,ID=varPrjPatchedID)'))) {
    Assert-True ($pSave.IndexOf($v[0]) -gt 0 -and $pSave.IndexOf($v[0]) -lt $pSave.IndexOf($v[1])) "Projects: global predicate variable set before its read: $($v[1])"
}
$pChoices = @($pAll.Keys | Where-Object { $pAll[$_] -match '\bChoices\(' } | Sort-Object)
Assert-True (($pChoices -join ',') -ceq 'btnPrjSave.OnSelect,ddPrjCountry.Items,ddPrjStatus.Items') "Projects: Choices() only on the two dropdown Items and in Save ($($pChoices -join ', '))"
$pAsIs = @{}; foreach ($c in @('Status', 'Country')) { $pAsIs[$c] = "Split(Concat(Choices([@Projects].$c),Value,Char(31)) & If(!IsBlank(varPrjEdit.$c) && CountIf(Choices([@Projects].$c),Value=varPrjEdit.$c)=0,Char(31) & varPrjEdit.$c,`"`"),Char(31))" }
Assert-True ((PGet 'ddPrjStatus' 'Items') -ceq ('=' + $pAsIs.Status) -and (PGet 'ddPrjCountry' 'Items') -ceq ('=' + $pAsIs.Country) -and (PGet 'ddPrjStatus' 'Items.Value') -eq '=Value' -and (PGet 'ddPrjCountry' 'Items.Value') -eq '=Value') 'Projects: Status/Country dropdown Items = Choices([@Projects].<column>) (SharePoint values, not translated) plus the stored value of the record when it is not in Choices (shown as-is)'
Assert-True (([regex]::Matches($pSave, '\bChoices\(')).Count -eq 1 -and $pSave.Contains('If(IsBlank(varPrjSaveRec.Status) || (CountIf(Choices([@Projects].Status),Value=varPrjSaveRec.Status)=0 && !(varPrjSaveMode="Edit" && varPrjSaveRec.Status=varPrjEdit.Status)),Collect(colPrjSaveErrors,{Field:"Status"')) 'Projects: Save validates Status once against Choices (not inside ForAll); an unchanged stored value outside Choices is accepted in Edit'
Assert-True (@($pAll.Values | Where-Object { $_ -match 'ForAll\([^;]*\bChoices\(' }).Count -eq 0 -and $pText -notmatch '\bSearch\(') 'Projects: no Choices() inside ForAll, no Search()'
Assert-True ($pText -notmatch "ForAll\([^)]*\bProjects\b[^)]*\)[^;]*\b(?:LookUp|Filter)\(\s*Projects") 'Projects: no remote LookUp/Filter inside ForAll'

# (P6)-(P8) Save: validation, duplicate block, conflict check, one Patch, verify read, local update after verify ------------
Assert-True (([regex]::Matches($srcAll, '\bPatch\(\s*Projects\b')).Count -eq 1 -and $pSave -match '\bPatch\(\s*Projects\b') 'Projects: exactly one Patch(Projects) in Src, in btnPrjSave.OnSelect'
foreach ($k in $pAll.Keys) { if ($k -ne 'btnPrjSave.OnSelect') { Assert-True ($pAll[$k] -notmatch '\bPatch\(') "Projects: $k has no Patch" } }
Assert-True ($pText -notmatch "\bPatch\(\s*(?:'Assignment Periods'|'Project Workers'|Hours|Workers|Employers)\b" -and $pText -notmatch "\b(?:Remove|RemoveIf|Update|UpdateIf)\(\s*(?:Projects|'Assignment Periods')\b") 'Projects: no write to other lists; periods are never closed or removed by this screen'
$pm = [regex]::Match($pSave, '\bPatch\(\s*Projects\s*,')
$pPatch = Get-Balanced $pSave ($pm.Index + 5)
$pPargs = Split-Args $pPatch.Substring(1, $pPatch.Length - 2)
Assert-True ($pPargs.Count -eq 3 -and $pPargs[1].Trim() -ceq 'If(varPrjSaveMode="New",Defaults(Projects),First(colPrjPreRaw))') 'Projects: Patch base: Defaults(Projects) for New, the pre-read record for Edit'
$pRec = $pPargs[2].Trim()
$pRecArgs = Split-Args $pRec.Substring(1, $pRec.Length - 2)
$pKeys = @($pRecArgs | ForEach-Object { ($_ -split ':', 2)[0].Trim() })
$pAllowed = @('Title', "'Project Number'", "'Project Reference'", "'Customer Name'", 'Status', 'Street', "'House Number'", "'Postal Code'", 'City', 'Country', "'ProjectHomeSite URL'")
Assert-True (@($pKeys | Where-Object { $_ -cnotin $pAllowed }).Count -eq 0 -and $pKeys.Count -eq $pAllowed.Count) "Projects: Patch writes exactly the app fields: $($pKeys -join ', ')"
Assert-True ($pPatch -notmatch "Project Leader|Site Managers|ProjectLeader1|SiteManagers|Modified|\bID\s*:") 'Projects: Patch never writes Project Leader / Site Managers (person fields stay untouched), Modified or ID'
$pRecMap = @{}; foreach ($a in $pRecArgs) { $kv = $a -split ':', 2; $pRecMap[$kv[0].Trim()] = $kv[1].Trim() }
Assert-True ($pRecMap['Status'] -ceq '{Value:varPrjSaveRec.Status}') 'Projects: Status patched as {Value: ...} (choice record, no Choices() lookup)'
Assert-True ($pRecMap['Country'] -ceq 'If(IsBlank(varPrjSaveRec.Country),Blank(),{Value:varPrjSaveRec.Country})') 'Projects: Country patched as {Value: ...} (blank selection = Blank())'
Assert-True ($pRecMap["'ProjectHomeSite URL'"] -ceq 'If(IsBlank(varPrjSaveRec.Url),Blank(),varPrjSaveRec.Url)' -and $pRecMap['Title'] -ceq 'varPrjSaveRec.Name' -and $pRecMap["'Project Number'"] -ceq 'varPrjSaveRec.Number') 'Projects: Title = Name, Project Number = Number, URL text (blank = Blank())'
foreach ($f in $pWritten) { Assert-True ($pSave -match "$f\s*:\s*Trim\($([regex]::Escape((PInputOf $f))) & """"\)") "Projects: save record trims $f (Trim(x & """"))" }
foreach ($f in @('Name', 'Number', 'Reference', 'Customer', 'Street', 'HouseNumber', 'PostalCode', 'City', 'Url')) { Assert-True ($pSaveN.Contains("If(Len(varPrjSaveRec.$f)>255,Collect(colPrjSaveErrors,{Field:`"$f`"")) "Projects: length check <= 255 for $f" }
Assert-True ($pSaveN.Contains('If(IsBlank(varPrjSaveRec.Name),Collect(colPrjSaveErrors,{Field:"Name"') -and $pSaveN.Contains('If(IsBlank(varPrjSaveRec.Number),Collect(colPrjSaveErrors,{Field:"Number"')) 'Projects: Project Name and Project Number required (after Trim)'
Assert-True ($pSaveN.Contains('If(!IsBlank(varPrjSaveRec.Url)&&!StartsWith(varPrjSaveRec.Url,"https://"),Collect(colPrjSaveErrors,{Field:"Url"')) 'Projects: URL empty or starting with https://'
$pUrlFx = [regex]::Match($pSave, 'If\(!IsBlank\(varPrjSaveRec\.Url\) && !StartsWith\(varPrjSaveRec\.Url,"https://"\)').Value.Substring(3)
foreach ($c in @(@('""', $false), @('"https://geacloud.sharepoint.com/sites/TEST"', $false), @('"HTTPS://x"', $false), @('"http://x"', $true), @('"www.x.nl"', $true))) { Assert-Eval "With({varPrjSaveRec:{Url:$($c[0])}},$pUrlFx)" $c[1] "Projects: URL $($c[0]) invalid = $($c[1])" }
$pDupCmp = 'Lower(Trim(Number))=varPrjDupKey&&(varPrjSaveMode="New"||ID<>varPrjSaveID)'
Assert-True (([regex]::Matches($pSaveN, [regex]::Escape($pDupCmp))).Count -eq 2 -and $pSaveN.Contains('CountIf(colAdminProjects,' + $pDupCmp) -and $pSaveN.Contains('CountIf(colPrjDup,' + $pDupCmp)) 'Projects: duplicate Project Number blocked: loaded list and server read, trim + case-insensitive, own ID excluded'
Assert-True ($pSaveN.Contains((Norm 'Set(varPrjSaveNumber,varPrjSaveRec.Number); Set(varPrjDupKey,Lower(varPrjSaveRec.Number));'))) 'Projects: duplicate predicate variables set from the trimmed number'
Assert-True ($pSaveN -notmatch 'Filter\(Projects,Title=') 'Projects: no duplicate check on Title (only Project Number)'
$pDupFx = (Get-Balanced $pSave ($pSave.IndexOf('CountIf(colPrjDup,') + 7))
foreach ($c in @(@('"New"', 'Blank()', '"TEST-002"', 1), @('"Edit"', '5', '"TEST-002"', 0), @('"Edit"', '6', '" test-002 "', 1))) { Assert-Eval "With({colPrjDup:Table({ID:5,Number:$($c[2])}),varPrjSaveMode:$($c[0]),varPrjSaveID:$($c[1]),varPrjDupKey:Lower(`"TEST-002`")},CountIf$pDupFx)" $c[3] "Projects: duplicate count (mode $($c[0]), own ID $($c[1]), found $($c[2])) = $($c[3])" }
$pProj = [regex]::Match($pLoad, 'As prj,(\{ID:prj\.ID,[^}]*\})').Groups[1].Value
Assert-True ($pProj.Length -gt 0 -and ([regex]::Matches($pText, [regex]::Escape($pProj))).Count -eq 4) 'Projects: one projection text for load, pre-read, number check and verify read'
foreach ($c in @('Title', "'Project Number'", "'Project Reference'", "'Customer Name'", 'Status.Value', 'Street', "'House Number'", "'Postal Code'", 'City', 'Country.Value', "'Project Leader'.DisplayName", "'Site Managers'.DisplayName", "'ProjectHomeSite URL'")) { Assert-True ($pProj.Contains("Trim(prj.$c & `"`")")) "Projects: projection normalizes $c with Trim(x & `"`")" }
Assert-True ($pProj -notmatch 'Modified|Coalesce\(') 'Projects: projection has no Modified and no Coalesce(x,"")'
$pModDisp = Norm 'RemoveIf(colPrjModified,ID=varPrjPatchedID); Collect(colPrjModified,{ID:varPrjPatchedID,Modified:First(colPrjVerifyRaw).Modified});'
Assert-True (([regex]::Matches($pSaveN, [regex]::Escape($pModDisp))).Count -eq 1) 'Projects: Save updates the display-only Modified copy from the verify read, once'
$pI = [ordered]@{
    Val = $pSaveN.IndexOf('If(IsBlank(varPrjSaveRec.Name)'); DupLocal = $pSaveN.IndexOf('CountIf(colAdminProjects,'); GateRead = $pSaveN.IndexOf('If(IsEmpty(colPrjSaveErrors),IfError(Refresh(Projects),')
    Pre = $pSaveN.IndexOf('ClearCollect(colPrjPreRaw,Filter(Projects,ID=varPrjSaveID))'); Dup = $pSaveN.IndexOf('ClearCollect(colPrjDup,'); Conf = $pSaveN.IndexOf('Set(varPrjSaveConflict,true)')
    Periods = $pSaveN.IndexOf("ClearCollect(colPrjPeriods,"); WriteGate = $pSaveN.IndexOf('If(IsEmpty(colPrjSaveErrors),Set(varPrjPatchError,false);IfError(CountRows(ClearCollect(colPrjPatched,Patch(Projects,')
    Patch = $pSaveN.IndexOf('Patch(Projects,'); Verify = $pSaveN.IndexOf('ClearCollect(colPrjVerifyRaw,Filter(Projects,ID=varPrjPatchedID))'); Ok = $pSaveN.IndexOf('Set(varPrjSaveVerified,true)')
    Local = $pSaveN.IndexOf('If(varPrjSaveVerified&&IsEmpty(colPrjSaveErrors),RemoveIf(colAdminProjects,ID=varPrjPatchedID);Collect(colAdminProjects,First(colPrjVerify));')
}
$pOrder = @($pI.Values); $pOrdered = $true; for ($i = 1; $i -lt $pOrder.Count; $i++) { if ($pOrder[$i - 1] -le 0 -or $pOrder[$i] -le $pOrder[$i - 1]) { $pOrdered = $false } }
Assert-True $pOrdered "Projects: order validation -> local duplicate -> (no errors) Refresh + pre-read -> number check -> conflict -> open-period check -> (no errors) one Patch -> Refresh + verify read -> local update ($(($pI.Keys | ForEach-Object { "$_=$($pI[$_])" }) -join ' '))"
Assert-True (([regex]::Matches($pText, '(?<!Clear)Collect\(colAdminProjects,')).Count -eq 1 -and ([regex]::Matches($pText, 'RemoveIf\(colAdminProjects,')).Count -eq 1 -and $pSaveN.Contains('Set(varPrjEdit,First(colPrjVerify))')) 'Projects: colAdminProjects and the snapshot changed only by the loader and after a verified save (from the verify read)'
Assert-True ($pSaveN.Contains('varPrjSaveWrites=0,Set(varAdmMsgKind,"Error");') -and $pSaveN.Contains('Set(varPrjSaveFailed,true);Set(varPrjLoadState,"Failed");Set(varAdmMsgKind,"Error");') -and ([regex]::Matches($pSaveN, 'Set\(varPrjSaveFailed,true\)')).Count -eq 1) 'Projects: zero writes + error stays Loaded; write + error -> Failed and SaveFailed (set once; input kept, save blocked)'
# SharePoint unique constraint (MS-022) refusal reported as duplicate Project Number (field Number), other Patch errors as "not confirmed" + reason
$pPatchErr = Get-Balanced $pSave ($pSave.IndexOf('Collect(colPrjSaveErrors,{Field:If("duplicate" in Lower(FirstError.Message)') + 7)
$pPatchErrRec = (Split-Args $pPatchErr.Substring(1, $pPatchErr.Length - 2))[1].Replace('FirstError.Message', 'fe')
Assert-Eval "With({LangNl:false,T:$tRec,fe:`"The list item could not be added or updated because duplicate values were found in the following field(s) in the list: [Project Number].`"},$pPatchErrRec.Field & `"|`" & $pPatchErrRec.Message)" 'Number|Fix: Project Number already exists (refused by SharePoint).' 'Projects: SharePoint uniqueness refusal -> duplicate Project Number (red Number field)'
Assert-Eval "With({LangNl:false,T:$tRec,fe:`"Access denied.`"},$pPatchErrRec.Field & `"|`" & $pPatchErrRec.Message)" '|SharePoint error: Access denied.' 'Projects: other Patch error -> "SharePoint error:" + SharePoint reason'
Assert-True ($pSaveN.Contains('If(CountIf(colPrjSaveErrors,Field="Number")>0,Set(varPrjSaveDupFound,true));')) 'Projects: a refused duplicate is counted in the SaveEnd trace (DupFound)'

# Conflict check and verify read: exactly the app-written fields, both sides normalized
$iPTab = $pSave.IndexOf('With({d:Filter(Table(')
$pTableFx = 'Table' + (Get-Balanced $pSave ($iPTab + 'With({d:Filter(Table'.Length))
$pMcf = [regex]::Match($pSave, 'With\(\{p:First\(colPrjPre\)\},\s*If\(')
$pCfCall = Get-Balanced $pSave ($pMcf.Index + $pMcf.Length - 1)
$pConflictFx = (Split-Args $pCfCall.Substring(1, $pCfCall.Length - 2))[0]
Assert-True ((@([regex]::Matches($pTableFx, '\{F:"(\w+)"') | ForEach-Object { $_.Groups[1].Value }) -join ',') -ceq ($pWritten -join ',')) "Projects: verify compares exactly the app-written fields ($($pWritten -join ','))"
foreach ($f in $pWritten) {
    Assert-True ($pConflictFx.Contains("Trim(p.$f & `"`")<>Trim(varPrjEdit.$f & `"`")")) "Projects: conflict check compares $f (pre-read vs loaded snapshot)"
    Assert-True ($pTableFx.Contains("D:Trim(v.$f & `"`")<>Trim(varPrjSaveRec.$f & `"`")")) "Projects: verify compares $f with the written value"
}
Assert-True ($pTableFx -notmatch 'Leader|SiteManager|Modified' -and $pConflictFx -notmatch 'Leader|SiteManager|Modified') 'Projects: verify and conflict ignore the person fields (not written by the app) and Modified'
function PRaw([string]$name, [string]$num, [string]$city, [string]$status, [string]$country, [string]$empty, [string]$person) {
    return "{ID:7,Title:$name,'Project Number':$num,'Project Reference':$empty,'Customer Name':$empty,Status:$status,Street:$empty,'House Number':$empty,'Postal Code':$empty,City:$city,Country:$country,'Project Leader':$person,'Site Managers':$person,'ProjectHomeSite URL':$empty,Modified:DateTime(2026,10,30,9,0,0)}"
}
function PProj([string]$raw) { return "With({prj:$raw},$pProj)" }
$pSrFx = Get-Balanced $pSave ($pSave.IndexOf('Set(varPrjSaveRec,') + 3); $pSrFx = $pSrFx.Substring('(varPrjSaveRec,'.Length, $pSrFx.Length - '(varPrjSaveRec,'.Length - 1)
function PVerify([string]$raw, [string]$inputs, [string]$col) { return "With({LangNl:false,T:$tRec},With({v:$(PProj $raw),varPrjSaveRec:With({$inputs},$pSrFx)},Concat(Filter($pTableFx,D),$col,`",`")))" }
$bT = 'If(false,"x")'; $bC = 'If(false,{Value:"x"})'; $bP = 'If(false,{DisplayName:"x"})'
$pRawBlank = PRaw '"TEST Project 2"' '"TEST-002"' $bT '{Value:"Active"}' $bC $bT $bP
$pRawEmpty = PRaw '"TEST Project 2"' '"TEST-002"' '""' '{Value:"Active"}' $bC '""' '{DisplayName:""}'
$pInEmpty = PIn '"TEST Project 2"' '"TEST-002"' '""' '"Active"' 'If(false,"x")' '""'
$pInBlank = PIn '"TEST Project 2"' '"TEST-002"' $bT '"Active"' $bT $bT
Assert-Eval (PVerify $pRawBlank $pInEmpty 'F') '' 'Projects: verify passes: SharePoint Blank fields / blank Country, inputs ""'
Assert-Eval (PVerify $pRawEmpty $pInBlank 'F') '' 'Projects: verify passes: SharePoint "" fields, inputs Blank'
Assert-Eval (PVerify $pRawBlank (PIn '" TEST Project 2 "' '" TEST-002"' '"  "' '"Active"' $bT '" "') 'F') '' 'Projects: verify passes: inputs with surrounding spaces are trimmed before writing'
Assert-Eval (PVerify (PRaw '"TEST Project 2"' '"TEST-002"' $bT '{Value:"Active"}' $bC $bT '{DisplayName:"Someone"}') $pInEmpty 'F') '' 'Projects: verify passes when only the person fields differ (not written by the app)'
Assert-Eval (PVerify (PRaw '"TEST Project 2"' '"TEST-002"' $bT '{Value:"On hold"}' $bC $bT $bP) $pInEmpty 'F') 'Status' 'Projects: verify fails on Status and names only that field'
Assert-Eval (PVerify (PRaw '"TEST Project 2"' '"TEST-002"' $bT '{Value:"Active"}' '{Value:"Netherlands"}' $bT $bP) $pInEmpty 'L') 'Country' 'Projects: verify fails on Country (label in the message)'
Assert-Eval (PVerify (PRaw '"TEST Project 2"' '"TEST-020"' $bT '{Value:"Active"}' $bC $bT $bP) $pInEmpty 'F') 'Number' 'Projects: verify fails on Project Number'
function PConflict([string]$preRaw, [string]$snapRaw) { return "With({p:$(PProj $preRaw),varPrjEdit:$(PProj $snapRaw),varPrjSaveID:7},$pConflictFx)" }
Assert-Eval (PConflict $pRawBlank $pRawBlank) $false 'Projects: conflict does not fire: unchanged row'
Assert-Eval (PConflict $pRawEmpty $pRawBlank) $false 'Projects: conflict does not fire: "" versus Blank in SharePoint'
Assert-Eval (PConflict (PRaw '"TEST Project 2"' '"TEST-002"' $bT '{Value:"Active"}' $bC $bT '{DisplayName:"Someone"}') $pRawBlank) $false 'Projects: conflict does not fire when only a person field changed'
Assert-Eval (PConflict (PRaw '"TEST Project 2"' '"TEST-002"' $bT '{Value:"Closed"}' $bC $bT $bP) $pRawBlank) $true 'Projects: conflict fires: another user closed the project'
Assert-Eval (PConflict (PRaw '"TEST Project 2"' '"TEST-002"' '"Rotterdam"' '{Value:"Active"}' $bC $bT $bP) $pRawBlank) $true 'Projects: conflict fires: another user changed City'
function PDirty([string]$snapRaw, [string]$inputs) { return "With({varPrjMode:`"Edit`",varPrjEdit:$(PProj $snapRaw),$inputs},$pDirty)" }
Assert-Eval (PDirty $pRawBlank $pInEmpty) $false 'Projects: not dirty: snapshot from Blank fields, inputs ""'
Assert-Eval (PDirty $pRawEmpty $pInBlank) $false 'Projects: not dirty: snapshot from "" fields, inputs Blank'
Assert-Eval (PDirty $pRawBlank (PIn '"TEST Project 2"' '"TEST-002"' '""' '"On hold"' $bT '""')) $true 'Projects: dirty: Status changed'
Assert-Eval (PDirty (PRaw '"TEST Project 2"' '"TEST-002"' $bT $bC $bC $bT $bP) (PIn '"TEST Project 2"' '"TEST-002"' '""' $bT $bT '""')) $false 'Projects: not dirty: blank Status in SharePoint and blank dropdown selection'

# Closing a project: open assignment periods -> amber warning after the save; never blocks, never closes periods
$pChkFx = Get-Balanced $pSave ($pSave.IndexOf('Set(varPrjSaveCheckPeriods,') + 3); $pChkFx = $pChkFx.Substring('(varPrjSaveCheckPeriods,'.Length, $pChkFx.Length - '(varPrjSaveCheckPeriods,'.Length - 1)
foreach ($c in @(@('"Edit"', '5', '"Active"', '"Closed"', $true), @('"Edit"', '5', '"On hold"', '"Closed"', $true), @('"Edit"', '5', '"Closed"', '"Closed"', $false), @('"Edit"', '5', '"Active"', '"On hold"', $false), @('"New"', 'Blank()', '"Active"', '"Closed"', $false), @('"Edit"', 'Blank()', '"Active"', '"Closed"', $false))) {
    Assert-Eval "With({varPrjSaveMode:$($c[0]),varPrjSaveID:$($c[1]),varPrjEdit:{Status:$($c[2])},varPrjSaveRec:{Status:$($c[3])}},$pChkFx)" $c[4] "Projects: open-period check when $($c[0]) $($c[2]) -> $($c[3]): $($c[4])"
}
$pPerStart = $pSave.IndexOf('If(IsEmpty(colPrjSaveErrors) && varPrjSaveCheckPeriods,')
Assert-True ($pPerStart -gt 0) 'Projects: open-period read only when no errors and the status changes to Closed'
$pPer = Get-Balanced $pSave ($pPerStart + 2)
Assert-True ($pPer.Contains("IfError(Refresh('Assignment Periods'),Set(varPrjSavePeriodsUnchecked,true);false);") -and $pPer.IndexOf("Refresh('Assignment Periods')") -lt $pPer.IndexOf("Filter('Assignment Periods'")) 'Projects: Assignment Periods refreshed before the period read (H16)'
Assert-True ($pPer.Contains("ClearCollect(colPrjPeriods,ForAll(Filter('Assignment Periods',ProjectKey=varPrjSaveKey) As ap,{ID:ap.ID,ProjectKey:ap.ProjectKey,Until:ap.Until}))") -and $pPer.Contains('If(CountRows(colPrjPeriods)>=500,Set(varPrjSavePeriodsUnchecked,true));')) 'Projects: delegable period read (ProjectKey = global var) with 500 guard -> "could not be checked" (fail-closed warning)'
Assert-True (([regex]::Matches($pPer, 'Set\(varPrjSavePeriodsUnchecked,true\)')).Count -eq 3 -and ([regex]::Matches($pPer, 'colPrjSaveErrors')).Count -eq 1 -and $pPer -notmatch '\b(Patch|Remove|RemoveIf|Update|UpdateIf)\(') 'Projects: Refresh error, read error and >= 500 rows only mark "not checked"; the period check never adds a save error and never writes periods'
$pOpenFx = Get-Balanced $pPer ($pPer.IndexOf('Set(varPrjSaveOpenPeriods,') + 3); $pOpenFx = $pOpenFx.Substring('(varPrjSaveOpenPeriods,'.Length, $pOpenFx.Length - '(varPrjSaveOpenPeriods,'.Length - 1)
Assert-Eval "With({varPrjSaveKey:`"5`",colPrjPeriods:Table({ID:1,ProjectKey:`"5`",Until:If(false,Date(2000,1,1))},{ID:2,ProjectKey:`"5`",Until:Date(2026,10,25)},{ID:3,ProjectKey:`"6`",Until:If(false,Date(2000,1,1))},{ID:4,ProjectKey:`"5`",Until:If(false,Date(2000,1,1))})},$pOpenFx)" 2 'Projects: open periods = this ProjectKey with empty Until (closed periods and other projects not counted)'
Assert-Eval 'With({varPrjSaveMode:"Edit",varPrjSaveID:12},If(varPrjSaveMode="Edit",Text(varPrjSaveID),""))' '12' 'Projects: ProjectKey for the period read = Text(project ID) (same as Screen1 ProjectKey)'
Assert-True ($pSave.Contains('Set(varPrjSaveKey,If(varPrjSaveMode="Edit",Text(varPrjSaveID),""))')) 'Projects: varPrjSaveKey formula as evaluated'

# (P9) Cache invalidation after a verified save
$pOkBranch = $pSaveN.Substring($pI.Local)
foreach ($k in @('Set(varProjectsCacheReady,false)', 'Set(varMastersReady,false)', 'Set(varReportReady,false)', 'Set(varReportValid,false)')) { Assert-True ($pOkBranch.Contains($k) -and $pOkBranch.IndexOf($k) -lt $pOkBranch.IndexOf('varPrjSaveWrites=0,')) "Projects: verified save invalidates $k (success branch only)" }
Assert-True ($pSaveN.Contains('If(IsEmpty(colPrjSaveErrors),IfError(Refresh(Projects),Collect(colPrjSaveErrors,{Field:"",Message:If(LangNl&&!IsBlank(T.prjErrVerify.nl)')) 'Projects: Projects connector refreshed before the verify read (cache invalidation incl. Refresh)'

# (P10) Traces: no names, values or FirstError.Message
$pTraces = 0
foreach ($k in $pAll.Keys) {
    foreach ($m in [regex]::Matches($pAll[$k], '\bTrace\(')) {
        $pTraces++
        $t = Get-Balanced $pAll[$k] ($m.Index + 5)
        Assert-True ($t.StartsWith('("DIAG|Projects|')) "Projects: $k : trace name DIAG|Projects|..."
        Assert-True ($t -notmatch 'FirstError|txtPrj|ddPrj|varPrjSaveRec|varPrjSaveNumber|varPrjDupKey|varPrjEdit\.|\.Name\b|\.Number\b|Title|Message|varAdmMsg') "Projects: $k : trace has no names, numbers, values, messages or FirstError.Message"
    }
}
Assert-True ($pTraces -ge 10) "Projects: traces checked: $pTraces"
Assert-True ($pSaveN.Contains((Norm 'Trace("DIAG|Projects|SaveEnd",TraceSeverity.Information,{Screen:"Projects",Mode:varPrjSaveMode,ItemID:Coalesce(varPrjPatchedID,varPrjSaveID,0),ElapsedMs:DateDiff(varPrjDiagT0,Now(),TimeUnit.Milliseconds),Reads:varPrjSaveReads,Writes:varPrjSaveWrites,Verified:varPrjSaveVerified,DupFound:varPrjSaveDupFound,Conflict:varPrjSaveConflict,OpenPeriods:varPrjSaveOpenPeriods,PeriodsUnchecked:varPrjSavePeriodsUnchecked,Errors:CountRows(colPrjSaveErrors)})'))) 'Projects: SaveEnd trace with Mode/ItemID/ElapsedMs/Reads/Writes/Verified/DupFound/Conflict/OpenPeriods/Errors'
Assert-True ($pSaveN.Contains((Norm 'Trace("DIAG|Projects|VerifyMismatch",TraceSeverity.Warning,{Screen:"Projects",ItemID:Coalesce(varPrjPatchedID,0),Rows:CountRows(colPrjVerifyRaw),Fields:varPrjVerifyDiff})'))) 'Projects: VerifyMismatch trace with field names only'
$pFe = @([regex]::Matches($pText, 'FirstError\.Message'))
$pFeOk = @($pFe | Where-Object { $pText.Substring([Math]::Max(0, $_.Index - 400), [Math]::Min(400, $_.Index)) -match 'Collect\(col\w*Errors,\{[^{}]*$' })
Assert-True ($pFe.Count -eq 5 -and $pFeOk.Count -eq $pFe.Count) "Projects: FirstError.Message only inside the shown error collections ($($pFe.Count) uses: 2 x load, 3 x Patch error record)"

# (P11) User texts via T
$pUsedT = @([regex]::Matches($pText, '\bT\.(\w+)\.(?:en|nl)\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True (@($pUsedT | Where-Object { $_ -notmatch '^(prj|adm)' }).Count -eq 0) "Projects: only prj* and shared adm* T keys used ($($pUsedT.Count))"
$pPrjKeys = @($tKeys | Where-Object { $_ -like 'prj*' })
Assert-True ($pPrjKeys.Count -ge 50 -and @($pPrjKeys | Where-Object { $_ -cnotin $pUsedT -and $_ -cnotin $pendingUiT }).Count -eq 0) "Projects: all $($pPrjKeys.Count) prj* T keys exist with English text and are used on scrProjects (nl empty)"
$pPrjOk = @([regex]::Matches($formulas, '(?m)^\s*prj\w+:\s*\{en:\s*"[^"]+",\s*nl:\s*""\}')).Count
Assert-True ($pPrjOk -eq $pPrjKeys.Count) "Projects: every prj* key has an English text and an empty nl text ($pPrjOk of $($pPrjKeys.Count))"
$pHard = @()
foreach ($k in $pAll.Keys) {
    $fx = $pAll[$k]
    if ($k -like '*.Font' -or $k -eq 'imgPrjSpinner.Image') { continue }
    if ($k -like '*.OnVisible' -or $k -like '*.OnSelect') { $fx = [regex]::Replace($fx, 'Trace\("[^"]*"', 'Trace(') }
    foreach ($lit in [regex]::Matches($fx, '"([^"]*)"')) { if ($lit.Groups[1].Value -match '[A-Za-z]{2,}\s+[A-Za-z]') { $pHard += "$k : `"$($lit.Groups[1].Value)`"" } }
}
Assert-True ($pHard.Count -eq 0) "Projects: no hard-coded sentences (all user texts via T) $($pHard -join '; ')"
$pLit = @()
foreach ($n in $pIdx.Keys) {
    $props = $pIdx[$n]['Properties']; if (([string]$props['Visible']).Trim() -eq '=false') { continue }
    foreach ($p in @('Text', 'HintText', 'AccessibleLabel', 'Tooltip')) {
        if (!$props.ContainsKey($p) -or ($n -like 'imgLogo*' -and $p -eq 'AccessibleLabel')) { continue }
        if (([string]$props[$p]).Trim() -match '^="[^"]*[A-Za-z][^"]*"$') { $pLit += "$n.$p" }
    }
}
Assert-True ($pLit.Count -eq 0) "Projects: visible captions use T, no literal text $($pLit -join ', ')"
$pTexts = [ordered]@{ prjTitle = 'Projects'; prjSearchHint = 'Search number, name or city'; prjCount = '{0} projects'; prjShowInactive = 'Show inactive'; prjNewProject = 'New project'; prjSecGeneral = 'GENERAL'; prjSecAddress = 'ADDRESS'; prjSecPeople = 'PEOPLE'; prjSecLinks = 'LINKS'; prjLastChanged = 'Last changed in SharePoint: {0}'; prjErrConflict = 'Changed in SharePoint by someone else. Nothing saved. Click Discard, then Refresh.'; prjErrDuplicate = 'Fix: Project Number already exists' }
foreach ($k in $pTexts.Keys) { Assert-True ($formulas.Contains("$($k): {en: ""$($pTexts[$k])"", nl: """"}")) "Projects: T.$k = '$($pTexts[$k])'" }

# (P14) Refresh before every SharePoint read (H16), form reset, Modified display -----------------------------------------
$pBeh = @{}
foreach ($p in $pScreenProps.Keys) { if ($p -like 'On*') { $pBeh["$pScreen.$p"] = [string]$pScreenProps[$p] } }
Get-BehaviourFormulas $pDoc['Screens'][$pScreen]['Children'] $pScreen $pBeh
$pSp = @()
foreach ($k in ($pBeh.Keys | Sort-Object)) { foreach ($r in (Test-RefreshBeforeReads $pBeh[$k])) { $pSp += $r; Assert-True ($r.Status -eq 'Refreshed') "Projects: $k : read of $($r.Source) (formula line $($r.Line)) preceded by Refresh($($r.Source)) in the same branch [$($r.Status)]" } }
Assert-True (@($pSp | Where-Object Source -eq 'Projects').Count -eq 4 -and @($pSp | Where-Object Source -eq "'Assignment Periods'").Count -eq 1 -and $pSp.Count -eq 5) "Projects: SharePoint reads: 4 x Projects (load, pre-read, number check, verify), 1 x Assignment Periods (closing check)"
$pFr = PGet 'btnPrjFormReset' 'OnSelect'
$pReset = 'Reset(txtPrjName); Reset(txtPrjNumber); Reset(txtPrjReference); Reset(txtPrjCustomer); Reset(ddPrjStatus); Reset(txtPrjStreet); Reset(txtPrjHouseNumber); Reset(txtPrjPostalCode); Reset(txtPrjCity); Reset(ddPrjCountry); Reset(txtPrjUrl)'
Assert-True ($pIdx['btnPrjFormReset']['Control'] -eq 'Classic/Button@2.2.0' -and (PGet 'btnPrjFormReset' 'Visible') -eq '=false' -and $pFr.StartsWith('=If(varPrjLoadState="Loaded" && IsEmpty(colPrjLoadErrors) && !Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && !Coalesce(varPrjSaveFailed,false),') -and $pFr.Contains($pReset)) 'Projects: hidden btnPrjFormReset resets all 11 inputs only when Loaded/idle/no failed save'
Assert-True ($pFr -notmatch '\b(Patch|Refresh|Collect|ClearCollect|Remove|RemoveIf|Clear|Set|UpdateContext|Select|Navigate)\(') 'Projects: form reset is local only (no mutation, no variable change, no further Select)'
Assert-True (([regex]::Matches($pText, 'Select\(btnPrjFormReset\)')).Count -eq 2 -and $pLoad.IndexOf('If(varPrjLoadState="Loaded",Select(btnPrjFormReset))') -gt $pLoad.LastIndexOf('Set(varPrjForceRefresh,false); Set(varPrjBusy,false);')) 'Projects: form reset selected at the end of the loader (after busy off) and after a verified save'
foreach ($k in @('btnPrjLoad.OnSelect', 'btnPrjSave.OnSelect', 'btnPrjNew.OnSelect', 'btnPrjDiscard.OnSelect', 'galPrjList.OnSelect')) { Assert-True ($pAll[$k].Contains($pReset)) "Projects: $k resets all form inputs (incl. both dropdowns)" }
foreach ($k in @($pTextFields.Keys) + @($pDropFields.Keys)) { Assert-True (!$pIdx[$k]['Properties'].ContainsKey('Reset')) "Projects: $k has no Reset property (Reset() calls only)" }
$pModFx = (PGet 'lblPrjModified' 'Text').TrimStart('=')
Assert-True ($pModFx.Contains('LookUp(colPrjModified,ID=varPrjSelectedID).Modified') -and $pModFx -notmatch '\b(Projects|Filter)\b') 'Projects: lblPrjModified reads the local Modified copy only'
$pModUses = @($pAll.Keys | Where-Object { $pAll[$_] -match 'Modified' } | Sort-Object)
Assert-True (($pModUses -join ',') -ceq 'btnPrjLoad.OnSelect,btnPrjSave.OnSelect,lblPrjMetrics.Y,lblPrjModified.Text') "Projects: Modified used only in loader, save display update, lblPrjModified and its height carrier ($($pModUses -join ', '))"
$pModFix = 'LangNl:false,T:' + $tRec + ',colPrjModified:Table({ID:7,Modified:DateTime(2026,10,30,8,5,0)})'
Assert-Eval ('With({' + $pModFix + ',varPrjMode:"Edit",varPrjSelectedID:7},' + $pModFx + ')') 'Last changed in SharePoint: 30-10-2026 08:05' 'Projects: Last changed line (Edit): dd-mm-yyyy hh:mm'
Assert-Eval ('With({' + $pModFix + ',varPrjMode:"New",varPrjSelectedID:Blank()},' + $pModFx + ')') '' 'Projects: Last changed line empty for New'
Assert-True ($pLoad.Contains('Set(varPrjLoadedAt,Now());') -and $pLoad.IndexOf('Set(varPrjLoadedAt,Now());') -gt $pLoad.IndexOf('If(IsEmpty(colPrjLoadErrors),') -and ([regex]::Matches($pText, 'Set\(varPrjLoadedAt,')).Count -eq 1) 'Projects: load time set only in the successful-load branch'

# (P15) Messages only via the shared admin message bar (varAdmMsgKind/Head/Body), same head mapping as Contractors ---------
Assert-True ($pText -notmatch '\bNotify\(' -and $pText -notmatch 'NotificationType\.') 'Projects: no Notify(), no NotificationType'
Assert-True (!$pIdx.ContainsKey('lblPrjStatus') -and !$pIdx.ContainsKey('lblPrjErrors')) 'Projects: no status line or error list (messages only in the bar)'
$pMsgs = @()
foreach ($k in ($pAll.Keys | Sort-Object)) {
    $fx = $pAll[$k]
    foreach ($m in [regex]::Matches($fx, '\bSet\(varAdmMsgKind,')) {
        $kc = Get-SetArg $fx ($m.Index + 3) 'varAdmMsgKind'
        $rest = $fx.Substring($m.Index + 3 + $kc[0].Length)
        $mh = [regex]::Match($rest, '^;\s*Set\(varAdmMsgHead,')
        Assert-True ($k -match '\.On\w+$' -and $mh.Success) "Projects: $k : Set(varAdmMsgKind,$($kc[1])) in a behaviour formula, directly followed by Set(varAdmMsgHead,...)"
        $hc = Get-SetArg $rest ($mh.Index + $mh.Length - 'varAdmMsgHead,'.Length - 1) 'varAdmMsgHead'
        $rest2 = $rest.Substring($mh.Index + $mh.Length - 'varAdmMsgHead,'.Length - 1 + $hc[0].Length)
        $mb = [regex]::Match($rest2, '^;\s*Set\(varAdmMsgBody,')
        Assert-True $mb.Success "Projects: $k : Set(varAdmMsgHead,...) directly followed by Set(varAdmMsgBody,...)"
        $bc = Get-SetArg $rest2 ($mb.Index + $mb.Length - 'varAdmMsgBody,'.Length - 1) 'varAdmMsgBody'
        $pMsgs += [pscustomobject]@{ Key = $k; Pos = $m.Index; Kind = $kc[1].Trim(); Head = $hc[1].Trim(); Body = $bc[1].Trim() }
    }
}
foreach ($v in @('varAdmMsgKind', 'varAdmMsgHead', 'varAdmMsgBody')) { Assert-True (([regex]::Matches($pText, "\bSet\($v,")).Count -eq $pMsgs.Count) "Projects: Set($v,...) only inside a kind/head/body triple ($($pMsgs.Count) triples)" }
$pWarnKeys = @('prjWarnOpenPeriods', 'prjWarnPeriodsUnchecked'); $pSuccessKeys = @('prjMsgLoaded', 'prjMsgSavedRenumber', 'prjMsgDiscarded')
$pKinds = @{}
foreach ($c in $pMsgs) {
    $pKinds[$c.Kind] = 1 + [int]$pKinds[$c.Kind]
    if ($c.Kind -eq '""') { Assert-True ($c.Head -eq '""' -and $c.Body -eq '""' -and $c.Key -in @('icoPrjMsgClose.OnSelect', 'scrProjects.OnVisible')) "Projects: $($c.Key) : clear only in Close and OnVisible"; continue }
    Assert-True ($headsByKind.ContainsKey($c.Kind)) "Projects: $($c.Key) : kind $($c.Kind) is Error, Warning or Success"
    $hm = [regex]::Match($c.Head, '^If\(LangNl && !IsBlank\(T\.(admHead\w+)\.nl\),T\.\1\.nl,T\.\1\.en\)$')
    Assert-True ($hm.Success -and $hm.Groups[1].Value -in $headsByKind[$c.Kind]) "Projects: $($c.Key) : $($c.Kind) head from T ($($hm.Groups[1].Value)) is one of $($headsByKind[$c.Kind] -join '/') (same mapping as Contractors)"
    $head = $hm.Groups[1].Value
    $bk = @([regex]::Matches($c.Body, '\bT\.(\w+)\.en\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $lbl = "Projects: $($c.Key) : $($c.Kind)/$head body (T: $($bk -join ','))"
    switch ($c.Kind) {
        '"Error"' { Assert-True (@($bk | Where-Object { $_ -in $pWarnKeys -or $_ -in $pSuccessKeys }).Count -eq 0) "$lbl has no warning or success text" }
        '"Warning"' { Assert-True (@($bk | Where-Object { $_ -in $pWarnKeys }).Count -eq 2 -and @($bk | Where-Object { $_ -notin ($pWarnKeys + 'prjMsgSavedRenumber' + 'admMsgSavedPrefix') }).Count -eq 0) "$lbl carries the period warnings, nothing else except the Saved. prefix and the renumber note" }
        '"Success"' { Assert-True (@($bk | Where-Object { $_ -notin $pSuccessKeys }).Count -eq 0) "$lbl has only success texts" }
    }
    switch ($head) {
        'admHeadBlocked' { Assert-True ($c.Body -ceq (TT 'prjMsgActionBlocked') -or $c.Body -ceq (TT 'prjMsgReloadBlocked')) "$lbl = action / reload blocked" }
        'admHeadNotLoaded' { Assert-True ($bk -contains 'prjMsgLoadFailed' -and $c.Body.Contains('First(colPrjLoadErrors).Message')) "$lbl = load failed + first load error" }
        'admHeadLoaded' { Assert-True ($bk -contains 'prjMsgLoaded') "$lbl = loaded count/time" }
        'admHeadDiscarded' { Assert-True ($c.Body -ceq (TT 'prjMsgDiscarded')) "$lbl = changes discarded" }
        'admHeadNotSaved' { Assert-True ($c.Body.Contains('First(colPrjSaveErrors).Message')) "$lbl = first save error (+n more)" }
        'admHeadSaved' { Assert-True ($c.Key -eq 'btnPrjSave.OnSelect') "$lbl only after a verified save" }
        'admHeadAttention' { Assert-True ($c.Key -eq 'btnPrjSave.OnSelect' -and $c.Kind -eq '"Warning"' -and $c.Body.StartsWith('Trim(' + (TT 'admMsgSavedPrefix') + ' & " " & ')) "$lbl = only the verified save with a warning (amber, body starts with Saved.); no live Attention message" }
    }
}
Assert-True ($pKinds['"Error"'] -eq 9 -and $pKinds['"Warning"'] -eq 1 -and $pKinds['"Success"'] -eq 3 -and $pKinds['""'] -eq 2) "Projects: message kinds 9 x Error, 1 x Warning (save with open periods), 3 x Success, 2 x clear ($(($pKinds.Keys | Sort-Object | ForEach-Object { "$_=$($pKinds[$_])" }) -join ' '))"
$pExpMsg = [ordered]@{ 'btnPrjDiscard.OnSelect' = 2; 'btnPrjLoad.OnSelect' = 3; 'btnPrjNew.OnSelect' = 1; 'btnPrjRefresh.OnSelect' = 1; 'btnPrjSave.OnSelect' = 5; 'galPrjList.OnSelect' = 1; 'icoPrjMsgClose.OnSelect' = 1; 'scrProjects.OnVisible' = 1 }
$pGotMsg = (($pMsgs | Group-Object Key | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ';')
Assert-True ($pGotMsg -ceq (($pExpMsg.Keys | Sort-Object | ForEach-Object { "$_=$($pExpMsg[$_])" }) -join ';')) "Projects: messages per formula as expected: $pGotMsg"
$pBlockedN = Norm (',' + 'Set(varAdmMsgKind,"Error"); Set(varAdmMsgHead,' + (TT 'admHeadBlocked') + '); Set(varAdmMsgBody,' + (TT 'prjMsgActionBlocked') + '))')
foreach ($ctl in @('btnPrjSave', 'btnPrjNew', 'btnPrjRefresh', 'btnPrjDiscard', 'galPrjList')) { Assert-True ((Norm (PGet $ctl 'OnSelect')).EndsWith($pBlockedN)) "Projects: $ctl : the guard's else branch shows Blocked. (error, no mutation)" }
$pSaveMsg = @($pMsgs | Where-Object Key -eq 'btnPrjSave.OnSelect' | Sort-Object Pos)
Assert-True ((($pSaveMsg | ForEach-Object { $_.Kind }) -join ',') -ceq '"Warning","Success","Error","Error","Error"') 'Projects: save messages in order: warning, success, zero-write error, failed-save error, blocked'
$pOutHead = 'If(varPrjSaveOpenPeriods>0 || varPrjSavePeriodsUnchecked,'
Assert-True (([regex]::Matches($pSave, [regex]::Escape($pOutHead))).Count -eq 1 -and $pSaveN.IndexOf((Norm $pOutHead)) -gt $pI.Local -and $pSaveN.IndexOf((Norm $pOutHead)) -lt $pSaveN.IndexOf('varPrjSaveWrites=0,')) 'Projects: verified save shows one message: amber when periods are open or unchecked, else green; head "Saved." in both'
function PMsg([string]$fixture, [string]$fx) { return "With({LangNl:false,T:$tRec},With({$fixture},$fx))" }
Assert-Eval (PMsg 'x:0' $pSaveMsg[0].Head) 'Attention.' 'Projects: amber save message head = Attention.'
Assert-Eval (PMsg 'varPrjSaveRenumbered:false,varPrjSaveOpenPeriods:2,varPrjSavePeriodsUnchecked:false' $pSaveMsg[0].Body) 'Saved. Status Closed: 2 open assignment period(s) remain; they are not closed automatically.' 'Projects: Saved. + open-period warning (amber)'
Assert-Eval (PMsg 'varPrjSaveRenumbered:false,varPrjSaveOpenPeriods:0,varPrjSavePeriodsUnchecked:true' $pSaveMsg[0].Body) 'Saved. Status Closed: open assignment periods could not be checked; check Project / team.' 'Projects: Saved. + "could not be checked" warning (read error or >= 500 rows)'
Assert-Eval (PMsg 'varPrjSaveRenumbered:true,varPrjSaveOpenPeriods:1,varPrjSavePeriodsUnchecked:false' $pSaveMsg[0].Body) 'Saved. The new number also shows in Hours Summary. Status Closed: 1 open assignment period(s) remain; they are not closed automatically.' 'Projects: renumber note + period warning in one amber message'
Assert-Eval (PMsg 'varPrjSaveRenumbered:false' $pSaveMsg[1].Body) '' 'Projects: green message: only the head "Saved."'
Assert-Eval (PMsg 'colPrjSaveErrors:Table({Field:"Number",Message:T.prjErrDuplicate.en},{Field:"",Message:"y"})' $pSaveMsg[2].Body) 'Fix: Project Number already exists (+1 more)' 'Projects: zero-write error: first error (+n more)'
Assert-Eval (PMsg 'varPrjSaveMode:"New",colPrjSaveErrors:Table({Field:"",Message:T.prjErrPatch.en})' $pSaveMsg[3].Body) 'Save not confirmed by SharePoint. Maybe created: click Discard, then search the number before retrying.' 'Projects: failed-save error (New)'
$pLoadMsg = @($pMsgs | Where-Object Key -eq 'btnPrjLoad.OnSelect' | Sort-Object Pos)
Assert-True ((($pLoadMsg | ForEach-Object { $_.Kind }) -join ',') -ceq '"Error","Success","Error"') 'Projects: loader messages in order: reload blocked, loaded, load failed'
Assert-Eval (PMsg 'colAdminProjects:Table({ID:1},{ID:2}),varPrjLoadedAt:DateTime(2026,10,30,8,5,7)' $pLoadMsg[1].Body) '2 projects loaded at 08:05:07' 'Projects: load success message: count and time'
Assert-Eval (PMsg 'colPrjLoadErrors:Table({Message:T.prjErrLoadProjects.en & " " & "Network error"},{Message:T.prjErrLimitProjects.en})' $pLoadMsg[2].Body) 'Loading failed. Click Refresh. Projects not read: Network error (+1 more)' 'Projects: load failure message'
$pBarExp = [ordered]@{ X = '=lblPrjTitle.X'; Y = '=lblPrjTitle.Y+lblPrjTitle.Height'; Width = '=lblPrjTitle.Width'; Height = '=If(!IsBlank(varAdmMsgKind),40,0)'; Visible = '=!IsBlank(varAdmMsgKind)'; Fill = '=Switch(varAdmMsgKind,"Error",ColorValue("#DB1E28"),"Warning",ColorValue("#F29400"),"Success",ColorValue("#1AFF80"),Color.Transparent)' }
foreach ($k in $pBarExp.Keys) { Assert-True ((PGet 'conPrjMsgBar' $k) -ceq $pBarExp[$k]) "Projects: conPrjMsgBar.$k = $($pBarExp[$k]) (same as Contractors)" }
foreach ($c in @('lblPrjMsgHead', 'lblPrjMsgBody', 'icoPrjMsgClose')) { Assert-True ((PGet $c 'Color') -ceq $textColFx) "Projects: $c.Color white on red, #000F41 on amber/green" }
Assert-True ((PGet 'lblPrjMsgHead' 'Text') -ceq '=varAdmMsgHead' -and (PGet 'lblPrjMsgBody' 'Text') -ceq '=varAdmMsgBody' -and (PGet 'icoPrjMsgClose' 'OnSelect') -ceq '=Set(varAdmMsgKind,""); Set(varAdmMsgHead,""); Set(varAdmMsgBody,"")' -and $pVis.StartsWith('=Set(varAdmMsgKind,""); Set(varAdmMsgHead,""); Set(varAdmMsgBody,"");')) 'Projects: bar shows the shared variables; Close and OnVisible clear them first'
$pBarReaders = @($pAll.Keys | Where-Object { $_ -notmatch '\.On\w+$' -and $pAll[$_] -match '\bvarAdmMsg(Kind|Head|Body)\b' } | ForEach-Object { ($_ -split '\.')[0] } | Sort-Object -Unique)
Assert-True (($pBarReaders -join ',') -ceq 'conPrjMsgBar,icoPrjMsgClose,lblPrjMsgBody,lblPrjMsgHead') "Projects: message variables only displayed by the bar controls ($($pBarReaders -join ', '))"

# (P16) List card: search on number/name/city, Show inactive = show Closed (default off), On hold counts as active --------
Assert-True ((PGet 'txtPrjSearch' 'HintText') -eq (TT 'prjSearchHint').Insert(0, '=') -and (PGet 'txtPrjSearch' 'AccessibleLabel') -eq (PGet 'txtPrjSearch' 'HintText')) 'Projects: search hint/label from T ("Search number, name or city")'
Assert-True ((PGet 'lblPrjCount' 'Text') -ceq ('=Substitute(' + (TT 'prjCount') + ',"{0}",Text(CountRows(galPrjList.AllItems)))')) 'Projects: count "{0} projects" = visible gallery rows'
Assert-True ((PGet 'btnPrjShowInactiveSwitch' 'OnSelect') -ceq '=Set(varPrjShowInactive,!Coalesce(varPrjShowInactive,false))' -and (PGet 'btnPrjShowInactiveSwitch' 'DisplayMode') -ceq '=DisplayMode.Edit' -and (PGet 'btnPrjShowInactiveKnob' 'OnSelect') -ceq '=Select(btnPrjShowInactiveSwitch)' -and (PGet 'btnPrjShowInactiveKnob' 'DisplayMode') -ceq '=btnPrjShowInactiveSwitch.DisplayMode') 'Projects: Show inactive switch toggles a local filter only (knob forwards to the track)'
$pSi = @($pAll.Keys | Where-Object { $pAll[$_] -match 'Set\(varPrjShowInactive,' } | Sort-Object)
Assert-True (($pSi -join ',') -ceq 'btnPrjShowInactiveSwitch.OnSelect,scrProjects.OnVisible' -and $pVis.Contains('Set(varPrjShowInactive,false)')) 'Projects: varPrjShowInactive only set by its switch and the first-visit init (false = Closed hidden)'
$pItems = (PGet 'galPrjList' 'Items').TrimStart('=')
$pItemFix = 'colAdminProjects:Table({ID:1,Name:"Alpha",Number:"TEST-002",Customer:"Cust",City:"Delft",Status:"Active"},{ID:2,Name:"Beta",Number:"TEST-001",Customer:"",City:"Ede",Status:"On hold"},{ID:3,Name:"Gamma",Number:"P-9",Customer:"",City:"Venlo",Status:"Closed"},{ID:4,Name:"Delta",Number:"A-1",Customer:"",City:"",Status:""})'
function PItems([string]$show, [string]$search, [string]$col) { return "With({$pItemFix,varPrjShowInactive:$show,txtPrjSearch:{Text:$search}},Concat($pItems,$col,`",`"))" }
Assert-Eval (PItems 'false' '""' 'Number') 'A-1,TEST-001,TEST-002' 'Projects: default list hides Closed, shows On hold and blank Status; sorted by Project Number'
Assert-Eval (PItems 'true' '""' 'Number') 'A-1,P-9,TEST-001,TEST-002' 'Projects: Show inactive on: Closed projects shown too'
Assert-Eval (PItems 'If(false,true)' '""' 'Number') 'A-1,TEST-001,TEST-002' 'Projects: blank switch state = Closed hidden'
Assert-Eval (PItems 'true' '" test-00 "' 'Number') 'TEST-001,TEST-002' 'Projects: search on Project Number (trim, case-insensitive)'
Assert-Eval (PItems 'true' '"gam"' 'Number') 'P-9' 'Projects: search on Project Name'
Assert-Eval (PItems 'true' '"ede"' 'Number') 'TEST-001' 'Projects: search on City'
Assert-Eval (PItems 'true' '"cust"' 'Number') '' 'Projects: Customer is not a search field'
$pRowName = (PGet 'lblPrjRowName' 'Text').TrimStart('='); $pRowSub = (PGet 'lblPrjRowSub' 'Text').TrimStart('=')
$nd = [string][char]0x2013; $md = [string][char]0x00B7
Assert-Eval "With({ThisItem:{Number:`"TEST-002`",Name:`"Alpha`"}},$pRowName)" "TEST-002 $nd Alpha" 'Projects: row name line "Project Number - Project Name"'
Assert-Eval "With({ThisItem:{Number:`"TEST-002`",Name:`"`"}},$pRowName)" 'TEST-002' 'Projects: row name line without a name shows only the number'
Assert-Eval "With({ThisItem:{Customer:`"Cust`",City:`"Delft`"}},$pRowSub)" "Cust $md Delft" 'Projects: row subline "Customer <middle dot> City"'
Assert-Eval "With({ThisItem:{Customer:`"`",City:`"Delft`"}},$pRowSub)" 'Delft' 'Projects: row subline without customer: only City (no dangling separator)'
$pChipVis = (PGet 'btnPrjRowStatus' 'Visible').TrimStart('=')
foreach ($c in @(@('"Active"', $false), @('"On hold"', $true), @('"Closed"', $true), @('""', $false))) { Assert-Eval "With({ThisItem:{Status:$($c[0])}},$pChipVis)" $c[1] "Projects: row status chip visible for Status $($c[0]) = $($c[1])" }
Assert-True ((PGet 'btnPrjRowStatus' 'Text') -ceq '=ThisItem.Status' -and (PGet 'lblPrjRowName' 'Width') -ceq "=Parent.TemplateWidth-If($pChipVis,88,0)") 'Projects: row chip shows the SharePoint Status text (not colour only); name line leaves room for the chip'
Assert-True ((PGet 'lblPrjRowName' 'Size') -eq '=15' -and (PGet 'lblPrjRowName' 'FontWeight') -eq '=FontWeight.Semibold' -and (PGet 'lblPrjRowSub' 'Size') -eq '=13' -and (PGet 'galPrjList' 'TemplateSize') -eq '=64') 'Projects: row name 15 Semibold, subline 13, row height 64'

# (P17) Form card: header, status chip, sections GENERAL/ADDRESS/PEOPLE/LINKS on the 1-3 column grid, Last changed bottom right ----
$pTitleFx = (PGet 'lblPrjFormTitle' 'Text').TrimStart('=')
Assert-Eval "With({LangNl:false,T:$tRec,varPrjMode:`"New`",varPrjEdit:{Number:`"`",Name:`"`"}},$pTitleFx)" 'New project' 'Projects: header for New = "New project"'
Assert-Eval "With({LangNl:false,T:$tRec,varPrjMode:`"Edit`",varPrjEdit:{Number:`"TEST-002`",Name:`"Alpha`"}},$pTitleFx)" "TEST-002 $nd Alpha" 'Projects: header = Project Number + Project Name'
$pFormChipText = (PGet 'btnPrjFormChip' 'Text')
Assert-True ($pFormChipText -ceq '=ddPrjStatus.Selected.Value' -and (PGet 'btnPrjFormChip' 'DisplayMode') -eq '=DisplayMode.Disabled' -and !$pIdx['btnPrjFormChip']['Properties'].ContainsKey('OnSelect') -and (PGet 'btnPrjFormChip' 'Visible') -ceq '=Coalesce(varPrjMode,"") in ["New","Edit"] && !IsBlank(ddPrjStatus.Selected.Value)') 'Projects: status chip shows the Status draft as text, static, only in New/Edit with a Status'
$pLay = [ordered]@{ X = '=If(Parent.Width>=1000,1,0)'; Y = '=If(Self.X=1,408,24)'; Width = '=If(Self.X=1,Max(0,Parent.Width-432),Parent.Width-48)'; Height = '=If(Self.X=1,24,500)' }
foreach ($k in $pLay.Keys) { Assert-True ((PGet 'lblPrjLayout' $k) -ceq $pLay[$k]) "Projects: layout carrier lblPrjLayout.$k as Contractors" }
Assert-True ((PGet 'lblPrjMetrics' 'X') -ceq '=If(lblPrjLayout.Width-48>=572,3,If(lblPrjLayout.Width-48>=376,2,1))' -and (PGet 'lblPrjMetrics' 'Y') -ceq '=lblPrjModified.Y+lblPrjModified.Height+24' -and (PGet 'lblPrjMetrics' 'Width') -ceq '=If(lblPrjLayout.X=1,Self.Height-48,452)' -and (PGet 'lblPrjMetrics' 'Height') -ceq '=If(lblPrjLayout.X=1,Max(conPrjBody.Height,Self.Y+48,568),lblPrjLayout.Height+Self.Y+24)' -and (PGet 'lblPrjGrid' 'Width') -ceq '=(lblPrjLayout.Width-48-16*(lblPrjMetrics.X-1))/lblPrjMetrics.X') 'Projects: grid carriers (columns 3/2/1 at content 572/376, gap 16; content height) as Contractors'
$pSecExp = [ordered]@{ lblPrjSecGeneral = '=lblPrjFormDivider.Y+1+20'; lblPrjSecAddress = '=lblPrjSecGeneral.Y+38+RoundUp(5/lblPrjMetrics.X,0)*74'; lblPrjSecPeople = '=lblPrjSecAddress.Y+38+RoundUp(5/lblPrjMetrics.X,0)*74'; lblPrjSecLinks = '=lblPrjSecPeople.Y+38+RoundUp(2/lblPrjMetrics.X,0)*74' }
foreach ($k in $pSecExp.Keys) { Assert-True ((PGet $k 'Y') -ceq $pSecExp[$k] -and (PGet $k 'Size') -eq '=12' -and (PGet $k 'FontWeight') -eq '=FontWeight.Bold' -and (PGet $k 'Height') -eq '=18') "Projects: section $k 12 Bold, top $($pSecExp[$k])" }
Assert-True ((PGet 'lblPrjModified' 'Y') -ceq '=lblPrjSecLinks.Y+38+74' -and (PGet 'lblPrjModified' 'Align') -eq '=Align.Right' -and (PGet 'lblPrjModified' 'X') -eq '=24' -and (PGet 'lblPrjModified' 'Width') -eq '=lblPrjLayout.Width-48' -and (PGet 'lblPrjModified' 'Size') -eq '=12') 'Projects: "Last changed in SharePoint" bottom right, under LINKS (no Active switch row)'
$pGrid = [ordered]@{ General = @('Name', 'Number', 'Reference', 'Customer', 'Status'); Address = @('Street', 'HouseNumber', 'PostalCode', 'City', 'Country'); People = @('Leader', 'SiteManager'); Links = @('Url') }
$pCtlOf = @{ Name = 'txtPrjName'; Number = 'txtPrjNumber'; Reference = 'txtPrjReference'; Customer = 'txtPrjCustomer'; Status = 'ddPrjStatus'; Street = 'txtPrjStreet'; HouseNumber = 'txtPrjHouseNumber'; PostalCode = 'txtPrjPostalCode'; City = 'txtPrjCity'; Country = 'ddPrjCountry'; Leader = 'txtPrjLeader'; SiteManager = 'txtPrjSiteManager'; Url = 'txtPrjUrl' }
foreach ($s in $pGrid.Keys) {
    for ($n = 0; $n -lt $pGrid[$s].Count; $n++) {
        $f = $pGrid[$s][$n]; $lb = "lblPrj${f}Label"; $ct = $pCtlOf[$f]; $sec = "lblPrjSec$s"
        $xx = if ($n -eq 0) { '=24' } else { "=24+Mod($n,lblPrjMetrics.X)*(lblPrjGrid.Width+16)" }
        $yy = if ($n -eq 0) { "=$sec.Y+30" } else { "=$sec.Y+30+RoundDown($n/lblPrjMetrics.X,0)*74" }
        $ww = if ($f -eq 'Url') { '=lblPrjLayout.Width-48' } else { '=lblPrjGrid.Width' }
        Assert-True ((PGet $lb 'X') -ceq $xx -and (PGet $ct 'X') -ceq $xx -and (PGet $lb 'Y') -ceq $yy -and (PGet $ct 'Y') -ceq "=$lb.Y+22" -and (PGet $lb 'Width') -ceq $ww -and (PGet $ct 'Width') -ceq $ww -and (PGet $ct 'Height') -eq '=36') "Projects: $s field $n ($f): grid cell, input 22 px under the label, h36$(if ($f -eq 'Url') { ', full content width' })"
        Assert-True ((PGet $lb 'Size') -eq '=13' -and (PGet $lb 'FontWeight') -eq '=FontWeight.Semibold' -and (PGet $lb 'Height') -eq '=18' -and (PGet $lb 'Text') -match 'T\.prjField') "Projects: $lb : 13 Semibold, h18, text from T"
    }
}
foreach ($r in @('Name', 'Number', 'Status')) { Assert-True ((PGet "lblPrj${r}Required" 'Text') -eq '="*"' -and (PGet "lblPrj${r}Required" 'Y') -eq "=lblPrj${r}Label.Y") "Projects: red required star after $r" }
Assert-True (@($pIdx.Keys | Where-Object { $_ -like 'lblPrj*Required' }).Count -eq 3) 'Projects: exactly 3 required stars (Project Name, Project Number, Status)'
foreach ($k in $pTextFields.Keys) {
    $f = $pTextFields[$k]; $er = "CountIf(colPrjSaveErrors,Field=""$f"")>0"
    foreach ($pv in @(@('BorderColor', '#9B9B9B'), @('HoverBorderColor', '#5A5A5A'), @('FocusedBorderColor', '#0303B8'), @('PressedBorderColor', '#0303B8'))) { Assert-True ((PGet $k $pv[0]) -ceq "=If($er,ColorValue(""#DB1E28""),ColorValue(""$($pv[1])""))") "Projects: $k.$($pv[0]) red when colPrjSaveErrors has Field=$f" }
    Assert-True ((PGet $k 'BorderThickness') -ceq "=If($er,2,1)" -and (PGet $k 'DisplayMode') -ceq (PGet 'txtPrjName' 'DisplayMode') -and (PGet $k 'MaxLength') -eq '=255') "Projects: $k border 1/2 px, same form DisplayMode, MaxLength 255"
}
foreach ($k in $pDropFields.Keys) { $f = $pDropFields[$k]; Assert-True ((PGet $k 'BorderColor') -ceq "=If(CountIf(colPrjSaveErrors,Field=""$f"")>0,ColorValue(""#DB1E28""),ColorValue(""#DCDCDC""))" -and (PGet $k 'DisplayMode') -ceq (PGet 'txtPrjName' 'DisplayMode')) "Projects: $k red border on Field=$f, same form DisplayMode" }
$pFields = @([regex]::Matches($pSave, 'Collect\(colPrjSaveErrors,\{Field:"(\w*)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True (@($pFields | Where-Object { $_ -ne '' -and $_ -cnotin $pWritten }).Count -eq 0) "Projects: every collected error Field is an input field or '' ($($pFields -join ','))"
Assert-True ((PGet 'txtPrjName' 'DisplayMode') -ceq '=If(varPrjLoadState="Loaded" && IsEmpty(colPrjLoadErrors) && !Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && !Coalesce(varPrjSaveFailed,false) && Coalesce(varPrjMode,"") in ["New","Edit"],DisplayMode.Edit,DisplayMode.Disabled)') 'Projects: inputs editable only when Loaded, idle, no failed save, New/Edit (else Disabled: the field box always renders)'
$pFormKids = @($pIdx['conPrjFormCard']['Children'] | ForEach-Object { @($_.Keys)[0] })
$pExpKids = 'lblPrjFormTitle,btnPrjFormChip,lblPrjFormDivider,lblPrjSecGeneral,lblPrjNameLabel,lblPrjNameRequired,txtPrjName,lblPrjNumberLabel,lblPrjNumberRequired,txtPrjNumber,lblPrjReferenceLabel,txtPrjReference,lblPrjCustomerLabel,txtPrjCustomer,lblPrjStatusLabel,lblPrjStatusRequired,ddPrjStatus,lblPrjSecAddress,lblPrjStreetLabel,txtPrjStreet,lblPrjHouseNumberLabel,txtPrjHouseNumber,lblPrjPostalCodeLabel,txtPrjPostalCode,lblPrjCityLabel,txtPrjCity,lblPrjCountryLabel,ddPrjCountry,lblPrjSecPeople,lblPrjLeaderLabel,txtPrjLeader,lblPrjSiteManagerLabel,txtPrjSiteManager,lblPrjSecLinks,lblPrjUrlLabel,txtPrjUrl,lblPrjModified'
Assert-True (($pFormKids -join ',') -ceq $pExpKids) "Projects: conPrjFormCard children: $($pFormKids -join ',')"
Assert-True ((@($pIdx['conPrjListCard']['Children'] | ForEach-Object { @($_.Keys)[0] }) -join ',') -ceq 'txtPrjSearch,icoPrjSearch,lblPrjCount,lblPrjShowInactive,btnPrjShowInactiveSwitch,btnPrjShowInactiveKnob,galPrjList' -and (@($pIdx['conPrjCanvas']['Children'] | ForEach-Object { @($_.Keys)[0] }) -join ',') -ceq 'conPrjListCard,conPrjFormCard') 'Projects: list card and canvas children as Contractors'
foreach ($cp in @(@('conPrjListCard', 'X', '=24'), @('conPrjListCard', 'Y', '=24'), @('conPrjListCard', 'Width', '=If(lblPrjLayout.X=1,360,Parent.Width-48)'), @('conPrjListCard', 'Height', '=lblPrjMetrics.Width'), @('conPrjFormCard', 'X', '=lblPrjLayout.Y'), @('conPrjFormCard', 'Y', '=lblPrjLayout.Height'), @('conPrjFormCard', 'Width', '=lblPrjLayout.Width'), @('conPrjFormCard', 'Height', '=If(lblPrjLayout.X=1,lblPrjMetrics.Height-48,lblPrjMetrics.Y)'), @('conPrjFormCard', 'DropShadow', '=DropShadow.Light'), @('conPrjListCard', 'Fill', '=Color.White'), @('conPrjBody', 'Y', '=conPrjMsgBar.Y+conPrjMsgBar.Height'), @('conPrjBody', 'Height', '=Max(0,navPrj.Y-Self.Y)'), @('galPrjList', 'Y', '=lblPrjCount.Y+lblPrjCount.Height+12'), @('galPrjList', 'Height', '=Parent.Height-Self.Y-12'))) {
    Assert-True ((PGet $cp[0] $cp[1]) -ceq $cp[2]) "Projects: $($cp[0]).$($cp[1]) = $($cp[2])"
}
# Numeric mirror of the pinned formulas: no overlap of labels/inputs/section headers, inside the 24 px padding, cards side by side or stacked
function Get-PrjGeom([int]$layW) {
    $cw = $layW - 48; $c = if ($cw -ge 572) { 3 } elseif ($cw -ge 376) { 2 } else { 1 }
    $colW = ($cw - 16 * ($c - 1)) / $c
    $gen = 24 + 30 + 16 + 1 + 20; $adr = $gen + 38 + [Math]::Ceiling(5 / $c) * 74; $ppl = $adr + 38 + [Math]::Ceiling(5 / $c) * 74; $lnk = $ppl + 38 + [Math]::Ceiling(2 / $c) * 74
    $mod = $lnk + 38 + 74
    return @{ Cols = $c; ColW = $colW; CW = $cw; Sec = [ordered]@{ General = $gen; Address = $adr; People = $ppl; Links = $lnk }; Mod = $mod; MetY = $mod + 24 + 24 }
}
foreach ($W in 320, 768, 900, 1000, 1280, 1366, 1920) {
    $wide = $W -ge 1000; $layW = if ($wide) { [Math]::Max(0, $W - 432) } else { $W - 48 }
    $g = Get-PrjGeom $layW
    $rects = @()
    foreach ($s in $pGrid.Keys) {
        $rects += @{ N = "sec$s"; X = 24; Y = $g.Sec[$s]; W = $g.CW; H = 18 }
        for ($n = 0; $n -lt $pGrid[$s].Count; $n++) {
            $f = $pGrid[$s][$n]; $wd = if ($f -eq 'Url') { $g.CW } else { $g.ColW }
            $x = if ($f -eq 'Url') { 24 } else { 24 + ($n % $g.Cols) * ($g.ColW + 16) }
            $ly = $g.Sec[$s] + 30 + [Math]::Floor($n / $g.Cols) * 74
            $rects += @{ N = "lbl$f"; X = $x; Y = $ly; W = $wd; H = 18 }; $rects += @{ N = "in$f"; X = $x; Y = $ly + 22; W = $wd; H = 36 }
        }
    }
    $rects += @{ N = 'modified'; X = 24; Y = $g.Mod; W = $g.CW; H = 24 }
    $ov = @()
    for ($i = 0; $i -lt $rects.Count; $i++) {
        $a = $rects[$i]
        if ($a.X -lt 24 -or $a.X + $a.W -gt 24 + $g.CW + 0.01) { $ov += "$($a.N) outside" }
        for ($j = $i + 1; $j -lt $rects.Count; $j++) { $b = $rects[$j]; if ($a.X -lt $b.X + $b.W -and $b.X -lt $a.X + $a.W -and $a.Y -lt $b.Y + $b.H -and $b.Y -lt $a.Y + $a.H) { $ov += "$($a.N)/$($b.N)" } }
    }
    Assert-True ($ov.Count -eq 0) "Projects W=$W (card $layW, $($g.Cols) col of $([Math]::Round($g.ColW,1))): no overlap and inside the padding ($($ov -join ', '))"
    if ($g.Cols -ge 2) { Assert-True ($g.ColW -ge 180) "Projects W=$W : columns >= 180 px" }
    Assert-True ($g.MetY -eq $g.Mod + 48 -and $g.Mod -ge $g.Sec.Links + 30 + 22 + 36 + 16) "Projects W=$W : Last changed under the URL field, content height $($g.MetY)"
    foreach ($bodyH in 300, 700) {
        $metH = if ($wide) { [Math]::Max($bodyH, [Math]::Max($g.MetY + 48, 568)) } else { 500 + $g.MetY + 24 }
        $listH = if ($wide) { $metH - 48 } else { 452 }; $formH = if ($wide) { $metH - 48 } else { $g.MetY }
        $layY = if ($wide) { 408 } else { 24 }; $layH = if ($wide) { 24 } else { 500 }
        Assert-True ($formH -ge $g.MetY -and ($layY + $layW + 24 -le $W -or $layW -le 0) -and $listH - (24 + 36 + 12 + 24 + 12) - 12 -ge 200) "Projects W=$W body=$bodyH : form card holds its content, 24 px right margin, gallery >= 200 px"
        if ($wide) { Assert-True ($layH -eq 24 -and 24 + 360 + 24 -eq $layY -and $listH -eq $formH) "Projects W=$W body=$bodyH : wide: cards side by side, tops equal, equal heights" }
        else { Assert-True ($layH -ge 24 + $listH + 24 -and $layH + $formH + 24 -eq $metH) "Projects W=$W body=$bodyH : narrow: form card stacked under the list card, no overlap" }
    }
}

# (P18) Title bar, spinner, footer, Home tile -----------------------------------------------------------------------------
$pKids = @($pDoc['Screens'][$pScreen]['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($pKids[0..3] -join ',') -ceq 'lblPrjTitle,imgLogoProjects,imgPrjSpinner,conPrjMsgBar' -and $pKids[-2] -eq 'navPrj' -and $pKids[-1] -eq 'recPrjFooterLine') 'Projects: children order title, logo, spinner, message bar ... footer, footer line (as Contractors)'
Assert-True ((PGet 'lblPrjTitle' 'Height') -eq '=60' -and (PGet 'lblPrjTitle' 'Text') -ceq ('=' + (TT 'prjTitle'))) 'Projects: title bar 60 px, title "Projects" from T'
Assert-True ([string]$pScreenProps['Fill'] -eq '=ColorValue("#F5F6F8")') 'Projects: page background #F5F6F8'
$pSpImg = PGet 'imgPrjSpinner' 'Image'
Assert-True ($pSpImg.StartsWith('="data:image/svg+xml;utf8," & EncodeUrl("<svg') -and $pSpImg.Contains('#FFFFFF') -and $pSpImg.Contains('animateTransform') -and (PGet 'imgPrjSpinner' 'Visible') -ceq '=Coalesce(varPrjBusy,false) || Coalesce(varPrjSaving,false) || varPrjLoadState="Loading"' -and (PGet 'imgPrjSpinner' 'X') -ceq '=lblPrjTitle.X+lblPrjTitle.Width-24-Self.Width') 'Projects: white SVG spinner (hand-built; Contractors moved to cmpTitleBar), right in the title bar while loading/saving'
$pFoot = [ordered]@{ btnPrjHome = '110'; btnPrjNew = '90'; btnPrjRefresh = '110'; btnPrjDiscard = '188'; btnPrjSave = '140' }
$cfDef = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'Component/cmpFooter.pa.yaml')))['ComponentDefinitions']['cmpFooter']; $cfIdx = @{}; Index-Controls $cfDef['Children'] $cfIdx
function CfProp([string]$c, [string]$p) { return ([string]$cfIdx[$c]['Properties'][$p]).Trim() }
foreach ($b in $pFoot.Keys) { $e = 'btnCmp' + $b.Substring(6); Assert-True ((PGet $b 'Width') -eq "=$($pFoot[$b])" -and (PGet $b 'Text') -match 'T\.prj' -and (PGet $b 'Fill') -ceq (CfProp $e 'Fill') -and (PGet $b 'X') -ceq (CfProp $e 'X').Replace('btnCmp', 'btnPrj').Replace('lblCmpFooterMetrics', 'lblFooterButtonMetrics')) "Projects: footer $b width $($pFoot[$b]), text from T, same role/position formula as the cmpFooter button $e" }
Assert-True ((@($pIdx['conPrjButtonRow']['Children'] | ForEach-Object { @($_.Keys)[0] }) -join ',') -ceq 'btnPrjHome,icoPrjHome,btnPrjNew,btnPrjRefresh,btnPrjDiscard,btnPrjSave' -and (PGet 'conPrjButtonRow' 'Width') -ceq (CfProp 'conCmpFooterRow' 'Width').Replace('btnCmp', 'btnPrj').Replace('lblCmpFooterMetrics', 'lblFooterButtonMetrics')) 'Projects: one footer row: Home (+ icon) left; New, Refresh, Discard changes, Save right'
$homeDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'scrHome.pa.yaml'))); $homeIdx2 = @{}; Index-Controls $homeDoc['Screens']['scrHome']['Children'] $homeIdx2
Assert-True ($homeIdx2['btnTileProjects']['Properties']['OnSelect'] -eq '=Navigate(scrProjects)' -and !$homeIdx2['btnTileProjects']['Properties'].ContainsKey('DisplayMode') -and $homeIdx2['icoTileProjects']['Properties']['Icon'] -eq '=Icon.Folder' -and $homeIdx2['icoTileProjects']['Properties']['OnSelect'] -eq '=Select(btnTileProjects)' -and !$homeIdx2.ContainsKey('lblTileSubProjects')) 'Home: Projects tile active (Navigate(scrProjects), Icon.Folder, no "Coming soon")'
# Home layout: 4 columns from 896 px (margin 24, column gap 16, tile min 200, tile gap 12); static formula check plus mirrored geometry.
$hlp = $homeIdx2['lblHomeLayout']['Properties']
Assert-True ((Norm $hlp['X']) -ceq '=If(conHomeScroll.Width-48>=848,4,1)' -and (Norm $hlp['Y']) -ceq '=If(Self.X=4,(conHomeScroll.Width-48-48)/4,conHomeScroll.Width-48)') 'Home layout formulas: 4 columns when content width >= 848 (screen 896), margin 24, column gap 16'
Assert-True ((Norm $homeIdx2['btnTileKnowledgeBase']['Properties']['X']).StartsWith('=24+If(lblHomeLayout.X=4,3*(lblHomeLayout.Y+16),0)') -and (Norm $homeIdx2['lblHomeHeaderKnowledge']['Properties']['X']).StartsWith('=24+If(lblHomeLayout.X=4,3*(lblHomeLayout.Y+16),0)')) 'Home Knowledge column X = 24 + 3 x (column width + 16)'
foreach ($w in 320, 728, 895, 896, 900, 1280, 1920) {
  $avail = $w - 48; $cols = if ($avail -ge 848) { 4 } else { 1 }
  $colW = if ($cols -eq 4) { [math]::Floor(($avail - 48) / 4) } else { $avail }
  $n = [math]::Max(1, [math]::Floor(($colW + 12) / 212)); $tileW = ($colW - ($n - 1) * 12) / $n
  $right = 24 + ($cols - 1) * ($colW + 16) + $colW
  if ($w -eq 900 -or $w -eq 896) { Assert-True ($cols -eq 4) "Home $w px: 4 columns" }
  if ($w -eq 895) { Assert-True ($cols -eq 1) 'Home 895 px: stacked mode (no 4 columns)' }
  if ($w -ge 896) { Assert-True ($colW -ge 200) "Home $w px: column width $colW >= 200" }
  Assert-True (($tileW -ge 200 -or $avail -lt 200 + 0) -and $right -le $w - 24 + 0.5) "Home $w px: no overlap, tile width $tileW, content right edge $right <= $($w - 24)"
}
$edState = [IO.File]::ReadAllText((Join-Path $srcDir '_EditorState.pa.yaml'))
Assert-True ($edState -match '(?m)^\s+- scrProjects\s*$') 'Projects: scrProjects listed in _EditorState ScreensOrder'

# (P19) Studio FAIL build adminpattern-20261030_071949 (Eddy 30-10-2026): items 4, 5, a, d, e, f (helpers from section 17) ------
# Item 4: same cause as on Contractors (View fallback rendered the empty inputs invisibly); all inputs always render.
Test-FormInputsRender $pIdx (@($pTextFields.Keys) + @($pDropFields.Keys)) @('txtPrjLeader', 'txtPrjSiteManager') 'conPrjFormCard' 'varPrjLoadState:"Loaded",colPrjLoadErrors:Filter(Table({Message:""}),false),varPrjBusy:false,varPrjSaving:false,varPrjSaveFailed:false,varPrjMode:"Edit"' 'Projects'
Assert-True ($pText -notmatch 'DisplayMode\.View') 'Projects: no DisplayMode.View on the screen'
# Item 5: auto-select the first visible row after a successful load
$prjEmpty = '{ID:Blank(),Name:"",Number:"",Reference:"",Customer:"",Status:"",Street:"",HouseNumber:"",PostalCode:"",City:"",Country:"",Leader:"",SiteManager:"",Url:""}'
Test-AutoSelect $pLoad $pItems (PGet 'galPrjList' 'Default') (PGet 'galPrjList' 'OnSelect') 'Prj' 'colAdminProjects' $prjEmpty $pDirty 'Projects'
foreach ($c in @(@('false', '""', '4', 'first visible row by Project Number (A-1; Closed hidden)'), @('true', '""', '4', 'Show inactive on: A-1 still first'), @('false', '"test"', '2', 'search filter applied (TEST-001)'), @('true', '"p-9"', '3', 'Closed row selectable when shown'))) {
    Assert-Eval "With({$pItemFix,varPrjShowInactive:$($c[0]),txtPrjSearch:{Text:$($c[1])}},Text(First($pItems).ID))" $c[2] "Projects auto-select: $($c[3]) -> ID $($c[2])"
}
Assert-Eval "With({$pItemFix,varPrjShowInactive:false,txtPrjSearch:{Text:`"p-9`"}},IsBlank(First($pItems).ID))" $true 'Projects auto-select: only a hidden Closed project matches -> no selection (Mode "")'
Assert-Eval "With({colAdminProjects:Filter(Table({ID:1,Name:`"`",Number:`"`",Customer:`"`",City:`"`",Status:`"`"}),false),varPrjShowInactive:false,txtPrjSearch:{Text:`"`"}},IsBlank(First($pItems).ID))" $true 'Projects auto-select: empty list -> no selection'
# Item d: SharePoint refusal (nothing written) keeps Loaded and the input; partial write / verify failure -> Failed
Test-WriteCounter $pSave 'Prj' 'Projects' 'Projects'
Assert-Eval (PG 'btnPrjSave' $pFix) $true 'Projects: after a refused save (Loaded, SaveFailed false, input kept) Save is allowed again (retry)'
Assert-True ($pPatchErrRec.Contains('T.prjErrSharePoint.en') -and $pSave.Contains('Set(varPrjPatchError,true); Collect(colPrjSaveErrors,{Field:If("duplicate" in Lower(FirstError.Message)')) 'Projects: Patch error branch sets the flag and keeps the duplicate mapping (red Project Number)'
# Item a: a stored Status/Country outside Choices is shown as-is (extra option for this record only), never counts as a change,
# is not blocked by the Status validation when unchanged, and is written back unchanged as {Value: <stored>}.
$chS = 'Table({Value:"Active"},{Value:"On hold"},{Value:"Closed"})'; $chC = 'Table({Value:"Netherlands"},{Value:"Germany"})'
$stFx = $pAsIs.Status.Replace('Choices([@Projects].Status)', 'chS'); $coFx = $pAsIs.Country.Replace('Choices([@Projects].Country)', 'chC')
foreach ($c in @(@('"Archived"', 'Active,On hold,Closed,Archived', 'unknown stored value added once, after the choices'), @('"Active"', 'Active,On hold,Closed', 'known value: no extra option'), @('""', 'Active,On hold,Closed', 'empty: no extra option'), @('If(false,"x")', 'Active,On hold,Closed', 'blank: no extra option'))) {
    Assert-Eval "With({chS:$chS,varPrjEdit:{Status:$($c[0])}},Concat($stFx,Value,`",`"))" $c[1] "Projects a: Status items, $($c[2])"
}
Assert-Eval "With({chC:$chC,varPrjEdit:{Country:`"Belgium`"}},Concat($coFx,Value,`",`"))" 'Netherlands,Germany,Belgium' 'Projects a: Country items, unknown stored value added'
foreach ($v in @('"Archived"', '"Active"')) { Assert-Eval "With({chS:$chS,varPrjEdit:{Status:$v}},CountIf($stFx,Value=varPrjEdit.Status))" 1 "Projects a: stored Status $v is exactly one dropdown item, so Default = varPrjEdit.Status shows it as-is" }
$pRawUnk = PRaw '"TEST Project 2"' '"TEST-002"' $bT '{Value:"Archived"}' '{Value:"Belgium"}' $bT $bP
Assert-Eval (PDirty $pRawUnk (PIn '"TEST Project 2"' '"TEST-002"' '""' '"Archived"' '"Belgium"' '""')) $false 'Projects a: unknown Status/Country shown as-is: not dirty'
Assert-Eval (PDirty $pRawUnk (PIn '"TEST Project 2"' '"TEST-002"' '""' '"Active"' '"Belgium"' '""')) $true 'Projects a: user picks another Status: dirty'
Assert-Eval (PDirty $pRawUnk (PIn '"TEST Project 2"' '"TEST-002"' '""' '"Archived"' '"Germany"' '""')) $true 'Projects a: user picks another Country: dirty'
$pUnkBase = $pBase.Replace('Status:"Active"', 'Status:"Archived"').Replace('Country:"Netherlands"', 'Country:"Belgium"')
$pUnkClean = $pUnkBase + (PIn '"A"' '"TEST-002"' '""' '"Archived"' '"Belgium"' '""')
foreach ($g in @('btnPrjHome', 'btnPrjNew', 'galPrjList')) { Assert-Eval (PG $g $pUnkClean) $true "Projects a: $g allowed with an untouched unknown Status/Country" }
Assert-Eval (PG 'btnPrjSave' $pUnkClean) $false 'Projects a: Save not enabled by an untouched unknown value'
Assert-Eval (PG 'btnPrjSave' ($pUnkBase + (PIn '"B"' '"TEST-002"' '""' '"Archived"' '"Belgium"' '""'))) $true 'Projects a: other field changed with unknown Status: Save allowed'
Assert-Eval (PConflict $pRawUnk $pRawUnk) $false 'Projects a: conflict check ignores the dropdown (SharePoint pre-read vs loaded snapshot, both "Archived")'
$stVal = Get-Balanced $pSave ($pSave.IndexOf('If(IsBlank(varPrjSaveRec.Status) || (') + 2)
$stCond = (Split-Args $stVal.Substring(1, $stVal.Length - 2))[0].Replace('Choices([@Projects].Status)', 'chS')
foreach ($c in @(@('"Edit"', '"Archived"', '"Archived"', $false, 'Edit, unknown value unchanged: accepted'), @('"Edit"', '"Archived"', '"Retired"', $true, 'Edit, other unknown value: error'), @('"New"', '""', '"Archived"', $true, 'New with an unknown value: error'), @('"Edit"', '"Archived"', '""', $true, 'empty Status: error (required)'), @('"Edit"', '"Active"', '"Closed"', $false, 'known value: accepted'))) {
    Assert-Eval "With({chS:$chS,varPrjSaveMode:$($c[0]),varPrjEdit:{Status:$($c[1])},varPrjSaveRec:{Status:$($c[2])}},$stCond)" $c[3] "Projects a/e: Status validation: $($c[4])"
}
$pInUnk = PIn '"TEST Project 2"' '"TEST-002"' '""' '"Archived"' '"Belgium"' '""'
Assert-Eval "With({$pInUnk},With($pSrFx,Status & `"|`" & Country))" 'Archived|Belgium' 'Projects a: unchanged unknown values written back as-is ({Value: stored})'
Assert-Eval (PVerify $pRawUnk (PIn '"TEST Project 2"' '"TEST-002"' '""' '"Archived"' '"Belgium"' '""') 'F') '' 'Projects a: verify passes after writing back the unknown values unchanged'
# Item e: Project Name stays required (validation present, red star)
Assert-True ($pSaveN.Contains('If(IsBlank(varPrjSaveRec.Name),Collect(colPrjSaveErrors,{Field:"Name"') -and (PGet 'lblPrjNameRequired' 'Text') -eq '="*"') 'Projects e: Project Name required (validation + star)'
# Item f: varPrjEdit (saved status source for the chip) only from the loaded list, the verify read or the empty/New snapshot
$prjEditSets = Get-SetValues $pText 'varPrjEdit'
Assert-True ($prjEditSets.Count -ge 3 -and @($prjEditSets | Where-Object { $_ -notmatch '^(LookUp\(colAdminProjects,ID=varPrjSelectedID\)|First\(colPrjVerify\)|\{ID:Blank\(\),.*\})$' }).Count -eq 0) "Projects f: varPrjEdit only from the loaded list, the verify read or the empty/New snapshot ($($prjEditSets -join ' | '))"
Write-Output 'PASS Test-AdminScreens (Projects): static structure only. Studio import, binding (Choices/[@Projects], Hyperlink URL, person DisplayName), delegation (Monitor), SharePoint case-sensitivity of ''Project Number'' = and functional tests NOT verified.'
