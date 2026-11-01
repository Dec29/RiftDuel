class_name DeployRules
extends RefCounted

const CONFIG := preload("res://data/config.gd")


static func base_cost(data: OperatorData) -> int:
	return data.deploy_cost-int(data.talent_1.effect_params["cost_reduction"]) if data.talent_1.effect_type=="low_cost_support" else data.deploy_cost


static func permanent_cost(data: OperatorData, side: SideState) -> int:
	var rhine := side.rhine_cost_reduction+(side.rhine_first_cost_reduction if not side.rhine_first_discount_used and side.rhine_cost_reduction>0 else 0) if data.group_id=="rhine" else 0
	return maxi(0,base_cost(data)-rhine-(side.vanguard_cost_discount if data.profession_id=="vanguard" else (side.sniper_cost_discount if data.profession_id=="sniper" else 0)))


static func actual_cost(operator_data: OperatorData, side_state: SideState) -> int:
	if operator_data.profession_id=="guard":return maxi(0,permanent_cost(operator_data,side_state)-side_state.next_deploy_discount-int(side_state.wildmane_discounts.get(operator_data.operator_id,0)))
	return operator_data.deploy_cost if operator_data.branch_trait.effect_type in ["stainless_device_1","stainless_device_2","stainless_device_3","monstr_reconstruction","flowing_shape","jessica_shield","ling_summon","pozyomka_typewriter","curse_doll","medical_drone", "seaborn", "mon3tr", "phantom", "executor_clone", "water_cannon", "summoner_drone"] else maxi(0, permanent_cost(operator_data,side_state) - side_state.next_deploy_discount)


static func is_legal(
	side: int,
	operator_data: OperatorData,
	cell: Vector2i,
	ball_cell: Vector2i,
	units: Array[UnitState],
	side_state: SideState,
	arena: ArenaData,
	platform_cells: Array[Vector2i] = [],
	ignore_line: bool = false,
) -> bool:
	if cell.x < 0 or cell.x >= CONFIG.GRID_COLUMNS or cell.y < 0 or cell.y >= CONFIG.GRID_ROWS:
		return false
	var terrain := "high" if cell in platform_cells else arena.terrain_at(cell)
	if terrain != "ground" and terrain != "high":
		return false
	if operator_data.terrain_requirement != "both" and terrain != operator_data.terrain_requirement:
		return false
	if not ignore_line and not operator_data.ignore_deploy_line:
		if side == 0 and cell.x < ball_cell.x:
			return false
		if side == 1 and cell.x > ball_cell.x:
			return false
	if side_state.cost < actual_cost(operator_data, side_state) or side_state.cooldowns.get(operator_data.operator_id, 0) > 0:
		return false
	for unit in units:
		if unit.cell == cell or (unit.hp>0 and unit.monstr_origin_cell==cell):
			return false
		if unit.side == side and unit.operator_id == operator_data.operator_id and operator_data.branch_trait.effect_type not in ["stainless_device_1","stainless_device_2","stainless_device_3","ling_summon","flowing_shape","summoner_drone"]:
			return false
	return true
