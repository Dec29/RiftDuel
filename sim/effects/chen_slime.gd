class_name ChenSlime
extends RefCounted

var source_id: int
var side: int
var cells: Array[Vector2i]
var due_tick: int
var speed_remaining_percent: int
var defense_reduce: int


func _init(source: UnitState, offsets: Array[Vector2i], due: int, speed: int, defense: int) -> void:
	source_id=source.unit_id;side=source.side;due_tick=due
	speed_remaining_percent=speed;defense_reduce=defense
	for offset in offsets:cells.append(source.cell+AttackRange.rotate_offset(offset,source.facing))
