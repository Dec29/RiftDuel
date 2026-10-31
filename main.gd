extends Node2D

@onready var match_view: MatchView = $MatchView

var match_state: MatchState
var local_input: LocalInput
var ai_input: AIInput
var solo_rules := MatchRules.new("score",5,1)
var session: NetSession
var _finish_sent := false
var _result_shown := false
var _simulation_phase := 0
var _audio: GameAudio
var _transferring := false


func _ready() -> void:
	set_physics_process(false)
	var operator_data := {}
	for operator_id in OperatorDB.all_ids():
		operator_data[operator_id] = OperatorDB.get_data(operator_id)
	var squad := SquadConfig.new()
	var squad_error := squad.read()
	if not squad_error.is_empty():
		push_error(squad_error)
		get_tree().quit(1)
		return
	var squads: Array = [squad.operator_ids, squad.operator_ids] if session == null else ([session.local_squad, session.remote_squad] if session.side == 0 else [session.remote_squad, session.local_squad])
	var skills: Array = [squad.skill_indices, squad.skill_indices] if session == null else ([session.local_skills, session.remote_skills] if session.side == 0 else [session.remote_skills, session.local_skills])
	match_state = MatchState.new(session.match_seed if session != null else 0x52494654, operator_data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads, skills, session.match_rules if session!=null else solo_rules)
	local_input = LocalInput.new(session.side if session != null else 0)
	if session == null:
		var ai_operators := {}
		for id in squad.operator_ids:
			ai_operators[id] = operator_data[id]
		ai_input = AIInput.new(1, ai_operators)
	match_view.bind(match_state, local_input, operator_data)
	var preferences := preload("res://preferences.gd").new()
	var preferences_error: String = preferences.read()
	if not preferences_error.is_empty():
		push_error(preferences_error)
		get_tree().quit(1)
		return
	match_view.mirror_board = (local_input.side == 0) == (preferences.goal_position == "left")
	match_view.multiplayer_match = session != null
	match_view.session=session
	match_view.result_confirmed = session == null
	match_view.home_requested.connect(func() -> void:
		var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
		assert(error == OK, "Cannot return to start menu")
	)
	match_view.room_requested.connect(_return_to_room)
	var pause_menu := $PauseLayer/PauseMenu
	if session != null:
		pause_menu.hide()
		pause_menu.set_process_input(false)
		session.failed.connect(func(message: String) -> void:
			if match_view.result_confirmed:
				return
			match_view.set_process_unhandled_input(false)
			$NetworkLayer/NetworkHUD.show_failure(message)
		)
		$NetworkLayer/NetworkHUD.leave_requested.connect(func() -> void:
			session.leave()
			var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
			assert(error == OK, "Cannot open start menu")
		)
		$NetworkLayer/NetworkHUD.show()
	pause_menu.pause_requested.connect(func() -> void: get_tree().paused = true)
	pause_menu.resume_requested.connect(func() -> void: get_tree().paused = false)
	pause_menu.home_requested.connect(func() -> void:
		get_tree().paused = false
		var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
		assert(error == OK, "Cannot return to start menu: " + error_string(error))
	)
	match_view.set_process_unhandled_input(false)
	var preparing:=Label.new()
	preparing.text="正在准备战场…"
	preparing.position=Vector2(540,340)
	preparing.z_index=1000
	add_child(preparing)
	await match_view.original_vfx.prepare(match_view)
	preparing.queue_free()
	if session!=null:
		if session.phase=="failed":return
		session.mark_loaded()
	match_view.set_process_unhandled_input(true)
	set_physics_process(true)
	_begin_battle_audio.call_deferred()


func _begin_battle_audio() -> void:
	_audio = GameAudio.instance(get_tree())
	_audio.begin_battle(match_state,local_input.side)


func _physics_process(_delta: float) -> void:
	if match_state.result == MatchState.RESULT_RUNNING:
		if session != null and session.phase != "running":
			return
		_simulation_phase += 1
		match_view.simulation_phase = _simulation_phase % Config.PHYSICS_TICKS_PER_SIMULATION_TICK
		if _simulation_phase < Config.PHYSICS_TICKS_PER_SIMULATION_TICK:
			return
		_simulation_phase = 0
	if match_state.result != MatchState.RESULT_RUNNING and not _result_shown:
		_result_shown = true
		local_input.take_commands()
		DeployInteraction.cancel(match_view)
		$PauseLayer/PauseMenu.hide()
		$PauseLayer/PauseMenu.set_process_input(false)
		match_view.queue_redraw()
		match_view.set_process(false)
	if session != null:
		if session.phase != "running":
			return
		if match_state.result == MatchState.RESULT_RUNNING:
			session.seal_frame(match_state.input_tick, local_input)
			var frame := session.take_frame(match_state.input_tick)
			match_view.simulation_waiting = frame.is_empty()
			$NetworkLayer/NetworkHUD.set_waiting(frame.is_empty(), local_input.side)
			if not frame.is_empty():
				match_state.step(frame[0], frame[1])
				_audio.observe_battle(match_state,match_view._operator_data)
				match_view.original_vfx.observe(match_view)
		else:
			if (local_input.side == 0 or session.bilateral_finish) and not _finish_sent:
				session.announce_finish(match_state.input_tick, match_state.result)
				_finish_sent = true
			if session.finish_tick != -1 and not match_view.result_confirmed:
				if session.finish_tick != match_state.input_tick or session.announced_result != match_state.result:
					session._fail("双方对局结果不一致，请使用相同版本")
				else:
					session.record_round(match_state.result)
					session.completed()
					match_view.result_confirmed = true
					$NetworkLayer/NetworkHUD.hide()
					match_view.queue_redraw()
		return
	if match_state.result == MatchState.RESULT_RUNNING:
		match_state.step(local_input.take_commands(), ai_input.commands_for_tick(match_state))
		_audio.observe_battle(match_state,match_view._operator_data)
		match_view.original_vfx.observe(match_view)
		match_view.queue_redraw()


func _return_to_room() -> void:
	if _transferring:return
	if session.phase == "running" and session.finish_tick > 0:
		session.return_to_room()
		var room = load("res://lobby.tscn").instantiate()
		room.session = session
		_transferring = true
		get_tree().root.add_child(room)
		get_tree().current_scene = room
		queue_free()
	else:
		var error := get_tree().change_scene_to_file("res://lobby.tscn")
		assert(error == OK, "Cannot return to room entry")


func _exit_tree() -> void:
	if _audio != null:
		_audio.stop_battle()
	if session != null and not _transferring:
		session.leave()
		session.queue_free()
