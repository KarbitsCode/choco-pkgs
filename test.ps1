param (
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$folderArgs = ".",
	[switch]$PackageOnly,
	[switch]$NoScreenshots
)

function Write-Color {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory, Position=0, ValueFromPipeline)]
		[string] $Text,

		[System.ConsoleColor] $Foreground = "Gray",
		[System.ConsoleColor] $Background = "Black"
	)

	begin {
		$script:oldFg = [System.Console]::ForegroundColor
		$script:oldBg = [System.Console]::BackgroundColor
	}
	process {
		if ($Foreground) { [System.Console]::ForegroundColor = $Foreground }
		if ($Background) { [System.Console]::BackgroundColor = $Background }
		Write-Output $Text
	}
	end {
		[System.Console]::ForegroundColor = $script:oldFg
		[System.Console]::BackgroundColor = $script:oldBg
	}
}

$Script:ScreenshotJob = $null
$Script:ScreenshotFolder = ".\_ss\"

function Start-ScreenshotLoop {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[string]$Folder = ".\ss",
		[int]$Interval = 10
	)

	if ($Script:ScreenshotJob -and ($Script:ScreenshotJob.State -eq "Running")) {
		Write-Warning "Screenshot loop already running."
		return
	}

	if ($PSCmdlet.ShouldProcess("Screenshot loop", "Start")) {
		# Ensure folder exists
		New-Item -ItemType Directory -Force -Path $Folder | Out-Null

		$Script:ScreenshotJob = Start-Job -ScriptBlock {
			param(
				[string]$Folder,
				[int]$Interval
			)

			Add-Type -AssemblyName System.Windows.Forms
			Add-Type -AssemblyName System.Drawing
			Add-Type -TypeDefinition "public static class DPI { [System.Runtime.InteropServices.DllImport(""user32.dll"")] public static extern bool SetProcessDPIAware(); }"
			[DPI]::SetProcessDPIAware()

			# Screenshot in a loop
			while ($true) {
				$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
				$path = Join-Path $Folder "screenshot_$timestamp.png"

				$screen = [System.Windows.Forms.Screen]::PrimaryScreen
				$bounds = $screen.Bounds

				$bmp = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
				$gfx = [System.Drawing.Graphics]::FromImage($bmp)
				$gfx.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bmp.Size)
				$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
				$gfx.Dispose()
				$bmp.Dispose()

				Start-Sleep -Seconds $Interval
			}
		} -ArgumentList $Folder, $Interval

		Write-Verbose "Screenshot loop started."
	}
}

function Stop-ScreenshotLoop {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param()
	if (-not $Script:ScreenshotJob) {
		Write-Warning "No screenshot loop has been started."
		return
	}

	if ($Script:ScreenshotJob.State -eq "Running") {
		if ($PSCmdlet.ShouldProcess("Screenshot loop", "Stop")) {
			Stop-Job $Script:ScreenshotJob
			Remove-Job $Script:ScreenshotJob
			$Script:ScreenshotJob = $null
			Write-Verbose "Screenshot loop stopped."
		}
	} else {
		Write-Warning "Screenshot loop is not running."
	}
}

function Remove-TempFiles {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
	param ()

	process {
		$targets = @()
		$targets += Get-ChildItem -Path "." -Recurse | Where-Object { $_.Extension -in ".zip", ".exe", ".msi" }
		if (-not $PackageOnly) {
			$targets += Get-ChildItem -Path "." -Filter *.nupkg
		}
		if ($NoScreenshots) {
			$targets += Get-ChildItem -Path $Script:ScreenshotFolder -ErrorAction SilentlyContinue
			$targets += Get-Item -Path $Script:ScreenshotFolder -ErrorAction SilentlyContinue
		}

		foreach ($t in $targets) {
			if ($PSCmdlet.ShouldProcess($t.FullName, "Remove temp file")) {
				Remove-Item $t.FullName -Force -ErrorAction SilentlyContinue -Verbose
			}
		}
	}
}

