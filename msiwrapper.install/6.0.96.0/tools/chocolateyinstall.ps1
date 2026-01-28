$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  destination   = $toolsDir
  fileType      = 'MSI'
  url           = 'https://www.exemsi.com/downloads/msi_wrapper/MSI_Wrapper_6_0_96_0.msi'
  softwareName  = 'MSI Wrapper*'
  checksum      = '81585A79B32DA0DCD4C4EF57505D246FEC3C2BBC7FDBC14534E1810476998E61'
  checksumType  = 'sha256'
  silentArgs    = "/qb! /norestart /l*v `"$($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`""
  validExitCodes= @(0, 3010, 1641, 1603)
}

Install-ChocolateyPackage @packageArgs
