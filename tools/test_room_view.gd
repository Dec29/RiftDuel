extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var error := change_scene_to_file("res://view/start_menu.tscn")
	if not _check(error == OK, "Cannot open start menu"):
		return
	await process_frame
	await process_frame
	current_scene.get_node("Menu/Multiplayer").pressed.emit()
	await process_frame
	await process_frame
	var lobby := current_scene
	if not _check(lobby.scene_file_path == "res://lobby.tscn", "Multiplayer button did not enter lobby"):
		return
	var view := lobby.get_node("RoomView")
	var panel := view.get_node("Center/Panel")
	if not _check(lobby.session is RelaySession and panel.get_node("Mode").selected == 0 and not panel.get_node("AddressRow").visible, "Multiplayer defaults to internet without LAN address row"):
		return
	panel.get_node("Mode").select(1)
	panel.get_node("Mode").item_selected.emit(1)
	if not _check(not lobby.session is RelaySession and panel.get_node("AddressRow").visible, "LAN remains available through mode selection"):
		return
	var capture_args := OS.get_cmdline_user_args()
	if not capture_args.is_empty():
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(capture_args[0].get_basename() + "_choose.png") == OK, "Cannot save room selection screenshot"):
			return
	panel.get_node("Create").pressed.emit()
	if not _check(lobby.session.phase == "hosting" and lobby.session.room_code.length() == 6 and panel.get_node("Room").visible and panel.get_node("Room/ReadyRow/Start").disabled, "Create room must show code without allowing premature start"):
		return
	if not capture_args.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(capture_args[0].get_basename() + "_host.png") == OK, "Cannot save host screenshot"):
			return
	var client := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(client)
	client.join_code(lobby.session.room_code)
	var deadline := Time.get_ticks_msec() + 4000
	while client.phase in ["searching", "connecting"] and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "room" and lobby.session.phase == "room", "Room code could not join from UI-created room: %s / %s" % [lobby.session.status, client.status]):
		return
	panel.get_node("Room/Columns/Rules/Draft").set_pressed(false)
	while client.rules.draft_enabled and Time.get_ticks_msec() < deadline: await process_frame
	if not _check(not client.rules.draft_enabled,"Disabled draft setting reaches guest before readiness"): return
	panel.get_node("Room/ReadyRow/Ready").pressed.emit()
	client.set_ready(true)
	deadline = Time.get_ticks_msec() + 2000
	while not lobby.session.remote_ready and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(not panel.get_node("Room/ReadyRow/Start").disabled, "Start button should enable only after both ready"):
		return
	panel.get_node("Room/ReadyRow/Start").pressed.emit()
	deadline = Time.get_ticks_msec() + 2000
	while (current_scene == lobby or client.phase == "room") and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(current_scene != lobby and client.phase == "loading", "Room must transfer both players into loading"):
		return
	client.mark_loaded()
	var battle := current_scene
	if not _check(battle.session != null and battle.ai_input == null and not battle.get_node("PauseLayer/PauseMenu").visible, "Multiplayer scene must reuse session, omit AI and disable pause"):
		return
	deadline = Time.get_ticks_msec() + 8000
	while client.phase != "running" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "running" and battle.session.phase == "running", "Scene transition must preserve connection and loaded barrier: %s / %s" % [client.status,battle.session.status]):
		return
	client.leave()
	await process_frame
	await process_frame
	deadline = Time.get_ticks_msec() + 2000
	while battle.session.phase != "failed" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(battle.get_node("NetworkLayer/NetworkHUD/Failure").visible, "Disconnected match must show failure overlay"):
		return
	battle.get_node("NetworkLayer/NetworkHUD/Failure/Panel/Return").pressed.emit()
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://view/start_menu.tscn" and not paused, "Disconnect return must reach unpaused menu"):
		return
	client.queue_free()
	print("Room view OK: multiplayer entry, room code, ready/start, scene transfer, no AI/pause, disconnect return")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
