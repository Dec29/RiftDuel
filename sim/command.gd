class_name InputCommand
extends RefCounted

enum Kind {
	DEPLOY,
	SKILL,
	RETREAT,
	USE_ITEM,
	COPY,
	SKIP_RECOVERY,
	RECOVERY_DEPLOY,
}

var tick: int
var kind: int
var operator_id: String
var unit_id: int
var cell: Vector2i
var skill_index: int
var facing: int
var item_kind: int


func _init(
	command_tick: int = 0,
	command_kind: int = Kind.DEPLOY,
	command_operator_id: String = "",
	command_unit_id: int = -1,
	command_cell: Vector2i = Vector2i.ZERO,
	command_skill_index: int = -1,
	command_facing: int = -1,
	command_item_kind: int = -1,
) -> void:
	tick = command_tick
	kind = command_kind
	operator_id = command_operator_id
	unit_id = command_unit_id
	cell = command_cell
	skill_index = command_skill_index
	facing = command_facing
	item_kind = command_item_kind
