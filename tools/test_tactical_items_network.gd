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
	var deadline := Time.get_ticks_msec() + 15000
	if online:
		(host as RelaySession).create_online(args[0])
		while host.phase != "hosting" and Time.get_ticks_msec() < deadline:
			await process_frame
		if not _check(host.phase == "hosting", "Tactical local relay create"): return
		(client as RelaySession).join_online(args[0], host.room_code)
	else:
		host.create_room(24964, "135791", 24965)
		client.join_address("127.0.0.1", "135791", 24964)
	while client.phase != "room" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "room", "Tactical LAN handshake"): return
	host.local_squad = PackedStringArray(["blaze", "nightingale"])
	host.local_skills = PackedInt32Array()
	host.local_skills.resize(host.local_squad.size())
	client.local_squad = PackedStringArray(["hoshiguma"])
	client.local_skills = PackedInt32Array()
	client.local_skills.resize(client.local_squad.size())
	host.set_ready(true)
	client.set_ready(true)
	while (not host.remote_ready or not client.remote_ready) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(host.remote_ready and client.remote_ready, "Tactical LAN ready boundary"): return
	host.start_match()
	while client.phase != "loading" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "loading", "Tactical LAN load"): return
	host.mark_loaded()
	client.mark_loaded()
	while client.phase != "running" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "running", "Tactical LAN loaded barrier"): return
	if online:
		deadline = Time.get_ticks_msec() + 30000
	var data := {}
	for id in ["blaze", "nightingale", "hoshiguma"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var first := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [host.local_squad, host.remote_squad])
	var second := MatchState.new(client.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad])
	for state: MatchState in [first, second]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		state.sides[0].tactical_items = [1, 1, 1, 0]
		state.sides[1].tactical_items = [0, 0, 1, 0]
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	var hashes := [{0: first.state_hash()}, {0: second.state_hash()}]
	var checked := 0
	var queued := {}
	var used_kinds: Array[int] = []
	var saw_windup := [false, false]
	var saw_blast := [false, false]
	while (first.tick < 560 or second.tick < 560) and Time.get_ticks_msec() < deadline:
		if not _check(host.phase == "running" and client.phase == "running", "Tactical peers stopped: host=%s/%s client=%s/%s" % [host.phase, host.status, client.phase, client.status]): return
		for index in 2:
			var state: MatchState = [first, second][index]
			var peer: NetSession = [host, client][index]
			var input: LocalInput = [blue, red][index]
			var key := Vector2i(index, state.tick)
			if not queued.has(key):
				queued[key] = true
				if state.tick == 0:
					input.select_operator("blaze" if index == 0 else "hoshiguma")
					input.queue_deploy(state.tick, Vector2i(11 if index == 0 else 9, 5))
				if index == 0:
					if state.tick == 10: input.queue_item(state.tick, 0, Vector2i(12, 5), 2)
					if state.tick == 11: input.queue_item(state.tick, 1, Vector2i(12, 5))
					if state.tick == 12:
						input.select_operator("nightingale")
						input.queue_deploy(state.tick, Vector2i(12, 5))
					if state.tick == 13: input.queue_item(state.tick, 2, Vector2i(8, 5))
					if state.tick == 160:
						input.select_operator("blaze")
						input.queue_deploy(state.tick, Vector2i(11, 5))
				elif state.tick == 180:
					input.queue_item(state.tick, 2, Vector2i(12, 4))
			if state.tick < 560:
				peer.seal_frame(state.tick, input)
				var frame := peer.take_frame(state.tick)
				if not frame.is_empty():
					for batch: Array in frame:
						for command: InputCommand in batch:
							if index == 1 and command.kind == InputCommand.Kind.USE_ITEM:
								used_kinds.append(command.item_kind)
					state.step(frame[0], frame[1])
					for effect in state.tactical_item_effects:
						if effect.item_kind == Config.TACTICAL_ITEM_STUN:
							if effect.activated: saw_blast[index] = true
							else: saw_windup[index] = true
					hashes[index][state.tick] = state.state_hash()
		while hashes[0].has(checked + 1) and hashes[1].has(checked + 1):
			checked += 1
			if not _check(hashes[0][checked] == hashes[1][checked], "Tactical LAN divergence tick%d" % checked): return
		if online:
			await create_timer(1.0 / Config.TICK_RATE).timeout
		else:
			await process_frame
	if not _check(checked == 560 and used_kinds == [0, 1, 2, 2] and first.platform_cells == [Vector2i(12, 5)] and first.sides[0].tactical_items == [0, 0, 0, 0] and first.sides[1].tactical_items == [0, 0, 0, 0], "Tactical network expected560 ticks/kinds[0,1,2,2]/platform[(12,5)]/empty inventories; actual ticks=%d kinds=%s platforms=%s blue=%s red=%s" % [checked, used_kinds, first.platform_cells, first.sides[0].tactical_items, first.sides[1].tactical_items]): return
	if not _check(saw_windup == [true, true] and saw_blast == [true, true], "Both peers actually observe pending bombs and detonation, beyond matching hashes"): return
	host.close()
	client.close()
	print("Tactical %s OK: real codec9, asymmetric squads, crate-independent item fixture, crane/platform/windup/blast/side2 and560 continuous hashes; focused fixture, not full cross-device acceptance" % ("relay" if online else "LAN"))
	quit(0)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
