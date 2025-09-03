function Download-Installer {
    param (
        [string]$PackageDir
    )

    $verificationFile = Join-Path $PackageDir "tools\VERIFICATION.txt"
    if (-not (Test-Path $verificationFile)) {
        Write-Host "No VERIFICATION.txt found in $PackageDir, skipping download." -ForegroundColor Yellow
        return
    }

    $content = Get-Content $verificationFile

    $url = ($content | Select-String -Pattern '^  URL: <(.*)>$').Matches.Groups[1].Value

    if (-not $url) {
        Write-Warning "No URL found in VERIFICATION.txt at $PackageDir"
        return
    }

    $checksumType = ($content | Select-String -Pattern '^  checksum_type: (.*)$').Matches.Groups[1].Value
    $expectedChecksum = ($content | Select-String -Pattern '^  file_checksum: (.*)$').Matches.Groups[1].Value

    $toolsDir = Join-Path $PackageDir "tools"
    if (-not (Test-Path $toolsDir)) {
        New-Item -ItemType Directory -Path $toolsDir | Out-Null
    }
    $outFile = Join-Path $toolsDir ([System.IO.Path]::GetFileName($url))

    Write-Host "Downloading $url to $outFile..."
    curl.exe -L $url -o $outFile

    if ($checksumType -and $expectedChecksum) {
        Write-Host "Verifying $outFile..."
        $actualChecksum = (Get-FileHash -Path $outFile -Algorithm $checksumType).Hash.ToUpper()

        Write-Host "Expected checksum: $expectedChecksum"
        Write-Host "Actual checksum:   $actualChecksum"

        if ($actualChecksum -ne $expectedChecksum.ToUpper()) {
            throw "Checksum verification failed for $outFile"
        } else {
            Write-Host "Checksum verification passed for $outFile" -ForegroundColor Green
        }
    } else {
        Write-Host "No checksum info found, download only." -ForegroundColor Yellow
    }
}

$pkgFolder = "."
Remove-Item *.nupkg
Get-ChildItem -Path "." -Recurse | Where-Object { $_.Extension -in ".zip", ".exe" } | Remove-Item

Get-ChildItem -Path $pkgFolder -Recurse -Filter *.nuspec | ForEach-Object {
	$dir = $_.DirectoryName
	$file = $_.FullName

	cnc $dir
	Download-Installer $dir
	choco pack $file
}

# =================================================================================================

Write-Host "Getting list of packages before install test..." -ForegroundColor Blue
$installedBefore = choco list --limit-output | ForEach-Object { ($_ -split '\|')[0] }

Get-ChildItem -Path $pkgFolder -Filter *.nupkg | ForEach-Object {
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName)
    
    # Getting the pkgName and pkgVersion directly from the filename
    if ($filename -match '^(?<id>.+)\.(?<version>\d+\.\d+\.\d+(-[A-Za-z0-9]+)?)$') {
        $pkgName = $matches['id']
        $pkgVersion = $matches['version']
    }
    
    # Skipping .install package since it probably already installed by its metapackage
    if ($pkgName -notlike "*.install") {
        Write-Host "Installing $pkgName version $pkgVersion..." -ForegroundColor Blue
        choco install $pkgName --version=$pkgVersion --source=$pkgFolder --yes --force
    }
}

Write-Host "Getting list of packages after install test..." -ForegroundColor Blue
$installedAfter = choco list --limit-output | ForEach-Object { ($_ -split '\|')[0] }
$newlyInstalled = $installedAfter | Where-Object { $_ -notin $installedBefore }

if ($newlyInstalled.Length -ne 0) {
    Write-Host "Uninstalling newly installed packages: $($newlyInstalled -join ', ')" -ForegroundColor Yellow
    choco uninstall @newlyInstalled -yes
} else {
    Write-Host "There is no change in list of packages, it's possible if all the previous package installs failed." -ForegroundColor Yellow
}

Get-ChildItem -Path "." -Recurse | Where-Object { $_.Extension -in ".zip", ".exe" } | Remove-Item
Remove-Item *.nupkg
