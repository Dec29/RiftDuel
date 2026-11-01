extends SceneTree
var failures := 0
var data := {"nearl":load("res://resources/operators/nearl.tres"),"shining":load("res://resources/operators/shining.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres"),"myrtle":load("res://resources/operators/myrtle.tres"),"hellagur":load("res://resources/operators/hellagur.tres")}
func _initialize() -> void:
	var op: OperatorData=data.nearl
	check(op.validation_error().is_empty(),"Resource: "+op.validation_error())
	check(op.skills.size()==2 and op.max_health==2780 and op.attack==462 and op.defense==575 and op.magic_resist==10 and op.attack_range==[Vector2i.ZERO],"Original raw base and actual2skills")
	var aid := fixture(0);aid.units[0].sp=4;aid.units[0].attack_ticks_left=1
	aid.units.append(UnitState.new(1,0,"shining",Vector2i(13,5),700,0,10000));aid.next_unit_id=2
	aid.step([],[])
	check(aid.units[1].hp==1158 and aid.units[0].sp==0 and aid.units[0].last_attack_is_heal,"S1 charge heal180%, baseline416 then aura110%=458")
	var cap := fixture(0)
	for t in 360:cap.step([],[])
	check(cap.units[0].sp==12 and cap.units[0].skill_ticks_left==0,"FullHP cap3charges, no wasted trigger")
	var mode := fixture(1);mode.units[0].sp=40;mode.units[0].attack_ticks_left=0
	mode.units.append(UnitState.new(1,0,"shining",Vector2i(13,5),700,0,10000));mode.next_unit_id=2
	mode.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	check(mode.units[0].skill_ticks_left==1199 and SkillRules.attack_value(mode.units[0],op)==832 and SkillRules.attack_interval_ticks(mode.units[0],op)==39 and mode.units[1].hp==1158,"S2 ATK80%, 1.3s interval, heal458,1200tick")
	check(SkillRules.block_count_value(mode.units[0],op)==3,"S2 keeps block3")
	for t in 38:mode.step([],[])
	check(mode.units[1].hp==1158,"No early second S2 heal")
	mode.step([],[]);check(mode.units[1].hp==1613,"Next heal at39tick, cap targetHP")
	mode.units[1].hp=700;mode.units[0].attack_ticks_left=1
	StatusRules.add_control(mode,mode.units[0],"bind",30);mode.step([],[])
	check(mode.units[1].hp==700,"Bind stops ordinary S2 treatment")
	mode.units[0].bind_ticks_left=0;mode.units[0].skill_ticks_left=1;mode.step([],[])
	check(SkillRules.attack_value(mode.units[0],op)==462 and SkillRules.attack_interval_ticks(mode.units[0],op)==36,"Expiry restores base ATK/interval")
	var global := fixture(0);global.units[0].cell=Vector2i(18,5)
	var medic := UnitState.new(1,0,"shining",Vector2i(12,2),1613,0,1,0)
	var ally := UnitState.new(2,0,"bagpipe",Vector2i(13,2),1000,0,10000)
	global.units.append(medic);global.units.append(ally);global.next_unit_id=3
	global.step([],[])
	check(medic.healing_output_percent==110 and ally.hp==1292,"Global outgoing aura applies to distant healer, no range/targetability filter")
	medic.attack_ticks_left=1;var before_hp := ally.hp
	global.step([InputCommand.new(global.tick,2,"",0)],[])
	check(medic.healing_output_percent==100 and ally.hp==before_hp+265,"Retreat removes output aura before same-tick treatment")
	var death := fixture(0);var other := UnitState.new(1,0,"shining",Vector2i(14,2),1613,0,10000);death.units.append(other);death.next_unit_id=2;AuraRules.refresh(death)
	death._apply_damage(death.units[0],op,10000,"true")
	check(other.healing_output_percent==100,"Source death removes aura immediately")
	var reg := fixture(0);reg.units[0].cell=Vector2i(18,5)
	reg.units.append(UnitState.new(1,0,"myrtle",Vector2i(12,5),1000,0,10000));reg.next_unit_id=2
	for t in 60:reg.step([],[])
	check(reg.units[1].hp==1025 and reg.units[1].healing_output_percent==110,"Output aura does not scale continuous life regeneration")
	var musha := UnitState.new(4,0,"hellagur",Vector2i(12,5),1000,0,36);musha.healing_output_percent=110
	check(SkillRules.healing_output(musha,Combat.calculate_healing(70))==39 and SkillRules.healing_received(musha,data.hellagur,100,reg.units[0])==0,"Own trait heal output scales; external Musha heal remains prohibited")
	for facing in 4:
		var range_test := fixture(1);range_test.units[0].facing=facing
		for offset in op.skills[1].attack_range_override:check(range_test._is_in_attack_range(range_test.units[0],Vector2i(12,5)+AttackRange.rotate_offset(offset,facing),op.skills[1].attack_range_override),"Nine range cells facing%d"%facing)
	var physical := fixture(0);physical.units[0].attack_ticks_left=1
	physical.units.append(UnitState.new(1,1,"bagpipe",Vector2i(11,5),2484,0,10000));physical.next_unit_id=2
	physical.step([],[])
	check(physical.units[1].hp<2484 and not physical.units[0].last_attack_is_heal,"Outside self-only range: own blocked enemy is a valid ordinary target")
	var a := fixture(1);var b := fixture(1)
	for s in [a,b]:s.units[0].sp=40
	for t in 600:
		var commands: Array[InputCommand]=[]
		if t==0:commands.append(InputCommand.new(0,1,"",0,Vector2i.ZERO,1))
		a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Replay tick%d"%t)
	var hash_before := a.state_hash();a.units[0].healing_output_percent+=1;check(a.state_hash()!=hash_before,"Output cache in hash")
	print("Nearl focused failures=",failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var s := MatchState.new(148,data);s.ball.cell=Vector2i(5,5);s.units=[UnitState.new(0,0,"nearl",Vector2i(12,5),2780,0,10000,0,index)];s.next_unit_id=1;return s
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
