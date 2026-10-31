extends RefCounted
# Offline source-component sampler. Only the build tool evaluates Unity curves/particles.
const PPS := 1.0
const SAMPLE_STEP := 1.0/120.0
var pack: Dictionary
var asset_root: String
var phase:=0
var role: String
var time:=0.0
var facing:=0
var mirror:=false
var show_inactive:=false
var discard_invisible:=false
var apply_source_pivot:=true
var emission_seconds:=1.0
var sample_horizon:=3.0
var travel_units:=2.8
var attachment_offset:=Vector3.ZERO
var ground_plane:=false
var restore_prewarm:=false
var pose_cache: Dictionary={}
var texture_cache: Dictionary={}
var shader_cache: Dictionary={}
var material_cache: Dictionary={}
var geometry: Array[Dictionary]=[]
func v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func dict3(d: Dictionary) -> Vector3:
	return Vector3(d.x, d.y, d.z)

func col(d: Dictionary) -> Color:
	return Color(d.r, d.g, d.b, d.a)

func curve(c: Dictionary, t: float) -> float:
	var keys: Array = c.m_Curve
	if keys.is_empty(): return 0
	if t <= keys[0].time: return keys[0].value
	if t >= keys[-1].time: return keys[-1].value
	for i in keys.size() - 1:
		var a: Dictionary = keys[i]
		var b: Dictionary = keys[i+1]
		if t < a.time or t > b.time: continue
		if not is_finite(float(a.outSlope)): return a.value
		var dt: float = b.time - a.time
		var u: float = (t - a.time) / dt
		return (2*u*u*u-3*u*u+1)*a.value + (u*u*u-2*u*u+u)*dt*a.outSlope + (-2*u*u*u+3*u*u)*b.value + (u*u*u-u*u)*dt*b.inSlope
	return 0

func value(c: Dictionary, t: float = 0, r: float = 0.5) -> float:
	match int(c.minMaxState):
		0: return c.scalar
		1: return c.scalar * curve(c.maxCurve, t)
		2: return c.scalar * lerpf(curve(c.minCurve, t), curve(c.maxCurve, t), r)
		3: return lerpf(c.minScalar, c.scalar, r)
	push_error("Unknown MinMaxCurve mode"); return 0

func gradient(g: Dictionary, t: float) -> Color:
	var result := Color.WHITE
	for channel in 4:
		var prefix := "atime" if channel == 3 else "ctime"
		var count: int = g.m_NumAlphaKeys if channel == 3 else g.m_NumColorKeys
		var component: String = ["r", "g", "b", "a"][channel]
		var output: float = g["key0"][component]
		for i in count:
			var at: float = g[prefix + str(i)] / 65535.0
			output = g["key" + str(i)][component]
			if i == count-1 or t <= at: break
			var bt: float = g[prefix + str(i+1)] / 65535.0
			if t < bt:
				if int(g.get("m_Mode", 0)) == 1: break
				output = lerpf(output, g["key" + str(i+1)][component], (t-at)/maxf(0.000001,bt-at)); break
		result[channel] = output
	return result

func color_value(c: Dictionary, t: float, r: float) -> Color:
	match int(c.minMaxState):
		0: return col(c.maxColor)
		1: return gradient(c.maxGradient,t)
		2: return col(c.minColor).lerp(col(c.maxColor),r)
		3: return gradient(c.minGradient,t).lerp(gradient(c.maxGradient,t),r)
		4: return gradient(c.maxGradient,r)
	push_error("Unknown MinMaxGradient mode"); return Color.MAGENTA

func streamed(clip: Dictionary, channel: int, t: float) -> float:
	if channel >= int(clip.stream_count): return clip.constants[channel-int(clip.stream_count)]
	var keys: Array = clip.curves[str(channel)]
	var key: Array = keys[0]
	for candidate in keys:
		if candidate[0] > t: break
		key = candidate
	var dt: float = t-key[0]
	var c: Array = key[1]
	return ((c[0]*dt+c[1])*dt+c[2])*dt+c[3]

func sample_pose(f: Dictionary, t: float) -> Dictionary:
	var nodes: Dictionary = {}
	for node in f.nodes:
		nodes[int(node.hash)] = node.duplicate(true)
	var overrides: Dictionary = {}
	for clip in f.clips:
		var at: float = fposmod(t+clip.cycle_offset*clip.duration,clip.duration) if clip.loop else clampf(t,0,clip.duration)
		for b in clip.bindings:
			var path := int(b.path)
			if int(b.type) == 4:
				var dest: String = {1:"pos",2:"rot",3:"scale",4:"euler"}.get(int(b.attribute),"")
				if dest.is_empty(): push_error("Unknown transform binding"); continue
				var values: Array = []
				for i in int(b.count): values.append(streamed(clip,int(b.channel)+i,at))
				nodes[path][dest] = values
			elif int(b.type)==1 and int(b.attribute)==2086281974:
				nodes[path].active=streamed(clip,int(b.channel),at)>=.5
			elif b.has("property"):
				if not overrides.has(path): overrides[path] = []
				overrides[path].append([b.property,streamed(clip,int(b.channel),at)])
	var transforms: Dictionary = {}
	var by_path: Dictionary = {}
	var active_by_path: Dictionary = {}
	for node in f.nodes:
		var n: Dictionary = nodes[int(node.hash)]
		if not n.path.is_empty():
			n.active=n.active and active_by_path[n.parent]
		active_by_path[n.path]=n.active
		var q: Array = n.rot
		var basis := Basis(Quaternion(q[0],q[1],q[2],q[3]).normalized())
		if n.has("euler"):
			var e := v3(n.euler) * PI / 180
			# Unity ZXY Euler order.
			basis = Basis(Vector3.UP,e.y) * Basis(Vector3.RIGHT,e.x) * Basis(Vector3.BACK,e.z)
		var tr := Transform3D(basis.scaled_local(v3(n.scale)),v3(n.pos))
		if not n.path.is_empty(): tr = by_path[n.parent] * tr
		by_path[n.path] = tr
		transforms[n.path] = tr
	return {"nodes":nodes,"transforms":transforms,"overrides":overrides}

