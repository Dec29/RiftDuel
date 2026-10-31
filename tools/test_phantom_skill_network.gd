extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var client := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(host)
	root.add_child(client)
	host.create_room(25010, "246810", 25011)
	client.join_address("127.0.0.1", "246810", 25010)
	var deadline := Time.get_ticks_msec() + 60000
	while client.phase != "room" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "room", "Cannot connect new-operator LAN fixture"):
		return
	host.local_squad = PackedStringArray(["phantom"])
	host.local_skills = PackedInt32Array()
	host.local_skills = PackedInt32Array([1])
	client.local_squad = PackedStringArray(["phantom"])
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
	var data := {"phantom": db.get_data("phantom")}
	var ball_data := MatchState.DEFAULT_BALL_DATA.duplicate(true) as BallData
	ball_data.kick_threshold = 100000
	var first := MatchState.new(host.match_seed, data, ball_data, MatchState.DEFAULT_ARENA, [host.local_squad, host.remote_squad], [host.local_skills, host.remote_skills])
	var second := MatchState.new(client.match_seed, data, ball_data, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad], [client.remote_skills, client.local_skills])
	for state in [first, second]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
	var cell := Vector2i(11,5)
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	blue.select_operator("phantom")
	blue.queue_deploy(0, cell, 2)
	red.select_operator("phantom")
	red.queue_deploy(0, Vector2i(9,5), 0)
	var hashes := [{0:first.state_hash()}, {0:second.state_hash()}]
	var checked := 0
	var queued := [false, false, false]
	var observed := false
	while (first.tick < 600 or second.tick < 600) and Time.get_ticks_msec() < deadline:
		for index in 2:
			var state: MatchState = [first,second][index]
			var peer: NetSession = [host,client][index]
			if state.tick < 600:
				if index == 0 and state.tick == 200 and not queued[0]:
					blue.select_operator("phantom_clone")
					blue.queue_deploy(state.tick, Vector2i(12,5), 2)
					queued[0] = true
				if index == 1 and state.tick == 200 and not queued[1]:
					red.select_operator("phantom_clone")
					red.queue_deploy(state.tick, Vector2i(8,5), 0)
					queued[1] = true
				peer.seal_frame(state.tick, [blue,red][index])
				var frame := peer.take_frame(state.tick)
				if not frame.is_empty():
					state.step(frame[0],frame[1])
					if state.units.size() == 4 and state.units[0].attack_boost_stacks < 10 and state.units[1].deploy_control_kind >= 0 and state.units[2].skill_index == 1 and state.units[3].skill_index == 2: observed = true
					hashes[index][state.tick] = state.state_hash()
		while hashes[0].has(checked+1) and hashes[1].has(checked+1):
			checked += 1
			if not _check(hashes[0][checked] == hashes[1][checked], "New operator network divergence at %d" % checked):
				return
		await process_frame
	if not _check(checked == 600 and first.units.size() == 4 and first.units[0].operator_id == "phantom" and observed and first.units[0].skill_ticks_left == 0 and first.units[1].skill_ticks_left == 0 and first.units[0].facing == 2, "Both peers must deploy carried passive skills and independent clones"):
		return
	host.close()
	client.close()
	print("Phantom S2/S3 LAN OK: asymmetric squad, ready/load barrier, real encoded ground deployment/facing/passive skills and independent clones and600 continuous matching hashes (focused fixture, not a full match)")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
