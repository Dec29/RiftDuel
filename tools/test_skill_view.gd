extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := load("res://main.tscn").instantiate() as Node2D
	root.add_child(main)
	main.set_physics_process(false)
	var state: MatchState = main.match_state
	var input: LocalInput = main.local_input
	var view: MatchView = main.match_view
	state.sides[0].cost = 99
	for side in 2:
		state.squad_ids[side] = PackedStringArray(Config.DEFAULT_SQUAD_IDS)
		state.squad_skills[side].resize(Config.DEFAULT_SQUAD_IDS.size())
		state.squad_skills[side].fill(0)
	var deploy: Array[InputCommand] = [InputCommand.new(0, InputCommand.Kind.DEPLOY, "bagpipe", -1, Vector2i(19, 5))]
	state.step(deploy, [])
	for _tick in 600:
		state.step([], [])
	input.select_unit(0)
	view.queue_redraw()
	var before := state.state_hash()
	await process_frame
	await process_frame
	if state.state_hash() != before:
		push_error("Rendering changed simulation state")
		quit(1)
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = view._skill_rect().get_center()
	view._unhandled_input(click)
	var commands := input.take_commands()
	if state.state_hash() != before or commands.size() != 1 or commands[0].kind != InputCommand.Kind.SKILL:
		push_error("Skill button did not queue a command without mutating simulation")
		quit(1)
		return
	state.step(commands, [])
	if state.units[0].skill_ticks_left != 1049 or state.units[0].sp != 0:
		push_error("Skill button command did not activate Bagpipe")
		quit(1)
		return
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	view._unhandled_input(key)
	if not input.take_commands().is_empty():
		push_error("Active skill accepted a second activation")
		quit(1)
		return
	view.queue_redraw()
	await process_frame
	await process_frame
	var capture_args := OS.get_cmdline_user_args()
	if not capture_args.is_empty():
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(capture_args[0])
		if error != OK:
			push_error("Cannot save skill UI capture: %s" % error_string(error))
			quit(1)
			return
	print("Skill view OK: read-only render, button command, activation")
	quit(0)
