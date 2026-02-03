$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  destination   = $toolsDir
  fileType      = 'MSI'
  url           = 'https://www.exemsi.com/downloads/msi_wrapper/MSI_Wrapper_8_0_20_0.msi'
  softwareName  = 'MSI Wrapper*'
  checksum      = '2890025271C8C70C4F18BA7734A81ADEF1A612EF50C32AC6773942A4A9F0F1A0'
  checksumType  = 'sha256'
  silentArgs    = "/qb! /norestart /l*v `"$($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`""
  validExitCodes= @(0, 3010, 1641, 1603)
}

Install-ChocolateyPackage @packageArgs
