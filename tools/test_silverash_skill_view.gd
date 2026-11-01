extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var silver: OperatorData = load("res://resources/operators/silverash.tres")
	var data := {"silverash": silver}
	var state := MatchState.new(123, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [["silverash"], ["silverash"]], [[1], [2]])
	state.sides[0].cost = 99
	state.sides[1].cost = 99
	state.ball.cell = Vector2i(10, 10)
	state.step([InputCommand.new(0, 0, "silverash", -1, Vector2i(12, 5), -1, 2)], [InputCommand.new(0, 0, "silverash", -1, Vector2i(8, 5), -1, 0)])
	if not check(state.units.size() == 2 and state.units[0].skill_index == 1 and state.units[1].skill_index == 2, "Independent actual S2/S3 deployment"): return
	var input := LocalInput.new(0)
	var view := MatchView.new()
	view.bind(state, input, data)
	root.add_child(view)
	input.select_operator("silverash")
	view._info_tab = view.InfoTab.SKILL
	if not await render(state, view, "reserve-s2"): return
	if not check("雪境生存法则" in view._info_layout_paragraphs and "手动触发" in view._info_layout_paragraphs, "Reserve carried name and trigger"): return
	input.select_unit(0)
	view._info_tab = view.InfoTab.COMMAND
	state.units[0].sp = 5
	view._activate_selected_skill()
	var commands := input.take_commands()
	if not check(commands.size() == 1 and commands[0].skill_index == 1, "Actual button queues stance switch"): return
	state.step(commands, [])
	if not await render(state, view, "active-s2"): return
	if not check(state.units[0].skill_ticks_left == -2 and view._range_offsets(silver, state.units[0].cell).size() == 4 and view._skill_bar_ratio(state.units[0], silver.skills[1]) == 0.0, "Stance shows four cells and SP rather than infinite full bar"): return
	state.units[0].sp = 5
	if not await render(state, view, "ready-return-s2"): return
	view._activate_selected_skill()
	commands = input.take_commands()
	if not check(commands.size() == 1 and commands[0].unit_id == 0 and commands[0].skill_index == 1, "Same live button can return to original state"): return
	state.step(commands, [])
	if not await render(state, view, "returned-s2"): return
	if not check(view._range_offsets(silver, state.units[0].cell) == silver.attack_range, "Return restores visible base eight cells"): return
	state.units[0].sp = 5
	state.step([InputCommand.new(state.tick, 1, "", 0, Vector2i.ZERO, 1)], [])
	state.units[1].sp = 90
	input.side = 1
	input.select_unit(1)
	view._activate_selected_skill()
	commands = input.take_commands()
	if not check(commands.size() == 1 and commands[0].skill_index == 2, "Other side carried S3 manual button"): return
	state.step([], commands)
	view._info_tab = view.InfoTab.SKILL
	if not await render(state, view, "details-s3"): return
	if not check("真银斩" in view._info_layout_paragraphs, "Deployed S3 name"): return
	for side in 2:
		input.side = side
		input.select_unit(side)
		for mirrored in [false, true]:
			view.mirror_board = mirrored
			for facing in 4:
				state.units[side].facing = facing
				if not check(view._range_offsets(silver, state.units[side].cell) == silver.skills[1 if side == 0 else 2].attack_range_override and view._range_offsets(silver, state.units[side].cell).size() == (4 if side == 0 else 16), "Visible exact active source range"): return
				if not await render(state, view, "side%d-mirror%d-facing%d" % [side, int(mirrored), facing]): return
	input.side = 0
	input.select_unit(1)
	view._activate_selected_skill()
	if not check(input.take_commands().is_empty(), "Enemy skill remains readonly"): return
	state.units[1].skill_ticks_left = 1
	state.step([], [])
	if not check(view._range_offsets(silver, state.units[1].cell) == silver.attack_range, "Expiry restores displayed base range"): return
	view.queue_free()
	print("SilverAsh skill view OK: actual carried deployment, two-way stance button, SP progress, S3 sixteen cells, four directions/mirrors, readonly rendering")
	quit(0)


func render(state: MatchState, view: MatchView, name: String) -> bool:
	var before := state.state_hash()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not check(before == state.state_hash(), "Rendering changed sim: " + name): return false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not check(root.get_texture().get_image().save_png("res://.godot/silverash-" + name + ".png") == OK, "Screenshot failed"): return false
	return true


func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
