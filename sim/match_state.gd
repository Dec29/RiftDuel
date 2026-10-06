class_name MatchState
extends RefCounted

const CONFIG := preload("res://data/config.gd")
const DEFAULT_BALL_DATA := preload("res://resources/ball/standard.tres")
const DEFAULT_ARENA := preload("res://resources/map/standard_arena.tres")
const ATTACK_RANGE := preload("res://sim/attack_range.gd")
const PHANTOM_DATA: OperatorData = preload("res://resources/summons/nightingale_phantom.tres")

const RESULT_RUNNING := 0
const RESULT_BLUE_WIN := 1
const RESULT_RED_WIN := 2
const RESULT_DRAW := 3

var tick: int
var rng: RNG
var units: Array[UnitState]
var ball: BallState
var sides: Array[SideState]
var result: int
var next_unit_id: int
var _operator_data: Dictionary
var _ball_data: BallData
var _arena: ArenaData


func _init(
	match_seed: int = 1,
	match_operator_data: Dictionary = {},
	match_ball_data: BallData = DEFAULT_BALL_DATA,
	match_arena: ArenaData = DEFAULT_ARENA,
) -> void:
	tick = 0
	rng = RNG.new(match_seed)
	units = []
	ball = BallState.new()
	sides = [SideState.new(0), SideState.new(1)]
	result = RESULT_RUNNING
	next_unit_id = 0
	_operator_data = match_operator_data.duplicate()
	_operator_data[PHANTOM_DATA.operator_id] = PHANTOM_DATA
	_ball_data = match_ball_data
	_arena = match_arena


