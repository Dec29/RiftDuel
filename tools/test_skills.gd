extends SceneTree

const IDS := ["angelina", "bagpipe", "blaze", "ceobe", "exusiai", "hoshiguma", "nightingale", "swire_alter"]
var _definitions: Dictionary = {}
var _failures: int = 0


func _initialize() -> void:
	for operator_id in IDS:
		_definitions[operator_id] = load("res://resources/operators/%s.tres" % operator_id)

	var input := LocalInput.new(0)
	input.queue_skill(8, 3)
	var commands := input.take_commands()
	_expect(commands.size() == 1 and commands[0].tick == 8 and commands[0].unit_id == 3 and commands[0].skill_index == 0 and commands[0].kind == InputCommand.Kind.SKILL, "LocalInput skill command mismatch")

	var bagpipe := _match("bagpipe", 35)
	bagpipe.step(_cast(0), [])
	_expect(bagpipe.units[0].sp == 0 and bagpipe.units[0].skill_ticks_left == 1049, "Bagpipe activation: expected SP=0 duration=1049")
	_expect(bagpipe.ball.accum.x == -850 and bagpipe.units[0].attack_ticks_left == 21, "Bagpipe: expected push=-850 interval=21")
	bagpipe.units[0].skill_ticks_left = 1
	bagpipe.units[0].attack_ticks_left = 21
	bagpipe.step([], [])
	_expect(bagpipe.units[0].skill_ticks_left == 0 and bagpipe.units[0].attack_ticks_left == 29, "Bagpipe expiry did not restore attack interval")

	var blaze := _match("blaze", 2)
	blaze.units[0].attack_ticks_left = 2
	blaze.step(_cast(0), [])
	_expect(blaze.units[0].skill_ticks_left == 0 and blaze.units[0].sp == 2 and blaze.ball.accum == Vector2i.ZERO, "Blaze automatic skill must wait until an actual attack")
	blaze.step([], [])
	_expect(blaze.units[0].skill_ticks_left == 0 and blaze.ball.move_direction == Vector2i.LEFT, "Blaze empowered strike did not kick ball")
	_expect(SkillRules.attack_value(blaze.units[0], _definitions["blaze"]) == 765, "Blaze attack did not restore after strike")

	var exusiai := _match("exusiai", 4, Vector2i(11, 4))
	exusiai.units.append(UnitState.new(1, 1, "bagpipe", Vector2i(10, 4), 2484, 0, 100))
	exusiai.next_unit_id = 2
	exusiai.step(_cast(0), [])
	_expect(exusiai.units[1].hp == 2061 and exusiai.units[0].skill_ticks_left == 0, "Exusiai volley with blessing/PvP tuning: expected 3 x 141 damage, HP=2061")
	var volley_ball := _match("exusiai", 4, Vector2i(11, 4))
	volley_ball.step(_cast(0), [])
	_expect(volley_ball.ball.move_direction == Vector2i.LEFT, "Exusiai volley failed to accumulate three ball hits")

	var hoshiguma := _match("hoshiguma", 40)
	hoshiguma.units[0].attack_ticks_left = 100
	hoshiguma.units.append(UnitState.new(1, 1, "swire_alter", Vector2i(10, 5), 2360, 0, 1))
	hoshiguma.next_unit_id = 2
	hoshiguma.step(_cast(0), [])
	_expect(hoshiguma.units[0].hp == 3840, "Hoshiguma defense boost: expected 5% floor x specialist coefficient = 10 damage")
	_expect(SkillRules.attack_value(hoshiguma.units[0], _definitions["hoshiguma"]) == 602 and SkillRules.defense_value(hoshiguma.units[0], _definitions["hoshiguma"]) == 1345, "Hoshiguma skill plus 6% defender aura mismatch")

	var nightingale := _match("nightingale", 30, Vector2i(12, 4))
	nightingale.units.append(UnitState.new(1, 0, "swire_alter", Vector2i(11, 5), 1000, 0, 100))
	nightingale.next_unit_id = 2
	nightingale.step(_cast(0), [])
	_expect(nightingale.units[1].hp == 1333 and nightingale.ball.accum == Vector2i.ZERO, "Nightingale: expected healing=333 after 50% PvP adjustment without ball push")

	var angelina := _match("angelina", 10, Vector2i(11, 4))
	angelina.step([], [])
	_expect(angelina.units[0].sp == 0 and angelina.units[0].skill_ticks_left == 1049 and angelina.ball.accum.x == -1138, "Angelina auto activation or 2.1x attack failed")

	var ceobe := _match("ceobe", 18, Vector2i(11, 4))
	ceobe.units.append(UnitState.new(1, 1, "bagpipe", Vector2i(10, 4), 2484, 0, 100))
	ceobe.next_unit_id = 2
	ceobe.step(_cast(0), [])
	_expect(ceobe.units[0].sp == 12 and ceobe.units[1].hp == 1984 and ceobe.units[1].bind_ticks_left == 90, "Ceobe with isolation/defense damage: expected SP=12 damage=500 bind=90")
	ceobe.step([], [])
	_expect(ceobe.units[1].bind_ticks_left == 89, "Bind timer did not decay by one tick")
	ceobe.units[0].attack_ticks_left = 1
	ceobe.step(_cast(2), [])
	_expect(ceobe.units[0].sp == 6, "Ceobe second charge did not cost 6 SP")
	ceobe.units[0].attack_ticks_left = 1
	ceobe.step(_cast(3), [])
	_expect(ceobe.units[0].sp == 0, "Ceobe third charge did not cost 6 SP")
	ceobe.step(_cast(4), [])
	_expect(ceobe.units[0].skill_ticks_left == 0 and ceobe.units[0].sp == 0, "Empty charge activation was accepted")

	var regen := _match("bagpipe", 0, Vector2i(20, 5))
	for _tick in 30:
		regen.step([], [])
	_expect(regen.units[0].sp == 1 and regen.units[0].sp_regen_ticks == 0, "Time SP: expected 1 after 30 ticks")
	regen.units[0].sp = 35
	regen.step(_cast(30), [])
	for _tick in 30:
		regen.step([], [])
	_expect(regen.units[0].sp == 0 and regen.units[0].sp_regen_ticks == 0, "SP regenerated during timed skill")
	regen.units[0].skill_ticks_left = 1
	regen.step([], [])
	for _tick in 30:
		regen.step([], [])
	_expect(regen.units[0].sp == 1, "SP did not resume after skill expiry")
	var timed := _match("bagpipe", 35, Vector2i(20, 5))
	timed.step(_cast(0), [])
	for _tick in 1049:
		timed.step([], [])
	_expect(timed.units[0].skill_ticks_left == 0 and timed.units[0].sp == 0, "Timed skill did not expire after exactly 1050 ticks")
	var charges := _match("ceobe", 17, Vector2i(20, 5))
	for _tick in 90:
		charges.step([], [])
	_expect(charges.units[0].sp == 18, "Charge SP exceeded three-charge cap")

	var hit_regen := _match("blaze", 0)
	hit_regen.step([], [])
	_expect(hit_regen.units[0].sp == 1, "Ball hit did not recharge on_hit SP")
	hit_regen.units[0].attack_ticks_left = 1
	hit_regen.ball.move_ticks_left = 3
	hit_regen.ball.move_direction = Vector2i.LEFT
	hit_regen.step([], [])
	_expect(hit_regen.units[0].sp == 1, "Moving ball incorrectly granted on_hit SP")
	var damaged_data := (_definitions["bagpipe"] as OperatorData).duplicate(true) as OperatorData
	damaged_data.skills[0].sp_recharge_type = "on_damaged"
	var damaged_definitions := _definitions.duplicate()
	damaged_definitions["bagpipe"] = damaged_data
	var damaged := MatchState.new(0x12345678, damaged_definitions)
	damaged.units = [UnitState.new(0, 0, "swire_alter", Vector2i(11, 5), 2360, 0, 1)]
	damaged.units.append(UnitState.new(1, 1, "bagpipe", Vector2i(10, 5), 2484, 0, 100))
	damaged.next_unit_id = 2
	damaged.step([], [])
	_expect(damaged.units[1].sp == 1, "Damage did not recharge on_damaged SP")
	damaged_data.dodge_physical = 100
	damaged.units[0].attack_ticks_left = 1
	damaged.units[1].attack_ticks_left = 100
	var before_hp := damaged.units[1].hp
	damaged.step([], [])
	_expect(damaged.units[1].hp == before_hp and damaged.units[1].sp == 1, "Dodged attack granted damage SP or dealt damage")

	var rejected := _match("bagpipe", 0)
	rejected.step(_cast(0), [])
	_expect(rejected.units[0].skill_ticks_left == 0 and rejected.units[0].sp == 0, "Undercharged skill was accepted")
	var wrong_side := _match("bagpipe", 35)
	wrong_side.step([], _cast(0))
	_expect(wrong_side.units[0].skill_ticks_left == 0 and wrong_side.units[0].sp == 35, "Enemy command activated another side's skill")
	var pending := _match("blaze", 2, Vector2i(20, 5))
	pending.step(_cast(0), [])
	for _tick in 90:
		pending.step([], [])
	_expect(pending.units[0].skill_ticks_left == 0 and pending.units[0].sp == 2, "No-target automatic skill consumed stored SP")
	for operator_id in ["blaze", "exusiai", "ceobe"]:
		var skill: SkillResource = _definitions[operator_id].skills[0]
		var automatic := _match(operator_id, SkillRules.sp_limit(skill), Vector2i(20, 5))
		var replay := _match(operator_id, SkillRules.sp_limit(skill), Vector2i(20, 5))
		var automatic_states: Array[MatchState] = [automatic, replay]
		for state in automatic_states:
			state.step(_cast(0), [])
			_expect(state.units[0].sp == SkillRules.sp_limit(skill), "%s consumed SP without a target" % operator_id)
			state.units.append(UnitState.new(1, 1, "bagpipe", Vector2i(19, 5), 2484, 0, 100))
			state.next_unit_id = 2
			state.units[0].attack_ticks_left = 1
			state.step([], [])
			_expect(state.units[1].hp < 2400 and state.units[0].sp == SkillRules.sp_limit(skill) - skill.sp_required, "%s did not automatically empower attack or spent more than one charge" % operator_id)
		_expect(automatic.state_hash() == replay.state_hash(), "%s automatic replay diverged" % operator_id)
		var red := _match(operator_id, SkillRules.sp_limit(skill), Vector2i(0, 5))
		red.units[0].side = 1
		red.units[0].facing = 0
		red.units.append(UnitState.new(1, 0, "bagpipe", Vector2i(1, 5), 2484, 0, 100))
		red.next_unit_id = 2
		red.step([], [])
		_expect(red.units[1].hp < 2400 and red.units[0].sp == SkillRules.sp_limit(skill) - skill.sp_required, "%s red-side automatic trigger failed" % operator_id)
	var passive := _match("swire_alter", 0)
	_expect(not SkillRules.can_activate(passive.units[0], _definitions["swire_alter"].skills[0]), "Passive skill must not accept manual activation")

	for operator_id in IDS:
		var state := _match(operator_id, 0)
		var base_hash := state.state_hash()
		for field in ["sp_regen_ticks", "skill_ticks_left", "bind_ticks_left"]:
			state.units[0].set(field, 1)
			_expect(state.state_hash() != base_hash, "State hash omits %s" % field)
			state.units[0].set(field, 0)
	print("Skills: seven effects, SP, ownership, expiry, and hash checks; failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _match(operator_id: String, sp: int, cell: Vector2i = Vector2i(11, 5)) -> MatchState:
	var state := MatchState.new(0x12345678, _definitions)
	var operator := _definitions[operator_id] as OperatorData
	state.units = [UnitState.new(0, 0, operator_id, cell, operator.max_health, sp, 1)]
	state.next_unit_id = 1
	return state


func _cast(tick: int) -> Array[InputCommand]:
	return [InputCommand.new(tick, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 0)]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
