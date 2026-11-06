param([string]$RepositoryRoot, [string]$ExpectedFingerprint)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\lib\ArenaNavigation.ps1')
Assert-ArenaNavigation -RepositoryRoot $RepositoryRoot
$ManifestPath = Join-Path $RepositoryRoot 'toolkit\scenery\AA_Arena_Main.scenery.json'
$Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
if ((Get-ArenaSceneryFingerprint $Manifest) -ne $ExpectedFingerprint) { throw 'PowerShell and Python fingerprints differ' }
function Expect-Rejection {
    param([string]$Message)
    $Rejected = $false
    try { Assert-ArenaNavigation -RepositoryRoot $RepositoryRoot }
    catch {
        if ($_.Exception.Message -notlike "*$Message*") { throw }
        $Rejected = $true
    }
    if (-not $Rejected) { throw "Expected rejection for $Message" }
}
$Original = [IO.File]::ReadAllBytes($ManifestPath)
try {
    $Manifest.objects[0].position[1] = 2.7
    $Manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ManifestPath -Encoding utf8
    Expect-Rejection 'Scenery changed'
} finally { [IO.File]::WriteAllBytes($ManifestPath, $Original) }
$Level = Join-Path $RepositoryRoot 'toolkit\Data\Mods\AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6\Levels\AA_Arena_Main'
foreach ($Case in @(@('Terrains\ground.data', 'Terrain changed'), @('Ai\aigrid.data', 'Navigation grid differs'))) {
    $Path = Join-Path $Level $Case[0]
    $Original = [IO.File]::ReadAllBytes($Path)
    try {
        [IO.File]::WriteAllText($Path, 'changed')
        Expect-Rejection $Case[1]
    } finally { [IO.File]::WriteAllBytes($Path, $Original) }
}
Assert-ArenaNavigation -RepositoryRoot $RepositoryRoot
Write-Output 'Windows navigation guard regression checks passed'
