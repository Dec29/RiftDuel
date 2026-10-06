extends SceneTree

const CONFIG := preload("res://data/config.gd")


func _initialize() -> void:
	create_timer(20).timeout.connect(func() -> void: quit(1))
	var expected := {"vanguard": 25, "guard": 40, "defender": 17, "sniper": 25, "caster": 30, "supporter": 20, "specialist": 25, "medic": 0, "summon": 0}
	assert(CONFIG.UNIT_DAMAGE_PERCENT_BY_PROFESSION == expected)
	assert(CONFIG.UNIT_EFFECTIVE_DEFENSE_PERCENT == 70 and CONFIG.UNIT_MIN_DAMAGE_PERCENT == 5 and CONFIG.UNIT_HEAL_PERCENT == 50)
	var template: OperatorData = load("res://resources/operators/blaze.tres")
	var target_template: OperatorData = load("res://resources/operators/angelina.tres")
	for profession_id in OperatorData.PROFESSION_IDS:
		var source := template.duplicate(true) as OperatorData
		source.operator_id = "future_" + profession_id
		source.profession_id = profession_id
		source.attack = 1000
		var target := target_template.duplicate(true) as OperatorData
		target.max_health = 10000
		target.defense = 100
		target.magic_resist = 20
		var data := {source.operator_id: source, target.operator_id: target}
		var state := MatchState.new(91, data)
		state.units = [UnitState.new(0, 0, source.operator_id, Vector2i(11, 5), source.max_health, 0, 1), UnitState.new(1, 1, target.operator_id, Vector2i(10, 5), 10000, 0, 10000)]
		state.next_unit_id = 2
		state.step([], [])
		var damage := roundi(930 * int(expected[profession_id]) / 100.0)
		assert(state.units[1].hp == 10000 - damage, "New operator did not inherit profession coefficient: " + profession_id)
		var pushes := MatchState.new(91, data)
		pushes.units = [UnitState.new(0, 0, source.operator_id, Vector2i(11, 5), source.max_health, 0, 1)]
		pushes.next_unit_id = 1
		pushes.step([], [])
		assert(pushes.ball.accum == Vector2i(-1000, 0), "PvP damage coefficient leaked into ball push")
	assert(Combat.calculate_damage(1000, 99999, 0, "physical", 0, RNG.new(1), "guard") == 20)
	assert(Combat.calculate_damage(1000, 99999, 100, "magical", 0, RNG.new(1), "caster") == 15)
	assert(Combat.calculate_damage(1000, 99999, 100, "true", 100, RNG.new(1), "guard") == 400)
	assert(Combat.calculate_healing(350) == 175 and Combat.calculate_healing(810, 80) == 324)
	var regen_data: OperatorData = target_template.duplicate(true)
	regen_data.talent_2.effect_params["heal_per_second"] = 21
	var regen := MatchState.new(92, {"angelina": regen_data, "blaze": template})
	regen.units = [UnitState.new(0, 0, "angelina", Vector2i(20, 0), 1000, 0, 10000), UnitState.new(1, 0, "blaze", Vector2i(20, 1), 1000, 0, 10000)]
	regen.next_unit_id = 2
	for tick in 60:
		regen.step([], [])
		if tick == 29:
			assert(regen.units[1].hp == 1010 and regen.units[1].hp_regen_accum == 1500)
	assert(regen.units[1].hp == 1021 and regen.units[1].hp_regen_accum == 0, "Fractional regeneration was rounded away per tick")
	var roster := {"blaze": template, "angelina": target_template, "hoshiguma": load("res://resources/operators/hoshiguma.tres"), "nightingale": load("res://resources/operators/nightingale.tres")}
	var battles: Array[MatchState] = [MatchState.new(93, roster), MatchState.new(93, roster)]
	for battle in battles:
		battle.units = [UnitState.new(0, 0, "blaze", Vector2i(11, 5), 2821, 2, 1), UnitState.new(1, 1, "hoshiguma", Vector2i(10, 5), 3850, 40, 1), UnitState.new(2, 0, "nightingale", Vector2i(12, 4), 1705, 30, 1), UnitState.new(3, 1, "angelina", Vector2i(8, 2), 1385, 0, 10000)]
		battle.next_unit_id = 4
	for tick in 600:
		var blue: Array[InputCommand] = []
		var red: Array[InputCommand] = []
		if tick == 0:
			blue.append(InputCommand.new(tick, InputCommand.Kind.SKILL, "", 2, Vector2i.ZERO, 0))
			red.append(InputCommand.new(tick, InputCommand.Kind.SKILL, "", 1, Vector2i.ZERO, 0))
		for battle in battles:
			battle.step(blue, red)
		assert(battles[0].state_hash() == battles[1].state_hash(), "Adjusted PvP replay diverged at tick %d" % tick)
	print("Balance OK: all professions/new IDs, 70% defense, 5% floors, 50% healing/integer regeneration, unchanged ball push")
	quit(0)
