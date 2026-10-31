extends SceneTree

var original := PackedByteArray()
var had_saved := false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	had_saved = FileAccess.file_exists(SquadConfig.FILE_PATH)
	if had_saved: original = FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
	var fixture := SquadConfig.new()
	fixture.operator_ids = PackedStringArray(["bagpipe", "exusiai"])
	fixture.skill_indices = PackedInt32Array([2, 1])
	if not check(fixture.write().is_empty(), "Write isolated fixture"): return
	var stored := FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
	for cycle in 3:
		if not check(change_scene_to_file("res://view/squad_menu.tscn") == OK, "Enter squad"): return
		await frames()
		var menu = current_scene
		print("SQUAD_ESCAPE_BEFORE_OVERVIEW cycle%d" % cycle)
		await escape_key()
		if not check(current_scene != null and current_scene.scene_file_path == "res://view/start_menu.tscn", "Overview Escape returns to live start menu cycle%d" % cycle): return
		current_scene.get_node("Menu/Squad").pressed.emit()
		await frames()
		menu = current_scene
		menu._open_slot(0)
		await frames()
		await escape_key()
		if not check(current_scene == menu and menu.selected_slot == -1 and not menu.picker.visible, "Normal picker Escape returns to overview"): return
		menu.quick_button.pressed.emit()
		await frames()
		menu._select_operator("myrtle")
		menu.profession_button.pressed.emit()
		menu.sort_button.pressed.emit()
		await frames()
		await escape_key()
		if not check(not menu.sort_sidebar.visible and menu.profession_sidebar.visible and menu.quick_mode, "Escape closes sort before profession"): return
		await escape_key()
		if not check(not menu.profession_sidebar.visible and menu.quick_mode, "Escape closes profession before picker"): return
		await escape_key()
		if not check(not menu.quick_mode and menu.draft == fixture.operator_ids and FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH) == stored, "Escape discards quick draft without writing"): return
		menu.clear_button.pressed.emit()
		await frames()
		await escape_key()
		if not check(not menu.clear_prompt.visible and menu.draft == fixture.operator_ids, "Escape cancels clear confirmation"): return
		menu.draft.clear(); menu.draft_skills.clear(); menu._show_overview()
		await escape_key()
		if not check(menu.exit_prompt.visible and current_scene == menu, "Empty overview Escape prompts without leaving"): return
		await escape_key()
		if not check(not menu.exit_prompt.visible and current_scene == menu, "Escape dismisses empty-team prompt"): return
		menu.draft = fixture.operator_ids.duplicate(); menu.draft_skills = fixture.skill_indices.duplicate(); menu._show_overview()
		await escape_key()
		if not check(current_scene != null and current_scene.scene_file_path == "res://view/start_menu.tscn", "Final Escape leaves live start menu"): return
	if not check(FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH) == stored, "Escape never modifies saved squad"): return
	print("SQUAD_ESCAPE_OK: real key dispatch,3 cycles,overview/start,picker,quick discard,sort/profession,clear/empty prompts and original save restored")
	GameAudio.instance(self).stop_menu()
	# Audio mixer releases playback references asynchronously.
	await create_timer(0.15).timeout
	finish(0)


func escape_key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE; event.pressed = true
	root.push_input(event, true)
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE; event.pressed = false
	root.push_input(event, true)
	await frames()


func frames() -> void:
	await process_frame
	await process_frame


func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		finish(1)
	return ok


func finish(code: int) -> void:
	if had_saved:
		var file := FileAccess.open(SquadConfig.FILE_PATH, FileAccess.WRITE)
		file.store_buffer(original); file.close()
	elif FileAccess.file_exists(SquadConfig.FILE_PATH): DirAccess.remove_absolute(SquadConfig.FILE_PATH)
	quit(code)
