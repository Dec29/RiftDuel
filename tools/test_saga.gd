extends SceneTree
var failures := 0
var data := {"saga":load("res://resources/operators/saga.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres"),"angelina":load("res://resources/operators/angelina.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.saga
	check(op.validation_error().is_empty() and op.attack==530 and op.max_health==2205 and op.skills.size()==3,"Saga rawE2/M3 and3skills")
	var enemy: OperatorData=data.bagpipe.duplicate(true);enemy.operator_id="enemy_fixture";enemy.max_health=100000;enemy.defense=0;enemy.talent_1.effect_type="none";enemy.talent_2.effect_type="none";data.enemy_fixture=enemy
	var state := fixture(0);var target := add_enemy(state,100)
	state._apply_damage(target,enemy,999,"physical",state.units[0])
	check(target.hp==1 and target.critical_ticks_left==300 and SkillRules.block_count_value(target,enemy)==0,"Fatal hit leaves1HP and10second zero-block wound")
	check(SkillRules.attack_interval_ticks(target,enemy)==150,"Wound reduces final attackspeed80percent")
	target.attack_speed_bonus=100
	check(SkillRules.attack_interval_ticks(target,enemy)==75 and SkillRules.healing_received(target,enemy,100)==0,"Final speed factor also covers buffs, no direct healing")
	state.units.append(UnitState.new(2,1,"angelina",Vector2i(0,0),1000,0,100000))
	StatusRules.regenerate(state)
	check(target.hp==1,"Global continuous recovery cannot heal wounded")
	state.units[0].attack_ticks_left=0;state.step([],[])
	check(state.units[0].last_attack_tick<0 and target.hp==1,"Saga ordinary attack skips critically wounded unit")
	var normal_death := fixture(0);var doomed := add_enemy(normal_death,1);normal_death._apply_damage(doomed,enemy,1,"physical",normal_death.units[0]);normal_death.units[0].sp=0
	for tick in 300:normal_death.step([],[])
	check(normal_death.units.size()==1 and normal_death.units[0].sp==10,"Natural10second death gives no killSP, only10 naturalSP")
	var reward := fixture(0);var marked := add_enemy(reward,1);reward._apply_damage(marked,enemy,1,"physical",reward.units[0]);var killer := UnitState.new(2,0,"bagpipe",Vector2i(13,4),1000,0,100000);reward.units.append(killer);reward._apply_damage(marked,enemy,1,"true",killer)
	check(marked.hp<=0 and killer.sp==2,"Other source receives2SP for wound kill")
	var blocked_reward := fixture(0);var marked2 := add_enemy(blocked_reward,1);blocked_reward._apply_damage(marked2,enemy,1,"physical",blocked_reward.units[0]);var busy := UnitState.new(2,0,"bagpipe",Vector2i(13,4),1000,0,100000);busy.skill_ticks_left=10;blocked_reward.units.append(busy);blocked_reward._apply_damage(marked2,enemy,1,"true",busy)
	check(busy.sp==0,"Active skill blocks killSP reward")
	var purge := fixture(1);var victim := add_enemy(purge,100);purge.units[0].sp=39;purge.sides[0].cost=0;purge.step([cast(purge,1)],[])
	check(purge.units[0].sp==26 and purge.sides[0].cost==4 and victim.hp==1 and victim.critical_execute_tick==22,"S2 costs one of3charges, grants4DP and queues0.7s execution")
	for tick in 20:purge.step([],[])
	check(victim.hp==1,"Execution does not happen early")
	purge.step([],[])
	check(victim.hp==0 and purge.units[0].sp==28,"Execution at21ticks grants Saga2SP")
	var fury := fixture(2);var low := add_enemy(fury,49999);fury.units[0].sp=40;fury.units[0].attack_ticks_left=0;fury.step([cast(fury,2)],[])
	check(low.hp==49389 and SkillRules.attack_interval_ticks(fury.units[0],op)==47 and SkillRules.attack_output_value(fury.units[0],op)==1219,"S3 raw1219, added0.5s and two305hits below halfHP")
	var cost := fixture(2);cost.sides[0].cost=0;cost.units[0].sp=40;cost.step([cast(cost,2)],[])
	for tick in 599:cost.step([],[])
	check(cost.sides[0].cost==40 and cost.units[0].skill_ticks_left==0,"S3 exactly20DP over20s plus20 naturalDP")
	var focus := fixture(0);var source := focus.units[0];source.hp=881;SagaRules.trigger_focus(focus,source,op)
	check(source.saga_focus_used and source.saga_focus_ticks==450 and SkillRules.dodge_chance(source,op,"physical")==70,"Focus triggers once strictly below40percent")
	StatusRules.regenerate(focus);check(source.hp==882,"5percent regen receives50percent PvP scale with integer remainder")
	source.silence_ticks_left=3;var before := source.hp;StatusRules.regenerate(focus)
	check(source.hp==before and SkillRules.dodge_chance(source,op,"physical")==0,"Silence pauses focus effects")
	source.saga_focus_ticks=0;source.silence_ticks_left=0;SagaRules.trigger_focus(focus,source,op)
	check(source.saga_focus_ticks==0,"Focus cannot trigger twice on same deployment")
	var edge := fixture(0);var almost := add_enemy(edge,101)
	edge._apply_damage(almost,data.enemy_fixture,100,"physical",edge.units[0])
	check(almost.hp==1 and almost.critical_ticks_left==0,"Nonfatal hit naturally leaving1HP must not mark critical wound")
	var a := fixture(1);var b := fixture(1)
	for replay in [a,b]:add_enemy(replay,100);replay.units[0].sp=39
	for tick in 360:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(cast(a,1))
		a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Saga wound/execution seeded per-tick replay")
	print("SAGA_CORE_OK" if failures==0 else "SAGA_FAILED %d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["saga"]);var skills := PackedInt32Array([index]);var state := MatchState.new(10,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills]);state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"saga",-1,Vector2i(13,5),-1,2)],[]);state.units[0].attack_ticks_left=100000;return state
func add_enemy(state: MatchState,hp: int) -> UnitState:
	var unit := UnitState.new(state.units.size(),1,"enemy_fixture",Vector2i(12,5),hp,0,100000);state.units.append(unit);return unit
func cast(state: MatchState,index: int) -> InputCommand:return InputCommand.new(state.tick,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
