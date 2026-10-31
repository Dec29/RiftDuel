extends SceneTree

const RANGE := preload("res://sim/attack_range.gd")
var failures := 0
var data := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id in ["schwarz", "bagpipe", "exusiai"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var black: OperatorData = data["schwarz"]
	check(black.skills.size() == 3 and black.skills[1].skill_name == "暮眼锐瞳" and black.skills[2].skill_name == "战术的终结", "Three named skills")
	check([black.skills[1].initial_sp, black.skills[1].sp_required, black.skills[1].duration] == [20, 30, 40.0], "S2 M3 initial20/cost30/duration40")
	check([black.skills[2].initial_sp, black.skills[2].sp_required, black.skills[2].duration] == [12, 25, 25.0], "S3 M3 initial12/cost25/duration25")
	var line: Array[Vector2i] = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0)]
	check(black.skills[1].attack_range_override.is_empty() and black.skills[2].attack_range_override == line, "Original range4-1 includes self plus four forward cells")
	var importer_script := GDScript.new()
	importer_script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	check(importer_script.reload() == OK, "Importer compiles")
	var importer: RefCounted = importer_script.new()
	var imports := {}
	for id in ["schwarz", "exusiai", "suzuran", "shining", "blaze", "silverash", "bagpipe", "hoshiguma", "eyjafjalla", "nightingale", "horn", "angelina", "phantom", "ceobe", "saileach", "swire_alter", "skadi", "typhon", "ifrit", "siege", "saria", "mostima", "weedy", "magallan"]:
		imports[id] = load("res://resources/operators/%s.tres" % id).duplicate(true)
		imports[id].skills.resize(1)
	check(importer._append_skills(imports), "CSV appends all approved skills")
	for index in [1, 2]:
		var imported: SkillResource = imports["schwarz"].skills[index]
		check(imported.effect_params == black.skills[index].effect_params and imported.effect_params["talent_chance_percent"] is int and imported.attack_range_override == black.skills[index].attack_range_override, "CSV matches typed resource %d" % index)
		test_attacks(index)
		test_duration(index)
		test_range(index)
	test_loadout()
	print("Schwarz S2/S3: additive attack, proc50/100, first-hit timing, ball/box, SP/duration, range4 and restore, AI, CSV, independent loadouts; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func fixture(index: int, seed: int = 1) -> MatchState:
	var state := MatchState.new(seed, data)
	state.units = [UnitState.new(0, 0, "schwarz", Vector2i(12,5), 1833, data["schwarz"].skills[index].sp_required, 0, 0, index)]
	state.next_unit_id = 1
	state.ball.cell = Vector2i(5,5)
	return state


func activate(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, state.units[0].skill_index)], [])


func test_attacks(index: int) -> void:
	var black: OperatorData = data["schwarz"]
	for seed in [1, 2, 3, 4, 5, 7, 13, 41, 93, 123, 8192]:
		var state := fixture(index, seed)
		state.units.append(UnitState.new(1, 1, "bagpipe", Vector2i(14,5), 100000, 0, 100000, 0))
		state.next_unit_id = 2
		var sample := RNG.new(seed)
		var proc := sample.next_percent() < (50 if index == 1 else 100)
		activate(state)
		var attack := (3091 if index == 1 else 3763) if proc else (1932 if index == 1 else 2352)
		var expected := Combat.calculate_damage(attack, 382, 0, "physical", 0, RNG.new(1), "sniper")
		check(100000 - state.units[1].hp == expected, "First hit uses unreduced defense, index%d seed%d" % [index, seed])
		check(state.rng.state == sample.state and state.units[1].armor_break_ticks_left == (150 if proc else 0), "Exactly one talent RNG per actual attack; proc50/100")
		check(SkillRules.attack_value(state.units[0], black) == (1932 if index == 1 else 2352), "Additive skill attack before proc")
		if proc:
			state.units[0].attack_ticks_left = 1
			var before: int = state.units[1].hp
			state.rng = RNG.new(seed)
			state.step([], [])
			check(before - state.units[1].hp == Combat.calculate_damage(attack, 306, 0, "physical", 0, RNG.new(1), "sniper") and state.units[1].armor_break_ticks_left == 150, "Following hit uses reduced DEF; repeat refreshes without stacking")
	var aura := fixture(index)
	var partner := data["exusiai"].duplicate(true) as OperatorData
	partner.talent_2 = TalentResource.new()
	partner.talent_2.effect_type = "none"
	aura._operator_data["exusiai"] = partner
	aura.units.append(UnitState.new(1,0,"exusiai",Vector2i(18,8),1673,0,100000,0))
	aura.next_unit_id = 2
	aura.units[0].attack_ticks_left = 100000
	activate(aura)
	check(SkillRules.attack_value(aura.units[0], black) == (1999 if index == 1 else 2419), "Crossfire +8% adds to +130/180%, not multiplied")
	var ball_data := MatchState.DEFAULT_BALL_DATA.duplicate() as BallData
	ball_data.kick_threshold = 100000
	var ball := MatchState.new(1, data, ball_data)
	ball.units = [UnitState.new(0,0,"schwarz",Vector2i(12,5),1833,black.skills[index].sp_required,0,2,index)]
	var sample := RNG.new(1)
	var proc := sample.next_percent() < (50 if index == 1 else 100)
	activate(ball)
	check(ball.ball.accum == Vector2i(-((3091 if index == 1 else 3763) if proc else (1932 if index == 1 else 2352)),0) and ball.rng.state == sample.state, "Ball gets actual multiplier without PvP reduction")
	var box := fixture(index)
	box.tactical_boxes = [TacticalBox.new(0, Vector2i(14,5), 3)]
	var before_rng := box.rng.state
	activate(box)
	check(box.tactical_boxes[0].hits_left == 2 and box.rng.state == before_rng, "One box hit without talent RNG")


