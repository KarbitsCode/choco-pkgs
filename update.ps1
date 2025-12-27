param (
	[Parameter(Mandatory = $true, Position = 1)]
	[string]$packageFolder,
	[Parameter(Mandatory = $true, Position = 2)]
	[string]$newVersion
)

. "$PSScriptRoot\test.ps1"
Push-Location $packageFolder

$newFolder = Join-Path "$(Get-Location)" $newVersion
if (Test-Path $newFolder) {
	throw "Folder with version $newVersion already exists."
}

Write-Color "Getting latest version locally..." -Foreground Blue
$existingVersions = Get-ChildItem -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+(\.\d+)?$' } | Sort-Object { [Version]$_.Name }
$previousVersion = $existingVersions[-1].Name
$previousFolder = Join-Path "$(Get-Location)" $previousVersion
Write-Color "Found local version: $previousVersion" -Foreground Green

Write-Color "Cloning folder: $previousVersion -> $newVersion" -Foreground Blue
Copy-Item $previousFolder $newFolder -Recurse -Verbose
Write-Color "Done cloning folder: $newVersion" -Foreground Green

Write-Color "Replacing version data to $newVersion..." -Foreground Blue
$oldVersionDot = $previousVersion                     # "2.0.7.0"
$oldVersionUnd = $previousVersion -replace '\.', '_'  # "2_0_7_0"
$newVersionDot = $newVersion                          # "3.0.1.0"
$newVersionUnd = $newVersion -replace '\.', '_'       # "3_0_1_0"
$patterns = @(
	@{ Old = [regex]::Escape($oldVersionDot); New = $newVersionDot },
	@{ Old = [regex]::Escape($oldVersionUnd); New = $newVersionUnd }
)
Get-ChildItem $newFolder -Recurse -File | ForEach-Object {
	$content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
	if ($null -eq $content) { return }
	$original = $content

	foreach ($p in $patterns) {
		$content = $content -replace $p.Old, $p.New
	}

	if ($content -ne $original) {
		Set-Content $_.FullName $content -Encoding UTF8 -Verbose
		Normalize-TrailingLines $_.FullName
	}
}
Write-Color "Done replacing version data on all files with $newVersion" -Foreground Green

Write-Color "Retriving package installer info in $newVersion..." -Foreground Blue
$info = Get-InstallerInfoFromPackageArgs $newFolder
if (-not $info) {
	$info = Get-InstallerInfoFromVerification $newFolder
}
if (-not $info) {
	Write-Warning "There's no installer info in package, skipping..."
} else {
	Write-Color "Successfully retrived package installer info from $newVersion" -Foreground Green

	Write-Color "Updating package installer hash in $newVersion..." -Foreground Blue
	$newChecksum = (Get-RemoteChecksum $info.Url -Algorithm $info.ChecksumType).ToUpper()
	Write-Color "Got new checksum: $newChecksum" -Foreground Green
	$newInstallerInfo = @{
							Url          = $info.Url
							Checksum     = $newChecksum
							ChecksumType = $info.ChecksumType
							OutputFile   = ""
							Source       = $info.Source
						}
	Set-InstallerInfo $newFolder $newInstallerInfo
	Write-Color "Done updating package installer hash in $newVersion" -Foreground Green

	if ($info.Source -eq "VERIFICATION.txt") {
		Write-Color "Downloading installer to $newFolder..." -Foreground Blue
		Download-Installer -Url $info.Url -OutputFile $info.OutputFile
		Write-Color "Done downloading installer to $($info.OutputFile)" -Foreground Green
	}
}

Write-Color "Successfully updated $packageFolder to version $newVersion" -Foreground Green
Pop-Location


