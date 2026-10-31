extends SceneTree

const CONFIG := preload("res://data/config.gd")
const DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const DEPLOY_CELL := Vector2i(11, 5)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := load("res://main.tscn").instantiate() as Node2D
	root.add_child(main)
	main.set_physics_process(false)
	var state: MatchState = main.match_state
	var input: LocalInput = main.local_input
	var view: MatchView = main.match_view
	var fixture_data := {}
	for id in CONFIG.DEFAULT_SQUAD_IDS:
		fixture_data[id] = root.get_node("OperatorDB").get_data(id)
	for side in 2:
		state.squad_ids[side] = PackedStringArray(CONFIG.DEFAULT_SQUAD_IDS)
	main.ai_input = AIInput.new(1, fixture_data)
	view.bind(state, input, fixture_data)
	view.mirror_board = false
	state.sides[0].cost = 99
	var center := view.projection.cell_rect(DEPLOY_CELL).get_center()
	for facing in DIRECTIONS.size():
		var before := state.state_hash()
		_begin_deploy(view, DEPLOY_CELL)
		if not _check(view._deploy_phase == MatchView.DeployPhase.FACING and input.take_commands().is_empty() and state.state_hash() == before, "Dropping a card must enter facing preview without deploying"):
			return
		_mouse(view, center, true)
		_motion(view, center + DIRECTIONS[facing] * view.projection.cell_rect(DEPLOY_CELL).size.x * 2)
		_mouse(view, center + DIRECTIONS[facing] * view.projection.cell_rect(DEPLOY_CELL).size.x * 2, false)
		var commands := input.take_commands()
		if not _check(commands.size() == 1 and commands[0].kind == InputCommand.Kind.DEPLOY and commands[0].facing == facing and commands[0].cell == DEPLOY_CELL and state.state_hash() == before, "Direction %d must queue exactly one deploy command and preserve state" % facing):
			return
		state.step(commands, [])
		if not _check(state.units.size() == 1 and state.units[0].facing == facing and state.sides[0].cost == 86, "Direction %d must deploy and spend 13 cost only on simulation step" % facing):
			return
		input.select_unit(state.units[0].unit_id)
		before = state.state_hash()
		_mouse(view, view._cancel_rect().get_center(), true)
		commands = input.take_commands()
		if not _check(commands.size() == 1 and commands[0].kind == InputCommand.Kind.RETREAT and state.state_hash() == before, "Deployed-unit retreat button must queue RETREAT without writing state"):
			return
		state.step(commands, [])
		state.sides[0].cooldowns.clear()
		state.sides[0].cost = 99

	state.sides[0].cost = 0
	var before := state.state_hash()
	_mouse(view, view._card_rect(view._operator_ids.find("bagpipe")).get_center(), true)
	if not _check(view._deploy_phase == MatchView.DeployPhase.IDLE and input.selected_operator_id == "bagpipe" and input.take_commands().is_empty() and state.state_hash() == before, "Insufficient-cost card must show information without beginning deployment"):
		return
	state.sides[0].cost = 99
	before = state.state_hash()
	_begin_deploy(view, DEPLOY_CELL)
	_mouse(view, view._skill_rect().get_center(), true)
	var confirmed := input.take_commands()
	if not _check(confirmed.size() == 1 and confirmed[0].kind == InputCommand.Kind.DEPLOY and confirmed[0].facing == 2 and state.state_hash() == before, "Confirm button must queue the default west-facing deployment without writing state"):
		return

	_begin_deploy(view, Vector2i(9, 5))
	if not _check(view._deploy_phase == MatchView.DeployPhase.IDLE and input.take_commands().is_empty() and state.state_hash() == before, "Illegal first drop must cancel without a deploy command"):
		return
	_begin_deploy(view, DEPLOY_CELL)
	_mouse(view, center, true)
	_motion(view, center + Vector2(1, 1))
	_mouse(view, center + Vector2(1, 1), false)
	if not _check(view._deploy_phase == MatchView.DeployPhase.FACING and input.take_commands().is_empty() and state.state_hash() == before, "A direction drag below the threshold must keep preview pending"):
		return
	_mouse(view, view._cancel_rect().get_center(), true)
	if not _check(view._deploy_phase == MatchView.DeployPhase.IDLE and input.take_commands().is_empty() and state.state_hash() == before, "Preview cancel button must discard deployment without cost"):
		return
	_begin_deploy(view, DEPLOY_CELL)
	_mouse(view, center, true, MOUSE_BUTTON_RIGHT)
	if not _check(view._deploy_phase == MatchView.DeployPhase.IDLE and input.take_commands().is_empty(), "Right-click must cancel pending deployment"):
		return
	_begin_deploy(view, DEPLOY_CELL)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	view._unhandled_input(escape)
	if not _check(view._deploy_phase == MatchView.DeployPhase.IDLE and input.take_commands().is_empty() and state.state_hash() == before, "Escape must cancel pending deployment without writing state"):
		return
	_begin_deploy(view, DEPLOY_CELL)
	state.ball.cell = Vector2i(12, 5)
	before = state.state_hash()
	_mouse(view, center, true)
	_motion(view, center + Vector2.LEFT * view.projection.cell_rect(DEPLOY_CELL).size.x * 2)
	_mouse(view, center + Vector2.LEFT * view.projection.cell_rect(DEPLOY_CELL).size.x * 2, false)
	if not _check(input.take_commands().is_empty() and state.state_hash() == before, "Moving deployment line must revalidate a pending cell before direction commit"):
		return
	view._unhandled_input(escape)
	state.ball.cell = Vector2i(10, 5)

	var first_card := view._card_rect(0)
	var last_card := view._card_rect(7)
	var canvas: Vector2i = ViewPalette.SCREEN_SIZE
	if not _check(last_card.end.x <= canvas.x and last_card.end.x > canvas.x * 0.9 and first_card.position.y > canvas.y * 0.75 and last_card.end.y <= canvas.y and not view._cost_rect().intersects(first_card) and not view._cost_rect().intersects(last_card), "Expected cards at lower right with separate cost card: canvas=%s root=%s first=%s last=%s cost=%s" % [canvas, root.size, first_card, last_card, view._cost_rect()]):
		return
	for index in 7:
		if not _check(view._card_rect(index).position.y == last_card.position.y and view._card_rect(index).end.x <= view._card_rect(index + 1).position.x, "Eight deployment cards must form a nonoverlapping horizontal row"):
			return
	_begin_deploy(view, DEPLOY_CELL)
	before = state.state_hash()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(state.state_hash() == before, "Drawing deployment preview must not mutate simulation state"):
		return

	var capture_args := OS.get_cmdline_user_args()
	if not capture_args.is_empty():
		_mouse(view, view._cancel_rect().get_center(), true)
		state.units = [
			UnitState.new(0, 0, "blaze", Vector2i(12, 5), 2821, 1, 0, 0),
			UnitState.new(1, 1, "hoshiguma", Vector2i(13, 5), 3200, 26, 0, 2),
			UnitState.new(2, 0, "exusiai", Vector2i(14, 4), 1673, 3, 0, 2),
			UnitState.new(3, 1, "ceobe", Vector2i(6, 4), 1565, 12, 0, 0),
		]
		state.next_unit_id = 4
		state.step([], [])
		state.ball.add_push(state.ball.cell + Vector2i.RIGHT, 4000, load("res://resources/ball/standard.tres"))
		for _tick in 3:
			state.step([], [])
		_begin_deploy(view, DEPLOY_CELL)
		view._preview_facing = 3
		before = state.state_hash()
		view.queue_redraw()
		await process_frame
		await process_frame
		if not _check(state.state_hash() == before, "Drawing attack and damage effects must not mutate simulation state"):
			return
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(capture_args[0])
		if not _check(error == OK, "Cannot save deployment UI screenshot: %s" % error_string(error)):
			return
	print("Deploy view OK: two drags, four facings, cancel controls, deferred commands, HUD placement, read-only rendering")
	quit(0)


func _begin_deploy(view: MatchView, cell: Vector2i) -> void:
	_mouse(view, view._card_rect(view._tray_operator_ids().find("bagpipe")).get_center(), true)
	_motion(view, view.projection.cell_rect(cell).get_center())
	_mouse(view, view.projection.cell_rect(cell).get_center(), false)


func _mouse(view: MatchView, position: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = pressed
	view._unhandled_input(event)


func _motion(view: MatchView, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	view._unhandled_input(event)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
