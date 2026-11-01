from pathlib import Path
import argparse,sys,json,hashlib,collections
parser=argparse.ArgumentParser(description='Audit selected original VFX prefabs and their dependency graph')
for name in ['client-root','parser-deps','lz4ak-source','cab-index','output']:parser.add_argument('--'+name,type=Path,required=True)
parser.add_argument('--bundle',required=True)
parser.add_argument('--prefab',action='append',required=True)
args=parser.parse_args()
OUT=args.output;OUT.mkdir(parents=True,exist_ok=True)
BASE=args.client_root/'StreamingAssets/AB/Windows';PATCH=args.client_root/'PersistentData/Bundles'
source=PATCH/args.bundle if (PATCH/args.bundle).is_file() else BASE/args.bundle
# Existing local UnityPy + audited Ark-Unpacker module; no install or client execution.
sys.path.insert(0,str(args.parser_deps))
import UnityPy
from UnityPy.helpers import CompressionHelper
from UnityPy.enums.BundleFile import CompressionFlags
block=args.lz4ak_source.read_bytes()
if hashlib.sha256(block).hexdigest()!='55832b28aefe510880bfcf54c0628138b0ee561b46b3fb8830f58fddadcd475a':
 raise ValueError('Unverified LZ4AK source; expected audited Ark-Unpacker 4a4b9ef module')
ns={}
exec(block.decode('utf8').replace('from ..utils.Profiler import CodeProfiler','from contextlib import nullcontext as CodeProfiler'),ns)
CompressionHelper.DECOMPRESSION_MAP[CompressionFlags.LZHAM]=ns['decompress_lz4ak']
env=UnityPy.load(str(source));assets={o.assets_file.name:o.assets_file for o in env.objects};objects={(o.assets_file.name,o.path_id):o for o in env.objects}
cab=next(o.assets_file.name for o in env.objects if o.type.name=='AssetBundle')
index=json.loads(args.cab_index.read_text(encoding='utf8'))

manifest=[];loaded={str(source)};missing=[];exports=OUT/'native';exports.mkdir(exist_ok=True)
def register(path):
 p=Path(path);rel=None
 for root in [PATCH,BASE]:
  try:rel=p.relative_to(root);break
  except ValueError:pass
 if rel:
  candidate=PATCH/rel
  p=candidate if candidate.exists() else BASE/rel
 key=str(p)
 if key in loaded:return
 loaded.add(key);e=UnityPy.load(key)
 for o in e.objects:assets[o.assets_file.name]=o.assets_file;objects[o.assets_file.name,o.path_id]=o
 manifest.append({'source':key,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
def resolve(cab,ref):
 if ref['m_PathID']==0:return None
 if ref['m_FileID']:
  external=assets[cab].externals[ref['m_FileID']-1].path;target=external.rsplit('/',1)[-1]
  if not target.startswith('CAB-'):
   if target not in ['unity default resources','unity_builtin_extra']:return ('builtin',external)
   if target not in assets:register(args.client_root/'Resources'/target)
   return (target,ref['m_PathID'])
  if target not in assets:
   if target in index:register(index[target])
   else:missing.append({'source':cab,'ref':ref,'target':target});return None
  cab=target
 key=(cab,ref['m_PathID'])
 if key not in objects:missing.append({'source':cab,'ref':ref});return None
 return key
bundle=next(o.read_typetree() for o in env.objects if o.type.name=='AssetBundle')
containers=dict(bundle['m_Container']);summaries=[];selected=set();materials={};shaders={};trails=[]
def refscan(value):
 if isinstance(value,dict):
  if 'm_FileID' in value and 'm_PathID' in value:yield value
  else:
   for v in value.values():yield from refscan(v)
 elif isinstance(value,(list,tuple)):
  for v in value:yield from refscan(v)
for name in args.prefab:
 root=containers['dyn/battle/prefabs/effects/'+name+'.prefab']['asset']['m_PathID'];rows=[]
 def visit(pid,parent='',active=True):
  g=objects[cab,pid].read_typetree();path=parent+'/'+g['m_Name'];active=active and g['m_IsActive'];components=[];transform=None
  selected.add((cab,pid))
  for r in g['m_Component']:
   key=resolve(cab,r['component'])
   if not key:continue
   obj=objects[key];t=obj.read_typetree();components.append({'id':obj.path_id,'type':obj.type.name,'tree':t});selected.add(key)
   if obj.type.name=='Transform':transform=t
   if obj.type.name=='TrailRenderer':trails.append({'prefab':name,'path':path,'tree':t})
  rows.append({'path':path,'active':active,'components':components})
  for tr in transform['m_Children']:visit(objects[cab,tr['m_PathID']].read_typetree()['m_GameObject']['m_PathID'],path,active)
 visit(root);summaries.append({'name':name,'nodes':rows})
# Explicit renderer dependencies only; shader bytecode, animation and materials retained.
queue=[]
for p in summaries:
 for n in p['nodes']:
  for c in n['components']:
   for ref in refscan(c['tree']):
    key=resolve(cab,ref)
    if key and key[0]!='builtin' and key not in selected:queue.append(key)
visited=set(selected)
while queue:
 key=queue.pop()
 if key in visited:continue
 visited.add(key);obj=objects[key];t=obj.read_typetree();typ=obj.type.name
 if typ=='Material':materials[str(key)]={'key':list(key),'tree':t}
 if typ=='Shader':shaders[str(key)]={'key':list(key),'name':t['m_ParsedForm']['m_Name'],'object':obj}
 dest=exports/key[0];dest.mkdir(exist_ok=True);(dest/(str(key[1])+'.json')).write_text(json.dumps({'type':typ,'tree':t},default=str,ensure_ascii=False),encoding='utf8')
 if typ=='Texture2D':obj.read().image.save(dest/(str(key[1])+'.png'))
 for ref in refscan(t):
  rkey=resolve(key[0],ref)
  if rkey and rkey[0]!='builtin' and rkey not in visited:queue.append(rkey)
manifest.insert(0,{'source':str(source),'bytes':source.stat().st_size,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
(OUT/'hierarchy.json').write_text(json.dumps(summaries,ensure_ascii=False,indent=2),encoding='utf8')
(OUT/'dependency-sources.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
(OUT/'missing-dependencies.json').write_text(json.dumps(missing,ensure_ascii=False,indent=2),encoding='utf8')
(OUT/'materials.json').write_text(json.dumps(materials,ensure_ascii=False,indent=2),encoding='utf8')
(OUT/'trails.json').write_text(json.dumps(trails,ensure_ascii=False,indent=2),encoding='utf8')
for key,s in shaders.items():
 obj=s['object'];name=s['name'];print('SHADER',key,name)
 try:(exports/(str(obj.path_id)+'.shader.txt')).write_text(obj.read().export(),encoding='utf8')
 except Exception as e:print('SHADER_EXPORT_ERROR',str(e))
print('DEPENDENCY_AUDIT',len(visited),'objects',len(materials),'materials',len(shaders),'shaders',len(missing),'missing',len(trails),'trails')
for p in summaries:
 counts=collections.Counter(c['type'] for n in p['nodes'] for c in n['components']);print(p['name'],len(p['nodes']),dict(counts))
 for n in p['nodes']:
  for c in n['components']:
   if c['type']=='ParticleSystem':print('PS',n['path'],'active',n['active'],[k for k,v in c['tree'].items() if isinstance(v,dict) and v.get('enabled')])
