$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# $name: CrystalMark Retro (Install) -> CrystalMark Retro
$name = $($env:ChocolateyPackageTitle -replace '\s*\(.*?\)', '')
# $fileName: CrystalMark Retro -> CrystalMarkRetro
$fileName = $($name -replace '\s+', '')
$version = '2.0.2'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  softwareName  = "$name*"
  fileType      = 'EXE'
  silentArgs    = '/SILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
  validExitCodes= @(0)
}

[array]$key = Get-UninstallRegistryKey -SoftwareName $packageArgs['softwareName']

if ($key.Count -eq 1) {
  $key | ForEach-Object {
    $packageArgs['file'] = "$($_.UninstallString)"

    if ($packageArgs['fileType'] -eq 'MSI') {
      $packageArgs['silentArgs'] = "$($_.PSChildName) $($packageArgs['silentArgs'])"
      $packageArgs['file'] = ''
    }

    Uninstall-ChocolateyPackage @packageArgs
  }
} elseif ($key.Count -eq 0) {
  Write-Warning "$packageName has already been uninstalled by other means."
} elseif ($key.Count -gt 1) {
  Write-Warning "$($key.Count) matches found!"
  Write-Warning "To prevent accidental data loss, no programs will be uninstalled."
  Write-Warning "Please alert package maintainer the following keys were matched:"
  $key | ForEach-Object {Write-Warning "- $($_.DisplayName)"}
}