function Get-RemoteChecksum {
	param(
		[string]$Url,
		[string]$Algorithm = 'sha256'
	)

	$fn = [System.IO.Path]::GetTempFileName()
	if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
		& curl.exe -L $Url -o $fn
	} else {
		Invoke-WebRequest $Url -OutFile $fn -UseBasicParsing
	}
	$res = Get-FileHash $fn -Algorithm $Algorithm | ForEach-Object Hash
	Remove-Item $fn -Force -ErrorAction Ignore
	return $res.ToLower()
}

function Get-Dependencies {
	param(
		[string[]]$PackageDir
	)

	$allDeps = @()

	# Process all nuspec files recursively
	foreach ($nuspecFile in Get-ChildItem -Path $PackageDir -Recurse -Filter *.nuspec) {
		try {
			[xml]$xml = Get-Content $nuspecFile.FullName -Raw

			# Get id and version from <dependency> nodes
			$xml.package.metadata.dependencies.dependency | ForEach-Object {
				if ($_.id) {
					$allDeps += [PSCustomObject]@{
						Id	  = $_.id
						Version = $_.version
					}
				}
			}
		} catch {
			Write-Warning "Failed to read $($nuspecFile.FullName)"
		}
	}

	return $allDeps | Sort-Object Id, Version -Unique
}

function Get-InstallerDisplayName {
	param (
		[string]$Url,
		[string]$OutputFile
	)

	if ($OutputFile) {
		return [System.IO.Path]::GetFileName($OutputFile)
	}

	return [System.IO.Path]::GetFileName($Url)
}

function Get-InstallerInfoFromVerification {
	param (
		[string]$PackageDir
	)

	$verificationFile = Get-ChildItem -Path $PackageDir -Recurse -Filter "VERIFICATION.txt" -File -ErrorAction SilentlyContinue |
		Where-Object { $_.Directory.Name -in @("tools","legal") } |
		Select-Object -First 1

	if (-not $verificationFile) {
		return $null
	}

	$content = Get-Content $verificationFile.FullName

	$url = ($content | Select-String '^  URL: <(.*)>$').Matches.Groups[1].Value
	if (-not $url) {
		return $null
	}

	$checksumType = ($content | Select-String '^  checksum_type: (.*)$').Matches.Groups[1].Value
	$checksum     = ($content | Select-String '^  file_checksum: (.*)$').Matches.Groups[1].Value

	$toolsDir = Join-Path $PackageDir "tools"
	$outFile  = Join-Path $toolsDir (Get-InstallerDisplayName($url))

	return @{
		Url          = $url
		Checksum     = $checksum
		ChecksumType = $checksumType
		OutputFile   = $outFile
		Source       = "VERIFICATION.txt"
	}
}

