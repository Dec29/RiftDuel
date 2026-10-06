extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var error := change_scene_to_file("res://main.tscn")
	if not _check(error == OK, "Cannot open single-player scene"):
		return
	await process_frame
	await process_frame
	await physics_frame
	await process_frame
	var battle := current_scene
	var menu := battle.get_node("PauseLayer/PauseMenu")
	var state: MatchState = battle.match_state
	var view: MatchView = battle.match_view
	var operator: OperatorData = root.get_node("OperatorDB").get_data("bagpipe")
	state.units = [UnitState.new(0, 0, "bagpipe", Vector2i(12, 5), operator.max_health, 0, 20)]
	state.units[0].skill_ticks_left = 600
	state.next_unit_id = 1
	battle.local_input.select_unit(0)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = menu._pause_rect().get_center()
	menu._input(click)
	var frozen := state.state_hash()
	var tick := state.tick
	for frame in 5:
		await physics_frame
		await process_frame
	if not _check(paused and menu.menu_open and not battle.can_process() and not view.can_process() and menu.can_process() and state.state_hash() == frozen, "Pause must freeze ticks, cost, skills, AI and battle rendering"):
		return
	click.position = view._cancel_rect().get_center()
	Input.parse_input_event(click)
	await process_frame
	if not _check(battle.local_input.take_commands().is_empty() and state.state_hash() == frozen, "Pause overlay must block battle input"):
		return
	var capture_args := OS.get_cmdline_user_args()
	if not capture_args.is_empty():
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(capture_args[0]) == OK, "Cannot capture pause overlay"):
			return
	click.position = menu._resume_rect().get_center()
	menu._input(click)
	click.pressed = false
	menu._input(click)
	await physics_frame
	await process_frame
	if not _check(not paused and not menu.menu_open and state.tick > tick and state.units[0].skill_ticks_left < 600, "Continue must resume the same battle and skill countdown"):
		return
	click.pressed = true
	click.position = menu._pause_rect().get_center()
	menu._input(click)
	click.position = menu._home_rect().get_center()
	menu._input(click)
	await process_frame
	await process_frame
	if not _check(not paused and current_scene.scene_file_path == "res://view/start_menu.tscn", "Home must restore the start menu and clear pause"):
		return
	current_scene.get_node("Menu/SinglePlayer").pressed.emit()
	await process_frame
	await process_frame
	await physics_frame
	await process_frame
	if not _check(not paused and current_scene.match_state.tick > 0 and current_scene.get_node("PauseLayer/PauseMenu").menu_open == false, "A new single-player battle must start unpaused"):
		return
	print("Pause menu OK: frozen state and inputs, continue same battle, home transition, new battle unpaused")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
