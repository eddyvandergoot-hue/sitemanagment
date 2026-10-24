$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-ReadExisting.ps1')
$checkpoint=Join-Path $projectRoot (Get-Content (Join-Path $PSScriptRoot 'performance-backup.txt') -Raw).Trim()
$allowed=@{
 Screen1=@{btnReadTeam=@('OnSelect');btnGotoHours=@('OnSelect');btnAddtoTeam=@('OnSelect');Gallery1=@('Y');lblSelectionLoadStatus=@('Y')}
 scrHours=@{btnReadWeek=@('OnSelect');btnSaveWeek=@('OnSelect','X','Y');lblWeekLoadStatus=@('Y');galHours=@('Y')}
 scrWeeklyHours=@{btnRefreshReport=@('OnSelect');ddReportProject=@('OnChange')}
}
foreach($screen in $currentIndexes.Keys){
 $doc=$builder.Build().Deserialize([IO.File]::ReadAllText((Join-Path $checkpoint ('Src/'+$screen+'.pa.yaml'))))
 $old=@{}; Index-ReadControls $doc['Screens'][$screen]['Children'] $old
 foreach($name in $old.Keys){
  if(!$currentIndexes[$screen].ContainsKey($name)){throw "Removed control $name"}
  foreach($property in $old[$name]['Properties'].Keys){
   if($old[$name]['Properties'][$property] -cne $currentIndexes[$screen][$name]['Properties'][$property]){
    $permitted=$allowed[$screen][$name]
    if($screen -eq 'scrHours' -and $property -eq 'Y' -and $old[$name]['Properties']['Y'] -eq '=226'){$permitted=@('Y')}
    if($property -notin $permitted){throw "Unexpected diff: $screen.$name.$property"}
    Write-Output "DIFF $screen.$name.$property"
   }
  }
 }
}
foreach($name in @('App.pa.yaml','_EditorState.pa.yaml')){
 if((Get-FileHash (Join-Path $checkpoint ('Src/'+$name))).Hash -ne (Get-FileHash (Join-Path $projectRoot ('Src/'+$name))).Hash){throw "Unexpected $name change"}
}
$week=$currentIndexes.scrHours['btnReadWeek']['Properties']['OnSelect']
$report=$currentIndexes.scrWeeklyHours['btnLoadReport']['Properties']['OnSelect']
if($week -notmatch 'CacheKey=requestKey && Epoch=epoch' -or $report -notmatch 'ProjectID=ddReportProject.Selected.ID && Epoch=Coalesce\(varDataEpoch,0\)'){throw 'Cache identity/epoch guard absent'}
if($report -notmatch 'If\(CountRows\(batch\)<500' -or $report -notmatch 'CountRows\(batch\)>=500'){throw 'Fast/fallback completeness guards absent'}
foreach($pair in @(@('Screen1','btnRefreshTeam'),@('scrHours','btnRefreshWeek'),@('scrWeeklyHours','btnRefreshReport'),@('Screen1','btnAddtoTeam'),@('scrHours','btnSaveWeek'))){
 $fx=$currentIndexes[$pair[0]][$pair[1]]['Properties']['OnSelect']
 if($fx -notmatch 'Set\(varDataEpoch,Coalesce\(varDataEpoch,0\)\+1\)' -or $fx -notmatch 'Clear\(colReportCache\)'){throw 'Invalidation missing'}
}
Expect-Read 'With({colWeekCache:Table({CacheKey:"7|2|2020|53",Epoch:1,Rows:Table({MonHours:8})},{CacheKey:"8|2|2020|53",Epoch:1,Rows:Table({MonHours:99})}),requestKey:"7|2|2020|53",epoch:1},Sum(LookUp(colWeekCache,CacheKey=requestKey && Epoch=epoch).Rows,MonHours))' 8 'Nested cache isolates project/team/week'
Expect-Read 'With({colReportCache:Table({ProjectID:7,Epoch:1}),selectedID:7,epoch:2},IsBlank(LookUp(colReportCache,ProjectID=selectedID && Epoch=epoch).ProjectID))' $true 'Invalidated epoch rejects old cached project'
foreach($n in @(0,499,500,501)){
 Expect-Read ('With({batch:Sequence('+$n+')},CountRows(batch)<500)') ($n -lt 500) "Fast history path completeness boundary $n"
}
Write-Output 'PASS scoped property diff, cache guards, invalidation sites, fast/fallback guards. No online performance measurement.'
