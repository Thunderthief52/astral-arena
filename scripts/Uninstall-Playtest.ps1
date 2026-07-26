[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$Bg3DataPath
)

$ErrorActionPreference = "Stop"
$ModuleUuid = "3b7d59a3-a846-4ecd-9c5d-a7bfe3f1b84f"
$Destination = Join-Path (Resolve-Path $Bg3DataPath).Path "Mods\AstralArena"
$Meta = Join-Path $Destination "meta.lsx"

if (-not (Test-Path $Destination -PathType Container)) {
    Write-Host "Astral Arena is not installed at: $Destination"
    exit 0
}
if (-not ((Test-Path $Meta -PathType Leaf) -and (Select-String -Path $Meta -SimpleMatch $ModuleUuid -Quiet))) {
    throw "Refusing to remove an unexpected folder: $Destination"
}

if ($PSCmdlet.ShouldProcess($Destination, "Remove Astral Arena playtest files")) {
    Remove-Item -Path $Destination -Recurse -Force
    Write-Host "Removed Astral Arena from: $Destination"
    Write-Host "Open BG3 Mod Manager and remove Astral Arena from the active load order if it remains listed."
    Write-Host "Installer backups, if any, remain under %LOCALAPPDATA%\AstralArena\Backups."
}
