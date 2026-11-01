extends SceneTree
var failures := 0
var data := {"typhon":load("res://resources/operators/typhon.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres"),"hoshiguma":load("res://resources/operators/hoshiguma.tres")}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var op: OperatorData=data.typhon
	check(op.validation_error().is_empty() and op.max_health==1702 and op.attack==1045 and op.defense==113 and op.attack_interval==2.4,"Pinned E2 raw stats and typed three skills")
	check(op.attack_range.size()==13 and Vector2i.ZERO not in op.attack_range and Vector2i(1,0) not in op.attack_range and Vector2i(4,1) in op.attack_range and Vector2i(4,2) not in op.attack_range,"Exact range4-3 including blind cells")
	for facing in 4:
		for offset in op.attack_range:check(AttackRange.rotate_offset(AttackRange.rotate_offset(offset,facing),(4-facing)%4)==offset,"Four-way range rotation")
	var s1 := fixture(0)
	for tick in 599:s1.step([],[])
	check(s1.units[0].sp==35,"S1 natural initial15/35")
	s1.step([cast(s1,0)],[])
	check(s1.units[0].skill_ticks_left==1049 and SkillRules.attack_value(s1.units[0],op)==1515 and SkillRules.attack_interval_ticks(s1.units[0],op)==50,"S1 additive45percent and45speed")
	var s2 := fixture(1)
	for tick in 239:s2.step([],[])
	s2.step([cast(s2,1)],[])
	check(s2.units[0].skill_ticks_left==599 and SkillRules.attack_value(s2.units[0],op)==1568,"S2 initial42 reaches50 in8seconds and first20s")
	for tick in 599:s2.step([],[])
	check(s2.units[0].skill_ticks_left==0,"First S2 expires")
	for tick in 1500:s2.step([],[])
	s2.step([cast(s2,1)],[])
	check(s2.units[0].skill_ticks_left==-2 and s2.units[0].skill_repeat_activation_count==2,"Second S2 is infinite")
	StatusRules.apply_silence(s2,s2.units[0],2)
	check(SkillRules.attack_value(s2.units[0],op)==1045,"Silence pauses infinite stats")
	s2.step([],[]);s2.step([],[])
	check(SkillRules.attack_value(s2.units[0],op)==1568,"Infinite skill resumes")
	var weight := fixture(0)
	weight.units.append(UnitState.new(1,1,"bagpipe",Vector2i(11,2),2484,0,100000))
	weight.units.append(UnitState.new(2,1,"hoshiguma",Vector2i(10,3),3850,0,100000))
	weight.units[0].attack_ticks_left=0
	weight.step([],[])
	check(weight.units[1].hp==2484 and weight.units[2].hp<3850,"Heavier defender takes priority over lowerID vanguard")
	check(weight.units[0].penetration_stacks==1,"Penetration increases before first attack")
	for index in 4:
		weight.units[0].attack_ticks_left=0;weight.step([],[])
	check(weight.units[0].penetration_stacks==5,"Five attacks cap defense penetration50percent")
	weight.units.resize(1);weight.units[0].attack_ticks_left=100000
	for tick in 240:weight.step([],[])
	check(weight.units[0].penetration_stacks==0,"8second idle clears penetration")
	var rain := fixture(2)
	rain.units[0].sp=40
	rain.step([cast(rain,2)],[])
	check(rain.units[0].sp==40 and rain.units[0].skill_ticks_left==0,"No markable target cannot spendSP")
	rain.ball.cell=Vector2i(11,2);rain._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);rain._ball_data.kick_threshold=100000
	rain.units[0].attack_ticks_left=0
	rain.step([cast(rain,2)],[])
	check(rain.units[0].skill_ammo_left==9 and rain.units[0].rain_arrows_left==4 and rain.units[0].mark_kind==2 and SkillRules.attack_interval_ticks(rain.units[0],op)==165,"Actual ball mark,10 rounds, delayed5arrow round,5.5s interval")
	for tick in 12:rain.step([],[])
	check(rain.ball.accum==Vector2i(-9145,0) and rain.units[0].rain_arrows_left==0,"Five175percent raw pushes at0.1second intervals, no PvP/first-enemy multiplier")
	rain.step([cast(rain,2)],[])
	check(rain.units[0].skill_ticks_left==0 and rain.units[0].rain_arrows_left==0 and rain.units[0].sp==0,"Manual close consumes no extraSP and clears pending arrows")
	var first := fixture(0)
	var enemy: OperatorData=data.bagpipe.duplicate(true);enemy.operator_id="enemy_fixture";enemy.max_health=100000;enemy.defense=100
	data.enemy_fixture=enemy
	first=fixture(0)
	first.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(11,2),100000,0,100000))
	first.units[0].sp=35;first.units[0].attack_ticks_left=0
	first.step([cast(first,0)],[])
	check(first.units[1].hp==99410 and first.units[1].slow_ticks_left>0 and first.units[0].skill_hit_ids==PackedInt32Array([1]),"First skill hit160percent,10percent penetration, sniper PvP and slow")
	first.units[0].attack_ticks_left=0;first.step([],[])
	check(first.units[0].skill_hit_ids.size()==1 and first.units[1].hp==99045,"Second hit has no repeated first-hit multiplier,20percent penetration")
	var dual := fixture(1)
	for id in [1,2]:dual.units.append(UnitState.new(id,1,"enemy_fixture",Vector2i(11,id+1),100000,0,100000))
	dual.units[0].sp=50;dual.units[0].attack_ticks_left=0
	dual.step([cast(dual,1)],[])
	check(dual.units[1].hp==99388 and dual.units[2].hp==99388 and dual.units[0].skill_hit_ids.size()==2,"S2 two arrows prefer distinct targets with independent first-hit marks")
	var random_a := fixture(2);var random_b := fixture(2)
	for state in [random_a,random_b]:
		for id in [1,2]:state.units.append(UnitState.new(id,1,"enemy_fixture",Vector2i(11,id+1),100000,0,100000))
		state.units[0].sp=40;state.units[0].attack_ticks_left=0
	for tick in 20:
		var inputs: Array[InputCommand]=[]
		if tick==0:inputs.append(cast(random_a,2))
		random_a.step(inputs,[]);random_b.step(inputs,[])
		check(random_a.state_hash()==random_b.state_hash(),"Random per-arrow target replay%d"%tick)
	var oracle := RNG.new(2012)
	for arrow in 5:oracle.next_u32()
	check(random_a.rng.state==oracle.state and random_a.units[0].skill_ammo_left==9,"Five arrows independently sample two candidates, one ammo round")
	random_a.units[1].cell=Vector2i(11,4)
	for tick in 6:random_a.step([],[])
	check(random_a.units[0].mark_cell==Vector2i(11,4),"Mark follows target beyond original acquisition range")
	random_a.units.remove_at(1)
	for tick in 6:random_a.step([],[])
	check(random_a.units[0].mark_cell==Vector2i(11,4),"Mark retains last cell after target leaves")
	var a := fixture(2);var b := fixture(2)
	for state in [a,b]:
		state.ball.cell=Vector2i(11,2);state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=100000000
		state.units[0].sp=40;state.units[0].attack_ticks_left=0
	for tick in 1700:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(cast(a,2))
		a.step(commands,[]);b.step(commands,[])
		check(a.state_hash()==b.state_hash(),"Per-tick arrow/ammo/mark replay%d"%tick)
	check(a.units[0].skill_ammo_left==0 and a.units[0].skill_ticks_left==0,"Ten rounds expire and restore normal attack")
	check(op.attack==1045 and op.skills[1].duration==20.0,"Resources remain read-only")
	print("TYPHON_CORE_OK" if failures==0 else "TYPHON_FAILED count%d"%failures)
	quit(0 if failures==0 else 1)

func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["typhon"]);var skills := PackedInt32Array([index])
	var state := MatchState.new(2012,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state.step([InputCommand.new(0,0,"typhon",-1,Vector2i(13,2),-1,2)],[])
	return state

func cast(state: MatchState,index: int) -> InputCommand:
	return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,index)

func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
