extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=load("res://resources/operators/weedy.tres")
	var data := {"weedy":op}
	for index in 3:
		var ids := PackedStringArray(["weedy"]);var skills := PackedInt32Array([index])
		var state := MatchState.new(400,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
		state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
		state.step([InputCommand.new(0,0,"weedy",-1,Vector2i(13,5),-1,2)],[])
		state.step([InputCommand.new(1,0,"weedy_cannon",-1,Vector2i(13,4),-1,2)],[])
		state.ball.cell=Vector2i(12,4) if index==2 else Vector2i(12,5)
		state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=0
		var input := LocalInput.new(0);input.select_unit(0)
		var view := MatchView.new();view.bind(state,input,data);root.add_child(view)
		await process_frame
		view._activate_selected_skill();var commands := input.take_commands()
		if not check(commands.size()==(1 if index==2 else 0),"S1/S2 automatic, S3 manual"):return
		state.step(commands,[])
		if not check(state.units[0].skill_activation_count==1,"Actual carried skill activation"):return
		for mirrored in [false,true]:
			view.mirror_board=mirrored
			for facing in 4:
				for unit in state.units:unit.facing=facing
				var before := state.state_hash();view.queue_redraw()
				await process_frame;await process_frame
				if not check(before==state.state_hash(),"View leaves simulation unchanged"):return
				var model: OperatorSpineVisual=view._bagpipe_models[0]
				var expected: String=["Skill","Skill_2_Begin","Skill_3_Down" if facing==1 else "Skill_3"][index]
				if not check(model.clip==expected and model.mesh.get_surface_count()==1,"Weedy actual skill family "+expected):return
				var cannon: OperatorSpineVisual=view._bagpipe_models[1]
				if not check(cannon.mesh.get_surface_count()==1 and cannon.view_index==(1 if facing==3 else 0) and cannon.scale_for_row(100)*cannon.body_height==65.0,"Separate cannon native model/sides and measured scale"):return
				if index==2 and not check(cannon.clip==("Skill_Down" if facing==1 else "Skill"),"Cannon actual synchronized nitrogen animation"):return
				if DisplayServer.get_name()!="headless" and facing==2:
					await RenderingServer.frame_post_draw
					if not check(root.get_texture().get_image().save_png("res://.godot/five-operators-research/weedy-s%d-m%d.png"%[index,int(mirrored)])==OK,"Capture"):return
		var audio := BattleAudio.new();root.add_child(audio);audio.voice_volume=0;audio.sfx_volume=0
		audio.begin(state,0);audio.observe(state,view._operator_data)
		if not check(audio._voices.weedy.size()==6 and not audio._voices.has("weedy_cannon"),"Six original voices, no cloned cannon voice"):return
		audio.queue_free()
		state.step([InputCommand.new(state.tick,2,"",1)],[])
		view.queue_redraw();await process_frame;await process_frame
		if not check("weedy_cannon" in view._tray_operator_ids() and not view._operator_available(MatchState.CANNON_DATA),"Exited cannon becomes visible but cooldown disables deployment"):return
		view.queue_free();await process_frame
	print("WEEDY_VIEW_OK: three carried skills, cannon deployment/model/lifetime-card, mirrors/facings, voice and read-only hash")
	quit(0)
func check(value: bool,label: String) -> bool:
	if not value:push_error(label);quit(1)
	return value
