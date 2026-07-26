[CmdletBinding()]
param(
    [string]$Version = "0.1.1-alpha.1"
)

$ErrorActionPreference = "Stop"
if ($Version -notmatch "^[0-9A-Za-z][0-9A-Za-z.-]*$") {
    throw "Invalid release version: $Version"
}

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$BuildRoot = Join-Path $RepositoryRoot "build\AstralArena-$Version"
$Archive = Join-Path $RepositoryRoot "dist\AstralArena-$Version.zip"

if (Test-Path $BuildRoot) {
    Remove-Item $BuildRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $BuildRoot "Mods") | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Archive) | Out-Null

Copy-Item (Join-Path $RepositoryRoot "src\Mods\AstralArena") (Join-Path $BuildRoot "Mods\AstralArena") -Recurse
Copy-Item (Join-Path $PSScriptRoot "Install-Playtest.ps1") $BuildRoot
Copy-Item (Join-Path $PSScriptRoot "Uninstall-Playtest.ps1") $BuildRoot
Copy-Item (Join-Path $PSScriptRoot "Enable-SE-Console.ps1") $BuildRoot
Copy-Item (Join-Path $RepositoryRoot "PLAYTEST.md") $BuildRoot
Copy-Item (Join-Path $RepositoryRoot "README.md") $BuildRoot
Copy-Item (Join-Path $RepositoryRoot "CHANGELOG.md") $BuildRoot
Copy-Item (Join-Path $RepositoryRoot "CONTRIBUTING.md") $BuildRoot
Copy-Item (Join-Path $RepositoryRoot "LICENSE") $BuildRoot
Copy-Item (Join-Path $RepositoryRoot "docs") (Join-Path $BuildRoot "docs") -Recurse

if (Test-Path $Archive) {
    Remove-Item $Archive -Force
}
Compress-Archive -Path $BuildRoot -DestinationPath $Archive -CompressionLevel Optimal
Write-Host $Archive
