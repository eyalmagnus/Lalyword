# Check if Developer Mode is properly enabled for Flutter builds
# Run: powershell -ExecutionPolicy Bypass -File .\check_developer_mode.ps1

Write-Host "Checking Developer Mode status..." -ForegroundColor Cyan
Write-Host ""

# Check registry
$userReg = $null
$sysReg = $null
try {
    $userReg = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
} catch {}
try {
    $sysReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
} catch {}

Write-Host "Registry Status:" -ForegroundColor Yellow
if ($userReg -and $userReg.AllowDevelopmentWithoutDevLicense -eq 1) {
    Write-Host "  [OK] User-level registry: Enabled" -ForegroundColor Green
} else {
    Write-Host "  [X] User-level registry: Not set" -ForegroundColor Red
}

if ($sysReg -and $sysReg.AllowDevelopmentWithoutDevLicense -eq 1) {
    Write-Host "  [OK] System-level registry: Enabled" -ForegroundColor Green
} else {
    Write-Host "  [X] System-level registry: Not set (requires admin)" -ForegroundColor Yellow
}

Write-Host ""

# Test actual symlink capability
Write-Host "Testing symlink support..." -ForegroundColor Yellow
$testDir = Join-Path $env:TEMP "flutter_symlink_test_$(Get-Random)"
$testFile = Join-Path $testDir "target.txt"
$testLink = Join-Path $testDir "link.txt"

try {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    "test" | Out-File -FilePath $testFile -Encoding ASCII
    
    $link = New-Item -ItemType SymbolicLink -Path $testLink -Target $testFile -ErrorAction Stop
    Write-Host "  [OK] Symlinks are working!" -ForegroundColor Green
    $symlinksWork = $true
    Remove-Item $testLink -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host "  [X] Symlinks are NOT working" -ForegroundColor Red
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
    $symlinksWork = $false
} finally {
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""

# Summary
if ($symlinksWork) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Developer Mode is ENABLED" -ForegroundColor Green
    Write-Host "You can proceed with the build!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run: powershell -ExecutionPolicy Bypass -File .\build_windows_simple.ps1" -ForegroundColor Cyan
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Developer Mode is NOT properly enabled" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "To enable Developer Mode:" -ForegroundColor Yellow
    Write-Host "1. Press Win+I to open Windows Settings" -ForegroundColor Cyan
    Write-Host "2. Go to: Privacy & Security > For developers" -ForegroundColor Cyan
    Write-Host "3. Toggle 'Developer Mode' to ON" -ForegroundColor Cyan
    Write-Host "4. Accept any prompts" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Opening Settings now..." -ForegroundColor Yellow
    start ms-settings:developers
    Write-Host ""
    Write-Host "After enabling, run this script again to verify." -ForegroundColor Yellow
}

