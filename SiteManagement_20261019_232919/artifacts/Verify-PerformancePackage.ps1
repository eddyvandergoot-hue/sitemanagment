$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$buildDir=Join-Path $root (Get-Content (Join-Path $PSScriptRoot 'performance-builddir.txt') -Raw).Trim()
Add-Type -AssemblyName System.IO.Compression.FileSystem
$built=[IO.Compression.ZipFile]::OpenRead((Join-Path $buildDir 'SiteManagement_Performance_Test.msapp'))
$original=[IO.Compression.ZipFile]::OpenRead((Join-Path $root 'Site Managment_VS.msapr'))
function Read-Entry($zip,$name){
 $entry=$zip.GetEntry($name); if(!$entry){throw "Missing $name"}
 $reader=New-Object IO.StreamReader($entry.Open());try{return $reader.ReadToEnd()}finally{$reader.Dispose()}
}
try{
 foreach($entry in @('Properties.json','References\DataSources.json','References\Templates.json')){
  if((Read-Entry $built $entry) -cne (Read-Entry $original ('msapp\'+$entry))){throw "Metadata differs: $entry"}
  Write-Output "PASS original metadata $entry"
 }
 foreach($file in Get-ChildItem (Join-Path $root 'Src') -Filter '*.pa.yaml'){
  if((Read-Entry $built ('Src\'+$file.Name)) -cne [IO.File]::ReadAllText($file.FullName)){throw "Source differs $($file.Name)"}
  Write-Output "PASS exact packed source $($file.Name)"
 }
}finally{$built.Dispose();$original.Dispose()}
