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
# 01-11-2026 (Studio FAIL A/B of build components-20261031_074310): the dirty expression lives once in the hidden label lbl<P>Dirty
# (Text = If(<dirty>,"true","false")); every guard reads the label (03-11-2026 N1: fail-closed, clean only = "false"), so no cmpField output is read inside a component
# input. 03-11-2026 (approval build, Eddy): the temporary debug line (lbl<P>Debug, varDebug, varDbgEvent) is removed; this helper checks
# that nothing of it is left, then expands the label reference in the property map, so all behavioural checks below still evaluate the
# real guard text.
function Apply-DirtyLabel($map, [string]$p, [string]$scr) {
    $lblFx = ([string]$map["lbl${p}Dirty.Text"]).Trim()
    $head = "=If((Coalesce(var${p}Mode,`"`") in [`"New`",`"Edit`"] && ("; $tail = ',"true","false")'
    Assert-True ($lblFx.StartsWith($head) -and $lblFx.EndsWith($tail) -and ([string]$map["lbl${p}Dirty.Visible"]).Trim() -eq '=false') "${scr}: lbl${p}Dirty is a hidden label, Text = If(<dirty>,""true"",""false"") (the one dirty source)"
    $d = $lblFx.Substring(4, $lblFx.Length - 4 - $tail.Length)
    # N1 (03-11-2026, fail-closed): "clean" only when the label literally says "false"; every blocking / Discard-permitting read is
    # <>"false" (blank or unexpected = dirty); Save requires the literal "true" (blank or unexpected = no Save).
    $scrN = if ($p -eq 'Emp') { 'scrContractors' } elseif ($p -eq 'Prj') { 'scrProjects' } else { 'scrWorkers' }
    $cleanRef = "lbl${p}Dirty.Text=`"false`""; $dirtyRef = "lbl${p}Dirty.Text<>`"false`""; $saveRef = "lbl${p}Dirty.Text=`"true`""
    $expByRef = [ordered]@{
        $cleanRef = @("cmp${p}Footer.HomeEnabled", "cmp${p}Footer.OnHome", "cmp${p}Footer.NewEnabled", "cmp${p}Footer.OnNew", "cmp${p}Footer.RefreshEnabled", "cmp${p}Footer.OnRefresh", "cmp${p}List.Enabled", "cmp${p}List.OnSelectRow", "cmp${p}List.OnToggleShowInactive", "$scrN.OnVisible") | Sort-Object
        $dirtyRef = @("cmp${p}Footer.DiscardEnabled", "cmp${p}Footer.OnDiscard", "btn${p}Load.OnSelect") | Sort-Object
        $saveRef  = @("cmp${p}Footer.SaveEnabled", "cmp${p}Footer.OnSave") | Sort-Object
    }
    $readers = @(@($map.Keys) | Where-Object { $_ -notlike "lbl${p}Dirty.*" -and ([string]$map[$_]) -cmatch "\blbl${p}Dirty\.Text\b" } | Sort-Object)
    $expAll = @($expByRef.Values | ForEach-Object { $_ }) | Sort-Object
    Assert-True (($readers -join ',') -ceq ($expAll -join ',')) "${scr}: exactly the 15 guards (footer inputs/handlers, list card, loader, OnVisible) read lbl${p}Dirty.Text ($($readers -join ', '))"
    foreach ($r in $expByRef.Keys) {
        $users = @(@($map.Keys) | Where-Object { ([string]$map[$_]).Contains($r) } | Sort-Object)
        Assert-True (($users -join ',') -ceq ($expByRef[$r] -join ',')) "${scr}: guards reading $r : $($users -join ', ')"
    }
    $refCount = 0; foreach ($k in $readers) { $t = [string]$map[$k]; $all3 = ([regex]::Matches($t, "\blbl${p}Dirty\.Text\b")).Count; $known = 0; foreach ($r in $expByRef.Keys) { $known += ([regex]::Matches($t, [regex]::Escape($r))).Count }; Assert-True ($all3 -eq $known -and $t -notmatch "!\(lbl${p}Dirty|\(lbl${p}Dirty\.Text=`"true`"\)") "${scr}: $k reads lbl${p}Dirty.Text only in a fail-closed form (=""false"", <>""false"", Save =""true""; no !(... =""true""))"; $refCount += $known }
    # Fixtures with the label value itself (blank / unexpected text = fail-closed), on the real guard texts before expansion
    $gfx = "var${p}LoadState:`"Loaded`",col${p}LoadErrors:Filter(Table({Message:`"`"}),false),var${p}Busy:false,var${p}Saving:false,var${p}SaveFailed:false,var${p}Mode:`"Edit`",var${p}SelectedID:5"
    $gfxFailed = $gfx.Replace("var${p}SaveFailed:false", "var${p}SaveFailed:true").Replace("var${p}LoadState:`"Loaded`"", "var${p}LoadState:`"Failed`"")
    # Workers (08-11-2026): OnVisible always reloads fresh when idle and clean (forced load; H16), so its condition has no LoadState term.
    $visCond = if ($p -eq 'Wrk') { "!Coalesce(var${p}Busy,false) && !Coalesce(var${p}Saving,false) && $cleanRef" } else { "var${p}LoadState<>`"Loaded`" && !Coalesce(var${p}Busy,false) && !Coalesce(var${p}Saving,false) && $cleanRef" }
    $visAct = if ($p -eq 'Wrk') { "Set(var${p}ForceRefresh,true); Select(btn${p}Load)" } else { "Select(btn${p}Load)" }
    $loadCond = "$dirtyRef && !Coalesce(var${p}SaveFailed,false)"
    Assert-True (([string]$map["$scrN.OnVisible"]).Contains("If($visCond,$visAct)") -and ([string]$map["btn${p}Load.OnSelect"]).Contains("If($loadCond,")) "${scr}: OnVisible auto-loads only when the label says ""false""; the loader refuses unless the label says ""false"" (or after a failed save)"
    $gExpr = [ordered]@{ Home = ([string]$map["cmp${p}Footer.HomeEnabled"]).Trim().Substring(1); New = ([string]$map["cmp${p}Footer.NewEnabled"]).Trim().Substring(1); Refresh = ([string]$map["cmp${p}Footer.RefreshEnabled"]).Trim().Substring(1); List = ([string]$map["cmp${p}List.Enabled"]).Trim().Substring(1); Discard = ([string]$map["cmp${p}Footer.DiscardEnabled"]).Trim().Substring(1); Save = ([string]$map["cmp${p}Footer.SaveEnabled"]).Trim().Substring(1); AutoLoad = $visCond; LoadBlocked = $loadCond }
    #                    label       Home   New    Refresh List   Discard Save   AutoLoad LoadBlocked
    $gCases = @(@('"false"', $true, $true, $true, $true, $false, $false, $true, $false),
                @('"true"', $false, $false, $false, $false, $true, $true, $false, $true),
                @('""', $false, $false, $false, $false, $true, $false, $false, $true),
                @('Blank()', $false, $false, $false, $false, $true, $false, $false, $true),
                @('"x"', $false, $false, $false, $false, $true, $false, $false, $true))
    foreach ($c in $gCases) {
        $i = 1
        foreach ($g in $gExpr.Keys) {
            $env = if ($g -eq 'AutoLoad') { $gfx.Replace("var${p}LoadState:`"Loaded`"", "var${p}LoadState:`"NotLoaded`"") } else { $gfx }
            Assert-Eval "With({$env,lbl${p}Dirty:{Text:$($c[0])}},$($gExpr[$g]))" $c[$i] "${scr} N1: label $($c[0]) -> $g $(if ($c[$i]) { 'allowed' } else { 'blocked' })"
            $i++
        }
        foreach ($g in @(@('Refresh', $true), @('Discard', $true), @('LoadBlocked', $false), @('Save', $false), @('New', $false))) { Assert-Eval "With({$gfxFailed,lbl${p}Dirty:{Text:$($c[0])}},$($gExpr[$g[0]]))" $g[1] "${scr} N1: after a failed save, label $($c[0]) -> $($g[0]) $(if ($g[1]) { 'allowed (Refresh = Discard, H15)' } else { 'not allowed / not blocking' })" }
    }
    $cv = @(@($map.Keys) | Where-Object { ([string]$map[$_]) -cmatch "\bcmp${p}\w+\.Value\b" -and $_ -notin @("lbl${p}Dirty.Text", "cmp${p}Footer.OnSave", $(if ($p -eq 'Wrk') { 'lblWrkDupKey.Text' } else { 'lbl-none' })) })
    Assert-True ($cv.Count -eq 0) "${scr}: cmpField Value is read only by lbl${p}Dirty and the Save record (cmp${p}Footer.OnSave) ($($cv -join ', '))"
    # Expand the label reference for the behavioural checks below: clean = !<dirty>, dirty / Save = <dirty> (same results as the label for its two real values)
    foreach ($k in $readers) { $map[$k] = ([string]$map[$k]).Replace($dirtyRef, $d).Replace($saveRef, $d).Replace($cleanRef, '!' + $d) }
    $evs = [ordered]@{ "cmp${p}Footer.OnHome" = 'OnHome'; "cmp${p}Footer.OnNew" = 'OnNew'; "cmp${p}Footer.OnRefresh" = 'OnRefresh'; "cmp${p}Footer.OnDiscard" = 'OnDiscard'; "cmp${p}Footer.OnSave" = 'OnSave'; "cmp${p}List.OnSelectRow" = 'OnSelectRow'; "cmp${p}List.OnToggleShowInactive" = 'OnToggleShowInactive'; "cmp${p}MsgBar.OnClose" = 'OnClose' }
    foreach ($k in $evs.Keys) {
        Assert-True (([string]$map[$k]).Trim() -notmatch 'varDbg') "${scr}: $k has no debug prefix (debug line removed for the approval build)"
    }
    $left = @(@($map.Keys) | Where-Object { $_ -like "lbl${p}Debug.*" -or ([string]$map[$_]) -match '\bvarDbg\w*|\bvarDebug\b' })
    Assert-True ($left.Count -eq 0) "${scr}: no debug line left (lbl${p}Debug, varDbgEvent, varDebug) ($($left -join ', '))"
    foreach ($k in @(@($map.Keys) | Where-Object { $_ -like "lbl${p}Dirty.*" })) { $map.Remove($k) }
    $script:lastDirty = $d
}

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
Apply-DirtyLabel $all 'Emp' 'Contractors'; $dirtyFromLbl = $script:lastDirty
$screenText = ($all.Values) -join "`n"
$srcAll = (Get-ChildItem $srcDir -Filter *.pa.yaml | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
Assert-True ($srcAll.Contains('OnStart: =Set(varSaving, false); Set(varWeekSaving, false); Set(varLang, "en")') -and $srcAll -notmatch '\bvarDebug\b|\bvarDbg\w*|lbl(Emp|Prj)Debug') 'App.OnStart without varDebug and no debug line anywhere in Src (approval build)'
$srcDeep = (Get-ChildItem $srcDir -Filter *.pa.yaml -Recurse | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
Assert-True ($srcDeep -notmatch '\bvarDebug\b|\bvarDbg\w*|lbl(Emp|Prj)Debug') 'No debug line in Src including Src\Components (approval build)'
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
Assert-True ($dirty -ceq $dirtyFromLbl) 'Dirty text in the Save guard = the lblEmpDirty text (one source)'
foreach ($f in @('Name', 'Street', 'HouseNumber', 'Postalcode', 'City', 'Country', 'ContactName', 'ContactEmail', 'ContactPhone')) {
    Assert-True ($dirty.Contains("Trim(cmpEmp$f.Value & """")<>Trim(varEmpEdit.$f & """")")) "Dirty compares cmpEmp$f.Value directly with varEmpEdit, both sides Trim(x & """") (no OnChange dependency, blank = empty)"
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
'varEmpEdit:{ID:5,Name:"A",Code:"",Street:"",HouseNumber:"",Postalcode:"",City:"",Country:"",ContactName:"",ContactEmail:"",ContactPhone:"",Active:true},' +
'cmpEmpName:{Value:"B"},cmpEmpStreet:{Value:""},cmpEmpHouseNumber:{Value:""},cmpEmpPostalcode:{Value:""},cmpEmpCity:{Value:""},cmpEmpCountry:{Value:""},cmpEmpContactName:{Value:""},cmpEmpContactEmail:{Value:""},cmpEmpContactPhone:{Value:""},varEmpActiveDraft:true'
$clean = $fix.Replace('cmpEmpName:{Value:"B"}', 'cmpEmpName:{Value:"A"}')
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
Assert-Eval (Get-GuardFx 'btnEmpSave' $newFix.Replace('cmpEmpName:{Value:"B"}', 'cmpEmpName:{Value:""}')) $false 'Save blocked: New without input'
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
# Form is bound to varEmpEdit (cmpField.DefaultValue), never to the list selection. Step 3a: cmpField instances replace txtEmp* + labels + star.
$inputMap = [ordered]@{ cmpEmpName = 'Name'; cmpEmpStreet = 'Street'; cmpEmpHouseNumber = 'HouseNumber'; cmpEmpPostalcode = 'Postalcode'; cmpEmpCity = 'City'; cmpEmpCountry = 'Country'; cmpEmpContactName = 'ContactName'; cmpEmpContactEmail = 'ContactEmail'; cmpEmpContactPhone = 'ContactPhone' }
$fieldEnabled = '=varEmpLoadState="Loaded" && IsEmpty(colEmpLoadErrors) && !Coalesce(varEmpBusy,false) && !Coalesce(varEmpSaving,false) && !Coalesce(varEmpSaveFailed,false) && Coalesce(varEmpMode,"") in ["New","Edit"]'
$fieldLabels = @{ cmpEmpName = 'empFieldName'; cmpEmpCode = 'empFieldCode'; cmpEmpStreet = 'empFieldStreet'; cmpEmpHouseNumber = 'empFieldHouseNumber'; cmpEmpPostalcode = 'empFieldPostalcode'; cmpEmpCity = 'empFieldCity'; cmpEmpCountry = 'empFieldCountry'; cmpEmpContactName = 'empFieldContactName'; cmpEmpContactEmail = 'empFieldContactEmail'; cmpEmpContactPhone = 'empFieldContactPhone' }
foreach ($k in $inputMap.Keys) {
    Assert-True ($idx[$k]['Control'] -eq 'CanvasComponent' -and $idx[$k]['ComponentName'] -eq 'cmpField') "${k} is a cmpField instance"
    $ip = $idx[$k]['Properties']
    Assert-True (([string]$ip['DefaultValue']).Trim() -ceq "=varEmpEdit.$($inputMap[$k])") "${k}.DefaultValue = varEmpEdit.$($inputMap[$k])"
    Assert-True (([string]$ip['Enabled']).Trim() -ceq $fieldEnabled) "${k}.Enabled = the edit guard (Loaded, no load error, not busy/saving/failed, Mode New or Edit), as Boolean"
    Assert-True ($ip['Invalid'] -ceq ('=CountIf(colEmpSaveErrors,Field="' + $inputMap[$k] + '")>0')) "${k}.Invalid = CountIf(colEmpSaveErrors,Field=""$($inputMap[$k])"")>0 (red border rule)"
    $itExp = if ($k -eq 'cmpEmpCountry') { '="dropdown"' } else { '="text"' }
    Assert-True ($ip['InputType'] -ceq $itExp -and $ip['MaxLength'] -ceq '=255' -and $ip['HintText'] -ceq '=""' -and -not $ip.ContainsKey('OnChange')) "${k}: InputType $itExp, MaxLength 255, HintText, no OnChange logic"
    Assert-True (($ip.ContainsKey('Items')) -eq ($k -eq 'cmpEmpCountry')) "${k}: Items only on the Country dropdown"
    Assert-True ($ip['Label'] -ceq ('=' + (TT0 $fieldLabels[$k]))) "${k}.Label from T.$($fieldLabels[$k])"
    Assert-True (($ip.ContainsKey('Required') -and $ip['Required'] -eq '=true') -eq ($k -eq 'cmpEmpName')) "${k}.Required only on Contractor Name"
    Assert-True ($ip['Height'] -ceq '=58' -and $ip['Width'] -ceq '=lblEmpGrid.Width') "${k}: height 58 (label 18 + 4 + field 36), grid cell width"
}
$cp = $idx['cmpEmpCode']['Properties']
Assert-True ($idx['cmpEmpCode']['ComponentName'] -eq 'cmpField' -and $cp['InputType'] -ceq '="readonly"' -and $cp['Enabled'] -ceq '=false' -and -not $cp.ContainsKey('Required') -and -not $cp.ContainsKey('Invalid')) 'cmpEmpCode: read-only, never enabled, no star, never written (not in the dirty check or Save record)'
Assert-True ($cp['Label'] -ceq ('=' + (TT0 $fieldLabels['cmpEmpCode'])) -and ([string]$cp['DefaultValue']).Contains('varEmpEdit.Code') -and ([string]$cp['DefaultValue']).Contains((TT0 'empCodeAuto'))) 'cmpEmpCode.DefaultValue = saved code, or the automatic text in New/Edit without code'
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
$vis = [string]$all["$screenName.OnVisible"]  # dirty label expanded (Apply-DirtyLabel)
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
        if ($arg.TrimStart().StartsWith('Patch(') -or $arg.TrimStart().StartsWith('If(varEmpSaveWriteCountry,Patch(Employers,')) { continue }  # item 9: the one write (record shape chosen by If)
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
Assert-True ($screenText -notmatch '\bSearch\(') 'No Search() on scrContractors'
# 04-11-2026 (item 9, MS-024): Employers.Country is a choice column. Choices() only on the cmpEmpCountry dropdown Items and once in Save (in-list flag), never inside ForAll.
$eChoices = @($all.Keys | Where-Object { $all[$_] -match '\bChoices\(' } | Sort-Object)
Assert-True (($eChoices -join ',') -ceq 'btnEmpSave.OnSelect,cmpEmpCountry.Items') "Contractors: Choices() only on the Country dropdown Items and in Save ($($eChoices -join ', '))"
Assert-True ((Get-Prop 'cmpEmpCountry' 'Items') -ceq '=ShowColumns(Choices([@Employers].Country),Value)') 'Contractors: Country dropdown Items = ShowColumns(Choices([@Employers].Country),Value) (column Value as identifier), same as Projects'
Assert-True (([regex]::Matches((Get-Prop 'btnEmpSave' 'OnSelect'), '\bChoices\(')).Count -eq 1 -and @($all.Values | Where-Object { $_ -match 'ForAll\([^;]*\bChoices\(' }).Count -eq 0) 'Contractors: Choices() once in Save, never inside ForAll'
Assert-True ($screenText -notmatch "ForAll\([^)]*\b(?:Employers|Workers)\b[^)]*\)[^;]*\b(?:LookUp|Filter)\(\s*(?:Employers|Workers)") 'No remote LookUp/Filter inside ForAll'

# (6)-(8) Save: validation, duplicate block, conflict check, one Patch, verify read, local update after verify ----
$save = Get-Prop 'btnEmpSave' 'OnSelect'; $saveN = Norm $save
# Item 9 (04-11-2026, Country choice safety like Projects N3): one write per save; the record shape (with / without Country) is chosen by one If inside the single write gate.
$eSelAt = $save.IndexOf('ClearCollect(colEmpPatched,If(')
Assert-True ($eSelAt -gt 0 -and ([regex]::Matches($save, 'ClearCollect\(colEmpPatched,')).Count -eq 1) 'Contractors: exactly one ClearCollect(colEmpPatched, If(<shape>, Patch, Patch)) write step in Save'
$eSel = Get-Balanced $save ($eSelAt + 'ClearCollect(colEmpPatched,If'.Length)
$eSelArgs = Split-Args $eSel.Substring(1, $eSel.Length - 2)
Assert-True ($eSelArgs.Count -eq 3 -and $eSelArgs[0].Trim() -ceq 'varEmpSaveWriteCountry' -and $eSelArgs[1].Trim().StartsWith('Patch(Employers,') -and $eSelArgs[2].Trim().StartsWith('Patch(Employers,')) 'Contractors: If(varEmpSaveWriteCountry, Patch(with Country), Patch(without Country)): exactly one Patch runs'
Assert-True (([regex]::Matches($srcAll, '\bPatch\(\s*Employers\b')).Count -eq 2 -and ([regex]::Matches($eSel, '\bPatch\(\s*Employers\b')).Count -eq 2) 'The two Patch(Employers) shapes are both inside that one If in btnEmpSave.OnSelect (no other Patch(Employers) in Src)'
$eShape = @{}
foreach ($si in 1, 2) {
    $sp = $eSelArgs[$si].Trim(); $sa = Split-Args $sp.Substring('Patch('.Length, $sp.Length - 'Patch('.Length - 1)
    Assert-True ($sa.Count -eq 3 -and $sa[1].Trim() -ceq 'If(varEmpSaveMode="New",Defaults(Employers),First(colEmpPreRaw))') "Contractors: shape $si : base Defaults(Employers) for New, the pre-read record for Edit"
    $sr = $sa[2].Trim(); $eShape[$si] = [ordered]@{}; foreach ($a in (Split-Args $sr.Substring(1, $sr.Length - 2))) { $kv = $a -split ':', 2; $eShape[$si][$kv[0].Trim()] = $kv[1].Trim() }
}
$eShapeExp = @{ 1 = "Title,Street,'House Number',Postalcode,City,Country,'Contact Name','Contact Email','Contact Phone',Active"; 2 = "Title,Street,'House Number',Postalcode,City,'Contact Name','Contact Email','Contact Phone',Active" }
foreach ($si in 1, 2) { Assert-True ((@($eShape[$si].Keys) -join ',') -ceq $eShapeExp[$si]) "Contractors: shape $si writes exactly $($eShapeExp[$si]) (no Address, no Employer Code)" }
Assert-True ((@($eShape[2].Keys | ForEach-Object { "$_=$($eShape[2][$_])" }) -join ';') -ceq (@($eShape[1].Keys | Where-Object { $_ -ne 'Country' } | ForEach-Object { "$_=$($eShape[1][$_])" }) -join ';')) 'Contractors: both shapes write the other 9 fields identically'
Assert-True ($eShape[1]['Country'] -ceq 'If(IsBlank(varEmpSaveRec.Country),Blank(),{Value:varEmpSaveRec.Country})') 'Contractors: Country patched as {Value: ...} (blank selection = Blank())'
Assert-True ($eShape[1]['Title'] -ceq 'varEmpSaveRec.Name' -and $eShape[1]['Street'] -ceq 'varEmpSaveRec.Street' -and $eShape[1]["'House Number'"] -ceq 'varEmpSaveRec.HouseNumber') 'Contractors: Title = Name, Street, House Number from the save record'
Assert-True ($eSel -notmatch '\bChoices\(' -and $srcAll -notmatch '\bemp\.Address\b' -and $screenText -notmatch '\bAddress\s*:' -and $screenText -notmatch '\.Address\b|\bcmpEmpAddress\b|empFieldAddress') 'Contractors: no Choices() in a Patch record; Address is never read, compared, shown or written on scrContractors (column kept in SharePoint)'
foreach ($k in $all.Keys) { if ($k -ne 'btnEmpSave.OnSelect') { Assert-True ($all[$k] -notmatch '\bPatch\(') "$k has no Patch" } }
Assert-True ($eSel -notmatch "Employer Code|EmployerCode1|'Employer Code'") 'Patch never writes Contractor Code (Employer Code / EmployerCode1)'
foreach ($f in @('Name', 'Street', 'HouseNumber', 'Postalcode', 'City', 'Country', 'ContactName', 'ContactEmail', 'ContactPhone')) {
    Assert-True ($save -match "$f\s*:\s*Trim\(cmpEmp$f\.Value & """"\)") "Save record trims $f (Trim(x & """"): blank input = empty text)"
    if ($f -ne 'Country') { Assert-True ($saveN.Contains("If(Len(varEmpSaveRec.$f)>255,Collect(colEmpSaveErrors,{Field:`"$f`"")) "Length check <= 255 for $f" } else { Assert-True (!$saveN.Contains('If(Len(varEmpSaveRec.Country)>255')) 'Country: no length check (choice list check instead, like Projects)' }
}
Assert-True ($saveN.Contains('If(IsBlank(varEmpSaveRec.Name),Collect(colEmpSaveErrors,{Field:"Name"')) 'Name required (after Trim)'
Assert-True ($saveN.Contains('!IsMatch(varEmpSaveRec.ContactEmail,Match.Email)')) 'Email: empty or IsMatch(Match.Email)'
Assert-True ($saveN.Contains('Lower(Trim(Name))=varEmpDupKey&&(varEmpSaveMode="New"||ID<>varEmpSaveID)') -and ([regex]::Matches($saveN, [regex]::Escape('Lower(Trim(Name))=varEmpDupKey&&(varEmpSaveMode="New"||ID<>varEmpSaveID)'))).Count -eq 2) 'Duplicate name: trim + case-insensitive, own ID excluded, local list and server read'
Assert-True ($saveN.Contains('CountIf(colAdminEmployers,Lower(Trim(Name))=varEmpDupKey') -and $saveN.Contains('ClearCollect(colEmpDup,ForAll(Filter(Employers,Title=varEmpDupName)Asemp,')) 'Duplicate check on the loaded list and a delegable server read (Title = global var)'
Assert-True ($saveN.Contains('Set(varEmpDupName,varEmpSaveRec.Name);Set(varEmpDupKey,Lower(varEmpSaveRec.Name));')) 'Duplicate predicate variables set before the reads'
$proj = [regex]::Match($load, 'As emp,(\{ID:emp\.ID,[^}]*\})').Groups[1].Value
Assert-True ($proj.Length -gt 0 -and ([regex]::Matches($screenText, [regex]::Escape($proj))).Count -eq 4) 'One projection text for load, pre-read, duplicate read and verify read'
foreach ($f in @('Name', 'Street', 'HouseNumber', 'Postalcode', 'City', 'Country', 'ContactName', 'ContactEmail', 'ContactPhone')) {
    Assert-True ($saveN.Contains("Trim(p.$f&`"`")<>Trim(varEmpEdit.$f&`"`")")) "Conflict check compares $f (pre-read vs loaded snapshot, both Trim(x & `"`"))"
    Assert-True ($saveN.Contains("D:Trim(v.$f&`"`")<>Trim(varEmpSaveRec.$f&`"`")")) "Verify read compares $f with the written value (both Trim(x & `"`"))"
}
Assert-True ($saveN.Contains('Coalesce(p.Active,true)<>Coalesce(varEmpEdit.Active,true)')) 'Conflict check compares Active (both Coalesce(x,true))'
Assert-True ($saveN.Contains('D:Coalesce(v.Active,true)<>Coalesce(varEmpSaveRec.Active,true)')) 'Verify read compares Active (both Coalesce(x,true))'
Assert-True ($save.Contains('Active:Coalesce(varEmpActiveDraft,true)});')) 'Save record: Active = Coalesce(varEmpActiveDraft,true) (switch draft)'
$modDisplayN = Norm 'RemoveIf(colEmpModified,ID=varEmpPatchedID); Collect(colEmpModified,{ID:varEmpPatchedID,Modified:First(colEmpVerifyRaw).Modified});'
Assert-True (([regex]::Matches($saveN, [regex]::Escape($modDisplayN))).Count -eq 1) 'Save updates the display-only Modified copy (colEmpModified) from the verify read, once'
$ctlDecN = Norm 'If(CountRows(colEmpCtlRaw)=1 && First(colEmpCtlRaw).Modified=First(colEmpPreRaw).Modified,"NoWrite","PossibleWrite")'
Assert-True (([regex]::Matches($saveN, [regex]::Escape($ctlDecN))).Count -eq 1) 'N1 control read (Edit): Modified of the control read compared with the pre-read, once'
Assert-True ($saveN.Replace($modDisplayN, '').Replace($ctlDecN, '') -notmatch 'p\.Code|v\.Code|Modified') 'Conflict/verify ignore Contractor Code (flow MS-019) and Modified (Modified only in the display copy update and the N1 control read after a Patch error)'
$iVal = $saveN.IndexOf('If(IsBlank(varEmpSaveRec.Name)')
$iDupLocal = $saveN.IndexOf('CountIf(colAdminEmployers,')
$iGateRead = $saveN.IndexOf('If(IsEmpty(colEmpSaveErrors),IfError(Refresh(Employers),')
$iPre = $saveN.IndexOf('ClearCollect(colEmpPreRaw,Filter(Employers,ID=varEmpSaveID))')
$iDup = $saveN.IndexOf('ClearCollect(colEmpDup,')
$iConf = $saveN.IndexOf('Set(varEmpSaveConflict,true)')
$iWriteGate = $saveN.IndexOf('If(IsEmpty(colEmpSaveErrors),Set(varEmpPatchError,false);IfError(CountRows(ClearCollect(colEmpPatched,If(varEmpSaveWriteCountry,Patch(Employers,')
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
$reset = 'Reset(cmpEmpName); Reset(cmpEmpStreet); Reset(cmpEmpHouseNumber); Reset(cmpEmpPostalcode); Reset(cmpEmpCity); Reset(cmpEmpCountry); Reset(cmpEmpContactName); Reset(cmpEmpContactEmail); Reset(cmpEmpContactPhone); Set(varEmpActiveDraft,Coalesce(varEmpEdit.Active,true))'
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
foreach ($c in @("'Employer Code'", 'Street', "'House Number'", 'Postalcode', 'City', 'Country.Value', "'Contact Name'", "'Contact Email'", "'Contact Phone'")) { Assert-True ($proj.Contains("Trim(emp.$c & `"`")")) "Projection normalizes $c with Trim(x & `"`")" }
Assert-True ((@([regex]::Matches($proj, '[\{,](\w+):') | ForEach-Object { $_.Groups[1].Value }) -join ',') -ceq 'ID,Name,Code,Street,HouseNumber,Postalcode,City,Country,ContactName,ContactEmail,ContactPhone,Active' -and $proj -notmatch 'Address') 'Projection fields: ID, Name, Code, Street, HouseNumber, Postalcode, City, Country (choice .Value), ContactName, ContactEmail, ContactPhone, Active (no Address)'
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
Assert-True (($fNames -join ',') -ceq 'Name,Street,HouseNumber,Postalcode,City,Country,ContactName,ContactEmail,ContactPhone,Active') "Verify compares exactly the app-written fields: $($fNames -join ',')"
Assert-True ($tableFx -cnotmatch '\.Code\b|"Code"|Employer Code|EmployerCode1|Modified' -and $conflictFx -cnotmatch '\.Code\b|Employer Code|EmployerCode1|Modified') 'Verify and conflict ignore Contractor Code (EmployerCode1, flow MS-019) and Modified'
# Fixtures: a SharePoint row as returned after the save (typed blanks for empty fields), and the form inputs
$blankT = 'If(false,"x")'; $blankB = 'If(false,true)'
function Raw([string]$name, [string]$city, [string]$code, [string]$active, [string]$empty) {
    return "{ID:7,Title:$name,'Employer Code':$code,Street:$empty,'House Number':$empty,Postalcode:$empty,City:$city,Country:{Value:$empty},'Contact Name':$empty,'Contact Email':$empty,'Contact Phone':$empty,Active:$active,Modified:DateTime(2026,10,28,9,0,0)}"
}
function Inputs([string]$name, [string]$city, [string]$empty, [string]$active) {
    return "cmpEmpName:{Value:$name},cmpEmpStreet:{Value:$empty},cmpEmpHouseNumber:{Value:$empty},cmpEmpPostalcode:{Value:$empty},cmpEmpCity:{Value:$city},cmpEmpCountry:{Value:$empty},cmpEmpContactName:{Value:$empty},cmpEmpContactEmail:{Value:$empty},cmpEmpContactPhone:{Value:$empty},varEmpActiveDraft:$active"
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
$newSnap = '{ID:Blank(),Name:"",Code:"",Street:"",HouseNumber:"",Postalcode:"",City:"",Country:"",ContactName:"",ContactEmail:"",ContactPhone:"",Active:true}'
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
Assert-True (@($spReads | Where-Object Source -eq 'Employers').Count -eq 6 -and @($spReads | Where-Object Source -eq 'Workers').Count -eq 1) "SharePoint reads on scrContractors: 6 x Employers (load, pre-read, duplicate, verify, N1 control read Edit / New after a Patch error), 1 x Workers (load)"
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
foreach ($ctl in @('btnEmpSave', 'btnEmpNew', 'btnEmpRefresh', 'btnEmpDiscard', 'galEmpList')) { Assert-True ((Norm ((Get-Prop $ctl 'OnSelect') -replace ';\s*true\s*$', '')).EndsWith($blockedN)) "$ctl : the guard's else branch shows 'Blocked.' + action blocked as an error (no mutation; list handler ends with ; true for ReturnType Boolean)" }
Assert-True ($load.Contains((Triple 'Error' 'admHeadBlocked' (TT 'empMsgReloadBlocked')) + ',')) 'Loader: reload over unsaved input shows Blocked. + reload blocked (error) and does nothing else'
foreach ($k in @('btnEmpLoad.OnSelect', 'btnEmpSave.OnSelect', 'btnEmpActiveSwitch.OnSelect')) { foreach ($m in [regex]::Matches($all[$k], '\bTrace\(')) { Assert-True ((Get-Balanced $all[$k] ($m.Index + 5)) -notmatch 'varAdmMsg') "$k : no message variable inside a Trace" } }
# Texts (T): head words, unchanged message texts; the body no longer repeats the head word "Saved."
$fixTexts = [ordered]@{ empErrNameRequired = 'Fix: Contractor Name empty'; empErrEmail = 'Fix: Email invalid'; empErrPhone = 'Fix: Phone invalid'; empErrCountry = 'Fix: Country unknown'; empFieldStreet = 'Street'; empFieldHouseNumber = 'House Number'; empFieldPostalcode = 'Postal Code'; empFieldCity = 'City'; empFieldCountry = 'Country'; empFieldContactName = 'Name'; empFieldContactEmail = 'Email'; empFieldContactPhone = 'Phone'; empErrTooLong = 'Fix: {0} too long'; empErrDuplicate = 'Fix: Contractor Name already exists'
    admHeadNotSaved = 'Not saved.'; admHeadNotLoaded = 'Not loaded.'; admHeadBlocked = 'Blocked.'; admHeadAttention = 'Attention.'; admHeadSaved = 'Saved.'; admHeadLoaded = 'Loaded.'; admHeadDiscarded = 'Discarded.'; admMsgClose = 'Close message'
    empMsgSavedRename = 'The new name also shows on past hours.' }
foreach ($k in $fixTexts.Keys) { Assert-True ($formulas.Contains("$($k): {en: ""$($fixTexts[$k])"", nl: """"}")) "T.$k = '$($fixTexts[$k])'" }
Assert-True ($formulas -notmatch '\bempMsgSaved:' -and $formulas -notmatch 'en: "(Saved|Not saved)\.\s') 'T.empMsgSaved removed; no body text starts with the head word "Saved." / "Not saved."'
$conflictMsg = 'Changed in SharePoint by someone else. Nothing saved. Click Discard, then Refresh.'
Assert-True ($formulas.Contains("empErrConflict: {en: ""$conflictMsg"", nl: """"}")) 'T.empErrConflict exact text'
# Keys delivered by powerfx-logic for the form header that powerfx-ui builds next (30-10-2026); remove a key from this list once the header uses it.
$pendingUiT = @()  # all header keys are used now (empNoSelection 3a, prjNoSelection 3b)
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
$cmpBarExp = [ordered]@{ X = '=cmpEmpTitle.X'; Y = '=cmpEmpTitle.Y+cmpEmpTitle.Height'; Width = '=cmpEmpTitle.Width'; Height = '=If(IsBlank(varAdmMsgKind),0,40)'; Kind = '=varAdmMsgKind'; Head = '=varAdmMsgHead'; Body = '=varAdmMsgBody'; CloseLabel = ('=' + (TT 'admMsgClose')) }
foreach ($k in $cmpBarExp.Keys) { Assert-True ([string]$mbi['Properties'][$k] -ceq $cmpBarExp[$k]) "cmpEmpMsgBar.$k = $($cmpBarExp[$k])" }
$kids3 = @($doc['Screens'][$screenName]['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True ($kids3[0] -eq 'cmpEmpTitle' -and $kids3[1] -eq 'cmpEmpMsgBar') 'Children: cmpEmpTitle, then cmpEmpMsgBar directly under it'
$mbDef = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'Components/cmpMessageBar.pa.yaml')))['ComponentDefinitions']['cmpMessageBar']
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
$barHFx = ([string]$mbi['Properties']['Height']).TrimStart('=')
foreach ($case in @(@('"Error"', 40), @('"Warning"', 40), @('"Success"', 40), @('""', 0), @('If(false,"x")', 0))) { Assert-Eval "With({varAdmMsgKind:$($case[0])},$barHFx)" $case[1] "cmpEmpMsgBar instance Height for kind $($case[0]) = $($case[1]) (host variable, not the own BarHeight output)" }
$kindSets = @([regex]::Matches($srcAll, 'Set\(varAdmMsgKind,("[^"]*")\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True (@($kindSets | Where-Object { $_ -notin @('""', '"Error"', '"Warning"', '"Success"') }).Count -eq 0) "varAdmMsgKind is only set to empty, Error, Warning or Success, so Height If(IsBlank(kind),0,40) equals the component BarHeight ($($kindSets -join ','))"
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
Assert-True ((Get-Prop 'btnEmpShowInactiveSwitch' 'OnSelect') -ceq ('=If(' + $lcEn.Substring(1) + ',Set(varEmpShowInactive,!Coalesce(varEmpShowInactive,false))); true') -and (Get-Prop 'cmpEmpList' 'ShowInactive') -ceq '=Coalesce(varEmpShowInactive,false)') 'Show inactive switch (cmpListCard): OnToggleShowInactive = guard, then flip the local filter variable; the component never flips the state itself'
$siSets = @($all.Keys | Where-Object { $all[$_] -match 'Set\(varEmpShowInactive,' } | Sort-Object)
Assert-True (($siSets -join ',') -ceq 'btnEmpShowInactiveSwitch.OnSelect,scrContractors.OnVisible') "varEmpShowInactive set only by its switch and the OnVisible init ($($siSets -join ', '))"
$items = (Get-Prop 'galEmpList' 'Items').TrimStart('=')
Assert-True ($items -notmatch 'varEmpShowInactive' -and $items -notmatch 'SearchKey' -and $items -notmatch 'cmpEmpList\.' -and $items -notmatch 'txtEmpSearch' -and $items.EndsWith('Inactive:!r.Active,ChipText:If(r.Active,"",If(LangNl && !IsBlank(T.empInactive.nl),T.empInactive.nl,T.empInactive.en))})')) 'List rows (Studio shape 02-11-2026): host passes all rows sorted with Inactive = !Active, no Show inactive filter and no SearchKey; the component filters (Show inactive, search); the host never reads cmpEmpList.SearchText/Items back in Items'
$itemFix = 'colAdminEmployers:Table({ID:1,Name:"A",Code:"",City:"",Active:true},{ID:2,Name:"B",Code:"",City:"",Active:false},{ID:3,Name:"C",Code:"",City:"",Active:If(false,true)}),cmpEmpList:{SearchText:""},LangNl:false,T:' + $tRec
foreach ($c in @('false', 'true', 'If(false,true)')) { Assert-Eval "With({$itemFix,varEmpShowInactive:$c},CountRows($items))" 3 "List rows with varEmpShowInactive = ${c}: all 3 rows (the component hides inactive rows)" }
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
    $a = $g + 38 + [Math]::Ceiling(2 / $c) * 74; $k = $a + 38 + [Math]::Ceiling(5 / $c) * 74; $row = $k + 38 + [Math]::Ceiling(3 / $c) * 74
    $modWide = $cw -ge 480; $modY = if ($modWide) { $row } else { $row + 32 }
    return @{ Cols = $c; ColW = $colW; CW = $cw; Gen = $g; Addr = $a; Cont = $k; Row = $row; ModWide = $modWide; ModY = $modY; MetY = $modY + 24 + 24 }
}
# Geometry (admin pattern, 30-10-2026): two white cards on #F5F6F8, 24 px margin/gap/padding; wide (>=1000): list card 360 left, form card right, tops equal; narrow: stacked.
# The carriers' formulas are pinned by exact text, then mirrored here for each width.
$expLay = @{ X='=If(Parent.Width>=1000,1,0)'; Y='=If(Self.X=1,408,24)'; Width='=If(Self.X=1,Max(0,Parent.Width-448),Parent.Width-64)'; Height='=If(Self.X=1,24,500)' }
foreach ($k in $expLay.Keys) { Assert-True ((Get-Prop 'lblEmpLayout' $k) -eq $expLay[$k]) "Layout carrier lblEmpLayout.$k formula as mirrored" }
Assert-True ((Get-Prop 'lblEmpMetrics' 'Width') -eq '=If(lblEmpLayout.X=1,Self.Height-48,452)' -and (Get-Prop 'lblEmpMetrics' 'Height') -eq '=If(lblEmpLayout.X=1,Max(conEmpBody.Height,Self.Y+48,568),lblEmpLayout.Height+Self.Y+24)') 'Layout carrier lblEmpMetrics Width/Height formulas as mirrored (X = columns, Y = content height: see grid tests)'
$li = $idx['cmpEmpList']
Assert-True ($li['Control'] -eq 'CanvasComponent' -and $li['ComponentName'] -eq 'cmpListCard') 'List card = cmpListCard instance (replaces conEmpListCard, search, count, Show inactive switch and gallery)'
foreach ($card in @(@('cmpEmpList', 'X', '=24'), @('cmpEmpList', 'Y', '=24'), @('cmpEmpList', 'Width', '=If(lblEmpLayout.X=1,360,Parent.Width-64)'), @('cmpEmpList', 'Height', '=lblEmpMetrics.Width'),
        @('cmpEmpList', 'SelectedID', '=Coalesce(varEmpSelectedID,0)'), @('cmpEmpList', 'ShowInactive', '=Coalesce(varEmpShowInactive,false)'),
        @('cmpEmpList', 'SearchHint', ('=' + (TT 'empSearchHint'))), @('cmpEmpList', 'ShowInactiveLabel', ('=' + (TT 'empShowInactive'))), @('cmpEmpList', 'OnText', ('=' + (TT 'admOn'))), @('cmpEmpList', 'OffText', ('=' + (TT 'admOff'))),
        @('cmpEmpList', 'CountFormat', ('=' + (TT 'empCount'))),
        @('conEmpFormCard', 'Fill', '=Color.White'), @('conEmpFormCard', 'DropShadow', '=DropShadow.Light'), @('conEmpFormCard', 'RadiusTopLeft', '=8'), @('conEmpFormCard', 'X', '=lblEmpLayout.Y'), @('conEmpFormCard', 'Y', '=lblEmpLayout.Height'), @('conEmpFormCard', 'Width', '=lblEmpLayout.Width'), @('conEmpFormCard', 'Height', '=If(lblEmpLayout.X=1,lblEmpMetrics.Height-48,lblEmpMetrics.Y)'))) {
    Assert-True ((Get-Prop $card[0] $card[1]) -ceq $card[2]) "$($card[0]).$($card[1]) = $($card[2])"
}
Assert-True ($srcAll -match 'empSearchHint: \{en: "Search name, code or city"' -and $srcAll -match 'empCount: \{en: "\{0\} contractors"') 'T: search hint "Search name, code or city", count "{0} contractors"'
$canvKids = @($idx['conEmpCanvas']['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($canvKids -join ',') -ceq 'cmpEmpList,conEmpFormCard') 'conEmpCanvas holds exactly the list card instance and the form card (debug line removed)'
# cmpListCard internals that fix the list geometry (white card, radius 8, shadow, search 24/36, info row 24, gallery rows 64)
$lcDef = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'Components/cmpListCard.pa.yaml')))['ComponentDefinitions']['cmpListCard']
$lci = @{}; Index-Controls $lcDef['Children'] $lci
function GetLcProp([string]$c, [string]$p) { return ([string]$lci[$c]['Properties'][$p]).Trim() }
Assert-True (((GetLcProp 'conCmpListCard' 'Fill') -ceq '=Color.White') -and ((GetLcProp 'conCmpListCard' 'DropShadow') -ceq '=DropShadow.Light') -and ((GetLcProp 'conCmpListCard' 'RadiusTopLeft') -ceq '=8') -and ((GetLcProp 'conCmpListCard' 'Height') -ceq '=Parent.Height')) 'cmpListCard: white card, DropShadow.Light, radius 8, full component height'
$lcKids = @($lci['conCmpListCard']['Children'] | ForEach-Object { @($_.Keys)[0] })
Assert-True (($lcKids -join ',') -ceq 'txtSearch,icoCmpListSearch,htmlCmpListInfo,btnCmpListSwitch,btnCmpListKnob,galRows') "cmpListCard children: $($lcKids -join ',')"
$sY = [int](GetLcProp 'txtSearch' 'Y').TrimStart('='); $sH = [int](GetLcProp 'txtSearch' 'Height').TrimStart('='); $cH = [int](GetLcProp 'htmlCmpListInfo' 'Height').TrimStart('=')
Assert-True (($sY -eq 24) -and ($sH -eq 36) -and ((GetLcProp 'txtSearch' 'Width') -eq '=Parent.Width-48') -and ((GetLcProp 'txtSearch' 'PaddingLeft') -eq '=40') -and ((GetLcProp 'txtSearch' 'RadiusTopLeft') -eq '=4') -and ((GetLcProp 'txtSearch' 'Fill') -eq '=Color.White')) 'Search field (cmpListCard): white, radius 4, h36 at Y 24, PaddingLeft 40 (room for the magnifier)'
Assert-True (((GetLcProp 'icoCmpListSearch' 'Icon') -eq '=Icon.Search') -and ($lci['icoCmpListSearch']['Control'] -eq 'Classic/Icon@2.5.0') -and ((GetLcProp 'icoCmpListSearch' 'X') -eq '=txtSearch.X+12') -and ((GetLcProp 'icoCmpListSearch' 'Width') -eq '=18')) 'Magnifier = Classic/Icon Icon.Search inside the search field (X+12, 18 wide)'
Assert-True (((GetLcProp 'htmlCmpListInfo' 'Y') -eq '=txtSearch.Y+txtSearch.Height+12') -and ($cH -eq 26) -and ((GetLcProp 'btnCmpListSwitch' 'Y') -eq '=htmlCmpListInfo.Y+1') -and ((GetLcProp 'btnCmpListSwitch' 'X') -eq '=Parent.Width-24-Self.Width') -and ((GetLcProp 'htmlCmpListInfo' 'X') -eq '=24')) 'One info row under the search (item 1): count left, Show inactive text + switch right on the same line (one HtmlViewer row, switch at the same Y)'
Assert-True (((GetLcProp 'galRows' 'Y') -eq '=htmlCmpListInfo.Y+htmlCmpListInfo.Height+12') -and ((GetLcProp 'galRows' 'X') -eq '=0') -and ((GetLcProp 'galRows' 'Width') -eq '=Parent.Width') -and ((GetLcProp 'galRows' 'Height') -eq '=Max(0,Parent.Height-Self.Y-12)') -and ((GetLcProp 'galRows' 'TemplateSize') -eq '=64')) 'Gallery below the info row, full card width, fixed row height 64'
$rowT = GetLcProp 'htmlCmpRowTitle' 'HtmlText'; $rowS = GetLcProp 'htmlCmpRowSub' 'HtmlText'
Assert-True ((($rowT -match 'white-space:nowrap') -and ($rowT -match 'text-overflow:ellipsis') -and ($rowS -match 'white-space:nowrap') -and ($rowS -match 'text-overflow:ellipsis')) -and ((GetLcProp 'htmlCmpRowTitle' 'Height') -eq '=24') -and ((GetLcProp 'htmlCmpRowSub' 'Height') -eq '=20') -and ((GetLcProp 'htmlCmpRowSub' 'Y') -eq '=34')) 'List row (item 6): name on line 1 and subtitle on line 2, each one line with ellipsis, fixed positions in the 64 px row'
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
Assert-True ((Get-Prop 'lblEmpSecGeneral' 'Y') -eq '=lblEmpFormDivider.Y+1+20' -and (Get-Prop 'lblEmpSecAddress' 'Y') -eq '=lblEmpSecGeneral.Y+38+RoundUp(2/lblEmpMetrics.X,0)*74' -and (Get-Prop 'lblEmpSecContact' 'Y') -eq '=lblEmpSecAddress.Y+38+RoundUp(5/lblEmpMetrics.X,0)*74' -and (Get-Prop 'btnEmpActiveSwitch' 'Y') -eq '=lblEmpSecContact.Y+38+RoundUp(3/lblEmpMetrics.X,0)*74') 'Section tops: previous top + 38 + rows*74 (label 18 + 4 + field 36 + 16 row gap; header 18 + 12; 24 between sections); bottom row below CONTACT'
$grid = @{ GENERAL = @('Name', 'Code'); ADDRESS = @('Street', 'HouseNumber', 'Postalcode', 'City', 'Country'); CONTACT = @('ContactName', 'ContactEmail', 'ContactPhone') }
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
$chipFill = 'If(Coalesce(varEmpMode,"")="New",ColorValue("#D5EDFF"),Coalesce(varEmpEdit.Active,true),ColorValue("#1AFF80"),ColorValue("#E6E6E6"))'; $chipCol = 'If(Coalesce(varEmpMode,"")="New",ColorValue("#0303B8"),Coalesce(varEmpEdit.Active,true),ColorValue("#000F41"),ColorValue("#000000"))'
# 03-11-2026 (Eddy, TP-HOME-02 point 8): in New mode the chip shows "New" (T.admChipNew) in light blue #D5EDFF with #0303B8 text; grey stays reserved for Inactive
$empChipTx = (Get-Prop 'btnEmpFormChip' 'Text').TrimStart('=')
$chipColName = 'If(c=ColorValue("#E6E6E6"),"#E6E6E6",c=ColorValue("#1AFF80"),"#1AFF80",c=ColorValue("#000F41"),"#000F41",c=ColorValue("#000000"),"#000000",c=ColorValue("#D5EDFF"),"#D5EDFF",c=ColorValue("#0303B8"),"#0303B8","?")'
foreach ($c in @(@('"New"', 'true', 'New|#D5EDFF|#0303B8'), @('"New"', 'false', 'New|#D5EDFF|#0303B8'), @('"Edit"', 'true', 'Active|#1AFF80|#000F41'), @('"Edit"', 'false', 'Inactive|#E6E6E6|#000000'), @('"Edit"', 'If(false,true)', 'Active|#1AFF80|#000F41'))) {
    Assert-Eval "With({LangNl:false,T:$tRec,varEmpMode:$($c[0]),varEmpEdit:{Active:$($c[1])}},$empChipTx & ""|"" & With({c:$chipFill},$chipColName) & ""|"" & With({c:$chipCol},$chipColName))" $c[2] "btnEmpFormChip: Mode $($c[0]), saved Active $($c[1]) -> $($c[2])"
}
Assert-True ($formulas.Contains('admChipNew: {en: "New", nl: ""}')) 'T.admChipNew = New (shared admin chip text)'
Assert-True (($idx['btnEmpFormChip']['Control'] -eq 'Classic/Button@2.2.0') -and ((Get-Prop 'btnEmpFormChip' 'DisplayMode') -eq '=DisplayMode.Disabled') -and (-not $idx['btnEmpFormChip']['Properties'].ContainsKey('OnSelect')) -and ((Get-Prop 'btnEmpFormChip' 'Visible') -eq '=Coalesce(varEmpMode,"") in ["New","Edit"]')) 'Status chip btnEmpFormChip: hand-built Classic/Button, static (Disabled with identical disabled colours), no OnSelect, hidden when Mode is empty'
foreach ($p in 'Fill', 'HoverFill', 'PressedFill', 'DisabledFill') { Assert-True ((Get-Prop 'btnEmpFormChip' $p) -ceq "=$chipFill") "btnEmpFormChip.$p = green #1AFF80 when the SAVED status is Active (varEmpEdit.Active), grey #E6E6E6 when Inactive (not the switch draft)" }
foreach ($p in 'Color', 'HoverColor', 'PressedColor', 'DisabledColor') { Assert-True ((Get-Prop 'btnEmpFormChip' $p) -ceq "=$chipCol") "btnEmpFormChip.$p = #000F41 on green, #000000 on grey" }
Assert-True (((Get-Prop 'btnEmpFormChip' 'Text').Contains('T.empFieldActive')) -and ((Get-Prop 'btnEmpFormChip' 'Text').Contains('T.empInactive')) -and ((Get-Prop 'btnEmpFormChip' 'Text') -notmatch 'varEmpActiveDraft') -and ((Get-Prop 'btnEmpFormChip' 'X') -eq '=Parent.Width-24-Self.Width') -and ((Get-Prop 'btnEmpFormChip' 'Height') -eq '=24') -and ((Get-Prop 'btnEmpFormChip' 'RadiusTopLeft') -eq '=12') -and ((Get-Prop 'btnEmpFormChip' 'Size') -eq '=12')) 'Chip text is the saved state (not colour only), right-aligned on the card padding (24), h24, radius 12'
Assert-True (((Get-Prop 'lblEmpFormTitle' 'Width') -eq '=Max(0,Parent.Width-48-84)') -and ((Get-Prop 'lblEmpFormTitle' 'X') -eq '=24')) 'Header title leaves room for the chip (72 + 12) and never overlaps it'
Assert-True (((Get-Prop 'lblEmpFormDivider' 'Fill') -eq '=ColorValue("#EDEDED")') -and ((Get-Prop 'lblEmpFormDivider' 'Height') -eq '=1') -and ((Get-Prop 'lblEmpFormDivider' 'Width') -eq '=lblEmpLayout.Width-48') -and ((Get-Prop 'lblEmpFormDivider' 'Y') -eq '=lblEmpFormTitle.Y+lblEmpFormTitle.Height+16')) 'Divider: 1 px #EDEDED under the header, full content width'
$formKids = @($idx['conEmpFormCard']['Children'] | ForEach-Object { @($_.Keys)[0] })
$expKids = 'lblEmpFormTitle,btnEmpFormChip,lblEmpFormDivider,lblEmpSecGeneral,cmpEmpName,cmpEmpCode,lblEmpSecAddress,cmpEmpStreet,cmpEmpHouseNumber,cmpEmpPostalcode,cmpEmpCity,cmpEmpCountry,lblEmpSecContact,cmpEmpContactName,cmpEmpContactEmail,cmpEmpContactPhone,btnEmpActiveSwitch,btnEmpActiveKnob,lblEmpActiveState,lblEmpModified'
Assert-True (($formKids -join ',') -ceq $expKids) "conEmpFormCard children (final structure): $($formKids -join ',')"
# numeric mirror of the grid
foreach ($W in 320, 768, 900, 1000, 1280, 1366, 1920) {
    $wide = $W -ge 1000; $layW = if ($wide) { [Math]::Max(0, $W - 432) } else { $W - 48 }
    if ($layW -lt 100) { continue }
    $g = Get-FormGeom $layW
    if ($g.Cols -ge 2) { Assert-True ($g.ColW -ge 180) "W=$W (card $layW): $($g.Cols) columns of $([Math]::Round($g.ColW,1)) px (>= 180)" }
    Assert-True ($g.Cols * $g.ColW + 16 * ($g.Cols - 1) -eq $g.CW) "W=$W : columns + 16 px gaps fill the content width exactly (inside the 24 px padding)"
    $secStep = 18 + 12
    foreach ($pair in @(@('GENERAL', $g.Gen, 2, $g.Addr), @('ADDRESS', $g.Addr, 5, $g.Cont), @('CONTACT', $g.Cont, 3, $g.Row))) {
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
$tbDef = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'Components/cmpTitleBar.pa.yaml')))['ComponentDefinitions']['cmpTitleBar']
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
# TP-HOME-03 item 8b (Eddy, 4-11-2026): New clicked by mistake. Discard is also enabled in New mode (clean form); the admission check
# in DiscardEnabled = the first If-condition of OnDiscard. OnNew remembers the record selected before New (Edit with a selection;
# New -> New keeps the remembered one; else Blank). OnDiscard in New mode (not after a failed save) selects that record again when it is
# still in the loaded list AND visible in the list card (Show inactive / Show closed, search), else the first visible row - the same
# filtered Items text as the loader auto-select - and fills varPSelectedID/varPEdit/Mode with the loader's own branch; empty visible list
# or a load that is not Loaded (or has load errors) = no selection (Mode ""). Local only: no Patch/Refresh/Remove/Collect/Select.
# The loader clears var<P>PrevSelectedID at the start of every real load (Refresh, Discard after a failed save), so no stale ID survives.
function Test-DiscardNew([string]$p, [string]$scr, [string]$guard, [string]$dirtyFx, [string]$onDiscard, [string]$onNew, [string]$load, [string]$itemsFx, [string]$col, [string]$emptySnap, [string]$colFix, $cases, $map, [string]$firstField = 'Name') {
    $prev = "var${p}PrevSelectedID"
    $expGuard = "!Coalesce(var${p}Busy,false) && !Coalesce(var${p}Saving,false) && (Coalesce(var${p}SaveFailed,false) || var${p}Mode=`"New`" || $dirtyFx)"
    Assert-True ($guard -ceq $expGuard) "$scr 8b: DiscardEnabled = not busy/saving and (SaveFailed or Mode New or dirty)"
    Assert-True ($onDiscard.StartsWith('=If(' + $expGuard + ',')) "$scr 8b: OnDiscard starts with the identical admission check (fail-closed parity)"
    # OnNew stores the previous selection before switching to New
    $newSet = "Set($prev,If(var${p}Mode=`"Edit`" && !IsBlank(var${p}SelectedID),var${p}SelectedID,var${p}Mode=`"New`",$prev,Blank()));"
    $iNewSet = $onNew.IndexOf($newSet); $iMode = $onNew.IndexOf("Set(var${p}Mode,`"New`")")
    Assert-True ($iNewSet -gt 0 -and $iMode -gt $iNewSet -and ([regex]::Matches($onNew, [regex]::Escape("Set($prev,"))).Count -eq 1) "$scr 8b: OnNew stores the previous selection ($newSet) before Mode New"
    $newArg = $newSet.Substring($prev.Length + 5, $newSet.Length - $prev.Length - 7)
    foreach ($c in @(@('"Edit"', '5', 'If(false,0)', '5', 'Edit with a selection -> remembered'), @('"Edit"', 'If(false,0)', '3', 'blank', 'Edit without a selection -> Blank'), @('"New"', 'If(false,0)', '3', '3', 'New again -> keeps the remembered record'), @('""', 'If(false,0)', '3', 'blank', 'no record in the form -> Blank'))) {
        Assert-Eval "With({var${p}Mode:$($c[0]),var${p}SelectedID:$($c[1]),${prev}:$($c[2])},With({x:$newArg},If(IsBlank(x),`"blank`",Text(x))))" $c[3] "$scr 8b: OnNew remembers: $($c[4])"
    }
    # The loader clears the remembered ID at the start of every real load; only OnNew, OnDiscard and the loader set it
    Assert-True ($load.Contains("Set(var${p}Busy,true); Set(var${p}LoadState,`"Loading`"); Set(var${p}DiagT0,Now()); Set($prev,Blank());")) "$scr 8b: every real load (Refresh, Discard after a failed save) clears $prev"
    $setters = @(@($map.Keys) | Where-Object { ([string]$map[$_]) -match "Set\($prev," } | Sort-Object)
    Assert-True (($setters -join ',') -ceq "btn${p}Discard.OnSelect,btn${p}Load.OnSelect,btn${p}New.OnSelect") "$scr 8b: $prev is set only by New, Discard and the loader ($($setters -join ', '))"
    # OnDiscard: failed save first (forced reload, unchanged), then the New branch
    $dN = Norm $onDiscard
    $head = "Clear(col${p}SaveErrors);If(Coalesce(var${p}SaveFailed,false),Set(var${p}ForceRefresh,true);Select(btn${p}Load),If(var${p}Mode=`"New`","
    $iHead = $dN.IndexOf((Norm $head))
    Assert-True ($iHead -gt 0) "$scr 8b: OnDiscard keeps the forced reload after a failed save and only then takes the New branch"
    $iBr = $onDiscard.IndexOf("If(var${p}Mode=`"New`",")
    $branch = Get-Balanced $onDiscard ($iBr + 2)
    Assert-True ($branch -notmatch '\b(Patch|Refresh|Remove|RemoveIf|Collect|ClearCollect|Select|SubmitForm|UpdateIf|Navigate)\(') "$scr 8b: Discard New branch is local (no Patch/Refresh/Remove/Collect/Select/Navigate)"
    $selAt = $branch.IndexOf("Set(var${p}SelectedID,If(var${p}LoadState=`"Loaded`" && IsEmpty(col${p}LoadErrors),")
    Assert-True ($selAt -gt 0) "$scr 8b: Discard New branch picks the row only on a Loaded list without load errors"
    $selSet = Get-Balanced $branch ($selAt + 3); $selArg = $selSet.Substring("var${p}SelectedID,".Length + 1, $selSet.Length - "var${p}SelectedID,".Length - 2)
    Assert-True ($selArg.Contains("With({vis:$itemsFx},If(!IsBlank($prev) && !IsBlank(LookUp(vis,ID=$prev).ID),$prev,First(vis).ID))")) "$scr 8b: previous-or-first uses the loader auto-select's visible list text (host Items + list card predicate)"
    $fill = "If(!IsBlank(var${p}SelectedID) && !IsBlank(LookUp($col,ID=var${p}SelectedID).ID),Set(var${p}Edit,LookUp($col,ID=var${p}SelectedID)); Set(var${p}Mode,`"Edit`"),Set(var${p}Mode,`"`"); Set(var${p}SelectedID,Blank()); Set(var${p}Edit,$emptySnap))"
    $bN = Norm $branch
    Assert-True ($bN.Contains((Norm ($selSet + ';' + $fill + ";Set($prev,Blank());"))) -and (Norm $load).Contains((Norm $fill))) "$scr 8b: Discard New branch fills the form with the loader's own auto-select branch (same text), then clears $prev"
    $after = $dN.Substring($dN.IndexOf((Norm $branch)) + (Norm $branch).Length)
    Assert-True ($after.StartsWith(';Reset(cmp' + $p + $firstField + ');') -and $after.Contains('Set(varAdmMsgKind,"Success");')) "$scr 8b: after the New branch the form components are reset and the Discarded message is shown (shared with Edit-mode Discard)"
    foreach ($c in $cases) {
        $fx = "With({$colFix,LangNl:false,T:$tRec,var${p}ShowInactive:$($c[0]),cmp${p}List:{SearchText:$($c[1])},${prev}:$($c[2]),var${p}LoadState:$($c[3]),col${p}LoadErrors:$($c[4])},With({x:$selArg},If(IsBlank(x),`"blank`",Text(x))))"
        Assert-Eval $fx $c[5] "$scr 8b: Discard in New mode: $($c[6]) -> $($c[5])"
    }
}
# Item d: "nothing written" (SharePoint refused: Patch error AND no record with ID) -> Not saved., state stays Loaded, input kept,
# retry possible; a returned ID with an error, no ID without an error (uncertain), an ID mismatch or a verify read/mismatch
# after a successful Patch -> Failed + SaveFailed (locked, Refresh = Discard).
function Test-WriteCounter([string]$save, [string]$p, [string]$list, [string]$scr) {
    $sN = Norm $save
    # 03-11-2026 (reviewer N1): a Patch error without a returned record counts as zero writes ONLY when a control read proves that
    # nothing was written (Edit: same row, Modified unchanged since the pre-read; New: no row with the duplicate key that was not in
    # the pre-save duplicate read). Control read failed / 500+ rows / possible write -> counted as a write (Failed, fail-closed).
    $wFx = "If(var${p}PatchError && IsBlank(var${p}PatchedID) && var${p}SaveCtl=`"NoWrite`",0,1)"
    $ctlSet = "Set(var${p}SaveCtl,If(var${p}PatchError && IsBlank(var${p}PatchedID),`"Pending`",`"`"));"
    $iCtl = $sN.IndexOf((Norm $ctlSet)); $iCtlRef = $sN.IndexOf((Norm "If(var${p}SaveCtl=`"Pending`",IfError(Refresh($list),Set(var${p}SaveCtl,`"ReadFailed`");false));"))
    $iCtlE = $sN.IndexOf((Norm "If(var${p}SaveCtl=`"Pending`" && var${p}SaveMode=`"Edit`",Set(var${p}SaveReads,var${p}SaveReads+1); IfError(CountRows(ClearCollect(col${p}CtlRaw,Filter($list,ID=var${p}SaveID)))>=0,Set(var${p}SaveCtl,`"ReadFailed`");false));"))
    $iCtlN = $sN.IndexOf((Norm "If(var${p}SaveCtl=`"Pending`" && var${p}SaveMode=`"New`",Set(var${p}SaveReads,var${p}SaveReads+1); IfError(CountRows(ClearCollect(col${p}CtlRaw,Filter($list,"))
    $decHead = Norm "If(var${p}SaveCtl=`"Pending`",Set(var${p}SaveCtl,If(CountRows(col${p}CtlRaw)>=500,`"ReadFailed`","
    $iDec = $sN.IndexOf($decHead)
    Assert-True ($iCtl -gt 0 -and $iCtlRef -gt $iCtl -and $iCtlE -gt $iCtlRef -and $iCtlN -gt $iCtlE -and $iDec -gt $iCtlN -and $sN.Contains('Clear(col' + $p + 'CtlRaw);') -and $sN.Contains("Set(var${p}SaveCtl,`"`");")) "$scr N1: control read only after a Patch error without record: Refresh($list), read by ID (Edit) or by the duplicate key (New), 500 guard, then decision; reset at the start of every save"
    $decFx = Get-Balanced $save ($save.IndexOf("Set(var${p}SaveCtl,If(CountRows(col${p}CtlRaw)>=500,") + 3); $decFx = $decFx.Substring("(var${p}SaveCtl,".Length, $decFx.Length - "(var${p}SaveCtl,".Length - 1)
    $pre = "col${p}PreRaw:Table({ID:7,Modified:DateTime(2026,11,3,9,0,0)}),col${p}Dup:Table({ID:3})"
    foreach ($c in @(@('"Edit"', 'Table({ID:7,Modified:DateTime(2026,11,3,9,0,0)})', 'NoWrite', 'Edit, Modified unchanged'),
                    @('"Edit"', 'Table({ID:7,Modified:DateTime(2026,11,3,9,0,5)})', 'PossibleWrite', 'Edit, Modified changed'),
                    @('"Edit"', 'Filter(Table({ID:7,Modified:DateTime(2026,11,3,9,0,0)}),false)', 'PossibleWrite', 'Edit, row not found'),
                    @('"New"', 'Filter(Table({ID:7,Modified:DateTime(2026,11,3,9,0,0)}),false)', 'NoWrite', 'New, no row with the key'),
                    @('"New"', 'Table({ID:3,Modified:DateTime(2026,11,3,9,0,0)})', 'NoWrite', 'New, only the row known before the save'),
                    @('"New"', 'Table({ID:3,Modified:DateTime(2026,11,3,9,0,0)},{ID:12,Modified:DateTime(2026,11,3,9,0,9)})', 'PossibleWrite', 'New, a new row with the key'),
                    @('"New"', 'ForAll(Sequence(500),{ID:Value+100,Modified:DateTime(2026,11,3,9,0,0)})', 'ReadFailed', 'New, 500+ rows'))) {
        Assert-Eval "With({$pre,var${p}SaveMode:$($c[0]),col${p}CtlRaw:$($c[1])},$decFx)" $c[2] "$scr N1: control read decision: $($c[3]) -> $($c[2])"
    }
    $iInit = $sN.IndexOf("Set(var${p}SaveWrites,0);"); $iF0 = $sN.IndexOf((Norm "Set(var${p}PatchError,false);IfError(CountRows(ClearCollect(col${p}Patched,"))
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
    foreach ($c in @(@('true', 'If(false,0)', $err, 'false', 'Loaded', 'Patch error without a returned record, control read proves nothing written', '"NoWrite"'),
                    @('true', 'If(false,0)', $err, 'false', 'Failed', 'Patch error without a returned record, control read shows a possible write', '"PossibleWrite"'),
                    @('true', 'If(false,0)', $err, 'false', 'Failed', 'Patch error without a returned record, control read failed (unknown)', '"ReadFailed"'),
                    @('true', 'If(false,0)', $err, 'false', 'Failed', 'Patch error without a returned record, control read never decided', '"Pending"'),
                    @('true', '7', $err, 'false', 'Failed', 'Patch error but a record with ID returned: possibly written', '""'),
                    @('false', 'If(false,0)', $err, 'false', 'Failed', 'no error and no record (uncertain): counted as a write', '""'),
                    @('false', '7', $err, 'false', 'Failed', 'Patch returned ID 7, then verify read error or mismatch', '""'),
                    @('false', '7', $none, 'true', 'Saved', 'Patch ID 7 and verify OK', '""'))) {
        Assert-Eval "With({var${p}PatchError:$($c[0]),var${p}PatchedID:$($c[1]),var${p}SaveCtl:$($c[6])},With({var${p}SaveWrites:$wFx},With({col${p}SaveErrors:$($c[2]),var${p}SaveVerified:$($c[3])},$out)))" $c[4] "$scr : $($c[5]) -> $($c[4])"
    }
    foreach ($c in @(@('true', 'If(false,0)', 'Pending'), @('true', '7', ''), @('false', 'If(false,0)', ''))) { Assert-Eval "With({var${p}PatchError:$($c[0]),var${p}PatchedID:$($c[1])},If(var${p}PatchError && IsBlank(var${p}PatchedID),`"Pending`",`"`"))" $c[2] "$scr N1: control read state after the Patch (error $($c[0]), ID $($c[1])) = '$($c[2])' (only an error without record is checked)" }
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
$empSorted = 'Sort' + (Get-Balanced $empItemsAll ($empItemsAll.IndexOf('Sort(ForAll(') + 4))
Assert-True ($empItemsAll.StartsWith('ForAll(' + $empSorted + ' As r,{ID:r.ID,Title:r.Name,Subtitle:')) 'cmpListCard Items = all rows sorted, projected to ID, Title, Subtitle, Inactive, ChipText (no host filter)'
$lcGal = ([string]$lci['galRows']['Properties']['Items']).Trim()
Assert-True ($lcGal.StartsWith('=Filter(cmpListCard.Items,') -and $lcGal.EndsWith(')')) 'cmpListCard gallery = Filter(Items, <Show inactive and search predicate>)'
$lcPredC = $lcGal.Substring('=Filter(cmpListCard.Items,'.Length, $lcGal.Length - '=Filter(cmpListCard.Items,'.Length - 1)
$empPred = $lcPredC.Replace('txtSearch.Text', 'cmpEmpList.SearchText').Replace('cmpListCard.ShowInactive', 'Coalesce(varEmpShowInactive,false)')
# the loader auto-select = the first row the list card shows: host Items, then the component's own predicate (Show inactive = varEmpShowInactive, search on its SearchText)
$empItems = 'Filter(' + $empItemsAll + ',' + $empPred + ')'
$empEmpty = '{ID:Blank(),Name:"",Code:"",Street:"",HouseNumber:"",Postalcode:"",City:"",Country:"",ContactName:"",ContactEmail:"",ContactPhone:"",Active:true}'
Test-AutoSelect $load $empItems $null (Get-Prop 'galEmpList' 'OnSelect') 'Emp' 'colAdminEmployers' $empEmpty $dirty 'Contractors'
Assert-True ((Get-Prop 'cmpEmpList' 'SelectedID') -ceq '=Coalesce(varEmpSelectedID,0)') 'Contractors auto-select: the selected ID goes to cmpListCard.SelectedID (row highlight), Coalesce to 0 without selection'
$empSelFix = 'colAdminEmployers:Table({ID:1,Name:"Zeta",Code:"EMP-001",City:"Ede",Active:true},{ID:2,Name:"alpha",Code:"EMP-002",City:"",Active:false},{ID:3,Name:"Beta",Code:"",City:"Delft",Active:If(false,true)})'
foreach ($c in @(@('false', '""', '3', 'first active row by name (inactive alpha hidden; blank Active = active)'), @('true', '""', '2', 'Show inactive on: alpha first'), @('false', '" ZET "', '1', 'search filter applied'), @('false', '"emp-00"', '1', 'search on the code'), @('false', '"delft"', '3', 'search on the city'))) {
    Assert-Eval "With({$empSelFix,LangNl:false,T:$tRec,varEmpShowInactive:$($c[0]),cmpEmpList:{SearchText:$($c[1])}},Text(First($empItems).ID))" $c[2] "Contractors auto-select: $($c[3]) -> ID $($c[2])"
}
Assert-Eval "With({$empSelFix,LangNl:false,T:$tRec,varEmpShowInactive:false,cmpEmpList:{SearchText:`"nomatch`"}},IsBlank(First($empItems).ID))" $true 'Contractors auto-select: empty visible list -> no ID -> Mode "" (no selection)'
Assert-Eval "With({colAdminEmployers:Filter(Table({ID:1,Name:`"`",Code:`"`",City:`"`",Active:true}),false),LangNl:false,T:$tRec,varEmpShowInactive:false,cmpEmpList:{SearchText:`"`"}},IsBlank(First($empItems).ID))" $true 'Contractors auto-select: empty list -> no selection'
$noErr = 'Filter(Table({Message:""}),false)'
$empDiscCases = @(@('false', '""', '1', '"Loaded"', $noErr, '1', 'previous record visible -> restored'),
    @('false', '""', '2', '"Loaded"', $noErr, '3', 'previous record inactive, Show inactive off -> first visible row'),
    @('true', '""', '2', '"Loaded"', $noErr, '2', 'previous inactive record shown (Show inactive on) -> restored'),
    @('false', '""', '99', '"Loaded"', $noErr, '3', 'previous record no longer in the loaded list -> first visible row'),
    @('false', '""', 'If(false,0)', '"Loaded"', $noErr, '3', 'no previous record -> first visible row'),
    @('false', '"delft"', '1', '"Loaded"', $noErr, '3', 'previous record hidden by the search text -> first visible row'),
    @('false', '"nomatch"', '1', '"Loaded"', $noErr, 'blank', 'empty visible list -> no selection (Mode "")'),
    @('false', '""', '1', '"Failed"', $noErr, 'blank', 'load not Loaded -> no selection'),
    @('false', '""', '1', '"Loaded"', 'Table({Message:"x"})', 'blank', 'load errors present -> no selection'))
Test-DiscardNew 'Emp' 'Contractors' $guards.btnEmpDiscard $dirty (Get-Prop 'btnEmpDiscard' 'OnSelect') (Get-Prop 'btnEmpNew' 'OnSelect') $load $empItems 'colAdminEmployers' $empEmpty $empSelFix $empDiscCases $all
$cleanNew = $clean.Replace('varEmpMode:"Edit"', 'varEmpMode:"New"').Replace('varEmpSelectedID:5', 'varEmpSelectedID:Blank()').Replace('varEmpEdit:{ID:5,Name:"A"', 'varEmpEdit:{ID:Blank(),Name:""').Replace('cmpEmpName:{Value:"A"}', 'cmpEmpName:{Value:""}')
Assert-Eval (Get-GuardFx 'btnEmpSave' $cleanNew) $false 'Contractors 8b fixture: New form untouched is clean (Save blocked)'
Assert-Eval (Get-GuardFx 'btnEmpDiscard' $cleanNew) $true 'Contractors 8b: Discard allowed in New mode with a clean form'
Assert-Eval (Get-GuardFx 'btnEmpDiscard' $cleanNew.Replace('varEmpBusy:false', 'varEmpBusy:true')) $false 'Contractors 8b: Discard in New mode blocked while loading'
Assert-Eval (Get-GuardFx 'btnEmpDiscard' $cleanNew.Replace('varEmpSaving:false', 'varEmpSaving:true')) $false 'Contractors 8b: Discard in New mode blocked while saving'
Assert-Eval (Get-GuardFx 'btnEmpDiscard' $clean.Replace('varEmpMode:"Edit"', 'varEmpMode:""')) $false 'Contractors 8b: Discard stays disabled without a record in the form (clean)'
Test-WriteCounter $save 'Emp' 'Employers' 'Contractors'
Assert-Eval (Get-GuardFx 'btnEmpSave' $fix) $true 'Contractors: after a refused save (Loaded, SaveFailed false, input kept) Save is allowed again (retry)'
$empPatchErr = Get-Balanced $save ($save.IndexOf('Set(varEmpPatchError,true); Collect(colEmpSaveErrors,') + 'Set(varEmpPatchError,true); Collect'.Length)
$empPatchErrRec = (Split-Args $empPatchErr.Substring(1, $empPatchErr.Length - 2))[1].Replace('FirstError.Message', 'fe')
Assert-Eval "With({LangNl:false,T:$tRec,fe:`"Access denied.`"},$empPatchErrRec.Field & `"|`" & $empPatchErrRec.Message)" '|SharePoint error: Access denied.' 'Contractors: refused Patch -> red message with the SharePoint reason'
# Item f (statuschip = saved status): varEmpEdit.Active comes only from the loaded/verified rows or the New default
function Get-SetValues([string]$text, [string]$var) { return @([regex]::Matches($text, "Set\($var,") | ForEach-Object { $b = Get-Balanced $text ($_.Index + 3); $b.Substring($var.Length + 2, $b.Length - $var.Length - 3).Trim() } | Sort-Object -Unique) }
$empEditSets = Get-SetValues $screenText 'varEmpEdit'
Assert-True ($empEditSets.Count -ge 3 -and @($empEditSets | Where-Object { $_ -notmatch '^(LookUp\(colAdminEmployers,ID=varEmpSelectedID\)|First\(colEmpVerify\)|\{ID:Blank\(\),.*Active:true\})$' }).Count -eq 0) "Contractors: varEmpEdit (saved status source for the chip) only from the loaded list, the verify read or the empty/New snapshot ($($empEditSets -join ' | '))"
# (D) 01-11-2026 Studio FAIL A: dirty must be false right after a load (auto-selected row) and after every row selection or New.
# Each cmpField.Value is evaluated with the component's own Value formula on the state after its reset (text input
# Text = Value & ""; dropdown Selected = the as-is row of Value, blank = no selection). Proves the formulas, not Studio's reset timing.
$emptyQ = '""'  # Windows PowerShell 5.1 collapses a doubled quote inside $() in a double-quoted string
$cmpFieldDef = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'Components/cmpField.pa.yaml')))['ComponentDefinitions']['cmpField']
$cvFx = ([string]$cmpFieldDef['Properties']['Value']).TrimStart('=')
function CV-Rec([string]$valueFx, [string]$type) { return "{Value:With({cmpField:{InputType:`"$type`",DefaultValue:($valueFx) & `"`"},txtFieldValue:{Text:($valueFx) & `"`"},ddFieldValue:{Selected:If(IsBlank($valueFx),If(false,{Value:`"`"}),{Value:$valueFx})}},$cvFx)}" }
function Emp-Inputs([string]$cityOverride) {
    $parts = @(); foreach ($k in $inputMap.Keys) { $v = "varEmpEdit.$($inputMap[$k])"; if ($k -eq 'cmpEmpCity' -and $cityOverride -ne '') { $v = $cityOverride }; $ty = if ($k -eq 'cmpEmpCountry') { 'dropdown' } else { 'text' }; $parts += "${k}:$(CV-Rec $v $ty)" }
    return ($parts -join ',') + ',varEmpActiveDraft:Coalesce(varEmpEdit.Active,true)'
}
$lblDirtyFx = ([string]$idx['lblEmpDirty']['Properties']['Text']).Trim().TrimStart('=')
$rawRows = @((Raw '"Zeta"' '"Ede"' '"EMP-001"' 'true' '" Street 1 "').Replace('{ID:7,', '{ID:1,'), (Raw '"alpha"' $blankT $blankT 'false' $blankT).Replace('{ID:7,', '{ID:2,'), (Raw '" Beta "' '"Delft"' '""' $blankB '""').Replace('{ID:7,', '{ID:3,'))
$loadedCol = 'Table(' + (($rawRows | ForEach-Object { Proj $_ }) -join ',') + ')'
$loadEnv = "colAdminEmployers:$loadedCol,LangNl:false,T:$tRec,varEmpShowInactive:false,cmpEmpList:{SearchText:`"`"}"
Assert-Eval "With({$loadEnv},Text(First($empItems).ID))" '3' 'Dirty fixture: load auto-selects ID 3 (Beta; alpha inactive hidden)'
Assert-Eval "With({$loadEnv},With({varEmpMode:`"Edit`",varEmpEdit:LookUp(colAdminEmployers,ID=First($empItems).ID)},With({$(Emp-Inputs '')},$lblDirtyFx)))" 'false' 'Contractors: dirty false right after load (auto-selected row, inputs reset to the loaded values; blanks and spaces normalized by the loader)'
foreach ($id in 1, 2, 3) { Assert-Eval "With({$loadEnv},With({varEmpMode:`"Edit`",varEmpEdit:LookUp(colAdminEmployers,ID=$id)},With({$(Emp-Inputs '')},$lblDirtyFx)))" 'false' "Contractors: dirty false after selecting row $id" }
Assert-Eval "With({varEmpMode:`"New`",varEmpEdit:$empEmpty},With({$(Emp-Inputs '')},$lblDirtyFx))" 'false' 'Contractors: dirty false after New (empty snapshot, Active true)'
Assert-Eval "With({varEmpMode:`"Edit`",varEmpEdit:{ID:9,Name:`"N`",Code:$blankT,Street:$blankT,HouseNumber:$blankT,Postalcode:$blankT,City:$blankT,Country:$blankT,ContactName:$blankT,ContactEmail:$blankT,ContactPhone:$blankT,Active:$blankB}},With({$(Emp-Inputs '')},$lblDirtyFx))" 'false' 'Contractors: dirty false for a snapshot with Blank fields and Blank Active (blank = "" and = active)'
Assert-Eval "With({$loadEnv},With({varEmpMode:`"Edit`",varEmpEdit:LookUp(colAdminEmployers,ID=3)},With({$(Emp-Inputs $emptyQ)},$lblDirtyFx)))" 'true' 'Contractors: dirty true when an input still shows another value than the loaded one (what the Studio test showed)'
# Item 9 (04-11-2026, MS-024): ADDRESS = Street, House Number, Postal Code, City, Country (choice). Country choice safety like Projects N3:
# an UNCHANGED stored Country outside Choices([@Employers].Country) is not written (Patch shape without Country); a new or changed value
# must be in the list (error on field Country, T.empErrCountry); all decided in the local validation before the first read/write.
$eInC = 'CountIf(Choices([@Employers].Country),Value=varEmpSaveRec.Country)>0'
Assert-True ($save.Contains("Set(varEmpSaveCountryInList,$eInC);")) 'Contractors: in-list flag = CountIf(Choices([@Employers].Country),Value=<save value>)>0'
$iEFirstIO = $saveN.IndexOf('If(IsEmpty(colEmpSaveErrors),IfError(Refresh(Employers),')
$iEIn = $saveN.IndexOf((Norm "Set(varEmpSaveCountryInList,$eInC);")); $iEWc = $saveN.IndexOf('Set(varEmpSaveWriteCountry,'); $iECo = $saveN.IndexOf('If(!IsBlank(varEmpSaveRec.Country)&&!varEmpSaveCountryInList')
Assert-True ($iEIn -gt 0 -and $iEWc -gt $iEIn -and $iECo -gt $iEWc -and $iECo -lt $iEFirstIO) 'Contractors: Country in-list flag, write flag and validation before the first read/write'
function EFlag([string]$name) { $b = Get-Balanced $save ($save.IndexOf("Set($name,") + 3); return $b.Substring($name.Length + 2, $b.Length - $name.Length - 3) }
$eWcFx = EFlag 'varEmpSaveWriteCountry'
Assert-True ($eWcFx -ceq '!(varEmpSaveMode="Edit" && !IsBlank(varEmpSaveRec.Country) && !varEmpSaveCountryInList && varEmpSaveRec.Country=Trim(varEmpEdit.Country & ""))') 'Contractors: write flag = not (Edit, non-blank, outside the list, unchanged) (same rule as varPrjSaveWriteCountry)'
$eCoVal = Get-Balanced $save ($save.IndexOf('If(!IsBlank(varEmpSaveRec.Country) && !varEmpSaveCountryInList') + 2)
$eCoArgs = Split-Args $eCoVal.Substring(1, $eCoVal.Length - 2)
Assert-True ($eCoArgs.Count -eq 2 -and $eCoArgs[1].Trim() -ceq ('Collect(colEmpSaveErrors,{Field:"Country",Message:' + (TT0 'empErrCountry') + '})')) 'Contractors: unknown Country -> error on field Country (red border) with T.empErrCountry'
$chE = 'Table({Value:"Netherlands"},{Value:"Germany"})'
$eInEnv = "varEmpSaveCountryInList:$($eInC.Replace('Choices([@Employers].Country)', 'chE'))"
foreach ($c in @(
        @('"Edit"', '"Belgium"', '"Belgium"', 'false', 'false', 'legacy value outside the list unchanged: accepted, not written'),
        @('"Edit"', '"Belgium"', '"Germany"', 'true', 'false', 'legacy value changed to a list value: written'),
        @('"Edit"', '"Belgium"', '"Atlantis"', 'true', 'true', 'changed to another unknown value: error'),
        @('"Edit"', '"Netherlands"', '"Netherlands"', 'true', 'false', 'list value unchanged: written as before'),
        @('"Edit"', '""', '""', 'true', 'false', 'blank unchanged: written as Blank()'),
        @('"Edit"', '"Germany"', '""', 'true', 'false', 'cleared: written as Blank()'),
        @('"New"', '""', '""', 'true', 'false', 'New without Country (no SharePoint default): written as Blank()'),
        @('"New"', '""', '"Germany"', 'true', 'false', 'New with a list value: written'),
        @('"New"', '""', '"Belgium"', 'true', 'true', 'New with an unknown value: error'))) {
    $fx = "With({chE:$chE,varEmpSaveMode:$($c[0]),varEmpEdit:{Country:$($c[1])},varEmpSaveRec:{Country:$($c[2])}},With({$eInEnv},Text($eWcFx) & ""|"" & Text($($eCoArgs[0]))))"
    Assert-Eval $fx "$($c[3])|$($c[4])" "Contractors Country: $($c[5]) -> WriteCountry|Error = $($c[3])|$($c[4])"
    $si = if ($c[3] -eq 'true') { 1 } else { 2 }
    Assert-True ($eShape[$si].Contains('Country') -eq ($c[3] -eq 'true')) "Contractors Country: $($c[5]) -> Patch shape $si has Country: $($c[3])"
}
foreach ($k in @('btnEmpNew.OnSelect', 'btnEmpDiscard.OnSelect', 'btnEmpLoad.OnSelect', "$screenName.OnVisible")) { Assert-True ($all[$k].Contains('Street:"",HouseNumber:"",Postalcode:"",City:"",Country:""') -and $all[$k] -notmatch 'Netherlands') "$k : empty/New snapshot with Street, HouseNumber and Country """" (Employers.Country has no SharePoint default)" }
$rawCo = $rawBlank.Replace('Country:{Value:If(false,"x")}', 'Country:{Value:"Germany"}')
Assert-True ($rawCo -ne $rawBlank) 'Fixture: SharePoint row with Country Germany'
Assert-Eval (VerifyDiff $rawCo $inEmpty 'L') 'Country' 'Verify fails on Country (choice .Value compared with the written value; label in the message)'
Assert-Eval (VerifyDiff $rawBlank.Replace('Country:{Value:If(false,"x")}', 'Country:If(false,{Value:"x"})') $inEmpty 'F') '' 'Verify passes: blank Country record in SharePoint, empty selection'
Assert-Eval (VerifyDiff $rawBlank.Replace("Street:If(false,`"x`")", 'Street:"Main St"') $inEmpty 'L') 'Street' 'Verify fails on Street (label Street)'
Assert-Eval (VerifyDiff $rawBlank.Replace("'House Number':If(false,`"x`")", "'House Number':`"12a`"") $inEmpty 'L') 'House Number' 'Verify fails on House Number (label House Number)'
Assert-Eval (Conflict $rawCo $rawBlank) $true 'Conflict fires: another user changed Country'
Assert-Eval (Conflict $rawBlank.Replace("Street:If(false,`"x`")", 'Street:"Main St"') $rawBlank) $true 'Conflict fires: another user changed Street'
Assert-Eval (Conflict $rawBlank.Replace("'House Number':If(false,`"x`")", "'House Number':`"12a`"") $rawBlank) $true 'Conflict fires: another user changed House Number'
Assert-Eval (Dirty $rawBlank ((Inputs '"TEST Contractor 2"' '"Test Stad2"' '""' 'true').Replace('cmpEmpCountry:{Value:""}', 'cmpEmpCountry:{Value:"Germany"}'))) $true 'Dirty: Country picked'
Assert-Eval (Dirty $rawCo ((Inputs '"TEST Contractor 2"' '"Test Stad2"' '""' 'true').Replace('cmpEmpCountry:{Value:""}', 'cmpEmpCountry:{Value:"Germany"}'))) $false 'Not dirty: Country unchanged'
Assert-Eval (Dirty $rawBlank ((Inputs '"TEST Contractor 2"' '"Test Stad2"' '""' 'true').Replace('cmpEmpStreet:{Value:""}', 'cmpEmpStreet:{Value:"Main St"}'))) $true 'Dirty: Street changed'
Assert-Eval (Dirty $rawBlank ((Inputs '"TEST Contractor 2"' '"Test Stad2"' '""' 'true').Replace('cmpEmpHouseNumber:{Value:""}', 'cmpEmpHouseNumber:{Value:"12a"}'))) $true 'Dirty: House Number changed'
Assert-True ((Get-Prop 'cmpEmpCountry' 'DefaultValue') -ceq '=varEmpEdit.Country' -and (Get-Prop 'cmpEmpCountry' 'Invalid') -ceq '=CountIf(colEmpSaveErrors,Field="Country")>0') 'Contractors: Country dropdown DefaultValue = varEmpEdit.Country, Invalid via colEmpSaveErrors.Field'
$idxP = @{}; Index-Controls ($builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'scrProjects.pa.yaml'))))['Screens']['scrProjects']['Children'] $idxP
foreach ($k in @('cmpEmpStreet', 'cmpEmpHouseNumber', 'cmpEmpPostalcode', 'cmpEmpCity', 'cmpEmpCountry')) {
    $pk = $k.Replace('cmpEmp', 'cmpPrj').Replace('Postalcode', 'PostalCode')
    Assert-True ((Get-Prop $k 'X') -ceq $idxP[$pk]['Properties']['X'].Trim().Replace('lblPrj', 'lblEmp') -and (Get-Prop $k 'Y') -ceq $idxP[$pk]['Properties']['Y'].Trim().Replace('lblPrj', 'lblEmp')) "Contractors ${k}: grid X/Y mirror Projects $pk"
}
Assert-True ($formulas -notmatch '\bempFieldAddress\b') 'T.empFieldAddress removed (Address is no longer shown)'
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
Apply-DirtyLabel $pAll 'Prj' 'Projects'; $pDirtyFromLbl = $script:lastDirty
$pText = ($pAll.Values) -join "`n"
# --- Step 3b (31-10-2026): footer, list card, title bar, message bar and form fields of scrProjects are component instances (same compatibility layer as Contractors).
$pFooterMap = [ordered]@{ btnPrjHome = 'Home'; btnPrjNew = 'New'; btnPrjRefresh = 'Refresh'; btnPrjDiscard = 'Discard'; btnPrjSave = 'Save' }
Assert-True ($pIdx['cmpPrjFooter']['Control'] -eq 'CanvasComponent' -and $pIdx['cmpPrjFooter']['ComponentName'] -eq 'cmpFooter') 'Projects: footer = cmpFooter instance (cmpPrjFooter)'
foreach ($k in $pFooterMap.Keys) {
    $v = $pFooterMap[$k]; $en = ([string]$pAll["cmpPrjFooter.${v}Enabled"]).Trim(); $os = ([string]$pAll["cmpPrjFooter.On$v"]).Trim()
    Assert-True ($en.StartsWith('=') -and $en.Length -gt 3) "Projects: cmpPrjFooter.${v}Enabled is a Boolean expression"
    $g = $en.Substring(1)
    Assert-True ($os.StartsWith('=If(' + $g + ',')) "Projects: cmpPrjFooter.On$v starts with the same guard text as ${v}Enabled (fail-closed)"
    $pAll["$k.OnSelect"] = $pAll["cmpPrjFooter.On$v"]; $pAll["$k.DisplayMode"] = '=If(' + $g + ',DisplayMode.Edit,DisplayMode.Disabled)'
    $pAll.Remove("cmpPrjFooter.On$v"); $pAll.Remove("cmpPrjFooter.${v}Enabled")
}
$plEn = ([string]$pAll['cmpPrjList.Enabled']).Trim(); $plOs = ([string]$pAll['cmpPrjList.OnSelectRow']).Trim(); $plTg = ([string]$pAll['cmpPrjList.OnToggleShowInactive']).Trim()
Assert-True ($pIdx['cmpPrjList']['Control'] -eq 'CanvasComponent' -and $pIdx['cmpPrjList']['ComponentName'] -eq 'cmpListCard') 'Projects: list card = cmpListCard instance (cmpPrjList)'
Assert-True ($plOs.StartsWith('=If(' + $plEn.Substring(1) + ',') -and $plTg.StartsWith('=If(' + $plEn.Substring(1) + ',')) 'Projects: cmpPrjList.Enabled is the first If-condition of OnSelectRow and OnToggleShowInactive'
$pAll['galPrjList.OnSelect'] = $pAll['cmpPrjList.OnSelectRow']; $pAll['galPrjList.DisplayMode'] = '=If(' + $plEn.Substring(1) + ',DisplayMode.Edit,DisplayMode.Disabled)'
$pAll['galPrjList.Items'] = $pAll['cmpPrjList.Items']; $pAll['btnPrjShowInactiveSwitch.OnSelect'] = $pAll['cmpPrjList.OnToggleShowInactive']
$pAll['icoPrjMsgClose.OnSelect'] = $pAll['cmpPrjMsgBar.OnClose']
foreach ($rm in 'cmpPrjList.OnSelectRow', 'cmpPrjList.Enabled', 'cmpPrjList.Items', 'cmpPrjList.OnToggleShowInactive', 'cmpPrjMsgBar.OnClose') { $pAll.Remove($rm) }
$pText = ($pAll.Values) -join "`n"
function PGet([string]$ctl, [string]$prop) { $v = $pAll["$ctl.$prop"]; if ($null -eq $v) { throw "FAIL missing $ctl.$prop" }; return ([string]$v).Trim() }
$pTextFields = [ordered]@{ cmpPrjName = 'Name'; cmpPrjNumber = 'Number'; cmpPrjReference = 'Reference'; cmpPrjCustomer = 'Customer'; cmpPrjStreet = 'Street'; cmpPrjHouseNumber = 'HouseNumber'; cmpPrjPostalCode = 'PostalCode'; cmpPrjCity = 'City'; cmpPrjUrl = 'Url' }
$pDropFields = [ordered]@{ cmpPrjStatus = 'Status'; cmpPrjCountry = 'Country' }
$pWritten = @('Name', 'Number', 'Reference', 'Customer', 'Status', 'Street', 'HouseNumber', 'PostalCode', 'City', 'Country', 'Url')
function PInputOf([string]$f) { foreach ($k in $pTextFields.Keys) { if ($pTextFields[$k] -eq $f) { return "$k.Value" } }; foreach ($k in $pDropFields.Keys) { if ($pDropFields[$k] -eq $f) { return "$k.Value" } }; throw "no input for $f" }

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
Assert-True ($pDirty -ceq $pDirtyFromLbl) 'Projects: dirty text in the Save guard = the lblPrjDirty text (one source)'
foreach ($f in $pWritten) { Assert-True ($pDirty.Contains("Trim($(PInputOf $f) & """")<>Trim(varPrjEdit.$f & """")")) "Projects: dirty compares $(PInputOf $f) directly with varPrjEdit.$f, both sides Trim(x & """")" }
Assert-True (([regex]::Matches($pDirty, '<>')).Count -eq $pWritten.Count -and $pDirty -notmatch 'Leader|SiteManager|txtPrjSearch|Modified') 'Projects: dirty covers exactly the 11 app-written fields (not the read-only person fields, search or Modified)'
Assert-True ($pGuards.btnPrjSave.EndsWith('&& ' + $pDirty)) 'Projects: Save requires dirty'
foreach ($ctl in @('btnPrjHome', 'btnPrjNew', 'galPrjList')) { Assert-True ($pGuards[$ctl].EndsWith('!' + $pDirty)) "Projects: $ctl blocked while dirty (same dirty text)" }
Assert-True ($pGuards.btnPrjRefresh -ceq ('!Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && (Coalesce(varPrjSaveFailed,false) || !' + $pDirty + ')')) 'Projects: Refresh blocked while loading/saving; allowed when clean or after a failed save (H15)'
Assert-True ($pGuards.btnPrjDiscard -ceq ('!Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && (Coalesce(varPrjSaveFailed,false) || varPrjMode="New" || ' + $pDirty + ')')) 'Projects: Discard requires dirty, New mode (8b) or SaveFailed'
Assert-True ($pGuards.btnPrjHome -ceq ('!Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && !' + $pDirty) -and $pGuards.btnPrjNew -ceq $pGuards.galPrjList) 'Projects: Home = not busy/saving/dirty; New = gallery-selection guard'
foreach ($k in @('varPrjLoadState="Loaded"', 'IsEmpty(colPrjLoadErrors)', '!Coalesce(varPrjBusy,false)', '!Coalesce(varPrjSaving,false)', '!Coalesce(varPrjSaveFailed,false)')) { Assert-True ($pGuards.btnPrjSave.Contains($k) -and $pGuards.btnPrjNew.Contains($k)) "Projects: Save and New guards contain $k" }
Assert-True ($pGuards.btnPrjSave.Contains('(varPrjMode="New" || (varPrjMode="Edit" && !IsBlank(varPrjSelectedID)))')) 'Projects: Save guard: New, or Edit with an ID'
Assert-True ((PGet 'btnPrjHome' 'OnSelect') -ceq ('=If(' + $pGuards.btnPrjHome + ',Navigate(scrHome))')) 'Projects: Home navigates only to scrHome, inside the guard'
function PIn([string]$name, [string]$num, [string]$city, [string]$status, [string]$country, [string]$empty) {
    return "cmpPrjName:{Value:$name},cmpPrjNumber:{Value:$num},cmpPrjReference:{Value:$empty},cmpPrjCustomer:{Value:$empty},cmpPrjStatus:{Value:$status},cmpPrjStreet:{Value:$empty},cmpPrjHouseNumber:{Value:$empty},cmpPrjPostalCode:{Value:$empty},cmpPrjCity:{Value:$city},cmpPrjCountry:{Value:$country},cmpPrjUrl:{Value:$empty}"
}
$pSnap = '{ID:5,Name:"A",Number:"TEST-002",Reference:"",Customer:"",Status:"Active",Street:"",HouseNumber:"",PostalCode:"",City:"",Country:"Netherlands",Leader:"",SiteManager:"",Url:""}'
$pBase = 'varPrjLoadState:"Loaded",colPrjLoadErrors:Filter(Table({Message:""}),false),varPrjBusy:false,varPrjSaving:false,varPrjSaveFailed:false,varPrjMode:"Edit",varPrjSelectedID:5,varPrjEdit:' + $pSnap + ','
$pFix = $pBase + (PIn '"B"' '"TEST-002"' '""' '"Active"' '"Netherlands"' '""')
$pClean = $pBase + (PIn '"A"' '"TEST-002"' '""' '"Active"' '"Netherlands"' '""')
function PG($name, $fixture) { return 'With({' + $fixture + '},' + $pGuards[$name] + ')' }
Assert-Eval (PG 'btnPrjSave' $pFix) $true 'Projects: Save allowed: Loaded, Edit with ID, dirty'
Assert-Eval (PG 'btnPrjSave' $pClean) $false 'Projects: Save blocked: not dirty'
Assert-Eval (PG 'btnPrjSave' $pClean.Replace('cmpPrjStatus:{Value:"Active"}', 'cmpPrjStatus:{Value:"Closed"}')) $true 'Projects: Save allowed: only Status changed (dirty)'
Assert-Eval (PG 'btnPrjSave' $pClean.Replace('cmpPrjCountry:{Value:"Netherlands"}', 'cmpPrjCountry:{Value:"Germany"}')) $true 'Projects: Save allowed: only Country changed (dirty)'
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
$cfFieldDef = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'Components/cmpField.pa.yaml')))['ComponentDefinitions']['cmpField']; $cfFieldIdx = @{}; Index-Controls $cfFieldDef['Children'] $cfFieldIdx
Assert-True ($cfFieldIdx['ddFieldValue']['Properties']['AllowEmptySelection'] -eq '=true') 'Projects: the cmpField dropdown has AllowEmptySelection = true (blank SharePoint value stays blank, no false dirty); Status and Country are cmpField dropdowns'

# Form bound to varPrjEdit, never to the gallery selection
$pFieldGuard = '=varPrjLoadState="Loaded" && IsEmpty(colPrjLoadErrors) && !Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && !Coalesce(varPrjSaveFailed,false) && Coalesce(varPrjMode,"") in ["New","Edit"]'
$pLabelKey = @{ Name = 'prjFieldName'; Number = 'prjFieldNumber'; Reference = 'prjFieldReference'; Customer = 'prjFieldCustomer'; Status = 'prjFieldStatus'; Street = 'prjFieldStreet'; HouseNumber = 'prjFieldHouseNumber'; PostalCode = 'prjFieldPostalCode'; City = 'prjFieldCity'; Country = 'prjFieldCountry'; Leader = 'prjFieldLeader'; SiteManager = 'prjFieldSiteManager'; Url = 'prjFieldUrl' }
foreach ($k in @($pTextFields.Keys) + @($pDropFields.Keys)) {
    $f = if ($pTextFields.Contains($k)) { $pTextFields[$k] } else { $pDropFields[$k] }; $fp = $pIdx[$k]['Properties']
    Assert-True (($pIdx[$k]['Control'] -eq 'CanvasComponent') -and ($pIdx[$k]['ComponentName'] -eq 'cmpField')) "Projects: $k is a cmpField instance"
    Assert-True ((PGet $k 'DefaultValue') -ceq "=varPrjEdit.$f") "Projects: $k.DefaultValue = varPrjEdit.$f"
    Assert-True (((PGet $k 'Enabled') -ceq $pFieldGuard) -and ((PGet $k 'Invalid') -ceq ('=CountIf(colPrjSaveErrors,Field="' + $f + '")>0')) -and ((PGet $k 'Height') -eq '=58') -and ((PGet $k 'MaxLength') -eq '=255') -and ((PGet $k 'Label') -ceq ('=' + (TT $pLabelKey[$f]))) -and (-not $fp.ContainsKey('Visible')) -and (-not $fp.ContainsKey('OnChange'))) "Projects: $k Enabled = edit guard (Boolean), Invalid = CountIf(colPrjSaveErrors,Field=""$f"")>0, label from T, h58, MaxLength 255, no Visible, no OnChange logic"
    Assert-True ((($fp.ContainsKey('Required') -and $fp['Required'] -eq '=true') -eq ($f -in @('Name', 'Number', 'Status'))) -and ((PGet $k 'InputType') -eq $(if ($pDropFields.Contains($k)) { '="dropdown"' } else { '="text"' }))) "Projects: $k Required only on Project Name, Project Number and Status; InputType text / dropdown"
}
foreach ($k in @('cmpPrjLeader', 'cmpPrjSiteManager')) { $f = @{ cmpPrjLeader = 'Leader'; cmpPrjSiteManager = 'SiteManager' }[$k]; Assert-True (((PGet $k 'DefaultValue') -ceq "=varPrjEdit.$f") -and ((PGet $k 'InputType') -eq '="readonly"') -and ((PGet $k 'Enabled') -eq '=false') -and ($pIdx[$k]['ComponentName'] -eq 'cmpField') -and ((PGet $k 'Label') -ceq ('=' + (TT $pLabelKey[$f])))) "Projects: $k read-only cmpField, never enabled, showing varPrjEdit.$f (DisplayName)" }
Assert-True ($srcAll -notmatch '\btxtPrj\w*\b|\bddPrj\w*\b|\bgalPrjList\b|\blblPrj\w*Label\b|\blblPrj\w*Required\b|\bconPrjMsgBar\b|\bnavPrj\b|\bconPrjListCard\b|\bimgPrjSpinner\b|\bimgLogoProjects\b|\blblPrjTitle\b|\bconPrjButtonRow\b') 'Projects: no replaced hand-built control (txtPrj*, ddPrj*, galPrjList, field labels/stars, conPrjMsgBar, navPrj, spinner, logo) is left in Src'
$pSelUses = @($pAll.Keys | Where-Object { $pAll[$_] -match 'cmpPrjList\.SelectedRowID' })
Assert-True ($pSelUses.Count -eq 1 -and $pSelUses[0] -eq 'galPrjList.OnSelect') 'Projects: cmpPrjList.SelectedRowID only read in the guarded OnSelectRow handler'
Assert-True (@($pIdx.Keys | Where-Object { $pIdx[$_]['Control'] -like 'Classic/CheckBox@*' -or $pIdx[$_]['Control'] -like '*ComboBox*' }).Count -eq 0) 'Projects: no CheckBox/ComboBox (Status replaces Active; person fields read-only)'
Assert-True ($pText -notmatch '\bvarPrjActiveDraft\b|btnPrjActiveSwitch') 'Projects: no Active switch (Status replaces Active)'

# (P2) Loader: staging, reuse, dirty block, no mutations, H16 Refresh first -----------------------------------------------
$pLoad = PGet 'btnPrjLoad' 'OnSelect'; $pLoadN = Norm $pLoad
$pVis = [string]$pAll["$pScreen.OnVisible"]  # dirty label expanded (Apply-DirtyLabel)
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
        if ($arg.TrimStart().StartsWith('Patch(') -or $arg.TrimStart().StartsWith('If(varPrjSaveWriteStatus && varPrjSaveWriteCountry,Patch(Projects,')) { continue }  # N3: the one write (record shape chosen by If)
        $pReads++
        $col = $m.Groups[1].Value; $after = $fx.Substring($m.Index)
        Assert-True ($after.Contains("CountRows($col)>=500") -or $after.Contains("CountRows($col)<>1") -or $after.Contains("CountRows($col)=1")) "Projects: $k : SharePoint read into $col is followed by a 500 guard (or exact-one check for an ID read)"
    }
}
Assert-True ($pReads -eq 7) "Projects: SharePoint reads into collections: $pReads (load, pre-read, number check, open periods, verify, N1 control read Edit / New after a Patch error)"

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
$pPredExp = @('Projects|ID=varPrjSaveID', "Projects|'Project Number'=varPrjSaveNumber", 'Projects|ID=varPrjPatchedID', "'Assignment Periods'|ProjectKey=varPrjSaveKey", 'Projects|ID=varPrjSaveID', "Projects|'Project Number'=varPrjSaveNumber")  # last two: N1 control read (same predicates as pre-read / number check)
Assert-True ((($pPreds | Sort-Object) -join ';') -ceq (($pPredExp | Sort-Object) -join ';')) "Projects: server predicates are exactly column = global variable ($($pPreds -join '; '))"
Assert-True ($pText -notmatch "\bProjectName\b" -and $pText -notmatch "'Project Name'") "Projects: no bare ProjectName and no 'Project Name' column (Project Name = Title; Project Number = 'Project Number')"
$pSave = PGet 'btnPrjSave' 'OnSelect'; $pSaveN = Norm $pSave
foreach ($v in @(@('Set(varPrjSaveNumber,varPrjSaveRec.Number)', "Filter(Projects,'Project Number'=varPrjSaveNumber)"), @('Set(varPrjSaveKey,If(varPrjSaveMode="Edit",Text(varPrjSaveID),""))', "Filter('Assignment Periods',ProjectKey=varPrjSaveKey)"), @('Set(varPrjSaveID,', 'Filter(Projects,ID=varPrjSaveID)'), @('Set(varPrjPatchedID,', 'Filter(Projects,ID=varPrjPatchedID)'))) {
    Assert-True ($pSave.IndexOf($v[0]) -gt 0 -and $pSave.IndexOf($v[0]) -lt $pSave.IndexOf($v[1])) "Projects: global predicate variable set before its read: $($v[1])"
}
$pChoices = @($pAll.Keys | Where-Object { $pAll[$_] -match '\bChoices\(' } | Sort-Object)
Assert-True (($pChoices -join ',') -ceq 'btnPrjSave.OnSelect,cmpPrjCountry.Items,cmpPrjStatus.Items') "Projects: Choices() only on the two cmpField dropdown Items and in Save ($($pChoices -join ', '))"
$pAsIs = @{}; foreach ($c in @('Status', 'Country')) { $pAsIs[$c] = "Split(Concat(Choices([@Projects].$c),Value,Char(31)) & If(!IsBlank(varPrjEdit.$c) && CountIf(Choices([@Projects].$c),Value=varPrjEdit.$c)=0,Char(31) & varPrjEdit.$c,`"`"),Char(31))" }
Assert-True ((PGet 'cmpPrjStatus' 'Items') -ceq '=ShowColumns(Choices([@Projects].Status),Value)' -and (PGet 'cmpPrjCountry' 'Items') -ceq '=ShowColumns(Choices([@Projects].Country),Value)' -and ($cfFieldIdx['ddFieldValue']['Properties']['Items'] -match 'LookUp\(cmpField\.Items,Value=cmpField\.DefaultValue\)')) 'Projects: Status/Country dropdown Items = the Choices([@Projects].<column>) values (column Value as identifier, not translated); cmpField appends the stored value of the record itself when it is not in the list (shown as-is, never dirty)'
$pInList = 'Set(varPrjSaveStatusInList,CountIf(Choices([@Projects].Status),Value=varPrjSaveRec.Status)>0); Set(varPrjSaveCountryInList,CountIf(Choices([@Projects].Country),Value=varPrjSaveRec.Country)>0);'
Assert-True (([regex]::Matches($pSave, '\bChoices\(')).Count -eq 2 -and ([regex]::Matches($pSave, [regex]::Escape($pInList))).Count -eq 1 -and $pSave.Contains('If(IsBlank(varPrjSaveRec.Status) || (!varPrjSaveStatusInList && !(varPrjSaveMode="Edit" && varPrjSaveRec.Status=varPrjEdit.Status)),Collect(colPrjSaveErrors,{Field:"Status"')) 'Projects: Save checks Status and Country once each against Choices (not inside ForAll, before any read/write); Status validation uses the flag; an unchanged stored value outside Choices is accepted in Edit'
Assert-True ($pSaveN.IndexOf((Norm $pInList)) -gt 0 -and $pSaveN.IndexOf((Norm $pInList)) -lt $pSaveN.IndexOf('If(IsEmpty(colPrjSaveErrors),IfError(Refresh(Projects),')) 'Projects N3: in-list flags and write flags set in the local validation, before the first read/write'
Assert-True (@($pAll.Values | Where-Object { $_ -match 'ForAll\([^;]*\bChoices\(' }).Count -eq 0 -and $pText -notmatch '\bSearch\(') 'Projects: no Choices() inside ForAll, no Search()'
Assert-True ($pText -notmatch "ForAll\([^)]*\bProjects\b[^)]*\)[^;]*\b(?:LookUp|Filter)\(\s*Projects") 'Projects: no remote LookUp/Filter inside ForAll'

# (P6)-(P8) Save: validation, duplicate block, conflict check, one Patch, verify read, local update after verify ------------
# N3 (03-11-2026): one write per save; the record shape (with / without Status, Country) is chosen by one If inside the single write gate.
$pSelAt = $pSave.IndexOf('ClearCollect(colPrjPatched,If(')
Assert-True ($pSelAt -gt 0 -and ([regex]::Matches($pSave, 'ClearCollect\(colPrjPatched,')).Count -eq 1) 'Projects N3: exactly one ClearCollect(colPrjPatched, If(<shape>, Patch, ...)) write step in Save'
$pSel = Get-Balanced $pSave ($pSelAt + 'ClearCollect(colPrjPatched,If'.Length)
$pSelArgs = Split-Args $pSel.Substring(1, $pSel.Length - 2)
Assert-True ($pSelArgs.Count -eq 7 -and $pSelArgs[0].Trim() -ceq 'varPrjSaveWriteStatus && varPrjSaveWriteCountry' -and $pSelArgs[2].Trim() -ceq 'varPrjSaveWriteStatus' -and $pSelArgs[4].Trim() -ceq 'varPrjSaveWriteCountry' -and @(1, 3, 5, 6 | Where-Object { -not $pSelArgs[$_].Trim().StartsWith('Patch(Projects,') }).Count -eq 0) 'Projects N3: If(Status && Country, Patch(all), Status, Patch(no Country), Country, Patch(no Status), Patch(neither)): exactly one Patch runs'
Assert-True (([regex]::Matches($srcAll, '\bPatch\(\s*Projects\b')).Count -eq 4 -and ([regex]::Matches($pSel, '\bPatch\(\s*Projects\b')).Count -eq 4) 'Projects: the four Patch(Projects) shapes are all inside that one If in btnPrjSave.OnSelect (no other Patch(Projects) in Src)'
$pShape = @{}
foreach ($si in 1, 3, 5, 6) {
    $sp = $pSelArgs[$si].Trim(); $sa = Split-Args $sp.Substring('Patch('.Length, $sp.Length - 'Patch('.Length - 1)
    Assert-True ($sa.Count -eq 3 -and $sa[1].Trim() -ceq 'If(varPrjSaveMode="New",Defaults(Projects),First(colPrjPreRaw))') "Projects N3: shape $si : base Defaults(Projects) for New, the pre-read record for Edit"
    $sr = $sa[2].Trim(); $pShape[$si] = [ordered]@{}; foreach ($a in (Split-Args $sr.Substring(1, $sr.Length - 2))) { $kv = $a -split ':', 2; $pShape[$si][$kv[0].Trim()] = $kv[1].Trim() }
}
$pShapeKeys = @{ 1 = @('Status', 'Country'); 3 = @('Status'); 5 = @('Country'); 6 = @() }
foreach ($si in 1, 3, 5, 6) {
    $common = @($pShape[$si].Keys | Where-Object { $_ -notin @('Status', 'Country') })
    Assert-True ((($common | ForEach-Object { "$_=$($pShape[$si][$_])" }) -join ';') -ceq ((@($pShape[1].Keys | Where-Object { $_ -notin @('Status', 'Country') }) | ForEach-Object { "$_=$($pShape[1][$_])" }) -join ';') -and (@('Status', 'Country' | Where-Object { $pShape[$si].Contains($_) }) -join ',') -ceq ($pShapeKeys[$si] -join ',')) "Projects N3: shape $si writes the same 9 other fields identically and Status/Country = $($pShapeKeys[$si] -join ',')"
    if ($pShape[$si].Contains('Status')) { Assert-True ($pShape[$si]['Status'] -ceq '{Value:varPrjSaveRec.Status}') "Projects N3: shape $si Status = {Value: ...}" }
    if ($pShape[$si].Contains('Country')) { Assert-True ($pShape[$si]['Country'] -ceq 'If(IsBlank(varPrjSaveRec.Country),Blank(),{Value:varPrjSaveRec.Country})') "Projects N3: shape $si Country = {Value: ...} / Blank()" }
}
Assert-True ($pSel -notmatch '\bChoices\(') 'Projects N3: no Choices() in any Patch record'
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
    Periods = $pSaveN.IndexOf("ClearCollect(colPrjPeriods,"); WriteGate = $pSaveN.IndexOf('If(IsEmpty(colPrjSaveErrors),Set(varPrjPatchError,false);IfError(CountRows(ClearCollect(colPrjPatched,If(varPrjSaveWriteStatus&&varPrjSaveWriteCountry,Patch(Projects,')
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
Assert-True ($pSaveN.Contains((Norm 'Trace("DIAG|Projects|SaveEnd",TraceSeverity.Information,{Screen:"Projects",Mode:varPrjSaveMode,ItemID:Coalesce(varPrjPatchedID,varPrjSaveID,0),ElapsedMs:DateDiff(varPrjDiagT0,Now(),TimeUnit.Milliseconds),Reads:varPrjSaveReads,Writes:varPrjSaveWrites,Verified:varPrjSaveVerified,DupFound:varPrjSaveDupFound,Conflict:varPrjSaveConflict,OpenPeriods:varPrjSaveOpenPeriods,PeriodsUnchecked:varPrjSavePeriodsUnchecked,Errors:CountRows(colPrjSaveErrors),ControlRead:varPrjSaveCtl})'))) 'Projects: SaveEnd trace with Mode/ItemID/ElapsedMs/Reads/Writes/Verified/DupFound/Conflict/OpenPeriods/Errors/ControlRead (N1)'
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
    foreach ($lit in [regex]::Matches($fx, '"([^"]*)"')) { if ($lit.Groups[1].Value -match '[A-Za-z]{2,}\s+[A-Za-z]' -and $lit.Groups[1].Value -cne 'On hold') { $pHard +="$k : `"$($lit.Groups[1].Value)`"" } }
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
$pTexts = [ordered]@{ prjTitle = 'Projects'; prjSearchHint = 'Search number, name or city'; prjCount = '{0} projects'; prjShowInactive = 'Show closed'; prjNewProject = 'New project'; prjSecGeneral = 'GENERAL'; prjSecAddress = 'ADDRESS'; prjSecPeople = 'PEOPLE'; prjSecLinks = 'LINKS'; prjLastChanged = 'Last changed in SharePoint: {0}'; prjErrConflict = 'Changed in SharePoint by someone else. Nothing saved. Click Discard, then Refresh.'; prjErrDuplicate = 'Fix: Project Number already exists' }
foreach ($k in $pTexts.Keys) { Assert-True ($formulas.Contains("$($k): {en: ""$($pTexts[$k])"", nl: """"}")) "Projects: T.$k = '$($pTexts[$k])'" }

