extends SceneTree

var _definitions := {}
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		push_error("Passive healing test did not complete")
		quit(1)
	)
	for id in ["angelina", "bagpipe", "blaze", "ceobe", "exusiai", "hoshiguma", "nightingale", "swire_alter"]:
		_definitions[id] = load("res://resources/operators/%s.tres" % id)
	var data: OperatorData = _definitions.swire_alter
	var skill := data.skills[0]
	_expect(skill.effect_params == {"heal_percent": 80, "hp_threshold_percent": 70, "heal_radius": 1, "coin_limit": 3}, "S1M3 healing parameters differ from specification")
	var csv := FileAccess.open("res://import/operators.csv", FileAccess.READ)
	var header := csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row[0] == "琳琅诗怀雅":
			var csv_skill: Dictionary = JSON.parse_string(row[header.find("skill_effect_params")])
			var csv_talent: Dictionary = JSON.parse_string(row[header.find("talent1_effect_params")])
			for key in skill.effect_params:
				_expect(int(csv_skill[key]) == skill.effect_params[key], "CSV and skill resource disagree: " + key)
			for key in data.talent_1.effect_params:
				_expect(int(csv_talent[key]) == data.talent_1.effect_params[key], "CSV and talent resource disagree: " + key)
	var income := _deployed(Vector2i(20, 0))
	var merchant := income.units[0]
	_expect(merchant.coins == 1 and merchant.sp == 0 and merchant.last_coin_gain_tick == 0, "Deployment must grant exactly one coin, not SP")
	for _tick in 88:
		income.step([], [])
	_expect(merchant.coins == 1 and merchant.coin_attack_stacks == 0, "Income arrived before three seconds")
	var before_cost := income.sides[0].cost
	income.step([], [])
	_expect(merchant.coins == 2 and merchant.coin_attack_stacks == 1 and income.sides[0].cost == before_cost - 2, "Three-second drain must spend 3 DP after same-tick regeneration and give one coin/stack")
	for _tick in 180:
		income.step([], [])
	_expect(merchant.coins == 3 and merchant.coin_attack_stacks == 3 and merchant.last_coin_gain_tick == 179, "Coin cap must not stop cost drain or attack stacks")
	for _tick in 630:
		income.step([], [])
	_expect(merchant.coin_attack_stacks == 8 and merchant.coins == 3 and merchant.sp == 0 and SkillRules.attack_value(merchant, data) == 1069, "Attack stacks must cap at +32%; coins do not expire or recharge as SP")
	for side in 2:
		for y in range(-1, 2):
			for x in range(-1, 2):
				if x == 0 and y == 0:
					continue
				var state := _deployed(Vector2i(11, 5) if side == 0 else Vector2i(9, 5), side)
				var unit := state.units[0]
				unit.attack_ticks_left = 1
				var ally := UnitState.new(1, side, "bagpipe", unit.cell + Vector2i(x, y), 1000, 0, 10000)
				state.units.append(ally)
				state.next_unit_id = 2
				state.step([], [])
				_expect(ally.hp == 1324 and unit.coins == 0 and unit.last_attack_is_heal and state.ball.accum == Vector2i.ZERO and ally.last_heal_tick == 1, "Eight-neighbor healing failed: side=%d offset=%s hp=%d" % [side, Vector2i(x, y), ally.hp])
	var priority := _deployed(Vector2i(20, 5))
	priority.units[0].attack_ticks_left = 1
	priority.units.append(UnitState.new(1, 0, "bagpipe", Vector2i(19, 4), 1000, 0, 10000))
	priority.units.append(UnitState.new(2, 0, "hoshiguma", Vector2i(20, 4), 1900, 0, 10000))
	priority.next_unit_id = 3
	priority.step([], [])
	_expect(priority.units[1].hp == 1324 and priority.units[2].hp == 1900, "Select lowest HP ratio, not most missing HP")
	priority.units[1].hp = 1242
	priority.units[2].hp = 1925
	priority.units[0].coins = 1
	priority.units[0].attack_ticks_left = 1
	priority.step([], [])
	_expect(priority.units[1].hp == 1566 and priority.units[2].hp == 1925, "Equal HP ratios must use ascending unit ID")
	for hp in [2695, 2694]:
		var threshold := _deployed(Vector2i(20, 5))
		threshold.units[0].attack_ticks_left = 1
		threshold.units.append(UnitState.new(1, 0, "hoshiguma", Vector2i(19, 4), hp, 0, 10000))
		threshold.next_unit_id = 2
		threshold.step([], [])
		_expect(threshold.units[1].hp == (hp if hp == 2695 else hp + 324), "70 percent threshold must be strict: hp=%d" % hp)
	var excluded := _deployed(Vector2i(20, 5))
	excluded.units[0].hp = 100
	excluded.units[0].attack_ticks_left = 1
	excluded.units.append(UnitState.new(1, 0, "bagpipe", Vector2i(18, 5), 100, 0, 10000))
	excluded.units.append(UnitState.new(2, 1, "bagpipe", Vector2i(20, 4), 100, 0, 10000))
	excluded.units.append(UnitState.new(3, 0, "hoshiguma", Vector2i(19, 4), 0, 0, 10000))
	excluded.next_unit_id = 4
	excluded.step([], [])
	_expect(excluded.units[0].hp == 100 and excluded.units[0].coins == 1 and excluded.units[1].hp == 100 and excluded.units[2].hp == 100, "Must exclude self, dead, enemy and out-of-range targets without wasting coin")
	for coins in [0, 1]:
		var ordinary := _deployed(Vector2i(11, 5))
		ordinary.units[0].coins = coins
		ordinary.units[0].attack_ticks_left = 1
		if coins == 0:
			ordinary.units.append(UnitState.new(1, 0, "bagpipe", Vector2i(12, 5), 1000, 0, 10000))
			ordinary.next_unit_id = 2
		ordinary.step([], [])
		_expect(ordinary.ball.accum.x == -810 and ordinary.units[0].coins == coins and not ordinary.units[0].last_attack_is_heal, "No coin or no healing target must preserve ordinary attack")
	var boosted := _deployed(Vector2i(20, 5))
	boosted.units[0].coin_attack_stacks = 8
	boosted.units[0].attack_ticks_left = 1
	boosted.units.append(UnitState.new(1, 0, "bagpipe", Vector2i(19, 4), 1000, 0, 10000))
	boosted.next_unit_id = 2
	boosted.step([], [])
	_expect(boosted.units[1].hp == 1428, "Healing must use current buffed attack value and 50% PvP adjustment")
	_expect(not SkillRules.can_manually_activate(boosted.units[0], skill), "Passive coin skill must reject manual activation")
	var starved := _deployed(Vector2i(20, 0))
	starved.sides[0].cost = 1
	starved.sides[0].cost_regen_ticks = 0
	starved.units[0].cost_drain_ticks = 89
	starved.step([], [])
	_expect(starved.units.is_empty() and starved.sides[0].cost == 1 and starved.sides[0].cooldowns.swire_alter == 750, "Insufficient DP must auto-retreat without refund or partial drain")
	var retreat := _deployed(Vector2i(20, 0))
	before_cost = retreat.sides[0].cost
	retreat.step([InputCommand.new(retreat.tick, InputCommand.Kind.RETREAT, "", 0)], [])
	_expect(retreat.units.is_empty() and retreat.sides[0].cost == before_cost, "Merchant retreat must not refund DP")
	for _tick in 750:
		retreat.step([], [])
	retreat.step([InputCommand.new(retreat.tick, InputCommand.Kind.DEPLOY, "swire_alter", -1, Vector2i(20, 0))], [])
	_expect(retreat.units[0].coins == 1 and retreat.units[0].coin_attack_stacks == 0 and retreat.units[0].cost_drain_ticks == 1, "Redeployment must reset coins, buffs and drain clock")
	var first := MatchState.new(12345, _definitions)
	var second := MatchState.new(12345, _definitions)
	for state in [first, second]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
	var heals := 0
	for tick in 2400:
		var blue: Array[InputCommand] = []
		var red: Array[InputCommand] = []
		if tick == 0:
			blue = [InputCommand.new(0, 0, "bagpipe", -1, Vector2i(11, 3)), InputCommand.new(0, 0, "swire_alter", -1, Vector2i(12, 3))]
			red = [InputCommand.new(0, 0, "exusiai", -1, Vector2i(8, 2), -1, 0)]
		elif tick == 600:
			blue = [InputCommand.new(tick, 1, "", 0, Vector2i.ZERO, 0)]
		elif tick == 1200:
			blue = [InputCommand.new(tick, 2, "", 1)]
		elif tick == 1950:
			blue = [InputCommand.new(tick, 0, "swire_alter", -1, Vector2i(12, 3))]
		first.step(blue, red)
		second.step(blue, red)
		_expect(first.state_hash() == second.state_hash(), "Passive healing replay diverged at tick %d" % tick)
		for unit in first.units:
			if unit.last_coin_spend_tick == tick:
				heals += 1
	_expect(heals > 0, "Replay must exercise actual combat healing")
	var hashed := _deployed(Vector2i(20, 0))
	for field in ["coins", "coin_attack_stacks", "cost_drain_ticks", "last_coin_gain_tick", "last_coin_spend_tick", "last_attack_is_heal"]:
		var before := hashed.state_hash()
		var old: Variant = hashed.units[0].get(field)
		hashed.units[0].set(field, not old if old is bool else int(old) + 1)
		_expect(hashed.state_hash() != before, "State hash omits %s" % field)
		hashed.units[0].set(field, old)
	print("Passive healing: S1M3, coin income/cap, DP drain/retreat, eight cells, strict HP threshold, buff, targeting, 2400-tick replay; heals=%d failures=%d" % [heals, _failures])
	quit(0 if _failures == 0 else 1)


func _deployed(cell: Vector2i, side: int = 0) -> MatchState:
	var state := MatchState.new(12345, _definitions)
	state.sides[side].cost = 99
	var commands: Array[InputCommand] = [InputCommand.new(0, 0, "swire_alter", -1, cell)]
	var empty: Array[InputCommand] = []
	state.step(commands if side == 0 else empty, commands if side == 1 else empty)
	return state


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
