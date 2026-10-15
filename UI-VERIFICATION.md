# Mote verification

## 0.1.0 baseline

Verified locally on 2026-10-11, Apple M5 Max, macOS 26.6.2.

## Running app

- Launched the real `.app` through Launch Services, then installed the signed build in `/Applications/Mote.app`.
- Inspected real rendered screenshots of the 520 × 560 point window at normal scale. Labels are 14–29 points, results 16 points; primary/secondary controls match and keyboard focus is visible.
- Inspected the selector on the user's actual 3440 × 1440 display. Screen capture was initially denied, the app explained the permission, and the user enabled it. A subsequent real capture succeeded.
- Dragged a rectangle around a line in another app's screen content. OCR returned the line, and a normal Command-V paste into TextEdit matched it. The recognition step took 0.27 seconds for that selection; this excludes snapshot acquisition and the user's selection time.
- Escape closed the selector. Pasting into TextEdit afterward confirmed the clipboard was unchanged.
- Used arrows, Space, and Return to complete a keyboard-only rectangle. A tiny selection returned “No text found”; the previous result and clipboard were preserved and verified with another paste.
- Verified Tab → Open image → Copy again, and Shift-Tab back, with a visible focus ring. Buttons also support arrow navigation.
- Changed the shortcut from Command-Shift-2 to Command-Shift-8 through the menu, quit, and reopened the installed app. The new shortcut and last result persisted. Restored Command-Shift-2.
- Command-Shift-2 opened the selector while Mote was active. Global Carbon registration reported success. The app-bound automation input could not independently verify a physical global shortcut from another foreground app; that specific hardware-input check remains unverified.
- Opened a PNG using the native image picker; exact two-line OCR succeeded. Verified the Edit → Paste command inserts clipboard text into the picker path field after adding standard editing commands. The final installed app read the image in 0.21 seconds and displayed the correct result.
- Inspected the final installed window screenshot after the last UI change. The code signature passes strict verification. The installed executable and packaged executable are compared by SHA-256 during packaging.

## Automated checks

Run `python3 tests/verify.py --report verification.json`.

- Exact text on large, small Retina-sized, and dark-background image fixtures: five runs each.
- Blank image: no text, exit 3.
- Invalid and missing image: failure, exit 1, no fabricated output.
- The CLI shares the production OCR function and does not mutate the clipboard or app state.

Timing samples and their scope are recorded in `verification.json` and `benchmark.json`; they are not claims about arbitrary documents. OCR output can contain mistakes, particularly in fast mode or with low-resolution/stylized text.

## Remaining limits

The complete app is about 77 KiB, so the 64 KiB stretch goal remains open. Framework/model disk size is supplied by macOS, and runtime memory is much larger than the executable. Multiple-display selection is implemented for the screen under the pointer, but moving between different physical displays was not manually verified. Local development signing is verified; notarization and distribution on another Mac are not part of this build.

No server, release deployment, login item, or cloud data store was created. Last text and preferences persist locally as described in the README.

## 0.1.1 cursor correction in the smaller build

Verified on the same Mac and display on 2026-10-11. Reproduced the arrow-cursor symptom using a temporary diagnostic panel that rendered both AppKit's current cursor and the actual system cursor. Before the fix, the former was a 24 × 24 crosshair while the latter was a 28 × 40 arrow, including after the overlay became key. With the fix, both were 24 × 24 crosshairs after activation. The panel was excluded from production.

The fix explicitly applies the crosshair when opening selection, after asynchronous key-window activation, and during dragging. The arrow is restored when selection ends. Both build routes were rebuilt and passed strict signature verification. All 18 existing OCR checks passed against the final smaller executable; results are in experiments/runtime/ocr-verification.json.

Launched the final signed smaller 0.1.1 candidate and confirmed its process path. Inspected the clean selector and main-window screenshots. Command-Shift-2 opened selection; a drag over blank sky completed with “No text found” and retained the previous saved text. The corrected candidate remains running from experiments/runtime/build/Mote.app. The original /Applications/Mote.app is unchanged and closed. The signed candidate totals 59,313 bytes (57.9 KiB), 80 bytes larger than 0.1.0.

## 0.1.2 mouse-only selection

Verified on 2026-10-12 in the signed smaller build. The actual full-display screenshot was 3456 × 2234 pixels; the main window rendered at 1040 × 1184 pixels. Inspected both at the user's current scale. The selector now shows one legible line, “Drag around text · Escape cancels”, with no keyboard-selection instructions.

Command-Shift-2 opened selection. Pressing Left, Space, Right, Down, and Return did not submit a rectangle; the selector remained open. Escape cancelled and preserved the result. Clicking Capture text also opened selection. Dragging a rectangle over blank content completed with “No text found” and preserved the last result. Separately observed a successful 17-character screen OCR result in the running 0.1.2 app.

The version is visible in the main-window footer. The keyboard rectangle code, drawn keyboard crosshair, and custom main-window arrow navigation are removed; native mouse crosshair behavior and Tab navigation remain. Both build routes passed strict signature checks. Existing OCR checks were reused without adding implementation-mirroring tests; reports are verification.json and experiments/runtime/ocr-verification.json.

The corrected candidate remains running from experiments/runtime/build/Mote.app. The original installed bundle is unchanged. The signed app's uncompressed file total is 59,265 bytes (57.9 KiB), 48 bytes less than 0.1.1. Updated the README and runtime experiment documentation with the practical size-test purpose and exact measured sizes. Historical verification above describes older versions, including their now-removed keyboard selection.

## 0.1.3 Pluck rename (2026-10-15)

Both the conventional and compact certificate-signed builds passed all 18 existing OCR checks. Strict code-signature checks and ZIP extraction with byte-for-byte comparison passed. The compact local bundle is 59,267 bytes, including its signature; its executable is 56,624 bytes.

Launched the compact Pluck.app and visually inspected the renamed main window, footer, and application menu. The existing saved result loaded from the unchanged storage location. Command-Shift-2 opened the renamed selection overlay and Escape returned to the app. No screen-capture permission change was needed on this Mac. This focused rename check does not establish notarization, behavior on other Macs, or a new complete capture-to-paste regression pass.


## 0.1.4 overlapping selectors (2026-10-15)

Found Mote 0.1.2 and Pluck 0.1.3 running concurrently from separate bundles with the same capture shortcut. The app registered Carbon hotkeys with options 0. Apple's installed CarbonEvents.h documents that this allows multiple applications to receive the same shortcut. The fix uses kEventHotKeyExclusive so only the owning app receives it; a conflicting exclusive registration uses the existing conflict message.

A real two-process regression test holds an exclusive shortcut, then calls the production registration method. Version 0.1.3 incorrectly reports success; the corrected conventional and generated runtime builds both report a conflict, then successfully register after the holder exits. The test emits no keyboard input and does not write user preferences. The release workflow runs it before OCR verification.

Closed the old Mote process and restarted the compact Pluck 0.1.4 build. One drag completed a screen capture, recognized 66 characters in 0.48 seconds, closed the selector, and copied the expected text to the system clipboard. Inspected the actual result window and checked that only the Pluck process remained. The automation sends app-bound keyboard input, so it did not reproduce the original physical global-key event dispatch to both old processes.

All 18 OCR checks passed for both builds. Strict code-signature and ZIP extraction checks passed. The local compact bundle remains 59,267 bytes with a 56,624-byte executable, exactly unchanged from 0.1.3. User text and clipboard were backed up for testing and restored before final relaunch.
