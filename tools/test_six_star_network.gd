extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for index in 3:
		if not await round_trip(index): return
	print("SIX_STAR_NETWORK_OK: all actual carried skills on both sides, actual deploy/activation,%d continuous wire/replay hashes"%720+"; controlled-SP short fixture")
	quit(0)


func round_trip(index: int) -> bool:
	var operator_id := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "thorns"
	var args := OS.get_cmdline_user_args()
	var online := args.size()>1 and args[1].begins_with("ws")
	var ticks := 240
	var port := 25010+index*2
	var host: NetSession = RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content()) if online else NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var client: NetSession = RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content()) if online else NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	root.add_child(host)
	root.add_child(client)
	if online:
		host.create_online(args[1])
	else:
		host.create_room(port, "642319", port + 1)
	var deadline := Time.get_ticks_msec() + 8000
	if online:
		while host.phase != "hosting" and host.phase != "failed" and Time.get_ticks_msec() < deadline:
			await process_frame
		if not check(host.phase == "hosting", "Relay create phase=%s status=%s" % [host.phase,host.status]): return false
		client.join_online(args[1], host.room_code)
	else:
		client.join_address("127.0.0.1", "642319", port)
	while (host.phase != "room" or client.phase != "room") and host.phase != "failed" and client.phase != "failed" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(host.phase == "room" and client.phase == "room", "Room join"): return false
	host.local_squad = PackedStringArray([operator_id])
	client.local_squad = host.local_squad.duplicate()
	host.local_skills = PackedInt32Array([index])
	client.local_skills = PackedInt32Array([(index+1)%3])
	host.set_ready(true)
	client.set_ready(true)
	while (not host.remote_ready or not client.remote_ready) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(host.remote_skills == client.local_skills and client.remote_skills == host.local_skills, "Selected skills exchanged independently before ready"): return false
	host.start_match()
	while (host.phase != "loading" or client.phase != "loading") and host.phase != "failed" and client.phase != "failed" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(host.phase == "loading" and client.phase == "loading", "Load barrier"): return false
	host.mark_loaded()
	client.mark_loaded()
	while (host.phase != "running" or client.phase != "running") and host.phase != "failed" and client.phase != "failed" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(host.phase == "running" and client.phase == "running", "Begin barrier"): return false
	var data := {operator_id: load("res://resources/operators/%s.tres" % operator_id)}
	data.bagpipe=load("res://resources/operators/bagpipe.tres")
	var ground: bool = data[operator_id].terrain_requirement != "high"
	var lane := 5 if ground else 2
	var blue_cell := Vector2i(11,5) if ground else Vector2i(13,2)
	var red_cell := Vector2i(9,5) if ground else Vector2i(7,2)
	if ground:blue_cell=Vector2i(13,5);red_cell=Vector2i(7,5)
	var squads: Array = [host.local_squad, host.remote_squad]
	var skills: Array = [host.local_skills, host.remote_skills]
	var first := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads, skills)
	var second := MatchState.new(client.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad], [client.remote_skills, client.local_skills])
	var replay := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads, skills)
	for state: MatchState in [first, second, replay]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		state.ball.cell = Vector2i(10, 5 if operator_id=="kaltsit" else lane)
		state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true)
		state._ball_data.kick_threshold=1000000000
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	var hashes := [{0: first.state_hash()}, {0: second.state_hash()}]
	var checked := 0
	var observed := [false,false]
	var summon_observed := [false,false]
	var queued := {}
	var schedule := {}
	var delay := RelaySession.RELAY_DELAY if online else NetSession.INPUT_DELAY
	deadline = Time.get_ticks_msec() + 170000
	while checked < ticks and Time.get_ticks_msec() < deadline:
		if not queued.has(first.tick):
			queued[first.tick] = true
			if first.tick == 0:
				blue.select_operator(operator_id)
				blue.queue_deploy(first.tick, blue_cell)
				red.select_operator(operator_id)
				red.queue_deploy(first.tick, red_cell)
			elif first.tick==8 and operator_id=="ines":
				if index==2:blue.select_operator(operator_id);blue.queue_deploy(first.tick,Vector2i(14,5))
				if (index+1)%3==2:red.select_operator(operator_id);red.queue_deploy(first.tick,Vector2i(6,5))
			elif first.tick==50 and operator_id in ["vigil","pozyomka","silence_alter"]:
				var summon := "vigil_wolf" if operator_id=="vigil" else ("pozyomka_typewriter" if operator_id=="pozyomka" else "silence_alter_drone")
				if operator_id!="silence_alter" or index==1:
					blue.select_operator(summon);blue.queue_deploy(first.tick,Vector2i(14,4) if operator_id=="pozyomka" else Vector2i(12,3))
				if operator_id!="silence_alter" or (index+1)%3==1:
					red.select_operator(summon);red.queue_deploy(first.tick,Vector2i(6,4) if operator_id=="pozyomka" else Vector2i(8,3))
			elif first.tick == 30:
				var a := actor(first,operator_id,0);var b := actor(first,operator_id,1)
				if a!=null:blue.queue_skill(first.tick,a.unit_id,index)
				if b!=null:red.queue_skill(first.tick,b.unit_id,(index+1)%3)
		if first.tick < ticks:
			host.seal_frame(first.tick, blue)
			var frame := host.take_frame(first.tick)
			if not frame.is_empty():
				schedule[first.tick] = frame
				prepare(first)
				first.step(frame[0], frame[1])
				hashes[0][first.tick] = first.state_hash()
		if second.tick < ticks:
			client.seal_frame(second.tick, red)
			var frame := client.take_frame(second.tick)
			if not frame.is_empty():
				prepare(second)
				second.step(frame[0], frame[1])
				hashes[1][second.tick] = second.state_hash()
		while hashes[0].has(checked + 1) and hashes[1].has(checked + 1):
			checked += 1
			var frame: Array = schedule[replay.tick]
			var a: Array[InputCommand] = []
			var b: Array[InputCommand] = []
			a.assign(frame[0])
			b.assign(frame[1])
			prepare(replay)
			replay.step(a, b)
			if not check(hashes[0][checked] == hashes[1][checked] and replay.state_hash() == hashes[0][checked], "First loadout divergence tick %d" % checked): return false
			if checked==delay+1:
				for side in 2:
					var carried := index if side==0 else (index+1)%3
					if operator_id=="ines" and carried==2:
						if not check(actor(replay,operator_id,side)==null and replay.sides[side].ines_first_shadow_used and replay.sides[side].cost==99,"Actual0cost first sentinel crossed input transport"):return false
					elif not check(actor(replay,operator_id,side)!=null and replay.sides[side].cost==99-data[operator_id].deploy_cost,"Actual deployment and exact paid cost on both sides"):return false
			for unit in replay.units:
				if unit.operator_id in ["vigil_wolf","pozyomka_typewriter","silence_alter_drone"]:summon_observed[unit.side]=true
				if unit.operator_id==operator_id:observed[unit.side]=observed[unit.side] or (unit.skill_activation_count>0)
			if checked==30+delay+1:
				for side in 2:
					var carried := index if side==0 else (index+1)%3
					var unit := actor(replay,operator_id,side)
					if not check(unit.skill_index==carried and (unit.skill_activation_count>0),"Actual deployment passive or manual carried skill%d"%carried):return false
			hashes[0].erase(checked)
			hashes[1].erase(checked)
		if not check(host.phase == "running" and client.phase == "running", "Transport remained valid: %s / %s"%[host.status,client.status]): return false
		if online:
			await create_timer(0.034).timeout
		else:
			await process_frame
	if not check(false not in observed and checked==ticks and first.units.size()>=2,"Actual carried skill activation on both peers"):return false
	if operator_id in ["vigil","pozyomka","silence_alter"]:
		for side in 2:
			var carried := index if side==0 else (index+1)%3
			if operator_id!="silence_alter" or carried==1:
				if not check(summon_observed[side],"Actual new summon deploy crossed transport side%d"%side):return false
	host.leave()
	client.close()
	host.queue_free()
	client.queue_free()
	await process_frame
	print("SIX_STAR_NETWORK_ROUND_OK: %s, host%d/client%d,%d continuous hashes"%["relay" if online else "LAN",index,(index+1)%3,ticks])
	return true


func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition


func prepare(state: MatchState) -> void:
	# Isolated identical fixture on both peers and replay; no state is sent over the network.
	if state.tick==18:
		for source: UnitState in state.units.duplicate():
			var step_x := -1 if source.side==0 else 1
			state.units.append(UnitState.new(state.next_unit_id,1-source.side,"bagpipe",source.cell+Vector2i(step_x,0),2000,0,100000));state.next_unit_id+=1
			state.units.append(UnitState.new(state.next_unit_id,source.side,"bagpipe",source.cell+Vector2i(0,1),200,0,100000));state.next_unit_id+=1
	if state.tick==12 or state.tick==28:
		for unit in state.units:
			var data: OperatorData=state._operator_data[unit.operator_id]
			if unit.operator_id=="bagpipe":unit.hp=200;unit.bind_ticks_left=300;continue
			unit.sp=SkillRules.sp_limit(data.skills[unit.skill_index])
			unit.attack_ticks_left=0


func actor(state: MatchState, id: String, side: int) -> UnitState:
	for unit in state.units:
		if unit.operator_id==id and unit.side==side and unit.hp>0:return unit
	return null
