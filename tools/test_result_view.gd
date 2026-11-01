extends SceneTree

class ResultView extends MatchView:
	var labels := PackedStringArray()
	func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
		labels.append(text)
		super._draw_text(position, text, font_size, color)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void: quit(1))
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	var battle = current_scene
	battle.match_state.tick = Config.MATCH_TICKS + Config.OVERTIME_TICKS - 1
	battle.match_state.units.clear()
	battle.match_state.ball.cell = Config.BALL_START_CELL
	var empty: Array[InputCommand] = []
	battle.match_state.step(empty, empty)
	await physics_frame
	await process_frame
	var frozen: int = battle.match_state.state_hash()
	await physics_frame
	await physics_frame
	if not _check(battle.match_state.result == 3 and battle.match_state.state_hash() == frozen and not battle.get_node("PauseLayer/PauseMenu").visible, "Draw must freeze battle and hide pause"):
		return
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	battle.match_view._unhandled_input(key)
	if not _check(battle.local_input.take_commands().is_empty(), "Finished battle must block skill input"):
		return
	var preview := ResultView.new()
	var state := MatchState.new(36, battle.match_view._operator_data)
	preview.bind(state, battle.local_input, battle.match_view._operator_data)
	root.add_child(preview)
	for verdict in [MatchState.RESULT_BLUE_WIN, MatchState.RESULT_RED_WIN]:
		state.result = verdict
		state.tick = Config.MATCH_TICKS
		preview.labels.clear()
		preview.queue_redraw()
		await process_frame
		await process_frame
		if not _check(preview.labels.has("时间结束 · 05:00") and preview.labels.has("蓝方胜利" if verdict == 1 else "红方胜利") and preview.labels.has("剩余  00:00"), "Normal-time settlement must not be mislabeled overtime"):
			return
	preview.queue_free()
	await process_frame
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(args[0]) == OK, "Cannot save draw screenshot"):
			return
	_click(battle.match_view, battle.match_view._result_home_rect().get_center())
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://view/start_menu.tscn" and not paused, "Result home must open unpaused start menu"):
		return
	var session := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(session)
	session.phase = "loading"
	session.round_number=1
	session.match_rules=MatchRules.new()
	var network_battle = load("res://main.tscn").instantiate()
	network_battle.session = session
	var menu := current_scene
	root.add_child(network_battle)
	session.side = 1
	network_battle.local_input.side = 1
	current_scene = network_battle
	menu.queue_free()
	network_battle.match_state.result = MatchState.RESULT_DRAW
	network_battle.match_state.tick = Config.MATCH_TICKS + Config.OVERTIME_TICKS
	await physics_frame
	await process_frame
	_click(network_battle.match_view, network_battle.match_view._result_room_rect().get_center())
	if not _check(current_scene == network_battle, "Unverified network result must disable return buttons"):
		return
	session.phase = "running"
	session._receive({"type": "finish", "tick": Config.MATCH_TICKS + Config.OVERTIME_TICKS, "result": MatchState.RESULT_DRAW})
	network_battle._physics_process(0.0)
	if not _check(network_battle.match_view.result_confirmed and not network_battle.get_node("NetworkLayer/NetworkHUD").visible, "Draw finish notification must unlock return after local result verification"):
		return
	session._fail("对方已离开对局")
	if not _check(not network_battle.get_node("NetworkLayer/NetworkHUD/Failure").visible and network_battle.match_state.result == MatchState.RESULT_DRAW, "Disconnect after verified result must not replace settlement"):
		return
	if not args.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(args[0].get_basename() + "_network.png") == OK, "Cannot save network settlement"):
			return
	_click(network_battle.match_view, network_battle.match_view._result_room_rect().get_center())
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://lobby.tscn" and current_scene.session.phase == "idle" and not is_instance_valid(session), "After peer departure return must dispose disconnected session and open pairing"):
		return
	if not _check(current_scene.session is RelaySession, "Returned room defaults to a fresh internet session"):
		return
	current_scene.get_node("RoomView/Center/Panel/Mode").select(1)
	current_scene.get_node("RoomView/Center/Panel/Mode").item_selected.emit(1)
	current_scene.get_node("RoomView/Center/Panel/Create").pressed.emit()
	if not _check(current_scene.session.phase == "hosting", "Returned room must be able to create again"):
		return
	current_scene.get_node("RoomView/Center/Panel/Footer/Back").pressed.emit()
	await process_frame
	await process_frame
	current_scene.get_node("Menu/SinglePlayer").pressed.emit()
	await process_frame
	await process_frame
	if not _check(current_scene.match_state.result == 0 and current_scene.match_state.tick < 30, "New match must reset previous result and time"):
		return
	print("Result view OK: draw/freeze, blocked input, home, verification gate, pairing after peer departure and new match")
	quit(0)

func _click(view: MatchView, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	view._unhandled_input(event)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
