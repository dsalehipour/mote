# Mote 0.1.0 verification

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
