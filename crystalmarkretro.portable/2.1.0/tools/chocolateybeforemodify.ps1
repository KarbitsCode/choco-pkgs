$ErrorActionPreference = 'Stop'

# Kill the app process before upgrade/uninstall
Get-Process -Name 'CrystalMarkRetro*' -ErrorAction SilentlyContinue | ForEach-Object {
  try {
    Write-Host "Try to stop running processes..."
    Stop-Process -Id $_.Id -Force -ErrorAction Stop
    Write-Host "Stopped process $($_.ProcessName).exe (PID: $($_.Id))"
  } catch {
    Write-Warning "Failed to stop ${name}: $_"
  }
}
