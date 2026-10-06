extends Control

const PALETTE := preload("res://view/palette.gd")
const PREFERENCES := preload("res://preferences.gd")

var preferences := PREFERENCES.new()


func _ready() -> void:
	var error := preferences.read()
	$Center/Panel/Status.text = error
	$Center/Panel/Tabs/Connection/Custom.button_pressed = preferences.use_custom_server
	$Center/Panel/Tabs/Connection/Endpoint.text = preferences.custom_endpoint
	$Center/Panel/Tabs/Connection/Endpoint.visible = preferences.use_custom_server
	$Center/Panel/Tabs/Display/Goal.select(0 if preferences.goal_position == "left" else 1)
	$Center/Panel/Tabs/Connection/Custom.toggled.connect(func(enabled: bool) -> void:
		$Center/Panel/Tabs/Connection/Endpoint.visible = enabled
	)
	$Center/Panel/Actions/Save.pressed.connect(_save)
	$Center/Panel/Actions/Cancel.pressed.connect(_back)
	$Center/Panel.item_rect_changed.connect(queue_redraw)
	var normal := StyleBoxFlat.new()
	normal.bg_color = PALETTE.HUD_INSET
	normal.border_color = PALETTE.HUD_RULE
	normal.set_border_width_all(1)
	normal.content_margin_left = PALETTE.HUD_PADDING * 0.6
	normal.content_margin_right = PALETTE.HUD_PADDING * 0.6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = PALETTE.HUD_HOVER
	hover.border_color = PALETTE.BLUE
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = PALETTE.ARROW
	focus.set_border_width_all(1)
	for button in find_children("*", "Button", true, false):
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("focus", focus)
		button.add_theme_color_override("font_color", PALETTE.TEXT)
		button.add_theme_color_override("font_hover_color", PALETTE.TEXT)
	for label in find_children("*", "Label", true, false):
		label.add_theme_color_override("font_color", PALETTE.TEXT)
	$Center/Panel/Status.add_theme_color_override("font_color", PALETTE.RED)
	$Center/Panel/Tabs/Connection/Default.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	$Center/Panel/Tabs/Display/Hint.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	for description in [$Center/Panel/Tabs/Connection/Default, $Center/Panel/Tabs/Display/Hint, $Center/Panel/Status]:
		description.add_theme_font_size_override("font_size", PALETTE.MENU_TEXT_SIZE)
		description.add_theme_constant_override("line_spacing", PALETTE.INFO_PARAGRAPH_GAP)
	for action in [$Center/Panel/Tabs/Display/Goal, $Center/Panel/Actions/Save, $Center/Panel/Actions/Cancel]:
		action.add_theme_font_size_override("font_size", PALETTE.HUD_TITLE_SIZE)
	var tab_panel := StyleBoxFlat.new()
	tab_panel.bg_color = PALETTE.HUD_INSET
	tab_panel.border_color = PALETTE.HUD_RULE
	tab_panel.set_border_width_all(1)
	tab_panel.set_content_margin_all(PALETTE.HUD_PADDING)
	var selected := StyleBoxFlat.new()
	selected.bg_color = PALETTE.HUD_SURFACE
	selected.border_color = PALETTE.BLUE
	selected.border_width_bottom = 2
	selected.content_margin_left = PALETTE.HUD_PADDING
	selected.content_margin_right = PALETTE.HUD_PADDING
	selected.content_margin_top = PALETTE.HUD_PADDING * 0.5
	selected.content_margin_bottom = PALETTE.HUD_PADDING * 0.5
	var unselected := selected.duplicate() as StyleBoxFlat
	unselected.border_width_bottom = 0
	var tab_hover := unselected.duplicate() as StyleBoxFlat
	tab_hover.bg_color = PALETTE.HUD_HOVER
	$Center/Panel/Tabs.add_theme_stylebox_override("panel", tab_panel)
	$Center/Panel/Tabs.add_theme_stylebox_override("tab_selected", selected)
	$Center/Panel/Tabs.add_theme_stylebox_override("tab_unselected", unselected)
	$Center/Panel/Tabs.add_theme_stylebox_override("tab_hovered", tab_hover)
	$Center/Panel/Tabs.add_theme_stylebox_override("tab_focus", focus)
	$Center/Panel/Tabs.add_theme_color_override("font_selected_color", PALETTE.TEXT)
	$Center/Panel/Tabs.add_theme_color_override("font_unselected_color", PALETTE.MUTED_TEXT)
	$Center/Panel/Tabs.add_theme_color_override("font_hovered_color", PALETTE.TEXT)
	$Center/Panel/Tabs.add_theme_font_size_override("font_size", PALETTE.HUD_TITLE_SIZE)
	var goal_popup := $Center/Panel/Tabs/Display/Goal.get_popup() as PopupMenu
	goal_popup.add_theme_stylebox_override("panel", tab_panel)
	goal_popup.add_theme_stylebox_override("hover", hover)
	goal_popup.add_theme_color_override("font_color", PALETTE.TEXT)
	goal_popup.add_theme_color_override("font_hover_color", PALETTE.TEXT)
	goal_popup.add_theme_font_size_override("font_size", PALETTE.HUD_TITLE_SIZE)
	var field := normal.duplicate() as StyleBoxFlat
	field.content_margin_left = PALETTE.HUD_PADDING * 0.6
	field.content_margin_right = PALETTE.HUD_PADDING * 0.6
	$Center/Panel/Tabs/Connection/Endpoint.add_theme_stylebox_override("normal", field)
	$Center/Panel/Tabs/Connection/Endpoint.add_theme_stylebox_override("focus", focus)
	$Center/Panel/Tabs/Connection/Endpoint.add_theme_color_override("font_color", PALETTE.TEXT)
	$Center/Panel/Tabs/Connection/Endpoint.add_theme_color_override("font_placeholder_color", PALETTE.MUTED_TEXT)
	$Center/Panel/Tabs/Connection/Endpoint.add_theme_font_size_override("font_size", PALETTE.MENU_TEXT_SIZE)
	$Center/Panel/Actions/Save.grab_focus()


func _save() -> void:
	preferences.use_custom_server = $Center/Panel/Tabs/Connection/Custom.button_pressed
	preferences.custom_endpoint = $Center/Panel/Tabs/Connection/Endpoint.text.strip_edges()
	preferences.goal_position = "left" if $Center/Panel/Tabs/Display/Goal.selected == 0 else "right"
	var error := preferences.write()
	$Center/Panel/Status.text = error
	if error.is_empty():
		_back()


func _back() -> void:
	var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
	assert(error == OK, "Cannot return from settings")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PALETTE.BACKGROUND)
	var panel: Rect2 = $Center/Panel.get_global_rect().grow(PALETTE.HUD_PADDING)
	draw_rect(panel, PALETTE.HUD_SURFACE)
	draw_rect(Rect2(panel.position, Vector2(3, panel.size.y)), PALETTE.BLUE)