func get_texture(path: String) -> Texture2D:
	if not texture_cache.has(path): texture_cache[path] = load(asset_root+"/"+path)
	return texture_cache[path]

func renderer_edits(source: Dictionary, node_hash: int) -> Array:
	var edits: Array=pose_cache.overrides.get(node_hash,[]).duplicate(true)
	if source.has("uv_scroll"):
		var initial: Array=pack.materials[source.material].textures._MainTex.offset
		var dynamic_uv: bool=String(pack.materials[source.material].shader).begins_with("Torappu/Particles/Disturb/")
		for axis in 2:
			if dynamic_uv:edits.append([["scroll","main_velocity",axis],float(source.uv_scroll.speed[axis])])
			edits.append([["textures","_MainTex",axis+2],(0.0 if dynamic_uv else float(source.uv_scroll.speed[axis])*time)+(float(initial[axis]) if source.uv_scroll.keep_initial_offset else 0.0)])
		if source.uv_scroll.has("secondary"):
			var secondary: Dictionary=source.uv_scroll.secondary
			var second_initial: Array=pack.materials[source.material].textures[secondary.name].offset
			for axis in 2:
				if dynamic_uv:edits.append([["scroll","disturb_velocity",axis],float(secondary.speed[axis])])
				edits.append([["textures",secondary.name,axis+2],(0.0 if dynamic_uv else float(secondary.speed[axis])*time)+(float(second_initial[axis]) if source.uv_scroll.keep_initial_offset else 0.0)])
	return edits

