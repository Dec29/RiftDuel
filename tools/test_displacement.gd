extends SceneTree

var failures := 0
var data := {}
var arena := ArenaData.new()


func _initialize() -> void:
	for id in ["bagpipe", "phantom", "hoshiguma"]:
		data[id] = load("res://resources/operators/%s.tres" % id).duplicate(true)
		data[id].talent_1.effect_type = ""
		data[id].talent_2.effect_type = ""
	for row in 11: arena.terrain_rows.append("g".repeat(10) + "n" + "g".repeat(10))
	check(DisplacementRules.weight(data.bagpipe) == 1 and DisplacementRules.weight(data.phantom) == 0 and DisplacementRules.weight(data.hoshiguma) == 3, "PvP weights inherit profession/branch")
	for force in [0, 1, 2, 3, 7]:
		var state := fixture()
		var distance := DisplacementRules.apply_unit(state, state.units[0], state.units[1], Vector2i.RIGHT, force)
		check(distance == maxi(0, force - 1) and state.units[1].cell == Vector2i(12 + maxi(0, force - 1), 5), "Exact difference, equal zero, no three-cell cap: force%d" % force)
	for facing in 4:
		var state := fixture()
		state.units[0].cell = Vector2i(5, 5)
		state.units[0].facing = facing
		state.units[1].cell = Vector2i(14, 5)
		check(DisplacementRules.apply_unit(state, state.units[0], state.units[1], AttackRange.rotate_offset(Vector2i.RIGHT, facing), 3) == 2, "Four world directions facing%d" % facing)
	for mode in ["push", "pull"]:
		var state := fixture()
		state.units[0].cell = Vector2i(15, 5) if mode == "push" else Vector2i(5, 5)
		state.units[1].cell = Vector2i(8, 5)
		check(DisplacementRules.apply_unit(state, state.units[0], state.units[1], Vector2i.RIGHT, 3) == 1 and state.units[1].cell.x == 9, "Endpoint on midline shortens whole movement: " + mode)
	var crossing := fixture()
	crossing.units[0].cell = Vector2i(5, 5)
	crossing.units[1].cell = Vector2i(8, 5)
	check(DisplacementRules.apply_unit(crossing, crossing.units[0], crossing.units[1], Vector2i.RIGHT, 4) == 3 and crossing.units[1].cell.x == 11, "Path may cross line")
	var ball_on_path := fixture()
	ball_on_path.ball.cell = Vector2i(14, 5)
	check(DisplacementRules.apply_unit(ball_on_path, ball_on_path.units[0], ball_on_path.units[1], Vector2i.RIGHT, 4) == 3 and ball_on_path.ball.cell == Vector2i(14, 5) and ball_on_path.ball.accum == Vector2i.ZERO, "Ball is never gathered into the unit group or pushed by it")
	var high_target := fixture()
	high_target.platform_cells.append(high_target.units[1].cell)
	check(DisplacementRules.apply_unit(high_target, high_target.units[0], high_target.units[1], Vector2i.RIGHT, 9) == 0, "First slice leaves high-tile units fixed")
	var chain := fixture()
	chain.units.append(UnitState.new(2, 0, "phantom", Vector2i(13, 5), 1000, 0, 10000))
	chain.units.append(UnitState.new(3, 1, "hoshiguma", Vector2i(14, 5), 1000, 0, 10000))
	check(DisplacementRules.apply_unit(chain, chain.units[0], chain.units[1], Vector2i.RIGHT, 6) == 2 and chain.units[1].cell == Vector2i(14, 5) and chain.units[2].cell == Vector2i(15, 5) and chain.units[3].cell == Vector2i(16, 5), "Chain includes both sides; sum weights1+0+3 and preserve relative cells")
	var equal := fixture()
	equal.units.append(UnitState.new(2, 1, "hoshiguma", Vector2i(13, 5), 1000, 0, 10000))
	check(DisplacementRules.apply_unit(equal, equal.units[0], equal.units[1], Vector2i.RIGHT, 4) == 0 and equal.units[1].cell.x == 12 and equal.units[2].cell.x == 13, "Combined weight equal force: no partial move")
	var crowded_line := fixture()
	crowded_line.units[0].cell = Vector2i(5, 5)
	crowded_line.units[1].cell = Vector2i(8, 5)
	crowded_line.units.append(UnitState.new(2, 1, "bagpipe", Vector2i(9, 5), 1000, 0, 10000))
	check(DisplacementRules.apply_unit(crowded_line, crowded_line.units[0], crowded_line.units[1], Vector2i.RIGHT, 4) == 0, "Recheck every member after shortening; neither may stop on line")
	var pull := fixture()
	pull.units[0].cell = Vector2i(12, 5)
	pull.units[1].cell = Vector2i(15, 5)
	check(DisplacementRules.direction(pull.units[0], pull.units[1].cell, "pull") == Vector2i.LEFT and DisplacementRules.apply_unit(pull, pull.units[0], pull.units[1], Vector2i.LEFT, 7) == 2 and pull.units[1].cell.x == 13 and pull.units[0].cell.x == 12, "Puller is fixed obstacle; no crossing source")
	for obstacle in ["platform", "box", "warning", "item", "edge"]:
		var state := fixture()
		if obstacle == "platform": state.platform_cells.append(Vector2i(14, 5))
		if obstacle == "box": state.tactical_boxes.append(TacticalBox.new(0, Vector2i(14, 5), 3))
		if obstacle == "warning": state.box_warning_cell = Vector2i(14, 5)
		if obstacle == "item": state.tactical_item_effects.append(TacticalItemEffect.new(2, 0, Vector2i(14, 5), 0, 0))
		if obstacle == "edge": state.units[1].cell = Vector2i(19, 5)
		check(DisplacementRules.apply_unit(state, state.units[0], state.units[1], Vector2i.RIGHT, 9) == 1, "Obstacle clips whole path: " + obstacle)
	var motion := fixture()
	motion.units[1].attack_ticks_left = 17
	motion.units[1].sp = 0
	DisplacementRules.apply_unit(motion, motion.units[0], motion.units[1], Vector2i.RIGHT, 3)
	var before := motion.units[1].cell
	check(DisplacementRules.apply_unit(motion, motion.units[0], motion.units[1], Vector2i.LEFT, 3) == 0 and motion.units[1].cell == before, "First movement owns its feedback interval")
	for tick in 7: motion.step([], [])
	check(motion.units[1].displacement_ticks_left == 1 and motion.units[1].attack_ticks_left == 17, "Movement freezes attack cooldown")
	motion.step([], [])
	check(motion.units[1].displacement_ticks_left == 0 and motion.units[1].attack_ticks_left == 16, "Movement expires and attacks resume")
	_test_ball()
	_test_attack()
	print("Displacement: force-minus-total-weight, chain/line/collision, ball exceptions, typed skill, movement clocks and replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _test_ball() -> void:
	for obstacle in ["none", "platform", "box", "defender"]:
		var state := fixture()
		state.units.clear()
		state.ball.cell = Vector2i(9, 5)
		if obstacle == "platform": state.platform_cells.append(Vector2i(12, 5))
		if obstacle == "box": state.tactical_boxes.append(TacticalBox.new(0, Vector2i(12, 5), 3))
		if obstacle == "defender": state.units.append(UnitState.new(0, 0, "hoshiguma", Vector2i(12, 5), 1000, 0, 10000))
		check(DisplacementRules.apply_ball(state, Vector2i.RIGHT, 1) == 0, "Ball equal weight does not move")
		check(DisplacementRules.apply_ball(state, Vector2i.RIGHT, 5) == 4, "Ball distance from BallData weight")
		for tick in 32: state.step([], [])
		check(state.ball.cell == Vector2i(13 if obstacle == "none" else 11, 5) and state.ball.displacement_steps_left == 0, "Ball ignores line; collision cancels remaining cells: " + obstacle)
	var goal := fixture()
	goal.units.clear()
	goal.ball.cell = Vector2i(2, 5)
	DisplacementRules.apply_ball(goal, Vector2i.LEFT, 10)
	for tick in 16: goal.step([], [])
	check(goal.result == MatchState.RESULT_BLUE_WIN and goal.ball.cell.x == 0, "Multi-cell shift still resolves goal on first arrival")
	var frozen := goal.state_hash()
	goal.step([], [])
	check(goal.state_hash() == frozen, "Ended match freezes movement state")


func _test_attack() -> void:
	var prototype := data.bagpipe.duplicate(true) as OperatorData
	prototype.attack_range = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)]
	prototype.skills[0].effect_type = "shift_attack"
	prototype.skills[0].effect_params = {"attack_mult": 1.0, "shift_force": 4, "shift_mode": "push"}
	prototype.skills[0].trigger_type = "attack"
	prototype.skills[0].sp_recharge_type = "time"
	prototype.skills[0].sp_required = 4
	prototype.skills[0].initial_sp = 0
	prototype.skills[0].duration = 0.0
	check(prototype.skills[0].parameters_are_valid(), "Typed experimental shift skill")
	var invalid := prototype.skills[0].duplicate(true) as SkillResource
	invalid.effect_params["shift_force"] = 4.5
	check(not invalid.parameters_are_valid(), "Reject fractional force")
	invalid.effect_params["shift_force"] = 4
	invalid.effect_params["shift_mode"] = "teleport"
	check(not invalid.parameters_are_valid(), "Reject unsupported displacement mode")
	var definitions := data.duplicate()
	definitions.bagpipe = prototype
	var first := fixture(definitions)
	var replay := fixture(definitions)
	for state in [first, replay]:
		state.units[0].cell = Vector2i(11, 5)
		state.units[0].facing = 0
		state.units[0].sp = 4
		state.units[0].attack_ticks_left = 1
	for tick in 120:
		first.step([], [])
		replay.step([], [])
		check(first.state_hash() == replay.state_hash(), "Real skill every-tick replay %d" % tick)
		if tick == 0: check(first.units[1].cell.x == 15 and first.units[0].sp == 0 and first.units[1].hp < 1000, "Actual attack consumes one charge, damages then shifts")
	var changed := fixture()
	var hash := changed.state_hash()
	changed.units[0].displacement_origin.x = 1
	check(changed.state_hash() != hash, "Origin participates in hash")
	for field in ["displacement_ticks_left", "displacement_duration_ticks"]:
		changed = fixture()
		hash = changed.state_hash()
		changed.units[0].set(field, 1)
		check(changed.state_hash() != hash, field + " participates in hash")
	changed = fixture()
	hash = changed.state_hash()
	changed.ball.displacement_steps_left = 1
	check(changed.state_hash() != hash, "Ball remaining shift participates in hash")
	var importer := GDScript.new()
	importer.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	check(importer.reload() == OK and importer.new()._parse_effect_params('{"attack_mult":1.0,"shift_force":4,"shift_mode":"push"}')["shift_force"] is int, "Import preserves typed force")


func fixture(definitions: Dictionary = {}) -> MatchState:
	if definitions.is_empty(): definitions = data
	var state := MatchState.new(123, definitions, MatchState.DEFAULT_BALL_DATA, arena)
	state.units = [UnitState.new(0, 0, "bagpipe", Vector2i(5, 5), 1000, 0, 10000), UnitState.new(1, 1, "bagpipe", Vector2i(12, 5), 1000, 0, 10000)]
	state.next_unit_id = 2
	state.ball.cell = Vector2i(10, 10)
	return state


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
