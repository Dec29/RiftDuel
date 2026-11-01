extends SceneTree
func _initialize() -> void:
	var results := []
	for op in (["mon3tr_reconstruction","ling_soul1","ling_soul2","ling_soul3","flowing_shape","jessica_shield","dusk_freeling","stainless_device_atk","stainless_device_sp","stainless_cannon"] if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()):
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/operators/'+op+'/source_manifest.json'))
		for row: Dictionary in manifest.files:
			if FileAccess.get_sha256("res://"+str(row.path))!=row.sha256:
				push_error("Source SHA mismatch "+str(row.path));quit(1);return
		for side in ["single"]:
			var base: String="res://assets/operators/"+op+"/"+side+"/"+manifest.char_id
			var atlas := SpineAtlasResource.new();var file := SpineSkeletonFileResource.new()
			if atlas.load_from_atlas_file(base+".atlas")!=OK or file.load_from_file(base+".skel")!=OK:push_error(base);quit(1);return
			var data := SpineSkeletonDataResource.new();data.atlas_res=atlas;data.skeleton_file_res=file
			if not data.ensure_loaded() or data.get_page_count()!=1 or data.is_page_pma(0):push_error(data.get_last_error());quit(1);return
			if ResourceSaver.save(data,"res://assets/operators/"+op+"/"+side+"/"+op+".res",ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
			var instance := data.create_instance();var animations := {};var modes := {}
			for name in data.get_animation_names():
				data.clear_tracks(instance);data.set_animation(instance,0,name,false)
				var completed := false
				for frame in range(1,12001):
					data.update_animation_state(instance,1.0/300.0);data.apply_animation_state(instance)
					if frame==60:
						data.update_world_transform(instance,0.0)
						for command: Dictionary in data.get_render_commands(instance):modes[str(command.get("blend_mode","unknown"))]=command.keys()
					var events := data.drain_events(instance)
					if "completed" in str(events):animations[name]=roundi(frame/10.0)/30.0;completed=true;break
				if not completed:push_error(op+" "+side+" animation did not complete: "+name);quit(1);return
			data.destroy_instance(instance)
			results.append({"id":op,"side":side,"animations":animations,"pages":1,"pma":false,"render_modes":modes})
			print(op," ",side," ",animations," modes=",modes.keys())
	DirAccess.make_dir_recursive_absolute("res://.godot/m129-research")
	var out := FileAccess.open("res://.godot/m129-research/summon-native.json",FileAccess.WRITE);out.store_string(JSON.stringify(results,"  "));out.close()
	quit(0)
