extends SceneTree
var failures := 0
var counts := {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1; push_error(text)
func available(state: DraftState, count: int, start: PackedStringArray = PackedStringArray()) -> Array:
	var result := Array(start)
	for id in state.ids:
		if result.size()>=count: break
		if id not in result and not state.banned(id): result.append(id)
	return result
func run() -> void:
	counts = root.get_node("OperatorDB").network_content().skill_counts
	var state := DraftState.new(counts)
	check(MatchRules.pvp_default().draft_enabled and not MatchRules.new("score",5,1).draft_enabled,"multiplayer default on, simulation/solo opt-out")
	check(state.duration_ms()==20000,"first ban20 seconds")
	check(state.ban(0,"bagpipe").is_empty(),"ban accepted")
	check(not state.ban(1,"bagpipe").is_empty() and state.bans[1].is_empty(),"concurrent duplicate ban rejected without spending slot")
	state.update_selection(0,[],[],true)
	state.update_selection(1,[],[],true)
	check(state.stage==1 and state.duration_ms()==100000,"both finish ban early; pick100 seconds")
	var first := available(state,6)
	state.update_selection(0,first.slice(0,3),[],false)
	check(state.snapshot().picks==[[],[]],"partial picks never public")
	state.update_selection(0,first,[],true)
	check(state.locked[0] and state.snapshot().picks==[[],[]],"one confirmed side remains secret")
	state.update_selection(1,first,[],true)
	check(state.stage==2 and state.picks[0]==state.picks[1] and state.picks[0].size()==6,"same operators allowed across both teams and revealed together")
	check(state.ban_limits==[3,2] and not state.can_ban(1,first[0]),"empty ban does not carry forward; picked operators protected")
	var bans := available(state,12)
	for id in bans:
		if id not in first:
			state.ban(1,id)
			if state.locked[1]: break
	check(state.bans[1].size()==2 and state.locked[1],"second ban only2 choices")
	state.update_selection(0,[],[],true)
	check(state.stage==3 and state.duration_ms()==100000,"second pick100 seconds")
	var second := available(state,12,state.picks[0])
	check(not state.update_selection(0,second.slice(1),[],false).is_empty(),"cannot remove first six")
	state.update_selection(0,second,[],true)
	state.update_selection(1,second.slice(0,9),[],false)
	check(state.picks[0].size()==6 and state.picks[1].size()==6,"second picks remain private until stage completion")
	state.expire()
	check(state.stage==4 and state.duration_ms()==30000 and state.picks[0].size()==12 and state.picks[1].size()==12,"timeout fills current selection and preserves earlier six")
	var indices := []
	for id in state.picks[0]: indices.append(int(counts[id])-1)
	state.update_selection(0,Array(state.picks[0]),indices,false)
	check(state.skills[0].is_empty(),"unconfirmed skills private")
	state.update_selection(0,Array(state.picks[0]),indices,true)
	check(state.skills[0].is_empty() and state.skills[1].is_empty(),"single confirmed skill configuration still private")
	var invalid := indices.duplicate(); invalid[0]=3
	check(not state.update_selection(1,Array(state.picks[1]),invalid,true).is_empty(),"unimplemented skill rejected")
	state.expire()
	check(state.stage==5 and state.skills[0]==PackedInt32Array(indices) and state.skills[1].size()==12,"final skills reveal and early/full completion")
	var auto := DraftState.new(counts)
	auto.preferences[0]=PackedStringArray(["nightingale","bagpipe","blaze"])
	auto.preferred_skills[0]=PackedInt32Array([2,1,1])
	var replica := DraftState.new(counts)
	for phase in 6:
		auto.serial+=1
		var snapshot := auto.snapshot()
		snapshot.draft_id="a".repeat(32);snapshot.remaining_ms=auto.duration_ms() if auto.stage<5 else 0
		var value: Dictionary=JSON.parse_string(JSON.stringify(snapshot))
		check(replica.read_snapshot(value).is_empty(),"JSON snapshot replica phase%d"%phase)
		check(not replica.read_snapshot(value).is_empty(),"duplicate control snapshot rejected")
		if phase<5: auto.expire()
	check(auto.picks[0][0]=="nightingale" and auto.skills[0][0]==2 and auto.picks[0].size()==12,"all-timeout deterministic favorite fallback and preferred skills")
	var limit := DraftState.new(counts)
	limit.expire();limit.expire()
	check(limit.ban_limits==[2,2],"all-empty first bans leave exactly2 second bans")
	print("DRAFT_RULES_OK default switch, five clocks, empty bans, collision, duplicate picks, stage privacy, protected picks, partial timeout, skill validation, JSON replicas; failures=",failures)
	quit(0 if failures==0 else 1)
