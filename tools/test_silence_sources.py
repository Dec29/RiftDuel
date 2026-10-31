"""Check actual local original media against pinned source manifests; no placeholders."""
import hashlib
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
model = json.loads((root / 'assets/operators/silence/source_manifest.json').read_text(encoding='utf-8-sig'))
assert model['pinned_commit'] == '85f588ae805127ce93e8c47aa6dfcabc932f0a3e'
assert len(model['files']) == 6
for item in model['files']:
    raw = (root / item['file'].removeprefix('res://')).read_bytes()
    assert len(raw) == item['size'] and hashlib.sha256(raw).hexdigest().lower() == item['sha256'].lower()
    if item['file'].endswith('.skel'):
        assert b'3.8.99' in raw[:64]
    if item['file'].endswith('.atlas'):
        assert raw.lstrip().startswith(b'char_108_silent.png')
for category, count in [('cards', 2), ('audio/voices', 6)]:
    files = json.loads((root / f'assets/{category}/source_manifest.json').read_text())['files']
    actual = [item for item in files if item['operator_id'] == 'silence']
    assert len(actual) == count
    for item in actual:
        raw = (root / item['path']).read_bytes()
        assert len(raw) == item['bytes'] and hashlib.sha256(raw).hexdigest().lower() == item['sha256'].lower()
        if category == 'cards':
            assert raw.startswith(b'\x89PNG') and struct.unpack('>II', raw[16:24]) == (item['width'], item['height'])
        else:
            assert item['tag'] in ['023', '024', '025', '026', '027', '028']
sounds = json.loads((root / 'assets/audio/sfx/source_manifest.json').read_text())['files']
verified = [item for item in sounds if any(e.get('operator_id') == 'silence' for e in item['original_event_evidence'])]
assert len(verified) == 2
for item in verified:
    raw = (root / item['path']).read_bytes()
    assert hashlib.sha256(raw).hexdigest().lower() == item['sha256'].lower()
print('Silence: six original model files, two cards, six original voice clips and two event-mapped sounds verified')

model=json.loads((root/'assets/operators/medical_drone/source_manifest.json').read_text())
assert model['pinned_commit']=='85f588ae805127ce93e8c47aa6dfcabc932f0a3e' and len(model['files'])==3
for f in model['files']:
 raw=(root/f['file'].removeprefix('res://')).read_bytes()
 assert len(raw)==f['size'] and hashlib.sha256(raw).hexdigest()==f['sha256']
 if f['file'].endswith('.skel'):assert b'3.8.99' in raw[:64]
 if f['file'].endswith('.atlas'):assert raw.lstrip().startswith(b'token_10000_silent_healrb.png')
sounds=json.loads((root/'assets/audio/sfx/source_manifest.json').read_text())['files']
files=[f for f in sounds if any(e.get('operator_id')=='medical_drone' for e in f['original_event_evidence'])]
assert len(files)==1 and files[0]['id']=='b_char_tokenset'
assert hashlib.sha256((root/files[0]['path']).read_bytes()).hexdigest()==files[0]['sha256']
print('Actual medical drone original single skeleton/atlas/PNG and deployment cue SHA verified')
