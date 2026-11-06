extends Control

const PALETTE := preload("res://view/palette.gd")

var _polyhedron_phase := 0.0
var _underline_phase := 0.0
var _polyhedron_vertices := PackedVector3Array()
var _polyhedron_edges: Array[Vector2i] = []


func _ready() -> void:
	_update_startup.call_deferred()
	if not get_tree().root.has_meta("display_preferences_applied"):
		var preferences = preload("res://preferences.gd").new()
		var display_error: String = preferences.read()
		if not display_error.is_empty():
			push_error(display_error)
			get_tree().quit(1)
			return
		DisplaySettings.apply(preferences,get_tree().root)
		get_tree().root.set_meta("display_preferences_applied",true)
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("qa") and not args.is_empty() and args[0] == "--qa-relay":
		var relay_driver = load("res://tools/relay_export_driver.gd").new()
		get_tree().root.add_child.call_deferred(relay_driver)
		relay_driver.call_deferred("start", args.slice(1))
		queue_free()
		return
	if OS.has_feature("qa") and not args.is_empty() and args[0] == "--qa-peer":
		var driver = load("res://tools/net_peer_driver.gd").new()
		get_tree().root.add_child.call_deferred(driver)
		driver.call_deferred("start", args.slice(1))
		queue_free()
		return
	_start_menu_audio.call_deferred()
	var squad := SquadConfig.new()
	var squad_error := squad.read(SquadConfig.FILE_PATH, true)
	if not squad_error.is_empty():
		push_error(squad_error)
		get_tree().quit(1)
		return
	if squad.operator_ids.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://view/squad_menu.tscn")
		return
	# Icosahedron topology is built once; only its presentation rotates.
	var golden_ratio := (1.0 + sqrt(5.0)) * 0.5
	for first in [-1.0, 1.0]:
		for second in [-golden_ratio, golden_ratio]:
			_polyhedron_vertices.append(Vector3(0.0, first, second))
			_polyhedron_vertices.append(Vector3(first, second, 0.0))
			_polyhedron_vertices.append(Vector3(second, 0.0, first))
	for first in _polyhedron_vertices.size():
		for second in range(first + 1, _polyhedron_vertices.size()):
			if is_equal_approx(_polyhedron_vertices[first].distance_squared_to(_polyhedron_vertices[second]), 4.0):
				_polyhedron_edges.append(Vector2i(first, second))
	for index in _polyhedron_vertices.size():
		_polyhedron_vertices[index] = _polyhedron_vertices[index].normalized()
	var normal := StyleBoxFlat.new()
	normal.bg_color = PALETTE.HUD_SURFACE
	normal.border_color = PALETTE.BLUE
	normal.set_border_width_all(1)
	normal.border_width_left = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = PALETTE.HUD_HOVER
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = PALETTE.HUD_INSET
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.border_color = PALETTE.HUD_RULE
	disabled.border_width_left = 1
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = PALETTE.ARROW
	focus.set_border_width_all(1)
	for button in $Menu.get_children():
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("disabled", disabled)
		button.add_theme_stylebox_override("focus", focus)
		button.add_theme_color_override("font_color", PALETTE.TEXT)
		button.add_theme_color_override("font_hover_color", PALETTE.TEXT)
		button.add_theme_color_override("font_pressed_color", PALETTE.TEXT)
		button.add_theme_color_override("font_disabled_color", PALETTE.HUD_DISABLED_TEXT)
	$Title.add_theme_color_override("font_color", PALETTE.BALL)
	$Subtitle.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	$Menu/SinglePlayer.pressed.connect(func() -> void:
		var error := get_tree().change_scene_to_file("res://solo_setup.tscn")
		assert(error == OK, "Cannot open single-player battle: " + error_string(error))
	)
	$Menu/SinglePlayer.grab_focus()
	$Menu/Squad.pressed.connect(func() -> void:
		var error := get_tree().change_scene_to_file("res://view/squad_menu.tscn")
		assert(error == OK, "Cannot open squad menu")
	)
	$Menu/Multiplayer.pressed.connect(func() -> void:
		var error := get_tree().change_scene_to_file("res://lobby.tscn")
		assert(error == OK, "Cannot open multiplayer lobby")
	)
	$Menu/Settings.pressed.connect(func() -> void:
		var error := get_tree().change_scene_to_file("res://view/settings_menu.tscn")
		assert(error == OK, "Cannot open settings")
	)


