extends SceneTree
var failures := 0
var data := {}
const RANGE := preload("res://sim/attack_range.gd")
func _initialize() -> void:
	data["eyjafjalla"] = load("res://resources/operators/eyjafjalla.tres")
	var enemy: OperatorData = load("res://resources/operators/bagpipe.tres").duplicate(true)
	enemy.magic_resist = 40
	enemy.talent_1.effect_type = "none"
	enemy.talent_2.effect_type = "none"
	data["bagpipe"] = enemy
	var op: OperatorData = data["eyjafjalla"]
	check(op.skills.size() == 3 and op.skills[1].parameters_are_valid() and op.skills[2].parameters_are_valid(), "Three validated named skills")
	for index in [1,2]:
		var deployed := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["eyjafjalla"],["bagpipe"]],[PackedInt32Array([index]),PackedInt32Array([0])])
		deployed.sides[0].cost = 99
		var old_rng := deployed.rng.state
		deployed.step([InputCommand.new(0,0,"eyjafjalla",-1,Vector2i(12,5))],[])
		check(deployed.units.is_empty() and deployed.rng.state == old_rng,"Illegal ground deployment does not draw SP RNG")
		deployed.ball.cell = Vector2i(5,5)
		deployed.step([InputCommand.new(1,0,"eyjafjalla",-1,Vector2i(12,2))],[])
		check(deployed.units.size() == 1 and deployed.units[0].skill_index == index,"Legal deployment retains carried skill")
		check(deployed.units[0].sp >= (7 if index == 1 else 62) and deployed.units[0].sp <= (15 if index == 1 else 70),"Deploy random SP uses carried skill initial values")
	var idle := fixture(1)
	idle.units[0].sp = 15
	idle.step([], [])
	check(idle.units[0].sp == 15 and idle.units[0].skill_ticks_left == 0, "Charged S2 waits for attack")
	var splash := fixture(1)
	splash.units[0].sp = 15
	splash.units[0].attack_ticks_left = 0
	for cell in [Vector2i(15,2), Vector2i(16,3), Vector2i(17,2)]:
		splash.units.append(UnitState.new(splash.units.size(),1,"bagpipe",cell,100000,0,10000))
	splash.next_unit_id = 4
	splash.step([], [])
	var main_damage := Combat.calculate_damage(1361,0,30,"magical",0,RNG.new(1),"caster")
	var splash_damage := Combat.calculate_damage(1361,0,40,"magical",0,RNG.new(1),"caster")
	check(splash.units[0].sp == 10 and splash.units[0].skill_ticks_left == 0, "Consumes exactly one S2 charge")
	check(splash.units[1].hp == 100000-main_damage*2 and splash.units[1].resist_break_ticks_left == 180 and SkillRules.magic_resist_value(splash.units[1],enemy) == 30, "Main MR reduced before two half packets")
	check(splash.units[2].hp == 100000-splash_damage and splash.units[2].resist_remaining_percent == 100 and splash.units[3].hp == 100000, "Diagonal splash radius2, secondary MR unchanged, distance4 excluded")
	for n in 2:
		splash.units[0].attack_ticks_left = 0
		splash.step([], [])
	check(splash.units[0].sp == 0 and splash.units[1].resist_remaining_percent == 75 and splash.units[1].resist_break_ticks_left == 180, "Three stored charges, refresh without stacking")
	for unit in splash.units: unit.attack_ticks_left = 10000
	for t in 180: splash.step([], [])
	check(splash.units[1].resist_break_ticks_left == 0 and SkillRules.magic_resist_value(splash.units[1],enemy) == 40, "180tick expiry restores MR")
	var before := idle.state_hash()
	idle.units[0].resist_break_ticks_left = 1
	check(idle.state_hash() != before,"MR duration enters hash")
	idle.units[0].resist_break_ticks_left = 0
	idle.units[0].resist_remaining_percent = 75
	check(idle.state_hash() != before,"MR percent enters hash")
	var ball := fixture(1,2)
	ball.ball.cell = Vector2i(11,2)
	ball.units[0].sp = 15
	ball.units[0].attack_ticks_left = 0
	ball.step([],[])
	check(ball.ball.accum == Vector2i(-2721,0) and ball.units[0].sp == 10,"S2 ball gets one full raw push")
	var box := fixture(1,2)
	box.units[0].sp = 15
	box.units[0].attack_ticks_left = 0
	box.tactical_boxes.append(TacticalBox.new(0,Vector2i(11,2),3))
	box.step([],[])
	check(box.tactical_boxes[0].hits_left == 2 and box.units[0].sp == 10,"S2 box one action one hit")
	for count in [5,8]:
		var state := fixture(2)
		for offset in [Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(1,1),Vector2i(1,-1),Vector2i(0,1),Vector2i(0,-1),Vector2i(-1,0)].slice(0,count):
			state.units.append(UnitState.new(state.units.size(),1,"bagpipe",state.units[0].cell+offset,100000,0,10000))
		state.next_unit_id = count+1
		state.units[0].sp = 80
		state.units[0].attack_ticks_left = 0
		var expected_rng := RNG.new(state.rng.state)
		if count > 6:
			for pick in 6: expected_rng.next_u32()
		state.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
		check(state.units[0].skill_ticks_left == 449 and SkillRules.attack_value(state.units[0],op) == 1574 and SkillRules.attack_interval_ticks(state.units[0],op) == 15,"S3 exact stats, duration, interval")
		var hits := 0
		for unit in state.units:
			if unit.side == 1 and unit.hp < 100000: hits += 1
		check(hits == mini(count,6) and state.rng.state == expected_rng.state,"Random distinct up to6, no RNG when all fit")
		for facing in 4:
			state.units[0].facing = facing
			for x in range(-4,5):
				for y in range(-4,5):
					var target := state.units[0].cell+RANGE.rotate_offset(Vector2i(x,y),facing)
					check(state._is_in_attack_range(state.units[0],target,RANGE.effective_offsets(state.units[0],op)) == (absi(x)+absi(y)<=3),"S3 exact25-cell diamond all facings")
	var first := fixture(2)
	var second := fixture(2)
	first.units[0].sp = 80
	second.units[0].sp = 80
	for t in 900:
		var commands: Array[InputCommand] = []
		if t == 0: commands.append(InputCommand.new(t,1,"",0,Vector2i.ZERO,2))
		first.step(commands,[])
		second.step(commands,[])
		check(first.state_hash() == second.state_hash(),"Every-tick deterministic replay")
		if t == 449: check(first.units[0].skill_ticks_left == 0 and SkillRules.attack_value(first.units[0],op) == 735 and SkillRules.attack_interval_ticks(first.units[0],op) == 48,"450tick expiration restores base stats")
	var importer := GDScript.new()
	importer.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	check(importer.reload() == OK,"Importer compiles")
	var imported := {}
	for file in DirAccess.get_files_at("res://resources/operators"):
		if file.ends_with(".tres"):
			var loaded: OperatorData = load("res://resources/operators/"+file)
			imported[loaded.operator_id] = loaded.duplicate(true)
			imported[loaded.operator_id].skills.resize(1)
	check(importer.new()._append_skills(imported),"All CSV skills import")
	for index in [1,2]: check(imported["eyjafjalla"].skills[index].effect_params == op.skills[index].effect_params and imported["eyjafjalla"].skills[index].attack_range_override == op.skills[index].attack_range_override,"Typed CSV resource parity")
	var invalid: SkillResource = op.skills[1].duplicate(true)
	invalid.effect_params["resist_duration_ticks"] = 0.5
	check(not invalid.parameters_are_valid(),"Reject fractional MR duration")
	print("Eyjafjalla S2/S3: charges, two packets, MR lifecycle/hash, radius, ball/box, random targets/range, exact duration, CSV and replay; failures=%d"%failures)
	quit(0 if failures == 0 else 1)
func fixture(index:int,facing:int=0)->MatchState:
	var ball_data: BallData = MatchState.DEFAULT_BALL_DATA.duplicate(true)
	ball_data.kick_threshold = 100000
	var state := MatchState.new(123,data,ball_data)
	state.ball.cell = Vector2i(5,5)
	state.units = [UnitState.new(0,0,"eyjafjalla",Vector2i(12,2),1743,0,10000,facing,index)]
	state.next_unit_id = 1
	return state
func check(ok:bool,message:String)->void:
	if not ok:
		failures += 1
		push_error(message)
