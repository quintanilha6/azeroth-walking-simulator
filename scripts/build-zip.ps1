# Builds a CurseForge-ready zip by hand (the GitHub Action does this automatically).
# Usage (from the addon folder):  powershell -File scripts\build-zip.ps1 -Version 2.1.0
param([Parameter(Mandatory = $true)][string]$Version)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$name = "AzerothWalkingSimulator"
$stage = Join-Path $root ".release\$name"
$zip = Join-Path $root ".release\$name-v$Version.zip"

if (Test-Path (Join-Path $root ".release")) { Remove-Item (Join-Path $root ".release") -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null

# Only the files players need (same list as .pkgmeta keeps)
$keep = @("$name.toc", "*.lua", "LICENSE", "CHANGELOG.md")
foreach ($item in $keep) {
  Get-ChildItem -Path $root -Filter $item -File | Copy-Item -Destination $stage
}
Copy-Item (Join-Path $root "UI") (Join-Path $stage "UI") -Recurse

# Fill in the version (written without a byte-order mark)
$toc = Join-Path $stage "$name.toc"
$text = [IO.File]::ReadAllText($toc).Replace("@project-version@", $Version)
[IO.File]::WriteAllText($toc, $text, (New-Object Text.UTF8Encoding $false))

# The zip must contain the addon folder at its top level, with "/" separators
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$fs = [IO.File]::Open($zip, [IO.FileMode]::Create)
$archive = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
Get-ChildItem $stage -Recurse -File | ForEach-Object {
  $rel = "$name/" + $_.FullName.Substring($stage.Length + 1).Replace("\", "/")
  [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $rel) | Out-Null
}
$archive.Dispose()
$fs.Dispose()
Write-Host "Built $zip"
