﻿$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    unzipLocation  = $toolsDir
    url            = 'https://www.tc4shell.com/binary/Phar7z.zip'
    url64bit       = 'https://www.tc4shell.com/binary/Phar7z.zip'
    checksum       = '37A030732314C44CADBB15E9205C01F40FC15BE575CC5975619F8A7374C2B70B'
    checksumType   = 'sha256'
    checksum64     = '37A030732314C44CADBB15E9205C01F40FC15BE575CC5975619F8A7374C2B70B'
    checksumType64 = 'sha256'
}

$filename = if ((Get-OSArchitectureWidth 64) -and $env:chocolateyForceX86 -ne $true) {
                Write-Host "Using 64 bit version..."
                Split-Path $packageArgs["url64bit"] -Leaf
            } else {
                Write-Host "Using 32 bit version..."
                Split-Path $packageArgs["url"] -Leaf
            }

$packageArgs["fileFullPath"] = "$(Join-Path $toolsDir $filename)"

$archiveLocation = Get-ChocolateyWebFile @packageArgs
$extractLocation = "$(Join-Path (Split-Path -parent $archiveLocation) "Formats")"

$spliter = "path to executable:"
$7zLocation = "$(Split-Path -parent ((7z --shimgen-noop | Select-String $spliter) -split $spliter | ForEach-Object Trim)[1])"
$installLocation = "$(Join-Path $7zLocation "Formats")"

Write-Host "Installing plugin..."

New-Item -ItemType directory -Path $installLocation -Force | Out-Null
Get-ChocolateyUnzip -FileFullPath $archiveLocation -Destination $extractLocation | Out-Null
if ((Get-OSArchitectureWidth 64) -and $env:chocolateyForceX86 -ne $true) {
    $extractLocationArch = Join-Path $extractLocation '*.64.dll'
} else {
    $extractLocationArch = Join-Path $extractLocation '*.32.dll'
}

Get-ChildItem -Recurse $extractLocationArch -Name -File | ConvertTo-Json | Out-File $toolsDir\installed.json
Copy-Item "$($extractLocationArch)" "$($installLocation)" -Recurse -Force

Get-ChildItem "$toolsDir\*.zip" -Recurse:$false | ForEach-Object {
  Remove-Item $_ -ErrorAction SilentlyContinue
  if (Test-Path $_) {
    Write-Debug "Failed to delete: $($_.FullName)"
    Set-Content "$($_.FullName).ignore" -Value '' -Force
  }
}

Write-Host "Install completed." -ForegroundColor Green
