extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {"schwarz": load("res://resources/operators/schwarz.tres")}
	var squads: Array = [PackedStringArray(["schwarz"]), PackedStringArray(["schwarz"])]
	var skills: Array = [PackedInt32Array([1]), PackedInt32Array([2])]
	var state := MatchState.new(123, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads, skills)
	state.sides[0].cost = 99
	state.sides[1].cost = 99
	state.step([InputCommand.new(0, 0, "schwarz", -1, Vector2i(12, 2), -1, 2)], [InputCommand.new(0, 0, "schwarz", -1, Vector2i(8, 8), -1, 0)])
	var input := LocalInput.new(0)
	var view := MatchView.new()
	view.bind(state, input, data)
	root.add_child(view)
	input.select_operator("schwarz")
	view._info_tab = view.InfoTab.SKILL
	if not await render(state, view, "reserve-s2"): return
	if not check("暮眼锐瞳" in view._info_layout_paragraphs and "战术的终结" not in view._info_layout_paragraphs, "Reserve details use carried S2"): return
	input.select_unit(0)
	view._info_tab = view.InfoTab.COMMAND
	state.units[0].sp = 30
	if not await render(state, view, "ready-s2"): return
	view._activate_selected_skill()
	var commands := input.take_commands()
	if not check(commands.size() == 1 and commands[0].skill_index == 1 and commands[0].unit_id == 0, "Manual button forwards equipped index"): return
	state.step(commands, [])
	if not await render(state, view, "active-s2"): return
	view._info_tab = view.InfoTab.SKILL
	if not await render(state, view, "details-s2"): return
	if not check("暮眼锐瞳" in view._info_layout_paragraphs and "手动触发" in view._info_layout_paragraphs, "Deployed skill tab uses S2 name/trigger"): return
	input.select_unit(1)
	view._info_tab = view.InfoTab.COMMAND
	state.units[1].sp = 25
	state.step([], [InputCommand.new(state.tick, 1, "", 1, Vector2i.ZERO, 2)])
	if not await render(state, view, "enemy-active-s3"): return
	view._activate_selected_skill()
	if not check(input.take_commands().is_empty(), "Enemy manual skill remains read-only"): return
	view._info_tab = view.InfoTab.SKILL
	if not await render(state, view, "enemy-details-s3"): return
	if not check("战术的终结" in view._info_layout_paragraphs and "手动触发" in view._info_layout_paragraphs, "Enemy details use its independent S3"): return
	for side in 2:
		for mirrored in [false, true]:
			input.side = side
			view.mirror_board = mirrored
			var unit := state.units[side]
			input.select_unit(unit.unit_id)
			for facing in 4:
				unit.facing = facing
				if not check(view._range_offsets(data["schwarz"], unit.cell) == (data["schwarz"].attack_range if side == 0 else data["schwarz"].skills[2].attack_range_override), "Active range matches sim, independent choice"): return
				if not await render(state, view, "side%d-mirror%d-facing%d" % [side, int(mirrored), facing]): return
	state.units[1].skill_ticks_left = 1
	state.step([], [])
	if not check(view._range_offsets(data["schwarz"],state.units[1].cell) == data["schwarz"].attack_range, "Displayed range restores at expiry"): return
	view.queue_free()
	print("Schwarz skill view OK: reserve/deployed/enemy names, progress, input index, read-only frames")
	quit(0)


func render(state: MatchState, view: MatchView, name: String) -> bool:
	var before := state.state_hash()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not check(before == state.state_hash(), "Render changed simulation: " + name): return false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not check(root.get_texture().get_image().save_png("res://.godot/schwarz-" + name + ".png") == OK, "Screenshot failed"): return false
	return true


func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
