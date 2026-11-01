from pathlib import Path
import argparse,sys,json,struct,zlib,math,shutil,hashlib,collections
parser=argparse.ArgumentParser(description='Export audited VFX to the shared Godot source-pack format')
for name in ['dependency-manifest','hierarchy','parser-deps','lz4ak-source','output']:parser.add_argument('--'+name,type=Path,required=True)
args=parser.parse_args()
ROOT=args.hierarchy.parent
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
from UnityPy.helpers.MeshHelper import MeshHandler
sources=json.loads(args.dependency_manifest.read_text(encoding='utf8'));objs={};assets={}
for row in sources:
 env=UnityPy.load(row['source'])
 for o in env.objects:objs[o.assets_file.name,o.path_id]=o;assets[o.assets_file.name]=o.assets_file
cab=next(o.assets_file.name for o in UnityPy.load(sources[0]['source']).objects if o.type.name=='AssetBundle');hier=json.loads(args.hierarchy.read_text(encoding='utf8'))
OUT=args.output;OUT.mkdir(parents=True,exist_ok=True);(OUT/'textures').mkdir(exist_ok=True)
def resolve(cab,ref):
 if not ref['m_PathID']:return None
 if ref['m_FileID']:cab=assets[cab].externals[ref['m_FileID']-1].path.rsplit('/',1)[-1]
 return (cab,ref['m_PathID'])
mats=[];matlookup={};textures=[]
def material(cab,ref):
 key=resolve(cab,ref)
 if key in matlookup:return matlookup[key]
 obj=objs[key];m=obj.read_typetree();p=m['m_SavedProperties'];shader=objs[resolve(key[0],m['m_Shader'])].read_typetree();floats=dict(p['m_Floats']);texs={}
 for name,tex in p['m_TexEnvs']:
  tk=resolve(key[0],tex['m_Texture'])
  if not tk:continue
  fn=tk[0]+'_'+str(tk[1])+'.png';target=OUT/'textures'/fn
  if not target.exists():objs[tk].read().image.save(target)
  texs[name]={'file':'textures/'+fn,'scale':[tex['m_Scale'][a] for a in 'xy'],'offset':[tex['m_Offset'][a] for a in 'xy']}
 state=shader['m_ParsedForm']['m_SubShaders'][0]['m_Passes'][0]['m_State']['rtBlend0'];blend={k:floats.get(v['name'],v['val']) for k,v in state.items()}
 entry={'name':m['m_Name'],'shader':shader['m_ParsedForm']['m_Name'],'floats':floats,'colors':dict(p['m_Colors']),'textures':texs,'blend':blend,'source':[key[0],str(key[1])],'keywords':m['m_ValidKeywords']}
 matlookup[key]=len(mats);mats.append(entry);return len(mats)-1
def decode_clip(t):
 data=t['m_MuscleClip']['m_Clip']['data'];s=data['m_StreamedClip'];raw=struct.pack('<'+'I'*len(s['data']),*s['data']);curves={};offset=0
 while offset<len(raw):
  tm,count=struct.unpack_from('<fI',raw,offset);offset+=8
  for _ in range(count):
   index,*coeff=struct.unpack_from('<Iffff',raw,offset);offset+=20
   curves.setdefault(str(index),[]).append([max(-1e20,min(1e20,tm)),coeff])
 assert data['m_DenseClip']['m_CurveCount']==0
 bindings=[];ch=0
 for b in t['m_ClipBindingConstant']['genericBindings']:
  count=(4 if b['attribute']==2 else 3) if b['typeID']==4 else 1
  bindings.append({'path':b['path'],'type':b['typeID'],'attribute':b['attribute'],'channel':ch,'count':count});ch+=count
 constants=data['m_ConstantClip']['data'];assert ch==s['curveCount']+len(constants)
 return {'name':t['m_Name'],'duration':t['m_MuscleClip']['m_StopTime'],'loop':t['m_MuscleClip']['m_LoopTime'],'cycle_offset':t['m_MuscleClip']['m_CycleOffset'],'stream_count':s['curveCount'],'curves':curves,'constants':constants,'bindings':bindings}
