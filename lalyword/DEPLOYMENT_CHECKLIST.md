# iOS Deployment Checklist

Use this checklist to ensure everything is ready for deployment.

## Pre-Deployment Checklist

### ✅ Apple Developer Account
- [ ] Have active Apple Developer Program membership ($99/year)
- [ ] Can access [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Can access [Apple Developer Portal](https://developer.apple.com/account)

### ✅ Development Environment
- [ ] Xcode installed and updated
- [ ] Flutter SDK installed (`flutter doctor` passes)
- [ ] CocoaPods installed (`pod --version`)
- [ ] Command Line Tools installed

### ✅ App Configuration
- [ ] Bundle Identifier set: `com.example.lalyword` (or your own)
- [ ] Version number updated in `pubspec.yaml`
- [ ] App name set: "Lalyword"
- [ ] App icons configured
- [ ] Signing certificates configured in Xcode

### ✅ Code Signing
- [ ] Development team selected in Xcode
- [ ] Automatic signing enabled OR manual provisioning profile configured
- [ ] Certificates valid (not expired)

## TestFlight Deployment Checklist

### ✅ Build & Archive
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Run `flutter build ipa --release` OR archive in Xcode
- [ ] Build succeeds without errors

### ✅ Upload
- [ ] Archive uploaded to App Store Connect
- [ ] Processing completed (check TestFlight tab)
- [ ] No compliance issues

### ✅ TestFlight Setup
- [ ] App created in App Store Connect (if first time)
- [ ] TestFlight tab accessible
- [ ] Internal testers added (optional)
- [ ] External testers added OR public link created

### ✅ Distribution
- [ ] Testers invited via email OR public link shared
- [ ] Testers have TestFlight app installed
- [ ] Testers can install and run the app

## Ad-hoc Distribution Checklist

### ✅ Device Registration
- [ ] Collected UDIDs from all friends' iPhones
- [ ] Registered devices in Apple Developer Portal
- [ ] Verified device count (max 100 per year)

### ✅ Provisioning Profile
- [ ] Created Ad-hoc provisioning profile
- [ ] Profile includes all registered devices
- [ ] Profile installed in Xcode
- [ ] Profile selected in Xcode project settings

### ✅ Build
- [ ] Ad-hoc profile selected in Xcode
- [ ] Build configuration set to Release
- [ ] IPA built successfully
- [ ] IPA file available at `build/ios/ipa/lalyword.ipa`

### ✅ Distribution
- [ ] IPA uploaded to cloud storage (Dropbox, Google Drive, etc.)
- [ ] Friends have installation instructions
- [ ] Friends know how to trust developer certificate

## Quick Test Commands

```bash
# Check Flutter setup
flutter doctor

# Clean and rebuild
cd lalyword
flutter clean
flutter pub get
flutter build ios --release --no-codesign

# Check iOS setup
cd ios
pod install
cd ..

# Build IPA
flutter build ipa --release
```

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "No signing certificate" | Create in Developer Portal or let Xcode auto-generate |
| "Bundle ID exists" | Change bundle ID to your own domain |
| "Provisioning profile mismatch" | Ensure bundle ID matches everywhere |
| "Device not registered" | Add UDID to Developer Portal |
| "Can't install on device" | Trust developer certificate in Settings |
| Build fails | Check `flutter doctor` and Xcode console |

## Version Management

Before each deployment:
1. Update version in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # Version + Build number
   ```
2. Commit changes:
   ```bash
   git add pubspec.yaml
   git commit -m "Bump version to 1.0.1+2"
   ```

## Support Resources

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)

