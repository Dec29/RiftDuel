extends SceneTree

var failures := 0
var data := {}

func _initialize() -> void:
	for id in GuardSpecialistRules.IDS:data[id]=load("res://resources/operators/"+id+".tres")
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.profession_id="caster";dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	for id in GuardSpecialistRules.IDS:check(data[id].validation_error().is_empty(),id+" strict runtime schema: "+data[id].validation_error())
	var requested := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "basic"
	if requested=="shaw":shaw()
	elif requested=="gavial_alter":gavial()
	elif requested=="mlynar":mlynar(false)
	elif requested=="mlynar_full":mlynar(true)
	elif requested=="gladiia":gladiia()
	elif requested=="edges":edges()
	else:shaw();gavial();mlynar(false)
	print("M129_GUARD_SPECIALIST_OK ",requested,"; failures=",failures)
	quit(0 if failures==0 else 1)


func shaw() -> void:
	var op: OperatorData=data.shaw
	check(op.skills.size()==2 and op.max_health==1785 and op.attack==580 and op.defense==365,"Shaw exact E2 stats, only two real skills")
	var state := fixture("shaw",0);var actor := state.units[0]
	check(SkillRules.magic_resist_value(actor,op)==15,"Shaw original fire suit15RES is active in its real talent slot1")
	var target := enemy(state,Vector2i(13,5));var extra := enemy(state,Vector2i(13,6));actor.attack_ticks_left=1;actor.sp=5;state.step([],[])
	check(actor.sp==0 and actor.skill_ticks_left==0 and target.hp==99782 and extra.hp==99782,"S1 actual5SP,150% physical splash to two targets at current25%profession factor")
	check(state.terrain_at(Vector2i(12,8))=="high" and target.cell==Vector2i(11,5) and extra.cell==Vector2i(12,7),"S1 force3-weight1 moves straight2, diagonal stops before high-tile corner: actual %s and %s"%[target.cell,extra.cell])
	var second := fixture("shaw",1);actor=second.units[0];target=enemy(second,Vector2i(12,5));extra=enemy(second,Vector2i(12,6));actor.sp=17;cast(second)
	check(actor.sp==0 and target.hp==99565 and extra.hp==99565,"S2 actual17SP,300%physical radius1 splash")
	var empty := fixture("shaw",1);actor=empty.units[0];actor.sp=17;cast(empty);check(actor.sp==17,"S2 with no enemy/object resets basic clock but does not consume SP")
	var ball := fixture("shaw",1);actor=ball.units[0];actor.sp=17;ball.ball.cell=Vector2i(12,5);cast(ball)
	check(actor.sp==0 and ball.ball.move_direction==Vector2i.LEFT and ball.ball.displacement_steps_left==2,"S2 actual ball uses force3 minus independent BallData weight1")
	StatusRules.apply_silence(state,state.units[0],30);check(SkillRules.magic_resist_value(state.units[0],op)==0,"Shaw silence suspends talent15RES")
	replay("shaw",2,600)


