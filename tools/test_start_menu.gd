extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var startup: String = ProjectSettings.get_setting("application/run/main_scene")
	if not _check(startup == "res://view/start_menu.tscn", "Startup must open the start menu, got " + startup):
		return
	var error := change_scene_to_file(startup)
	if not _check(error == OK, "Cannot open startup: " + error_string(error)):
		return
	await process_frame
	await process_frame
	var menu := current_scene
	var title := menu.get_node("Title") as Label
	if not _check(title.text == "明日方舟：逐界争锋" and title.get_global_rect().get_center().x == 640 and title.position.y < 240, "Title must be centered near the top: " + str(title.get_global_rect())):
		return
	if not _check(menu.get_node("Subtitle").text == "Arknights：RiftDuel" and not menu.has_node("Notice"), "Start menu must show the requested subtitle without a footer notice"):
		return
	var entries := menu.get_node("Menu").get_children()
	var expected := ["单人模式", "多人模式", "编队", "设置"]
	if not _check(entries.size() == 4, "Menu must contain four entries, got %d" % entries.size()):
		return
	for index in 4:
		var button := entries[index] as Button
		if not _check(button.text == expected[index] and not button.disabled and button.get_global_rect().get_center().x == 640, "Entry %d has wrong label, availability or alignment: %s" % [index, button.text]):
			return
		if index > 0 and not _check(button.position.y > entries[index - 1].position.y, "Entries must appear in requested vertical order"):
			return
	if not _check(root.get_node("OperatorDB").all_ids().has("shining") and menu.get_child_count() == 3, "Menu must register Shining without creating a battle"):
		return
	var capture_args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var first_image := root.get_texture().get_image()
		if not capture_args.is_empty() and not _check(first_image.save_png(capture_args[0]) == OK, "Cannot save start-menu screenshot"):
			return
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		var second_image := root.get_texture().get_image()
		if not _check(first_image.get_region(Rect2i(360, 280, 560, 340)).get_data() != second_image.get_region(Rect2i(360, 280, 560, 340)).get_data(), "Polyhedron must visibly rotate between rendered frames"):
			return
		if not _check(first_image.get_region(Rect2i(448, 267, 384, 7)).get_data() != second_image.get_region(Rect2i(448, 267, 384, 7)).get_data(), "Title underline must visibly slide between rendered frames"):
			return
		if not capture_args.is_empty() and not _check(second_image.save_png(capture_args[0].get_basename() + "-animated.png") == OK, "Cannot save animated start-menu screenshot"):
			return
	for route in [["Settings", "res://view/settings_menu.tscn"], ["Squad", "res://view/squad_menu.tscn"], ["Multiplayer", "res://lobby.tscn"]]:
		current_scene.get_node("Menu/" + route[0]).pressed.emit()
		await process_frame
		await process_frame
		if not _check(current_scene.scene_file_path == route[1], "Animated menu must still open " + route[0]):
			return
		if not _check(change_scene_to_file(startup) == OK, "Cannot reopen start menu"):
			return
		await process_frame
		await process_frame
	entries = current_scene.get_node("Menu").get_children()
	entries[0].pressed.emit()
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://solo_setup.tscn", "Single-player must open preparation"):
		return
	if not _check(current_scene.scene_file_path == "res://solo_setup.tscn" and current_scene.rules.mode == "score", "Single-player preparation defaults to timed score"): return
	current_scene.get_node("RoomView/Center/Panel/Room/ReadyRow/Start").pressed.emit()
	await process_frame
	await process_frame
	var battle := current_scene
	var deadline := Time.get_ticks_msec()+15000
	while battle.match_state.tick == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(battle.match_state != null and battle.local_input.side == 0 and battle.ai_input.side == 1 and battle.match_state.tick > 0, "Single-player battle must run with local player and mirror AI"):
		return
	print("Start menu OK: startup, title, rotating background, sliding underline, all four routes and running battle")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
