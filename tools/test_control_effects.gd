extends SceneTree
var data := {}
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
func fixture(id: String, index: int=0) -> MatchState:
	var ids := PackedStringArray([id]);var skills := PackedInt32Array([index])
	var state := MatchState.new(44,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.ball.cell=Vector2i(0,10)
	var d: OperatorData=data[id]
	var source := UnitState.new(0,0,id,Vector2i(12,5),d.max_health-100,0,0,2)
	source.skill_index=index;source.deployed_tick=-300;state.units.append(source)
	var enemy := UnitState.new(1,1,"fixture",source.cell+AttackRange.rotate_offset(d.attack_range[0],source.facing),100000,0,100000,0)
	state.units.append(enemy);state.next_unit_id=2
	return state
func run() -> void:
	for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
	var neutral: OperatorData=data.bagpipe.duplicate(true);neutral.operator_id="fixture";neutral.max_health=100000;neutral.attack=0;neutral.talent_1.effect_type="none";neutral.talent_2.effect_type="none";data.fixture=neutral
	var slow := fixture("bagpipe");var target: UnitState=slow.units[0]
	target.attack_ticks_left=10;target.last_attack_tick=0
	StatusRules.add_control(slow,target,"slow",24)
	check(target.attack_ticks_left==22 and target.slow_next_interrupt_tick==90 and target.last_basic_interrupt_tick==0,"Slow interrupts with bounded12tick delay and shared90tick cooldown")
	for tick in range(1,90):
		slow.tick=tick;StatusRules.add_control(slow,target,"slow",1)
	check(target.attack_ticks_left==22,"Repeated and overlapping slow cannot reset current action during cooldown")
	slow.tick=90;StatusRules.add_control(slow,target,"slow",1)
	check(target.attack_ticks_left==34,"Continuous aura can interrupt again exactly at90ticks")
	var bind := fixture("bagpipe");target=bind.units[0]
	StatusRules.add_control(bind,target,"bind",75)
	StatusRules.add_control(bind,target,"bind",135)
	check(target.bind_ticks_left==75,"Active bind cannot refresh or extend")
	for tick in 75:StatusRules.advance_controls(target)
	check(target.bind_ticks_left==0 and target.bind_immunity_ticks_left==30,"Bind expires into30tick immunity")
	StatusRules.add_control(bind,target,"bind",75);check(target.bind_ticks_left==0,"Immunity applies across sources")
	for tick in 29:StatusRules.advance_controls(target)
	StatusRules.add_control(bind,target,"bind",75);check(target.bind_ticks_left==0,"Full1second immunity cannot be shortened")
	StatusRules.advance_controls(target);StatusRules.add_control(bind,target,"bind",75);check(target.bind_ticks_left==75,"Bind resumes after immunity")
	LumenRules.clear_controls(bind,target);check(target.bind_ticks_left==0 and target.bind_immunity_ticks_left==30,"Lumen cleanse ends bind and grants immunity")
	var pulses := fixture("bagpipe");var controlled_ticks := 0
	for tick in 360:
		pulses.tick=tick;StatusRules.advance_controls(pulses.units[0])
		if tick%90==0:StatusRules.add_control(pulses,pulses.units[0],"bind",75)
		if pulses.units[0].bind_ticks_left>0:controlled_ticks+=1
	check(controlled_ticks==150,"Magallan75of90 pulse becomes150of360 bound ticks with immunity,41.7percent")
	for id in data:
		if id=="fixture":continue
		var state := fixture(id);var source: UnitState=state.units[0]
		source.bind_ticks_left=600
		for tick in 60:state.tick=tick;AttackRules.resolve(state)
		check(source.last_attack_tick==-1,"Bind suppresses every normal attack/heal dispatcher: "+id)
		if data[id].branch_trait.effect_type=="bard":continue
		source.bind_ticks_left=0;source.attack_ticks_left=0
		AttackRules.resolve(state)
		check(source.last_attack_tick>=0,"Unbound ordinary action remains usable: "+id)
	var buff := fixture("exusiai",2);target=buff.units[0];target.sp=SkillRules.sp_limit(data.exusiai.skills[2]);SkillRules.activate(target,data.exusiai);target.bind_ticks_left=60
	AttackRules.resolve(buff);check(target.last_attack_tick==-1 and target.skill_ticks_left!=0,"Sustained attack enhancement cannot bypass bind")
	var cast := fixture("texas",1);target=cast.units[0];target.bind_ticks_left=90;target.sp=40
	var cast_commands: Array[InputCommand]=[InputCommand.new(0,1,"",0,Vector2i.ZERO,1)]
	cast.step(cast_commands,[])
	check(target.skill_activation_count==1 and cast.units[1].hp<100000,"Bound unit can cast independent damage skill")
	var field := fixture("ifrit",2);target=field.units[0];target.sp=100;target.bind_ticks_left=90
	var field_commands: Array[InputCommand]=[InputCommand.new(0,1,"",0,Vector2i.ZERO,2)]
	field.step(field_commands,[])
	check(target.skill_ticks_left>0,"Bound unit may start sustained independent skill")
	for kind in ["slow","bind"]:
		var volley := fixture("typhon",2);var archer: UnitState=volley.units[0]
		archer.sp=SkillRules.sp_limit(data.typhon.skills[2]);SkillRules.activate(archer,data.typhon)
		archer.skill_ammo_left=0;archer.rain_arrows_left=4
		StatusRules.add_control(volley,archer,kind,75)
		check(archer.rain_arrows_left==0 and archer.skill_ticks_left==0,"Interrupted last ammo volley ends skill without free extra arrows: "+kind)
	var drift := fixture("bagpipe");target=drift.units[0];target.bind_ticks_left=90
	DisplacementRules.apply_unit(drift,drift.units[1],target,Vector2i.RIGHT,4)
	check(target.displacement_ticks_left>0,"Bind does not block external displacement")
	var one := fixture("bagpipe");var two := fixture("bagpipe")
	var empty: Array[InputCommand]=[]
	for tick in 900:
		for state in [one,two]:
			if tick%3==0:StatusRules.add_control(state,state.units[0],"slow",24)
			if tick%90==0:StatusRules.add_control(state,state.units[0],"bind",75)
			state.step(empty,empty)
		check(one.state_hash()==two.state_hash(),"900tick deterministic control replay")
	for key in ["slow_next_interrupt_tick","last_basic_interrupt_tick","bind_immunity_ticks_left"]:
		var old_hash := one.state_hash();one.units[0].set(key,one.units[0].get(key)+1);check(one.state_hash()!=old_hash,"Control future field included in hash: "+key)
	print("CONTROL_EFFECTS_OK:56 normal dispatchers, strengthened attack/heal, independent skills, victim cooldown, immunity/cleanse/displacement,900tick replay" if failures==0 else "CONTROL_EFFECTS_FAILED%d"%failures)
	quit(0 if failures==0 else 1)