function Get-InstallerInfoFromPackageArgs {
	param (
		[string]$PackageDir
	)

	$installFile = Join-Path $PackageDir "tools\chocolateyInstall.ps1"
	if (-not (Test-Path $installFile)) {
		return @()
	}

	$script = Get-Content $installFile -Raw
	$match  = [regex]::Match($script, '\$packageArgs\s*=\s*@\{([^}]*)\}', 'Singleline')
	if (-not $match.Success) {
		return @()
	}

	$pkgArgs = @{}
	foreach ($line in ($match.Groups[1].Value -split "`r?`n")) {
		if ($line -match '^\s*([a-zA-Z0-9_]+)\s*=\s*(.+)$') {
			$pkgArgs[$matches[1]] = $matches[2].Trim("'`"")
		}
	}

	$results = @()

	if ($pkgArgs.url -and $pkgArgs.checksum -and $pkgArgs.checksumType) {
		$results += @{
			Url          = $pkgArgs.url
			Checksum     = $pkgArgs.checksum
			ChecksumType = $pkgArgs.checksumType
			Source       = "packageArgs:url"
		}
	}

	if ($pkgArgs.url64bit -and $pkgArgs.checksum64 -and $pkgArgs.checksumType64) {
		$results += @{
			Url          = $pkgArgs.url64bit
			Checksum     = $pkgArgs.checksum64
			ChecksumType = $pkgArgs.checksumType64
			Source       = "packageArgs:url64bit"
		}
	}

	return $results
}

function Test-InstallerChecksum {
	param (
		[string]$Url,
		[string]$Checksum,
		[string]$ChecksumType,
		[string]$OutputFile,
		[string]$Source
	)

	if (-not ($Url -and $Checksum -and $ChecksumType)) {
		Write-Warning "No checksum info available ($Source)"
		return $false
	}

	$name     = Get-InstallerDisplayName $Url $OutputFile
	Write-Color "Verifying $name ($Source)..." -Foreground Blue

	$expected = $Checksum.ToUpper()
	$actual = (Get-RemoteChecksum -Url $Url -Algorithm $ChecksumType).ToUpper()

	Write-Output "Expected checksum: $expected"
	Write-Output "Actual checksum:   $actual"

	if ($actual -eq $expected) {
		Write-Color "Checksum verification passed for $name" -Foreground Green
		return $true
	} else {
		Write-Warning "Checksum verification failed for $name"
		return $false
	}
}

function Get-InstallerFromWeb {
	param (
		[string]$Url,
		[string]$OutputFile
	)

	$dir = Split-Path $OutputFile
	if (-not (Test-Path $dir)) {
		New-Item -ItemType Directory -Path $dir | Out-Null
	}

	Write-Color "Downloading $Url to $OutputFile" -Foreground Blue
	curl.exe -L $Url -o $OutputFile
}

function Test-PackageChecksum {
	param (
		[string]$PackageDir
	)

	$info = Get-InstallerInfoFromVerification $PackageDir
	if (-not $info) {
		Write-Warning "No installer info found"
		return
	}

	Get-InstallerFromWeb -Url $info.Url -OutputFile $info.OutputFile

	Test-InstallerChecksum `
		-Url $info.Url `
		-Checksum $info.Checksum `
		-ChecksumType $info.ChecksumType `
		-OutputFile $info.OutputFile `
		-Source $info.Source
}


function Test-PackageChecksum2 {
	param (
		[string]$PackageDir
	)

	foreach ($info in Get-InstallerInfoFromPackageArgs $PackageDir) {
		Test-InstallerChecksum `
			-Url $info.Url `
			-Checksum $info.Checksum `
			-ChecksumType $info.ChecksumType `
			-Source $info.Source
	}
}

function Normalize-TrailingLines {
	param (
		[string]$Path
	)

	if (-not (Test-Path $Path)) {
		return
	}

	$text = Get-Content -Path $Path -Raw

	# Normalize CRLF / LF, trim excessive newlines
	$eol = if ($text -match "`r`n") { "`r`n" } else { "`n" }
	$text = $text -replace '(\r?\n)+$', ''
	$text += $eol

	[System.IO.File]::WriteAllText($Path, $text, [Text.Encoding]::UTF8)
}

function Set-InstallerInfoToVerification {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[string]$PackageDir,
		[hashtable]$InstallerInfo
	)

	$verificationFile = Get-ChildItem -Path $PackageDir -Recurse -Filter "VERIFICATION.txt" -File -ErrorAction SilentlyContinue |
		Where-Object { $_.Directory.Name -in @("tools","legal") } |
		Select-Object -First 1

	if (-not $verificationFile) {
		throw "VERIFICATION.txt not found"
	}

	$text = Get-Content $verificationFile.FullName -Raw

	if ($InstallerInfo.Url) {
		$text = [regex]::Replace(
			$text,
			'(?m)^(\s*URL:\s*<)[^>]+(>)',
			"  URL: <$($InstallerInfo.Url)>"
		)
	}

	if ($InstallerInfo.ChecksumType) {
		$text = [regex]::Replace(
			$text,
			'(?m)^([ \t]*checksum_type:[ \t]*)\S+',
			"`$1$($InstallerInfo.ChecksumType)"
		)
	}

	if ($InstallerInfo.Checksum) {
		$text = [regex]::Replace(
			$text,
			'(?m)^(\s*file_checksum:\s*)\S+',
			"  file_checksum: $($InstallerInfo.Checksum)"
		)
	}

	if ($PSCmdlet.ShouldProcess($verificationFile, "Write VERIFICATION.txt")) {
		Set-Content -Path $verificationFile.FullName -Value $text -Encoding UTF8
		Normalize-TrailingLines $verificationFile.FullName
		Write-Output "Updated VERIFICATION.txt (in-place)"
	}
}

