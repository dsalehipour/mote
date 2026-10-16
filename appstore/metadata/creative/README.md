# Pluck App Store artwork

The [generated-v2 concepts](generated-v2/README.md) explore a new direction focused on extracting text from photos, paused videos, and scanned pages. They are pending review and have not replaced the submitted screenshots below.

Four 1280 × 800 screenshots use the marketing site's warm ivory, green, and blue palette. The Pluck windows are unaltered captures of the actual signed 1.0 (6) app recognizing the included sample image. They are placed in HTML compositions with headlines and contextual graphics.

- `exports/01-copy-the-uncopyable.png`: primary product screenshot.
- `exports/02-image-to-text.png`: original image and real OCR result.
- `exports/03-one-shortcut.png`: shortcut and reusable last result.
- `exports/04-on-your-mac.png`: local recognition and privacy.
- `index.html`: local review gallery with full-size links.
- `screenshots.html?shot=1` through `?shot=4`: editable composition sources.
- `sample.html`, `assets/sample.png`: original artwork recognized by Pluck.
- `assets/pluck-import.png`, `assets/pluck-result.png`: native app captures.

Serve this folder with a local static server and render each composition at exactly 1280 × 800. Verify the browser's actual viewport dimensions after opening a new tab. Inspect every exported PNG before uploading it. Screenshot APIs may return JPEG bytes; verify the file signature and transcode to actual RGB PNG when needed. Every submitted PNG must begin with the standard PNG signature and have the expected 1280 × 800 dimensions.

## Motion study

`exports/pluck-motion-study.mp4` is a 20.27-second, 1920 × 1080, 30 fps H.264 animation of the four screenshot compositions. It has no audio. Regenerate it with `./render-motion-preview.sh` (requires FFmpeg).

This is a marketing motion study, **not a screen-recorded walkthrough**. It is not included in the App Store video upload. A separate App Store preview needs a clean capture of the actual app interaction, following [Apple's preview guidance](https://developer.apple.com/app-store/app-previews/) and [technical specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/).

The screenshots and review gallery were visually inspected at their export size and at a 1440 × 900 desktop viewport. Native OCR recognized the sample image successfully; the rendered result is the observed output, including its punctuation normalization.
