class_name LocalInput
extends RefCounted

var side: int
var selected_operator_id: String
var selected_unit_id: int
var _pending_commands: Array[InputCommand]


func _init(player_side: int) -> void:
	side = player_side
	selected_operator_id = ""
	selected_unit_id = -1
	_pending_commands = []


func select_operator(operator_id: String) -> void:
	selected_operator_id = operator_id
	selected_unit_id = -1


func select_unit(unit_id: int) -> void:
	selected_operator_id = ""
	selected_unit_id = unit_id


func clear_selection() -> void:
	selected_operator_id = ""
	selected_unit_id = -1


func queue_deploy(command_tick: int, cell: Vector2i, facing: int = -1) -> void:
	_pending_commands.append(InputCommand.new(
		command_tick,
		InputCommand.Kind.DEPLOY,
		selected_operator_id,
		-1,
		cell,
		-1,
		facing,
	))
	clear_selection()


func queue_retreat(command_tick: int, unit_id: int) -> void:
	_pending_commands.append(InputCommand.new(
		command_tick,
		InputCommand.Kind.RETREAT,
		"",
		unit_id,
	))
	clear_selection()


func take_commands() -> Array[InputCommand]:
	var commands := _pending_commands
	_pending_commands = []
	return commands


func queue_skill(command_tick: int, unit_id: int) -> void:
	_pending_commands.append(InputCommand.new(command_tick, InputCommand.Kind.SKILL, "", unit_id, Vector2i.ZERO, 0))
