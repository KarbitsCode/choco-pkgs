$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# $name: CrystalMark Retro (Install) -> CrystalMark Retro
$name = $($env:ChocolateyPackageTitle -replace '\s*\(.*?\)', '')
# $fileName: CrystalMark Retro -> CrystalMarkRetro
$fileName = $($name -replace '\s+', '')
$version = '2.0.6'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  softwareName  = "$name*"
  zipFileName   = "${env:ChocolateyPackageName}Install.zip"
  name          = $fileName
}

Uninstall-ChocolateyZipPackage @packageArgs
Uninstall-BinFile @packageArgs
