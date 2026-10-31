extends SceneTree

class InspectionView extends MatchView:
	var labels := PackedStringArray()
	var range_cells: Array[Vector2i] = []

	func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
		labels.append(text)
		super._draw_text(position, text, font_size, color)

class InspectionRenderer extends BattleRenderer:
	func draw_range(view: MatchView, operator: OperatorData, cell: Vector2i, facing: int) -> void:
		var inspection := view as InspectionView
		for offset in operator.attack_range:
			inspection.range_cells.append(cell + MatchView.RANGE.rotate_offset(offset, facing))
		super.draw_range(view, operator, cell, facing)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := {}
	var database := root.get_node("OperatorDB")
	for id in database.all_ids():
		definitions[id] = database.get_data(id)
	var state := MatchState.new(0x52494654, definitions)
	var input := LocalInput.new(0)
	var view := InspectionView.new()
	view.renderer = InspectionRenderer.new()
	view.bind(state, input, definitions)
	root.add_child(view)
	state.units = [UnitState.new(0, 0, "bagpipe", Vector2i(12, 5), 2484, 35, 1, 2), UnitState.new(1, 1, "bagpipe", Vector2i(8, 5), 1700, 35, 1, 3)]
	state.next_unit_id = 2
	var enemy := state.units[1]
	var before := state.state_hash()
	_click(view, view.projection.cell_rect(enemy.cell).get_center())
	if not _check(input.selected_unit_id == enemy.unit_id and view._selected_unit() == enemy and state.state_hash() == before, "Clicking enemy must select its live state without a simulation write"):
		return
	if not _check(view._info_tab == MatchView.InfoTab.SKILL,"Enemy inspection defaults to equipped skill information"):
		return
	view._info_tab = MatchView.InfoTab.COMMAND
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(view.labels.has("敌方干员 · 作战信息") and view.labels.has("生命  1700 / 2484") and view.labels.has("技力  35 / 35") and view.labels.has("技能就绪") and view.labels.has("敌方干员 · 仅查看") and view.labels.has("不可撤退") and view.range_cells.has(Vector2i(8, 4)) and not view.range_cells.has(Vector2i(9, 5)), "Enemy panel must preserve HP, SP, ready state and north-facing range; labels=%s range=%s" % [view.labels, view.range_cells]):
		return
	for ticks in [60, -1]:
		enemy.skill_ticks_left = ticks
		view.labels.clear()
		view.queue_redraw()
		await process_frame
		await process_frame
		if not _check(view.labels.has("技能生效 · 剩余 2s" if ticks == 60 else "下次攻击已强化"), "Enemy skill state must remain visible for ticks=%d: %s" % [ticks, view.labels]):
			return
	enemy.skill_ticks_left = 0
	enemy.operator_id = "ceobe"
	enemy.sp = 12
	view.labels.clear()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(view.labels.has("充能 2 / 3"), "Enemy charge count must remain visible: %s" % view.labels):
		return
	enemy.operator_id = "swire_alter"
	view.labels.clear()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(view.labels.has("敌方干员 · 仅查看") and view.labels.has("金币  0 / 3"), "Enemy passive must show live coins and a read-only action"):
		return
	enemy.operator_id = "bagpipe"
	enemy.sp = 35
	before = state.state_hash()
	_click(view, view._skill_rect().get_center())
	_click(view, view._cancel_rect().get_center())
	_click(view, view.projection.cell_rect(enemy.cell).get_center(), MOUSE_BUTTON_RIGHT)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	view._unhandled_input(key)
	if not _check(input.take_commands().is_empty() and state.state_hash() == before, "Enemy skill button, space, retreat button and right-click must never create commands"):
		return
	if not _check(not view._tray_operator_ids().has("bagpipe") and view._tray_operator_ids().size() == definitions.size() - 1, "Own deployed Bagpipe must disappear from tray"):
		return
	state.units.remove_at(0)
	state.sides[0].cost = 0
	state.sides[0].cooldowns["bagpipe"] = 60
	if not _check(view._tray_operator_ids().has("bagpipe") and view._tray_operator_ids().size() == definitions.size(), "Retired own operator must reappear even during cooldown, with low cost and enemy duplicate"):
		return
	state.sides[0].cooldowns.clear()
	state.sides[0].cost = 99
	_click(view, view._card_rect(view._tray_operator_ids().find("bagpipe")).get_center())
	if not _check(input.selected_operator_id == "bagpipe" and view._deploy_phase == MatchView.DeployPhase.DRAGGING, "Dynamic tray slot must select correct operator and exit enemy inspection"):
		return
	DeployInteraction.cancel(view)
	state.units.insert(0, UnitState.new(0, 0, "bagpipe", Vector2i(12, 5), 2484, 35))
	_click(view, view.projection.cell_rect(state.units[0].cell).get_center())
	view._unhandled_input(key)
	_click(view, view._cancel_rect().get_center())
	var commands := input.take_commands()
	if not _check(commands.size() == 2 and commands[0].kind == InputCommand.Kind.SKILL and commands[1].kind == InputCommand.Kind.RETREAT, "Switching back to own unit must restore skill and retreat commands"):
		return
	state.units = [enemy]
	_click(view, view.projection.cell_rect(enemy.cell).get_center())
	state.units.clear()
	before = state.state_hash()
	view._unhandled_input(key)
	_click(view, view._cancel_rect().get_center())
	if not _check(view._selected_unit() == null and input.take_commands().is_empty() and state.state_hash() == before, "Removed enemy must not leave stale details or commands"):
		return
	for index in view._operator_ids.size():
		state.units.append(UnitState.new(index, 0, view._operator_ids[index], Vector2i(index, 0), 100))
	if not _check(view._tray_operator_ids() == PackedStringArray(["phantom_clone"]), "All ordinary own units deployed must leave only the eligible Phantom clone card"):
		return
	state.units.append(UnitState.new(state.units.size(), 0, "phantom_clone", Vector2i(18, 0), 1416))
	if not _check(view._tray_operator_ids().is_empty(), "Existing clone and all ordinary own units deployed must leave an empty tray"):
		return
	view.queue_redraw()
	await process_frame
	await process_frame
	state.units = [UnitState.new(0, 0, "bagpipe", Vector2i(12, 5), 2484, 35, 1, 2), enemy]
	_click(view, view.projection.cell_rect(enemy.cell).get_center())
	view.labels.clear()
	before = state.state_hash()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(state.state_hash() == before, "Enemy panel and range rendering must not write simulation state"):
		return
	var capture_args := OS.get_cmdline_user_args()
	if not capture_args.is_empty():
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(capture_args[0])
		if not _check(error == OK, "Cannot save enemy inspection screenshot: %s" % error_string(error)):
			return
	print("Enemy view OK: live HP/SP/status/facing, read-only controls, removed-unit selection, dynamic own-side tray")
	quit(0)


func _click(view: MatchView, position: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = true
	view._unhandled_input(event)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
