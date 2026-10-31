extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var client := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(host)
	root.add_child(client)
	host.create_room(24934, "246810", 24935)
	client.join_address("127.0.0.1", "246810", 24934)
	var deadline := Time.get_ticks_msec() + 8000
	while client.phase != "room" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "room", "Cannot connect new-operator LAN fixture"):
		return
	host.local_squad = PackedStringArray(["eyjafjalla"])
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
	var data := {"eyjafjalla": db.get_data("eyjafjalla"), "bagpipe": db.get_data("bagpipe")}
	var first := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [host.local_squad, host.remote_squad])
	var second := MatchState.new(client.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad])
	for state in [first, second]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
	var cell := Vector2i(-1,-1)
	for x in range(10,21):
		for y in 11:
			if MatchState.DEFAULT_ARENA.terrain_at(Vector2i(x,y)) == "high":
				cell = Vector2i(x,y)
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	blue.select_operator("eyjafjalla")
	blue.queue_deploy(0, cell, 2)
	red.select_operator("bagpipe")
	red.queue_deploy(0, Vector2i(5,5), 0)
	var hashes := [{0:first.state_hash()}, {0:second.state_hash()}]
	var checked := 0
	var skill_queued := false
	while (first.tick < 120 or second.tick < 120) and Time.get_ticks_msec() < deadline:
		if first.tick == 100 and not skill_queued:
			blue.queue_skill(100,0)
			skill_queued = true
		for index in 2:
			var state: MatchState = [first,second][index]
			var peer: NetSession = [host,client][index]
			if state.tick < 120:
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
	if not _check(checked == 120 and first.units.size() == 2 and first.units[0].operator_id == "eyjafjalla" and first.units[0].attack_bonus_percent == 14 and first.units[0].skill_repeat_activation_count == 1 and first.units[0].skill_ticks_left > 0, "Both peers must simulate Eyjafjalla deployment, random SP and manual first S1"):
		return
	host.close()
	client.close()
	print("Eyjafjalla LAN OK: asymmetric squad, ready/load barrier, real encoded deployment/manual skill and 120 continuous matching hashes (focused fixture, not a full match)")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
