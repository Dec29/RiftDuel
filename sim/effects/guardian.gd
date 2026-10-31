class_name GuardianRules
extends RefCounted


# Returns true only when the guardian replaces ordinary combat this tick.
static func advance(state: MatchState, unit: UnitState, data: OperatorData) -> bool:
	var skill := data.skills[unit.skill_index]
	if unit.attack_intent!=null and unit.attack_intent.kind!=AttackIntent.TargetKind.HEAL:return false
	if unit.silence_ticks_left > 0:
		return false
	if skill.effect_type == "guardian_calcium" and unit.skill_ticks_left > 0:
		if unit.stun_ticks_left == 0 and unit.displacement_ticks_left == 0 and (unit.skill_elapsed_ticks + 1) % int(skill.effect_params["pulse_ticks"]) == 0:
			heal_targets(state, unit, data, targets(state, unit, data, false))
		return true
	if not SkillRules.can_activate(unit, skill):
		return false
	if unit.attack_intent==null and skill.effect_type == "guardian_aid" and unit.attack_ticks_left > 1:
		return false
	var allies := targets(state, unit, data, skill.effect_type == "guardian_aid")
	allies=AttackTimeline.pinned(state,unit,allies)
	if allies.is_empty():
		return false
	if unit.attack_intent!=null and not AttackTimeline.advance(state,unit):return true
	if not AttackTimeline.windup(state,unit,data,allies,allies[0].cell,true):return true
	SkillRules.activate(unit, data)
	heal_targets(state, unit, data, allies)
	unit.skill_ticks_left = 0
	unit.attack_ticks_left = SkillRules.attack_interval_ticks(unit, data)
	return true


static func targets(state: MatchState, unit: UnitState, data: OperatorData, first_aid: bool) -> Array[UnitState]:
	var result: Array[UnitState] = []
	var skill := data.skills[unit.skill_index]
	for ally in state.units:
		var ally_data: OperatorData = state._operator_data[ally.operator_id]
		var max_hp := SkillRules.max_health_value(ally, ally_data)
		if ally.hp <= 0 or ally.critical_ticks_left>0 or ally.side != unit.side or ally_data.profession_id == "summon" or ally_data.branch_trait.effect_type in ["musha","unyield"] or not state._is_in_attack_range(unit, ally.cell, skill.attack_range_override):
			continue
		if ally.hp >= max_hp:
			continue
		if first_aid and ally.hp * 100 > max_hp * int(skill.effect_params["hp_threshold_percent"]):
			continue
		if first_aid:
			if result.is_empty() or ally.hp * SkillRules.max_health_value(result[0], state._operator_data[result[0].operator_id]) < result[0].hp * max_hp:
				result = [ally]
		else:
			result.append(ally)
	return result


static func heal_targets(state: MatchState, unit: UnitState, data: OperatorData, allies: Array[UnitState]) -> void:
	var skill := data.skills[unit.skill_index]
	var amount := Combat.calculate_healing(SkillRules.attack_value(unit, data), int(skill.effect_params["heal_percent"]))
	for ally in allies:
		var ally_data: OperatorData = state._operator_data[ally.operator_id]
		ally.hp = mini(SkillRules.max_health_value(ally, ally_data), ally.hp + SkillRules.healing_received(ally,ally_data,amount,unit))
		ally.last_heal_tick = state.tick
		if data.talent_2.effect_type == "healing_sp" and SkillRules.can_gain_sp(ally) and ally.skill_ticks_left == 0 and ally_data.skills[ally.skill_index].sp_recharge_type != "passive":
			ally.sp = mini(SkillRules.sp_limit(ally_data.skills[ally.skill_index]), ally.sp + int(data.talent_2.effect_params["sp_add"]))
		unit.last_attack_tick = state.tick
		unit.last_attack_is_heal = true
		unit.last_attack_target_x = ally.cell.x
		unit.last_attack_target_y = ally.cell.y
