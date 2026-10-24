$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$pacDir=Split-Path (Get-Command pac).Source
[Reflection.Assembly]::LoadFrom((Join-Path $pacDir 'YamlDotNet.dll')) | Out-Null
$deserializer=(New-Object YamlDotNet.Serialization.DeserializerBuilder).Build()
# Reuse editing functions only, without executing the previous installer.
$helpers=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Repair-ReadExisting.ps1'))
Invoke-Expression $helpers.Substring($helpers.IndexOf('function Property'),$helpers.IndexOf('$path=Join-Path')-$helpers.IndexOf('function Property'))
function Put($name,$key,$value) {
 Property $name $key $value
 $script:source=$script:source -replace '(?m)(\S)( +-[ ]\w+:)','$1' # no-op for normal YAML
}
function Read-Screen($name) {
 $script:path=Join-Path $root ('Src/'+$name+'.pa.yaml')
 $script:source=[IO.File]::ReadAllText($script:path)
 $doc=$deserializer.Deserialize($script:source); $script:controls=@{}
 Index-Controls $doc['Screens'][$name]['Children'] $script:controls
}
function Write-Screen { [IO.File]::WriteAllText($script:path,$script:source,(New-Object Text.UTF8Encoding($false))) }
function Replace-Property($name,$key,$value) {
 # Preserve the trailing newline even when the replaced property is last.
 $head=[regex]::Match($script:source,'(?m)^( +)- '+[regex]::Escape($name)+':\r?$')
 $indent=$head.Groups[1].Value+'      '
 $pattern='(?m)^'+$indent+[regex]::Escape($key)+':[^\r\n]*(?:\r?\n(?:'+$indent+'  [^\r\n]*|[ \t]*(?=\r?$)))*'
 $start=$head.Index
 $rest=$script:source.Substring($start)
 $match=[regex]::Match($rest,$pattern)
 if(!$match.Success){throw "Missing $name.$key"}
 $line=$indent+$key+': '+$value
 if($value -match '[\r\n]') { $line=$indent+$key+": |-`n"+(($value.TrimEnd() -split '\r?\n' | ForEach-Object {$indent+'  '+$_}) -join "`n") }
 $script:source=$script:source.Substring(0,$start+$match.Index)+$line+"`n"+$rest.Substring($match.Index+$match.Length).TrimStart("`r","`n")
}
function Add-Refresh($name,$action,$x,$y,$disabled) {
 Add-Root @"
- ${name}:
    Control: Classic/Button@2.2.0
    Properties:
      Text: ="Refresh"
      OnSelect: =$action
      DisplayMode: =If($disabled,DisplayMode.Disabled,DisplayMode.Edit)
      X: =$x
      Y: =$y
      Width: =110
      Height: =40
      Font: =Font.'Segoe UI'
      Size: =14
      FontWeight: =FontWeight.Semibold
      Align: =Align.Center
      VerticalAlign: =VerticalAlign.Middle
      PaddingTop: =0
      PaddingBottom: =0
      PaddingLeft: =16
      PaddingRight: =16
      RadiusTopLeft: =8
      RadiusTopRight: =8
      RadiusBottomLeft: =8
      RadiusBottomRight: =8
"@
}
$invalidate='Set(varDataEpoch,Coalesce(varDataEpoch,0)+1); Clear(colWeekCache);'
Read-Screen 'Screen1'
$team=$controls['btnReadTeam']['Properties']['OnSelect']
$team=$team.Replace('=If(!varSelectionBusy && !varSaving,','=If(!varSelectionBusy && !varSaving && (!varSelectionLoaded || Coalesce(varSelectionEpoch,-1)<>Coalesce(varDataEpoch,0) || Coalesce(varSelectionProjectID,0)<>Coalesce(ddProject.Selected.Id,0) || Coalesce(varSelectionTeam,"")<>Coalesce(ddTeam.Selected.Value,"")),')
$team=[regex]::Replace($team,'(?m)^ IfError\(Refresh\([^\r\n]+\r?\n','')
$team=$team.Replace('Set(varSelectionLoaded,true);','Set(varSelectionLoaded,true); Set(varSelectionEpoch,Coalesce(varDataEpoch,0));')
Replace-Property 'btnReadTeam' 'OnSelect' $team
Replace-Property 'btnGotoHours' 'OnSelect' ($controls['btnGotoHours']['Properties']['OnSelect'].Replace("Refresh('Project Workers');",''))
Replace-Property 'btnAddtoTeam' 'OnSelect' ('='+$invalidate+ $controls['btnAddtoTeam']['Properties']['OnSelect'].TrimStart('='))
Add-Refresh 'btnRefreshTeam' ($invalidate+' Set(varSelectionLoaded,false); Set(varSelectionBusy,true); IfError(Refresh(Projects); Refresh(Workers); Refresh(''Project Workers''),Notify(FirstError.Message,NotificationType.Error)); Set(varSelectionBusy,false); Select(btnReadTeam)') '40' '176' 'varSelectionBusy || varSaving'
Write-Screen
Read-Screen 'scrHours'
$week=$controls['btnReadWeek']['Properties']['OnSelect']
$key='Text(Coalesce(varProject.Id,ddProject.Selected.Id)) & "|" & Coalesce(varTeam.Value,ddTeam.Selected.Value) & "|" & Text(ddHoursYear.Selected.Value) & "|" & Text(ddHoursWeek.Selected.Value)'
$week=[regex]::Replace($week,'(?m)^   IfError\(Refresh\([^\r\n]+\r?\n','')
$week=$week.Replace('If(IsEmpty(colWeekLoadErrors),'+"`n"+'    Set(varEntryFirstISOYear','If(IsEmpty(colWeekLoadErrors) && Coalesce(varEntryYearsEpoch,-1)<>Coalesce(varDataEpoch,0),'+"`n"+'    Set(varEntryFirstISOYear')
# Accept CRLF source as well.
$week=$week.Replace("If(IsEmpty(colWeekLoadErrors),`r`n    Set(varEntryFirstISOYear","If(IsEmpty(colWeekLoadErrors) && Coalesce(varEntryYearsEpoch,-1)<>Coalesce(varDataEpoch,0),`r`n    Set(varEntryFirstISOYear")
$week=$week.Replace('Set(varWeekReady,true);','Set(varWeekReady,true); Set(varEntryYearsEpoch,Coalesce(varDataEpoch,0));')
$week=$week.TrimStart('=' )
$wrapped=@"
=If(!varWeekLoading && !varWeekSaving,
 With({requestKey:$key,epoch:Coalesce(varDataEpoch,0)},
  If(!(varWeekReady && varWeekRequestKey=requestKey && varWeekEpoch=epoch),
   With({cached:LookUp(colWeekCache,CacheKey=requestKey && Epoch=epoch)},
    If(!IsBlank(cached.CacheKey),
     ClearCollect(colWeekRows,cached.Rows); ClearCollect(colWeekOriginal,cached.Rows);
     Set(varLoadedWeekMonday,cached.Monday); Set(varWeekMonday,cached.Monday);
     Set(varWeekKeyIssue,cached.KeyIssue); Set(varWeekMessage,cached.Message);
     Clear(colWeekLoadErrors); Set(varWeekReady,true),
     $week;
     If(varWeekReady,
      Collect(colWeekCache,{CacheKey:requestKey,Epoch:epoch,Rows:colWeekRows,Monday:varLoadedWeekMonday,KeyIssue:varWeekKeyIssue,Message:varWeekMessage})
     )
    );
    If(varWeekReady,Set(varWeekRequestKey,requestKey); Set(varWeekEpoch,epoch))
   )
  )
 )
)
"@
Replace-Property 'btnReadWeek' 'OnSelect' $wrapped
Replace-Property 'btnSaveWeek' 'OnSelect' ('='+$invalidate+$controls['btnSaveWeek']['Properties']['OnSelect'].TrimStart('='))
Add-Refresh 'btnRefreshWeek' ($invalidate+' Set(varWeekReady,false); IfError(Refresh(Hours); Refresh(''Project Workers''),Notify(FirstError.Message,NotificationType.Error)); Select(btnReadWeek)') 'btnSaveWeek.X-122' 'btnSaveWeek.Y' 'varWeekLoading || varWeekSaving || JSON(ShowColumns(colWeekRows,MonHours,TueHours,WedHours,ThuHours,FriHours,SatHours,SunHours))<>JSON(ShowColumns(colWeekOriginal,MonHours,TueHours,WedHours,ThuHours,FriHours,SatHours,SunHours))'
Write-Screen
Read-Screen 'scrWeeklyHours'
$report=$controls['btnRefreshReport']['Properties']['OnSelect']
$report=[regex]::Replace($report,'(?m)^\s*IfError\(Refresh\([^\r\n]+\r?\n','')
$report=$report.Replace('Set(varReportReady,true)','Set(varReportReady,true); Set(varReportEpoch,Coalesce(varDataEpoch,0))')
$report=$report.Replace('=If(!varReportBusy,','=If(!varReportBusy && (!varReportReady || Coalesce(varReportEpoch,-1)<>Coalesce(varDataEpoch,0) || Coalesce(varReportProjectID,0)<>Coalesce(ddReportProject.Selected.ID,0)),')
# Hidden loading action is separate from explicit Refresh.
$block="- btnLoadReport:`n    Control: Classic/Button@2.2.0`n    Properties:`n      Text: =`"Read`"`n      Visible: =false`n      Width: =1`n      Height: =1`n      OnSelect: |-`n"+(($report -split '\r?\n' | ForEach-Object {'        '+$_}) -join "`n")
# Summary root uses four spaces instead of six.
$script:source=$script:source.TrimEnd()+"`n"+(($block -split '\r?\n'|ForEach-Object {'    '+$_})-join "`n")+"`n"
Replace-Property 'btnRefreshReport' 'OnSelect' ('='+$invalidate+' Set(varReportReady,false); IfError(Refresh(Projects); Refresh(Hours); Refresh(''Project Workers''); Refresh(Workers),Notify(FirstError.Message,NotificationType.Error)); Select(btnLoadReport)')
Replace-Property 'ddReportProject' 'OnChange' ($controls['ddReportProject']['Properties']['OnChange'].Replace('Select(btnRefreshReport)','Select(btnLoadReport)'))
Screen-Event 'scrWeeklyHours' 'OnVisible' '=Select(btnLoadReport)'
Write-Screen


