# Mac App Store build

This target uses the same compact Objective-C implementation as the direct download, with App Sandbox, a native app icon, a privacy manifest, and Apple distribution signing. It supports Apple Silicon on macOS 14 or later. Store version and build number live in `Pluck.xcconfig`.

## Build and export

Use a full Xcode installation signed into the Apple Developer account. Set `DEVELOPER_DIR` to that installation if the system default points at Command Line Tools. Override `DEVELOPMENT_TEAM` when building for another team; distribution also requires the matching registered bundle identifier and export options.

```sh
xcodebuild -project appstore/Pluck.xcodeproj -scheme Pluck \
  -configuration Release -archivePath appstore/build/Pluck.xcarchive \
  -derivedDataPath appstore/build/DerivedData -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath appstore/build/Pluck.xcarchive \
  -exportPath appstore/build/export -exportOptionsPlist appstore/ExportOptions.plist \
  -allowProvisioningUpdates
```

The generated `Pluck.pkg` is a Mac App Store upload package, not a replacement for the standalone GitHub ZIP. Export uses automatic App Store distribution signing. Certificates, private keys, provisioning profiles, build outputs, and App Review contact details must not be committed.

The project generates the compact source before compilation. `render_icon.swift` reproducibly creates the checked-in Mac icon sizes with AppKit. The icon, privacy manifest, signing metadata, and provisioning profile increase the Store build size compared with the tiny direct-download experiment. Measure each final package independently.

## Sandbox and privacy

The app has only App Sandbox and user-selected read-only file access. It has no network, microphone, camera, or temporary-exception entitlement. Screen access is controlled separately by macOS user consent. The privacy manifest declares the app's own UserDefaults and elapsed-time measurement uses.

The Store build retains bundle ID `com.darius.mote`. macOS redirects its local text file to `~/Library/Containers/com.darius.mote/Data/Library/Application Support/Mote/last-result.txt`. It does not migrate or overwrite the direct build's existing file outside the container. Settings and the last successful result survive app restarts.

## Verification

```sh
python3 experiments/runtime/generate.py
python3 tests/verify_hotkey.py
python3 tests/verify_capture_recovery.py
TMPDIR="$HOME/Library/Containers/com.darius.mote/Data/tmp" \
  python3 tests/verify.py \
  --binary appstore/build/Pluck.xcarchive/Products/Applications/Pluck.app/Contents/MacOS/Pluck
codesign --verify --deep --strict appstore/build/Pluck.xcarchive/Products/Applications/Pluck.app
pkgutil --check-signature appstore/build/export/Pluck.pkg
```

Launch the development-signed app once before the CLI checks to establish its container. The fixture generator uses a temporary folder inside that container, since a command-line path does not receive the user-selected access granted by the image picker. Also test the real image picker with an image outside the container, screen selection, Escape, clipboard paste into another app, persisted text after reopening, and the Privacy policy menu item.

## Submission material

`metadata/listing.json` holds the listing and reviewer instructions; private review-contact data is intentionally absent. `metadata/creative` contains editable compositions, native source captures, and the four 1280 × 800 PNG screenshots used in the submission. The separate motion study is a screenshot animation for marketing review, not an uploaded App Store preview.

Version 1.0 (6) was submitted on October 16, 2026 and verified as **Waiting for Review**. See [VERIFICATION.md](VERIFICATION.md) for the review-record link, submission ID, validation evidence, and release settings.

Create the macOS app record in App Store Connect, upload the signed package, complete the privacy and age-rating questionnaires, choose the build, and submit for review. Keep the app free and select manual release after approval. A successful local archive/export is not an App Store upload, submission, approval, or public release.
