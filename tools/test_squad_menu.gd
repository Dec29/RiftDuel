extends SceneTree

var _original := PackedByteArray()
var _had_saved := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_had_saved = FileAccess.file_exists(SquadConfig.FILE_PATH)
	if _had_saved:
		_original = FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
		var args := OS.get_cmdline_user_args()
		var folder := args[0] if not args.is_empty() else "res://.godot"
		var backup := FileAccess.open(folder.path_join("squad-menu-original.cfg"), FileAccess.WRITE)
		if not _check(backup != null,"Cannot preserve original squad in evidence directory"):return
		backup.store_buffer(_original)
		backup.close()
	var fixture := SquadConfig.new()
	fixture.operator_ids = PackedStringArray(["bagpipe", "nightingale"])
	fixture.skill_indices = PackedInt32Array()
	fixture.skill_indices.resize(fixture.operator_ids.size())
	if not _check(fixture.write().is_empty(), "Cannot create isolated UI squad fixture"):
		return
	change_scene_to_file("res://view/start_menu.tscn")
	await process_frame
	await process_frame
	current_scene.get_node("Menu/Squad").pressed.emit()
	await process_frame
	await process_frame
	var menu = current_scene
	if not _check(menu.scene_file_path == "res://view/squad_menu.tscn" and menu.draft == fixture.operator_ids and menu.overview.get_child_count() == 12, "Start-menu squad entry must open the saved twelve-slot overview"):
		return
	if not _check(menu.get_node("Margin/Layout/Header/Back").text.is_empty() and not menu.has_node("Margin/Layout/Actions/Cancel") and not menu.has_node("Margin/Layout/Actions/Confirm") and not menu.status.visible, "Overview must use a back icon without save/cancel buttons or persistent footer instructions"):
		return
	var body_rect: Rect2 = menu.get_node("Margin/Layout/Body").get_global_rect()
	for card in menu.overview.get_children():
		if not _check(card.size == Vector2(132, 280) and body_rect.encloses(card.get_global_rect()), "All twelve portrait slots must fit at 132 by 280 without scrolling"):
			return
	if not _check(menu.overview.size.x == 912 and is_equal_approx(menu.overview.get_global_rect().get_center().x, body_rect.get_center().x), "Six portrait columns must remain centered with 24-pixel gaps"):
		return
	await _capture("overview")
	var initial_ids: PackedStringArray = fixture.operator_ids.duplicate()
	await _click(menu.quick_button)
	var ids: PackedStringArray = menu.ROSTER_SORT.ordered_ids(root.get_node("OperatorDB").all_ids(), menu.sort_key, menu.sort_descending, root.get_node("OperatorDB").get_data)
	if not _check(menu.quick_mode and menu.roster.get_child_count() == ids.size() and menu.roster.columns == ceili(ids.size() / 2.0) and menu.roster.size.x > menu.roster_scroll.size.x and menu.roster_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER and not menu.has_node("Margin/Layout/Body/Picker/RosterPane"), "Quick picker must retain every operator in its clipped two-row continuous roster without paging controls"):
		return
	var viewport_rect: Rect2 = menu.roster_scroll.get_global_rect()
	var next_column_rect: Rect2 = menu.roster.get_child(6).get_global_rect()
	if not _check(menu.get_node("Margin/Layout/Body/Picker/Details").size.x == 316 and menu.roster.get_child(0).size == Vector2(126, 280) and next_column_rect.position.x < viewport_rect.end.x and next_column_rect.end.x > viewport_rect.end.x, "Picker must retain 316-pixel details, 126 by 280 portraits and a clipped next-column hint"):
		return
	var first_add := ids[0]
	var second_add := ids[-1]
	await _click(menu.roster.get_node(first_add))
	var check_saved := SquadConfig.new()
	if not _check(check_saved.read().is_empty() and check_saved.operator_ids == initial_ids and menu.draft.has(first_add), "Quick clicks must change only the batch before confirmation"):
		return
	var selected_before: PackedStringArray = menu.draft.duplicate()
	await _drag(menu.roster_scroll.get_global_rect().get_center(), Vector2(-160, 0), "quick-held")
	if not _check(abs(menu.roster_scroll.scroll_horizontal - 160) <= 1 and menu.draft == selected_before and check_saved.read().is_empty() and check_saved.operator_ids == initial_ids, "Dragging must move the roster continuously without selecting or saving"):
		return
	await _drag(menu.roster_scroll.get_global_rect().get_center(), Vector2(-menu.roster.size.x, 0))
	var right_edge: int = roundi(menu.roster_scroll.get_h_scroll_bar().max_value - menu.roster_scroll.get_h_scroll_bar().page)
	if not _check(menu.roster_scroll.scroll_horizontal == right_edge and menu.draft == selected_before, "Drag beyond the viewport must clamp to the right edge and release without selection"):
		return
	await _click(menu.roster.get_node(second_add))
	if not _check(menu.roster_scroll.scroll_horizontal == right_edge and menu.draft.has(first_add) and menu.draft.has(second_add), "Clicking after a drag retains scroll and choices: expected edge=%d, actual=%d, expected IDs=%s/%s, actual draft=%s" % [right_edge, menu.roster_scroll.scroll_horizontal, first_add, second_add, menu.draft]):
		return
	await _capture("quick-right")
	await _drag(menu.roster_scroll.get_global_rect().get_center(), Vector2(menu.roster.size.x, 0))
	if not _check(menu.roster_scroll.scroll_horizontal == 0, "Reverse drag must clamp to the left edge"):
		return
	# Crossing the threshold and returning to the same card is still a drag.
	var point: Vector2 = menu.roster.get_node(first_add).get_global_rect().get_center()
	await _pointer(point, true)
	await _motion(point, point + Vector2(-30, 0))
	await _motion(point + Vector2(-30, 0), point)
	await _pointer(point, false)
	if not _check(menu.draft.has(first_add) and menu.roster_scroll.scroll_horizontal == 0, "Returning a drag to its origin must not become a click"):
		return
	# Tiny mouse jitter remains a deliberate click.
	await _drag(point, Vector2(2, 0))
	if not _check(not menu.draft.has(first_add) and menu.draft.has(second_add), "Small click jitter must toggle the operator and renumber the batch"):
		return
	await _capture("quick-left")
	await _click(menu.clear_selection)
	for index in 12:
		menu._select_operator(ids[index])
	var twelve: PackedStringArray = ids.slice(0, 12)
	menu._select_operator(ids[12])
	if not _check(menu.draft == twelve and menu.status.visible, "Quick picker must cap at twelve"):
		return
	await process_frame
	await process_frame
	if not _check(menu.roster.get_child(0).size == Vector2(126, 280) and menu.roster.get_global_rect().end.y <= menu.get_node("Margin/Layout/Actions").get_global_rect().position.y, "Twelve-cap feedback must leave both portrait rows clear of the action buttons"):
		return
	await _capture("quick-twelve-cap")
	# All nineteen operators now expose their three implemented skills.
	menu._preview("swire_alter")
	if not _check(menu.draft == twelve and menu.get_node("Margin/Layout/Body/Picker/Details/Content/Skills/Skill1").button_pressed and not menu.get_node("Margin/Layout/Body/Picker/Details/Content/Skills/Skill2").disabled and not menu.get_node("Margin/Layout/Body/Picker/Details/Content/Skills/Skill3").disabled, "Swire's completed skills are selectable without changing the twelve-unit draft"):
		return
	await _click(menu.get_node("Margin/Layout/Header/Back"))
	if not _check(menu.draft == initial_ids and check_saved.read().is_empty() and check_saved.operator_ids == initial_ids and menu.overview.visible, "Back must discard the unconfirmed batch"):
		return
	await _click(menu.quick_button)
	await _click(menu.clear_selection)
	await _reveal(menu, second_add)
	await _click(menu.roster.get_node(second_add))
	await _reveal(menu, first_add)
	await _click(menu.roster.get_node(first_add))
	await _click(menu.quick_confirm)
	if not _check(check_saved.read().is_empty() and check_saved.operator_ids == PackedStringArray([second_add, first_add]) and menu.overview.visible, "Quick confirmation must save the click order once and return to overview"):
		return
	await _click(menu.clear_button)
	if not _check(menu.clear_prompt.visible and check_saved.read().is_empty() and check_saved.operator_ids == PackedStringArray([second_add, first_add]), "Opening clear confirmation must preserve the saved squad"):
		return
	await _capture("clear-confirmation")
	if DisplayServer.get_name() != "headless":
		await _click(menu.overview.get_child(0))
		if not _check(menu.clear_prompt.visible and menu.overview.visible and check_saved.read().is_empty() and check_saved.operator_ids == PackedStringArray([second_add, first_add]), "Confirmation overlay must block underlying card clicks"):
			return
	await _click(menu.get_node("ClearPrompt/Center/Panel/Content/Actions/Cancel"))
	if not _check(not menu.clear_prompt.visible and not menu.draft.is_empty(), "Cancelling clear must preserve the squad"):
		return
	await _click(menu.clear_button)
	await _click(menu.get_node("ClearPrompt/Center/Panel/Content/Actions/Confirm"))
	if not _check(check_saved.read(SquadConfig.FILE_PATH, true).is_empty() and check_saved.operator_ids.is_empty() and menu.draft.is_empty(), "Confirmed clear must persist an empty squad"):
		return
	menu._request_back()
	await _capture("empty-exit")
	if not _check(menu.exit_prompt.visible, "Cleared squad must still block exiting"):
		return
	await _click(menu.get_node("ExitPrompt/Center/Panel/Content/Actions/Keep"))
	# Restore the known two-person edit fixture through the normal picker.
	for id in initial_ids:
		menu._open_slot(menu.draft.size())
		await process_frame
		await process_frame
		if not _check_available_roster(menu, ids):return
		await _capture("normal-add-available")
		var before_drag: PackedStringArray = menu.draft.duplicate()
		await _drag(menu.roster_scroll.get_global_rect().get_center(), Vector2(-90, 0))
		if not _check(menu.picker.visible and menu.draft == before_drag and check_saved.read(SquadConfig.FILE_PATH, true).is_empty() and check_saved.operator_ids == before_drag, "Normal picker drag must not replace or save an operator"):
			return
		await _reveal(menu, id)
		await _click(menu.roster.get_node(id))
	if not _check(menu.draft == initial_ids, "Direct horizontal picker must save additions after dragging"):
		return
	menu._open_slot(0)
	if not _check_available_roster(menu, ids):return
	if not _check(menu.preview_id == "bagpipe" and not menu.roster.has_node("bagpipe") and not menu.roster.has_node("nightingale"), "Replacement keeps current operator in details while hiding every assigned operator from the roster"):return
	await _capture("normal-replace-available")
	menu._select_operator("nightingale")
	if not _check(menu.draft == fixture.operator_ids and menu.picker.visible, "Another assigned operator must not create duplicates"):
		return
	menu._select_operator("exusiai")
	var persisted := SquadConfig.new()
	if not _check(persisted.read().is_empty() and persisted.operator_ids == PackedStringArray(["exusiai", "nightingale"]) and menu.overview.visible, "Clicking a replacement must persist immediately and return to overview"):
		return
	menu._open_slot(0)
	if not _check_available_roster(menu, ids):return
	if not _check(menu.roster.has_node("bagpipe") and not menu.roster.has_node("exusiai") and not menu.roster.has_node("nightingale"), "Reopening after replacement makes the removed operator available and hides the new squad"):return
	var skill_buttons = menu.get_node("Margin/Layout/Body/Picker/Details/Content/Skills")
	if not _check(not skill_buttons.get_child(1).disabled and not skill_buttons.get_child(2).disabled, "Only implemented S2/S3 become selectable"):
		return
	await _click(skill_buttons.get_child(1))
	if not _check(persisted.read().is_empty() and persisted.skill_indices == PackedInt32Array([1, 0]) and menu.preview_skill == 1 and skill_buttons.get_child(1).button_pressed and menu.details.text.contains("扫射模式"), "Normal skill selection persists instantly and updates details"):
		return
	await _capture("exusiai-s2")
	menu._request_back()
	await _click(menu.quick_button)
	await _click(skill_buttons.get_child(2))
	if not _check(menu.draft_skills == PackedInt32Array([2, 0]) and persisted.read().is_empty() and persisted.skill_indices == PackedInt32Array([1, 0]), "Quick skill selection modifies only the batch"):
		return
	await _capture("exusiai-s3-draft")
	menu._request_back()
	if not _check(menu.draft_skills == PackedInt32Array([1, 0]), "Back discards batch skills as well as IDs"):
		return
	await _click(menu.quick_button)
	await _click(skill_buttons.get_child(2))
	await _click(menu.quick_confirm)
	if not _check(persisted.read().is_empty() and persisted.skill_indices == PackedInt32Array([2, 0]), "Quick confirm persists selected skills once"):
		return
	for index in 2:
		menu._open_slot(0)
		menu.get_node("Margin/Layout/Actions/Remove").pressed.emit()
		menu._open_slot(menu.draft.size())
		if not _check_available_roster(menu, ids):return
		menu._request_back()
	if not _check(persisted.read(SquadConfig.FILE_PATH, true).is_empty() and persisted.operator_ids.is_empty() and not SquadConfig.validate_ids(persisted.operator_ids).is_empty(), "Removing the last operator must persist an empty editable squad while battle validation still rejects it"):
		return
	menu._request_back()
	if not _check(menu.exit_prompt.visible and current_scene == menu, "Empty squad must block leaving the overview"):
		return
	menu.get_node("ExitPrompt/Center/Panel/Content/Actions/Keep").pressed.emit()
	change_scene_to_file("res://view/start_menu.tscn")
	for index in 4:
		await process_frame
	menu = current_scene
	if not _check(menu.scene_file_path == "res://view/squad_menu.tscn" and menu.draft.is_empty(), "Restarting with an empty stored squad must return to squad editing"):
		return
	menu._open_slot(0)
	menu._select_operator("exusiai")
	menu._open_slot(1)
	menu._select_operator("nightingale")
	menu._open_slot(0)
	menu._select_skill(2)
	menu._request_back()
	menu._request_back()
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://view/start_menu.tscn" and persisted.read().is_empty() and persisted.operator_ids == PackedStringArray(["exusiai", "nightingale"]), "A nonempty auto-saved squad must permit returning to the start menu"):
		return
	current_scene.get_node("Menu/SinglePlayer").pressed.emit()
	await process_frame
	await process_frame
	if not _check(current_scene.scene_file_path == "res://solo_setup.tscn", "Single-player enters preparation"): return
	current_scene.get_node("RoomView/Center/Panel/Room/ReadyRow/Start").pressed.emit()
	await process_frame
	await process_frame
	var battle = current_scene
	battle.set_physics_process(false)
	if not _check(battle.match_state.squad_ids[0] == persisted.operator_ids and battle.match_state.squad_ids[1] == persisted.operator_ids and battle.match_view._operator_ids == persisted.operator_ids and battle.ai_input._operator_ids.size() == 2 and battle.match_state.squad_skills[0] == persisted.skill_indices and battle.match_state.squad_skills[1] == persisted.skill_indices, "Single-player, tray and mirror AI must use the saved squad"):
		return
	battle.match_state.sides[1].cost = 99
	var empty_inputs: Array[InputCommand] = []
	while battle.match_state.tick < Config.AI_DECISION_INTERVAL_TICKS:
		battle.match_state.step(empty_inputs, empty_inputs)
	var before: int = battle.match_state.state_hash()
	var ai_commands: Array[InputCommand] = battle.ai_input.commands_for_tick(battle.match_state)
	if not _check(not ai_commands.is_empty() and ai_commands[0].operator_id in persisted.operator_ids and battle.match_state.state_hash() == before, "Mirror AI must deploy only selected operators and remain read-only"):
		return
	change_scene_to_file("res://view/squad_menu.tscn")
	await process_frame
	await process_frame
	menu = current_scene
	await _click(menu.quick_button)
	await _click(menu.clear_selection)
	var portrait_ids := PackedStringArray(["bagpipe", "exusiai", "swire_alter", "angelina", "blaze", "ceobe", "eyjafjalla", "horn", "hoshiguma", "nightingale", "phantom", "silverash"])
	for index in 12:
		menu._select_operator(portrait_ids[index])
		menu._select_skill(index % 3)
	await _click(menu.quick_confirm)
	if not _check(persisted.read().is_empty() and persisted.operator_ids == portrait_ids, "Twelve-operator confirmation must persist the complete portrait overview"):
		return
	await _capture("overview-twelve")
	menu._open_slot(0)
	await process_frame
	await process_frame
	if not _check_available_roster(menu, ids):return
	if not _check(menu.roster.get_child_count()==ids.size()-12 and menu.roster.columns==ceili((ids.size()-12)/2.0),"A full twelve-person squad must leave exactly the unassigned cards in two rows"):return
	await _capture("normal-twelve-available")
	menu._request_back()
	await _click(menu.quick_button)
	if not _check(menu.roster.get_child_count()==ids.size() and menu.roster.has_node("bagpipe") and menu.roster.has_node("exusiai"),"Quick picker after filtered editing must still include assigned operators for removal"):return
	menu._preview("swire_alter")
	await _capture("picker-twelve")
	print("Squad menu OK: centered twelve portrait slots, normal roster excludes assigned operators and restores replaced/removed choices, clipped two-row roster, duplicate rejection, instant persistence, continuous mouse dragging, unchanged quick batch/order/cap/cancel/confirm, clear confirmation, last removal, empty exit/restart guard and mirror-AI match integration; original squad restored")
	_finish(0)


