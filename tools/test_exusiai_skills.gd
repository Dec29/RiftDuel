extends SceneTree

var failures := 0
var definitions := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id in ["exusiai", "bagpipe", "phantom"]:
		definitions[id] = load("res://resources/operators/%s.tres" % id)
	var data: OperatorData = definitions["exusiai"]
	check(data.skills.size() == 3 and data.skills[0].skill_name == "冲锋模式", "Three named Exusiai skills")
	check(data.skills[1].initial_sp == 25 and data.skills[1].sp_required == 35 and data.skills[1].duration == 15.0 and data.skills[1].trigger_type == "manual", "S2 M3 25/35, manual, 15s")
	check(data.skills[2].initial_sp == 20 and data.skills[2].sp_required == 30 and data.skills[2].trigger_type == "auto" and data.skills[2].effect_params["attack_interval_add"] == -0.22, "S3 M3 20/30, auto, interval -0.22s")
	var importer_script := GDScript.new()
	importer_script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	check(importer_script.reload() == OK, "Importer compiles")
	var importer: RefCounted = importer_script.new()
	var imported := data.duplicate(true) as OperatorData
	imported.skills.resize(1)
	var import_data := {"exusiai": imported}
	# Current CSV contains all ordinary operators; keep only Exusiai as the assertion target.
	for id in root.get_node("OperatorDB").all_ids():
		if id=="exusiai":continue
		var other := load("res://resources/operators/%s.tres" % id).duplicate(true) as OperatorData
		other.skills.resize(1)
		import_data[id] = other
	check(importer._append_skills(import_data), "Additional CSV imports successfully")
	for index in 3:
		check(imported.skills[index].skill_name == data.skills[index].skill_name and imported.skills[index].initial_sp == data.skills[index].initial_sp and imported.skills[index].trigger_type == data.skills[index].trigger_type and imported.skills[index].effect_params == data.skills[index].effect_params and imported.skills[index].duration == data.skills[index].duration, "CSV matches runtime skill %d" % index)
	var path := "user://exusiai-loadout-test.cfg"
	var legacy := ConfigFile.new()
	legacy.set_value("squad", "operators", PackedStringArray(["exusiai", "bagpipe"]))
	check(legacy.save(path) == OK, "Legacy fixture creation")
	var squad := SquadConfig.new()
	check(squad.read(path).is_empty() and squad.skill_indices == PackedInt32Array([0, 0]), "IDs-only save migrates explicitly to S1")
	var migrated := ConfigFile.new()
	check(migrated.load(path) == OK and migrated.get_value("squad", "version") == 2 and migrated.get_value("squad", "skills") == PackedInt32Array([0, 0]), "Migration is persisted")
	squad.skill_indices = PackedInt32Array([2, 0])
	check(squad.write(path).is_empty(), "Save selected S3")
	var restored := SquadConfig.new()
	check(restored.read(path).is_empty() and restored.skill_indices == squad.skill_indices, "Skill and slot order survive restart")
	for indices in [[], [0], [3, 0], [-1, 0], [1.5, 0], [true, 0], ["1", 0], null]:
		check(not SquadConfig.validate_loadout(squad.operator_ids, indices).is_empty(), "Reject malformed/unopened skills: %s" % str(indices))
	check(not SquadConfig.validate_loadout(["exusiai", "swire_alter"], [0, 3]).is_empty(), "Reject nonexistent fourth skill")
	check(SquadConfig.validate_loadout(["exusiai", "bagpipe"], [0, 1]).is_empty(), "Newly implemented Bagpipe S2 accepted")
	check(DirAccess.remove_absolute(path) == OK, "Remove isolated persistence fixture")
	# Same immutable resource, different choices on the two sides.
	var squads: Array = [PackedStringArray(["exusiai"]), PackedStringArray(["exusiai"])]
	var skills: Array = [PackedInt32Array([1]), PackedInt32Array([2])]
	var state := MatchState.new(123, definitions, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads, skills)
	state.sides[0].cost = 99
	state.sides[1].cost = 99
	state.step([InputCommand.new(0, 0, "exusiai", -1, Vector2i(12, 2))], [InputCommand.new(0, 0, "exusiai", -1, Vector2i(8, 2))])
	check(state.units.size() == 2 and state.units[0].skill_index == 1 and state.units[0].sp == 25 and state.units[1].skill_index == 2 and state.units[1].sp == 20, "Deployment uses each side's skill/initial SP")
	check(data.skills[0].initial_sp == 0 and data.skills[1].initial_sp == 25 and data.skills[2].initial_sp == 20, "Shared resources stay immutable")
	var hash_before := state.state_hash()
	state.units[0].skill_index = 0
	check(state.state_hash() != hash_before, "Unit skill participates in hash")
	state.units[0].skill_index = 1
	state.squad_skills[0][0] = 0
	check(skills[0][0] == 1, "Match owns a copy of input loadout")
	check(state.state_hash() != hash_before, "Frozen loadout participates in hash")
	state.squad_skills[0][0] = 1
	state.step([InputCommand.new(state.tick, 2, "", 0)], [])
	state.sides[0].cooldowns.clear()
	state.step([InputCommand.new(state.tick, 0, "exusiai", -1, Vector2i(12, 2))], [])
	check(state.units[-1].skill_index == 1 and state.units[-1].sp == 25, "Redeployment resets SP but retains equipped S2")
	var manual := fixture(1, 35)
	manual.units.append(UnitState.new(1, 1, "bagpipe", Vector2i(10, 4), 2484, 0, 1000))
	manual.next_unit_id = 2
	manual.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 1)], [])
	check(manual.units[1].hp == 2484 and manual.units[0].skill_ticks_left == 449 and manual.units[0].sp == 0, "S2 begins its windup without an early hit")
	settle_volley(manual)
	check(manual.units[1].hp == 2036 and manual.units[0].skill_ticks_left == 450-manual.tick, "S2 impact: four independently scaled 112 damage hits")
	check(SkillRules.attack_value(manual.units[0], data) == 716 and SkillRules.attack_interval_ticks(manual.units[0], data) == 27, "S2 keeps baseline interval, combines blessing with multiplier")
	manual.units[0].attack_ticks_left = 1
	var previous_release := manual.units[0].last_attack_tick
	manual.step([], [])
	settle_volley(manual,previous_release)
	check(manual.units[1].hp == 1588 and manual.units[0].skill_ticks_left == 450-manual.tick, "S2 remains active for subsequent real volley impacts")
	var idle := fixture(1, 35)
	idle.ball.cell = Vector2i(10, 8)
	idle.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 2)], [])
	check(idle.units[0].sp == 35 and idle.units[0].skill_ticks_left == 0, "Command cannot switch equipped skill")
	idle.step([], [InputCommand.new(1, 1, "", 0, Vector2i.ZERO, 1)])
	check(idle.units[0].skill_ticks_left == 0, "Opponent cannot activate another side's unit")
	idle.step([InputCommand.new(2, 1, "", 0, Vector2i.ZERO, 1)], [])
	check(idle.units[0].skill_ticks_left == 449, "Manual S2 can open without a target")
	for ignored in 449:
		idle.step([], [])
	check(idle.units[0].skill_ticks_left == 0 and idle.units[0].sp == 0 and SkillRules.attack_value(idle.units[0], data) == 572, "450 ticks restore baseline, no SP regeneration while active")
	for ignored in 30:
		idle.step([], [])
	check(idle.units[0].sp == 1, "SP resumes after expiry")
	var auto := fixture(2, 29)
	auto.ball.cell = Vector2i(10, 8)
	auto.units[0].sp_regen_ticks = 29
	auto.units[0].attack_ticks_left = 100
	auto.step([], [])
	check(auto.units[0].sp == 0 and auto.units[0].skill_ticks_left == 449 and SkillRules.attack_interval_ticks(auto.units[0], data) == 21, "S3 activates at full SP without a target; interval includes +12 AS")
	check(not SkillRules.can_manually_activate(auto.units[0], data.skills[2]), "S3 cannot be manually activated")
	auto.units.append(UnitState.new(1, 1, "bagpipe", Vector2i(10, 4), 2484, 0, 1000))
	auto.next_unit_id = 2
	auto.units[0].attack_ticks_left = 1
	auto.step([], [])
	check(auto.units[1].hp == 2484, "S3 windup cannot damage before fire")
	settle_volley(auto)
	check(auto.units[1].hp == 2029 and SkillRules.attack_value(auto.units[0], data) == 630, "S3 impact has five independently scaled 91 damage hits")
	auto.units[0].skill_ticks_left = 1
	var expected_remaining := maxi(0,auto.units[0].attack_next_ready_tick-auto.tick)
	auto.step([], [])
	check(auto.units[0].skill_ticks_left == 0 and auto.units[0].attack_ticks_left == expected_remaining and SkillRules.attack_interval_ticks(auto.units[0], data) == 27, "S3 expiry preserves the current attack cycle")
	# Increase only the ball threshold in a private fixture to observe all volley pushes.
	for index in [1, 2]:
		var ball_data := MatchState.DEFAULT_BALL_DATA.duplicate() as BallData
		ball_data.kick_threshold = 100000
		var ball_state := MatchState.new(123, definitions, ball_data)
		ball_state.units = [UnitState.new(0, 0, "exusiai", Vector2i(11, 5), data.max_health, data.skills[index].sp_required, 1, 2, index)]
		ball_state.next_unit_id = 1
		ball_state.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, index)], [])
		settle_volley(ball_state)
		check(ball_state.ball.accum == Vector2i(-2864 if index == 1 else -3150, 0), "Each volley hit contributes unscaled ball push")
	var box_state := fixture(1, 35)
	box_state.ball.cell = Vector2i(10, 8)
	box_state.tactical_boxes = [TacticalBox.new(0, Vector2i(10, 4), 3)]
	box_state.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 1)], [])
	settle_volley(box_state)
	var box_rng := RNG.new(123)
	box_rng.next_u32()
	check(box_state.tactical_boxes.is_empty() and box_state.sides[0].tactical_items.reduce(func(a: int, b: int) -> int: return a + b, 0) == 1 and box_state.rng.state == box_rng.state, "Four-shot volley destroys three-hit box with exactly one loot draw")
	var ai := AIInput.new(0, definitions)
	var ai_state := fixture(1, 35)
	for i in Config.AI_SKILL_REACTION_TICKS:
		check(ai.commands_for_tick(ai_state).is_empty(), "Manual AI skill observes reaction time")
		ai_state.step([], [])
	var before_ai := ai_state.state_hash()
	var commands := ai.commands_for_tick(ai_state)
	check(commands[0].kind == 1 and commands[0].skill_index == 1 and before_ai == ai_state.state_hash(), "AI uses the equipped skill and reads simulation only")
	var input := LocalInput.new(0)
	input.queue_skill(7, 0, 1)
	var encoded := CommandCodec.encode(input.take_commands())
	check(CommandCodec.decode(JSON.parse_string(JSON.stringify(encoded)), 7, Engine.get_main_loop().root.get_node("OperatorDB").network_content()["ids"]).commands[0].skill_index == 1, "Selected skill survives nine-field wire encoding")
	for bad in [-1, 3]:
		check(CommandCodec.decode([[7, 1, "", 0, 0, 0, bad, -1, -1]], 7, Engine.get_main_loop().root.get_node("OperatorDB").network_content()["ids"]).has("error"), "Reject out-of-range activation indices")
	var first := fixture(2, 20)
	var replay := fixture(2, 20)
	first.ball.cell = Vector2i(10, 8)
	replay.ball.cell = Vector2i(10, 8)
	for tick in 1200:
		first.step([], [])
		replay.step([], [])
		check(first.state_hash() == replay.state_hash(), "First replay divergence at tick %d" % tick)
	print("Exusiai S2/S3: persistence, loadout isolation, damage, timing, SP, ball, box, AI, wire and replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func fixture(index: int, sp: int) -> MatchState:
	var state := MatchState.new(123, definitions)
	var data: OperatorData = definitions["exusiai"]
	state.units = [UnitState.new(0, 0, "exusiai", Vector2i(11, 4), data.max_health, sp, 1, 2, index)]
	state.next_unit_id = 1
	return state


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func settle_volley(state: MatchState, previous_release: int=-1) -> void:
	var unit:=state.units[0]
	var deadline:=state.tick+90
	while (unit.last_attack_tick==previous_release or not state.attack_projectiles.is_empty()) and state.tick<deadline:state.step([],[])
	check(state.tick<deadline,"Volley reaches its actual release and impact")
