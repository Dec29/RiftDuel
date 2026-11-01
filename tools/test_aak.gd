extends SceneTree
var failures := 0
var data := {"aak":load("res://resources/operators/aak.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.aak
	var ally: OperatorData=data.bagpipe.duplicate(true);ally.operator_id="ally_fixture";ally.max_health=100000;ally.defense=0;ally.talent_1.effect_type="none";ally.talent_2.effect_type="none";data.ally_fixture=ally
	check(op.validation_error().is_empty() and op.attack==703 and op.magic_resist==10 and op.terrain_requirement=="high","Raw M3 data and high ground branch")
	var empty := fixture(1);empty.units[0].sp=30;empty.step([cast(empty,1)],[])
	check(empty.units[0].sp==30 and empty.units[0].skill_ticks_left==0,"No eligible friendly target does not consume SP")
	var inject := fixture(1);add_ally(inject);inject.units[0].sp=30;inject.step([cast(inject,1)],[])
	check(inject.units[1].hp==176625 and SkillRules.max_health_value(inject.units[1],ally)==180000 and inject.units[1].aak_buff_ticks==900,"15x125 friendly damage before proportional HP/DEF buff")
	check(SkillRules.defense_value(inject.units[0],op)==274 and SkillRules.max_health_value(inject.units[0],op)==3661,"S2 self DEF/HP80percent")
	inject._retreat_unit(inject.units[0]);inject.step([],[])
	check(inject.units[0].aak_buff_ticks==899 and SkillRules.max_health_value(inject.units[0],ally)==180000,"Recipient buff survives Aak retreat")
	var lethal := fixture(2);add_ally(lethal);lethal.units[1].hp=100;lethal.units[0].sp=35;lethal.step([cast(lethal,2)],[])
	check(lethal.units.size()==1 and SkillRules.attack_value(lethal.units[0],op)==1055 and SkillRules.attack_interval_ticks(lethal.units[0],op)==26,"Friendlyfire can kill; living Aak still gainsS3 buff")
	var shield := fixture(2);add_ally(shield);shield.units[1].barrier_hp=[1000];shield.units[1].barrier_ticks_left=[1000];shield.units[1].barrier_defense_percent=[0];shield.units[1].barrier_magic_only=[0];shield.units[1].barrier_magic_resist_add=[0];shield.units[0].sp=35;shield.step([cast(shield,2)],[])
	check(shield.units[1].hp==99125 and shield.units[1].barrier_hp[0]==0,"Each friendly shot passes barrier independently")
	var loss := fixture(0)
	for tick in 29:loss.step([],[])
	check(loss.units[0].hp==2014,"Exactly1percent maxHP loss per second")
	loss.units[0].hp=1
	for tick in 30:loss.step([],[])
	check(loss.units[0].hp==1,"Trait loss nonlethal at1HP")
	check(SkillRules.healing_received(loss.units[0],op,100)==120,"Received direct healing amplified20percent")
	var a := fixture(0);var b := fixture(0)
	for state in [a,b]:
		state.units[0].attack_ticks_left=0;state.units[0].hp=1000;state.units.append(UnitState.new(1,1,"ally_fixture",Vector2i(12,2),100000,0,100000))
	for tick in 180:
		a.step([],[]);b.step([],[]);check(a.state_hash()==b.state_hash(),"Random drugs replay")
	for proc in 4:
		var sample := fixture(0)
		sample.units[0].hp=1000;sample.units[0].attack_ticks_left=0
		sample.units.append(UnitState.new(1,1,"ally_fixture",Vector2i(12,2),100000,0,100000))
		for seed in range(1,100):
			var candidate := RNG.new(seed)
			if candidate.next_u32()%4==proc:sample.rng=RNG.new(seed);break
		sample.step([],[])
		check(sample.units[1].hp==(99736 if proc==1 else 99824),"Each random drug's actual attack damage")
		if proc==0:check(sample.units[0].hp==1184,"Self-heal uses50percent PvP then received120percent")
		elif proc==2:check(sample.units[1].slow_ticks_left==42 and SkillRules.attack_interval_ticks(sample.units[1],ally)==roundi(ally.attack_interval*30),"Slow marker does not change attack speed")
		elif proc==3:check(sample.units[1].stun_ticks_left==30,"Random stun exact duration")
	for facing in 4:
		var priority := fixture(1);priority.units[0].facing=facing
		priority.units.append(UnitState.new(1,0,"ally_fixture",priority.units[0].cell+AttackRange.rotate_offset(Vector2i(1,1),facing),100000,0,100000))
		priority.units.append(UnitState.new(2,0,"ally_fixture",priority.units[0].cell+AttackRange.rotate_offset(Vector2i(2,0),facing),100000,0,100000))
		check(AakRules.friendly_target(priority,priority.units[0],op).unit_id==2,"Front line has priority over closer diagonal in four facings")
	var silence := fixture(0);silence.units[0].silence_ticks_left=100
	for tick in 29:silence.step([],[])
	check(silence.units[0].hp==2014,"Silence does not disable geek branch life loss")
	print("AAK_CORE_OK" if failures==0 else "AAK_FAILED %d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["aak"]);var skills := PackedInt32Array([index]);var state := MatchState.new(20,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state.step([InputCommand.new(0,0,"aak",-1,Vector2i(13,2),-1,2)],[]);state.units[0].attack_ticks_left=100000;return state
func add_ally(state: MatchState) -> void:state.units.append(UnitState.new(1,0,"ally_fixture",Vector2i(12,2),100000,0,100000))
func cast(state: MatchState,index: int) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