func step(cmd_a: Array[InputCommand], cmd_b: Array[InputCommand]) -> void:
	if result != RESULT_RUNNING:
		return
	for side_state in sides:
		side_state.phantom_cooldown_ticks = maxi(0, side_state.phantom_cooldown_ticks - 1)
		var cooldown_ids := side_state.cooldowns.keys()
		cooldown_ids.sort()
		for operator_id in cooldown_ids:
			side_state.cooldowns[operator_id] -= 1
			if side_state.cooldowns[operator_id] == 0:
				side_state.cooldowns.erase(operator_id)
		side_state.cost_regen_ticks += 1
		if side_state.cost_regen_ticks == CONFIG.COST_REGEN_TICKS:
			side_state.cost_regen_ticks = 0
			side_state.cost = mini(CONFIG.COST_MAX, side_state.cost + CONFIG.COST_REGEN_RATE)

	var commands_by_side := [cmd_a, cmd_b]
	for side in 2:
		for command in commands_by_side[side]:
			assert(command.tick == tick, "command tick does not match MatchState.tick")
			if command.kind == InputCommand.Kind.DEPLOY:
				assert(_operator_data.has(command.operator_id), "unknown operator_id")
				assert(command.facing >= -1 and command.facing <= 3, "unknown deployment facing")
				var deploy_data := _operator_data[command.operator_id] as OperatorData
				var is_phantom: bool = command.operator_id == PHANTOM_DATA.operator_id
				if phantom_can_deploy(side, command.cell) if is_phantom else DeployRules.is_legal(side, deploy_data, command.cell, ball.cell, units, sides[side], _arena):
					var unit := UnitState.new(
						next_unit_id,
						side,
						command.operator_id,
						command.cell,
						deploy_data.max_health,
						deploy_data.initial_sp,
						roundi(deploy_data.attack_interval * CONFIG.TICK_RATE),
						command.facing,
					)
					if deploy_data.skills[0].effect_type == "passive_heal":
						unit.coins = mini(int(deploy_data.skills[0].effect_params["coin_limit"]), int(deploy_data.talent_1.effect_params["initial_coins"]))
						unit.last_coin_gain_tick = tick
					if is_phantom:
						sides[side].phantom_count -= 1
						sides[side].phantom_cooldown_ticks = roundi(PHANTOM_DATA.redeploy_time * CONFIG.TICK_RATE)
					else:
						var member_ids := _operator_data.keys()
						member_ids.sort()
						for id in member_ids:
							var member: OperatorData = _operator_data[id]
							if member.talent_2.effect_type == "initial_sp_aura" and deploy_data.profession_id == member.talent_2.effect_params["profession_id"]:
								unit.sp = mini(SkillRules.sp_limit(deploy_data.skills[0]), unit.sp + int(member.talent_2.effect_params["initial_sp_add"]))
						if deploy_data.talent_2.effect_type == "summon_phantom":
							var params := deploy_data.talent_2.effect_params
							sides[side].phantom_count = mini(int(params["stock_limit"]), sides[side].phantom_count + int(params["stock_per_deploy"]))
					next_unit_id += 1
					units.append(unit)
					sides[side].cost -= deploy_data.deploy_cost
			elif command.kind == InputCommand.Kind.RETREAT:
				for index in units.size():
					var retreating := units[index]
					if retreating.unit_id == command.unit_id and retreating.side == side:
						var retreat_data := _operator_data[retreating.operator_id] as OperatorData
						if retreat_data.branch_trait.effect_type not in ["cost_drain", "phantom"]:
							sides[side].cost = mini(
								CONFIG.COST_MAX,
								sides[side].cost + (retreat_data.deploy_cost if retreat_data.branch_trait.effect_type == "refund_on_kill" else roundi(retreat_data.deploy_cost * CONFIG.RETREAT_REFUND_RATIO)),
							)
						if retreat_data.branch_trait.effect_type != "phantom":
							sides[side].cooldowns[retreating.operator_id] = roundi(retreat_data.redeploy_time * CONFIG.TICK_RATE)
						units.remove_at(index)
						break
			else:
				assert(command.kind == InputCommand.Kind.SKILL, "unknown command kind")
				assert(command.skill_index == 0, "only skill index 0 is supported")
				for unit in units:
					if unit.unit_id == command.unit_id and unit.side == side:
						var operator := _operator_data[unit.operator_id] as OperatorData
						if SkillRules.can_manually_activate(unit, operator.skills[0]):
							SkillRules.activate(unit, operator)
						break

	var maintained_units: Array[UnitState] = []
	for unit in units:
		unit.bind_ticks_left = maxi(0, unit.bind_ticks_left - 1)
		var operator := _operator_data[unit.operator_id] as OperatorData
		if unit.hp > 0 and operator.branch_trait.effect_type == "cost_drain":
			unit.cost_drain_ticks += 1
			var branch_trait := operator.branch_trait
			if unit.cost_drain_ticks == roundi(float(branch_trait.effect_params["drain_interval"]) * CONFIG.TICK_RATE):
				unit.cost_drain_ticks = 0
				var amount := int(branch_trait.effect_params["drain_amount"])
				if sides[unit.side].cost < amount:
					sides[unit.side].cooldowns[unit.operator_id] = roundi(operator.redeploy_time * CONFIG.TICK_RATE)
					continue
				sides[unit.side].cost -= amount
				if operator.talent_1.effect_type == "coin_income":
					var talent := operator.talent_1.effect_params
					var limit := int(operator.skills[0].effect_params["coin_limit"])
					if unit.coins < limit:
						unit.coins = mini(limit, unit.coins + int(talent["coins_per_drain"]))
						unit.last_coin_gain_tick = tick
					unit.coin_attack_stacks = mini(int(talent["max_attack_stacks"]), unit.coin_attack_stacks + 1)
		maintained_units.append(unit)
	units = maintained_units
	_refresh_talents()

	for unit in units:
		if unit.hp <= 0:
			continue
		var data: OperatorData = _operator_data[unit.operator_id]
		if data.branch_trait.effect_type == "phantom":
			unit.life_loss_ticks += 1
			if unit.life_loss_ticks == CONFIG.TICK_RATE:
				unit.life_loss_ticks = 0
				unit.hp -= roundi(SkillRules.max_health_value(unit, data) * int(data.branch_trait.effect_params["life_loss_percent"]) / 100.0)
				unit.last_damage_tick = tick
		var recovery := 0
		for source in units:
			var source_data: OperatorData = _operator_data[source.operator_id]
			if source.side == unit.side and source.hp > 0 and source.skill_ticks_left == 0 and source_data.talent_2.effect_type == "inactive_regen_aura":
				recovery += int(source_data.talent_2.effect_params["heal_per_second"])
		if unit.hp > 0 and recovery > 0:
			unit.hp_regen_accum += recovery * CONFIG.UNIT_HEAL_PERCENT
			var healed := unit.hp_regen_accum / (CONFIG.TICK_RATE * 100)
			unit.hp_regen_accum %= CONFIG.TICK_RATE * 100
			if healed > 0 and unit.hp < SkillRules.max_health_value(unit, data):
				unit.hp = mini(SkillRules.max_health_value(unit, data), unit.hp + healed)
				unit.last_heal_tick = tick

	for unit in units:
		if unit.hp <= 0:
			continue
		var attacker_data := _operator_data[unit.operator_id] as OperatorData
		if attacker_data.branch_trait.effect_type == "phantom":
			continue
		var skill := attacker_data.skills[0]
		if skill.sp_recharge_type == "time" and (unit.skill_ticks_left == 0 or skill.effect_type == "charge_shot"):
			if unit.sp < SkillRules.sp_limit(skill):
				unit.sp_regen_ticks += 1
				if unit.sp_regen_ticks == CONFIG.TICK_RATE:
					unit.sp_regen_ticks = 0
					unit.sp += 1
		if skill.effect_type == "atk_boost_auto" and SkillRules.can_activate(unit, skill):
			SkillRules.activate(unit, attacker_data)
		unit.attack_ticks_left -= 1
		if unit.attack_ticks_left > 0:
			continue

		unit.attack_ticks_left = SkillRules.attack_interval_ticks(unit, attacker_data)
		var attack := SkillRules.attack_value(unit, attacker_data)
		if skill.effect_type == "passive_heal" and unit.coins > 0:
			var heal_target: UnitState
			var target_max_hp := 1
			for ally in units:
				if ally.side != unit.side or ally.hp <= 0 or ally.unit_id == unit.unit_id or ally.operator_id == PHANTOM_DATA.operator_id:
					continue
				var offset := ally.cell - unit.cell
				var radius := int(skill.effect_params["heal_radius"])
				var ally_data := _operator_data[ally.operator_id] as OperatorData
				var ally_max := SkillRules.max_health_value(ally, ally_data)
				if absi(offset.x) > radius or absi(offset.y) > radius or ally.hp * 100 >= ally_max * int(skill.effect_params["hp_threshold_percent"]):
					continue
				if heal_target == null or ally.hp * target_max_hp < heal_target.hp * ally_max:
					heal_target = ally
					target_max_hp = ally_max
			if heal_target != null:
				heal_target.hp = mini(target_max_hp, heal_target.hp + Combat.calculate_healing(attack, int(skill.effect_params["heal_percent"])))
				unit.coins -= 1
				unit.last_coin_spend_tick = tick
				unit.last_attack_tick = tick
				unit.last_attack_target_x = heal_target.cell.x
				unit.last_attack_target_y = heal_target.cell.y
				unit.last_attack_is_heal = true
				heal_target.last_heal_tick = tick
				continue
		if attacker_data.damage_type == "healing":
			var healed_ids: Array[int] = []
			var target_count := int(attacker_data.branch_trait.effect_params["target_count"])
			for _target in target_count:
				var heal_target: UnitState
				var target_max_hp := 1
				for ally in units:
					if ally.side != unit.side or ally.hp <= 0 or ally.operator_id == PHANTOM_DATA.operator_id or ally.unit_id in healed_ids:
						continue
					var ally_data: OperatorData = _operator_data[ally.operator_id]
					var ally_max := SkillRules.max_health_value(ally, ally_data)
					if ally.hp < ally_max and _is_in_attack_range(unit, ally.cell, attacker_data.attack_range) and (heal_target == null or ally.hp * target_max_hp < heal_target.hp * ally_max):
						heal_target = ally
						target_max_hp = ally_max
				if heal_target == null:
					break
				heal_target.hp = mini(target_max_hp, heal_target.hp + Combat.calculate_healing(attack))
				healed_ids.append(heal_target.unit_id)
				unit.last_attack_tick = tick
				unit.last_attack_is_heal = true
				unit.last_attack_target_x = heal_target.cell.x
				unit.last_attack_target_y = heal_target.cell.y
				heal_target.last_heal_tick = tick
			if not healed_ids.is_empty() and skill.sp_recharge_type == "on_hit" and unit.skill_ticks_left == 0:
				unit.sp = mini(SkillRules.sp_limit(skill), unit.sp + 1)
			continue

		var attack_target: UnitState
		var target_taunt := -1
		for enemy in units:
			if enemy.side != unit.side and enemy.hp > 0 and _is_in_attack_range(unit, enemy.cell, attacker_data.attack_range):
				var enemy_data: OperatorData = _operator_data[enemy.operator_id]
				var taunt := int(enemy_data.branch_trait.effect_params["taunt_level"]) if enemy_data.branch_trait.effect_type == "phantom" else 0
				if taunt > target_taunt:
					attack_target = enemy
					target_taunt = taunt
		if attack_target != null:
			if SkillRules.is_auto_trigger(skill) and SkillRules.can_activate(unit, skill):
				SkillRules.activate(unit, attacker_data)
				attack = SkillRules.attack_value(unit, attacker_data)
			var targets: Array[UnitState] = [attack_target]
			var target_count := attacker_data.block_count if attacker_data.branch_trait.effect_type == "attack_all_blocked" else 1
			if attacker_data.talent_1.effect_type == "attack_proc" and rng.next_percent() < int(attacker_data.talent_1.effect_params["chance_percent"]):
				attack = roundi(attack * int(attacker_data.talent_1.effect_params["attack_percent"]) / 100.0)
				target_count = int(attacker_data.talent_1.effect_params["target_count"])
			for enemy in units:
				if targets.size() >= target_count:
					break
				if enemy != attack_target and enemy.side != unit.side and enemy.hp > 0 and _is_in_attack_range(unit, enemy.cell, attacker_data.attack_range):
					targets.append(enemy)
			unit.last_attack_tick = tick
			unit.last_attack_is_heal = false
			unit.last_attack_target_x = attack_target.cell.x
			unit.last_attack_target_y = attack_target.cell.y
			var shot_count := int(skill.effect_params["shot_count"]) if unit.skill_ticks_left != 0 and skill.effect_type == "multi_shot" else 1
			var hit := false
			for target in targets:
				var target_data: OperatorData = _operator_data[target.operator_id]
				var dodge_chance := target_data.dodge_physical if attacker_data.damage_type == "physical" else target_data.dodge_magical
				for _shot in shot_count:
					if target.hp <= 0:
						break
					var damage := Combat.calculate_damage(attack, SkillRules.defense_value(target, target_data), SkillRules.magic_resist_value(target, target_data), attacker_data.damage_type, dodge_chance, rng, attacker_data.profession_id)
					var landed := _apply_damage(target, target_data, damage)
					if landed and unit.skill_ticks_left != 0 and skill.effect_type == "charge_shot":
						target.bind_ticks_left = roundi(float(skill.effect_params["bind_duration"]) * CONFIG.TICK_RATE)
					hit = hit or landed
					if target.hp > 0 and attacker_data.talent_1.effect_type == "defense_damage":
						var extra_attack := roundi(SkillRules.defense_value(target, target_data) * int(attacker_data.talent_1.effect_params["defense_damage_percent"]) / 100.0)
						if extra_attack > 0:
							var extra_damage := Combat.calculate_damage(extra_attack, 0, SkillRules.magic_resist_value(target, target_data), "magical", target_data.dodge_magical, rng, attacker_data.profession_id)
							hit = _apply_damage(target, target_data, extra_damage) or hit
					if target.hp <= 0 and attacker_data.branch_trait.effect_type == "refund_on_kill":
						sides[unit.side].cost = mini(CONFIG.COST_MAX, sides[unit.side].cost + int(attacker_data.branch_trait.effect_params["refund_amount"]))
			if hit and skill.sp_recharge_type == "on_hit" and unit.skill_ticks_left == 0:
				unit.sp = mini(SkillRules.sp_limit(skill), unit.sp + 1)
			if unit.skill_ticks_left == -1:
				unit.skill_ticks_left = 0
		elif ball.move_ticks_left == 0 and _is_in_attack_range(unit, ball.cell, attacker_data.attack_range):
			if SkillRules.is_auto_trigger(skill) and SkillRules.can_activate(unit, skill):
				SkillRules.activate(unit, attacker_data)
				attack = SkillRules.attack_value(unit, attacker_data)
			if attacker_data.talent_1.effect_type == "attack_proc" and rng.next_percent() < int(attacker_data.talent_1.effect_params["chance_percent"]):
				attack = roundi(attack * int(attacker_data.talent_1.effect_params["attack_percent"]) / 100.0)
			unit.last_attack_tick = tick
			unit.last_attack_is_heal = false
			unit.last_attack_target_x = ball.cell.x
			unit.last_attack_target_y = ball.cell.y
			var shot_count := int(skill.effect_params["shot_count"]) if unit.skill_ticks_left != 0 and skill.effect_type == "multi_shot" else 1
			for _shot in shot_count:
				ball.add_push(unit.cell, attack, _ball_data, ATTACK_RANGE.rotate_offset(Vector2i.RIGHT, unit.facing))
			if skill.sp_recharge_type == "on_hit" and unit.skill_ticks_left == 0:
				unit.sp = mini(SkillRules.sp_limit(skill), unit.sp + 1)
			if unit.skill_ticks_left == -1:
				unit.skill_ticks_left = 0

	for unit in units:
		unit.hp_lock_ticks_left = maxi(0, unit.hp_lock_ticks_left - 1)
		if unit.skill_ticks_left > 0:
			var operator := _operator_data[unit.operator_id] as OperatorData
			var old_interval := SkillRules.attack_interval_ticks(unit, operator)
			unit.skill_ticks_left -= 1
			if unit.skill_ticks_left == 0:
				unit.attack_ticks_left = ceili(float(unit.attack_ticks_left) * SkillRules.attack_interval_ticks(unit, operator) / old_interval)

	var alive_units: Array[UnitState] = []
	for unit in units:
		if unit.hp > 0:
			alive_units.append(unit)
		else:
			var defeated_data := _operator_data[unit.operator_id] as OperatorData
			if defeated_data.branch_trait.effect_type != "phantom":
				sides[unit.side].cooldowns[unit.operator_id] = roundi(defeated_data.redeploy_time * CONFIG.TICK_RATE)
	units = alive_units
	_refresh_talents()

	ball.advance_move(ball.move_ticks_left == 1 and ball_move_is_blocked())

	tick += 1
	if ball.cell.x <= 0:
		result = RESULT_BLUE_WIN
	elif ball.cell.x >= CONFIG.GRID_COLUMNS - 1:
		result = RESULT_RED_WIN
	elif tick == CONFIG.MATCH_TICKS or tick >= CONFIG.MATCH_TICKS + CONFIG.OVERTIME_TICKS:
		if ball.cell.x < CONFIG.BALL_START_CELL.x:
			result = RESULT_BLUE_WIN
		elif ball.cell.x > CONFIG.BALL_START_CELL.x:
			result = RESULT_RED_WIN
		elif tick >= CONFIG.MATCH_TICKS + CONFIG.OVERTIME_TICKS:
			result = RESULT_DRAW


