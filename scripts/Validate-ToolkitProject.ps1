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
$ArenaLevelRoot = Join-Path $ModuleRoot "Levels\AA_Arena_Main"
$SceneryManifestPath = Join-Path $RepositoryRoot "toolkit\scenery\AA_Arena_Main.scenery.json"
$GeneratedSceneryIndexPath = Join-Path $RepositoryRoot "toolkit\scenery\AA_Arena_Main.generated-files.json"

$Required = @(
    $MetaPath,
    (Join-Path $ModuleRoot "Levels\AA_Arena_Main\meta.lsf"),
    (Join-Path $ModuleRoot "Levels\AA_Arena_Main\Ai\aigrid.data"),
    (Join-Path $ModuleRoot "Levels\AA_Arena_Main\Terrains\bcc2dd2c-a07d-4bda-a199-3f95933efee0.lsf"),
    (Join-Path $EditorRoot "Levels\AA_Arena_Main\EditorMetaData.lsx"),
    (Join-Path $ProjectRoot "meta.lsx"),
    (Join-Path $ProjectRoot "thumbnail.png"),
    (Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\BootstrapServer.lua"),
    (Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Shared\ArenaSites.lua"),
    $SceneryManifestPath,
    $GeneratedSceneryIndexPath
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
if ($Values.CharacterCreationLevelName -ne "") { throw "Character creation must inherit BG3's system character creator." }
if ($Values.NumPlayers -ne "4") { throw "Adventure must support four players." }
if ((Get-Content -LiteralPath $MetaPath -Raw) -match 'WLD_|BGO_|CRE_|END_|TUT_') {
    throw "Adventure metadata references a vanilla campaign level."
}

$ControllerPath = Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Server\Controller.lua"
$ControllerText = Get-Content -LiteralPath $ControllerPath -Raw
if ($ControllerText -notmatch 'DB_CharacterCreationTransitionInfo\(Constants\.ArenaLevel, ""\)') {
    throw "Adventure runtime does not configure the character-creation transition to AA_Arena_Main."
}
if ($ControllerText -notmatch 'RegisterListener\("CharacterCreationFinished", 0, "before"') {
    throw "Adventure runtime must configure the transition from the unrestricted pre-character-creation-finished Osiris callback."
}
if ($ControllerText -match 'Ext\.Events\.SessionLoaded:Subscribe\(function\(\)\s*configureAdventureTransition\(\)') {
    throw "Adventure runtime attempts to mutate Osiris databases from restricted SessionLoaded context."
}
if ($ControllerText -notmatch 'TeleportPartiesToLevelWithMovie\(Constants\.ArenaLevel, "", ""\)') {
    throw "Adventure runtime is missing the SYS_CC recovery transfer to AA_Arena_Main."
}
if ($ControllerText -notmatch 'RegisterListener\("LevelGameplayReady", 2') {
    throw "Adventure runtime does not re-arm onboarding when arena gameplay becomes ready."
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

$SceneryManifest = Get-Content -LiteralPath $SceneryManifestPath -Raw | ConvertFrom-Json
$GeneratedSceneryIndex = [string[]](Get-Content -LiteralPath $GeneratedSceneryIndexPath -Raw | ConvertFrom-Json)
$AllSceneryEntries = @($SceneryManifest.objects) + @($SceneryManifest.lights)
if (@($AllSceneryEntries | Group-Object id | Where-Object Count -gt 1).Count -gt 0) {
    throw "Arena scenery manifest contains duplicate ids."
}
if (@($AllSceneryEntries | Group-Object name | Where-Object Count -gt 1).Count -gt 0) {
    throw "Arena scenery manifest contains duplicate object names."
}
foreach ($Object in $SceneryManifest.objects) {
    $TemplateUuid = [guid]::Empty
    if (-not [guid]::TryParse([string]$Object.template, [ref]$TemplateUuid)) {
        throw "Arena scenery object '$($Object.id)' has an invalid template UUID."
    }
}

$ExpectedSceneryCount = @($SceneryManifest.objects).Count
$ExpectedLightCount = @($SceneryManifest.lights).Count
$ActualSceneryFiles = @(Get-ChildItem -LiteralPath (Join-Path $ArenaLevelRoot "Scenery") -Filter *.lsf -File)
$ActualLightFiles = @(Get-ChildItem -LiteralPath (Join-Path $ArenaLevelRoot "Lights") -Filter *.lsf -File)
if ($ActualSceneryFiles.Count -ne $ExpectedSceneryCount) {
    throw "Expected $ExpectedSceneryCount scenery files, found $($ActualSceneryFiles.Count)."
}
if ($ActualLightFiles.Count -ne $ExpectedLightCount) {
    throw "Expected $ExpectedLightCount light files, found $($ActualLightFiles.Count)."
}
if ($GeneratedSceneryIndex.Count -ne ($ExpectedSceneryCount + $ExpectedLightCount)) {
    throw "Generated scenery index does not match the manifest."
}
foreach ($RelativePath in $GeneratedSceneryIndex) {
    $GeneratedPath = Join-Path $RepositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $GeneratedPath -PathType Leaf)) {
        throw "Indexed generated scenery artifact is missing: $GeneratedPath"
    }
    if ((Get-Item -LiteralPath $GeneratedPath).Length -lt 100) {
        throw "Generated scenery artifact is unexpectedly small: $GeneratedPath"
    }
}

Write-Host "Toolkit project validation passed:" -ForegroundColor Green
Write-Host "  Adventure UUID: $ModuleUuid"
Write-Host "  Character flow: inherited system CC -> AA_Arena_Main"
Write-Host "  Combat sites:   Astral Flats, Crescent Ruin, Echelon Steps"
Write-Host "  Visual pass:    $ExpectedSceneryCount scenery objects, $ExpectedLightCount lights"
Write-Host "  Players:        1-4"
