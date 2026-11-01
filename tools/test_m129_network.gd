extends SceneTree
var current_id := ""
var skill_count := 3
var copy_seen := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var checked_operators := 0
	var checked_skills := 0
	for id in ["wildmane", "gavial_alter", "eunectes", "chen_alter", "goldenglow", "mon3tr_operator", "stainless", "gladiia", "muelsyse", "mlynar", "jessica_alter", "fiammetta", "dusk", "titi", "ling", "shaw"]:
		if not OS.get_cmdline_user_args().is_empty():
			var selected := OS.get_cmdline_user_args()[0]
			if selected=="tail":
				if id not in ["mlynar","jessica_alter","fiammetta","dusk","titi","ling","shaw"]:continue
			elif id!=selected:continue
		current_id=id;skill_count=(load("res://resources/operators/"+id+".tres") as OperatorData).skills.size()
		checked_operators+=1;checked_skills+=skill_count
		for index in skill_count:
			if not await round_trip(index):return
	print("M129_NETWORK_OK: operators=",checked_operators," carried-skill wire cases=",checked_skills,"; actual deploy/control,64tick triple replay, not full matches")
	quit(0)


func round_trip(index: int) -> bool:
	var operator_id := current_id
	var args := OS.get_cmdline_user_args()
	var online := args.size()>1 and args[1].begins_with("ws")
	var ticks := 64
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
		if not check(host.phase == "hosting", "Relay create phase=%s" % host.phase): return false
		client.join_online(args[1], host.room_code)
	else:
		client.join_address("127.0.0.1", "642319", port)
	while client.phase != "room" and client.phase != "failed" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(host.phase == "room" and client.phase == "room", "Room join"): return false
	host.local_squad = PackedStringArray([operator_id,"exusiai"])
	client.local_squad = PackedStringArray([operator_id,"exusiai"])
	host.local_skills = PackedInt32Array([index,0])
	client.local_skills = PackedInt32Array([(index+1)%skill_count,0])
	host.set_ready(true)
	client.set_ready(true)
	while (not host.remote_ready or not client.remote_ready) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(host.remote_skills == client.local_skills and client.remote_skills == host.local_skills, "Selected skills exchanged independently before ready"): return false
	host.start_match()
	while (host.phase != "loading" or client.phase != "loading") and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(host.phase == "loading" and client.phase == "loading", "Both peers load barrier"): return false
	host.mark_loaded()
	client.mark_loaded()
	while (host.phase != "running" or client.phase != "running") and Time.get_ticks_msec() < deadline:
		await process_frame
	if not check(host.phase == "running" and client.phase == "running", "Both peers begin barrier"): return false
	var data := {operator_id: load("res://resources/operators/%s.tres" % operator_id),"exusiai":load("res://resources/operators/exusiai.tres")}
	var ground: bool = data[operator_id].terrain_requirement != "high"
	var lane := 5 if ground else 2
	var blue_cell := Vector2i(11,5) if ground else Vector2i(13,2)
	var red_cell := Vector2i(9,5) if ground else Vector2i(7,2)
	var squads: Array = [host.local_squad, host.remote_squad]
	var skills: Array = [host.local_skills, host.remote_skills]
	var first := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads, skills)
	var second := MatchState.new(client.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [client.remote_squad, client.local_squad], [client.remote_skills, client.local_skills])
	var replay := MatchState.new(host.match_seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads, skills)
	for state: MatchState in [first, second, replay]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		state.ball.cell = Vector2i(10, lane)
		state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true)
		state._ball_data.kick_threshold=1000000000
	var blue := LocalInput.new(0)
	var red := LocalInput.new(1)
	var hashes := [{0: first.state_hash()}, {0: second.state_hash()}]
	var checked := 0
	var observed := [false,false]
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
			elif first.tick == 120 and operator_id == "weedy":
				blue.select_operator("weedy_cannon")
				blue.queue_deploy(first.tick, owned_cannon_cell(first,0))
				red.select_operator("weedy_cannon")
				red.queue_deploy(first.tick, owned_cannon_cell(first,1))
			elif first.tick == 120 and operator_id == "magallan":
				for side in 2:
					var unit := first.units[side]
					var id: String=MatchState.DRONE_IDS[unit.skill_index]
					var input := blue if side==0 else red
					input.select_operator(id)
					input.queue_deploy(first.tick,(Vector2i(13,3) if side==0 else Vector2i(7,3)) if unit.skill_index==1 else (Vector2i(12,2) if side==0 else Vector2i(8,2)))
			elif operator_id=="muelsyse" and first.tick==8:
				blue.select_operator("flowing_shape");blue.queue_deploy(first.tick,flow_cell(first,0))
				red.select_operator("flowing_shape");red.queue_deploy(first.tick,flow_cell(first,1))
			elif operator_id=="muelsyse" and first.tick==16:
				blue.queue_skill(first.tick,2,0);red.queue_skill(first.tick,3,0)
			elif operator_id=="muelsyse" and first.tick==24:
				blue.queue_copy(first.tick,2,"exusiai",0);red.queue_copy(first.tick,3,"exusiai",0)
			elif first.tick == 30:
				blue.queue_skill(first.tick, 0, index)
				red.queue_skill(first.tick, 1, (index+1)%skill_count)
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
			if replay.units.size()==2:
				for side in 2:observed[side]=observed[side] or replay.units[side].skill_activation_count>0

			hashes[0].erase(checked)
			hashes[1].erase(checked)
		if not check(host.phase == "running" and client.phase == "running", "Transport remained valid: %s / %s"%[host.status,client.status]): return false
		if online:
			await create_timer(0.034).timeout
		else:
			await process_frame
	if not check(checked==ticks and first.units.size()>=2,"Actual deployments and continuous hashes"):return false
	if operator_id=="muelsyse":
		var copied := 0
		for unit in first.units:
			if unit.operator_id=="flowing_shape" and not unit.flow_is_split and unit.flow_copy_id=="exusiai":copied+=1
		if not check(copied==2,"Actual COPY accepted after real flow deploy/open window on both peers"):return false

	host.leave()
	client.close()
	host.queue_free()
	client.queue_free()
	await process_frame
	print("OPERATOR_NETWORK_ROUND_OK: %s, host%d/client%d,%d continuous hashes"%["relay" if online else "LAN",index,(index+1)%skill_count,ticks])
	return true


func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition


func prepare(state: MatchState) -> void:
	# Isolated identical fixture on both peers and replay; no state is sent over the network.
	if state.tick in [12,20]:
		for unit in state.units:
			var data: OperatorData=state._operator_data[unit.operator_id]
			if unit.operator_id=="saria":unit.hp=1000
			unit.sp=SkillRules.sp_limit(data.skills[unit.skill_index])
			unit.attack_ticks_left=0


func owned_cannon_cell(state: MatchState, side: int) -> Vector2i:
	for unit in state.units:
		if unit.side != side or unit.operator_id != "weedy":continue
		for offset in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var cell: Vector2i=unit.cell+offset
			if state.can_deploy(side,"weedy_cannon",cell):return cell
	push_error("Owned cannon fixture has no legal cell")
	return Vector2i(-1,-1)

func flow_cell(state: MatchState,side: int)->Vector2i:
	for y in state.CONFIG.GRID_ROWS:
		for x in state.CONFIG.GRID_COLUMNS:
			if state.can_deploy(side,"flowing_shape",Vector2i(x,y)):return Vector2i(x,y)
	push_error("No legal flow cell");return Vector2i(-1,-1)
