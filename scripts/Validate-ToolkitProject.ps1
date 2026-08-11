[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ModuleFolder = "AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6"
$ModuleUuid = "29c48c80-8777-f7b5-6bb8-376c1c5d8db6"
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$DataRoot = Join-Path $RepositoryRoot "toolkit\Data"
$ModuleRoot = Join-Path $DataRoot (Join-Path "Mods" $ModuleFolder)
$EditorRoot = Join-Path $DataRoot (Join-Path "Editor\Mods" $ModuleFolder)
$ProjectRoot = Join-Path $DataRoot (Join-Path "Projects" $ModuleFolder)
$MetaPath = Join-Path $ModuleRoot "meta.lsx"

$Required = @(
    $MetaPath,
    (Join-Path $ModuleRoot "Levels\AA_Arena_Main\meta.lsf"),
    (Join-Path $ModuleRoot "Levels\AA_Arena_Main\Ai\aigrid.data"),
    (Join-Path $ModuleRoot "Levels\AA_Arena_Main\Terrains\bcc2dd2c-a07d-4bda-a199-3f95933efee0.lsf"),
    (Join-Path $EditorRoot "Levels\AA_Arena_Main\EditorMetaData.lsx"),
    (Join-Path $ProjectRoot "meta.lsx"),
    (Join-Path $ProjectRoot "thumbnail.png"),
    (Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\BootstrapServer.lua"),
    (Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Shared\ArenaSites.lua")
)
foreach ($Path in $Required) {
    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "Required Toolkit artifact is missing: $Path"
    }
}

[xml]$Meta = Get-Content -LiteralPath $MetaPath -Raw
$Attributes = $Meta.SelectNodes("//node[@id='ModuleInfo']/attribute")
$Values = @{}
foreach ($Attribute in $Attributes) {
    $Values[$Attribute.id] = $Attribute.value
}
if ($Values.UUID -ne $ModuleUuid) { throw "Unexpected module UUID: $($Values.UUID)" }
if ($Values.Type -ne "Adventure") { throw "Module type must be Adventure." }
if ($Values.StartupLevelName -ne "AA_Arena_Main") { throw "Startup level is not AA_Arena_Main." }
if ($Values.CharacterCreationLevelName -ne "AA_Arena_Main") { throw "Character creation is not wired to AA_Arena_Main." }
if ($Values.NumPlayers -ne "4") { throw "Adventure must support four players." }
if ((Get-Content -LiteralPath $MetaPath -Raw) -match 'WLD_|BGO_|CRE_|END_') {
    throw "Adventure metadata references a vanilla campaign level."
}

Add-Type -AssemblyName System.Drawing
$ThumbnailPath = Join-Path $ProjectRoot "thumbnail.png"
$Image = [Drawing.Image]::FromFile($ThumbnailPath)
try {
    if ($Image.Width -lt 512 -or $Image.Height -lt 288) {
        throw "Project thumbnail is smaller than 512x288."
    }
} finally {
    $Image.Dispose()
}

$SitesPath = Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Shared\ArenaSites.lua"
$SitesText = Get-Content -LiteralPath $SitesPath -Raw
foreach ($Site in @("astral-flats", "crescent-ruin", "echelon-steps")) {
    if ($SitesText -notmatch [regex]::Escape($Site)) {
        throw "Arena site is missing from the runtime catalog: $Site"
    }
}

Write-Host "Toolkit project validation passed:" -ForegroundColor Green
Write-Host "  Adventure UUID: $ModuleUuid"
Write-Host "  Startup/CC:     AA_Arena_Main"
Write-Host "  Combat sites:   Astral Flats, Crescent Ruin, Echelon Steps"
Write-Host "  Players:        1-4"
