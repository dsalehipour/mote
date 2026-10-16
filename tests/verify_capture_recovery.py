#!/usr/bin/env python3
"""Check the permission/focus handoff in both app implementations, without capture."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='pluck-recovery-') as temp:
    for variant, flags in [('standard', []), ('compact', ['-DCOMPACT'])]:
        binary = Path(temp) / variant
        subprocess.run(['xcrun', 'clang', '-arch', 'arm64', '-fobjc-arc',
                        '-Wno-deprecated-declarations', *flags,
                        str(root / 'tests/capture-recovery.m'),
                        '-framework', 'AppKit', '-framework', 'Vision',
                        '-framework', 'Carbon', '-framework', 'ScreenCaptureKit',
                        '-o', str(binary)], check=True)
        print(variant, flush=True)
        subprocess.run([str(binary)], check=True, timeout=30)
