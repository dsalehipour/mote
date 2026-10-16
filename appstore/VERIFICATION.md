# App Store preparation verification

Checked October 16, 2026 with Xcode 26.6 (17F113), SDK 26.5, Apple Silicon.

- Release archive 1.0 (6) compiled without warnings or errors.
- Automatic export produced a Cloud Managed Apple Distribution app and a package signed with the team's 3rd Party Mac Developer Installer certificate.
- Strict code-signature verification passed for both the development archive and the app extracted from the distribution package.
- The distribution app contains App Sandbox and user-selected read-only file access, plus Apple's application/team identifiers. It contains no network, microphone, camera, or sandbox exception entitlement.
- All 18 OCR checks passed against the archived binary. Fresh CLI processes recognized the three synthetic fixtures with median launch-plus-OCR times of 0.251–0.254 seconds. These fixtures are not a general accuracy benchmark.
- Cross-process shortcut conflict detection and recovery passed in standard and compact implementations.
- Capture-recovery checks passed in both implementations: a repeat trigger reuses the existing selector, reactivation restores its focus, and a busy operation with no selector does not start another capture.
- The sandboxed image picker read a PNG outside the container, recognized its text, and saved the result inside the app container with mode 0600.
- A live screen selection recognized a two-line TextEdit sample on the first drag. Pasting into a fresh TextEdit document matched the 76-character result.
- The updated archive opened its selector from the shortcut and cancelled with Escape. Reopening restored the last result. There was only one running Pluck process after replacing the earlier test build.
- After granting screen permission, the user confirmed that one press of Command–Shift–2 from another app immediately brings up the crosshair in the updated build.
- The new privacy menu entry is present. The policy is published and its public URL returns the policy with HTTP 200 after a canonical URL redirect.
- The privacy page was visually checked on desktop and mobile. The store screenshot is a 1280 × 800 PNG framing an actual native app window, with no private screen content.

Measured artifact file bytes for this export:

| Artifact | Bytes |
| --- | ---: |
| Development archive's app | 142,929 |
| Distribution app extracted from package | 153,695 |
| Signed upload package | 96,649 |

Sizes exclude filesystem allocation, Apple-provided frameworks/models, and runtime memory. Apple may process or re-sign the app, changing its final storefront size.

The user's initial stumble immediately after macOS's second permission prompt was not reproduced with the now-approved permission. The change addresses the verified silent-ignore branch and activation handoff; it does not claim to reproduce every fresh-permission OS sequence. An actual App Store installation and Apple's review remain separate from these local checks.

Private review contact information and signing credentials are intentionally excluded from this repository. App Store Connect app ID: `6823632660`; title: `Pluck: Copy Screen Text`.
