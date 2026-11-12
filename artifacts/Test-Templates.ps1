# Test-Templates.ps1 - checks templates/ (DECISIONS.md H25): header snippet, weekreport shell, sample body.
# Merges like the flow (BODY token once, then every HEADER token) and optionally renders a PDF with Edge headless.
# Usage: .\Test-Templates.ps1 [-OutDir <folder>] [-RenderPdf]
param([string]$OutDir, [switch]$RenderPdf)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tpl = Join-Path $root 'templates'
$fails = New-Object System.Collections.Generic.List[string]
function Check([bool]$ok, [string]$msg) { if ($ok) { Write-Host "PASS  $msg" } else { Write-Host "FAIL  $msg"; $fails.Add($msg) } }
function Count([string]$text, [string]$pat) { ([regex]::Matches($text, $pat)).Count }
$utf8 = New-Object System.Text.UTF8Encoding $false
function ReadText([string]$p) { [System.IO.File]::ReadAllText($p, $utf8) }

$hPath = Join-Path $tpl 'header.html'; $wPath = Join-Path $tpl 'weekreport.html'; $sPath = Join-Path $tpl 'sample-body.html'
foreach ($p in $hPath, $wPath, $sPath) { Check (Test-Path $p) "exists: $(Split-Path $p -Leaf)" }
if ($fails.Count) { exit 1 }
$h = ReadText $hPath; $w = ReadText $wPath; $s = ReadText $sPath

# No BOM in templates (the flow concatenates them; a BOM in the middle would show as a character)
foreach ($p in $hPath, $wPath, $sPath) { $b = [System.IO.File]::ReadAllBytes($p); Check (-not ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)) "no BOM: $(Split-Path $p -Leaf)" }

# Tokens
Check ((Count $w '\{\{BODY\}\}') -eq 1) 'weekreport.html: BODY token exactly once'
Check ((Count $w '\{\{HEADER\}\}') -eq 0) 'weekreport.html: no HEADER token'
Check ((Count $h '\{\{') -eq 0) 'header.html: no tokens'
$pages = Count $s '<section class="page"'
Check ($pages -eq 2) 'sample-body.html: 2 pages'
Check ((Count $s '<section class="page"[^>]*>\s*(<style>[^<]*</style>\s*)?\{\{HEADER\}\}') -eq $pages) 'sample-body.html: every page starts with HEADER token'
Check ((Count $s '\{\{HEADER\}\}') -eq $pages) 'sample-body.html: HEADER token once per page'
Check ((Count $s '\{\{BODY\}\}') -eq 0) 'sample-body.html: no BODY token'
Check ((Count $w '(?s)<body>\s*\{\{BODY\}\}\s*</body>') -eq 1) 'weekreport.html: BODY token is the whole body'

# Snippets: no document skeleton
foreach ($pair in @(@('header.html', $h), @('sample-body.html', $s))) {
  Check ((Count $pair[1] '(?i)<!DOCTYPE|<html|<head|<body|</body|</html') -eq 0) "$($pair[0]): snippet only (no html/head/body)"
}
# Shell
Check ($w -match '^<!DOCTYPE html>') 'weekreport.html: doctype'
Check ($w -match '<meta charset="utf-8">') 'weekreport.html: utf-8'
Check ($w -match '@page\s*\{\s*size:\s*A4 landscape;') 'weekreport.html: A4 landscape'
Check ($w -match '\.page\s*\{[^}]*page-break-after:\s*always') 'weekreport.html: page-break-after on .page'
Check ($w -match '\.page:last-child\s*\{[^}]*page-break-after:\s*auto') 'weekreport.html: no empty last page'
foreach ($rule in @(
  @('thead th', 'background-color: #0303B8; color: #FFFFFF'),
  @('tr.alt td', 'background-color: #F0F0F0'),
  @('tr.subtotal td', 'background-color: #D5EDFF'),
  @('tr.total td', 'background-color: #000F41; color: #FFFFFF; font-weight: bold'),
  @('thead th.we', 'background-color: #F0F0F0'),
  @('table.report td.we', 'background-color: #F0F0F0'),
  @('h1.doc-title', 'position: absolute; top: 0; right: 12px;'),
  @('table.report', 'border-collapse: collapse; table-layout: fixed; width: 100%;'))) {
  Check ($w -match ([regex]::Escape($rule[0]) + '\s*\{[^}]*' + [regex]::Escape($rule[1]))) "weekreport.html: $($rule[0]) = $($rule[1])"
}
Check ($w -match 'table\.report th, table\.report td \{[^}]*border-bottom: 1px solid #DCDCDC') 'weekreport.html: row lines #DCDCDC'
Check ($w -match 'table\.report \.num \{ text-align: right; \}') 'weekreport.html: numbers right-aligned'
Check ($w -notmatch 'border-left') 'weekreport.html: no vertical line before Total (Eddy 12-11 item 9)'
Check ($w -match 'h1\.doc-title \{[^}]*height: 40px; line-height: 40px;[^}]*color: #FFFFFF') 'weekreport.html: title white in 40 px bar'
Check ($w -match '@bottom-left \{ font-family: Arial' -and $w -match '@bottom-right \{ font-family: Arial') 'weekreport.html: page footer margin boxes (Arial)'
Check ($w -notmatch '(?s)@bottom-(left|right) \{[^}]*content:') 'weekreport.html: no footer text in template (comes from app)'

