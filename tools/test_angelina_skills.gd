extends SceneTree

var failures := 0
var data := {}


func _initialize() -> void:
	data.angelina = load("res://resources/operators/angelina.tres")
	data.bagpipe = load("res://resources/operators/bagpipe.tres")
	data.phantom = load("res://resources/operators/phantom.tres")
	data.hoshiguma = load("res://resources/operators/hoshiguma.tres")
	var target := data.bagpipe.duplicate(true) as OperatorData
	target.operator_id = "target"
	target.max_health = 100000
	target.magic_resist = 0
	target.talent_1.effect_type = ""
	target.talent_2.effect_type = ""
	data.target = target
	for index in [1, 2]:
		check(data.angelina.skills[index].parameters_are_valid(), "Typed original skill")
		var state := fixture(index)
		state.units[0].hp = 1000
		state.tactical_boxes.append(TacticalBox.new(0, Vector2i(13, 5), 3))
		state.ball.cell = Vector2i(14, 5)
		for tick in 30: state.step([], [])
		check(state.units[0].hp == 1010 and state.units[0].sp == 1 and state.tactical_boxes[0].hits_left == 3 and state.ball.accum.x == 0 and state.units[0].last_attack_tick < 0, "Inactive: no attacks, normal charge and folded regen")
		state.units[0].sp = data.angelina.skills[index].sp_required
		state.units[0].attack_ticks_left = 1
		state.step([command(state, index)], [])
		check(state.tactical_boxes[0].hits_left == 2, "Multi-target still hits crate once per action")
		var hp := state.units[0].hp
		for tick in 30: state.step([], [])
		check(state.units[0].hp == hp, "Active skill stops inactive regen")
		state.units[0].skill_ticks_left = 1
		state.step([], [])
		check(state.units[0].skill_ticks_left == 0, "Skill expiry")
		for tick in 30: state.step([], [])
		check(state.units[0].hp == hp + 10, "Expiry restores regen")
	var rapid := fixture(1)
	rapid.units.append(UnitState.new(1, 1, "target", Vector2i(13, 5), 100000, 0, 10000))
	rapid.next_unit_id = 2
	rapid.units[0].sp = 15
	rapid.units[0].attack_ticks_left = 1
	rapid.step([command(rapid, 1)], [])
	check(SkillRules.attack_interval_ticks(rapid.units[0], data.angelina) == 8 and SkillRules.attack_value(rapid.units[0], data.angelina) == 542 and rapid.units[1].hp == 99951 and rapid.units[1].slow_ticks_left == 24, "S2 interval8 and 45percent damage; ATK unchanged and hit slow")
	for facing in 4:
		var multi := fixture(2, facing)
		var offsets := data.angelina.skills[2].attack_range_override as Array[Vector2i]
		check(offsets.size() == 19, "Original y-4 nineteen cells")
		for id in 6:
			multi.units.append(UnitState.new(id + 1, 1, "target", multi.units[0].cell + AttackRange.rotate_offset(offsets[id], facing), 100000, 0, 10000))
		multi.next_unit_id = 7
		multi.units[0].sp = 25
		multi.units[0].attack_ticks_left = 1
		multi.step([command(multi, 2)], [])
		var hit := 0
		for enemy in multi.units:
			if enemy.side == 1 and enemy.hp == 99729: hit += 1
		check(hit == 5 and multi.units[6].hp == 100000, "Five distinct targets, four facing range%d" % facing)
	var weight := fixture(2)
	weight.units.append(UnitState.new(1, 1, "target", Vector2i(14, 5), 100000, 0, 10000))
	weight.units.append(UnitState.new(2, 1, "phantom", Vector2i(16, 5), 1000, 0, 10000))
	weight.next_unit_id = 3
	check(DisplacementRules.effective_weight(weight, weight.units[1]) == 1, "Base weight")
	weight.units[0].skill_ticks_left = 10
	check(DisplacementRules.effective_weight(weight, weight.units[1]) == 0 and DisplacementRules.effective_weight(weight, weight.units[2]) == 0 and DisplacementRules.effective_weight(weight, weight.units[0]) == 1, "Opponent only and minimum zero")
	weight.units.append(UnitState.new(3, 0, "angelina", Vector2i(12, 7), 1385, 0, 10000, 0, 2))
	weight.units[3].skill_ticks_left = 10
	weight.next_unit_id = 4
	check(DisplacementRules.effective_weight(weight, weight.units[1]) == 0, "Same named effect does not stack")
	weight.units.append(UnitState.new(4, 1, MatchState.CLONE_DATA.operator_id, Vector2i(1, 9), 1000, 0, 10000))
	weight.units.append(UnitState.new(5, 1, "hoshiguma", Vector2i(1, 8), 1000, 0, 10000))
	weight.next_unit_id = 6
	check(DisplacementRules.effective_weight(weight, weight.units[4]) == 0 and DisplacementRules.effective_weight(weight, weight.units[5]) == 2, "Global enemy clone and defender; same aura does not stack")
	check(DisplacementRules.apply_unit(weight, weight.units[3], weight.units[1], Vector2i.RIGHT, 0) == 0, "Force0 minus weight0 remains zero distance")
	weight.units[0].hp = 0
	check(DisplacementRules.effective_weight(weight, weight.units[1]) == 0, "Remaining source supplies aura")
	weight.units[3].skill_ticks_left = 0
	check(DisplacementRules.effective_weight(weight, weight.units[1]) == 1, "Expiry/death restore")
	weight.units[3].skill_ticks_left = 10
	check(DisplacementRules.apply_unit(weight, weight.units[3], weight.units[1], Vector2i.RIGHT, 2) == 2 and weight.units[1].cell == Vector2i(16, 5) and weight.units[2].cell == Vector2i(18, 5), "Zero-weight rigid group retains relative positions")
	check(weight.ball.displacement_steps_left == 0 and weight._ball_data.weight == MatchState.DEFAULT_BALL_DATA.weight, "Ball weight remains read-only")
	for index in [1, 2]:
		var ball := fixture(index)
		ball.ball.cell = Vector2i(13, 5)
		ball.units[0].sp = data.angelina.skills[index].sp_required
		ball.units[0].attack_ticks_left = 1
		ball.step([command(ball, index)], [])
		check(ball.ball.accum.x == (244 if index == 1 else 1355), "Only one main ball hit index%d" % index)
		var first := fixture(index)
		var replay := fixture(index)
		first.units[0].sp = data.angelina.skills[index].sp_required
		replay.units[0].sp = first.units[0].sp
		for tick in 900:
			var commands: Array[InputCommand] = []
			if tick == 0: commands.append(command(first, index))
			first.step(commands, [])
			replay.step(commands, [])
			check(first.state_hash() == replay.state_hash(), "Replay index%d tick%d" % [index, tick])
	var importer := GDScript.new()
	importer.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	check(importer.reload() == OK, "Importer compiles")
	var imported := {}
	for file in DirAccess.get_files_at("res://resources/operators"):
		if file.ends_with(".tres"):
			var op := load("res://resources/operators/" + file).duplicate(true) as OperatorData
			op.skills.resize(1)
			imported[op.operator_id] = op
	check(importer.new()._append_skills(imported), "CSV imports")
	for index in [1, 2]:
		check(imported.angelina.skills[index].effect_params == data.angelina.skills[index].effect_params and imported.angelina.skills[index].attack_range_override == data.angelina.skills[index].attack_range_override, "Resource/CSV match")
	print("Angelina S2/S3: inactive attack/regen, rapid magic/slow, five targets/range, weight aura/group and900tick replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func fixture(index: int, facing: int = 0) -> MatchState:
	var state := MatchState.new(123, data)
	state.units = [UnitState.new(0, 0, "angelina", Vector2i(12, 5), 1385, 0, 10000, facing, index)]
	state.next_unit_id = 1
	state.ball.cell = Vector2i(5, 10)
	return state


func command(state: MatchState, index: int) -> InputCommand:
	return InputCommand.new(state.tick, 1, "", 0, Vector2i.ZERO, index)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
