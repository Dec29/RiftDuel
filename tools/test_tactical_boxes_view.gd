extends SceneTree

const CONFIG := preload("res://data/config.gd")

class RecordingView extends MatchView:
	var labels: Array[String] = []
	func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
		labels.append(text)
		super._draw_text(position, text, font_size, color)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {}
	for id in CONFIG.DEFAULT_SQUAD_IDS:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var state := MatchState.new(71, data)
	state.tick = 1800
	state.box_warning_cell = Vector2i(12, 7)
	state.tactical_boxes = [TacticalBox.new(0, Vector2i(11, 3), 2), TacticalBox.new(1, Vector2i(14, 5), 1)]
	state.sides[0].tactical_items = [2, 1, 3, 0]
	state.sides[1].tactical_items = [1, 2, 0, 0]
	for side in 2:
		for mirrored in [false, true]:
			var input := LocalInput.new(side)
			var view := RecordingView.new()
			root.add_child(view)
			view.bind(state, input, data)
			view.mirror_board = mirrored
			input.select_operator("bagpipe")
			view._preview_cell = state.box_warning_cell
			var before := state.state_hash()
			if not _check(not DeployInteraction.preview_is_legal(view), "Preview rejects warning cell on either side"): return
			view._preview_cell = state.tactical_boxes[0].cell
			if not _check(not DeployInteraction.preview_is_legal(view), "Preview rejects box cell on either side"): return
			input.clear_selection()
			view._preview_cell = Vector2i(-1, -1)
			view.queue_redraw()
			await process_frame
			await process_frame
			if not _check(view.labels.has("!"), "Warning remains visible"): return
			for kind in CONFIG.TACTICAL_ITEM_COUNT:
				if not _check(view.labels.has(MatchView.ITEM_NAMES[kind]) == (state.sides[side].tactical_items[kind] > 0), "Only owned item types have visible cards without quantity text"): return
			if not _check(state.state_hash() == before and input.take_commands().is_empty(), "Rendering and preview are read-only"): return
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				if not _check(root.get_texture().get_image().save_png("res://.godot/tactical-box-side%d-mirror%d-view.png" % [side, int(mirrored)]) == OK, "Save box screenshot"): return
			view.free()
	var controlled := MatchState.new(72, data)
	controlled.tick = 420
	controlled.platform_cells.append(Vector2i(11, 3))
	var blaze: OperatorData = data["blaze"]
	controlled.units.append(UnitState.new(0, 1, "blaze", Vector2i(9, 5), blaze.max_health, 0, 30))
	controlled.units[0].stun_ticks_left = 360
	var input := LocalInput.new(0)
	var view := RecordingView.new()
	root.add_child(view)
	view.bind(controlled, input, data)
	input.select_unit(0)
	view._info_tab = MatchView.InfoTab.COMMAND
	var before := controlled.state_hash()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(view.labels.has("晕") and view.labels.has("眩晕剩余 12.0秒 · 停攻／阻挡0") and controlled.state_hash() == before, "Stun countdown and platform rendering stay read-only"): return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png("res://.godot/tactical-items-status-view.png") == OK, "Save status screenshot"): return
	view._info_tab = MatchView.InfoTab.TALENT
	view.labels.clear()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(view.labels.has("严酷训练（生效倒计时 1.0秒）") and controlled.state_hash() == before, "Resistance shows warmup rather than premature active"): return
	controlled.tick = 450
	before = controlled.state_hash()
	view.labels.clear()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(view.labels.has("严酷训练（已生效）") and controlled.state_hash() == before and input.take_commands().is_empty(), "Resistance activates at15 seconds without view state writes"): return
	view.free()
	print("Tactical view OK: warnings, hits, inventory, both sides/mirrors, platforms/stun/resistance warmup, previews and rendering read-only")
	quit(0)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
