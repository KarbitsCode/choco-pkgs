$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# $name: CrystalMark 3D25 (Portable) -> CrystalMark 3D25
$name = $($env:ChocolateyPackageTitle -replace '\s*\(.*?\)', '')
# $fileName: CrystalMark 3D25 -> CrystalMark3D25
$fileName = $($name -replace '\s+', '')
$version = '1.0.0'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  softwareName  = "$name*"
  zipFileName   = "${env:ChocolateyPackageName}Install.zip"
  name          = $fileName
}

Uninstall-ChocolateyZipPackage @packageArgs
Uninstall-BinFile @packageArgs
