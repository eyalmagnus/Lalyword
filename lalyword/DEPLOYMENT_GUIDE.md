# iOS Deployment Guide for Friends

This guide will help you deploy your Lalyword app to your friends' iPhones using TestFlight (recommended) or Ad-hoc distribution.

## Prerequisites

1. **Apple Developer Account** ($99/year)
   - Sign up at https://developer.apple.com/programs/
   - You need this for both TestFlight and Ad-hoc distribution

2. **Xcode** (latest version recommended)
   - Download from Mac App Store
   - Make sure Command Line Tools are installed

3. **Flutter** (already installed)
   - Verify: `flutter doctor`

## Method 1: TestFlight (Recommended - Easiest for Friends)

TestFlight allows you to distribute your app to up to 10,000 testers without needing their device UDIDs.

### Step 1: Prepare Your App

1. **Update version number** (if needed):
   ```bash
   # Edit pubspec.yaml to increment version
   # Current: version: 1.0.0+1
   # Example: version: 1.0.1+2
   ```

2. **Clean and get dependencies**:
   ```bash
   cd lalyword
   flutter clean
   flutter pub get
   ```

3. **Build iOS release**:
   ```bash
   flutter build ipa --release
   ```
   This creates: `build/ios/ipa/lalyword.ipa`

### Step 2: Upload to App Store Connect

**Option A: Using Xcode (Easiest)**

1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode:
   - Select **Product → Archive**
   - Wait for archive to complete
   - In Organizer window, click **Distribute App**
   - Choose **App Store Connect**
   - Follow the wizard to upload

**Option B: Using Command Line**

1. Archive the app:
   ```bash
   flutter build ipa --release
   ```

2. Upload using `xcrun altool` or `xcrun notarytool`:
   ```bash
   xcrun altool --upload-app --type ios --file build/ios/ipa/lalyword.ipa \
     --username YOUR_APPLE_ID --password YOUR_APP_SPECIFIC_PASSWORD
   ```

### Step 3: Set Up TestFlight

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **My Apps** → **Lalyword** (create app if needed)
3. Go to **TestFlight** tab
4. Wait for processing (can take 10-30 minutes)
5. Add testers:
   - **Internal Testing**: Add up to 100 team members
   - **External Testing**: Add up to 10,000 testers via email or public link

### Step 4: Invite Friends

1. **Internal Testers**:
   - Add their Apple ID emails in App Store Connect
   - They'll receive an email invitation
   - They need to install TestFlight app from App Store

2. **External Testers**:
   - Create a public link (no email needed)
   - Share the link with friends
   - They install TestFlight and use the link

## Method 2: Ad-hoc Distribution (Alternative)

Use this if you don't have an Apple Developer account or want to distribute directly.

### Requirements:
- Apple Developer Account ($99/year)
- UDID of each friend's iPhone (up to 100 devices per year)

### Step 1: Get Friends' UDIDs

Ask each friend to:
1. Connect iPhone to Mac/PC
2. Open iTunes/Finder
3. Click on device → find UDID (serial number)
4. Or use: Settings → General → About → find Identifier

### Step 2: Register Devices

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Go to **Devices** → **+** → Add each UDID

### Step 3: Create Ad-hoc Provisioning Profile

1. In Developer Portal:
   - Go to **Profiles** → **+**
   - Select **Ad Hoc**
   - Choose your App ID (`com.example.lalyword`)
   - Select certificates
   - Select all registered devices
   - Download profile

2. Install profile:
   - Double-click downloaded `.mobileprovision` file
   - Or drag to Xcode

### Step 4: Build Ad-hoc IPA

1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode:
   - Select **Runner** target
   - Go to **Signing & Capabilities**
   - Select your Ad-hoc provisioning profile
   - Change scheme to **Release**

3. Build:
   ```bash
   flutter build ipa --release
   ```

### Step 5: Distribute

1. Share the `.ipa` file:
   - Located at: `build/ios/ipa/lalyword.ipa`
   - Upload to cloud storage (Dropbox, Google Drive, etc.)

2. Friends install via:
   - **macOS**: Use Apple Configurator 2
   - **Windows**: Use 3uTools or similar
   - **Direct**: They need to trust your developer certificate on their device

## Quick Deployment Script

Run the provided `deploy_ios.sh` script for automated deployment.

## Troubleshooting

### Common Issues:

1. **"No valid code signing certificate"**
   - Solution: Create certificate in Apple Developer Portal
   - Xcode can auto-generate: Xcode → Preferences → Accounts → Download Manual Profiles

2. **"Bundle identifier already exists"**
   - Solution: Change bundle ID in `ios/Runner.xcodeproj/project.pbxproj`
   - Or use your own domain: `com.yourname.lalyword`

3. **"Provisioning profile doesn't match"**
   - Solution: Ensure bundle ID matches in Xcode and Developer Portal

4. **Friends can't install**
   - TestFlight: Make sure they have TestFlight app installed
   - Ad-hoc: They need to trust developer certificate in Settings → General → VPN & Device Management

## Next Steps

- For production release: Follow App Store submission process
- For updates: Increment version in `pubspec.yaml` and repeat process

## Resources

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [TestFlight Guide](https://developer.apple.com/testflight/)
- [App Store Connect](https://appstoreconnect.apple.com)

