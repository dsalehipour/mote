#!/usr/bin/env python3
"""Build an arm64-only app with the macOS Command Line Tools. No packages required."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time

root = Path(__file__).resolve().parent
app = root / 'Pluck.app'
contents = app / 'Contents'
binary = contents / 'MacOS' / 'Pluck'
binary.parent.mkdir(parents=True, exist_ok=True)
settings = {
    'CFBundleIdentifier': 'com.darius.mote',
    'CFBundleName': 'Pluck',
    'CFBundleDisplayName': 'Pluck',
    'CFBundleExecutable': 'Pluck',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '0.1.4',
    'CFBundleVersion': '5',
    'LSMinimumSystemVersion': '14.0',
    'LSUIElement': True,
    'NSHighResolutionCapable': True,
    'NSScreenCaptureUsageDescription': 'Pluck reads text only from screen areas you choose.',
}
with (contents / 'Info.plist').open('wb') as f:
    plistlib.dump(settings, f, fmt=plistlib.FMT_BINARY)

start = time.perf_counter()
opt = os.environ.get('OPTIMIZE', '-O3')
subprocess.run(['xcrun', 'clang', '-arch', 'arm64', '-mmacosx-version-min=14.0',
    opt, '-flto', '-fobjc-arc', '-fvisibility=hidden', '-Wall', '-Wextra',
    '-Wno-unused-parameter', '-Wno-deprecated-declarations',
    '-Wl,-dead_strip', '-Wl,-no_exported_symbols', '-Wl,-objc_stubs_small',
    str(root / 'Mote.m'), '-framework', 'AppKit', '-framework', 'Vision',
    '-framework', 'Carbon', '-framework', 'ScreenCaptureKit', '-o', str(binary)], check=True)
compile_seconds = time.perf_counter() - start
subprocess.run(['strip', '-u', '-r', str(binary)], check=True)
identity = os.environ.get('SIGN_IDENTITY', '-')
subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none',
    '--signature-size', os.environ.get('SIGNATURE_RESERVE', '2048'),
    '--identifier', settings['CFBundleIdentifier'], str(app)], check=True)
subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
metrics = {
    'version': settings['CFBundleShortVersionString'], 'architecture': 'arm64',
    'optimization': opt, 'signing': 'ad-hoc' if identity == '-' else 'local development certificate',
    'compile_seconds': round(compile_seconds, 3),
    'executable_bytes': binary.stat().st_size,
    'bundle_logical_bytes': sum(p.stat().st_size for p in app.rglob('*') if p.is_file()),
    'note': 'Uncompressed file bytes. OS frameworks/models and APFS allocation are separate.',
}
(root / 'build-metrics.json').write_text(json.dumps(metrics, indent=2) + '\n')
print(json.dumps(metrics, indent=2))
