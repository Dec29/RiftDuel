extends SceneTree

var failures := 0
var data := {"saileach":load("res://resources/operators/saileach.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}

func _initialize() -> void:
	var expected_range: Array[Vector2i] = [Vector2i(0,-2),Vector2i(0,-1),Vector2i(0,0),Vector2i(0,1),Vector2i(0,2),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(2,0)]
	var actual: Array[Vector2i] = data.saileach.skills[2].attack_range_override
	check(actual.size() == expected_range.size(), "Exact S3 range size")
	for cell in expected_range: check(cell in actual, "Correct east-facing range cell %s" % cell)
	for facing in 4:
		var probe := fixture(2)
		probe.units[0].facing = facing
		for cell in expected_range:
			check(probe._is_in_attack_range(probe.units[0],probe.units[0].cell+AttackRange.rotate_offset(cell,facing),actual), "Range rotates every cell facing%d" % facing)
		check(not probe._is_in_attack_range(probe.units[0],probe.units[0].cell+AttackRange.rotate_offset(Vector2i(-1,0),facing),actual), "No unintended backward range")
	var importer_script := GDScript.new()
	importer_script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	check(importer_script.reload() == OK,"Importer compiles")
	var importer: RefCounted = importer_script.new()
	var imported := {}
	for file in DirAccess.get_files_at("res://resources/operators"):
		if not file.ends_with(".tres"): continue
		var op := load("res://resources/operators/"+file).duplicate(true) as OperatorData
		op.skills.resize(1)
		imported[op.operator_id] = op
	var valid := bool(importer._append_skills(imported))
	check(valid,"All approved CSV skills import")
	if valid:
		for index in [1,2]:
			var source: SkillResource = data.saileach.skills[index]
			var generated: SkillResource = imported.saileach.skills[index]
			check(generated.attack_range_override == source.attack_range_override and generated.effect_params == source.effect_params and generated.skill_name == source.skill_name and generated.duration == source.duration and generated.initial_sp == source.initial_sp and generated.sp_required == source.sp_required,"Saileach CSV/runtime parity")
	var heal := fixture(1)
	heal.units.append(UnitState.new(1,0,"bagpipe",Vector2i(13,5),500,0,10000))
	heal.next_unit_id = 2
	heal.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	check(heal.units[0].flag_cell == Vector2i(13,5) and SkillRules.defense_value(heal.units[1],data.bagpipe) == 573, "Lowest health fraction flag and additive DEF50%")
	check(heal.units[0].attack_speed_bonus == 0, "Flag talent still excludes source itself after throwing")
	for tick in 29: heal.step([],[])
	check(heal.units[1].hp == 636, "One second regeneration follows global50% with integer remainder")
	var enemy := UnitState.new(2,1,"bagpipe",Vector2i(14,5),2484,0,10000)
	heal.units.append(enemy)
	heal.next_unit_id = 3
	DisplacementRules.apply_unit(heal,enemy,heal.units[1],Vector2i.LEFT,3)
	AuraRules.refresh(heal)
	check(heal.units[0].flag_cell == Vector2i(13,5) and heal.units[1].cell != Vector2i(13,5) and heal.units[1].flag_defense_bonus_percent == 0, "Real push leaves flag on original tile")
	heal.units.append(UnitState.new(3,0,"bagpipe",Vector2i(13,5),1000,0,10000))
	heal.next_unit_id = 4
	AuraRules.refresh(heal)
	check(heal.units[3].flag_defense_bonus_percent == 50, "New ordinary occupant receives tile effect")
	StatusRules.apply_silence(heal, heal.units[0],30)
	check(heal.units[3].flag_defense_bonus_percent == 0, "Silence pauses flag skill and talent")
	for tick in 30: heal.step([],[])
	check(heal.units[3].flag_defense_bonus_percent == 50, "Unexpired flag effect resumes")
	var costs := fixture(1)
	costs.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	for tick in 449: costs.step([],[])
	check(costs.sides[0].cost == 35 and costs.units[0].skill_ticks_left == 0 and costs.units[0].flag_cell == Vector2i(-1,-1), "Exact450ticks:20 skill cost plus15 natural; flag recalled")
	for facing in 4:
		var burst := fixture(2)
		burst.units[0].facing = facing
		var cell := Vector2i(12,5)+AttackRange.rotate_offset(Vector2i(1,0),facing)
		var victim_data := data.bagpipe.duplicate(true) as OperatorData
		victim_data.max_health = 100000
		burst._operator_data.bagpipe = victim_data
		burst.units.append(UnitState.new(1,1,"bagpipe",cell,100000,0,10000))
		burst.next_unit_id = 2
		burst.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
		check(burst.units[0].flag_cell == cell and burst.sides[0].cost == 10 and burst.units[1].hp == 100000 and burst._fragile_damage_percent(burst.units[1]) == 130 and burst.units[1].slow_ticks_left == 1, "Immediate cost/center slow/fragile but delayed damage facing%d" % facing)
		for tick in 29: burst.step([],[])
		check(burst.units[1].hp == 100000 and burst.units[0].flag_landing_ticks_left == 1, "No early landing damage")
		burst.step([],[])
		check(burst.units[1].hp < 100000 and burst.units[1].stun_ticks_left == 105 and not burst.units[0].flag_burst_pending, "Tick30 landing damage and3.5s stun")
		var before := burst.units[1].hp
		burst.step([],[])
		check(burst.units[1].hp == before, "Single burst not repeated")
		burst._retreat_unit(burst.units[0])
		AuraRules.refresh(burst)
		check(burst._fragile_damage_percent(burst.units[0]) == 100, "Retreat recalls ongoing flag aura")
	var high := fixture(2)
	high.units[0].cell = Vector2i(12,3)
	high.units[0].facing = 3
	high.units.append(UnitState.new(1,1,"bagpipe",Vector2i(12,2),2484,0,10000))
	high.next_unit_id = 2
	high.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
	check(high.terrain_at(high.units[0].flag_cell) == "ground" and high.units[0].flag_cell != high.units[0].cell and high.units[0].flag_cell != high.units[1].cell, "High-tile enemy selects nearest empty ground, not ignored")
	var mixed := fixture(2)
	mixed.units[0].cell = Vector2i(12,3)
	mixed.units[0].facing = 3
	mixed.units.append(UnitState.new(1,1,"bagpipe",Vector2i(12,2),2484,0,10000))
	mixed.units.append(UnitState.new(2,1,"bagpipe",Vector2i(12,1),2484,0,10000))
	mixed.next_unit_id = 3
	mixed.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
	check(mixed.units[0].flag_cell == Vector2i(12,1), "Enemy on ground tile precedes fallback for high target")
	var first := fixture(2)
	var aura := fixture(2)
	aura.units.append(UnitState.new(1,1,"bagpipe",Vector2i(13,5),2484,0,10000))
	aura.units.append(UnitState.new(2,0,"bagpipe",Vector2i(14,5),2484,0,10000))
	aura.next_unit_id = 3
	var ally := aura.units[2]
	aura.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
	check(ally.attack_speed_bonus == 10, "Thrown flag supplies neighboring ally talent aura")
	aura.units[0].skill_ticks_left = 1
	aura.step([],[])
	check(ally.attack_speed_bonus == 0 and aura.units[0].flag_cell == Vector2i(-1,-1), "Expiry immediately recalls talent anchor without stale tick")
	var replay := fixture(2)
	var commands: Array[InputCommand] = [InputCommand.new(0,1,"",0,Vector2i.ZERO,2)]
	var empty_commands: Array[InputCommand] = []
	for state in [first,replay]: state.step(commands,empty_commands)
	for tick in 600:
		first.step([],[])
		replay.step([],[])
		check(first.state_hash() == replay.state_hash(), "Replay tick%d" % tick)
	print("Saileach: flag targeting/ground tile push/regeneration/costs, facing4 delay/center fragile/stun, silence/recall and600tick replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func fixture(index: int) -> MatchState:
	var state := MatchState.new(123,data)
	state.units = [UnitState.new(0,0,"saileach",Vector2i(12,5),1835,data.saileach.skills[index].sp_required,10000,0,index)]
	state.next_unit_id = 1
	state.sides[0].cost = 0
	state.ball.cell = Vector2i(10,10)
	return state

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
