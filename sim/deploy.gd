class_name DeployRules
extends RefCounted

const CONFIG := preload("res://data/config.gd")


static func is_legal(
	side: int,
	operator_data: OperatorData,
	cell: Vector2i,
	ball_cell: Vector2i,
	units: Array[UnitState],
	side_state: SideState,
	arena: ArenaData,
) -> bool:
	if cell.x < 0 or cell.x >= CONFIG.GRID_COLUMNS or cell.y < 0 or cell.y >= CONFIG.GRID_ROWS:
		return false
	var terrain := arena.terrain_at(cell)
	if terrain != "ground" and terrain != "high":
		return false
	if operator_data.terrain_requirement != "both" and terrain != operator_data.terrain_requirement:
		return false
	if not operator_data.ignore_deploy_line:
		if side == 0 and cell.x < ball_cell.x:
			return false
		if side == 1 and cell.x > ball_cell.x:
			return false
	if side_state.cost < operator_data.deploy_cost or side_state.cooldowns.get(operator_data.operator_id, 0) > 0:
		return false
	for unit in units:
		if unit.cell == cell:
			return false
		if unit.side == side and unit.operator_id == operator_data.operator_id:
			return false
	return true
