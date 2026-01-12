# Script to enable Developer Mode for Flutter Windows builds
# Run this script as Administrator

Write-Host "Enabling Developer Mode for Flutter Windows builds..." -ForegroundColor Yellow
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternatively, you can enable Developer Mode manually:" -ForegroundColor Yellow
    Write-Host "1. Press Win+I to open Settings" -ForegroundColor Cyan
    Write-Host "2. Go to Privacy & Security > For developers" -ForegroundColor Cyan
    Write-Host "3. Enable 'Developer Mode'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Opening Settings now..." -ForegroundColor Yellow
    start ms-settings:developers
    exit 1
}

# Enable Developer Mode via registry
Write-Host "Setting registry keys..." -ForegroundColor Cyan

# System-level setting
try {
    $null = New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord -Force
    Write-Host "✓ System-level Developer Mode enabled" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to set system-level registry: $_" -ForegroundColor Red
}

# User-level setting
try {
    $null = New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord -Force
    Write-Host "✓ User-level Developer Mode enabled" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to set user-level registry: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Developer Mode should now be enabled!" -ForegroundColor Green
Write-Host "You may need to restart your terminal or log out and back in for changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "After enabling, you can build with:" -ForegroundColor Cyan
Write-Host "  flutter build windows --release" -ForegroundColor White

