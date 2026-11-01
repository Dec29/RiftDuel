extends SceneTree

const CONFIG := preload("res://data/config.gd")

class RecordingView extends MatchView:
	var labels: Array[String] = []
	var highlighted := {}
	func _draw_cell_color(cell: Vector2i, color: Color, inset: float = 0.0) -> void:
		if is_equal_approx(color.a, 0.22):
			highlighted[cell] = projection.cell_polygon(cell, inset)
		super._draw_cell_color(cell, color, inset)
	func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
		labels.append(text)
		super._draw_text(position, text, font_size, color)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {}
	for id in root.get_node("OperatorDB").all_ids():
		data[id] = root.get_node("OperatorDB").get_data(id)
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(121, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [CONFIG.DEFAULT_SQUAD_IDS, CONFIG.DEFAULT_SQUAD_IDS])
			state.sides[side].cost = 99
			var input := LocalInput.new(side)
			var view := RecordingView.new()
			root.add_child(view)
			view.bind(state, input, data)
			view.set_process(false)
			view.simulation_waiting = true
			view.mirror_board = mirrored
			var before := state.state_hash()
			var far_left := view.projection.board_point(Vector2.ZERO)
			var far_right := view.projection.board_point(Vector2(CONFIG.GRID_COLUMNS, 0))
			var near_left := view.projection.board_point(Vector2(0, CONFIG.GRID_ROWS))
			var near_right := view.projection.board_point(Vector2(CONFIG.GRID_COLUMNS, CONFIG.GRID_ROWS))
			if not _check(is_equal_approx(far_left.y, far_right.y) and is_equal_approx(near_left.y, near_right.y) and is_equal_approx(far_left.x + far_right.x, near_left.x + near_right.x), "Reference view has horizontal edges and symmetric convergence"): return
			if not _check(is_equal_approx(absf(far_right.x - far_left.x) / absf(near_right.x - near_left.x), ViewPalette.BOARD_FAR_SCALE), "Far width is78 percent of near width"): return
			for row in CONFIG.GRID_ROWS:
				for column in CONFIG.GRID_COLUMNS:
					var cell := Vector2i(column, row)
					if not _check(view.projection.screen_to_cell(view.projection.cell_rect(cell).get_center()) == cell, "Cell center roundtrip %s side%d mirror%d" % [cell, side, int(mirrored)]): return
					if state.terrain_at(cell) == "high":
						var top := view.projection.cell_polygon(cell)
						for u in [0.15, 0.85]:
							for v in [0.15, 0.85]:
								var point: Vector2 = top[0].lerp(top[1], u).lerp(top[3].lerp(top[2], u), v)
								if not _check(view.projection.screen_to_cell(point) == cell, "Raised top corner hit %s" % cell): return
			for point in [Vector2(-0.5, 5), Vector2(21.5, 5), Vector2(10, -0.5), Vector2(10, 11.5)]:
				if not _check(view.projection.screen_to_cell(view.projection.board_point(point)) == Vector2i(-1, -1), "Outside tilted board rejects input"): return
			var isolated_high := Vector2i(6, 4)
			var top := view.projection.cell_polygon(isolated_high)
			var side_face := (top[2] + top[3]) * 0.5 + Vector2(0, ViewPalette.PLATFORM_HEIGHT * 0.5)
			if not _check(view.projection.screen_to_cell(side_face) == Vector2i(-1, -1), "Visible high side is not a deployment surface"): return
			var cell := Vector2i(11 if side == 0 else 9, 5)
			var center := view.projection.cell_rect(cell).get_center()
			for facing in 4:
				input.select_operator("bagpipe")
				view._deploy_phase = MatchView.DeployPhase.FACING
				view._preview_cell = cell
				# Near-diagonal logical drags distinguish inverse projection from screen axes.
				var directions := [Vector2(1, 0.95), Vector2(0.7, 1), Vector2(-1, 0.95), Vector2(0.7, -1)]
				var drag: Vector2 = view.projection.view_direction(directions[facing] * 2, cell) * ViewPalette.CELL_SIZE
				if not _check(view.projection.board_direction(drag, cell).is_equal_approx(directions[facing] * ViewPalette.CELL_SIZE * 2), "Direction transform must roundtrip"): return
				_mouse(view, center, true)
				_mouse(view, center + drag, false)
				var commands := input.take_commands()
				if not _check(commands.size() == 1 and commands[0].cell == cell and commands[0].facing == facing and state.state_hash() == before, "Tilted drag sends original logical facing%d" % facing): return
			# Ground geometry must survive repeated raised reads; floor mesh must follow mirror switches.
			var ground := view.projection.cell_polygon(isolated_high, 0.0, false)
			for read_index in 4:
				var raised := view.projection.cell_polygon(isolated_high)
				for corner in 4:
					if not _check(raised[corner].is_equal_approx(ground[corner] - Vector2(0, ViewPalette.PLATFORM_HEIGHT)), "Repeated high reads must not mutate cached ground"): return
			view.mirror_board = not mirrored
			view.queue_redraw()
			await process_frame
			await process_frame
			var mesh_ground: PackedVector2Array = view._floor_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			if not _check(mesh_ground.size() == CONFIG.GRID_COLUMNS * CONFIG.GRID_ROWS * 4 and mesh_ground[0].is_equal_approx(view.projection.board_point(Vector2.ZERO)) and view._floor_mesh_mirrored == view.mirror_board, "Floor mesh rebuild follows runtime mirror change"): return
			var mirrored_ground := view.projection.cell_polygon(isolated_high, 0.0, false)
			if not _check(mirrored_ground[0].is_equal_approx(view.projection.board_point(Vector2(isolated_high))), "Mirror switch invalidates projected geometry"): return
			view.mirror_board = mirrored
			# A match overlay raises the surface immediately without changing map resources.
			var converted := Vector2i(12, 5)
			var old_center := view.projection.cell_rect(converted).get_center()
			var old_polygon := view.projection.cell_polygon(converted)
			state.platform_cells.append(converted)
			var new_polygon := view.projection.cell_polygon(converted)
			for corner in 4:
				if not _check(new_polygon[corner].is_equal_approx(old_polygon[corner] - Vector2(0, ViewPalette.PLATFORM_HEIGHT)), "Live artificial terrain changes cached polygon height"): return
			var new_center := view.projection.cell_rect(converted).get_center()
			if not _check(new_center.is_equal_approx(old_center - Vector2(0, ViewPalette.PLATFORM_HEIGHT)) and view.projection.screen_to_cell(new_center) == converted and MatchState.DEFAULT_ARENA.terrain_at(converted) == "ground", "Artificial top raises and picks same logical tile; resource remains ground"): return
			if not _check(view.projection.cell_rect(converted, false).get_center().is_equal_approx(old_center), "Ball anchor stays on ground through an artificial high tile"): return
			state.units = [UnitState.new(0, side, "bagpipe", cell, data["bagpipe"].max_health, 5, 20, 2 if side == 0 else 0), UnitState.new(1, 1 - side, "hoshiguma", Vector2i(9 if side == 0 else 11, 5), data["hoshiguma"].max_health, 5, 20, 0 if side == 0 else 2), UnitState.new(2, side, "nightingale", converted, data["nightingale"].max_health, 5, 20)]
			state.ball.accum = Vector2i(-500, 0)
			state.ball.move_direction = Vector2i.LEFT
			state.ball.move_ticks_left = 2
			input.select_unit(0)
			for facing in 4:
				state.units[0].facing = facing
				before = state.state_hash()
				view.highlighted.clear()
				view.queue_redraw()
				await process_frame
				await process_frame
				var expected_cells: Array[Vector2i] = []
				for offset in MatchView.RANGE.acquisition_offsets(data["bagpipe"]):
					expected_cells.append(cell + MatchView.RANGE.rotate_offset(offset, facing))
				if not _check(view.highlighted.size() == expected_cells.size() and state.state_hash() == before, "Four-facing range uses logical cells and is read-only"): return
				for range_cell in expected_cells:
					if not _check(view.highlighted.has(range_cell), "Range highlight covers exact acquisition cell"): return
					var polygon: PackedVector2Array = view.highlighted[range_cell]
					var corners := [Vector2(0.02, 0.02), Vector2(0.98, 0.02), Vector2(0.98, 0.98), Vector2(0.02, 0.98)]
					for corner in 4:
						var lift := Vector2(0, ViewPalette.PLATFORM_HEIGHT if state.terrain_at(range_cell) == "high" else 0)
						if not _check(polygon[corner].is_equal_approx(view.projection.board_point(Vector2(range_cell) + corners[corner]) - lift), "Range corners follow projected tile top"): return
			before = state.state_hash()
			view.labels.clear()
			view.queue_redraw()
			await process_frame
			await process_frame
			if not _check(state.state_hash() == before and view.labels.has("待部署干员"), "Projection rendering reaches HUD and leaves simulation untouched"): return
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				if not _check(root.get_texture().get_image().save_png("res://.godot/arena-projection-%d-%d.png" % [side, int(mirrored)]) == OK, "Save tilted battle screenshot"): return
			view.free()
	print("Arena projection OK:231 cells/raised corners/side rejection, side2/mirror2, near-diagonal facing4, artificial tops, ball/goals/HUD, read-only hashes")
	quit(0)


func _mouse(view: MatchView, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.pressed = pressed
	event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
