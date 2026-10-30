# Static checks for the admin screens (ADMIN_PLAN.md par. 6). Build 1: Contractors (scrContractors, list Employers).
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
    Assert-True ($dirty.Contains("Trim(txtEmp$f.Text & """")<>Trim(varEmpEdit.$f & """")")) "Dirty compares txtEmp$f.Text directly with varEmpEdit, both sides Trim(x & """") (no OnChange dependency, blank = empty)"
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
'txtEmpName:{Text:"B"},txtEmpAddress:{Text:""},txtEmpPostalcode:{Text:""},txtEmpCity:{Text:""},txtEmpCountry:{Text:""},txtEmpContactName:{Text:""},txtEmpContactEmail:{Text:""},txtEmpContactPhone:{Text:""},varEmpActiveDraft:true'
$clean = $fix.Replace('txtEmpName:{Text:"B"}', 'txtEmpName:{Text:"A"}')
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
Assert-Eval (Get-GuardFx 'btnEmpSave' $newFix.Replace('txtEmpName:{Text:"B"}', 'txtEmpName:{Text:""}')) $false 'Save blocked: New without input'
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

# Form is bound to varEmpEdit, never to the gallery selection
$inputMap = [ordered]@{ txtEmpName = 'Name'; txtEmpAddress = 'Address'; txtEmpPostalcode = 'Postalcode'; txtEmpCity = 'City'; txtEmpCountry = 'Country'; txtEmpContactName = 'ContactName'; txtEmpContactEmail = 'ContactEmail'; txtEmpContactPhone = 'ContactPhone' }
foreach ($k in $inputMap.Keys) { Assert-True ((Get-Prop $k 'Default') -ceq "=varEmpEdit.$($inputMap[$k])") "$k.Default = varEmpEdit.$($inputMap[$k])" }
# A1 (30-10-2026): Classic/CheckBox chkEmpActive/chkEmpShowInactive replaced by emulated switches with draft variables.
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
$selUses = @($all.Keys | Where-Object { $all[$_] -match 'galEmpList\.Selected' })
Assert-True ($selUses.Count -eq 1 -and $selUses[0] -eq 'galEmpList.OnSelect') 'galEmpList.Selected only read in the guarded gallery OnSelect'

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
    Assert-True ($save -match "$f\s*:\s*Trim\(txtEmp$f\.Text & """"\)") "Save record trims $f (Trim(x & """"): blank input = empty text)"
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
$iWriteGate = $saveN.IndexOf('If(IsEmpty(colEmpSaveErrors),Set(varEmpSaveWrites,1);IfError(CountRows(ClearCollect(colEmpPatched,Patch(Employers,')
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
$reset = 'Reset(txtEmpName); Reset(txtEmpAddress); Reset(txtEmpPostalcode); Reset(txtEmpCity); Reset(txtEmpCountry); Reset(txtEmpContactName); Reset(txtEmpContactEmail); Reset(txtEmpContactPhone); Set(varEmpActiveDraft,Coalesce(varEmpEdit.Active,true))'
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
        Assert-True ($t -notmatch 'FirstError|txtEmp|varEmpSaveRec|varEmpDupName|varEmpDupKey|varEmpEdit\.|\.Name\b|Title|Message') "$k : trace has no names, values or FirstError.Message"
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
$badCoalesce = @([regex]::Matches($screenText, 'Coalesce\(\s*(?:emp|p|v|varEmpEdit|varEmpSaveRec|txtEmp\w+)\.[^,()]+,\s*""\s*\)') | ForEach-Object { $_.Value })
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
    return "txtEmpName:{Text:$name},txtEmpAddress:{Text:$empty},txtEmpPostalcode:{Text:$empty},txtEmpCity:{Text:$city},txtEmpCountry:{Text:$empty},txtEmpContactName:{Text:$empty},txtEmpContactEmail:{Text:$empty},txtEmpContactPhone:{Text:$empty},varEmpActiveDraft:$active"
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
Assert-True ($saveN.Contains((Norm 'Collect(colEmpSaveErrors,{Field:"",Message:If(LangNl && !IsBlank(T.empErrPatch.nl),T.empErrPatch.nl,T.empErrPatch.en) & " " & FirstError.Message});false);'))) 'Patch error: SharePoint reason (FirstError.Message) appended to the notified error only (never Trace)'
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
$headsByKind = @{ '"Error"' = @('admHeadNotSaved', 'admHeadNotLoaded', 'admHeadBlocked'); '"Warning"' = @('admHeadAttention', 'admHeadSaved'); '"Success"' = @('admHeadLoaded', 'admHeadSaved', 'admHeadDiscarded') }
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
        '"Warning"' { Assert-True (@($bk | Where-Object { $_ -in $warnKeys }).Count -ge 1 -and @($bk | Where-Object { $_ -notin ($warnKeys + 'empMsgSavedRename') }).Count -eq 0) "$lbl carries a warning text (empWarn*), nothing else except the rename note" }
        '"Success"' { Assert-True (@($bk | Where-Object { $_ -notin $successKeys }).Count -eq 0 -and @($bk | Where-Object { $_ -in $warnKeys }).Count -eq 0) "$lbl has only success texts, no warning" }
    }
    switch ($head) {
        'admHeadBlocked' { Assert-True ($c.Body -ceq (TT 'empMsgActionBlocked') -or $c.Body -ceq (TT 'empMsgReloadBlocked')) "$lbl = action blocked / reload blocked" }
        'admHeadNotLoaded' { Assert-True ($bk -contains 'empMsgLoadFailed' -and $c.Body.Contains('First(colEmpLoadErrors).Message')) "$lbl = load failed + first load error" }
        'admHeadLoaded' { Assert-True ($bk -contains 'empMsgLoaded') "$lbl = loaded count/time" }
        'admHeadDiscarded' { Assert-True ($c.Body -ceq (TT 'empMsgDiscarded')) "$lbl = changes discarded" }
        'admHeadAttention' { Assert-True (($bk -join ',') -ceq 'empWarnActiveWorkers') "$lbl = active-worker warning only" }
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
$unusedT = @($tKeys | Where-Object { $_ -cnotin $used })
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
Assert-True ($outArgs.Count -eq 3 -and $outArgs[1].Trim().StartsWith('Set(varAdmMsgKind,"Warning"); Set(varAdmMsgHead,' + (TT 'admHeadSaved') + ');') -and $outArgs[2].Trim().StartsWith('Set(varAdmMsgKind,"Success"); Set(varAdmMsgHead,' + (TT 'admHeadSaved') + ');')) 'Verified save: exactly one message per outcome (warning branch Warning, else Success), head "Saved."'
$iOutN = $saveN.IndexOf((Norm $outHead))
Assert-True ($iOutN -gt $iLocal -and $iOutN -gt $saveN.IndexOf('If(varEmpSaveRenamed,IfError(Refresh(Workers),') -and $iOutN -lt $saveN.IndexOf('Select(btnEmpFormReset)') -and $iOutN -lt $saveN.IndexOf('varEmpSaveWrites=0,')) 'Verified save: outcome message after the Workers refresh (its result is known), before the form reset, success branch only'
$condFx = $outArgs[0].Trim()
Assert-Eval "With({varEmpSaveWarnWorkers:0,varEmpSaveWorkersRefreshFailed:false},$condFx)" $false 'No warning: green Success'
Assert-Eval "With({varEmpSaveWarnWorkers:2,varEmpSaveWorkersRefreshFailed:false},$condFx)" $true 'Active workers on deactivation: amber Warning'
Assert-Eval "With({varEmpSaveWarnWorkers:0,varEmpSaveWorkersRefreshFailed:true},$condFx)" $true 'Workers refresh failed after rename: amber Warning'
Assert-Eval (Msg 'x:0' $saveMsg[0].Head) 'Saved.' 'Save message head: Saved.'
Assert-Eval (Msg 'varEmpSaveRenamed:false,varEmpSaveWarnWorkers:2,varEmpSaveWorkersRefreshFailed:false' $saveMsg[0].Body) '2 active worker(s) still have this contractor.' 'Saved. + active-worker warning in one amber message (no leading space)'
Assert-Eval (Msg 'varEmpSaveRenamed:false,varEmpSaveWarnWorkers:0,varEmpSaveWorkersRefreshFailed:true' $saveMsg[0].Body) 'Workers not refreshed: open Project / team and click Refresh.' 'Saved. + Workers-refresh warning'
Assert-Eval (Msg 'varEmpSaveRenamed:true,varEmpSaveWarnWorkers:0,varEmpSaveWorkersRefreshFailed:true' $saveMsg[0].Body) 'The new name also shows on past hours. Workers not refreshed: open Project / team and click Refresh.' 'Saved. + rename + Workers-refresh warning in one amber message'
Assert-Eval (Msg 'varEmpSaveRenamed:true,varEmpSaveWarnWorkers:3,varEmpSaveWorkersRefreshFailed:true' $saveMsg[0].Body) 'The new name also shows on past hours. 3 active worker(s) still have this contractor. Workers not refreshed: open Project / team and click Refresh.' 'Both warnings in one amber message'
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

# Message bar (conEmpMsgBar) directly under the title bar: full title width, 40 px, hidden (height 0) without a message
Assert-True ($idx['conEmpMsgBar']['Control'] -eq 'GroupContainer@1.5.0' -and $idx['conEmpMsgBar']['Variant'] -eq 'ManualLayout') 'conEmpMsgBar is a manual GroupContainer@1.5.0'
$barExp = [ordered]@{ X = '=lblEmpTitle.X'; Y = '=lblEmpTitle.Y+lblEmpTitle.Height'; Width = '=lblEmpTitle.Width'; Height = '=If(!IsBlank(varAdmMsgKind),40,0)'; Visible = '=!IsBlank(varAdmMsgKind)'
    Fill = '=Switch(varAdmMsgKind,"Error",ColorValue("#DB1E28"),"Warning",ColorValue("#F29400"),"Success",ColorValue("#1AFF80"),Color.Transparent)' }
foreach ($k in $barExp.Keys) { Assert-True ((Get-Prop 'conEmpMsgBar' $k) -ceq $barExp[$k]) "conEmpMsgBar.$k = $($barExp[$k])" }
$kids3 = @($doc['Screens'][$screenName]['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True ($kids3[3] -eq 'conEmpMsgBar' -and (@($idx['conEmpMsgBar']['Children'] | ForEach-Object { @($_.Keys)[0] }) -join ',') -ceq 'lblEmpMsgHead,lblEmpMsgBody,icoEmpMsgClose') 'Children: conEmpMsgBar after title, logo and spinner; bar holds head, body and close icon'
Assert-Eval 'IsBlank("")' $true 'Interpreter: IsBlank("") = true (cleared message hides the bar)'
$barFillFx = (Get-Prop 'conEmpMsgBar' 'Fill').TrimStart('=') -replace 'ColorValue\("(#[0-9A-F]{6})"\)', '"$1"' -replace 'Color\.Transparent', '"none"'
$textColFx = '=If(varAdmMsgKind="Error",Color.White,ColorValue("#000F41"))'
foreach ($case in @(@('"Error"', '#DB1E28', 'white', $true), @('"Warning"', '#F29400', '#000F41', $true), @('"Success"', '#1AFF80', '#000F41', $true), @('""', 'none', '#000F41', $false), @('If(false,"x")', 'none', '#000F41', $false))) {
    Assert-Eval "With({varAdmMsgKind:$($case[0])},$barFillFx)" $case[1] "Bar fill for kind $($case[0]) = $($case[1])"
    Assert-Eval "With({varAdmMsgKind:$($case[0])},$((Get-Prop 'conEmpMsgBar' 'Visible').TrimStart('=')))" $case[3] "Bar visible for kind $($case[0]) = $($case[3])"
    Assert-Eval "With({varAdmMsgKind:$($case[0])},$((Get-Prop 'conEmpMsgBar' 'Height').TrimStart('=')))" $(if ($case[3]) { 40 } else { 0 }) "Bar height for kind $($case[0])"
    Assert-Eval "With({varAdmMsgKind:$($case[0])},$($textColFx.TrimStart('=').Replace('Color.White', '"white"').Replace('ColorValue("#000F41")', '"#000F41"')))" $case[2] "Bar text colour for kind $($case[0]) = $($case[2])"
}
foreach ($c in @('lblEmpMsgHead', 'lblEmpMsgBody', 'icoEmpMsgClose')) { Assert-True ((Get-Prop $c 'Color') -ceq $textColFx) "$c.Color: white on red, #000F41 on amber/green" }
Assert-True ((Get-Prop 'lblEmpMsgHead' 'Text') -ceq '=varAdmMsgHead' -and (Get-Prop 'lblEmpMsgHead' 'FontWeight') -ceq '=FontWeight.Bold' -and (Get-Prop 'lblEmpMsgBody' 'Text') -ceq '=varAdmMsgBody' -and (Get-Prop 'lblEmpMsgBody' 'FontWeight') -ceq '=FontWeight.Normal') 'Head label Bold = varAdmMsgHead; body label Normal = varAdmMsgBody'
Assert-True ($idx['icoEmpMsgClose']['Control'] -eq 'Classic/Icon@2.5.0' -and (Get-Prop 'icoEmpMsgClose' 'Icon') -ceq '=Icon.Cancel' -and (Get-Prop 'icoEmpMsgClose' 'OnSelect') -ceq '=Set(varAdmMsgKind,""); Set(varAdmMsgHead,""); Set(varAdmMsgBody,"")' -and (Get-Prop 'icoEmpMsgClose' 'AccessibleLabel') -ceq ('=' + (TT 'admMsgClose'))) 'Close icon (Classic/Icon Icon.Cancel, label from T) clears kind, head and body'
Assert-True ($vis.StartsWith('=Set(varAdmMsgKind,""); Set(varAdmMsgHead,""); Set(varAdmMsgBody,"");') -and $vis.IndexOf('Set(varAdmMsgKind,"")') -lt $vis.IndexOf('Select(btnEmpLoad)')) 'OnVisible clears the message first, before the load'
$barReaders = @($all.Keys | Where-Object { $_ -notmatch '\.On\w+$' -and $all[$_] -match '\bvarAdmMsg(Kind|Head|Body)\b' } | ForEach-Object { ($_ -split '\.')[0] } | Sort-Object -Unique)
Assert-True (($barReaders -join ',') -ceq 'conEmpMsgBar,icoEmpMsgClose,lblEmpMsgBody,lblEmpMsgHead') "Message variables are only displayed by the bar controls ($($barReaders -join ', '))"

# Active switch (btnEmpActiveSwitch): same guard as the former checkbox, toggles varEmpActiveDraft, live amber warning only on -> off
$swDm = Get-Prop 'btnEmpActiveSwitch' 'DisplayMode'; $swSuffix = ',DisplayMode.Edit,DisplayMode.View)'
Assert-True ($swDm -ceq (Get-Prop 'txtEmpName' 'DisplayMode') -and $swDm.StartsWith('=If(') -and $swDm.EndsWith($swSuffix)) 'Switch DisplayMode = the form-input guard of the former checkbox (Loaded, no load errors, not busy/saving/SaveFailed, New/Edit; else View)'
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
    @{ Track = 'btnEmpActiveSwitch'; Knob = 'btnEmpActiveKnob'; State = 'Coalesce(varEmpActiveDraft,true)'; Parent = 'conEmpFormCard' },
    @{ Track = 'btnEmpShowInactiveSwitch'; Knob = 'btnEmpShowInactiveKnob'; State = 'Coalesce(varEmpShowInactive,false)'; Parent = 'conEmpListCard' })
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
Assert-True ((Get-Prop 'btnEmpShowInactiveSwitch' 'OnSelect') -ceq '=Set(varEmpShowInactive,!Coalesce(varEmpShowInactive,false))' -and (Get-Prop 'btnEmpShowInactiveSwitch' 'DisplayMode') -ceq '=DisplayMode.Edit') 'Show inactive switch: local filter toggle only, always available (as the former checkbox)'
$siSets = @($all.Keys | Where-Object { $all[$_] -match 'Set\(varEmpShowInactive,' } | Sort-Object)
Assert-True (($siSets -join ',') -ceq 'btnEmpShowInactiveSwitch.OnSelect,scrContractors.OnVisible') "varEmpShowInactive set only by its switch and the OnVisible init ($($siSets -join ', '))"
$items = (Get-Prop 'galEmpList' 'Items').TrimStart('=')
Assert-True ($items.Contains('(Coalesce(varEmpShowInactive,false) || Active)')) 'Gallery filter reads varEmpShowInactive (blank = hide inactive)'
$itemFix = 'colAdminEmployers:Table({ID:1,Name:"A",Code:"",City:"",Active:true},{ID:2,Name:"B",Code:"",City:"",Active:false},{ID:3,Name:"C",Code:"",City:"",Active:If(false,true)}),txtEmpSearch:{Text:""}'
foreach ($c in @(@('false', 2), @('true', 3), @('If(false,true)', 2))) { Assert-Eval "With({$itemFix,varEmpShowInactive:$($c[0])},CountRows($items))" ($c[1]) "Gallery rows with varEmpShowInactive = $($c[0]): $($c[1])" }
$stateFx = (Get-Prop 'lblEmpActiveState' 'Text').TrimStart('=')
foreach ($c in @(@('true', 'Active'), @('false', 'Inactive'), @('If(false,true)', 'Active'))) { Assert-Eval "With({LangNl:false,T:$tRec,varEmpActiveDraft:$($c[0])},$stateFx)" $c[1] "lblEmpActiveState shows the state as text ($($c[0]) -> $($c[1])), not only colour" }
Assert-True ((Get-Prop 'btnEmpActiveSwitch' 'Tooltip') -ceq (Get-Prop 'lblEmpActiveState' 'Text')) 'Active switch tooltip = state text'
# Red border per field, bound to colEmpSaveErrors.Field
$fieldsCollected = @([regex]::Matches($save, 'Collect\(colEmpSaveErrors,\{Field:"(\w*)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True (@($fieldsCollected | Where-Object { $_ -ne '' -and $_ -cnotin @($inputMap.Values) }).Count -eq 0) "Every collected error Field is one of the 8 inputs or '' ($($fieldsCollected -join ','))"
foreach ($k in $inputMap.Keys) {
    $f = $inputMap[$k]
    foreach ($pv in @(@('BorderColor', '#9B9B9B'), @('HoverBorderColor', '#5A5A5A'), @('FocusedBorderColor', '#0303B8'), @('PressedBorderColor', '#0303B8'))) {
        $exp = '=If(CountIf(colEmpSaveErrors,Field="' + $f + '")>0,ColorValue("#DB1E28"),ColorValue("' + $pv[1] + '"))'
        Assert-True ((Get-Prop $k $pv[0]) -ceq $exp) "$k.$($pv[0]) red #DB1E28 when colEmpSaveErrors has Field=$f, else $($pv[1])"
    }
    $bc = (Get-Prop $k 'BorderColor').TrimStart('=').Replace('ColorValue("#DB1E28")', '"red"').Replace('ColorValue("#9B9B9B")', '"grey"')
    Assert-Eval "With({colEmpSaveErrors:Table({Field:`"City`",Message:`"x`"},{Field:`"`",Message:`"y`"})},$bc)" $(if ($f -eq 'City') { 'red' } else { 'grey' }) "$k border with a City error"
    Assert-Eval "With({colEmpSaveErrors:Filter(Table({Field:`"$f`",Message:`"x`"}),false)},$bc)" 'grey' "$k border without errors"
    # A2 (30-10-2026): editable field = white, 1px #9B9B9B (2px red when invalid), radius 4, h36, focus 2px
    Assert-True ((Get-Prop $k 'BorderThickness') -ceq ('=If(CountIf(colEmpSaveErrors,Field="' + $f + '")>0,2,1)') -and (Get-Prop $k 'FocusedBorderThickness') -ceq '=2') "$k : border 1px (2px when invalid), focus 2px"
    foreach ($kv in @(@('Fill', '=Color.White'), @('HoverFill', '=Color.White'), @('PressedFill', '=Color.White'), @('Height', '=36'), @('RadiusTopLeft', '=4'), @('RadiusTopRight', '=4'), @('RadiusBottomLeft', '=4'), @('RadiusBottomRight', '=4'), @('Width', '=lblEmpGrid.Width'), @('Size', '=14'))) { Assert-True ((Get-Prop $k $kv[0]) -ceq $kv[1]) "$k.$($kv[0]) = $($kv[1])" }
}
Assert-True ((Get-Prop 'txtEmpSearch' 'BorderColor') -ceq '=ColorValue("#9B9B9B")') 'Search box has its own admin-pattern border (#9B9B9B, no error binding)'


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
foreach ($card in @(@('conEmpListCard', 'Fill', '=Color.White'), @('conEmpListCard', 'DropShadow', '=DropShadow.Light'), @('conEmpListCard', 'RadiusTopLeft', '=8'), @('conEmpListCard', 'X', '=24'), @('conEmpListCard', 'Y', '=24'), @('conEmpListCard', 'Width', '=If(lblEmpLayout.X=1,360,Parent.Width-48)'), @('conEmpListCard', 'Height', '=lblEmpMetrics.Width'),
        @('conEmpFormCard', 'Fill', '=Color.White'), @('conEmpFormCard', 'DropShadow', '=DropShadow.Light'), @('conEmpFormCard', 'RadiusTopLeft', '=8'), @('conEmpFormCard', 'X', '=lblEmpLayout.Y'), @('conEmpFormCard', 'Y', '=lblEmpLayout.Height'), @('conEmpFormCard', 'Width', '=lblEmpLayout.Width'), @('conEmpFormCard', 'Height', '=If(lblEmpLayout.X=1,lblEmpMetrics.Height-48,lblEmpMetrics.Y)'))) {
    Assert-True ((Get-Prop $card[0] $card[1]) -ceq $card[2]) "$($card[0]).$($card[1]) = $($card[2])"
}
$canvKids = @($idx['conEmpCanvas']['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($canvKids -join ',') -ceq 'conEmpListCard,conEmpFormCard') 'conEmpCanvas holds exactly the list card and the form card'
$listKids = @($idx['conEmpListCard']['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($listKids -join ',') -ceq 'txtEmpSearch,icoEmpSearch,lblEmpCount,lblEmpShowInactive,btnEmpShowInactiveSwitch,btnEmpShowInactiveKnob,galEmpList') "List card children: $($listKids -join ',')"
$sY = [int](Get-Prop 'txtEmpSearch' 'Y').TrimStart('='); $sH = [int](Get-Prop 'txtEmpSearch' 'Height').TrimStart('=')
Assert-True ($sY -eq 24 -and $sH -eq 36 -and (Get-Prop 'txtEmpSearch' 'Width') -eq '=Parent.Width-48' -and (Get-Prop 'txtEmpSearch' 'PaddingLeft') -eq '=40' -and (Get-Prop 'txtEmpSearch' 'RadiusTopLeft') -eq '=4' -and (Get-Prop 'txtEmpSearch' 'Fill') -eq '=Color.White' -and (Get-Prop 'txtEmpSearch' 'BorderColor') -eq '=ColorValue("#9B9B9B")' -and (Get-Prop 'txtEmpSearch' 'HoverBorderColor') -eq '=ColorValue("#5A5A5A")') 'Search field: white, 1px #9B9B9B (hover #5A5A5A), radius 4, h36, PaddingLeft 40 (room for the magnifier)'
Assert-True ((Get-Prop 'icoEmpSearch' 'Icon') -eq '=Icon.Search' -and $idx['icoEmpSearch']['Control'] -eq 'Classic/Icon@2.5.0' -and (Get-Prop 'icoEmpSearch' 'X') -eq '=txtEmpSearch.X+12' -and (Get-Prop 'icoEmpSearch' 'Width') -eq '=18') 'Magnifier = Classic/Icon Icon.Search inside the search field (X+12, 18 wide, ends before the text at 40)'
Assert-True ((Get-Prop 'txtEmpSearch' 'HintText') -eq (Get-Prop 'txtEmpSearch' 'AccessibleLabel') -and (Get-Prop 'txtEmpSearch' 'HintText') -eq '=If(LangNl && !IsBlank(T.empSearchHint.nl),T.empSearchHint.nl,T.empSearchHint.en)' -and $srcAll -match 'empSearchHint: \{en: "Search name, code or city"') 'Search hint from T: "Search name, code or city"'
Assert-True ((Get-Prop 'lblEmpCount' 'Text') -ceq '=Substitute(If(LangNl && !IsBlank(T.empCount.nl),T.empCount.nl,T.empCount.en),"{0}",Text(CountRows(galEmpList.AllItems)))' -and $srcAll -match 'empCount: \{en: "\{0\} contractors"') 'Count label: T.empCount with {0} = CountRows(galEmpList.AllItems) (visible gallery rows, no new data logic)'
$cH = 24
Assert-True ((Get-Prop 'lblEmpCount' 'Y') -eq '=txtEmpSearch.Y+txtEmpSearch.Height+12' -and (Get-Prop 'lblEmpShowInactive' 'Y') -eq '=lblEmpCount.Y' -and (Get-Prop 'btnEmpShowInactiveSwitch' 'Y') -eq '=lblEmpCount.Y' -and (Get-Prop 'btnEmpShowInactiveSwitch' 'X') -eq '=Parent.Width-24-Self.Width' -and (Get-Prop 'lblEmpShowInactive' 'X') -eq '=btnEmpShowInactiveSwitch.X-8-Self.Width' -and (Get-Prop 'lblEmpCount' 'X') -eq '=24') 'Row under the search: count left, Show inactive label + switch right (same Y)'
Assert-True ((Get-Prop 'galEmpList' 'Y') -eq '=lblEmpCount.Y+lblEmpCount.Height+12' -and (Get-Prop 'galEmpList' 'X') -eq '=0' -and (Get-Prop 'galEmpList' 'Width') -eq '=Parent.Width' -and (Get-Prop 'galEmpList' 'Height') -eq '=Parent.Height-Self.Y-12' -and (Get-Prop 'galEmpList' 'TemplateSize') -eq '=64') 'Gallery below the count row, full card width, row height 64 (padding 12/16)'
$gY = $sY + $sH + 12 + $cH + 12
Assert-True ((Get-Prop 'conEmpBody' 'Y') -eq '=conEmpMsgBar.Y+conEmpMsgBar.Height' -and (Get-Prop 'conEmpBody' 'Height') -eq '=Max(0,navEmp.Y-Self.Y)') 'Body starts directly under the message bar (bar directly under the title bar, height 0 when no message) and ends at the footer'
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
Assert-True ($null -eq $idx['lblEmpCodeValue'] -and $idx['txtEmpCode']['Control'] -eq 'Classic/TextInput@2.3.2') 'Contractor Code value is a Classic/TextInput@2.3.2 (txtEmpCode); lblEmpCodeValue is gone'
Assert-True ((Get-Prop 'txtEmpCode' 'DisplayMode') -eq '=DisplayMode.Disabled') 'txtEmpCode is always DisplayMode.Disabled (never editable)'
$codeDefault = 'If(Coalesce(varEmpMode,"")="Edit" && !IsBlank(varEmpEdit.Code),varEmpEdit.Code,Coalesce(varEmpMode,"") in ["New","Edit"],If(LangNl && !IsBlank(T.empCodeAuto.nl),T.empCodeAuto.nl,T.empCodeAuto.en),"")'
Assert-True ((Norm (Get-Prop 'txtEmpCode' 'Default').TrimStart('=')) -eq (Norm $codeDefault)) 'txtEmpCode Default = the former lblEmpCodeValue Text formula'
foreach ($kv in @(@('Fill','=ColorValue("#F0F0F0")'),@('DisabledFill','=ColorValue("#F0F0F0")'),@('BorderColor','=Color.Transparent'),@('DisabledBorderColor','=Color.Transparent'),@('Color','=ColorValue("#000000")'),@('DisabledColor','=ColorValue("#000000")'),@('BorderThickness','=0'),@('RadiusTopLeft','=4'),@('RadiusBottomRight','=4'),@('PaddingLeft','=12'),@('PaddingRight','=12'),@('Size','=14'),@('FontWeight','=FontWeight.Normal'),@('Height','=36'),@('Width','=lblEmpGrid.Width'),@('AccessibleLabel','=If(LangNl && !IsBlank(T.empFieldCode.nl),T.empFieldCode.nl,T.empFieldCode.en)'))) { Assert-True ((Get-Prop 'txtEmpCode' $kv[0]) -eq $kv[1]) "txtEmpCode.$($kv[0]) (read-only: grey fill, no border)" }
Assert-True ($dirty -notmatch 'txtEmpCode' -and $saveN -notmatch 'txtEmpCode') 'txtEmpCode is not part of dirty/Save (the app never writes Employer Code)'
# Grid carriers (pinned) and numeric mirror
Assert-True ((Get-Prop 'lblEmpMetrics' 'X') -eq '=If(lblEmpLayout.Width-48>=572,3,If(lblEmpLayout.Width-48>=376,2,1))' -and (Get-Prop 'lblEmpGrid' 'Width') -eq '=(lblEmpLayout.Width-48-16*(lblEmpMetrics.X-1))/lblEmpMetrics.X' -and (Get-Prop 'lblEmpGrid' 'Visible') -eq '=false') 'Grid: columns = 3 (content >= 572), 2 (>= 376), else 1; column width = (content - 16*(cols-1))/cols (gap 16, min ~180 per column); lblEmpGrid is a hidden label'
Assert-True ((Get-Prop 'lblEmpMetrics' 'Y') -eq '=lblEmpModified.Y+lblEmpModified.Height+24') 'lblEmpMetrics.Y = bottom of the last row (lblEmpModified) + 24 padding'
Assert-True ((Get-Prop 'lblEmpSecGeneral' 'Y') -eq '=lblEmpFormDivider.Y+1+20' -and (Get-Prop 'lblEmpSecAddress' 'Y') -eq '=lblEmpSecGeneral.Y+38+RoundUp(2/lblEmpMetrics.X,0)*74' -and (Get-Prop 'lblEmpSecContact' 'Y') -eq '=lblEmpSecAddress.Y+38+RoundUp(4/lblEmpMetrics.X,0)*74' -and (Get-Prop 'btnEmpActiveSwitch' 'Y') -eq '=lblEmpSecContact.Y+38+RoundUp(3/lblEmpMetrics.X,0)*74') 'Section tops: previous top + 38 + rows*74 (label 18 + 4 + field 36 + 16 row gap; header 18 + 12; 24 between sections); bottom row below CONTACT'
$grid = @{ GENERAL = @('Name', 'Code'); ADDRESS = @('Address', 'Postalcode', 'City', 'Country'); CONTACT = @('ContactName', 'ContactEmail', 'ContactPhone') }
$secCtl = @{ GENERAL = 'lblEmpSecGeneral'; ADDRESS = 'lblEmpSecAddress'; CONTACT = 'lblEmpSecContact' }
foreach ($s in $grid.Keys) {
    Assert-True ($idx[$secCtl[$s]]['Control'] -eq 'Label@2.5.1' -and (Get-Prop $secCtl[$s] 'Size') -eq '=12' -and (Get-Prop $secCtl[$s] 'FontWeight') -eq '=FontWeight.Bold' -and (Get-Prop $secCtl[$s] 'Color') -eq '=ColorValue("#0303B8")' -and (Get-Prop $secCtl[$s] 'Text') -match 'T\.emp' -and (Get-Prop $secCtl[$s] 'Height') -eq '=18') "$($secCtl[$s]): section header 12 Bold #0303B8 from T, h18"
    for ($n = 0; $n -lt $grid[$s].Count; $n++) {
        $f = $grid[$s][$n]; $lb = "lblEmp${f}Label"; $tx = "txtEmp$f"
        $xx = if ($n -eq 0) { '=24' } else { "=24+Mod($n,lblEmpMetrics.X)*(lblEmpGrid.Width+16)" }
        $yy = if ($n -eq 0) { "=$($secCtl[$s]).Y+30" } else { "=$($secCtl[$s]).Y+30+RoundDown($n/lblEmpMetrics.X,0)*74" }
        Assert-True ((Get-Prop $lb 'X') -ceq $xx -and (Get-Prop $tx 'X') -ceq $xx -and (Get-Prop $lb 'Y') -ceq $yy -and (Get-Prop $tx 'Y') -ceq "=$lb.Y+22" -and (Get-Prop $lb 'Width') -eq '=lblEmpGrid.Width') "$s field $n ($f): grid cell X/Y by column/row, input 22 px under the label top (label 18 + 4)"
        Assert-True ((Get-Prop $lb 'Size') -eq '=13' -and (Get-Prop $lb 'FontWeight') -eq '=FontWeight.Semibold' -and (Get-Prop $lb 'Color') -eq '=ColorValue("#000000")' -and (Get-Prop $lb 'Height') -eq '=18') "$lb : 13 Semibold black, h18"
    }
}
Assert-True ((Get-Prop 'lblEmpNameRequired' 'Text') -eq '="*"' -and (Get-Prop 'lblEmpNameRequired' 'Color') -eq '=ColorValue("#DB1E28")' -and (Get-Prop 'lblEmpNameRequired' 'Y') -eq '=lblEmpNameLabel.Y' -and (Get-Prop 'lblEmpNameRequired' 'X').StartsWith('=lblEmpNameLabel.X+Round(Len(lblEmpNameLabel.Text)') -and !$idx.ContainsKey('lblEmpCodeRequired')) 'Required marker: red "*" label right after Contractor Name only'
# header
Assert-True ((Get-Prop 'lblEmpFormTitle' 'Size') -eq '=22' -and (Get-Prop 'lblEmpFormTitle' 'FontWeight') -eq '=FontWeight.Semibold' -and (Get-Prop 'lblEmpFormTitle' 'Color') -eq '=ColorValue("#000F41")' -and (Get-Prop 'lblEmpFormTitle' 'Visible') -eq '=Coalesce(varEmpMode,"") in ["New","Edit"]' -and (Get-Prop 'lblEmpFormTitle' 'Text').Contains('T.empNewContractor') -and (Get-Prop 'lblEmpFormTitle' 'Text').Contains('varEmpEdit.Name')) 'Header: record name 22 Semibold #000F41 (Edit: varEmpEdit.Name; New: T.empNewContractor), only visible in New/Edit'
$chipFill = 'If(Coalesce(varEmpActiveDraft,true),ColorValue("#1AFF80"),ColorValue("#E6E6E6"))'; $chipCol = 'If(Coalesce(varEmpActiveDraft,true),ColorValue("#000F41"),ColorValue("#000000"))'
Assert-True ($idx['btnEmpFormChip']['Control'] -eq 'Classic/Button@2.2.0' -and (Get-Prop 'btnEmpFormChip' 'DisplayMode') -eq '=DisplayMode.Disabled' -and !$idx['btnEmpFormChip']['Properties'].ContainsKey('OnSelect') -and (Get-Prop 'btnEmpFormChip' 'Visible') -eq '=Coalesce(varEmpMode,"") in ["New","Edit"]') 'Status chip btnEmpFormChip: Classic/Button, static (Disabled with identical disabled colours), no OnSelect, New/Edit only'
foreach ($p in 'Fill', 'HoverFill', 'PressedFill', 'DisabledFill') { Assert-True ((Get-Prop 'btnEmpFormChip' $p) -ceq "=$chipFill") "btnEmpFormChip.$p = green #1AFF80 when Active, grey #E6E6E6 when Inactive (varEmpActiveDraft)" }
foreach ($p in 'Color', 'HoverColor', 'PressedColor', 'DisabledColor') { Assert-True ((Get-Prop 'btnEmpFormChip' $p) -ceq "=$chipCol") "btnEmpFormChip.$p = #000F41 on green, #000000 on grey" }
Assert-True ((Get-Prop 'btnEmpFormChip' 'Text').Contains('T.empFieldActive') -and (Get-Prop 'btnEmpFormChip' 'Text').Contains('T.empInactive') -and (Get-Prop 'btnEmpFormChip' 'X') -eq '=lblEmpFormTitle.X+lblEmpFormTitle.Width+12' -and (Get-Prop 'btnEmpFormChip' 'Height') -eq '=24' -and (Get-Prop 'btnEmpFormChip' 'RadiusTopLeft') -eq '=12' -and (Get-Prop 'btnEmpFormChip' 'Size') -eq '=12') 'Chip text is the state (not colour only), right of the name (12 px), h24, radius 12'
Assert-True ((Get-Prop 'lblEmpFormDivider' 'Fill') -eq '=ColorValue("#EDEDED")' -and (Get-Prop 'lblEmpFormDivider' 'Height') -eq '=1' -and (Get-Prop 'lblEmpFormDivider' 'Width') -eq '=lblEmpLayout.Width-48' -and (Get-Prop 'lblEmpFormDivider' 'Y') -eq '=lblEmpFormTitle.Y+lblEmpFormTitle.Height+16' -and (Get-Prop 'lblEmpFormDivider' 'Visible') -eq '=Coalesce(varEmpMode,"") in ["New","Edit"]') 'Divider: 1 px #EDEDED under the header, full content width, New/Edit only'
$formKids = @($idx['conEmpFormCard']['Children'] | ForEach-Object { @($_.Keys)[0] })
$expKids = 'lblEmpFormTitle,btnEmpFormChip,lblEmpFormDivider,lblEmpSecGeneral,lblEmpNameLabel,lblEmpNameRequired,txtEmpName,lblEmpCodeLabel,txtEmpCode,lblEmpSecAddress,lblEmpAddressLabel,txtEmpAddress,lblEmpPostalcodeLabel,txtEmpPostalcode,lblEmpCityLabel,txtEmpCity,lblEmpCountryLabel,txtEmpCountry,lblEmpSecContact,lblEmpContactNameLabel,txtEmpContactName,lblEmpContactEmailLabel,txtEmpContactEmail,lblEmpContactPhoneLabel,txtEmpContactPhone,btnEmpActiveSwitch,btnEmpActiveKnob,lblEmpActiveState,lblEmpModified'
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
# (16) Load/save spinner in the title bar (imgEmpSpinner) ---------------------------------------------------------------
Assert-True ($idx.ContainsKey('imgEmpSpinner') -and $idx['imgEmpSpinner']['Control'] -eq 'Image@2.2.3') 'imgEmpSpinner exists as Image@2.2.3'
$spImg = Get-Prop 'imgEmpSpinner' 'Image'
Assert-True ($spImg.StartsWith('="data:image/svg+xml;utf8," & EncodeUrl("<svg') -and $spImg.EndsWith('</svg>")') -and $spImg -notmatch "`n") 'Spinner Image: single-line data-URI SVG via EncodeUrl'
Assert-True ($spImg -match "<animateTransform[^>]*attributeName='transform'[^>]*type='rotate'[^>]*from='0 12 12'[^>]*to='360 12 12'[^>]*repeatCount='indefinite'" -and $spImg -match "viewBox='0 0 24 24'") 'Spinner SVG: 24x24 viewBox with animateTransform rotate 0..360 around 12 12, indefinite'
$spCols = @([regex]::Matches($spImg, '#[0-9A-Fa-f]{3,8}\b') | ForEach-Object { $_.Value.ToUpper() } | Sort-Object -Unique)
Assert-True ($spCols.Count -eq 1 -and $spCols[0] -eq '#FFFFFF') "Spinner SVG uses only #FFFFFF ($($spCols -join ','))"
Assert-True ($spImg -notmatch 'opacity|rgba?\(|hsla?\(' -and $spImg -notmatch "(?:stroke|fill)='(?!none'|#)") 'Spinner SVG: no opacity, rgb()/hsl() or named colours (only solid white on #0303B8)'
Assert-True ((Get-Prop 'imgEmpSpinner' 'Visible') -eq '=Coalesce(varEmpBusy,false) || Coalesce(varEmpSaving,false) || varEmpLoadState="Loading"') 'Spinner Visible = busy || saving || LoadState="Loading"'
Assert-True ((Get-Prop 'imgEmpSpinner' 'Width') -eq '=24' -and (Get-Prop 'imgEmpSpinner' 'Height') -eq '=24' -and (Get-Prop 'imgEmpSpinner' 'ImagePosition') -eq '=ImagePosition.Fit' -and (Get-Prop 'imgEmpSpinner' 'AccessibleLabel') -eq '=If(LangNl && !IsBlank(T.empBusy.nl),T.empBusy.nl,T.empBusy.en)') 'Spinner: 24x24, ImagePosition Fit, AccessibleLabel from T (empBusy)'
Assert-True (!$idx['imgEmpSpinner']['Properties'].ContainsKey('Fill') -and !$idx['imgEmpSpinner']['Properties'].ContainsKey('OnSelect')) 'Spinner has no Fill/OnSelect'
Assert-True ((Get-Prop 'imgEmpSpinner' 'X') -eq '=lblEmpTitle.X+lblEmpTitle.Width-24-Self.Width' -and (Get-Prop 'imgEmpSpinner' 'Y') -eq '=lblEmpTitle.Y+(lblEmpTitle.Height-Self.Height)/2') 'Spinner at the right of the title bar (24 px margin), vertically centred in the 60 px bar'
foreach ($W in 320, 480, 768, 1280) {
    $tX = 0; $tW = $W; $sX = $tX + $tW - 48; $lX = $tX + 15
    Assert-True ($sX -ge $lX + 99 -and $sX + 24 -le $tX + $tW) "W=$W : spinner (X $sX..$($sX + 24)) inside the title bar and clear of the logo (ends $($lX + 99))"
}
$kids = @($doc['Screens'][$screenName]['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True ($kids[0] -eq 'lblEmpTitle' -and $kids[1] -eq 'imgLogoContractors' -and $kids[2] -eq 'imgEmpSpinner') 'Children order: title, logo directly after, spinner after the logo'
Write-Output 'PASS Test-AdminScreens (Contractors): static structure only. Studio import, binding, delegation (Monitor), SharePoint case-sensitivity of Title = and functional tests NOT verified.'
