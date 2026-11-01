extends SceneTree

var failures := 0
var data := {}
var op: OperatorData


func _initialize() -> void:
	op=load("res://resources/operators/lee.tres");data.lee=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.skills[0].sp_recharge_type="on_hit";dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	check(op.validation_error().is_empty(),"Resource: "+op.validation_error())
	check(op.max_health==2427 and op.attack==789 and op.defense==465 and op.deploy_cost==9 and op.redeploy_time==25,"E2 max stats no trust/potential/module")
	var first := fixture(0);var actor := first.units[0]
	actor.sp=7;first.step([],[])
	check(actor.sp==0 and actor.skill_ticks_left==-2 and SkillRules.attack_value(actor,op)==1262 and SkillRules.dodge_chance(actor,op,"magical")==40 and SkillRules.dodge_chance(actor,op,"physical")==0,"S1 permanent+60%%ATK and40%% magical only dodge")
	var costs := fixture(0);actor=costs.units[0];actor.cost_drain_ticks=89;costs.sides[0].cost=20;costs.sides[0].cost_regen_ticks=0;costs.step([],[])
	check(costs.sides[0].cost==15 and actor.lee_control_charm,"Actual3second drain pays5 and creates one charm")
	var foe := enemy(costs,Vector2i(14,3))
	StatusRules.add_control(costs,actor,"stun",60,foe)
	check(actor.stun_ticks_left==0 and not actor.lee_control_charm and foe.stun_ticks_left==90,"Charm intercepts once and reflects3seconds to real caster")
	StatusRules.add_control(costs,actor,"stun",60,foe)
	check(actor.stun_ticks_left==60,"Second stun lands without charm")
	actor.stun_ticks_left=0;actor.lee_control_charm=true
	check(LeeRules.before_control(costs,actor,"frozen",foe) and not actor.lee_control_charm,"Freeze hook intercepts using exact source")
	actor.lee_control_charm=true;check(LeeRules.before_control(costs,actor,"stun") and not actor.lee_control_charm,"Source-free control consumes guard without inventing caster")
	actor.cost_drain_ticks=89;actor.lee_control_charm=false;costs.sides[0].cost=4;costs.sides[0].cost_regen_ticks=0;costs.step([],[])
	check(costs.sides[0].cost==1 and not actor.lee_control_charm,"Insufficient5 but enough3 pays3, no charm")
	actor.cost_drain_ticks=89;costs.sides[0].cost=2;costs.sides[0].cost_regen_ticks=0;costs.step([],[])
	check(actor not in costs.units and costs.sides[0].cost==2 and costs.sides[0].cooldowns.lee==750,"Insufficient3 actual automatic retreat with25sec cooldown/no refund")
	var aura := fixture(0);actor=aura.units[0];foe=enemy(aura,Vector2i(14,3));AuraRules.refresh(aura)
	check(actor.attack_speed_bonus==28 and foe.attack_speed_bonus==-28,"One enemy within8neighbors doubles both14AS effects")
	var distant := enemy(aura,Vector2i(14,4));AuraRules.refresh(aura)
	check(actor.attack_speed_bonus==14 and foe.attack_speed_bonus==-14 and distant.attack_speed_bonus==0,"Second diagonal enemy disables doubling but not blocking talent")
	var second := fixture(1);actor=second.units[0]
	check(SkillRules.attack_interval_ticks(actor,op)==23,"S2 carried passive+30AS before activation")
	actor.sp=7;cast(second);check(actor.sp==7 and actor.lee_mark_target_id==-1,"S2 requires enemy target")
	foe=enemy(second,Vector2i(14,3));var near := enemy(second,Vector2i(15,3));var diagonal := enemy(second,Vector2i(15,4));actor.attack_ticks_left=10000;cast(second)
	check(actor.sp==0 and actor.lee_mark_target_id==foe.unit_id and actor.lee_mark_until_tick==second.tick-1+150 and LeeRules.target_priority(second,foe),"S2 actual mark/7SP/5second priority")
	check(SkillRules.taunt_level(foe,data.target)==1,"S2 mark uses shared priority for every attack consumer")
	second._apply_damage(foe,data.target,1,"true",actor);check(actor.lee_mark_stacks==1,"Friendly actual damage counts once")
	second._apply_damage(foe,data.target,1,"true",near);check(actor.lee_mark_stacks==1,"Enemy-side damage does not contribute")
	actor.lee_mark_until_tick=second.tick;LeeRules.advance(second)
	check(actor.lee_mark_target_id==-1 and foe.hp==100000-2-magical(2525) and near.hp==100000-magical(2525) and diagonal.hp==100000,"5sec radius1 base300%%+one20%% stack, no diagonals/self feeding")
	var capped := fixture(1);actor=capped.units[0];foe=enemy(capped,Vector2i(14,3));actor.sp=7;cast(capped)
	for index in 29:capped._apply_damage(foe,data.target,1,"true",actor)
	check(actor.lee_mark_target_id>=0 and actor.lee_mark_stacks==29,"Does not explode before30 damage instances")
	capped._apply_damage(foe,data.target,1,"true",actor)
	check(actor.lee_mark_target_id==-1 and foe.hp==100000-30-magical(7101),"30th hit immediately explodes900%%")
	var death := fixture(1);actor=death.units[0];foe=enemy(death,Vector2i(14,3));near=enemy(death,Vector2i(15,3));actor.sp=7;cast(death);foe.hp=1;death._apply_damage(foe,data.target,1,"true",actor)
	check(actor.lee_mark_target_id==-1 and near.hp==100000-magical(2525),"Target fatal hit triggers immediate blast before cleanup")
	var departed := fixture(1);actor=departed.units[0];foe=enemy(departed,Vector2i(14,3));actor.sp=7;cast(departed);departed._retreat_unit(actor)
	check(foe.hp==100000-magical(2367),"Retreat while blocking marker detonates")
	var unblocked := fixture(1);actor=unblocked.units[0];foe=enemy(unblocked,Vector2i(14,3));actor.sp=7;cast(unblocked);foe.cell=Vector2i(15,3);unblocked._retreat_unit(actor)
	check(foe.hp==100000,"Retreat when no longer blocking cancels marker")
	for facing in 4:
		var third := fixture(2);actor=third.units[0];actor.facing=facing;actor.sp=7;actor.attack_ticks_left=1;foe=enemy(third,actor.cell+AttackRange.rotate_offset(Vector2i(1,0),facing));near=enemy(third,actor.cell+AttackRange.rotate_offset(Vector2i(0,1),facing));var previous_cell := near.cell;third.step([],[])
		check(actor.skill_ticks_left==-2 and SkillRules.attack_value(actor,op)==1184 and SkillRules.defense_value(actor,op)==698 and SkillRules.taunt_level(actor,op)==1,"S3 permanent+50%%ATK/DEF/taunt direction%d"%facing)
		check(foe.hp==100000-physical(1184) and near.hp==100000 and near.cell==previous_cell,"S3 only attacks primary, other target force1 equals light weight1 direction%d"%facing)
		var inside_hits := 0;var outside_dodges := 0
		for index in 100:
			if not LeeRules.source_dodges(third,actor,op,foe,"physical"):inside_hits+=1
			near.cell=actor.cell+Vector2i(4,4)
			if LeeRules.source_dodges(third,actor,op,near,"magical"):outside_dodges+=1
		check(inside_hits==100 and outside_dodges>50 and outside_dodges<90,"70%% source-location dodge outside only direction%d"%facing)
		check(not LeeRules.source_dodges(third,actor,op,near,"true"),"S3 true damage never dodges")
	var hashed := fixture(1);actor=hashed.units[0]
	for key in ["lee_mark_target_id","lee_mark_until_tick","lee_mark_stacks"]:
		var previous := hashed.state_hash();actor.set(key,actor.get(key)+1);check(previous!=hashed.state_hash(),"Hash covers "+key)
	var previous := hashed.state_hash();actor.lee_control_charm=true;check(previous!=hashed.state_hash(),"Hash covers charm")
	previous=hashed.state_hash();actor.lee_marked=true;check(previous!=hashed.state_hash(),"Hash covers target priority flag")
	previous=hashed.state_hash();actor.lee_mark_cell=Vector2i.ONE;check(previous!=hashed.state_hash(),"Hash covers marker position")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:enemy(state,Vector2i(14,3));state.units[0].sp=7;state.units[0].attack_ticks_left=1
		for tick in 900:
			var commands: Array[InputCommand]=[]
			if index==1 and tick in [0,300,600]:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Replay S%d tick%d"%[index+1,tick])
	print("LEE_OK all3skills, merchant fee/charm reflection, blockAS, marker/stack/fatal/exit,4facings,source-location dodge,3x900tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(index: int) -> MatchState:
	var state := MatchState.new(317,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["lee"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"lee",-1,Vector2i(13,3),-1,0)],[])
	check(state.units.size()==1 and state.units[0].operator_id=="lee" and state.sides[0].cost==90,"Actual9cost legal ground deployment")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=10000;return state


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)],[])


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func magical(power: int) -> int:
	return Combat.calculate_damage(power,0,0,"magical",0,RNG.new(1),"specialist")


func physical(power: int) -> int:
	return Combat.calculate_damage(power,0,0,"physical",0,RNG.new(1),"specialist")


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
