class_name ChampagneBomb
extends RefCounted

var bomb_id: int
var source_id: int
var side: int
var cell: Vector2i
var placed_tick: int
var attack: int
var triggered_tick: int = -1


func _init(id: int, source: UnitState, position: Vector2i, tick: int, attack_value: int) -> void:
	bomb_id = id
	source_id = source.unit_id
	side = source.side
	cell = position
	placed_tick = tick
	attack = attack_value
