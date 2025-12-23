#!/bin/bash
# Quick script to rebuild and package the web app for distribution
# Ensures clean build with no stale files

set -e  # Exit on error

echo "🧹 Cleaning previous builds..."
# Clean Flutter build artifacts
flutter clean
# Remove any remaining build/web directory (in case flutter clean missed it)
rm -rf build/web
# Remove old zip file to ensure fresh package
rm -f lalyword-web-build.zip

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building Flutter web app (release mode)..."
flutter build web --release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Verify build directory exists and has content
    if [ ! -d "build/web" ]; then
        echo "❌ Error: build/web directory not found!"
        exit 1
    fi
    
    echo "📦 Creating zip package from clean build..."
    cd build/web
    # Remove any README, temp files, or hidden files that shouldn't be in the zip
    rm -f README.txt .DS_Store .last_build_id
    
    # Verify we have the expected files
    if [ ! -f "index.html" ] || [ ! -f "main.dart.js" ] || [ ! -f "flutter_bootstrap.js" ]; then
        echo "❌ Error: Required files missing from build!"
        exit 1
    fi
    
    # Create zip from current directory (build/web) - using -0 for no compression to verify contents easily
    # Remove existing zip first to ensure clean creation
    rm -f ../../lalyword-web-build.zip
    zip -r ../../lalyword-web-build.zip . -q
    
    cd ../..
    
    # Verify zip was created
    if [ ! -f "lalyword-web-build.zip" ]; then
        echo "❌ Error: Failed to create zip file!"
        exit 1
    fi
    
    ZIP_SIZE=$(du -h lalyword-web-build.zip | cut -f1)
    echo "✅ Package created: lalyword-web-build.zip ($ZIP_SIZE)"
    echo ""
    echo "🚀 Ready to transfer! Just copy lalyword-web-build.zip to the other computer."
    echo "📝 Note: This is a clean build with only the latest code."
else
    echo "❌ Build failed. Please fix errors and try again."
    exit 1
fi

