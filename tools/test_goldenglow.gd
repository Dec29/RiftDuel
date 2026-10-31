extends SceneTree

var failures := 0
var data := {}
var op: OperatorData

func _initialize() -> void:
	op=load("res://resources/operators/goldenglow.tres");data.goldenglow=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.attack=1;dummy.defense=0;dummy.magic_resist=50;data.target=dummy
	var state := fixture(0);var actor := state.units[0];var foe := enemy(state,Vector2i(14,3))
	actor.attack_ticks_left=0;state.step([],[])
	check(foe.hp==100000-magic(331)-magic(66),"Normal331 main and20percent float both ignore15RES")
	check(actor.golden_trait_hits[0]==1,"Normal attached float first hit records ramp1")
	for index in 6:actor.attack_ticks_left=0;state.step([],[])
	var hp := foe.hp;actor.attack_ticks_left=0;state.step([],[])
	check(hp-foe.hp==magic(331)+magic(364),"Attached same-target float capped110percent")
	foe.hp=0;var other := enemy(state,Vector2i(15,2));actor.attack_ticks_left=0;state.step([],[])
	check(other.hp==100000-magic(331)-magic(66) and actor.golden_trait_hits[0]==1,"New target resets float20percent")
	var released := fixture(0);actor=released.units[0];foe=enemy(released,Vector2i(14,3));actor.sp=35;released.rng=RNG.new(1);cast(released)
	check(actor.skill_ticks_left==749 and SkillRules.attack_value(actor,op)==463 and SkillRules.attack_interval_ticks(actor,op)==26,"S1 actual25seconds ATK40 AS50")
	check(actor.golden_target_ids[0]==foe.unit_id and actor.golden_target_ids[1]==foe.unit_id and actor.golden_target_ids[2]==GoldenglowRules.NO_TARGET,"S1 two independent released units")
	foe.cell=Vector2i(2,9);hp=foe.hp;actor.stun_ticks_left=100;actor.frozen_ticks_left=100
	actor.golden_cooldowns=PackedInt32Array([0,0,0]);released.step([],[])
	check(foe.hp<hp,"Released locks pursue outside base range while source stunned/frozen")
	actor.golden_explosion_stacks[0]=40;actor.golden_cooldowns[0]=0;actor.golden_cooldowns[1]=1000;hp=foe.hp
	released.step([],[])
	check(hp-foe.hp==magic(1389) and actor.golden_explosion_stacks[0]==1 and actor.golden_target_ids[0]==GoldenglowRules.NO_TARGET,"Forced300percent explosion ignores float ramp and returns only its unit")
	actor.silence_ticks_left=10;var before := released.rng.state;hp=foe.hp;actor.golden_cooldowns[0]=0;released.step([],[])
	check(foe.hp==hp and released.rng.state==before,"Silence pauses skill units and draws no explosion RNG")
	var permanent := fixture(1);actor=permanent.units[0];actor.sp=70;foe=enemy(permanent,Vector2i(14,4));permanent.step([],[]);permanent.step([],[])
	check(actor.skill_ticks_left==-2 and SkillRules.attack_value(actor,op)==530 and actor.golden_target_ids[0]==foe.unit_id,"S2 actual automatic permanent ATK60 and enlarged range")
	var global_state := fixture(2);actor=global_state.units[0];foe=enemy(global_state,Vector2i(2,9));actor.sp=55;cast(global_state)
	check(actor.skill_ticks_left==899 and actor.golden_target_ids[2]==foe.unit_id and foe.hp<100000 and foe.slow_ticks_left>0,"S3 three units global enemy acquisition and stop mark")
	check(actor.attack_ticks_left>1000,"S3 stops ordinary body attack")
	var objects := fixture(2);actor=objects.units[0];actor.sp=55;cast(objects)
	objects.tactical_boxes.append(TacticalBox.new(0,Vector2i(2,2),3));objects.ball.cell=Vector2i(2,9)
	GoldenglowRules.advance_released(objects)
	check(objects.tactical_boxes[0].hits_left==3 and objects.ball.accum==Vector2i.ZERO,"S3 cannot globally attack box or ball")
	objects.ball.cell=Vector2i(14,3);GoldenglowRules.advance_released(objects)
	check(objects.ball.accum!=Vector2i.ZERO,"S3 can acquire ball in base range")
	var field_hash := objects.state_hash();actor.golden_cooldowns[0]+=1
	check(objects.state_hash()!=field_hash,"Independent unit clocks participate in deterministic hash")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for replay in [a,b]:enemy(replay,Vector2i(14,3));replay.units[0].sp=op.skills[index].sp_required
		for tick in 600:
			var commands:Array[InputCommand]=[]
			if tick==0 and index!=1:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Goldenglow replay S%d tick%d"%[index+1,tick])
	print("GOLDENGLOW_OK all3skills, attached ramp/resistignore, released independent locks/cooldowns/explosions, stun/frozen/silence, global enemy/localobjects,3x600tick replay; failures=",failures)
	quit(0 if failures==0 else 1)

func fixture(index:int) -> MatchState:
	var ball := MatchState.DEFAULT_BALL_DATA.duplicate(true) as BallData;ball.kick_threshold=1000000000
	var state := MatchState.new(377,data,ball,MatchState.DEFAULT_ARENA,[["goldenglow"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"goldenglow",-1,Vector2i(13,2),-1,0)],[])
	check(state.units.size()==1 and state.sides[0].cost==77,"Actual22cost legal high deployment")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=100000;return state

func enemy(state:MatchState,cell:Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit

func cast(state:MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)],[])

func magic(power:int) -> int:
	return Combat.calculate_damage(power,0,35,"magical",0,RNG.new(1),"caster")

func check(condition:bool,message:String) -> void:
	if not condition:failures+=1;push_error(message)
