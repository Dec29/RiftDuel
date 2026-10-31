extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for id in ["nightingale_phantom", "phantom_clone"]:
		var owner := "nightingale" if id == "nightingale_phantom" else "phantom"
		var data := {owner: load("res://resources/operators/%s.tres" % owner)}
		for skill_index in ([0] if id == "nightingale_phantom" else [0, 1, 2]):
			var ids := PackedStringArray([owner])
			var skills := PackedInt32Array([skill_index])
			var state := MatchState.new(719, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [ids, ids], [skills, skills])
			state.sides[0].cost = 99
			state.sides[1].cost = 99
			state.ball.cell = Vector2i(10, 10)
			var row := 2 if owner == "nightingale" else 4
			state.step([InputCommand.new(0,0,owner,-1,Vector2i(13,row),-1,2)], [InputCommand.new(0,0,owner,-1,Vector2i(7,row),-1,0)])
			state.step([InputCommand.new(1,0,id,-1,Vector2i(13,5),-1,2)], [InputCommand.new(1,0,id,-1,Vector2i(7,5),-1,0)])
			if not check(state.units.size() == 4, "Actual legal owner and summon deployment both sides " + id): return
			var input := LocalInput.new(0)
			var view := MatchView.new()
			view.bind(state,input,data)
			root.add_child(view)
			await process_frame
			await process_frame
			for unit: UnitState in [state.units[2],state.units[3]]:
				var model: OperatorSpineVisual = view._bagpipe_models[unit.unit_id]
				if not check(model.clip == "Start" and model.mesh.get_surface_count() == 1, "Native deployment Start " + id): return
			var controlled := state.units[2]
			controlled.displacement_ticks_left=2
			var control_hash := state.state_hash()
			var control_model: OperatorSpineVisual=view._bagpipe_models[2]
			if not check(control_model.prepare(controlled,state.tick,SkillRules.attack_interval_ticks(controlled,state._operator_data[id])) and control_model.clip=="Idle" and control_hash==state.state_hash(),"Displacement interrupts deployment into Idle without state writes"):return
			controlled.displacement_ticks_left=0
			if not check(control_model.prepare(controlled,state.tick,SkillRules.attack_interval_ticks(controlled,state._operator_data[id])) and control_model.clip=="Start","Remaining deployment resumes after displacement"):return
			var initial_mesh: PackedVector2Array = view._bagpipe_models[2].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
			for tick in 17: state.step([],[])
			view.queue_redraw()
			await process_frame
			await process_frame
			var moved_mesh: PackedVector2Array = view._bagpipe_models[2].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			if not check(initial_mesh != moved_mesh, "Deployment visibly changes native geometry " + id): return
			for tick in 30: state.step([],[])
			for mirrored in [false,true]:
				view.mirror_board = mirrored
				for facing in 4:
					for unit: UnitState in [state.units[2],state.units[3]]: unit.facing = facing
					var before := state.state_hash()
					view.queue_redraw()
					await process_frame
					await process_frame
					if not check(before == state.state_hash(), "Render leaves combat hash unchanged"): return
					for unit: UnitState in [state.units[2],state.units[3]]:
						var model: OperatorSpineVisual = view._bagpipe_models[unit.unit_id]
						if not check(model.clip == "Idle" and model.mesh.get_surface_count() == 1 and model.view_index == (1 if facing == 3 else 0), "Native Idle/facing " + id): return
						if id == "nightingale_phantom" and not check(is_zero_approx(model.pose_seconds), "Zero-duration cage Idle remains static"): return
						var expected_height := 90.0 if id == "nightingale_phantom" else 120.0
						if not check(is_equal_approx(model.scale_for_row(100) * model.body_height, expected_height), "Measured body scale " + id): return
						if not check(is_zero_approx(model.anchor_offset(model.scale_for_row(100)).y + model.body_bottom * model.scale_for_row(100)), "Foot anchor stays on tile"): return
					if DisplayServer.get_name() != "headless" and skill_index == 0:
						await capture("%s-idle-m%d-f%d" % [id,int(mirrored),facing])
			# Static placement only for near/far visual projection; legal deployment was verified above.
			for row_index in [1,9]:
				state.units[2].cell=Vector2i(13,row_index)
				state.units[3].cell=Vector2i(7,row_index)
				var snapshot := state.state_hash()
				view.queue_redraw()
				await process_frame
				await process_frame
				var model: OperatorSpineVisual=view._bagpipe_models[2]
				var width := view.renderer.unit_row_width(view,state.units[2])
				var ratio := 0.9 if id=="nightingale_phantom" else 1.2
				if not check(is_equal_approx(model.scale_for_row(width)*model.body_height,width*ratio) and snapshot==state.state_hash(),"Near/far projection scales without state write"):return
				if DisplayServer.get_name()!="headless" and skill_index==0:await capture("%s-row%d"%[id,row_index])
			state.units[2].cell=Vector2i(13,5)
			state.units[3].cell=Vector2i(7,5)
			if id == "phantom_clone":
				var unit := state.units[2]
				unit.facing = 2
				state.ball.cell = unit.cell + Vector2i.LEFT
				var before_push := state.ball.accum
				for tick in 35:
					state.step([],[])
					if unit.last_attack_tick == state.tick-1: break
				if not check(unit.last_attack_tick == state.tick-1 and (state.ball.accum != before_push or state.ball.move_ticks_left > 0), "Actual clone attack pushes ball with carried passive%d" % skill_index): return
				view.queue_redraw()
				await process_frame
				await process_frame
				if not check(view._bagpipe_models[2].clip == "Attack", "Actual attack uses clone Attack, not guessed numbered skill"): return
				if DisplayServer.get_name() != "headless": await capture("clone-attack-s%d" % skill_index)
			state.units[2].stun_ticks_left=15
			view.queue_redraw()
			await process_frame
			await process_frame
			if not check(view._bagpipe_models[2].clip=="Idle" and is_zero_approx(view._bagpipe_models[2].pose_seconds),"Stun holds native Idle pose"):return
			state.units[2].stun_ticks_left=0
			view.queue_redraw()
			await process_frame
			await process_frame
			var model: OperatorSpineVisual = view._bagpipe_models[2]
			var pose := model.pose_seconds
			var before := state.state_hash()
			paused = true
			view.queue_redraw()
			await process_frame
			await process_frame
			if not check(model.pose_seconds == pose and state.state_hash() == before, "Pause freezes model without state mutation"): return
			paused = false
			state.result = MatchState.RESULT_DRAW
			view.queue_redraw()
			await process_frame
			await process_frame
			pose = model.pose_seconds
			view.queue_redraw()
			await process_frame
			if not check(model.pose_seconds == pose, "Result freezes native pose"): return
			state.result = MatchState.RESULT_RUNNING
			state._retreat_unit(state.units[2])
			view.queue_redraw()
			await process_frame
			await process_frame
			if not check(not view._bagpipe_models.has(2) and view._bagpipe_models.has(3), "Only removed summon model instance is released"): return
			view.queue_free()
			await process_frame
	print("SUMMON_MODELS_OK: actual deployment, Start/Idle/native Attack, cage static no attack, clone three passives, both sides/four facings/mirrors, scales/anchors, pause/result/removal and readonly hashes")
	quit(0)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if not args.is_empty() else "res://.godot/summon-model-evidence"
	if not check(root.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK, "Capture " + label): return

func check(value: bool, label: String) -> bool:
	if not value:
		push_error(label)
		quit(1)
	return value
