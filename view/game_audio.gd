class_name GameAudio
extends Node

const INTRO := preload("res://assets/audio/music/m_sys_act1multi_intro.ogg")
const LOOP := preload("res://assets/audio/music/m_sys_act1multi_loop.ogg")
const BATTLE_INTRO := preload("res://assets/audio/music/m_bat_indust_intro.mp3")
const BATTLE_LOOP := preload("res://assets/audio/music/m_bat_indust_loop.mp3")
const CROSSFADE_SECONDS := 0.5
const PREFERENCES := preload("res://preferences.gd")

var music_volume := PREFERENCES.DEFAULT_VOLUME
var sfx_volume := PREFERENCES.DEFAULT_VOLUME
var voice_volume := PREFERENCES.DEFAULT_VOLUME
var voice_sides := "both"
var _intro := AudioStreamPlayer.new()
var _loop := AudioStreamPlayer.new()
var _crossfade := -1.0
var _music_mode := ""
var _battle: BattleAudio


static func instance(tree: SceneTree) -> GameAudio:
	var audio := tree.root.get_node_or_null("GameAudio") as GameAudio
	if audio==null:
		audio=GameAudio.new()
		audio.name="GameAudio"
		tree.root.add_child(audio)
	return audio


func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_intro.stream=INTRO
	_loop.stream=LOOP
	add_child(_intro)
	add_child(_loop)
	_intro.finished.connect(func() -> void:
		if not _loop.playing:
			_crossfade=CROSSFADE_SECONDS
			_loop.play()
			_music_levels()
	)
	var preferences := PREFERENCES.new()
	var error: String=preferences.read()
	if not error.is_empty():
		push_error(error)
		get_tree().quit(1)
		return
	apply_preferences(preferences)


func apply_preferences(preferences: RefCounted) -> void:
	music_volume=preferences.music_volume
	sfx_volume=preferences.sfx_volume
	voice_volume=preferences.voice_volume
	voice_sides=preferences.voice_sides
	if _battle!=null:
		_battle.apply_preferences(preferences)
	_music_levels()


func start_menu() -> void:
	if _battle!=null:_battle.stop()
	if _music_mode=="menu" and (_intro.playing or _loop.playing):return
	_start_music("menu",INTRO,LOOP)


func _start_music(mode: String, intro: AudioStream, loop: AudioStream) -> void:
	_stop_music()
	_music_mode=mode
	_intro.stream=intro
	_loop.stream=loop
	_crossfade=-1.0
	_intro.play()
	_music_levels()


func stop_menu() -> void:
	if _music_mode=="menu":_stop_music()


func _stop_music() -> void:
	_intro.stop()
	_loop.stop()
	_intro.stream_paused=false
	_loop.stream_paused=false
	_crossfade=-1.0
	_music_mode=""


func _exit_tree() -> void:
	_stop_music()
	if _battle!=null:_battle.stop()


func begin_battle(state: MatchState, side: int) -> void:
	stop_menu()
	if _battle==null:
		_battle=BattleAudio.new()
		add_child(_battle)
	_battle.sfx_volume=sfx_volume
	_battle.voice_volume=voice_volume
	_battle.voice_sides=voice_sides
	_battle.begin(state,side)
	# Silent QA does not auto-play streams; audio fixtures decode explicitly.
	if AudioServer.get_driver_name()!="Dummy":_start_music("battle",BATTLE_INTRO,BATTLE_LOOP)


func observe_battle(state: MatchState, operators: Dictionary) -> void:
	_battle.observe(state,operators)
	if state.result!=MatchState.RESULT_RUNNING:stop_battle()


func stop_battle() -> void:
	_battle.stop()
	if _music_mode=="battle":_stop_music()


func _process(delta: float) -> void:
	var paused := get_tree().paused and _music_mode=="battle"
	_intro.stream_paused=paused
	_loop.stream_paused=paused
	if paused:return
	if _intro.playing and _crossfade<0.0 and _intro.stream.get_length()-_intro.get_playback_position()<=CROSSFADE_SECONDS:
		_crossfade=0.0
		_loop.play()
	if _crossfade>=0.0:
		_crossfade=minf(CROSSFADE_SECONDS,_crossfade+delta)
		if _crossfade==CROSSFADE_SECONDS:_intro.stop()
	_music_levels()


func _music_levels() -> void:
	var progress := clampf(_crossfade/CROSSFADE_SECONDS,0.0,1.0)
	_intro.volume_linear=float(music_volume)/100.0*(1.0-progress)
	_loop.volume_linear=float(music_volume)/100.0*(progress if _crossfade>=0.0 else 0.0)
