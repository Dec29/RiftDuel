extends SceneTree

class DelayedSession extends NetSession:
	var outgoing: Array[Dictionary] = []
	func _send(message: Dictionary) -> void:
		outgoing.append({"at":Time.get_ticks_msec()+120,"message":message})
	func _process(delta: float) -> void:
		while not outgoing.is_empty() and outgoing[0].at<=Time.get_ticks_msec():
			var entry: Dictionary=outgoing.pop_front()
			if peer!=null: super._send(entry.message)
		super._process(delta)

var peers: Array[NetSession]=[]
var deadline:=0
var delay:=0.005
var chosen:=PackedStringArray(["bagpipe","blaze","nightingale","exusiai","saria","surtr","texas","silverash","kaltsit","ling","myrtle","amiya"])
var selected_skills:=PackedInt32Array()

func _initialize() -> void: call_deferred("run")

func check(value: bool,message: String) -> bool:
	if not value: push_error(message); quit(1)
	return value

func poll() -> bool:
	await create_timer(delay).timeout
	for p in peers:
		if not check(p.phase!="failed","session failed: "+p.status): return false
	return check(Time.get_ticks_msec()<deadline,"draft network deadline")

func stage(expected: int) -> bool:
	while peers[0].draft.state==null or peers[1].draft.state==null or peers[0].draft.state.stage!=expected or peers[1].draft.state.stage!=expected:
		if not await poll(): return false
	return true

func settle() -> bool:
	var end:=Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<end:
		if not await poll(): return false
	return true

