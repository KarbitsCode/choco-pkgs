$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# $name: CrystalMark Retro (Install) -> CrystalMark Retro
$name = $($env:ChocolateyPackageTitle -replace '\s*\(.*?\)', '')
# $fileName: CrystalMark Retro -> CrystalMarkRetro
$fileName = $($name -replace '\s+', '')
$version = '1.0.0'
$fileLocation = Join-Path $toolsDir "$($fileName)$($version -replace '\.', '_').zip"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  file          = $fileLocation
  softwareName  = "$name*"
  checksum      = '53E626D3AA88FAE753256ED49C76366B5D607F7F722D0C0EDC9A94CA72E05FC8'
  checksumType  = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs
Get-ChildItem $toolsDir\*.zip -Recurse:$false | ForEach-Object { Remove-Item $_ -ea 0; if (Test-Path $_) { Set-Content "$_.ignore" } }

# For shim executable
$osArch = (Get-WmiObject Win32_OperatingSystem | Select OSArchitecture).OSArchitecture
if ($osArch -eq "ARM 64-bit") {
  $exePath = "$($fileName)A64.exe"
} elseif ($osArch -eq "64-bit") {
  $exePath = "$($fileName)64.exe"
} else {
  $exePath = "$($fileName)32.exe"
}

Install-BinFile -Name $fileName -Path (Join-Path -Path $toolsDir -ChildPath $exePath)
