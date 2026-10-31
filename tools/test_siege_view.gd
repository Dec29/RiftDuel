extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData = load("res://resources/operators/siege.tres")
	var data := {"siege":op}
	for index in 3:
		var ids := PackedStringArray(["siege"]);var skills := PackedInt32Array([index])
		var state := MatchState.new(112,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
		state.sides[0].cost=99;state.ball.cell=Vector2i(12,5)
		state.step([InputCommand.new(0,0,"siege",-1,Vector2i(13,5),-1,2)],[])
		state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=0
		var input := LocalInput.new(0);input.select_unit(0)
		var view := MatchView.new();view.bind(state,input,data);root.add_child(view)
		await process_frame
		view._activate_selected_skill()
		var commands := input.take_commands()
		if not check(commands.size()==(1 if index==2 else 0),"S1/S2 automatic; only S3 manual button"):return
		state.step(commands,[])
		if not check(state.units[0].skill_activation_count==1,"Actual skill activation"):return
		for mirrored in [false,true]:
			view.mirror_board=mirrored
			for facing in 4:
				state.units[0].facing=facing;state.units[0].last_attack_tick=state.tick-1
				var before := state.state_hash();view.queue_redraw()
				await process_frame;await process_frame
				if not check(before==state.state_hash(),"Rendering read-only"):return
				var model: OperatorSpineVisual=view._bagpipe_models[0]
				if not check(model.clip=="Attack" and model.view_index==(1 if facing==3 else 0) and model.mesh.get_surface_count()==1,"Both native sides visible, four directions"):return
				if DisplayServer.get_name()!="headless" and facing==2:
					await RenderingServer.frame_post_draw
					if not check(root.get_texture().get_image().save_png("res://.godot/five-operators-research/siege-s%d-m%d.png"%[index,int(mirrored)])==OK,"Capture"):return
		var audio := BattleAudio.new();root.add_child(audio);audio.voice_volume=0;audio.sfx_volume=0
		audio.begin(state,0);audio.observe(state,data)
		if not check(audio._voices.siege.size()==6,"Six original Japanese deployment/skill voices decode"):return
		audio.queue_free();view.queue_free();await process_frame
	print("SIEGE_VIEW_OK: carried skills, buttons, native four-way/both mirror models, six decoded voices, read-only rendering")
	quit(0)
func check(value: bool,label: String) -> bool:
	if not value:push_error(label);quit(1)
	return value
