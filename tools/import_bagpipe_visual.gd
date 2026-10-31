extends SceneTree
func _initialize() -> void:
	for side: String in ["front", "back"]:
		var stem := "res://assets/operators/bagpipe/%s/char_222_bpipe" % side
		var atlas := SpineAtlasResource.new()
		var file := SpineSkeletonFileResource.new()
		if atlas.load_from_atlas_file(stem + ".atlas") != OK or file.load_from_file(stem + ".skel") != OK:
			push_error("Bagpipe source load failed: " + side)
			quit(1)
			return
		var data := SpineSkeletonDataResource.new()
		data.atlas_res = atlas
		data.skeleton_file_res = file
		if not data.ensure_loaded() or ResourceSaver.save(data, "res://assets/operators/bagpipe/%s/bagpipe.res" % side, ResourceSaver.FLAG_COMPRESS) != OK:
			push_error("Bagpipe resource generation failed: " + side)
			quit(1)
			return
		print("BAGPIPE_RESOURCE_OK ", side)
	quit(0)
