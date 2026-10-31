extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var client := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(host)
	root.add_child(client)
	host.create_room(25020, "246810", 25021)
	client.join_address("127.0.0.1", "246810", 25020)
	var deadline := Time.get_ticks_msec() + 120000
	while client.phase != "room" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "room", "Cannot connect new-operator LAN fixture"):
		return
	host.local_squad = PackedStringArray(["ceobe"])
	host.local_skills = PackedInt32Array()
	host.local_skills = PackedInt32Array([1])
	client.local_squad = PackedStringArray(["ceobe"])
	client.local_skills = PackedInt32Array()
	client.local_skills = PackedInt32Array([2])
	host.set_ready(true)
	client.set_ready(true)
	while (not host.remote_ready or not client.remote_ready) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(host.remote_ready and client.remote_ready, "New operator squad must pass the ready boundary"):
		return
	host.start_match()
	while client.phase != "loading" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "loading", "New operator fixture load timed out"):
		return
	host.mark_loaded()
	client.mark_loaded()
	while client.phase != "running" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "running", "New operator loaded barrier timed out"):
		return
	var db := root.get_node("OperatorDB")
	var target := db.get_data("bagpipe").duplicate(true) as OperatorData
	target.max_health = 100000
	var data := {"ceobe": db.get_data("ceobe"), "bagpipe": target}
	var ball_data := MatchState.DEFAULT_BALL_DATA.duplicate(true) as BallData
	ball_data.kick_threshold = 100000
	var first := MatchState.new(host.match_seed, data, ball_data, MatchState.DEFAULT_ARENA, [host.local_squad, host.remote_squad], [host.local_skills, host.remote_skills])
	var second := MatchState.new(client.match_seed, data, ball_data, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad], [client.remote_skills, client.local_skills])
	for state in [first, second]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		# Durable, nonattacking target isolates silence throughout the S3 duration.
		state.units.append(UnitState.new(0,0,"bagpipe",Vector2i(11,2),100000,0,100000))
		state.next_unit_id = 1
		state.ball.cell = Vector2i(10,10)
	var cell := Vector2i(12,2)
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	blue.select_operator("ceobe")
	blue.queue_deploy(0, cell, 2)
	red.select_operator("ceobe")
	red.queue_deploy(0, Vector2i(8,2), 0)
	var hashes := [{0:first.state_hash()}, {0:second.state_hash()}]
	var checked := 0
	var queued := [false, false, false]
	var observed := false
	while (first.tick < 3000 or second.tick < 3000) and Time.get_ticks_msec() < deadline:
		for index in 2:
			var state: MatchState = [first,second][index]
			var peer: NetSession = [host,client][index]
			if state.tick < 3000:
				if index == 0 and state.tick == 600 and not queued[0]:
					blue.queue_skill(state.tick, 1, 1)
					queued[0] = true
				if index == 1 and state.tick == 800 and not queued[1]:
					red.queue_skill(state.tick, 2, 2)
					queued[1] = true
				if index == 0 and state.tick == 900 and not queued[2]:
					blue.queue_skill(state.tick, 1, 1)
					queued[2] = true
				peer.seal_frame(state.tick, [blue,red][index])
				var frame := peer.take_frame(state.tick)
				if not frame.is_empty():
					state.step(frame[0],frame[1])
					if state.units.size() == 3 and state.units[1].skill_ticks_left > 0 and state.units[2].skill_ticks_left > 0 and state.units[0].silence_ticks_left > 0: observed = true
					hashes[index][state.tick] = state.state_hash()
		while hashes[0].has(checked+1) and hashes[1].has(checked+1):
			checked += 1
			if not _check(hashes[0][checked] == hashes[1][checked], "New operator network divergence at %d" % checked):
				return
		await process_frame
	if not _check(checked == 3000 and first.units.size() == 3 and first.units[1].operator_id == "ceobe" and observed and first.units[1].skill_ticks_left == 0 and first.units[2].skill_ticks_left == 0 and first.units[0].silence_ticks_left == 0 and first.units[1].facing == 2, "Both peers must simulate actual S2/S3 activation and expiry"):
		return
	host.close()
	client.close()
	print("Ceobe S2/S3 LAN OK: asymmetric squad, ready/load barrier, real encoded high deployment/facing/time charge, S3 silence on durable fixture target, expiry and3000 continuous matching hashes (focused fixture, not a full match)")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
