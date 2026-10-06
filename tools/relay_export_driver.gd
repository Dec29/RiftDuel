extends Node

var host: RelaySession
var client: RelaySession


func start(args: PackedStringArray) -> void:
	assert(args.size() == 1)
	get_tree().create_timer(45.0).timeout.connect(func() -> void: get_tree().quit(1))
	host = RelaySession.new()
	client = RelaySession.new()
	add_child(host)
	add_child(client)
	host.failed.connect(func(message: String) -> void:
		push_error(message)
		get_tree().quit(1)
	)
	client.failed.connect(func(message: String) -> void:
		push_error(message)
		get_tree().quit(1)
	)
	host.create_online(args[0])
	await _wait_phase(host, "hosting")
	client.join_online(args[0], host.room_code, host.invite)
	await _wait_phase(client, "room")
	await _wait_phase(host, "room")
	host.set_ready(true)
	client.set_ready(true)
	while not host.remote_ready or not client.remote_ready:
		await get_tree().process_frame
	host.start_match()
	await _wait_phase(host, "loading")
	await _wait_phase(client, "loading")
	host.mark_loaded()
	client.mark_loaded()
	await _wait_phase(host, "running")
	await _wait_phase(client, "running")
	var operators := {}
	for id in OperatorDB.all_ids():
		operators[id] = OperatorDB.get_data(id)
	assert(operators.size() == 8)
	var states := [MatchState.new(host.match_seed, operators), MatchState.new(client.match_seed, operators)]
	for state in states:
		state.sides[0].cost = 99
	var hashes := [{0: states[0].state_hash()}, {0: states[1].state_hash()}]
	var inputs := [LocalInput.new(0), LocalInput.new(1)]
	inputs[0].select_operator("nightingale")
	inputs[0].queue_deploy(0, Vector2i(12, 2), 2)
	inputs[0].select_operator("nightingale_phantom")
	inputs[0].queue_deploy(0, Vector2i(11, 2), 2)
	var peers := [host, client]
	while states[0].tick < 120 or states[1].tick < 120:
		for index in 2:
			if states[index].tick >= 120:
				continue
			peers[index].seal_frame(states[index].tick, inputs[index])
			var frame: Array = peers[index].take_frame(states[index].tick)
			if not frame.is_empty():
				states[index].step(frame[0], frame[1])
				hashes[index][states[index].tick] = states[index].state_hash()
		await get_tree().create_timer(0.034).timeout
	for tick in 121:
		assert(hashes[0][tick] == hashes[1][tick])
	assert(states[0].units.size() == 2 and states[0].units[1].operator_id == "nightingale_phantom")
	assert(states[0].units[1].hp < 6000 and states[0].sides[0].phantom_count == 1)
	# Protocol fixture; the 120-tick simulation itself has not reached a game result.
	host.announce_finish(120, 3)
	client.announce_finish(120, 3)
	while host.finish_tick != 120 or client.finish_tick != 120:
		await get_tree().process_frame
	host.close()
	client.close()
	print("EXPORTED RELAY OK: eight operators, default TLS, phantom deployment/life loss/stock, 121 every-tick hashes and finish handshake")
	get_tree().quit(0)


func _wait_phase(peer: RelaySession, phase: String) -> void:
	while peer.phase != phase:
		await get_tree().process_frame
