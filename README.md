# Pluck

**Copy text you can’t select.**

Press **⌘ Shift 2**, drag over text on your screen, then paste it anywhere. Pluck turns words in screenshots, videos, PDFs, and other apps into editable text, with recognition handled locally by macOS.

**[Download for Mac](https://github.com/dsalehipour/pluck/releases/latest/download/Pluck-macOS-arm64.zip)** · **[Visit the website](https://pluck.bigfootenvysme.chatgpt.site)** · [Release notes](https://github.com/dsalehipour/pluck/releases/latest)

## Small by design

Pluck began as a challenge: build the smallest Mac app I could that was also practical. The v0.1.4 GitHub release is approximately **58 KiB**, including its code signature. There is no bundled OCR model or web runtime; it uses the frameworks already on your Mac. The separate App Store target includes the additional icon assets and signing metadata Apple requires.

Exact sizes and checksums are published with [each release](https://github.com/dsalehipour/pluck/releases/latest). App size means uncompressed file bytes; system frameworks, filesystem allocation, and runtime memory are separate.

## Get started

1. [Download the latest release](https://github.com/dsalehipour/pluck/releases/latest/download/Pluck-macOS-arm64.zip), unzip it, and move **Pluck.app** to Applications.
2. Open Pluck and enable **Screen & System Audio Recording** in System Settings when prompted. Quit and reopen Pluck to apply a permission change if capture does not start. Pluck captures no audio.
3. Press **⌘ Shift 2**, drag around the words you want, and release. Paste with **⌘ V**. **Escape** cancels.

Requires **Apple Silicon and macOS 14 or later**. This experimental release is **not notarized by Apple**; macOS may block first launch. If you trust the app, review it in **System Settings → Privacy & Security**.

The download button always points to the latest published release.

When upgrading from Mote, quit the old copy before opening Pluck. Pluck claims its capture shortcut exclusively so another copy cannot open a second selector. If a different app already owns that shortcut, choose another in the Pluck menu.

## A few useful extras

- Recognize text from an existing image using **Open image**.
- Reopen or copy your last result from the menu bar.
- Choose a different shortcut, faster recognition, language correction, or a result preview in the app menu.

## Privacy

Recognition runs on your Mac. Pluck has no account, analytics, app network client, or background capture. Screen images stay in memory.

The latest successful text result is saved locally and replaced by the next successful capture. Settings and the last result survive restarting the app. Pluck was previously called Mote and retains its original storage locations to preserve existing data: `~/Library/Application Support/Mote/last-result.txt` and preferences under `com.darius.mote`.

The sandboxed App Store target stores its data inside its macOS container instead. The direct build's existing data stays in place. Read the [privacy policy](https://pluck.bigfootenvysme.chatgpt.site/privacy.html) for details.

## Build from source

Apple’s Command Line Tools and Python 3 are required. No third-party packages are needed.

```sh
git clone https://github.com/dsalehipour/pluck.git
cd pluck
python3 experiments/runtime/build.py
open experiments/runtime/build/Pluck.app
```

The compact build uses runtime class registration to reduce binary metadata. The conventional Objective-C build remains available with `python3 build.py`.

[Build instructions and architecture](docs/BUILDING.md) · [Size experiment](experiments/runtime/README.md) · [Verification record](UI-VERIFICATION.md)

The [Mac App Store target](appstore/README.md) requires full Xcode and an Apple Developer account for distribution signing. Its presence here does not mean Pluck is available in the App Store yet.

## Contributing

[Open an issue](https://github.com/dsalehipour/pluck/issues) for a bug or suggestion. For bugs, include your macOS version, app version, and steps to reproduce. Keep changes focused on practical functionality and a small footprint.