# (P14) Refresh before every SharePoint read (H16), form reset, Modified display -----------------------------------------
$pBeh = @{}
foreach ($p in $pScreenProps.Keys) { if ($p -like 'On*') { $pBeh["$pScreen.$p"] = [string]$pScreenProps[$p] } }
Get-BehaviourFormulas $pDoc['Screens'][$pScreen]['Children'] $pScreen $pBeh
$pSp = @()
foreach ($k in ($pBeh.Keys | Sort-Object)) { foreach ($r in (Test-RefreshBeforeReads $pBeh[$k])) { $pSp += $r; Assert-True ($r.Status -eq 'Refreshed') "Projects: $k : read of $($r.Source) (formula line $($r.Line)) preceded by Refresh($($r.Source)) in the same branch [$($r.Status)]" } }
Assert-True (@($pSp | Where-Object Source -eq 'Projects').Count -eq 6 -and @($pSp | Where-Object Source -eq "'Assignment Periods'").Count -eq 1 -and $pSp.Count -eq 7) "Projects: SharePoint reads: 6 x Projects (load, pre-read, number check, verify, N1 control read Edit / New after a Patch error), 1 x Assignment Periods (closing check)"
$pFr = PGet 'btnPrjFormReset' 'OnSelect'
$pReset = 'Reset(cmpPrjName); Reset(cmpPrjNumber); Reset(cmpPrjReference); Reset(cmpPrjCustomer); Reset(cmpPrjStatus); Reset(cmpPrjStreet); Reset(cmpPrjHouseNumber); Reset(cmpPrjPostalCode); Reset(cmpPrjCity); Reset(cmpPrjCountry); Reset(cmpPrjUrl)'
Assert-True ($pIdx['btnPrjFormReset']['Control'] -eq 'Classic/Button@2.2.0' -and (PGet 'btnPrjFormReset' 'Visible') -eq '=false' -and $pFr.StartsWith('=If(varPrjLoadState="Loaded" && IsEmpty(colPrjLoadErrors) && !Coalesce(varPrjBusy,false) && !Coalesce(varPrjSaving,false) && !Coalesce(varPrjSaveFailed,false),') -and $pFr.Contains($pReset)) 'Projects: hidden btnPrjFormReset resets all 11 inputs only when Loaded/idle/no failed save'
Assert-True ($pFr -notmatch '\b(Patch|Refresh|Collect|ClearCollect|Remove|RemoveIf|Clear|Set|UpdateContext|Select|Navigate)\(') 'Projects: form reset is local only (no mutation, no variable change, no further Select)'
Assert-True (([regex]::Matches($pText, 'Select\(btnPrjFormReset\)')).Count -eq 2 -and $pLoad.IndexOf('If(varPrjLoadState="Loaded",Select(btnPrjFormReset))') -gt $pLoad.LastIndexOf('Set(varPrjForceRefresh,false); Set(varPrjBusy,false);')) 'Projects: form reset selected at the end of the loader (after busy off) and after a verified save'
foreach ($k in @('btnPrjLoad.OnSelect', 'btnPrjSave.OnSelect', 'btnPrjNew.OnSelect', 'btnPrjDiscard.OnSelect', 'galPrjList.OnSelect')) { Assert-True ($pAll[$k].Contains($pReset)) "Projects: $k resets all form inputs (incl. both dropdowns)" }
foreach ($k in @($pTextFields.Keys) + @($pDropFields.Keys)) { Assert-True (!$pIdx[$k]['Properties'].ContainsKey('Reset')) "Projects: $k has no Reset property (Reset(<instance>) calls only)" }
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
foreach ($ctl in @('btnPrjSave', 'btnPrjNew', 'btnPrjRefresh', 'btnPrjDiscard', 'galPrjList')) { Assert-True ((Norm ((PGet $ctl 'OnSelect') -replace ';\s*true\s*$', '')).EndsWith($pBlockedN)) "Projects: $ctl : the guard's else branch shows Blocked. (error, no mutation; list handler ends with ; true)" }
# 02-11-2026: the list card events are ReturnType Boolean (Studio shape), so both list handlers end with ; true
Assert-True ((([string](PGet 'galPrjList' 'OnSelect')).TrimEnd()).EndsWith('; true')) 'Projects: cmpPrjList OnSelectRow ends with ; true (Boolean event; the toggle is checked exactly above)'
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
$pBarExp = [ordered]@{ X = '=cmpPrjTitle.X'; Y = '=cmpPrjTitle.Y+cmpPrjTitle.Height'; Width = '=cmpPrjTitle.Width'; Height = '=If(IsBlank(varAdmMsgKind),0,40)'; Kind = '=varAdmMsgKind'; Head = '=varAdmMsgHead'; Body = '=varAdmMsgBody'; CloseLabel = ('=' + (TT 'admMsgClose')) }
Assert-True ($pIdx['cmpPrjMsgBar']['Control'] -eq 'CanvasComponent' -and $pIdx['cmpPrjMsgBar']['ComponentName'] -eq 'cmpMessageBar') 'Projects: cmpPrjMsgBar is a cmpMessageBar instance'
foreach ($k in $pBarExp.Keys) { Assert-True (([string]$pIdx['cmpPrjMsgBar']['Properties'][$k]) -ceq $pBarExp[$k]) "Projects: cmpPrjMsgBar.$k = $($pBarExp[$k]) (same as Contractors)" }
Assert-True ((PGet 'icoPrjMsgClose' 'OnSelect') -ceq '=Set(varAdmMsgKind,""); Set(varAdmMsgHead,""); Set(varAdmMsgBody,"")' -and $pVis.StartsWith('=Set(varAdmMsgKind,""); Set(varAdmMsgHead,""); Set(varAdmMsgBody,"");')) 'Projects: cmpPrjMsgBar.OnClose and OnVisible clear kind, head and body first'
$pBarReaders = @($pAll.Keys | Where-Object { $_ -notmatch '\.On\w+$' -and $pAll[$_] -match '\bvarAdmMsg(Kind|Head|Body)\b' } | ForEach-Object { ($_ -split '\.')[0] } | Sort-Object -Unique)
Assert-True (($pBarReaders -join ',') -ceq 'cmpPrjMsgBar') "Projects: message variables only displayed by the bar instance ($($pBarReaders -join ', '))"

