$ErrorActionPreference='Stop'
$installer=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Optimize-Loading.ps1'))
Invoke-Expression ($installer.Substring(0,$installer.IndexOf("Read-Screen 'Screen1'")).Replace('$PSScriptRoot',("'"+$PSScriptRoot+"'")))
Read-Screen 'scrWeeklyHours'
$fx=$controls['btnLoadReport']['Properties']['OnSelect']
$start=$fx.IndexOf('ForAll(colReportAssignments As member,')
$end=$fx.IndexOf('If(IsEmpty(colReportLoadErrors),',$start)
if($start -lt 0 -or $end -lt 0){throw 'History block not found'}
$old=$fx.Substring($start,$end-$start)
# Reuse the existing date/ISO/historical-employer projection without changing its semantics.
$projectionStart=$old.IndexOf('If(CountIf(batch,IsBlank(WorkDay)')
$projectionEnd=$old.IndexOf('))),Collect(colReportLoadErrors') # not used: balanced extraction instead
function Expression-End([string]$text,[int]$offset) {
 $depth=0; $quoted=$false
 for($i=$offset;$i -lt $text.Length;$i++) {
  if($text[$i] -eq '"'){$quoted=!$quoted}
  if(!$quoted){if($text[$i] -eq '('){$depth++};if($text[$i] -eq ')'){$depth--;if($depth -eq 0){return $i+1}}}
 }
 throw 'Unbalanced expression'
}
$projection=$old.Substring($projectionStart,(Expression-End $old $projectionStart)-$projectionStart)
$fallback=$old.TrimEnd()
# Remove closure for the enclosing If(IsEmpty(errors),...) outside the ForAll expression.
$forAllEnd=Expression-End $old 0
$fallback=$old.Substring(0,$forAllEnd)
# Existing full per-year scan is retained only for assignments whose initial batch reaches the row limit.
$fallbackBody=$fallback.Substring($fallback.IndexOf('IfError('))
$fallbackBody=$fallbackBody.Substring(0,(Expression-End $fallbackBody 0))
$new=@"
ForAll(colReportAssignments As member,
 IfError(
  With({batch:ForAll(ShowColumns(Filter(Hours,Assignment.Id=member.ID),ID,'Work Date',Employer,Hours) As entry,
   {HourID:entry.ID,WorkDay:entry.'Work Date',ContractorID:entry.Employer.Id,ContractorName:entry.Employer.Value,HourValue:entry.Hours})},
   If(CountRows(batch)<500,
    $projection,
    $fallbackBody
   )
  ),Collect(colReportLoadErrors,{Message:FirstError.Message});false
 )
)
  );
  
"@
$fx=$fx.Substring(0,$start)+$new+$fx.Substring($end)
Replace-Property 'btnLoadReport' 'OnSelect' $fx
Write-Screen
