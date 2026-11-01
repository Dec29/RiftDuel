extends Resource
# Legacy meshes remain readable. New clips store exact CPU arrays and material references.
@export var storage_version:=0
@export var buffer_surfaces: Array[Dictionary]=[]
@export var layers: Array[ArrayMesh]=[]
@export var surface_arrays: Array[Array]=[]
@export var layer_materials: Array[Material]=[]

func capture(meshes: Array[ArrayMesh]) -> void:
	assert(layers.is_empty() and surface_arrays.is_empty())
	for mesh in meshes:
		assert(mesh.get_surface_count()==1,"Source VFX layer must have exactly one surface")
		surface_arrays.append(mesh.surface_get_arrays(0))
		layer_materials.append(mesh.surface_get_material(0))
	prepare_buffers()

func layer_count() -> int:
	return layers.size() if not layers.is_empty() else surface_arrays.size()

func material_at(index: int) -> Material:
	return layers[index].surface_get_material(0) if not layers.is_empty() else layer_materials[index]

func create_meshes() -> Array[ArrayMesh]:
	if not layers.is_empty():return layers
	assert(surface_arrays.size()==layer_materials.size(),"VFX geometry/material count mismatch")
	var result: Array[ArrayMesh]=[]
	for i in surface_arrays.size():
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface_arrays[i],[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		mesh.surface_set_material(0,layer_materials[i])
		result.append(mesh)
	return result

# Packing happens offline once. Gameplay updates existing GPU buffers without rebuilding meshes.
func padded_arrays(index: int) -> Array:
	var arrays: Array=surface_arrays[index].duplicate()
	var count: int=arrays[Mesh.ARRAY_VERTEX].size()
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX].duplicate() if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(count))
	var vertex_capacity:=int(ceil(count/64.0))*64
	var index_capacity:=int(ceil(indices.size()/96.0))*96
	assert(vertex_capacity<65536,"VFX packed index format must remain 16 bit")
	var vertices: PackedVector2Array=arrays[Mesh.ARRAY_VERTEX].duplicate();vertices.resize(vertex_capacity);arrays[Mesh.ARRAY_VERTEX]=vertices
	var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR].duplicate();colors.resize(vertex_capacity);arrays[Mesh.ARRAY_COLOR]=colors
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV].duplicate();uv.resize(vertex_capacity);arrays[Mesh.ARRAY_TEX_UV]=uv
	indices.resize(index_capacity);arrays[Mesh.ARRAY_INDEX]=indices
	return arrays

func prepare_buffers() -> void:
	assert(layers.is_empty(),"Convert legacy meshes to CPU arrays before packing")
	buffer_surfaces.clear()
	for i in surface_arrays.size():
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,padded_arrays(i),[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES|Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		var raw: Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),0)
		raw.erase("material")
		buffer_surfaces.append(raw)
	storage_version=2

func create_dynamic_mesh(index: int) -> ArrayMesh:
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,padded_arrays(index),[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES|Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	return mesh
