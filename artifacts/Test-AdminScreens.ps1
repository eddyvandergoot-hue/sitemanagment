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
Assert-True ($dirty.Contains('Coalesce(chkEmpActive.Value,true)<>Coalesce(varEmpEdit.Active,true)')) 'Dirty compares chkEmpActive.Value with varEmpEdit.Active, both sides Coalesce(x,true) (blank Active = active)'
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
'txtEmpName:{Text:"B"},txtEmpAddress:{Text:""},txtEmpPostalcode:{Text:""},txtEmpCity:{Text:""},txtEmpCountry:{Text:""},txtEmpContactName:{Text:""},txtEmpContactEmail:{Text:""},txtEmpContactPhone:{Text:""},chkEmpActive:{Value:true}'
$clean = $fix.Replace('txtEmpName:{Text:"B"}', 'txtEmpName:{Text:"A"}')
function Get-GuardFx($name, $fixture) { return 'With({' + $fixture + '},' + $guards[$name] + ')' }
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix) $true 'Save allowed: Loaded, Edit with ID, dirty'
Assert-Eval (Get-GuardFx 'btnEmpSave' $clean) $false 'Save blocked: not dirty'
Assert-Eval (Get-GuardFx 'btnEmpSave' $clean.Replace('chkEmpActive:{Value:true}', 'chkEmpActive:{Value:false}')) $true 'Save allowed: only Active unchecked (dirty)'
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
Assert-True ((Get-Prop 'chkEmpActive' 'Default') -ceq '=Coalesce(varEmpEdit.Active,true)') 'chkEmpActive.Default = varEmpEdit.Active (blank shown as active)'
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
Assert-True ($save.Contains('Active:Coalesce(chkEmpActive.Value,true)});')) 'Save record: Active = Coalesce(chkEmpActive.Value,true)'
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
Assert-True ($saveN.Contains('varEmpSaveWrites=0,Notify(') -and $saveN.Contains('Set(varEmpSaveFailed,true);Set(varEmpLoadState,"Failed");')) 'Zero writes + error stays Loaded; write + error -> Failed and SaveFailed (input kept, save blocked)'
Assert-True (([regex]::Matches($saveN, 'Set\(varEmpSaveFailed,true\)')).Count -eq 1) 'SaveFailed set in exactly one place'
Assert-True ($saveN.Contains('Set(varEmpSaveWarnWorkers,If(varEmpSaveMode="Edit"&&Coalesce(varEmpEdit.Active,true)&&!varEmpSaveRec.Active,CountIf(colEmpWorkers,EmployerID=varEmpSaveID')) 'Deactivation with active workers is counted (warning)'
Assert-True ($screenText -notmatch 'Collect\(colEmpSaveErrors,\{[^}]*empWarnActiveWorkers') 'Active-worker warning never blocks the save'
Assert-True ($load.Contains('ClearCollect(colPendingEmpWorkers,ForAll(Workers As wrk,{ID:wrk.ID,EmployerID:wrk.Employer.Id,WorkerActive:wrk.Active}))')) 'Workers read for the warning: explicit projection (lookup ID filtered locally)'
$reset = 'Reset(txtEmpName); Reset(txtEmpAddress); Reset(txtEmpPostalcode); Reset(txtEmpCity); Reset(txtEmpCountry); Reset(txtEmpContactName); Reset(txtEmpContactEmail); Reset(txtEmpContactPhone); Reset(chkEmpActive)'
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
    if ($k -like '*.Font') { continue }
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
    return "txtEmpName:{Text:$name},txtEmpAddress:{Text:$empty},txtEmpPostalcode:{Text:$empty},txtEmpCity:{Text:$city},txtEmpCountry:{Text:$empty},txtEmpContactName:{Text:$empty},txtEmpContactEmail:{Text:$empty},txtEmpContactPhone:{Text:$empty},chkEmpActive:{Value:$active}"
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
Assert-True ($fr.Contains($reset)) 'Form reset resets all 8 inputs and the Active checkbox'
Assert-True ($fr -notmatch '\b(Patch|Refresh|Collect|ClearCollect|Remove|RemoveIf|Clear|Set|UpdateContext|Select|Navigate)\(' -and $fr -notmatch '\.Run\(') 'Form reset is local only (no mutation, no variable change, no further Select: no cycle)'
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
Assert-True (($modUses -join ',') -ceq 'btnEmpLoad.OnSelect,btnEmpSave.OnSelect,lblEmpModified.Text') "Modified used only in the loader, the save display update and lblEmpModified.Text ($($modUses -join ', '))"
foreach ($k in @('btnEmpSave.DisplayMode', 'btnEmpRefresh.DisplayMode', 'btnEmpDiscard.DisplayMode', 'btnEmpHome.DisplayMode', 'btnEmpNew.DisplayMode', 'galEmpList.DisplayMode')) { Assert-True ($all[$k] -notmatch 'Modified|colEmpModified') "$k guard does not use Modified" }
Assert-True ($tableFx -notmatch 'Modified|colEmpModified' -and $conflictFx -notmatch 'Modified|colEmpModified' -and $dirty -notmatch 'Modified') 'Modified never in verify, conflict or dirty comparison'
$modFx = (Get-Prop 'lblEmpModified' 'Text').TrimStart('=')
Assert-True ($idx['lblEmpModified']['Control'] -eq 'Label@2.5.1' -and $modFx.Contains('LookUp(colEmpModified,ID=varEmpSelectedID).Modified') -and $modFx -notmatch "\b(Employers|Filter)\b") 'lblEmpModified: read-only label from the local copy (no SharePoint call)'
$modFix = 'LangNl:false,T:' + $tRec + ',colEmpModified:Table({ID:7,Modified:DateTime(2026,10,29,21,5,0)},{ID:8,Modified:DateTime(2026,1,2,9,4,0)})'
Assert-Eval ('With({' + $modFix + ',varEmpMode:"Edit",varEmpSelectedID:7},' + $modFx + ')') 'Last changed in SharePoint: 29-10-2026 21:05' 'Modified line (Edit, item 7): dd-mm-yyyy hh:mm'
Assert-Eval ('With({' + $modFix + ',varEmpMode:"Edit",varEmpSelectedID:8},' + $modFx + ')') 'Last changed in SharePoint: 02-01-2026 09:04' 'Modified line (Edit, item 8): leading zeros, 24-hour'
Assert-Eval ('With({' + $modFix + ',varEmpMode:"New",varEmpSelectedID:Blank()},' + $modFx + ')') '' 'Modified line empty for New'
Assert-Eval ('With({' + $modFix + ',varEmpMode:"Edit",varEmpSelectedID:9},' + $modFx + ')') '' 'Modified line empty when the item has no loaded Modified'

