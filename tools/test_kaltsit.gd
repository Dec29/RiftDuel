extends SceneTree
var failures := 0
var data := {"kaltsit":load("res://resources/operators/kaltsit.tres"),"shining":load("res://resources/operators/shining.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.kaltsit
	var enemy: OperatorData=data.bagpipe.duplicate(true);enemy.operator_id="enemy_fixture";enemy.max_health=100000;enemy.defense=0;enemy.magic_resist=0;enemy.talent_1.effect_type="none";enemy.talent_2.effect_type="none";data.enemy_fixture=enemy
	check(op.validation_error().is_empty() and MatchState.MON3TR_DATA.validation_error().is_empty() and op.attack==490,"Validated owner/token raw data")
	var bound := fixture(1,false)
	for tick in 60:bound.step([],[])
	check(bound.units[0].sp==0 and bound.units[0].sp_regen_ticks==0,"Bound skill cannot charge before token deployment")
	var guard := fixture(0);guard.units[0].sp=20;guard.step([cast(guard,0)],[])
	check(SkillRules.defense_value(guard.units[0],op)==538 and SkillRules.defense_value(guard.units[1],MatchState.MON3TR_DATA)==1013,"S1 self and in-range Mon3tr DEF150percent")
	guard.units[1].cell=Vector2i(15,5);Mon3trRules.refresh_range(guard)
	check(SkillRules.defense_value(guard.units[1],MatchState.MON3TR_DATA)==0,"Outside owner range DEF0 overrides all buffs")
	var heal := fixture(0);heal.units[0].hp=1600;heal.units[1].hp=100;heal.units[0].attack_ticks_left=0
	heal.units.append(UnitState.new(2,0,"enemy_fixture",Vector2i(12,2),1,0,100000));heal.step([],[])
	check(heal.units[1].hp==345 and heal.units[2].hp==1,"Owner prioritizes bound token over lower-HP ordinary ally")
	var tactical := fixture(1);add_enemy(tactical,Vector2i(11,3));tactical.units[0].sp=8;tactical.units[1].attack_ticks_left=0;tactical.step([cast(tactical,1)],[])
	check(tactical.units[2].hp==98934 and SkillRules.attack_interval_ticks(tactical.units[0],op)==43 and tactical.units[1].mon3tr_mode==2,"S2 token2664 raw,40percent guard damage and owner speed100")
	var melt := fixture(2);add_enemy(melt,Vector2i(11,3));melt.units[0].sp=15;melt.units[1].attack_ticks_left=0;melt.step([cast(melt,2)],[])
	check(melt.units[2].hp==97981 and SkillRules.damage_type(melt.units[1],MatchState.MON3TR_DATA)=="true" and SkillRules.defense_value(melt.units[1],MatchState.MON3TR_DATA)==1215,"S3 initial5047 raw true damage,DEF200percent")
	melt.units[0].skill_ticks_left=300;melt.units[0].skill_elapsed_ticks=300;AuraRules.refresh(melt)
	check(SkillRules.attack_value(melt.units[1],MatchState.MON3TR_DATA)==3225,"S3 linear half-duration attack+130percent")
	melt.units[0].skill_ticks_left=1;melt.units[1].attack_ticks_left=10000;melt.units[0].attack_ticks_left=10000;melt.step([],[])
	check(melt.units[1].hp==2716 and melt.units[0].skill_ticks_left==0,"S3 no enemy kill loses half maxHP on expiry")
	var kill := fixture(2);add_enemy(kill,Vector2i(11,3));kill.units[2].hp=1;kill.units[0].sp=15;kill.units[1].attack_ticks_left=0;kill.step([cast(kill,2)],[])
	check(kill.units[1].mon3tr_killed,"Enemy defeat records token kill credit")
	kill.units[0].skill_ticks_left=1;kill.units[1].attack_ticks_left=10000;kill.step([],[]);check(kill.units[1].hp==5433,"Recorded kill suppresses end loss")
	var death := fixture(1);add_enemy(death,Vector2i(11,3));death._apply_damage(death.units[1],MatchState.MON3TR_DATA,99999,"true",death.units[2])
	check(death.units[2].hp==99520 and death.units[2].stun_ticks_left==90 and death.sides[0].cooldowns.mon3tr==750,"Death explodes480 true/stun and starts independent25sec cooldown")
	var retreat := fixture(2);add_enemy(retreat,Vector2i(11,3));retreat._retreat_unit(retreat.units[0]);retreat.step([],[])
	check(retreat.units.size()==1 and retreat.units[0].hp==100000 and retreat.sides[0].cooldowns.mon3tr==749,"Owner retreat withdraws token without death explosion")
	var manual := fixture(1);manual.units[0].sp=8;manual.step([cast(manual,1)],[]);manual._retreat_unit(manual.units[1]);manual.step([],[])
	check(manual.units[0].sp==0 and manual.units[0].skill_ticks_left==0 and manual.sides[0].cooldowns.mon3tr==749,"Token retreat ends binding and clears all SP without explosion")
	var a := fixture(2);var b := fixture(2)
	for state in [a,b]:add_enemy(state,Vector2i(11,3));state.units[0].sp=15;state.units[1].attack_ticks_left=0
	for tick in 650:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(cast(a,2))
		a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Bound-skill/full-duration replay")
	var other_heal := fixture(0);other_heal.units[1].hp=100
	other_heal.units.append(UnitState.new(2,0,"shining",Vector2i(12,2),data.shining.max_health,0,0,1))
	other_heal.step([],[])
	check(other_heal.units[1].hp==100,"Other ordinary medic cannot directly heal Mon3tr")
	var owner_death := fixture(1);add_enemy(owner_death,Vector2i(11,3))
	owner_death._apply_damage(owner_death.units[0],op,99999,"true",owner_death.units[2])
	check(owner_death.units.size()==2 and owner_death.units[1].operator_id=="enemy_fixture" and owner_death.units[1].hp==100000,"Owner defeat immediately withdraws token without explosion")
	var fatal_end := fixture(2);add_enemy(fatal_end,Vector2i(11,3));fatal_end.units[0].sp=15;fatal_end.step([cast(fatal_end,2)],[])
	fatal_end.units[1].hp=100;fatal_end.units[0].skill_ticks_left=1;fatal_end.step([],[])
	check(fatal_end.units.size()==2 and fatal_end.units[1].hp==99520,"Fatal meltdown loss triggers the real death explosion once")
	var external := fixture(2);external.units[0].sp=15;external.step([cast(external,2)],[])
	external.units[1].silence_ticks_left=30;AuraRules.refresh(external)
	check(external.units[1].mon3tr_mode==3,"Token silence leaves external active owner skill effective")
	var discounted := fixture(0,false);discounted.sides[0].next_deploy_discount=5;var cost := discounted.sides[0].cost
	discounted.step([InputCommand.new(discounted.tick,0,"mon3tr",-1,Vector2i(12,3),-1,2)],[])
	check(discounted.sides[0].cost==cost-10 and discounted.sides[0].next_deploy_discount==5,"Token costs10 and neither uses nor consumes ordinary discount")
	print("KALTSIT_CORE_OK" if failures==0 else "KALTSIT_FAILED %d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int,token: bool=true) -> MatchState:
	var ids := PackedStringArray(["kaltsit"]);var skills := PackedInt32Array([index]);var state := MatchState.new(40,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills]);state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state.step([InputCommand.new(0,0,"kaltsit",-1,Vector2i(13,2),-1,2)],[])
	if token:state.step([InputCommand.new(state.tick,0,"mon3tr",-1,Vector2i(12,3),-1,2)],[])
	check(state.units.size()==(2 if token else 1),"Legal token deployment outside squad with owner")
	for unit in state.units:unit.attack_ticks_left=100000
	return state
func add_enemy(state: MatchState,cell: Vector2i) -> void:state.units.append(UnitState.new(state.units.size(),1,"enemy_fixture",cell,100000,0,100000))
func cast(state: MatchState,index: int) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