# (P16) List card: search on number/name/city, Show inactive = show Closed (default off), On hold counts as active --------
Assert-True ((PGet 'cmpPrjList' 'SearchHint') -ceq ('=' + (TT 'prjSearchHint'))) 'Projects: search hint/label from T ("Search number, name or city")'
Assert-True ((PGet 'cmpPrjList' 'CountFormat') -ceq ('=' + (TT 'prjCount')) -and -not $pIdx['cmpPrjList']['Properties'].ContainsKey('CountText')) 'Projects: count format "{0} projects"; the list card counts the shown rows itself (no read-back of its Items)'
Assert-True ((PGet 'btnPrjShowInactiveSwitch' 'OnSelect') -ceq ('=If(' + $plEn.Substring(1) + ',Set(varPrjShowInactive,!Coalesce(varPrjShowInactive,false))); true') -and (PGet 'cmpPrjList' 'ShowInactive') -ceq '=Coalesce(varPrjShowInactive,false)') 'Projects: Show inactive (= show Closed) toggles a local filter only, guard first; the component never flips the state'
$pSi = @($pAll.Keys | Where-Object { $pAll[$_] -match 'Set\(varPrjShowInactive,' } | Sort-Object)
Assert-True (($pSi -join ',') -ceq 'btnPrjShowInactiveSwitch.OnSelect,scrProjects.OnVisible' -and $pVis.Contains('Set(varPrjShowInactive,false)')) 'Projects: varPrjShowInactive only set by its switch and the first-visit init (false = Closed hidden)'
$pItemsAll = (PGet 'galPrjList' 'Items').TrimStart('=')
$pSorted = 'Sort' + (Get-Balanced $pItemsAll ($pItemsAll.IndexOf('Sort(ForAll(') + 4))
Assert-True ($pItemsAll.StartsWith('ForAll(' + $pSorted + ' As r,{ID:r.ID,Title:') -and $pItemsAll -notmatch 'cmpPrjList\.' -and $pItemsAll -notmatch 'txtPrjSearch' -and $pItemsAll -notmatch 'varPrjShowInactive' -and $pItemsAll -notmatch 'SearchKey' -and $pItemsAll.Contains('Inactive:r.Status="Closed"')) 'Projects: cmpListCard Items = all rows sorted, projected to ID, Title, Subtitle, Inactive (Closed), ChipText; no host filter, no SearchKey, no read-back of cmpPrjList.SearchText/Items'
$pPred = $lcPredC.Replace('txtSearch.Text', 'cmpPrjList.SearchText').Replace('cmpListCard.ShowInactive', 'Coalesce(varPrjShowInactive,false)')
$pItems = 'Filter(' + $pItemsAll + ',' + $pPred + ')'
$pItemFix = 'colAdminProjects:Table({ID:1,Name:"Alpha",Number:"TEST-002",Customer:"Cust",City:"Delft",Status:"Active"},{ID:2,Name:"Beta",Number:"TEST-001",Customer:"",City:"Ede",Status:"On hold"},{ID:3,Name:"Gamma",Number:"P-9",Customer:"",City:"Venlo",Status:"Closed"},{ID:4,Name:"Delta",Number:"A-1",Customer:"",City:"",Status:""})'
# shown rows = host Items filtered by the component's search predicate; IDs: 1 TEST-002, 2 TEST-001 (On hold), 3 P-9 (Closed), 4 A-1
function PItems([string]$show, [string]$search) { return "With({$pItemFix,LangNl:false,T:$tRec,varPrjShowInactive:$show,cmpPrjList:{SearchText:$search}},Concat($pItems,Text(ID),`",`"))" }
Assert-Eval (PItems 'false' '""') '4,2,1' 'Projects: default list hides Closed, shows On hold and blank Status; sorted by Project Number (A-1, TEST-001, TEST-002)'
Assert-Eval (PItems 'true' '""') '4,3,2,1' 'Projects: Show inactive on: Closed projects shown too (A-1, P-9, TEST-001, TEST-002)'
Assert-Eval (PItems 'If(false,true)' '""') '4,2,1' 'Projects: blank switch state = Closed hidden'
Assert-Eval (PItems 'true' '" test-00 "') '2,1' 'Projects: search on Project Number (trim, case-insensitive)'
Assert-Eval (PItems 'true' '"gam"') '3' 'Projects: search on Project Name'
Assert-Eval (PItems 'true' '"ede"') '2' 'Projects: search on City'
Assert-Eval (PItems 'true' '"cust"') '' 'Projects: Customer is not a search field'
$pProjFix = $pItemFix + ',cmpPrjList:{SearchText:""},LangNl:false,T:' + $tRec + ',varPrjShowInactive:true'
$md = [string][char]0x00B7
Assert-Eval "With({$pProjFix},Concat($pItemsAll,Title & ""|"" & Subtitle & ""|"" & Text(Inactive) & ""|"" & ChipText,"";""))" ("Delta|A-1|false|;Gamma|P-9 $md Venlo|true|Closed;Beta|TEST-001 $md Ede|false|On hold;Alpha|TEST-002 $md Delft|false|") 'Projects: Items projection: Title = Project Name, Subtitle = Project Number and City (no duplicate, no dangling separator), Inactive = Closed, ChipText Closed / On hold / empty'
Assert-Eval "With({colAdminProjects:Table({ID:1,Name:""N"",Number:""X-1"",Customer:"""",City:"""",Status:""Active""},{ID:2,Name:"""",Number:""X-2"",Customer:"""",City:""Ede"",Status:""Active""}),cmpPrjList:{SearchText:""""},LangNl:false,T:$tRec,varPrjShowInactive:false},Concat($pItemsAll,Title & ""|"" & Subtitle,"";""))" "N|X-1;X-2|X-2 $md Ede" 'Projects: blank city: Subtitle is only the number; blank name: Title falls back to the number'
Assert-True ((PGet 'cmpPrjList' 'SelectedID') -ceq '=Coalesce(varPrjSelectedID,0)') 'Projects: the selected ID goes to cmpListCard.SelectedID'

# (P17) Form card: header, status chip, sections GENERAL/ADDRESS/PEOPLE/LINKS on the 1-3 column grid, Last changed bottom right ----
$pTitleFx = (PGet 'lblPrjFormTitle' 'Text').TrimStart('=')
foreach ($c in @(@('"New"', 'New project'), @('"Edit"', 'Project details'), @('""', 'No project selected'), @('If(false,"x")', 'No project selected'))) { Assert-Eval "With({LangNl:false,T:$tRec,varPrjMode:$($c[0])},$pTitleFx)" $c[1] "Projects: header text for Mode $($c[0]) = $($c[1]) (no Project Number/Name repeated)" }
Assert-True ($pTitleFx.Contains('T.prjFormDetails') -and $pTitleFx.Contains('T.prjNoSelection') -and $pTitleFx.Contains('T.prjNewProject') -and ($pTitleFx -notmatch 'varPrjEdit') -and (-not $pIdx['lblPrjFormTitle']['Properties'].ContainsKey('Visible')) -and $formulas.Contains('prjFormDetails: {en: "Project details", nl: ""}')) 'Projects: header texts from T (prjFormDetails, prjNewProject, prjNoSelection), always visible'
$pFormChipText = (PGet 'btnPrjFormChip' 'Text')
# 03-11-2026 (Eddy, TP-HOME-02 point 8): New mode -> chip "New" (T.admChipNew) light blue #D5EDFF / #0303B8; Edit -> the SAVED status (green only for Active, grey otherwise); no selection -> hidden
$pChipFill = (PGet 'btnPrjFormChip' 'Fill').TrimStart('='); $pChipCol = (PGet 'btnPrjFormChip' 'Color').TrimStart('='); $pChipVis = (PGet 'btnPrjFormChip' 'Visible').TrimStart('=')
foreach ($c in @(@('"New"', '"Active"', 'true|New|#D5EDFF|#0303B8'), @('"New"', '"Closed"', 'true|New|#D5EDFF|#0303B8'), @('"Edit"', '"Active"', 'true|Active|#1AFF80|#000F41'), @('"Edit"', '"On hold"', 'true|On hold|#E6E6E6|#000000'), @('"Edit"', '"Closed"', 'true|Closed|#E6E6E6|#000000'), @('"Edit"', '""', 'false|||'), @('""', '""', 'false|||'), @('If(false,"x")', '"Active"', 'false|||'))) {
    Assert-Eval "With({LangNl:false,T:$tRec,varPrjMode:$($c[0]),varPrjEdit:{Status:$($c[1])}},If($pChipVis,""true|"" & $($pFormChipText.TrimStart('=')) & ""|"" & With({c:$pChipFill},$chipColName) & ""|"" & With({c:$pChipCol},$chipColName),""false|||""))" $c[2] "Projects chip: Mode $($c[0]), saved Status $($c[1]) -> visible|text|fill|colour = $($c[2])"
}
Assert-True (($pFormChipText -ceq '=If(Coalesce(varPrjMode,"")="New",If(LangNl && !IsBlank(T.admChipNew.nl),T.admChipNew.nl,T.admChipNew.en),varPrjEdit.Status)') -and ((PGet 'btnPrjFormChip' 'DisplayMode') -eq '=DisplayMode.Disabled') -and (-not $pIdx['btnPrjFormChip']['Properties'].ContainsKey('OnSelect')) -and ((PGet 'btnPrjFormChip' 'Visible') -ceq '=Coalesce(varPrjMode,"")="New" || (Coalesce(varPrjMode,"")="Edit" && !IsBlank(varPrjEdit.Status))') -and ((PGet 'btnPrjFormChip' 'X') -eq '=Parent.Width-24-Self.Width') -and ((PGet 'lblPrjFormTitle' 'Width') -eq '=Max(0,Parent.Width-48-84)')) 'Projects: status chip shows the SAVED status (varPrjEdit.Status) as text, static, hidden when Mode is empty, right-aligned on the card padding; reviewer N2 solved'
$pLay = [ordered]@{ X = '=If(Parent.Width>=1000,1,0)'; Y = '=If(Self.X=1,408,24)'; Width = '=If(Self.X=1,Max(0,Parent.Width-448),Parent.Width-64)'; Height = '=If(Self.X=1,24,500)' }
foreach ($k in $pLay.Keys) { Assert-True ((PGet 'lblPrjLayout' $k) -ceq $pLay[$k]) "Projects: layout carrier lblPrjLayout.$k as Contractors" }
Assert-True ((PGet 'lblPrjMetrics' 'X') -ceq '=If(lblPrjLayout.Width-48>=572,3,If(lblPrjLayout.Width-48>=376,2,1))' -and (PGet 'lblPrjMetrics' 'Y') -ceq '=lblPrjModified.Y+lblPrjModified.Height+24' -and (PGet 'lblPrjMetrics' 'Width') -ceq '=If(lblPrjLayout.X=1,Self.Height-48,452)' -and (PGet 'lblPrjMetrics' 'Height') -ceq '=If(lblPrjLayout.X=1,Max(conPrjBody.Height,Self.Y+48,568),lblPrjLayout.Height+Self.Y+24)' -and (PGet 'lblPrjGrid' 'Width') -ceq '=(lblPrjLayout.Width-48-16*(lblPrjMetrics.X-1))/lblPrjMetrics.X') 'Projects: grid carriers (columns 3/2/1 at content 572/376, gap 16; content height) as Contractors'
$pSecExp = [ordered]@{ lblPrjSecGeneral = '=lblPrjFormDivider.Y+1+20'; lblPrjSecAddress = '=lblPrjSecGeneral.Y+38+RoundUp(5/lblPrjMetrics.X,0)*74'; lblPrjSecPeople = '=lblPrjSecAddress.Y+38+RoundUp(5/lblPrjMetrics.X,0)*74'; lblPrjSecLinks = '=lblPrjSecPeople.Y+38+RoundUp(2/lblPrjMetrics.X,0)*74' }
foreach ($k in $pSecExp.Keys) { Assert-True ((PGet $k 'Y') -ceq $pSecExp[$k] -and (PGet $k 'Size') -eq '=12' -and (PGet $k 'FontWeight') -eq '=FontWeight.Bold' -and (PGet $k 'Height') -eq '=18') "Projects: section $k 12 Bold, top $($pSecExp[$k])" }
Assert-True ((PGet 'lblPrjModified' 'Y') -ceq '=lblPrjSecLinks.Y+38+74' -and (PGet 'lblPrjModified' 'Align') -eq '=Align.Right' -and (PGet 'lblPrjModified' 'X') -eq '=24' -and (PGet 'lblPrjModified' 'Width') -eq '=lblPrjLayout.Width-48' -and (PGet 'lblPrjModified' 'Size') -eq '=12') 'Projects: "Last changed in SharePoint" bottom right, under LINKS (no Active switch row)'
$pGrid = [ordered]@{ General = @('Name', 'Number', 'Reference', 'Customer', 'Status'); Address = @('Street', 'HouseNumber', 'PostalCode', 'City', 'Country'); People = @('Leader', 'SiteManager'); Links = @('Url') }
$pCtlOf = @{ Name = 'cmpPrjName'; Number = 'cmpPrjNumber'; Reference = 'cmpPrjReference'; Customer = 'cmpPrjCustomer'; Status = 'cmpPrjStatus'; Street = 'cmpPrjStreet'; HouseNumber = 'cmpPrjHouseNumber'; PostalCode = 'cmpPrjPostalCode'; City = 'cmpPrjCity'; Country = 'cmpPrjCountry'; Leader = 'cmpPrjLeader'; SiteManager = 'cmpPrjSiteManager'; Url = 'cmpPrjUrl' }
foreach ($s in $pGrid.Keys) {
    for ($n = 0; $n -lt $pGrid[$s].Count; $n++) {
        $f = $pGrid[$s][$n]; $ct = $pCtlOf[$f]; $sec = "lblPrjSec$s"
        $xx = if ($n -eq 0) { '=24' } else { "=24+Mod($n,lblPrjMetrics.X)*(lblPrjGrid.Width+16)" }
        $yy = if ($n -eq 0) { "=$sec.Y+30" } else { "=$sec.Y+30+RoundDown($n/lblPrjMetrics.X,0)*74" }
        $ww = if ($f -eq 'Url') { '=lblPrjLayout.Width-48' } else { '=lblPrjGrid.Width' }
        Assert-True (((PGet $ct 'X') -ceq $xx) -and ((PGet $ct 'Y') -ceq $yy) -and ((PGet $ct 'Width') -ceq $ww) -and ((PGet $ct 'Height') -eq '=58')) "Projects: $s field $n ($f): cmpField at the grid cell, 58 high (label 18 + 4 + field 36)$(if ($f -eq 'Url') { ', full content width' })"
    }
}
Assert-True (@($pIdx.Keys | Where-Object { $pIdx[$_]['Properties'].ContainsKey('Required') -and $pIdx[$_]['Properties']['Required'] -eq '=true' }).Count -eq 3) 'Projects: exactly 3 required fields (Project Name, Project Number, Status)'
foreach ($k in @($pTextFields.Keys) + @($pDropFields.Keys)) { $f = if ($pTextFields.Contains($k)) { $pTextFields[$k] } else { $pDropFields[$k] }; $er = "CountIf(colPrjSaveErrors,Field=""$f"")>0"; Assert-Eval "With({colPrjSaveErrors:Table({Field:`"$f`",Message:`"x`"})},$((PGet $k 'Invalid').TrimStart('=')))" $true "Projects: $k.Invalid true with an error on Field=$f"; Assert-Eval "With({colPrjSaveErrors:Table({Field:`"Other`",Message:`"x`"})},$((PGet $k 'Invalid').TrimStart('=')))" $false "Projects: $k.Invalid false without an error on Field=$f" }
$pFields = @([regex]::Matches($pSave, 'Collect\(colPrjSaveErrors,\{Field:"(\w*)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True (@($pFields | Where-Object { $_ -ne '' -and $_ -cnotin $pWritten }).Count -eq 0) "Projects: every collected error Field is an input field or '' ($($pFields -join ','))"
Assert-True ((PGet 'cmpPrjName' 'Enabled') -ceq $pFieldGuard) 'Projects: inputs editable only when Loaded, idle, no failed save, New/Edit (else Disabled: the field box always renders)'
$pFormKids = @($pIdx['conPrjFormCard']['Children'] | ForEach-Object { @($_.Keys)[0] })
$pExpKids = 'lblPrjFormTitle,btnPrjFormChip,lblPrjFormDivider,lblPrjSecGeneral,cmpPrjName,cmpPrjNumber,cmpPrjReference,cmpPrjCustomer,cmpPrjStatus,lblPrjSecAddress,cmpPrjStreet,cmpPrjHouseNumber,cmpPrjPostalCode,cmpPrjCity,cmpPrjCountry,lblPrjSecPeople,cmpPrjLeader,cmpPrjSiteManager,lblPrjSecLinks,cmpPrjUrl,lblPrjModified'
Assert-True (($pFormKids -join ',') -ceq $pExpKids) "Projects: conPrjFormCard children: $($pFormKids -join ',')"
Assert-True ((@($pIdx['conPrjCanvas']['Children'] | ForEach-Object { @($_.Keys)[0] }) -join ',') -ceq 'cmpPrjList,conPrjFormCard') 'Projects: canvas children = list card instance and form card (debug line removed)'
foreach ($cp in @(@('cmpPrjList', 'X', '=24'), @('cmpPrjList', 'Y', '=24'), @('cmpPrjList', 'Width', '=If(lblPrjLayout.X=1,360,Parent.Width-64)'), @('cmpPrjList', 'Height', '=lblPrjMetrics.Width'), @('conPrjFormCard', 'X', '=lblPrjLayout.Y'), @('conPrjFormCard', 'Y', '=lblPrjLayout.Height'), @('conPrjFormCard', 'Width', '=lblPrjLayout.Width'), @('conPrjFormCard', 'Height', '=If(lblPrjLayout.X=1,lblPrjMetrics.Height-48,lblPrjMetrics.Y)'), @('conPrjFormCard', 'DropShadow', '=DropShadow.Light'), @('conPrjBody', 'Y', '=cmpPrjMsgBar.Y+cmpPrjMsgBar.Height'), @('conPrjBody', 'Height', '=Max(0,cmpPrjFooter.Y-Self.Y)'))) {
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
Assert-True ((($pKids[0..1] -join ',') -ceq 'cmpPrjTitle,cmpPrjMsgBar') -and ($pKids[-1] -eq 'cmpPrjFooter')) 'Projects: children order title bar instance, message bar instance ... footer instance (as Contractors)'
Assert-True ((PGet 'cmpPrjTitle' 'Height') -eq '=60' -and (PGet 'cmpPrjTitle' 'Title') -ceq ('=' + (TT 'prjTitle')) -and (PGet 'cmpPrjTitle' 'Logo') -eq '=GEA_logo_white' -and (PGet 'cmpPrjTitle' 'Busy') -ceq '=Coalesce(varPrjBusy,false) || Coalesce(varPrjSaving,false) || varPrjLoadState="Loading"' -and (PGet 'cmpPrjTitle' 'BusyLabel') -ceq ('=' + (TT 'prjBusy'))) 'Projects: title bar instance 60 px, title "Projects" from T, logo GEA_logo_white, Busy = busy || saving || Loading'
Assert-True (($pIdx['cmpPrjFooter']['Control'] -eq 'CanvasComponent') -and ($pIdx['cmpPrjFooter']['ComponentName'] -eq 'cmpFooter') -and ((PGet 'cmpPrjFooter' 'Y') -eq '=Parent.Height-Self.Height') -and ((PGet 'cmpPrjFooter' 'Height') -eq '=68') -and ((PGet 'cmpPrjFooter' 'HomeText') -match 'T\.prjHome') -and ((PGet 'cmpPrjFooter' 'NewText') -match 'T\.prjNew') -and ((PGet 'cmpPrjFooter' 'RefreshText') -match 'T\.prjRefresh') -and ((PGet 'cmpPrjFooter' 'DiscardText') -match 'T\.prjDiscard') -and ((PGet 'cmpPrjFooter' 'SaveText') -match 'T\.prjSave')) 'Projects: footer = cmpFooter instance anchored at the bottom (68), texts from T; widths, order and role colours are pinned in the component (Test-FooterRow, Test-GeaColors)'
$homeDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'scrHome.pa.yaml'))); $homeIdx2 = @{}; Index-Controls $homeDoc['Screens']['scrHome']['Children'] $homeIdx2
Assert-True ($homeIdx2['cmpTileProjects']['Properties']['OnSelect'] -eq '=Navigate(scrProjects); true' -and $homeIdx2['cmpTileProjects']['Properties']['Active'] -eq '=true' -and $homeIdx2['cmpTileContractors']['Properties']['OnSelect'] -eq '=Navigate(scrContractors); true' -and $homeIdx2['cmpTileProjects']['ComponentName'] -eq 'cmpTile') 'Home: Projects and Contractors tiles are active cmpTile instances (Navigate(scrProjects) / Navigate(scrContractors)); Home layout (tile size, wrap, no overlap at 1366/1000/700) is pinned in Test-Layout'
$edState = [IO.File]::ReadAllText((Join-Path $srcDir '_EditorState.pa.yaml'))
Assert-True ($edState -match '(?m)^\s+- scrProjects\s*$') 'Projects: scrProjects listed in _EditorState ScreensOrder'

