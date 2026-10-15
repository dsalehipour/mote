# Building and architecture

Apple Silicon, macOS 14 or later. Building requires Apple's Command Line Tools and Python 3. No package download is needed.

```sh
python3 build.py
open Pluck.app
python3 tests/verify.py --report verification.json
```

To build the smallest variant, use `python3 experiments/runtime/build.py`; its app is written to `experiments/runtime/build/Pluck.app`. The specialized [runtime-registration build](../experiments/runtime/README.md) derives from the same source.

The default build uses ad-hoc signing. For a stable local development identity:

```sh
SIGN_IDENTITY='your-existing-code-signing-identity' python3 build.py
```

The delivered local build uses Darius's existing `qopy-dev` certificate with the original bundle identifier, `com.darius.mote`. This keeps screen permission stable across rebuilds. It is a local development build, not an Apple-notarized distribution.

`OPTIMIZE=-Oz` compares size-focused optimization with the default `-O3`. `SIGNATURE_RESERVE` adjusts the signing allocation when using a certificate chain larger than the local development certificate. The build must pass strict code-signature validation.

## How it works

Objective-C and AppKit provide the window and menu. Carbon registers a global shortcut without an event tap. ScreenCaptureKit captures one still of the display under the pointer, excluding Pluck's own windows. A native overlay presents that image for selection. Only the selected crop goes to Vision text recognition, then to the pasteboard.

The screenshot and crop stay in process memory and are released after the operation. There is no background capture, polling timer, bundled model, web runtime, or app network client. macOS provides the frameworks and recognition models, which are not included in the app's size.

The shared OCR implementation is also callable for repeatable checks:

```sh
Pluck.app/Contents/MacOS/Pluck --ocr image.png
Pluck.app/Contents/MacOS/Pluck --ocr image.png fast
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

An optional [runtime-registration experiment](../experiments/runtime/README.md) retains the mouse selection interface and shortcut at **59,265 bytes (57.9 KiB)** for the signed app. Its core screen-selection-to-clipboard flow was tested. It keeps memory protections enabled but adds specialized build machinery; it is not the default or installed build.

`benchmark.json` compares `-Oz` and `-O3` on the same two-line image. Their observed timings are close and do not establish general speed superiority. `-O3` was slightly smaller in this comparison and is the default.

`tests/verify.py` checks exact OCR output on large text, small Retina-sized text, and light-on-dark text, plus blank, invalid, and missing images. Five separate processes per text case provide basic timing samples. The UI verification record is in [`UI-VERIFICATION.md`](../UI-VERIFICATION.md).

## Publishing future builds

The `.github/workflows/release.yml` workflow runs for pushed `v*` tags. Update the version in the app and builder, commit the change, and push a matching version tag from a commit containing the workflow. GitHub's macOS runner builds the compact arm64 app, runs all 18 OCR checks, verifies the signature, then packages and verifies the extracted bytes before creating a release. A failed build publishes nothing. The workflow does not publish every unreviewed commit.

Every release keeps the same asset name, `Pluck-macOS-arm64.zip`, plus `SHA256SUMS.txt`, `release.json`, and the OCR report. `scripts/package_release.py` rejects tags that disagree with the bundle version. The landing page reads the latest release metadata on load and when revisited, and its stable download link follows GitHub's latest release even without JavaScript.

The website source is stored and deployed through ChatGPT Sites, independently of the app repository. No scheduled agent or site rebuild is needed when publishing a new app release. The latest-release URL convention is documented by [GitHub](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases).

## Pluck rename

Version 0.1.3 renames the app, executable, menu, window, and download package to Pluck. The bundle identifier `com.darius.mote`, window autosave key, and `Application Support/Mote` directory intentionally remain unchanged to retain existing settings and saved text. Historical measurements above refer to the versions stated. The release also includes an identical `Mote-macOS-arm64.zip` compatibility asset so old download links continue to work. The internal release metadata marker keeps its original name for existing clients.


## Shortcut regression check

After building the compact variant, run `python3 tests/verify_hotkey.py`. It tests the actual registration method in both variants against a separate process holding Command-Shift-9, then verifies recovery when that process exits. It does not synthesize key presses or alter saved preferences. The release workflow runs this alongside OCR and package verification.
