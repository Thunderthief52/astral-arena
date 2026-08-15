param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$DivinePath = (Join-Path (Split-Path -Parent $RepoRoot) 'tools\ExportTool-v1.19.5\Packed\Tools\Divine.exe')
)

$ErrorActionPreference = 'Stop'

$manifestPath = Join-Path $RepoRoot 'toolkit\scenery\AA_Arena_Main.scenery.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$levelRoot = Join-Path $RepoRoot "toolkit\Data\Mods\AstralArenaAdventure_29c48c80-8777-f7b5-6bb8-376c1c5d8db6\Levels\$($manifest.levelName)"
$sceneryRoot = Join-Path $levelRoot 'Scenery'
$lightsRoot = Join-Path $levelRoot 'Lights'
$indexPath = Join-Path $RepoRoot 'toolkit\scenery\AA_Arena_Main.generated-files.json'

if (-not (Test-Path -LiteralPath $DivinePath -PathType Leaf)) {
    throw "Divine.exe was not found at '$DivinePath'. Install LSLib or pass -DivinePath explicitly."
}

$allEntries = @($manifest.objects) + @($manifest.lights)
$duplicateIds = @($allEntries | Group-Object id | Where-Object Count -gt 1)
$duplicateNames = @($allEntries | Group-Object name | Where-Object Count -gt 1)
if ($duplicateIds.Count -gt 0) {
    throw "Scenery manifest contains duplicate id(s): $($duplicateIds.Name -join ', ')"
}
if ($duplicateNames.Count -gt 0) {
    throw "Scenery manifest contains duplicate name(s): $($duplicateNames.Name -join ', ')"
}

New-Item -ItemType Directory -Path $sceneryRoot -Force | Out-Null
New-Item -ItemType Directory -Path $lightsRoot -Force | Out-Null

function New-DeterministicGuid {
    param([Parameter(Mandatory)][string]$Name)

    $namespace = [guid]'29c48c80-8777-f7b5-6bb8-376c1c5d8db6'
    $namespaceBytes = $namespace.ToByteArray()
    $nameBytes = [Text.Encoding]::UTF8.GetBytes("AA_Arena_Main/$Name")
    $input = New-Object byte[] ($namespaceBytes.Length + $nameBytes.Length)
    [Array]::Copy($namespaceBytes, 0, $input, 0, $namespaceBytes.Length)
    [Array]::Copy($nameBytes, 0, $input, $namespaceBytes.Length, $nameBytes.Length)
    $sha1 = [Security.Cryptography.SHA1]::Create()
    try {
        $hash = $sha1.ComputeHash($input)
    }
    finally {
        $sha1.Dispose()
    }

    $bytes = New-Object byte[] 16
    [Array]::Copy($hash, $bytes, 16)
    $bytes[7] = ($bytes[7] -band 0x0f) -bor 0x50
    $bytes[8] = ($bytes[8] -band 0x3f) -bor 0x80
    return ([guid]::new($bytes)).ToString()
}

function Convert-ToInvariant {
    param([Parameter(Mandatory)]$Value)
    return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
}

function Get-YawQuaternion {
    param([double]$Degrees)
    $halfRadians = $Degrees * [Math]::PI / 360.0
    return @(
        '0',
        (Convert-ToInvariant ([Math]::Sin($halfRadians))),
        '0',
        (Convert-ToInvariant ([Math]::Cos($halfRadians)))
    ) -join ' '
}

function Add-Attribute {
    param(
        [Parameter(Mandatory)][System.Xml.XmlWriter]$Writer,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Value
    )
    $Writer.WriteStartElement('attribute')
    $Writer.WriteAttributeString('id', $Id)
    $Writer.WriteAttributeString('type', $Type)
    $Writer.WriteAttributeString('value', $Value)
    $Writer.WriteEndElement()
}

