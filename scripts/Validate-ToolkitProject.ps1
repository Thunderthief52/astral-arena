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
    (Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Shared\AdventureHandoff.lua"),
    (Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Shared\ArenaSites.lua"),
    (Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Shared\PreparationLoadout.lua"),
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
if ($Values.Version64 -ne "36028797018963984") { throw "Adventure module version is not alpha.16 build 16." }
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
if ($ControllerText -notmatch 'markCharacterCreationFinished\(adventureHandoff\)') {
    throw "Adventure runtime does not gate recovery behind CharacterCreationFinished."
}
if ($ControllerText -match 'else\s+recoverCharacterCreationHandoff\(levelName\)') {
    throw "LevelGameplayReady must not transfer the temporary character-creation dummies."
}
if ($ControllerText -notmatch 'schedule\(2500, finishCharacterCreationHandoff\)') {
    throw "Adventure runtime does not defer its post-completion fallback check."
}
if ($ControllerText -notmatch 'RegisterListener\("LevelGameplayReady", 2') {
    throw "Adventure runtime does not re-arm onboarding when arena gameplay becomes ready."
}

$HandoffPath = Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Shared\AdventureHandoff.lua"
$HandoffText = Get-Content -LiteralPath $HandoffPath -Raw
if ($HandoffText -notmatch 'state\.characterCreationFinished == true') {
    throw "Character-creation recovery does not require a completed creator session."
}

$AdapterPath = Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Server\Bg3Adapter.lua"
$AdapterText = Get-Content -LiteralPath $AdapterPath -Raw
if ($AdapterText -notmatch 'AddExplorationExperience\(member\.guid, gain\)') {
    throw "XP onboarding does not award independently owned split-screen avatars."
}
if ($AdapterText -match 'AddExplorationExperience\(members\[1\]\.guid, gain\)') {
    throw "XP onboarding still assumes the first party member covers every split-screen avatar."
}
foreach ($UnsafeCampTemplate in @(
    "edb2601b-7f01-44e5-84df-7513a695d4eb",
    "14d9b664-b4e4-4e22-a83f-7fafd09f61f5"
)) {
    if ($AdapterText -match [regex]::Escape($UnsafeCampTemplate)) {
        throw "Arena startup still references crash-prone campaign template $UnsafeCampTemplate."
    }
}
if ($AdapterText -match 'ensureCampService' -or $AdapterText -match 'Osi\.CreateAt\(WITHERS') {
    throw "Arena onboarding must not create campaign Withers or ledger entities at runtime."
}

$CampServicePath = Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Server\CampService.lua"
$CampServiceText = Get-Content -LiteralPath $CampServicePath -Raw
if ($CampServiceText -notmatch 'STARTING_GOLD = 300' -or $CampServiceText -notmatch 'HIRELING_COST = 100') {
    throw "Arena camp economy is not configured for 300 starting gold and 100-gold hirelings."
}
if ($ControllerText -match 'campService:isLedger' -or $ControllerText -match 'RegisterListener\("UseFinished", 3') {
    throw "Crash-prone world ledger interaction is still registered."
}

$SoloArenaPath = Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Server\SoloArena.lua"
$SoloArenaText = Get-Content -LiteralPath $SoloArenaPath -Raw
if ($SoloArenaText -notmatch '_repairMixedLevelParty' -or $SoloArenaText -notmatch '"repairing"') {
    throw "Automatic onboarding cannot recover a mixed-level split-screen party."
}
if ($SoloArenaText -notmatch 'kind = "wave_start"' -or $SoloArenaText -notmatch 'Constants\.MenuMessages\.waveStart') {
    throw "Arena waves are not gated by the controller-safe ready prompt."
}
if ($AdapterText -notmatch 'restoreWaveResources' -or $AdapterText -notmatch 'Osi\.RestoreParty') {
    throw "Between-wave recovery does not restore spell slots and class resources."
}
$PreparationLoadoutText = Get-Content -LiteralPath (Join-Path $RepositoryRoot "src\Mods\AstralArena\ScriptExtender\Lua\AstralArena\Shared\PreparationLoadout.lua") -Raw
foreach ($RequiredSlot in @("light-armour", "medium-armour", "heavy-armour", "helmet", "gloves", "boots", "amulet", "ring")) {
    if ($PreparationLoadoutText -notmatch [regex]::Escape('slot = "' + $RequiredSlot + '"')) {
        throw "Personal preparation loadout is missing required slot: $RequiredSlot"
    }
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
$LevelMetaSourcePath = Join-Path $RepositoryRoot "toolkit\levels\AA_Arena_Main.meta.lsx"
if (-not (Test-Path -LiteralPath $LevelMetaSourcePath -PathType Leaf)) {
    throw "Arena level metadata source is missing."
}
[xml]$LevelMetaSource = Get-Content -LiteralPath $LevelMetaSourcePath -Raw
$LevelMetaValues = @{}
foreach ($Attribute in $LevelMetaSource.save.region.node.attribute) {
    $LevelMetaValues[$Attribute.id] = $Attribute.value
}
if ($LevelMetaValues.LevelAtmosphere -ne "73e03af9-7ab1-47a7-906b-a4e0362045ef") {
    throw "Arena level does not use the shipped Underdark atmosphere."
}
$LevelBoundsNode = $LevelMetaSource.save.region.node.children.node | Where-Object id -eq "LevelBounds"
$LevelBoundsValues = @{}
foreach ($Attribute in $LevelBoundsNode.attribute) {
    $LevelBoundsValues[$Attribute.id] = $Attribute.value
}
if ($LevelBoundsValues.Min -ne "-140 -40 -100" -or $LevelBoundsValues.Max -ne "140 60 110") {
    throw "Arena level bounds do not contain the Underdark vista shell."
}
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

$CombatClearZones = @($SceneryManifest.combatClearZones)
$NavigationClearZones = @($SceneryManifest.navigationClearZones)
if ($CombatClearZones.Count -ne 3) {
    throw "Arena scenery manifest must define three combat-clear approach zones."
}
if ($NavigationClearZones.Count -lt 2) {
    throw "Arena scenery manifest must define safe staging and Withers approach zones."
}
$ClearZones = @($CombatClearZones) + @($NavigationClearZones)
foreach ($Zone in $ClearZones) {
    if (@($Zone.minimum).Count -ne 2 -or @($Zone.maximum).Count -ne 2) {
        throw "Combat-clear zone '$($Zone.id)' has invalid bounds."
    }
    foreach ($Object in $SceneryManifest.objects) {
        $Position = @($Object.position)
        $BlocksTravel = $Object.walkThrough -ne $true -and $Object.walkOn -ne $true
        $Inside = $Position[0] -ge $Zone.minimum[0] -and $Position[0] -le $Zone.maximum[0] -and $Position[2] -ge $Zone.minimum[1] -and $Position[2] -le $Zone.maximum[1]
        if ($BlocksTravel -and $Inside) {
            throw "Solid scenery '$($Object.id)' intrudes into combat-clear zone '$($Zone.id)'."
        }
    }
}
if (@($SceneryManifest.objects | Where-Object { $_.id -match '(rock|boulder)' }).Count -gt 0) {
    throw "Collision-unsafe planted rocks or boulders remain in the arena scenery manifest."
}

$ExpectedSceneryCount = @($SceneryManifest.objects).Count
$ExpectedLightCount = @($SceneryManifest.lights).Count
$ActualSceneryFiles = @(Get-ChildItem -LiteralPath (Join-Path $ArenaLevelRoot "Scenery") -Filter *.lsf -File)
$ActualLightFiles = @(Get-ChildItem -LiteralPath (Join-Path $ArenaLevelRoot "Lights") -Filter *.lsf -File)
if ($ActualSceneryFiles.Count -ne 1 -or $ActualSceneryFiles[0].Name -ne "_merged.lsf") {
    throw "Arena scenery must be compiled into the engine-loaded Scenery/_merged.lsf resource."
}
if ($ActualLightFiles.Count -ne 1 -or $ActualLightFiles[0].Name -ne "_merged.lsf") {
    throw "Arena lights must be compiled into the engine-loaded Lights/_merged.lsf resource."
}
if ($GeneratedSceneryIndex.Count -ne 2) {
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
Write-Host "  Clear lanes:    $($CombatClearZones.Count) combat approaches + $($NavigationClearZones.Count) camp routes"
Write-Host "  Visual pass:    $ExpectedSceneryCount scenery objects, $ExpectedLightCount lights"
Write-Host "  Players:        1-4"
