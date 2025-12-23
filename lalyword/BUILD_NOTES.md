# Web Build Notes

## Clean Build Process

To ensure you always get a fresh build with the latest code, use the provided script:

```bash
./package-web.sh
```

This script:
1. ✅ Cleans all previous build artifacts (`flutter clean`)
2. ✅ Removes any leftover `build/web` directory
3. ✅ Removes old zip files
4. ✅ Gets fresh dependencies
5. ✅ Builds a release version
6. ✅ Verifies the build succeeded
7. ✅ Creates a clean zip package

## File Timestamps Explained

When you build, you'll see different timestamps on files. This is **normal**:

### Files That Change Every Build (Your App Code)
These files are rebuilt with every `flutter build web`:
- `main.dart.js` - Your app's compiled code ✅
- `flutter_bootstrap.js` - App initialization ✅
- `flutter_service_worker.js` - Service worker with file hashes ✅
- `index.html` - Main HTML file ✅
- `version.json` - Version metadata ✅
- `assets/` - Your app assets ✅

### Files That Don't Change (Flutter Engine)
These files are part of Flutter SDK and only change when you upgrade Flutter:
- `flutter.js` - Flutter web engine (may show old date)
- `canvaskit/` - Canvas rendering library (may show old date)
- `manifest.json` - PWA manifest (copied from `web/manifest.json`)

**This is expected behavior!** Flutter caches these engine files to speed up builds.

## Ensuring Clean Builds

If you suspect you're getting mixed versions:

1. **Always use the script**: `./package-web.sh`
   - This ensures everything is cleaned first

2. **Or manually clean**:
   ```bash
   flutter clean
   rm -rf build/web
   flutter build web --release
   ```

3. **Check the critical files** after building:
   ```bash
   ls -lh build/web/main.dart.js build/web/flutter_bootstrap.js build/web/version.json
   ```
   These should all have the same timestamp (current build time).

## Version Consistency Check

The `flutter_service_worker.js` contains hashes of all files. If files don't match their hashes, the service worker will cache-bust. You can verify this file references the correct versions.

## Browser Caching

If you're testing on another computer and see old versions:
1. Clear browser cache
2. Hard refresh (Ctrl+Shift+R or Cmd+Shift+R)
3. Or test in an incognito/private window

The service worker will automatically update when it detects file changes via hash mismatches.