function Write-LayerList {
    param(
        [Parameter(Mandatory)][System.Xml.XmlWriter]$Writer,
        [Parameter(Mandatory)][string]$LevelName,
        [Parameter(Mandatory)][string]$LayerGuid
    )
    $Writer.WriteStartElement('node'); $Writer.WriteAttributeString('id', 'LayerList')
    $Writer.WriteStartElement('children')
    $Writer.WriteStartElement('node'); $Writer.WriteAttributeString('id', 'Layers')
    $Writer.WriteStartElement('children')
    $Writer.WriteStartElement('node'); $Writer.WriteAttributeString('id', 'Object'); $Writer.WriteAttributeString('key', 'MapKey')
    Add-Attribute $Writer 'MapKey' 'FixedString' $LevelName
    $Writer.WriteStartElement('children')
    $Writer.WriteStartElement('node'); $Writer.WriteAttributeString('id', 'Layer')
    Add-Attribute $Writer 'Object' 'guid' $LayerGuid
    $Writer.WriteEndElement()
    $Writer.WriteEndElement()
    $Writer.WriteEndElement()
    $Writer.WriteEndElement()
    $Writer.WriteEndElement()
    $Writer.WriteEndElement()
    $Writer.WriteEndElement()
}

function Write-Transform {
    param(
        [Parameter(Mandatory)][System.Xml.XmlWriter]$Writer,
        [Parameter(Mandatory)]$Position,
        [string]$Rotation = '0 0 0 1',
        [double]$Scale = 1.0
    )
    $positionValue = @($Position | ForEach-Object { Convert-ToInvariant $_ }) -join ' '
    $Writer.WriteStartElement('node'); $Writer.WriteAttributeString('id', 'Transform')
    Add-Attribute $Writer 'Scale' 'float' (Convert-ToInvariant $Scale)
    Add-Attribute $Writer 'Position' 'fvec3' $positionValue
    Add-Attribute $Writer 'RotationQuat' 'fvec4' $Rotation
    $Writer.WriteEndElement()
}

function Write-Resource {
    param(
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][scriptblock]$WriteGameObject
    )

    $tempPath = [IO.Path]::ChangeExtension($OutputPath, '.lsx')
    $settings = [Xml.XmlWriterSettings]::new()
    $settings.Indent = $true
    $settings.IndentChars = "`t"
    $settings.Encoding = [Text.UTF8Encoding]::new($false)
    $writer = [Xml.XmlWriter]::Create($tempPath, $settings)
    try {
        $writer.WriteStartDocument()
        $writer.WriteStartElement('save')
        $writer.WriteStartElement('version')
        $writer.WriteAttributeString('major', '4')
        $writer.WriteAttributeString('minor', '8')
        $writer.WriteAttributeString('revision', '0')
        $writer.WriteAttributeString('build', '500')
        $writer.WriteAttributeString('lslib_meta', 'v1,bswap_guids,lsf_keys_adjacency')
        $writer.WriteEndElement()
        $writer.WriteStartElement('region'); $writer.WriteAttributeString('id', 'Templates')
        $writer.WriteStartElement('node'); $writer.WriteAttributeString('id', 'Templates')
        $writer.WriteStartElement('children')
        $writer.WriteStartElement('node'); $writer.WriteAttributeString('id', 'GameObjects')
        & $WriteGameObject $writer
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndElement()
        $writer.WriteEndDocument()
    }
    finally {
        $writer.Dispose()
    }

    $divineOutput = & $DivinePath -g bg3 -a convert-resource -s $tempPath -d $OutputPath -i lsx -o lsf 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Divine failed to build '$OutputPath': $($divineOutput -join [Environment]::NewLine)"
    }
    Remove-Item -LiteralPath $tempPath
}

$generated = New-Object Collections.Generic.List[string]

