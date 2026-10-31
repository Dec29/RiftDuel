class_name GoalRecoveryRules
extends RefCounted


static func begin(state: MatchState, side: int) -> void:
	var waiting := PackedStringArray()
	for id in state.squad_ids[side]:
		var deployed := false
		for unit in state.units:
			if unit.side == side and unit.operator_id == id:
				deployed = true
		if not deployed and state.sides[side].cooldowns.get(id, 0) > 0:
			waiting.append(id)
	# Stable ID tie-break keeps equal cooldowns independent of dictionary order.
	var ordered := Array(waiting)
	ordered.sort_custom(func(a: String, b: String) -> bool:
		var left := int(state.sides[side].cooldowns[a])
		var right := int(state.sides[side].cooldowns[b])
		return a < b if left == right else left > right
	)
	for index in mini(state.CONFIG.GOAL_RECOVERY_OPERATORS, ordered.size()):
		state.sides[side].cooldowns.erase(ordered[index])
	state.sides[side].cost = mini(state.CONFIG.COST_MAX, state.sides[side].cost + state.CONFIG.GOAL_RECOVERY_COST)
	if state.result != state.RESULT_RUNNING: return
	state.recovery_side = side
	state.recovery_ticks_left = state.CONFIG.GOAL_RECOVERY_INPUT_TICKS
	if not has_deployment(state):
		state.recovery_side = -1
		state.recovery_ticks_left = 0


static func has_deployment(state: MatchState) -> bool:
	for id in state.squad_ids[state.recovery_side]:
		for row in state.CONFIG.GRID_ROWS:
			for column in state.CONFIG.GRID_COLUMNS:
				if state.can_deploy(state.recovery_side, id, Vector2i(column, row)):
					return true
	return false


# Return at most one legal deployment. Other actions and the other side are frozen.
static func commands(state: MatchState, blue: Array[InputCommand], red: Array[InputCommand]) -> Array[InputCommand]:
	var selected: Array[InputCommand] = blue if state.recovery_side == 0 else red
	for command in selected:
		assert(command.tick == state.input_tick, "recovery command tick mismatch")
		if command.kind == InputCommand.Kind.SKIP_RECOVERY:
			state.recovery_side = -1
			state.recovery_ticks_left = 0
			break
		if command.kind == InputCommand.Kind.RECOVERY_DEPLOY and state.can_deploy(state.recovery_side, command.operator_id, command.cell):
			return [command]
	state.recovery_input_ticks += 1
	state.recovery_ticks_left = maxi(0, state.recovery_ticks_left - 1)
	if state.recovery_ticks_left == 0: state.recovery_side = -1
	return []
