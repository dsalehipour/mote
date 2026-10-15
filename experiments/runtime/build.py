#!/usr/bin/env python3
"""Build the experimental runtime-registered version without changing Pluck.app."""
from pathlib import Path
import json
import runpy
import struct

here = Path(__file__).resolve().parent
root = here.parents[1]
runpy.run_path(str(here/'generate.py'), run_name='__main__')
script = (root/'build.py').read_text()
flag = "'-Wl,-objc_stubs_small',"
assert script.count(flag) == 1, 'Review the canonical build flags before generating this experiment.'
script = script.replace(flag, flag + " '-Wl,-const_selrefs',")
script_path = here/'build/build.py'
script_path.write_text(script)
runpy.run_path(str(script_path), run_name='__main__')

binary = here/'build/Pluck.app/Contents/MacOS/Pluck'
data = binary.read_bytes()
assert struct.unpack_from('<I', data)[0] == 0xfeedfacf
commands = struct.unpack_from('<I', data, 16)[0]
offset = 32
segments = []
for _ in range(commands):
    command, size = struct.unpack_from('<II', data, offset)
    if command == 0x19:
        name = data[offset+8:offset+24].split(b'\0')[0].decode()
        file_bytes = struct.unpack_from('<Q', data, offset+48)[0]
        flags = struct.unpack_from('<I', data, offset+68)[0]
        segments.append(dict(name=name, file_bytes=file_bytes, flags=flags))
    offset += size
assert any(s['name']=='__DATA_CONST' and s['flags'] & 0x10 for s in segments), 'Constant-data protection must stay enabled.'
assert all(s['file_bytes']==0 for s in segments if s['name']=='__DATA'), 'Writable metadata returned: review generated classes/literals.'
(here/'build/layout.json').write_text(json.dumps(segments, indent=2)+'\n')
