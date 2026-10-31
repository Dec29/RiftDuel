extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {"horn": load("res://resources/operators/horn.tres")}
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(123, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [["horn"], ["horn"]], [[1], [2]])
			state.sides[0].cost = 99
			state.sides[1].cost = 99
			state.ball.cell = Vector2i(10, 10)
			state.step([InputCommand.new(0, 0, "horn", -1, Vector2i(14, 5), -1, 2)], [InputCommand.new(0, 0, "horn", -1, Vector2i(6, 5), -1, 0)])
			if not check(state.units.size() == 2, "Actual deployment"): return
			var input := LocalInput.new(side)
			var view := MatchView.new()
			view.bind(state, input, data)
			view.mirror_board = mirrored
			root.add_child(view)
			input.select_unit(side)
			var unit := state.units[side]
			unit.sp = 25 if side == 0 else 35
			view._activate_selected_skill()
			var commands := input.take_commands()
			if not check(commands.size() == 1 and commands[0].skill_index == (1 if side == 0 else 2), "Real activation button queues equipped index"): return
			if side == 0: state.step(commands, [])
			else: state.step([], commands)
			if side == 0:
				unit.skill_ammo_left = 5
				state.tactical_boxes.append(TacticalBox.new(0, Vector2i(11, 5), 3))
			else:
				unit.skill_elapsed_ticks = 360
				unit.skill_ticks_left = 360
			var before := state.state_hash()
			view._details_open = true
			view.queue_redraw()
			await process_frame
			await process_frame
			if not check(state.state_hash() == before and view._skill_bar_ratio(unit, data.horn.skills[unit.skill_index]) > 0, "Read-only ammo/duration bar"): return
			if DisplayServer.get_name() != "headless":
				if not check(root.get_texture().get_image().save_png("res://.godot/horn-skills-%d-%s.png" % [side, mirrored]) == OK, "Screenshot"): return
			view._activate_selected_skill()
			commands = input.take_commands()
			if not check(commands.size() == 1, "Active skill button allows close/dump"): return
			if side == 0: state.step(commands, [])
			else: state.step([], commands)
			if not check(unit.skill_ticks_left == 0 and (state.tactical_boxes.is_empty() if side == 0 else true), "Button closes actual effect"): return
			view.queue_free()
			await process_frame
	print("Horn skill view OK: actual deployment/equipped activation/dump/close, side2/mirror2 and read-only bars")
	quit(0)


func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
