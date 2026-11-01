extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=load("res://resources/operators/typhon.tres")
	var data := {"typhon":op}
	for index in 3:
		var ids := PackedStringArray(["typhon"]);var skills := PackedInt32Array([index])
		var state := MatchState.new(2012,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
		state.sides[0].cost=99;state.ball.cell=Vector2i(10,2)
		state.step([InputCommand.new(0,0,"typhon",-1,Vector2i(13,2),-1,2)],[])
		state.units[0].sp=op.skills[index].sp_required
		var input := LocalInput.new(0);input.select_unit(0)
		var view := MatchView.new();view.bind(state,input,data);root.add_child(view)
		await process_frame
		view._activate_selected_skill()
		state.step(input.take_commands(),[])
		if not check(state.units[0].skill_activation_count==1,"Actual button chooses carried skill%d"%index):return
		for permanent in [false,true]:
			if permanent:
				if index!=1:continue
				state.units[0].skill_repeat_activation_count=2;state.units[0].skill_ticks_left=-2
			for mirrored in [false,true]:
				view.mirror_board=mirrored
				for facing in 4:
					state.units[0].facing=facing;state.units[0].last_attack_tick=state.tick-1
					var before := state.state_hash();view.queue_redraw()
					await process_frame;await process_frame
					if not check(before==state.state_hash(),"Rendering stays read-only"):return
					var model: OperatorSpineVisual=view._bagpipe_models[0]
					var expected := "Skill_3" if index==2 else (("Skill_Down_2_2" if facing==1 else "Skill_2_2") if permanent else ("Skill_Down_2_1" if facing==1 else "Skill_2_1"))
					if index==0:expected="Attack_Down" if facing==1 else "Attack"
					if not check(model.clip.begins_with(expected) and model.view_index==(1 if facing==3 else 0) and model.mesh.get_surface_count()==1,"Actual native skill action "+expected):return
					if DisplayServer.get_name()!="headless" and facing==2:
						await RenderingServer.frame_post_draw
						if not check(root.get_texture().get_image().save_png("res://.godot/typhon-s%d-perm%d-m%d.png"%[index,int(permanent),int(mirrored)])==OK,"Capture"):return
		if index==2:
			var ai := AIInput.new(0,data)
			if not check(ai.commands_for_tick(state).is_empty(),"AI does not immediately close its active marked skill"):return
		view.queue_free();await process_frame
	var audio := BattleAudio.new();root.add_child(audio);audio.voice_volume=0
	if not check(audio._voices.typhon.size()==6 and audio._sfx.has("p_atk_mechaxbow_s"),"Original six voices and skill cue decode"):return
	audio.queue_free();await process_frame
	print("TYPHON_VIEW_OK:3 actual buttons, native normal/S2 first/permanent/S3 clips, both mirror/facings, ammo, audio and read-only hashes")
	quit(0)
func check(value: bool,label: String) -> bool:
	if not value:push_error(label);quit(1)
	return value