foreach ($object in $manifest.objects) {
    $mapKey = New-DeterministicGuid "scenery/$($object.id)"
    $outputPath = Join-Path $sceneryRoot "$mapKey.lsf"
    Write-Resource $outputPath {
        param($writer)
        Add-Attribute $writer 'MapKey' 'FixedString' $mapKey
        Add-Attribute $writer 'Name' 'LSString' ([string]$object.name)
        Add-Attribute $writer 'LevelName' 'FixedString' ([string]$manifest.levelName)
        Add-Attribute $writer 'Type' 'FixedString' 'scenery'
        Add-Attribute $writer 'TemplateName' 'FixedString' ([string]$object.template)
        Add-Attribute $writer 'Flag' 'uint8' '1'
        Add-Attribute $writer 'CanClickThrough' 'bool' 'True'
        if ($null -ne $object.cover) { Add-Attribute $writer 'CoverAmount' 'uint8' ([string]$object.cover) }
        if ($object.walkOn -eq $true) { Add-Attribute $writer 'WalkOn' 'bool' 'True' }
        if ($object.walkThrough -eq $true) { Add-Attribute $writer 'WalkThrough' 'bool' 'True' }
        if ($object.decorative -eq $true) { Add-Attribute $writer 'IsDecorative' 'bool' 'True' }
        Add-Attribute $writer '_OriginalFileVersion_' 'int64' '144115207403209026'
        $writer.WriteStartElement('children')
        Write-Transform $writer $object.position (Get-YawQuaternion ([double]$object.yaw)) ([double]$object.scale)
        Write-LayerList $writer ([string]$manifest.levelName) ([string]$manifest.sceneryLayer)
        $writer.WriteEndElement()
    }
    $generated.Add((Resolve-Path -LiteralPath $outputPath).Path.Substring($RepoRoot.Length + 1))
}

$pointLightTemplate = 'ae8105f5-0490-4d85-9ef7-b6beeedea3a3'
foreach ($light in $manifest.lights) {
    $mapKey = New-DeterministicGuid "light/$($light.id)"
    $outputPath = Join-Path $lightsRoot "$mapKey.lsf"
    Write-Resource $outputPath {
        param($writer)
        Add-Attribute $writer 'Enabled' 'bool' 'True'
        Add-Attribute $writer 'Flag' 'int32' '1'
        Add-Attribute $writer 'Color' 'fvec3' (@($light.color | ForEach-Object { Convert-ToInvariant $_ }) -join ' ')
        Add-Attribute $writer 'Gain' 'float' (Convert-ToInvariant $light.gain)
        Add-Attribute $writer 'Intensity' 'float' (Convert-ToInvariant $light.intensity)
        Add-Attribute $writer 'Radius' 'float' (Convert-ToInvariant $light.radius)
        Add-Attribute $writer 'ScatteringScale' 'float' (Convert-ToInvariant $light.scattering)
        Add-Attribute $writer 'LevelName' 'FixedString' ([string]$manifest.levelName)
        Add-Attribute $writer 'MapKey' 'FixedString' $mapKey
        Add-Attribute $writer 'Name' 'LSString' ([string]$light.name)
        Add-Attribute $writer 'TemplateName' 'FixedString' $pointLightTemplate
        Add-Attribute $writer 'Type' 'FixedString' 'light'
        Add-Attribute $writer '_OriginalFileVersion_' 'int64' '144115207403209014'
        $writer.WriteStartElement('children')
        Write-LayerList $writer ([string]$manifest.levelName) ([string]$manifest.lightingLayer)
        Write-Transform $writer $light.position '0 0 0 1' 1.0
        $writer.WriteEndElement()
    }
    $generated.Add((Resolve-Path -LiteralPath $outputPath).Path.Substring($RepoRoot.Length + 1))
}

$previous = [string[]]@()
if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
    $previous = [string[]](Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json)
}
$current = @($generated | Sort-Object)
foreach ($relativePath in $previous) {
    if ($relativePath -notin $current) {
        $candidate = Join-Path $RepoRoot $relativePath
        $resolvedParent = (Resolve-Path -LiteralPath (Split-Path -Parent $candidate)).Path
        if ($resolvedParent -in @((Resolve-Path $sceneryRoot).Path, (Resolve-Path $lightsRoot).Path) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            Remove-Item -LiteralPath $candidate
        }
    }
}

ConvertTo-Json -InputObject $current | Set-Content -LiteralPath $indexPath -Encoding utf8
Write-Host "Built $($manifest.objects.Count) scenery object(s) and $($manifest.lights.Count) light(s) for $($manifest.levelName)."
