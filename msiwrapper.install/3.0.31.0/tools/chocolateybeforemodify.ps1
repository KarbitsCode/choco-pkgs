$ErrorActionPreference = 'Stop'

# Kill the app process before upgrade/uninstall
@("MsiWrapperBatch", "MsiWrapper", "MsiSql") | ForEach-Object {
  $name = $_
  try {
    Get-Process -Name $name -ErrorAction Stop | ForEach-Object {
      try {
        Write-Host "Try to stop running processes..."
        Stop-Process -Id $_.Id -Force -ErrorAction Stop
        Write-Host "Stopped process $($_.ProcessName).exe (PID: $($_.Id))"
      } catch {
        Write-Warning "Failed to stop ${name}: $_"
      }
    }
  } catch {
    Write-Debug "Did not find ${name}.exe process"
  }
}
