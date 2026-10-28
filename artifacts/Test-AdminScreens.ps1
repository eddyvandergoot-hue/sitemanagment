# Static checks for the admin screens (ADMIN_PLAN.md par. 6). Build 1: Contractors (scrContractors, list Employers).
# Proves source structure only: no Studio import, Canvas binding, delegation (Monitor) or functional result.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Check-WeeklySource.ps1')
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
foreach ($c in @('txtEmpName.Text', 'txtEmpAddress.Text', 'txtEmpPostalcode.Text', 'txtEmpCity.Text', 'txtEmpCountry.Text', 'txtEmpContactName.Text', 'txtEmpContactEmail.Text', 'txtEmpContactPhone.Text', 'chkEmpActive.Value')) {
    Assert-True ($dirty.Contains($c + '<>varEmpEdit.') -or $dirty.Contains($c + '<>Coalesce(varEmpEdit.')) "Dirty compares $c directly with varEmpEdit (no OnChange dependency)"
}
Assert-True ($guards.btnEmpSave.EndsWith('&& ' + $dirty)) 'Save requires dirty'
foreach ($ctl in @('btnEmpHome', 'btnEmpNew', 'btnEmpRefresh', 'galEmpList')) { Assert-True ($guards[$ctl].EndsWith('!' + $dirty)) "$ctl blocked while dirty (same dirty text)" }
Assert-True ($guards.btnEmpDiscard.Contains('|| ' + $dirty + ')')) 'Discard requires dirty or SaveFailed (same dirty text)'
Assert-True ($guards.btnEmpHome -ceq $guards.btnEmpRefresh -and $guards.btnEmpNew -ceq $guards.galEmpList) 'Home = Refresh guard; New = gallery-selection guard'
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
Assert-Eval (Get-GuardFx 'btnEmpHome' $clean.Replace('varEmpLoadState:"Loaded"', 'varEmpLoadState:"Failed"')) $true 'Home/Refresh allowed after a failed load (not dirty)'
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
Assert-True ($loadN.Contains((Norm 'If(Coalesce(varEmpForceRefresh,false),IfError(Refresh(Employers),'))) 'Forced load refreshes the Employers connector cache'
Assert-True ((Get-Prop 'btnEmpRefresh' 'OnSelect').Contains('Set(varEmpForceRefresh,true); Select(btnEmpLoad)')) 'Refresh forces the staged loader'
Assert-True ($vis.Contains('If(varEmpLoadState<>"Loaded" && !Coalesce(varEmpBusy,false) && !Coalesce(varEmpSaving,false) && !' + $dirty + ',Select(btnEmpLoad))')) 'OnVisible loads only when not Loaded, idle and not dirty'
$conc = Get-Balanced $load $load.IndexOf('Concurrent(')
$branches = Split-Args $conc.Substring('Concurrent('.Length, $conc.Length - 'Concurrent('.Length - 1)
Assert-True ($branches.Count -eq 2) 'Loader runs two independent reads in Concurrent'
Assert-True ($branches[0].Contains('ClearCollect(colPendingAdminEmployers,') -and $branches[0] -notmatch 'colEmpWorkersLoadErrors|colEmpLoadErrors\b' -and $branches[0].Contains('Collect(colEmpEmployersLoadErrors,')) 'Concurrent branch 1 writes only its own error collection'
Assert-True ($branches[1].Contains('ClearCollect(colPendingEmpWorkers,') -and $branches[1] -notmatch 'colEmpEmployersLoadErrors|colEmpLoadErrors\b' -and $branches[1].Contains('Collect(colEmpWorkersLoadErrors,')) 'Concurrent branch 2 writes only its own error collection'
$iMerge = $loadN.IndexOf('Collect(colEmpLoadErrors,colEmpEmployersLoadErrors,colEmpWorkersLoadErrors)')
$iLimitE = $loadN.IndexOf('If(CountRows(colPendingAdminEmployers)>=500,Collect(colEmpLoadErrors,')
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
    Assert-True ($save -match "$f\s*:\s*Trim\(txtEmp$f\.Text\)") "Save record trims $f"
    Assert-True ($saveN.Contains("If(Len(varEmpSaveRec.$f)>255,Collect(colEmpSaveErrors,")) "Length check <= 255 for $f"
}
Assert-True ($saveN.Contains('If(IsBlank(varEmpSaveRec.Name),Collect(colEmpSaveErrors,{Field:"Name"')) 'Name required (after Trim)'
Assert-True ($saveN.Contains('!IsMatch(varEmpSaveRec.ContactEmail,Match.Email)')) 'Email: empty or IsMatch(Match.Email)'
Assert-True ($saveN.Contains('Lower(Trim(Name))=varEmpDupKey&&(varEmpSaveMode="New"||ID<>varEmpSaveID)') -and ([regex]::Matches($saveN, [regex]::Escape('Lower(Trim(Name))=varEmpDupKey&&(varEmpSaveMode="New"||ID<>varEmpSaveID)'))).Count -eq 2) 'Duplicate name: trim + case-insensitive, own ID excluded, local list and server read'
Assert-True ($saveN.Contains('CountIf(colAdminEmployers,Lower(Trim(Name))=varEmpDupKey') -and $saveN.Contains('ClearCollect(colEmpDup,ForAll(Filter(Employers,Title=varEmpDupName)Asemp,')) 'Duplicate check on the loaded list and a delegable server read (Title = global var)'
Assert-True ($saveN.Contains('Set(varEmpDupName,varEmpSaveRec.Name);Set(varEmpDupKey,Lower(varEmpSaveRec.Name));')) 'Duplicate predicate variables set before the reads'
$proj = [regex]::Match($load, 'As emp,(\{ID:emp\.ID,[^}]*\})').Groups[1].Value
Assert-True ($proj.Length -gt 0 -and ([regex]::Matches($screenText, [regex]::Escape($proj))).Count -eq 4) 'One projection text for load, pre-read, duplicate read and verify read'
foreach ($f in @('Name', 'Address', 'Postalcode', 'City', 'Country', 'ContactName', 'ContactEmail', 'ContactPhone', 'Active')) {
    Assert-True ($saveN.Contains("p.$f<>varEmpEdit.$f")) "Conflict check compares $f (pre-read vs loaded snapshot)"
    Assert-True ($saveN.Contains("v.$f=varEmpSaveRec.$f")) "Verify read compares $f with the written value"
}
Assert-True ($saveN -notmatch 'p\.Code|v\.Code|Modified') 'Conflict/verify ignore Contractor Code (flow MS-019) and Modified'
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
Assert-True ($saveN.Contains('varEmpSaveWrites=0,Set(varEmpMsg,') -and $saveN.Contains('Set(varEmpSaveFailed,true);Set(varEmpLoadState,"Failed");')) 'Zero writes + error stays Loaded; write + error -> Failed and SaveFailed (input kept, save blocked)'
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

Write-Output 'PASS Test-AdminScreens (Contractors): static structure only. Studio import, binding, delegation (Monitor), SharePoint case-sensitivity of Title = and functional tests NOT verified.'
