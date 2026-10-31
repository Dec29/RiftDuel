extends SceneTree

var failures := 0
var data := {}
var op: OperatorData


func _initialize() -> void:
	op=load("res://resources/operators/texas_alter.tres");data.texas_alter=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	check(op.validation_error().is_empty() and op.max_health==1598 and op.attack==569 and op.defense==320 and op.skills.size()==3,"Original E2, no trust/potential/module, actual three M3 skills")
	var first := fixture(0);var unit := actor(first);var target := enemy(first,Vector2i(13,5));unit.attack_ticks_left=1;first.step([],[])
	check(unit.skill_activation_count==1 and unit.sp==0 and SkillRules.attack_value(unit,op)==1081 and SkillRules.attack_interval_ticks(unit,op)==26,"S1 actual zero-SP deployment passive,70%+20%ATK and first-kill ASPD8")
	check(first._damage_taken_percent(unit,"true")==75.0 and first._damage_taken_percent(unit,"magical")==75.0,"Before first kill, original all-damage25% reduction includes true")
	check(target.hp==100000-damage(1081,"physical") and target.silence_ticks_left==300 and target.texas_dot_until_tick==301 and target.texas_dot_next_tick==31,"S1 actual attack applies ten-second silence and separate DOT")
	unit.attack_ticks_left=10000;var hp := target.hp
	for tick in 30:first.step([],[])
	check(target.hp==hp-damage(400,"magical"),"Original fixed400 magic DOT first pulse after one second")
	var next := target.texas_dot_next_tick;unit.attack_ticks_left=1;first.step([],[])
	check(target.texas_dot_next_tick==next and target.texas_dot_until_tick==first.tick-1+300,"Reapplying silence/DOT refreshes duration, not pulse phase or stacked damage")
	var departed := fixture(0);unit=actor(departed);target=enemy(departed,Vector2i(13,5));unit.attack_ticks_left=1;departed.step([],[]);hp=target.hp
	departed.step([InputCommand.new(departed.tick,2,"",unit.unit_id)],[])
	check(unit not in departed.units and target.texas_dot_until_tick>0,"Actual retreat does not remove already-applied DOT")
	for tick in 300:departed.step([],[])
	check(target.hp==hp-10*damage(400,"magical") and target.texas_dot_until_tick==0 and target.texas_dot_source_id==-1,"Exactly ten source-attributed DOT pulses persist after retreat, then clear")
	var reset := fixture(0);unit=actor(reset);unit.hp=1000;target=enemy(reset,Vector2i(13,5));target.hp=1;unit.attack_ticks_left=1;reset.step([],[])
	check(unit.hp==1598 and unit.texas_first_kill_used and not unit.texas_recast_pending and unit.skill_activation_count==2 and unit.skill_ticks_left==359,"Actual first kill resets all HP and re-releases full S1 once")
	check(SkillRules.attack_interval_ticks(unit,op)==28 and reset._damage_taken_percent(unit,"true")==100.0,"First kill immediately removes swordsmanship speed and damage protection")
	unit.hp=1000;target=enemy(reset,Vector2i(13,5));target.hp=1;unit.attack_ticks_left=1;reset.step([],[])
	check(unit.hp==1000 and unit.skill_activation_count==2,"Second actual kill cannot grant another reset")
	var muted := fixture(0);unit=actor(muted);target=enemy(muted,Vector2i(13,5));unit.attack_ticks_left=1;muted.step([],[]);target.hp=1;unit.hp=1000;unit.attack_ticks_left=10000;StatusRules.apply_silence(muted,unit,60)
	for tick in 30:muted.step([],[])
	check(unit.texas_first_kill_used and unit.texas_recast_pending and unit.skill_activation_count==1 and unit.hp==1000,"First DOT kill under actual silence retains opportunity without premature heal/recast")
	for tick in 35:muted.step([],[])
	check(not unit.texas_recast_pending and unit.skill_activation_count==2 and unit.hp==1598,"Silence expiry executes pending first-kill heal and passive restart")
	var late := fixture(0);unit=actor(late);unit.skill_ticks_left=1;target=enemy(late,Vector2i(13,5));unit.attack_ticks_left=1;late.step([],[]);target.hp=1;unit.hp=1000;unit.attack_ticks_left=10000
	check(unit.skill_ticks_left==0,"Initial passive really expired before delayed kill")
	for tick in 30:late.step([],[])
	check(unit.skill_activation_count==2 and unit.hp==1598 and unit.skill_ticks_left>0,"First delayed kill after duration still restarts passive")
	var defended := dummy.duplicate(true) as OperatorData;defended.magic_resist=50;data.target=defended
	var second := fixture(1,[Vector2i(13,5)]);data.target=dummy;unit=actor(second);target=second.units[0]
	check(unit.skill_activation_count==1 and unit.skill_ticks_left==299 and SkillRules.attack_value(unit,op)==996,"S2 actual deployment10seconds,55%+20%ATK")
	check(target.hp==100000-damage(2390,"magical",50) and SkillRules.magic_resist_value(target,defended)==35 and target.texas_resist_until_tick==300,"S2 burst follows attack buff, then30% resist reduction50to35")
	hp=target.hp;unit.attack_ticks_left=1;second.step([],[])
	check(target.hp==hp-2*damage(996,"magical",35),"S2 actual two-hit magical ordinary attack with reduced resist")
	unit.attack_ticks_left=10000
	while second.tick<300:second.step([],[])
	second.step([],[])
	check(target.texas_resist_remaining_percent==100 and target.texas_resist_until_tick==0 and SkillRules.magic_resist_value(target,defended)==50 and SkillRules.attack_value(unit,op)==569,"S2 and resistance modifier independently expire without stale stats")
	var cells: Array[Vector2i]=[Vector2i(13,5),Vector2i(12,4),Vector2i(11,5),Vector2i(12,6),Vector2i(13,6)]
	var third := fixture(2,cells);unit=actor(third)
	for enemy_unit in third.units:
		if enemy_unit.side==1:check(enemy_unit.hp==100000-2*damage(1127,"magical") and enemy_unit.stun_ticks_left==60,"S3 actual two165% deployment bursts and2second stun")
	check(unit.skill_ticks_left==239 and SkillRules.attack_value(unit,op)==683,"S3 actual eight-second passive with tradition20%ATK")
	for tick in 19:third.step([],[])
	check(third.units[0].hp==100000-2*damage(1127,"magical"),"No sword rain before quantized initial20ticks")
	third.step([],[])
	for index in 5:check(third.units[index].hp==100000-2*damage(1127,"magical")-(damage(888,"magical") if index<4 else 0),"First rain chooses at most four distinct targets, target%d"%index)
	while third.texas_rains.is_empty() and third.tick<220:third.step([],[])
	check(not third.texas_rains.is_empty(),"Deterministic native-range0to9tick delay produces an actual pending rain")
	var rain: TexasRain=third.texas_rains[0];target=WArtilleryRules.owner(third,rain.target_ids[0]);hp=target.hp;var due := rain.due_tick
	third.step([InputCommand.new(third.tick,2,"",unit.unit_id)],[])
	while third.tick<=due:third.step([],[])
	check(unit not in third.units and target.hp==hp-damage(rain.attack,"magical") and third.texas_rains.is_empty(),"Already-emitted rain lands once after actual source retreat, then lifecycle clears")
	var objects := fixture(2,[],true);unit=actor(objects)
	check(objects.tactical_boxes[0].hits_left==1,"S3 actual deployment burst applies two box hits")
	var redeploy := fixture(0);unit=actor(redeploy);target=enemy(redeploy,Vector2i(13,5));target.hp=1;unit.attack_ticks_left=1;redeploy.step([],[])
	redeploy.step([InputCommand.new(redeploy.tick,2,"",unit.unit_id)],[])
	check(redeploy.sides[0].cost==94 and redeploy.sides[0].cooldowns["texas_alter"]==540,"Actual executor retreat refunds5 and starts18second cooldown")
	for tick in 540:redeploy.step([],[])
	redeploy.step([InputCommand.new(redeploy.tick,0,"texas_alter",-1,Vector2i(12,5),-1,0)],[])
	var again := actor(redeploy)
	check(again.unit_id!=unit.unit_id and redeploy.sides[0].cost==89 and not again.texas_first_kill_used and again.skill_activation_count==1,"Actual later redeployment still costs10, resets per-deploy talent and starts carried passive")
	for index in 3:
		var a := fixture(index,[Vector2i(13,5),Vector2i(11,5)]);var b := fixture(index,[Vector2i(13,5),Vector2i(11,5)])
		var id := actor(a).unit_id
		for tick in 1000:
			var commands: Array[InputCommand]=[]
			if tick==300:commands.append(InputCommand.new(a.tick,2,"",id))
			if tick==850:commands.append(InputCommand.new(a.tick,0,"texas_alter",-1,Vector2i(12,5),-1,0))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Everytick replay S%d tick%d"%[index+1,tick])
			if tick==850:check(actor(a)!=null and actor(a).unit_id!=id,"Replay includes actual post-cooldown redeployment")
	var hashed := fixture(0);unit=actor(hashed)
	for key in ["texas_started_tick","texas_rain_next_tick","texas_rain_emissions","texas_dot_until_tick","texas_dot_next_tick","texas_dot_source_id","texas_resist_remaining_percent","texas_resist_until_tick"]:
		var previous := hashed.state_hash();unit.set(key,unit.get(key)+1);check(previous!=hashed.state_hash(),"Hash includes "+key)
	for key in ["texas_first_kill_used","texas_recast_pending","texas_burst_pending"]:
		var previous := hashed.state_hash();unit.set(key,not unit.get(key));check(previous!=hashed.state_hash(),"Hash includes "+key)
	var pending := TexasRain.new();hashed.texas_rains.append(pending)
	for key in ["source_id","side","facing","attack","due_tick","stun_ticks","goal_generation"]:
		var previous := hashed.state_hash();pending.set(key,pending.get(key)+1);check(previous!=hashed.state_hash(),"Hash includes rain."+key)
	var previous := hashed.state_hash();pending.target_ids.append(2);check(previous!=hashed.state_hash(),"Hash includes rain target IDs")
	previous=hashed.state_hash();pending.box_ids.append(3);check(previous!=hashed.state_hash(),"Hash includes rain box IDs")
	for key in ["source_cell","ball_cell"]:
		previous=hashed.state_hash();pending.set(key,pending.get(key)+Vector2i.ONE);check(previous!=hashed.state_hash(),"Hash includes rain vector."+key)
	print("TEXAS_ALTER_OK all3 actual deployment passives, cost/redeploy, both talents and delayed opportunity, DOT/rain lifecycle,3x1000tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(index: int, enemies: Array[Vector2i] = [], boxes: bool = false) -> MatchState:
	var state := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["texas_alter"],["target"]],[[index],[0]])
	for cell in enemies:enemy(state,cell)
	if boxes:state.tactical_boxes=[TacticalBox.new(0,Vector2i(13,5),3)]
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"texas_alter",-1,Vector2i(12,5),-1,0)],[])
	var unit := actor(state)
	check(unit!=null and state.sides[0].cost==89 and unit.skill_index==index and unit.skill_activation_count==1,"Controlled99 actual legal deployment deducts10 and executes carried passive")
	state.ball.cell=Vector2i(5,5);unit.attack_ticks_left=10000;return state


func actor(state: MatchState) -> UnitState:
	for unit in state.units:
		if unit.operator_id=="texas_alter" and unit.hp>0:return unit
	return null


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func damage(value: int, kind: String, resist: int = 0) -> int:
	return Combat.calculate_damage(value,0,resist,kind,0,RNG.new(1),"specialist")


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
