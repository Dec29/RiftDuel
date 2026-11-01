extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id in ["hoshiguma"]:
		var operator: OperatorData = load("res://resources/operators/%s.tres" % id)
		var data := {id: operator}
		var state := MatchState.new(123, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [PackedStringArray([id]), PackedStringArray([id])], [PackedInt32Array([1]), PackedInt32Array([2])])
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		state.ball.cell = Vector2i(10, 10)
		var blue_cell := Vector2i(12, 5)
		var red_cell := Vector2i(8, 5)
		state.step([InputCommand.new(0, 0, id, -1, blue_cell, -1, 2)], [InputCommand.new(0, 0, id, -1, red_cell, -1, 0)])
		if not check(state.units.size() == 2 and state.units[0].skill_index == 1 and state.units[1].skill_index == 2, "Actual deployment preserves independent carried skills"): return
		var input := LocalInput.new(0)
		var view := MatchView.new()
		view.bind(state, input, data)
		root.add_child(view)
		input.select_operator(id)
		view._info_tab = view.InfoTab.SKILL
		if not await render(state, view, id + "-reserve"): return
		if not check(operator.skills[1].skill_name in view._info_layout_paragraphs and "被动 · 部署即生效" in view._info_layout_paragraphs, "Reserve shows actual S2 name and trigger"): return
		state.units[0].sp = SkillRules.sp_limit(operator.skills[1])
		state.units[0].hp = operator.max_health / 2
		state.units[0].attack_ticks_left = 1
		state.step([], [])
		input.select_unit(0)
		if not await render(state, view, id + "-s2"): return
		if not check(state.units[0].sp == 0 and state.units[0].skill_ticks_left == 0 and operator.skills[1].trigger_type == "passive", "S2 retains three charges and no manual activation"): return
		view._activate_selected_skill()
		if not check(input.take_commands().is_empty(), "S2 button cannot queue a manual command"): return
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
		if not check(SkillRules.attack_interval_ticks(state.units[1], operator) == 36 and SkillRules.block_count_value(state.units[1], operator) == 3, "Actual S3 interval and block state"): return
		if not check(operator.skills[2].skill_name in view._info_layout_paragraphs and "手动触发" in view._info_layout_paragraphs, "Actual S3 name/trigger shown"): return
		var expected: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT]
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
	print("Hoshiguma skill view OK: actual deployment, automatic charges, manual S3, source range, attribute/interval/block status, read-only rendering")
	quit(0)


func render(state: MatchState, view: MatchView, name: String) -> bool:
	var before := state.state_hash()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not check(before == state.state_hash(), "View changed simulation: " + name): return false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not check(root.get_texture().get_image().save_png("res://.godot/hoshiguma-" + name + ".png") == OK, "Screenshot failed"): return false
	return true


func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
