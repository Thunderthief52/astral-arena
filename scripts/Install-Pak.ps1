[CmdletBinding()]
param(
    [string]$PakPath
)

$ErrorActionPreference = "Stop"
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $PakPath) {
    $Candidate = Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot "dist") -Filter "AstralArena-*.pak" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $Candidate) {
        throw "No Astral Arena PAK was found in the dist folder."
    }
    $PakPath = $Candidate.FullName
}
$ResolvedPak = (Resolve-Path $PakPath).Path
if ([IO.Path]::GetExtension($ResolvedPak) -ne ".pak") {
    throw "The selected file is not a .pak: $ResolvedPak"
}

$ModsDirectory = Join-Path $env:LOCALAPPDATA "Larian Studios\Baldur's Gate 3\Mods"
$Destination = Join-Path $ModsDirectory "AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6.pak"
$BackupRoot = Join-Path $env:LOCALAPPDATA "AstralArena\PakBackups"
New-Item -ItemType Directory -Force -Path $ModsDirectory | Out-Null

if (Test-Path $Destination -PathType Leaf) {
    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Backup = Join-Path $BackupRoot $Timestamp
    New-Item -ItemType Directory -Force -Path $Backup | Out-Null
    Copy-Item -LiteralPath $Destination -Destination $Backup
    Write-Host "Backed up the previous PAK to: $Backup"
}
Copy-Item -LiteralPath $ResolvedPak -Destination $Destination -Force

Write-Host "Installed Astral Arena Adventure:" -ForegroundColor Green
Write-Host "  $Destination"
Write-Host "Enable Astral Arena Adventure in BG3's Mod Manager, then start a new game."
