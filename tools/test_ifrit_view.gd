extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=load("res://resources/operators/ifrit.tres")
	var data := {"ifrit":op}
	for index in 3:
		var ids := PackedStringArray(["ifrit"]);var skills := PackedInt32Array([index])
		var state := MatchState.new(134,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
		state.sides[0].cost=99;state.ball.cell=Vector2i(10,2)
		state.step([InputCommand.new(0,0,"ifrit",-1,Vector2i(13,2),-1,2)],[])
		state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=0
		var input := LocalInput.new(0);input.select_unit(0)
		var view := MatchView.new();view.bind(state,input,data);root.add_child(view)
		await process_frame
		view._activate_selected_skill()
		var commands := input.take_commands()
		if not check(commands.is_empty() if index==1 else commands.size()==1,"S2 automatic only; correct carried manual buttons"):return
		state.step(commands,[])
		if not check(state.units[0].skill_activation_count==1,"Actual carried skill activation%d"%index):return
		if index==2:
			for tick in 30:state.step([],[])
		for mirrored in [false,true]:
			view.mirror_board=mirrored
			for facing in 4:
				state.units[0].facing=facing;state.units[0].last_attack_tick=state.tick-1
				var before := state.state_hash();view.queue_redraw()
				await process_frame;await process_frame
				if not check(before==state.state_hash(),"Rendering stays read-only"):return
				var model: OperatorSpineVisual=view._bagpipe_models[0]
				var expected := ("Skill_Down_2_Loop" if facing==1 else "Skill_2_Loop") if index==2 else ("Attack_Down" if facing==1 else "Attack")
				if not check(model.clip==expected and model.view_index==(1 if facing==3 else 0) and model.mesh.get_surface_count()==1,"Native maintained flame / normal attacks "+expected):return
				if DisplayServer.get_name()!="headless" and facing==2:
					await RenderingServer.frame_post_draw
					if not check(root.get_texture().get_image().save_png("res://.godot/ifrit-s%d-m%d.png"%[index,int(mirrored)])==OK,"Capture"):return
		if index==2:
			var audio := BattleAudio.new();root.add_child(audio);audio.voice_volume=0;audio.sfx_volume=0
			audio.begin(state,0);audio.observe(state,data)
			var before := state.state_hash()
			if not check(audio._flame_loops.size()==1 and audio._flame_loops[0].stream.loop and audio._voices.ifrit.size()==6,"Maintained flame loops once with six original voices"):return
			root.get_tree().paused=true;audio._process(0.1)
			if not check(audio._flame_loops[0].stream_paused,"Pause freezes sustained sound"):return
			root.get_tree().paused=false;audio._process(0.1)
			if not check(state.state_hash()==before,"Audio clock/RNG leaves simulation unchanged"):return
			state.units[0].silence_ticks_left=1;audio.observe(state,data)
			if not check(audio._flame_loops.is_empty(),"Silence stops flame loop"):return
			state.units[0].silence_ticks_left=0;audio.observe(state,data)
			state.result=MatchState.RESULT_DRAW;audio.observe(state,data)
			if not check(audio._flame_loops.is_empty() and not audio._running,"Result stops continuous loop"):return
			audio.queue_free()
		view.queue_free();await process_frame
	print("IFRIT_VIEW_OK: three carried skills/buttons, line range, both mirror/facings, native flame loop, six voices, pause/silence/result and read-only hash")
	quit(0)
func check(value: bool,label: String) -> bool:
	if not value:push_error(label);quit(1)
	return value
