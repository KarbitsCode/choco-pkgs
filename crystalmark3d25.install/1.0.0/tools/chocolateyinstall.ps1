$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# $name: CrystalMark 3D25 (Install) -> CrystalMark 3D25
$name = $($env:ChocolateyPackageTitle -replace '\s*\(.*?\)', '')
# $fileName: CrystalMark 3D25 -> CrystalMark3D25
$fileName = $($name -replace '\s+', '')
$version = '1.0.0'
$fileLocation = Join-Path $toolsDir "$($fileName)_$($version -replace '\.', '_').exe"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  fileType      = 'EXE'
  file          = $fileLocation
  softwareName  = "$name*"
  silentArgs    = '/SILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
  validExitCodes= @(0)
}

Install-ChocolateyInstallPackage @packageArgs

Get-ChildItem "$toolsDir\*.exe" -Recurse:$false | ForEach-Object {
  Remove-Item $_ -ErrorAction SilentlyContinue
  if (Test-Path $_) {
    Write-Debug "Failed to delete: $($_.FullName)"
    Set-Content "$($_.FullName).ignore" -Value '' -Force
  }
}
