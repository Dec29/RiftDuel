"""Verify the menu change and current summon/prop media against their registered fingerprints."""
from pathlib import Path
import json,hashlib,struct,re
ROOT=Path(__file__).resolve().parents[1]
def verify(path,record):
 raw=path.read_bytes()
 assert len(raw)==record.get('bytes',record.get('size')) and hashlib.sha256(raw).hexdigest().lower()==record['sha256'].lower(),str(path)
 return raw
summons=[]
for resource in sorted((ROOT/'resources/summons').glob('*.tres')):
 ident=re.search(r'^operator_id = "([^"]+)"',resource.read_text(encoding='utf-8'),re.M)[1]
 manifest=json.loads((ROOT/'assets/cards'/ident/'source_manifest.json').read_text(encoding='utf-8'))
 rows=[r for r in manifest['files'] if r['kind']=='avatar' and r['operator_id']==ident]
 assert len(rows)==1
 raw=verify(ROOT/rows[0]['path'],rows[0]);assert raw[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',raw[16:24])==(180,180)
 assert rows[0]['commit'] in rows[0]['url'] and rows[0]['char_id'] in rows[0]['url'];summons.append(ident)
music=json.loads((ROOT/'assets/audio/music/source_manifest.json').read_text(encoding='utf-8'))
rows=[r for r in music['files'] if r.get('original_id','').startswith('m_sys_act1multi_')]
assert {r['original_id'] for r in rows}=={'m_sys_act1multi_intro','m_sys_act1multi_loop'}
for row in rows:
 raw=verify(ROOT/row['path'],row);assert raw.startswith(b'OggS') and row['compressed_packets_byte_identical']
packfiles=0
for parent in ['ines_shadow','saileach_flag']:
 base=ROOT/'assets/battle/props'/parent;j=json.loads((base/'source_manifest.json').read_text(encoding='utf-8'))
 verify(base/'source_pack.json',dict(bytes=j['source_pack_bytes'],sha256=j['source_pack_sha256']))
 for row in j['textures']:verify(base/row['file'],row)
 for row in j['runtime_files']:verify(ROOT/row['path'].removeprefix('res://'),row);packfiles+=1
 assert not json.loads((base/'animation-binding-gaps.json').read_text())
j=json.loads((ROOT/'assets/operators/champagne_bottle/source_manifest.json').read_text(encoding='utf-8'))
for row in j['files']:
 raw=verify(ROOT/row['file'].removeprefix('res://'),row)
 if row['file'].endswith('.skel'):assert b'3.8.99' in raw[:64]
assert j['normal_blend_verified'] and j['animation_seconds']['single']['Attack']==.2
print('MEDIA_FINGERPRINTS_OK',len(summons),'current summon avatars, 2 native Vorbis music segments,',packfiles,'original mesh/cloth props, champagne skeleton/atlas/texture')
