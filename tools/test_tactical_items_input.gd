extends SceneTree

const CONFIG := preload("res://data/config.gd")
const RANGE := preload("res://sim/attack_range.gd")

class RecordingView extends MatchView:
	var labels: Array[String] = []
	func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
		labels.append(text)
		super._draw_text(position, text, font_size, color)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {}
	var db := root.get_node("OperatorDB")
	for id in db.all_ids():
		data[id] = db.get_data(id)
	var squad: PackedStringArray = db.all_ids().slice(0, 12)
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(117, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [squad, squad])
			state.sides[side].cost = 99
			state.sides[side].tactical_items = [4, 2, 2, 0]
			var input := LocalInput.new(side)
			var view := RecordingView.new()
			root.add_child(view)
			view.bind(state, input, data)
			view.mirror_board = mirrored
			var before := state.state_hash()
			if not _check(view._tray_count() == 15, "12 operators and3 stacked item types share one row"): return
			for index in view._tray_count():
				var card := view._card_rect(index)
				if not _check(card.position.y == ViewPalette.CARD_ORIGIN.y and card.position.x >= 0 and card.end.x <= ViewPalette.SCREEN_SIZE.x and card.size.y == ViewPalette.CARD_SIZE.y, "Visible cards remain whole and inside canvas"): return
			var last_card := view._card_rect(14)
			_mouse(view, last_card.get_center(), true, MOUSE_BUTTON_WHEEL_DOWN)
			if not _check(view._card_rect(14) == last_card and state.state_hash() == before and input.take_commands().is_empty(), "Wheel does not move the complete tray or simulation"): return
			view.queue_redraw()
			await process_frame
			await process_frame
			if not _check(view.labels.has("雪雉的起重机") and view.labels.has("娜丝缇的高台") and view.labels.has("轰隆隆先生"), "All item names visible without scrolling"): return
			for label in view.labels:
				if not _check(not label.begins_with("道具：") and not label.begins_with("持有 "), "No tactical item quantity display"): return
			if side == 0 and not mirrored and not await _screenshot("tactical-tray12-items-view.png"): return
			var card := _item_rect(view, 1)
			_mouse(view, card.get_center(), true)
			_mouse(view, card.get_center(), false)
			if not _check(input.selected_item_kind == 1 and view._deploy_phase == MatchView.DeployPhase.IDLE and input.take_commands().is_empty() and state.state_hash() == before, "Item click shows info without consuming"): return
			if not await _drag(view, 1, Vector2i(10, 3)): return
			if not _check(input.take_commands().is_empty() and state.state_hash() == before, "Illegal middle drop consumes nothing"): return
			var high_cell := Vector2i(13 if side == 0 else 7, 3)
			_mouse(view, _item_rect(view, 1).get_center(), true)
			_motion(view, view.projection.cell_rect(high_cell).get_center())
			var escape := InputEventKey.new()
			escape.pressed = true
			escape.keycode = KEY_ESCAPE
			view._unhandled_input(escape)
			if not _check(input.take_commands().is_empty() and state.state_hash() == before, "Escape cancels item preview"): return
			if not await _drag(view, 1, high_cell): return
			var commands := input.take_commands()
			if not _check(commands.size() == 1 and commands[0].kind == InputCommand.Kind.USE_ITEM and commands[0].item_kind == 1 and commands[0].cell == high_cell and commands[0].facing == -1 and state.state_hash() == before, "Platform drop queues one mirrored-correct intent"): return
			var empty: Array[InputCommand] = []
			state.step(commands if side == 0 else empty, commands if side == 1 else empty)
			if not await _preview_frame(view, "Platform rise", false): return
			for label in view.labels:
				if not _check(not label.begins_with("道具：") and not label.begins_with("持有 "), "No tactical item quantity display"): return
			if side == 0 and not mirrored and not await _screenshot("tactical-platform-rise-view.png"): return
			if not _check(state.platform_cells == [high_cell] and state.sides[side].tactical_items[1] == 1, "Platform only applied by simulation"): return
			var stun_cell := Vector2i(7 if side == 0 else 13, 5)
			var enemy: OperatorData = data["bagpipe"]
			state.units.append(UnitState.new(0, 1 - side, "bagpipe", stun_cell + Vector2i.LEFT, enemy.max_health, 0, 30))
			before = state.state_hash()
			if not await _drag(view, 2, stun_cell): return
			commands = input.take_commands()
			if not _check(commands.size() == 1 and commands[0].item_kind == 2 and commands[0].cell == stun_cell and state.state_hash() == before, "Stun drop allowed in opposing deployment region, still read-only"): return
			state.step(commands if side == 0 else empty, commands if side == 1 else empty)
			if not _check(state.units[0].stun_ticks_left == 0 and state.item_reserves_cell(stun_cell), "Simulation consumes item, reserves tile and delays stun"): return
			if not await _preview_frame(view, "Bomb windup", false): return
			for label in view.labels:
				if not _check(not label.begins_with("道具：") and not label.begins_with("持有 "), "No tactical item quantity display"): return
			if side == 0 and not mirrored and not await _screenshot("tactical-bomb-windup-view.png"): return
			for elapsed in CONFIG.ITEM_STUN_WINDUP_TICKS:
				state.step([], [])
			if not _check(state.units[0].stun_ticks_left == 360 and not state.item_reserves_cell(stun_cell), "Blast applies stun at30 ticks and frees tile"): return
			if not await _preview_frame(view, "Bomb explosion", false): return
			for label in view.labels:
				if not _check(not label.begins_with("道具：") and not label.begins_with("持有 "), "No tactical item quantity display"): return
			if side == 0 and not mirrored and not await _screenshot("tactical-bomb-explosion-view.png"): return
			var target := Vector2i(12 if side == 0 else 8, 5)
			var blaze: OperatorData = data["blaze"]
			for facing in 4:
				state.units.append(UnitState.new(facing + 1, side, "blaze", target, blaze.max_health, 0, 30))
				var crane_cell := target - RANGE.rotate_offset(Vector2i.RIGHT, facing)
				before = state.state_hash()
				if not await _drag(view, 0, crane_cell): return
				if not _check(view._deploy_phase == MatchView.DeployPhase.FACING and input.take_commands().is_empty() and state.state_hash() == before, "Crane drop enters facing stage, no consumption"): return
				var center := view.projection.cell_rect(crane_cell).get_center()
				var end := center + view.projection.view_direction(Vector2(RANGE.rotate_offset(Vector2i.RIGHT, facing))) * 72
				_mouse(view, center, true)
				_motion(view, end)
				if not await _preview_frame(view, "Crane facing drag", true): return
				_mouse(view, end, false)
				commands = input.take_commands()
				if not _check(commands.size() == 1 and commands[0].item_kind == 0 and commands[0].facing == facing and commands[0].cell == crane_cell and state.state_hash() == before, "Crane direction%d side%d mirror%d sends one correct intent" % [facing, side, int(mirrored)]): return
				state.step(commands if side == 0 else empty, commands if side == 1 else empty)
				if not await _preview_frame(view, "Crane lift", false): return
				if side == 0 and not mirrored and facing == 0 and not await _screenshot("tactical-crane-lift-view.png"): return
				if not _check(state.units.size() == 1 and state.sides[side].cooldowns["blaze"] == 150, "Crane effects applied only by sim"): return
			if not _check(state.sides[side].tactical_items[0] == 0 and 0 not in view._tray_item_kinds(), "Used-up kind disappears from tray"): return
			before = state.state_hash()
			_mouse(view, _item_rect(view, 1).get_center(), true)
			_mouse(view, _item_rect(view, 1).get_center(), false)
			if not _check(input.selected_item_kind == 1, "Neighbor card receives click after consumed kind shifts positions"): return
			_mouse(view, view._cancel_rect().get_center(), true)
			if not _check(input.selected_item_kind == -1 and input.take_commands().is_empty(), "Close item information has no command"): return
			_mouse(view, _item_rect(view, 1).get_center(), true)
			_motion(view, view.projection.cell_rect(Vector2i(13 if side == 0 else 7, 4)).get_center())
			_mouse(view, view.projection.cell_rect(Vector2i(13 if side == 0 else 7, 4)).get_center(), true, MOUSE_BUTTON_RIGHT)
			if not _check(view._deploy_phase == MatchView.DeployPhase.IDLE and input.take_commands().is_empty() and state.state_hash() == before, "Right-click cancels item preview without consumption"): return
			view.queue_redraw()
			await process_frame
			await process_frame
			if not _check(state.state_hash() == before, "Post-consumption row/render stays read-only"): return
			view.free()
	print("Tactical input OK:12+3 one row/no scrolling/stacking, side2/mirror2/facing4, info/cancel/invalid, intent-only platform/stun/crane consumption")
	quit(0)