func material_for(index: int, edits: Array) -> ShaderMaterial:
	var cache_key:=str(index)+JSON.stringify(edits)
	var fade:=clampf(1.0-(time-emission_seconds)/0.5,0,1) if role=="attached" and time>emission_seconds else 1.0
	cache_key+="/"+str(fade)
	if material_cache.has(cache_key): return material_cache[cache_key]
	var base: Dictionary = pack.materials[index].duplicate(true)
	for entry in edits:
		var prop: Array = entry[0]
		var v: float = entry[1]
		var component := int(prop[2]) % 4
		if prop[0] == "scroll":
			if not base.has(prop[1]):base[prop[1]]=Vector2.ZERO
			base[prop[1]][component]=v
		elif prop[0] == "floats": base.floats[prop[1]] = v
		elif prop[0] == "colors": base.colors[prop[1]][["r","g","b","a"][component]] = v
		elif prop[0] == "textures":
			base.textures[prop[1]]["scale" if component < 2 else "offset"][component%2] = v
	var mat := ShaderMaterial.new()
	var blend := "add" if int(base.blend.destBlend) == 1 else "mix"
	if base.shader=="Torappu/Particles/Mask/Mask (Add)":blend="mask_add"
	if base.shader=="Torappu/Particles/Disturb/Disturb Origin":blend="disturb_"+blend
	if base.shader=="Torappu/Particles/Disturb/Disturb Anchor":blend="disturb_anchor_"+blend
	if "UVTween" in base.shader:blend="uvtween_"+blend
	if base.shader=="Torappu/Particles/Dissolve/Dissolve Add Double":blend="double_add"
	if base.shader=="Torappu/Particles/Dissolve/Dissolve AB Double":blend="double_mix"
	if base.shader in ["Torappu/Particles/Disturb/Disturb(CustomData)","Torappu/Particles-L2D/Disturb/Disturb(CustomData)"]:
		assert(int(base.blend.srcBlend)==5 and int(base.blend.destBlend)==10,"Unverified CustomData blend path")
		assert(float(base.floats.get("_HGCustomVertexStream",0))==0,"Custom vertex stream requires its original extra UV attributes")
		blend="disturb_custom_mix"
	if base.shader=="Torappu/Particles/SimSpine/AlphaBlend-ZDistorted":blend="flag_mix"
	if not shader_cache.has(blend): shader_cache[blend] = load("res://assets/battle/vfx/native_" + blend + ".gdshader")
	mat.shader = shader_cache[blend]
	if blend.begins_with("disturb_") or blend.begins_with("uvtween_"):mat.set_meta("original_vfx_clock",true)
	var tint: Color=col(base.colors.get("_MainColor" if "/Disturb/" in base.shader else "_TintColor",{"r":1,"g":1,"b":1,"a":1}))
	if blend=="flag_mix":tint=col(base.colors._Color)
	mat.set_shader_parameter("tint",Vector4(tint.r,tint.g,tint.b,tint.a))
	mat.set_shader_parameter("amount",base.floats.get("_Amount",0))
	mat.set_shader_parameter("border",base.floats.get("_BorderWidth",0.1))
	mat.set_shader_parameter("channel",int(base.floats.get("_MainTexChannel",0)))
	mat.set_shader_parameter("premultiply",base.floats.get("_PremultiplyAlpha",5))
	mat.set_shader_parameter("mode",2 if "VertexColor Major" in base.shader else (1 if "Dissolve" in base.shader else 0))
	mat.set_shader_parameter("add_factor",base.floats.get("_AddFactor",0))
	mat.set_shader_parameter("intensity",Vector2(base.floats.get("_IntensityU",0),base.floats.get("_IntensityV",0)))
	for name in ["_MainTex", "_DissolveTex", "_MaskTex", "_AddTex", "_DisturTex", "_DisturbTex", "_DisturTex_02", "_WeightTex", "_DissolveTex_01", "_DissolveTex_02"]:
		if not base.textures.has(name): continue
		var tex: Dictionary = base.textures[name]
		var uniform_name: String={"_MainTex":"main","_DissolveTex":"dissolve","_MaskTex":"mask","_AddTex":"add","_DisturTex":"disturb","_DisturbTex":"disturb","_DisturTex_02":"disturb2","_WeightTex":"weight","_DissolveTex_01":"dissolve","_DissolveTex_02":"dissolve2"}[name]
		mat.set_shader_parameter(uniform_name+"_texture",get_texture(tex.file))
		mat.set_shader_parameter(uniform_name+"_st",Vector4(tex.scale[0],tex.scale[1],tex.offset[0],tex.offset[1]))
	if base.shader=="Torappu/Particles/Disturb/Disturb Anchor":
		mat.set_shader_parameter("anchor_uv",Vector2(base.floats._AnchorU,base.floats._AnchorV))
		mat.set_shader_parameter("anchor2_uv",Vector2(base.floats._AnchorU_02,base.floats._AnchorV_02))
		mat.set_shader_parameter("intensity2",Vector2(base.floats._IntensityU_02,base.floats._IntensityV_02))
		mat.set_shader_parameter("use_weight","_WEIGHT_ON" in base.keywords)
		mat.set_shader_parameter("use_disturb2",int(base.floats._ToggleUseDisturb2)>0)
		mat.set_shader_parameter("use_dissolve",int(base.floats._ToggleUseDissolve)>0)
		mat.set_shader_parameter("alpha_control",base.floats._MainColorACtrl)
		var velocity: Color=col(base.colors._UVTween)
		mat.set_shader_parameter("uv_tween",Vector4(velocity.r,velocity.g,velocity.b,velocity.a))
	if base.shader in ["Torappu/Particles/Dissolve/Dissolve Add Double","Torappu/Particles/Dissolve/Dissolve AB Double"]:
		mat.set_shader_parameter("amount",base.floats._Amount_01)
		mat.set_shader_parameter("border",base.floats._BorderWidth_01)
		mat.set_shader_parameter("amount2",base.floats._Amount_02)
		mat.set_shader_parameter("border2",base.floats._BorderWidth_02)
	if "UVTween" in base.shader:
		var speed: Color=col(base.colors._UVTween)
		mat.set_shader_parameter("uv_tween",Vector4(speed.r,speed.g,speed.b,speed.a))
	if blend=="flag_mix":mat.set_shader_parameter("cutoff",base.floats._Cutoff)
	if blend=="disturb_custom_mix":
		mat.set_shader_parameter("opacity",base.floats._Opacity)
		mat.set_shader_parameter("disturb_channel",int(base.floats._DisturbTexChannel))
		mat.set_shader_parameter("dissolve_channel",int(base.floats._DissolvTexChannel))
		mat.set_shader_parameter("disturb_scale",base.floats.get("_DisturbScale",1.0))
		mat.set_shader_parameter("disturb_dissolve",base.floats._DisturbInfluenceDissolveUV)
		mat.set_shader_parameter("main_speed",Vector2(base.floats._MainUSpeed,base.floats._MainVSpeed))
		mat.set_shader_parameter("dissolve_speed",Vector2(base.floats._DissolveUSpeed,base.floats._DissolveVSpeed))
		mat.set_shader_parameter("disturb_speed",Vector2(base.floats._DisturbUSpeed,base.floats._DisturbVSpeed))
	mat.set_shader_parameter("main_velocity",base.get("main_velocity",Vector2.ZERO))
	mat.set_shader_parameter("disturb_velocity",base.get("disturb_velocity",Vector2.ZERO))
	mat.set_shader_parameter("end_fade",fade)
	material_cache[cache_key]=mat
	return mat

func project_point(p: Vector3) -> Vector2:
	var center:=profile_motion(time) if role=="projectile" else Vector3.ZERO
	var source: Vector3=p-center+attachment_offset
	if ground_plane:source=Basis(Vector3.RIGHT,-PI/2)*source
	var at:=Basis(Vector3.UP,-facing*PI/2)*source
	if ground_plane:return Vector2(at.x,at.z)
	return Vector2(at.x,-at.y*0.8660254+at.z*0.5)

func profile_motion(t: float) -> Vector3:
	# Canonical straight flight, recorded in clip metadata; caller owns the true impact event.
	return Vector3(travel_units*clampf(t/emission_seconds,0,1),0,0) if role=="projectile" else Vector3.ZERO

func draw_geometry(source_key: String, points: PackedVector2Array, colors: PackedColorArray, uv: PackedVector2Array, mat: ShaderMaterial, order: int, indices: PackedInt32Array = PackedInt32Array()) -> void:
	if points.size() < 3: return
	if discard_invisible:
		var tint: Vector4=mat.get_shader_parameter("tint")
		if tint.w<=0.0 or float(mat.get_shader_parameter("end_fade"))<=0.0:return
		var any_alpha:=false
		for color in colors:
			if color.a>0.0:any_alpha=true;break
		if not any_alpha:return
	geometry.append({"points":points,"colors":colors,"uv":uv,"material":mat,"order":order,"source_key":source_key,"sequence":geometry.size()})
	if not indices.is_empty(): geometry[-1]["indices"]=indices

