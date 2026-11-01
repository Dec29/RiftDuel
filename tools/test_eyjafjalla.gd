extends SceneTree

const RANGE := [Vector2i(0,-1),Vector2i(0,0),Vector2i(0,1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(2,-1),Vector2i(2,0),Vector2i(2,1),Vector2i(3,0)]
const ROTATE := preload("res://sim/attack_range.gd")
const CONFIG := preload("res://data/config.gd")
var _failures := 0


func _initialize() -> void:
	var definitions := {}
	for id in ["eyjafjalla","ceobe","bagpipe"]:
		definitions[id] = load("res://resources/operators/%s.tres" % id)
	var eyja: OperatorData = definitions["eyjafjalla"]
	_expect([eyja.max_health,eyja.attack,eyja.defense,eyja.magic_resist,eyja.attack_interval,eyja.block_count,eyja.deploy_cost,eyja.redeploy_time] == [1743,645,122,20,1.6,1,21,70.0], "E2 raw values exclude trust, potential, module and talent")
	_expect(eyja.profession_id == "caster" and eyja.damage_type == "magical" and eyja.branch_trait.effect_type == "magical_attack" and Array(eyja.attack_range) == RANGE, "Core caster uses magical damage and exact3-1 range")
	_expect(eyja.skills[0].initial_sp == 25 and eyja.skills[0].sp_required == 35 and eyja.skills[0].sp_recharge_type == "time" and eyja.skills[0].duration == 25.0, "S1M3 initial25, required35, time/manual, duration25s")
	for facing in 4:
		var state := _fixture(definitions)
		state.units[0].facing = facing
		for y in range(-4,5):
			for x in range(-4,5):
				var offset := Vector2i(x,y)
				var target := state.units[0].cell + ROTATE.rotate_offset(offset,facing)
				_expect(state._is_in_attack_range(state.units[0],target,eyja.attack_range) == (offset in RANGE), "Facing%d offset%s range mismatch" % [facing,offset])
	_test_skill(definitions)
	_test_aura(definitions)
	_test_random_sp(definitions)
	_test_redeploy(definitions)
	_test_import(eyja)
	_test_replay(definitions)
	_expect(eyja.attack == 645 and eyja.skills[0].initial_sp == 25 and eyja.skills[0].effect_params["attack_mult"] == 1.6, "Simulation must not rewrite resources")
	print("Eyjafjalla: E2, four facings, first/repeat S1, aura, SP7..15/cap, redeploy reset/hash, CSV, replay/old eight; failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _fixture(definitions: Dictionary) -> MatchState:
	var state := MatchState.new(123,definitions,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["eyjafjalla","ceobe","bagpipe"],["ceobe","bagpipe"]])
	state.units = [UnitState.new(0,0,"eyjafjalla",Vector2i(12,2),1743,35,48,0),UnitState.new(1,0,"ceobe",Vector2i(13,2),1565,0,10000),UnitState.new(2,0,"bagpipe",Vector2i(14,3),2484,0,10000),UnitState.new(3,1,"ceobe",Vector2i(6,2),1565,0,10000)]
	state.next_unit_id = 4
	return state


func _cast(state: MatchState, id: int = 0) -> void:
	state.step([InputCommand.new(state.tick,InputCommand.Kind.SKILL,"",id,Vector2i.ZERO,0)],[])


func _test_skill(definitions: Dictionary) -> void:
	var state := _fixture(definitions)
	var eyja: OperatorData = definitions["eyjafjalla"]
	state.step([],[])
	_expect(state.units[0].skill_ticks_left == 0 and state.units[0].skill_repeat_activation_count == 0, "Full SP must not autoactivate manual S1")
	_expect(SkillRules.attack_value(state.units[0],eyja) == 735 and SkillRules.attack_interval_ticks(state.units[0],eyja) == 48, "Talent-only attack735, interval48ticks")
	_cast(state)
	_expect(state.units[0].sp == 0 and state.units[0].skill_ticks_left == 749 and state.units[0].skill_repeat_activation_count == 1, "First S1 consumes35SP, lasts750ticks, count1")
	_expect(SkillRules.attack_value(state.units[0],eyja) == 735 and SkillRules.attack_interval_ticks(state.units[0],eyja) == 30, "First S1 only adds60AS, without60%ATK")
	for _tick in 748:
		state.step([],[])
	_expect(state.units[0].skill_ticks_left == 1 and state.units[0].sp == 0, "No time SP recharge while active; exact25s duration")
	state.step([],[])
	_expect(state.units[0].skill_ticks_left == 0 and SkillRules.attack_interval_ticks(state.units[0],eyja) == 48, "Expiry restores48tick interval")
	for _tick in 1050:
		state.step([],[])
	_expect(state.units[0].sp == 35, "Inactive recharge reaches35 in1050ticks")
	_cast(state)
	_expect(state.units[0].skill_repeat_activation_count == 2 and SkillRules.attack_value(state.units[0],eyja) == 1122 and SkillRules.attack_interval_ticks(state.units[0],eyja) == 30, "Second S1 adds60%ATK to14%talent: round(645*1.74)=1122")
	var before := state.state_hash()
	state.units[0].skill_repeat_activation_count += 1
	_expect(state.state_hash() != before, "Repeat count must enter hash")
	state.units[0].skill_repeat_activation_count -= 1
	state.units[0].skill_ticks_left = 0
	state.units[0].sp = 35
	_cast(state)
	_expect(state.units[0].skill_repeat_activation_count == 3 and SkillRules.attack_value(state.units[0],eyja) == 1122, "Third activation keeps60% bonus without stacking")
	var hit := _fixture(definitions)
	hit.units[0].attack_ticks_left = 1
	hit.units = [hit.units[0],UnitState.new(1,1,"bagpipe",Vector2i(13,2),5000,0,10000)]
	hit.step([],[])
	_expect(hit.units[1].hp == 4779, "Magical attack735 ignoresDEF, uses caster30%:221damage")
	hit.units[0].attack_ticks_left = 1
	hit.units[0].skill_repeat_activation_count = 1
	hit.units[0].sp = 35
	_cast(hit)
	_expect(hit.units[1].hp == 4442, "Repeat S1 attack1122 uses caster30%:337damage")


func _test_aura(definitions: Dictionary) -> void:
	var state := _fixture(definitions)
	AuraRules.refresh(state)
	_expect(state.units[0].attack_bonus_percent == 14 and state.units[1].attack_bonus_percent == 14 and state.units[2].attack_bonus_percent == 0 and state.units[3].attack_bonus_percent == 8, "Aura includes self/allied caster, excludes noncaster/enemy")
	state.step([InputCommand.new(0,InputCommand.Kind.RETREAT,"",0)],[])
	_expect(state.units[0].attack_bonus_percent == 8, "Source retreat removes aura; isolated Ceobe keeps8%")
	var dead := _fixture(definitions)
	dead.units[0].hp = 0
	dead.step([],[])
	_expect(dead.units[0].attack_bonus_percent == 8, "Source defeat removes aura")
	var undeployed := MatchState.new(123,definitions)
	undeployed.units = [UnitState.new(0,0,"ceobe",Vector2i(12,2),1565,0,10000)]
	undeployed.step([],[])
	_expect(undeployed.units[0].attack_bonus_percent == 8, "Undeployed source gives no aura")


func _test_random_sp(definitions: Dictionary) -> void:
	var observed := {}
	var raw := (definitions["eyjafjalla"] as OperatorData).duplicate(true) as OperatorData
	raw.skills[0].initial_sp = 0
	var raw_definitions := definitions.duplicate()
	raw_definitions["eyjafjalla"] = raw
	for seed in range(1,257):
		var expected_rng := RNG.new(seed)
		var expected := 7 + expected_rng.next_u32() % 9
		var state := MatchState.new(seed,raw_definitions)
		state.sides[0].cost = 99
		state.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"eyjafjalla",-1,Vector2i(12,2),-1,0)],[])
		_expect(state.units.size() == 1 and state.units[0].sp == expected and state.rng.state == expected_rng.state, "Deployment draws one RNG value7..15, seed%d" % seed)
		observed[state.units[0].sp] = true
		var capped := MatchState.new(seed,definitions)
		capped.sides[0].cost = 99
		capped.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"eyjafjalla",-1,Vector2i(12,2),-1,0)],[])
		_expect(capped.units[0].sp == mini(35,25+expected), "Initial25+random caps at35, seed%d" % seed)
	_expect(observed.size() == 9 and observed.has(7) and observed.has(15) and not observed.has(16), "Interval includes7/15, excludes16")
	var rejected := MatchState.new(123,definitions)
	var rng_before := rejected.rng.state
	rejected.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"eyjafjalla",-1,Vector2i(12,5))],[])
	_expect(rejected.units.is_empty() and rejected.rng.state == rng_before, "Rejected deployment consumes no RNG")