func _update_startup() -> void:
	if not is_inside_tree(): return
	var tree := get_tree()
	await tree.process_frame
	if not is_inside_tree(): return
	await tree.process_frame
	if not is_inside_tree(): return
	tree.root.get_node("ClientUpdates").startup()


func _process(delta: float) -> void:
	_polyhedron_phase = fposmod(_polyhedron_phase + delta * PALETTE.MENU_POLYHEDRON_SPEED, TAU)
	_underline_phase = fposmod(_underline_phase + delta * PALETTE.MENU_UNDERLINE_SPEED, TAU)
	queue_redraw()


func _start_menu_audio() -> void:
	# The headless QA host has no audio output; decoding is tested explicitly.
	if AudioServer.get_driver_name()!="Dummy":
		GameAudio.instance(get_tree()).start_menu()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PALETTE.BACKGROUND)
	var polyhedron_center := size * PALETTE.MENU_POLYHEDRON_CENTER
	var radius := minf(size.x * PALETTE.MENU_POLYHEDRON_RADIUS.x, size.y * PALETTE.MENU_POLYHEDRON_RADIUS.y)
	var rotation := Basis(Vector3.UP, _polyhedron_phase) * Basis(Vector3.RIGHT, 0.4 + sin(_polyhedron_phase) * 0.2) * Basis(Vector3.FORWARD, sin(_polyhedron_phase) * 0.12)
	var projected := PackedVector2Array()
	var depths := PackedFloat32Array()
	for vertex in _polyhedron_vertices:
		var rotated := rotation * vertex
		projected.append(polyhedron_center + Vector2(rotated.x, rotated.y) * radius)
		depths.append((rotated.z + 1.0) * 0.5)
	for edge in _polyhedron_edges:
		var start := projected[edge.x]
		var end := projected[edge.y]
		var direction := (end - start).normalized()
		# Near edge-on lines can be shorter than the two endpoint gaps.
		if start.distance_to(end) > PALETTE.MENU_POLYHEDRON_GAP * 2.0:
			var color := PALETTE.ARROW
			color.a = 0.14 + (depths[edge.x] + depths[edge.y]) * 0.16
			draw_line(start + direction * PALETTE.MENU_POLYHEDRON_GAP, end - direction * PALETTE.MENU_POLYHEDRON_GAP, color, 1.2, true)
	for index in projected.size():
		var color := PALETTE.ARROW
		color.a = 0.35 + depths[index] * 0.35
		draw_circle(projected[index], PALETTE.MENU_POLYHEDRON_POINT_RADIUS, color, true, -1.0, true)
	var center_x := size.x * 0.5
	var mark_center := Vector2(center_x, size.y * 0.14)
	var mark_size := float(PALETTE.CELL_SIZE)
	for offset in [-0.22, 0.22]:
		var start := mark_center + Vector2(mark_size * (offset - 0.18), mark_size * 0.28)
		draw_line(start, start + Vector2(mark_size * 0.36, -mark_size * 0.56), PALETTE.BLUE, 3.0, true)
	var underline_y := size.y * 0.375
	var half_width := minf(PALETTE.MENU_UNDERLINE_HALF_WIDTH, size.x * 0.4)
	var half_length := minf(PALETTE.MENU_UNDERLINE_HALF_LENGTH, half_width)
	var slide_center := center_x + sin(_underline_phase) * (half_width - half_length)
	draw_line(Vector2(center_x - half_width, underline_y), Vector2(center_x + half_width, underline_y), PALETTE.GRID, 1.0)
	draw_line(Vector2(slide_center - half_length, underline_y), Vector2(slide_center + half_length, underline_y), PALETTE.ARROW, 2.0)