func sample_mesh(prefab_index: int, age_seconds: float, direction: int) -> Array[ArrayMesh]:
	phase=prefab_index
	time=age_seconds
	facing=direction
	geometry.clear()
	var f: Dictionary=pack.prefabs[phase]
	pose_cache=sample_pose(f,time)
	for m in f.meshes:
		var node: Dictionary
		for candidate in pose_cache.nodes.values():
			if candidate.path==m.path: node=candidate;break
		if not node.active:continue
		if role=="projectile" and time>=emission_seconds:continue
		var points:=PackedVector2Array()
		var colors:=PackedColorArray()
		var uv:=PackedVector2Array()
		var tr: Transform3D=pose_cache.transforms[m.path]
		var skin_transforms: Array[Transform3D]=[]
		if m.has("skin"):
			for bone_index in m.skin.bones.size():
				var b: Array=m.skin.bindposes[bone_index]
				var bind:=Transform3D(Basis(Vector3(b[0],b[4],b[8]),Vector3(b[1],b[5],b[9]),Vector3(b[2],b[6],b[10])),Vector3(b[3],b[7],b[11]))
				skin_transforms.append(pose_cache.transforms[m.skin.bones[bone_index]]*bind)
		for i in m.vertices.size():
			var world: Vector3=tr*v3(m.vertices[i])
			if m.has("skin"):
				world=Vector3.ZERO
				for influence in m.skin.influences[i]:world+=(skin_transforms[int(influence[0])]*v3(m.vertices[i]))*float(influence[1])
			points.append(project_point(world+profile_motion(time)))
			var c: Array=m.colors[i]
			colors.append(Color(c[0],c[1],c[2],c[3]))
			uv.append(Vector2(m.uv[i][0],m.uv[i][1]))
		draw_geometry("mesh:"+m.path,points,colors,uv,material_for(m.material,renderer_edits(m,int(node.hash))),int(m.sort))
	draw_trails(f)
	draw_particles(f)
	geometry.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return a.sequence<b.sequence if a.order==b.order else a.order<b.order)
	var layers: Array[ArrayMesh]=[]
	for row in geometry:
		var mesh:=ArrayMesh.new()
		var arrays:=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=row.points
		arrays[Mesh.ARRAY_COLOR]=row.colors
		arrays[Mesh.ARRAY_TEX_UV]=row.uv
		if row.has("indices"):arrays[Mesh.ARRAY_INDEX]=row.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,row.material)
		layers.append(mesh)
	return layers

func draw_trails(f: Dictionary) -> void:
	for trail in f.trails:
		var points3: Array[Vector3] = []
		var stamps: Array[float] = []
		var at := maxf(0,time-trail.lifetime)
		while at <= minf(time,emission_seconds) + 0.00001:
			var pose := sample_pose(f,at)
			var pos: Vector3 = pose.transforms[trail.path].origin + profile_motion(at)
			if points3.is_empty() or points3[-1].distance_to(pos) >= trail.min_distance:
				points3.append(pos); stamps.append(at)
			at += SAMPLE_STEP
		if points3.size() < 2: continue
		var node_hash := 0
		for n in f.nodes:
			if n.path == trail.path: node_hash = int(n.hash); break
		var edits: Array = renderer_edits(trail,node_hash)
		var width: float = trail.parameters.widthMultiplier
		for entry in edits:
			if entry[0][0] == "trail": width = entry[1]
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var uv := PackedVector2Array()
		var indices := PackedInt32Array()
		for i in points3.size():
			var center := project_point(points3[i])
			var tangent := project_point(points3[mini(i+1,points3.size()-1)])-project_point(points3[maxi(0,i-1)])
			var side := tangent.normalized().orthogonal()
			var age: float = (time-stamps[i])/trail.lifetime
			var w := curve(trail.parameters.widthCurve,age)*width*PPS*0.5
			var c := gradient(trail.parameters.colorGradient,age)
			for sign in [-1,1]:
				points.append(center+side*w*sign);colors.append(c)
				uv.append(Vector2(float(i)/(points3.size()-1),0 if sign<0 else 1))
			if i>0:
				var j:=i*2
				indices.append_array(PackedInt32Array([j-2,j-1,j,j,j-1,j+1]))
		draw_geometry("trail:"+trail.path,points,colors,uv,material_for(trail.material,edits),trail.sort,indices)

var particle_systems: Dictionary = {}
var particle_materials: Dictionary = {}
var sub_emitter_births:=0
var sampled_particle_trails:=0

