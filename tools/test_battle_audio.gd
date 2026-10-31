extends SceneTree

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var operators := {}
	for id in root.get_node("OperatorDB").all_ids():operators[id]=root.get_node("OperatorDB").get_data(id)
	var squad := PackedStringArray(["bagpipe","silverash"])
	var skills := PackedInt32Array([2,1])
	var a := MatchState.new(438,operators,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[squad,squad],[skills,skills])
	var b := MatchState.new(438,operators,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[squad,squad],[skills,skills])
	var audio := BattleAudio.new()
	root.add_child(audio)
	audio.voice_volume=0
	audio.sfx_volume=0
	audio.rng.seed=774
	audio.begin(a,0)
	if not check(audio._voices.size()==BattleAudio.START_CUES.size() and audio._sfx.has(BattleAudio.DEPLOY_CUE) and audio._sfx.has("p_atk_gunlance_n") and audio._sfx.has("b_char_addshield"),"Voice pools, landing, normal attack and missing shield cue load"):return
	var deploy_tags := {}
	var skill_tags := {}
	for index in 100:
		audio._voice("bagpipe",false,0)
		deploy_tags[audio.last_voice_tag]=true
		audio._voice("bagpipe",true,0)
		skill_tags[audio.last_voice_tag]=true
	if not check(deploy_tags.size()==2 and skill_tags.size()==4,"Random selection uses both deployment and all four skill lines"):return
	audio.voice_events=0
	audio.sfx_events=0
	for state in [a,b]:state.sides[0].cost=100
	var commands: Array[InputCommand] = [InputCommand.new(0,0,"bagpipe",-1,Vector2i(13,5),-1,0),InputCommand.new(0,0,"silverash",-1,Vector2i(13,4),-1,0)]
	a.step(commands,[])
	b.step(commands,[])
	var hash_before := a.state_hash()
	audio.observe(a,operators)
	if not check(a.state_hash()==hash_before and audio.voice_events==2 and audio.sfx_events==2,"Successful deployments speak and play landing sound, read-only"):return
	audio.observe(a,operators)
	if not check(audio.voice_events==2,"Repeated frame and waiting does not replay"):return
	a.step([InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,2)],[])
	b.step([InputCommand.new(b.tick,1,"",0,Vector2i.ZERO,2)],[])
	audio.observe(a,operators)
	if not check(a.units[0].skill_activation_count==0 and audio.voice_events==2,"Insufficient-SP skill does not speak"):return
	for state in [a,b]:
		state.units[0].sp=100
		state.units[1].sp=100
	for tick in 90:
		var inputs: Array[InputCommand]=[]
		if tick==0:inputs=[InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,2),InputCommand.new(a.tick,1,"",1,Vector2i.ZERO,1)]
		if tick==1:inputs=[InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,2),InputCommand.new(a.tick,1,"",1,Vector2i.ZERO,1)]
		a.step(inputs,[])
		b.step(inputs,[])
		var before := a.state_hash()
		audio.observe(a,operators)
		if not check(a.state_hash()==before and a.state_hash()==b.state_hash(),"Audio random choices leave per-tick state/RNG unchanged"):return
	if not check(a.units[0].skill_activation_count==1 and a.units[1].skill_activation_count==1 and audio.voice_events==4 and audio.sfx_events==4,"Accepted activation counted once; invalid repeats and stance close do not speak"):return
	var prior_voice := audio.voice_events
	var prior_sfx := audio.sfx_events
	audio._process(19.99)
	for state in [a,b]:
		state.units[0].skill_ticks_left=0
		state.units[0].sp=100
		action_skill(state)
	audio.observe(a,operators)
	if not check(a.state_hash()==b.state_hash() and audio.voice_events==prior_voice and audio.sfx_events==prior_sfx+1,"Rapid successful skill keeps its sound effect but voice respects20 seconds"):return
	audio._process(0.02)
	for state in [a,b]:
		state.units[0].skill_ticks_left=0
		state.units[0].sp=100
		action_skill(state)
	audio.observe(a,operators)
	if not check(audio.voice_events==prior_voice+1 and audio.sfx_events==prior_sfx+2,"Skill voice resumes after20 real active seconds"):return
	var redeployed := UnitState.new(8,0,"bagpipe",Vector2i(13,5),100)
	audio._request_voice(redeployed,true)
	if not check(audio.voice_events==prior_voice+1,"Redeployment cannot reset same-operator skill voice cooldown"):return
	audio._request_voice(redeployed,false)
	if not check(audio.voice_events==prior_voice+2,"Deployment voice does not share skill cooldown"):return
	var enemy := UnitState.new(9,1,"bagpipe",Vector2i(7,5),100)
	var preferences=preload("res://preferences.gd").new()
	preferences.voice_volume=0
	preferences.sfx_volume=0
	preferences.voice_sides="local"
	audio.apply_preferences(preferences)
	prior_voice=audio.voice_events
	prior_sfx=audio.sfx_events
	audio._request_voice(enemy,false)
	audio._request_voice(enemy,true)
	audio._cue(enemy.operator_id,2)
	if not check(audio.voice_events==prior_voice and audio.sfx_events==prior_sfx+1,"Local-only scope filters enemy deployment/skill voices, never enemy SFX"):return
	audio.begin(a,1)
	audio._request_voice(a.units[0],false)
	audio._request_voice(enemy,false)
	if not check(audio.voice_events==prior_voice+1,"Local-only also recognizes red-side player"):return
	preferences.voice_sides="both"
	audio.apply_preferences(preferences)
	var heal_squad := PackedStringArray(["nightingale","bagpipe"])
	var heal_skills := PackedInt32Array([1,0])
	var healing := MatchState.new(441,operators,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[heal_squad,heal_squad],[heal_skills,heal_skills])
	healing.units=[UnitState.new(0,0,"nightingale",Vector2i(13,2),operators.nightingale.max_health,30,0,0,1),UnitState.new(1,0,"bagpipe",Vector2i(14,2),int(operators.bagpipe.max_health/2),0,999)]
	audio.begin(healing,0)
	prior_voice=audio.voice_events
	healing.step([],[])
	audio.observe(healing,operators)
	if not check(healing.units[0].skill_activation_count==1 and audio.voice_events==prior_voice+1,"Charged healing shield counts actual consumption once"):return
	var sounds := MatchState.new(445,operators,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["eyjafjalla"],["bagpipe"]],[[0],[0]])
	sounds.units=[UnitState.new(0,0,"eyjafjalla",Vector2i(13,2),operators.eyjafjalla.max_health,0,0,0,0),UnitState.new(1,1,"bagpipe",Vector2i(14,2),operators.bagpipe.max_health,0,999)]
	audio.begin(sounds,0)
	prior_sfx=audio.sfx_events
	sounds.step([],[])
	hash_before=sounds.state_hash()
	audio.observe(sounds,operators)
	if not check(sounds.units[0].last_attack_tick==0 and sounds.state_hash()==hash_before and audio.sfx_events==prior_sfx,"Real normal attack queues source delay without mutating state"):return
	for tick in 13:
		sounds.step([],[])
		audio.observe(sounds,operators)
	if not check(audio.sfx_events==prior_sfx,"Delayed attack sound waits15 combat ticks"):return
	sounds.step([],[])
	audio.observe(sounds,operators)
	if not check(audio.sfx_events==prior_sfx+1,"Original attack sound fires at its due tick"):return
	audio.observe(sounds,operators)
	if not check(audio.sfx_events==prior_sfx+1,"Repeated rendering never duplicates normal attack sound"):return
	sounds.units[0].attack_ticks_left=0
	sounds.step([],[])
	audio.observe(sounds,operators)
	sounds.step([InputCommand.new(sounds.tick,InputCommand.Kind.RETREAT,"",0)],[])
	audio.observe(sounds,operators)
	for tick in 20:
		sounds.step([],[])
		audio.observe(sounds,operators)
	if not check(audio.sfx_events==prior_sfx+1 and audio._pending_sounds.is_empty(),"Retreat cancels delayed sounds; no post-retreat attack playback"):return
	var charged := MatchState.new(446,operators,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["eyjafjalla"],["bagpipe"]],[[1],[0]])
	charged.units=[UnitState.new(0,0,"eyjafjalla",Vector2i(13,2),operators.eyjafjalla.max_health,operators.eyjafjalla.skills[1].sp_required,0,0,1),UnitState.new(1,1,"bagpipe",Vector2i(14,2),operators.bagpipe.max_health,0,999)]
	audio.begin(charged,0)
	prior_sfx=audio.sfx_events
	charged.step([],[])
	audio.observe(charged,operators)
	if not check(charged.units[0].skill_activation_count==1 and audio.sfx_events==prior_sfx,"Charged fire attack preserves the original delayed sound"):return
	for tick in 13:
		charged.step([],[])
		audio.observe(charged,operators)
	if not check(audio.sfx_events==prior_sfx,"Charged fire sound waits15 combat ticks"):return
	charged.step([],[])
	hash_before=charged.state_hash()
	audio.observe(charged,operators)
	if not check(audio.sfx_events==prior_sfx+1 and charged.state_hash()==hash_before,"Charged fire sound fires once without modifying simulation"):return
	audio.begin(a,0)
	for player in audio._voice_players:
		if not check(player.volume_linear==0.0,"Voice mute applies"):return
	a.result=MatchState.RESULT_BLUE_WIN
	audio.observe(a,operators)
	for player in audio._voice_players:
		if not check(not player.playing,"Result stops battle voices"):return
	for player in audio._sfx_players:
		if not check(not player.playing,"Result stops all battle sound effects"):return
	if not check(audio._pending_sounds.is_empty(),"Result clears delayed sound effects"):return
	if AudioServer.get_driver_name()!="Dummy":
		audio.begin(healing,0)
		var capture := AudioEffectCapture.new()
		capture.buffer_length=1.0
		var effect_index := AudioServer.get_bus_effect_count(0)
		AudioServer.add_bus_effect(0,capture)
		audio.voice_volume=100
		audio._voice("bagpipe",false,0)
		await create_timer(0.6).timeout
		var signal_energy := 0.0
		for sample in capture.get_buffer(capture.get_frames_available()):signal_energy+=sample.length_squared()
		if not check(signal_energy>0.001,"Native battle voice mixes audible signal"):return
		preferences.voice_volume=0
		audio.apply_preferences(preferences)
		for active_player in audio._voice_players:
			if not check(active_player.volume_linear==0.0,"Volume edits mute already playing voices immediately"):return
		audio._voice("bagpipe",false,1)
		preferences.voice_sides="local"
		audio.apply_preferences(preferences)
		for voice_index in audio._voice_players.size():
			if audio._voice_owners[voice_index]==1 and not check(not audio._voice_players[voice_index].playing,"Local-only immediately stops already playing enemy dialogue"):return
		preferences.sfx_volume=100
		audio.apply_preferences(preferences)
		for cue in [BattleAudio.DEPLOY_CUE,"p_atk_gunlance_n","b_char_addshield"]:
			audio.stop()
			capture.clear_buffer()
			audio._play_sound(cue,true)
			await create_timer(0.3).timeout
			var sfx_energy := 0.0
			for sample in capture.get_buffer(capture.get_frames_available()):sfx_energy+=sample.length_squared()
			if not check(sfx_energy>0.001,"Native landing/attack/shield sound mixes audible signal: "+cue):return
		preferences.sfx_volume=0
		audio.apply_preferences(preferences)
		for sfx_player in audio._sfx_players:
			if not check(sfx_player.volume_linear==0.0,"Volume edits immediately mute active sound effects"):return
		audio.begin(healing,0)
		var player := audio._voice_players[0]
		player.stream=audio._voices.bagpipe["024"]
		player.play()
		audio._play_sound("b_char_atkboost",true)
		var sfx_player := audio._sfx_players[(audio._sfx_cursor+BattleAudio.SKILL_SFX_CHANNELS-1)%BattleAudio.SKILL_SFX_CHANNELS]
		await create_timer(0.1).timeout
		paused=true
		await process_frame
		var clock := audio._active_seconds
		var position := player.get_playback_position()
		var sfx_position := sfx_player.get_playback_position()
		await create_timer(0.2).timeout
		if not check(player.stream_paused and absf(player.get_playback_position()-position)<0.05,"Single-player pause freezes voice playback"):return
		if not check(sfx_player.stream_paused and absf(sfx_player.get_playback_position()-sfx_position)<0.05,"Single-player pause freezes sound effect playback"):return
		if not check(audio._active_seconds==clock,"Paused time does not consume voice cooldown"):return
		paused=false
		await process_frame
		audio.stop()
		AudioServer.remove_bus_effect(0,effect_index)
	audio.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("BATTLE_AUDIO_OK:random voices/CD/sides; landing/normal attack/healing/skill cues; source delay/de-dup/retreat; SFX independent; per-tick hash/RNG; pause/mute/end")
	quit(0)

func check(ok: bool,message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok


func action_skill(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,2)],[])
