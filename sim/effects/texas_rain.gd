class_name TexasRain
extends RefCounted

var source_id: int = -1
var side: int = 0
var source_cell := Vector2i.ZERO
var facing: int = 0
var attack: int = 0
var due_tick: int = 0
var stun_ticks: int = 0
var target_ids := PackedInt32Array()
var box_ids := PackedInt32Array()
var ball_cell := Vector2i(-1,-1)
var goal_generation: int = 0
