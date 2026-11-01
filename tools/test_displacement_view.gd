extends SceneTree

const FIXTURE := preload("res://tools/displacement_fixture.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var interactive := "--interactive" in OS.get_cmdline_user_args()
	for mode in (["pull"] if "--pull" in OS.get_cmdline_user_args() else ["push", "pull"]):
		for side in ([0] if interactive else [0, 1]):
			for mirrored in ([false] if interactive else [false, true]):
				var state := FIXTURE.create_match(mode)
				var input := LocalInput.new(side)
				var view := MatchView.new()
				view.bind(state, input, state._operator_data)
				view.mirror_board = mirrored
				root.add_child(view)
				state.step(FIXTURE.deploy_blue(0), FIXTURE.deploy_red(0))
				for tick in 30:
					state.step([], [])
					if state.units[1].displacement_ticks_left > 0: break
				if not check(state.units.size() == 3 and state.units[1].displacement_ticks_left > 0, "Actual attack must produce visible displacement"): return
				state.units[0].attack_ticks_left = 10000
				for stage in ["start", "middle", "end"]:
					if stage == "middle":
						for tick in state.units[1].displacement_duration_ticks / 2: state.step([], [])
					if stage == "end":
						while state.units[1].displacement_ticks_left > 0: state.step([], [])
					input.select_unit(1)
					view._details_open = true
					var before := state.state_hash()
					view.queue_redraw()
					await process_frame
					await process_frame
					if not check(state.state_hash() == before, "View must not mutate sim"): return
					var endpoint := view.projection.cell_rect(state.units[1].cell).get_center()
					if stage == "end" and not check(view.renderer.unit_screen_center(view, state.units[1]).is_equal_approx(endpoint), "Actor finishes on authoritative cell"): return
					if stage == "middle":
						var origin := view.projection.cell_rect(state.units[1].displacement_origin).get_center()
						var center := view.renderer.unit_screen_center(view, state.units[1])
						if not check(center.distance_to(origin) > 1 and center.distance_to(endpoint) > 1, "Smooth pose between source and destination"): return
						var click := InputEventMouseButton.new()
						click.button_index = MOUSE_BUTTON_LEFT
						click.pressed = true
						click.position = center
						view._unhandled_input(click)
						if not check(input.selected_unit_id == 1 and state.state_hash() == before, "Moving actor remains clickable without state mutation"): return
					if DisplayServer.get_name() != "headless":
						if not check(root.get_texture().get_image().save_png("res://.godot/displacement-%s-%d-%s-%s.png" % [mode, side, mirrored, stage]) == OK, "Screenshot save"): return
				if interactive:
					# Local QA lab: only normal view-generated commands enter step.
					state.units[0].attack_ticks_left = 0
					while true:
						await physics_frame
						state.step(input.take_commands() if side == 0 else [], input.take_commands() if side == 1 else [])
				view.queue_free()
				await process_frame
	print("Displacement view OK: push/pull, side2/mirror2, real attack/pose/selection/endpoints and read-only hash")
	quit(0)


func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