func test_duration(index: int) -> void:
	var state := fixture(index)
	state.units[0].attack_ticks_left = 100000
	state.units[0].sp -= 1
	activate(state)
	check(state.units[0].skill_ticks_left == 0, "Insufficient SP rejected")
	state.units[0].sp += 1
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,3-index)], [])
	state.step([], [InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,index)])
	check(state.units[0].skill_ticks_left == 0, "Wrong index and opposing side rejected")
	activate(state)
	var ticks := 1200 if index == 1 else 750
	check(state.units[0].skill_ticks_left == ticks-1 and state.units[0].sp == 0 and SkillRules.attack_interval_ticks(state.units[0], data["schwarz"]) == (48 if index == 1 else 60), "Manual activation and true interval")
	for ignored in ticks-2:
		state.step([], [])
	check(state.units[0].skill_ticks_left == 1 and state.units[0].sp == 0, "Entire duration freezes SP")
	state.units[0].attack_ticks_left = 60
	state.step([], [])
	check(state.units[0].skill_ticks_left == 0 and SkillRules.attack_value(state.units[0],data["schwarz"]) == 840 and SkillRules.attack_interval_ticks(state.units[0],data["schwarz"]) == 48 and state.units[0].attack_ticks_left == (59 if index == 1 else 48), "Expiry restores stats and proportionally rescales remaining cooldown")
	for ignored in 30:
		state.step([], [])
	check(state.units[0].sp == 1, "Natural SP resumes after expiry")


func test_range(index: int) -> void:
	for facing in 4:
		var state := fixture(index)
		var unit := state.units[0]
		unit.facing = facing
		activate(state)
		for x in range(-1,6):
			for y in range(-2,3):
				var local := Vector2i(x,y)
				var expected := (x >= 0 and x <= 4 and y == 0) if index == 2 else (x >= 0 and x <= 2 and absi(y) <= 1)
				check(state._is_in_attack_range(unit,unit.cell+RANGE.rotate_offset(local,facing),RANGE.effective_offsets(unit,data["schwarz"])) == expected, "Exact active range index%d facing%d local%s" % [index,facing,local])
		unit.skill_ticks_left = 1
		state.step([], [])
		check(RANGE.effective_offsets(unit,data["schwarz"]) == data["schwarz"].attack_range and data["schwarz"].attack_range.size() == 9, "Range restores without resource writes")
	var extended := fixture(2)
	activate(extended)
	extended.units.append(UnitState.new(1,1,"bagpipe",Vector2i(16,5),100000,0,100000,0))
	extended.next_unit_id = 2
	extended.units[0].attack_ticks_left = 1
	extended.step([], [])
	check(extended.units[1].hp < 100000, "Simulation acquires enemy four cells forward")
	extended.sides[0].cost = 0
	var before := extended.state_hash()
	var commands := AIInput.new(0,{"schwarz":data["schwarz"]}).commands_for_tick(extended)
	check(commands.is_empty() and before == extended.state_hash(), "AI retains active S3 targeting outside base range and is read-only")
	var side_target := fixture(2)
	side_target.units.append(UnitState.new(1,1,"bagpipe",Vector2i(13,6),100000,0,100000,0))
	activate(side_target)
	check(side_target.units[1].hp == 100000, "S3 excludes neighboring side row immediately on activation")


func test_loadout() -> void:
	check(SquadConfig.validate_loadout(PackedStringArray(["schwarz"]),PackedInt32Array([2])).is_empty(), "S3 available in persistent squad")
	var squads: Array = [PackedStringArray(["schwarz"]),PackedStringArray(["schwarz"])]
	var skills: Array = [PackedInt32Array([1]),PackedInt32Array([2])]
	var first := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,squads,skills)
	var replay := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,squads,skills)
	for state: MatchState in [first,replay]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		state.ball.cell = Vector2i(10,8)
	for tick in 1680:
		var a: Array[InputCommand] = []
		var b: Array[InputCommand] = []
		if tick == 0:
			a.append(InputCommand.new(tick,0,"schwarz",-1,Vector2i(12,2)))
			b.append(InputCommand.new(tick,0,"schwarz",-1,Vector2i(8,8)))
		if tick == 330: a.append(InputCommand.new(tick,1,"",0,Vector2i.ZERO,1))
		if tick == 400: b.append(InputCommand.new(tick,1,"",1,Vector2i.ZERO,2))
		first.step(a,b)
		replay.step(a,b)
		check(first.state_hash() == replay.state_hash(), "Continuous deterministic replay tick%d" % tick)
		if tick == 0: check(first.units[0].sp == 20 and first.units[1].sp == 12, "Independent deployment SP")
	check(first.units[0].skill_index == 1 and first.units[1].skill_index == 2 and first.units[0].skill_ticks_left == 0 and first.units[1].skill_ticks_left == 0, "Both independent skills expire")
	first.step([InputCommand.new(first.tick,2,"",0)],[])
	first.sides[0].cooldowns.clear()
	first.step([InputCommand.new(first.tick,0,"schwarz",-1,Vector2i(12,2))],[])
	check(first.units[-1].skill_index == 1 and first.units[-1].sp == 20, "Redeployment retains choice and resets initial SP")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
