extends SceneTree

var failures := 0
var data := {}
var op: OperatorData
var token_data: OperatorData


func _initialize() -> void:
	op=load("res://resources/operators/pozyomka.tres")
	token_data=load("res://resources/summons/pozyomka_typewriter.tres")
	data.pozyomka=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=100;dummy.magic_resist=0;dummy.skills[0].sp_recharge_type="on_hit";dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	check(op.validation_error().is_empty(),"Pozyomka schema: "+op.validation_error())
	check(token_data.validation_error().is_empty(),"Typewriter schema: "+token_data.validation_error())
	check(op.max_health==1802 and op.attack==876 and op.defense==193 and op.initial_deploy_cost==16 and op.deploy_cost==20,"Original E2 max/no trust/potential/module")
	check(token_data.attack==866 and token_data.deploy_cost==5 and token_data.redeploy_time==40 and token_data.attack_range==[Vector2i.ZERO,Vector2i.RIGHT,Vector2i(2,0),Vector2i(3,0)],"Actual token stats and forward3 range")
	var invalid := op.skills[0].duplicate(true) as SkillResource
	invalid.effect_params.chance_percent=101;check(not invalid.validation_error().is_empty(),"Reject impossible critical probability")
	invalid=op.skills[1].duplicate(true) as SkillResource;invalid.effect_params.charge_count=3;check(not invalid.validation_error().is_empty(),"Reject wrong stored-charge profile")
	for seed_value in [1,4]:
		var crit := fixture(0);var crit_actor := crit.units[0];var crit_target := enemy(crit,Vector2i(15,2))
		crit_actor.skill_ticks_left=-2;crit_actor.attack_ticks_left=1;crit.rng=RNG.new(seed_value)
		var expected_rng := RNG.new(seed_value);var critical := expected_rng.next_u32()%100<40
		crit.step([],[])
		check(crit_target.hp==100000-physical(roundi(1402*2.25) if critical else 1402,100),"S1 exact40%% simulation RNG /225%% currentATK seed%d"%seed_value)
	var first := fixture(0);var actor := first.units[0];var foe := enemy(first,Vector2i(15,2))
	actor.sp=20;actor.attack_ticks_left=1;first.step([],[])
	check(actor.sp==0 and actor.skill_ticks_left==-2 and actor.skill_activation_count==1 and SkillRules.attack_value(actor,op)==1402,"S1 20 attack SP, permanent+60%%")
	var device := deploy_token(first,Vector2i(14,4))
	check(device.skill_ticks_left==-2 and device.typewriter_owner_id==actor.unit_id,"New S1 device shares permanent stance")
	check(not first.enemy_is_targetable(1,device) and not first._apply_damage(device,token_data,9999,"true",foe) and device.hp==500,"Device rejects targeted/direct true damage")
	check(SkillRules.healing_received(device,token_data,200,actor)==0,"Device excluded from ordinary heals")
	var baseline := first.state_hash();device.typewriter_owner_id+=1;check(first.state_hash()!=baseline,"Hash includes token owner");device.typewriter_owner_id-=1
	var burst := fixture(1);actor=burst.units[0]
	actor.sp=18;cast(burst)
	check(actor.sp==18 and actor.skill_activation_count==0,"S2 rejects no normal-range target")
	foe=enemy(burst,Vector2i(15,2));device=deploy_token(burst,Vector2i(14,4));var device_foe := enemy(burst,Vector2i(15,4))
	actor.attack_ticks_left=10000;device.attack_ticks_left=10000
	var old := foe.hp;var device_old := device_foe.hp;cast(burst)
	check(actor.sp==9 and actor.skill_ticks_left==0 and actor.skill_activation_count==1,"S2 actual9 SP /two charge limit")
	check(old-foe.hp==3*physical(2015,100),"Owner S2 actual three230%% hits")
	check(device_old-device_foe.hp==physical(1992,100)+2*physical(1992,82),"Device S2 three230%% hits apply18%% DEF after first")
	check(device_foe.typewriter_defense_remaining_percent==82 and device_foe.typewriter_defense_until_tick==burst.tick-1+120,"Actual token debuff4sec")
	var before := burst.sides[0].cost;burst.step([InputCommand.new(burst.tick,2,"",device.unit_id)],[])
	check(device not in burst.units and burst.sides[0].cost==before and burst.sides[0].cooldowns.pozyomka_typewriter==600,"S2 device retreat no refund; own20sec starts on exit and ticks once")
	for facing in 4:
		var third := fixture(2);actor=third.units[0];actor.facing=facing;actor.sp=35;actor.attack_ticks_left=1
		foe=enemy(third,actor.cell+AttackRange.rotate_offset(Vector2i(3,0),facing));cast(third)
		check(actor.sp==0 and actor.skill_ticks_left==899 and SkillRules.attack_interval_ticks(actor,op)==30,"S3 35SP/30seconds and interval1second direction%d"%facing)
		check(foe.hp==100000-physical(2234,100),"S3 original front3 255%% direction%d"%facing)
		var flank := fixture(2);actor=flank.units[0];actor.facing=facing;actor.sp=35;actor.attack_ticks_left=1;foe=enemy(flank,actor.cell+AttackRange.rotate_offset(Vector2i(2,1),facing));cast(flank)
		check(foe.hp==100000-physical(1752,100),"S3 off-center200%% direction%d"%facing)
	var paired := fixture(2);actor=paired.units[0];device=deploy_token(paired,Vector2i(14,4));foe=enemy(paired,Vector2i(15,4));actor.sp=35;actor.attack_ticks_left=10000;device.attack_ticks_left=1;cast(paired)
	check(device.skill_ticks_left==899 and foe.hp==100000-physical(2208,100),"S3 device synchronized30sec, full255%% own866ATK")
	check(SkillRules.damage_profession_id(token_data)=="sniper","Token inherits sniper PvP factor")
	var adjacent := fixture(0);actor=adjacent.units[0];device=deploy_token(adjacent,Vector2i(12,2));foe=enemy(adjacent,Vector2i(14,2));device.attack_ticks_left=1;adjacent.step([],[])
	check(foe.typewriter_defense_remaining_percent==77,"Four-neighbor device applies original23%% DEF reduction")
	foe.typewriter_defense_until_tick=adjacent.tick;PozyomkaRules.maintain(adjacent)
	check(foe.typewriter_defense_remaining_percent==100 and foe.typewriter_defense_until_tick==0,"Defense debuff restores exactly at expiry")
	var lifetime := fixture(2);actor=lifetime.units[0];device=deploy_token(lifetime,Vector2i(14,4));lifetime.tick=device.deployed_tick+749;PozyomkaRules.maintain(lifetime);check(device in lifetime.units,"Token survives before25sec")
	lifetime.tick+=1;PozyomkaRules.maintain(lifetime);check(device not in lifetime.units and lifetime.sides[0].cooldowns.pozyomka_typewriter==1200,"At25sec removed, own40sec cooldown")
	var exiting := fixture(0);actor=exiting.units[0];device=deploy_token(exiting,Vector2i(14,4));exiting._retreat_unit(actor)
	check(actor not in exiting.units and device not in exiting.units,"Owner actual retreat removes device")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:enemy(state,Vector2i(15,2));state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=1;deploy_token(state,Vector2i(14,4));enemy(state,Vector2i(16,4))
		for tick in 900:
			var commands: Array[InputCommand]=[]
			if tick==0 and index>0:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Replay skill%d tick%d"%[index+1,tick])
	print("POZYOMKA_OK all3skills, token stats/cost/lifetime/cooldown/immunity/owner binding, physical debuff,4facings,3x900tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(index: int) -> MatchState:
	var state := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["pozyomka"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"pozyomka",-1,Vector2i(13,2),-1,0)],[])
	check(state.units.size()==1 and state.units[0].operator_id=="pozyomka" and state.sides[0].cost==79,"Actual legal high deployment deducts20")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=10000;return state


func deploy_token(state: MatchState, cell: Vector2i) -> UnitState:
	var before := state.sides[0].cost
	state.step([InputCommand.new(state.tick,0,"pozyomka_typewriter",-1,cell,-1,0)],[])
	var device: UnitState=null
	for unit in state.units:
		if unit.operator_id=="pozyomka_typewriter":device=unit
	check(device!=null and state.sides[0].cost==before-5,"Token actual5cost deployment outside squad")
	if device!=null:device.attack_ticks_left=10000
	return device


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)],[])


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func physical(power: int, defense: int) -> int:
	return Combat.calculate_damage(power,defense,0,"physical",0,RNG.new(1),"sniper")


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
