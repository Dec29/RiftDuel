extends SceneTree
var failures := 0
var data := {"saria":load("res://resources/operators/saria.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres"),"ifrit":load("res://resources/operators/ifrit.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData = data.saria
	check(op.validation_error().is_empty() and op.max_health==3150 and op.attack==485 and op.defense==595 and op.block_count==3,"Raw E2 guardian stats")
	check(op.attack_range==[Vector2i.ZERO] and op.skills[0].attack_range_override.size()==9 and op.skills[1].attack_range_override.size()==21 and op.skills[2].attack_range_override.size()==25,"Ordinary self-cell range and three independent healing areas")
	var aid := fixture(0)
	aid.units[0].sp_regen_ticks=17
	aid.units[0].hp=1575;aid.units[0].sp=12;aid.units[0].attack_ticks_left=0
	aid.step([],[])
	check(aid.units[0].sp_regen_ticks==17 and aid.units[0].hp==2012 and aid.units[0].sp==8 and aid.units[0].skill_activation_count==1,"S1 <=50percent, one charge,180percent heal at50percent balance, no self SP while casting")
	var idle := fixture(0)
	idle.units[0].sp=12;idle.units[0].attack_ticks_left=0;idle.units[0].hp=1576
	idle.step([],[])
	check(idle.units[0].sp==12 and idle.units[0].skill_activation_count==0,"Above half HP does not waste charge")
	var med := fixture(1)
	med.units[0].sp=7;med.units[0].hp=2000
	med.units.append(UnitState.new(1,0,"bagpipe",Vector2i(12,5),1000,0,100000))
	med.units.append(UnitState.new(2,0,"bagpipe",Vector2i(14,5),1000,0,100000))
	med.units[2].skill_ticks_left=200
	med.step([],[])
	check(med.units[0].hp==2340 and med.units[1].hp==1340 and med.units[2].hp==1340,"S2 heals all wounded in21-cell area at140percent")
	check(med.units[1].sp==1 and med.units[2].sp==0 and med.units[0].sp==0,"HealingSP goes to eligible ally, not blocked active skill or own cast")
	var suit := fixture(0)
	suit.tick=600;AuraRules.refresh(suit)
	check(SkillRules.attack_value(suit.units[0],op)==509 and SkillRules.defense_value(suit.units[0],op)==619,"20sec one Rhine suit stack")
	suit.tick=3000;AuraRules.refresh(suit)
	check(SkillRules.attack_value(suit.units[0],op)==606 and SkillRules.defense_value(suit.units[0],op)==714,"100sec cap five suit stacks")
	StatusRules.apply_silence(suit,suit.units[0],2)
	check(SkillRules.attack_value(suit.units[0],op)==485,"Silence suspends earned suit bonus")
	var calcium := fixture(2)
	calcium.units[0].sp=80;calcium.units[0].hp=2000
	calcium.units.append(UnitState.new(1,1,"bagpipe",Vector2i(12,5),2484,0,100000))
	calcium.step([InputCommand.new(calcium.tick,1,"",0,Vector2i.ZERO,2)],[])
	check(calcium._magical_damage_taken_percent(calcium.units[1])==155,"S3 live55percent magic vulnerability")
	var physical := Combat.calculate_damage(1000,0,0,"physical",0,RNG.new(1),"caster",120,calcium._magical_damage_taken_percent(calcium.units[1]))
	var magical := Combat.calculate_damage(1000,0,0,"magical",0,RNG.new(1),"caster",120,calcium._magical_damage_taken_percent(calcium.units[1]))
	var pure := Combat.calculate_damage(1000,0,0,"true",0,RNG.new(1),"caster",120,155)
	check(physical==360 and pure==360 and magical==558,"Magic-only multiplier combines with fragile before final single rounding")
	for tick in 29:calcium.step([],[])
	check(calcium.units[0].hp==2085 and calcium.units[0].sp==0 and calcium.units[0].last_attack_is_heal,"S3 1sec85HP heal, stops physical attack and natural SP")
	calcium.units[0].stun_ticks_left=60
	for tick in 30:calcium.step([],[])
	check(calcium.units[0].hp==2085 and calcium._magical_damage_taken_percent(calcium.units[1])==155,"Stun stops maintained healing but retains active enemy field")
	StatusRules.apply_silence(calcium,calcium.units[0],100)
	check(calcium._magical_damage_taken_percent(calcium.units[1])==100,"Silence immediately removes enemy vulnerability")
	var real := fixture(2)
	real.units[0].cell=Vector2i(13,3);real.units[0].sp=80
	SkillRules.activate(real.units[0],op)
	real.units.append(UnitState.new(1,0,"ifrit",Vector2i(13,2),1680,0,0,2))
	real.units.append(UnitState.new(2,1,"bagpipe",Vector2i(12,2),2484,0,100000))
	AuraRules.refresh(real);AttackRules.resolve(real)
	check(real.units[2].hp==2079,"Actual Ifrit line magic receives55percent field damage amplification")
	var pulse := fixture(2)
	pulse.units[0].hp=1;pulse.units[0].sp=80
	pulse.step([InputCommand.new(pulse.tick,1,"",0,Vector2i.ZERO,2)],[])
	for tick in 899:pulse.step([],[])
	check(pulse.units[0].skill_ticks_left==0 and pulse.units[0].skill_activation_count==1,"S3 exactly30seconds expiry")
	var a := fixture(1);var b := fixture(1)
	for state in [a,b]:state.units[0].hp=500
	for tick in 900:
		a.step([],[]);b.step([],[])
		check(a.state_hash()==b.state_hash(),"Healing/suit/SP deterministic replay%d"%tick)
	check(op.attack==485 and op.defense==595,"Resources read-only")
	print("SARIA_CORE_OK" if failures==0 else "SARIA_FAILED count%d"%failures)
	quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["saria"]);var skills := PackedInt32Array([index])
	var state := MatchState.new(202,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state.step([InputCommand.new(0,0,"saria",-1,Vector2i(13,5),-1,2)],[])
	state.units[0].attack_ticks_left=100000
	return state
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
