extends SceneTree

const CONFIG := preload("res://data/config.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(1))
	var operators := {}
	var database := root.get_node("OperatorDB")
	for id in database.all_ids():
		operators[id] = database.get_data(id)
	for side in 2:
		for goal_left in [true, false]:
			var state := MatchState.new(71, operators)
			state.sides[side].cost = 99
			var input := LocalInput.new(side)
			var view := MatchView.new()
			view.bind(state, input, operators)
			view.mirror_board = (side == 0) == goal_left
			root.add_child(view)
			var before := state.state_hash()
			for y in CONFIG.GRID_ROWS:
				for x in CONFIG.GRID_COLUMNS:
					var cell := Vector2i(x, y)
					assert(view._screen_to_cell(view._cell_rect(cell).get_center()) == cell)
			assert(view._screen_to_cell(Vector2(ViewPalette.BOARD_ORIGIN) - Vector2.ONE) == Vector2i(-1, -1))
			var goal := view._goal_line(side)
			assert(goal.size.y == ViewPalette.BOARD_SIZE.y)
			assert(is_equal_approx(goal.get_center().x, ViewPalette.BOARD_ORIGIN.x + (0 if goal_left else ViewPalette.BOARD_SIZE.x)))
			var cell := Vector2i(11 if side == 0 else 9, 5)
			for facing in 4:
				_mouse(view, view._card_rect(view._operator_ids.find("bagpipe")).get_center(), true)
				var center := view._cell_rect(cell).get_center()
				_mouse(view, center, false)
				assert(view._deploy_phase == MatchView.DeployPhase.FACING)
				var direction := view._view_direction(Vector2(AttackRange.rotate_offset(Vector2i.RIGHT, facing)))
				_mouse(view, center, true)
				_mouse(view, center + direction * ViewPalette.CELL_SIZE * 2, false)
				var commands := input.take_commands()
				assert(commands.size() == 1 and commands[0].cell == cell and commands[0].facing == facing)
				assert(state.state_hash() == before)
			state.units = [UnitState.new(0, side, "bagpipe", cell, 2484, 5, 0, 2 if side == 0 else 0)]
			state.next_unit_id = 1
			before = state.state_hash()
			_mouse(view, view._cell_rect(cell).get_center(), true)
			assert(input.selected_unit_id == 0)
			_mouse(view, view._cell_rect(cell).get_center(), true, MOUSE_BUTTON_RIGHT)
			assert(input.take_commands()[0].kind == InputCommand.Kind.RETREAT)
			state.ball.accum = Vector2i(-500, 0)
			before = state.state_hash()
			view.queue_redraw()
			await process_frame
			await process_frame
			assert(state.state_hash() == before)
			var args := OS.get_cmdline_user_args()
			if not args.is_empty():
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(args[0].get_basename() + "_%d_%s.png" % [side, "left" if goal_left else "right"]) == OK)
			view.free()
	print("Mirror view OK: both sides/goals, all cells, four facing drags, selection/retreat, full goal lines and read-only rendering")
	quit(0)


func _mouse(view: MatchView, position: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.pressed = pressed
	event.button_index = button
	view._unhandled_input(event)
