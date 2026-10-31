extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {"exusiai": load("res://resources/operators/exusiai.tres")}
	var squads: Array = [PackedStringArray(["exusiai"]), PackedStringArray(["exusiai"])]
	var skills: Array = [PackedInt32Array([1]), PackedInt32Array([2])]
	var state := MatchState.new(123, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads, skills)
	state.sides[0].cost = 99
	state.sides[1].cost = 99
	state.step([InputCommand.new(0, 0, "exusiai", -1, Vector2i(12, 2), -1, 2)], [InputCommand.new(0, 0, "exusiai", -1, Vector2i(8, 2), -1, 0)])
	var input := LocalInput.new(0)
	var view := MatchView.new()
	view.bind(state, input, data)
	root.add_child(view)
	input.select_operator("exusiai")
	view._info_tab = view.InfoTab.SKILL
	if not await render(state, view, "reserve-s2"): return
	if not check("扫射模式" in view._info_layout_paragraphs and "过载模式" not in view._info_layout_paragraphs, "Reserve details use carried S2"): return
	input.select_unit(0)
	view._info_tab = view.InfoTab.COMMAND
	state.units[0].sp = 35
	if not await render(state, view, "ready-s2"): return
	view._activate_selected_skill()
	var commands := input.take_commands()
	if not check(commands.size() == 1 and commands[0].skill_index == 1 and commands[0].unit_id == 0, "Manual button forwards equipped index"): return
	state.step(commands, [])
	if not await render(state, view, "active-s2"): return
	view._info_tab = view.InfoTab.SKILL
	if not await render(state, view, "details-s2"): return
	if not check("扫射模式" in view._info_layout_paragraphs and "手动触发" in view._info_layout_paragraphs, "Deployed skill tab uses S2 name/trigger"): return
	input.select_unit(1)
	view._info_tab = view.InfoTab.COMMAND
	state.units[1].sp = 30
	state.step([], [])
	if not await render(state, view, "enemy-active-s3"): return
	view._activate_selected_skill()
	if not check(input.take_commands().is_empty(), "Enemy auto skill remains read-only"): return
	view._info_tab = view.InfoTab.SKILL
	if not await render(state, view, "enemy-details-s3"): return
	if not check("过载模式" in view._info_layout_paragraphs and "自动触发" in view._info_layout_paragraphs, "Enemy details use its independent S3"): return
	view.queue_free()
	print("Exusiai skill view OK: reserve/deployed/enemy names, progress, input index, read-only frames")
	quit(0)


func render(state: MatchState, view: MatchView, name: String) -> bool:
	var before := state.state_hash()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not check(before == state.state_hash(), "Render changed simulation: " + name): return false
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not check(root.get_texture().get_image().save_png("res://.godot/exusiai-" + name + ".png") == OK, "Screenshot failed"): return false
	return true


func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
