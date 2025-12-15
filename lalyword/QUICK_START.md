# Quick Start: Deploy to Friends' iPhones

## Fastest Method: TestFlight (Recommended)

### Step 1: Build the App
```bash
cd lalyword
./deploy_ios.sh
# Choose option 1 (TestFlight/App Store)
```

### Step 2: Upload to App Store Connect
1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. In Xcode:
   - **Product → Archive**
   - Wait for archive
   - Click **Distribute App**
   - Choose **App Store Connect**
   - Follow wizard

### Step 3: Set Up TestFlight
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. **My Apps → Lalyword → TestFlight**
3. Wait for processing (~10-30 min)
4. Add testers:
   - **External Testing** → Create public link
   - Share link with friends

### Step 4: Friends Install
1. Friends install **TestFlight** app from App Store
2. Friends open your TestFlight link
3. They tap **Install** in TestFlight

**That's it!** 🎉

---

## Requirements

- ✅ Apple Developer Account ($99/year)
- ✅ Xcode installed
- ✅ Flutter installed

---

## Need Help?

- See `DEPLOYMENT_GUIDE.md` for detailed instructions
- See `DEPLOYMENT_CHECKLIST.md` for troubleshooting

---

## Alternative: Ad-hoc Distribution

If you don't want to use TestFlight:

1. Get UDIDs from friends' iPhones
2. Register devices in [Apple Developer Portal](https://developer.apple.com/account)
3. Create Ad-hoc provisioning profile
4. Build IPA with Ad-hoc profile
5. Share IPA file with friends

See `DEPLOYMENT_GUIDE.md` for full instructions.

