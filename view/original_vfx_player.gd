extends RefCounted
# Caller owns battle-clock age and projected anchor; this object has no clock or callbacks.
static var buffer_creations:=0
static var buffer_reuses:=0
var instance: Node2D
var presentation_gain:=1.0
var frame: Resource
var _layers: Array[MeshInstance2D]=[]
var _buffers: Array[Dictionary]=[]
var _buffer_orders: Array[Array]=[]
var _shaders: Array[Shader]=[]
var _gains: Array[float]=[]
var _uses_clock: Array[bool]=[]
var _clock_layers: Array[MeshInstance2D]=[]
var _clock_age:=NAN

func attach(parent: Node2D) -> void:
	instance=Node2D.new()
	parent.add_child(instance)
	instance.visible=false

func sample(clip: Resource, age_seconds: float, facing: int, anchor: Vector2, pixels_per_unit: float, mirrored: bool, depth: int) -> bool:
	var next_frame: Resource=clip.frame_at(age_seconds,facing)
	if next_frame==null:
		clear()
		return false
	if next_frame!=frame:
		assert(next_frame.storage_version in [0,1,2],"Unknown VFX storage version")
		var meshes: Array[ArrayMesh]=[]
		if next_frame.storage_version!=2:meshes=clip.meshes_for(next_frame)
		_clock_layers.clear();_clock_age=NAN
		var count: int=next_frame.layer_count()
		while _layers.size()<count:
			var layer:=MeshInstance2D.new()
			instance.add_child(layer)
			_layers.append(layer)
			_buffers.append({});_buffer_orders.append([])
			_shaders.append(null);_gains.append(NAN);_uses_clock.append(false)
		for i in _layers.size():
			var active: bool=i<count
			_layers[i].visible=active
			if active:
				var mesh: ArrayMesh=dynamic_mesh(next_frame,i) if next_frame.storage_version==2 else meshes[i]
				if _layers[i].mesh!=mesh:_layers[i].mesh=mesh
				var material: ShaderMaterial=next_frame.material_at(i)
				if _layers[i].material!=material:_layers[i].material=material
				if _shaders[i]!=material.shader:
					_shaders[i]=material.shader;_gains[i]=NAN
					_uses_clock[i]=material.get_meta("original_vfx_clock",false)
				if _gains[i]!=presentation_gain:
					_layers[i].set_instance_shader_parameter("presentation_gain",presentation_gain);_gains[i]=presentation_gain
				if _uses_clock[i]:_clock_layers.append(_layers[i])
			else:
				_layers[i].mesh=null
				_layers[i].material=null
		frame=next_frame
	if _clock_age!=age_seconds:
		for layer in _clock_layers:layer.set_instance_shader_parameter("source_time",age_seconds)
		_clock_age=age_seconds
	instance.transform=Transform2D(Vector2(-pixels_per_unit if mirrored else pixels_per_unit,0),Vector2(0,pixels_per_unit),anchor)
	instance.z_index=depth
	instance.visible=true
	return true

func clear() -> void:
	# Cleared pool slots already hold no meshes/materials; avoid repeating engine setters.
	if frame==null:return
	instance.visible=false
	for layer in _layers:
		layer.mesh=null
		layer.material=null
	_clock_layers.clear();_clock_age=NAN
	frame=null

func dispose() -> void:
	clear()
	instance.queue_free()

func dynamic_mesh(source: Resource,index: int) -> ArrayMesh:
	var raw: Dictionary=source.buffer_surfaces[index]
	var capacity:=Vector2i(raw.vertex_count,raw.index_count)
	var meshes: Dictionary=_buffers[index]
	var order: Array=_buffer_orders[index]
	var mesh: ArrayMesh
	if meshes.has(capacity):
		buffer_reuses+=1
		mesh=meshes[capacity];order.erase(capacity);order.append(capacity)
	else:
		buffer_creations+=1
		mesh=source.create_dynamic_mesh(index);meshes[capacity]=mesh;order.append(capacity)
		while order.size()>4:meshes.erase(order.pop_front())
		assert(mesh.surface_get_format(0)==int(raw.format),"Packed VFX vertex format mismatch")
	RenderingServer.mesh_surface_update_vertex_region(mesh.get_rid(),0,0,raw.vertex_data)
	RenderingServer.mesh_surface_update_attribute_region(mesh.get_rid(),0,0,raw.attribute_data)
	RenderingServer.mesh_surface_update_index_region(mesh.get_rid(),0,0,raw.index_data)
	mesh.custom_aabb=raw.aabb
	return mesh
