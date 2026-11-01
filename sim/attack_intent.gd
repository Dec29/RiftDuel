class_name AttackIntent
extends RefCounted
# Only locked identities and integer combat-clock data survive the windup.
enum TargetKind { UNIT, BOX, BALL, HEAL, CELL }
var kind: int
var target_ids := PackedInt32Array()
var object_id := -1
var cell := Vector2i(-1,-1)
var goal_generation := 0
var started_tick := 0
var release_tick := 0
var release_frame := 0
var interval_ticks := 0
var clip := ""
var source_frames := 0
var window_ticks := 0

var requires_primary := false

var shot_target_ids:=PackedInt32Array()
