extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=load("res://resources/operators/magallan.tres")
	var data := {"magallan":op}
	for index in 3:
		var ids := PackedStringArray(["magallan"]);var skills := PackedInt32Array([index])
		var state := MatchState.new(400,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
		state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
		state.step([InputCommand.new(0,0,"magallan",-1,Vector2i(13,2),-1,2)],[])
		var input := LocalInput.new(0);input.select_unit(0)
		var view := MatchView.new();view.bind(state,input,data);root.add_child(view)
		await process_frame
		var drone_id: String=MatchState.DRONE_IDS[index]
		if not check(drone_id in view._tray_operator_ids() and view._operator_available(MatchState.DRONE_DATA[drone_id]),"Chosen module appears as deployable card"):return
		state.step([InputCommand.new(1,0,drone_id,-1,Vector2i(13,3) if index==1 else Vector2i(12,2),-1,2)],[])
		if not check(state.units.size()==2,"Actual legal drone deployment"):return
		state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=0
		state.ball.cell=Vector2i(12,3) if index==1 else Vector2i(11,2)
		view._activate_selected_skill();var commands := input.take_commands()
		if not check(commands.size()==1,"Three modules each have manual button"):return
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
				if not check(model.clip=="Skill" and model.mesh.get_surface_count()==1,"Shared native module activation animation"):return
				var drone: OperatorSpineVisual=view._bagpipe_models[1]
				if not check(drone.mesh.get_surface_count()==1 and drone.view_index==(1 if facing==3 else 0) and is_equal_approx(drone.scale_for_row(100)*drone.body_height,55.0),"Separate native drone, four facings, measured scale"):return
				if index==0 and not check(drone.clip=="Idle","F has no invented Attack clip"):return
				if DisplayServer.get_name()!="headless" and facing==2:
					await RenderingServer.frame_post_draw
					if not check(root.get_texture().get_image().save_png("res://.godot/five-operators-research/magallan-s%d-m%d.png"%[index,int(mirrored)])==OK,"Capture"):return
		input.select_unit(1);view.queue_redraw();await process_frame
		var audio := BattleAudio.new();root.add_child(audio);audio.voice_volume=0;audio.sfx_volume=0
		audio.begin(state,0);audio.observe(state,view._operator_data)
		if not check(audio._voices.magallan.size()==6 and not audio._voices.has(drone_id),"Six original JA voices, no cloned drone voice"):return
		if index>0:
			state.units[1].last_attack_tick=state.tick
			audio.observe(state,view._operator_data)
			if not check(audio.sfx_events>0,"Actual drone skill SFX cached and emitted"):return
		audio.queue_free()
		var ai := AIInput.new(0,data);var before := state.state_hash();ai.commands_for_tick(state)
		if not check(before==state.state_hash(),"AI queries deployed drone without mutation"):return
		state.step([InputCommand.new(state.tick,2,"",1)],[])
		view.queue_redraw();await process_frame;await process_frame
		if not check(drone_id in view._tray_operator_ids() and not view._operator_available(MatchState.DRONE_DATA[drone_id]),"Manual retreat preserves stock card and cooldown"):return
		view.queue_free();await process_frame
	print("MAGALLAN_VIEW_OK: three modules, native body/drones, tray, mirrors/facings, voices/SFX and read-only hash")
	quit(0)
func check(value: bool,label: String) -> bool:
	if not value:push_error(label);quit(1)
	return value
