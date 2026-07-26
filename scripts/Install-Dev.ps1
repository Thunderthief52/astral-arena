[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$Bg3DataPath
)

$ErrorActionPreference = "Stop"

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $RepositoryRoot "src\Mods\AstralArena"
$ModsDirectory = Join-Path $Bg3DataPath "Mods"
$Destination = Join-Path $ModsDirectory "AstralArena"

if (-not (Test-Path $Source -PathType Container)) {
    throw "Astral Arena source directory was not found: $Source"
}

New-Item -ItemType Directory -Force -Path $ModsDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $Destination | Out-Null

Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Recurse -Force

Write-Host "Installed unpacked Astral Arena mod to: $Destination"
Write-Host "Launch BG3 with Script Extender and use !aa_demo in the server console."

