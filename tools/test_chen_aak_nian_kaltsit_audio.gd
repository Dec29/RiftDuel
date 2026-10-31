extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for id in ["chen","aak","nian","kaltsit"]:
		for index in 3:
			var op: OperatorData=load("res://resources/operators/%s.tres"%id)
			var data := {id:op}
			var fixture: OperatorData=load("res://resources/operators/bagpipe.tres");fixture=fixture.duplicate(true);fixture.operator_id="friendly_fixture";fixture.max_health=100000;data.friendly_fixture=fixture
			var ids := PackedStringArray([id]);var carried := PackedInt32Array([index])
			var a := MatchState.new(910,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[carried,carried]);var b := MatchState.new(910,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[carried,carried])
			for state: MatchState in [a,b]:
				state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=1000000
			var audio := BattleAudio.new();root.add_child(audio);audio.voice_volume=0;audio.sfx_volume=0;audio.begin(a,0)
			var row := 2 if op.terrain_requirement=="high" else 5
			var deploy: Array[InputCommand]=[InputCommand.new(0,0,id,-1,Vector2i(13,row),-1,2)]
			for state: MatchState in [a,b]:state.step(deploy,[])
			audio.observe(a,a._operator_data)
			if id=="kaltsit":
				deploy=[InputCommand.new(a.tick,0,"mon3tr",-1,Vector2i(12,3),-1,2)]
				for state: MatchState in [a,b]:state.step(deploy,[])
				audio.observe(a,a._operator_data)
			for state: MatchState in [a,b]:
				state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=0
				state.ball.cell=Vector2i(11,3) if id=="kaltsit" else Vector2i(12,row)
				if id=="kaltsit":state.units[1].attack_ticks_left=0
				if id=="aak":state.units.append(UnitState.new(1,0,"friendly_fixture",Vector2i(12,3),100000,0,100000))
			var before := audio.sfx_events
			for tick in 120:
				var commands: Array[InputCommand]=[]
				if tick==0 and not (id=="chen" and index==0):commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
				a.step(commands,[]);b.step(commands,[])
				var hash_before := a.state_hash();audio.observe(a,a._operator_data)
				if not check(hash_before==a.state_hash() and a.state_hash()==b.state_hash(),"Original audio leaves sim/RNG unchanged"):return
			if not check(a.units[0].skill_activation_count>0 and audio.sfx_events>before,"Actual skill/attack audio dispatched "+id+str(index)):return
			audio.queue_free();await process_frame
	print("FOUR_OPERATOR_AUDIO_OK: actual deployment/12skills/delayed hits, JA decoding, cached verified special cues,1440 read-only replay ticks")
	quit(0)
func check(value: bool,label: String) -> bool:
	if not value:push_error(label);quit(1)
	return value
