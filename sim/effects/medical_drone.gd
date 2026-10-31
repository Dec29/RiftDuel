class_name MedicalDroneRules
extends RefCounted


static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id=="silence" and state._operator_data[unit.operator_id].skills[unit.skill_index].effect_type=="medical_drone_supply":return unit
	return null


static func available(state: MatchState, side: int) -> bool:
	var source := owner(state,side)
	if state.result!=state.RESULT_RUNNING or source==null or source.medical_drone_stock<=0 or state.sides[side].cost<state.MEDICAL_DRONE_DATA.deploy_cost or state.sides[side].cooldowns.get("medical_drone",0)>0:return false
	for unit in state.units:
		if unit.operator_id=="medical_drone" and unit.side==side and unit.hp>0:return false
	return true


static func maintain(state: MatchState) -> void:
	var retained: Array[UnitState]=[]
	for unit in state.units:
		if unit.operator_id=="medical_drone" and state.tick-unit.deployed_tick>=int(state.MEDICAL_DRONE_DATA.branch_trait.effect_params["lifetime_ticks"]):continue
		retained.append(unit)
	state.units=retained


static func heal(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.sleep_ticks_left>0:return
	unit.attack_ticks_left=maxi(0,unit.attack_ticks_left-1)
	if unit.attack_ticks_left>0:return
	# Continuous ordinary attack: pulses continue even with no injured target.
	unit.attack_ticks_left=roundi(data.attack_interval*state.CONFIG.TICK_RATE)
	unit.last_attack_tick=state.tick;unit.last_attack_is_heal=true
	unit.last_attack_target_x=unit.cell.x;unit.last_attack_target_y=unit.cell.y
	var amount := Combat.calculate_healing(SkillRules.attack_value(unit,data))
	for ally in state.units:
		if ally.hp<=0 or ally.side!=unit.side or ally.critical_ticks_left>0:continue
		var ally_data: OperatorData=state._operator_data[ally.operator_id]
		if ally_data.profession_id=="summon" or ally_data.branch_trait.effect_type in ["musha","unyield"] or not state._is_in_attack_range(unit,ally.cell,data.attack_range):continue
		ally.hp=mini(SkillRules.max_health_value(ally,ally_data),ally.hp+SkillRules.healing_received(ally,ally_data,amount,unit))
		ally.last_heal_tick=state.tick
