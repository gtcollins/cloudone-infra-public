# Lists every value you still need to customize for CloudOne.
# Exit code 1 while anything is left, 0 when you're done.
#
#   .\scripts\check-customization.ps1
#
# When you replace a value, also delete its "CHANGE ME" comment.

$root = Split-Path -Parent $PSScriptRoot
$pattern = 'CHANGE ME|REPLACE_WITH|^\s*\w+\s*=\s*"TODO"'

$matches = Get-ChildItem -Path $root -Recurse -File -Include *.tf, *.tfvars, *.hcl |
  Where-Object { $_.FullName -notmatch '[\\/]\.terraform(-envs)?[\\/]' -and $_.Name -ne '.terraform.lock.hcl' } |
  Select-String -Pattern $pattern |
  Where-Object { $_.Line -notmatch '^\s*#' }   # skip banners and explanations

if (-not $matches) {
  Write-Host "[OK] Nothing left to customize. Run 'terraform plan' in envs/dev next." -ForegroundColor Green
  exit 0
}

Write-Host "[STOP] $(@($matches).Count) line(s) still need your CloudOne values:" -ForegroundColor Red
Write-Host ""
foreach ($m in $matches) {
  $rel = $m.Path.Substring($root.Length + 1).Replace('\', '/')
  Write-Host ("  {0}:{1}  " -f $rel, $m.LineNumber) -ForegroundColor Yellow -NoNewline
  Write-Host $m.Line.Trim()
}
Write-Host ""
Write-Host "See CUSTOMIZE.md for what to put in each one."
exit 1
