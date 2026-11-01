class_name ArchettoVolley
extends RefCounted

var source_id: int = -1
var side: int = 0
var source_cell := Vector2i.ZERO
var facing: int = 0
var target_kind: int = 0
var target_id: int = -1
var cell := Vector2i.ZERO
var attack: int = 0
var shots_left: int = 5
var segment_shots: int = 5
var total_shots: int = 0
var next_tick: int = 0
var start_tick: int = 0
var goal_generation: int = 0
var visited_ids := PackedInt32Array()