func init_particles() -> void:
	var serial := 0
	for fi in pack.prefabs.size():
		var f: Dictionary = pack.prefabs[fi]
		for system in f.particles:
			var seed_value:=73100+serial
			serial+=1
			if fi!=phase:continue
			var key: String = str(fi)+":"+system.path
			particle_systems[key] = []
			particle_materials[key] = material_for(int(system.material),[])
			var source_node_hash:=0
			for node in f.nodes:
				if node.path==system.path:source_node_hash=int(node.hash);break
			var ps: Dictionary = system.particle
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var duration: float = ps.lengthInSec
			var delay := value(ps.startDelay,0,rng.randf())
			var cycles := int(ceil(sample_horizon/duration)) if ps.looping else 1
			var births: Array[float] = []
			for cycle in range(-1 if restore_prewarm and ps.prewarm and ps.looping else 0,cycles):
				var origin: float = delay+cycle*duration
				var accumulator := 0.0
				for step in int(ceil(duration/SAMPLE_STEP)):
					var at := step*SAMPLE_STEP
					accumulator += maxf(0,value(ps.EmissionModule.rateOverTime,at/duration))*SAMPLE_STEP
					while accumulator>=1:
						births.append(origin+at); accumulator-=1
				for burst in ps.EmissionModule.m_Bursts:
					if rng.randf() > burst.get("probability",1): continue
					for repeat in maxi(1,int(burst.get("cycleCount",1))):
						var at: float = origin+burst.time+repeat*burst.get("repeatInterval",0)
						var count := int(value(burst.countCurve,burst.time/duration,rng.randf()))
						for j in count: births.append(at)
			births.sort()
			for birth in births:
				if birth > minf(sample_horizon,emission_seconds): continue
				var r: Array[float] = []
				for j in 16: r.append(rng.randf())
				var birth_pose:=sample_pose(f,birth)
				var shape: Dictionary = ps.ShapeModule.duplicate(true)
				for edit in birth_pose.overrides.get(source_node_hash,[]):
					if edit[0][0]=="particle" and edit[0][1]=="ShapeModule.radius.value":shape.radius.value=edit[1]
				var pos := Vector3.ZERO
				var direction := Vector3.BACK
				var mesh_color:=Color.WHITE
				var phi := r[0]*TAU
				if shape.enabled:
					var radius: float = shape.radius.value
					match int(shape.type):
						0,1,2,3:
							var z: float = r[1]*2-1
							if int(shape.type) in [2,3]: z=absf(z)
							direction = Vector3(cos(phi)*sqrt(1-z*z),sin(phi)*sqrt(1-z*z),z)
							pos=direction*radius*pow(lerpf(pow(1-shape.radiusThickness,3),1,r[2]),1.0/3)
						4,8:
							var rad: float = sqrt(lerpf(pow(1-shape.radiusThickness,2),1,r[2]))
							pos=Vector3(cos(phi),sin(phi),0)*radius*rad
							var angle: float = deg_to_rad(shape.angle)*rad
							direction=Vector3(cos(phi)*sin(angle),sin(phi)*sin(angle),cos(angle))
						10,11:
							var arc_phi: float=r[0]*deg_to_rad(shape.arc.value)
							direction=Vector3(cos(arc_phi),sin(arc_phi),0)
							var radial: float=1.0 if int(shape.type)==11 else sqrt(lerpf(pow(1-shape.radiusThickness,2),1,r[2]))
							pos=direction*radius*radial
						6:
							assert(int(shape.placementMode)==2 and int(shape.m_MeshSpawn.mode)==0 and not shape.m_UseMeshMaterialIndex,"Unverified mesh emission mode")
							var mesh: Dictionary=system.shape_mesh
							var areas: Array[float]=[];var total:=0.0
							for tri in mesh.vertices.size()/3:
								total+=(v3(mesh.vertices[tri*3+1])-v3(mesh.vertices[tri*3])).cross(v3(mesh.vertices[tri*3+2])-v3(mesh.vertices[tri*3])).length()*.5;areas.append(total)
							assert(total>0,"Mesh emitter has no non-degenerate surface")
							var triangle:=0
							while triangle<areas.size()-1 and areas[triangle]<r[0]*total:triangle+=1
							var b:=sqrt(r[1]);var weights:=Vector3(1-b,b*(1-r[2]),b*r[2]);direction=Vector3.ZERO
							mesh_color=Color(0,0,0,0)
							for corner in 3:
								var index:=triangle*3+corner;pos+=v3(mesh.vertices[index])*weights[corner];direction+=v3(mesh.normals[index])*weights[corner]
								var mc: Array=mesh.colors[index];mesh_color+=Color(mc[0],mc[1],mc[2],mc[3])*weights[corner]
							direction=direction.normalized();pos+=direction*float(shape.m_MeshNormalOffset)
							if not shape.m_UseMeshColors:mesh_color=Color.WHITE
						5:
							pos=Vector3(r[0]-.5,r[1]-.5,r[2]-.5)
						15:
							# BoxShell; area-weight faces. A zero extent collapses to its rectangle.
							pos=Vector3(r[0]-.5,r[1]-.5,r[2]-.5)
							var size:=dict3(shape.m_Scale).abs()
							var areas:=Vector3(size.y*size.z,size.x*size.z,size.x*size.y)
							var pick: float=r[14]*(areas.x+areas.y+areas.z)
							var axis:=0 if pick<areas.x else (1 if pick<areas.x+areas.y else 2)
							pos[axis]=-.5 if r[15]<.5 else .5
						_:
							push_error("Unsupported source shape "+str(shape.type))
					var e := dict3(shape.m_Rotation)*PI/180
					var basis := Basis(Vector3.UP,e.y)*Basis(Vector3.RIGHT,e.x)*Basis(Vector3.BACK,e.z)
					pos=basis*(pos*dict3(shape.m_Scale))+dict3(shape.m_Position)
					direction=basis*direction
				var init: Dictionary = ps.InitialModule
				var tr: Transform3D = birth_pose.transforms[system.path]
				var world_space := int(ps.moveWithTransform)==1
				var velocity := direction*value(init.startSpeed,fmod(birth-delay,duration)/duration,r[3])
				if world_space:
					pos=tr*pos + (Vector3(travel_units*clampf(birth/emission_seconds,0,1),0,0) if fi==phase and role=="projectile" else Vector3.ZERO)
					velocity=tr.basis*velocity
				var life := maxf(0.001,value(init.startLifetime,fmod(birth-delay,duration)/duration,r[4]))
				particle_systems[key].append({"birth":birth,"life":life,"random":r,"positions":[pos],"velocities":[velocity],"velocity":velocity,"rotations":[0.0],"birth_transform":tr,"world":world_space,"mesh_color":mesh_color})

	init_birth_sub_emitters(pack.prefabs[phase])