# (P19) Studio FAIL build adminpattern-20261030_071949 (Eddy 30-10-2026): items 4, 5, a, d, e, f (helpers from section 17) ------
# Item 4: same cause as on Contractors (View fallback rendered the empty inputs invisibly); all inputs always render.
foreach ($c in @($pTextFields.Keys) + @($pDropFields.Keys) + @('cmpPrjLeader', 'cmpPrjSiteManager')) { $fp = $pIdx[$c]['Properties'];
    Assert-True ((-not $fp.ContainsKey('Visible')) -and (@($pIdx['conPrjFormCard']['Children'] | ForEach-Object { @($_.Keys)[0] }) -ccontains $c) -and ($fp['Height'] -eq '=58')) "Projects : $c is always rendered (no Visible formula), a direct child of conPrjFormCard, height 58" }
$pFieldFix = 'varPrjLoadState:"Loaded",colPrjLoadErrors:Filter(Table({Message:""}),false),varPrjBusy:false,varPrjSaving:false,varPrjSaveFailed:false,varPrjMode:"Edit"'
Assert-Eval "With({$pFieldFix},$($pFieldGuard.Substring(1)))" $true 'Projects : cmpField.Enabled true: Loaded, idle, Edit'
foreach ($m in @('""', 'If(false,"x")')) { Assert-Eval "With({$($pFieldFix -replace 'Mode:"Edit"', "Mode:$m")},$($pFieldGuard.Substring(1)))" $false "Projects : no record in the form (Mode $m): all fields Disabled (rendered, not editable)" }
Assert-True ($pText -notmatch 'DisplayMode\.View') 'Projects: no DisplayMode.View on the screen'
# Item 5: auto-select the first visible row after a successful load
$prjEmpty = '{ID:Blank(),Name:"",Number:"",Reference:"",Customer:"",Status:"",Street:"",HouseNumber:"",PostalCode:"",City:"",Country:"",Leader:"",SiteManager:"",Url:""}'
Test-AutoSelect $pLoad $pItems '' (PGet 'galPrjList' 'OnSelect') 'Prj' 'colAdminProjects' $prjEmpty $pDirty 'Projects'
foreach ($c in @(@('false', '""', '4', 'first visible row by Project Number (A-1; Closed hidden)'), @('true', '""', '4', 'Show inactive on: A-1 still first'), @('false', '"test"', '2', 'search filter applied (TEST-001)'), @('true', '"p-9"', '3', 'Closed row selectable when shown'))) {
    Assert-Eval "With({$pItemFix,LangNl:false,T:$tRec,varPrjShowInactive:$($c[0]),cmpPrjList:{SearchText:$($c[1])}},Text(First($pItems).ID))" $c[2] "Projects auto-select: $($c[3]) -> ID $($c[2])"
}
Assert-Eval "With({$pItemFix,LangNl:false,T:$tRec,varPrjShowInactive:false,cmpPrjList:{SearchText:`"p-9`"}},IsBlank(First($pItems).ID))" $true 'Projects auto-select: only a hidden Closed project matches -> no selection (Mode "")'
Assert-Eval "With({colAdminProjects:Filter(Table({ID:1,Name:`"`",Number:`"`",Customer:`"`",City:`"`",Status:`"`"}),false),LangNl:false,T:$tRec,varPrjShowInactive:false,cmpPrjList:{SearchText:`"`"}},IsBlank(First($pItems).ID))" $true 'Projects auto-select: empty list -> no selection'
$pNoErr = 'Filter(Table({Message:""}),false)'
$prjDiscCases = @(@('false', '""', '1', '"Loaded"', $pNoErr, '1', 'previous record visible -> restored'),
    @('false', '""', '2', '"Loaded"', $pNoErr, '2', 'previous record On hold (always visible) -> restored'),
    @('false', '""', '3', '"Loaded"', $pNoErr, '4', 'previous record Closed, Show closed off -> first visible row'),
    @('true', '""', '3', '"Loaded"', $pNoErr, '3', 'previous Closed record shown (Show closed on) -> restored'),
    @('false', '""', '99', '"Loaded"', $pNoErr, '4', 'previous record no longer in the loaded list -> first visible row'),
    @('false', '""', 'If(false,0)', '"Loaded"', $pNoErr, '4', 'no previous record -> first visible row'),
    @('false', '"test-001"', '1', '"Loaded"', $pNoErr, '2', 'previous record hidden by the search text -> first visible row'),
    @('false', '"nomatch"', '1', '"Loaded"', $pNoErr, 'blank', 'empty visible list -> no selection (Mode "")'),
    @('false', '""', '1', '"Failed"', $pNoErr, 'blank', 'load not Loaded -> no selection'),
    @('false', '""', '1', '"Loaded"', 'Table({Message:"x"})', 'blank', 'load errors present -> no selection'))
Test-DiscardNew 'Prj' 'Projects' $pGuards.btnPrjDiscard $pDirty (PGet 'btnPrjDiscard' 'OnSelect') (PGet 'btnPrjNew' 'OnSelect') $pLoad $pItems 'colAdminProjects' $prjEmpty $pItemFix $prjDiscCases $pAll
Assert-Eval (PG 'btnPrjDiscard' $pClean.Replace('varPrjMode:"Edit"', 'varPrjMode:"New"')) $true 'Projects 8b: Discard allowed in New mode with a clean form'
Assert-Eval (PG 'btnPrjDiscard' $pClean.Replace('varPrjMode:"Edit"', 'varPrjMode:"New"').Replace('varPrjSaving:false', 'varPrjSaving:true')) $false 'Projects 8b: Discard in New mode blocked while saving'
Assert-Eval (PG 'btnPrjDiscard' $pClean.Replace('varPrjMode:"Edit"', 'varPrjMode:"New"').Replace('varPrjBusy:false', 'varPrjBusy:true')) $false 'Projects 8b: Discard in New mode blocked while loading'
Assert-Eval (PG 'btnPrjDiscard' $pClean.Replace('varPrjMode:"Edit"', 'varPrjMode:""')) $false 'Projects 8b: Discard stays disabled without a record in the form (clean)'
# Item d: SharePoint refusal (nothing written) keeps Loaded and the input; partial write / verify failure -> Failed
Test-WriteCounter $pSave 'Prj' 'Projects' 'Projects'
Assert-Eval (PG 'btnPrjSave' $pFix) $true 'Projects: after a refused save (Loaded, SaveFailed false, input kept) Save is allowed again (retry)'
Assert-True ($pPatchErrRec.Contains('T.prjErrSharePoint.en') -and $pSave.Contains('Set(varPrjPatchError,true); Collect(colPrjSaveErrors,{Field:If("duplicate" in Lower(FirstError.Message)')) 'Projects: Patch error branch sets the flag and keeps the duplicate mapping (red Project Number)'
# Item a: a stored Status/Country outside Choices is shown as-is (extra option for this record only), never counts as a change,
# is not blocked by the Status validation when unchanged, and is written back unchanged as {Value: <stored>}.
$chS = 'Table({Value:"Active"},{Value:"On hold"},{Value:"Closed"})'; $chC = 'Table({Value:"Netherlands"},{Value:"Germany"})'
# Status/Country items outside the list are appended by cmpField (tested in Test-Components); the dirty/Save checks below use the unchanged stored value.
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
$pInS = 'CountIf(Choices([@Projects].Status),Value=varPrjSaveRec.Status)>0'; $pInC = 'CountIf(Choices([@Projects].Country),Value=varPrjSaveRec.Country)>0'
Assert-True ($pSave.Contains("Set(varPrjSaveStatusInList,$pInS);") -and $pSave.Contains("Set(varPrjSaveCountryInList,$pInC);")) 'Projects a/N3: in-list flags = CountIf(Choices(...),Value=<save value>)>0'
$stCond = (Split-Args $stVal.Substring(1, $stVal.Length - 2))[0].Replace('varPrjSaveStatusInList', '(' + $pInS.Replace('Choices([@Projects].Status)', 'chS') + ')')
foreach ($c in @(@('"Edit"', '"Archived"', '"Archived"', $false, 'Edit, unknown value unchanged: accepted'), @('"Edit"', '"Archived"', '"Retired"', $true, 'Edit, other unknown value: error'), @('"New"', '""', '"Archived"', $true, 'New with an unknown value: error'), @('"Edit"', '"Archived"', '""', $true, 'empty Status: error (required)'), @('"Edit"', '"Active"', '"Closed"', $false, 'known value: accepted'))) {
    Assert-Eval "With({chS:$chS,varPrjSaveMode:$($c[0]),varPrjEdit:{Status:$($c[1])},varPrjSaveRec:{Status:$($c[2])}},$stCond)" $c[3] "Projects a/e: Status validation: $($c[4])"
}
$pInUnk = PIn '"TEST Project 2"' '"TEST-002"' '""' '"Archived"' '"Belgium"' '""'
Assert-Eval "With({$pInUnk},With($pSrFx,Status & `"|`" & Country))" 'Archived|Belgium' 'Projects a: the save record keeps the unchanged unknown values (verify compares them; N3 decides whether they are in the Patch record)'
Assert-Eval (PVerify $pRawUnk (PIn '"TEST Project 2"' '"TEST-002"' '""' '"Archived"' '"Belgium"' '""') 'F') '' 'Projects a/N3: verify passes when the unknown values were not written (SharePoint still holds them unchanged)'
# N3 (03-11-2026): an unchanged Status/Country outside the current choice list is NOT written (left out of the Patch record);
# changed values and every value of a New record are written as {Value: ...}. Flags evaluated on the real Save text, the shape
# picked exactly like the If in the write step (Status && Country -> shape 1, Status -> 3, Country -> 5, else 6).
function PFlag([string]$name) { $b = Get-Balanced $pSave ($pSave.IndexOf("Set($name,") + 3); return $b.Substring($name.Length + 2, $b.Length - $name.Length - 3) }
$pWsFx = PFlag 'varPrjSaveWriteStatus'; $pWcFx = PFlag 'varPrjSaveWriteCountry'
$pInEnv = "varPrjSaveStatusInList:$($pInS.Replace('Choices([@Projects].Status)', 'chS')),varPrjSaveCountryInList:$($pInC.Replace('Choices([@Projects].Country)', 'chC'))"
foreach ($c in @(@('"Edit"', '"Archived"', '"Belgium"', '"Archived"', '"Belgium"', 'false|false', 'unknown Status and Country unchanged: neither written'),
                @('"Edit"', '"Archived"', '"Belgium"', '"Active"', '"Belgium"', 'true|false', 'Status changed to a list value: Status written, unchanged unknown Country not'),
                @('"Edit"', '"Archived"', '"Belgium"', '"Archived"', '"Germany"', 'false|true', 'Country changed: Country written, unchanged unknown Status not'),
                @('"Edit"', '"Archived"', '"Belgium"', '"Retired"', '"Belgium"', 'true|false', 'Status changed to another unknown value: counted as written (the validation blocks it)'),
                @('"Edit"', '"Active"', '"Netherlands"', '"Active"', '"Netherlands"', 'true|true', 'list values unchanged: written as before'),
                @('"Edit"', '"Active"', '""', '"Active"', '""', 'true|true', 'blank Country unchanged: written as Blank() as before'),
                @('"New"', '"Active"', '"Belgium"', '"Active"', '"Belgium"', 'true|true', 'New record: always written'))) {
    $fx = "With({chS:$chS,chC:$chC,varPrjSaveMode:$($c[0]),varPrjEdit:{Status:$($c[1]),Country:$($c[2])},varPrjSaveRec:{Status:$($c[3]),Country:$($c[4])}},With({$pInEnv},Text($pWsFx) & ""|"" & Text($pWcFx)))"
    Assert-Eval $fx $c[5] "Projects N3: $($c[6]) -> WriteStatus|WriteCountry = $($c[5])"
    $ws = $c[5].StartsWith('true'); $wc = $c[5].EndsWith('true'); $si = if ($ws -and $wc) { 1 } elseif ($ws) { 3 } elseif ($wc) { 5 } else { 6 }
    Assert-True (($pShape[$si].Contains('Status') -eq $ws) -and ($pShape[$si].Contains('Country') -eq $wc)) "Projects N3: $($c[6]) -> Patch record (shape $si) has Status: $ws, Country: $wc"
}
# 08-11-2026 (Workers build, ADMIN_PLAN 5.3): Projects like Contractors: a NEW or CHANGED Country outside Choices([@Projects].Country)
# is an error on field Country (T.prjErrCountry "Fix: Country unknown"), decided in the local validation before the first read/write;
# an unchanged legacy value stays accepted and is not written (N3 shape above).
$pCoTxt = 'If(!IsBlank(varPrjSaveRec.Country) && !varPrjSaveCountryInList && !(varPrjSaveMode="Edit" && varPrjSaveRec.Country=Trim(varPrjEdit.Country & "")),Collect(colPrjSaveErrors,{Field:"Country",Message:' + (TT0 'prjErrCountry') + '}));'
$iPCo = $pSaveN.IndexOf((Norm $pCoTxt)); $iPFirstIO = $pSaveN.IndexOf('If(IsEmpty(colPrjSaveErrors),IfError(Refresh(Projects),'); $iPIn = $pSaveN.IndexOf('Set(varPrjSaveCountryInList,')
Assert-True ($iPCo -gt $iPIn -and $iPIn -gt 0 -and $iPFirstIO -gt $iPCo -and ([regex]::Matches($pSave, [regex]::Escape('{Field:"Country",Message:'))).Count -eq 1) 'Projects: unknown Country -> error on field Country (T.prjErrCountry) after the in-list flag, before the first read/write'
Assert-Eval "With({LangNl:false,T:$tRec},T.prjErrCountry.en & `"|`" & T.prjErrCountry.nl)" 'Fix: Country unknown|' 'Projects: T.prjErrCountry = "Fix: Country unknown" (nl empty)'
$pCoCond = (Split-Args (Get-Balanced $pCoTxt 2).Substring(1, (Get-Balanced $pCoTxt 2).Length - 2))[0]
foreach ($c in @(@('"Edit"', '"Belgium"', '"Belgium"', $false, 'legacy value outside the list unchanged: accepted (not written, N3)'), @('"Edit"', '"Belgium"', '"Atlantis"', $true, 'changed to another unknown value: error'), @('"Edit"', '"Netherlands"', '"Germany"', $false, 'changed to a list value: accepted'), @('"Edit"', '"Germany"', '""', $false, 'cleared: accepted (written as Blank())'), @('"New"', '""', '"Belgium"', $true, 'New with an unknown value: error'), @('"New"', '""', '"Netherlands"', $false, 'New with a list value: accepted'))) {
    Assert-Eval "With({chC:$chC,varPrjSaveMode:$($c[0]),varPrjEdit:{Country:$($c[1])},varPrjSaveRec:{Country:$($c[2])}},With({varPrjSaveCountryInList:$($pInC.Replace('Choices([@Projects].Country)', 'chC'))},$pCoCond))" $c[3] "Projects Country: $($c[4]) -> error=$($c[3])"
}
# Item e: Project Name stays required (validation present, red star)
Assert-True ($pSaveN.Contains('If(IsBlank(varPrjSaveRec.Name),Collect(colPrjSaveErrors,{Field:"Name"') -and (PGet 'cmpPrjName' 'Required') -eq '=true') 'Projects e: Project Name required (validation + required field)'
# Item f: varPrjEdit (saved status source for the chip) only from the loaded list, the verify read or the empty/New snapshot
$prjEditSets = Get-SetValues $pText 'varPrjEdit'
Assert-True ($prjEditSets.Count -ge 3 -and @($prjEditSets | Where-Object { $_ -notmatch '^(LookUp\(colAdminProjects,ID=varPrjSelectedID\)|First\(colPrjVerify\)|\{ID:Blank\(\),.*\})$' }).Count -eq 0) "Projects f: varPrjEdit only from the loaded list, the verify read or the empty/New snapshot ($($prjEditSets -join ' | '))"
# (PD) 01-11-2026 Studio FAIL A on Projects: dirty false right after load and after select, with the dropdowns Status and Country
# (as-is row for a value outside Choices, blank = no selection) evaluated with the cmpField Value formula.
function Prj-Inputs([string]$statusOverride) {
    $parts = @()
    foreach ($k in $pTextFields.Keys) { $parts += "${k}:$(CV-Rec "varPrjEdit.$($pTextFields[$k])" 'text')" }
    foreach ($k in $pDropFields.Keys) { $v = "varPrjEdit.$($pDropFields[$k])"; if ($k -eq 'cmpPrjStatus' -and $statusOverride -ne '') { $v = $statusOverride }; $parts += "${k}:$(CV-Rec $v 'dropdown')" }
    return ($parts -join ',')
}
$pLblDirtyFx = ([string]$pIdx['lblPrjDirty']['Properties']['Text']).Trim().TrimStart('=')
$pdT = 'If(false,"x")'; $pdC = 'If(false,{Value:"x"})'; $pdP = 'If(false,{DisplayName:"x"})'  # own names: $bc (= $bC, PowerShell is case-insensitive) is reused for message bodies above
$pRawRows = @((PRaw '"Alpha"' '"TEST-002"' '"Delft"' '{Value:"Active"}' '{Value:"Netherlands"}' '" x "' '{DisplayName:"P"}').Replace('{ID:7,', '{ID:1,'), (PRaw '"Beta"' '"TEST-001"' $pdT '{Value:"Archived"}' $pdC $pdT $pdP).Replace('{ID:7,', '{ID:2,'), (PRaw $pdT '"A-1"' '"Ede"' $pdC '{Value:"Belgium"}' '""' $pdP).Replace('{ID:7,', '{ID:3,'))
$pLoadedCol = 'Table(' + (($pRawRows | ForEach-Object { PProj $_ }) -join ',') + ')'
$pLoadEnv = "colAdminProjects:$pLoadedCol,LangNl:false,T:$tRec,varPrjShowInactive:false,cmpPrjList:{SearchText:`"`"}"
Assert-Eval "With({$pLoadEnv},Text(First($pItems).ID))" '3' 'Projects dirty fixture: load auto-selects ID 3 (A-1 first by number)'
Assert-Eval "With({$pLoadEnv},With({varPrjMode:`"Edit`",varPrjEdit:LookUp(colAdminProjects,ID=First($pItems).ID)},With({$(Prj-Inputs '')},$pLblDirtyFx)))" 'false' 'Projects: dirty false right after load (auto-selected row; blank Status = no selection, Country Belgium)'
foreach ($id in 1, 2, 3) { Assert-Eval "With({$pLoadEnv},With({varPrjMode:`"Edit`",varPrjEdit:LookUp(colAdminProjects,ID=$id)},With({$(Prj-Inputs '')},$pLblDirtyFx)))" 'false' "Projects: dirty false after selecting row $id (row 2: Status Archived outside Choices shown as-is, blank Country)" }
Assert-Eval "With({varPrjMode:`"New`",varPrjEdit:{ID:Blank(),Name:`"`",Number:`"`",Reference:`"`",Customer:`"`",Status:`"Active`",Street:`"`",HouseNumber:`"`",PostalCode:`"`",City:`"`",Country:`"Netherlands`",Leader:`"`",SiteManager:`"`",Url:`"`"}},With({$(Prj-Inputs '')},$pLblDirtyFx))" 'false' 'Projects: dirty false after New (Status Active, Country Netherlands preselected)'
Assert-Eval "With({$pLoadEnv},With({varPrjMode:`"Edit`",varPrjEdit:LookUp(colAdminProjects,ID=1)},With({$(Prj-Inputs $emptyQ)},$pLblDirtyFx)))" 'true' 'Projects: dirty true when the Status dropdown shows no selection while Active was loaded'
# 07-11-2026 (Eddy, after 3 empty Employers records EMP-007/008/009 of 4-11): Save with an empty name (New and Edit, spaces only too)
# is blocked with zero reads/writes, on every path: the name error is collected before the one gate that encloses every SharePoint
# read and every Patch; double click = second OnSave sees varXxxSaving (set as first action) or, after a successful New, Edit + clean;
# Save after Discard needs mode New/Edit and lblXxxDirty "true" again (Discard resets the inputs and leaves New).
function Get-RawOnSave([string]$scr) { $raw = [IO.File]::ReadAllText((Join-Path $srcDir "$scr.pa.yaml")); $a = $raw.IndexOf('OnSave: |-'); $b = $raw.IndexOf('RefreshText:', $a); return ($raw.Substring($a + 10, $b - $a - 10).Trim().TrimStart('=') -replace "`r", '') }
foreach ($ns in @(@('Emp', (Get-RawOnSave 'scrContractors'), 'Employers', 'empErrNameRequired', 2), @('Prj', (Get-RawOnSave 'scrProjects'), 'Projects', 'prjErrNameRequired', 4))) {
    $p = $ns[0]; $sv = [string]$ns[1]; $list = $ns[2]; $key = $ns[3]; $nPatch = $ns[4]
    $outer = Get-Balanced $sv 2; $oArgs = Split-Args $outer.Substring(1, $outer.Length - 2)
    $g = $oArgs[0].Trim(); $body = $oArgs[1]
    foreach ($k in @("!Coalesce(var${p}Saving,false)", "!Coalesce(var${p}Busy,false)", "!Coalesce(var${p}SaveFailed,false)", "(var${p}Mode=`"New`" || (var${p}Mode=`"Edit`" && !IsBlank(var${p}SelectedID)))", "lbl${p}Dirty.Text=`"true`"")) { Assert-True ($g.Contains($k)) "${list}: Save guard contains $k (double click / Save after Discard blocked)" }
    Assert-True ($body.TrimStart().StartsWith("Set(var${p}Saving,true);")) "${list}: varXxxSaving is set as the very first action of Save (second click blocked)"
    Assert-True ($sv.Contains("Name:Trim(cmp${p}Name.Value & `"`")")) "${list}: save name = Trim(cmp${p}Name.Value & `"`") (spaces only = blank)"
    $req = "If(IsBlank(var${p}SaveRec.Name),Collect(col${p}SaveErrors,{Field:`"Name`",Message:" + (TT0 $key) + '}));'
    $iReq = $sv.IndexOf($req); $gateTxt = "If(IsEmpty(col${p}SaveErrors),"; $iGate = $sv.IndexOf("`n" + (' ' * 15) + $gateTxt)
    Assert-True ($iReq -gt 0 -and $iGate -gt $iReq) "${list}: empty-name error (Field Name, T.$key) is collected before the read/write gate"
    $gStart = $iGate + 1 + 15 + 2; $gate = Get-Balanced $sv $gStart; $gEnd = $gStart + $gate.Length
    $io = [regex]::Matches($sv, "Refresh\(|Patch\(|Filter\(($list|Employers|Projects|Workers|'Assignment Periods'|'Project Workers'),")
    $outside = @($io | Where-Object { ($_.Index -lt $gStart -or $_.Index -ge $gEnd) -and !($_.Value -eq 'Refresh(' -and $sv.Substring($_.Index, 16) -eq 'Refresh(Workers)' -and $_.Index -gt $gEnd) })
    Assert-True ($io.Count -gt 0 -and $outside.Count -eq 0) "${list}: every SharePoint read and every Patch lies inside If(IsEmpty(col${p}SaveErrors),...) (zero writes on a validation error)"
    Assert-True (([regex]::Matches($gate, "Patch\($list,")).Count -eq $nPatch -and ([regex]::Matches($sv, "Title:var${p}SaveRec\.Name")).Count -eq $nPatch) "${list}: all $nPatch Patch shapes write Title = the validated var${p}SaveRec.Name"
    Assert-Eval "With({var${p}SaveRec:{Name:Trim(`"   `" & `"`")}},Text(IsBlank(var${p}SaveRec.Name)))" 'true' "${list}: a name of spaces only counts as empty"
}
Write-Output 'PASS Test-AdminScreens (Projects): static structure only. Studio import, binding (Choices/[@Projects], Hyperlink URL, person DisplayName), delegation (Monitor), SharePoint case-sensitivity of ''Project Number'' = and functional tests NOT verified.'
# =====================================================================================================================
# Build 3 (08-11-2026): Workers (scrWorkers, list Workers; ADMIN_PLAN.md par. 5, decisions V1-V6). Same admin pattern as Contractors;
# fields First Name*, Surname*, Worker Code (read-only, flow MS-017), Trade*, Contractor* (Employer lookup via the loaded Employers),
# Language*, Active. Rules: validation before IO, duplicate warning + "Save anyway", deactivation blocked by an active Project Workers
# link, N3 for legacy Trade/Language, one Patch, conflict + verify. Proves source structure only (no Studio import/binding/delegation).
# =====================================================================================================================
$wScreen = 'scrWorkers'
$wDoc = $builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir "$wScreen.pa.yaml")))
$script:formulas = 0; $script:failures = 0
Check-Node $wDoc $wScreen
if ($script:failures -gt 0) { throw 'FAIL Power Fx syntax in scrWorkers' }
Assert-True $true "Workers: Power Fx syntax: $script:formulas formulas in scrWorkers parsed"
$formulas = [string]$appDoc['App']['Properties']['Formulas']
$script:names = @{}; $script:controlCount = 0
foreach ($entry in $wDoc['Screens'][$wScreen]['Children']) { Check-Control $entry }
Assert-True ($script:controlCount -gt 0) "Workers: control templates/properties valid ($script:controlCount controls)"
$wIdx = @{}; Index-Controls $wDoc['Screens'][$wScreen]['Children'] $wIdx
$wScreenProps = $wDoc['Screens'][$wScreen]['Properties']
$wAll = @{}
foreach ($n in $wIdx.Keys) { foreach ($pp in $wIdx[$n]['Properties'].Keys) { $wAll["$n.$pp"] = ([string]$wIdx[$n]['Properties'][$pp]) } }
foreach ($pp in $wScreenProps.Keys) { $wAll["$wScreen.$pp"] = [string]$wScreenProps[$pp] }
$wRawOnSelect = @{}; foreach ($k in @($wAll.Keys)) { $wRawOnSelect[$k] = $wAll[$k] }
Apply-DirtyLabel $wAll 'Wrk' 'Workers'; $wDirtyFromLbl = $script:lastDirty
# compatibility layer (same as Contractors/Projects): footer/list/message-bar handlers under their historical control names
$wFooterMap = [ordered]@{ btnWrkHome = 'Home'; btnWrkNew = 'New'; btnWrkRefresh = 'Refresh'; btnWrkDiscard = 'Discard'; btnWrkSave = 'Save' }
Assert-True ($wIdx['cmpWrkFooter']['Control'] -eq 'CanvasComponent' -and $wIdx['cmpWrkFooter']['ComponentName'] -eq 'cmpFooter' -and $wIdx['cmpWrkTitle']['ComponentName'] -eq 'cmpTitleBar' -and $wIdx['cmpWrkMsgBar']['ComponentName'] -eq 'cmpMessageBar' -and $wIdx['cmpWrkList']['ComponentName'] -eq 'cmpListCard') 'Workers: title bar, message bar, list card and footer are the admin components (cmpTitleBar, cmpMessageBar, cmpListCard, cmpFooter)'
foreach ($k in $wFooterMap.Keys) {
    $v = $wFooterMap[$k]; $en = ([string]$wAll["cmpWrkFooter.${v}Enabled"]).Trim(); $os = ([string]$wAll["cmpWrkFooter.On$v"]).Trim()
    Assert-True ($en.StartsWith('=') -and $en.Length -gt 3 -and $os.StartsWith('=If(' + $en.Substring(1) + ',')) "Workers: cmpWrkFooter.On$v starts with the same guard text as ${v}Enabled (fail-closed)"
    $wAll["$k.OnSelect"] = $wAll["cmpWrkFooter.On$v"]; $wAll["$k.DisplayMode"] = '=If(' + $en.Substring(1) + ',DisplayMode.Edit,DisplayMode.Disabled)'
    $wAll.Remove("cmpWrkFooter.On$v"); $wAll.Remove("cmpWrkFooter.${v}Enabled")
}
$wlEn = ([string]$wAll['cmpWrkList.Enabled']).Trim()
Assert-True (([string]$wAll['cmpWrkList.OnSelectRow']).Trim().StartsWith('=If(' + $wlEn.Substring(1) + ',') -and ([string]$wAll['cmpWrkList.OnToggleShowInactive']).Trim().StartsWith('=If(' + $wlEn.Substring(1) + ',')) 'Workers: cmpWrkList.Enabled is the first If-condition of OnSelectRow and OnToggleShowInactive'
$wAll['galWrkList.OnSelect'] = $wAll['cmpWrkList.OnSelectRow']; $wAll['galWrkList.DisplayMode'] = '=If(' + $wlEn.Substring(1) + ',DisplayMode.Edit,DisplayMode.Disabled)'; $wAll['galWrkList.Items'] = $wAll['cmpWrkList.Items']
foreach ($rm in 'cmpWrkList.OnSelectRow', 'cmpWrkList.Enabled', 'cmpWrkList.Items', 'cmpWrkList.OnToggleShowInactive', 'cmpWrkMsgBar.OnClose') { $wAll.Remove($rm) }
$wText = ($wAll.Values) -join "`n"
function WProp([string]$ctl, [string]$prop) { $v = $wAll["$ctl.$prop"]; if ($null -eq $v) { throw "FAIL missing $ctl.$prop" }; return ([string]$v).Trim() }
function TTw([string]$k) { return "If(LangNl && !IsBlank(T.$k.nl),T.$k.nl,T.$k.en)" }

