extends SceneTree

var failures := 0
var data := {}
var op: OperatorData

func _initialize() -> void:
	op=load("res://resources/operators/chen_alter.tres");data.chen_alter=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.attack=1;dummy.defense=300;dummy.magic_resist=0;data.target=dummy
	var basic := fixture(0);var actor := basic.units[0]
	var front := enemy(basic,Vector2i(14,3));var back := enemy(basic,Vector2i(15,2))
	actor.attack_ticks_left=0;basic.step([],[])
	check(front.hp==100000-physical(1160,300) and back.hp==100000-physical(773,300),"Basic spread all enemies; only front3 gets150percent")
	check(actor.sp==1 and SkillRules.attack_interval_ticks(actor,op)==64,"S1 offensive SP and common terrain AS8")
	actor.sp=op.skills[0].sp_required;actor.attack_ticks_left=0;basic.step([],[])
	check(actor.skill_activation_count==1 and actor.skill_ammo_left in [3,4],"S1 automatic4ammo and own20percent spare")
	check(SkillRules.attack_value(actor,op)==1546,"S1 attack100percent additive")
	for index in [1,2]:
		var state := fixture(index);actor=state.units[0];front=enemy(state,Vector2i(14,3));back=enemy(state,Vector2i(15,2))
		actor.sp=op.skills[index].sp_required;actor.attack_ticks_left=0;cast(state)
		check(actor.skill_ticks_left==-2 and actor.skill_ammo_left in ([7,8] if index==1 else [30,32]),"Manual ammo lifecycle S%d"%(index+1))
		check(front.chen_slime_defense_reduce==(170 if index==1 else 220),"Approved slime fixedDEF S%d"%(index+1))
		check(front.attack_speed_remaining_percent==(65 if index==1 else 55),"Approved slime percentageAS S%d"%(index+1))
		check(back.chen_slime_defense_reduce==0,"Slime excludes high terrain target")
		check(state.chen_slimes.size()==1,"One field perattack, not per S3 shot")
		var old_count := state.chen_slimes.size();actor.attack_ticks_left=100000;cast(state)
		check(actor.skill_ticks_left==0 and actor.skill_ammo_left==0 and state.chen_slimes.size()==old_count,"Manual stop clears ammo but retains released slime")
		state._retreat_unit(actor);check(state.chen_slimes.size()==1,"Slime independent of source exit")
		while state.tick<=151:state.step([],[])
		check(front.chen_slime_defense_reduce==0 and front.attack_speed_remaining_percent==100,"Slime exact5second expiration removes both debuffs")
	var charged := fixture(1);actor=charged.units[0];actor.sp=SkillRules.sp_limit(op.skills[1]);cast(charged)
	check(actor.skill_ammo_left==20 and actor.sp==0,"S2 full charge gives20ammo and clears both charges")
	var broken := fixture(2);actor=broken.units[0];actor.sp=op.skills[2].sp_required;actor.attack_ticks_left=0
	broken.tactical_boxes.append(TacticalBox.new(0,Vector2i(14,3),1));var ball_before := broken.ball.accum
	cast(broken);check(broken.tactical_boxes.is_empty() and broken.ball.accum==ball_before,"S3 breaks box once; secondshot cannot hit remote ball")
	var high := UnitState.new(99,0,"target",Vector2i(15,2),100000,0,100000);high.skill_ammo_left=10
	var sniper := dummy.duplicate(true) as OperatorData;sniper.profession_id="sniper"
	var medic := dummy.duplicate(true) as OperatorData;medic.profession_id="medic"
	charged.rng=RNG.new(1);var expected := RNG.new(1);var spare := expected.next_u32()%100<10
	ChenAlterRules.consume_ammo(charged,high,sniper,1)
	check(high.skill_ammo_left==(10 if spare else 9) and charged.rng.state==expected.state,"Pinned original other-sniper10percent, one RNG draw")
	var random_before := charged.rng.state;high.skill_ammo_left=10
	ChenAlterRules.consume_ammo(charged,high,medic,1)
	check(high.skill_ammo_left==9 and charged.rng.state==random_before,"Other medical ammo gains no sniper talent and no RNG draw")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:enemy(state,Vector2i(14,3));state.units[0].sp=op.skills[index].sp_required;state.units[0].attack_ticks_left=0
		for tick in 600:
			var commands:Array[InputCommand]=[]
			if tick==0 and index>0:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Chen deterministic S%d tick%d"%[index+1,tick])
	print("CHEN_ALTER_OK all3skills, ammo/overcharge/manualclose, original pinned sniper-only spare, spread frontcells, approved slime5sec/localground, boxbreak,3x600tick replay; failures=",failures)
	quit(0 if failures==0 else 1)

func fixture(index:int) -> MatchState:
	var state := MatchState.new(129,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["chen_alter"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"chen_alter",-1,Vector2i(13,2),-1,0)],[])
	check(state.units.size()==1 and state.sides[0].cost==67,"Actual32cost legal high deployment")
	state.platform_cells.append(Vector2i(15,2));state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=100000;return state

func enemy(state:MatchState,cell:Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit

func cast(state:MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)],[])

func physical(power:int,defense:int) -> int:
	return Combat.calculate_damage(power,defense,0,"physical",0,RNG.new(1),"sniper")

func check(condition:bool,message:String) -> void:
	if not condition:failures+=1;push_error(message)
