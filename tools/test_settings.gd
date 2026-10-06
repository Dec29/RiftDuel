extends SceneTree

const PREFERENCES := preload("res://preferences.gd")
const TEST_PATH := "user://settings-test.cfg"
var _original := PackedByteArray()
var _had_original := false
var _deadline := 0
var _finished := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_deadline = Time.get_ticks_msec() + 20000
	_had_original = FileAccess.file_exists(PREFERENCES.FILE_PATH)
	if _had_original:
		_original = FileAccess.get_file_as_bytes(PREFERENCES.FILE_PATH)
	var preferences := PREFERENCES.new()
	if not _check(preferences.endpoint() == "wss://134.175.45.75/ws" and preferences.goal_position == "left" and not preferences.use_custom_server, "New preferences must use default server and left goal"):
		return
	for endpoint in ["wss://example.com:0/ws", "wss://example.com:99999/ws", "wss://example.com:-1/ws", "wss://example.com:abc/ws", "ws://127.0.0.1:0/ws", "ws://127.0.0.1:65536/ws"]:
		if not _check(not PREFERENCES.valid_endpoint(endpoint), "Invalid port accepted: " + endpoint):
			return
	if not _check(PREFERENCES.valid_endpoint("wss://example.com:1/ws") and PREFERENCES.valid_endpoint("wss://example.com:65535/ws"), "Valid explicit port boundaries rejected"):
		return
	preferences.use_custom_server = true
	preferences.custom_endpoint = "wss://example.com:443/ws"
	preferences.goal_position = "right"
	if not _check(preferences.write(TEST_PATH).is_empty(), "Cannot persist test settings"):
		return
	var loaded := PREFERENCES.new()
	if not _check(loaded.read(TEST_PATH).is_empty() and loaded.endpoint() == preferences.custom_endpoint and loaded.goal_position == "right", "Persisted settings lost endpoint or goal position"):
		return
	preferences.custom_endpoint = "ws://example.com/ws"
	if not _check(not preferences.write(TEST_PATH).is_empty() and loaded.read(TEST_PATH).is_empty() and loaded.endpoint() == "wss://example.com:443/ws", "Invalid custom server must be rejected without overwriting saved preferences"):
		return
	var invalid := ConfigFile.new()
	invalid.set_value("display", "goal_position", "center")
	invalid.save(TEST_PATH)
	if not _check(not loaded.read(TEST_PATH).is_empty(), "Invalid disk preferences must report error"):
		return
	preferences = PREFERENCES.new()
	if not _check(preferences.write().is_empty(), "Cannot establish isolated default UI settings"):
		return
	change_scene_to_file("res://view/start_menu.tscn")
	await process_frame
	await process_frame
	current_scene.get_node("Menu/Settings").pressed.emit()
	await process_frame
	await process_frame
	var settings := current_scene
	if not _check(settings.scene_file_path == "res://view/settings_menu.tscn", "Settings button did not open settings"):
		return
	var panel := settings.get_node("Center/Panel")
	if not _check(panel.get_node("Tabs").get_tab_title(0) == "连接" and panel.get_node("Tabs").get_tab_title(1) == "显示" and not panel.get_node("Tabs/Connection/Endpoint").visible, "Settings must have connection/display tabs and hidden custom endpoint by default"):
		return
	panel.get_node("Tabs/Connection/Custom").button_pressed = true
	panel.get_node("Tabs/Connection/Endpoint").text = "http://unsafe/ws"
	panel.get_node("Actions/Save").pressed.emit()
	if not _check(current_scene == settings and not panel.get_node("Status").text.is_empty(), "Invalid endpoint must keep settings open with error"):
		return
	panel.get_node("Actions/Cancel").pressed.emit()
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://view/start_menu.tscn" and preferences.read().is_empty() and not preferences.use_custom_server, "Cancel must return without saving drafts"):
		return
	current_scene.get_node("Menu/Settings").pressed.emit()
	await process_frame
	await process_frame
	panel = current_scene.get_node("Center/Panel")
	panel.get_node("Tabs/Connection/Custom").button_pressed = true
	panel.get_node("Tabs/Connection/Endpoint").text = "wss://example.com/ws"
	panel.get_node("Tabs/Display/Goal").select(1)
	panel.get_node("Actions/Save").pressed.emit()
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://view/start_menu.tscn" and preferences.read().is_empty() and preferences.endpoint() == "wss://example.com/ws" and preferences.goal_position == "right", "Save must persist both tabs and return"):
		return
	current_scene.get_node("Menu/SinglePlayer").pressed.emit()
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://main.tscn" and current_scene.local_input.side == 0 and not current_scene.match_view.mirror_board, "Saved right-side preference must reach blue-side match rendering"):
		return
	current_scene.match_view.home_requested.emit()
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://view/start_menu.tscn", "Match must return to menu after settings integration check"):
		return
	var room = preload("res://view/room_view.tscn").instantiate()
	root.add_child(room)
	var joins := []
	room.online_join_requested.connect(func(code: String, invite: String) -> void: joins.append([code, invite]))
	room.get_node("Center/Panel/Mode").select(1)
	room.update_room({"phase": "idle", "online": true, "status": "", "side": 0, "code": "", "local_ready": false, "remote_ready": false, "addresses": ""})
	room.get_node("Center/Panel/JoinRow/Code").text = "123456:" + "a".repeat(32)
	room.get_node("Center/Panel/JoinRow/Join").pressed.emit()
	if not _check(joins == [["123456", "a".repeat(32)]] and not room.has_node("Center/Panel/Endpoint") and not room.get_node("Center/Panel/AddressRow").visible, "Online room must parse one complete invitation with no address fields"):
		return
	room.queue_free()
	_finish(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		_finish(1)
	return condition


func _finish(code: int) -> void:
	_finished = true
	if _had_original:
		var file := FileAccess.open(PREFERENCES.FILE_PATH, FileAccess.WRITE)
		file.store_buffer(_original)
		file.close()
	else:
		DirAccess.remove_absolute(PREFERENCES.FILE_PATH)
	DirAccess.remove_absolute(TEST_PATH)
	if code == 0:
		print("Settings OK: defaults, persistence, validation, cancel/save, tabs and simplified invitation input; original preferences restored")
	quit(code)


func _process(_delta: float) -> bool:
	if not _finished and _deadline > 0 and Time.get_ticks_msec() > _deadline:
		push_error("Settings test timed out")
		_finish(1)
	return false
