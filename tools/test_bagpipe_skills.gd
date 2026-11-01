extends SceneTree

var failures := 0
var data := {}


func _initialize() -> void:
	data["bagpipe"] = load("res://resources/operators/bagpipe.tres")
	var bag: OperatorData = data["bagpipe"]
	var enemy := bag.duplicate(true) as OperatorData
	enemy.operator_id = "target"
	enemy.max_health = 100000
	enemy.defense = 100
	enemy.talent_1.effect_type = ""
	enemy.talent_2.effect_type = ""
	enemy.branch_trait.effect_type = ""
	data["target"] = enemy
	check(bag.skills.size() == 3 and bag.skills[0].skill_name == "迅捷打击·γ型" and bag.skills[1].skill_name == "高效冲击" and bag.skills[2].skill_name == "闭膛连发", "Three original names")
	check(bag.skills[1].parameters_are_valid() and bag.skills[2].parameters_are_valid() and SkillRules.sp_limit(bag.skills[1]) == 12, "Typed resources and three4SP charges")
	for index in [1, 2]:
		var deployed := MatchState.new(123, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [["bagpipe"], ["bagpipe"]], [[index], [index]])
		deployed.ball.cell = Vector2i(5, 5)
		deployed.sides[0].cost = 99
		deployed.step([InputCommand.new(0, 0, "bagpipe", -1, Vector2i(12, 5), -1, 0)], [])
		check(deployed.units[0].sp == (6 if index == 1 else 31) and deployed.units[0].skill_index == index, "Actual deployment adds Military Tradition6 index%d" % index)
		for _tick in (180 if index == 1 else 269): deployed.step([], [])
		check(deployed.units[0].sp == (12 if index == 1 else 40) and deployed.units[0].skill_ticks_left == 0, "S2 stores charges without target, S3 ready after9s index%d" % index)
		var current := deployed.units[0].sp
		deployed.step([InputCommand.new(deployed.tick, 1, "", 0, Vector2i.ZERO, 0)], [])
		check(deployed.units[0].sp == current and deployed.units[0].skill_ticks_left == 0, "Wrong carried index ignored")
	var invalid_manual := fixture(1)
	invalid_manual.units[0].sp = 12
	invalid_manual.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 1)], [])
	check(invalid_manual.units[0].sp == 12 and invalid_manual.units[0].skill_ticks_left == 0, "S2 cannot be activated manually")
	for index in [1, 2]:
		for facing in 4:
			var state := fixture(index, facing)
			state.units[0].sp = 12 if index == 1 else 40
			state.units[0].attack_ticks_left = 1 if index == 1 else 0
			var cell := state.units[0].cell + AttackRange.rotate_offset(Vector2i.RIGHT, facing)
			state.units.append(UnitState.new(1, 1, "target", cell, 100000, 0, 10000))
			state.next_unit_id = 2
			var commands: Array[InputCommand] = []
			if index == 2: commands.append(InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 2))
			state.step(commands, [])
			var oracle := RNG.new(123)
			var total := 0
			for _shot in (2 if index == 1 else 3):
				var proc := oracle.next_percent() < 25
				total += (364 if proc else 276) if index == 1 else (402 if proc else 305)
			check(state.units[1].hp == 100000 - total and state.rng.state == oracle.state, "Independent per-strike talent and integer physical damage index%d facing%d" % [index, facing])
			check(state.units[0].sp == (8 if index == 1 else 0) and state.units[0].skill_ticks_left == (0 if index == 1 else 599), "One charge per S2 action or one S3 activation")
			if index == 2:
				check(SkillRules.attack_value(state.units[0], bag) == 1289 and SkillRules.defense_value(state.units[0], bag) == 840 and SkillRules.attack_interval_ticks(state.units[0], bag) == 51 and SkillRules.block_count_value(state.units[0], bag) == 2, "S3 ATK/DEF120percent, interval70percent, block+1")
			var ball := fixture(index, facing)
			ball._ball_data = MatchState.DEFAULT_BALL_DATA.duplicate(true)
			ball._ball_data.kick_threshold = 10000
			ball.units[0].sp = 4 if index == 1 else 40
			ball.units[0].attack_ticks_left = 1 if index == 1 else 0
			ball.ball.cell = ball.units[0].cell + AttackRange.rotate_offset(Vector2i.RIGHT, facing)
			ball.step(commands, [])
			oracle = RNG.new(123)
			total = 0
			for _shot in (2 if index == 1 else 3):
				total += (1524 if oracle.next_percent() < 25 else 1172) if index == 1 else (1676 if oracle.next_percent() < 25 else 1289)
			check(ball.ball.accum == AttackRange.rotate_offset(Vector2i(total, 0), facing) and ball.rng.state == oracle.state, "Per-strike raw ball pushes, no PvP scaling index%d facing%d" % [index, facing])
			var box := fixture(index, facing)
			box.units[0].sp = 12 if index == 1 else 40
			box.units[0].attack_ticks_left = 1 if index == 1 else 0
			box.tactical_boxes = [TacticalBox.new(0, box.units[0].cell + AttackRange.rotate_offset(Vector2i.RIGHT, facing), 3)]
			box.ball.cell = box.units[0].cell
			var rng_before := box.rng.state
			box.step(commands, [])
			if index == 1:
				check(box.tactical_boxes.size() == 1 and box.tactical_boxes[0].hits_left == 1 and box.rng.state == rng_before, "S2 two strikes hit box twice without crit RNG")
			else:
				var loot_rng := RNG.new(rng_before)
				loot_rng.next_u32()
				check(box.tactical_boxes.is_empty() and box.sides[0].tactical_items.reduce(func(a: int, b: int) -> int: return a + b, 0) == 1 and box.rng.state == loot_rng.state, "S3 three strikes destroy box and grant exactly one drop")
			check(box.ball.accum == Vector2i.ZERO and box.units[0].sp == (8 if index == 1 else 0), "Box priority and one skill cost per action")
			var wounded_box := fixture(index, facing)
			wounded_box.units[0].sp = 12 if index == 1 else 40
			wounded_box.units[0].attack_ticks_left = 1 if index == 1 else 0
			wounded_box.tactical_boxes = [TacticalBox.new(0, cell, 1), TacticalBox.new(1, cell + AttackRange.rotate_offset(Vector2i.RIGHT, facing), 3)]
			wounded_box.ball.cell = wounded_box.units[0].cell
			wounded_box.step(commands, [])
			check(wounded_box.tactical_boxes.size() == 1 and wounded_box.tactical_boxes[0].box_id == 1 and wounded_box.tactical_boxes[0].hits_left == 3 and wounded_box.sides[0].tactical_items.reduce(func(a: int, b: int) -> int: return a + b, 0) == 1 and wounded_box.ball.accum == Vector2i.ZERO, "Destroyed box stops remaining strikes without retarget or duplicate drop")
	var stopped := fixture(1)
	stopped.units[0].sp = 4
	stopped.units[0].attack_ticks_left = 1
	stopped.sides[0].cost = 50
	stopped.units.append(UnitState.new(1, 1, "target", Vector2i(13, 5), 1, 0, 10000))
	stopped.next_unit_id = 2
	stopped.step([], [])
	var first_roll := RNG.new(123)
	first_roll.next_percent()
	check(stopped.units.size() == 1 and stopped.sides[0].cost == 51 and stopped.rng.state == first_roll.state and stopped.units[0].sp == 0, "Dead main target stops second strike/extra RNG, kill refunds once")
	var moving := fixture(2)
	moving.units[0].sp = 40
	moving.units[0].attack_ticks_left = 0
	moving.ball.cell = Vector2i(13, 5)
	moving.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 2)], [])
	var two_rolls := RNG.new(123)
	two_rolls.next_percent()
	two_rolls.next_percent()
	check(moving.ball.move_ticks_left > 0 and moving.rng.state == two_rolls.state, "Kick begins after second strike; third does not consume RNG")
	# A widened fixture tests the pre-existing extra-target talent without changing the actual two-cell range.
	var expanded := bag.duplicate(true) as OperatorData
	expanded.attack_range.append(Vector2i(2, 0))
	data["bagpipe"] = expanded
	var splash := fixture(2)
	splash.units[0].sp = 40
	splash.units[0].attack_ticks_left = 0
	splash.units.append(UnitState.new(1, 1, "target", Vector2i(13, 5), 100000, 0, 10000))
	splash.units.append(UnitState.new(2, 1, "target", Vector2i(14, 5), 100000, 0, 10000))
	splash.next_unit_id = 3
	splash.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 2)], [])
	var rolls := RNG.new(123)
	var extra_damage := 0
	for _shot in 3:
		if rolls.next_percent() < 25: extra_damage += 402
	check(splash.units[2].hp == 100000 - extra_damage, "Extra target appears only in the independently proc'd strike")
	data["bagpipe"] = bag
	var duration := fixture(2)
	duration.units[0].sp = 40
	duration.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 2)], [])
	for _tick in 598: duration.step([], [])
	check(duration.units[0].skill_ticks_left == 1 and duration.units[0].sp == 0, "599 active ticks freeze SP")
	duration.step([], [])
	check(duration.units[0].skill_ticks_left == 0 and SkillRules.attack_value(duration.units[0], bag) == 586 and SkillRules.defense_value(duration.units[0], bag) == 382 and SkillRules.attack_interval_ticks(duration.units[0], bag) == 30 and SkillRules.block_count_value(duration.units[0], bag) == 1, "600tick expiration restores attributes, interval and block")
	var first := fixture(1)
	var second := fixture(1)
	for t in 600:
		first.step([], [])
		second.step([], [])
		check(first.state_hash() == second.state_hash(), "Every-tick deterministic replay %d" % t)
	var importer := GDScript.new()
	importer.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	check(importer.reload() == OK, "Importer compiles")
	var imported := {}
	for file in DirAccess.get_files_at("res://resources/operators"):
		if file.ends_with(".tres"):
			var op := load("res://resources/operators/" + file) as OperatorData
			imported[op.operator_id] = op.duplicate(true)
			imported[op.operator_id].skills.resize(1)
	check(importer.new()._append_skills(imported), "CSV imports all implemented skills")
	for index in [1, 2]: check(imported["bagpipe"].skills[index].effect_params == bag.skills[index].effect_params and imported["bagpipe"].skills[index].trigger_type == bag.skills[index].trigger_type, "Typed CSV/resource match")
	var invalid := bag.skills[1].duplicate(true) as SkillResource
	invalid.effect_params["shot_count"] = 1.5
	check(not invalid.parameters_are_valid(), "Reject fractional shot count")
	print("Bagpipe S2/S3: initialSP/charges, per-strike proc and targets, kill refund/stop, ball/box, duration/interval/block, CSV and replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func fixture(index: int, facing: int = 0) -> MatchState:
	var state := MatchState.new(123, data)
	state.ball.cell = Vector2i(5, 5)
	state.units = [UnitState.new(0, 0, "bagpipe", Vector2i(12, 5), 2484, 0, 10000, facing, index)]
	state.next_unit_id = 1
	return state


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