func _test_redeploy(definitions: Dictionary) -> void:
	var state := MatchState.new(123,definitions,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["eyjafjalla"],["bagpipe"]])
	state.sides[0].cost = 99
	state.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"eyjafjalla",-1,Vector2i(12,2),-1,0)],[])
	state.units[0].sp = 35
	_cast(state)
	_expect(state.units[0].skill_repeat_activation_count == 1, "First deployment activation count1")
	state.step([InputCommand.new(state.tick,InputCommand.Kind.RETREAT,"",0)],[])
	_expect(state.sides[0].cooldowns["eyjafjalla"] == 2100, "Normal redeploy70s without SilverAsh")
	for _tick in 2100:
		state.step([],[])
	state.step([InputCommand.new(state.tick,InputCommand.Kind.DEPLOY,"eyjafjalla",-1,Vector2i(12,2),-1,0)],[])
	_expect(state.units.size() == 1 and state.units[0].unit_id == 1 and state.units[0].skill_repeat_activation_count == 0 and state.units[0].sp >= 32 and state.units[0].sp <= 35, "Redeployment resets count, draws SP again")
	state.units[0].sp = 35
	_cast(state,1)
	_expect(SkillRules.attack_value(state.units[0],definitions["eyjafjalla"]) == 735, "Redeployed first S1 speed-only")


