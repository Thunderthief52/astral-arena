[CmdletBinding()]
param(
    [string]$Version = "0.3.2-alpha.5",
    [string]$Bg3DataPath,
    [string]$DivinePath
)

$ErrorActionPreference = "Stop"
if ($Version -notmatch "^[0-9A-Za-z][0-9A-Za-z.-]*$") {
    throw "Invalid release version: $Version"
}

$ModuleFolder = "AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6"
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$BuildRoot = Join-Path $RepositoryRoot "build\pak-$Version"
$SourceModule = Join-Path $RepositoryRoot "toolkit\Data\Mods\$ModuleFolder"
$StageMods = Join-Path $BuildRoot "Mods"
$StageModule = Join-Path $StageMods $ModuleFolder
$PakPath = Join-Path $RepositoryRoot "dist\AstralArena-$Version.pak"
$LocalizationSource = Join-Path $RepositoryRoot "src\Localization\English\AstralArena_English.xml"
$StageLocalization = Join-Path $BuildRoot "Localization\English\AstralArena_English.loca"

if (-not $DivinePath) {
    $DivinePath = Join-Path (Split-Path -Parent $RepositoryRoot) "tools\ExportTool-v1.19.5\Packed\Tools\Divine.exe"
}
if (-not (Test-Path -LiteralPath $DivinePath -PathType Leaf)) {
    throw "Divine.exe was not found at '$DivinePath'."
}

if (-not $Bg3DataPath) {
    $ProgramFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")
    $Bg3DataPath = Join-Path $ProgramFilesX86 "Steam\steamapps\common\Baldurs Gate 3\Data"
}
if (-not (Test-Path -LiteralPath $Bg3DataPath -PathType Container)) {
    throw "BG3 Toolkit Data was not found at '$Bg3DataPath'."
}
if (-not (Test-Path -LiteralPath $SourceModule -PathType Container)) {
    throw "Toolkit module source is missing: $SourceModule"
}

if (Test-Path -LiteralPath $BuildRoot) {
    $ResolvedBuild = (Resolve-Path -LiteralPath $BuildRoot).Path
    $ResolvedRepositoryBuild = (Resolve-Path -LiteralPath (Join-Path $RepositoryRoot "build")).Path
    if (-not $ResolvedBuild.StartsWith($ResolvedRepositoryBuild + [IO.Path]::DirectorySeparatorChar)) {
        throw "Refusing to clear unexpected build path: $ResolvedBuild"
    }
    Remove-Item -LiteralPath $ResolvedBuild -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $StageMods | Out-Null
Copy-Item -LiteralPath $SourceModule -Destination $StageMods -Recurse -Force

$StageScriptExtender = Join-Path $StageModule "ScriptExtender"
New-Item -ItemType Directory -Force -Path $StageScriptExtender | Out-Null
Copy-Item -Path (Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\*") -Destination $StageScriptExtender -Recurse -Force

if (-not (Test-Path -LiteralPath $LocalizationSource -PathType Leaf)) {
    throw "English arena menu localization source is missing: $LocalizationSource"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $StageLocalization) | Out-Null
& $DivinePath -g bg3 -a convert-loca -s $LocalizationSource -d $StageLocalization
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $StageLocalization -PathType Leaf)) {
    throw "Divine failed to compile the arena menu localization."
}

$InstalledModule = Join-Path $Bg3DataPath "Mods\$ModuleFolder"
foreach ($RelativePath in @("GUI\metadata.lsf", "mod_publish_logo.png")) {
    $Source = Join-Path $InstalledModule $RelativePath
    $Destination = Join-Path $StageModule $RelativePath
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Toolkit-generated package asset is missing: $Source"
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $PakPath) | Out-Null
if (Test-Path -LiteralPath $PakPath) {
    Remove-Item -LiteralPath $PakPath -Force
}
& $DivinePath -g bg3 -a create-package -s $BuildRoot -d $PakPath -c lz4
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $PakPath -PathType Leaf)) {
    throw "Divine failed to create the Adventure PAK."
}

$Listing = @(& $DivinePath -g bg3 -a list-package -s $PakPath 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Divine could not validate the created Adventure PAK."
}
foreach ($RequiredEntry in @(
    "Mods/$ModuleFolder/meta.lsx",
    "Mods/$ModuleFolder/Levels/AA_Arena_Main/meta.lsf",
    "Mods/$ModuleFolder/ScriptExtender/Lua/AstralArena/Server/Controller.lua",
    "Mods/$ModuleFolder/ScriptExtender/Lua/AstralArena/Server/Bg3Adapter.lua",
    "Localization/English/AstralArena_English.loca"
)) {
    if (-not ($Listing | Where-Object { $_ -like "$RequiredEntry`t*" })) {
        throw "Created PAK is missing required entry: $RequiredEntry"
    }
}

Write-Host "Astral Arena Adventure PAK built:" -ForegroundColor Green
Write-Host "  $PakPath"
Write-Host "  Entries: $($Listing.Count)"
