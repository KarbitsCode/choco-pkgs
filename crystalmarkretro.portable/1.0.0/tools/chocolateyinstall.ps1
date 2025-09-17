$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

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
}

Get-ChocolateyUnzip @packageArgs

Get-ChildItem "$toolsDir\*.zip" -Recurse:$false | ForEach-Object {
  Remove-Item $_ -ErrorAction SilentlyContinue
  if (Test-Path $_) {
    Write-Debug "Failed to delete: $($_.FullName)"
    Set-Content "$($_.FullName).ignore" -Value '' -Force
  }
}

# For executable shim
$osArch = (Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty OSArchitecture)
if ($osArch -eq "ARM 64-bit") {
  $exePath = "$($fileName)A64.exe"
} elseif ($osArch -eq "64-bit") {
  $exePath = "$($fileName)64.exe"
} else {
  $exePath = "$($fileName)32.exe"
}

Install-BinFile -Name $fileName -Path (Join-Path -Path $toolsDir -ChildPath $exePath)

# Prevent unnecessary recursive shims
Get-ChildItem -Path "$toolsDir\Resource" -Recurse -Filter *.exe | ForEach-Object {
  $ignoreFile = "$($_.FullName).ignore"
  if (-not (Test-Path $ignoreFile)) {
    New-Item -Path $ignoreFile -ItemType File -Force | ForEach-Object {
      Write-Debug "Adding ignore file: $($_.FullName)"
    }
  }
}
