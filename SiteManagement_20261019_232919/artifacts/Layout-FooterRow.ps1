$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
function Control-Block($text,$name){
 $h=[regex]::Match($text,'(?m)^( +)- '+$name+':\r?$');if(!$h.Success){throw "Missing $name"}
 $p='(?ms)^'+$h.Groups[1].Value+'- '+$name+':.*?(?=^ {0,'+$h.Groups[1].Length+'}\S|\z)'
 return [regex]::Match($text,$p)
}
function Layout-Property($name,$key,$value){
 $m=Control-Block $script:source $name;$indent=[regex]::Match($m.Value,'^ +').Value+'      '
 $pattern='(?m)^'+$indent+$key+':[^\r\n]*(?:\r?\n'+$indent+'  [^\r\n]*)*'
 $line=$indent+$key+': '+$value
 if([regex]::IsMatch($m.Value,$pattern)){$block=[regex]::Replace($m.Value,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($p)$line})}
 else{$properties=[regex]::Match($m.Value,'(?m)^ +Properties:\r?\n');$block=$m.Value.Insert($properties.Index+$properties.Length,$line+"`n")}
 $script:source=$script:source.Remove($m.Index,$m.Length).Insert($m.Index,$block)
}
$screens=@(
 @{Screen='Screen1';Bar='navProjectTeam';Row='conProjectButtonRow';Nav=@('btnGotoHours','btnGotoHoursSummary');Actions=@('btnRefreshTeam','btnAddtoTeam')},
 @{Screen='scrHours';Bar='navWeeklyHours';Row='conWeekButtonRow';Nav=@('btnWeeklyProjectTeam');Actions=@('btnRefreshWeek','btnSaveWeek')},
 @{Screen='scrWeeklyHours';Bar='navHoursSummary';Row='conSummaryButtonRow';Nav=@('btnSummaryProjectTeam');Actions=@('btnReportPreviousWeeks','btnReportNextWeeks','btnRefreshReport')}
)
foreach($cfg in $screens){
 $path=Join-Path $root ('Src/'+$cfg.Screen+'.pa.yaml');$script:source=[IO.File]::ReadAllText($path)
 $rootIndent=if($cfg.Screen -eq 'scrWeeklyHours'){'    '}else{'      '}
 $blocks=@{};$buttons=$cfg.Nav+$cfg.Actions
 foreach($name in $buttons){
  Layout-Property $name 'Y' '=lblFooterButtonMetrics.Y'
  Layout-Property $name 'Height' '=lblFooterButtonMetrics.Height'
 }
 for($i=0;$i -lt $cfg.Nav.Count;$i++){
  $x=if($i -eq 0){'=lblFooterButtonMetrics.X'}else{'='+$cfg.Nav[$i-1]+'.X+'+$cfg.Nav[$i-1]+'.Width+lblFooterButtonMetrics.Width'}
  Layout-Property $cfg.Nav[$i] 'X' $x
 }
 for($i=$cfg.Actions.Count-1;$i -ge 0;$i--){
  $x=if($i -eq $cfg.Actions.Count-1){'=Parent.Width-lblFooterButtonMetrics.X-Self.Width'}else{'='+$cfg.Actions[$i+1]+'.X-lblFooterButtonMetrics.Width-Self.Width'}
  Layout-Property $cfg.Actions[$i] 'X' $x
 }
 foreach($name in @('btnReportPreviousWeeks','btnReportNextWeeks')){
  if($name -in $buttons){foreach($pair in @(@('Font',"=Font.'Segoe UI'"),@('Size','=14'),@('FontWeight','=FontWeight.Semibold'),@('Align','=Align.Center'),@('VerticalAlign','=VerticalAlign.Middle'),@('PaddingTop','=0'),@('PaddingBottom','=0'),@('PaddingLeft','=16'),@('PaddingRight','=16'),@('RadiusTopLeft','=8'),@('RadiusTopRight','=8'),@('RadiusBottomLeft','=8'),@('RadiusBottomRight','=8'))){Layout-Property $name $pair[0] $pair[1]}}
 }
 foreach($name in $buttons){
  $m=Control-Block $script:source $name;$oldIndent=[regex]::Match($m.Value,'^ +').Length
  $blocks[$name]=(($m.Value.TrimEnd() -split '\r?\n' | ForEach-Object {if($_.Length -ge $oldIndent){$_.Substring($oldIndent)}else{''}})-join "`n")
  $script:source=$script:source.Remove($m.Index,$m.Length)
 }
 $m=Control-Block $script:source $cfg.Bar;$script:source=$script:source.Remove($m.Index,$m.Length)
 $minWidth='2*lblFooterButtonMetrics.X+'+(($buttons|ForEach-Object {$_+'.Width'}) -join '+')+'+'+($buttons.Count-1)+'*lblFooterButtonMetrics.Width'
 $bar=@"
- $($cfg.Bar):
    Control: GroupContainer@1.5.0
    Variant: AutoLayout
    Properties:
      X: =0
      Y: =Parent.Height-Self.Height
      Width: =Parent.Width
      Height: =2*lblFooterButtonMetrics.Y+lblFooterButtonMetrics.Height+16
      Fill: =RGBA(244,246,250,1)
      LayoutDirection: =LayoutDirection.Vertical
      LayoutAlignItems: =LayoutAlignItems.Start
      LayoutJustifyContent: =LayoutJustifyContent.Start
      LayoutWrap: =false
      LayoutOverflowX: =LayoutOverflow.Scroll
      LayoutOverflowY: =LayoutOverflow.Hide
      LayoutGap: =0
      PaddingTop: =0
      PaddingBottom: =0
      PaddingLeft: =0
      PaddingRight: =0
    Children:
      - $($cfg.Row):
          Control: GroupContainer@1.5.0
          Variant: ManualLayout
          Properties:
            Width: =Max(Parent.Width,$minWidth)
            Height: =2*lblFooterButtonMetrics.Y+lblFooterButtonMetrics.Height
            FillPortions: =0
            Fill: =Color.Transparent
          Children:
"@
 foreach($name in $buttons){$bar+="`n"+(($blocks[$name] -split '\r?\n'|ForEach-Object {'            '+$_})-join "`n")}
 $script:source=$script:source.TrimEnd()+"`n"+(($bar -split '\r?\n'|ForEach-Object {$rootIndent+$_})-join "`n")+"`n"
 if($cfg.Screen -eq 'Screen1'){
  Layout-Property 'lblSelectionLoadStatus' 'Y' '=ddTeam.Y+ddTeam.Height+12'
  $script:source+=@'
      - lblFooterButtonMetrics:
          Control: Label@2.5.1
          Properties:
            Text: =""
            Visible: =false
            X: =40
            Y: =16
            Width: =12
            Height: =40
'@+"`n"
 }
 if($cfg.Screen -eq 'scrHours'){Layout-Property 'lblWeekLoadStatus' 'Y' '=ddHoursWeek.Y+ddHoursWeek.Height+8'}
 if($cfg.Screen -eq 'scrWeeklyHours'){
  Layout-Property 'lblddReportStartYear' 'Y' '=Max(ddReportProject.Y+ddReportProject.Height,ddReportContractor.Y+ddReportContractor.Height)+12'
  Layout-Property 'lblReportNameHeader' 'Y' '=lblReportStatus.Y+lblReportStatus.Height+12'
 }
 [IO.File]::WriteAllText($path,$script:source,(New-Object Text.UTF8Encoding($false)))
}