def decode_legacy(t):
 # Preserve legacy component curves as the same polynomial channels used by streamed clips.
 assert not t['m_CompressedRotationCurves'] and not t['m_PPtrCurves']
 curves={};bindings=[];channel=0;duration=0.0
 def add(path,typ,attribute,rows,components,prop=None):
  nonlocal channel,duration
  binding={'path':zlib.crc32(path.encode()),'type':typ,'attribute':attribute,'channel':channel,'count':len(components)}
  if prop:binding['property']=prop
  bindings.append(binding)
  for component in components:
   keys=[]
   for i,key in enumerate(rows):
    assert key.get('weightedMode',0)==0,'Weighted legacy tangents require explicit support'
    tm=float(key['time']);duration=max(duration,tm)
    scalar=lambda value:float(value[component]) if component else float(value)
    v=scalar(key['value']);coeff=[0.,0.,0.,v]
    if i+1<len(rows):
     nxt=rows[i+1];dt=float(nxt['time'])-tm;m0=scalar(key['outSlope']);m1=scalar(nxt['inSlope']);v1=scalar(nxt['value'])
     if dt>0 and math.isfinite(m0) and math.isfinite(m1):coeff=[(2*v-2*v1+dt*(m0+m1))/dt**3,(-3*v+3*v1-dt*(2*m0+m1))/dt**2,m0,v]
    keys.append([tm,coeff])
   curves[str(channel)]=keys;channel+=1
 for field,attribute,axes in [('m_RotationCurves',2,'xyzw'),('m_PositionCurves',1,'xyz'),('m_ScaleCurves',3,'xyz'),('m_EulerCurves',4,'xyz')]:
  for entry in t[field]:add(entry['path'],4,attribute,entry['curve']['m_Curve'],axes)
 for entry in t['m_FloatCurves']:
  name=entry['attribute'];prop=None
  if name.startswith('material.'):
   parts=name.split('.')[1:];assert len(parts)<=2
   prop=['colors',parts[0],'rgba'.index(parts[1])] if len(parts)==2 else ['floats',parts[0],0]
  else:assert name=='m_IsActive','Unmapped legacy property '+name
  add(entry['path'],entry['classID'],zlib.crc32(name.encode()),entry['curve']['m_Curve'],[None],prop)
 return {'name':t['m_Name'],'duration':duration,'loop':t['m_WrapMode']==2,'cycle_offset':0.,'stream_count':channel,'curves':curves,'constants':[],'bindings':bindings,'source_legacy':True}

def mesh_payload(cab,ref):
 key=resolve(cab,ref);mh=MeshHandler(objs[key].read());mh.process();points=[];uv=[];colors=[];normals=[]
 for submesh in mh.get_triangles():
  for tri in submesh:
   for ix in tri:
    points.append(mh.m_Vertices[ix]);uv.append(mh.m_UV0[ix][:2]);colors.append(mh.m_Colors[ix] if mh.m_Colors else [1,1,1,1]);normals.append(mh.m_Normals[ix])
 return {'source':[key[0],str(key[1])],'vertices':points,'uv':uv,'colors':colors,'normals':normals}
