class_name TacticalRules
extends RefCounted


static func advance_boxes(state: MatchState) -> void:
	if state.result == state.RESULT_RUNNING and state.tick >= state.next_box_spawn_tick - state.CONFIG.BOX_WARNING_TICKS:
		if state.box_warning_cell.x < 0:
			var left: Array[Vector2i] = []
			var right: Array[Vector2i] = []
			for row in state.CONFIG.GRID_ROWS:
				for column in state.CONFIG.GRID_COLUMNS:
					var cell := Vector2i(column, row)
					if box_cell_is_available(state, cell):
						if column < state.CONFIG.BALL_START_CELL.x: left.append(cell)
						else: right.append(cell)
			if not left.is_empty() or not right.is_empty():
				var half := 0 if right.is_empty() else 1
				if not left.is_empty() and not right.is_empty():
					var weights := box_half_weights(state)
					half = 0 if state.rng.next_u32() % (weights[0] + weights[1]) < weights[0] else 1
				var candidates: Array[Vector2i] = left if half == 0 else right
				state.box_warning_cell = candidates[state.rng.next_u32() % candidates.size()]
				state.next_box_spawn_tick = maxi(state.next_box_spawn_tick, state.tick + state.CONFIG.BOX_WARNING_TICKS)
		if state.box_warning_cell.x >= 0 and state.tick >= state.next_box_spawn_tick and box_cell_is_available(state, state.box_warning_cell):
			state.tactical_boxes.append(TacticalBox.new(state.next_box_id, state.box_warning_cell, state.CONFIG.BOX_REQUIRED_HITS))
			state.next_box_id += 1
			var half := 0 if state.box_warning_cell.x < state.CONFIG.BALL_START_CELL.x else 1
			state.box_spawn_counts_by_half[half] += 1
			state.box_same_half_streak = state.box_same_half_streak + 1 if state.box_last_spawn_half == half else 1
			state.box_last_spawn_half = half
			state.box_warning_cell = Vector2i(-1, -1)
			var interval_steps := (state.CONFIG.BOX_INTERVAL_MAX_TICKS - state.CONFIG.BOX_INTERVAL_MIN_TICKS) / state.CONFIG.TICK_RATE + 1
			state.next_box_spawn_tick = state.tick + state.CONFIG.BOX_INTERVAL_MIN_TICKS + (state.rng.next_u32() % interval_steps) * state.CONFIG.TICK_RATE


# Indices are fixed world halves (left/right), not player sides.
static func box_half_weights(state: MatchState) -> PackedInt32Array:
	var most := maxi(state.box_spawn_counts_by_half[0], state.box_spawn_counts_by_half[1])
	var weights := PackedInt32Array()
	for half in 2:
		var weight := state.CONFIG.BOX_HALF_BASE_WEIGHT + (most - state.box_spawn_counts_by_half[half]) * state.CONFIG.BOX_HALF_DEFICIT_WEIGHT
		if half == state.box_last_spawn_half: weight = maxi(1, weight / (state.box_same_half_streak + 1))
		weights.append(weight)
	return weights


static func box_cell_is_available(state: MatchState, cell: Vector2i) -> bool:
	if state.item_reserves_cell(cell):
		return false
	if cell.x == state.CONFIG.BALL_START_CELL.x or state.terrain_at(cell) != "ground" or cell == state.ball.cell:
		return false
	if state.ball.move_ticks_left > 0 and cell == state.ball.cell + state.ball.move_direction:
		return false
	for unit in state.units:
		if unit.cell == cell:
			return false
	for box in state.tactical_boxes:
		if box.cell == cell:
			return false
	return true


