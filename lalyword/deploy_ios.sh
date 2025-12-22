#!/bin/bash

# iOS Deployment Script for Lalyword
# This script helps automate the iOS deployment process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Lalyword iOS Deployment Script${NC}"
echo "=================================="
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: pubspec.yaml not found. Please run this script from the lalyword directory.${NC}"
    exit 1
fi

# Navigate to project root
cd "$(dirname "$0")"

echo -e "${YELLOW}📦 Step 1: Cleaning previous builds...${NC}"
flutter clean

echo -e "${YELLOW}📥 Step 2: Getting dependencies...${NC}"
flutter pub get

echo -e "${YELLOW}🔍 Step 3: Running Flutter doctor...${NC}"
flutter doctor

echo ""
echo -e "${YELLOW}🔐 Step 3.5: Checking code signing certificates...${NC}"
if security find-identity -v -p codesigning | grep -q "iPhone Distribution\|iPhone Developer"; then
    echo -e "${GREEN}✅ Code signing certificates found${NC}"
    security find-identity -v -p codesigning | grep "iPhone Distribution\|iPhone Developer" | head -3
else
    echo -e "${YELLOW}⚠️  No code signing certificates found${NC}"
    echo "You may need to:"
    echo "1. Open Xcode → Settings → Accounts"
    echo "2. Add your Apple ID and download certificates"
    echo "3. Or create certificates in Apple Developer Portal"
fi

echo ""
echo -e "${YELLOW}📱 Step 4: Building iOS release...${NC}"
echo "Choose deployment method:"
echo "1) Build IPA for TestFlight/App Store"
echo "2) Build IPA for Ad-hoc distribution"
echo "3) Build and open in Xcode (for manual archive)"
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo -e "${GREEN}Building IPA for App Store/TestFlight...${NC}"
        flutter build ipa --release
        echo ""
        echo -e "${GREEN}✅ Build complete!${NC}"
        echo -e "IPA location: ${GREEN}build/ios/ipa/lalyword.ipa${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Open Xcode: open ios/Runner.xcworkspace"
        echo "2. Product → Archive"
        echo "3. Distribute App → App Store Connect"
        echo "4. Or upload manually using xcrun altool"
        ;;
    2)
        echo -e "${GREEN}Building IPA for Ad-hoc distribution...${NC}"
        flutter build ipa --release --export-method ad-hoc
        echo ""
        echo -e "${GREEN}✅ Build complete!${NC}"
        echo -e "IPA location: ${GREEN}build/ios/ipa/lalyword.ipa${NC}"
        echo ""
        echo "⚠️  Make sure you have:"
        echo "1. Registered all device UDIDs in Apple Developer Portal"
        echo "2. Created an Ad-hoc provisioning profile"
        echo "3. Selected the profile in Xcode"
        echo ""
        echo "Share the IPA file with your friends for installation."
        ;;
    3)
        echo -e "${GREEN}Building and opening in Xcode...${NC}"
        flutter build ios --release --no-codesign
        echo ""
        echo -e "${GREEN}✅ Opening Xcode...${NC}"
        open ios/Runner.xcworkspace
        echo ""
        echo "In Xcode:"
        echo "1. Select your development team in Signing & Capabilities"
        echo "2. Product → Archive"
        echo "3. Distribute App"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✨ Deployment preparation complete!${NC}"
echo ""
echo "For detailed instructions, see DEPLOYMENT_GUIDE.md"

