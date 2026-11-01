extends SceneTree

var failures := 0
var data := {}
var op: OperatorData


func _initialize() -> void:
	op=load("res://resources/operators/carnelian.tres");data.carnelian=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	check(op.validation_error().is_empty() and op.max_health==2106 and op.attack==846 and op.defense==228 and op.magic_resist==15 and op.skills.size()==3,"Original E2/no trust/potential/module, three M3 skills")
	var resting := fixture(0);var actor: UnitState=resting.units[0];var primary := enemy(resting,Vector2i(15,2));actor.attack_ticks_left=1;resting.step([],[])
	check(primary.hp==100000 and actor.attack_ticks_left==1 and SkillRules.defense_value(actor,op)==684 and SkillRules.magic_resist_value(actor,op)==35,"Idle phalanx does not attack;200%DEF and20RES")
	StatusRules.apply_silence(resting,actor,60)
	check(SkillRules.defense_value(actor,op)==684 and SkillRules.magic_resist_value(actor,op)==35,"Branch idle defenses survive silence")
	for enhanced in [false,true]:
		var first := fixture(0);actor=first.units[0];actor.hp=1000;actor.sp=36 if enhanced else 18;actor.attack_ticks_left=1;primary=enemy(first,Vector2i(15,2));var other := enemy(first,Vector2i(12,3));cast(first)
		check(actor.sp==0 and actor.carnelian_charged==enhanced and actor.skill_ticks_left==599,"S1 actual SP consumed completely,20second skill")
		check(actor.hp==(1842 if enhanced else 1421),"Actual cast heals original80/40percent under current healing factor")
		check(SkillRules.attack_value(actor,op)==1354 and primary.hp==100000-damage(1354) and other.hp==100000-damage(1354),"S1 actual range-wide magic attacks and inherited caster factor")
		check(SkillRules.defense_value(actor,op)==(912 if enhanced else 456) and SkillRules.magic_resist_value(actor,op)==(35 if enhanced else 15),"Only charged S1 retains trait; defense bonuses add")
		actor.skill_ticks_left=1;first.step([],[])
		check(SkillRules.defense_value(actor,op)==684 and SkillRules.magic_resist_value(actor,op)==35,"S1 end restores idle defenses")
	var partial := fixture(0);actor=partial.units[0];actor.sp=35;cast(partial)
	check(actor.sp==0 and not actor.carnelian_charged,"Partial second stage35/36 is uncharged; consumes all35SP")
	for enhanced in [false,true]:
		var second := fixture(1);actor=second.units[0];actor.sp=50 if enhanced else 25;actor.attack_ticks_left=1;primary=enemy(second,Vector2i(15,2));cast(second)
		check(actor.sp==0 and actor.skill_ticks_left==749 and actor.carnelian_charged==enhanced and SkillRules.attack_interval_ticks(actor,op)==27,"S2 actual cast consumes allSP,25seconds and0.9second interval")
		check(SkillRules.attack_value(actor,op)==(1015 if enhanced else 846) and primary.hp==100000-damage(1015 if enhanced else 846),"Only charged S2 grants20%ATK")
		check(primary.bind_ticks_left==(18 if enhanced else 0) and primary.slow_ticks_left==(0 if enhanced else 9),"Charged0.6second bind replaces normal0.3second slow")
		StatusRules.apply_silence(second,actor,60);var hp := primary.hp;actor.attack_ticks_left=1;second.step([],[])
		check(primary.hp==hp and SkillRules.defense_value(actor,op)==228 and SkillRules.magic_resist_value(actor,op)==15,"Silenced active skill cannot attack or regain idle-only defenses")
	var charge := fixture(0);actor=charge.units[0];actor.sp=18;actor.sp_regen_ticks=0;actor.sp_regen_accum=0
	for tick in 150:charge.step([],[])
	check(actor.sp==26 and actor.sp_regen_ticks==0 and actor.sp_regen_accum==0,"Second-stage SP: original1+0.6/s gives exact8 in5seconds")
	for tick in 1000:charge.step([],[])
	check(actor.sp==36,"Actual second-stage cap36")
	var muted := fixture(0);actor=muted.units[0];actor.sp=18;actor.sp_regen_ticks=0;actor.sp_regen_accum=0;StatusRules.apply_silence(muted,actor,180)
	for tick in 150:muted.step([],[])
	check(actor.sp==23,"Silence stops0.6 talent but preserves base natural1SP/s")
	var first_stage := fixture(0);actor=first_stage.units[0];actor.sp=0;actor.sp_regen_ticks=0;actor.sp_regen_accum=0
	for tick in 150:first_stage.step([],[])
	check(actor.sp==5,"First stage receives no extra talent SP")
	var third := fixture(2);actor=third.units[0];actor.sp=56;actor.attack_ticks_left=1;primary=enemy(third,Vector2i(15,3));cast(third)
	check(actor.sp==0 and actor.skill_ticks_left==629 and actor.carnelian_charged and primary.carnelian_mark_stacks==1 and primary.carnelian_mark_owner_id==actor.unit_id,"S3 actual full charge,21seconds and expanded corner target")
	check(primary.hp==100000-damage(846,120),"First charged mark applies20% before first hit")
	actor.attack_ticks_left=10000
	for tick in 29:third.step([],[])
	check(SkillRules.attack_value(actor,op)==964,"Ramp first +14% at one second, not continuous per-tick growth")
	actor.skill_elapsed_ticks=599;check(SkillRules.attack_value(actor,op)==3096,"Ramp at19seconds is266%")
	actor.skill_elapsed_ticks=600;check(SkillRules.attack_value(actor,op)==3215,"Ramp reaches280% at20seconds")
	actor.skill_elapsed_ticks=30
	for index in 6:
		actor.attack_ticks_left=1;third.step([],[])
	check(primary.carnelian_mark_stacks==5,"Only five stacks despite repeated hits")
	actor.skill_ticks_left=1;third.step([],[]);third.step([],[])
	check(primary.carnelian_mark_stacks==0 and primary.carnelian_mark_owner_id==-1 and SkillRules.defense_value(actor,op)==684,"Marks removed at skill end, idle restored")
	var normal := fixture(2);actor=normal.units[0];actor.sp=28;actor.attack_ticks_left=1;primary=enemy(normal,Vector2i(15,3));cast(normal)
	check(primary.hp==100000-damage(846) and primary.carnelian_mark_owner_id==-1,"Uncharged S3 has ramp/range but no mark")
	var departed := fixture(2);actor=departed.units[0];actor.sp=56;actor.attack_ticks_left=1;primary=enemy(departed,Vector2i(15,3));cast(departed)
	departed.step([InputCommand.new(departed.tick,2,"",actor.unit_id)],[])
	check(primary.carnelian_mark_owner_id==-1 and primary.carnelian_mark_stacks==0,"Actual source retreat cleans source-owned mark")
	for facing in 4:
		var rotated := fixture(2);actor=rotated.units[0];actor.facing=facing;actor.sp=28;actor.attack_ticks_left=1;primary=enemy(rotated,actor.cell+AttackRange.rotate_offset(Vector2i(2,1),facing));var outside := enemy(rotated,actor.cell+AttackRange.rotate_offset(Vector2i(2,2),facing));cast(rotated)
		check(primary.hp<100000 and outside.hp==100000,"Expanded range respects original diagram facing%d"%facing)
	var objects := fixture(0);actor=objects.units[0];actor.sp=18;actor.attack_ticks_left=1;objects.tactical_boxes=[TacticalBox.new(0,Vector2i(15,2),3)];cast(objects)
	check(objects.tactical_boxes[0].hits_left==2,"Active phalanx attacks actual box once")
	var ball := fixture(0);actor=ball.units[0];actor.sp=18;actor.attack_ticks_left=1;ball.ball.cell=Vector2i(15,2);cast(ball)
	check(actor.last_attack_tick==1 and actor.sp==0,"Active phalanx actual ball attack and skill activation")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:enemy(state,Vector2i(15,2));state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=1
		for tick in 850:
			var commands: Array[InputCommand]=[]
			if tick==0:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Everytick replay S%d tick%d"%[index+1,tick])
	var hashed := fixture(0)
	for key in ["carnelian_mark_owner_id","carnelian_mark_stacks","carnelian_mark_until_tick"]:
		var previous := hashed.state_hash();hashed.units[0].set(key,hashed.units[0].get(key)+1);check(previous!=hashed.state_hash(),"Hash includes "+key)
	var previous := hashed.state_hash();hashed.units[0].carnelian_charged=true;check(previous!=hashed.state_hash(),"Hash includes charge-stage boolean")
	print("CARNELIAN_OK all3 skills normal/charged, actual deployment/cost/SP, both talents, phalanx trait, marks/lifecycle,3x850tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(index: int) -> MatchState:
	var state := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["carnelian"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"carnelian",-1,Vector2i(13,2),-1,0)],[])
	check(state.units.size()==1 and state.units[0].operator_id=="carnelian" and state.sides[0].cost==75,"Controlled99 actual legal high-tile deployment deducts24")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=10000;return state


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,state.units[0].skill_index)],[])


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func damage(value: int, amplification: int = 100) -> int:
	return Combat.calculate_damage(value,0,0,"magical",0,RNG.new(1),"caster",amplification)


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
