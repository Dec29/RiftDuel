extends SceneTree
const CONFIG = preload("res://data/config.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var data := {}
	for id in CONFIG.DEFAULT_SQUAD_IDS:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var bagpipe: OperatorData = data["bagpipe"]
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(172, data)
			state.tick = 180
			for facing in 4:
				var cell := Vector2i(13 if side == 0 else 7, 1 + facing * 3)
				state.units.append(UnitState.new(facing, side, "bagpipe", cell, bagpipe.max_health, 0, 30, facing))
			var input := LocalInput.new(side)
			var view := MatchView.new()
			view.process_mode = Node.PROCESS_MODE_PAUSABLE
			root.add_child(view)
			view.bind(state, input, data)
			view.mirror_board = mirrored
			input.select_unit(1)
			var before := state.state_hash()
			await process_frame
			await process_frame
			if not _check(state.state_hash() == before and view._bagpipe_models.size() == 4, "All four facings render read-only"): return
			for facing in 4:
				var model: OperatorSpineVisual = view._bagpipe_models[facing]
				if not _check(model.view_index == (1 if facing == 3 else 0) and model.mesh.get_surface_count() == 1, "Verified front/back and one merged draw"): return
			var model: OperatorSpineVisual = view._bagpipe_models[1]
			var idle_pose: PackedVector2Array = model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
			state.units[1].last_attack_tick = state.tick - 8
			state.units[1].last_attack_target_x = state.units[1].cell.x
			state.units[1].last_attack_target_y = state.units[1].cell.y + 1
			before = state.state_hash()
			await process_frame
			await process_frame
			if not _check(model.clip == "Attack_Loop_Down" and idle_pose != model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] and state.state_hash() == before, "Actual downward attack changes pose without changing simulation"): return
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				if not _check(root.get_texture().get_image().save_png("res://.godot/bagpipe-side%d-mirror%d.png" % [side, int(mirrored)]) == OK, "Save battle view"): return
			paused = true
			var frozen: PackedVector2Array = model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
			await process_frame
			view.queue_redraw()
			await process_frame
			if not _check(frozen == model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Pause freezes the exact pose"): return
			paused = false
			state.result = MatchState.RESULT_DRAW
			await process_frame
			frozen = model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
			await process_frame
			if not _check(frozen == model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Result freezes animation"): return
			state.units.clear()
			view.queue_redraw()
			await process_frame
			await process_frame
			if not _check(view._bagpipe_models.is_empty(), "Retreat releases visual instances"): return
			view.free()
	# Repeated action changes used to retain an ever-growing native mixing chain.
	var unit := UnitState.new(0, 1, "bagpipe", Vector2i(9, 5), bagpipe.max_health, 0, 30)
	var model := BagpipeVisual.new()
	if not _check(model.initialize(), "Long-lived skeleton initializes"): return
	var state := MatchState.new(172, data)
	state.units.append(unit)
	var before := state.state_hash()
	var durations: Array[int] = []
	for batch in 8:
		var started := Time.get_ticks_usec()
		for frame in 480:
			var visual_tick := float(batch * 480 + frame) * 3.0
			# Fixture attack marker only; the adapter must preserve all simulation fields.
			unit.last_attack_tick = int(visual_tick) / 30 * 30
			before = state.state_hash()
			if not _check(model.prepare(unit, visual_tick, 30) and state.state_hash() == before, "Six-minute action cycle remains read-only"): return
			if not _check(BagpipeVisual.SOURCES[model.view_index].drain_events(model._instances[model.view_index]).is_empty(), "Native event queue is drained"): return
		durations.append(Time.get_ticks_usec() - started)
	# A broad growth gate, not an absolute FPS promise; catches the old linear chain.
	var early := durations[1] + durations[2]
	var late := durations[6] + durations[7]
	if not _check(late < early * 3 + 20000, "Animation update time must not grow with action history: %s" % [durations]): return
	print("BAGPIPE_LONG_ACTION_US ", durations)
	print("BAGPIPE_VISUAL_OK")
	quit(0)
func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
