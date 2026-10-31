extends SceneTree

const OUTPUT := "res://.godot/profession-filter-evidence"
var original := PackedByteArray()
var had_saved := false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	had_saved = FileAccess.file_exists(SquadConfig.FILE_PATH)
	if had_saved:
		original = FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
	var backup := FileAccess.open(OUTPUT + "/squad-restore.json", FileAccess.WRITE)
	backup.store_string(JSON.stringify({"path": ProjectSettings.globalize_path(SquadConfig.FILE_PATH), "existed": had_saved, "bytes": Marshalls.raw_to_base64(original)}))
	backup.close()
	var db = root.get_node("OperatorDB")
	var fixture := SquadConfig.new()
	fixture.operator_ids = PackedStringArray(["chen"])
	for id in db.all_ids():
		if db.get_data(id).profession_id == "medic" and not fixture.operator_ids.has(id):
			fixture.operator_ids.append(id)
	fixture.skill_indices.resize(fixture.operator_ids.size())
	fixture.skill_indices[0] = 2
	if not check(fixture.write().is_empty(), "Write isolated squad fixture"):
		return
	var stored := FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
	change_scene_to_file("res://view/squad_menu.tscn")
	await process_frame
	await process_frame
	var menu = current_scene
	if not check(not menu.profession_button.visible and not menu.profession_sidebar.visible, "Overview has no profession selector"):
		return
	await click(menu.overview.get_child(0))
	await capture("button")
	await click(menu.profession_button)
	if not check(menu.profession_sidebar.visible and menu.profession_button.text == "收起 ›", "Actual header click opens profession sidebar"):
		return
	if not check(PackedStringArray(menu.PROFESSIONS.keys()) == PackedStringArray(["vanguard", "sniper", "defender", "guard", "caster", "medic", "supporter", "specialist"]), "Profession icon order follows reference sidebar"):
		return
	var body: Rect2 = menu.get_node("Margin/Layout/Body").get_global_rect()
	for option in menu.profession_options.get_children():
		if not check(body.encloses(option.get_global_rect()) and option.size.y > 40 and not option.get_global_rect().intersects(menu.roster_scroll.get_global_rect()), "All nine sidebar options fit without covering roster or actions"):
			return
	for profession in menu.PROFESSIONS:
		await click(menu.profession_options.get_node(profession))
		if not check_roster(menu, profession, false):
			return
		if not check(menu.draft == fixture.operator_ids and menu.draft_skills == fixture.skill_indices and FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH) == stored and menu.preview_id == "chen", "Filtering leaves squad, carried skills, saved bytes and current-slot details unchanged"):
			return
	await click(menu.profession_options.get_node("guard"))
	await capture("single-guard")
	await click(menu.profession_options.get_node("medic"))
	if not check(menu.empty_roster.visible and menu.roster.get_child_count() == 0, "No unassigned medics gives explicit empty state, no fallback cards"):
		return
	await capture("single-empty-medic")
	await click(menu.profession_button)
	if not check(not menu.profession_sidebar.visible and menu.profession_filter == "medic", "Collapsing preserves active filter"):
		return
	await click(menu.get_node("Margin/Layout/Header/Back"))
	await click(menu.quick_button)
	if not check_roster(menu, "medic", true):
		return
	await click(menu.profession_button)
	await capture("quick-medic")
	for profession in menu.PROFESSIONS:
		await click(menu.profession_options.get_node(profession))
		if not check_roster(menu, profession, true):
			return
	await click(menu.profession_options.get_node("guard"))
	await click(menu.roster.get_node("chen"))
	if not check(not menu.draft.has("chen") and menu.roster.has_node("chen") and FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH) == stored, "Quick filtered click removes selected guard only in draft and keeps card available"):
		return
	await click(menu.roster.get_node("chen"))
	menu._select_skill(1)
	await click(menu.profession_options.get_node("All"))
	if not check_roster(menu, "", true):
		return
	var before_drag: PackedStringArray = menu.draft.duplicate()
	var origin: Vector2 = menu.roster_scroll.get_global_rect().get_center()
	for pressed in [true, false]:
		var pointer := InputEventMouseButton.new()
		pointer.button_index = MOUSE_BUTTON_LEFT
		pointer.position = origin if pressed else origin - Vector2(90, 0)
		pointer.pressed = pressed
		root.push_input(pointer, true)
		await process_frame
		if pressed:
			var motion := InputEventMouseMotion.new()
			motion.position = origin - Vector2(90, 0)
			motion.relative = Vector2(-90, 0)
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			root.push_input(motion, true)
			await process_frame
	if not check(menu.roster_scroll.scroll_horizontal == 90 and menu.draft == before_drag, "Roster dragging with sidebar open preserves filtered selection and scrolls normally"):
		return
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await process_frame
	if not check(not menu.profession_sidebar.visible and menu.quick_mode, "Escape closes sidebar before discarding batch"):
		return
	await click(menu.quick_confirm)
	var saved := SquadConfig.new()
	if not check(saved.read().is_empty() and saved.operator_ids[-1] == "chen" and saved.skill_indices[-1] == 1, "Quick confirmation saves selected order and skill after filtering"):
		return
	await click(menu.overview.get_child(0))
	await click(menu.profession_button)
	await click(menu.profession_options.get_node("guard"))
	if not check_roster(menu, "guard", false):
		return
	await click(menu.roster.get_node("skadi"))
	if not check(saved.read().is_empty() and saved.operator_ids[0] == "skadi" and menu.overview.visible, "Filtered ordinary replacement still saves immediately"):
		return
	await click(menu.quick_button)
	await click(menu.profession_button)
	await click(menu.profession_options.get_node("sniper"))
	await click(menu.roster.get_node("exusiai"))
	await click(menu.get_node("Margin/Layout/Header/Back"))
	if not check(menu.draft == saved.operator_ids and menu.draft_skills == saved.skill_indices and not menu.profession_button.visible and not menu.profession_sidebar.visible, "Returning from filtered quick batch discards changes and hides filter controls"):
		return
	change_scene_to_file("res://view/squad_menu.tscn")
	await process_frame
	await process_frame
	if not check(current_scene.profession_filter.is_empty(), "Fresh squad scene starts with ALL, no filter persistence in saved squad"):
		return
	restore_saved()
	print("PROFESSION_FILTER_OK: actual clicks; eight professions+ALL; normal excludes assigned; quick includes assigned; empty/collapse/Escape; save/confirm/discard; original squad restored")
	quit(0)


