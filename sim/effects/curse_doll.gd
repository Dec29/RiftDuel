class_name CurseDollRules
extends RefCounted

static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id=="shamare" and state._operator_data[unit.operator_id].skills[unit.skill_index].effect_type=="curse_doll_supply":return unit
	return null

static func available(state: MatchState, side: int) -> bool:
	var source := owner(state,side)
	if source==null or source.silence_ticks_left>0 or source.curse_doll_stock<=0 or state.result!=state.RESULT_RUNNING or state.sides[side].cost<state.CURSE_DOLL_DATA.deploy_cost or state.sides[side].cooldowns.get("curse_doll",0)>0:return false
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id=="curse_doll":return false
	return true

static func maintain(state: MatchState) -> void:
	var alive: Array[UnitState]=[]
	for unit in state.units:
		if unit.operator_id=="curse_doll":
			var source := WArtilleryRules.owner(state,unit.curse_doll_owner_id)
			if source==null or source.hp<=0 or state.tick-unit.deployed_tick>=int(state.CURSE_DOLL_DATA.branch_trait.effect_params["lifetime_ticks"]):continue
		alive.append(unit)
	state.units=alive

static func remove_owned(state: MatchState, source: UnitState) -> void:
	for unit in state.units.duplicate():
		if unit.curse_doll_owner_id==source.unit_id:state.units.erase(unit)
