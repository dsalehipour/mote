#!/usr/bin/env python3
"""Package a verified compact build under stable GitHub release asset names."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--tag', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
app = root / 'experiments/runtime/build/Mote.app'
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
version = info['CFBundleShortVersionString']
if args.tag != 'v' + version:
    raise SystemExit('Release tag must match the app version: v' + version)
subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
args.output.mkdir(parents=True, exist_ok=True)
archive = args.output / 'Mote-macOS-arm64.zip'
files = sorted(p for p in app.rglob('*') if p.is_file())
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for path in files:
        z.write(path, path.relative_to(app.parent))
with tempfile.TemporaryDirectory() as temp:
    subprocess.run(['ditto', '-x', '-k', str(archive), temp], check=True)
    extracted = Path(temp) / 'Mote.app'
    subprocess.run(['codesign', '--verify', '--strict', str(extracted)], check=True)
    for path in files:
        assert path.read_bytes() == (extracted / path.relative_to(app)).read_bytes()
metadata = {
    'version': version,
    'app_bytes': sum(p.stat().st_size for p in files),
    'executable_bytes': (app / 'Contents/MacOS/Mote').stat().st_size,
    'archive_bytes': archive.stat().st_size,
    'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
    'asset': archive.name,
    'architecture': 'arm64',
    'minimum_macos': info['LSMinimumSystemVersion'],
    'notarized': False,
}
(args.output / 'release.json').write_text(json.dumps(metadata, indent=2) + '\n')
(args.output / 'SHA256SUMS.txt').write_text(metadata['sha256'] + '  ' + archive.name + '\n')
notes = f'''Mote {version} is an experiment in making a tiny Mac app that is still practical. Press Command-Shift-2, drag around text, then paste its words anywhere. Recognition runs locally.

Download **{archive.name}** below. Unzip it, move Mote.app to Applications, and enable screen recording when prompted. Apple Silicon and macOS {metadata['minimum_macos']} or later are required.

This experimental build is **not notarized by Apple**. macOS may block first launch; only approve an app you trust through System Settings > Privacy & Security. No audio capture or Accessibility access is needed.

Complete app: **{metadata['app_bytes']:,} bytes ({metadata['app_bytes']/1024:.1f} KiB)**, including its code signature. macOS frameworks/models and runtime memory are separate. Download archive: {metadata['archive_bytes']:,} bytes.

Built from this tag with GitHub Actions, with strict signature verification, 18 OCR checks, and extraction/byte-comparison checks before publication. SHA-256 is provided in SHA256SUMS.txt. Stable download: https://github.com/dsalehipour/mote/releases/latest/download/{archive.name}

<!-- mote-release {json.dumps(metadata, separators=(',', ':'))} -->
'''
(args.output / 'release-notes.md').write_text(notes)
print(json.dumps(metadata, indent=2))
