# Shared by Windows build tools. Keep the stamp format aligned with navgrid.py.
function Get-ArenaManifestHash {
    param([Parameter(Mandatory)][string]$Path)
    $Text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $Sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($Sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant() }
    finally { $Sha.Dispose() }
}

function Get-ArenaSceneryFingerprint {
    param([Parameter(Mandatory)]$Manifest)
    $ById = @{}
    foreach ($Object in $Manifest.objects) {
        if ($Object.walkThrough -eq $true) { continue }
        if ($ById.ContainsKey([string]$Object.id)) { throw "Duplicate scenery id: $($Object.id)" }
        $ById[[string]$Object.id] = $Object
    }
    [string[]]$Ids = @($ById.Keys)
    [Array]::Sort($Ids, [StringComparer]::Ordinal)
    $Rows = @(
        foreach ($Id in $Ids) {
            $Object = $ById[$Id]
            $Numbers = @($Object.position) + @($(if ($null -eq $Object.yaw) { 0 } else { $Object.yaw }), $(if ($null -eq $Object.scale) { 1 } else { $Object.scale }))
            $Fixed = @($Numbers | ForEach-Object {
                $Rounded = [Math]::Round([double]$_, 3)
                if ($Rounded -eq 0) { $Rounded = 0.0 }
                $Rounded.ToString('F3', [Globalization.CultureInfo]::InvariantCulture)
            })
            ,@($Id, [string]$Object.template, @($Fixed[0..2]), $Fixed[3], $Fixed[4], ($Object.walkOn -eq $true), ($Object.decorative -eq $true), $(if ($null -eq $Object.cover) { 0 } else { $Object.cover }))
        }
    )
    $Json = ConvertTo-Json -InputObject $Rows -Depth 8 -Compress
    $Sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($Sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Json)))).Replace('-', '').ToLowerInvariant() }
    finally { $Sha.Dispose() }
}

function Assert-ArenaNavigation {
    param([Parameter(Mandatory)][string]$RepositoryRoot)
    $Manifest = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'toolkit\scenery\AA_Arena_Main.scenery.json') -Raw | ConvertFrom-Json
    $RecordPath = Join-Path $RepositoryRoot 'toolkit\scenery\AA_Arena_Main.navgrid.json'
    $Help = 'Rebuild navigation in the Toolkit, save it, then run tools/scenery/record_navgrid.py. For editor authoring use Build-ArenaScenery.ps1 -EditorOnly -EditorOutputPath <directory>.'
    if (-not (Test-Path -LiteralPath $RecordPath -PathType Leaf)) { throw "No navigation record. $Help" }
    $Record = Get-Content -LiteralPath $RecordPath -Raw | ConvertFrom-Json
    if ($Record.formatVersion -ne 2) { throw "Navigation record needs terrain-file verification. $Help" }
    if ($Record.sceneryFingerprint -ne (Get-ArenaSceneryFingerprint $Manifest)) { throw "Scenery changed after navigation generation. $Help" }
    $Level = Join-Path $RepositoryRoot 'toolkit\Data\Mods\AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6\Levels\AA_Arena_Main'
    $Files = @{}
    foreach ($Folder in @('Terrains', 'TileConstructions')) {
        foreach ($File in Get-ChildItem -LiteralPath (Join-Path $Level $Folder) -File -Recurse) {
            $Relative = $File.FullName.Substring($Level.Length + 1).Replace('\', '/')
            $Files[$Relative] = (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    $RecordedFiles = @($Record.terrainFiles.PSObject.Properties)
    if ($Files.Count -ne $RecordedFiles.Count) { throw "Terrain file inventory changed. $Help" }
    foreach ($File in $RecordedFiles) {
        if ($Files[$File.Name] -ne $File.Value) { throw "Terrain changed: $($File.Name). $Help" }
    }
    $Grid = Join-Path $Level 'Ai\aigrid.data'
    if (-not (Test-Path -LiteralPath $Grid -PathType Leaf)) { throw "Navigation grid is missing. $Help" }
    if ((Get-FileHash -LiteralPath $Grid -Algorithm SHA256).Hash -ne $Record.aigridSha256) { throw "Navigation grid differs from the recorded Toolkit output. $Help" }
}
