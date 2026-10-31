extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {"phantom":load("res://resources/operators/phantom.tres")}
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(123, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [["phantom"],["phantom"]], [[1],[2]])
			state.sides[0].cost = 99
			state.sides[1].cost = 99
			state.ball.cell = Vector2i(10, 10)
			state.step([InputCommand.new(0,0,"phantom",-1,Vector2i(12,5),-1,2)], [InputCommand.new(0,0,"phantom",-1,Vector2i(8,5),-1,0)])
			state.step([InputCommand.new(1,0,"phantom_clone",-1,Vector2i(13,5),-1,2)], [InputCommand.new(1,0,"phantom_clone",-1,Vector2i(7,5),-1,0)])
			if not check(state.units.size() == 4 and state.units[2].skill_index == 1 and state.units[3].skill_index == 2, "Real body/clone deployment carries equipped skills"): return
			var input := LocalInput.new(side)
			var view := MatchView.new()
			view.bind(state, input, data)
			view.mirror_board = mirrored
			root.add_child(view)
			for id in [side, side + 2]:
				input.select_unit(id)
				view._details_open = true
				view._info_tab = view.InfoTab.COMMAND
				var before := state.state_hash()
				view.queue_redraw()
				await process_frame
				await process_frame
				if not check(before == state.state_hash(), "Read-only passive UI"): return
				if not check(view._skill_bar_ratio(state.units[id], state._operator_data[state.units[id].operator_id].skills[state.units[id].skill_index]) == (1.0 if side == 0 else 0.0), "Stacks show actual bar, burst has no charge bar"): return
				view._info_tab = view.InfoTab.SKILL
				view.queue_redraw()
				await process_frame
				await process_frame
				if not check(before == state.state_hash() and ("无技力消耗 · 层数耗尽或撤退后结束" if side == 0 else "无技力消耗 · 一次突袭／控制4.5秒") in view._info_layout_paragraphs, "Accurate passive duration in details"): return
				view._info_tab = view.InfoTab.COMMAND
				view.queue_redraw()
				await process_frame
				await process_frame
				view._activate_selected_skill()
				if not check(input.take_commands().is_empty(), "Deployment passive cannot manually activate"): return
				if DisplayServer.get_name() != "headless":
					if not check(root.get_texture().get_image().save_png("res://.godot/phantom-skills-%d-%s-%d.png" % [side,mirrored,id]) == OK, "Screenshot"): return
			view.queue_free()
			await process_frame
	print("Phantom skill view OK: body/clone selected passives, side2/mirror2 and read-only hashes")
	quit(0)


func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
