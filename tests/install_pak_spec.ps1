$ErrorActionPreference = 'Stop'
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$Build = Join-Path $RepositoryRoot 'build'
$Fixture = Join-Path $Build ('install-test-' + [guid]::NewGuid().ToString())
$Module = 'AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6'
$Game = Join-Path $Fixture 'Game'
$Local = Join-Path $Fixture 'Local'
$Pak = Join-Path $Fixture 'AstralArena-9.9.9-alpha.1.pak'
try {
    foreach ($Folder in @('bin', "Data\Mods\$Module", "Data\Public\$Module")) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Game $Folder) | Out-Null
    }
    [IO.File]::WriteAllText((Join-Path $Game 'bin\bg3.exe'), 'fixture executable marker')
    [IO.File]::WriteAllText((Join-Path $Game "Data\Mods\$Module\old.lua"), 'old loose runtime')
    [IO.File]::WriteAllText((Join-Path $Game "Data\Public\$Module\old.txt"), 'old loose stats')
    [IO.File]::WriteAllText($Pak, 'fixture package payload')
    & (Join-Path $RepositoryRoot 'scripts\Install-Pak.ps1') -PakPath $Pak -LocalAppDataPath $Local -Bg3DataPath (Join-Path $Game 'Data')
    foreach ($Kind in @('Mods','Public')) {
        if (Test-Path -LiteralPath (Join-Path $Game "Data\$Kind\$Module")) { throw "Loose $Kind still shadows the package" }
        $BackedUp = @(Get-ChildItem -LiteralPath (Join-Path $Local 'AstralArena\PakBackups') -File -Recurse | Where-Object FullName -Like "*\LooseData\$Kind\$Module\*")
        if ($BackedUp.Count -ne 1) { throw "Loose $Kind backup was not preserved" }
    }
    $Installed = Join-Path $Local "Larian Studios\Baldur's Gate 3\Mods\$Module.pak"
    if ((Get-FileHash -LiteralPath $Installed).Hash -ne (Get-FileHash -LiteralPath $Pak).Hash) { throw 'Installed checksum mismatch' }
    $Probe = Join-Path $Fixture 'AstralArena-9.9.9-alpha.1-terrain-probe.pak'
    [IO.File]::WriteAllText($Probe,'probe fixture')
    $Rejected=$false
    try { & (Join-Path $RepositoryRoot 'scripts\Install-Pak.ps1') -PakPath $Probe -LocalAppDataPath $Local -Bg3DataPath (Join-Path $Game 'Data') }
    catch { if ($_.Exception.Message -notlike '*Only normal versioned release*') { throw }; $Rejected=$true }
    if (-not $Rejected) { throw 'A probe package was accepted' }
    Write-Output 'Installer regression passed: both loose trees backed up, verified package installed, probe rejected.'
} finally {
    if (Test-Path -LiteralPath $Fixture) {
        $Resolved = (Resolve-Path -LiteralPath $Fixture).Path
        if (-not $Resolved.StartsWith([IO.Path]::GetFullPath($Build) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing cleanup outside the build fixture: $Resolved"
        }
        Remove-Item -LiteralPath $Resolved -Recurse -Force
    }
}
