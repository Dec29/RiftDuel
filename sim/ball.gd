class_name BallState
extends RefCounted

const CONFIG := preload("res://data/config.gd")

var cell: Vector2i
var accum: Vector2i
var move_ticks_left: int
var move_direction: Vector2i
var displacement_steps_left: int = 0


func _init(start_cell: Vector2i = CONFIG.BALL_START_CELL) -> void:
	cell = start_cell
	accum = Vector2i.ZERO
	move_ticks_left = 0
	move_direction = Vector2i.ZERO


func add_push(origin_cell: Vector2i, damage: int, ball_data: BallData, fallback_direction: Vector2i = Vector2i.RIGHT) -> void:
	if move_ticks_left > 0:
		return

	var offset := cell - origin_cell
	var direction := Vector2i(signi(offset.x), signi(offset.y))
	if direction == Vector2i.ZERO:
		direction = fallback_direction
	accum += direction * (damage * ball_data.push_ratio)

	if accum.length_squared() < ball_data.kick_threshold * ball_data.kick_threshold:
		return

	if absi(accum.x) >= absi(accum.y):
		move_direction = Vector2i(signi(accum.x), 0)
	else:
		move_direction = Vector2i(0, signi(accum.y))
	accum = Vector2i.ZERO
	move_ticks_left = CONFIG.BALL_MOVE_TICKS


func advance_move(blocked: bool = false) -> void:
	if move_ticks_left == 0:
		return

	move_ticks_left -= 1
	if move_ticks_left > 0:
		return

	var target := cell + move_direction
	if not blocked and target.x >= 0 and target.x < CONFIG.GRID_COLUMNS and target.y >= 0 and target.y < CONFIG.GRID_ROWS:
		cell = target
		if displacement_steps_left > 0:
			displacement_steps_left -= 1
			if displacement_steps_left > 0:
				move_ticks_left = CONFIG.BALL_MOVE_TICKS
				return
	displacement_steps_left = 0
	move_direction = Vector2i.ZERO
