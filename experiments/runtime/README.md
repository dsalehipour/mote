# Runtime-registration size experiment

This candidate preserves the full Mote interface, Command-Shift-2, custom screen selection, image picker, preferences, clipboard output, and persistent last result. It reduces the signed app's uncompressed file total from **78,417 to 59,233 bytes**, a **24.46% reduction**. The executable is 56,592 bytes. The installed release is unchanged.

## Build

From the repository root:

```sh
SIGN_IDENTITY=qopy-dev python3 experiments/runtime/build.py
python3 tests/verify.py --binary experiments/runtime/build/Mote.app/Contents/MacOS/Mote --report experiments/runtime/build/ocr-verification.json
```

Use your own existing signing identity, or omit `SIGN_IDENTITY` for ad-hoc signing. The local test used the existing development certificate. The candidate has the same bundle identifier as Mote: quit the installed app before launching it. Output stays in the ignored `experiments/runtime/build/` directory. The canonical source and normal build remain unchanged.

## How it saves space

The generator converts Mote's five custom classes and their callbacks into C functions, then registers them with Apple's public Objective-C runtime APIs at launch. Compiler-checked Objective-C declarations remain available. System receiver classes are resolved by name; dynamic collection literals use ordinary factory methods so they do not recreate writable class-reference tables. Selector references use the linker's `-const_selrefs` placement.

The writable segment now contains only zero-initialized state, which occupies memory but no bytes in the executable. This removes a padded 16 KiB file segment and some metadata. `__DATA_CONST` retains its read-only-after-fixups flag. Code signing, executable protections, and accurate OCR remain enabled. No `-no_data_const`, custom loader, compressed executable, or additional runtime is used.

The controller and selection coordinates become process globals because Mote has one controller and one active selection. A new selection resets its coordinates. View-owned images and completion blocks use associated objects, so their lifetime follows the view.

The cost is more specialized build machinery and some class-registration work at startup. New method argument/return types need an ABI review; the generator rejects unfamiliar non-object types. OCR timings do not establish a startup or memory improvement. This is an experimental size strategy, not the default build.

## Verification on this Mac

Tested on 2026-10-11, Apple M5 Max, macOS 26.6.2:

- All 18 existing OCR checks passed, including large, small Retina-sized, and dark text, plus blank, invalid, and missing images. Fresh-process fixture medians were 0.236–0.247 seconds. See `ocr-verification.json` for scope and results.
- Launched the actual signed candidate and confirmed its process path. Viewed the rendered main window and full-display selector on the 3440 x 1440 display. UI labels, result area, and focus matched the regular app.
- Command-Shift-2 opened the selector. Dragging over text in Codex recognized 162 characters in 0.23 seconds. Ordinary Command-V into TextEdit reproduced the result.
- A second capture followed by Escape preserved both the last result and the clipboard, checked with another paste into TextEdit.
- Tab moved focus from Capture to Open image. Existing menus and their setting choices appeared. Captured text survived quitting and reopening the candidate.
- Strict signature verification passed. The packaged executable's bytes before the signature exactly match those of the UI-tested build. The builder asserts a zero-file-byte writable segment and preserved constant-data protection.
- Returned to the original installed app and restored the user's previous last result. No screen-permission setting was changed.

The automation's keys are app-bound, so a physical global key press while another app is foreground remains unverified. The candidate's image picker, changing preference values, full keyboard rectangle flow, multiple physical displays, other Macs, and notarized distribution have not received a new complete pass. The normal build's earlier coverage is recorded in the root `UI-VERIFICATION.md`.

Last text and preferences use the same durable local locations as the regular app. Screenshots stay in memory; there is no server or deployment step. These figures measure the app's files, excluding system frameworks/models, filesystem allocation, and runtime memory.

Apple references: [runtime class creation](https://developer.apple.com/documentation/ObjectiveC/objc_allocateClassPair%28_%3A_%3A_%3A%29), [method registration](https://github.com/apple-oss-distributions/objc4/blob/main/runtime/runtime.h), and [selector placement](https://github.com/apple-oss-distributions/ld64/blob/main/doc/man/man1/ld-classic.1).
