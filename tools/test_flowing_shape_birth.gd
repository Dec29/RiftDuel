extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func run() -> void:
	var source := OperatorSpineMap.entry_for("flowing_shape").front as SpineSkeletonDataResource
	# Inspect the source directly, independently of the adapter's empty-clip list.
	for clip in ["Start", "A_Start", "B_Start"]:
		var instance := source.create_instance()
		if not check(source.set_animation(instance, 0, clip, false), "Native birth " + clip): return
		var visible := false
		var samples := []
		for frame in 30:
			if not check(source.set_track_time(instance, 0, frame / 30.0) and source.update_animation_state(instance, 0.0) and source.apply_animation_state(instance) and source.update_world_transform(instance, 0.0), "Native sampling"): return
			var count := source.get_render_commands(instance).size()
			samples.append(count)
			visible = visible or count > 0
		if not check(visible, "Native birth reveals attachments " + clip): return
		print("FLOW_NATIVE_BIRTH ", clip, " commands_by_frame=", samples)
		source.destroy_instance(instance)
	var state := MatchState.new(155, {"muelsyse": load("res://resources/operators/muelsyse.tres")})
	var cases := 0
	for copied in ["", "bagpipe", "exusiai"]:
		for facing in 4:
			var unit := UnitState.new(0, 0, "flowing_shape", Vector2i(13, 3), 10000, 0, 0, facing)
			unit.deployed_tick = 100
			unit.flow_copy_id = copied
			unit.flow_melee = copied == "bagpipe"
			state.units = [unit]
			var model := OperatorSpineVisual.new()
			if not check(model.initialize("flowing_shape"), model.last_error): return
			for half_frame in 65:
				var before := state.state_hash()
				if not check(model.prepare(unit, 100.0 + half_frame * 0.5, 60), model.last_error): return
				if not check(before == state.state_hash(), "Birth rendering read-only"): return
				if half_frame >= 60 and not check(model.mesh.get_surface_count() > 0, "Birth returns to visible idle"): return
				cases += 1
			# Tactical-point transparency must also recover to the copied body.
			unit.flow_point_until_tick = 200
			if not check(model.prepare(unit, 140, 60), model.last_error): return
			unit.flow_point_until_tick = 0
			if not check(model.prepare(unit, 160, 60) and model.mesh.get_surface_count() > 0, "Point returns to visible body"): return
	print("FLOWING_SHAPE_BIRTH_OK ", cases, " source-backed half-frame poses, original/melee/ranged, four facings and tactical-point recovery")
	quit(0)
