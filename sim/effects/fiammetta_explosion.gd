class_name FiammettaExplosion
extends RefCounted

var source_id: int
var side: int
var source_cell: Vector2i
var facing: int
var center_hundredths: Vector2i
var attack: int
var radius_hundredths: int
var due_tick: int


func _init(source: UnitState, center: Vector2i, power: int, radius: int, due: int) -> void:
	source_id=source.unit_id;side=source.side;source_cell=source.cell;facing=source.facing
	center_hundredths=center;attack=power;radius_hundredths=radius;due_tick=due