func _finish(code: int) -> void:
	if _had_saved:
		var file := FileAccess.open(SquadConfig.FILE_PATH, FileAccess.WRITE)
		file.store_buffer(_original)
		file.close()
	elif FileAccess.file_exists(SquadConfig.FILE_PATH):
		DirAccess.remove_absolute(SquadConfig.FILE_PATH)
	quit(code)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		_finish(1)
	return condition


func _check_available_roster(menu: Control, ids: PackedStringArray) -> bool:
	if not _check(not menu.quick_mode and menu.roster.get_child_count()==ids.size()-menu.draft.size(),"Normal roster must contain exactly the operators outside the saved squad"):return false
	for id in ids:
		if not _check(menu.roster.has_node(NodePath(id)) != menu.draft.has(id),"Normal roster availability is incorrect for "+id):return false
	return true


func _click(button: Button) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		button.pressed.emit()
	else:
		var point := button.get_global_rect().get_center()
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = point
			event.global_position = point
			event.pressed = pressed
			root.push_input(event, true)
			await process_frame
	await process_frame
	await process_frame


func _pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	if DisplayServer.get_name() == "headless":
		current_scene._input(event)
	else:
		root.push_input(event, true)
	await process_frame
	await process_frame


func _motion(from: Vector2, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	if DisplayServer.get_name() == "headless":
		current_scene._input(event)
	else:
		root.push_input(event, true)
	await process_frame
	await process_frame


func _drag(point: Vector2, delta: Vector2, screenshot: String = "") -> void:
	await _pointer(point, true)
	await _motion(point, point + delta)
	if not screenshot.is_empty():
		await _capture(screenshot)
	await _pointer(point + delta, false)
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw


func _reveal(menu: Control, operator_id: String) -> void:
	await process_frame
	await process_frame
	var viewport_rect: Rect2 = menu.roster_scroll.get_global_rect()
	var card_rect: Rect2 = menu.roster.get_node(operator_id).get_global_rect()
	if card_rect.position.x < viewport_rect.position.x or card_rect.end.x > viewport_rect.end.x:
		await _drag(viewport_rect.get_center(), Vector2(viewport_rect.get_center().x - card_rect.get_center().x, 0))


func _capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var args := OS.get_cmdline_user_args()
		var directory := args[0] if not args.is_empty() else "res://.godot/"
		if not _check(root.get_texture().get_image().save_png(directory.path_join("squad-" + name + ".png")) == OK, "Cannot save squad screenshot " + name):
			return