func ball_move_is_blocked() -> bool:
	if ball.move_ticks_left == 0:
		return false
	var ball_target := ball.cell + ball.move_direction
	if ball_target.x < 0 or ball_target.x >= CONFIG.GRID_COLUMNS or ball_target.y < 0 or ball_target.y >= CONFIG.GRID_ROWS:
		return true
	var terrain := _arena.terrain_at(ball_target)
	if terrain != "ground" and terrain != "ground_no_deploy":
		return true
	for unit in units:
		var blocker_data := _operator_data[unit.operator_id] as OperatorData
		if unit.hp > 0 and unit.cell == ball_target and blocker_data.block_count >= CONFIG.BLOCK_BALL_MIN:
			return true
	return false


func state_hash() -> int:
	var hash_value := 17
	hash_value = (hash_value * 31 + tick) & 0x7fffffff
	hash_value = (hash_value * 31 + rng.state) & 0x7fffffff
	hash_value = (hash_value * 31 + result) & 0x7fffffff
	hash_value = (hash_value * 31 + next_unit_id) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.cell.x) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.cell.y) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.accum.x) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.accum.y) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.move_ticks_left) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.move_direction.x) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.move_direction.y) & 0x7fffffff

	for side_state in sides:
		hash_value = (hash_value * 31 + side_state.side_id) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.cost) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.cost_regen_ticks) & 0x7fffffff
		var cooldown_ids := side_state.cooldowns.keys()
		cooldown_ids.sort()
		for operator_id in cooldown_ids:
			for codepoint in String(operator_id).to_utf32_buffer():
				hash_value = (hash_value * 31 + codepoint) & 0x7fffffff
			hash_value = (hash_value * 31 + side_state.cooldowns[operator_id]) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.phantom_count) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.phantom_cooldown_ticks) & 0x7fffffff

	var previous_unit_id := -1
	for unit in units:
		assert(unit.unit_id > previous_unit_id, "units must stay sorted by unit_id")
		previous_unit_id = unit.unit_id
		hash_value = (hash_value * 31 + unit.unit_id) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.side) & 0x7fffffff
		for codepoint in unit.operator_id.to_utf32_buffer():
			hash_value = (hash_value * 31 + codepoint) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.cell.x) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.cell.y) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.facing) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.hp) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.sp) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.attack_ticks_left) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.sp_regen_ticks) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.skill_ticks_left) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.bind_ticks_left) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_attack_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_attack_target_x) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_attack_target_y) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_damage_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_heal_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.coins) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.coin_attack_stacks) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.cost_drain_ticks) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_coin_gain_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_coin_spend_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + int(unit.last_attack_is_heal)) & 0x7fffffff
		for field in [unit.attack_bonus_percent, unit.defense_bonus_percent, unit.attack_speed_bonus, unit.magic_resist_bonus, unit.max_health_bonus_percent, unit.blessing_target_id, int(unit.emergency_heal_used), unit.hp_lock_ticks_left, unit.revive_cost, unit.hp_regen_accum, unit.last_damage_block_tick, unit.life_loss_ticks]:
			hash_value = (hash_value * 31 + field) & 0x7fffffff
	return hash_value


