# Mote

An experiment to build the smallest Mac app I could while still making something practical. Mote copies text you cannot normally select: press **⌘⇧2**, drag around text on screen, then paste it anywhere. Recognition runs locally on the Mac.

The smallest signed build of **Mote 0.1.2 is 59,265 bytes (57.9 KiB)** for the entire app bundle. That is the sum of its uncompressed files, including its signature. macOS supplies the frameworks and OCR models; their size and runtime memory are separate.

## Use

Open `Mote.app`. Press **Command + Shift + 2**, or click **Capture text**. Drag a rectangle and release. Paste with **Command + V**. **Escape** cancels without replacing the clipboard.

On first use, enable Mote in **System Settings → Privacy & Security → Screen & System Audio Recording**. Mote does not capture audio and does not need Accessibility permission. The menu's **Screen capture permission…** action opens the relevant settings.

The menu bar's text-viewfinder icon and the **Mote** application menu expose:

- Capture text; open an existing image; show or copy the last result.
- Shortcut choices: Command + Shift + 2, 8, or 9. Registration conflicts are reported.
- Fast recognition, language correction, and optional result preview after capture.
- Reveal the saved text and quit.

Accurate recognition and language correction are the defaults. Fast mode can reduce accuracy. Result preview is off by default so successful captures do not interrupt pasting into another app. A checkmark in the menu bar indicates successful copying.

Selection uses the mouse: drag from one corner to the other and release to copy. Arrow keys, Space, and Return do not control the selector. Tab and Shift-Tab still move through the main window's controls. Place the pointer on the desired display before invoking capture; a selection stays on that display.

## Requirements and build

Apple Silicon, macOS 14 or later. Building requires Apple's Command Line Tools and Python 3. No package download is needed.

```sh
python3 build.py
open Mote.app
python3 tests/verify.py --report verification.json
```

To build the smallest variant, use `python3 experiments/runtime/build.py`; its app is written to `experiments/runtime/build/Mote.app`. The specialized [runtime-registration build](experiments/runtime/README.md) derives from the same source.

The default build uses ad-hoc signing. For a stable local development identity:

```sh
SIGN_IDENTITY='your-existing-code-signing-identity' python3 build.py
```

The delivered local build uses Darius's existing `qopy-dev` certificate with Mote's own bundle identifier, `com.darius.mote`. This keeps screen permission stable across rebuilds. It is a local development build, not an Apple-notarized distribution.

`OPTIMIZE=-Oz` compares size-focused optimization with the default `-O3`. `SIGNATURE_RESERVE` adjusts the signing allocation when using a certificate chain larger than the local development certificate. The build must pass strict code-signature validation.

## How it works

Objective-C and AppKit provide the window and menu. Carbon registers a global shortcut without an event tap. ScreenCaptureKit captures one still of the display under the pointer, excluding Mote's own windows. A native overlay presents that image for selection. Only the selected crop goes to Vision text recognition, then to the pasteboard.

The screenshot and crop stay in process memory and are released after the operation. There is no background capture, polling timer, bundled model, web runtime, or app network client. macOS provides the frameworks and recognition models, which are not included in the app's size.

The shared OCR implementation is also callable for repeatable checks:

```sh
Mote.app/Contents/MacOS/Mote --ocr image.png
Mote.app/Contents/MacOS/Mote --ocr image.png fast
```

Exit codes: 0 means text found; 3 means a valid image with no recognized text; 1 means an image/read error. The CLI prints text only and does not change the clipboard or saved result.

## Persistence and privacy

The most recent successful result is saved as UTF-8 at `~/Library/Application Support/Mote/last-result.txt`, with an owner-only directory and file. A subsequent successful capture replaces that last result. Cancellation and failures leave the last result and clipboard alone. This is a last-result cache, not an unlimited history.

Shortcut and recognition preferences use macOS user defaults under `com.darius.mote`. Both settings and the last result survive quitting/relaunching. The app bundle contains no user captures or settings. This is a local desktop application; there is no server or production provisioning step.

## Size and verification

Measured for version 0.1.2, signed with the existing local development certificate:

| Build | Complete app | Executable |
| --- | ---: | ---: |
| Smallest runtime-registration build | **59,265 bytes (57.9 KiB)** | 56,624 bytes |
| Standard Objective-C build | 78,321 bytes (76.5 KiB) | 75,680 bytes |

Removing keyboard rectangle selection saved 48 app bytes compared with 0.1.1 (59,313 bytes). The machine-code section shrank by 808 bytes, but its 32 KiB aligned segment stayed the same size. Fewer instructions do not always mean an equally large file-size reduction.

`build-metrics.json` records the exact executable size, total uncompressed app-file bytes, and compilation time. APFS allocated size, compressed download size, and runtime memory are different measurements. Runtime memory is substantially larger than the executable because AppKit and Vision load system code and models.

The normal full UI build remains above the 64 KiB target. Separate executable, read-only relocation, and writable-data segments account for 64 KiB of page-aligned space before signature/linker data. Read-only data protection, code signing, and normal executable protections remain enabled.

An optional [runtime-registration experiment](experiments/runtime/README.md) retains the mouse selection interface and shortcut at **59,265 bytes (57.9 KiB)** for the signed app. Its core screen-selection-to-clipboard flow was tested. It keeps memory protections enabled but adds specialized build machinery; it is not the default or installed build.

`benchmark.json` compares `-Oz` and `-O3` on the same two-line image. Their observed timings are close and do not establish general speed superiority. `-O3` was slightly smaller in this comparison and is the default.

`tests/verify.py` checks exact OCR output on large text, small Retina-sized text, and light-on-dark text, plus blank, invalid, and missing images. Five separate processes per text case provide basic timing samples. The UI verification record is in `UI-VERIFICATION.md`.
