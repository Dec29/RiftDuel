class_name WExplosive
extends RefCounted

# 0=ground mine, 1=marked unit, 2=marked box, 3=marked ball, 4=detached last position.
var bomb_id: int
var source_id: int
var side: int
var kind: int
var target_id: int = -1
var cell: Vector2i
var source_cell: Vector2i
var placed_tick: int
var explode_tick: int = -1
var expire_tick: int = 0
var attack: int = 0
var stun_ticks: int
var facing: int
