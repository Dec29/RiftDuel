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
	if not _check(preferences.window_mode=="windowed" and preferences.window_resolution==Vector2i(1600,900),"Default window must be1600x900"):return
	if not _check(preferences.music_volume==10 and preferences.sfx_volume==10 and preferences.voice_volume==10 and preferences.voice_sides=="both","Quiet default audio with both teams' voices"):return
	var legacy := ConfigFile.new()
	legacy.set_value("display","goal_position","right")
	legacy.save(TEST_PATH)
	if not _check(preferences.read(TEST_PATH).is_empty() and preferences.window_resolution==Vector2i(1600,900),"Legacy preferences must acquire display defaults"):return
	preferences=PREFERENCES.new()
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
	preferences.window_mode="fullscreen"
	preferences.window_resolution=Vector2i(1280,720)
	preferences.music_volume=0
	preferences.sfx_volume=55
	preferences.voice_volume=70
	preferences.voice_sides="local"
	if not _check(preferences.write(TEST_PATH).is_empty(), "Cannot persist test settings"):
		return
	var loaded := PREFERENCES.new()
	if not _check(loaded.read(TEST_PATH).is_empty() and loaded.endpoint() == preferences.custom_endpoint and loaded.goal_position == "right" and loaded.window_mode=="fullscreen" and loaded.window_resolution==Vector2i(1280,720), "Persisted settings lost connection/goal/display preferences"):
		return
	preferences.custom_endpoint = "ws://example.com/ws"
	if not _check(loaded.music_volume==0 and loaded.sfx_volume==55 and loaded.voice_volume==70 and loaded.voice_sides=="local","Audio group levels and side selection persist independently"):return
	if not _check(not preferences.write(TEST_PATH).is_empty() and loaded.read(TEST_PATH).is_empty() and loaded.endpoint() == "wss://example.com:443/ws", "Invalid custom server must be rejected without overwriting saved preferences"):
		return
	var invalid := ConfigFile.new()
	invalid.set_value("display", "goal_position", "center")
	invalid.save(TEST_PATH)
	if not _check(not loaded.read(TEST_PATH).is_empty(), "Invalid disk preferences must report error"):
		return
	invalid=ConfigFile.new()
	invalid.set_value("display","window_mode","unknown")
	invalid.save(TEST_PATH)
	if not _check(not loaded.read(TEST_PATH).is_empty(),"Invalid display mode must fail at storage boundary"):return
	invalid=ConfigFile.new()
	invalid.set_value("audio","music_volume",101)
	invalid.save(TEST_PATH)
	if not _check(not loaded.read(TEST_PATH).is_empty(),"Invalid volume must fail at storage boundary"):return
	invalid=ConfigFile.new()
	invalid.set_value("audio","voice_sides","enemy")
	invalid.save(TEST_PATH)
	if not _check(not loaded.read(TEST_PATH).is_empty(),"Unknown voice side selection fails at storage boundary"):return
	preferences = PREFERENCES.new()
	if not _check(preferences.write().is_empty(), "Cannot establish isolated default UI settings"):
		return
	change_scene_to_file("res://view/start_menu.tscn")
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless" and not _check(root.size==DisplaySettings.fitting_resolution(Vector2i(1600,900)),"First startup applies enlarged default window"):return
	current_scene.get_node("Menu/Settings").pressed.emit()
	await process_frame
	await process_frame
	var settings := current_scene
	if not _check(settings.scene_file_path == "res://view/settings_menu.tscn", "Settings button did not open settings"):
		return
	var panel := settings.get_node("Center/Panel")
	var display=panel.get_node("Tabs/Display")
	if not _check(display.get_node("WindowMode").get_index()<display.get_node("Goal").get_index() and display.get_node("Resolution").get_index()<display.get_node("Goal").get_index(),"Display controls must precede goal position"):return
	display.get_node("WindowMode").select(1)
	display.get_node("WindowMode").item_selected.emit(1)
	panel.get_node("Tabs/Audio/Music").value=0
	if not _check(panel.get_node("Tabs/Audio/MusicLabel").text=="音乐 · 0%","Audio slider labels must preserve their category"):return
	if not _check(preferences.read().is_empty() and preferences.music_volume==0 and GameAudio.instance(self)._intro.volume_linear==0.0 and preferences.window_mode=="windowed","Audio applies/saves immediately without saving display drafts"):return
	panel.get_node("Tabs").current_tab=2
	if not _check(not panel.get_node("Actions/Save").visible and panel.get_node("Actions/Cancel").text=="返回","Audio tab needs only a back action"):return
	panel.get_node("Tabs").current_tab=0
	if not _check(display.get_node("Resolution").disabled,"Borderless fullscreen resolution must use desktop"):return
	if not _check(panel.get_node("Tabs").get_tab_title(0) == "连接" and panel.get_node("Tabs").get_tab_title(1) == "显示" and not panel.get_node("Tabs/Connection/Endpoint").visible, "Settings must have connection/display tabs and hidden custom endpoint by default"):
		return
	panel.get_node("Tabs/Connection/Custom").button_pressed = true
	panel.get_node("Tabs/Connection/Endpoint").text = "http://unsafe/ws"
	panel.get_node("Tabs/Audio/Voice").value=9
	panel.get_node("Tabs/Audio/VoiceSides").select(1)
	panel.get_node("Tabs/Audio/VoiceSides").item_selected.emit(1)
	if not _check(preferences.read().is_empty() and preferences.voice_volume==9 and preferences.voice_sides=="local" and not preferences.use_custom_server,"Audio remains usable beside invalid connection drafts"):return
	panel.get_node("Actions/Save").pressed.emit()
	if not _check(current_scene == settings and not panel.get_node("Status").text.is_empty(), "Invalid endpoint must keep settings open with error"):
		return
	panel.get_node("Actions/Cancel").pressed.emit()
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://view/start_menu.tscn" and preferences.read().is_empty() and not preferences.use_custom_server and preferences.window_mode=="windowed", "Cancel must return without saving drafts"):
		return
	if not _check(preferences.music_volume==0 and preferences.voice_volume==9 and preferences.voice_sides=="local","Returning keeps immediately saved audio"):return
	current_scene.get_node("Menu/Settings").pressed.emit()
	await process_frame
	await process_frame
	panel = current_scene.get_node("Center/Panel")
	panel.get_node("Tabs/Connection/Custom").button_pressed = true
	panel.get_node("Tabs/Connection/Endpoint").text = "wss://example.com/ws"
	panel.get_node("Tabs/Display/Goal").select(1)
	panel.get_node("Tabs/Audio/Music").value=0
	panel.get_node("Tabs/Audio/SFX").value=55
	panel.get_node("Tabs/Audio/Voice").value=70
	panel.get_node("Actions/Save").pressed.emit()
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://view/start_menu.tscn" and preferences.read().is_empty() and preferences.endpoint() == "wss://example.com/ws" and preferences.goal_position == "right", "Save must persist both tabs and return"):
		return
	if not _check(preferences.music_volume==0 and preferences.sfx_volume==55 and preferences.voice_volume==70 and GameAudio.instance(self)._intro.volume_linear==0.0,"Audio sliders save and apply, zero music is mute"):return
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
	room.online_join_requested.connect(func(code: String) -> void: joins.append(code))
	room.get_node("Center/Panel/Mode").select(0)
	room.update_room({"phase": "idle", "online": true, "status": "", "side": 0, "code": "", "local_ready": false, "remote_ready": false, "addresses": ""})
	room.get_node("Center/Panel/JoinRow/Code").text = "123456"
	room.get_node("Center/Panel/JoinRow/Join").pressed.emit()
	if not _check(joins == ["123456"] and not room.has_node("Center/Panel/Endpoint") and not room.get_node("Center/Panel/AddressRow").visible, "Online room must parse one six-digit room code with no address fields"):
		return
	room.queue_free()
	if DisplayServer.get_name()!="headless":
		for mode in PREFERENCES.WINDOW_MODES:
			current_scene.get_node("Menu/Settings").pressed.emit()
			await process_frame
			await process_frame
			panel=current_scene.get_node("Center/Panel")
			var mode_index := PREFERENCES.WINDOW_MODES.find(mode)
			panel.get_node("Tabs/Display/WindowMode").select(mode_index)
			panel.get_node("Tabs/Display/WindowMode").item_selected.emit(mode_index)
			if mode=="windowed":
				var options: OptionButton=panel.get_node("Tabs/Display/Resolution")
				for index in options.item_count:
					if options.get_item_text(index)=="1280 × 720":options.select(index)
			panel.get_node("Actions/Save").pressed.emit()
			await process_frame
			await process_frame
			var expected := Window.MODE_WINDOWED if mode=="windowed" else (Window.MODE_FULLSCREEN if mode=="borderless" else Window.MODE_EXCLUSIVE_FULLSCREEN)
			if not _check(preferences.read().is_empty() and preferences.window_mode==mode and root.mode==expected and (root.size==Vector2i(1280,720) if mode=="windowed" else root.size==DisplayServer.screen_get_size(root.current_screen)),"Actual saved window mode/size: "+mode):return
		preferences.window_mode="windowed"
		DisplaySettings.apply(preferences,root)
		change_scene_to_file("res://view/settings_menu.tscn")
		await process_frame
		await process_frame
		current_scene.get_node("Center/Panel/Tabs").current_tab=1
		await process_frame
		await RenderingServer.frame_post_draw
		var rect: Rect2=current_scene.get_node("Center/Panel").get_global_rect().grow(20)
		if not _check(Rect2(Vector2.ZERO,current_scene.size).encloses(rect),"Display settings panel fits logical canvas"):return
		var args := OS.get_cmdline_user_args()
		var folder := args[0] if not args.is_empty() else "res://.godot"
		if not _check(root.get_texture().get_image().save_png(folder.path_join("settings-display.png"))==OK,"Settings graphics capture"):return
		current_scene.get_node("Center/Panel/Tabs").current_tab=2
		await process_frame
		await RenderingServer.frame_post_draw
		rect=current_scene.get_node("Center/Panel").get_global_rect().grow(20)
		if not _check(Rect2(Vector2.ZERO,current_scene.size).encloses(rect),"Audio settings panel fits logical canvas"):return
		if not _check(root.get_texture().get_image().save_png(folder.path_join("settings-audio.png"))==OK,"Audio settings graphics capture"):return
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
		print("Settings OK:1600x900 defaults, legacy persistence, cancel/save, window resolution, desktop borderless/fullscreen, display controls above goal and invitation input; original preferences restored")
	quit(code)


func _process(_delta: float) -> bool:
	if not _finished and _deadline > 0 and Time.get_ticks_msec() > _deadline:
		push_error("Settings test timed out")
		_finish(1)
	return false
