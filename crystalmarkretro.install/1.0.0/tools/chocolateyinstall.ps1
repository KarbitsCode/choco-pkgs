$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# $name: CrystalMark Retro (Install) -> CrystalMark Retro
$name = $env:ChocolateyPackageTitle -replace '\s*\(.*?\)', '' 
$version = $env:ChocolateyPackageVersion
$fileLocation = Join-Path $toolsDir "$($name -replace '\s+', '')$($version -replace '\.', '_').exe"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  fileType      = 'EXE'
  file          = $fileLocation
  softwareName  = "$name*"
  checksum      = '70C6EF3A62807F95BE5D5C614AFB25B2F4A0F483D7C26B9B8995FC0AB1CCC410'
  checksumType  = 'sha256'
  silentArgs    = '/SILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
  validExitCodes= @(0)
}

Install-ChocolateyPackage @packageArgs
Get-ChildItem $toolsDir\*.exe -Recurse:$false | ForEach-Object { Remove-Item $_ -ea 0; if (Test-Path $_) { Set-Content "$_.ignore" } }
