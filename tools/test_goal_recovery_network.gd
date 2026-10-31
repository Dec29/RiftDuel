extends SceneTree

class DelayedSession extends NetSession:
	var outgoing: Array[Dictionary] = []
	func _send(message: Dictionary) -> void:
		outgoing.append({"at":Time.get_ticks_msec()+120,"message":message})
	func _process(delta: float) -> void:
		while not outgoing.is_empty() and outgoing[0].at <= Time.get_ticks_msec():
			var pending: Dictionary = outgoing.pop_front()
			if peer != null: super._send(pending.message)
		super._process(delta)

var peers: Array[NetSession] = []
var deadline := 0
var poll_delay := 0.003

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value

func poll() -> bool:
	await create_timer(poll_delay).timeout
	for peer in peers:
		if not check(peer.phase != "failed", "session failed: " + peer.status): return false
	return check(Time.get_ticks_msec() < deadline, "network deadline")

func run() -> void:
	deadline = Time.get_ticks_msec()+120000
	var args := OS.get_cmdline_user_args()
	var endpoint := args[0] if not args.is_empty() else ""
	if not endpoint.is_empty(): poll_delay = 0.027
	var content: Dictionary = root.get_node("OperatorDB").network_content()
	for side in 2:
		var peer: NetSession = DelayedSession.new(content) if endpoint.is_empty() else RelaySession.new(content)
		root.add_child(peer)
		peers.append(peer)
	if endpoint.is_empty():
		peers[0].create_room(24971,"231948",24972)
		peers[1].join_address("127.0.0.1","231948",24971)
	else:
		peers[0].create_online(endpoint)
		while peers[0].phase != "hosting":
			if not await poll(): return
		peers[1].join_online(endpoint,peers[0].room_code)
	while peers[0].phase != "room" or peers[1].phase != "room":
		if not await poll(): return
	var ids := PackedStringArray(["bagpipe","blaze"])
	for peer in peers:
		peer.local_squad = ids.duplicate()
		peer.local_skills = PackedInt32Array([0,0])
		peer.set_ready(true)
	while not peers[0].remote_ready or not peers[1].remote_ready:
		if not await poll(): return
	peers[0].start_match()
	for peer in peers:
		while peer.phase != "loading":
			if not await poll(): return
		peer.mark_loaded()
	while peers[0].phase != "running" or peers[1].phase != "running":
		if not await poll(): return
	var data := {"bagpipe":load("res://resources/operators/bagpipe.tres"),"blaze":load("res://resources/operators/blaze.tres")}
	var states: Array[MatchState] = []
	var inputs: Array[LocalInput] = [LocalInput.new(0),LocalInput.new(1)]
	var hashes: Array[Dictionary] = [{},{}]
	var frozen: Array[int] = [0,0]
	for peer in peers:
		var state := MatchState.new(peer.match_seed,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[PackedInt32Array([0,0]),PackedInt32Array([0,0])],peer.match_rules)
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		state.sides[0].tactical_items[3] = 1
		states.append(state)
	for side in 2:
		inputs[side].select_operator("bagpipe")
		inputs[side].queue_deploy(0,Vector2i(18 if side == 0 else 2,9))
	var queued := PackedInt32Array([-1,-1])
	while states[0].input_tick < 650 or states[1].input_tick < 650:
		for side in 2:
			var state := states[side]
			var frame_tick := state.input_tick
			if frame_tick >= 650: continue
			if queued[side] != frame_tick:
				queued[side] = frame_tick
				if side == 1 and frame_tick == 45:
					inputs[side].select_operator("blaze")
					inputs[side].queue_deploy(frame_tick,Vector2i(16,9),0,true)
				if side == 0 and frame_tick == 115: inputs[side].queue_skip_recovery(frame_tick)
				if side == 0 and frame_tick == 560: inputs[side].queue_item(frame_tick,3,Vector2i(13,5))
			peers[side].seal_frame(frame_tick,inputs[side])
			var frame := peers[side].take_frame(frame_tick)
			if frame.is_empty(): continue
			if frame_tick in [30,100,150]: state.ball.cell.x = 0 if frame_tick == 30 else 20
			if frame_tick == 500:
				var token := UnitState.new(90,1,"nightingale_phantom",Vector2i(13,4),1000,0,10000)
				state.units.append(token)
			var old_tick := state.tick
			state.step(frame[0],frame[1])
			if state.tick == old_tick: frozen[side] += 1
			hashes[side][state.input_tick] = state.state_hash()
		if not await poll(): return
	for frame_tick in range(1,651):
		if not check(hashes[0][frame_tick] == hashes[1][frame_tick],"wire replay mismatch frame%d" % frame_tick): return
	var result := states[0]
	if not check(result.recovery_input_ticks > 338 and result.tick == 650-result.recovery_input_ticks and frozen[0] == frozen[1],"freeze independent input and battle clocks"): return
	if not check(result.goals == PackedInt32Array([1,2]) and result.recovery_side == -1,"both sides score, early deployment, skip and timeout"): return
	var crossed := false
	var phantom := false
	for actor in result.units:
		if actor.operator_id == "blaze" and actor.side == 1 and actor.cell == Vector2i(16,9): crossed = true
		if actor.operator_id == "nightingale_phantom": phantom = true
	if not check(crossed and not phantom and result.sides[0].tactical_items[3] == 0 and result.tactical_item_effects.size() == 1,"real network cross-boundary deploy and drone consumes/removes summon"): return
	for peer in peers:
		if peer.side == 0 or peer.bilateral_finish: peer.announce_finish(result.input_tick,2)
	while peers[0].finish_tick < 0 or peers[1].finish_tick < 0:
		if not await poll(): return
	for peer in peers:
		peer.record_round(2)
		peer.completed()
		peer.close()
		peer.queue_free()
	print("GOAL_RECOVERY_NETWORK_OK 650 per-frame hashes, wire deploy/skip/timeout/drone, finish by input frame; transport=", "LAN with120ms outgoing delay" if endpoint.is_empty() else "local relay")
	quit(0)
