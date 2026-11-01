extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var operator: OperatorData=load("res://resources/operators/skadi.tres")
	var data := {"skadi":operator}
	for index in 3:
		var state := MatchState.new(263,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[PackedStringArray(["skadi"]),PackedStringArray(["skadi"])],[PackedInt32Array([index]),PackedInt32Array([index])])
		state.sides[0].cost=99;state.sides[1].cost=99;state.ball.cell=Vector2i(10,10)
		state.step([InputCommand.new(0,0,"skadi",-1,Vector2i(13,5),-1,0)],[InputCommand.new(0,0,"skadi",-1,Vector2i(7,5),-1,2)])
		var input := LocalInput.new(0)
		var view := MatchView.new()
		view.bind(state,input,data)
		root.add_child(view)
		input.select_operator("skadi")
		view._info_tab=view.InfoTab.SKILL
		if not await render(state,view,"reserve%d"%index):return
		if not check(operator.skills[index].skill_name in view._info_layout_paragraphs,"Reserve carried skill name"):return
		input.select_unit(0)
		if index!=1:
			state.units[0].sp=operator.skills[index].sp_required
			view._activate_selected_skill()
			var commands := input.take_commands()
			if not check(commands.size()==1 and commands[0].skill_index==index,"Correct carried skill button"):return
			state.step(commands,[])
		else:
			view._activate_selected_skill()
			if not check(input.take_commands().is_empty(),"Deployment S2 never queues manual activation"):return
		for side in 2:
			input.side=side;input.select_unit(side)
			for mirrored in [false,true]:
				view.mirror_board=mirrored
				for facing in 4:
					state.units[side].facing=facing
					if not check(view._range_offsets(operator,state.units[side].cell)==operator.attack_range,"Exact two-cell range shared with simulation"):return
					if not await render(state,view,"s%d-side%d-m%d-f%d"%[index,side,int(mirrored),facing]):return
		input.side=0;input.select_unit(1)
		view._activate_selected_skill()
		if not check(input.take_commands().is_empty(),"Enemy activation remains unavailable"):return
		state.units[0].skill_ticks_left=1;state.step([],[])
		if not await render(state,view,"expired%d"%index):return
		view.queue_free();await process_frame
	var audio := BattleAudio.new()
	root.add_child(audio)
	audio.voice_volume=0;audio.sfx_volume=0;audio.rng.seed=263
	var deployment := {};var skills := {}
	for index in 100:
		audio._voice("skadi",false,0);deployment[audio.last_voice_tag]=true
		audio._voice("skadi",true,0);skills[audio.last_voice_tag]=true
	if not check(deployment.size()==2 and skills.size()==4 and audio._sfx.has("p_atk_sword_n") and audio._sfx.has("p_imp_skadi_h"),"All six JP voices and original attack cues decode"):return
	audio.queue_free();await process_frame
	print("SKADI_VIEW_OK: carried3 skills, buttons, both sides/mirror/facings, exact ranges, read-only rendering, six voices and attack cues")
	quit(0)

func render(state: MatchState,view: MatchView,label: String) -> bool:
	var before := state.state_hash()
	view.queue_redraw();await process_frame;await process_frame
	if not check(before==state.state_hash(),"View changed simulation: "+label):return false
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		if not check(root.get_texture().get_image().save_png("res://.godot/skadi-view-"+label+".png")==OK,"Screenshot"):return false
	return true

func check(value: bool,label: String) -> bool:
	if not value:push_error(label);quit(1)
	return value
