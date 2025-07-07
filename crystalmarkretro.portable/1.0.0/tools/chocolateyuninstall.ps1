$ErrorActionPreference = 'Stop'

# $name: CrystalMark Retro (Install) -> CrystalMark Retro
$name = $env:ChocolateyPackageTitle -replace '\s*\(.*?\)', '' 
$shortName = $($name -replace '\s+', '')

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  softwareName  = "$name*"
  zipFileName   = "${env:ChocolateyPackageName}Install.zip"
  name          = $shortName
}

Uninstall-ChocolateyZipPackage @packageArgs
Uninstall-BinFile @packageArgs