func init_birth_sub_emitters(f: Dictionary) -> void:
	var systems: Dictionary={}
	for system in f.particles:systems[system.path]=system
	for parent in f.particles:
		for link in parent.get("sub_emitters",[]):
			assert(link.type==0 and link.properties==0 and link.probability==1.0,"Unverified sub-emitter event/inheritance/probability")
			var child: Dictionary=systems[link.path]
			assert(not child.particle.SubModule.enabled and child.particle.moveWithTransform==0,"Nested/world sub-emitter requires explicit support")
			var key: String=str(phase)+":"+child.path
			var templates: Array=particle_systems[key]
			assert(not templates.is_empty(),"Source birth sub-emitter has no burst template")
			var generated: Array=[]
			for source in particle_systems[str(phase)+":"+parent.path]:
				var birth: float=source.birth
				var pose:=sample_pose(f,birth)
				var parent_transform: Transform3D=pose.transforms[parent.path]
				var child_transform: Transform3D=pose.transforms[child.path]
				var position: Vector3=source.positions[0] if source.world else parent_transform*source.positions[0]
				for burst in child.particle.EmissionModule.m_Bursts:
					assert(burst.probability==1.0 and burst.cycleCount==1 and burst.time==0,"Unverified child burst schedule")
					var count:=int(value(burst.countCurve,0,.5))
					for i in count:
						var item: Dictionary=templates[generated.size()%templates.size()].duplicate(true)
						item.birth=birth;item.positions=[child_transform.affine_inverse()*position]
						item.velocities=[item.velocities[0]];item.velocity=item.velocities[0];item.rotations=[0.0]
						item.birth_transform=child_transform
						item.life=maxf(.001,value(child.particle.InitialModule.startLifetime,fposmod(birth,float(child.particle.lengthInSec))/float(child.particle.lengthInSec),item.random[4]))
						generated.append(item);sub_emitter_births+=1
			particle_systems[key]=generated

func trajectory(item: Dictionary, system: Dictionary, age: float) -> Dictionary:
	var ps: Dictionary = system.particle
	var r: Array = item.random
	var target := int(ceil(age/SAMPLE_STEP))
	var positions: Array = item.positions
	var rotations: Array = item.rotations
	var velocities: Array = item.velocities
	var velocity: Vector3 = item.velocity
	var birth_basis: Basis = item.birth_transform.basis
	while positions.size() <= target:
		var at: float = (positions.size()-0.5)*SAMPLE_STEP
		var u: float = at/item.life
		var force := Vector3.ZERO
		if ps.ForceModule.enabled:
			var fm: Dictionary=ps.ForceModule
			force=Vector3(value(fm.x,u,r[9]),value(fm.y,u,r[10]),value(fm.z,u,r[11]))
			if item.world and not fm.inWorldSpace: force=birth_basis*force
			elif not item.world and fm.inWorldSpace: force=birth_basis.inverse()*force
		force+=Vector3.DOWN*9.81*value(ps.InitialModule.gravityModifier,u,r[12])
		velocity+=force*SAMPLE_STEP
		var extra := Vector3.ZERO
		if ps.VelocityModule.enabled:
			var vm: Dictionary=ps.VelocityModule
			extra=Vector3(value(vm.x,u,r[9]),value(vm.y,u,r[10]),value(vm.z,u,r[11]))
			if item.world and not vm.inWorldSpace: extra=birth_basis*extra
			elif not item.world and vm.inWorldSpace: extra=birth_basis.inverse()*extra
		var total:=velocity+extra
		if ps.ClampVelocityModule.enabled:
			var cm: Dictionary=ps.ClampVelocityModule
			# Recorded approximation: source damping applied at a 60Hz-equivalent rate.
			var limit:=maxf(0,value(cm.magnitude,u,r[13]))
			var length:=total.length()
			if length>limit:
				total=total.normalized()*lerpf(length,limit,1-pow(1-float(cm.dampen),SAMPLE_STEP*60))
			velocity=total-extra
		positions.append(positions[-1]+total*SAMPLE_STEP)
		velocities.append(total)
		var angular:=0.0
		if ps.RotationModule.enabled: angular=value(ps.RotationModule.curve,u,r[7])
		rotations.append(rotations[-1]+angular*SAMPLE_STEP)
	item.velocity=velocity
	var sample_at:=age/SAMPLE_STEP
	var lower:=int(floor(sample_at))
	var upper:=mini(lower+1,positions.size()-1)
	return {"position":(positions[lower] as Vector3).lerp(positions[upper],sample_at-lower),"rotation":lerpf(rotations[lower],rotations[upper],sample_at-lower),"velocity":(velocities[lower] as Vector3).lerp(velocities[upper],sample_at-lower)}