func phantom_available(side: int) -> bool:
	if result != RESULT_RUNNING or sides[side].phantom_count <= 0 or sides[side].phantom_cooldown_ticks > 0 or sides[side].cost < PHANTOM_DATA.deploy_cost:
		return false
	for unit in units:
		if unit.side == side and unit.operator_id == "nightingale" and unit.hp > 0:
			return true
	return false


func phantom_can_deploy(side: int, cell: Vector2i) -> bool:
	if not phantom_available(side) or cell.x < 0 or cell.x >= CONFIG.GRID_COLUMNS or cell.y < 0 or cell.y >= CONFIG.GRID_ROWS:
		return false
	if _arena.terrain_at(cell) != PHANTOM_DATA.terrain_requirement or (side == 0 and cell.x < ball.cell.x) or (side == 1 and cell.x > ball.cell.x):
		return false
	for unit in units:
		if unit.cell == cell:
			return false
	return true


func _refresh_talents() -> void:
	var old_health: Array[int] = []
	var old_intervals: Array[int] = []
	for unit in units:
		var data: OperatorData = _operator_data[unit.operator_id]
		old_health.append(SkillRules.max_health_value(unit, data))
		old_intervals.append(SkillRules.attack_interval_ticks(unit, data))
		unit.attack_bonus_percent = 0
		unit.defense_bonus_percent = 0
		unit.attack_speed_bonus = 0
		unit.magic_resist_bonus = 0
		unit.max_health_bonus_percent = 0
	for source in units:
		if source.hp <= 0:
			continue
		var source_data: OperatorData = _operator_data[source.operator_id]
		var first := source_data.talent_1
		var second := source_data.talent_2
		if first.effect_type == "attack_speed_buff":
			source.attack_speed_bonus += int(first.effect_params["attack_speed_add"])
		if second.effect_type == "random_blessing":
			if source.blessing_target_id == -1:
				var candidates: Array[UnitState] = []
				for ally in units:
					if ally.side == source.side and ally.unit_id != source.unit_id and ally.hp > 0:
						candidates.append(ally)
				if not candidates.is_empty():
					source.blessing_target_id = candidates[rng.next_u32() % candidates.size()].unit_id
			for ally in units:
				if ally.unit_id == source.unit_id or ally.unit_id == source.blessing_target_id:
					ally.attack_bonus_percent += int(second.effect_params["attack_percent"])
					ally.max_health_bonus_percent += int(second.effect_params["max_health_percent"])
		if second.effect_type == "isolated_buff":
			var isolated := true
			for ally in units:
				if ally.side == source.side and ally.unit_id != source.unit_id and ally.hp > 0 and absi(ally.cell.x - source.cell.x) + absi(ally.cell.y - source.cell.y) <= 1:
					isolated = false
					break
			if isolated:
				source.attack_bonus_percent += int(second.effect_params["attack_percent"])
				source.attack_speed_bonus += int(second.effect_params["attack_speed_add"])
		for ally in units:
			if ally.side != source.side or ally.hp <= 0:
				continue
			var ally_data: OperatorData = _operator_data[ally.operator_id]
			if first.effect_type == "attack_speed_aura":
				ally.attack_speed_bonus += int(first.effect_params["attack_speed_add"])
			if first.effect_type == "magic_resist_aura" and _is_in_attack_range(source, ally.cell, source_data.attack_range):
				ally.magic_resist_bonus += int(first.effect_params["magic_resist_add"])
			if second.effect_type == "defense_aura" and ally_data.profession_id == second.effect_params["profession_id"]:
				ally.defense_bonus_percent += int(second.effect_params["defense_percent"])
	for index in units.size():
		var unit := units[index]
		var data: OperatorData = _operator_data[unit.operator_id]
		var new_max := SkillRules.max_health_value(unit, data)
		if unit.hp > 0 and new_max != old_health[index]:
			unit.hp = maxi(1, roundi(float(unit.hp) * new_max / old_health[index]))
		var interval := SkillRules.attack_interval_ticks(unit, data)
		if interval != old_intervals[index]:
			unit.attack_ticks_left = ceili(float(unit.attack_ticks_left) * interval / old_intervals[index])


