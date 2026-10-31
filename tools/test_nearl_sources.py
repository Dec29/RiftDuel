"""Check actual local original media against pinned source manifests; no placeholders."""
import hashlib
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
model = json.loads((root / 'assets/operators/nearl/source_manifest.json').read_text(encoding='utf-8-sig'))
assert model['pinned_commit'] == '85f588ae805127ce93e8c47aa6dfcabc932f0a3e'
assert len(model['files']) == 6
for item in model['files']:
    raw = (root / item['file'].removeprefix('res://')).read_bytes()
    assert len(raw) == item['size'] and hashlib.sha256(raw).hexdigest().lower() == item['sha256'].lower()
    if item['file'].endswith('.skel'):
        assert b'3.8.99' in raw[:64]
    if item['file'].endswith('.atlas'):
        assert raw.lstrip().startswith(b'char_148_nearl.png')
for category, count in [('cards', 2), ('audio/voices', 6)]:
    files = json.loads((root / f'assets/{category}/source_manifest.json').read_text())['files']
    actual = [item for item in files if item['operator_id'] == 'nearl']
    assert len(actual) == count
    for item in actual:
        raw = (root / item['path']).read_bytes()
        assert len(raw) == item['bytes'] and hashlib.sha256(raw).hexdigest().lower() == item['sha256'].lower()
        if category == 'cards':
            assert raw.startswith(b'\x89PNG') and struct.unpack('>II', raw[16:24]) == (item['width'], item['height'])
        else:
            assert item['tag'] in ['023', '024', '025', '026', '027', '028']
sounds = json.loads((root / 'assets/audio/sfx/source_manifest.json').read_text())['files']
verified = [item for item in sounds if any(e.get('operator_id') == 'nearl' for e in item['original_event_evidence'])]
assert len(verified) == 5
for item in verified:
    raw = (root / item['path']).read_bytes()
    assert hashlib.sha256(raw).hexdigest().lower() == item['sha256'].lower()
print('Nearl: six original model files, two cards, six original voice clips and five event-mapped sounds verified')
