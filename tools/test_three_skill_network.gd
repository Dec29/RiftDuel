extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var online := not args.is_empty()
	var host: NetSession = RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content()) if online else NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var client: NetSession = RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content()) if online else NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(host)
	root.add_child(client)
	var deadline := Time.get_ticks_msec() + 8000
	if online:
		host.create_online(args[0])
		while host.phase != "hosting" and host.phase != "failed" and Time.get_ticks_msec() < deadline: await process_frame
		if not check(host.phase == "hosting", "Create loopback relay room"): return
		client.join_online(args[0], host.room_code)
	else:
		host.create_room(24924, "731625", 24925)
		client.join_address("127.0.0.1", "731625", 24924)
	while client.phase != "room" and client.phase != "failed" and Time.get_ticks_msec() < deadline: await process_frame
	if not check(host.phase == "room" and client.phase == "room", "Join real session"): return
	host.local_squad = PackedStringArray(["suzuran", "shining", "blaze"])
	client.local_squad = host.local_squad.duplicate()
	host.local_skills = PackedInt32Array([1, 1, 1])
	client.local_skills = PackedInt32Array([2, 2, 2])
	host.set_ready(true)
	client.set_ready(true)
	while (not host.remote_ready or not client.remote_ready) and Time.get_ticks_msec() < deadline: await process_frame
	if not check(host.remote_skills == client.local_skills and client.remote_skills == host.local_skills, "Independent six-skill loadouts exchanged"): return
	host.start_match()
	while client.phase != "loading" and client.phase != "failed" and Time.get_ticks_msec() < deadline: await process_frame
	if not check(client.phase == "loading", "Loading barrier"): return
	host.mark_loaded()
	client.mark_loaded()
	while client.phase != "running" and client.phase != "failed" and Time.get_ticks_msec() < deadline: await process_frame
	if not check(client.phase == "running", "Running barrier"): return
	var data := {}
	for id in host.local_squad: data[id] = load("res://resources/operators/%s.tres" % id)
	var states: Array[MatchState] = []
	for _i in 3:
		var state := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [host.local_squad, client.local_squad], [host.local_skills, client.local_skills])
		state.ball.cell = Vector2i(10, 10)
		# Controlled starting fixture; only real player skill commands travel over the wire.
		for side in 2:
			for index in 3:
				var id: String = host.local_squad[index]
				var op: OperatorData = data[id]
				var cell: Vector2i = [Vector2i(12, 2), Vector2i(14, 4), Vector2i(13, 5)][index] if side == 0 else [Vector2i(8, 2), Vector2i(6, 4), Vector2i(7, 5)][index]
				state.units.append(UnitState.new(side * 3 + index, side, id, cell, 1000 if id == "blaze" else op.max_health, op.skills[1 if side == 0 else 2].initial_sp, roundi(op.attack_interval * 30), 2 if side == 0 else 0, 1 if side == 0 else 2))
		state.next_unit_id = 6
		states.append(state)
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	var queued := {}
	var frames := {}
	var hashes := [{}, {}]
	var checked := 0
	var observed := [false, false, false, false, false, false]
	var delay := RelaySession.RELAY_DELAY if online else NetSession.INPUT_DELAY
	deadline = Time.get_ticks_msec() + 140000
	while checked < 2400 and Time.get_ticks_msec() < deadline:
		var tick := states[0].tick
		if not queued.has(tick):
			queued[tick] = true
			if tick == 200: red.queue_skill(tick, 4, 2)
			if tick == 400: red.queue_skill(tick, 5, 2)
			if tick == 500:
				red.queue_skill(tick, 3, 1)
			if tick == 520: red.queue_skill(tick, 3, 2)
			if tick < 2400: host.seal_frame(tick, blue)
			var frame := host.take_frame(tick)
			if not frame.is_empty():
				frames[tick] = frame
				states[0].step(frame[0], frame[1])
				hashes[0][states[0].tick] = states[0].state_hash()
		if states[1].tick < 2400:
			client.seal_frame(states[1].tick, red)
			var frame := client.take_frame(states[1].tick)
			if not frame.is_empty():
				states[1].step(frame[0], frame[1])
				hashes[1][states[1].tick] = states[1].state_hash()
		# A frame may arrive after it was sealed; collect it again without re-sealing.
		if queued.has(states[0].tick) and states[0].tick < 2400:
			var frame := host.take_frame(states[0].tick)
			if not frame.is_empty():
				frames[states[0].tick] = frame
				states[0].step(frame[0], frame[1])
				hashes[0][states[0].tick] = states[0].state_hash()
		while hashes[0].has(checked + 1) and hashes[1].has(checked + 1):
			var frame: Array = frames[checked]
			states[2].step(frame[0], frame[1])
			checked += 1
			if not check(hashes[0][checked] == hashes[1][checked] and states[2].state_hash() == hashes[0][checked], "Wire/replay divergence at %d" % checked): return
			for index in 6:
				observed[index] = observed[index] or (not states[2].units[2].barrier_hp.is_empty() if index == 1 else states[2].units[index].skill_ticks_left != 0)
			if checked == 500 + delay + 1 and not check(states[2].units[3].skill_ticks_left == 0, "Wrong carried index rejected over wire"): return
			hashes[0].erase(checked)
			hashes[1].erase(checked)
			frames.erase(checked - 1)
		if not check(host.phase == "running" and client.phase == "running", "Transport stays running"): return
		if online: await physics_frame
		else: await process_frame
	if not check(checked == 2400 and false not in observed, "All six skills actually activated during 2400 continuous hashes"): return
	if not check(states[2].units[0].skill_ticks_left == -2 and states[2].units[2].skill_ticks_left == -2 and states[2].units[3].skill_ticks_left == 0 and states[2].units[4].skill_ticks_left == 0 and states[2].units[5].skill_ticks_left == 0, "Permanent S2 and expired S3 lifecycles"): return
	host.leave()
	client.close()
	host.queue_free()
	client.queue_free()
	print("Three operator network OK: %s, six actual skills, 2400 continuous hashes and replay" % ("loopback relay" if online else "LAN"))
	quit(0)


func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
