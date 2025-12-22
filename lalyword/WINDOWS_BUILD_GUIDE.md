# Windows Executable Build Guide

This guide explains how to create a Windows executable (.exe) for the Lalyword app.

## Important Note

**You cannot build Windows executables on macOS.** Flutter requires a Windows machine to build Windows apps. However, you have several options:

---

## Option 1: Build on a Windows Machine (Recommended)

### Prerequisites

1. **Windows 10/11** machine
2. **Flutter SDK** installed
3. **Visual Studio** with Windows desktop development workload

### Step 1: Install Flutter on Windows

1. Download Flutter SDK from https://docs.flutter.dev/get-started/install/windows
2. Extract to a location (e.g., `C:\src\flutter`)
3. Add Flutter to your PATH
4. Run `flutter doctor` to check setup

### Step 2: Install Visual Studio

1. Download Visual Studio Community (free) from https://visualstudio.microsoft.com/
2. During installation, select:
   - **Desktop development with C++** workload
   - **Windows 10/11 SDK** (latest version)

### Step 3: Enable Windows Desktop Support

```bash
flutter config --enable-windows-desktop
flutter doctor
```

### Step 4: Get Dependencies

```bash
cd lalyword
flutter pub get
```

### Step 5: Build Windows Executable

**For Release Build (Optimized):**
```bash
flutter build windows --release
```

**For Debug Build (Faster, larger file):**
```bash
flutter build windows --debug
```

### Step 6: Find Your Executable

The executable will be located at:
```
build\windows\x64\runner\Release\lalyword.exe
```

**Important:** You need to distribute the entire `Release` folder, not just the `.exe` file, as it contains required DLLs and assets.

### Step 7: Create a Portable Package

To distribute the app, copy the entire `Release` folder:
- `lalyword.exe`
- All `.dll` files
- `data` folder (contains assets)
- `flutter_windows.dll`

Users can run `lalyword.exe` directly from this folder.

---

## Option 2: Use GitHub Actions (CI/CD)

You can automate Windows builds using GitHub Actions, even from your macOS machine.

### Step 1: Create GitHub Actions Workflow

Create `.github/workflows/build-windows.yml`:

```yaml
name: Build Windows Executable

on:
  workflow_dispatch:  # Manual trigger
  push:
    tags:
      - 'v*'  # Trigger on version tags

jobs:
  build:
    runs-on: windows-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.5'
          channel: 'stable'
      
      - name: Enable Windows Desktop
        run: flutter config --enable-windows-desktop
      
      - name: Get Dependencies
        run: flutter pub get
      
      - name: Build Windows Release
        run: flutter build windows --release
      
      - name: Upload Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: windows-executable
          path: build/windows/x64/runner/Release/
          retention-days: 30
```

### Step 2: Push to GitHub and Trigger Build

1. Push your code to GitHub
2. Go to **Actions** tab
3. Click **Build Windows Executable**
4. Click **Run workflow**
5. Download the artifact when complete

---

## Option 3: Use Windows VM on macOS

You can run Windows in a VM using:
- **Parallels Desktop** (paid, best performance)
- **VMware Fusion** (paid)
- **UTM** (free, open-source)
- **VirtualBox** (free)

Then follow **Option 1** steps inside the VM.

---

## Option 4: Use Cloud Windows Instances

Services like:
- **AWS EC2** (Windows instances)
- **Azure Virtual Machines**
- **Google Cloud Compute Engine**

You can rent a Windows VM temporarily, build your app, and download the executable.

---

## Building a Single-File Executable (Advanced)

By default, Flutter creates a folder with multiple files. To create a more portable package:

### Method 1: Create Installer (Recommended)

Use tools like:
- **Inno Setup** (free, popular)
- **NSIS** (free, open-source)
- **WiX Toolset** (free, Microsoft)

These create `.exe` installers that bundle everything.

### Method 2: Create ZIP Archive

Simply zip the entire `Release` folder:
```bash
# On Windows
cd build\windows\x64\runner
Compress-Archive -Path Release\* -DestinationPath lalyword-windows.zip
```

Users extract and run `lalyword.exe`.

---

## Troubleshooting

### Error: "Windows desktop support not enabled"
```bash
flutter config --enable-windows-desktop
flutter doctor
```

### Error: "Visual Studio not found"
- Install Visual Studio with C++ workload
- Run `flutter doctor` to verify

### Error: "Missing Windows SDK"
- Install Windows 10/11 SDK from Visual Studio Installer
- Or download from Microsoft website

### App doesn't run on other Windows machines
- Make sure you distribute the entire `Release` folder
- Check that all DLLs are included
- Test on a clean Windows machine

---

## Quick Reference

**Build command:**
```bash
flutter build windows --release
```

**Output location:**
```
build/windows/x64/runner/Release/
```

**What to distribute:**
- Entire `Release` folder (recommended)
- Or create an installer using Inno Setup/NSIS

---

## Next Steps

1. Choose your build method (Windows machine, CI/CD, or VM)
2. Build the executable
3. Test on a clean Windows machine
4. Distribute the `Release` folder or create an installer
5. Consider code signing for distribution (optional but recommended)

For more information, see: https://docs.flutter.dev/deployment/windows

