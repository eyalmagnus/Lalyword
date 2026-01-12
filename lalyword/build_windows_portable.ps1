# Build script for Windows portable installation
# This script builds the Laly app for Windows and creates a portable ZIP package

param(
    [switch]$SkipDeveloperModeCheck = $false
)

# Set execution policy for this process to allow script execution
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Laly Windows Portable Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Developer Mode is enabled
if (-not $SkipDeveloperModeCheck) {
    Write-Host "Checking Developer Mode status..." -ForegroundColor Yellow
    
    $devModeEnabled = $false
    try {
        $regValue = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
        if ($regValue -and $regValue.AllowDevelopmentWithoutDevLicense -eq 1) {
            $devModeEnabled = $true
        }
    } catch {
        # Registry key doesn't exist
    }
    
    if (-not $devModeEnabled) {
        Write-Host "WARNING: Developer Mode may not be enabled!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Flutter requires Developer Mode for Windows builds with plugins." -ForegroundColor Yellow
        Write-Host "To enable Developer Mode:" -ForegroundColor Yellow
        Write-Host "1. Press Win+I to open Settings" -ForegroundColor Cyan
        Write-Host "2. Go to Privacy & Security > For developers" -ForegroundColor Cyan
        Write-Host "3. Enable 'Developer Mode'" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Or run: .\enable_developer_mode.ps1 (as Administrator)" -ForegroundColor Cyan
        Write-Host ""
        $response = Read-Host "Continue anyway? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            Write-Host "Build cancelled." -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "[OK] Developer Mode appears to be enabled" -ForegroundColor Green
    }
    Write-Host ""
}

# Navigate to project directory
$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

Write-Host "Project directory: $projectDir" -ForegroundColor Cyan
Write-Host ""

# Step 1: Get dependencies
Write-Host "Step 1: Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get dependencies!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Dependencies installed" -ForegroundColor Green
Write-Host ""

# Step 2: Build Windows release
Write-Host "Step 2: Building Windows release..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed!" -ForegroundColor Red
    Write-Host "Make sure Developer Mode is enabled in Windows Settings." -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Build completed successfully" -ForegroundColor Green
Write-Host ""

# Step 3: Verify build output
$buildOutput = Join-Path $projectDir "build\windows\x64\runner\Release"
if (-not (Test-Path $buildOutput)) {
    Write-Host "ERROR: Build output directory not found: $buildOutput" -ForegroundColor Red
    exit 1
}

$exePath = Join-Path $buildOutput "lalyword.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: Executable not found: $exePath" -ForegroundColor Red
    exit 1
}

Write-Host "Build output location: $buildOutput" -ForegroundColor Cyan
Write-Host ""

# Step 4: Create portable ZIP package
Write-Host "Step 3: Creating portable ZIP package..." -ForegroundColor Yellow

$zipName = "lalyword-windows-portable.zip"
$zipPath = Join-Path $projectDir $zipName

# Remove existing ZIP if it exists
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
    Write-Host "Removed existing ZIP file" -ForegroundColor Yellow
}

# Create ZIP archive
Compress-Archive -Path "$buildOutput\*" -DestinationPath $zipPath -Force

if (-not (Test-Path $zipPath)) {
    Write-Host "ERROR: Failed to create ZIP archive!" -ForegroundColor Red
    exit 1
}

$zipSize = (Get-Item $zipPath).Length / 1MB
Write-Host "[OK] Portable package created: $zipName ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green
Write-Host ""

# Step 5: Display summary
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build Summary" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Portable package: $zipPath" -ForegroundColor Cyan
Write-Host "Build directory:  $buildOutput" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test on another PC:" -ForegroundColor Yellow
Write-Host "1. Extract the ZIP file to any folder" -ForegroundColor White
Write-Host "2. Run lalyword.exe from the extracted folder" -ForegroundColor White
Write-Host "3. No installation or SDK required!" -ForegroundColor White
Write-Host ""
Write-Host "Build completed successfully! [OK]" -ForegroundColor Green