pack=[];unknown=[];unbound=[]
for prefab in hier:
 nodes=[];meshes=[];trails=[];clips=[];particles=[]
 # Unity permits identical sibling names; retain object identity instead of overwriting poses.
 siblings=collections.Counter((c['tree']['m_Father']['m_PathID'],n['path'].rsplit('/',1)[-1]) for n in prefab['nodes'][1:] for c in n['components'] if c['type']=='Transform')
 transform_paths={}
 for index,n in enumerate(prefab['nodes']):
  component=next(c for c in n['components'] if c['type']=='Transform');tr=component['tree'];parent=transform_paths.get(tr['m_Father']['m_PathID'],'');leaf=n['path'].rsplit('/',1)[-1]
  if siblings[tr['m_Father']['m_PathID'],leaf]>1:leaf+='@'+str(component['id'])
  transform_paths[component['id']]=('' if index==0 else (parent+'/'+leaf if parent else leaf))
 for n in prefab['nodes']:
  comps={c['type']:c['tree'] for c in n['components']};tr=comps['Transform'];component=next(c for c in n['components'] if c['type']=='Transform');path=transform_paths[component['id']]
  source_path=n['path'].split('/',2)[2] if n['path'].count('/')>=2 else ''
  nodes.append({'path':path,'source_path':source_path,'hash':zlib.crc32(path.encode()),'parent':transform_paths.get(tr['m_Father']['m_PathID'],''), 'pos':[tr['m_LocalPosition'][a] for a in 'xyz'],'rot':[tr['m_LocalRotation'][a] for a in 'xyzw'],'scale':[tr['m_LocalScale'][a] for a in 'xyz'],'active':bool(n['active'])})
  if 'Animator' in comps:
   ctrl=objs[resolve(cab,comps['Animator']['m_Controller'])].read_typetree()
   for ref in ctrl['m_AnimationClips']:
    clip=decode_clip(objs[resolve(cab,ref)].read_typetree());clip['binding_root']=path;clips.append(clip)
  if 'Animation' in comps and comps['Animation']['m_PlayAutomatically']:
   clip=decode_legacy(objs[resolve(cab,comps['Animation']['m_Animation'])].read_typetree());clip['binding_root']=path;clips.append(clip)
  if 'ParticleSystem' in comps and comps['ParticleSystem']['EmissionModule']['enabled'] and comps['ParticleSystemRenderer']['m_Enabled']:
   renderer=comps['ParticleSystemRenderer']
   trail_only=renderer['m_RenderMode']==5
   if trail_only:
    assert comps['ParticleSystem']['TrailModule']['enabled'] and len(renderer['m_Materials'])>1 and renderer['m_Materials'][1]['m_PathID'], 'None renderer has no supported visible trail material'
   particles.append({'path':path,'active':bool(n['active']),'particle':comps['ParticleSystem'],'renderer':renderer,'material':material(cab,renderer['m_Materials'][1 if trail_only else 0])})
   if trail_only:particles[-1]['render_particles']=False
   if comps['ParticleSystem']['TrailModule']['enabled']:
    particles[-1]['particle_trail_material']=material(cab,renderer['m_Materials'][1])
   if renderer['m_RenderMode']==4:particles[-1]['mesh']=mesh_payload(cab,renderer['m_Mesh'])
   if comps['ParticleSystem']['ShapeModule']['enabled'] and comps['ParticleSystem']['ShapeModule']['type']==6:
    particles[-1]['shape_mesh']=mesh_payload(cab,comps['ParticleSystem']['ShapeModule']['m_Mesh'])
   if comps['ParticleSystem']['SubModule']['enabled']:
    links=[]
    for sub in comps['ParticleSystem']['SubModule']['subEmitters']:
     assert sub['emitter']['m_FileID']==0 and sub['type']==0 and sub['properties']==0, 'Only audited local birth sub-emitters without inheritance are supported'
     target=next(nn for nn in prefab['nodes'] if any(cc['type']=='ParticleSystem' and cc['id']==sub['emitter']['m_PathID'] for cc in nn['components']))
     tt=next(cc for cc in target['components'] if cc['type']=='Transform')
     links.append({'path':transform_paths[tt['id']],'type':sub['type'],'properties':sub['properties'],'probability':sub['emitProbability']})
    particles[-1]['sub_emitters']=links

  if 'MeshRenderer' in comps and comps['MeshRenderer']['m_Enabled']:
   renderer=comps['MeshRenderer'];mesh_key=resolve(cab,comps['MeshFilter']['m_Mesh']);mesh=objs[mesh_key].read();mh=MeshHandler(mesh);mh.process();points=[];uv=[];colors=[]
   for tri in mh.get_triangles()[0]:
    for ix in tri:
     points.append(mh.m_Vertices[ix]);uv.append(mh.m_UV0[ix][:2]);colors.append(mh.m_Colors[ix] if mh.m_Colors else [1,1,1,1])
   meshes.append({'source':[mesh_key[0],str(mesh_key[1])],'path':path,'vertices':points,'uv':uv,'colors':colors,'material':material(cab,renderer['m_Materials'][0]),'sort':renderer['m_SortingOrder']})
  if 'SkinnedMeshRenderer' in comps:
   renderer=comps['SkinnedMeshRenderer'];key=resolve(cab,renderer['m_Mesh']);mesh=objs[key].read();mh=MeshHandler(mesh);mh.process()
   assert not renderer['m_BlendShapeWeights'],'Blend shapes require explicit support'
   transforms=transform_paths
   bones=[]
   for ref in renderer['m_Bones']:
    assert ref['m_FileID']==0 and ref['m_PathID'] in transforms,'Skin bone outside restored hierarchy'
    bones.append(transforms[ref['m_PathID']])
   assert len(bones)==len(mesh.m_BindPose) and len(renderer['m_Materials'])==1
   bindposes=[[getattr(matrix,'e'+str(r)+str(c)) for r in range(4) for c in range(4)] for matrix in mesh.m_BindPose]
   indices=mh.m_BoneIndices;weights=mh.m_BoneWeights
   if weights is None:
    assert all(len(row)==1 for row in indices),'Only single-index optimized skins have implicit unit weights'
    weights=[[1.] for row in indices]
   points=[];uv=[];colors=[];influences=[]
   for submesh in mh.get_triangles():
    for tri in submesh:
     for ix in tri:
      assert len(indices[ix])==len(weights[ix]) and abs(sum(weights[ix])-1.)<.001
      influence=[[int(b),float(w)] for b,w in zip(indices[ix],weights[ix]) if w>0]
      assert all(0<=b<len(bones) for b,w in influence)
      points.append(mh.m_Vertices[ix]);uv.append(mh.m_UV0[ix][:2]);colors.append(mh.m_Colors[ix] if mh.m_Colors else [1,1,1,1]);influences.append(influence)
   meshes.append({'source':[key[0],str(key[1])],'path':path,'vertices':points,'uv':uv,'colors':colors,'skin':{'bones':bones,'bindposes':bindposes,'influences':influences},'material':material(cab,renderer['m_Materials'][0]),'sort':renderer['m_SortingOrder']})
  if 'TrailRenderer' in comps and n['active'] and comps['TrailRenderer']['m_Enabled']:
   trail=comps['TrailRenderer'];trails.append({'path':path,'material':material(cab,trail['m_Materials'][0]),'sort':trail['m_SortingOrder'],'lifetime':trail['m_Time'],'min_distance':trail['m_MinVertexDistance'],'parameters':trail['m_Parameters']})
  for component in n['components']:
   script=component['tree']
   if component['type']=='MonoBehaviour' and 'xspeed' in script:
    restored=[m for m in meshes+particles+trails if m['path']==path]
    if not restored and any(k in comps and not comps[k]['m_Enabled'] for k in ['MeshRenderer','ParticleSystemRenderer','TrailRenderer']):continue # Source-disabled renderer; original script remains in hierarchy evidence.
    assert len(restored)==1,'UV driver has no single restored renderer: '+prefab['name']+'/'+path
    driver={'speed':[script['xspeed'],script['yspeed']],'keep_initial_offset':bool(script['keepInitOffset']),'shared_material':bool(script['useSharedMaterial'])}
    if 'protectMainUV' in script:
     if script['protectMainUV']:driver['protected_main']=True
     if script['useSecondMap']:driver['secondary']={'name':script['secondMapName'],'speed':[script['secondXSpeed'],script['secondYSpeed']],'protected':bool(script['protectSecondUV'])}
    else:
     assert script['m_Script']['m_PathID']==1369540917083035942 and not script['extraMapSettings'],'Unmapped UV driver schema'
     driver['source_tween']={'repeat':script['tweenRepeat'],'seconds':script['tweenAnmTime'],'adaptation':'Continuous-speed approximation; original tween reset/easing unverified'}
     if script['useSecondMap']:driver['secondary']={'name':script['secondMapName'],'speed':[script['secondXSpeed'],script['secondYSpeed']]}
    restored[0]['uv_scroll']=driver
 for clip in clips:
  root=clip.pop('binding_root','')
  source_root=next(n['source_path'] for n in nodes if n['path']==root)
  relative={}
  for n in nodes:
   if root and n['path']!=root and not n['path'].startswith(root+'/'):continue
   local=n['source_path'][len(source_root)+1:] if source_root and n['path']!=root else ('' if source_root else n['source_path'])
   relative.setdefault(zlib.crc32(local.encode()),[]).append(n['hash'])
  bound=[]
  for b in clip['bindings']:
   if b['path'] not in relative:
    unbound.append({'prefab':prefab['name'],'clip':clip['name'],'animator_path':root,'binding':b,'reason':'Source clip target absent from this prefab animator subtree; Unity has no target to bind.'});continue
   assert len(relative[b['path']])==1,'Ambiguous original animation binding to same-named siblings; cannot guess '+prefab['name']+' '+str(b)
   if root or relative[b['path']][0]!=b['path']:b['source_path']=b['path'];b['path']=relative[b['path']][0]
   bound.append(b)
  clip['bindings']=bound
  for b in clip['bindings']:
   if b['type'] in [4,1]:continue
   if b.get('property'):continue
   if b['type']==198 and b['attribute']==zlib.crc32(b'ShapeModule.radius.value'):
    b['property']=['particle','ShapeModule.radius.value',0];continue
   if b['type']==96 and b['attribute']==zlib.crc32(b'm_Parameters.widthMultiplier'):b['property']=['trail','widthMultiplier',0];continue
   applicable=[x for x in meshes+trails+particles if zlib.crc32(x['path'].encode())==b['path']]
   if not applicable:unknown.append({'prefab':prefab['name'],'binding':b,'reason':'Not a restored renderer binding'});continue
   mat=mats[applicable[0]['material']];prop=b['attribute']&0xfffffff;component=(b['attribute']>>28)&15;found=None
   for category in ['colors','floats','textures']:
    for name in mat[category]:
     if (zlib.crc32(name.encode())&0xfffffff)==prop or category=='textures' and (zlib.crc32((name+'_ST').encode())&0xfffffff)==prop:found=[category,name,component]
   if found:b['property']=found
   else:unknown.append({'prefab':prefab['name'],'binding':b,'reason':'Unmapped property; not silently applied'})
 pack.append({'name':prefab['name'],'nodes':nodes,'meshes':meshes,'trails':trails,'clips':clips,'particles':particles})
