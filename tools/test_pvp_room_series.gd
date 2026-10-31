extends SceneTree

var _deadline := 0
var _endpoint := ""


func _initialize() -> void:call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():_endpoint=args[0]
	_deadline=Time.get_ticks_msec()+180000
	# Drive short deterministic fixtures ourselves; scene handoff and UI remain real.
	physics_frame.connect(func() -> void:
		if current_scene!=null and current_scene.scene_file_path=="res://main.tscn":current_scene.set_physics_process(false)
	)
	for displayed_side in 2:
		if not await exercise(displayed_side):return
	var audio := root.get_node_or_null("GameAudio") as GameAudio
	if audio!=null:audio.stop_menu()
	await create_timer(0.15).timeout
	print("PVP_ROOM_SERIES_OK: both UI roles, 3 rounds each, actual result clicks and automatic next-scene handoff, round reset and retained final room; short fixtures")
	quit(0)


func exercise(displayed_side: int) -> bool:
	var content: Dictionary=root.get_node("OperatorDB").network_content()
	var peers: Array[NetSession]=[]
	for side in 2:
		var peer: NetSession=RelaySession.new(content) if not _endpoint.is_empty() else NetSession.new(content)
		root.add_child(peer)
		peers.append(peer)
	if _endpoint.is_empty():
		peers[0].create_room(24791+displayed_side,"654321")
		peers[1].join_address("127.0.0.1","654321",24791+displayed_side)
	else:
		(peers[0] as RelaySession).create_online(_endpoint)
		if not await wait_phase(peers[0],"hosting"):return false
		(peers[1] as RelaySession).join_online(_endpoint,peers[0].room_code)
	for peer in peers:
		if not await wait_phase(peer,"room"):return false
	var code := peers[0].room_code
	var room_id := peers[0]._room_id
	var previous_match := ""
	var lobby = load("res://lobby.tscn").instantiate()
	lobby.session=peers[displayed_side]
	root.add_child(lobby)
	current_scene=lobby
	peers[0].set_rules({"mode":"score","minutes":1,"rounds":3,"draft_enabled":false})
	while peers[0].rules_pending or peers[1].rules.rounds!=3:
		if not await poll_peers(peers):return false
	for round_index in 3:
		if round_index==0:
			for peer in peers:
				peer.local_squad=PackedStringArray(["bagpipe"])
				peer.local_skills=PackedInt32Array([0])
				peer.set_ready(true)
			while not peers[0].remote_ready or not peers[1].remote_ready:
				if not await poll_peers(peers):return false
			peers[0].start_match()
		if not await wait_phase(peers[1-displayed_side],"loading"):return false
		peers[1-displayed_side].mark_loaded()
		for peer in peers:
			if not await wait_phase(peer,"running"):return false
		await process_frame
		var battle := current_scene
		if not check(battle.scene_file_path=="res://main.tscn" and battle.session==peers[displayed_side],"Original room must launch the selected player's match"):return false
		battle.set_physics_process(false)
		if not check(battle.match_state.tick==0 and battle.match_state.units.is_empty() and battle.match_state.sides[0].cost==Config.COST_INITIAL,"Second match must be newly initialized"):return false
		if not _endpoint.is_empty():
			var match_id: String=(peers[0] as RelaySession)._match_id
			if not check(match_id!=previous_match and peers[0]._room_id==room_id,"Rematch changes match ID and preserves room ID"):return false
			previous_match=match_id
		var squads: Array=[peers[0].local_squad,peers[1].local_squad]
		var skills: Array=[peers[0].local_skills,peers[1].local_skills]
		var states: Array[MatchState]=[]
		var inputs: Array[LocalInput]=[]
		for side in 2:
			states.append(battle.match_state if side==displayed_side else MatchState.new(peers[0].match_seed,battle.match_view._operator_data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,squads,skills,peers[0].match_rules))
			inputs.append(battle.local_input if side==displayed_side else LocalInput.new(side))
			for side_state in states[side].sides:side_state.cost=99
			inputs[side].select_operator("bagpipe")
			inputs[side].queue_deploy(0,Vector2i(13,5) if side==0 else Vector2i(7,5),0)
		var hashes: Array[Dictionary]=[{0:states[0].state_hash()},{0:states[1].state_hash()}]
		while states[0].tick<120 or states[1].tick<120:
			for side in 2:
				if states[side].tick>=120:continue
				peers[side].seal_frame(states[side].tick,inputs[side])
				var frame := peers[side].take_frame(states[side].tick)
				if not frame.is_empty():
					states[side].step(frame[0],frame[1])
					hashes[side][states[side].tick]=states[side].state_hash()
			if not await poll_peers(peers):return false
		for tick in 121:
			if not check(hashes[0][tick]==hashes[1][tick],"Rematch per-tick state diverged"):return false
		for state in states:state.result=MatchState.RESULT_DRAW
		if displayed_side==1 or not _endpoint.is_empty():peers[1-displayed_side].announce_finish(120,MatchState.RESULT_DRAW)
		battle._physics_process(0.0)
		while peers[0].finish_tick<0 or peers[1].finish_tick<0:
			if not await poll_peers(peers):return false
		battle._physics_process(0.0)
		peers[1-displayed_side].record_round(MatchState.RESULT_DRAW)
		peers[1-displayed_side].completed()
		if not check(battle.match_view.result_confirmed,"UI return remains gated on checked finish"):return false
		var frozen: int=battle.match_state.state_hash()
		if round_index==1:
			peers[1-displayed_side].return_to_room()
			while not peers[displayed_side].remote_returned:
				if not await poll_peers(peers):return false
		var click := InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=true
		click.position=battle.match_view._result_room_rect().get_center()
		battle.match_view._unhandled_input(click)
		battle.match_view._unhandled_input(click)
		await process_frame
		await process_frame
		if round_index==1:
			if not await wait_phase(peers[1-displayed_side],"loading"):return false
			if not check(current_scene.scene_file_path=="res://main.tscn" and current_scene.session==peers[displayed_side],"Second confirmation automatically opens next battle"):return false
			continue
		lobby=current_scene
		if not check(lobby.scene_file_path=="res://lobby.tscn" and lobby.session==peers[displayed_side] and is_instance_valid(lobby.session),"Return transfers the same live session into lobby"):return false
		var panel: Control=lobby.get_node("RoomView/Center/Panel")
		if round_index!=1:
			if not check(peers[displayed_side].phase=="returning" and panel.get_node("Room").visible and not panel.get_node("Create").visible and panel.get_node("Room/ReadyRow/Ready").disabled,"First return keeps room visible and waits for peer"):return false
			peers[1-displayed_side].return_to_room()
		if round_index<2:
			if not check(states[displayed_side].state_hash()==frozen,"Intermission must leave finished simulation frozen"):return false
			if not await wait_phase(peers[1-displayed_side],"loading"):return false
			await process_frame
			continue
		for peer in peers:
			if not await wait_phase(peer,"room"):return false
		if not check(peers[0].room_code==code and peers[1].room_code==code and peers[0].round_number==0 and not peers[0].local_ready and not peers[1].local_ready and peers[0]._consumed==0 and peers[1]._consumed==0,"Final series return keeps room and clears readiness/inputs"):return false
		if not check(panel.get_node("Room").visible and not panel.get_node("JoinRow").visible,"Final return must stay in room"):return false
	if displayed_side==0:
		peers[1-displayed_side].leave()
		if not await wait_phase(peers[displayed_side],"failed"):return false
	else:
		var exit_button: Button=lobby.get_node("RoomView/Center/Panel/Footer/Reset")
		if not check(exit_button.text=="退出房间","Retained room must identify its leave action"):return false
		exit_button.pressed.emit()
		if not await wait_phase(peers[1-displayed_side],"failed"):return false
	var final_panel: Control=lobby.get_node("RoomView/Center/Panel")
	if not check(final_panel.get_node("Create").visible and final_panel.get_node("JoinRow").visible and not final_panel.get_node("Room").visible,"Only peer departure returns the survivor to pairing"):return false
	lobby.queue_free()
	peers[1-displayed_side].queue_free()
	current_scene=null
	await process_frame
	return true


func wait_phase(peer: NetSession, phase: String) -> bool:
	while peer.phase!=phase:
		if not check(peer.phase!="failed" or phase=="failed","Unexpected room phase failure: "+peer.status):return false
		if not check(Time.get_ticks_msec()<_deadline,"Room phase timeout"):return false
		await process_frame
	return true


func poll_peers(peers: Array[NetSession]) -> bool:
	if _endpoint.is_empty():await process_frame
	else:await create_timer(0.034).timeout
	return check(Time.get_ticks_msec()<_deadline and peers[0].phase!="failed" and peers[1].phase!="failed","Room return transport failed or timed out: %s/%s | %s/%s"%[peers[0].phase,peers[0].status,peers[1].phase,peers[1].status])


func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
