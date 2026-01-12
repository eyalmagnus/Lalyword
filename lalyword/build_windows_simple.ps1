# Simple Windows build script - bypasses execution policy issues
# Usage: powershell -ExecutionPolicy Bypass -File .\build_windows_simple.ps1

Write-Host "Building Laly Windows Portable..." -ForegroundColor Cyan
Write-Host ""

# Navigate to script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Check Developer Mode
Write-Host "Checking Developer Mode..." -ForegroundColor Yellow
$devMode = $false
try {
    $userMode = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
    $sysMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
    if (($userMode -and $userMode.AllowDevelopmentWithoutDevLicense -eq 1) -or ($sysMode -and $sysMode.AllowDevelopmentWithoutDevLicense -eq 1)) {
        $devMode = $true
    }
} catch {}

if (-not $devMode) {
    Write-Host "WARNING: Developer Mode may not be enabled!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please enable Developer Mode:" -ForegroundColor Yellow
    Write-Host "1. Press Win+I" -ForegroundColor Cyan
    Write-Host "2. Go to: Privacy & Security > For developers" -ForegroundColor Cyan
    Write-Host "3. Enable 'Developer Mode'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or run: start ms-settings:developers" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Opening Settings now..." -ForegroundColor Yellow
    start ms-settings:developers
    Write-Host ""
    Write-Host "After enabling Developer Mode, run this script again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[OK] Developer Mode enabled" -ForegroundColor Green
Write-Host ""

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get dependencies!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Dependencies ready" -ForegroundColor Green
Write-Host ""

# Build
Write-Host "Building Windows release (this may take a few minutes)..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Build failed!" -ForegroundColor Red
    Write-Host "Make sure Developer Mode is enabled in Windows Settings." -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Build completed" -ForegroundColor Green
Write-Host ""

# Verify output
$buildDir = "build\windows\x64\runner\Release"
if (-not (Test-Path $buildDir)) {
    Write-Host "ERROR: Build output not found!" -ForegroundColor Red
    exit 1
}

$exePath = Join-Path $buildDir "lalyword.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: Executable not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Build location: $buildDir" -ForegroundColor Cyan
Write-Host ""

# Create ZIP
Write-Host "Creating portable ZIP package..." -ForegroundColor Yellow
$zipPath = "lalyword-windows-portable.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Compress-Archive -Path "$buildDir\*" -DestinationPath $zipPath -Force

if (Test-Path $zipPath) {
    $size = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-Host "[OK] Portable package created: $zipPath ($size MB)" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SUCCESS! Portable package ready!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "File: $zipPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To test on another PC:" -ForegroundColor Yellow
    Write-Host "1. Extract the ZIP to any folder" -ForegroundColor White
    Write-Host "2. Run lalyword.exe" -ForegroundColor White
    Write-Host "3. No installation needed!" -ForegroundColor White
} else {
    Write-Host "ERROR: Failed to create ZIP!" -ForegroundColor Red
    exit 1
}

