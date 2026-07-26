[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$Bg3DataPath
)

$ErrorActionPreference = "Stop"
$ResolvedDataPath = (Resolve-Path $Bg3DataPath).Path
$GameRoot = Split-Path -Parent $ResolvedDataPath
$BinPath = Join-Path $GameRoot "bin"
$SettingsPath = Join-Path $BinPath "ScriptExtenderSettings.json"

if (-not (Test-Path (Join-Path $BinPath "bg3.exe") -PathType Leaf)) {
    throw "The selected Data folder does not appear to belong to BG3: $ResolvedDataPath"
}

if (Test-Path $SettingsPath -PathType Leaf) {
    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item $SettingsPath "$SettingsPath.$Timestamp.backup" -Force
    $Settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
} else {
    $Settings = New-Object PSObject
}

foreach ($Pair in @(
    @{ Name = "CreateConsole"; Value = $true },
    @{ Name = "EnableLogging"; Value = $true },
    @{ Name = "LogRuntime"; Value = $true }
)) {
    if ($Settings.PSObject.Properties.Name -contains $Pair.Name) {
        $Settings.($Pair.Name) = $Pair.Value
    } else {
        $Settings | Add-Member -NotePropertyName $Pair.Name -NotePropertyValue $Pair.Value
    }
}

$Settings | ConvertTo-Json -Depth 20 | Set-Content -Path $SettingsPath -Encoding UTF8
Write-Host "Enabled the Script Extender console and runtime logging in: $SettingsPath" -ForegroundColor Green
Write-Host "Any previous settings file was preserved beside it with a timestamped .backup suffix."
