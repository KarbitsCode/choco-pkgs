$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  destination   = $toolsDir
  fileType      = 'MSI'
  url           = 'https://www.exemsi.com/downloads/msi_wrapper/MSI_Wrapper_5_1_87_0.msi'
  softwareName  = 'MSI Wrapper*'
  checksum      = 'DDE452CD1FF6A42D4A9AD3CFB93ED3DCB14355A0F106415D1D54BBDF09C508E8'
  checksumType  = 'sha256'
  silentArgs    = "/qb! /norestart /l*v `"$($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`""
  validExitCodes= @(0, 3010, 1641, 1603)
}

Install-ChocolateyPackage @packageArgs