func gavial() -> void:
	var op: OperatorData=data.gavial_alter
	check(op.max_health==2906 and op.attack==766 and op.skills.size()==3,"Gavial exact E2 stats and all3M3skills")
	var state := fixture("gavial_alter",0);var actor := state.units[0];var target := enemy(state,Vector2i(13,5));AuraRules.refresh(state)
	check(SkillRules.attack_value(actor,op)==873 and SkillRules.defense_value(actor,op)==446,"Talent10% plus4% for own blocked target follows shared blocking predicate")
	actor.hp=1000;actor.sp=25;actor.attack_ticks_left=1;cast(state)
	check(actor.sp==0 and actor.skill_ticks_left==749 and SkillRules.attack_value(actor,op)==1486,"S1 actual25SP,25seconds,+80% additiveATK")
	check(target.hp==99406 and actor.hp==1167,"S1 damage40%leech then shared50%healing and lowHP40%received modifier once")
	var high := fixture("gavial_alter",0);actor=high.units[0];actor.hp=2000;LumenRules.treat_amount(high,actor,100,actor);check(actor.hp==2120,"HighHP healing received multiplier120%")
	var second := fixture("gavial_alter",1);actor=second.units[0];target=enemy(second,Vector2i(12,5));actor.sp=35;actor.attack_ticks_left=1;cast(second)
	check(actor.skill_ticks_left==1199 and SkillRules.attack_value(actor,op)==2252 and SkillRules.defense_value(actor,op)==641,"S2 original35SP/40seconds; pulled target becomes blocked and refreshes talent to14%%: ticks%d ATK%d DEF%d"%[actor.skill_ticks_left,SkillRules.attack_value(actor,op),SkillRules.defense_value(actor,op)])
	check(target.cell==Vector2i(13,5),"S2 unblocked target pulled by M125 mediumforce2-weight1 onecell; owner staysfixed")
	var third := fixture("gavial_alter",2);actor=third.units[0];actor.sp=35;cast(third)
	check(actor.skill_ticks_left==749 and SkillRules.block_count_value(actor,op)==5 and SkillRules.attack_interval_ticks(actor,op)==18,"S3 actual35SP/25sec,+100AS,+2block")
	var before := actor.hp;third._apply_damage(actor,op,1000,"true",null,false)
	check(actor.hp==before-500 and actor.gavial_deferred_damage==500,"S3 exact50% damage deferred after shields, including true damage")
	actor.barrier_hp.append(100);actor.barrier_ticks_left.append(900);actor.barrier_defense_percent.append(0);actor.barrier_magic_only.append(0);actor.barrier_magic_resist_add.append(0)
	before=actor.hp;third._apply_damage(actor,op,200,"physical",null,false)
	check(actor.hp==before-50 and actor.gavial_deferred_damage==550,"Already absorbed HP barrier does not enter deferred damage pool")
	actor.skill_ticks_left=1;third.step([],[])
	check(actor.gavial_deferred_damage==0 and actor.gavial_debt_total==550 and actor.gavial_debt_ticks_left==600,"S3 normal end snapshots a20second independent debt")
	actor.nian_shield_layers=2;before=actor.hp
	for tick in 600:third.step([],[])
	check(actor.hp==before-550 and actor.nian_shield_layers==2 and actor.gavial_debt_total==0,"All200 debt pulses repay550 exactly once and bypass HP shields without damage recursion")
	var fatal := fixture("gavial_alter",2);actor=fatal.units[0];actor.gavial_debt_total=200;actor.gavial_debt_ticks_left=600;actor.hp=1
	for tick in 3:fatal.step([],[])
	check(actor.hp<=0 and actor not in fatal.units,"Deferred loss can defeat its owner through normal defeat cleanup")
	replay("gavial_alter",3,1000)


