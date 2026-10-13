# Runtime-registration size experiment

This is the smallest build in Mote's experiment to make the smallest Mac app I could that still does something practical: copy text from a selected screen area. Version **0.1.2 is 59,265 bytes (57.9 KiB)** for the signed app, down from 78,321 bytes for the standard build, a **24.33% reduction**. The executable is 56,624 bytes.

It keeps Command-Shift-2, mouse selection with a crosshair, Escape cancellation, the image picker, preferences, clipboard output, and the persistent last result. The original copy in /Applications is unchanged; the smaller 0.1.2 candidate runs separately.

## Build

From the repository root:

```sh
SIGN_IDENTITY=qopy-dev python3 experiments/runtime/build.py
python3 tests/verify.py --binary experiments/runtime/build/Mote.app/Contents/MacOS/Mote --report experiments/runtime/build/ocr-verification.json
```

Use your own existing signing identity, or omit `SIGN_IDENTITY` for ad-hoc signing. The local test used the existing development certificate. The candidate has the same bundle identifier as Mote: quit the installed app before launching it. Output stays in the ignored `experiments/runtime/build/` directory. Both build routes share the canonical source.

## How it saves space

The generator converts Mote's five custom classes and their callbacks into C functions, then registers them with Apple's public Objective-C runtime APIs at launch. Compiler-checked Objective-C declarations remain available. System receiver classes are resolved by name; dynamic collection literals use ordinary factory methods so they do not recreate writable class-reference tables. Selector references use the linker's `-const_selrefs` placement.

The writable segment now contains only zero-initialized state, which occupies memory but no bytes in the executable. This removes a padded 16 KiB file segment and some metadata. `__DATA_CONST` retains its read-only-after-fixups flag. Code signing, executable protections, and accurate OCR remain enabled. No `-no_data_const`, custom loader, compressed executable, or additional runtime is used.

The controller and selection coordinates become process globals because Mote has one controller and one active selection. A new selection resets its coordinates. View-owned images and completion blocks use associated objects, so their lifetime follows the view.

The cost is more specialized build machinery and some class-registration work at startup. New method argument/return types need an ABI review; the generator rejects unfamiliar non-object types. OCR timings do not establish a startup or memory improvement. This is an experimental size strategy, not the default build.

## Verification on this Mac

Initial full-flow verification on 2026-10-11, Apple M5 Max, macOS 26.6.2; the 0.1.2 checks below were rerun on 2026-10-12:

- All 18 existing OCR checks passed, including large, small Retina-sized, and dark text, plus blank, invalid, and missing images. Fresh-process fixture medians were 0.244–0.248 seconds in the 0.1.2 rerun. See `ocr-verification.json` for scope and results.
- Launched the actual signed candidate and confirmed its process path. Viewed the rendered main window and full-display selector on the 3440 x 1440 display. UI labels, result area, and focus matched the regular app.
- Command-Shift-2 opened the selector. Dragging over text in Codex recognized 162 characters in 0.23 seconds. Ordinary Command-V into TextEdit reproduced the result.
- A second capture followed by Escape preserved both the last result and the clipboard, checked with another paste into TextEdit.
- Tab moved focus from Capture to Open image. Existing menus and their setting choices appeared. Captured text survived quitting and reopening the candidate.
- Strict signature verification passed. The packaged executable's bytes before the signature exactly match those of the UI-tested build. The builder asserts a zero-file-byte writable segment and preserved constant-data protection.
- After initial testing, returned to the original installed app and restored the previous last result. At the user's request, subsequently launched the smaller candidate; version 0.1.2 is now running. No screen-permission setting was changed.

The automation's keys are app-bound, so a physical global key press while another app is foreground remains unverified. The candidate's image picker, changing preference values, multiple physical displays, other Macs, and notarized distribution have not received a new complete pass. The normal build's earlier coverage is recorded in the root `UI-VERIFICATION.md`.

Last text and preferences use the same durable local locations as the regular app. Screenshots stay in memory; there is no server or deployment step. These figures measure the app's files, excluding system frameworks/models, filesystem allocation, and runtime memory.

Apple references: [runtime class creation](https://developer.apple.com/documentation/ObjectiveC/objc_allocateClassPair%28_%3A_%3A_%3A%29), [method registration](https://github.com/apple-oss-distributions/objc4/blob/main/runtime/runtime.h), and [selector placement](https://github.com/apple-oss-distributions/ld64/blob/main/doc/man/man1/ld-classic.1).

## 0.1.1 cursor correction

A selector opened beneath a stationary pointer could miss a cursor-rectangle entry event. AppKit could also reset the pointer while the overlay became the key window asynchronously. The selector now applies the crosshair when it opens, reapplies it after becoming key and during dragging, and restores the arrow when selection ends.

Temporary in-app diagnostics reproduced the original failure: AppKit's current cursor was a crosshair while the actual system cursor was an arrow. With the fix, both rendered as crosshairs after activation. Diagnostic code was excluded from the shipped build. The final candidate opened with Command-Shift-2, completed a drag over blank screen content, and preserved the saved text. The correction adds 80 bytes to the signed app.

## 0.1.2 mouse-only selection

Removed arrow/Space/Return rectangle selection, its drawn keyboard crosshair, and custom arrow navigation between main-window buttons. The hint and accessibility text now describe mouse dragging and Escape only. Command-Shift-2 and the native mouse crosshair are preserved.

In the signed running candidate, Command-Shift-2 opened the selector; Left, Space, Right, Down, and Return left it open without submitting a selection. Escape cancelled. A mouse drag over blank content completed with “No text found” and kept the previous result. Inspected the single-line hint and final main window in real screenshots. The running app also showed a successful 17-character screen recognition.

The signed bundle shrank from 59,313 to 59,265 bytes, a saving of 48 bytes. Its machine-code section shrank from 18,096 to 17,288 bytes, but the containing 32 KiB segment and 16 KiB constant-data segment retained their alignment. Strict signature checks and the existing 18 OCR checks passed. The archive is compared with the exact UI-tested executable.
