$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot
$style=[ordered]@{
    Height='=40'; Font="=Font.'Segoe UI'"; Size='=14'; FontWeight='=FontWeight.Semibold'
    Align='=Align.Center'; VerticalAlign='=VerticalAlign.Middle'
    PaddingTop='=0'; PaddingBottom='=0'; PaddingLeft='=16'; PaddingRight='=16'
    RadiusTopLeft='=8'; RadiusTopRight='=8'; RadiusBottomLeft='=8'; RadiusBottomRight='=8'
}
$groups=@{
    'Screen1.pa.yaml'=@{
        btnGotoHours=@{Width='=160'}
        btnAddtoTeam=@{Width='=160';X='=btnGotoHours.X+btnGotoHours.Width+12';Y='=btnGotoHours.Y'}
        btnGotoHoursSummary=@{Width='=180';X='=btnAddtoTeam.X+btnAddtoTeam.Width+12';Y='=btnGotoHours.Y'}
    }
    'scrHours.pa.yaml'=@{ btnSaveWeek=@{} }
    'scrWeeklyHours.pa.yaml'=@{
        btnSummaryProjectTeam=@{Width='=160';X='=btnRefreshReport.X-Self.Width-12';Y='=btnRefreshReport.Y'}
        btnRefreshReport=@{Y='=32'}
    }
}
foreach($file in $groups.Keys) {
    $path=Join-Path $projectRoot ('Src/'+$file)
    $source=[IO.File]::ReadAllText($path)
    foreach($name in $groups[$file].Keys) {
        $head=[regex]::Match($source,'(?m)^( +)- '+[regex]::Escape($name)+':\r?$')
        if(!$head.Success) { throw "Knop ontbreekt: $name" }
        $indent=$head.Groups[1].Value
        $pattern='(?ms)^'+$indent+'- '+[regex]::Escape($name)+':.*?(?=^'+$indent+'- |\z)'
        $source=[regex]::Replace($source,$pattern,[Text.RegularExpressions.MatchEvaluator]{ param($match)
            $block=$match.Value
            $propertyIndent=$indent+'      '
            $values=[ordered]@{}
            foreach($key in $style.Keys) { $values[$key]=$style[$key] }
            foreach($key in $groups[$file][$name].Keys) { $values[$key]=$groups[$file][$name][$key] }
            foreach($key in $values.Keys) {
                $line=$propertyIndent+$key+': '+$values[$key]
                $propertyPattern='(?m)^'+$propertyIndent+[regex]::Escape($key)+':[^\r\n]*'
                if([regex]::IsMatch($block,$propertyPattern)) {
                    $block=[regex]::Replace($block,$propertyPattern,[Text.RegularExpressions.MatchEvaluator]{ param($m) $line })
                } else { $block=$block.TrimEnd()+"`n"+$line+"`n" }
            }
            return $block
        })
    }
    [IO.File]::WriteAllText($path,$source,(New-Object Text.UTF8Encoding($false)))
}
