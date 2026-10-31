extends SceneTree

const ORDER := preload("res://view/squad_roster_sort.gd")
const OUTPUT := "res://.godot/squad-sort-20261019"
var original := PackedByteArray()
var had_saved := false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	had_saved = FileAccess.file_exists(SquadConfig.FILE_PATH)
	if had_saved: original = FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
	var backup := FileAccess.open(OUTPUT + "/squad-restore.json", FileAccess.WRITE)
	backup.store_string(JSON.stringify({"path":ProjectSettings.globalize_path(SquadConfig.FILE_PATH), "existed":had_saved, "bytes":Marshalls.raw_to_base64(original)}))
	backup.close()
	var fixture := SquadConfig.new()
	fixture.operator_ids = PackedStringArray(["bagpipe", "exusiai", "myrtle", "ines"])
	fixture.skill_indices = PackedInt32Array([2, 1, 0, 1])
	if not check(fixture.write().is_empty(), "Write isolated squad fixture"): return
	var stored := FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
	change_scene_to_file("res://view/squad_menu.tscn")
	await process_frame
	await process_frame
	var menu = current_scene
	if not check(not menu.sort_button.visible and not menu.sort_sidebar.visible, "Overview hides sorting controls"): return
	await click(menu.quick_button)
	if not check(menu.sort_key == "rarity" and menu.sort_descending and check_order(menu), "Fresh picker is rarity-descending down each column (1/2, then 3/4)"): return
	var ids: PackedStringArray = root.get_node("OperatorDB").all_ids()
	if not check(ids.size() == ORDER.RARITY_BY_ID.size() and ORDER.RARITY_BY_ID.myrtle == 4 and ORDER.RARITY_BY_ID.amiya == 5 and ORDER.RARITY_BY_ID.ines == 6, "Explicit complete source rarity coverage and 4/5/6 star anchors"): return
	await click(menu.sort_button)
	if not check(menu.sort_sidebar.visible and menu.sort_options.get_child_count() == 9 and menu.sort_sidebar.get_global_rect().end.x <= root.get_visible_rect().end.x, "Right sidebar contains all nine criteria inside canvas"): return
	for row in menu.sort_options.get_children():
		if not check(menu.sort_sidebar.get_global_rect().encloses(row.get_global_rect()) and row.size.y >= 40, "Every sorting row has a visible usable target"): return
	await capture("rarity-descending")
	var snapshot: PackedStringArray = menu.draft.duplicate()
	var skills: PackedInt32Array = menu.draft_skills.duplicate()
	for key in ORDER.LABELS:
		for descending: bool in [false, true]:
			await click(arrow(menu, key, descending))
			if not check(menu.sort_key == key and menu.sort_descending == descending and check_order(menu), "Actual arrow reorders full roster: " + key + str(descending)): return
			if not check(menu.draft == snapshot and menu.draft_skills == skills and FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH) == stored, "Sorting preserves draft order, skill choices and exact saved bytes"): return
			var selected := 0
			for row in menu.sort_options.get_children():
				for control in row.get_child(0).get_children():
					if control is Button and control.toggle_mode and control.button_pressed: selected += 1
			if not check(selected == 1 and arrow(menu,key,descending).button_pressed, "Exactly one of eighteen direction indicators active"): return
	await click(menu.profession_button)
	await click(menu.profession_options.get_node("vanguard"))
	await click(arrow(menu,"attack",true))
	if not check(check_order(menu) and menu.roster.has_node("bagpipe") and menu.roster_scroll.size.x >= 126, "Profession+sorting combine while quick mode retains assigned cards"): return
	await capture("attack-filter-and-sort")
	await escape_key()
	if not check(not menu.sort_sidebar.visible and menu.profession_sidebar.visible and menu.quick_mode and menu.draft == snapshot, "First Escape closes sort sidebar without discarding draft"): return
	await escape_key()
	if not check(not menu.profession_sidebar.visible and menu.quick_mode, "Second Escape closes profession sidebar"): return
	await click(menu.profession_button)
	await click(menu.profession_options.get_node("All"))
	await click(menu.profession_button)
	await click(menu.sort_button)
	await click(arrow(menu,"max_health",false))
	await click(menu.sort_button)
	var chosen := ""
	for button in menu.roster.get_children():
		if not menu.draft.has(str(button.name)):
			chosen = str(button.name)
			break
	await click(menu.roster.get_node(chosen))
	if not check(menu.draft[-1] == chosen and FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH) == stored, "Selecting from sorted quick roster appends by click order without early save"): return
	await click(menu.quick_confirm)
	var saved := SquadConfig.new()
	if not check(saved.read().is_empty() and saved.operator_ids == menu.draft and saved.skill_indices.slice(0,4) == skills and not menu.sort_button.visible, "Quick confirm: saved=%s, draft=%s, saved skills=%s, original skills=%s, sorting visible=%s, quick=%s" % [saved.operator_ids, menu.draft, saved.skill_indices, skills, menu.sort_button.visible, menu.quick_mode]): return
	await click(menu.overview.get_child(0))
	if not check(menu.sort_key == "max_health" and not menu.sort_descending and not menu.sort_sidebar.visible and check_order(menu), "Sort preference retained across modes; normal mode excludes assigned"): return
	await click(menu.sort_button)
	await click(arrow(menu,"deploy_cost",false))
	await capture("normal-cost-ascending")
	await click(menu.sort_button)
	var replacement: String = menu.roster.get_child(0).name
	await click(menu.roster.get_child(0))
	if not check(saved.read().is_empty() and saved.operator_ids[0] == replacement and menu.overview.visible, "Sorted normal selection still replaces and saves immediately"): return
	var saved_before := FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
	await click(menu.quick_button)
	await click(menu.sort_button)
	await click(arrow(menu,"defense",true))
	await click(menu.sort_button)
	await click(menu.roster.get_child(0))
	await click(menu.get_node("Margin/Layout/Header/Back"))
	if not check(menu.draft == saved.operator_ids and FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH) == saved_before, "Back discards sorted quick draft without changing saved squad"): return
	change_scene_to_file("res://view/squad_menu.tscn")
	await process_frame
	await process_frame
	menu = current_scene
	if not check(menu.sort_key == "rarity" and menu.sort_descending, "New menu defaults again; no sorting state written to squad"): return
	# Empty normal roster remains empty when changing criteria/direction.
	fixture.operator_ids.clear()
	for id in ids:
		if root.get_node("OperatorDB").get_data(id).profession_id == "medic": fixture.operator_ids.append(id)
	fixture.skill_indices.resize(fixture.operator_ids.size())
	fixture.skill_indices.fill(0)
	if not check(fixture.write().is_empty(), "Write all-medic empty-filter fixture"): return
	change_scene_to_file("res://view/squad_menu.tscn")
	await process_frame
	await process_frame
	menu = current_scene
	await click(menu.overview.get_child(0))
	await click(menu.profession_button)
	await click(menu.profession_options.get_node("medic"))
	await click(menu.sort_button)
	await click(arrow(menu,"attack",false))
	if not check(menu.empty_roster.visible and menu.roster.get_child_count() == 0 and menu.sort_sidebar.visible, "Empty filtered roster stays empty under sorting"): return
	await capture("empty-filtered-roster")
	restore_saved()
	if not check(FileAccess.file_exists(SquadConfig.FILE_PATH) == had_saved and (not had_saved or FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH) == original), "Original user squad restored byte for byte"): return
	print("SQUAD_SORT_OK:9 criteria x2 directions,88 source rarities,ties,actual clicks,filter+normal+quick+empty,save/confirm/discard,sidebar/Escape,original squad restored")
	quit(0)


