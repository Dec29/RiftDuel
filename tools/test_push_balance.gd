extends SceneTree

const FORCES := {
	"weedy": {0: 3, 1: 2, 2: 4}, "feater": {0: 3, 1: 4},
	"cliffheart": {0: 3, 1: 3}, "mountain": {2: 2},
	"swire_alter": {2: 2}, "mostima": {2: 1}, "lee": {2: 1}, "phantom": {2: 1},
}
var failures := 0
var data := {}
var arena := ArenaData.new()


func _initialize() -> void:
	for row in 11: arena.terrain_rows.append("g".repeat(10) + "n" + "g".repeat(10))
	for id in FORCES:
		data[id] = load("res://resources/operators/%s.tres" % id)
	for id in ["bagpipe", "angelina", "rosa", "gravel", "projekt_red", "texas_alter"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	for kind in {"light": "vanguard", "guard": "guard", "heavy": "defender", "quick": "specialist"}:
		var op := (data.bagpipe as OperatorData).duplicate(true) as OperatorData
		op.operator_id = kind
		op.profession_id = {"light": "vanguard", "guard": "guard", "heavy": "defender", "quick": "specialist"}[kind]
		op.max_health = 100000; op.defense = 0; op.magic_resist = 0
		op.talent_1.effect_type = "none"; op.talent_1.effect_params = {}
		op.talent_2.effect_type = "none"; op.talent_2.effect_params = {}
		op.branch_trait.effect_type = "fast_redeploy" if kind == "quick" else "none"
		op.branch_trait.effect_params = {}
		data[kind] = op
	_test_weights()
	_test_force_matrix()
	_test_skills()
	_test_cannon()
	_test_angelina_and_rosa()
	print(("PUSH_BALANCE_OK: " if failures == 0 else "PUSH_BALANCE_FAILED: ") + " weights, force0-6 push/pull, actual12skills x4weights, cannon, ball, Angelina, Rosa and per-tick replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _test_weights() -> void:
	var op := (data.bagpipe as OperatorData).duplicate(true) as OperatorData
	for profession in {"vanguard": 1, "guard": 2, "defender": 3, "sniper": 1, "caster": 1, "medic": 1, "supporter": 1, "specialist": 1, "summon": 1}:
		op.profession_id = profession
		var expected: int = {"guard": 2, "defender": 3}.get(profession, 1)
		op.branch_trait.effect_type = "none"
		check(DisplacementRules.weight(op) == expected, "Base profession weight " + profession)
		op.branch_trait.effect_type = "fast_redeploy"
		check(DisplacementRules.weight(op) == expected - 1, "Quick redeploy subtracts rather than overrides " + profession)
	for id in ["gravel", "projekt_red", "phantom", "texas_alter"]:
		check(DisplacementRules.weight(data[id]) == 0, "Current quick redeploy stays zero " + id)
	check(DisplacementRules.weight(MatchState.CLONE_DATA) == 0, "Clone remains zero")
	check(DisplacementRules.weight(data.lee) == 1 and DisplacementRules.weight(data.swire_alter) == 1, "Merchants are not executor fast redeploy")
	for id in FORCES:
		for index in FORCES[id]:
			var skill: SkillResource = data[id].skills[index]
			check(skill.validation_error().is_empty() and skill.effect_params.shift_force == FORCES[id][index], "%s.S%d force/schema" % [id, index + 1])
	check(MatchState.CLONE_DATA.skills[2].effect_params.shift_force == 1, "Clone small force1")
	var invalid := (data.phantom as OperatorData).skills[2].duplicate(true) as SkillResource
	invalid.effect_params.shift_force = -1
	check(not invalid.validation_error().is_empty(), "Reject obsolete negative force at resource boundary")
	invalid.effect_params.shift_force = 0
	check(invalid.validation_error().is_empty(), "Micro force0 accepted")


func _test_force_matrix() -> void:
	for kind in ["quick", "light", "guard", "heavy"]:
		var weight: int = {"quick": 0, "light": 1, "guard": 2, "heavy": 3}[kind]
		for force in 7:
			for mode in ["push", "pull"]:
				var state := fixture("weedy", 0, kind)
				var target := state.units[1]
				state.units[0].cell = Vector2i(4 if mode == "push" else 0, 5)
				target.cell = Vector2i(12 if mode == "push" else 8, 5)
				var origin := target.cell
				var direction := DisplacementRules.direction(state.units[0], target.cell, mode)
				var expected := maxi(0, force - weight)
				check(DisplacementRules.apply_unit(state, state.units[0], target, direction, force) == expected and target.cell == origin + direction * expected, "%s force%d weight%d exact distance%d" % [mode, force, weight, expected])
	for force in 7:
		var state := fixture("weedy", 0, "light")
		state.units.clear(); state.ball.cell = Vector2i(5, 5)
		check(DisplacementRules.apply_ball(state, Vector2i.RIGHT, force) == maxi(0, force - 1), "Unchanged ball weight1 force%d" % force)


func _test_skills() -> void:
	for id in FORCES:
		for index in FORCES[id]:
			for kind in ["quick", "light", "guard", "heavy"]:
				var state := fixture(id, index, kind)
				var replay := fixture(id, index, kind)
				var target := state.units[2] if id == "lee" else state.units[1]
				var origin := target.cell
				var commands := activate(state)
				var again := activate(replay)
				var expected := maxi(0, int(FORCES[id][index]) - DisplacementRules.weight(data[kind]))
				if id == "cliffheart": expected = mini(expected, 2) # Source is fixed at col12, target starts col15.
				state.step(commands, []); replay.step(again, [])
				check((state.units[1].deploy_control_kind >= 0 if id == "phantom" else state.units[0].last_coin_spend_tick == state.tick - 1 if id == "swire_alter" else state.units[0].skill_activation_count > 0), "%s.S%d actually activated" % [id, index + 1])
				check(target.hp < 100000 if id != "lee" else target.hp == 100000, "%s.S%d intended damage target" % [id, index + 1])
				check(target.cell == origin + Vector2i.LEFT * expected if id == "cliffheart" else target.cell == origin + (Vector2i.DOWN if id == "lee" else Vector2i.RIGHT) * expected, "%s.S%d vs%s expected%d cells actual%s" % [id, index + 1, kind, expected, str(target.cell - origin)])
				for tick in 120:
					check(state.state_hash() == replay.state_hash(), "%s.S%d %s every-tick replay%d" % [id, index + 1, kind, tick])
					state.step([], []); replay.step([], [])


func activate(state: MatchState) -> Array[InputCommand]:
	var source := state.units[0]
	var op: OperatorData = data[source.operator_id]
	var skill := op.skills[source.skill_index]
	if source.operator_id == "phantom":
		# Real deployment drives the burst, preserve target unit identity/order.
		state.units.remove_at(0); state.next_unit_id = 2
		return [InputCommand.new(state.tick, InputCommand.Kind.DEPLOY, "phantom", -1, Vector2i(12, 5), 2, 0)]
	if source.operator_id == "swire_alter":
		source.skill_ticks_left = -2; source.coins = 1
	if skill.trigger_type == "manual" or source.operator_id == "swire_alter":
		return [InputCommand.new(state.tick, InputCommand.Kind.SKILL, "", source.unit_id, Vector2i.ZERO, source.skill_index)]
	return []


func _test_cannon() -> void:
	var state := fixture("weedy", 0, "light")
	state.units[0].attack_ticks_left = 100000
	state.units[1].cell = Vector2i(14, 4)
	state.units.append(UnitState.new(2, 0, "weedy_cannon", Vector2i(13, 4), 100, 0, 0, 0))
	state.next_unit_id = 3
	state.step([], [])
	check(state.units[1].cell == Vector2i(15, 4), "Cannon base1 plus talent1 moves weight1 one cell")
	var blast := fixture("weedy", 2, "light")
	blast.units[1].cell = Vector2i(15, 4)
	blast.units.append(UnitState.new(2, 0, "weedy_cannon", Vector2i(12, 4), 100, 0, 0, 0))
	blast.next_unit_id = 3
	blast.step(activate(blast), [])
	check(blast.units[1].cell == Vector2i(19, 4) and blast.units[1].hp == 100000 - 593 - 1200, "Cannon S3 force5, four rupture cells, talent added once")


func _test_angelina_and_rosa() -> void:
	var priority := fixture("rosa", 0, "light")
	priority.units.append(UnitState.new(2, 1, "guard", Vector2i(13, 6), 100000, 0, 100000))
	priority.units.append(UnitState.new(3, 1, "heavy", Vector2i(14, 5), 100000, 0, 100000))
	var ordered := SiegeRules.targets(priority, priority.units[0], [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)])
	check(ordered.size() == 3 and ordered[0].unit_id == 3 and ordered[1].unit_id == 2 and ordered[2].unit_id == 1, "Weight-priority sniper ranks defender3, guard2, light1 before unit ID")
	for kind in ["quick", "light", "guard", "heavy"]:
		var state := fixture("weedy", 0, kind)
		var angel := UnitState.new(2, 0, "angelina", Vector2i(2, 2), 1000, 0, 100000, 0, 2)
		angel.skill_ticks_left = 10; state.units.append(angel)
		var expected := maxi(0, DisplacementRules.weight(data[kind]) - 1)
		check(DisplacementRules.effective_weight(state, state.units[1]) == expected, "Angelina enemy minus1 clamp " + kind)
		state.units[1].cell = Vector2i(13, 5)
		check(DisplacementRules.apply_unit(state, state.units[0], state.units[1], Vector2i.RIGHT, 1) == maxi(0, 1 - expected), "Small-force synergy " + kind)
	var rosa := fixture("rosa", 0, "heavy")
	var heavy: OperatorData = data.heavy.duplicate(true)
	heavy.defense = 1000; rosa._operator_data.heavy = heavy
	var target := rosa.units[1]
	ClassicTacticalRules.hit(rosa, rosa.units[0], data.rosa, target, 1000, "physical")
	var penetrated := Combat.calculate_damage(1000, 400, 0, "physical", 0, RNG.new(1), "sniper")
	check(target.hp == 100000 - penetrated, "Rosa ignores60percent defense on weight3 defender")
	var angel := UnitState.new(2, 0, "angelina", Vector2i(2, 2), 1000, 0, 100000, 0, 2)
	angel.skill_ticks_left = 10; rosa.units.append(angel); target.hp = 100000
	ClassicTacticalRules.hit(rosa, rosa.units[0], data.rosa, target, 1000, "physical")
	var ordinary := Combat.calculate_damage(1000, 1000, 0, "physical", 0, RNG.new(1), "sniper")
	check(target.hp == 100000 - ordinary and penetrated > ordinary, "Reduced weight2 no longer triggers Rosa penetration")


func fixture(id: String, index: int, kind: String) -> MatchState:
	var state := MatchState.new(673, data, MatchState.DEFAULT_BALL_DATA, arena, [PackedStringArray([id]), PackedStringArray([kind])], [PackedInt32Array([index]), PackedInt32Array([0])])
	state.sides[0].cost = 99; state.ball.cell = Vector2i(10, 10); state.next_box_spawn_tick = 100000
	var op: OperatorData = data[id]
	state.units = [UnitState.new(0, 0, id, Vector2i(12, 5), op.max_health, SkillRules.sp_limit(op.skills[index]), 0, 0, index), UnitState.new(1, 1, kind, Vector2i(15 if id == "cliffheart" else 13, 5), 100000, 0, 100000)]
	if id == "lee":
		state.units[1].cell = Vector2i(12, 6)
		state.units[1].unit_id = 2
		state.units.insert(1, UnitState.new(1, 1, "light", Vector2i(13, 5), 100000, 0, 100000))
	state.next_unit_id = state.units.size()
	return state


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
