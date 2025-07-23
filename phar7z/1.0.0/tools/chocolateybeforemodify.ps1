$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

$installed = Get-Content -Path $toolsDir\installed.json -Raw | ConvertFrom-Json

$spliter = "path to executable:"
$7zLocation = "$(Split-Path -parent ((7z --shimgen-noop | Select-String $spliter) -split $spliter | ForEach-Object Trim)[1])"
$installLocation = "$(Join-Path $7zLocation "Formats")"

Write-Host "Removing plugin..."
ForEach ($file in $installed) {
  Remove-Item "$(Join-Path $installLocation $file)" -Force
}
Write-Host "Remove completed." -ForegroundColor Green
