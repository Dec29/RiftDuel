class_name BoardProjection
extends RefCounted

const CONFIG := preload("res://data/config.gd")
const PALETTE := preload("res://view/palette.gd")

# Shared state reference; terrain is read live, never copied.
var state: MatchState
var mirrored := false


func screen_to_cell(position: Vector2) -> Vector2i:
	# Raised top surfaces take precedence over the floor they visually cover.
	for row in range(CONFIG.GRID_ROWS - 1, -1, -1):
		for column in range(CONFIG.GRID_COLUMNS - 1, -1, -1):
			var cell := Vector2i(column, row)
			if state.terrain_at(cell) == "high" and Geometry2D.is_point_in_polygon(position, cell_polygon(cell)):
				return cell
	var local := board_unproject(position)
	if mirrored:
		local.x = CONFIG.GRID_COLUMNS - local.x
	var cell := Vector2i(floori(local.x), floori(local.y))
	if not cell_is_inside(cell) or state.terrain_at(cell) == "high":
		return Vector2i(-1, -1)
	return cell


func cell_is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < CONFIG.GRID_COLUMNS and cell.y >= 0 and cell.y < CONFIG.GRID_ROWS


func board_point(point: Vector2) -> Vector2:
	var display := Vector2(CONFIG.GRID_COLUMNS - point.x, point.y) if mirrored else point
	var depth := display.y / CONFIG.GRID_ROWS
	var scale := PALETTE.BOARD_FAR_SCALE / (1.0 - (1.0 - PALETTE.BOARD_FAR_SCALE) * depth)
	var x := (display.x / CONFIG.GRID_COLUMNS - 0.5) * PALETTE.BOARD_PROJECTED_WIDTH * scale
	return PALETTE.BOARD_PROJECTED_ORIGIN + Vector2(PALETTE.BOARD_PROJECTED_WIDTH * 0.5 + x, PALETTE.BOARD_PROJECTED_HEIGHT * depth * scale)


func board_unproject(position: Vector2) -> Vector2:
	var local := position - PALETTE.BOARD_PROJECTED_ORIGIN
	var screen_depth := local.y / PALETTE.BOARD_PROJECTED_HEIGHT
	var depth := screen_depth / (PALETTE.BOARD_FAR_SCALE + (1.0 - PALETTE.BOARD_FAR_SCALE) * screen_depth)
	var scale := PALETTE.BOARD_FAR_SCALE / (1.0 - (1.0 - PALETTE.BOARD_FAR_SCALE) * depth)
	return Vector2((0.5 + (local.x - PALETTE.BOARD_PROJECTED_WIDTH * 0.5) / (PALETTE.BOARD_PROJECTED_WIDTH * scale)) * CONFIG.GRID_COLUMNS, depth * CONFIG.GRID_ROWS)


func cell_polygon(cell: Vector2i, inset: float = 0.0, raised: bool = true) -> PackedVector2Array:
	var height := PALETTE.PLATFORM_HEIGHT if raised and state.terrain_at(cell) == "high" else 0.0
	var points := PackedVector2Array()
	for corner in [Vector2(inset, inset), Vector2(1.0 - inset, inset), Vector2(1.0 - inset, 1.0 - inset), Vector2(inset, 1.0 - inset)]:
		points.append(board_point(Vector2(cell) + corner) - Vector2(0, height))
	return points


func closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed


func cell_rect(cell: Vector2i, raised: bool = true) -> Rect2:
	var center := board_point(Vector2(cell) + Vector2.ONE * 0.5)
	if raised and state.terrain_at(cell) == "high":
		center.y -= PALETTE.PLATFORM_HEIGHT
	# Upright icons/labels use this anchor; ground and range use the polygon.
	return Rect2(center - Vector2.ONE * PALETTE.CELL_SIZE * PALETTE.BOARD_ZOOM * 0.5, Vector2.ONE * PALETTE.CELL_SIZE * PALETTE.BOARD_ZOOM)


func view_direction(direction: Vector2, cell: Vector2i = CONFIG.BALL_START_CELL) -> Vector2:
	var anchor := Vector2(cell) + Vector2.ONE * 0.5
	return (board_point(anchor + direction) - board_point(anchor)) / PALETTE.CELL_SIZE


func board_direction(direction: Vector2, cell: Vector2i = CONFIG.BALL_START_CELL) -> Vector2:
	var anchor := Vector2(cell) + Vector2.ONE * 0.5
	var logical := board_unproject(board_point(anchor) + direction)
	if mirrored:
		logical.x = CONFIG.GRID_COLUMNS - logical.x
	return (logical - anchor) * PALETTE.CELL_SIZE


func goal_line(side: int) -> PackedVector2Array:
	var column := 0 if side == 1 else CONFIG.GRID_COLUMNS
	return PackedVector2Array([board_point(Vector2(column, 0)), board_point(Vector2(column, CONFIG.GRID_ROWS))])