func draw_particles(f: Dictionary) -> void:
	for system in f.particles:
		if not system.active: continue
		if system.particle.TrailModule.enabled:draw_particle_trails(f,system)
		if not system.get("render_particles",true):continue
		var ps: Dictionary=system.particle
		var renderer: Dictionary=system.renderer
		var init: Dictionary=ps.InitialModule
		var key: String=str(phase)+":"+system.path
		var points:=PackedVector2Array()
		var colors:=PackedColorArray()
		var uv:=PackedVector2Array()
		var indices:=PackedInt32Array()
		var tr: Transform3D=pose_cache.transforms[system.path]
		for item in particle_systems[key]:
			var age: float=time-item.birth
			if age<0 or age>=item.life: continue
			var r: Array=item.random
			var u: float=age/item.life
			var state:=trajectory(item,system,age)
			var p: Vector3=state.position
			if not item.world: p=tr*p+profile_motion(time)
			var center:=project_point(p)
			var sx:=value(init.startSize,0,r[5])
			var sy:=value(init.startSizeY,0,r[6]) if init.size3D else sx
			var sm: Dictionary=ps.SizeModule
			if sm.enabled:
				sx*=value(sm.curve,u,r[5]);sy*=value(sm.y if sm.separateAxes else sm.curve,u,r[6])
			var angle: float=value(init.startRotation,0,r[7])+state.rotation
			var horizontal:=Vector2.RIGHT
			var vertical:=Vector2.DOWN
			if int(renderer.m_RenderAlignment)==2:
				var right: Vector3=tr.basis*Vector3.RIGHT
				var up: Vector3=tr.basis*Vector3.UP
				horizontal=(project_point(p+right)-center)/PPS
				vertical=(project_point(p-up)-center)/PPS
			elif mirror:horizontal=-horizontal
			if int(renderer.m_RenderMode)==1:
				var v: Vector3=state.velocity
				if not item.world:v=tr.basis*v
				var screen_v: Vector2=(project_point(p+v)-center)/PPS
				vertical=-screen_v.normalized()
				horizontal=vertical.orthogonal()
				sy=absf(sy*renderer.m_LengthScale)+screen_v.length()*renderer.m_VelocityScale
				angle=0
			var color: Color=color_value(init.startColor,0,r[8])*item.get("mesh_color",Color.WHITE)
			if ps.ColorModule.enabled:color*=color_value(ps.ColorModule.gradient,u,r[8])
			var uvm: Dictionary=ps.UVModule
			var nx:=1
			var ny:=1
			var frame:=0
			if uvm.enabled:
				nx=int(uvm.tilesX);ny=int(uvm.tilesY)
				frame=int((value(uvm.startFrame,u,r[2])+value(uvm.frameOverTime,u,r[3])*uvm.cycles)*nx*ny)%(nx*ny)
			if int(renderer.m_RenderMode)==4:
				var source_mesh: Dictionary=system.mesh
				var sz:=value(init.startSizeZ,0,r[14]) if init.size3D else sx
				if sm.enabled:sz*=value(sm.z if sm.separateAxes else sm.curve,u,r[14])
				var rx:=value(init.startRotationX,0,r[15]) if init.rotation3D else 0.0
				var ry:=value(init.startRotationY,0,r[14]) if init.rotation3D else 0.0
				var rotation:=Basis(Vector3.UP,ry)*Basis(Vector3.RIGHT,rx)*Basis(Vector3.BACK,angle)
				var source_basis: Basis=item.birth_transform.basis if item.world else tr.basis
				for vi in source_mesh.vertices.size():
					var vertex: Vector3=source_basis*(rotation*(v3(source_mesh.vertices[vi])*Vector3(sx,sy,sz)))
					points.append(project_point(p+vertex))
					var vc: Array=source_mesh.colors[vi]
					colors.append(color*Color(vc[0],vc[1],vc[2],vc[3]))
					uv.append(Vector2(source_mesh.uv[vi][0],source_mesh.uv[vi][1]))
					indices.append(indices.size())
				continue
			var start:=points.size()
			var corners: Array[Vector2]=[Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]
			var texcoords: Array[Vector2]=[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
			for i in 4:
				var corner: Vector2 = corners[i]
				if apply_source_pivot:
					# Source pivot is in particle diameters. Convert source Y-up to quad Y-down.
					corner -= Vector2(renderer.m_Pivot.x,-renderer.m_Pivot.y)
				var xy: Vector2=(corner*Vector2(sx,sy)).rotated(-angle)
				points.append(center+(horizontal*xy.x+vertical*xy.y)*PPS)
				colors.append(color)
				var tc:=texcoords[i]
				if uvm.enabled:
					var dims: Vector2=get_texture(pack.materials[system.material].textures._MainTex.file).get_size()
					tc=Vector2(lerpf(0.5*nx/dims.x,1.0-0.5*nx/dims.x,tc.x),lerpf(0.5*ny/dims.y,1.0-0.5*ny/dims.y,tc.y))
				uv.append(Vector2((frame%nx+tc.x)/nx,(ny-1-int(frame/ nx)+tc.y)/ny))
			indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
		var node_hash: int=f.nodes.filter(func(node):return node.path==system.path)[0].hash
		draw_geometry("particle:"+system.path,points,colors,uv,material_for(int(system.material),renderer_edits(system,node_hash)),int(renderer.m_SortingOrder),indices)

func draw_particle_trails(f: Dictionary, system: Dictionary) -> void:
	var module: Dictionary=system.particle.TrailModule
	if int(module.mode)==1:
		draw_particle_ribbon(f,system);return
	assert(module.mode==0 and not module.worldSpace and module.dieWithParticles and not module.sizeAffectsLifetime,"Unverified particle trail space/mode/lifetime")
	assert(module.ratio==1.0 and int(module.textureMode) in [0,1],"Unverified particle trail ratio/UV")
	var points:=PackedVector2Array();var colors:=PackedColorArray();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	var tr: Transform3D=pose_cache.transforms[system.path]
	for item in particle_systems[str(phase)+":"+system.path]:
		var age: float=time-item.birth
		if age<=0 or age>=item.life:continue
		trajectory(item,system,age)
		var positions: Array[Vector2]=[];var stamps: Array[float]=[]
		var steps:=int(ceil(age/SAMPLE_STEP))
		for step in range(steps,-1,-1):
			var at:=minf(age,step*SAMPLE_STEP)
			var ttl: float=value(module.lifetime,at/item.life,item.random[13])*item.life
			if age-at>ttl:continue
			var local: Vector3=trajectory(item,system,at).position
			var world: Vector3=local if item.world else tr*local
			var point:=project_point(world+profile_motion(time))
			if not positions.is_empty() and positions[-1].distance_to(point)<float(module.minVertexDistance):continue
			positions.append(point);stamps.append(at)
		if positions.size()<2:continue
		var distances: Array[float]=[0.0]
		for i in range(1,positions.size()):distances.append(distances[-1]+positions[i].distance_to(positions[i-1]))
		if distances[-1]<=.000001:continue
		var initial: Dictionary=system.particle.InitialModule
		var size:=value(initial.startSize,0,item.random[5])
		if system.particle.SizeModule.enabled:size*=value(system.particle.SizeModule.curve,age/item.life,item.random[5])
		var inherited:=Color.WHITE
		if module.inheritParticleColor:
			inherited=color_value(initial.startColor,0,item.random[8])
			if system.particle.ColorModule.enabled:inherited*=color_value(system.particle.ColorModule.gradient,age/item.life,item.random[8])
		var base:=points.size()
		for i in positions.size():
			var fraction: float=distances[i]/distances[-1]
			var tangent: Vector2=positions[mini(i+1,positions.size()-1)]-positions[maxi(0,i-1)]
			var half: Vector2=tangent.normalized().orthogonal()*value(module.widthOverTrail,fraction,item.random[5])*(size if module.sizeAffectsWidth else 1.0)*.5
			var color:=inherited*color_value(module.colorOverLifetime,age/item.life,item.random[8])*color_value(module.colorOverTrail,fraction,item.random[8])
			points.append(positions[i]-half);points.append(positions[i]+half);colors.append(color);colors.append(color)
			var u: float=distances[i] if module.textureMode==1 else fraction
			uv.append(Vector2(u,0));uv.append(Vector2(u,1))
			if i>0:
				var k:=base+i*2;indices.append_array(PackedInt32Array([k-2,k-1,k,k-1,k+1,k]))
		sampled_particle_trails+=1
	var node_hash: int=f.nodes.filter(func(node):return node.path==system.path)[0].hash
	draw_geometry("particle_trail:"+system.path,points,colors,uv,material_for(system.particle_trail_material,renderer_edits(system,node_hash)),system.renderer.m_SortingOrder,indices)

# Source Ribbon mode connects the live particles by age, rather than their movement history.
func draw_particle_ribbon(f: Dictionary, system: Dictionary) -> void:
	var module: Dictionary=system.particle.TrailModule
	assert(int(module.ribbonCount)==1 and not module.worldSpace and not module.splitSubEmitterRibbons and not module.attachRibbonsToTransform,"Unverified ribbon grouping/space")
	assert(int(module.textureMode) in [0,1],"Unverified ribbon UV mode")
	var tr: Transform3D=pose_cache.transforms[system.path]
	var alive: Array=[]
	for item in particle_systems[str(phase)+":"+system.path]:
		var age: float=time-item.birth
		if age>=0 and age<item.life:alive.append(item)
	alive.sort_custom(func(a,b):return a.birth>b.birth)
	if alive.size()<2:return
	var positions: Array[Vector2]=[];var distances: Array[float]=[0.0]
	for item in alive:
		var local: Vector3=trajectory(item,system,time-item.birth).position
		positions.append(project_point((local if item.world else tr*local)+profile_motion(time)))
		if positions.size()>1:distances.append(distances[-1]+positions[-1].distance_to(positions[-2]))
	if distances[-1]<=.000001:return
	var points:=PackedVector2Array();var colors:=PackedColorArray();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	for i in alive.size():
		var item: Dictionary=alive[i];var age: float=time-item.birth;var initial: Dictionary=system.particle.InitialModule
		var fraction: float=distances[i]/distances[-1]
		var size:=value(initial.startSize,0,item.random[5])
		if system.particle.SizeModule.enabled:size*=value(system.particle.SizeModule.curve,age/item.life,item.random[5])
		var inherited:=Color.WHITE
		if module.inheritParticleColor:
			inherited=color_value(initial.startColor,0,item.random[8])
			if system.particle.ColorModule.enabled:inherited*=color_value(system.particle.ColorModule.gradient,age/item.life,item.random[8])
		var color:=inherited*color_value(module.colorOverLifetime,age/item.life,item.random[8])*color_value(module.colorOverTrail,fraction,item.random[8])
		var tangent: Vector2=positions[mini(i+1,positions.size()-1)]-positions[maxi(0,i-1)]
		var half:=tangent.normalized().orthogonal()*value(module.widthOverTrail,fraction,item.random[5])*(size if module.sizeAffectsWidth else 1.0)*.5
		points.append(positions[i]-half);points.append(positions[i]+half);colors.append(color);colors.append(color)
		var u: float=distances[i] if int(module.textureMode)==1 else fraction
		uv.append(Vector2(u,0));uv.append(Vector2(u,1))
		if i>0:
			var k:=i*2;indices.append_array(PackedInt32Array([k-2,k-1,k,k-1,k+1,k]))
	sampled_particle_trails+=1
	var node_hash: int=f.nodes.filter(func(node):return node.path==system.path)[0].hash
	draw_geometry("particle_ribbon:"+system.path,points,colors,uv,material_for(system.particle_trail_material,renderer_edits(system,node_hash)),system.renderer.m_SortingOrder,indices)
