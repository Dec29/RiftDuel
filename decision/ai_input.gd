class_name AIInput
extends RefCounted

const CONFIG := preload("res://data/config.gd")
const ATTACK_RANGE := preload("res://sim/attack_range.gd")
const ROW_ORDER := [5, 4, 6, 3, 7, 2, 8, 1, 9]

var side: int
var _operator_data: Dictionary
var _operator_ids: PackedStringArray
var _next_decision_tick := CONFIG.AI_DECISION_INTERVAL_TICKS
var _skill_ready_at: Dictionary = {}


func _init(ai_side: int, operator_data: Dictionary) -> void:
	side = ai_side
	_operator_data = operator_data.duplicate()
	_operator_data["vigil_wolf"]=MatchState.VIGIL_WOLF_DATA
	_operator_data["pozyomka_typewriter"]=MatchState.TYPEWRITER_DATA
	_operator_data["silence_alter_drone"]=MatchState.SILENCE_DRONE_DATA
	_operator_data["curse_doll"]=MatchState.CURSE_DOLL_DATA
	_operator_data["medical_drone"]=MatchState.MEDICAL_DRONE_DATA
	_operator_data["seaborn"]=MatchState.SEABORN_DATA
	_operator_data["mon3tr"]=MatchState.MON3TR_DATA
	_operator_data["weedy_cannon"] = MatchState.CANNON_DATA
	for id in MatchState.DRONE_IDS:_operator_data[id]=MatchState.DRONE_DATA[id]
	_operator_data["phantom_clone"] = MatchState.CLONE_DATA
	_operator_data["nightingale_phantom"] = MatchState.PHANTOM_DATA
	_operator_ids = PackedStringArray(operator_data.keys())
	_operator_ids.sort()


