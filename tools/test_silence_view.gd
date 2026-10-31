extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {"ceobe":load("res://resources/operators/ceobe.tres")}
	for side in 2:
		for mirrored in [false,true]:
			var state := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["ceobe"],["ceobe"]],[[1],[2]])
			state.sides[0].cost = 99
			state.sides[1].cost = 99
			state.step([InputCommand.new(0,0,"ceobe",-1,Vector2i(12,2),-1,2)],[InputCommand.new(0,0,"ceobe",-1,Vector2i(8,8),-1,0)])
			if not check(state.units.size() == 2, "Actual high deployment"): return
			var input := LocalInput.new(side)
			var view := MatchView.new()
			view.bind(state,input,data)
			view.mirror_board = mirrored
			root.add_child(view)
			var unit := state.units[side]
			unit.sp = data.ceobe.skills[side+1].sp_required
			StatusRules.apply_silence(state, unit,150)
			input.select_unit(side)
			view._details_open = true
			var before := state.state_hash()
			view.queue_redraw()
			await process_frame
			await process_frame
			view._activate_selected_skill()
			if not check(input.take_commands().is_empty() and before == state.state_hash(), "Silence blocks real skill button and UI is read-only"): return
			if DisplayServer.get_name() != "headless":
				if not check(root.get_texture().get_image().save_png("res://.godot/ceobe-silence-%d-%s.png" % [side,mirrored]) == OK, "Screenshot"): return
			view.queue_free()
			await process_frame
	print("Silence view OK: marker/disabled button/read-only, side2/mirror2")
	quit(0)


func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
