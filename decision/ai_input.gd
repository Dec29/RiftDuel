class_name AIInput
extends RefCounted

const CONFIG := preload("res://data/config.gd")
const ARENA := preload("res://resources/map/standard_arena.tres")
const ATTACK_RANGE := preload("res://sim/attack_range.gd")
const ROSTER := [
	"swire_alter",
	"exusiai",
	"angelina",
	"ceobe",
	"bagpipe",
	"blaze",
	"hoshiguma",
	"nightingale",
]
const ROW_ORDER := [5, 4, 6, 3, 7, 2, 8, 1, 9]

var side: int
var _operator_data: Dictionary


func _init(ai_side: int, operator_data: Dictionary) -> void:
	side = ai_side
	_operator_data = operator_data


func commands_for_tick(state: MatchState) -> Array[InputCommand]:
	var commands: Array[InputCommand] = []
	if state.result != MatchState.RESULT_RUNNING:
		return commands
	for unit in state.units:
		if unit.side == side:
			var operator := _operator_data[unit.operator_id] as OperatorData
			if SkillRules.can_manually_activate(unit, operator.skills[0]):
				commands.append(InputCommand.new(state.tick, InputCommand.Kind.SKILL, "", unit.unit_id, Vector2i.ZERO, 0))

	var first_column := state.ball.cell.x
	var column_end := CONFIG.GRID_COLUMNS if side == 0 else -1
	var column_step := 1 if side == 0 else -1
	for operator_id in ROSTER:
		var operator := _operator_data[operator_id] as OperatorData
		for column in range(first_column, column_end, column_step):
			for row in ROW_ORDER:
				var cell := Vector2i(column, row)
				if DeployRules.is_legal(side, operator, cell, state.ball.cell, state.units, state.sides[side], ARENA):
					commands.append(InputCommand.new(
						state.tick,
						InputCommand.Kind.DEPLOY,
						operator_id,
						-1,
						cell,
					))
					return commands
	# Reuse idle cards after the ball leaves their range, without choosing tactics.
	for unit in state.units:
		if unit.side != side:
			continue
		var operator := _operator_data[unit.operator_id] as OperatorData
		var has_target := false
		for offset in operator.attack_range:
			var cell := unit.cell + ATTACK_RANGE.rotate_offset(offset, unit.facing)
			if cell == state.ball.cell:
				has_target = true
			for target in state.units:
				if target.side != side and target.cell == cell:
					has_target = true
		if not has_target:
			commands.append(InputCommand.new(state.tick, InputCommand.Kind.RETREAT, "", unit.unit_id))
			return commands
	return commands
