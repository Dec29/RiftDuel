extends Node2D

@onready var match_view: MatchView = $MatchView

var match_state: MatchState
var local_input: LocalInput
var ai_input: AIInput
var session: NetSession
var _finish_sent := false
var _result_shown := false


func _ready() -> void:
	var operator_data := {}
	for operator_id in OperatorDB.all_ids():
		operator_data[operator_id] = OperatorDB.get_data(operator_id)
	match_state = MatchState.new(session.match_seed if session != null else 0x52494654, operator_data)
	local_input = LocalInput.new(session.side if session != null else 0)
	if session == null:
		ai_input = AIInput.new(1, operator_data)
	match_view.bind(match_state, local_input, operator_data)
	var preferences := preload("res://preferences.gd").new()
	var preferences_error: String = preferences.read()
	if not preferences_error.is_empty():
		push_error(preferences_error)
		get_tree().quit(1)
		return
	match_view.mirror_board = (local_input.side == 0) == (preferences.goal_position == "left")
	match_view.multiplayer_match = session != null
	match_view.result_confirmed = session == null
	match_view.home_requested.connect(func() -> void:
		var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
		assert(error == OK, "Cannot return to start menu")
	)
	match_view.room_requested.connect(func() -> void:
		var error := get_tree().change_scene_to_file("res://lobby.tscn")
		assert(error == OK, "Cannot return to room entry")
	)
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
		session.mark_loaded()
	pause_menu.pause_requested.connect(func() -> void: get_tree().paused = true)
	pause_menu.resume_requested.connect(func() -> void: get_tree().paused = false)
	pause_menu.home_requested.connect(func() -> void:
		get_tree().paused = false
		var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
		assert(error == OK, "Cannot return to start menu: " + error_string(error))
	)


func _physics_process(_delta: float) -> void:
	if match_state.result != MatchState.RESULT_RUNNING and not _result_shown:
		_result_shown = true
		local_input.take_commands()
		match_view._cancel_deploy()
		$PauseLayer/PauseMenu.hide()
		$PauseLayer/PauseMenu.set_process_input(false)
		match_view.queue_redraw()
		match_view.set_process(false)
	if session != null:
		if session.phase != "running":
			return
		if match_state.result == MatchState.RESULT_RUNNING:
			session.seal_frame(match_state.tick, local_input)
			var frame := session.take_frame(match_state.tick)
			$NetworkLayer/NetworkHUD.set_waiting(frame.is_empty(), local_input.side)
			if not frame.is_empty():
				match_state.step(frame[0], frame[1])
		else:
			if (local_input.side == 0 or session.bilateral_finish) and not _finish_sent:
				session.announce_finish(match_state.tick, match_state.result)
				_finish_sent = true
			if session.finish_tick != -1 and not match_view.result_confirmed:
				if session.finish_tick != match_state.tick or session.announced_result != match_state.result:
					session._fail("双方对局结果不一致，请使用相同版本")
				else:
					session.completed()
					match_view.result_confirmed = true
					$NetworkLayer/NetworkHUD.hide()
					match_view.queue_redraw()
		return
	if match_state.result == MatchState.RESULT_RUNNING:
		match_state.step(local_input.take_commands(), ai_input.commands_for_tick(match_state))
		match_view.queue_redraw()


func _exit_tree() -> void:
	if session != null:
		session.leave()
		session.queue_free()
