[CmdletBinding()]
param(
    [string]$PakPath,
    [string]$LocalAppDataPath = $env:LOCALAPPDATA,
    [string]$Bg3DataPath
)

$ErrorActionPreference = "Stop"
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $PakPath) {
    $Candidate = Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot "dist") -Filter "AstralArena-*.pak" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^AstralArena-\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)\.\d+)?\.pak$' } |
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
if ([IO.Path]::GetFileName($ResolvedPak) -notmatch '^AstralArena-\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)\.\d+)?\.pak$') {
    throw 'Only normal versioned release PAKs can be installed with this script. Temporary terrain probes are excluded.'
}

if (Get-Process bg3, bg3_dx11, Glasses -ErrorAction SilentlyContinue) {
    throw "Close Baldur's Gate 3 and the Toolkit before installing the PAK."
}
if (-not $Bg3DataPath) {
    $Bg3DataPath = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Steam\steamapps\common\Baldurs Gate 3\Data'
}
$DataRoot = $null
if (Test-Path -LiteralPath $Bg3DataPath -PathType Container) {
    $DataRoot = (Resolve-Path -LiteralPath $Bg3DataPath).Path
    if (-not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $DataRoot) 'bin\bg3.exe') -PathType Leaf)) {
        throw "The supplied Data folder does not belong to BG3: $DataRoot"
    }
}
$ModsDirectory = Join-Path $LocalAppDataPath "Larian Studios\Baldur's Gate 3\Mods"
$Destination = Join-Path $ModsDirectory "AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6.pak"
$BackupRoot = Join-Path $LocalAppDataPath "AstralArena\PakBackups"
New-Item -ItemType Directory -Force -Path $ModsDirectory | Out-Null
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$Backup = Join-Path $BackupRoot $Timestamp

if (Test-Path $Destination -PathType Leaf) {
    New-Item -ItemType Directory -Force -Path $Backup | Out-Null
    Copy-Item -LiteralPath $Destination -Destination $Backup
    Write-Host "Backed up the previous PAK to: $Backup"
}
Copy-Item -LiteralPath $ResolvedPak -Destination $Destination -Force
$SourceHash = (Get-FileHash -LiteralPath $ResolvedPak -Algorithm SHA256).Hash
if ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -ne $SourceHash) {
    throw "Installed PAK does not match the source. Restore the backup before launching BG3."
}
Write-Host "Verified SHA256: $SourceHash"

# Loose Toolkit runtime files override package contents, including older Lua,
# level data and version metadata. Preserve this module's files outside Data.
if ($DataRoot) {
    foreach ($Category in @('Mods', 'Public')) {
        $Parent = [IO.Path]::GetFullPath((Join-Path $DataRoot $Category))
        $Loose = Join-Path $Parent 'AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6'
        if (Test-Path -LiteralPath $Loose -PathType Container) {
            $ResolvedLoose = (Resolve-Path -LiteralPath $Loose).Path
            if ((Split-Path -Parent $ResolvedLoose) -ne $Parent) { throw "Unexpected loose module path: $ResolvedLoose" }
            $BackupParent = [IO.Path]::GetFullPath((Join-Path $Backup "LooseData\$Category"))
            if (-not $BackupParent.StartsWith([IO.Path]::GetFullPath($BackupRoot) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Unexpected loose-module backup path: $BackupParent"
            }
            New-Item -ItemType Directory -Force -Path $BackupParent | Out-Null
            Move-Item -LiteralPath $ResolvedLoose -Destination $BackupParent
            Write-Host "Preserved loose Toolkit runtime files in: $BackupParent"
        }
    }
}

Write-Host "Installed Astral Arena Adventure:" -ForegroundColor Green
Write-Host "  $Destination"
Write-Host "Enable Astral Arena Adventure in BG3's Mod Manager, then start a new game."
Write-Host 'Terrain updates require a NEW Adventure: an existing save can retain its previous navigation grid.'
Write-Host 'Before editing this module in the Toolkit again, run scripts/Sync-ToolkitProject.ps1 to restore its editor runtime files.'
