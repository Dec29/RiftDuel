extends SceneTree
const OUTPUT := "res://.godot/texas-four-view-evidence"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var checked := 0
	for id in ["texas","lappland","ptilopsis","gravel"]:
		if not OS.get_cmdline_user_args().is_empty() and id!=OS.get_cmdline_user_args()[0]:continue
		for index in 2:
			if OS.get_cmdline_user_args().size()>1 and index!=int(OS.get_cmdline_user_args()[1]):continue
			checked+=1
			print("VIEW_SKILL ",id," ",index)
			var op: OperatorData=load("res://resources/operators/%s.tres"%id)
			var fixture: OperatorData=load("res://resources/operators/bagpipe.tres");fixture=fixture.duplicate(true);fixture.operator_id="fixture";fixture.max_health=100000;fixture.attack=0;fixture.defense=0
			var data := {id:op,"fixture":fixture}
			var ids := PackedStringArray([id]);var skills := PackedInt32Array([index])
			var state := MatchState.new(101,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills]);state.sides[0].cost=99;state.sides[1].cost=99;state.ball.cell=Vector2i(10,10)
			state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=1000000000
			var row := 2 if op.terrain_requirement=="high" else 5
			var audio := BattleAudio.new();root.add_child(audio);audio.voice_volume=0;audio.sfx_volume=0;audio.begin(state,0)
			state.step([InputCommand.new(0,0,id,-1,Vector2i(13,row),-1,2)],[InputCommand.new(0,0,id,-1,Vector2i(7,row),-1,0)])
			audio.observe(state,state._operator_data)
			if not check(state.units.size()==2,"Both owners actually deployed"):return
			var input := LocalInput.new(0);input.select_unit(0)
			var view := MatchView.new();view.bind(state,input,data);root.add_child(view);await process_frame
			for tick in 60:state.step([],[]);audio.observe(state,state._operator_data)
			var ally_cell := Vector2i(12,3) if id=="ptilopsis" else Vector2i(13,row+1)
			var enemy_cell := Vector2i(12,3) if id=="w" else Vector2i(12,row)
			if id!="ptilopsis":state.units.append(UnitState.new(state.next_unit_id,1,"fixture",enemy_cell,100000,0,100000));state.next_unit_id+=1
			state.units.append(UnitState.new(state.next_unit_id,0,"fixture",ally_cell,1000,0,100000));state.next_unit_id+=1
			state.units[-1].bind_ticks_left=300
			state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=0
			var auto: bool = (id=="texas" and index==0) or id in ["lappland","gravel"]
			if auto:state.step([],[])
			else:
				view._activate_selected_skill();var commands := input.take_commands()
				if not check(commands.size()==1,"Actual manual button queues command "+id):return
				state.step(commands,[])
			if not check((state.units[0].gravel_ticks_left>0 if id=="gravel" else state.units[0].skill_activation_count==1),"Actual carried skill activated "+id+str(index)):return
			audio.observe(state,state._operator_data)
			for sample in [0,150]:
				if sample>0:
					for tick in sample:state.step([],[]);audio.observe(state,state._operator_data)
				for mirrored in [false,true]:
					view.mirror_board=mirrored
					for facing in 4:
						for unit in state.units:unit.facing=facing
						var before := state.state_hash();view.queue_redraw();await process_frame;await process_frame
						if not check(before==state.state_hash(),"Read-only native model and HUD"):return
						var model: OperatorSpineVisual=view._bagpipe_models[0]
						if not check(model.mesh.get_surface_count()==1 and model.view_index==(1 if facing==3 else 0),"Four-way native mesh "+id+" "+model.clip):return
						if DisplayServer.get_name()!="headless" and facing==2:
							await RenderingServer.frame_post_draw
							if not check(root.get_texture().get_image().save_png(OUTPUT+"/%s-s%d-t%d-m%d.png"%[id,index,sample,int(mirrored)])==OK,"Screenshot"):return
			if id=="ptilopsis" and index==1:
				state.units[0].skill_ticks_left=1;state.step([],[]);view.queue_redraw();await process_frame;await process_frame
				if not check(view._bagpipe_models[0].clip=="Skill_End","Actual expiry event plays native End"):return
			if not check(audio._voices[id].size()==6 and audio.sfx_events>0,"JA and verified combat cues decoded/dispatched"):return
			var ai := AIInput.new(0,data);var before := state.state_hash();ai.commands_for_tick(state)
			if not check(before==state.state_hash(),"AI queries read-only"):return
			audio.queue_free();view.queue_free();await process_frame
	print("TEXAS_BATCH_VIEW_OK:%d actual carried skills, both-side owners, four facings/mirrors, native meshes, start/loop, 24JA/SFX, read-only view/audio/AI hashes"%checked)
	quit(0)
func check(value: bool,label: String) -> bool:
	if not value:push_error(label);quit(1)
	return value