(OUT/'unbound-source-bindings.json').write_bytes(json.dumps(unbound,indent=2).encode('utf8'))
(OUT/'animation-binding-gaps.json').write_text(json.dumps(unknown,indent=2),encoding='utf8')
required=[]
for pref in hier:
 for node in pref['nodes']:
  for c in node['components']:
   if c['type']!='ParticleSystem':continue
   for module,feature in [('TrailModule','particle_trails'),('SubModule','birth_sub_emitters')]:
    if c['tree'][module]['enabled']:required.append({'prefab':pref['name'],'path':node['path'],'feature':feature,'component_id':str(c['id'])})
(OUT/'source_pack.json').write_text(json.dumps({'prefabs':pack,'materials':mats,'required_component_adapters':required},ensure_ascii=False),encoding='utf8')

source_rows=[]
for row in sources:
 p=Path(row['source']);data=p.read_bytes()
 if len(data)!=row['bytes'] or hashlib.sha256(data).hexdigest()!=row['sha256']:raise ValueError('Changed source bundle '+str(p))
 source_rows.append(row)
media=[]
for path in sorted((OUT/'textures').glob('*.png')):
 cab_id,pid=path.stem.rsplit('_',1)
 media.append({'file':'textures/'+path.name,'original_cab':cab_id,'original_path_id':pid,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
prefabs=[]
for prefab in hier:
 tr=next(c['tree'] for c in prefab['nodes'][0]['components'] if c['type']=='Transform')
 prefabs.append({'name':prefab['name'],'original_cab':cab,'game_object_path_id':str(tr['m_GameObject']['m_PathID'])})
manifest={'copyright':'Arknights / Hypergryph and respective rightsholders. Local non-commercial fan-project testing is not a new license. Repository code license does not cover game art.','sources':source_rows,'prefabs':prefabs,'textures':media,'source_pack_bytes':(OUT/'source_pack.json').stat().st_size,'source_pack_sha256':hashlib.sha256((OUT/'source_pack.json').read_bytes()).hexdigest(),'decoder':{'unitypy':'1.25.4','unpacker_commit':'4a4b9efc6be4690b68b70b4a16578950baa066d3','lz4ak_source_sha256':hashlib.sha256(block).hexdigest()},'animation_binding_gaps':unknown}
(OUT/'source_manifest.json').write_bytes(json.dumps(manifest,ensure_ascii=False,indent=2).encode('utf8'))
print('SOURCE_PACK_OK',len(pack),'prefabs',len(mats),'materials',len(media),'textures','binding gaps',len(unknown))
if unknown:raise SystemExit(1)