# (15) Messages only via the Power Apps notification bar (Eddy 29-10-2026) ------------------------------------------
# No message text on the screen: errors NotificationType.Error (15000 ms; Failed/SaveFailed 0 = until closed), success NotificationType.Success (default
# timeout), one Notify per outcome, no Warning/Information; an invalid field is shown only by a red #DB1E28 border.
foreach ($gone in @('lblEmpStatus', 'lblEmpErrors')) { Assert-True (!$idx.ContainsKey($gone)) "$gone removed (no message text on the screen)" }
Assert-True ($srcAll -notmatch '\bvarEmpMsg(Error)?\b') 'varEmpMsg/varEmpMsgError no longer exist in Src'
$msgProps = @($all.Keys | Where-Object { $_ -notmatch '\.On\w+$' -and $all[$_] -match '\.Message\b|\bT\.emp(Msg|Err|Warn)\w*\.' } | Sort-Object)
Assert-True ($msgProps.Count -eq 0) "No non-behaviour property shows a message or error text ($($msgProps -join ', '))"
Assert-True ($screenText -notmatch 'NotificationType\.(Warning|Information)') 'No NotificationType.Warning/Information on scrContractors'
$notifies = @()
foreach ($k in ($all.Keys | Sort-Object)) {
    $fx = $all[$k]
    foreach ($m in [regex]::Matches($fx, '\bNotify\(')) {
        $call = Get-Balanced $fx ($m.Index + 6)
        $notifies += [pscustomobject]@{ Key = $k; Pos = $m.Index; Args = (Split-Args $call.Substring(1, $call.Length - 2)) }
    }
}
$successKeys = @('empMsgLoaded', 'empMsgSaved', 'empMsgSavedRename', 'empMsgDiscarded', 'empMsgNew')
foreach ($n in $notifies) {
    $type = $n.Args[1].Trim(); $keysIn = @([regex]::Matches($n.Args[0], '\bT\.(\w+)\.en\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    Assert-True ($n.Key -match '\.On\w+$') "$($n.Key) : Notify only in a behaviour formula"
    if ($type -eq 'NotificationType.Error') {
        # Failed states (load failed, SaveFailed) leave a read-only screen: that message stays until closed (timeout 0).
        $sticky = @($keysIn | Where-Object { $_ -in @('empMsgLoadFailed', 'empMsgSaveFailed', 'empMsgSaveFailedNew') }).Count -gt 0
        $expTimeout = if ($sticky) { '0' } else { '15000' }
        Assert-True ($n.Args.Count -eq 3 -and $n.Args[2].Trim() -eq $expTimeout -and @($keysIn | Where-Object { $_ -in $successKeys }).Count -eq 0) "$($n.Key) : error Notify (T: $($keysIn -join ',')) uses NotificationType.Error, $expTimeout ms, no success text"
    } else {
        Assert-True ($type -eq 'NotificationType.Success' -and $n.Args.Count -eq 2 -and @($keysIn | Where-Object { $_ -notin $successKeys -and $_ -notin @('empWarnActiveWorkers', 'empWarnWorkersRefresh') }).Count -eq 0 -and @($keysIn | Where-Object { $_ -in $successKeys }).Count -ge 1) "$($n.Key) : success Notify (T: $($keysIn -join ',')) uses NotificationType.Success with the default timeout"
    }
}
$expNotify = [ordered]@{ 'btnEmpLoad.OnSelect' = 3; 'btnEmpSave.OnSelect' = 4; 'btnEmpNew.OnSelect' = 2; 'btnEmpDiscard.OnSelect' = 2; 'btnEmpRefresh.OnSelect' = 1; 'galEmpList.OnSelect' = 1 }
$gotNotify = (($notifies | Group-Object Key | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ';')
Assert-True ($gotNotify -ceq (($expNotify.Keys | Sort-Object | ForEach-Object { "$_=$($expNotify[$_])" }) -join ';')) "Notify per formula as expected: $gotNotify"
$blockedN = Norm ',Notify(If(LangNl && !IsBlank(T.empMsgActionBlocked.nl),T.empMsgActionBlocked.nl,T.empMsgActionBlocked.en),NotificationType.Error,15000))'
foreach ($ctl in @('btnEmpSave', 'btnEmpNew', 'btnEmpRefresh', 'btnEmpDiscard', 'galEmpList')) { Assert-True ((Norm (Get-Prop $ctl 'OnSelect')).EndsWith($blockedN)) "$ctl : the guard's else branch notifies 'action blocked' as an error (no mutation)" }
Assert-True ($load.Contains('Notify(If(LangNl && !IsBlank(T.empMsgReloadBlocked.nl),T.empMsgReloadBlocked.nl,T.empMsgReloadBlocked.en),NotificationType.Error,15000),')) 'Loader: reload over unsaved input notifies an error and does nothing else'
foreach ($k in @('btnEmpLoad.OnSelect', 'btnEmpSave.OnSelect')) { foreach ($m in [regex]::Matches($all[$k], '\bTrace\(')) { Assert-True ((Get-Balanced $all[$k] ($m.Index + 5)) -notmatch 'Notify') "$k : no Notify inside a Trace" } }
# Texts (T) and the composed notification texts, evaluated with the interpreter
$fixTexts = [ordered]@{ empErrNameRequired = 'Fix: Contractor Name empty'; empErrEmail = 'Fix: Contact Email invalid'; empErrPhone = 'Fix: Contact Phone invalid'; empErrTooLong = 'Fix: {0} too long'; empErrDuplicate = 'Fix: Contractor Name already exists' }
foreach ($k in $fixTexts.Keys) { Assert-True ($formulas.Contains("$($k): {en: ""$($fixTexts[$k])"", nl: """"}")) "T.$k = '$($fixTexts[$k])'" }
$conflictMsg = 'Changed in SharePoint by someone else. Nothing saved. Click Discard, then Refresh.'
Assert-True ($formulas.Contains("empErrConflict: {en: ""$conflictMsg"", nl: """"}")) 'T.empErrConflict exact text'
$unusedT = @($tKeys | Where-Object { $_ -cnotin $used })
Assert-True ($unusedT.Count -eq 0) "No unused T keys ($($unusedT -join ', '))"
$saveNot = @($notifies | Where-Object Key -eq 'btnEmpSave.OnSelect' | Sort-Object Pos)
$loadNot = @($notifies | Where-Object Key -eq 'btnEmpLoad.OnSelect' | Sort-Object Pos)
function Msg([string]$fixture, [string]$fx) { return "With({LangNl:false,T:$tRec},With({$fixture},$fx))" }
Assert-True ($saveN.IndexOf((Norm $saveNot[1].Args[0])) -gt $saveN.IndexOf('varEmpSaveWrites=0,') -and $saveN.IndexOf((Norm $saveNot[2].Args[0]), $saveN.IndexOf('Set(varEmpSaveFailed,true)')) -gt 0) 'Save outcome: zero-write Notify after varEmpSaveWrites=0, failed-save Notify after SaveFailed'
Assert-Eval (Msg 'colEmpSaveErrors:Table({Field:"",Message:T.empErrConflict.en})' $saveNot[1].Args[0]) $conflictMsg 'Conflict notification is exactly the conflict text'
Assert-Eval (Msg 'colEmpSaveErrors:Table({Field:"Name",Message:T.empErrNameRequired.en},{Field:"ContactEmail",Message:T.empErrEmail.en},{Field:"ContactPhone",Message:T.empErrPhone.en})' $saveNot[1].Args[0]) 'Fix: Contractor Name empty (+2 more)' 'Several validation errors: one notification, first error + (+n more)'
Assert-Eval (Msg 'colEmpSaveErrors:Table({Field:"City",Message:Substitute(T.empErrTooLong.en,"{0}",T.empFieldCity.en)})' $saveNot[1].Args[0]) 'Fix: City too long' 'Too long: field label in the notification'
Assert-Eval (Msg 'varEmpSaveMode:"Edit",colEmpSaveErrors:Table({Field:"",Message:T.empErrPatch.en & " " & "List is read-only."})' $saveNot[2].Args[0]) 'Save not confirmed by SharePoint. List is read-only. Check SharePoint, then click Discard.' 'Failed save (Edit): SharePoint reason behind the short text'
Assert-Eval (Msg 'varEmpSaveMode:"New",colEmpSaveErrors:Table({Field:"",Message:Substitute(T.empErrVerifyFields.en,"{0}","City, Active")})' $saveNot[2].Args[0]) 'Save not confirmed: different in SharePoint: City, Active. Maybe created: click Discard, then search the name before retrying.' 'Failed save (New, verify mismatch): field labels, New advice'
Assert-Eval (Msg 'varEmpSaveRenamed:false,varEmpSaveWarnWorkers:2,varEmpSaveWorkersRefreshFailed:false' $saveNot[0].Args[0]) 'Saved. 2 active worker(s) still have this contractor.' 'Saved + active-worker warning in one success notification'
Assert-Eval (Msg 'varEmpSaveRenamed:true,varEmpSaveWarnWorkers:0,varEmpSaveWorkersRefreshFailed:true' $saveNot[0].Args[0]) 'Saved. The new name also shows on past hours. Workers not refreshed: open Project / team and click Refresh.' 'Saved + rename + Workers-refresh warning in one success notification'
Assert-Eval (Msg 'colAdminEmployers:Table({ID:1},{ID:2},{ID:3}),varEmpLoadedAt:DateTime(2026,10,29,21,5,7)' $loadNot[1].Args[0]) '3 contractors loaded at 21:05:07' 'Load success notification: count and time'
Assert-Eval (Msg 'colEmpLoadErrors:Table({Message:T.empErrLoadEmployers.en & " " & "Network error"},{Message:T.empErrLimitWorkers.en})' $loadNot[2].Args[0]) 'Loading failed. Click Refresh. Contractors not read: Network error (+1 more)' 'Load failure notification: first error + (+n more)'
# Red border per field, bound to colEmpSaveErrors.Field
$fieldsCollected = @([regex]::Matches($save, 'Collect\(colEmpSaveErrors,\{Field:"(\w*)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True (@($fieldsCollected | Where-Object { $_ -ne '' -and $_ -cnotin @($inputMap.Values) }).Count -eq 0) "Every collected error Field is one of the 8 inputs or '' ($($fieldsCollected -join ','))"
foreach ($k in $inputMap.Keys) {
    $f = $inputMap[$k]
    foreach ($pv in @(@('BorderColor', '#DCDCDC'), @('HoverBorderColor', '#0303B8'), @('FocusedBorderColor', '#0303B8'))) {
        $exp = '=If(CountIf(colEmpSaveErrors,Field="' + $f + '")>0,ColorValue("#DB1E28"),ColorValue("' + $pv[1] + '"))'
        Assert-True ((Get-Prop $k $pv[0]) -ceq $exp) "$k.$($pv[0]) red #DB1E28 when colEmpSaveErrors has Field=$f, else $($pv[1])"
    }
    $bc = (Get-Prop $k 'BorderColor').TrimStart('=').Replace('ColorValue("#DB1E28")', '"red"').Replace('ColorValue("#DCDCDC")', '"grey"')
    Assert-Eval "With({colEmpSaveErrors:Table({Field:`"City`",Message:`"x`"},{Field:`"`",Message:`"y`"})},$bc)" $(if ($f -eq 'City') { 'red' } else { 'grey' }) "$k border with a City error"
    Assert-Eval "With({colEmpSaveErrors:Filter(Table({Field:`"$f`",Message:`"x`"}),false)},$bc)" 'grey' "$k border without errors"
}
Assert-True ((Get-Prop 'txtEmpSearch' 'BorderColor') -ceq '=ColorValue("#DCDCDC")') 'Search box keeps the standard border (no error binding)'


# Geometry (TP-CONTRACTORS-01): search border not under the header, wide form top = list top, narrow no overlap.
# The carriers' formulas are pinned by exact text, then mirrored here for each width.
$expLay = @{ X='=If(Parent.Width>=1000,1,0)'; Y='=If(Self.X=1,464,40)'; Width='=If(Self.X=1,Min(584,Parent.Width-504),Min(584,Parent.Width-80))'; Height='=If(Self.X=1,100,404)' }
foreach ($k in $expLay.Keys) { Assert-True ((Get-Prop 'lblEmpLayout' $k) -eq $expLay[$k]) "Layout carrier lblEmpLayout.$k formula as mirrored" }
Assert-True ((Get-Prop 'lblEmpMetrics' 'X') -eq '=If(lblEmpLayout.Width-48>=536,1,0)' -and (Get-Prop 'lblEmpMetrics' 'Width') -eq '=If(lblEmpLayout.X=1,Max(200,Self.Height-124),280)' -and (Get-Prop 'lblEmpMetrics' 'Height') -eq '=If(lblEmpLayout.X=1,Max(conEmpBody.Height,lblEmpLayout.Height+Self.Y+24,288),lblEmpLayout.Height+Self.Y+24)' -and (Get-Prop 'lblEmpMetrics' 'Y') -eq '=24+76*(8+(1-Self.X))+40+12+20+24') 'Layout carrier lblEmpMetrics formulas as mirrored'
$sY = [int](Get-Prop 'txtEmpSearch' 'Y').TrimStart('='); $sH = [int](Get-Prop 'txtEmpSearch' 'Height').TrimStart('=')
$cY = [int](Get-Prop 'chkEmpShowInactive' 'Y').TrimStart('='); $cH = [int](Get-Prop 'chkEmpShowInactive' 'Height').TrimStart('=')
$gY = [int](Get-Prop 'galEmpList' 'Y').TrimStart('=')
Assert-True ($sY -ge 12) "Search box Y=$sY >= 12 (full border visible below the container top / status area)"
Assert-True ($cY -ge $sY + $sH + 8 -and $gY -ge $cY + $cH + 8) "Search < checkbox < list stack without overlap (Y $sY, $cY, $gY)"
Assert-True ((Get-Prop 'conEmpBody' 'Y') -eq '=lblEmpTitle.Y+lblEmpTitle.Height+12') 'Body starts 12 px under the title bar (no status line; messages only via Notify)'
foreach ($W in 320, 768, 900, 1000, 1280, 1366, 1920) {
    foreach ($errH in @(0)) {
        $wide = $W -ge 1000
        $layX = [int]$wide; $layY = if ($wide) { 464 } else { 40 }
        $layW = if ($wide) { [Math]::Min(584, $W - 504) } else { [Math]::Min(584, $W - 80) }
        $layH = if ($wide) { 100 } else { 404 }
        $metX = [int](($layW - 48) -ge 536)
        $metY = 24 + 76 * (8 + (1 - $metX)) + 40 + 12 + 20 + 24
        $bodyH = 500
        $metH = if ($wide) { [Math]::Max($bodyH, [Math]::Max($layH + $metY + 24, 288)) } else { $layH + $metY + 24 }
        $galH = if ($wide) { [Math]::Max(200, $metH - 124) } else { 280 }
        $galW = [Math]::Min(400, $W - 80)
        $lbl = "W=$W errBlock=$errH"
        Assert-True ($sY -ge 12 -and $gY + $galH -le $metH) "$lbl : search top $sY, list bottom $($gY + $galH) within canvas $metH"
        Assert-True ((($W -ge 1000) -and ($layY + $layW + 40 -le $W)) -or (($W -lt 1000) -and ($layY + $layW -le $W))) "$lbl : form (X=$layY, w=$layW) inside screen"
        if ($wide) {
            Assert-True ($layH -eq $gY) "$lbl : wide form top ($layH) = galEmpList top ($gY), below search ($sY) and checkbox ($cY)"
            Assert-True (40 + $galW + 24 -le $layY) "$lbl : wide list (right edge $(40 + $galW)) clear of form X=$layY"
            Assert-True ($layH + $metY -le $metH) "$lbl : form bottom $($layH + $metY) within canvas $metH"
        } else {
            Assert-True ($layH -ge $gY + $galH + 24) "$lbl : narrow form top $layH >= list bottom $($gY + $galH) + 24 (no overlap)"
            Assert-True ($layH + $metY -le $metH) "$lbl : narrow form bottom within canvas $metH"
        }
    }
}
# 29-10-2026: Contractor Code = read-only TextInput (txtEmpCode, always Disabled, field style); lblEmpModified = small grey line under chkEmpActive.
function Num($c,$pr){ $t=(Get-Prop $c $pr).TrimStart('='); $t=$t.Replace('lblEmpMetrics.X','1').Replace('24+76*1+24','124').Replace('24+76*2','176'); return [int](Invoke-Expression $t) }
Assert-True ($null -eq $idx['lblEmpCodeValue'] -and $idx['txtEmpCode']['Control'] -eq 'Classic/TextInput@2.3.2') 'Contractor Code value is a Classic/TextInput@2.3.2 (txtEmpCode); lblEmpCodeValue is gone'
Assert-True ((Get-Prop 'txtEmpCode' 'DisplayMode') -eq '=DisplayMode.Disabled') 'txtEmpCode is always DisplayMode.Disabled (never editable)'
$codeDefault = 'If(Coalesce(varEmpMode,"")="Edit" && !IsBlank(varEmpEdit.Code),varEmpEdit.Code,Coalesce(varEmpMode,"") in ["New","Edit"],If(LangNl && !IsBlank(T.empCodeAuto.nl),T.empCodeAuto.nl,T.empCodeAuto.en),"")'
Assert-True ((Norm (Get-Prop 'txtEmpCode' 'Default').TrimStart('=')) -eq (Norm $codeDefault)) 'txtEmpCode Default = the former lblEmpCodeValue Text formula'
foreach ($kv in @(@('Fill','=ColorValue("#F0F0F0")'),@('DisabledFill','=ColorValue("#F0F0F0")'),@('BorderColor','=ColorValue("#DCDCDC")'),@('DisabledBorderColor','=ColorValue("#DCDCDC")'),@('Color','=ColorValue("#000000")'),@('DisabledColor','=ColorValue("#000000")'),@('BorderThickness','=1'),@('RadiusTopLeft','=6'),@('RadiusBottomRight','=6'),@('PaddingLeft','=8'),@('PaddingRight','=8'),@('Size','=12'),@('FontWeight','=FontWeight.Normal'),@('Height','=40'),@('Width','=Min(256,lblEmpLayout.Width-48)'),@('X','=24'),@('Y','=24+76*1+24'),@('AccessibleLabel','=If(LangNl && !IsBlank(T.empFieldCode.nl),T.empFieldCode.nl,T.empFieldCode.en)'))) { Assert-True ((Get-Prop 'txtEmpCode' $kv[0]) -eq $kv[1]) "txtEmpCode.$($kv[0])" }
Assert-True ($dirty -notmatch 'txtEmpCode' -and $saveN -notmatch 'txtEmpCode') 'txtEmpCode is not part of dirty/Save (the app never writes Employer Code)'
$cvY = Num 'txtEmpCode' 'Y'; $cvH = Num 'txtEmpCode' 'Height'; $adY = Num 'lblEmpAddressLabel' 'Y'
Assert-True ($cvY + $cvH -le $adY) "txtEmpCode (ends $($cvY + $cvH)) above the address label ($adY)"
$mY = Num 'lblEmpModified' 'Y'; $mH = Num 'lblEmpModified' 'Height'; $chY = Num 'chkEmpActive' 'Y'; $chH = Num 'chkEmpActive' 'Height'
foreach ($W in 320, 768, 900, 1000, 1280, 1920) {
    $X = if ($W - 48 -ge 536) { 1 } else { 0 }
    $mY2 = 24 + 76 * (8 + (1 - $X)) + 40 + 12; $chY2 = 24 + 76 * (8 + (1 - $X)); $metY = 24 + 76 * (8 + (1 - $X)) + 40 + 12 + 20 + 24
    Assert-True ($mY2 -ge $chY2 + $chH + 12 -and $mY2 + $mH + 24 -le $metY) "W=$W : lblEmpModified (Y $mY2..$($mY2 + $mH)) 12 px under chkEmpActive (ends $($chY2 + $chH)), inside the form panel (ends $metY)"
}
Assert-True ((Get-Prop 'lblEmpModified' 'Y') -eq '=24+76*(8+(1-lblEmpMetrics.X))+40+12' -and (Get-Prop 'lblEmpMetrics' 'Y') -eq '=24+76*(8+(1-Self.X))+40+12+20+24') 'lblEmpModified Y = checkbox bottom + 12; lblEmpMetrics.Y includes the label + 24 bottom padding'
Assert-True ((Get-Prop 'lblEmpModified' 'X') -eq '=24' -and (Get-Prop 'lblEmpModified' 'Width') -eq '=Min(512,lblEmpLayout.Width-48)' -and (Get-Prop 'lblEmpModified' 'Size') -eq '=11' -and (Get-Prop 'lblEmpModified' 'FontWeight') -eq '=FontWeight.Normal' -and (Get-Prop 'lblEmpModified' 'Color') -eq '=ColorValue("#787878")' -and (Get-Prop 'lblEmpModified' 'Height') -eq '=20') 'lblEmpModified: Inter 11 Normal, #787878, Height 20, width Min(512,...)'
Write-Output 'PASS Test-AdminScreens (Contractors): static structure only. Studio import, binding, delegation (Monitor), SharePoint case-sensitivity of Title = and functional tests NOT verified.'
