$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  destination   = $toolsDir
  fileType      = 'MSI'
  url           = 'https://www.exemsi.com/downloads/msi_wrapper/MSI_Wrapper_3_0_25_0.msi'
  softwareName  = 'MSI Wrapper*'
  checksum      = '6007ADECC1CFE957CC6A52ED7A84D6238E4C30E350B361A707AD4AD46A15FF82'
  checksumType  = 'sha256'
  silentArgs    = "/qb! /norestart /l*v `"$($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`""
  validExitCodes= @(0, 3010, 1641, 1603)
}

Install-ChocolateyPackage @packageArgs
