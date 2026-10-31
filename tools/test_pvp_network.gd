extends SceneTree
var deadline := 0
var peers: Array[NetSession]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var endpoint := args[0] if not args.is_empty() else ""
	deadline=Time.get_ticks_msec()+150000
	var content: Dictionary=root.get_node("OperatorDB").network_content()
	for side in 2:
		var peer: NetSession=NetSession.new(content) if endpoint.is_empty() else RelaySession.new(content)
		root.add_child(peer);peers.append(peer)
		peer.failed.connect(func(message: String) -> void: print("PVP_FAILURE side=",peer.side," message=",message))
	if endpoint.is_empty():peers[0].create_room(24985,"642319",24986)
	else:peers[0].create_online(endpoint)
	if not await wait_phase(peers[0],"hosting"):return
	# Rules set before join must arrive in the joining snapshot.
	peers[0].set_rules({"mode":"single","minutes":12,"rounds":3,"draft_enabled":false})
	while peers[0].rules_pending:if not await poll():return
	if endpoint.is_empty():peers[1].join_address("127.0.0.1",peers[0].room_code,24985)
	else:peers[1].join_online(endpoint,peers[0].room_code)
	for peer in peers:
		if not await wait_phase(peer,"room"):return
	if not check(peers[1].rules.minutes==12 and peers[1].rules.mode=="single","join rule snapshot"):return
	for peer in peers:
		peer.local_squad=PackedStringArray(["bagpipe"]);peer.local_skills=PackedInt32Array([0]);peer.set_ready(true)
	while not peers[0].remote_ready or not peers[1].remote_ready:if not await poll():return
	peers[0].set_rules({"mode":"score","minutes":1,"rounds":3,"draft_enabled":false})
	while peers[0].rules_pending or peers[1].rules.mode!="score":if not await poll():return
	for peer in peers:
		if not check(not peer.local_ready and not peer.remote_ready,"edit invalidates both readiness"):return
		peer.set_ready(true)
	while not peers[0].remote_ready or not peers[1].remote_ready:if not await poll():return
	peers[0].start_match()
	var old_seed := -1
	var old_match := ""
	var code := peers[0].room_code
	for index in 3:
		for peer in peers:
			if not await wait_phase(peer,"loading"):return
			peer.mark_loaded()
		for peer in peers:
			if not await wait_phase(peer,"running"):return
		if not check(peers[0].round_number==index+1 and peers[1].round_number==index+1 and not peers[0].can_edit_rules(),"locked rules and sequential round"):return
		if not endpoint.is_empty():
			if not check(peers[0]._match_id!=old_match,"fresh per-round match identity"):return
			old_match=peers[0]._match_id
		old_seed=peers[0].match_seed
		var data := {"bagpipe":load("res://resources/operators/bagpipe.tres")}
		var states: Array[MatchState]=[]
		var inputs: Array[LocalInput]=[LocalInput.new(0),LocalInput.new(1)]
		for peer in peers:states.append(MatchState.new(peer.match_seed,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[peers[0].local_squad,peers[1].local_squad],[peers[0].local_skills,peers[1].local_skills],peer.match_rules))
		if not check(states[0].units.is_empty() and states[0].sides[0].cost==Config.COST_INITIAL and states[0].goals==PackedInt32Array([0,0]) and peers[0]._consumed==0,"fresh battle and input buffers"):return
		# Controlled-cost fixture follows the fresh initial-economy assertion.
		for state in states:
			for side_state in state.sides:side_state.cost=99
		inputs[0].select_operator("bagpipe");inputs[0].queue_deploy(0,Vector2i(13,5),2)
		inputs[1].select_operator("bagpipe");inputs[1].queue_deploy(0,Vector2i(7,5),0)
		var hashes: Array[Dictionary]=[{},{}]
		while states[0].tick<90 or states[1].tick<90:
			for side in 2:
				var state := states[side]
				if state.tick>=90:continue
				peers[side].seal_frame(state.tick,inputs[side])
				var frame := peers[side].take_frame(state.tick)
				if not frame.is_empty():
					if state.tick in [30,60]:state.ball.cell.x=0 if index!=1 else 20
					state.step(frame[0],frame[1]);hashes[side][state.tick]=state.state_hash()
			if not await poll():return
		for tick in range(1,91):
			if not check(hashes[0][tick]==hashes[1][tick],"wire divergence round%d tick%d"%[index,tick]):return
		if not check(states[0].units.size()==2 and states[1].units.size()==2 and states[0].sides[0].cost<99 and states[0].goals[0]+states[0].goals[1]==2,"actual deployments charged and retained across both goals"):return
		var result := 1 if index!=1 else 2
		for peer in peers:
			if peer.side==0 or peer.bilateral_finish:peer.announce_finish(90,result)
		while peers[0].finish_tick<0 or peers[1].finish_tick<0:if not await poll():return
		for peer in peers:peer.record_round(result);peer.completed()
		if not check(peers[0].series_wins()==[PackedInt32Array([1,0]),PackedInt32Array([1,1]),PackedInt32Array([2,1])][index],"series outcome accumulation"):return
		peers[index%2].return_to_room()
		if not await poll():return
		if not check(peers[1-index%2].phase=="running" and peers[index%2].phase=="returning","one player cannot bypass intermission"):return
		peers[1-index%2].return_to_room()
		if index==2:
			for peer in peers:
				if not await wait_phase(peer,"room"):return
		else:
			for peer in peers:
				if not await wait_phase(peer,"loading"):return
	if not check(peers[0].can_edit_rules() and peers[0].room_code==code and not peers[0].local_ready and not peers[1].local_ready,"series ends in editable same room"):return
	peers[1].leave()
	if not await wait_phase(peers[0],"failed"):return
	for peer in peers:peer.close();peer.queue_free()
	print("PVP_NETWORK_OK: prejoin snapshot, edit/readiness, 3 rounds, 270 wire hashes, real deployment and repeated goals, fresh input/units/cost, same-room final return; controlled-cost fixture; transport=", "LAN" if endpoint.is_empty() else endpoint)
	quit(0)
func poll() -> bool:
	await create_timer(0.027).timeout
	for peer in peers:
		if peer.phase=="failed":return check(false,"session failed: "+peer.status)
	return check(Time.get_ticks_msec()<deadline,"network timeout")
func wait_phase(peer: NetSession,wanted: String) -> bool:
	while peer.phase!=wanted:
		if wanted=="failed":
			await create_timer(0.027).timeout
			if not check(Time.get_ticks_msec()<deadline,"leave timeout"):return false
			continue
		if peer.phase=="failed":return check(wanted=="failed",peer.status)
		if not await poll():return false
	return true
func check(value: bool,message: String) -> bool:
	if not value:push_error(message);quit(1)
	return value