func arrow(menu: Control, key: String, descending: bool) -> Button:
	return menu.sort_options.get_node(key).get_child(0).get_node("Descending" if descending else "Ascending")


func check_order(menu: Control) -> bool:
	var count := 0
	var previous_id := ""
	var previous := 0.0
	for index: int in menu.roster.get_child_count():
		# Inspect visible positions down each column, rather than scene child order.
		var column := floori(index / 2.0)
		var row := index % 2
		var button: Button = menu.roster.get_child(row * menu.roster.columns + column)
		var origin: Vector2 = menu.roster.get_child(0).position
		var expected_position := origin + Vector2(column * (button.size.x + menu.roster.get_theme_constant("h_separation")), row * (button.size.y + menu.roster.get_theme_constant("v_separation")))
		if not button.position.is_equal_approx(expected_position): return false
		var id := str(button.name)
		var operator: OperatorData = root.get_node("OperatorDB").get_data(id)
		if not menu.profession_filter.is_empty() and operator.profession_id != menu.profession_filter: return false
		if not menu.quick_mode and menu.draft.has(id): return false
		var number: float
		if menu.sort_key == "rarity": number = ORDER.RARITY_BY_ID[id]
		elif menu.sort_key == "attack_frequency": number = 1.0 / operator.attack_interval
		elif menu.sort_key == "deploy_cost": number = operator.deploy_cost - (int(operator.talent_1.effect_params.cost_reduction) if operator.talent_1.effect_type == "low_cost_support" else 0)
		else: number = operator.get(menu.sort_key)
		if count > 0:
			if previous < number if menu.sort_descending else previous > number: return false
			if previous == number and previous_id >= id: return false
		previous = number
		previous_id = id
		count += 1
	var expected := 0
	for id in root.get_node("OperatorDB").all_ids():
		if (menu.quick_mode or not menu.draft.has(id)) and (menu.profession_filter.is_empty() or root.get_node("OperatorDB").get_data(id).profession_id == menu.profession_filter): expected += 1
	return count == expected


func click(button: Button) -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw


func escape_key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event,true)
	await process_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png") == OK, "Screenshot " + label)


func restore_saved() -> void:
	if had_saved:
		var file := FileAccess.open(SquadConfig.FILE_PATH,FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	elif FileAccess.file_exists(SquadConfig.FILE_PATH): DirAccess.remove_absolute(SquadConfig.FILE_PATH)


func check(ok: bool, label: String) -> bool:
	if not ok:
		restore_saved()
		push_error(label)
		quit(1)
	return ok
