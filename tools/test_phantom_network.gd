extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var client := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(host)
	root.add_child(client)
	host.create_room(24960, "246810", 24961)
	client.join_address("127.0.0.1", "246810", 24960)
	var deadline := Time.get_ticks_msec() + 10000
	while client.phase != "room" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "room", "Cannot connect new-operator LAN fixture"):
		return
	host.local_squad = PackedStringArray(["phantom","bagpipe"])
	host.local_skills = PackedInt32Array()
	host.local_skills.resize(host.local_squad.size())
	client.local_squad = PackedStringArray(["bagpipe"])
	client.local_skills = PackedInt32Array()
	client.local_skills.resize(client.local_squad.size())
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
	var data := {"phantom": db.get_data("phantom"), "bagpipe": db.get_data("bagpipe")}
	var first := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [host.local_squad, host.remote_squad])
	var second := MatchState.new(client.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad])
	for state in [first, second]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		state.ball.cell = Vector2i(14,5)
	var cell := Vector2i(15,5)
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	blue.select_operator("phantom")
	blue.queue_deploy(0, cell, 2)
	red.select_operator("bagpipe")
	red.queue_deploy(0, Vector2i(13,5), 0)
	var hashes := [{0:first.state_hash()}, {0:second.state_hash()}]
	var checked := 0
	while (first.tick < 360 or second.tick < 360) and Time.get_ticks_msec() < deadline:
		for index in 2:
			var state: MatchState = [first,second][index]
			var peer: NetSession = [host,client][index]
			if state.tick == 8 and index == 0:
				blue.select_operator("phantom_clone")
				blue.queue_deploy(8, Vector2i(14,5), 2)
			if state.tick < 360:
				peer.seal_frame(state.tick, [blue,red][index])
				var frame := peer.take_frame(state.tick)
				if not frame.is_empty():
					state.step(frame[0],frame[1])
					hashes[index][state.tick] = state.state_hash()
		while hashes[0].has(checked+1) and hashes[1].has(checked+1):
			checked += 1
			if not _check(hashes[0][checked] == hashes[1][checked], "New operator network divergence at %d" % checked):
				return
		await process_frame
	if not _check(checked == 360 and first.units.size() == 3 and first.units[0].operator_id == "phantom" and first.units[2].operator_id == "phantom_clone" and first.units[2].last_attack_tick >= 0 and first.units[1].hp < 2484 and first.units[0].facing == 2 and first.units[2].facing == 2, "Both peers simulate actual body and clone facing deployment and combat"):
		return
	host.close()
	client.close()
	print("Phantom LAN OK: asymmetric squad, ready/load barrier, real encoded body/clone deployment/facing/combat and360 continuous matching hashes (focused fixture, not a full match)")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
