extends SceneTree
const OUTPUT := "res://.godot/four-operators-view-evidence"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for id in (OS.get_cmdline_user_args() if not OS.get_cmdline_user_args().is_empty() else PackedStringArray(["chen","aak","nian","kaltsit"])):
		print("VIEW_OPERATOR ",id)
		var op: OperatorData=load("res://resources/operators/%s.tres"%id)
		var ally: OperatorData=load("res://resources/operators/bagpipe.tres");ally=ally.duplicate(true);ally.operator_id="ally_fixture";ally.max_health=100000
		var data := {id:op,"ally_fixture":ally}
		for index in 3:
			var ids := PackedStringArray([id]);var skills := PackedInt32Array([index])
			var state := MatchState.new(101,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills]);state.sides[0].cost=99;state.sides[1].cost=99;state.ball.cell=Vector2i(10,10)
			var row := 2 if op.terrain_requirement=="high" else 5
			state.step([InputCommand.new(0,0,id,-1,Vector2i(13,row),-1,2)],[InputCommand.new(0,0,id,-1,Vector2i(7,row),-1,0)])
			var input := LocalInput.new(0);input.select_unit(0)
			var view := MatchView.new();view.bind(state,input,data);root.add_child(view);await process_frame
			if id=="kaltsit":
				if not check("mon3tr" in view._tray_operator_ids() and view._operator_available(MatchState.MON3TR_DATA),"Actual owned Mon3tr card available"):return
				state.step([InputCommand.new(state.tick,0,"mon3tr",-1,Vector2i(12,3),-1,2)],[InputCommand.new(state.tick,0,"mon3tr",-1,Vector2i(8,3),-1,0)])
			if id=="aak":
				state.units.append(UnitState.new(state.next_unit_id,0,"ally_fixture",Vector2i(12,2),100000,0,100000));state.next_unit_id+=1
			for tick in 60:state.step([],[])
			if id=="chen":state.ball.cell=Vector2i(12,5)
			state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=0
			if id=="chen" and index==0:
				state.step([],[])
			else:
				view._activate_selected_skill();var commands := input.take_commands()
				if not check(commands.size()==1,"Manual carried-skill button queues actual command "+id):return
				state.step(commands,[])
			if not check(state.units[0].skill_activation_count==1,"Actual carried-skill activation "+id):return
			if id=="kaltsit":
				state.units[2].attack_ticks_left=0;state.ball.cell=Vector2i(11,3);state.step([],[])
			for mirrored in [false,true]:
				view.mirror_board=mirrored
				for facing in 4:
					for unit in state.units:unit.facing=facing
					var before := state.state_hash();view.queue_redraw();await process_frame;await process_frame
					if not check(before==state.state_hash(),"Model/HUD rendering read-only"):return
					var model: OperatorSpineVisual=view._bagpipe_models[0]
					if not check(model.mesh.get_surface_count()==1 and model.view_index==(1 if facing==3 else 0),"Native owner four-way mesh "+id):return
					if id=="kaltsit":
						var token: OperatorSpineVisual=view._bagpipe_models[2]
						if not check(token.operator_id=="mon3tr" and token.mesh.get_surface_count()==1,"Actual native summon mesh"):return
					if DisplayServer.get_name()!="headless" and facing==2:
						await RenderingServer.frame_post_draw
						if not check(root.get_texture().get_image().save_png(OUTPUT+"/%s-s%d-m%d.png"%[id,index,int(mirrored)])==OK,"Screenshot"):return
			var audio := BattleAudio.new();root.add_child(audio);audio.voice_volume=0;audio.sfx_volume=0;audio.begin(state,0);var before := state.state_hash();audio.observe(state,view._operator_data)
			if not check(audio._voices[id].size()==6 and before==state.state_hash(),"Six decoded JA voices and read-only SFX "+id):return
			if id=="kaltsit" and not check(not audio._voices.has("mon3tr"),"No fabricated summon voice"):return
			var ai := AIInput.new(0,data);before=state.state_hash();ai.commands_for_tick(state)
			if not check(before==state.state_hash(),"AI read-only with new catalog"):return
			if id=="kaltsit":
				state.step([InputCommand.new(state.tick,2,"",2)],[]);view.queue_redraw();await process_frame;await process_frame
				if not check("mon3tr" in view._tray_operator_ids() and not view._operator_available(MatchState.MON3TR_DATA) and not view._bagpipe_models.has(2),"Token cooldown card remains and retired model removed"):return
			audio.queue_free();view.queue_free();await process_frame
	print("FOUR_OPERATORS_VIEW_OK: selected operators each3 carried skills, buttons, actual both-side deployment, owner/summon native meshes, mirrors/four facings, JA decoding and read-only hashes")
	quit(0)
func check(value: bool,label: String) -> bool:
	if not value:push_error(label);quit(1)
	return value
