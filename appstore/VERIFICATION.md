# App Store submission verification

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
- The privacy page was visually checked on desktop and mobile. Four 1280 × 800 RGB PNG screenshots frame actual native app windows, with no private screen content. Their local exports and Apple-rendered images were visually inspected. All four upload records and build 1.0 (6) persisted after reloading App Store Connect.

Measured artifact file bytes for this export:

| Artifact | Bytes |
| --- | ---: |
| Development archive's app | 142,929 |
| Distribution app extracted from package | 153,695 |
| Signed upload package | 96,649 |

Sizes exclude filesystem allocation, Apple-provided frameworks/models, and runtime memory. Apple may process or re-sign the app, changing its final storefront size.

The user's initial stumble immediately after macOS's second permission prompt was not reproduced with the now-approved permission. The change addresses the verified silent-ignore branch and activation handoff; it does not claim to reproduce every fresh-permission OS sequence. An actual App Store installation and Apple's review remain separate from these local checks.

Private review contact information and signing credentials are intentionally excluded from this repository. App Store Connect app ID: `6823632660`; title: `Pluck: Copy Screen Text`.

At 08:57 CDT on October 16, 2026, Xcode reported "Upload succeeded" and "EXPORT SUCCEEDED" for version 1.0 (6). Apple processed the build, and it is attached to version 1.0. Description, keywords, support/marketing URLs, review information, and manual release were saved and verified after reload.

## Submitted to App Review

At **10:24 AM CDT on October 16, 2026**, App Store Connect confirmed **1 Item Submitted**. The resulting review record shows macOS version **1.0 (6)** as **Waiting for Review**.

- Submission ID: `b64aca3b-eec2-4321-b6e5-9d92b070bfc6`.
- [App Store Connect review record](https://appstoreconnect.apple.com/apps/6823632660/distribution/reviewsubmissions/details/b64aca3b-eec2-4321-b6e5-9d92b070bfc6).
- Privacy policy and **Data Not Collected** declaration are published.
- Subtitle is **Copy text from your screen**; categories are **Productivity** and **Utilities**.
- Content rights are saved. The age-rating questionnaire is complete, with a calculated **4+** global rating and Apple's regional equivalents; no rating override or Made for Kids designation was selected.
- Free pricing and availability for all **175 countries or regions** are saved. Returning to Current Price showed zero price/proceeds in all 350 table cells.
- **Manual release after approval** remains selected. Submission does not mean approval or public availability.

App Information previously returned errors while loading age ratings and saving dependent fields. A fresh load after saving content rights allowed the questionnaire to complete; categories then saved, and Apple's submission validation passed. The cause of the earlier service errors was not established.

The final review page was visually inspected and a local confirmation capture saved as `work/apple-waiting-for-review.jpg`. The public GitHub release remains the existing experimental direct download; this submission does not replace or notarize that ZIP.

## Artwork exports

The warm, minimal artwork sources and four PNG exports live in `metadata/creative`. A 20.27-second, 1920 × 1080 H.264 motion study is included for local review; it is a screenshot animation, not a recorded walkthrough, and was not uploaded as an App Store preview.

An export mismatch initially gave JPEG files `.png` names, causing Apple processing errors. All affected exports and source captures were transcoded to actual PNG, verified by signature/format/dimensions, and the four failed listing assets were replaced. Corrected images rendered in Apple's gallery and remained after reload. The export manifest hashes and local artwork ZIP integrity also passed.
