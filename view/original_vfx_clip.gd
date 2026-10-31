extends Resource
# Source layers keep their own additive/alpha/dissolve materials in each ArrayMesh.
@export var effect_id: StringName
@export var source_prefab: String
@export var frames_per_second: int=30
@export var frames_per_facing: int=0
@export var duration_seconds: float=0.0
@export var emission_seconds: float=0.0
@export var canonical_travel_units: float=0.0
@export var loop_from_seconds: float=-1.0
@export var frames: Array[Resource]=[]

func frame_at(age_seconds: float, facing: int) -> Resource:
	if age_seconds<0:return null
	if loop_from_seconds>=0 and age_seconds>=duration_seconds:
		age_seconds=loop_from_seconds+fposmod(age_seconds-loop_from_seconds,duration_seconds-loop_from_seconds)
	elif age_seconds>=duration_seconds:return null
	var index:=mini(int(age_seconds*frames_per_second),frames_per_facing-1)
	return frames[facing*frames_per_facing+index]

# Compatibility for legacy clips and CPU inspection. Packed frames use player-owned buffers.
const MESH_FRAME_CACHE_LIMIT:=16
var _mesh_frames: Dictionary={}
var _mesh_order: Array[int]=[]
func meshes_for(frame: Resource) -> Array[ArrayMesh]:
	var key: int=frame.get_instance_id()
	if _mesh_frames.has(key):
		_mesh_order.erase(key);_mesh_order.append(key)
		return _mesh_frames[key]
	var meshes: Array[ArrayMesh]=frame.create_meshes()
	_mesh_frames[key]=meshes;_mesh_order.append(key)
	while _mesh_order.size()>MESH_FRAME_CACHE_LIMIT:_mesh_frames.erase(_mesh_order.pop_front())
	return meshes
