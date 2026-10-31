extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data := {}
	for id in root.get_node("OperatorDB").all_ids():
		data[id] = root.get_node("OperatorDB").get_data(id)
	var squad: PackedStringArray = root.get_node("OperatorDB").all_ids().slice(0, 12)
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(117, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [squad, squad])
			state.sides[side].cost = 99
			state.sides[side].tactical_items = [2, 2, 2, 0]
			var unit := UnitState.new(0, side, "bagpipe", Vector2i(18 if side == 0 else 2, 5), 2484, 35, 30, 2 if side == 0 else 0)
			state.units.append(unit)
			state.next_unit_id = 1
			var input := LocalInput.new(side)
			var view := MatchView.new()
			root.add_child(view)
			view.bind(state, input, data)
			view.mirror_board = mirrored
			var before := state.state_hash()
			await process_frame
			await process_frame
			if not _check(not view._hud_visible() and view._tray_count() == 14 and Engine.time_scale == 1.0, "Unselected battlefield has no side panel or slow motion"): return
			if not _check(is_equal_approx(ViewPalette.BOARD_PROJECTED_WIDTH / ViewPalette.BOARD_PROJECTED_HEIGHT, 756.0 / 360.0), "Board grows uniformly"): return
			for i in view._tray_count():
				if not _check(not view._card_rect(i).intersects(view._cost_rect()) and Rect2(Vector2.ZERO, Vector2(ViewPalette.SCREEN_SIZE)).encloses(view._card_rect(i)), "All cards fit without scrolling and cost sits above the tray"): return
			if not await _capture("clear-%d-%d" % [side, int(mirrored)]): return
			_mouse(view, view.projection.cell_rect(unit.cell).get_center())
			await process_frame
			await process_frame
			if not _check(input.selected_unit_id == 0 and view._hud_visible() and view._hud_expanded() and view._info_tab == MatchView.InfoTab.SKILL and state.state_hash() == before, "Unit click defaults to read-only skill details"): return
			if not await _capture("compact-%d-%d" % [side, int(mirrored)]): return
			_mouse(view, view._details_rect().get_center())
			await process_frame
			await process_frame
			if not _check(not view._hud_expanded(),"Collapse returns to compact command card"):return
			_mouse(view, view._details_rect().get_center())
			await process_frame
			await process_frame
			if not _check(view._hud_expanded() and state.state_hash() == before and input.take_commands().is_empty(), "Details change only the visual layout"): return
			if not await _capture("details-%d-%d" % [side, int(mirrored)]): return
			_mouse(view, view._hud_rect().position + Vector2(10, 200), true, MOUSE_BUTTON_RIGHT)
			if not _check(input.take_commands().is_empty(), "Right click on information does not retreat a hidden unit"): return
			_mouse(view, view._close_info_rect().get_center())
			if not _check(not view._hud_visible() and input.take_commands().is_empty(), "Closing restores battlefield clicks without commands"): return
			if not _check(view._cost_rect().end.y < view._card_rect(0).position.y and state.state_hash() == before, "Cost is above the complete tray"): return
			var index := view._tray_operator_ids().find("blaze")
			_mouse(view, view._card_rect(index).get_center())
			if not _check(view._deploy_phase == MatchView.DeployPhase.DRAGGING and not view._hud_visible(), "Active drag leaves battlefield uncovered"): return
			await process_frame
			await process_frame
			var target := Vector2i(11 if side == 0 else 9, 5)
			_mouse(view, view.projection.cell_rect(target).get_center(), false)
			await process_frame
			await process_frame
			if not _check(view._deploy_phase == MatchView.DeployPhase.FACING and view._hud_visible() and not view._hud_expanded(), "Facing preview keeps compact confirmation"): return
			_mouse(view, view._skill_rect().get_center())
			var commands := input.take_commands()
			if not _check(commands.size() == 1 and commands[0].cell == target and state.state_hash() == before and Engine.time_scale == 1.0, "Confirmation forwards exactly one deployment intent"): return
			state.step([], [])
			if not _check(state.tick == 1 and Engine.time_scale == 1.0, "Inspection does not slow the fixed simulation tick"): return
			view.free()
	print("BATTLE_LAYOUT_OK: enlarged board, optional compact/details, input isolation, complete tray without scrolling, drag/facing, side2/mirror2, readonly and real-time")
	quit(0)

func _mouse(view: MatchView, point: Vector2, pressed: bool = true, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.pressed = pressed
	event.button_index = button
	view._unhandled_input(event)

func _capture(label: String) -> bool:
	if DisplayServer.get_name() == "headless": return true
	await RenderingServer.frame_post_draw
	return _check(root.get_texture().get_image().save_png("res://.godot/battle-layout-%s.png" % label) == OK, "Save layout screenshot")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
