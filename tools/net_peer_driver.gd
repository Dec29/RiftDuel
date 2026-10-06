extends Node

class DelayedSession extends NetSession:
	var delay_ms := 0
	var outgoing: Array[Dictionary] = []

	func _send(message: Dictionary) -> void:
		if message.type == "start":
			match_seed = 0x52494654
			message.seed = match_seed
		outgoing.append({"at": Time.get_ticks_msec() + delay_ms, "message": message})

	func _process(delta: float) -> void:
		while not outgoing.is_empty() and outgoing[0].at <= Time.get_ticks_msec():
			var item: Dictionary = outgoing.pop_front()
			if peer != null:
				super._send(item.message)
		super._process(delta)

class DelayedRelay extends RelaySession:
	var delay_ms := 0
	var outgoing: Array[Dictionary] = []

	func _send(message: Dictionary) -> void:
		outgoing.append({"at": Time.get_ticks_msec() + delay_ms, "message": message})

	func _process(delta: float) -> void:
		while not outgoing.is_empty() and outgoing[0].at <= Time.get_ticks_msec():
			var item: Dictionary = outgoing.pop_front()
			if _socket != null:
				super._send(item.message)
		super._process(delta)


var _session: NetSession
var _battle: Node
var _mode := ""
var _role := ""
var _prefix := ""
var _limit := 0
var _trace: FileAccess
var _last_tick := -1
var _started := 0
var _deadline := 0
var _queued := false
var _queued_until := 0
var _red_deployed := false
var _skill_sent := false
var _sent := 0
var _finished_at := 0
var _endpoint := ""
var _invitation_written := false
var _input_delay := NetSession.INPUT_DELAY


func start(args: PackedStringArray) -> void:
	assert(args.size() in [7, 8])
	assert(OperatorDB.all_ids().size() == 8, "Expected eight operator resources")
	_role = args[0]
	_prefix = args[1]
	_mode = args[5]
	_limit = int(args[6])
	_trace = FileAccess.open(_prefix + "_" + _role + ".trace", FileAccess.WRITE)
	assert(_trace != null)
	if args.size() == 8:
		_endpoint = args[7]
		_input_delay = RelaySession.RELAY_DELAY
		var relay := DelayedRelay.new()
		relay.delay_ms = int(args[4])
		_session = relay
	else:
		var lan := DelayedSession.new()
		lan.delay_ms = int(args[4])
		_session = lan
	get_tree().root.add_child(_session)
	_session.match_requested.connect(func() -> void:
		_battle = load("res://main.tscn").instantiate()
		_battle.session = _session
		get_tree().root.add_child(_battle)
		get_tree().current_scene = _battle
	)
	if not _endpoint.is_empty():
		if _role == "host":
			(_session as RelaySession).create_online(_endpoint)
	elif _role == "host":
		_session.create_room(int(args[2]), "654321", int(args[3]))
	else:
		_session.join_code("654321", int(args[3]))
	_started = Time.get_ticks_msec()
	_deadline = _started + 900000
	get_tree().physics_frame.connect(_step)


func _step() -> void:
	if not _endpoint.is_empty():
		var relay := _session as RelaySession
		var invitation_path := _prefix + ".invitation"
		if _role == "host" and relay.phase == "hosting" and not _invitation_written:
			var invitation := FileAccess.open(invitation_path + ".tmp", FileAccess.WRITE)
			invitation.store_string(JSON.stringify({"code": relay.room_code, "invite": relay.invite}))
			invitation.close()
			assert(DirAccess.rename_absolute(invitation_path + ".tmp", invitation_path) == OK)
			_invitation_written = true
		elif _role == "client" and relay.phase == "idle" and FileAccess.file_exists(invitation_path):
			var invitation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(invitation_path))
			assert(DirAccess.remove_absolute(invitation_path) == OK)
			relay.join_online(_endpoint, invitation.code, invitation.invite)
	if Time.get_ticks_msec() > _deadline:
		push_error("Peer test timed out: " + _session.status)
		get_tree().quit(1)
		return
	if _session.phase == "failed" and _finished_at == 0:
		push_error("Peer failed: " + _session.status)
		get_tree().quit(1)
		return
	if _session.phase == "room":
		if not _session.local_ready:
			_session.set_ready(true)
		if _role == "host" and _session.remote_ready:
			_session.start_match()
	if _battle == null:
		return
	var state: MatchState = _battle.match_state
	if state.tick != _last_tick:
		_trace.store_line("%d,%d" % [state.tick, state.state_hash()])
		_last_tick = state.tick
		if _mode == "battle":
			var own: UnitState
			for unit in state.units:
				if unit.side == _session.side:
					own = unit
					break
			if _queued and state.tick >= _queued_until:
				_queued = false
			if _role == "host" and not _queued:
				if own != null and own.cell.x - state.ball.cell.x > 1 and state.ball.move_ticks_left == 0:
					_battle.local_input.queue_retreat(state.tick, own.unit_id)
					_queued = true
					_queued_until = state.tick + _input_delay + 2
					_sent += 1
				elif own == null and not state.sides[0].cooldowns.has("swire_alter") and state.sides[0].cost >= 9:
					_battle.local_input.select_operator("swire_alter")
					_battle.local_input.queue_deploy(state.tick, Vector2i(11, 5) if state.ball.cell.x == 10 else state.ball.cell, 2)
					_queued = true
					_queued_until = state.tick + _input_delay + 2
					_sent += 1
			if _role == "client":
				if not _red_deployed and state.tick >= 300:
					_battle.local_input.select_operator("bagpipe")
					_battle.local_input.queue_deploy(state.tick, Vector2i(0, 3), 3)
					_red_deployed = true
					_sent += 1
				elif own != null and not _skill_sent and own.sp >= 35:
					_battle.local_input.queue_skill(state.tick, own.unit_id)
					_skill_sent = true
					_sent += 1
	if _finished_at == 0 and ((_mode == "battle" and state.result != 0 and _battle.match_view.result_confirmed) or (_mode == "endurance" and state.tick >= _limit)):
		_finished_at = Time.get_ticks_msec()
		_trace.flush()
		var result := FileAccess.open(_prefix + "_" + _role + ".json", FileAccess.WRITE)
		result.store_string(JSON.stringify({"tick": state.tick, "hash": state.state_hash(), "result": state.result, "ball": [state.ball.cell.x, state.ball.cell.y], "commands": _sent, "elapsed_ms": _finished_at - _started, "side": _session.side, "build": _session.build_id, "operators": OperatorDB.all_ids().size()}))
		result.close()
		_trace.close()
		get_tree().physics_frame.disconnect(_step)
		call_deferred("_finish")


func _finish() -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(get_tree().root.get_texture().get_image().save_png(_prefix + "_" + _role + ".png") == OK)
	await get_tree().create_timer(1.0).timeout
	print("Peer OK: %s mode=%s tick=%d commands=%d" % [_role, _mode, _last_tick, _sent])
	get_tree().quit(0)