# Fonts: Arial only (E5)
foreach ($pair in @(@('header.html', $h), @('weekreport.html', $w))) {
  $fams = [regex]::Matches($pair[1], 'font-family:\s*([^;"]+)') | ForEach-Object { $_.Groups[1].Value.Trim() }
  Check (@($fams).Count -ge 1 -and -not (@($fams) | Where-Object { $_ -ne 'Arial, Helvetica, sans-serif' })) "$($pair[0]): font-family Arial only"
}
Check ((Count ($h + $w + $s) '(?i)Inter|Segoe|Open Sans|Montserrat|GEA Sans') -eq 0) 'no other font names'

# Colours: GEA palette only
$palette = '#0303B8', '#000F41', '#FFFFFF', '#000000', '#F0F0F0', '#DCDCDC', '#D5EDFF', '#E6E6E6'
$h2 = [regex]::Replace($h, 'base64,[A-Za-z0-9+/=]+', 'base64,')
$cols = [regex]::Matches($h2 + $w + $s, '#[0-9A-Fa-f]{6}\b') | ForEach-Object { $_.Value.ToUpper() } | Sort-Object -Unique
$bad = @($cols | Where-Object { $palette -notcontains $_ })
Check ($bad.Count -eq 0) "colours in GEA palette ($($cols -join ' '))$(if ($bad.Count) { ' bad: ' + ($bad -join ' ') })"

# Logo: official file unchanged, white logo on Vibrant Blue, not stretched
$m = [regex]::Matches($h, 'src="data:image/svg\+xml;base64,([A-Za-z0-9+/=]+)"')
Check ($m.Count -eq 1) 'header.html: one base64 logo'
if ($m.Count -eq 1) {
  $bytes = [Convert]::FromBase64String($m[0].Groups[1].Value)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $hash = -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('X2') })
  Check ($hash -eq '5D460376D030AF075E004E50191C8BE0C8DB05C5E0A9E593F53612DA52606087') 'header.html: logo = official Assets/GEA_logo_white.svg (SHA-256)'
}
Check ($h -match 'background-color:#0303B8' -and $h -match 'bgcolor="#0303B8"') 'header.html: white logo on #0303B8'
Check ($h -match 'height:40px;' -and $h -match 'height="24"' -and $h -notmatch '<img[^>]*width=' -and $h -match 'width:auto') 'header.html: logo height only (no stretch)'
Check ($h -match 'alt="GEA"') 'header.html: alt GEA'

# No external references (converter must not fetch anything)
Check ((Count ($h2 + $w + $s) '(?i)(src|href)\s*=\s*"(https?:|//)') -eq 0) 'no external src/href'
Check ((Count ($w + $s) '(?i)<script|<link|@import') -eq 0) 'no script, link or @import'

# Synthetic data only (AGENTS: no personal data): names in sample start with Test/TEST
$names = [regex]::Matches($s, '<tr(?: class="alt")?><td>([^<]+)</td>') | ForEach-Object { $_.Groups[1].Value }
Check (@($names).Count -ge 1 -and -not (@($names) | Where-Object { $_ -notmatch '^Test ' })) "sample-body.html: synthetic worker names ($(@($names).Count))"
Check ((Count $s '(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}|\+31|\b06[- ]?\d{8}\b') -eq 0) 'sample-body.html: no e-mail or phone'

# Sample contract per page: named page + footer rule, title, info block, unit header, weekend cells
$secs = [regex]::Matches($s, '(?s)<section class="page" lang="([a-z]+)" style="page: wr-\1">\s*<style>@page wr-\1 \{ @bottom-left \{ content: "[^"]+"; \} @bottom-right \{ content: "[^"]+" counter\(page\) "[^"]+" counter\(pages\); \} \}</style>\s*\{\{HEADER\}\}\s*<h1 class="doc-title">[^<]+</h1>(.*?)</section>')
Check ($secs.Count -eq $pages) "sample-body.html: every page = named page + footer rule + HEADER + doc-title ($($secs.Count))"
foreach ($sec in $secs) {
  $body = $sec.Groups[2].Value; $lg = $sec.Groups[1].Value
  $meta = [regex]::Matches($body, '<tr><th>([^<]+)</th><td>') | ForEach-Object { $_.Groups[1].Value }
  Check (@($meta).Count -eq 5) "sample-body.html [$lg]: info block 5 rows (project name, number, reference, contractor, week)"
  Check ($body -match '<th class="num total-col">[^<]+\([^)]+\)</th>') "sample-body.html [$lg]: Total header with unit"
  $bad = 0; foreach ($r in [regex]::Matches($body, '(?s)<tr[^>]*>(.*?)</tr>')) { $v = $r.Groups[1].Value; if ($v -match 'colspan="10"' -or $v -match '^<th>[^<]*</th><td>') { continue }; if ((Count $v 'class="num we"') -ne 2) { $bad++ } }
  Check ($bad -eq 0) "sample-body.html [$lg]: Sat/Sun cells class we in every table row"
}