func commands_for_tick(state: MatchState) -> Array[InputCommand]:
	var commands: Array[InputCommand] = []
	if state.result != MatchState.RESULT_RUNNING:
		return commands
	if state.recovery_side >= 0:
		if state.recovery_side != side: return commands
		var columns: Array[int] = []
		for column in state.CONFIG.GRID_COLUMNS: columns.append(column)
		columns.sort_custom(func(a: int, b: int) -> bool:
			var left := absi(a-state.ball.cell.x)
			var right := absi(b-state.ball.cell.x)
			return (a > b if side == 0 else a < b) if left == right else left < right
		)
		for id in _operator_ids:
			for column in columns:
				for row in ROW_ORDER:
					var cell := Vector2i(column, row)
					if state.can_deploy(side, id, cell): return [InputCommand.new(state.input_tick, InputCommand.Kind.RECOVERY_DEPLOY, id, -1, cell)]
		return [InputCommand.new(state.input_tick, InputCommand.Kind.SKIP_RECOVERY)]
	var ready_ids: Array[int] = []
	for unit in state.units:
		if unit.side == side:
			var operator := _operator_data[unit.operator_id] as OperatorData
			if not (unit.skill_ticks_left != 0 and operator.skills[unit.skill_index].effect_type in ["silence_protocol", "marked_arrow_rain", "fortress_ammo", "fortress_overload", "lumen_lamp"]) and SkillRules.can_manually_activate(unit, operator.skills[unit.skill_index]):
				ready_ids.append(unit.unit_id)
				if not _skill_ready_at.has(unit.unit_id):
					_skill_ready_at[unit.unit_id] = state.tick + CONFIG.AI_SKILL_REACTION_TICKS
				if state.tick >= _skill_ready_at[unit.unit_id]:
					commands.append(InputCommand.new(state.input_tick, InputCommand.Kind.SKILL, "", unit.unit_id, Vector2i.ZERO, unit.skill_index))
					_skill_ready_at.erase(unit.unit_id)
	for id in _skill_ready_at.keys():
		if id not in ready_ids:
			_skill_ready_at.erase(id)
	if state.tick < _next_decision_tick:
		return commands
	_next_decision_tick = state.tick + CONFIG.AI_DECISION_INTERVAL_TICKS
	if state.sides[side].tactical_items[CONFIG.TACTICAL_ITEM_SUPPORT_DRONE] > 0:
		for ally in state.units:
			if ally.side == side and ally.hp > 0 and state.can_use_item(side, CONFIG.TACTICAL_ITEM_SUPPORT_DRONE, ally.cell):
				commands.append(InputCommand.new(state.input_tick, InputCommand.Kind.USE_ITEM, "", -1, ally.cell, -1, -1, CONFIG.TACTICAL_ITEM_SUPPORT_DRONE))
				return commands
	if state.sides[side].tactical_items[CONFIG.TACTICAL_ITEM_STUN] > 0:
		for enemy in state.units:
			if not state.enemy_is_targetable(side,enemy) or enemy.stun_ticks_left > 0:
				continue
			for offset in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
				var cell: Vector2i = enemy.cell + offset
				if state.can_use_item(side, CONFIG.TACTICAL_ITEM_STUN, cell):
					commands.append(InputCommand.new(state.input_tick, InputCommand.Kind.USE_ITEM, "", -1, cell, -1, -1, CONFIG.TACTICAL_ITEM_STUN))
					return commands

	var first_column := state.ball.cell.x
	var column_end := CONFIG.GRID_COLUMNS if side == 0 else -1
	var column_step := 1 if side == 0 else -1
	for summon in [["vigil_wolf",VigilRules.available(state,side)],["pozyomka_typewriter",PozyomkaRules.available(state,side)],["silence_alter_drone",SilenceAlterRules.drone_available(state,side)]]:
		if not summon[1]:continue
		for column in range(first_column,column_end,column_step):
			for row in ROW_ORDER:
				var cell := Vector2i(column,row)
				if state.can_deploy(side,summon[0],cell):commands.append(InputCommand.new(state.input_tick,InputCommand.Kind.DEPLOY,summon[0],-1,cell));return commands
	if CurseDollRules.available(state,side):
		for column in range(first_column,column_end,column_step):
			for row in ROW_ORDER:
				var cell := Vector2i(column,row)
				if state.can_deploy(side,"curse_doll",cell):commands.append(InputCommand.new(state.input_tick,InputCommand.Kind.DEPLOY,"curse_doll",-1,cell));return commands
	if MedicalDroneRules.available(state,side):
		for ally in state.units:
			if ally.hp<=0 or ally.side!=side:continue
			for delta in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
				var cell: Vector2i=ally.cell+delta
				if state.can_deploy(side,"medical_drone",cell):
					commands.append(InputCommand.new(state.input_tick,InputCommand.Kind.DEPLOY,"medical_drone",-1,cell));return commands
	if state.drone_visible(side):
		var drone_id: String=MatchState.DRONE_IDS[DroneRules.owner(state,side).skill_index]
		if state.drone_available(side,drone_id):
			for column in range(first_column,column_end,column_step):
				for row in ROW_ORDER:
					var cell := Vector2i(column,row)
					if state.can_deploy(side,drone_id,cell):
						commands.append(InputCommand.new(state.input_tick,InputCommand.Kind.DEPLOY,drone_id,-1,cell))
						return commands
	if BardRules.available(state,side):
		for column in range(first_column,column_end,column_step):
			for row in ROW_ORDER:
				var cell := Vector2i(column,row)
				if state.can_deploy(side,"seaborn",cell):
					commands.append(InputCommand.new(state.input_tick,InputCommand.Kind.DEPLOY,"seaborn",-1,cell))
					return commands
	if Mon3trRules.available(state,side):
		for column in range(first_column,column_end,column_step):
			for row in ROW_ORDER:
				var cell := Vector2i(column,row)
				if state.can_deploy(side,"mon3tr",cell):
					commands.append(InputCommand.new(state.input_tick,InputCommand.Kind.DEPLOY,"mon3tr",-1,cell))
					return commands
	if state.cannon_available(side):
		for column in range(first_column, column_end, column_step):
			for row in ROW_ORDER:
				var cell := Vector2i(column,row)
				if state.can_deploy(side,"weedy_cannon",cell):
					commands.append(InputCommand.new(state.input_tick,InputCommand.Kind.DEPLOY,"weedy_cannon",-1,cell))
					return commands
	if state.clone_available(side):
		for column in range(first_column, column_end, column_step):
			for row in ROW_ORDER:
				var cell := Vector2i(column, row)
				if state.clone_can_deploy(side, cell):
					commands.append(InputCommand.new(state.input_tick, InputCommand.Kind.DEPLOY, "phantom_clone", -1, cell))
					return commands
	for operator_id in _operator_ids:
		for column in range(first_column, column_end, column_step):
			for row in ROW_ORDER:
				var cell := Vector2i(column, row)
				if state.can_deploy(side, operator_id, cell):
					commands.append(InputCommand.new(
						state.input_tick,
						InputCommand.Kind.DEPLOY,
						operator_id,
						-1,
						cell,
					))
					return commands
	if state.sides[side].tactical_items[CONFIG.TACTICAL_ITEM_PLATFORM] > 0:
		var needs_high := false
		for operator_id in _operator_ids:
			var operator: OperatorData = _operator_data[operator_id]
			if operator.terrain_requirement != "high" or state.sides[side].cost < state.deploy_cost(side,operator_id) or state.sides[side].cooldowns.has(operator_id):
				continue
			var deployed := false
			for unit in state.units:
				if unit.side == side and unit.operator_id == operator_id:
					deployed = true
			needs_high = needs_high or not deployed
		if needs_high:
			for column in range(first_column, column_end, column_step):
				for row in ROW_ORDER:
					var cell := Vector2i(column, row)
					if state.can_use_item(side, CONFIG.TACTICAL_ITEM_PLATFORM, cell):
						commands.append(InputCommand.new(state.input_tick, InputCommand.Kind.USE_ITEM, "", -1, cell, -1, -1, CONFIG.TACTICAL_ITEM_PLATFORM))
						return commands
	# Reuse idle cards after the ball leaves their range, without choosing tactics.
	for unit in state.units:
		if unit.side != side:
			continue
		var operator := _operator_data[unit.operator_id] as OperatorData
		var has_target := false
		for offset in ATTACK_RANGE.effective_offsets(unit, operator):
			var cell := unit.cell + ATTACK_RANGE.rotate_offset(offset, unit.facing)
			if cell == state.ball.cell:
				has_target = true
			for box in state.tactical_boxes:
				if box.cell == cell:
					has_target = true
			for target in state.units:
				if target.side != side and target.cell == cell:
					has_target = true
		if not has_target:
			if state.sides[side].tactical_items[CONFIG.TACTICAL_ITEM_CRANE] > 0:
				for facing in 4:
					var cell := unit.cell - ATTACK_RANGE.rotate_offset(Vector2i.RIGHT, facing)
					if state.can_use_item(side, CONFIG.TACTICAL_ITEM_CRANE, cell, facing):
						commands.append(InputCommand.new(state.input_tick, InputCommand.Kind.USE_ITEM, "", -1, cell, -1, facing, CONFIG.TACTICAL_ITEM_CRANE))
						return commands
			commands.append(InputCommand.new(state.input_tick, InputCommand.Kind.RETREAT, "", unit.unit_id))
			return commands
	return commands
