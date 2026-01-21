# Build script for PSMonitorTools module
[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = "$PSScriptRoot\..\..\releases\PowerShell",
    
    [Parameter()]
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = 'Stop'

Write-Host "Building PSMonitorTools version $Version" -ForegroundColor Cyan

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

# Module source path
$ModulePath = "$PSScriptRoot\..\PSMonitorTools"

# Create versioned output directory
$VersionedOutputPath = Join-Path $OutputPath "PSMonitorTools\$Version"
if (Test-Path $VersionedOutputPath) {
    Remove-Item $VersionedOutputPath -Recurse -Force
}
New-Item -Path $VersionedOutputPath -ItemType Directory -Force | Out-Null

# Copy module files
Write-Host "Copying module files..." -ForegroundColor Yellow
Copy-Item "$ModulePath\*.ps*1" -Destination $VersionedOutputPath -Recurse

# Update manifest version
$ManifestPath = Join-Path $VersionedOutputPath "PSMonitorTools.psd1"
if (Test-Path $ManifestPath) {
    Write-Host "Updating module manifest version..." -ForegroundColor Yellow
    # Read manifest content and update version manually to avoid folder name conflict
    $manifestContent = Get-Content $ManifestPath -Raw
    $manifestContent = $manifestContent -replace "ModuleVersion\s*=\s*'[\d\.]+'", "ModuleVersion = '$Version'"
    Set-Content -Path $ManifestPath -Value $manifestContent -NoNewline
}

# Create zip archive
$ZipPath = Join-Path $OutputPath "PSMonitorTools-v$Version.zip"
Write-Host "Creating archive: $ZipPath" -ForegroundColor Yellow
Compress-Archive -Path "$OutputPath\PSMonitorTools" -DestinationPath $ZipPath -Force

Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "Output: $ZipPath" -ForegroundColor Green