function Set-InstallerInfoToPackageArgs {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[string]$PackageDir,
		[hashtable]$InstallerInfo
	)

	function Update-PackageArgsValue {
		param (
			[string]$ScriptText,
			[string]$Key,
			[string]$Value
		)

		if ($ScriptText -match "($Key\s*=\s*)['""]?[^`r`n]+") {
			return [regex]::Replace(
				$ScriptText,
				"($Key\s*=\s*)['""]?[^`r`n]+",
				"`$1'$Value'"
			)
		}

		return $ScriptText -replace '\$packageArgs\s*=\s*@\{',
			"`$packageArgs = @{`r`n    $Key = '$Value'"
	}

	$installFile = Join-Path $PackageDir "tools\chocolateyInstall.ps1"
	if (-not (Test-Path $installFile)) {
		throw "chocolateyInstall.ps1 not found"
	}

	$script = Get-Content $installFile -Raw

	switch ($InstallerInfo.Source) {
		'packageArgs:url' {
			$script = Update-PackageArgsValue -ScriptText $script -Key 'url'          -Value $InstallerInfo.Url
			$script = Update-PackageArgsValue -ScriptText $script -Key 'checksum'     -Value $InstallerInfo.Checksum
			$script = Update-PackageArgsValue -ScriptText $script -Key 'checksumType' -Value $InstallerInfo.ChecksumType
		}
		'packageArgs:url64bit' {
			$script = Update-PackageArgsValue -ScriptText $script -Key 'url64bit'       -Value $InstallerInfo.Url
			$script = Update-PackageArgsValue -ScriptText $script -Key 'checksum64'     -Value $InstallerInfo.Checksum
			$script = Update-PackageArgsValue -ScriptText $script -Key 'checksumType64' -Value $InstallerInfo.ChecksumType
		}
		default {
			throw "Unsupported source: $($InstallerInfo.Source)"
		}
	}

	if ($PSCmdlet.ShouldProcess($installFile, "Update $($InstallerInfo.Source) in chocolateyInstall.ps1")) {
		Set-Content -Path $installFile -Value $script -Encoding UTF8
		Normalize-TrailingLines $installFile
		Write-Output "Updated chocolateyInstall.ps1 ($($InstallerInfo.Source))"
	}
}

function Set-InstallerInfo {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[string]$PackageDir,
		[hashtable]$InstallerInfo
	)

	switch -Wildcard ($InstallerInfo.Source) {
		'VERIFICATION*' {
			Set-InstallerInfoToVerification `
				-PackageDir $PackageDir `
				-InstallerInfo $InstallerInfo `
				-WhatIf:$WhatIfPreference `
				-Confirm:$ConfirmPreference
		}
		'packageArgs*' {
			Set-InstallerInfoToPackageArgs `
				-PackageDir $PackageDir `
				-InstallerInfo $InstallerInfo `
				-WhatIf:$WhatIfPreference `
				-Confirm:$ConfirmPreference
		}
		default {
			throw "Unknown installer info source"
		}
	}
}

# =================================================================================================

function Test-Validation-Package {
	param (
		[string[]]$funcArgs
	)

	foreach ($pkgFolder in $funcArgs) {
		Get-ChildItem -Path $pkgFolder -Recurse -Filter *.nuspec | ForEach-Object {
			$dir = $_.DirectoryName
			$file = $_.FullName

			cnc $dir
			Test-PackageChecksum $dir
			Test-PackageChecksum2 $dir
			choco pack $file
		}
	}
}