# Tag balance (void elements and comments ignored)
function TagBalance([string]$text) {
  $void = 'meta', 'img', 'col', 'br', 'hr', 'link', 'input'
  $t = [regex]::Replace($text, '(?s)<!--.*?-->', '')
  $t = [regex]::Replace($t, '(?is)<style>.*?</style>', '<style></style>')
  $stack = New-Object System.Collections.Generic.Stack[string]
  foreach ($x in [regex]::Matches($t, '<(/?)([A-Za-z][A-Za-z0-9]*)[^>]*?(/?)>')) {
    $name = $x.Groups[2].Value.ToLower()
    if ($void -contains $name -or $x.Groups[3].Value -eq '/') { continue }
    if ($x.Groups[1].Value -eq '') { $stack.Push($name) }
    else {
      if ($stack.Count -eq 0) { return "unexpected </$name>" }
      $top = $stack.Pop(); if ($top -ne $name) { return "expected </$top>, found </$name>" }
    }
  }
  if ($stack.Count) { return "unclosed <$($stack.Peek())>" }
  return ''
}
foreach ($pair in @(@('header.html', $h), @('weekreport.html', $w), @('sample-body.html', $s))) {
  $r = TagBalance $pair[1]; Check ($r -eq '') "$($pair[0]): tags balanced$(if ($r) { ' - ' + $r })"
}
# Column count per row = 10 (colgroup)
foreach ($row in [regex]::Matches($s, '(?s)<tr[^>]*>(.*?)</tr>')) {
  $cells = 0
  foreach ($c in [regex]::Matches($row.Groups[1].Value, '<t[dh]( colspan="(\d+)")?')) { $cells += $(if ($c.Groups[2].Success) { [int]$c.Groups[2].Value } else { 1 }) }
  if ($row.Groups[1].Value -match '^<th>[^<]*</th><td>[^<]*</td>$') { continue }
  if ($cells -ne 10) { Check $false "sample-body.html: row with $cells cells: $($row.Value.Substring(0,[Math]::Min(60,$row.Value.Length)))" }
}

# Merge like the flow
$merged = $w.Replace('{{BODY}}', $s).Replace('{{HEADER}}', $h)
Check ((Count $merged '\{\{') -eq 0) 'merged: no tokens left'
$r = TagBalance $merged; Check ($r -eq '') "merged: tags balanced$(if ($r) { ' - ' + $r })"
Check ((Count $merged '<table class="gea-header"') -eq $pages) 'merged: header on every page'

if ($OutDir) {
  New-Item -ItemType Directory -Force $OutDir | Out-Null
  $mPath = Join-Path $OutDir 'weekreport-merged.html'
  [System.IO.File]::WriteAllText($mPath, $merged, $utf8)
  Write-Host "merged: $mPath"
  if ($RenderPdf) {
    $edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $edge) { Check $false 'Edge not found for -RenderPdf' }
    else {
      $pdf = Join-Path $OutDir 'weekreport-merged.pdf'
      if (Test-Path $pdf) { Remove-Item $pdf -Confirm:$false }
      $uri = ([System.Uri](Resolve-Path $mPath).Path).AbsoluteUri
      $prof = Join-Path $OutDir 'edge-profile'
      $pr = Start-Process -FilePath $edge -ArgumentList "--headless=new", "--disable-gpu", "--no-first-run", "--user-data-dir=`"$prof`"", "--no-pdf-header-footer", "--print-to-pdf=`"$pdf`"", $uri -PassThru -WindowStyle Hidden
      if (-not $pr.WaitForExit(60000)) { $pr.Kill(); Check $false 'Edge render timeout' }
      Check (Test-Path $pdf) "rendered PDF: $pdf"
      if (Test-Path $pdf) {
        $raw = [System.Text.Encoding]::GetEncoding(28591).GetString([System.IO.File]::ReadAllBytes($pdf))
        $n = ([regex]::Matches($raw, '/Type\s*/Page[^s]')).Count
        Check ($n -eq $pages) "rendered PDF: $n pages (expected $pages)"
      }
    }
  }
}

if ($fails.Count) { Write-Host "`nTest-Templates: $($fails.Count) FAIL"; exit 1 }
Write-Host "`nTest-Templates: all PASS"
