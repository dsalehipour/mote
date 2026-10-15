#!/usr/bin/env python3
"""Exercise the shipped OCR implementation on text, blank and invalid inputs."""
import argparse
import json
import pathlib
import statistics
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--binary', type=pathlib.Path)
parser.add_argument('--report', type=pathlib.Path)
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
binary = args.binary or root / 'Pluck.app/Contents/MacOS/Pluck'
expected = 'Utility Profit\nRent: $1,250.00\nMote copies text from your screen.\n'
results = []
with tempfile.TemporaryDirectory(prefix='mote-tests-') as temp:
    directory = pathlib.Path(temp)
    generator = directory / 'fixtures'
    subprocess.run(['xcrun', 'clang', '-fobjc-arc', str(root/'tests/fixtures.m'),
                    '-framework', 'AppKit', '-o', str(generator)], check=True)
    subprocess.run([str(generator), str(directory)], check=True)
    for name in ['large', 'small-retina', 'dark']:
        elapsed = []
        for _ in range(5):
            start = time.perf_counter()
            run = subprocess.run([str(binary), '--ocr', str(directory/(name+'.png'))], capture_output=True, text=True)
            elapsed.append(time.perf_counter()-start)
            assert run.returncode == 0, (name, run.stderr)
            assert run.stdout == expected, (name, run.stdout)
        results.append({'case': name, 'passed': True, 'runs': len(elapsed),
                        'median_seconds': round(statistics.median(elapsed), 3),
                        'range_seconds': [round(min(elapsed), 3), round(max(elapsed), 3)]})
    (directory/'invalid.png').write_text('not an image')
    for name, code in [('blank', 3), ('invalid', 1), ('missing', 1)]:
        run = subprocess.run([str(binary), '--ocr', str(directory/(name+'.png'))], capture_output=True, text=True)
        assert run.returncode == code, (name, run.returncode, run.stderr)
        assert not run.stdout.strip(), (name, run.stdout)
        results.append({'case': name, 'passed': True, 'exit_code': code})
report = {'binary': str(binary), 'cases': results,
          'timing_scope': 'Fresh CLI process per run; includes process launch and OCR. OS caches may be warm. Synthetic fixtures, not a general accuracy benchmark.'}
if args.report:
    args.report.write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