static func advance_effects(state: MatchState) -> void:
	var retained: Array[TacticalItemEffect] = []
	for effect in state.tactical_item_effects:
		if effect.item_kind == state.CONFIG.TACTICAL_ITEM_SUPPORT_DRONE:
			if state.tick < effect.placed_tick + state.CONFIG.ITEM_SUPPORT_DRONE_TICKS:
				retained.append(effect)
			continue
		if not effect.activated and state.tick >= effect.effect_tick:
			effect.activated = true
			for unit in state.units:
				var offset := unit.cell - effect.cell
				if state._operator_data[unit.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"] or unit.operator_id == "weedy_cannon" or unit.chen_slashes_left>0 or unit.side == effect.side or unit.hp <= 0 or absi(offset.x) + absi(offset.y) != 1:
					continue
				var duration: int = state.CONFIG.ITEM_STUN_TICKS
				if StatusRules.has_resistance(state,unit):
					duration=duration*state.CONFIG.STATUS_RESISTANCE_DURATION_PERCENT/100
				if not LeeRules.before_control(state,unit,"stun"):unit.stun_ticks_left = duration
		if state.tick < effect.effect_tick + state.CONFIG.ITEM_FEEDBACK_TICKS:
			retained.append(effect)
	state.tactical_item_effects = retained


static func strike_box(state: MatchState, unit: UnitState, box_target: TacticalBox) -> void:
	unit.last_attack_tick = state.tick
	unit.last_attack_is_heal = false
	unit.last_attack_target_x = box_target.cell.x
	unit.last_attack_target_y = box_target.cell.y
	box_target.hits_left -= 1
	if box_target.hits_left == 0:
		var item_pool: Array[int] = [state.CONFIG.TACTICAL_ITEM_CRANE, state.CONFIG.TACTICAL_ITEM_STUN, state.CONFIG.TACTICAL_ITEM_SUPPORT_DRONE]
		if state.platform_drop_count < state.CONFIG.PLATFORM_DROP_LIMIT:
			item_pool.append(state.CONFIG.TACTICAL_ITEM_PLATFORM)
		var item_kind := item_pool[state.rng.next_u32() % item_pool.size()]
		state.sides[unit.side].tactical_items[item_kind] += 1
		if item_kind == state.CONFIG.TACTICAL_ITEM_PLATFORM:
			state.platform_drop_count += 1
		state.tactical_boxes.erase(box_target)


static func use_item(state: MatchState, side: int, command: InputCommand) -> void:
	state.sides[side].tactical_items[command.item_kind] -= 1
	state.tactical_item_effects.append(TacticalItemEffect.new(command.item_kind, side, command.cell, command.facing, state.tick))
	if command.item_kind == state.CONFIG.TACTICAL_ITEM_CRANE:
		var retreat_target := state._crane_target(side, command.cell, command.facing)
		state._retreat_unit(retreat_target)
		state.sides[side].cooldowns[retreat_target.operator_id] = state.CONFIG.ITEM_CRANE_REDEPLOY_TICKS
	elif command.item_kind == state.CONFIG.TACTICAL_ITEM_PLATFORM:
		state.platform_cells.append(command.cell)
	elif command.item_kind == state.CONFIG.TACTICAL_ITEM_SUPPORT_DRONE:
		for unit in state.units.duplicate():
			if unit.hp <= 0 or unit.side == side or state._operator_data[unit.operator_id].profession_id != "summon" or not support_covers(command.cell, unit.cell): continue
			if unit.operator_id == "flowing_shape": TacticianRules.clear_steal(state, unit)
			state._retreat_unit(unit)
			# Flowing Shape normally returns to a point; forced withdrawal removes it too.
			if unit in state.units: state.units.erase(unit)
		AuraRules.refresh(state)


static func support_covers(origin: Vector2i, cell: Vector2i) -> bool:
	var offset := cell - origin
	return absi(offset.x) + absi(offset.y) <= 2


static func refresh_support(state: MatchState) -> void:
	for unit in state.units:
		var friendly := false
		var hostile := false
		for effect in state.tactical_item_effects:
			if effect.item_kind != state.CONFIG.TACTICAL_ITEM_SUPPORT_DRONE or not support_covers(effect.cell, unit.cell): continue
			if effect.side == unit.side: friendly = true
			else: hostile = true
		# Overlapping friendly drones do not multiply; opposing fields cancel.
		var percent := 100 + (state.CONFIG.ITEM_SUPPORT_SPEED_PERCENT if friendly else 0) - (state.CONFIG.ITEM_SUPPORT_SPEED_PERCENT if hostile else 0)
		unit.attack_speed_remaining_percent = roundi(unit.attack_speed_remaining_percent * percent / 100.0)
