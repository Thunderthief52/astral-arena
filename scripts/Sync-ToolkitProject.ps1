[CmdletBinding()]
param(
    [string]$Bg3DataPath
)

$ErrorActionPreference = "Stop"
$ModuleFolder = "AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6"
$ModuleUuid = "29c48c80-8777-f7b5-6bb8-376c1c5d8db6"
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$SourceData = Join-Path $RepositoryRoot "toolkit\Data"

function Find-Bg3DataPath {
    if ($Bg3DataPath) {
        return (Resolve-Path $Bg3DataPath).Path
    }
    $ProgramFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
    $ProgramFiles = [Environment]::GetFolderPath("ProgramFiles")
    $Candidates = @(
        (Join-Path $ProgramFilesX86 "Steam\steamapps\common\Baldurs Gate 3\Data"),
        (Join-Path $ProgramFiles "Steam\steamapps\common\Baldurs Gate 3\Data"),
        "C:\GOG Games\Baldurs Gate 3\Data"
    )
    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path $Candidate -PathType Container)) {
            return (Resolve-Path $Candidate).Path
        }
    }
    throw "Could not find the Baldur's Gate 3 Data folder."
}

function Copy-ProjectTree {
    param([string]$RelativePath, [string]$DataRoot)

    $Source = Join-Path $SourceData $RelativePath
    $Destination = Join-Path $DataRoot $RelativePath
    if (-not (Test-Path $Source -PathType Container)) {
        throw "Toolkit source directory is missing: $Source"
    }

    $Parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    if (Test-Path $Destination -PathType Container) {
        $Meta = Join-Path $Destination "meta.lsx"
        if ((Test-Path $Meta -PathType Leaf) -and -not (Select-String -LiteralPath $Meta -SimpleMatch $ModuleUuid -Quiet)) {
            throw "Refusing to update an unexpected Toolkit project: $Destination"
        }
    }
    Copy-Item -LiteralPath $Source -Destination $Parent -Recurse -Force
}

$ResolvedData = Find-Bg3DataPath
$GameRoot = Split-Path -Parent $ResolvedData
if (-not (Test-Path (Join-Path $GameRoot "bin\bg3.exe") -PathType Leaf)) {
    throw "The selected Data folder does not belong to Baldur's Gate 3: $ResolvedData"
}

Copy-ProjectTree -RelativePath (Join-Path "Projects" $ModuleFolder) -DataRoot $ResolvedData
Copy-ProjectTree -RelativePath (Join-Path "Editor\Mods" $ModuleFolder) -DataRoot $ResolvedData
Copy-ProjectTree -RelativePath (Join-Path "Mods" $ModuleFolder) -DataRoot $ResolvedData

$ScriptSource = Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender"
$ModuleDestination = Join-Path $ResolvedData (Join-Path "Mods" $ModuleFolder)
$ScriptDestination = Join-Path $ModuleDestination "ScriptExtender"
if (-not (Select-String -LiteralPath (Join-Path $ModuleDestination "meta.lsx") -SimpleMatch $ModuleUuid -Quiet)) {
    throw "Adventure module identity validation failed: $ModuleDestination"
}
New-Item -ItemType Directory -Force -Path $ScriptDestination | Out-Null
Copy-Item -Path (Join-Path $ScriptSource "*") -Destination $ScriptDestination -Recurse -Force

Write-Host "Synchronized Astral Arena Toolkit project:" -ForegroundColor Green
Write-Host "  Project: $ModuleFolder"
Write-Host "  Level:   AA_Arena_Main"
Write-Host "  Data:    $ResolvedData"
