extends SceneTree

const S2_RANGE: Array[Vector2i] = [Vector2i(0, 1), Vector2i.ZERO, Vector2i.RIGHT, Vector2i(0, -1)]
const S3_RANGE: Array[Vector2i] = [Vector2i(0, 3), Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1), Vector2i(0, -2), Vector2i(1, -2), Vector2i(0, -3)]
var failures := 0
var data := {}


func _initialize() -> void:
	data["silverash"] = load("res://resources/operators/silverash.tres")
	var silver: OperatorData = data["silverash"]
	var target := silver.duplicate(true) as OperatorData
	target.operator_id = "target"
	target.max_health = 100000
	target.defense = 100
	target.talent_1.effect_type = ""
	target.talent_2.effect_type = ""
	target.branch_trait.effect_type = ""
	data["target"] = target
	check(silver.skills.size() == 3 and silver.skills[1].skill_name == "雪境生存法则" and silver.skills[2].skill_name == "真银斩", "Three original named skills")
	check(silver.skills[1].parameters_are_valid() and silver.skills[2].parameters_are_valid(), "Typed parameters valid")
	check(silver.skills[1].attack_range_override == S2_RANGE and silver.skills[2].attack_range_override == S3_RANGE, "Original range1-2 four cells and range3-7 sixteen cells")
	var stance := fixture(1)
	stance.units[0].hp = 1000
	for _tick in 150: stance.step([], [])
	check(stance.units[0].sp == 5 and stance.units[0].hp == 1000 and stance.units[0].skill_ticks_left == 0, "Initial0, five seconds charge, no off-state regeneration")
	stance.step([InputCommand.new(stance.tick, 1, "", 0, Vector2i.ZERO, 1)], [])
	check(stance.units[0].sp == 0 and stance.units[0].skill_ticks_left == -2 and SkillRules.defense_value(stance.units[0], silver) == 794 and SkillRules.attack_output_value(stance.units[0], silver) == 784, "S2 defense doubles, attack still allowed without ranged penalty")
	stance.step([InputCommand.new(stance.tick, 1, "", 0, Vector2i.ZERO, 1)], [])
	check(stance.units[0].skill_ticks_left == -2, "Cannot turn off without5SP")
	for _tick in 28: stance.step([], [])
	check(stance.units[0].hp == 1076 and stance.units[0].skill_hp_regen_accum == 240000, "Thirty active ticks regenerate76.8HP with preserved fraction: maxHP6percent then50percent")
	for _tick in 120: stance.step([], [])
	check(stance.units[0].hp == 1384 and stance.units[0].sp == 5 and stance.units[0].skill_ticks_left == -2, "150 active ticks give384HP and replenish5SP")
	stance.units[0].stun_ticks_left = 2
	stance.step([InputCommand.new(stance.tick, 1, "", 0, Vector2i.ZERO, 1)], [])
	check(stance.units[0].skill_ticks_left == -2 and stance.units[0].sp == 5 and stance.units[0].hp == 1386, "Stun rejects toggle but does not stop regeneration")
	stance.units[0].stun_ticks_left = 0
	stance.step([InputCommand.new(stance.tick, 1, "", 0, Vector2i.ZERO, 1)], [])
	check(stance.units[0].sp == 0 and stance.units[0].skill_ticks_left == 0 and SkillRules.defense_value(stance.units[0], silver) == 397 and SkillRules.attack_output_value(stance.units[0], silver) == 627 and AttackRange.effective_offsets(stance.units[0], silver) == silver.attack_range, "Second5SP returns original stats/range and ranged penalty")
	var hp := stance.units[0].hp
	for _tick in 30: stance.step([], [])
	check(stance.units[0].hp == hp, "Turning off stops regeneration")
	# The normal talent refresh owns blessings; use a real Exusiai aura in this fixture.
	data["exusiai"] = load("res://resources/operators/exusiai.tres")
	var blessing := fixture(1)
	blessing.units.append(UnitState.new(1, 0, "exusiai", Vector2i(15, 2), 1673, 0, 10000))
	blessing.units[1].blessing_target_id = 0
	blessing.next_unit_id = 2
	blessing.units[0].hp = 1000
	blessing.units[0].sp = 5
	blessing.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 1)], [])
	var initial_hp := blessing.units[0].hp
	for _tick in 29: blessing.step([], [])
	check(SkillRules.max_health_value(blessing.units[0], silver) == 2816 and blessing.units[0].hp - initial_hp == 82, "Regen uses real blessed maximum2816 and fractional ticks")
	data.erase("exusiai")
	for facing in 4:
		for index in [1, 2]:
			var attack := fixture(index, facing)
			attack.units[0].sp = silver.skills[index].sp_required
			attack.ball.cell = attack.units[0].cell + AttackRange.rotate_offset(Vector2i.RIGHT, facing)
			if index == 2:
				attack._ball_data = MatchState.DEFAULT_BALL_DATA.duplicate(true)
				attack._ball_data.kick_threshold = 10000
			attack.units[0].attack_ticks_left = 1
			attack.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, index)], [])
			check(attack.ball.accum == AttackRange.rotate_offset(Vector2i(784 if index == 1 else 2210, 0), facing), "Raw ball attack once without ranged/PvP penalty index%d facing%d" % [index, facing])
			var boxes := fixture(index, facing)
			boxes.units[0].sp = silver.skills[index].sp_required
			boxes.units[0].attack_ticks_left = 1
			boxes.tactical_boxes = [TacticalBox.new(0, boxes.units[0].cell + AttackRange.rotate_offset(Vector2i.RIGHT, facing), 3)]
			boxes.ball.cell = boxes.units[0].cell
			boxes.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, index)], [])
			check(boxes.tactical_boxes[0].hits_left == 2 and boxes.ball.accum == Vector2i.ZERO, "Box one hit, higher priority than ball index%d facing%d" % [index, facing])
			var ranges := fixture(index, facing)
			ranges.units[0].sp = silver.skills[index].sp_required
			ranges.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, index)], [])
			var expected := S2_RANGE if index == 1 else S3_RANGE
			for x in range(-4, 5):
				for y in range(-4, 5):
					var local := Vector2i(x, y)
					check(ranges._is_in_attack_range(ranges.units[0], ranges.units[0].cell + AttackRange.rotate_offset(local, facing), AttackRange.effective_offsets(ranges.units[0], silver)) == (local in expected), "Exact range membership index%d facing%d offset%s" % [index, facing, local])
	var multi := fixture(2)
	multi.units[0].sp = 90
	multi.units[0].attack_ticks_left = 1
	for cell in [Vector2i(12, 2), Vector2i(12, 3), Vector2i(13, 3), Vector2i(12, 4), Vector2i(13, 4), Vector2i(14, 4), Vector2i(12, 6)]:
		multi.units.append(UnitState.new(multi.units.size(), 1, "target", cell, 100000, 0, 10000))
	multi.next_unit_id = 8
	multi.tactical_boxes = [TacticalBox.new(0, Vector2i(15, 5), 3)]
	multi.ball.cell = Vector2i(12, 8)
	multi.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 2)], [])
	for index in range(1, 8):
		check(multi.units[index].hp == (99144 if index <= 6 else 100000), "Six unique targets, physical guard0.4 DEF70, stableIDs target%d" % index)
	check(multi.ball.accum == Vector2i.ZERO and multi.tactical_boxes[0].hits_left == 3 and SkillRules.defense_value(multi.units[0], silver) == 119, "Enemies suppress box/ball and S3 defense minus70percent")
	var dodging := target.duplicate(true) as OperatorData
	dodging.operator_id = "dodging"
	dodging.dodge_physical = 50
	data["dodging"] = dodging
	var ordered := fixture(2)
	ordered.units[0].sp = 90
	ordered.units[0].attack_ticks_left = 1
	var cells: Array[Vector2i] = [Vector2i(12, 4), Vector2i(13, 4), Vector2i(14, 4), Vector2i(12, 6), Vector2i(13, 6), Vector2i(14, 6)]
	for cell in cells:
		ordered.units.append(UnitState.new(ordered.units.size(), 1, "dodging", cell, 100000, 0, 10000))
	ordered.units.append(UnitState.new(7, 1, "nightingale_phantom", Vector2i(15, 5), 6000, 0, 10000))
	ordered.next_unit_id = 8
	ordered.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 2)], [])
	var oracle := RNG.new(123)
	for index in range(1, 6):
		check(ordered.units[index].hp == (100000 if oracle.next_percent() < 50 else 99144), "Selected enemies receive ascendingID RNG roll%d" % index)
	check(ordered.units[6].hp == 100000 and ordered.units[7].hp == (6000 if oracle.next_percent() < 30 else 5116), "HighID taunt selected instead of sixth ordinary enemy, settled last")
	data.erase("dodging")
	var duration := fixture(2)
	for _tick in 450: duration.step([], [])
	check(duration.units[0].sp == 90, "Initial75 reaches90 after15s")
	duration.step([InputCommand.new(duration.tick, 1, "", 0, Vector2i.ZERO, 2)], [])
	for _tick in 898: duration.step([], [])
	check(duration.units[0].skill_ticks_left == 1 and duration.units[0].sp == 0, "899 active ticks freeze SP")
	duration.step([], [])
	check(duration.units[0].skill_ticks_left == 0 and SkillRules.defense_value(duration.units[0], silver) == 397 and SkillRules.attack_output_value(duration.units[0], silver) == 627 and AttackRange.effective_offsets(duration.units[0], silver) == silver.attack_range, "900tick expiry restores all original behavior")
	var retired := fixture(1)
	retired.squad_skills[0][retired.squad_ids[0].find("silverash")] = 1
	retired.units[0].sp = 5
	retired.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 1)], [])
	retired.step([InputCommand.new(retired.tick, 2, "", 0)], [])
	for _tick in 1890: retired.step([], [])
	retired.sides[0].cost = 99
	retired.step([InputCommand.new(retired.tick, 0, "silverash", -1, Vector2i(12, 5))], [])
	check(retired.units.size() == 1 and retired.units[0].skill_ticks_left == 0 and retired.units[0].sp == 0 and retired.units[0].skill_hp_regen_accum == 0, "Redeployment preserves carriedS2 but resets stance/SP/fraction")
	var ai_state := fixture(1)
	ai_state.units[0].sp = 5
	ai_state.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 1)], [])
	ai_state.units[0].sp = 5
	var ai := AIInput.new(0, data)
	for tick in Config.AI_SKILL_REACTION_TICKS:
		check(ai.commands_for_tick(ai_state).is_empty(), "AI stance switch observes skill reaction")
		ai_state.step([], [])
	var before := ai_state.state_hash()
	var commands := ai.commands_for_tick(ai_state)
	check(ai_state.state_hash() == before and commands.any(func(command: InputCommand) -> bool: return command.kind == 1 and command.unit_id == 0 and command.skill_index == 1), "Existing debugAI emits valid stance switch while readonly")
	var first := fixture(1)
	var second := fixture(1)
	for t in 700:
		var inputs: Array[InputCommand] = []
		if t in [160, 330, 500, 670]:
			inputs.append(InputCommand.new(t, 1, "", 0, Vector2i.ZERO, 1))
		first.step(inputs, [])
		second.step(inputs, [])
		check(first.state_hash() == second.state_hash(), "700tick every-tick toggle replay %d" % t)
	var importer := GDScript.new()
	importer.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	check(importer.reload() == OK, "Importer compiles")
	var imported := {}
	for file in DirAccess.get_files_at("res://resources/operators"):
		if file.ends_with(".tres"):
			var op := load("res://resources/operators/" + file) as OperatorData
			imported[op.operator_id] = op.duplicate(true)
			imported[op.operator_id].skills.resize(1)
	check(importer.new()._append_skills(imported), "CSV appends all approved skills")
	for index in [1, 2]:
		check(imported["silverash"].skills[index].effect_params == silver.skills[index].effect_params and imported["silverash"].skills[index].attack_range_override == silver.skills[index].attack_range_override and imported["silverash"].skills[index].duration == silver.skills[index].duration, "CSV/resource parity index%d" % index)
	var invalid := silver.skills[1].duplicate(true) as SkillResource
	invalid.effect_params["regen_health_percent"] = 6.5
	check(not invalid.parameters_are_valid(), "Reject fractional integer percentage")
	invalid = silver.skills[2].duplicate(true)
	invalid.effect_params["target_count"] = 0
	check(not invalid.parameters_are_valid(), "Reject zero targets")
	print("SilverAsh S2/S3: stance5SP, percentage regeneration, four directions, six targets, raw push/box priority, expiration/redeploy, AI/CSV and deterministic replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func fixture(index: int, facing: int = 0) -> MatchState:
	var state := MatchState.new(123, data)
	state.ball.cell = Vector2i(5, 5)
	state.units = [UnitState.new(0, 0, "silverash", Vector2i(12, 5), 2560, 75 if index == 2 else 0, 10000, facing, index)]
	state.next_unit_id = 1
	return state


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
