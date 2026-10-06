extends Control

const PALETTE := preload("res://view/palette.gd")


func _ready() -> void:
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
		var error := get_tree().change_scene_to_file("res://main.tscn")
		assert(error == OK, "Cannot open single-player battle: " + error_string(error))
	)
	$Menu/SinglePlayer.grab_focus()
	$Menu/Multiplayer.pressed.connect(func() -> void:
		var error := get_tree().change_scene_to_file("res://lobby.tscn")
		assert(error == OK, "Cannot open multiplayer lobby")
	)
	$Menu/Settings.pressed.connect(func() -> void:
		var error := get_tree().change_scene_to_file("res://view/settings_menu.tscn")
		assert(error == OK, "Cannot open settings")
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PALETTE.BACKGROUND)
	var center_x := size.x * 0.5
	var mark_center := Vector2(center_x, size.y * 0.14)
	var mark_size := float(PALETTE.CELL_SIZE)
	for offset in [-0.22, 0.22]:
		var start := mark_center + Vector2(mark_size * (offset - 0.18), mark_size * 0.28)
		draw_line(start, start + Vector2(mark_size * 0.36, -mark_size * 0.56), PALETTE.BLUE, 3.0, true)
	draw_line(Vector2(center_x - 190, size.y * 0.375), Vector2(center_x + 190, size.y * 0.375), PALETTE.GRID, 1.0)
	draw_line(Vector2(center_x - 38, size.y * 0.375), Vector2(center_x + 38, size.y * 0.375), PALETTE.ARROW, 2.0)