func mlynar(full: bool) -> void:
	var op: OperatorData=data.mlynar
	var state := fixture("mlynar",0);var actor := state.units[0];var target := enemy(state,Vector2i(13,5));actor.attack_ticks_left=1
	for tick in 899:state.step([],[])
	check(actor.mlynar_charge_ticks==900 and SkillRules.attack_value(actor,op)==1065 and SkillRules.block_count_value(actor,op)==0 and target.hp==100000,"Idle liberator reaches+200% in30seconds without attacking/blocking")
	actor.sp=30;actor.attack_ticks_left=1;cast(state)
	check(actor.skill_ticks_left==899 and SkillRules.block_count_value(actor,op)==3 and target.hp==99063 and SkillRules.defense_value(actor,op)==803,"S1 real30SP/30sec,200%physical with110%roamer and60%DEF")
	actor.skill_ticks_left=1;state.step([],[]);check(actor.mlynar_charge_bonus_percent==0 and actor.mlynar_charge_ticks==0,"S1 end resets liberator charge")
	var second := fixture("mlynar",1);actor=second.units[0];actor.mlynar_charge_ticks=900;actor.mlynar_charge_bonus_percent=200;actor.sp=25;target=enemy(second,Vector2i(12,5));actor.attack_ticks_left=0;cast(second)
	check(target.hp==98220 and SkillRules.attack_interval_ticks(actor,op)==45,"S2 two190%hits and original interval+0.3")
	cast(second);check(actor.skill_ticks_left==0 and actor.mlynar_charge_bonus_percent<=1,"S2 sameindex manual close ends skill and resets when no qualifyingkill")
	var surrounded := fixture("mlynar",0);actor=surrounded.units[0];enemy(surrounded,Vector2i(13,5));enemy(surrounded,Vector2i(14,6));enemy(surrounded,Vector2i(15,5))
	check(GuardSpecialistRules.mlynar_attack_percent(surrounded,actor,op)==115 and surrounded._damage_taken_percent(actor,"physical")==85.0,"Exactly3 surrounding enemies upgrades attackscale115% and reduces incoming15%")
	var reflected := fixture("mlynar",0);actor=reflected.units[0];target=enemy(reflected,Vector2i(12,5));reflected._apply_damage(actor,op,100,"physical",target)
	check(target.hp==99979,"Indifference15%rawATK true reflection usesGuard40%factor without recursion")
	if full:
		var third := fixture("mlynar",2);actor=third.units[0];actor.mlynar_charge_ticks=900;actor.mlynar_charge_bonus_percent=200;actor.sp=42;target=enemy(third,Vector2i(13,5));actor.attack_ticks_left=1;cast(third)
		check(actor.mlynar_charge_bonus_percent==400 and actor.skill_ticks_left==839 and target.hp==98509,"S3 traitbonus doubles to400%,180%physical plus12%attribute trueaura")
		var killed := fixture("mlynar",1);actor=killed.units[0];actor.mlynar_charge_ticks=900;actor.mlynar_charge_bonus_percent=200;actor.sp=25;target=enemy(killed,Vector2i(13,5));target.hp=1;actor.attack_ticks_left=0;cast(killed);cast(killed)
		check(actor.mlynar_charge_bonus_percent==200 and actor.mlynar_skill_killed,"Approved direct operator kill preservesS2 charge on manualclose")
	replay("mlynar",3,1000)


func gladiia() -> void:
	var op: OperatorData=data.gladiia
	check(op.max_health==2309 and op.attack==801 and op.group_id=="abyssal","Gladiia original E2 data and actual Abyssal faction")
	var state := fixture("gladiia",0);var actor := state.units[0];actor.hp=1000;actor.gladiia_regen_accum=0
	for tick in 30:state.step([],[])
	check(actor.hp==1028,"Abyssal maximumHP2.5%/s continuous regeneration follows50%and integercarry")
	var target := enemy(state,Vector2i(12,5));actor.attack_ticks_left=1;actor.sp=12;state.step([],[])
	check(actor.sp==8 and actor.skill_ticks_left==149 and target.hp==99453 and target.cell==Vector2i(13,5),"S1 one4SP from3charges,210%plus130%lightweighttalent,force3 pull stopsbeforeowner")
	check(actor.gladiia_hook_ticks_left==150,"S1 character hook locksSP for5seconds")
	var second := fixture("gladiia",1);actor=second.units[0];actor.sp=25;target=enemy(second,Vector2i(12,5));var other := enemy(second,Vector2i(12,6));actor.attack_ticks_left=0;cast(second)
	check(target.hp<100000 and other.hp<100000 and actor.gladiia_hook_ticks_left>0,"S2 actual2targets and character-channel gate")
	var last := actor.last_attack_tick
	for tick in 149:second.step([],[])
	check(actor.last_attack_tick==last,"S2 character hook suppresses next ordinaryattack until5seconds")
	var third := fixture("gladiia",2);actor=third.units[0];actor.sp=35;target=enemy(third,Vector2i(12,5));var near := enemy(third,Vector2i(13,6));cast(third)
	check(target.bind_ticks_left==239 and actor.skill_ticks_left==239 and actor.gladiia_vortex_cell==Vector2i(12,5) and actor.gladiia_vortex_pulses==1,"S3 farthest target bound8s and first independent vortex pulse; command-phase bind includes currenttick: bind%d skill%d cell%s pulses%d"%[target.bind_ticks_left,actor.skill_ticks_left,actor.gladiia_vortex_cell,actor.gladiia_vortex_pulses])
	check(target.hp==99662 and near.hp<100000 and target.gladiia_vortex_slow_remaining_percent==50,"S3 original130%magic pulse, lightweighttalent and approved50%ASslow")
	actor.frozen_ticks_left=100;var before := target.hp
	for tick in 45:third.step([],[])
	check(target.hp<before,"Released vortex pulse continues whileownerfrozen")
	for tick in 225:third.step([],[])
	check(actor.gladiia_vortex_started_tick==-1 and actor.gladiia_vortex_pulses==7,"Vortex lasts9s with6damagepulses and seventhpull-only completion")
	replay("gladiia",3,1000)


