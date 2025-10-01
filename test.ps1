param (
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$folderArgs = "."
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

function Remove-TempFiles {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
	param ()

	process {
		$targets = @()
		$targets += Get-ChildItem -Path "." -Recurse | Where-Object { $_.Extension -in ".zip", ".exe" }
		$targets += Get-ChildItem -Path "." -Filter *.nupkg

		foreach ($t in $targets) {
			if ($PSCmdlet.ShouldProcess($t.FullName, "Remove temp file")) {
				Remove-Item $t.FullName -Force -ErrorAction SilentlyContinue -Verbose
			}
		}
	}
}

function Get-Installer {
	param (
		[string]$PackageDir
	)

	# Try to find VERIFICATION.txt in common folders
	$verificationFile = Get-ChildItem -Path $PackageDir -Recurse -Filter "VERIFICATION.txt" -File -ErrorAction SilentlyContinue | Where-Object { $_.Directory.Name -in @("tools","legal") } | Select-Object -First 1 -ExpandProperty FullName
	if (-not $verificationFile -or -not (Test-Path $verificationFile)) {
		Write-Warning "No VERIFICATION.txt found in $PackageDir, skipping download."
		return
	}

	$content = Get-Content $verificationFile

	$url = ($content | Select-String -Pattern '^  URL: <(.*)>$').Matches.Groups[1].Value

	if (-not $url) {
		Write-Warning "No URL found in VERIFICATION.txt at $PackageDir"
		return
	}

	$checksumType = ($content | Select-String -Pattern '^  checksum_type: (.*)$').Matches.Groups[1].Value
	$expectedChecksum = ($content | Select-String -Pattern '^  file_checksum: (.*)$').Matches.Groups[1].Value.ToUpper()
	$actualChecksum = $(Get-RemoteChecksum $url $checksumType).ToUpper()

	$toolsDir = Join-Path $PackageDir "tools"
	if (-not (Test-Path $toolsDir)) {
		New-Item -ItemType Directory -Path $toolsDir | Out-Null
	}
	$outFile = Join-Path $toolsDir ([System.IO.Path]::GetFileName($url))

	Write-Output "Downloading $url to $outFile..."
	curl.exe -L $url -o $outFile

	if ($checksumType -and $expectedChecksum) {
		Write-Output "Verifying $outFile..."
		$actualChecksum = (Get-FileHash -Path $outFile -Algorithm $checksumType).Hash.ToUpper()

		Write-Output "Expected checksum: $expectedChecksum"
		Write-Output "Actual checksum:   $actualChecksum"

		if ($actualChecksum -ne $expectedChecksum) {
			throw "Checksum verification failed for $outFile"
		} else {
			Write-Color "Checksum verification passed for $outFile" -Foreground Green
		}
	} else {
		Write-Warning "No checksum info found, download only."
	}
}

function Get-Dependencies {
	param([string]$nuspecPath)

	try {
		[xml]$xml = Get-Content $nuspecPath -Raw
		$deps = @()

		# Parse <dependencies><dependency id="..." version="..." />
		$xml.package.metadata.dependencies.dependency | ForEach-Object {
			if ($_.id) { $deps += $_.id }
		}

		return $deps
	} catch {
		return @()
	}
}

# =================================================================================================

function Test-Validation-Package {
	foreach ($pkgFolder in $folderArgs) {
		Get-ChildItem -Path $pkgFolder -Recurse -Filter *.nuspec | ForEach-Object {
			$dir = $_.DirectoryName
			$file = $_.FullName

			cnc $dir
			Get-Installer $dir
			choco pack $file
		}
	}
}

function Test-Install-Package {
	Write-Color "Getting list of packages before install test..." -Foreground Blue
	$installedBefore = choco list --limit-output | ForEach-Object { ($_ -split '\|')[0] }

	# Get all nuspec dependency info
	$allDependencies = @{}
	foreach ($pkgFolder in $folderArgs) {
		Get-ChildItem -Path $pkgFolder -Recurse -Filter *.nuspec | ForEach-Object {
			$id = ([xml](Get-Content $_.FullName -Raw)).package.metadata.id
			$deps = Get-Dependencies $_.FullName
			$allDependencies[$id] = $deps
		}
	}
	$depIds = $allDependencies.Values | ForEach-Object { $_ } | Select-Object -Unique

	Get-ChildItem -Path "." -Filter *.nupkg | ForEach-Object {
		$filename = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName)

		# Getting the pkgName and pkgVersion directly from the filename
		if ($filename -match '^(?<id>.+)\.(?<version>\d+\.\d+\.\d+(-[A-Za-z0-9]+)?)$') {
			$pkgName = $matches['id']
			$pkgVersion = $matches['version']
		}

		# Skipping .install package only if $folderArgs is in default value (".") or it is in dependency from other package
		if (
			((($folderArgs.Count -eq 1 -and $folderArgs[0] -eq ".") -and $pkgName -notlike "*.install") -or
			($folderArgs.Count -ne 1 -or $folderArgs[0] -ne ".")) -and ($depIds -notcontains $pkgName)
		) {
			Write-Color "Installing $pkgName version $pkgVersion..." -Foreground Blue
			choco install $pkgName --version=$pkgVersion --source="." --yes --force
			Write-Color "Installing $pkgName version $pkgVersion... (with system powershell)" -Foreground Blue
			choco install $pkgName --version=$pkgVersion --source="." --yes --force --use-system-powershell
		}
	}

	Write-Color "Getting list of packages after install test..." -Foreground Blue
	$installedAfter = choco list --limit-output | ForEach-Object { ($_ -split '\|')[0] }
	$newlyInstalled = @($installedAfter | Where-Object { $_ -notin $installedBefore })

	if ($newlyInstalled.Length -ne 0) {
		Write-Color "Uninstalling newly installed packages: $($newlyInstalled -join ', ')" -Foreground Blue
		choco uninstall @newlyInstalled -yes
	} else {
		Write-Warning "There is no change in list of packages, it's possible if all the previous package installs failed."
	}
}

function Main {
	Remove-TempFiles
	Test-Validation-Package
	Test-Install-Package
	Remove-TempFiles
}

if ((Split-Path -Path $MyInvocation.InvocationName -Leaf) -eq $MyInvocation.MyCommand.Name) {
	Main
}
