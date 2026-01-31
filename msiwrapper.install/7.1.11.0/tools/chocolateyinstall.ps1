$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  destination   = $toolsDir
  fileType      = 'MSI'
  url           = 'https://www.exemsi.com/downloads/msi_wrapper/MSI_Wrapper_7_1_11_0.msi'
  softwareName  = 'MSI Wrapper*'
  checksum      = '9039D950976D67904C20B146165BFE359C3D68CCDDB1504A857E6AAD6A5A5FC5'
  checksumType  = 'sha256'
  silentArgs    = "/qb! /norestart /l*v `"$($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`""
  validExitCodes= @(0, 3010, 1641, 1603)
}

Install-ChocolateyPackage @packageArgs
