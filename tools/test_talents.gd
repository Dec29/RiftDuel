extends SceneTree

const IDS := ["angelina", "bagpipe", "blaze", "ceobe", "exusiai", "hoshiguma", "nightingale", "swire_alter"]
var _data := {}
var _failures := 0


func _initialize() -> void:
	for id in IDS:
		_data[id] = load("res://resources/operators/%s.tres" % id)
	var csv := FileAccess.open("res://import/operators.csv", FileAccess.READ)
	var header := csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() == 1:
			continue
		for id in IDS:
			var data: OperatorData = _data[id]
			if data.display_name == row[0]:
				_expect(data.profession_id == row[header.find("profession_id")], "CSV profession mismatch " + id)
				for index in 2:
					var prefix := "talent%d" % (index + 1)
					var talent: TalentResource = data.get("talent_%d" % (index + 1))
					var params: Dictionary = JSON.parse_string(row[header.find(prefix + "_effect_params")])
					for key in params:
						if key != "profession_id":
							params[key] = int(params[key])
					_expect(talent.effect_type == row[header.find(prefix + "_effect_type")] and talent.effect_params == params, "CSV talent mismatch " + id)
	var roster_copy := MatchState.new(1, _data)
	_expect(_data.size() == 8 and not _data.has("nightingale_phantom"), "MatchState changed caller's roster")
	var initial := _state()
	initial.step([InputCommand.new(0, 0, "bagpipe", -1, Vector2i(20, 0))], [])
	_expect(initial.units[0].sp == 21, "Military Tradition must grant +6 initial SP without field deployment")
	var refund_before := initial.sides[0].cost
	initial.step([InputCommand.new(1, 2, "", 0)], [])
	_expect(initial.sides[0].cost == refund_before + 13, "Charger retreat must refund full original deployment cost")
	var proc := _state()
	proc.units = [_unit(0, "bagpipe", 0, Vector2i(11, 5)), _unit(1, "angelina", 1, Vector2i(10, 5))]
	proc.units[0].attack_ticks_left = 1
	proc.units[1].hp = 1
	var old_cost := proc.sides[0].cost
	proc.step([], [])
	_expect(proc.units.size() == 1 and proc.sides[0].cost == mini(99, old_cost + 1), "Charger kill must grant exactly 1 DP")
	var critical := _state()
	critical.units = [_unit(0, "blaze", 0, Vector2i(11, 5)), _unit(1, "swire_alter", 1, Vector2i(10, 5))]
	critical.units[0].hp = 1
	critical.units[1].attack_ticks_left = 1
	critical.step([], [])
	_expect(critical.units[0].emergency_heal_used and critical.units[0].hp == 1412 and critical.units[0].hp_lock_ticks_left == 179, "Emergency heal must survive lethal damage, restore 50%, lock six seconds")
	critical.units[1].attack_ticks_left = 1
	critical.step([], [])
	_expect(critical.units[0].hp >= 1411, "Emergency lock must prevent damage below half health")
	var revive := _state()
	revive.units = [_unit(0, "swire_alter", 0, Vector2i(11, 5)), _unit(1, "blaze", 1, Vector2i(10, 5))]
	for cost in [5, 10, 20]:
		revive.units[0].hp = 1
		revive.units[1].attack_ticks_left = 1
		old_cost = revive.sides[0].cost
		revive.step([], [])
		_expect(revive.units[0].hp == 1652 and revive.sides[0].cost == old_cost - cost and revive.units[0].revive_cost == cost * 2, "Fatal revive must charge doubling cost and reset HP to 70%")
	var blessing := _state()
	blessing.units = [_unit(0, "exusiai", 0, Vector2i(20, 0)), _unit(1, "bagpipe", 0, Vector2i(20, 1))]
	blessing.units[1].hp = 1242
	blessing.step([], [])
	_expect(blessing.units[0].blessing_target_id == 1 and SkillRules.max_health_value(blessing.units[0], _data.exusiai) == 1840 and blessing.units[1].hp == 1366 and SkillRules.attack_value(blessing.units[1], _data.bagpipe) == 621, "Blessing must apply self and one ally, preserve HP ratio")
	blessing.step([InputCommand.new(1, 2, "", 0)], [])
	_expect(blessing.units[0].hp == 1242 and blessing.units[0].max_health_bonus_percent == 0, "Blessing must disappear with source retreat and preserve ratio")
	var isolation := _state()
	isolation.units = [_unit(0, "ceobe", 0, Vector2i(12, 2))]
	isolation.step([], [])
	_expect(SkillRules.attack_value(isolation.units[0], _data.ceobe) == 720 and SkillRules.attack_interval_ticks(isolation.units[0], _data.ceobe) == 44, "Ceobe isolated +8% ATK/+8 ASPD mismatch")
	isolation.units.append(_unit(1, "bagpipe", 0, Vector2i(12, 3)))
	isolation.step([], [])
	_expect(SkillRules.attack_value(isolation.units[0], _data.ceobe) == 667, "Adjacent ally must disable isolated talent")
	var armor := _state()
	armor.units = [_unit(0, "hoshiguma", 0, Vector2i(20, 0))]
	armor.step([], [])
	_expect(SkillRules.defense_value(armor.units[0], _data.hoshiguma) == 766, "Defender aura must apply +6% self defense")
	var aura := _state()
	aura.units = [_unit(0, "angelina", 0, Vector2i(20, 0)), _unit(1, "bagpipe", 0, Vector2i(20, 1))]
	aura.units[1].hp = 1000
	for _tick in 30:
		aura.step([], [])
	_expect(aura.units[1].hp == 1010 and SkillRules.attack_interval_ticks(aura.units[1], _data.bagpipe) == 28, "Angelina 50%-scaled global regeneration and ASPD mismatch")
	aura.units[0].skill_ticks_left = 50
	for _tick in 30:
		aura.step([], [])
	_expect(aura.units[1].hp == 1010, "Angelina active skill must suppress global regeneration")
	var heal := _state()
	heal.units = [_unit(0, "nightingale", 0, Vector2i(12, 2))]
	for index in 4:
		heal.units.append(_unit(index + 1, "bagpipe", 0, Vector2i(11 + index % 2, 1 + index / 2)))
		heal.units[-1].hp = 1000
	heal.units[0].attack_ticks_left = 1
	heal.step([], [])
	var healed := 0
	for unit in heal.units:
		if unit.unit_id > 0 and unit.hp == 1175:
			healed += 1
	_expect(healed == 3 and heal.units[1].magic_resist_bonus == 15, "Multi-target medic must heal exactly three allies and apply in-range RES aura")
	var proc_data: OperatorData = _data.bagpipe.duplicate(true)
	proc_data.talent_1.effect_params["chance_percent"] = 100
	proc_data.attack_range.append(Vector2i(1, 1))
	var proc_definitions := _data.duplicate()
	proc_definitions.bagpipe = proc_data
	var extra_target := MatchState.new(1, proc_definitions)
	extra_target.units = [_unit(0, "bagpipe", 0, Vector2i(11, 5)), _unit(1, "angelina", 1, Vector2i(10, 5)), _unit(2, "angelina", 1, Vector2i(10, 4))]
	extra_target.units[0].attack_ticks_left = 1
	extra_target.step([], [])
	_expect(extra_target.units[1].hp == 1215 and extra_target.units[2].hp == 1215, "Precision Loading proc must apply 130% attack and vanguard PvP tuning to two distinct targets")
	var block_data: OperatorData = _data.hoshiguma.duplicate(true)
	block_data.talent_1.effect_params["chance_percent"] = 100
	var true_data: OperatorData = _data.bagpipe.duplicate(true)
	true_data.damage_type = "true"
	true_data.talent_1.effect_params["chance_percent"] = 0
	var blocked_definitions := _data.duplicate()
	blocked_definitions.hoshiguma = block_data
	blocked_definitions.bagpipe = true_data
	var blocked := MatchState.new(1, blocked_definitions)
	blocked.units = [_unit(0, "bagpipe", 0, Vector2i(11, 5)), _unit(1, "hoshiguma", 1, Vector2i(10, 5))]
	blocked.units[0].attack_ticks_left = 1
	blocked.step([], [])
	_expect(blocked.units[1].hp == 3850 and blocked.units[1].last_damage_block_tick == 0, "Damage block must cancel true damage, not behave as a dodge")
	block_data.talent_1.effect_params["chance_percent"] = 0
	var peeled := MatchState.new(1, blocked_definitions)
	peeled.units = [_unit(0, "ceobe", 0, Vector2i(11, 5)), _unit(1, "hoshiguma", 1, Vector2i(10, 5))]
	peeled.units[0].attack_ticks_left = 1
	peeled.step([], [])
	_expect(peeled.units[1].hp == 3542, "Thresher must use caster tuning for both base hit and separate defense damage: 216+92")
	var clone_data: OperatorData = _data.blaze.duplicate(true)
	clone_data.attack_range.append(Vector2i(1, 1))
	clone_data.attack_range.append(Vector2i(1, -1))
	var aoe_definitions := _data.duplicate()
	aoe_definitions.blaze = clone_data
	var aoe := MatchState.new(1, aoe_definitions)
	aoe.units = [_unit(0, "blaze", 0, Vector2i(11, 5)), _unit(1, "bagpipe", 1, Vector2i(10, 5)), _unit(2, "bagpipe", 1, Vector2i(10, 4)), _unit(3, "bagpipe", 1, Vector2i(10, 6))]
	aoe.units[0].attack_ticks_left = 1
	aoe.step([], [])
	_expect(aoe.units[1].hp == 2285 and aoe.units[2].hp == 2285 and aoe.units[3].hp == 2285 and aoe.units[0].sp == 1, "Centurion must apply guard PvP tuning to each target, grant only one attack-recovery SP")
	_phantoms()
	print("Talents: roster/CSV, initial SP, refunds, emergency lock, fatal revive, blessing, isolation, auras, healing, phantom and hash; failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _phantoms() -> void:
	var first := _state()
	var second := _state()
	var deployment: Array[InputCommand] = [InputCommand.new(0, 0, "nightingale", -1, Vector2i(12, 2))]
	for state in [first, second]:
		state.step(deployment, [] as Array[InputCommand])
		_expect(state.sides[0].phantom_count == 2 and state.phantom_can_deploy(0, Vector2i(11, 5)), "Nightingale must grant two ground-deployable phantoms")
		_expect(not state.phantom_can_deploy(0, Vector2i(12, 8)) and not state.phantom_can_deploy(0, Vector2i(9, 5)) and not state.phantom_can_deploy(0, Vector2i(10, 5)), "Phantom cannot use high platform, opposing territory or center no-deploy line")
	for tick in range(1, 1800):
		var commands: Array[InputCommand] = []
		if tick == 1 or tick == 601:
			commands = [InputCommand.new(tick, 0, "nightingale_phantom", -1, Vector2i(11, 5) if tick == 1 else Vector2i(11, 6))]
		if tick == 602:
			commands = [InputCommand.new(tick, 2, "", 0)]
		first.step(commands, [])
		second.step(commands, [])
		_expect(first.state_hash() == second.state_hash(), "Phantom replay diverged tick %d" % tick)
		if tick == 1:
			_expect(first.sides[0].phantom_count == 1 and first.sides[0].phantom_cooldown_ticks == 600 and first.units[1].hp == 6000, "Phantom must cost 5 DP, consume stock, start 20-second deployment cooldown")
		if tick == 600:
			_expect(first.sides[0].phantom_cooldown_ticks == 1 and not first.phantom_available(0), "Cooldown opened early")
		if tick == 601:
			_expect(first.units.size() == 3 and first.sides[0].phantom_count == 0, "Multiple phantoms may coexist")
		if tick == 602:
			_expect(first.units.size() == 2 and not first.phantom_available(0), "Nightingale retreat must leave deployed phantoms, prevent new deployment")
	_expect(first.units.is_empty() and not first.sides[0].cooldowns.has("nightingale_phantom"), "Phantoms must expire from 3% HP/sec without ordinary defeat cooldown")
	first.sides[0].cooldowns.clear()
	first.sides[0].phantom_count = 2
	first.step([InputCommand.new(first.tick, 0, "nightingale", -1, Vector2i(12, 2))], [])
	_expect(first.sides[0].phantom_count == 3, "Nightingale redeployment replenishes two stock without exceeding three")
	first.sides[0].phantom_cooldown_ticks = 0
	var cost_before := first.sides[0].cost
	first.step([InputCommand.new(first.tick, 0, "nightingale_phantom", -1, Vector2i(11, 5))], [])
	_expect(first.sides[0].cost == cost_before - 5, "Phantom deployment must spend actual resource-defined DP")
	var phantom_id := first.units[-1].unit_id
	cost_before = first.sides[0].cost
	first.step([InputCommand.new(first.tick, 2, "", phantom_id)], [])
	_expect(first.sides[0].phantom_count == 2 and first.sides[0].cost == cost_before and first.sides[0].phantom_cooldown_ticks == 599, "Phantom retreat must not refund DP, replenish stock or restart deployment cooldown")
	first.sides[0].phantom_cooldown_ticks = 0
	first.sides[0].cost = 4
	_expect(not first.phantom_available(0), "Insufficient DP must prevent phantom deployment")
	var taunt := _state()
	taunt.sides[0].phantom_count = 2
	taunt.units = [_unit(0, "exusiai", 1, Vector2i(8, 2)), _unit(1, "bagpipe", 0, Vector2i(9, 2)), UnitState.new(2, 0, "nightingale_phantom", Vector2i(9, 3), 6000, 0, 1)]
	taunt.units[0].attack_ticks_left = 1
	taunt.step([], [])
	_expect(taunt.units[0].last_attack_target_y == 3 and taunt.units[2].last_attack_tick == -1 and taunt.units[1].last_damage_tick == -1, "Enemy must prioritize in-range phantom regardless of older unit ID; phantom cannot attack")
	var regen := _state()
	regen.units = [_unit(0, "nightingale", 0, Vector2i(12, 2)), _unit(1, "angelina", 0, Vector2i(16, 2)), _unit(2, "swire_alter", 0, Vector2i(11, 3)), UnitState.new(3, 0, "nightingale_phantom", Vector2i(12, 3), 3000)]
	regen.units[0].attack_ticks_left = 1
	regen.units[2].attack_ticks_left = 1
	regen.units[2].coins = 1
	for _tick in 30:
		regen.step([], [])
	_expect(regen.units[3].hp == 2830 and regen.units[2].coins == 1, "Phantom must reject normal/coin healing but accept 10 HP/s adjusted regeneration and lose 180 HP/s")
	var hashed := _state()
	hashed.units = [_unit(0, "bagpipe", 0, Vector2i(20, 0))]
	for field in ["attack_bonus_percent", "defense_bonus_percent", "attack_speed_bonus", "magic_resist_bonus", "max_health_bonus_percent", "blessing_target_id", "emergency_heal_used", "hp_lock_ticks_left", "revive_cost", "hp_regen_accum", "last_damage_block_tick", "life_loss_ticks"]:
		var hash_before := hashed.state_hash()
		var old: Variant = hashed.units[0].get(field)
		hashed.units[0].set(field, not old if old is bool else int(old) + 1)
		_expect(hash_before != hashed.state_hash(), "Hash omitted " + field)
		hashed.units[0].set(field, old)
	for field in ["phantom_count", "phantom_cooldown_ticks"]:
		var hash_before := hashed.state_hash()
		hashed.sides[0].set(field, 1)
		_expect(hash_before != hashed.state_hash(), "Hash omitted " + field)
		hashed.sides[0].set(field, 0)


func _state() -> MatchState:
	var state := MatchState.new(0x12345678, _data)
	state.sides[0].cost = 80
	state.sides[1].cost = 80
	state.ball.cell = Vector2i(10, 10)
	return state


func _unit(id: int, data_id: String, side: int, cell: Vector2i) -> UnitState:
	var data: OperatorData = _data[data_id]
	return UnitState.new(id, side, data_id, cell, data.max_health, 0, 10000)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
