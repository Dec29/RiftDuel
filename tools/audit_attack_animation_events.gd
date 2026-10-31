extends SceneTree
# Offline source evidence only. Native events never advance combat.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var results: Array[Dictionary]=[]
	var args:=OS.get_cmdline_user_args()
	for id in OperatorSpineMap.ENTRIES:
		if not args.is_empty() and id not in args:continue
		var entry:=OperatorSpineMap.entry_for(id)
		for side in 2:
			var data:=OperatorSpineMap.source(entry,side)
			for clip in data.get_animation_names():
				if "Attack" not in clip and "Skill" not in clip:continue
				var inst:=data.create_instance()
				if not data.set_animation(inst,0,clip,false):push_error(data.get_last_error());quit(1);return
				var events: Array[Dictionary]=[];var completed:=false;var duration_usec:=0
				for frame in 12000:
					if not data.update_animation_state(inst,1.0/300.0) or not data.apply_animation_state(inst):push_error(data.get_last_error());quit(1);return
					for event in data.drain_events(inst):
						if event.type=="event":events.append({"name":event.name,"time_usec":roundi(float(event.time)*1000000.0),"int_value":event.int_value,"string_value":event.string_value})
						if event.type=="completed":completed=true;duration_usec=roundi(float(event.track_time)*1000000.0)
					if completed:break
				data.destroy_instance(inst)
				results.append({"id":id,"side":side,"clip":clip,"completed":completed,"completion_sample_usec":duration_usec,"events":events})
	var folder:="res://.ai/attack-timing-20261023/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	FileAccess.open(folder+"source-events.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("ATTACK_SOURCE_AUDIT_OK: ",results.size()," source actions; evidence only, not gameplay tests")
	quit(0)
