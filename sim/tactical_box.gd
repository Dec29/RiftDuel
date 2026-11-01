class_name TacticalBox
extends RefCounted

var box_id: int
var cell: Vector2i
var hits_left: int


func _init(id: int, box_cell: Vector2i, required_hits: int) -> void:
	box_id = id
	cell = box_cell
	hits_left = required_hits
