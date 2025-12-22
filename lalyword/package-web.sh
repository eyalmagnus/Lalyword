#!/bin/bash
# Quick script to rebuild and package the web app for distribution

echo "🔨 Building Flutter web app..."
flutter build web --release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📦 Creating zip package..."
    cd build/web
    zip -r ../../lalyword-web-build.zip . -q
    cd ../..
    
    ZIP_SIZE=$(du -h lalyword-web-build.zip | cut -f1)
    echo "✅ Package created: lalyword-web-build.zip ($ZIP_SIZE)"
    echo ""
    echo "🚀 Ready to transfer! Just copy lalyword-web-build.zip to the other computer."
else
    echo "❌ Build failed. Please fix errors and try again."
    exit 1
fi

