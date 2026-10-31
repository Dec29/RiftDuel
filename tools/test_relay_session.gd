extends SceneTree

var _deadline := 0
var _endpoint := "ws://127.0.0.1:24860/ws"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_endpoint = args[0]
	_deadline = Time.get_ticks_msec() + 45000
	var pending := RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(pending)
	pending.phase = "starting"
	pending._room_id = "a".repeat(32)
	pending.local_squad = PackedStringArray(["bagpipe"])
	pending.local_skills = PackedInt32Array()
	pending.local_skills.resize(pending.local_squad.size())
	pending._receive({"v": RelaySession.PROTOCOL_VERSION, "seq": 1, "type": "ready", "room_id": pending._room_id, "side": 0, "ready": true})
	assert(pending.phase == "starting" and pending.local_ready)
	pending._receive({"v": RelaySession.PROTOCOL_VERSION, "seq": 3, "type": "hello"})
	assert(pending.phase == "failed")
	pending.queue_free()
	var legacy := RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(legacy)
	legacy._receive({"v": 3, "seq": 1, "type": "hello"})
	assert(legacy.phase == "failed")
	legacy.queue_free()
	var host := RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var client := RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(host)
	root.add_child(client)
	host.create_online(_endpoint)
	await _wait_phase(host, "hosting")
	client.join_online(_endpoint, host.room_code)
	await _wait_phase(client, "room")
	await _wait_phase(host, "room")
	assert(client.side == 1)
	var third := RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(third)
	third.join_online(_endpoint, host.room_code)
	await _wait_phase(third, "failed")
	assert(host.phase == "room" and client.phase == "room")
	third.queue_free()
	host.set_ready(true)
	client.set_ready(true)
	while not host.local_ready or not host.remote_ready or not client.local_ready or not client.remote_ready:
		await process_frame
		_check(host, client)
	assert(host.remote_squad == client.local_squad and client.remote_squad == host.local_squad)
	assert(host.local_squad == PackedStringArray(preload("res://data/config.gd").DEFAULT_SQUAD_IDS))
	host.start_match()
	await _wait_phase(host, "loading")
	await _wait_phase(client, "loading")
	assert(host.match_seed == client.match_seed and host.match_seed > 0)
	host.mark_loaded()
	client.mark_loaded()
	await _wait_phase(host, "running")
	await _wait_phase(client, "running")
	var operators := {}
	var db := root.get_node("OperatorDB")
	for id in db.all_ids():
		operators[id] = db.get_data(id)
	var states := [
		MatchState.new(host.match_seed, operators, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [host.local_squad, host.remote_squad]),
		MatchState.new(client.match_seed, operators, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad]),
	]
	for state in states:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
	var inputs := [LocalInput.new(0), LocalInput.new(1)]
	var peers := [host, client]
	var hashes := [{0: states[0].state_hash()}, {0: states[1].state_hash()}]
	inputs[0].select_operator("swire_alter")
	inputs[0].queue_deploy(0, Vector2i(12, 5), 2)
	inputs[0].select_operator("nightingale")
	inputs[0].queue_deploy(0, Vector2i(12, 2), 2)
	inputs[0].select_operator("nightingale_phantom")
	inputs[0].queue_deploy(0, Vector2i(11, 2), 2)
	inputs[1].select_operator("swire_alter")
	inputs[1].queue_deploy(0, Vector2i(8, 5), 0)
	while states[0].tick < 120 or states[1].tick < 120:
		for index in 2:
			if states[index].tick >= 120:
				continue
			peers[index].seal_frame(states[index].tick, inputs[index])
			var frame: Array = peers[index].take_frame(states[index].tick)
			if not frame.is_empty():
				states[index].step(frame[0], frame[1])
				hashes[index][states[index].tick] = states[index].state_hash()
		await create_timer(0.034).timeout
		_check(host, client)
	assert(states[0].units.size() == 4 and states[0].sides[0].phantom_count == 1)
	assert(states[0].units[2].operator_id == "nightingale_phantom" and states[0].units[2].hp < 6000)
	for tick in 121:
		assert(hashes[0][tick] == hashes[1][tick], "Relay state diverged at tick %d" % tick)
	# Control-message fixture: a hypothetical draw needs both reports.
	host.announce_finish(120, 3)
	await create_timer(0.1).timeout
	assert(host.finish_tick == -1 and client.finish_tick == -1)
	client.announce_finish(120, 3)
	while host.finish_tick == -1 or client.finish_tick == -1:
		await process_frame
		_check(host, client)
	assert(host.finish_tick == 120 and client.announced_result == 3)
	var retained_code := host.room_code
	var retained_room := host._room_id
	host.return_to_room()
	await _wait_phase(host,"returning")
	while not client.remote_returned:
		await process_frame
		_check(host,client)
	assert(client.phase=="running" and host.room_code==retained_code)
	client.return_to_room()
	await _wait_phase(host,"room")
	await _wait_phase(client,"room")
	assert(host._room_id==retained_room and client._room_id==retained_room and host.room_code==retained_code and not host.local_ready and not client.local_ready and host._consumed==0 and client._consumed==0)
	host.close()
	client.close()
	host.create_online(_endpoint)
	await _wait_phase(host, "hosting")
	client.join_online(_endpoint, host.room_code)
	await _wait_phase(client, "room")
	client.leave()
	await _wait_phase(host, "failed")
	host.create_online("ws://example.com:80/ws")
	assert(host.phase == "failed")
	var join_view = load("res://view/room_view.tscn").instantiate()
	root.add_child(join_view)
	var join_requests := []
	join_view.online_join_requested.connect(func(code: String) -> void: join_requests.append(code))
	join_view.get_node("Center/Panel/Mode").select(0)
	join_view.get_node("Center/Panel/JoinRow/Code").max_length = 6
	join_view.get_node("Center/Panel/JoinRow/Code").text = "123456"
	join_view.get_node("Center/Panel/JoinRow/Join").pressed.emit()
	assert(join_requests == ["123456"])
	join_view.queue_free()
	assert(change_scene_to_file("res://lobby.tscn") == OK)
	await process_frame
	await process_frame
	var lobby := current_scene
	var panel := lobby.get_node("RoomView/Center/Panel")
	panel.get_node("Mode").select(0)
	panel.get_node("Mode").item_selected.emit(0)
	assert(lobby.session is RelaySession and not panel.has_node("Endpoint") and not panel.has_node("Invite") and not panel.get_node("AddressRow").visible)
	lobby.preferences.use_custom_server = true
	lobby.preferences.custom_endpoint = _endpoint
	await _capture("relay-online-choose.png")
	panel.get_node("JoinRow/Code").text = "invalid"
	await _press(panel.get_node("JoinRow/Join"))
	assert(lobby.session.phase == "failed" and not panel.get_node("Status").text.is_empty())
	await _press(panel.get_node("Create"))
	await _wait_phase(lobby.session, "hosting")
	await _press(panel.get_node("Footer/Reset"))
	assert(lobby.session.phase == "idle" and not panel.get_node("Room").visible)
	host.create_online(_endpoint)
	await _wait_phase(host, "hosting")
	panel.get_node("JoinRow/Code").text = host.room_code
	await _press(panel.get_node("JoinRow/Join"))
	await _wait_phase(lobby.session, "room")
	await _wait_phase(host, "room")
	assert(lobby.session.side == 1 and panel.get_node("JoinRow/Code").text.is_empty())
	assert(not panel.get_node("Room/ReadyRow/Ready").disabled)
	await _press(panel.get_node("Room/ReadyRow/Ready"))
	while not host.remote_ready:
		await process_frame
		_check(host, lobby.session)
	await _press(panel.get_node("Room/ReadyRow/Ready"))
	while host.remote_ready or lobby.session.local_ready:
		await process_frame
		_check(host, lobby.session)
	await _press(panel.get_node("Footer/Reset"))
	await _wait_phase(host, "failed")
	assert(lobby.session.phase == "idle")
	await _press(panel.get_node("Create"))
	await _wait_phase(lobby.session, "hosting")
	assert(not panel.get_node("Room/Header/Copy").disabled and panel.get_node("Room/ReadyRow/Ready").disabled)
	assert("配对码" in panel.get_node("Room/Header/Code").text and "等待好友加入" in panel.get_node("Status").text)
	if DisplayServer.get_name() != "headless":
		var saved_clipboard := DisplayServer.clipboard_get()
		await _press(panel.get_node("Room/Header/Copy"))
		assert(DisplayServer.clipboard_get() == lobby.session.room_code)
		DisplayServer.clipboard_set(saved_clipboard)
	await _capture("relay-online-host.png")
	client.join_online(_endpoint, lobby.session.room_code)
	await _wait_phase(client, "room")
	await _wait_phase(lobby.session, "room")
	assert(panel.get_node("Room/Header/Copy").disabled and not panel.get_node("Room/ReadyRow/Ready").disabled)
	await _press(panel.get_node("Room/ReadyRow/Ready"))
	assert(lobby.session.local_ready and panel.get_node("Room/ReadyRow/Ready").text == "取消准备")
	await _press(panel.get_node("Room/ReadyRow/Ready"))
	assert(not lobby.session.local_ready)
	await create_timer(0.15).timeout
	await _press(panel.get_node("Room/ReadyRow/Ready"))
	client.set_ready(true)
	while not lobby.session.remote_ready:
		await process_frame
		_check(lobby.session, client)
	await _press(panel.get_node("Room/ReadyRow/Start"))
	await _wait_phase(client, "loading")
	client.mark_loaded()
	await _wait_phase(client, "running")
	var battle := current_scene
	assert(battle.scene_file_path == "res://main.tscn" and battle.session is RelaySession and battle.ai_input == null)
	client.leave()
	await _wait_phase(battle.session, "failed")
	battle.get_node("NetworkLayer/NetworkHUD/Failure/Panel/Return").pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://view/start_menu.tscn")
	host.queue_free()
	client.queue_free()
	print("Relay OK: real Go service, v4/code-only room, ready/load, 121 hashes, bilateral finish, retained room/return barrier, disconnect, WSS policy and mouse host/joiner ready/cancel/start and online UI to match/menu")
	quit(0)


func _press(button: Button) -> void:
	await process_frame
	await process_frame
	assert(button.is_visible_in_tree() and not button.disabled, "UI button unavailable: " + str(button.get_path()))
	if DisplayServer.get_name() == "headless":
		button.pressed.emit()
	else:
		var motion := InputEventMouseMotion.new()
		motion.position = button.get_global_rect().get_center()
		motion.global_position = motion.position
		root.push_input(motion)
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = motion.position
			click.global_position = motion.position
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			root.push_input(click)
			await process_frame


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/" + file_name)) == OK)


func _wait_phase(peer: RelaySession, expected: String) -> void:
	while peer.phase != expected:
		await process_frame
		assert(Time.get_ticks_msec() < _deadline, "Relay phase timeout: " + peer.phase)
		assert(peer.phase != "failed" or expected == "failed", "Unexpected relay failure: " + peer.status)


func _check(host: RelaySession, client: RelaySession) -> void:
	assert(Time.get_ticks_msec() < _deadline, "Relay test timed out")
	assert(host.phase != "failed" and client.phase != "failed", "Relay failed: " + host.status + " / " + client.status)