func _test_import(eyja: OperatorData) -> void:
	var importer_script := GDScript.new()
	importer_script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	_expect(importer_script.reload() == OK, "Importer methods compile")
	var importer: RefCounted = importer_script.new()
	var csv := FileAccess.open("res://import/operators.csv",FileAccess.READ)
	var header := csv.get_csv_line()
	var columns := {}
	for index in header.size():
		columns[header[index]] = index
	var found := false
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() == 1:
			continue
		_expect(importer._validate_row(row,columns), "CSV remains importable: " + row[0])
		if row[0] == "艾雅法拉":
			found = true
			var imported: OperatorData = importer._build_operator(row,columns)
			_expect(imported.attack == eyja.attack and imported.skills[0].initial_sp == 25 and imported.talent_1.effect_params == eyja.talent_1.effect_params and imported.talent_2.effect_params == eyja.talent_2.effect_params and imported.skills[0].effect_params == eyja.skills[0].effect_params and Array(imported.attack_range) == RANGE, "CSV preserves caster aura/randomSP/repeatS1")
	_expect(found, "Eyjafjalla CSV row required")


func _test_replay(definitions: Dictionary) -> void:
	var first := MatchState.new(456,definitions,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["eyjafjalla"],["bagpipe"]])
	var second := MatchState.new(456,definitions,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["eyjafjalla"],["bagpipe"]])
	first.sides[0].cost = 99
	second.sides[0].cost = 99
	for tick in 2800:
		var commands: Array[InputCommand] = []
		if tick == 0 or tick == 2151:
			commands = [InputCommand.new(tick,InputCommand.Kind.DEPLOY,"eyjafjalla",-1,Vector2i(12,2),-1,0)]
		if tick == 40 or tick == 2200:
			commands = [InputCommand.new(tick,InputCommand.Kind.SKILL,"",0 if tick == 40 else 1,Vector2i.ZERO,0)]
		if tick == 50:
			commands = [InputCommand.new(tick,InputCommand.Kind.RETREAT,"",0)]
		first.step(commands,[])
		second.step(commands,[])
		_expect(first.state_hash() == second.state_hash(), "Deploy/randomSP/skill/retreat replay mismatch tick%d" % tick)
	var old_data := {}
	for id in CONFIG.DEFAULT_SQUAD_IDS:
		old_data[id] = load("res://resources/operators/%s.tres" % id)
	var expanded := old_data.duplicate()
	expanded["eyjafjalla"] = definitions["eyjafjalla"]
	var old := MatchState.new(77,old_data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[CONFIG.DEFAULT_SQUAD_IDS,CONFIG.DEFAULT_SQUAD_IDS])
	var added := MatchState.new(77,expanded,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[CONFIG.DEFAULT_SQUAD_IDS,CONFIG.DEFAULT_SQUAD_IDS])
	_expect(CONFIG.DEFAULT_SQUAD_IDS.size() == 8 and "eyjafjalla" not in CONFIG.DEFAULT_SQUAD_IDS, "Default original eight unchanged")
	for tick in 120:
		var commands: Array[InputCommand] = []
		if tick == 0:
			old.sides[0].cost = 99
			added.sides[0].cost = 99
			commands = [InputCommand.new(0,InputCommand.Kind.DEPLOY,"bagpipe",-1,Vector2i(11,5))]
		if tick == 80:
			commands = [InputCommand.new(tick,InputCommand.Kind.RETREAT,"",0)]
		old.step(commands,[])
		added.step(commands,[])
		_expect(old.state_hash() == added.state_hash(), "Uncarried Eyjafjalla changes original eight tick%d" % tick)


func _expect(condition: bool,message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
