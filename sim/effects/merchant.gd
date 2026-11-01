class_name MerchantRules
extends RefCounted


static func clean_bombs(state: MatchState) -> void:
	var kept: Array[ChampagneBomb] = []
	for bomb in state.champagne_bombs:
		for source in state.units:
			if source.unit_id == bomb.source_id and source.hp > 0 and (bomb.triggered_tick < 0 or state.tick - bomb.triggered_tick < 12):
				kept.append(bomb)
				break
	state.champagne_bombs = kept


static func advance_bombs(state: MatchState) -> void:
	MerchantRules.clean_bombs(state)
	for unit in state.units:
		if unit.hp > 0: MerchantRules.trigger_bombs_at(state, unit,unit.cell)


static func trigger_bombs_at(state: MatchState, target: UnitState, cell: Vector2i) -> void:
	# Also called for every traversed cell after rigid displacement is committed.
	for bomb in state.champagne_bombs:
		if target.hp <= 0 or bomb.triggered_tick >= 0 or bomb.side == target.side or bomb.cell != cell: continue
		var owner: UnitState = null
		for source in state.units:
			if source.unit_id == bomb.source_id and source.hp > 0: owner = source
		if owner == null: continue
		bomb.triggered_tick = state.tick
		var source_data: OperatorData = state._operator_data[owner.operator_id]
		var skill := source_data.skills[owner.skill_index]
		var target_data: OperatorData = state._operator_data[target.operator_id]
		var hits := 2 if state.bomb_is_mature(bomb) else 1
		for hit in hits:
			if target.hp <= 0: break
			var damage := Combat.calculate_damage(bomb.attack,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,SkillRules.damage_profession_id(source_data),state._damage_taken_percent(target, "physical"))
			if state._apply_damage(target,target_data,damage,"physical") and target.hp > 0:
				StatusRules.add_control(state,target,"slow",int(skill.effect_params["slow_ticks"]))


static func plant_bomb(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var skill := data.skills[source.skill_index]
	var candidates: Array[Vector2i] = []
	for offset in skill.burst_range_override:
		var cell := source.cell + offset
		if state.bomb_cell_is_available(source,cell): candidates.append(cell)
	if candidates.is_empty(): return
	var chosen: UnitState = null
	var priority := -1
	for target in state.units:
		if not state.enemy_is_targetable(source.side,target) or target.cell not in candidates: continue
		var target_data: OperatorData = state._operator_data[target.operator_id]
		var taunt := int(target_data.branch_trait.effect_params["taunt_level"]) if target_data.branch_trait.effect_type == "phantom" else 0
		if taunt > priority:
			chosen = target
			priority = taunt
	var cell := chosen.cell if chosen != null else candidates[state.rng.next_u32() % candidates.size()]
	state.champagne_bombs.append(ChampagneBomb.new(state.next_bomb_id,source,cell,state.tick,roundi(SkillRules.attack_value(source,data)*int(skill.effect_params["bomb_attack_percent"])/100.0)))
	state.next_bomb_id += 1
	source.coins -= 1
	source.last_coin_spend_tick = state.tick
	source.bomb_next_tick = state.tick + int(skill.effect_params["plant_interval_ticks"])
	# Placement slightly postpones the pending ordinary attack, as in the source.
	source.attack_ticks_left += int(skill.effect_params["plant_attack_delay_ticks"])
	if chosen != null: MerchantRules.trigger_bombs_at(state, chosen,cell)


static func fire_coin(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var targets: Array[UnitState] = []
	for target in state.units:
		if state.enemy_is_targetable(source.side,target) and target.unit_id in source.coin_target_ids: targets.append(target)
	source.coins -= 1
	source.last_coin_spend_tick = state.tick
	source.coin_fire_ticks_left = int(data.skills[source.skill_index].effect_params["coin_interval_ticks"])
	if not targets.is_empty():
		var target := targets[state.rng.next_u32() % targets.size()]
		var target_data: OperatorData = state._operator_data[target.operator_id]
		var attack := roundi(SkillRules.attack_value(source,data)*int(data.skills[source.skill_index].effect_params["coin_attack_percent"])/100.0)
		var damage := Combat.calculate_damage(attack,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,SkillRules.damage_profession_id(data),state._damage_taken_percent(target, "physical"))
		source.last_attack_tick = state.tick
		source.last_attack_is_heal = false
		source.last_attack_target_x = target.cell.x
		source.last_attack_target_y = target.cell.y
		var landed := state._apply_damage(target,target_data,damage,"physical",source)
		if landed and source.hp > 0 and target.hp > 0:
			DisplacementRules.apply_unit(state,source,target,DisplacementRules.direction(source,target.cell,"push"),int(data.skills[source.skill_index].effect_params["shift_force"]))
			AuraRules.refresh(state)
	if source.coins == 0:
		source.coin_firing = false
		source.coin_target_ids.clear()
		source.coin_fire_ticks_left = 0


static func maintain_unit(state: MatchState, unit: UnitState, operator: OperatorData) -> bool:
	if unit.hp > 0 and operator.branch_trait.effect_type == "cost_drain":
		unit.cost_drain_ticks += 1
		var branch_trait := operator.branch_trait
		if unit.cost_drain_ticks == roundi(float(branch_trait.effect_params["drain_interval"]) * state.CONFIG.TICK_RATE):
			unit.cost_drain_ticks = 0
			var amount := int(branch_trait.effect_params["drain_amount"])
			if unit.operator_id=="lee" and unit.silence_ticks_left==0 and state.sides[unit.side].cost>=int(operator.talent_2.effect_params["drain_amount"]):
				amount=int(operator.talent_2.effect_params["drain_amount"])
				unit.lee_control_charm=true
			if state.sides[unit.side].cost < amount:
				state.sides[unit.side].cooldowns[unit.operator_id] = state._redeploy_ticks(unit.side, operator)
				LeeRules.on_exit(state,unit,false)
				return false
			state.sides[unit.side].cost -= amount
			if unit.silence_ticks_left == 0 and operator.talent_1.effect_type == "coin_income" and (operator.skills[unit.skill_index].sp_recharge_type == "passive" or unit.skill_ticks_left != 0):
				var talent := operator.talent_1.effect_params
				var limit := int(operator.skills[unit.skill_index].effect_params["coin_limit"])
				if unit.coins < limit:
					unit.coins = mini(limit, unit.coins + int(talent["coins_per_drain"]))
					unit.last_coin_gain_tick = state.tick
				unit.coin_attack_stacks = mini(int(talent["max_attack_stacks"]), unit.coin_attack_stacks + 1)
	return true
