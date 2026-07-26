[CmdletBinding()]
param(
    [string]$Bg3DataPath
)

$ErrorActionPreference = "Stop"
$ModuleUuid = "3b7d59a3-a846-4ecd-9c5d-a7bfe3f1b84f"

function Find-Bg3DataPath {
    if ($Bg3DataPath) {
        return (Resolve-Path $Bg3DataPath).Path
    }

    $Candidates = @(
        "${env:ProgramFiles(x86)}\Steam\steamapps\common\Baldurs Gate 3\Data",
        "${env:ProgramFiles}\Steam\steamapps\common\Baldurs Gate 3\Data",
        "C:\GOG Games\Baldurs Gate 3\Data"
    )
    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path $Candidate -PathType Container)) {
            return (Resolve-Path $Candidate).Path
        }
    }

    throw "Could not find BG3 automatically. Re-run with -Bg3DataPath 'D:\...\Baldurs Gate 3\Data'."
}

function Find-AstralArenaSource {
    $Candidates = @(
        (Join-Path $PSScriptRoot "Mods\AstralArena"),
        (Join-Path (Split-Path -Parent $PSScriptRoot) "src\Mods\AstralArena")
    )
    foreach ($Candidate in $Candidates) {
        $Meta = Join-Path $Candidate "meta.lsx"
        if ((Test-Path $Meta -PathType Leaf) -and (Select-String -Path $Meta -SimpleMatch $ModuleUuid -Quiet)) {
            return (Resolve-Path $Candidate).Path
        }
    }
    throw "Could not find an Astral Arena source folder containing module UUID $ModuleUuid."
}

$ResolvedDataPath = Find-Bg3DataPath
$GameRoot = Split-Path -Parent $ResolvedDataPath
$GameExecutable = Join-Path $GameRoot "bin\bg3.exe"
if (-not (Test-Path $GameExecutable -PathType Leaf)) {
    throw "The selected Data folder does not appear to belong to BG3: $ResolvedDataPath"
}

$Source = Find-AstralArenaSource
$ModsDirectory = Join-Path $ResolvedDataPath "Mods"
$Destination = Join-Path $ModsDirectory "AstralArena"
$BackupRoot = Join-Path $env:LOCALAPPDATA "AstralArena\Backups"

New-Item -ItemType Directory -Force -Path $ModsDirectory | Out-Null
if (Test-Path $Destination -PathType Container) {
    $ExistingMeta = Join-Path $Destination "meta.lsx"
    if (-not ((Test-Path $ExistingMeta -PathType Leaf) -and (Select-String -Path $ExistingMeta -SimpleMatch $ModuleUuid -Quiet))) {
        throw "Refusing to replace an unexpected folder: $Destination"
    }

    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Backup = Join-Path $BackupRoot $Timestamp
    New-Item -ItemType Directory -Force -Path $Backup | Out-Null
    Copy-Item -Path $Destination -Destination $Backup -Recurse -Force
    Remove-Item -Path $Destination -Recurse -Force
    Write-Host "Backed up the previous Astral Arena installation to: $Backup"
}

Copy-Item -Path $Source -Destination $Destination -Recurse -Force

Write-Host ""
Write-Host "Installed Astral Arena to: $Destination" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "  1. Open BG3 Mod Manager and refresh."
Write-Host "  2. Move Astral Arena to the active (left) list."
Write-Host "  3. Choose File > Save Order, then File > Export Order to Game."
Write-Host "  4. Make sure BG3 Script Extender v30 or newer is installed."
Write-Host "  5. Enable its console with Enable-SE-Console.ps1, launch BG3, and enter !aa_doctor."
