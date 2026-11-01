class_name DisplacementRules
extends RefCounted

const CONFIG := preload("res://data/config.gd")


static func weight(operator: OperatorData) -> int:
	var base_weight: int = CONFIG.UNIT_WEIGHT_BY_PROFESSION[operator.profession_id]
	var reduction: int = CONFIG.UNIT_WEIGHT_REDUCTION_BY_TRAIT[operator.branch_trait.effect_type] if CONFIG.UNIT_WEIGHT_REDUCTION_BY_TRAIT.has(operator.branch_trait.effect_type) else 0
	return maxi(0, base_weight - reduction)


static func effective_weight(state: MatchState, unit: UnitState) -> int:
	var reduction := 0
	for source in state.units:
		if source.hp <= 0 or source.side == unit.side or SkillRules.active_ticks(source) <= 0:
			continue
		var operator: OperatorData = state._operator_data[source.operator_id]
		var skill := operator.skills[source.skill_index]
		if skill.effect_type == "weightless_multi_target":
			reduction = maxi(reduction, int(skill.effect_params["weight_reduction"]))
	return maxi(0, weight(state._operator_data[unit.operator_id]) - reduction)


static func direction(source: UnitState, target_cell: Vector2i, mode: String) -> Vector2i:
	var offset := target_cell - source.cell
	var result := Vector2i(signi(offset.x), signi(offset.y))
	if result == Vector2i.ZERO:
		result = AttackRange.rotate_offset(Vector2i.RIGHT, source.facing)
	return -result if mode == "pull" else result


static func apply_unit(state: MatchState, source: UnitState, target: UnitState, direction: Vector2i, force: int) -> int:
	if target.titi_doze_owner_id>=0:return 0
	# Membership only grows: a blocker encountered on the planned path remains
	# part of the rigid group when its added weight shortens that path.
	if target.flow_point_until_tick>0:return 0
	if state._operator_data[target.operator_id].branch_trait.effect_type in ["stainless_device_1","stainless_device_2","stainless_device_3","silence_drone","pozyomka_typewriter","curse_doll","medical_drone","seaborn","water_cannon"] or target.chen_slashes_left>0 or target.hp <= 0 or target.displacement_ticks_left > 0 or state.terrain_at(target.cell) != "ground":
		return 0
	var group: Array[UnitState] = [target]
	var distance := 0
	var expanded := true
	while expanded:
		expanded = false
		var total_weight := 0
		for member in group:
			total_weight += effective_weight(state, member)
		distance = maxi(0, force - total_weight)
		var permitted := 0
		for step in distance:
			var blocked := false
			var additions: Array[UnitState] = []
			for member in group:
				var cell := member.cell + direction * (step + 1)
				if _blocked_cell(state, cell):
					blocked = true
					break
				if direction.x != 0 and direction.y != 0 and (_blocked_cell(state, cell - Vector2i(direction.x, 0)) or _blocked_cell(state, cell - Vector2i(0, direction.y))):
					blocked = true
					break
				for other in state.units:
					if other.hp > 0 and other.cell == cell and other not in group:
						if other.flow_point_until_tick>0 or state._operator_data[other.operator_id].branch_trait.effect_type in ["stainless_device_1","stainless_device_2","stainless_device_3","silence_drone","pozyomka_typewriter","curse_doll","medical_drone","seaborn","water_cannon"] or other.chen_slashes_left>0 or other == source or other.displacement_ticks_left > 0 or state.terrain_at(other.cell) != "ground":
							blocked = true
						elif other not in additions:
							additions.append(other)
			if blocked:
				break
			if not additions.is_empty():
				group.append_array(additions)
				group.sort_custom(func(a: UnitState, b: UnitState) -> bool: return a.unit_id < b.unit_id)
				expanded = true
				break
			permitted += 1
		if not expanded:
			distance = permitted
	# A whole group stops before the line; shortening can put another member
	# on it, so recheck until every endpoint is legal.
	while distance > 0:
		var on_line := false
		for member in group:
			if member.cell.x + direction.x * distance == CONFIG.BALL_START_CELL.x:
				on_line = true
		if not on_line:
			break
		distance -= 1
	if distance == 0:
		return 0
	for member in group:
		member.displacement_origin = member.cell
		member.cell += direction * distance
		member.displacement_duration_ticks = distance * CONFIG.UNIT_DISPLACEMENT_TICKS_PER_CELL
		member.displacement_ticks_left = member.displacement_duration_ticks
		if member.attack_intent!=null:StatusRules.interrupt_basic(state,member)
	Mon3trRules.refresh_range(state)
	for step in distance:
		for member in group:
			if member.hp > 0:
				MerchantRules.trigger_bombs_at(state, member,member.displacement_origin + direction * (step + 1))
				PusherRules.apply_rupture_damage(state, member)
	return distance


static func apply_ball(state: MatchState, direction: Vector2i, force: int) -> int:
	if state.ball.move_ticks_left > 0:
		return 0
	var distance := maxi(0, force - state._ball_data.weight)
	if distance == 0:
		return 0
	state.ball.accum = Vector2i.ZERO
	state.ball.move_direction = direction
	state.ball.move_ticks_left = CONFIG.BALL_MOVE_TICKS
	state.ball.displacement_steps_left = distance
	return distance


static func _blocked_cell(state: MatchState, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= CONFIG.GRID_COLUMNS or cell.y < 0 or cell.y >= CONFIG.GRID_ROWS:
		return true
	return state.terrain_at(cell) not in ["ground", "ground_no_deploy"] or state.box_reserves_cell(cell) or state.item_reserves_cell(cell)
