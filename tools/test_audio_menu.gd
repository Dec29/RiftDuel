extends SceneTree

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var audio := GameAudio.instance(self)
	var preferences=preload("res://preferences.gd").new()
	preferences.music_volume=100
	audio.apply_preferences(preferences)
	var capture := AudioEffectCapture.new()
	capture.buffer_length=4.0
	var index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,capture)
	audio.start_menu()
	# The source intro has a quiet lead-in; sample beyond that lead-in.
	await create_timer(2.6).timeout
	if not check(capture.get_frames_available()>0,"Music mixed decoded frames"):return
	var samples := capture.get_buffer(capture.get_frames_available())
	var energy := 0.0
	for frame in samples:energy+=frame.length_squared()
	if not check(energy>0.001,"Menu music contains audible signal"):return
	var position := audio._intro.get_playback_position()
	audio.start_menu()
	if not check(audio._intro.get_playback_position()>=position,"Menu navigation does not restart music"):return
	audio._intro.seek(GameAudio.INTRO.get_length()-0.6)
	await create_timer(1.1).timeout
	if not check(audio._loop.playing and not audio._intro.playing and GameAudio.LOOP.loop,"Intro crossfades into looping stream"):return
	audio._loop.seek(GameAudio.LOOP.get_length()-0.1)
	await create_timer(0.4).timeout
	if not check(audio._loop.playing and audio._loop.get_playback_position()<1.0,"Native loop wraps without reloading"):return
	preferences.music_volume=0
	audio.apply_preferences(preferences)
	if not check(audio._intro.volume_linear==0.0 and audio._loop.volume_linear==0.0,"Zero volume mutes both music layers"):return
	audio.stop_menu()
	if not check(not audio._intro.playing and not audio._loop.playing,"Battle entry stops menu music"):return
	var state := MatchState.new(812)
	var replay := MatchState.new(812)
	var before := state.state_hash()
	preferences.music_volume=100
	audio.apply_preferences(preferences)
	capture.clear_buffer()
	audio.begin_battle(state,0)
	if AudioServer.get_driver_name()=="Dummy":audio._start_music("battle",GameAudio.BATTLE_INTRO,GameAudio.BATTLE_LOOP)
	if not check(state.state_hash()==before and audio._intro.stream==GameAudio.BATTLE_INTRO and audio._loop.stream==GameAudio.BATTLE_LOOP,"Selected battle BGM replaces menu streams without modifying simulation"):return
	await create_timer(1.0).timeout
	var battle_energy := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):battle_energy+=frame.length_squared()
	if not check(battle_energy>0.001,"Battle BGM mixes an audible decoded signal"):return
	audio._intro.seek(GameAudio.BATTLE_INTRO.get_length()-0.6)
	await create_timer(1.1).timeout
	if not check(audio._loop.playing and not audio._intro.playing and GameAudio.BATTLE_LOOP.loop,"Battle intro crossfades into the original looping segment"):return
	audio._loop.seek(GameAudio.BATTLE_LOOP.get_length()-0.1)
	await create_timer(0.4).timeout
	if not check(audio._loop.playing and audio._loop.get_playback_position()<1.0,"Battle native loop wraps without reloading"):return
	paused=true
	await process_frame
	var battle_position := audio._loop.get_playback_position()
	await create_timer(0.2).timeout
	if not check(audio._loop.stream_paused and absf(audio._loop.get_playback_position()-battle_position)<0.05,"Single-player pause freezes battle BGM"):return
	paused=false
	await process_frame
	preferences.music_volume=0
	audio.apply_preferences(preferences)
	if not check(audio._intro.volume_linear==0.0 and audio._loop.volume_linear==0.0,"Music volume immediately mutes battle BGM"):return
	for tick in 45:
		state.step([],[])
		replay.step([],[])
		audio.observe_battle(state,{})
		if not check(state.state_hash()==replay.state_hash(),"Music observation preserves each simulation tick and RNG"):return
	state.result=MatchState.RESULT_BLUE_WIN
	audio.observe_battle(state,{})
	if not check(not audio._intro.playing and not audio._loop.playing,"Result stops battle BGM"):return
	audio.start_menu()
	if not check(audio._intro.stream==GameAudio.INTRO and audio._loop.stream==GameAudio.LOOP and audio._intro.playing,"Returning to menus restores the menu BGM"):return
	audio.begin_battle(replay,0)
	audio.stop_battle()
	if not check(not audio._intro.playing and not audio._loop.playing,"Leaving a running match stops battle BGM"):return
	AudioServer.remove_bus_effect(0,index)
	# Mixer commands complete asynchronously; let it release the stopped stream.
	await create_timer(0.15).timeout
	print("AUDIO_MENU_OK: menu/battle decoded signal, intro crossfade/native loops, immediate music volume, pause/result/leave/menu return, per-tick readonly hash/RNG")
	quit(0)

func check(ok: bool,message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
