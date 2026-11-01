extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id in ["suzuran", "shining", "blaze"]:
		var operator: OperatorData = load("res://resources/operators/%s.tres" % id)
		var data := {id: operator}
		var state := MatchState.new(123, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [PackedStringArray([id]), PackedStringArray([id])], [PackedInt32Array([1]), PackedInt32Array([2])])
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		state.ball.cell = Vector2i(10, 10)
		var blue_cell := Vector2i(12, 5) if id == "blaze" else Vector2i(12, 2)
		var red_cell := Vector2i(8, 5) if id == "blaze" else Vector2i(8, 8)
		state.step([InputCommand.new(0, 0, id, -1, blue_cell, -1, 2)], [InputCommand.new(0, 0, id, -1, red_cell, -1, 0)])
		if not check(state.units.size() == 2 and state.units[0].skill_index == 1 and state.units[1].skill_index == 2, "Actual deployment preserves independent carried skills"): return
		var input := LocalInput.new(0)
		var view := MatchView.new()
		view.bind(state, input, data)
		root.add_child(view)
		input.select_operator(id)
		view._info_tab = view.InfoTab.SKILL
		if not await render(state, view, id + "-reserve"): return
		if not check(operator.skills[1].skill_name in view._info_layout_paragraphs and "自动触发" in view._info_layout_paragraphs, "Reserve shows actual S2 name and trigger"): return
		state.units[0].sp = SkillRules.sp_limit(operator.skills[1])
		state.units[0].hp = operator.max_health / 2
		state.units[0].attack_ticks_left = 1
		state.step([], [])
		input.select_unit(0)
		if not await render(state, view, id + "-s2"): return
		if id == "shining":
			if not check(state.units[0].barrier_hp.size() == 1 and state.units[0].barrier_hp[0] == 265, "Actual S2 healing grants visible barrier"): return
		else:
			if not check(state.units[0].skill_ticks_left == -2 and view._skill_bar_ratio(state.units[0], operator.skills[1]) == 1.0 and ("技力消耗 %d · 持续无限" % operator.skills[1].sp_required) in view._info_layout_paragraphs, "Infinite skill remains active and progress is full"): return
		input.side = 1
		input.select_unit(1)
		view._info_tab = view.InfoTab.COMMAND
		state.units[1].sp = operator.skills[2].sp_required
		view._activate_selected_skill()
		var commands := input.take_commands()
		if not check(commands.size() == 1 and commands[0].skill_index == 2 and commands[0].unit_id == 1, "Manual button queues carried S3 only"): return
		state.step([], commands)
		view._info_tab = view.InfoTab.SKILL
		if not await render(state, view, id + "-s3"): return
		if not check(operator.skills[2].skill_name in view._info_layout_paragraphs and "手动触发" in view._info_layout_paragraphs, "Actual S3 name/trigger shown"): return
		var expected: Array[Vector2i] = []
		if id == "blaze":
			for x in 3:
				for y in range(-1, 2): expected.append(Vector2i(x, y))
		elif id == "shining":
			for x in 4:
				for y in range(-1, 2): expected.append(Vector2i(x, y))
		else:
			expected = operator.skills[2].attack_range_override.duplicate()
			if not check(expected.size() == 23 and Vector2i(3, 0) in expected, "Suzuran enlarged 23-cell source range"): return
		for side in 2:
			input.side = side
			input.select_unit(1)
			for mirrored in [false, true]:
				view.mirror_board = mirrored
				for facing in 4:
					state.units[1].facing = facing
					var displayed := view._range_offsets(operator, red_cell)
					if not check(displayed.size() == expected.size(), "Displayed S3 range size"): return
					for offset in expected:
						if not check(offset in displayed, "Exact S3 range offsets, burst preview separate from cutting"): return
					if not await render(state, view, "%s-side%d-mirror%d-facing%d" % [id, side, int(mirrored), facing]): return
		input.side = 0
		input.select_unit(1)
		view._activate_selected_skill()
		if not check(input.take_commands().is_empty(), "Enemy skill cannot be activated"): return
		state.units[1].skill_ticks_left = 1
		state.step([], [])
		if not check(view._range_offsets(operator, red_cell) == operator.attack_range, "Expiry restores base displayed range"): return
		view.queue_free()
		await process_frame
	print("Three operator skill view OK: actual deployment, names, buttons, permanent/charge status, exact ranges and read-only rendering")
	quit(0)


func render(state: MatchState, view: MatchView, name: String) -> bool:
	var before := state.state_hash()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not check(before == state.state_hash(), "View changed simulation: " + name): return false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not check(root.get_texture().get_image().save_png("res://.godot/three-skill-" + name + ".png") == OK, "Screenshot failed"): return false
	return true


func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