func _item_rect(view: MatchView, kind: int) -> Rect2:
	return view._card_rect(view._tray_operator_ids().size() + view._tray_item_kinds().find(kind))


func _drag(view: RecordingView, kind: int, cell: Vector2i) -> bool:
	_mouse(view, _item_rect(view, kind).get_center(), true)
	_motion(view, view.projection.cell_rect(cell).get_center())
	if not await _preview_frame(view, "Item%d held drag" % kind, true): return false
	if kind == 0 and view._local_input.side == 0 and not view.mirror_board:
		if not await _screenshot("crane-held-drag-view.png"): return false
	_mouse(view, view.projection.cell_rect(cell).get_center(), false)
	if not await _preview_frame(view, "Item%d after drop" % kind, kind == 0): return false
	if kind == 0 and view._local_input.side == 0 and not view.mirror_board:
		if not await _screenshot("crane-facing-preview-view.png"): return false
	return true


func _preview_frame(view: RecordingView, stage: String, item_info: bool) -> bool:
	var before := view._state.state_hash()
	view.labels.clear()
	view.queue_redraw()
	await process_frame
	await process_frame
	return _check(view.labels.has("待部署干员") and (not item_info or view.labels.has("战术道具")) and view._state.state_hash() == before, stage + ": rendering must reach HUD/tray and preserve simulation")


func _mouse(view: MatchView, position: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.pressed = pressed
	event.button_index = button
	view._unhandled_input(event)


func _motion(view: MatchView, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	view._unhandled_input(event)


func _screenshot(name: String) -> bool:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		return _check(root.get_texture().get_image().save_png("res://.godot/" + name) == OK, "Save tray screenshot")
	return true


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