func fixture(id: String, index: int) -> MatchState:
	var state := MatchState.new(129,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[[id],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,id,-1,Vector2i(14,5),-1,2)],[])
	check(state.units.size()==1 and state.sides[0].cost==99-data[id].deploy_cost,id+" real legal deployment with exact originalcost")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=100000;return state


func edges() -> void:
	var state := fixture("mlynar",2);var actor := state.units[0];actor.mlynar_charge_ticks=900;actor.mlynar_charge_bonus_percent=200;actor.sp=42;actor.attack_ticks_left=0
	var target := enemy(state,Vector2i(13,5));target.hp=1;cast(state)
	check(actor.mlynar_charge_bonus_percent==390 and actor.mlynar_skill_killed,"Mlynar S3 direct ordinary kill reduces doubled trait bonus by10points")
	state=fixture("mlynar",1);actor=state.units[0];actor.mlynar_charge_ticks=900;actor.mlynar_charge_bonus_percent=200;actor.sp=25;cast(state)
	target=enemy(state,Vector2i(13,5));target.hp=1;state._apply_damage(actor,data.mlynar,100,"physical",target)
	check(target.hp<=0 and not actor.mlynar_skill_killed,"Mlynar reflection defeat does not qualify for skill kill")
	cast(state);check(actor.mlynar_charge_bonus_percent<=1,"Reflection-only kill cannot preserve S2 charge")
	state=fixture("mlynar",1);actor=state.units[0];actor.mlynar_charge_ticks=900;actor.mlynar_charge_bonus_percent=200;actor.sp=25;actor.attack_ticks_left=0
	var summon: OperatorData=data.target.duplicate(true);summon.operator_id="summon_target";summon.profession_id="summon";state._operator_data.summon_target=summon
	target=enemy(state,Vector2i(13,5));target.operator_id="summon_target";target.hp=1;cast(state);check(not actor.mlynar_skill_killed,"Summon defeat does not qualify for S2 preservation")
	state=fixture("gavial_alter",2);actor=state.units[0];actor.sp=35;cast(state);state._apply_damage(actor,data.gavial_alter,200,"true",null,false);actor.skill_ticks_left=1;state.step([],[])
	var before := actor.hp;StatusRules.apply_silence(state,actor,90)
	for tick in 600:state.step([],[])
	check(actor.hp==before-100,"Already deferred Gavial debt repays through silence after active skill ends")
	state=fixture("gladiia",2);actor=state.units[0];actor.sp=35;target=enemy(state,Vector2i(12,5));cast(state);StatusRules.apply_silence(state,actor,90)
	before=target.hp
	for tick in 45:state.step([],[])
	check(target.hp<before,"Already released vortex continues through source silence")
	state.step([InputCommand.new(state.tick,2,"",actor.unit_id)],[]);before=target.hp
	for tick in 90:state.step([],[])
	check(target.hp==before and target.gladiia_vortex_slow_remaining_percent==100,"Source retreat cancels vortex and removes its speed aura")


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var target := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.next_unit_id+=1;state.units.append(target);return target


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,state.units[0].skill_index)],[])


func replay(id: String, count: int, ticks: int) -> void:
	for index in count:
		var a := fixture(id,index);var b := fixture(id,index)
		for state in [a,b]:enemy(state,Vector2i(13,5));enemy(state,Vector2i(12,6));state.units[0].sp=data[id].skills[index].sp_required;state.units[0].attack_ticks_left=1
		for tick in ticks:
			var commands: Array[InputCommand]=[]
			if tick==0 and data[id].skills[index].trigger_type=="manual":commands.append(InputCommand.new(a.tick,1,"",a.units[0].unit_id,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[])
			if a.state_hash()!=b.state_hash():check(false,id+" same-seed/input replay differs S%d tick%d"%[index+1,tick]);break


func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