func check_roster(menu: Control, profession: String, quick: bool) -> bool:
	var expected := PackedStringArray()
	var db = root.get_node("OperatorDB")
	for id in db.all_ids():
		if (quick or not menu.draft.has(id)) and (profession.is_empty() or db.get_data(id).profession_id == profession):
			expected.append(id)
	expected = menu.ROSTER_SORT.ordered_ids(expected, menu.sort_key, menu.sort_descending, db.get_data)
	var actual := PackedStringArray()
	for index: int in menu.roster.get_child_count():
		var column := floori(index / 2.0)
		var row := index % 2
		var button: Button = menu.roster.get_child(row * menu.roster.columns + column)
		actual.append(str(button.name))
	return check(actual == expected and menu.empty_roster.visible == expected.is_empty() and menu.roster.columns == maxi(1, ceili(expected.size() / 2.0)), "Exact %s roster for %s: expected %s, actual %s" % ["quick" if quick else "single", profession, expected, actual])


func click(button: Button) -> void:
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await process_frame
	await process_frame


func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png") == OK, "Screenshot " + label)


func restore_saved() -> void:
	if had_saved:
		var file := FileAccess.open(SquadConfig.FILE_PATH, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	elif FileAccess.file_exists(SquadConfig.FILE_PATH):
		DirAccess.remove_absolute(SquadConfig.FILE_PATH)


func check(value: bool, label: String) -> bool:
	if not value:
		restore_saved()
		push_error(label)
		quit(1)
	return value
