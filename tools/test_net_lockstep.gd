extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := {}
	for id in root.get_node("OperatorDB").all_ids():
		definitions[id] = root.get_node("OperatorDB").get_data(id)
	var host := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var client := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(host)
	root.add_child(client)
	host.create_room(24779, "234567", 24780)
	client.join_address("127.0.0.1", "234567", 24779)
	var deadline := Time.get_ticks_msec() + 3000
	while client.phase != "room" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "room", "Lockstep connection failed"):
		return
	host.local_squad = PackedStringArray(["swire_alter", "nightingale"])
	host.local_skills = PackedInt32Array()
	host.local_skills.resize(host.local_squad.size())
	client.local_squad = PackedStringArray(["bagpipe"])
	client.local_skills = PackedInt32Array()
	client.local_skills.resize(client.local_squad.size())
	host.set_ready(true)
	client.set_ready(true)
	deadline = Time.get_ticks_msec() + 3000
	while (not host.remote_ready or not client.remote_ready) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(host.remote_ready and client.remote_ready, "Ready exchange timed out"):
		return
	host.start_match()
	while client.phase != "loading" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "loading", "Start exchange timed out"):
		return
	host.match_seed = 0x52494654
	client.match_seed = 0x52494654
	host.mark_loaded()
	client.mark_loaded()
	while client.phase != "running" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "running", "Loaded exchange timed out"):
		return
	if not _check(host.remote_squad == client.local_squad and client.remote_squad == host.local_squad, "Asymmetric squads must be exchanged before loading"):
		return
	var squads: Array = [host.local_squad, host.remote_squad]
	var first := MatchState.new(host.match_seed, definitions, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads)
	var second := MatchState.new(client.match_seed, definitions, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad])
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	var schedule := {}
	var pending_blue := false
	var pending_red := false
	var checked := 0
	var blue_hashes := {}
	var red_hashes := {}
	deadline = Time.get_ticks_msec() + 45000
	while (first.result == 0 or second.result == 0) and Time.get_ticks_msec() < deadline:
		if first.result == 0:
			var own: UnitState
			for unit in first.units:
				if unit.side == 0:
					own = unit
					break
			if not pending_blue and own != null:
				if own.cell.x - first.ball.cell.x > 1 and first.ball.move_ticks_left == 0:
					blue.queue_retreat(first.tick, own.unit_id)
					pending_blue = true
			elif not pending_blue and own == null and not first.sides[0].cooldowns.has("swire_alter") and first.sides[0].cost >= definitions["swire_alter"].deploy_cost:
				blue.select_operator("swire_alter")
				blue.queue_deploy(first.tick, Vector2i(11, 5) if first.ball.cell.x == 10 else first.ball.cell, 2)
				pending_blue = true
			if first.tick == 300 and not pending_red:
				red.select_operator("bagpipe")
				red.queue_deploy(second.tick, Vector2i(0, 3), 3)
				pending_red = true
			host.seal_frame(first.tick, blue)
			var frame := host.take_frame(first.tick)
			if not frame.is_empty():
				for command: InputCommand in frame[0]:
					pending_blue = false
				if not frame[0].is_empty() or not frame[1].is_empty():
					schedule[first.tick] = frame
				first.step(frame[0], frame[1])
				blue_hashes[first.tick] = first.state_hash()
		if second.result == 0:
			client.seal_frame(second.tick, red)
			var frame := client.take_frame(second.tick)
			if not frame.is_empty():
				second.step(frame[0], frame[1])
				red_hashes[second.tick] = second.state_hash()
		while blue_hashes.has(checked + 1) and red_hashes.has(checked + 1):
			checked += 1
			if not _check(blue_hashes[checked] == red_hashes[checked], "First network divergence at tick %d: %d / %d" % [checked, blue_hashes[checked], red_hashes[checked]]):
				return
			blue_hashes.erase(checked)
			red_hashes.erase(checked)
		if not _check(host.phase == "running" and client.phase == "running", "Transport failed: %s / %s" % [host.status, client.status]):
			return
		await process_frame
	if not _check(first.result == 1 and second.result == 1 and first.tick == second.tick and checked == first.tick and first.tick <= 9000, "Network match did not finish: ticks=%d/%d result=%d/%d checked=%d" % [first.tick, second.tick, first.result, second.result, checked]):
		return
	var replay := MatchState.new(host.match_seed, definitions, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads)
	while replay.tick < first.tick:
		var frame: Array = schedule.get(replay.tick, [[], []])
		var blue_commands: Array[InputCommand] = []
		var red_commands: Array[InputCommand] = []
		blue_commands.assign(frame[0])
		red_commands.assign(frame[1])
		replay.step(blue_commands, red_commands)
	if not _check(replay.state_hash() == first.state_hash(), "Recorded network input replay diverged"):
		return
	host.announce_finish(first.tick, first.result)
	deadline = Time.get_ticks_msec() + 1000
	while client.finish_tick == -1 and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.finish_tick == second.tick and client.announced_result == second.result, "Host result announcement mismatch"):
		return
	host.completed()
	client.completed()
	print("Network lockstep OK: tick=%d every-tick hashes and replay agree, result=%d, commands=%d" % [checked, first.result, schedule.size()])
	host.close()
	client.close()
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
