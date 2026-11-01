extends SceneTree
var failures := 0
var data := {}
func _initialize() -> void:
	data.meteorite=load("res://resources/operators/meteorite.tres")
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=10000;dummy.defense=0;data.target=dummy
	var op: OperatorData=data.meteorite
	check(op.validation_error().is_empty() and op.skills.size()==2 and op.attack==865 and op.max_health==1505,"Original E2 values and two skills: "+op.validation_error())
	for facing in 4:
		var s := fixture(0);s.units[0].facing=facing;s.units[0].sp=3;s.units[0].attack_ticks_left=1
		for offset in [Vector2i(2,0),Vector2i(3,0),Vector2i(3,1),Vector2i(4,0),Vector2i(4,1)]:enemy(s,s.units[0].cell+AttackRange.rotate_offset(offset,facing))
		s.step([],[])
		check(s.units[1].hp==9535 and s.units[2].hp==9535 and s.units[3].hp==9535 and s.units[4].hp==9535 and s.units[5].hp==10000,"S1 215%%, exact radius2 incl edge/exclsqrt5 facing%d"%facing)
		check(s.units[0].sp==0 and s.units[0].skill_ticks_left==0,"S1 consumes3 and ends instant")
	var normal := fixture(0);normal.units[0].attack_ticks_left=1
	enemy(normal,Vector2i(16,4));enemy(normal,Vector2i(17,4));enemy(normal,Vector2i(17,5))
	normal.step([],[])
	check(normal.units[1].hp==9784 and normal.units[2].hp==9784 and normal.units[3].hp==10000 and normal.units[0].sp==1,"Normal radius1 physical splash, onceSP")
	var proc := fixture(0);enemy(proc,Vector2i(16,4));proc.rng=RNG.new(3);proc.units[0].attack_bonus_percent=20
	var expected_rng := RNG.new(3);check(expected_rng.next_percent()<30,"Fixed seed triggers proc")
	MeteoriteRules.resolve(proc,proc.units[0],op,{"kind":0,"cell":Vector2i(16,4)},2.15,4,false)
	check(proc.units[1].hp==9163 and proc.rng.state==expected_rng.state and proc.units[0].attack_bonus_percent==20,"ATK20+60 additive, round1557*2.15=3348, sniper837; one RNG and no cache mutation")
	var cast := fixture(1);cast._operator_data.target=dummy.duplicate(true);cast._operator_data.target.defense=700
	enemy(cast,Vector2i(16,4));enemy(cast,Vector2i(17,4));enemy(cast,Vector2i(17,5));cast.units[0].sp=20
	var cooldown := cast.units[0].attack_ticks_left
	cast.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	check(cast.units[1].hp==9474 and cast.units[2].hp==9474 and cast.units[3].hp==10000,"S2 candidate radius1, pre-debuff damage526")
	check(cast.units[1].shell_ticks_left==300 and SkillRules.defense_value(cast.units[1],cast._operator_data.target)==370 and cast.units[0].sp==0 and cast.units[0].attack_ticks_left==cooldown,"S2 -330 for300tick, preserve ordinaryCD")
	for t in 299:cast.step([],[])
	check(cast.units[1].shell_ticks_left==1,"No early expiry at299")
	cast.step([],[])
	check(cast.units[1].shell_defense_reduce==0 and SkillRules.defense_value(cast.units[1],cast._operator_data.target)==700,"Exact300tick restoresDEF")
	var refresh := fixture(1);enemy(refresh,Vector2i(16,4));refresh.units[0].sp=20
	refresh.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	for t in 10:refresh.step([],[])
	refresh.units[0].sp=20;refresh.step([InputCommand.new(refresh.tick,1,"",0,Vector2i.ZERO,1)],[])
	check(refresh.units[1].shell_defense_reduce==330 and refresh.units[1].shell_ticks_left==300,"Repeated shell refreshes, no flatDEF stacking")
	var persist := fixture(1);enemy(persist,Vector2i(16,4));persist.units[0].sp=20
	persist.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[]);persist._retreat_unit(persist.units[0])
	check(persist.units[0].shell_defense_reduce==330 and SkillRules.defense_value(persist.units[0],dummy)==0,"Independent debuff survives source exit and DEF clamp0")
	var stacking := fixture(1);stacking._operator_data.target=dummy.duplicate(true);stacking._operator_data.target.defense=700;enemy(stacking,Vector2i(16,4))
	stacking.units[1].defense_bonus_percent=50;stacking.units[1].burn_defense_reduce=300;stacking.units[1].shell_defense_reduce=330;stacking.units[1].armor_break_defense_percent=80
	check(SkillRules.defense_value(stacking.units[1],stacking._operator_data.target)==336,"Fixed reductions after positive multiplier, before armor percentage")
	var bind := fixture(1);enemy(bind,Vector2i(16,4));bind.units[0].sp=20
	StatusRules.add_control(bind,bind.units[0],"bind",90)
	bind.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	check(bind.units[1].hp<10000 and bind.units[0].sp==0,"Bind permits independent active shell")
	var miss := fixture(1);miss._operator_data.target=dummy.duplicate(true);miss._operator_data.target.dodge_physical=100;enemy(miss,Vector2i(16,4));miss.units[0].sp=20
	miss.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	check(miss.units[1].hp==10000 and miss.units[1].shell_ticks_left==0,"Dodge prevents damage and debuff")
	var empty := fixture(1);empty.units[0].sp=20;empty.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	check(empty.units[0].sp==20 and empty.units[0].skill_activation_count==0,"No target consumes noSP or RNG")
	var box := fixture(0);box.units[0].sp=3;box.units[0].attack_ticks_left=1;box.tactical_boxes=[TacticalBox.new(0,Vector2i(16,4),3)];var rng_before := box.rng.state
	box.step([],[])
	check(box.tactical_boxes[0].hits_left==2 and box.rng.state==rng_before,"Box counts one attack, no unused damage proc roll")
	var ball := fixture(0);ball.units[0].sp=3;ball.units[0].attack_ticks_left=1;ball.ball.cell=Vector2i(16,4);ball.step([],[])
	check(ball.ball.accum==Vector2i(1860,0),"S1 raw ball push1860, no sniper coefficient")
	var silence := fixture(0);enemy(silence,Vector2i(16,4));silence.units[0].attack_ticks_left=1;silence.units[0].silence_ticks_left=90;rng_before=silence.rng.state;silence.step([],[])
	check(silence.rng.state==rng_before and silence.units[1].hp==9784,"Silence skips proc RNG, retains branch splash")
	var a := fixture(1);var b := fixture(1)
	for s in [a,b]:enemy(s,Vector2i(16,4));s.units[0].sp=20
	for t in 600:
		var commands: Array[InputCommand]=[]
		if t in [0,450]:commands.append(InputCommand.new(t,1,"",0,Vector2i.ZERO,1))
		a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Everytick replay%d"%t)
	for field in ["shell_ticks_left","shell_defense_reduce"]:
		var before := a.state_hash();a.units[1].set(field,a.units[1].get(field)+1);check(a.state_hash()!=before,"Hash field "+field)
	print("Meteorite focused failures=",failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var s := MatchState.new(1,data);s.ball.cell=Vector2i(5,5);s.units=[UnitState.new(0,0,"meteorite",Vector2i(14,4),1505,0,10000,0,index)];s.next_unit_id=1;return s
func enemy(s: MatchState, cell: Vector2i) -> void:
	s.units.append(UnitState.new(s.next_unit_id,1,"target",cell,10000,0,10000));s.next_unit_id+=1
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