func run() -> void:
	deadline=Time.get_ticks_msec()+120000
	var args:=OS.get_cmdline_user_args()
	var endpoint: String=args[0] if not args.is_empty() else ""
	if not endpoint.is_empty(): delay=0.027
	var db: Node=root.get_node("OperatorDB")
	for side in 2:
		var p: NetSession=DelayedSession.new(db.network_content()) if endpoint.is_empty() else RelaySession.new(db.network_content())
		root.add_child(p); peers.append(p)
	if endpoint.is_empty():
		peers[0].create_room(24981,"231949",24982)
		peers[1].join_address("127.0.0.1","231949",24981)
	else:
		peers[0].create_online(endpoint)
		while peers[0].phase!="hosting":
			if not await poll(): return
		peers[1].join_online(endpoint,peers[0].room_code)
	while peers[0].phase!="room" or peers[1].phase!="room":
		if not await poll(): return
	var room_code:=peers[0].room_code
	if not check(peers[0].rules.draft_enabled and peers[1].rules.draft_enabled,"multiplayer defaults draft enabled"): return
	peers[0].set_rules(MatchRules.new("score",1,2,true).to_wire())
	while peers[0].rules_pending or peers[1].rules.rounds!=2:
		if not await poll(): return
	for id in chosen: selected_skills.append(db.get_data(id).skills.size()-1)
	for p in peers:
		p.local_squad=chosen.duplicate(); p.local_skills=selected_skills.duplicate(); p.set_ready(true)
	while not peers[0].remote_ready or not peers[1].remote_ready:
		if not await poll(): return
	peers[0].start_match()
	if not await stage(0): return
	var first_id:=peers[0].draft.draft_id
	peers[0].draft.request("ban",[],[],"aak")
	if not await settle(): return
	if not check(peers[1].draft.state.bans[0]==PackedStringArray(["aak"]),"ban publishes immediately"): return
	peers[1].draft.request("ban",[],[],"aak")
	if not await settle(): return
	if not check(peers[0].draft.state.bans[1].is_empty() and peers[1].phase=="draft","duplicate ban rejected without slot loss or disconnect"): return
	for id in ["archetto","carnelian"]: peers[0].draft.request("ban",[],[],id)
	for id in ["chen","chen_alter","cliffheart"]: peers[1].draft.request("ban",[],[],id)
	if not await stage(1): return
	peers[0].draft.request("update",Array(chosen.slice(0,2)))
	if not await settle(): return
	if not check(peers[1].draft.state.picks[0].is_empty(),"partial picks remain private"): return
	peers[0].draft.request("submit",Array(chosen.slice(0,6)))
	if not await settle(): return
	if not check(peers[1].draft.state.locked[0] and peers[1].draft.state.picks[0].is_empty(),"confirmed picks hidden until both finish"): return
	peers[1].draft.request("submit",Array(chosen.slice(0,6)))
	if not await stage(2): return
	if not check(peers[0].draft.state.picks[0]==peers[0].draft.state.picks[1],"both sides may choose identical operators"): return
	peers[1].draft.request("ban",[],[],"bagpipe")
	if not await settle(): return
	if not check(peers[1].draft.state.bans[1].size()==3,"previous picks protected from second ban"): return
	for id in ["cuora","dusk"]: peers[0].draft.request("ban",[],[],id)
	for id in ["elysium","eunectes"]: peers[1].draft.request("ban",[],[],id)
	if not await stage(3): return
	for p in peers: p.draft.request("submit",Array(chosen))
	if not await stage(4): return
	peers[0].draft.request("update",Array(chosen),Array(selected_skills))
	peers[0].draft.request("submit",Array(chosen),Array(selected_skills))
	if not await settle(): return
	if not check(peers[1].draft.state.skills[0].is_empty(),"skills hidden until stage completes"): return
	peers[1].draft.request("submit",Array(chosen),Array(selected_skills))
	for round_index in 2:
		for p in peers:
			while p.phase!="loading":
				if not await poll(): return
			if not check(p.draft.completed and p.draft.draft_id==first_id and p.local_squad==chosen and p.remote_squad==chosen and p.local_skills==selected_skills and p.remote_skills==selected_skills,"final loadout and series retained without repeat draft"): return
			p.mark_loaded()
		while peers[0].phase!="running" or peers[1].phase!="running":
			if not await poll(): return
		var states: Array[MatchState]=[]
		var inputs: Array[LocalInput]=[LocalInput.new(0),LocalInput.new(1)]
		var hashes: Array[Dictionary]=[{},{}]
		var data: Dictionary={}
		for id in chosen: data[id]=db.get_data(id)
		for side in 2:
			states.append(MatchState.new(peers[side].match_seed,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[chosen,chosen],[selected_skills,selected_skills],peers[side].match_rules))
			for s in states[side].sides: s.cost=99
			inputs[side].select_operator("bagpipe")
			inputs[side].queue_deploy(0,Vector2i(13,5) if side==0 else Vector2i(7,5),0)
		var frames:=120 if round_index==0 else 30
		while states[0].input_tick<frames or states[1].input_tick<frames:
			for side in 2:
				var tick:=states[side].input_tick
				if tick>=frames: continue
				peers[side].seal_frame(tick,inputs[side])
				var frame:=peers[side].take_frame(tick)
				if frame.is_empty(): continue
				states[side].step(frame[0],frame[1])
				hashes[side][states[side].input_tick]=states[side].state_hash()
			if not await poll(): return
		for tick in range(1,frames+1):
			if not check(hashes[0][tick]==hashes[1][tick],"drafted wire battle diverged at frame%d"%tick): return
		for p in peers:
			if p.side==0 or p.bilateral_finish: p.announce_finish(frames,MatchState.RESULT_DRAW)
		while peers[0].finish_tick<0 or peers[1].finish_tick<0:
			if not await poll(): return
		for p in peers: p.record_round(MatchState.RESULT_DRAW); p.completed(); p.return_to_room()
	while peers[0].phase!="room" or peers[1].phase!="room":
		if not await poll(): return
	if not check(peers[0].draft.state==null and peers[1].draft.state==null and peers[0].room_code==room_code,"new series resets draft, retains original room"): return
	for p in peers: p.set_ready(true)
	while not peers[0].remote_ready or not peers[1].remote_ready:
		if not await poll(): return
	peers[0].start_match()
	if not await stage(0): return
	peers[1].draft.request("cancel")
	while peers[0].phase!="room" or peers[1].phase!="room":
		if not await poll(): return
	if not check(peers[0].room_code==room_code and not peers[0].local_ready and not peers[1].local_ready,"cancel stays connected and clears ready"): return
	if endpoint.is_empty():
		for p in peers: p.set_ready(true)
		while not peers[0].remote_ready or not peers[1].remote_ready:
			if not await poll(): return
		peers[0].start_match()
		if not await stage(0): return
		for expected in range(1,6):
			if expected==2: peers[0].draft.request("update",Array(chosen.slice(0,2)))
			peers[0].draft.deadline_ms=Time.get_ticks_msec()
			if not await stage(expected): return
		if not check(peers[0].local_squad==chosen and peers[1].local_squad==chosen and peers[0].local_skills==selected_skills,"LAN authority timeout fills favorites and skill defaults"): return
	for p in peers: p.close(); p.queue_free()
	print("DRAFT_NETWORK_OK: five stages, live unique bans, private picks/skills, identical teams, 150 per-frame wire hashes, two rounds one draft, new series reset/cancel; ","LAN120ms" if endpoint.is_empty() else "relay")
	quit(0)