# (W1) Identical fail-closed guard in DisplayMode and as first OnSelect condition ------------------------------------
$wGuards = @{}
foreach ($ctl in @('btnWrkSave', 'btnWrkHome', 'btnWrkNew', 'btnWrkRefresh', 'btnWrkDiscard', 'galWrkList')) {
    $dm = WProp $ctl 'DisplayMode'; $os = WProp $ctl 'OnSelect'; $sfx = ',DisplayMode.Edit,DisplayMode.Disabled)'
    $g = $dm.Substring(4, $dm.Length - 4 - $sfx.Length)
    Assert-True ($dm.StartsWith('=If(') -and $dm.EndsWith($sfx) -and $os.StartsWith('=If(' + $g + ',')) "Workers: $ctl OnSelect starts with the same guard text as DisplayMode"
    $wGuards[$ctl] = $g
}
$wDirty = Get-Balanced $wGuards.btnWrkSave $wGuards.btnWrkSave.IndexOf('(Coalesce(varWrkMode,"") in ["New","Edit"]')
Assert-True ($wDirty -ceq $wDirtyFromLbl) 'Workers: dirty text in the Save guard = the lblWrkDirty text (one source)'
foreach ($f in @('FirstName', 'Surname', 'Trade', 'Contractor', 'Language')) { Assert-True ($wDirty.Contains("Trim(cmpWrk$f.Value & """")<>Trim(varWrkEdit.$f & """")")) "Workers: dirty compares cmpWrk$f.Value with varWrkEdit.$f, both sides Trim(x & """")" }
Assert-True ($wDirty.Contains('Coalesce(varWrkActiveDraft,true)<>Coalesce(varWrkEdit.Active,true)') -and ([regex]::Matches($wDirty, '<>')).Count -eq 6 -and $wDirty -notmatch 'Code|Modified|DupConfirmed|DupKey') 'Workers: dirty covers exactly First Name, Surname, Trade, Contractor, Language and the Active draft (not Worker Code, Modified or the Save anyway switch)'
Assert-True ($wGuards.btnWrkSave.EndsWith('&& ' + $wDirty) -and $wGuards.btnWrkSave.Contains('(varWrkMode="New" || (varWrkMode="Edit" && !IsBlank(varWrkSelectedID)))')) 'Workers: Save requires dirty and New, or Edit with an ID'
foreach ($ctl in @('btnWrkHome', 'btnWrkNew', 'galWrkList')) { Assert-True ($wGuards[$ctl].EndsWith('!' + $wDirty)) "Workers: $ctl blocked while dirty (same dirty text)" }
Assert-True ($wGuards.btnWrkRefresh -ceq ('!Coalesce(varWrkBusy,false) && !Coalesce(varWrkSaving,false) && (Coalesce(varWrkSaveFailed,false) || !' + $wDirty + ')')) 'Workers: Refresh blocked while loading/saving; allowed when clean or after a failed save (H15)'
Assert-True ($wGuards.btnWrkHome -ceq ('!Coalesce(varWrkBusy,false) && !Coalesce(varWrkSaving,false) && !' + $wDirty) -and $wGuards.btnWrkNew -ceq $wGuards.galWrkList -and (WProp 'btnWrkHome' 'OnSelect') -ceq ('=If(' + $wGuards.btnWrkHome + ',Navigate(scrHome))')) 'Workers: Home = not busy/saving/dirty and navigates only to scrHome; New = list-selection guard'
foreach ($k in @('varWrkLoadState="Loaded"', 'IsEmpty(colWrkLoadErrors)', '!Coalesce(varWrkBusy,false)', '!Coalesce(varWrkSaving,false)', '!Coalesce(varWrkSaveFailed,false)')) { Assert-True ($wGuards.btnWrkSave.Contains($k) -and $wGuards.btnWrkNew.Contains($k)) "Workers: Save and New guards contain $k" }
$wSnap = '{ID:5,FirstName:"Test",Surname:"Fitter 2",Code:"WKR-005",Trade:"Fitter",EmployerID:3,EmployerName:"TEST Employer",Contractor:"TEST Employer",Language:"Nederlands",Active:true}'
$wBase = 'varWrkLoadState:"Loaded",colWrkLoadErrors:Filter(Table({Message:""}),false),varWrkBusy:false,varWrkSaving:false,varWrkSaveFailed:false,varWrkMode:"Edit",varWrkSelectedID:5,varWrkEdit:' + $wSnap + ','
function WIn([string]$fn, [string]$sn, [string]$tr, [string]$co, [string]$la, [string]$act) { return "cmpWrkFirstName:{Value:$fn},cmpWrkSurname:{Value:$sn},cmpWrkTrade:{Value:$tr},cmpWrkContractor:{Value:$co},cmpWrkLanguage:{Value:$la},varWrkActiveDraft:$act" }
$wClean = $wBase + (WIn '"Test"' '"Fitter 2"' '"Fitter"' '"TEST Employer"' '"Nederlands"' 'true')
function WG([string]$name, [string]$fixture) { return 'With({' + $fixture + '},' + $wGuards[$name] + ')' }
Assert-Eval (WG 'btnWrkSave' $wClean) $false 'Workers: Save blocked when clean'
foreach ($c in @(@('cmpWrkFirstName:{Value:"Test"}', 'cmpWrkFirstName:{Value:"Tess"}', 'First Name'), @('cmpWrkSurname:{Value:"Fitter 2"}', 'cmpWrkSurname:{Value:"Welder 2"}', 'Surname'), @('cmpWrkTrade:{Value:"Fitter"}', 'cmpWrkTrade:{Value:"Welder"}', 'Trade'), @('cmpWrkContractor:{Value:"TEST Employer"}', 'cmpWrkContractor:{Value:"Other"}', 'Contractor'), @('cmpWrkLanguage:{Value:"Nederlands"}', 'cmpWrkLanguage:{Value:"English"}', 'Language'), @('varWrkActiveDraft:true', 'varWrkActiveDraft:false', 'Active'))) {
    $fx = $wClean.Replace($c[0], $c[1]); Assert-True ($fx -ne $wClean) "Workers fixture: $($c[2]) changed"
    Assert-Eval (WG 'btnWrkSave' $fx) $true "Workers: Save allowed when only $($c[2]) changed (dirty)"
    Assert-Eval (WG 'btnWrkHome' $fx) $false "Workers: Home blocked when $($c[2]) changed"
}
Assert-Eval (WG 'btnWrkSave' $wClean.Replace('cmpWrkFirstName:{Value:"Test"}', 'cmpWrkFirstName:{Value:" Test "}')) $false 'Workers: only spaces around a name are not dirty (Trim on both sides)'
$wDirtyFix = $wClean.Replace('cmpWrkFirstName:{Value:"Test"}', 'cmpWrkFirstName:{Value:"Tess"}')
foreach ($s in @('"NotLoaded"', '"Loading"', '"Failed"', 'Blank()')) { Assert-Eval (WG 'btnWrkSave' $wDirtyFix.Replace('varWrkLoadState:"Loaded"', "varWrkLoadState:$s")) $false "Workers: Save blocked: load state $s" }
foreach ($fl in @('varWrkBusy', 'varWrkSaving', 'varWrkSaveFailed')) { Assert-Eval (WG 'btnWrkSave' $wDirtyFix.Replace("${fl}:false", "${fl}:true")) $false "Workers: Save blocked: $fl" }
Assert-Eval (WG 'btnWrkSave' $wDirtyFix.Replace('Filter(Table({Message:""}),false)', 'Table({Message:"x"})')) $false 'Workers: Save blocked: load errors present'
Assert-Eval (WG 'btnWrkSave' $wDirtyFix.Replace('varWrkSelectedID:5', 'varWrkSelectedID:Blank()')) $false 'Workers: Save blocked: Edit without ID'
Assert-Eval (WG 'btnWrkRefresh' $wDirtyFix.Replace('varWrkSaveFailed:false', 'varWrkSaveFailed:true')) $true 'Workers: Refresh allowed after a failed save (= Discard, H15)'
Assert-Eval (WG 'btnWrkDiscard' $wClean.Replace('varWrkMode:"Edit"', 'varWrkMode:"New"')) $true 'Workers 8b: Discard allowed in New mode with a clean form'
Assert-Eval (WG 'galWrkList' $wClean) $true 'Workers: list selection allowed when Loaded and clean'
Assert-Eval (WG 'galWrkList' $wDirtyFix) $false 'Workers: list selection blocked while dirty'

# (W2) Form fields: cmpField instances bound to varWrkEdit, edit guard, red border, dropdown items ------------------------
$wFieldEnabled = '=varWrkLoadState="Loaded" && IsEmpty(colWrkLoadErrors) && !Coalesce(varWrkBusy,false) && !Coalesce(varWrkSaving,false) && !Coalesce(varWrkSaveFailed,false) && Coalesce(varWrkMode,"") in ["New","Edit"]'
$wFields = [ordered]@{ cmpWrkFirstName = @('FirstName', 'text', 'wrkFieldFirstName'); cmpWrkSurname = @('Surname', 'text', 'wrkFieldSurname'); cmpWrkTrade = @('Trade', 'dropdown', 'wrkFieldTrade'); cmpWrkContractor = @('Contractor', 'dropdown', 'wrkFieldContractor'); cmpWrkLanguage = @('Language', 'dropdown', 'wrkFieldLanguage') }
$wCardKids = @($wIdx['conWrkFormCard']['Children'] | ForEach-Object { @($_.Keys)[0] })
foreach ($k in $wFields.Keys) {
    $ip = $wIdx[$k]['Properties']; $f = $wFields[$k]
    Assert-True ($wIdx[$k]['ComponentName'] -eq 'cmpField' -and $wCardKids -ccontains $k -and -not $ip.ContainsKey('Visible') -and ([string]$ip['Height']).Trim() -eq '=58') "Workers: $k is a cmpField, direct child of the form card, always rendered, height 58"
    Assert-True (([string]$ip['DefaultValue']).Trim() -ceq "=varWrkEdit.$($f[0])" -and ([string]$ip['Enabled']).Trim() -ceq $wFieldEnabled -and ([string]$ip['Invalid']).Trim() -ceq ('=CountIf(colWrkSaveErrors,Field="' + $f[0] + '")>0') -and ([string]$ip['InputType']).Trim() -ceq ('="' + $f[1] + '"') -and ([string]$ip['Required']).Trim() -eq '=true' -and ([string]$ip['Label']).Trim() -ceq ('=' + (TTw $f[2]))) "Workers: $k DefaultValue varWrkEdit.$($f[0]), edit guard, red border via colWrkSaveErrors.Field=""$($f[0])"", InputType $($f[1]), required star, label T.$($f[2])"
}
Assert-True ((WProp 'cmpWrkTrade' 'Items') -ceq '=ShowColumns(Choices([@Workers].Trade),Value)' -and (WProp 'cmpWrkLanguage' 'Items') -ceq '=ShowColumns(Choices([@Workers].Language),Value)') 'Workers: Trade and Language dropdowns = ShowColumns(Choices([@Workers].<column>),Value) (identifier column, SharePoint values not translated)'
$wCoItems = (WProp 'cmpWrkContractor' 'Items').TrimStart('=')
Assert-Eval "With({colWrkEmployers:Table({ID:1,Name:`"Beta`",Active:true},{ID:2,Name:`"alpha`",Active:true},{ID:3,Name:`"Gamma`",Active:false},{ID:4,Name:`"`",Active:true},{ID:5,Name:`"Delta`",Active:If(false,true)})},Concat($wCoItems,Value,`",`"))" 'alpha,Beta,Delta' 'Workers: Contractor dropdown = active contractors with a name, sorted (inactive ones only appear as the current value of a record)'
$wCode = $wIdx['cmpWrkCode']['Properties']
Assert-True (([string]$wCode['Enabled']).Trim() -eq '=false' -and ([string]$wCode['InputType']).Trim() -ceq '="readonly"' -and -not $wCode.ContainsKey('Invalid') -and -not $wCode.ContainsKey('OnChange')) 'Workers: Worker Code is a read-only cmpField (never edited)'
$wCodeFx = ([string]$wCode['DefaultValue']).Trim().TrimStart('=')
foreach ($c in @(@('"Edit"', '"WKR-005"', 'WKR-005', 'Edit with a code shows the code'), @('"Edit"', '""', 'assigned automatically', 'Edit without a code (flow MS-017 not yet run)'), @('"New"', '""', 'assigned automatically', 'New'), @('""', '""', '', 'no record in the form'))) {
    Assert-Eval "With({LangNl:false,T:$tRec,varWrkMode:$($c[0]),varWrkEdit:{Code:$($c[1])}},$wCodeFx)" $c[2] "Workers: Worker Code shows '$($c[2])': $($c[3])"
}
Assert-Eval "With({$($wBase -replace ',$', '')},$($wFieldEnabled.Substring(1)))" $true 'Workers: fields editable when Loaded, idle, Edit'
foreach ($m in @('""', 'If(false,"x")')) { Assert-Eval "With({$(($wBase -replace ',$', '') -replace 'varWrkMode:"Edit"', "varWrkMode:$m")},$($wFieldEnabled.Substring(1)))" $false "Workers: no record in the form (Mode $m): fields Disabled" }
$wChoices = @($wAll.Keys | Where-Object { $wAll[$_] -match '\bChoices\(' } | Sort-Object)
Assert-True (($wChoices -join ',') -ceq 'btnWrkLoad.OnSelect,btnWrkSave.OnSelect,cmpWrkLanguage.Items,cmpWrkTrade.Items' -and @($wAll.Values | Where-Object { $_ -match 'ForAll\([^;]*\bChoices\(' }).Count -eq 0) "Workers: Choices() only in the dropdown Items, the loader (New defaults) and Save (in-list flags), never inside ForAll ($($wChoices -join ', '))"
Assert-True ($wText -notmatch '\bNotify\(' -and $wText -notmatch 'DisplayMode\.View' -and $wText -notmatch '\bSearch\(') 'Workers: no Notify (message bar only), no DisplayMode.View, no Search()'

# (W3) Loader: staging, Refresh first, two independent reads, 500 guards, commit only without errors ------------------
$wLoad = WProp 'btnWrkLoad' 'OnSelect'; $wLoadN = Norm $wLoad
foreach ($k in @('btnWrkLoad.OnSelect', "$wScreen.OnVisible")) { Assert-True ($wAll[$k] -notmatch '\b(Patch|Update|UpdateIf|Remove|RemoveIf|SubmitForm|Defaults)\s*\(' -and $wAll[$k] -notmatch "\b(?:Collect|ClearCollect)\(\s*(?:Employers|Workers|Projects|Hours|'Project Workers'|'Assignment Periods')\b") "Workers: $k has no Patch/Update/Remove/Defaults and does not Collect into a SharePoint list" }
Assert-True ($wLoad.Contains('If(' + $wDirty + ' && !Coalesce(varWrkSaveFailed,false),') -and $wLoad.Contains('If(!Coalesce(varWrkForceRefresh,false) && varWrkLoadState="Loaded" && IsEmpty(colWrkLoadErrors) && !Coalesce(varWrkSaveFailed,false),')) 'Workers: loader refuses to reload over unsaved input (except after a failed save) and reuses a valid list unless forced'
Assert-True ($wAll["$wScreen.OnVisible"].Contains('If(!Coalesce(varWrkBusy,false) && !Coalesce(varWrkSaving,false) && !' + $wDirty + ',Set(varWrkForceRefresh,true); Select(btnWrkLoad))')) 'Workers: OnVisible reloads fresh (forced) when idle and clean: contractor/worker changes made elsewhere are always read (H16)'
$iWConc = $wLoad.IndexOf('Concurrent(')
Assert-True ($wLoad.IndexOf('IfError(Refresh(Workers),') -lt $iWConc -and $wLoad.IndexOf('IfError(Refresh(Employers),') -lt $iWConc -and $wLoad.IndexOf('IfError(Refresh(Workers),') -gt 0 -and $wLoad -notmatch 'If\(Coalesce\(varWrkForceRefresh,false\),') 'Workers: every load refreshes the Workers and Employers connector cache first (H16)'
$wConc = Get-Balanced $wLoad $iWConc; $wBr = Split-Args $wConc.Substring('Concurrent('.Length, $wConc.Length - 'Concurrent('.Length - 1)
Assert-True ($wBr.Count -eq 2 -and $wBr[0].Contains('ClearCollect(colPendingWrkRaw,Workers)') -and $wBr[0].Contains('Collect(colWrkWorkersLoadErrors,') -and $wBr[0] -notmatch 'colWrkEmployersLoadErrors|colWrkLoadErrors\b' -and $wBr[1].Contains('ClearCollect(colPendingWrkEmployers,ForAll(Employers As emp,{ID:emp.ID,Name:Trim(emp.Title & ""),Active:Coalesce(emp.Active,true)}))') -and $wBr[1].Contains('Collect(colWrkEmployersLoadErrors,') -and $wBr[1] -notmatch 'colWrkWorkersLoadErrors|colWrkLoadErrors\b') 'Workers: two Concurrent reads (Workers; Employers ID/Title/Active), each with its own error collection'
$iWMerge = $wLoadN.IndexOf('Collect(colWrkLoadErrors,colWrkWorkersLoadErrors,colWrkEmployersLoadErrors)'); $iWLw = $wLoadN.IndexOf('If(CountRows(colPendingWrkRaw)>=500,Collect(colWrkLoadErrors,'); $iWLe = $wLoadN.IndexOf('If(CountRows(colPendingWrkEmployers)>=500,Collect(colWrkLoadErrors,')
$iWGate = $wLoadN.IndexOf('If(IsEmpty(colWrkLoadErrors),ClearCollect(colAdminWorkers,colPendingAdminWorkers);ClearCollect(colWrkEmployers,colPendingWrkEmployers);ClearCollect(colWrkModified,colPendingWrkModified);Set(varWrkNewTrade,varPendingWrkNewTrade);Set(varWrkNewLanguage,varPendingWrkNewLanguage);')
Assert-True ($iWMerge -gt 0 -and $iWLw -gt $iWMerge -and $iWLe -gt $iWMerge -and $iWGate -gt $iWLw -and $iWGate -gt $iWLe -and $wLoadN.IndexOf('Set(varWrkLoadState,"Loaded")') -gt $iWGate) 'Workers: errors merged, 500 guards on Workers AND Employers, staging committed (list, contractors, Modified, New defaults) only without errors, then Loaded'
Assert-True (([regex]::Matches($wText, 'ClearCollect\(colAdminWorkers,')).Count -eq 1 -and ([regex]::Matches($wText, 'ClearCollect\(colWrkEmployers,')).Count -eq 1) 'Workers: colAdminWorkers and colWrkEmployers are only replaced by the loader staging step'
Assert-True ($wLoad.Contains('Set(varPendingWrkNewTrade,IfError(If(CountIf(Choices([@Workers].Trade),Value="Unknown")>0,"Unknown",""),""));') -and $wLoad.Contains('Set(varPendingWrkNewLanguage,IfError(If(CountIf(Choices([@Workers].Language),Value="Nederlands")>0,"Nederlands",CountIf(Choices([@Workers].Language),Value="Dutch")>0,"Dutch",""),""));')) 'Workers: New defaults Trade "Unknown" and Language "Nederlands" (else "Dutch", Eddy 9-11-2026) only when that value exists in Choices (else empty: the user must choose; nothing invented)'
# 9-11-2026 (TP-WORKERS-01 g): Studio showed no "Nederlands" in Workers.Language; the default falls back to "Dutch", else empty (fail-closed)
$wLangDef = 'If(CountIf(chL,Value="Nederlands")>0,"Nederlands",CountIf(chL,Value="Dutch")>0,"Dutch","")'
Assert-True ($wLoad.Contains('IfError(' + $wLangDef.Replace('chL', 'Choices([@Workers].Language)') + ',"")')) 'Workers: Language default expression under test is the one in the loader'
foreach ($c in @(@('Table({Value:"Nederlands"},{Value:"Dutch"},{Value:"English"})', 'Nederlands'), @('Table({Value:"Dutch"},{Value:"English"})', 'Dutch'), @('Table({Value:"English"})', ''))) { Assert-Eval "With({chL:$($c[0])},$wLangDef)" $c[1] "Workers: Language default with choices $($c[0]) = '$($c[1])'" }
$wNewSnap = '{ID:Blank(),FirstName:"",Surname:"",Code:"",Trade:varWrkNewTrade & "",EmployerID:Blank(),EmployerName:"",Contractor:"",Language:varWrkNewLanguage & "",Active:true}'
Assert-True ($wLoad.Contains("Set(varWrkEdit,$wNewSnap)") -and (WProp 'btnWrkNew' 'OnSelect').Contains("Set(varWrkEdit,$wNewSnap);")) 'Workers: New snapshot (OnNew and reload in New mode) = empty fields, Trade/Language defaults, Active true'
$wProjAt = $wLoad.IndexOf('ClearCollect(colPendingAdminWorkers,'); $wProjCall = Get-Balanced $wLoad ($wProjAt + 'ClearCollect'.Length); $wProj = $wProjCall.Substring('(colPendingAdminWorkers,'.Length, $wProjCall.Length - '(colPendingAdminWorkers,'.Length - 1)
$wRawFix = "colPendingWrkRaw:Table({ID:1,'First Name':`" Ann `",Surname:`"Test`",'Worker Code':`"WKR-001`",Trade:{Value:`"Fitter`"},Employer:{Id:3,Value:`"TEST Employer`"},Language:{Value:`"Nederlands`"},Active:true},{ID:2,'First Name':`"Bob`",Surname:`"Test`",'Worker Code':`"`",Trade:{Value:`"F`"},Employer:{Id:4,Value:`"Old Co`"},Language:{Value:`"English`"},Active:false},{ID:3,'First Name':`"Cy`",Surname:`"Test`",'Worker Code':`"WKR-003`",Trade:{Value:`"Welder`"},Employer:{Id:9,Value:`"Ghost`"},Language:{Value:`"English`"},Active:true},{ID:4,'First Name':`"Di`",Surname:`"Test`",'Worker Code':If(false,`"x`"),Trade:If(false,{Value:`"x`"}),Employer:If(false,{Id:0,Value:`"x`"}),Language:If(false,{Value:`"x`"}),Active:If(false,true)}),colPendingWrkEmployers:Table({ID:3,Name:`"TEST Employer`",Active:true},{ID:4,Name:`"Old Co`",Active:false})"
Assert-Eval "With({LangNl:false,T:$tRec,$wRawFix},Concat($wProj,Text(ID) & `":`" & FirstName & `"/`" & Code & `"/`" & Trade & `"/`" & Text(Coalesce(EmployerID,0)) & `"/`" & Contractor & `"/`" & Language & `"/`" & Text(Active),`"|`"))" '1:Ann/WKR-001/Fitter/3/TEST Employer/Nederlands/true|2:Bob//F/4/Old Co (inactive)/English/false|3:Cy/WKR-003/Welder/9/Ghost/English/true|4:Di///0///true' 'Workers: loader projection: trimmed fields, legacy Trade kept as-is, Contractor = loaded name (+ " (inactive)"), unknown employer keeps the lookup value, blanks normalized, blank Active = active'
foreach ($k in @('btnWrkNew.OnSelect', 'btnWrkDiscard.OnSelect', 'btnWrkLoad.OnSelect', "$wScreen.OnVisible")) { Assert-True ($wAll[$k] -notmatch '(Nederlands|Dutch)"\s*,\s*EmployerID|Trade:"Unknown"') "Workers: $k does not hard-code Trade/Language in a snapshot (defaults come from Choices via the loader)" }
$wItemsAll = (WProp 'galWrkList' 'Items').TrimStart('=')
$wSorted = 'Sort' + (Get-Balanced $wItemsAll ($wItemsAll.IndexOf('Sort(ForAll(') + 4))
Assert-True ($wItemsAll.StartsWith('ForAll(' + $wSorted + ' As r,{ID:r.ID,Title:r.Name,Subtitle:')) 'Workers: cmpListCard Items = all rows sorted, projected to ID, Title, Subtitle, Inactive, ChipText (no host filter)'
$wPred = $lcPredC.Replace('txtSearch.Text', 'cmpWrkList.SearchText').Replace('cmpListCard.ShowInactive', 'Coalesce(varWrkShowInactive,false)')
$wItems = 'Filter(' + $wItemsAll + ',' + $wPred + ')'
$wEmpty = '{ID:Blank(),FirstName:"",Surname:"",Code:"",Trade:"",EmployerID:Blank(),EmployerName:"",Contractor:"",Language:"",Active:true}'
Test-AutoSelect $wLoad $wItems $null (WProp 'galWrkList' 'OnSelect') 'Wrk' 'colAdminWorkers' $wEmpty $wDirty 'Workers'
$wSelFix = 'colAdminWorkers:Table({ID:1,FirstName:"Zed",Surname:"Test",Code:"WKR-001",EmployerName:"TEST Employer",Active:true},{ID:2,FirstName:"alpha",Surname:"Test",Code:"WKR-002",EmployerName:"",Active:false},{ID:3,FirstName:"Bob",Surname:"Test",Code:"",EmployerName:"Delft Co",Active:If(false,true)})'
foreach ($c in @(@('false', '""', '3', 'first active row by "First Surname" (inactive alpha hidden; blank Active = active)'), @('true', '""', '2', 'Show inactive on: alpha first'), @('false', '"zed t"', '1', 'search on the name'), @('false', '"wkr-00"', '1', 'search on the worker code'), @('false', '"delft"', '3', 'search on the contractor'))) {
    Assert-Eval "With({$wSelFix,LangNl:false,T:$tRec,varWrkShowInactive:$($c[0]),cmpWrkList:{SearchText:$($c[1])}},Text(First($wItems).ID))" $c[2] "Workers list: $($c[3]) -> ID $($c[2])"
}
Assert-Eval "With({$wSelFix,LangNl:false,T:$tRec,varWrkShowInactive:false,cmpWrkList:{SearchText:`"`"}},Concat($wItems,Title & `" = `" & Subtitle,`"; `"))" ('Bob Test = Delft Co; Zed Test = WKR-001 ' + [char]0x00B7 + ' TEST Employer') 'Workers list rows: title "First Surname", subtitle "Worker Code - Contractor" (code or contractor alone when the other is blank)'

# (W4) Every SharePoint read in a behaviour formula is preceded by Refresh(<list>) in the same branch -------------------
$wBeh = @{}
foreach ($pp in $wScreenProps.Keys) { if ($pp -like 'On*') { $wBeh["$wScreen.$pp"] = [string]$wScreenProps[$pp] } }
Get-BehaviourFormulas $wDoc['Screens'][$wScreen]['Children'] $wScreen $wBeh
$wSp = @()
foreach ($k in ($wBeh.Keys | Sort-Object)) { foreach ($r in (Test-RefreshBeforeReads $wBeh[$k])) { $wSp += $r; Assert-True ($r.Status -eq 'Refreshed') "Workers: $k : read of $($r.Source) (formula line $($r.Line)) preceded by Refresh($($r.Source)) in the same branch [$($r.Status)]" } }
Assert-True (@($wSp | Where-Object Source -eq 'Workers').Count -eq 6 -and @($wSp | Where-Object Source -eq 'Employers').Count -eq 2 -and @($wSp | Where-Object Source -eq "'Project Workers'").Count -eq 1) "Workers: SharePoint reads: 6 x Workers (load, pre-read, duplicate, control read Edit/New, verify), 2 x Employers (load, re-read of a newly assigned contractor), 1 x Project Workers (deactivation check)"
# (W5) Server predicates: column = global variable (or the one constant Active=true, V1); 500 / exact-one guard after each read
$wFilters = 0
foreach ($k in $wAll.Keys) {
    foreach ($m in [regex]::Matches($wAll[$k], "\b(Filter|LookUp)\(\s*(Employers|Workers|Projects|Hours|'Project Workers'|'Assignment Periods')\s*,")) {
        $wFilters++
        $call = Get-Balanced $wAll[$k] ($m.Index + $m.Groups[1].Value.Length); $pred = (Split-Args $call.Substring(1, $call.Length - 2))[1].Trim()
        Assert-True ($m.Groups[1].Value -eq 'Filter' -and ($pred -match '^ID=var\w+$' -or $pred -ceq "'First Name'=varWrkSaveFirst && Surname=varWrkSaveSurname" -or ($m.Groups[2].Value -eq "'Project Workers'" -and $pred -ceq 'Active=true'))) "Workers: $k : server predicate '$pred' on $($m.Groups[2].Value) uses columns + global variables only (Active=true on Project Workers: decision V1)"
    }
}
Assert-True ($wFilters -eq 7) "Workers: server predicates checked: $wFilters (pre-read, duplicate, control Edit/New, verify, deactivation, contractor re-read)"
foreach ($k in $wAll.Keys) {
    foreach ($m in [regex]::Matches($wAll[$k], '\b(?:ClearCollect|Collect)\(\s*(\w+)\s*,')) {
        $call = Get-Balanced $wAll[$k] ($m.Index + $m.Value.IndexOf('(')); $arg = $call.Substring($m.Value.Length - $m.Value.IndexOf('('))
        if ($arg -notmatch "(?<![\w.'])(?:Employers|Workers|Projects|Hours)\b(?!\.)|'(?:Project Workers|Assignment Periods)'") { continue }
        if ($arg.TrimStart().StartsWith('If(varWrkSaveWriteTrade && varWrkSaveWriteLanguage,Patch(Workers,')) { continue }
        $col = $m.Groups[1].Value; $after = $wAll[$k].Substring($m.Index)
        Assert-True ($after.Contains("CountRows($col)>=500") -or $after.Contains("CountRows($col)<>1") -or $after.Contains("CountRows($col)=1")) "Workers: $k : SharePoint read into $col is followed by a 500 guard (or exact-one check for an ID read)"
    }
}

# (W6) Save: all local validation before the one gate that encloses every SharePoint read and the Patch -------------------
$wSave = WProp 'btnWrkSave' 'OnSelect'; $wSaveN = Norm $wSave
$wSv = Get-RawOnSave 'scrWorkers'
$wGateTxt = "If(IsEmpty(colWrkSaveErrors),`n" + (' ' * 16) + 'IfError(Refresh(Workers),'
$iWG = $wSv.IndexOf("`n" + (' ' * 15) + $wGateTxt)
Assert-True ($iWG -gt 0 -and ([regex]::Matches($wSv, [regex]::Escape($wGateTxt))).Count -eq 1) 'Workers: one read/write gate If(IsEmpty(colWrkSaveErrors), IfError(Refresh(Workers),...) ...)'
$wGStart = $iWG + 1 + 15 + 2; $wGate = Get-Balanced $wSv $wGStart; $wGEnd = $wGStart + $wGate.Length
$wIo = [regex]::Matches($wSv, "Refresh\(|Patch\(|Filter\((Workers|Employers|Projects|'Assignment Periods'|'Project Workers'),")
$wOut = @($wIo | Where-Object { ($_.Index -lt $wGStart -or $_.Index -ge $wGEnd) -and !($_.Value -eq 'Refresh(' -and $wSv.Substring($_.Index, 16) -eq 'Refresh(Workers)' -and $_.Index -gt $wGEnd) })
Assert-True ($wIo.Count -gt 8 -and $wOut.Count -eq 0) 'Workers: every SharePoint read and the Patch lie inside the gate (only the cache Refresh(Workers) after a verified save follows it)'
Assert-True (([regex]::Matches($wGate, 'Patch\(Workers,')).Count -eq 4 -and ([regex]::Matches($srcAll, '\bPatch\(\s*Workers\b')).Count -eq 4) 'Workers: the 4 Patch(Workers) shapes are all inside the gate (no other Patch(Workers) in Src)'
foreach ($fv in @('{Field:"FirstName"', '{Field:"Surname"', '{Field:"Trade"', '{Field:"Language"', '{Field:"Contractor"')) {
    $all1 = @([regex]::Matches($wSv, [regex]::Escape($fv)) | ForEach-Object { $_.Index })
    $iEc = $wSv.IndexOf('If(IsEmpty(colWrkSaveErrors) && varWrkSaveContractorChanged,'); $eEc = $iEc + (Get-Balanced $wSv ($iEc + 2)).Length + 2
    Assert-True ($all1.Count -ge 1 -and @($all1 | Where-Object { $_ -gt $iWG -and !($fv -eq '{Field:"Contractor"' -and $_ -gt $iEc -and $_ -lt $eEc) }).Count -eq 0) "Workers: every $fv error is collected in the local validation before the gate (Contractor also by the server re-read of a new assignment)"
}
Assert-True ($wSave.Contains('Set(varWrkSaving,true);') -and $wSave.IndexOf('Set(varWrkSaving,true);') -lt $wSave.IndexOf('Clear(colWrkSaveErrors);') -and $wSave.Contains('FirstName:Trim(cmpWrkFirstName.Value & ""),Surname:Trim(cmpWrkSurname.Value & ""),Trade:Trim(cmpWrkTrade.Value & ""),Contractor:Trim(cmpWrkContractor.Value & ""),Language:Trim(cmpWrkLanguage.Value & ""),Active:Coalesce(varWrkActiveDraft,true)')) 'Workers: varWrkSaving set first (double click blocked); save record = trimmed field values + Active draft'
$wLocalDup = $wSv.Substring($wSv.IndexOf('ClearCollect(colWrkDupLocal,'), $iWG - $wSv.IndexOf('ClearCollect(colWrkDupLocal,'))
Assert-True ($wLocalDup -notmatch 'Refresh\(|Filter\((Workers|Employers)|Patch\(') 'Workers: the local duplicate pre-check (before the gate) reads only the loaded list'
function WBal([string]$needle) { $i = $wSave.IndexOf($needle); if ($i -lt 0) { throw "FAIL missing $needle" }; return Get-Balanced $wSave ($i + 2) }
function WFlag([string]$name) { $b = Get-Balanced $wSave ($wSave.IndexOf("Set($name,") + 3); return $b.Substring($name.Length + 2, $b.Length - $name.Length - 3) }
# names: required, max 255, not digits only, First Name + " " + Surname <= 255
$wDig = (Split-Args (WBal 'If(!IsBlank(varWrkSaveRec.FirstName) && IsMatch(').Substring(1, (WBal 'If(!IsBlank(varWrkSaveRec.FirstName) && IsMatch(').Length - 2))[0]
Assert-True ($wDig -ceq '!IsBlank(varWrkSaveRec.FirstName) && IsMatch(varWrkSaveRec.FirstName,"[0-9]+")') 'Workers: digits-only rule = IsMatch(<name>,"[0-9]+") (IsMatch matches the complete text by default)'
foreach ($c in @(@('123', $true, 'digits only'), @('Jan2', $false, 'letters and digits'), @('12 34', $false, 'digits with a space'), @('Anna', $false, 'letters'))) { Assert-True ([regex]::IsMatch($c[0], '^(?:[0-9]+)$') -eq $c[1]) "Workers: First Name '$($c[0])' -> digits-only error $($c[1]) ($($c[2]); complete-match semantics simulated with .NET regex, the local interpreter has no IsMatch)" }
Assert-True ($wSave.Contains('If(IsBlank(varWrkSaveRec.FirstName),Collect(colWrkSaveErrors,{Field:"FirstName",Message:' + (TTw 'wrkErrFirstNameRequired') + '}));') -and $wSave.Contains('If(IsBlank(varWrkSaveRec.Surname),Collect(colWrkSaveErrors,{Field:"Surname",Message:' + (TTw 'wrkErrSurnameRequired') + '}));') -and $wSave.Contains('If(Len(varWrkSaveRec.FirstName)>255,') -and $wSave.Contains('If(Len(varWrkSaveRec.Surname)>255,') -and $wSave.Contains('If(!IsBlank(varWrkSaveRec.Surname) && IsMatch(varWrkSaveRec.Surname,"[0-9]+"),')) 'Workers: First Name and Surname required ("Fix: First Name empty" / "Fix: Surname empty"), max 255, not digits only'
$wLen = (Split-Args (WBal 'If(Len(varWrkSaveRec.FirstName)<=255').Substring(1, (WBal 'If(Len(varWrkSaveRec.FirstName)<=255').Length - 2))[0]
Assert-Eval "With({varWrkSaveRec:{FirstName:Concat(Sequence(200),`"a`"),Surname:Concat(Sequence(60),`"b`")}},$wLen)" $true 'Workers: First Name + Surname longer than 255 together -> error (Worker Name must fit)'
Assert-Eval "With({varWrkSaveRec:{FirstName:Concat(Sequence(200),`"a`"),Surname:Concat(Sequence(54),`"b`")}},$wLen)" $false 'Workers: exactly 255 together -> accepted'
Assert-Eval "With({varWrkSaveRec:{FirstName:Trim(`"   `" & `"`")}},Text(IsBlank(varWrkSaveRec.FirstName)))" 'true' 'Workers: a name of spaces only counts as empty'
# Trade / Language: required, in the list; N3 = unchanged legacy value outside Choices accepted and not written
$chT = 'Table({Value:"Fitter"},{Value:"Welder"},{Value:"Unknown"})'; $chL = 'Table({Value:"Nederlands"},{Value:"English"})'
foreach ($col in @(@('Trade', $chT, '"F"', '"Fitter"', '"W"'), @('Language', $chL, '"Deutsch"', '"English"', '"Polski"'))) {
    $cn = $col[0]; $inFx = "CountIf(Choices([@Workers].$cn),Value=varWrkSaveRec.$cn)>0"
    Assert-True ($wSave.Contains("Set(varWrkSave${cn}InList,$inFx);")) "Workers: $cn in-list flag = CountIf(Choices([@Workers].$cn),Value=<save value>)>0"
    $wfFx = WFlag "varWrkSaveWrite$cn"
    Assert-True ($wfFx -ceq "!(varWrkSaveMode=`"Edit`" && !IsBlank(varWrkSaveRec.$cn) && !varWrkSaveTradeInList && varWrkSaveRec.$cn=Trim(varWrkEdit.$cn & `"`"))".Replace('varWrkSaveTradeInList', "varWrkSave${cn}InList")) "Workers N3: write flag for $cn = not (Edit, non-blank, outside the list, unchanged)"
    $ifc = WBal "If(IsBlank(varWrkSaveRec.$cn),Collect(colWrkSaveErrors,{Field:`"$cn`""; $ifa = Split-Args $ifc.Substring(1, $ifc.Length - 2)
    Assert-True ($ifa.Count -eq 4 -and $ifa[1].Contains((TTw "wrkErr${cn}Required")) -and $ifa[3].Contains((TTw "wrkErr${cn}Unknown"))) "Workers: $cn empty -> ""Fix: $cn empty"", new/changed value outside the list -> ""Fix: $cn unknown"" (field $cn)"
    foreach ($c in @(@('"Edit"', $col[2], $col[2], 'false|false/false', 'legacy value outside the list unchanged: accepted, not written'), @('"Edit"', $col[2], $col[3], 'false|false/true', 'legacy value changed to a list value: written'), @('"Edit"', $col[2], $col[4], 'false|true/true', 'changed to another unknown value: error'), @('"Edit"', $col[3], '""', 'true|true/true', 'emptied (or legacy blank, V4): "empty" error first'), @('"New"', '""', $col[2], 'false|true/true', 'New with an unknown value: error'), @('"New"', '""', $col[3], 'false|false/true', 'New with a list value: accepted, written'))) {
        $fx = "With({ch:$($col[1]),varWrkSaveMode:$($c[0]),varWrkEdit:{${cn}:$($c[1])},varWrkSaveRec:{${cn}:$($c[2])}},With({varWrkSave${cn}InList:CountIf(ch,Value=varWrkSaveRec.$cn)>0},Text(IsBlank(varWrkSaveRec.$cn)) & `"|`" & Text($($ifa[2])) & `"/`" & Text($wfFx)))"
        Assert-Eval $fx $c[3] "Workers $cn : $($c[4]) -> empty|unknown/write = $($c[3])"
    }
}
# Contractor mapping: unchanged = by ID (inactive current allowed); changed/New = by Lower(Trim(name)) in the loaded Employers
$wCcFx = WFlag 'varWrkSaveContractorChanged'
$wMatchAt = $wSave.IndexOf('ClearCollect(colWrkEmpMatch,'); $wMatchCall = Get-Balanced $wSave ($wMatchAt + 'ClearCollect'.Length); $wMatchFx = $wMatchCall.Substring('(colWrkEmpMatch,'.Length, $wMatchCall.Length - '(colWrkEmpMatch,'.Length - 1)
$wCoChain = WBal 'If(IsBlank(varWrkSaveRec.Contractor),Collect(colWrkSaveErrors,{Field:"Contractor"'
$wCoChainR = 'If' + [regex]::Replace($wCoChain, 'Collect\(colWrkSaveErrors,\{Field:"Contractor",Message:If\(LangNl && !IsBlank\(T\.(\w+)\.nl\),T\.\w+\.nl,T\.\w+\.en\)\}\)', '"$1"')
Assert-True (([regex]::Matches($wCoChainR, '"wrkErrContractor(Required|Unknown|Ambiguous|Inactive)"')).Count -eq 4 -and $wCoChainR -notmatch 'Collect\(') 'Workers: contractor errors: empty, unknown, ambiguous, inactive (field Contractor)'
$wEmpFix = 'colWrkEmployers:Table({ID:3,Name:"TEST Employer",Active:true},{ID:4,Name:"Old Co",Active:false},{ID:5,Name:"Twin",Active:true},{ID:6,Name:"Twin",Active:true})'
$wEmpSetFx = WFlag 'varWrkSaveEmp'
foreach ($c in @(@('"Edit"', '"Old Co (inactive)"', '4', '"Old Co (inactive)"', 'ok|4', 'unchanged inactive current contractor: allowed (matched by ID)'),
                @('"Edit"', '"Old Co (inactive)"', '4', '"TEST Employer"', 'ok|3', 'changed to an active contractor: mapped to its ID'),
                @('"Edit"', '"TEST Employer"', '3', '"Old Co"', 'wrkErrContractorInactive|4', 'changed to an inactive contractor: blocked'),
                @('"Edit"', '"TEST Employer"', '3', '"Twin"', 'wrkErrContractorAmbiguous|0', 'two contractors with the same trimmed name: "Fix: Contractor ambiguous"'),
                @('"New"', '""', 'If(false,0)', '""', 'wrkErrContractorRequired|0', 'New without contractor: "Fix: Contractor empty"'),
                @('"New"', '""', 'If(false,0)', '"Nobody"', 'wrkErrContractorUnknown|0', 'name not in the loaded list: "Fix: Contractor unknown"'),
                @('"New"', '""', 'If(false,0)', '"test employer"', 'ok|3', 'name matched case-insensitively'),
                @('"Edit"', '"Ghost"', '9', '"Ghost"', 'wrkErrContractorUnknown|0', 'unchanged contractor that is no longer in the loaded list: unknown'))) {
    $fx = "With({$wEmpFix,varWrkSaveMode:$($c[0]),varWrkEdit:{Contractor:$($c[1]),EmployerID:$($c[2])},varWrkSaveRec:{Contractor:$($c[3])}},With({varWrkSaveContractorChanged:$wCcFx},With({colWrkEmpMatch:$wMatchFx},With({varWrkSaveEmp:$wEmpSetFx},Coalesce($wCoChainR,`"ok`") & `"|`" & Text(Coalesce(varWrkSaveEmp.ID,0))))))"
    Assert-Eval $fx $c[4] "Workers contractor: $($c[5]) -> $($c[4])"
}
Assert-True ($wSave.IndexOf('ClearCollect(colWrkEmpMatch,') -lt $iWG -and $wMatchFx -notmatch '\bEmployers\b') 'Workers: contractor mapping on the loaded Employers list only, before the gate'

# (W7) Patch: one write step, 4 record shapes for N3 (Trade/Language), never Worker Code; Worker Name = First Name + " " + Surname
$wSelAt = $wSave.IndexOf('ClearCollect(colWrkPatched,If(')
Assert-True ($wSelAt -gt 0 -and ([regex]::Matches($wSave, 'ClearCollect\(colWrkPatched,')).Count -eq 1) 'Workers: exactly one ClearCollect(colWrkPatched, If(<shape>, Patch, ...)) write step'
$wSel = Get-Balanced $wSave ($wSelAt + 'ClearCollect(colWrkPatched,If'.Length); $wSelArgs = Split-Args $wSel.Substring(1, $wSel.Length - 2)
Assert-True ($wSelArgs.Count -eq 7 -and $wSelArgs[0].Trim() -ceq 'varWrkSaveWriteTrade && varWrkSaveWriteLanguage' -and $wSelArgs[2].Trim() -ceq 'varWrkSaveWriteTrade' -and $wSelArgs[4].Trim() -ceq 'varWrkSaveWriteLanguage') 'Workers: If(Trade && Language, P1, Trade, P2, Language, P3, P4): exactly one Patch runs'
$wShape = @{}; $wSi = @{ 1 = 1; 2 = 3; 3 = 5; 4 = 6 }
foreach ($si in 1, 2, 3, 4) {
    $sp = $wSelArgs[$wSi[$si]].Trim(); $sa = Split-Args $sp.Substring('Patch('.Length, $sp.Length - 'Patch('.Length - 1)
    Assert-True ($sp.StartsWith('Patch(Workers,') -and $sa.Count -eq 3 -and $sa[1].Trim() -ceq 'If(varWrkSaveMode="New",Defaults(Workers),First(colWrkPreRaw))') "Workers: shape $si : Patch(Workers, Defaults for New / the pre-read record for Edit, ...)"
    $sr = $sa[2].Trim(); $wShape[$si] = [ordered]@{}; foreach ($a in (Split-Args $sr.Substring(1, $sr.Length - 2))) { $kv = $a -split ':', 2; $wShape[$si][$kv[0].Trim()] = $kv[1].Trim() }
}
$wShapeExp = @{ 1 = "'First Name',Surname,'Worker Name',Trade,Employer,Language,Active"; 2 = "'First Name',Surname,'Worker Name',Trade,Employer,Active"; 3 = "'First Name',Surname,'Worker Name',Employer,Language,Active"; 4 = "'First Name',Surname,'Worker Name',Employer,Active" }
foreach ($si in 1, 2, 3, 4) {
    Assert-True ((@($wShape[$si].Keys) -join ',') -ceq $wShapeExp[$si]) "Workers: shape $si writes exactly $($wShapeExp[$si]) (never Worker Code, field_1, Modified)"
    foreach ($kk in @($wShape[$si].Keys)) { Assert-True ($wShape[$si][$kk] -ceq $wShape[1][$kk]) "Workers: shape $si writes $kk identically to shape 1" }
}
Assert-True ($wShape[1]["'First Name'"] -ceq 'varWrkSaveRec.FirstName' -and $wShape[1]['Surname'] -ceq 'varWrkSaveRec.Surname' -and $wShape[1]["'Worker Name'"] -ceq 'varWrkSaveRec.FirstName & " " & varWrkSaveRec.Surname' -and $wShape[1]['Trade'] -ceq '{Value:varWrkSaveRec.Trade}' -and $wShape[1]['Employer'] -ceq '{Id:varWrkSaveEmp.ID,Value:varWrkSaveEmp.Name}' -and $wShape[1]['Language'] -ceq '{Value:varWrkSaveRec.Language}' -and $wShape[1]['Active'] -ceq 'varWrkSaveRec.Active') 'Workers: Patch values: trimmed names, Worker Name = First Name & " " & Surname (as flow MS-017), Trade/Language {Value}, Employer {Id, Value} from the loaded list, Active'
Assert-True ($srcAll -notmatch "'Worker Code'\s*:" -and $wSel -notmatch "Worker Code|field_\d|Title\s*:|Code\s*:|\bChoices\(") 'Workers: Worker Code (field_1, flow MS-017) is never written; no Choices() in a Patch record'
$wWtFx = WFlag 'varWrkSaveWriteTrade'; $wWlFx = WFlag 'varWrkSaveWriteLanguage'
foreach ($c in @(@('"Edit"', '"F"', '"Deutsch"', '"F"', '"Deutsch"', 4, 'legacy Trade and Language unchanged: neither written'), @('"Edit"', '"F"', '"English"', '"Fitter"', '"English"', 1, 'Trade changed to a list value, Language in the list: both written'), @('"Edit"', '"Fitter"', '"Deutsch"', '"Fitter"', '"Deutsch"', 2, 'legacy Language unchanged: Language not written'), @('"Edit"', '"F"', '"English"', '"F"', '"English"', 3, 'legacy Trade unchanged: Trade not written'), @('"New"', '""', '""', '"Unknown"', '"Nederlands"', 1, 'New: both written'))) {
    $fx = "With({chT:$chT,chL:$chL,varWrkSaveMode:$($c[0]),varWrkEdit:{Trade:$($c[1]),Language:$($c[2])},varWrkSaveRec:{Trade:$($c[3]),Language:$($c[4])}},With({varWrkSaveTradeInList:CountIf(chT,Value=varWrkSaveRec.Trade)>0,varWrkSaveLanguageInList:CountIf(chL,Value=varWrkSaveRec.Language)>0},With({varWrkSaveWriteTrade:$wWtFx,varWrkSaveWriteLanguage:$wWlFx},If($($wSelArgs[0]),1,$($wSelArgs[2]),2,$($wSelArgs[4]),3,4))))"
    Assert-Eval $fx $c[5] "Workers N3: $($c[6]) -> shape $($c[5])"
    Assert-True (($wShape[$c[5]].Contains('Trade')) -eq ($c[5] -in 1, 2) -and ($wShape[$c[5]].Contains('Language')) -eq ($c[5] -in 1, 3)) "Workers N3: shape $($c[5]) has Trade: $($c[5] -in 1, 2), Language: $($c[5] -in 1, 3)"
}

# (W8) Duplicate: WARN + confirm ("Save anyway"), never block silently; nothing written without the confirmation ------------
Assert-True ($wSave.Contains("ClearCollect(colWrkDup,ForAll(Filter(Workers,'First Name'=varWrkSaveFirst && Surname=varWrkSaveSurname) As w,") -and $wSave.IndexOf('Set(varWrkSaveFirst,varWrkSaveRec.FirstName); Set(varWrkSaveSurname,varWrkSaveRec.Surname);') -lt $wSave.IndexOf("Filter(Workers,'First Name'") -and $wSave.Contains('If(IsEmpty(colWrkSaveErrors) && CountRows(colWrkDup)>=500,')) 'Workers: server duplicate read Filter(Workers, First Name = global && Surname = global), 500 guard'
$wDupCond = (Split-Args (WBal 'If(IsEmpty(colWrkSaveErrors) && !varWrkSaveDupOk && CountIf(colWrkDup,').Substring(1, (WBal 'If(IsEmpty(colWrkSaveErrors) && !varWrkSaveDupOk && CountIf(colWrkDup,').Length - 2))[0]
$wDupCondL = $wDupCond.Replace('IsEmpty(colWrkSaveErrors) && ', '')
$wDupRows = 'colWrkDup:Table({ID:5,FirstName:"Test",Surname:"Fitter 2",Code:"WKR-005",EmployerID:3},{ID:7,FirstName:"TEST",Surname:"fitter 2",Code:"",EmployerID:3},{ID:8,FirstName:"Test",Surname:"Fitter 2",Code:"WKR-008",EmployerID:4})'
foreach ($c in @(@('"Edit"', '5', '3', 'false', $true, 'same name (other case) and contractor, other ID -> warning'), @('"Edit"', '5', '9', 'false', $false, 'same name, other contractor -> no warning'), @('"New"', 'If(false,0)', '4', 'false', $true, 'New with the name and contractor of ID 8 -> warning'), @('"Edit"', '5', '3', 'true', $false, 'confirmed with Save anyway -> no warning, save proceeds'))) {
    Assert-Eval "With({$wDupRows,varWrkSaveMode:$($c[0]),varWrkSaveID:$($c[1]),varWrkSaveEmp:{ID:$($c[2])},varWrkSaveDupOk:$($c[3]),varWrkSaveRec:{FirstName:`"Test`",Surname:`"Fitter 2`"}},$wDupCondL)" $c[4] "Workers duplicate: $($c[5])"
}
Assert-True ($wSave.Contains('Collect(colWrkSaveErrors,{Field:"Dup",Message:Substitute(' + (TTw 'wrkWarnDuplicate') + ',"{0}",varWrkSaveDupCodes)})') -and ([regex]::Matches($wSave, [regex]::Escape('{Field:"Dup"'))).Count -eq 2) 'Workers: duplicate (local pre-check and server read) collected as Field "Dup" with the worker code(s): nothing is written'
$wDokFx = WFlag 'varWrkSaveDupOk'
foreach ($c in @(@('true', '"test|fitter 2|test employer"', $true, 'confirmed for the same name and contractor'), @('true', '"test|fitter 2|other"', $false, 'confirmed for another contractor'), @('false', '"test|fitter 2|test employer"', $false, 'not confirmed'), @('true', '""', $false, 'no pending warning'))) {
    Assert-Eval "With({varWrkDupConfirmed:$($c[0]),varWrkDupPendingKey:$($c[1]),varWrkSaveDupKey:`"test|fitter 2|test employer`"},$wDokFx)" $c[2] "Workers Save anyway: $($c[3]) -> confirmation used = $($c[2])"
}
$wKeyLbl = ([string]$wIdx['lblWrkDupKey']['Properties']['Text']).Trim().TrimStart('='); $wKeySave = WFlag 'varWrkSaveDupKey'
Assert-Eval "With({cmpWrkFirstName:{Value:`" Test `"},cmpWrkSurname:{Value:`"Fitter 2`"},cmpWrkContractor:{Value:`"TEST Employer `"}},With({varWrkSaveRec:{FirstName:Trim(cmpWrkFirstName.Value & `"`"),Surname:Trim(cmpWrkSurname.Value & `"`"),Contractor:Trim(cmpWrkContractor.Value & `"`")}},Text(($wKeyLbl)=($wKeySave)) & `"|`" & ($wKeyLbl)))" 'true|test|fitter 2|test employer' 'Workers: the switch key (lblWrkDupKey, from the inputs) equals the save key (name and contractor, Lower/Trim)'
$wOutDup = 'varWrkSaveWrites=0 && varWrkSaveDupFound,' + "`n" + (' ' * 16) + 'Set(varWrkDupPendingKey,varWrkSaveDupKey); Set(varWrkDupConfirmed,false);'
Assert-True ($wSv.Contains($wOutDup) -and $wSave.Contains('Set(varAdmMsgKind,"Warning"); Set(varAdmMsgHead,' + (TTw 'admHeadAttention') + '); Set(varAdmMsgBody,LookUp(colWrkSaveErrors,Field="Dup").Message),')) 'Workers: duplicate outcome = amber "Attention." with the codes; the pending key is set and the confirmation cleared (state stays Loaded, input kept)'
$wVisSw = ([string]$wIdx['btnWrkSaveAnywaySwitch']['Properties']['Visible']).Trim()
Assert-True ($wVisSw -ceq '=Coalesce(varWrkMode,"") in ["New","Edit"] && !IsBlank(varWrkDupPendingKey) && varWrkDupPendingKey=lblWrkDupKey.Text' -and ([string]$wIdx['btnWrkSaveAnywayKnob']['Properties']['Visible']).Trim() -eq '=btnWrkSaveAnywaySwitch.Visible' -and ([string]$wIdx['lblWrkSaveAnywayState']['Properties']['Visible']).Trim() -eq '=btnWrkSaveAnywaySwitch.Visible') 'Workers: "Save anyway" switch only visible after a duplicate warning for exactly the shown name and contractor'
foreach ($c in @(@('"test|fitter 2|test employer"', '"test|fitter 2|test employer"', $true), @('"test|fitter 2|test employer"', '"test|fitter 3|test employer"', $false), @('""', '"||"', $false))) { Assert-Eval "With({varWrkMode:`"Edit`",varWrkDupPendingKey:$($c[0]),lblWrkDupKey:{Text:$($c[1])}},$($wVisSw.TrimStart('=')))" $c[2] "Workers: Save anyway visible = $($c[2]) (pending $($c[0]), shown $($c[1]))" }
$wSwOs = ([string]$wIdx['btnWrkSaveAnywaySwitch']['Properties']['OnSelect']).Trim()
Assert-True ($wSwOs.StartsWith('=If(' + $wFieldEnabled.Substring(1) + ',') -and ([string]$wIdx['btnWrkSaveAnywaySwitch']['Properties']['DisplayMode']).Trim() -ceq ('=If(' + $wFieldEnabled.Substring(1) + ',DisplayMode.Edit,DisplayMode.Disabled)') -and $wSwOs.Contains('If(!IsBlank(varWrkDupPendingKey) && varWrkDupPendingKey=lblWrkDupKey.Text,Set(varWrkDupConfirmed,!Coalesce(varWrkDupConfirmed,false)),Set(varWrkDupConfirmed,false))')) 'Workers: Save anyway switch: same edit guard in DisplayMode and OnSelect; toggles only for the warned name/contractor, else stays off'
foreach ($k in 'cmpWrkFirstName', 'cmpWrkSurname', 'cmpWrkContractor') { Assert-True (([string]$wIdx[$k]['Properties']['OnChange']).Trim() -ceq ('=If(' + $wFieldEnabled.Substring(1) + ',Set(varWrkDupConfirmed,false)); true')) "Workers: $k.OnChange resets the Save anyway confirmation (name or contractor changed)" }
$wConfSets = @(Get-SetValues $wText 'varWrkDupConfirmed' | Sort-Object)
Assert-True (($wConfSets -join '|') -ceq '!Coalesce(varWrkDupConfirmed,false)|false' -or ($wConfSets -join '|') -ceq 'false|!Coalesce(varWrkDupConfirmed,false)') "Workers: varWrkDupConfirmed is only switched by the Save anyway switch, otherwise reset to false ($($wConfSets -join ' | '))"
foreach ($k in @('btnWrkLoad.OnSelect', 'btnWrkNew.OnSelect', 'btnWrkDiscard.OnSelect', 'galWrkList.OnSelect', 'btnWrkSave.OnSelect')) { Assert-True ($wAll[$k].Contains('Set(varWrkDupPendingKey,""); Set(varWrkDupConfirmed,false);')) "Workers: $k clears the duplicate warning and the confirmation" }

# (W9) Deactivation blocked while the worker has an active Project Workers link (V1: one read Active=true, local match) -------
$wDeFx = WFlag 'varWrkSaveDeactivate'
foreach ($c in @(@('"Edit"', 'true', 'false', $true, 'active -> inactive'), @('"Edit"', 'false', 'false', $false, 'already inactive'), @('"Edit"', 'false', 'true', $false, 'reactivation'), @('"Edit"', 'If(false,true)', 'false', $true, 'blank Active (= active) -> inactive'), @('"New"', 'true', 'false', $false, 'New record'))) { Assert-Eval "With({varWrkSaveMode:$($c[0]),varWrkEdit:{Active:$($c[1])},varWrkSaveRec:{Active:$($c[2])}},$wDeFx)" $c[3] "Workers deactivation check needed: $($c[4]) -> $($c[3])" }
$wDeBlk = WBal 'If(IsEmpty(colWrkSaveErrors) && varWrkSaveDeactivate,'
Assert-True ($wDeBlk.Contains("IfError(Refresh('Project Workers'),Set(varWrkSaveDeactUnchecked,true);false);") -and $wDeBlk.Contains("ClearCollect(colWrkActivePW,ForAll(Filter('Project Workers',Active=true) As pw,{ID:pw.ID,WorkerID:pw.Worker.Id,ProjectID:pw.Project.Id,ProjectTitle:Trim(pw.Project.Value & `"`")}))") -and $wDeBlk.Contains('If(!varWrkSaveDeactUnchecked && CountRows(colWrkActivePW)>=500,Set(varWrkSaveDeactUnchecked,true));') -and ([regex]::Matches($srcAll, [regex]::Escape("Filter('Project Workers',Active=true)"))).Count -eq 1) 'Workers: deactivation = Refresh + ONE read Filter(Project Workers, Active=true) (V1 exception, only place in Src), lookup ID matched locally; read error or 500+ rows = blocked'
Assert-True ($wSave.IndexOf('If(IsEmpty(colWrkSaveErrors) && varWrkSaveDeactivate,') -lt $wSave.IndexOf('ClearCollect(colWrkPatched,') -and $wSave.IndexOf('If(IsEmpty(colWrkSaveErrors) && varWrkSaveDeactivate,') -gt $wSave.IndexOf('With({p:First(colWrkPre)},')) 'Workers: deactivation check after the conflict check, before the Patch'
$wDeMsgAt = $wDeBlk.IndexOf('Collect(colWrkSaveErrors,{Field:"Active",Message:Substitute('); $wDeMsgRec = Get-Balanced $wDeBlk ($wDeMsgAt + 'Collect'.Length); $wDeMsg = (Split-Args $wDeMsgRec.Substring(1, $wDeMsgRec.Length - 2))[1].Trim(); $wDeMsg = $wDeMsg.Substring('{Field:"Active",Message:'.Length, $wDeMsg.Length - '{Field:"Active",Message:'.Length - 1)
$wPwFix = 'colWrkActivePW:Table({ID:11,WorkerID:5,ProjectID:1,ProjectTitle:"Beta"},{ID:12,WorkerID:5,ProjectID:2,ProjectTitle:"alpha"},{ID:13,WorkerID:6,ProjectID:3,ProjectTitle:"Other"})'
Assert-Eval "With({LangNl:false,T:$tRec,varWrkSaveID:5,$wPwFix},$wDeMsg)" 'Still active in Project / team: alpha, Beta. Uncheck in Project / team first.' 'Workers: blocked deactivation names the projects (sorted)'
Assert-Eval "With({LangNl:false,T:$tRec,varWrkSaveID:5,colWrkActivePW:ForAll(Sequence(5),{ID:Value,WorkerID:5,ProjectID:Value,ProjectTitle:`"P`" & Text(Value)})},$wDeMsg)" 'Still active in Project / team: P1, P2, P3 (+2 more). Uncheck in Project / team first.' 'Workers: blocked deactivation shows the first 3 projects and "(+n more)"'
Assert-True ($wDeBlk.Contains('CountIf(colWrkActivePW,WorkerID=varWrkSaveID)>0,') -and $wDeBlk.Contains('Collect(colWrkSaveErrors,{Field:"Active",Message:' + (TTw 'wrkErrDeactCheck') + '})') -and $wSave.Contains('varWrkSaveWrites=0 && varWrkSaveDeactBlocked,') -and $wSave.Contains('Set(varAdmMsgKind,"Error"); Set(varAdmMsgHead,' + (TTw 'admHeadBlocked') + '); Set(varAdmMsgBody,LookUp(colWrkSaveErrors,Field="Active").Message),')) 'Workers: deactivation outcome = red "Blocked." with the projects or "could not be checked"; nothing written'

# Reviewer 08-11-2026 (non-blocking 3): a NEW contractor assignment (or New) is re-read by ID inside the gate before the Patch:
# not exactly 1 row, read error or Active false = zero writes with the unknown/inactive error on field Contractor; counted as a read.
$wEcBlk = WBal 'If(IsEmpty(colWrkSaveErrors) && varWrkSaveContractorChanged,'
Assert-True ($wSave.IndexOf('Set(varWrkSaveEmpID,varWrkSaveEmp.ID);') -gt 0 -and $wSave.IndexOf('Set(varWrkSaveEmpID,varWrkSaveEmp.ID);') -lt $wSave.IndexOf('IfError(Refresh(Workers),Collect(colWrkSaveErrors') -and $wEcBlk.Contains('IfError(Refresh(Employers),') -and $wEcBlk.Contains('Set(varWrkSaveReads,varWrkSaveReads+1);') -and $wEcBlk.Contains('ClearCollect(colWrkEmpCheck,ForAll(Filter(Employers,ID=varWrkSaveEmpID) As emp,{ID:emp.ID,Active:Coalesce(emp.Active,true)}))')) 'Workers: newly assigned contractor re-read by ID (global var set before the gate, Refresh first, counted in the reads)'
$iEcAt = $wSave.IndexOf('If(IsEmpty(colWrkSaveErrors) && varWrkSaveContractorChanged,')
Assert-True ($iEcAt -gt $wSave.IndexOf('If(IsEmpty(colWrkSaveErrors) && varWrkSaveDeactivate,') -and $iEcAt -lt $wSave.IndexOf('ClearCollect(colWrkPatched,')) 'Workers: contractor re-read after the deactivation check, directly before the Patch'
$wEcDec = WBal 'If(IsEmpty(colWrkSaveErrors) && (CountRows(colWrkEmpCheck)<>1'
$wEcArgs = Split-Args $wEcDec.Substring(1, $wEcDec.Length - 2)
$wEcMsg = [regex]::Match($wEcArgs[1], 'Message:(If\(CountRows.*)\}\)\s*$').Groups[1].Value
foreach ($c in @(@('Table({ID:3,Active:true})', 'false', '', 'active, one row: no error'), @('Table({ID:3,Active:false})', 'true', 'Fix: Contractor inactive', 'deactivated meanwhile in SharePoint'), @('Filter(Table({ID:3,Active:true}),false)', 'true', 'Fix: Contractor unknown', 'no longer in SharePoint'), @('Table({ID:3,Active:true},{ID:3,Active:true})', 'true', 'Fix: Contractor unknown', 'not exactly one row'))) {
    $cond = $wEcArgs[0].Replace('IsEmpty(colWrkSaveErrors) && ', '')
    Assert-Eval "With({LangNl:false,T:$tRec,colWrkEmpCheck:$($c[0])},Text($cond) & `"|`" & If($cond,$wEcMsg,`"`"))" ($c[1] + '|' + $c[2]) "Workers contractor re-read: $($c[3]) -> error $($c[1]) $($c[2])"
}
Assert-True (([regex]::Matches($wEcBlk, [regex]::Escape('{Field:"",Message:' + (TTw 'wrkErrPreRead') + '}'))).Count -eq 2 -and $wEcBlk.Contains('IfError(Refresh(Employers),Collect(colWrkSaveErrors,{Field:"",Message:' + (TTw 'wrkErrPreRead') + '});false);') -and ([regex]::Matches($wEcBlk, 'wrkErrContractorUnknown\.en')).Count -eq 1 -and ([regex]::Matches($wEcBlk, 'wrkErrContractorInactive\.en')).Count -eq 1 -and $wEcBlk -notmatch 'Patch\(') 'Workers: re-read Refresh/read errors = T.wrkErrPreRead (Field ""); unknown only for not exactly 1 row, inactive for Active false (field Contractor); no write in the block'
# Reviewer 08-11-2026 (non-blocking 4): duplicate check (local, server read, Save anyway) only for New or a changed name/contractor
$wDnFx = WFlag 'varWrkSaveDupNeeded'
foreach ($c in @(@('"Edit"', '"Test"', '"Fitter 2"', '"TEST Employer"', $false, 'Edit, name and contractor unchanged'), @('"Edit"', '"test"', '"FITTER 2"', '"test employer"', $false, 'Edit, only case differs'), @('"Edit"', '"Tess"', '"Fitter 2"', '"TEST Employer"', $true, 'Edit, First Name changed'), @('"Edit"', '"Test"', '"Welder 2"', '"TEST Employer"', $true, 'Edit, Surname changed'), @('"Edit"', '"Test"', '"Fitter 2"', '"Other"', $true, 'Edit, contractor changed'), @('"New"', '"Test"', '"Fitter 2"', '"TEST Employer"', $true, 'New'))) {
    Assert-Eval "With({varWrkSaveMode:$($c[0]),varWrkEdit:$wSnap,varWrkSaveRec:{FirstName:$($c[1]),Surname:$($c[2]),Contractor:$($c[3])}},$wDnFx)" $c[4] "Workers duplicate check needed: $($c[5]) -> $($c[4])"
}
Assert-True ($wSaveN.Contains((Norm 'If(IsEmpty(colWrkSaveErrors) && varWrkSaveDupNeeded,ClearCollect(colWrkDupLocal,')) -and $wSaveN.Contains((Norm 'If(IsEmpty(colWrkSaveErrors) && varWrkSaveDupNeeded,Set(varWrkSaveReads,varWrkSaveReads+1);IfError(CountRows(ClearCollect(colWrkDup,')) -and $wSave.IndexOf('Set(varWrkSaveDupNeeded,') -lt $wSave.IndexOf('ClearCollect(colWrkDupLocal,')) 'Workers: local duplicate pre-check and server duplicate read only when the duplicate check is needed (unchanged Edit = no read, no warning)'
# Reviewer 08-11-2026 (non-blocking 9): blank project title -> "Project ID <Project.Id>"
Assert-Eval "With({LangNl:false,T:$tRec,varWrkSaveID:5,colWrkActivePW:Table({ID:11,WorkerID:5,ProjectID:7,ProjectTitle:`"`"},{ID:12,WorkerID:5,ProjectID:8,ProjectTitle:`"Beta`"})},$wDeMsg)" 'Still active in Project / team: Project ID 7, Beta. Uncheck in Project / team first.' 'Workers: blocked deactivation shows "Project ID <Project.Id>" when the project title is blank'# (W10) Conflict check (pre-read vs loaded snapshot) and verify (read-back vs save record) on the app-written fields -----------
$wConfIf = Get-Balanced $wSave ($wSave.IndexOf('If(p.ID<>varWrkSaveID') + 2); $wConfCond = (Split-Args $wConfIf.Substring(1, $wConfIf.Length - 2))[0]
Assert-True ($wConfIf.Contains('Collect(colWrkSaveErrors,{Field:"",Message:' + (TTw 'wrkErrConflict') + '})') -and $wConfCond -notmatch 'Code|Modified|EmployerName|Contractor\b') 'Workers: conflict -> exact conflict message; compares the written fields only (not Worker Code, Modified, the lookup text)'
Assert-Eval "With({LangNl:false,T:$tRec},T.wrkErrConflict.en)" 'Changed in SharePoint by someone else. Nothing saved. Click Discard, then Refresh.' 'Workers: conflict message text exact (AGENTS)'
$wPre = '{ID:5,FirstName:"Test",Surname:"Fitter 2",Code:"WKR-005",Trade:"Fitter",EmployerID:3,EmployerName:"TEST Employer",Contractor:"TEST Employer",Language:"Nederlands",Active:true}'
foreach ($c in @(@('', '', $false, 'unchanged'), @('FirstName:"Test"', 'FirstName:"Tess"', $true, 'First Name'), @('Surname:"Fitter 2"', 'Surname:"Fitter 3"', $true, 'Surname'), @('Trade:"Fitter"', 'Trade:"Welder"', $true, 'Trade'), @('EmployerID:3', 'EmployerID:4', $true, 'Employer.Id'), @('Language:"Nederlands"', 'Language:"English"', $true, 'Language'), @('Active:true', 'Active:false', $true, 'Active'), @('Code:"WKR-005"', 'Code:"WKR-099"', $false, 'Worker Code (flow field)'), @('EmployerName:"TEST Employer"', 'EmployerName:"Renamed"', $false, 'contractor renamed (lookup text)'))) {
    $pf = if ($c[0]) { $wPre.Replace($c[0], $c[1]) } else { $wPre }
    Assert-Eval "With({p:$pf,varWrkEdit:$wPre,varWrkSaveID:5},$wConfCond)" $c[2] "Workers conflict: another user changed $($c[3]) -> conflict=$($c[2])"
}
$wTbl = Get-Balanced $wSave ($wSave.IndexOf('With({d:Filter(Table(') + 'With({d:Filter'.Length)
$wTblFx = (Split-Args $wTbl.Substring(1, $wTbl.Length - 2))[0]
Assert-Eval "With({LangNl:false,T:$tRec,v:$wPre,varWrkSaveRec:{FirstName:`"Test`",Surname:`"Fitter 2`",Trade:`"Fitter`",Language:`"Nederlands`",Active:true},varWrkSaveEmp:{ID:3,Name:`"TEST Employer`"}},Concat($wTblFx,F,`",`"))" 'FirstName,Surname,Trade,Contractor,Language,Active' 'Workers verify covers exactly First Name, Surname, Trade, Contractor (Employer.Id), Language, Active'
$wPreMoved = $wPre.Replace('EmployerID:3', 'EmployerID:4').Replace('Code:"WKR-005"', 'Code:""')
Assert-Eval "With({LangNl:false,T:$tRec,v:$wPreMoved,varWrkSaveRec:{FirstName:`"Test`",Surname:`"Fitter 2`",Trade:`"Fitter`",Language:`"Nederlands`",Active:true},varWrkSaveEmp:{ID:3,Name:`"TEST Employer`"}},Concat(Filter($wTblFx,D),L,`",`"))" 'Contractor' 'Workers verify: a different Employer.Id fails (label Contractor); Worker Code is not compared'
# (W11) write counter, control read and outcome (shared helper, same rules as Contractors/Projects)
Test-WriteCounter $wSave 'Wrk' 'Workers' 'Workers'
# (W12) 8b: Discard in New mode returns to the previous record (shared helper)
$wDiscCases = @(@('false', '""', '1', '"Loaded"', $noErr, '1', 'previous record visible -> restored'), @('false', '""', '2', '"Loaded"', $noErr, '3', 'previous record inactive, Show inactive off -> first visible row'), @('true', '""', '2', '"Loaded"', $noErr, '2', 'previous inactive record shown (Show inactive on) -> restored'), @('false', '""', '99', '"Loaded"', $noErr, '3', 'previous record no longer in the loaded list -> first visible row'), @('false', '""', 'If(false,0)', '"Loaded"', $noErr, '3', 'no previous record -> first visible row'), @('false', '"delft"', '1', '"Loaded"', $noErr, '3', 'previous record hidden by the search text -> first visible row'), @('false', '"nomatch"', '1', '"Loaded"', $noErr, 'blank', 'empty visible list -> no selection (Mode "")'), @('false', '""', '1', '"Failed"', $noErr, 'blank', 'load not Loaded -> no selection'), @('false', '""', '1', '"Loaded"', 'Table({Message:"x"})', 'blank', 'load errors present -> no selection'))
Test-DiscardNew 'Wrk' 'Workers' $wGuards.btnWrkDiscard $wDirty (WProp 'btnWrkDiscard' 'OnSelect') (WProp 'btnWrkNew' 'OnSelect') $wLoad $wItems 'colAdminWorkers' $wEmpty $wSelFix $wDiscCases $wAll 'FirstName'
$wEditSets = Get-SetValues $wText 'varWrkEdit'
Assert-True (@($wEditSets | Where-Object { $_ -notmatch '^(LookUp\(colAdminWorkers,ID=varWrkSelectedID\)|First\(colWrkVerify\)|\{ID:Blank\(\),.*Active:true\})$' }).Count -eq 0) "Workers: varWrkEdit only from the loaded list, the verify read or the empty/New snapshot ($($wEditSets -join ' | '))"

# (W13) After a verified save: local list from the verify read only, caches invalidated, contractor-change information ----------
$wOk = WBal 'If(varWrkSaveVerified && IsEmpty(colWrkSaveErrors),'
Assert-True ($wOk.Contains('RemoveIf(colAdminWorkers,ID=varWrkPatchedID); Collect(colAdminWorkers,First(colWrkVerify));') -and $wOk.Contains('Set(varWrkEdit,First(colWrkVerify));') -and $wSave.IndexOf('RemoveIf(colAdminWorkers') -gt $wSave.IndexOf('ClearCollect(colWrkVerifyRaw')) 'Workers: the list and the snapshot are updated only from the verify read'
Assert-True ($wOk.Contains('Set(varWorkersCacheReady,false); Set(varMastersReady,false); Set(varReportReady,false); Set(varReportValid,false);') -and $wOk.Contains('IfError(Refresh(Workers),Set(varWrkSaveRefreshFailed,true);false);')) 'Workers: verified save invalidates the worker/master/report caches (2.7) and refreshes the Workers connector'
$wMvFx = WFlag 'varWrkSaveContractorMoved'
foreach ($c in @(@('"Edit"', '3', '5', $true, 'contractor changed'), @('"Edit"', '3', '3', $false, 'same contractor'), @('"New"', 'If(false,0)', '3', $false, 'New worker'))) { Assert-Eval "With({varWrkSaveMode:$($c[0]),varWrkEdit:{EmployerID:$($c[1])},varWrkSaveEmp:{ID:$($c[2])}},$wMvFx)" $c[3] "Workers: contractor moved = $($c[3]) ($($c[4]))" }
$wMsgAt = $wOk.IndexOf('Set(varAdmMsgBody,Trim('); $wMsgSet = Get-Balanced $wOk ($wMsgAt + 3); $wMsgFx = $wMsgSet.Substring('(varAdmMsgBody,'.Length, $wMsgSet.Length - '(varAdmMsgBody,'.Length - 1)
Assert-Eval "With({LangNl:false,T:$tRec,varWrkSaveContractorMoved:true,varWrkSaveRefreshFailed:false},$wMsgFx)" 'Saved. Old hours keep the old contractor.' 'Workers: contractor change -> amber "Attention." body "Saved. Old hours keep the old contractor."'
Assert-True ($wOk.Contains('If(varWrkSaveContractorMoved || varWrkSaveRefreshFailed,') -and $wOk.Contains('Set(varAdmMsgKind,"Warning"); Set(varAdmMsgHead,' + (TTw 'admHeadAttention') + ');') -and $wOk.Contains('Set(varAdmMsgKind,"Success"); Set(varAdmMsgHead,' + (TTw 'admHeadSaved') + '); Set(varAdmMsgBody,"")')) 'Workers: saved with information = amber Attention (body starts with Saved.), else green Saved.'

# (W14) Texts via T (English, nl empty), traces without names, no Remove on SharePoint lists, Home tile -----------------------
$wKeys = @([regex]::Matches($wText, '\bT\.(\w+)\.en\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-True ($wKeys.Count -ge 50) "Workers: $($wKeys.Count) T keys used"
foreach ($k in $wKeys) { Assert-Eval "With({T:$tRec},!IsBlank(T.$k.en) && IsBlank(T.$k.nl))" $true "Workers: T.$k exists with English text (nl empty)" }
$wLits = @(@($wIdx.Keys) | Where-Object { $wIdx[$_]['Properties'].ContainsKey('Text') -and $wIdx[$_]['Control'] -like 'Label@*' } | Where-Object { ([string]$wIdx[$_]['Properties']['Text']).Trim() -match '^="[^"]+"$' })
Assert-True ($wLits.Count -eq 0) "Workers: no hard-coded visible label text (all through T) ($($wLits -join ', '))"
$wTraces = @([regex]::Matches($wText, 'Trace\("DIAG\|Workers\|\w+",TraceSeverity\.\w+,\{[^{}]*\}\)') | ForEach-Object { $_.Value })
Assert-True ($wTraces.Count -ge 10 -and @($wTraces | Where-Object { $_ -match 'FirstName|Surname|Contractor:|varWrkSaveRec|FirstError|DupCodes|DupKey' }).Count -eq 0 -and ([regex]::Matches($wText, 'Trace\(')).Count -eq $wTraces.Count) "Workers: $($wTraces.Count) traces DIAG|Workers|* with IDs, counts and flags only (no names, codes or SharePoint messages)"
Assert-True ($wText -notmatch "\b(?:Remove|RemoveIf|Clear|Update|UpdateIf)\(\s*(?:Workers|Employers|'Project Workers')\b" -and $wText -notmatch '\.Run\(') 'Workers: no Remove/Clear/Update on SharePoint lists, no flow call (deactivate = Active false)'
$hIdx = @{}; Index-Controls ($builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $srcDir 'scrHome.pa.yaml'))))['Screens']['scrHome']['Children'] $hIdx
Assert-True (([string]$hIdx['cmpTileWorkers']['Properties']['Active']).Trim() -eq '=true' -and ([string]$hIdx['cmpTileWorkers']['Properties']['OnSelect']).Trim() -ceq '=Navigate(scrWorkers); true' -and ([string]$hIdx['cmpTileWorkers']['Properties']['IconSvg']).Trim() -ceq '=IconWorkersWhite') 'Home: Workers tile active (white icon) and navigates to scrWorkers'
Assert-True (@([IO.File]::ReadAllText((Join-Path $srcDir '_EditorState.pa.yaml')) -split "`n" | Where-Object { $_.Trim() -eq '- scrWorkers' }).Count -eq 1) 'Workers: scrWorkers registered in _EditorState ScreensOrder'
Write-Output 'PASS Test-AdminScreens (Workers): static structure only. Studio import, binding (Choices([@Workers].Trade/Language), Worker Name display name, Employer lookup Patch), delegation (Filter Project Workers Active=true, Workers First Name/Surname =), SharePoint case-sensitivity and functional tests NOT verified.'