func _apply_damage(target: UnitState, data: OperatorData, damage: int) -> bool:
	if damage == 0:
		return false
	if data.talent_1.effect_type == "damage_block" and rng.next_percent() < int(data.talent_1.effect_params["chance_percent"]):
		target.last_damage_block_tick = tick
		return false
	var max_hp := SkillRules.max_health_value(target, data)
	if target.hp_lock_ticks_left > 0:
		damage = mini(damage, maxi(0, target.hp - ceili(max_hp * int(data.talent_1.effect_params["lock_hp_percent"]) / 100.0)))
	if damage == 0:
		return false
	target.hp -= damage
	target.last_damage_tick = tick
	if data.talent_1.effect_type == "emergency_heal" and not target.emergency_heal_used:
		target.hp = maxi(1, target.hp)
		var params := data.talent_1.effect_params
		if target.hp * 100 <= max_hp * int(params["hp_threshold_percent"]):
			target.emergency_heal_used = true
			target.hp = mini(max_hp, target.hp + roundi(max_hp * int(params["heal_percent"]) / 100.0))
			target.hp_lock_ticks_left = roundi(float(params["lock_duration"]) * CONFIG.TICK_RATE)
			target.last_heal_tick = tick
	if target.hp <= 0 and data.talent_2.effect_type == "fatal_revive":
		var params := data.talent_2.effect_params
		var cost := target.revive_cost if target.revive_cost > 0 else int(params["initial_cost"])
		if sides[target.side].cost >= cost:
			sides[target.side].cost -= cost
			target.revive_cost = cost * int(params["cost_multiplier"])
			target.hp = roundi(max_hp * int(params["heal_percent"]) / 100.0)
			target.last_heal_tick = tick
	var skill := data.skills[0]
	if skill.sp_recharge_type == "on_damaged" and target.skill_ticks_left == 0:
		target.sp = mini(SkillRules.sp_limit(skill), target.sp + 1)
	if target.hp <= 0:
		_refresh_talents()
	return true


func _is_in_attack_range(unit: UnitState, target_cell: Vector2i, attack_range: Array[Vector2i]) -> bool:
	var relative := target_cell - unit.cell
	for offset in attack_range:
		if relative == ATTACK_RANGE.rotate_offset(offset, unit.facing):
			return true
	return false
