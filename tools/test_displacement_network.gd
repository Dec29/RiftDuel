extends SceneTree

const FIXTURE := preload("res://tools/displacement_fixture.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var client := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(host)
	root.add_child(client)
	host.create_room(24980, "246810", 24981)
	client.join_address("127.0.0.1", "246810", 24980)
	var deadline := Time.get_ticks_msec() + 10000
	while client.phase != "room" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "room", "Cannot connect new-operator LAN fixture"):
		return
	host.local_squad = PackedStringArray(["bagpipe"])
	host.local_skills = PackedInt32Array()
	host.local_skills.resize(host.local_squad.size())
	client.local_squad = PackedStringArray(["bagpipe", "phantom"])
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
	var data := FIXTURE.definitions("push")
	var first := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [host.local_squad, host.remote_squad])
	var second := MatchState.new(client.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad])
	var replay := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [host.local_squad, host.remote_squad])
	for state in [first, second, replay]:
		state.ball.cell = Vector2i(12, 5)
		state.sides[0].cost = 99
		state.sides[1].cost = 99
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	blue.select_operator("bagpipe")
	blue.queue_deploy(0, Vector2i(14, 5), 2)
	red.select_operator("bagpipe")
	red.queue_deploy(0, Vector2i(12, 5), 0)
	red.select_operator("phantom")
	red.queue_deploy(0, Vector2i(11, 5), 0)
	var hashes := [{0:first.state_hash()}, {0:second.state_hash()}]
	var checked := 0
	var observed := false
	while (first.tick < 360 or second.tick < 360) and Time.get_ticks_msec() < deadline:
		for index in 2:
			var state: MatchState = [first,second][index]
			var peer: NetSession = [host,client][index]
			if state.tick < 360:
				peer.seal_frame(state.tick, [blue,red][index])
				var frame := peer.take_frame(state.tick)
				if not frame.is_empty():
					state.step(frame[0],frame[1])
					if index == 0:
						replay.step(frame[0], frame[1])
						if not _check(replay.state_hash() == state.state_hash(), "Third replay diverges at %d" % state.tick): return
					for unit in state.units:
						if unit.side == 1 and unit.displacement_ticks_left > 0 and unit.cell.x < 10: observed = true
					hashes[index][state.tick] = state.state_hash()
		while hashes[0].has(checked+1) and hashes[1].has(checked+1):
			checked += 1
			if not _check(hashes[0][checked] == hashes[1][checked], "New operator network divergence at %d" % checked):
				return
		await process_frame
	if not _check(checked == 360 and observed and first.units.size() == 3, "Both peers simulate actual encoded deployment and chain shift across the line"):
		return
	host.close()
	client.close()
	print("Displacement LAN OK: real deploy/facing/attack, chain across line and360 continuous matching hashes; focused fixture, not a full cross-device match")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
