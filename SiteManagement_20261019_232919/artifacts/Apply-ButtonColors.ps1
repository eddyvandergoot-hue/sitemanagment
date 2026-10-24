$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$navigation=@('btnGotoHours','btnGotoHoursSummary','btnWeeklyProjectTeam','btnSummaryProjectTeam')
$actions=@('btnAddtoTeam','btnRefreshTeam','btnSaveWeek','btnRefreshWeek','btnRefreshReport','btnReportPreviousWeeks','btnReportNextWeeks')
foreach($file in Get-ChildItem (Join-Path $root 'Src') -Filter '*.pa.yaml'){
 $source=[IO.File]::ReadAllText($file.FullName)
 foreach($name in ($navigation+$actions)){
  $head=[regex]::Match($source,'(?m)^( +)- '+$name+':\r?$')
  if(!$head.Success){continue}
  $indent=$head.Groups[1].Value
  $pattern='(?ms)^'+$indent+'- '+$name+':.*?(?=^ {0,'+$indent.Length+'}\S|\z)'
  $fill=if($name -in $navigation){'#194296'}else{'#7040A0'}
  $hover=if($name -in $navigation){'#123273'}else{'#593080'}
  $colors=[ordered]@{Fill=('=ColorValue("'+$fill+'")');HoverFill=('=ColorValue("'+$hover+'")');PressedFill=('=ColorValue("'+$hover+'")');Color='=Color.White';HoverColor='=Color.White';PressedColor='=Color.White';DisabledFill='=ColorValue("#E5E7EB")';DisabledColor='=ColorValue("#6B7280")';BorderColor=('=ColorValue("'+$fill+'")');HoverBorderColor=('=ColorValue("'+$hover+'")');PressedBorderColor=('=ColorValue("'+$hover+'")')}
  $source=[regex]::Replace($source,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($match)
   $block=$match.Value
   $pi=$indent+'      '
   foreach($key in $colors.Keys){
    $pp='(?m)^'+$pi+$key+':[^\r\n]*(?:\r?\n'+$pi+'  [^\r\n]*)*'
    $line=$pi+$key+': '+$colors[$key]
    if([regex]::IsMatch($block,$pp)){$block=[regex]::Replace($block,$pp,[Text.RegularExpressions.MatchEvaluator]{param($property) $line})}
    else{$properties=[regex]::Match($block,'(?m)^'+$indent+'    Properties:\r?\n');if(!$properties.Success){throw 'Properties missing'};$block=$block.Insert($properties.Index+$properties.Length,$line+"`n")}
   }
   $block
  })
 }
 [IO.File]::WriteAllText($file.FullName,$source,(New-Object Text.UTF8Encoding($false)))
}
