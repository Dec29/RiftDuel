extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run(operator_id: String = "nightingale") -> void:
	var args := OS.get_cmdline_user_args()
	var online := not args.is_empty() and args[0].begins_with("ws")
	var ticks := 2500
	var port := 24966
	var host: NetSession = RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content()) if online else NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var client: NetSession = RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content()) if online else NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(host)
	root.add_child(client)
	if online:
		host.create_online(args[0])
	else:
		host.create_room(port, "642319", port + 1)
	var deadline := Time.get_ticks_msec() + 8000
	if online:
		while host.phase != "hosting" and host.phase != "failed" and Time.get_ticks_msec() < deadline:
			await process_frame
		if not check(host.phase == "hosting", "Relay create phase=%s" % host.phase): return
		client.join_online(args[0], host.room_code)
	else:
		client.join_address("127.0.0.1", "642319", port)
	while client.phase != "room" and client.phase != "failed" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(host.phase == "room" and client.phase == "room", "Room join"): return
	host.local_squad = PackedStringArray([operator_id])
	client.local_squad = PackedStringArray([operator_id])
	host.local_skills = PackedInt32Array([1])
	client.local_skills = PackedInt32Array([2])
	host.set_ready(true)
	client.set_ready(true)
	while (not host.remote_ready or not client.remote_ready) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(host.remote_skills == client.local_skills and client.remote_skills == host.local_skills, "Selected skills exchanged independently before ready"): return
	host.start_match()
	while client.phase != "loading" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(client.phase == "loading", "Load barrier"): return
	host.mark_loaded()
	client.mark_loaded()
	while client.phase != "running" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(client.phase == "running", "Begin barrier"): return
	var data := {operator_id: load("res://resources/operators/%s.tres" % operator_id), "bagpipe": load("res://resources/operators/bagpipe.tres")}
	var squads: Array = [host.local_squad, host.remote_squad]
	var skills: Array = [host.local_skills, host.remote_skills]
	var first := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads, skills)
	var second := MatchState.new(client.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad], [client.remote_skills, client.local_skills])
	var replay := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads, skills)
	for state: MatchState in [first, second, replay]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		state.ball.cell = Vector2i(10, 10)
		state.units = [UnitState.new(0,0,"bagpipe",Vector2i(13,2),500,0,10000), UnitState.new(1,1,"bagpipe",Vector2i(9,8),500,0,10000)]
		state.next_unit_id = 2
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	var hashes := [{0: first.state_hash()}, {0: second.state_hash()}]
	var checked := 0
	var observed_s2 := false
	var queued := {}
	var schedule := {}
	var delay := RelaySession.RELAY_DELAY if online else NetSession.INPUT_DELAY
	deadline = Time.get_ticks_msec() + 90000
	while checked < ticks and Time.get_ticks_msec() < deadline:
		if not queued.has(first.tick):
			queued[first.tick] = true
			if first.tick == 0:
				blue.select_operator(operator_id)
				blue.queue_deploy(first.tick, Vector2i(12, 2))
				red.select_operator(operator_id)
				red.queue_deploy(first.tick, Vector2i(8, 8))
			elif first.tick == 310:
				blue.queue_skill(first.tick, 2, 0)
			elif first.tick == 630:
				red.queue_skill(first.tick, 3, 2)
		if first.tick < ticks:
			host.seal_frame(first.tick, blue)
			var frame := host.take_frame(first.tick)
			if not frame.is_empty():
				schedule[first.tick] = frame
				first.step(frame[0], frame[1])
				hashes[0][first.tick] = first.state_hash()
		if second.tick < ticks:
			client.seal_frame(second.tick, red)
			var frame := client.take_frame(second.tick)
			if not frame.is_empty():
				second.step(frame[0], frame[1])
				hashes[1][second.tick] = second.state_hash()
		while hashes[0].has(checked + 1) and hashes[1].has(checked + 1):
			checked += 1
			var frame: Array = schedule[replay.tick]
			var a: Array[InputCommand] = []
			var b: Array[InputCommand] = []
			a.assign(frame[0])
			b.assign(frame[1])
			replay.step(a, b)
			if not check(hashes[0][checked] == hashes[1][checked] and replay.state_hash() == hashes[0][checked], "First loadout divergence tick %d" % checked): return
			if replay.units.size() == 4 and not replay.units[0].barrier_hp.is_empty():
				observed_s2 = true
			if checked == delay + 1:
				if not check(replay.units.size() == 4, "Both actual carried-skill deployments must succeed"): return
			if checked == 310 + delay + 1:
				if not check(replay.units[2].skill_ticks_left == 0 and replay.units[2].sp <= 24, "S2 stored charges after real healing; wrong index ignored"): return
			if checked == 630 + delay + 1:
				if not check(replay.units[3].skill_ticks_left == 1799 and replay.units[3].sp == 0 and SkillRules.block_count_value(replay.units[3], data[operator_id]) == 1, "Actual S3 manual release and sanctuary aura"): return
			hashes[0].erase(checked)
			hashes[1].erase(checked)
		if not check(host.phase == "running" and client.phase == "running", "Transport remained valid"): return
		if online:
			await physics_frame
		else:
			await process_frame
	if not check(observed_s2 and checked == ticks and first.units[2].skill_ticks_left == 0 and first.units[2].sp <= 24 and first.units[3].skill_ticks_left == 0, "Continuous tick hashes/replay and both expirations"): return
	host.leave()
	client.close()
	host.queue_free()
	client.queue_free()
	print("Skill loadout network OK: %s %s, activation/expiry and %d continuous hash/replay checks" % [operator_id, "relay" if online else "LAN", ticks])
	quit(0)


func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

