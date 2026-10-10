param(
    [string]$Version = "1.0.0.0",
    [string]$SourceDir = "build\windows\x64\runner\Release",
    [string]$OutputDir = "build\release",
    [string]$IconPath = "windows\runner\resources\app_icon.ico"
)

$ErrorActionPreference = "Stop"

# Detectar y configurar ruta de WiX Toolset
$wixCandidates = @(
    "C:\Program Files (x86)\WiX Toolset v3.11\bin",
    "C:\Program Files\WiX Toolset v3.11\bin"
)

foreach ($cand in $wixCandidates) {
    if (Test-Path $cand) {
        $env:PATH = "$cand;$env:PATH"
        break
    }
}

if (-not (Get-Command "candle.exe" -ErrorAction SilentlyContinue)) {
    Write-Error "WiX Toolset (candle.exe / light.exe) no está disponible en PATH."
    exit 1
}

# Normalizar versión para formato MSI (X.Y.Z.B con enteros)
$cleanTag = $Version -replace "^v", ""
$parts = $cleanTag -split "[-.]"
$major = if ($parts.Length -gt 0 -and $parts[0] -match '^\d+$') { [int]$parts[0] } else { 1 }
$minor = if ($parts.Length -gt 1 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 0 }
$build = if ($parts.Length -gt 2 -and $parts[2] -match '^\d+$') { [int]$parts[2] } else { 0 }
$rev   = if ($parts.Length -gt 3 -and $parts[3] -match '^\d+$') { [int]$parts[3] } else { 0 }
$msiVersion = "$major.$minor.$build.$rev"

Write-Host "📦 Generando instalador nativo MSI para HakkinLauncher v$msiVersion..."

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$stagingDir = "$OutputDir\msi_staging"
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

$wxsFile = "windows\installer\HakkinLauncher.wxs"
$harvestedWxs = "$stagingDir\AppFiles.wxs"
$harvestedObj = "$stagingDir\AppFiles.wixobj"
$mainObj = "$stagingDir\HakkinLauncher.wixobj"
$outputMsi = "$OutputDir\HakkinLauncher-windows-x64.msi"

# 1. Cosechar directorio de release de Flutter usando heat.exe
heat.exe dir $SourceDir -cg AppFiles -dr INSTALLFOLDER -scom -sfrag -srd -var "var.SourceDir" -out $harvestedWxs

# 2. Compilar objetos WiX usando candle.exe
candle.exe -dProductVersion="$msiVersion" -dSourceDir="$SourceDir" -dIconPath="$IconPath" $wxsFile -out $mainObj
candle.exe -dProductVersion="$msiVersion" -dSourceDir="$SourceDir" $harvestedWxs -out $harvestedObj

# 3. Enlazar instalador MSI usando light.exe
light.exe -ext WixUIExtension -sval $mainObj $harvestedObj -out $outputMsi

if (Test-Path $outputMsi) {
} else {
    exit 1
}

Remove-Item -Recurse -Force $stagingDir -ErrorAction SilentlyContinue
