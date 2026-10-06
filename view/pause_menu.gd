extends Control

signal pause_requested
signal resume_requested
signal home_requested

const PALETTE := preload("res://view/palette.gd")

var menu_open := false
var _consume_release := false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _consume_release:
			_consume_release = false
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			if menu_open and _home_rect().has_point(event.position):
				get_viewport().set_input_as_handled()
				home_requested.emit()
				return
			if (menu_open and _resume_rect().has_point(event.position)) or _pause_rect().has_point(event.position):
				_consume_release = true
				menu_open = not menu_open
				queue_redraw()
				get_viewport().set_input_as_handled()
				if menu_open:
					pause_requested.emit()
				else:
					resume_requested.emit()
				return
	if menu_open:
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var pointer := get_local_mouse_position()
	var pause := _pause_rect()
	if menu_open:
		draw_rect(Rect2(Vector2.ZERO, size), Color(PALETTE.BACKGROUND, 0.82))
		var band := Rect2(Vector2(0, size.y * 0.5 - PALETTE.CELL_SIZE * 2.4), Vector2(size.x, PALETTE.CELL_SIZE * 4.8))
		draw_rect(band, Color(PALETTE.HUD_SURFACE, 0.96))
		draw_line(band.position, band.position + Vector2(size.x, 0), PALETTE.HUD_RULE, 1.0)
		draw_line(band.end - Vector2(size.x, 0), band.end, PALETTE.HUD_RULE, 1.0)
		var home := _home_rect()
		var resume := _resume_rect()
		for rect in [home, resume]:
			draw_rect(rect, PALETTE.HUD_HOVER if rect.has_point(pointer) else PALETTE.HUD_INSET)
			draw_rect(rect, PALETTE.ARROW if rect.has_point(pointer) else PALETTE.HUD_RULE, false, 1.0)
		var center := home.get_center()
		var icon_size := home.size.x * 0.22
		var door := PackedVector2Array([center + Vector2(-icon_size * 0.2, -icon_size), center + Vector2(icon_size, -icon_size), center + Vector2(icon_size, icon_size), center + Vector2(-icon_size * 0.2, icon_size)])
		draw_polyline(door, PALETTE.RED, 4.0, true)
		draw_line(center + Vector2(icon_size * 0.45, 0), center + Vector2(-icon_size, 0), PALETTE.RED, 4.0, true)
		draw_polyline(PackedVector2Array([center + Vector2(-icon_size * 0.5, -icon_size * 0.5), center + Vector2(-icon_size, 0), center + Vector2(-icon_size * 0.5, icon_size * 0.5)]), PALETTE.RED, 4.0, true)
		center = resume.get_center()
		icon_size = resume.size.x * 0.23
		draw_colored_polygon(PackedVector2Array([center + Vector2(-icon_size * 0.65, -icon_size), center + Vector2(icon_size, 0), center + Vector2(-icon_size * 0.65, icon_size)]), PALETTE.BALL)
	draw_rect(pause, PALETTE.HUD_HOVER if pause.has_point(pointer) else PALETTE.HUD_SURFACE)
	draw_rect(pause, PALETTE.ARROW if menu_open else PALETTE.HUD_RULE, false, 1.0)
	var bar_size := Vector2(pause.size.x * 0.14, pause.size.y * 0.44)
	for direction in [-1, 1]:
		var center := pause.get_center() + Vector2(direction * pause.size.x * 0.14, 0)
		draw_rect(Rect2(center - bar_size * 0.5, bar_size), PALETTE.BALL)


func _pause_rect() -> Rect2:
	return Rect2(Vector2(size.x - PALETTE.CELL_SIZE * 1.7, PALETTE.CELL_SIZE * 0.35), Vector2.ONE * PALETTE.CELL_SIZE * 1.2)


func _home_rect() -> Rect2:
	return Rect2(size * 0.5 + Vector2(-PALETTE.CELL_SIZE * 4.5, -PALETTE.CELL_SIZE * 1.5), Vector2.ONE * PALETTE.CELL_SIZE * 3.0)


func _resume_rect() -> Rect2:
	return Rect2(size * 0.5 + Vector2(PALETTE.CELL_SIZE * 1.5, -PALETTE.CELL_SIZE * 1.5), Vector2.ONE * PALETTE.CELL_SIZE * 3.0)
