extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {"angelina": load("res://resources/operators/angelina.tres")}
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(123, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [["angelina"], ["angelina"]], [[1], [2]])
			state.sides[0].cost = 99
			state.sides[1].cost = 99
			state.ball.cell = Vector2i(10, 10)
			state.step([InputCommand.new(0, 0, "angelina", -1, Vector2i(12, 2), -1, 2)], [InputCommand.new(0, 0, "angelina", -1, Vector2i(8, 8), -1, 0)])
			if not check(state.units.size() == 2, "Actual high deployment"): return
			var input := LocalInput.new(side)
			var view := MatchView.new()
			view.bind(state, input, data)
			view.mirror_board = mirrored
			root.add_child(view)
			input.select_unit(side)
			var unit := state.units[side]
			unit.sp = 15 if side == 0 else 25
			view._activate_selected_skill()
			var commands := input.take_commands()
			if not check(commands.size() == 1 and commands[0].skill_index == side + 1, "Actual activation button queues equipped index"): return
			if side == 0: state.step(commands, [])
			else: state.step([], commands)
			view._info_tab = view.InfoTab.SKILL
			view._details_open = true
			var before := state.state_hash()
			view.queue_redraw()
			await process_frame
			await process_frame
			if not check(state.state_hash() == before and view._skill_bar_ratio(unit, data.angelina.skills[unit.skill_index]) > 0 and AttackRange.effective_offsets(unit, data.angelina).size() == (12 if side == 0 else 19), "Read-only active range/bar"): return
			if DisplayServer.get_name() != "headless":
				if not check(root.get_texture().get_image().save_png("res://.godot/angelina-skills-%d-%s.png" % [side, mirrored]) == OK, "Screenshot"): return
			view._activate_selected_skill()
			if not check(input.take_commands().is_empty(), "Active skill does not allow unintended closing"): return
			unit.skill_ticks_left = 1
			state.step([], [])
			if not check(unit.skill_ticks_left == 0 and AttackRange.effective_offsets(unit, data.angelina).size() == 12, "Expiry restores normal range"): return
			view.queue_free()
			await process_frame
	print("Angelina skill view OK: high deployment/equipped activation, side2/mirror2 and read-only range/bars")
	quit(0)


func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
