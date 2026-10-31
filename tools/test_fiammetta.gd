extends SceneTree

var failures := 0
var data := {}
var op: OperatorData


func _initialize() -> void:
	op=load("res://resources/operators/fiammetta.tres");data.fiammetta=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=1000000;dummy.attack=1;dummy.defense=0;dummy.magic_resist=0;dummy.skills[0].sp_recharge_type="on_hit";data.target=dummy
	var base := fixture(0);var actor := base.units[0]
	check(SkillRules.attack_value(actor,op)==1292 and SkillRules.attack_interval_ticks(actor,op)==66,"Full HP initial50% vigor /offskill27AS")
	actor.hp=1000;base.tick=actor.deployed_tick+3;FiammettaRules.maintain(base)
	check(actor.hp==995 and actor.fiammetta_vigor_percent==25,"0.1second currentHP0.5% ceil and25% vigor")
	actor.hp=1;base.tick+=3;FiammettaRules.maintain(base);check(actor.hp==1 and actor.fiammetta_vigor_percent==0,"Nonlethal HP loss floor1")
	actor.hp=1000;actor.silence_ticks_left=10;base.tick+=3;FiammettaRules.maintain(base);check(actor.hp==1000 and actor.fiammetta_vigor_percent==0,"Silence suppresses both talent effects")
	var first := fixture(0);actor=first.units[0];actor.sp=10;actor.attack_ticks_left=0;var foe := enemy(first,Vector2i(18,2));cast(first)
	check(actor.sp==0 and actor.skill_ticks_left==899 and SkillRules.attack_value(actor,op)==2153 and SkillRules.attack_interval_ticks(actor,op)==84,"S1 actual10SP/30seconds/+100% additive attack, offskillAS removed")
	check(foe.hp==1000000-physical(2153),"S1 range extends toforward5")
	var second := fixture(1);actor=second.units[0];foe=enemy(second,Vector2i(17,2));var near := enemy(second,Vector2i(16,3));actor.sp=7;cast(second)
	check(actor.sp==0 and actor.skill_ticks_left==0 and second.fiammetta_explosions.size()==7,"S2 7offensiveSP creates endpoint and six0.66cell marks")
	var expected_due := PackedInt32Array([16,27,30,32,35,37,40])
	for index in 7:check(second.fiammetta_explosions[index].due_tick==expected_due[index],"Exact cumulative30tick quantization field%d"%index)
	actor.attack_ticks_left=100000
	while second.tick<16:second.step([],[])
	check(foe.hp==1000000,"No S2 main damage before15-flight ticks")
	second.step([],[])
	check(foe.hp==1000000-physical(5168) and near.hp==1000000-physical(5168),"S2 endpoint400% current attack, radius1.5 includes diagonal")
	for tick in 24:second.step([],[])
	check(second.fiammetta_explosions.is_empty() and foe.hp<1000000-physical(5168),"Six trail explosions finish at39flight+delay ticks")
	var departed := fixture(1);actor=departed.units[0];foe=enemy(departed,Vector2i(17,2));actor.sp=7;cast(departed);departed._retreat_unit(actor)
	for tick in 40:departed.step([],[])
	check(foe.hp<1000000 and departed.fiammetta_explosions.is_empty(),"Launched S2 trail finishes after actual retreat")
	for facing in 4:
		var third := fixture(2);actor=third.units[0];actor.facing=facing;actor.cell=Vector2i(13,8) if facing==3 else actor.cell;actor.sp=15;actor.attack_ticks_left=0
		var center := actor.cell+AttackRange.rotate_offset(Vector2i(4,0),facing)
		foe=enemy(third,center);near=enemy(third,center+AttackRange.rotate_offset(Vector2i(1,0),facing));var outside := enemy(third,center+AttackRange.rotate_offset(Vector2i(2,0),facing));var diagonal := enemy(third,center+AttackRange.rotate_offset(Vector2i(1,1),facing));cast(third)
		check(actor.sp==0 and actor.skill_ticks_left==-2 and foe.hp==1000000-physical(2842) and near.hp==1000000-physical(2842),"S3 fixed far4 center220percent direction%d"%facing)
		check(outside.hp==1000000-physical(1615) and diagonal.hp==1000000-physical(1615),"S3 outer125percent radius2 vsinner1.1 direction%d"%facing)
		cast(third);check(actor.skill_ticks_left==0 and SkillRules.attack_interval_ticks(actor,op)==66,"S3 actual manual close restores27AS")
	var empty := fixture(2);actor=empty.units[0];actor.sp=15;actor.attack_ticks_left=0;cast(empty)
	check(actor.last_attack_tick==empty.tick-1,"S3 sustained attack fires even without any target")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:enemy(state,Vector2i(17,2));state.units[0].sp=op.skills[index].sp_required;state.units[0].attack_ticks_left=1
		for tick in 500:
			var commands: Array[InputCommand]=[]
			if tick==0:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Replay S%d tick%d"%[index+1,tick])
	print("FIAMMETTA_OK all3skills, offensiveSP,0.1second currentHP loss/vigor, exact fractional delayed trails, independent lifetime,4directions,3x500tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(index: int) -> MatchState:
	var state := MatchState.new(377,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["fiammetta"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"fiammetta",-1,Vector2i(13,2),-1,0)],[])
	check(state.units.size()==1 and state.sides[0].cost==70,"Actual29cost legal deployment")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=100000;return state


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)],[])


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,1000000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func physical(power: int) -> int:
	return Combat.calculate_damage(power,0,0,"physical",0,RNG.new(1),"sniper")


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
