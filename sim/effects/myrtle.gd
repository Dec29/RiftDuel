class_name MyrtleRules
extends RefCounted


# The original skill replaces ordinary attacks; it is not an independent field heal.
static func heal(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if not StatusRules.advance_basic_attack(unit):return
	var skill := data.skills[unit.skill_index]
	var chosen: UnitState
	for ally in state.units:
		var ally_data: OperatorData=state._operator_data[ally.operator_id]
		var maximum := SkillRules.max_health_value(ally,ally_data)
		if ally.side!=unit.side or ally.hp<=0 or ally.critical_ticks_left>0 or ally.hp>=maximum or ally_data.profession_id=="summon" or ally_data.branch_trait.effect_type=="musha" or not state._is_in_attack_range(unit,ally.cell,skill.attack_range_override):continue
		if chosen==null or ally.hp*SkillRules.max_health_value(chosen,state._operator_data[chosen.operator_id])<chosen.hp*maximum:chosen=ally
	if chosen==null:return
	var target_data: OperatorData=state._operator_data[chosen.operator_id]
	var amount := Combat.calculate_healing(SkillRules.attack_value(unit,data),int(skill.effect_params["heal_percent"]))
	chosen.hp=mini(SkillRules.max_health_value(chosen,target_data),chosen.hp+SkillRules.healing_received(chosen,target_data,amount,unit))
	chosen.last_heal_tick=state.tick
	unit.last_attack_tick=state.tick
	unit.last_attack_is_heal=true
	unit.last_attack_target_x=chosen.cell.x
	unit.last_attack_target_y=chosen.cell.y
	unit.attack_ticks_left=state.CONFIG.TICK_RATE
