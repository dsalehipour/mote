#!/usr/bin/env python3
"""Check real cross-process shortcut conflict detection and recovery in both builds.

Run experiments/runtime/build.py first. Uses Command-Shift-9 briefly; no key
presses are synthesized, no captures are made, and preferences are not written.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='pluck-hotkey-') as temp:
    for variant, flags in [('standard', []), ('compact', ['-DCOMPACT'])]:
        binary = Path(temp) / variant
        subprocess.run(['xcrun', 'clang', '-arch', 'arm64', '-fobjc-arc',
                        '-Wno-deprecated-declarations', *flags,
                        str(root / 'tests/hotkey-conflict.m'),
                        '-framework', 'AppKit', '-framework', 'Vision',
                        '-framework', 'Carbon', '-framework', 'ScreenCaptureKit',
                        '-o', str(binary)], check=True)
        print(variant, flush=True)
        subprocess.run([str(binary)], check=True, timeout=30)
