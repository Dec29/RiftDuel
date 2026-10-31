extends SceneTree
var failures := 0
var data := {}

func _initialize() -> void:
	data.hellagur=load("res://resources/operators/hellagur.tres")
	data.myrtle=load("res://resources/operators/myrtle.tres")
	data.shining=load("res://resources/operators/shining.tres")
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;data.target=dummy
	var op: OperatorData=data.hellagur
	check(op.validation_error().is_empty(),"Resource: "+op.validation_error())
	check(op.skills.size()==3 and op.max_health==3825 and op.attack==762 and op.defense==334 and op.skills[1].duration==13.0,"Original raw stats and actual skill values")
	var regen := fixture(0)
	for t in 30:regen.step([],[])
	check(regen.units[0].hp==1030,"Unblocked60HP/s folded50%=30")
	StatusRules.apply_silence(regen,regen.units[0],60)
	for t in 30:regen.step([],[])
	check(regen.units[0].hp==1030 and regen.units[0].attack_speed_bonus==0,"Silence pauses talents, not trait")
	var blocking := fixture(0)
	add_enemy(blocking,Vector2i(13,5))
	for t in 30:blocking.step([],[])
	check(blocking.units[0].hp==1000 and blocking.enemy_is_blocked(blocking.units[1],0),"Own public blocking predicate stops regeneration")
	blocking.units[1].cell=Vector2i(16,5)
	blocking.units.append(UnitState.new(2,0,"target",Vector2i(17,5),100000,0,10000));blocking.next_unit_id=3
	for t in 30:blocking.step([],[])
	check(blocking.units[0].hp==1030 and blocking.enemy_is_blocked(blocking.units[1]) and not blocking.enemy_is_blocked(blocking.units[1],0),"Another ally blocking does not stop Hellagur regen")
	var speed := fixture(0);add_enemy(speed,Vector2i(13,5));speed.units[0].hp=1147
	for t in 7:speed.step([],[])
	check(speed.units[0].musha_attack_speed==0,"No premature quarter-second sample")
	speed.step([],[])
	check(speed.units[0].musha_attack_speed==100 and speed.units[0].musha_speed_accum==2 and SkillRules.attack_interval_ticks(speed.units[0],op)==18,"First sample8tick, capped100ASPD at30%HP")
	speed.units[0].hp=3825
	for t in 7:speed.step([],[])
	check(speed.units[0].musha_attack_speed==0 and speed.units[0].musha_speed_accum==0 and SkillRules.attack_interval_ticks(speed.units[0],op)==36,"Next sample7tick, fullHP restores36tick")
	var first := fixture(0);add_enemy(first,Vector2i(13,5));first.units[0].sp=2;first.units[0].attack_ticks_left=1
	first.step([],[])
	check(first.units[1].hp==98932 and first.units[0].hp==1070 and first.units[0].skill_ticks_left==0 and first.units[0].sp==0,"S1 two175% hits, per-damage35heal, no chargeSP refund")
	var second := fixture(1);add_enemy(second,Vector2i(13,5));second.units[0].sp=25;second.units[0].attack_ticks_left=1
	second.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	check(second.units[1].hp==98902 and second.units[0].hp==1070 and second.units[0].skill_ticks_left==389,"S2 ATK80/additive two hits,390tick")
	check(SkillRules.dodge_chance(second.units[0],op,"physical")==75 and SkillRules.dodge_chance(second.units[0],op,"magical")==0,"S2 physical dodge only")
	second.units[0].skill_ticks_left=1;second.step([],[])
	check(SkillRules.dodge_chance(second.units[0],op,"physical")==0 and SkillRules.attack_value(second.units[0],op)==762,"Expiry removes dodge/ATK")
	for facing in 4:
		var third := fixture(2);third.units[0].facing=facing;third.units[0].sp=35;third.units[0].attack_ticks_left=1
		for x in [1,2,3]:add_enemy(third,Vector2i(12,5)+AttackRange.rotate_offset(Vector2i(x,0),facing))
		third.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
		check(third.units[0].hp==1105 and third.units[1].hp==99390 and third.units[2].hp==99390 and third.units[3].hp==99390,"S3 extended3,3targets,each35heal facing%d"%facing)
	var objects := fixture(0);objects.units[0].sp=2;objects.units[0].attack_ticks_left=1;objects.ball.cell=Vector2i(13,5)
	objects.step([],[])
	check(objects.units[0].hp==1001 and objects.ball.move_ticks_left>0,"Ball two pushes but no trait heal (only idle1HP)")
	var boxes := fixture(0);boxes.units[0].sp=2;boxes.units[0].attack_ticks_left=1;boxes.tactical_boxes=[TacticalBox.new(0,Vector2i(13,5),3)]
	boxes.step([],[])
	check(boxes.tactical_boxes[0].hits_left==1 and boxes.units[0].hp==1001,"S1 box two hits, no enemy self-heal")
	var heal := fixture(0);heal.units[0].silence_ticks_left=90
	heal.units.append(UnitState.new(1,0,"myrtle",Vector2i(13,5),1565,24,1,0,1));heal.next_unit_id=2
	heal.step([InputCommand.new(0,1,"",1,Vector2i.ZERO,1)],[])
	check(heal.units[0].hp==1000 and heal.units[1].last_attack_tick<0 and SkillRules.healing_received(heal.units[0],op,100)==0,"Musha cannot be selected or receive external direct healing")
	var a := fixture(1);var b := fixture(1)
	for state in [a,b]:add_enemy(state,Vector2i(13,5));state.units[0].sp=25;state.units[0].attack_ticks_left=1
	for t in 600:
		var commands: Array[InputCommand]=[]
		if t==0:commands.append(InputCommand.new(0,1,"",0,Vector2i.ZERO,1))
		a.step(commands,[]);b.step(commands,[])
		check(a.state_hash()==b.state_hash(),"Everytick hash replay %d"%t)
	for field in ["musha_speed_accum","musha_attack_speed"]:
		var before := a.state_hash();a.units[0].set(field,a.units[0].get(field)+1);check(before!=a.state_hash(),"Hash includes "+field)
	a._retreat_unit(a.units[0]);check(a.units.size()==1,"Retreat drops own runtime")
	var fresh := UnitState.new(5,0,"hellagur",Vector2i(12,5),3825,15,36,0,1)
	check(fresh.musha_attack_speed==0 and fresh.musha_speed_accum==0 and fresh.skill_ticks_left==0,"Redeploy runtime starts clean")
	print("Hellagur focused failures=",failures);quit(0 if failures==0 else 1)

func fixture(index: int) -> MatchState:
	var s := MatchState.new(188,data);s.ball.cell=Vector2i(5,5);s.units=[UnitState.new(0,0,"hellagur",Vector2i(12,5),1000,0,10000,0,index)];s.next_unit_id=1;return s
func add_enemy(s: MatchState, cell: Vector2i) -> void:
	s.units.append(UnitState.new(s.next_unit_id,1,"target",cell,100000,0,10000));s.next_unit_id+=1
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