function Test-Install-Package {
	param (
		[string[]]$funcArgs
	)

	if ($PackageOnly) {
		return
	}

	Start-ScreenshotLoop -Folder $Script:ScreenshotFolder -Verbose

	Write-Color "Getting list of packages before install test..." -Foreground Blue
	$installedBefore = choco list --limit-output | ForEach-Object { ($_ -split '\|')[0] }

	# Gather all nuspec dependency info
	$deps = Get-Dependencies $funcArgs
	$dirs = Get-ChildItem -Directory | Select-Object -ExpandProperty Name

	foreach ($dep in $deps) {
		$id = $dep.Id
		$ver = $dep.Version.Trim("[", "]")

		# Automatically handle package dependencies here
		Write-Color "Preparing dependency package: $($id) version $($ver)" -Foreground Blue
		if ($id -notin $dirs) {
			# Make sure to not install it twice
			if ($id -notin $installedBefore) {
				choco install $id --version $ver --yes --force
			}
		} else {
			# Make sure to not package it twice
			if (-not (Test-Path "$($id).$($ver).nupkg")) {
				Test-Validation-Package "$($id)\$($ver)"
			}
		}
	}

	Get-ChildItem -Path "." -Filter *.nupkg | ForEach-Object {
		$filename = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName)

		# Getting the pkgName and pkgVersion directly from the filename
		if ($filename -match '^(?<id>.+)\.(?<version>\d+\.\d+\.\d+(-[A-Za-z0-9]+)?)$') {
			$pkgName = $matches['id']
			$pkgVersion = $matches['version']
		}

		# Skipping .install package only if $funcArgs is in default value (".") or it is in dependency from other package
		if (
			((($funcArgs.Count -eq 1 -and $funcArgs[0] -eq ".") -and $pkgName -notlike "*.install") -or
			($funcArgs.Count -ne 1 -or $funcArgs[0] -ne ".")) -and ($deps.Id -notcontains $pkgName)
		) {
			Write-Color "Getting list of packages before install test..." -Foreground Blue
			$installedBefore2 = choco list --limit-output | ForEach-Object { ($_ -split '\|')[0] }

			Write-Color "Installing $pkgName version $pkgVersion..." -Foreground Blue
			choco install $pkgName --version=$pkgVersion --source="." --yes --force
			Write-Color "Installing $pkgName version $pkgVersion... (with system powershell)" -Foreground Blue
			choco install $pkgName --version=$pkgVersion --source="." --yes --force --use-system-powershell

			Write-Color "Getting list of packages after install test..." -Foreground Blue
			$installedAfter2 = choco list --limit-output | ForEach-Object { ($_ -split '\|')[0] }
			$newlyInstalled2 = @($installedAfter2 | Where-Object { $_ -notin $installedBefore2 })

			if ($newlyInstalled2.Length -ne 0) {
				Write-Color "Uninstalling newly installed packages: $($newlyInstalled2 -join ', ')" -Foreground Blue
				choco uninstall @newlyInstalled2 --yes
			} else {
				Write-Warning "There is no change in list of packages, it's possible if this package failed to install."
			}
		}
	}

	Write-Color "Getting list of packages after install test..." -Foreground Blue
	$installedAfter = choco list --limit-output | ForEach-Object { ($_ -split '\|')[0] }
	$newlyInstalled = @($installedAfter | Where-Object { $_ -notin $installedBefore })

	if ($newlyInstalled.Length -ne 0) {
		Write-Color "Uninstalling newly installed packages: $($newlyInstalled -join ', ')" -Foreground Blue
		choco uninstall @newlyInstalled --yes
	} else {
		Write-Warning "There is no change in list of packages, it's probably all good."
	}

	Stop-ScreenshotLoop -Verbose
}

function Main {
	Remove-TempFiles
	Test-Validation-Package $folderArgs
	Test-Install-Package $folderArgs
	Remove-TempFiles
}

if ((Split-Path -Path $MyInvocation.InvocationName -Leaf) -eq ($MyInvocation.MyCommand.Name)) {
	Main
}
