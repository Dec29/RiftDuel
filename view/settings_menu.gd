extends Control

const PALETTE := preload("res://view/palette.gd")
const PREFERENCES := preload("res://preferences.gd")

var preferences := PREFERENCES.new()
var _capture_action := ""
var _key_buttons := {}
var _window_resolutions: Array[Vector2i]=[]


func _ready() -> void:
	var error := preferences.read()
	$Center/Panel/Status.text = error
	_build_keys()
	$Center/Panel/Tabs/Connection/Custom.button_pressed = preferences.use_custom_server
	$Center/Panel/Tabs/Connection/Endpoint.text = preferences.custom_endpoint
	$Center/Panel/Tabs/Connection/Endpoint.visible = preferences.use_custom_server
	$Center/Panel/Tabs/Display/Goal.select(0 if preferences.goal_position == "left" else 1)
	$Center/Panel/Tabs/Display/WindowMode.select(PREFERENCES.WINDOW_MODES.find(preferences.window_mode))
	$Center/Panel/Tabs/Display/WindowMode.item_selected.connect(func(_index: int) -> void:_resolution_options())
	_resolution_options()
	for kind in ["Music","SFX","Voice"]:
		var slider: HSlider=get_node("Center/Panel/Tabs/Audio/"+kind)
		slider.value=preferences.get(kind.to_lower()+"_volume")
		var label: Label=get_node("Center/Panel/Tabs/Audio/"+kind+"Label")
		var title: String = {"Music":"音乐","SFX":"音效","Voice":"语音"}[kind]
		label.text="%s · %d%%"%[title,int(slider.value)]
		slider.value_changed.connect(func(value: float) -> void:
			label.text="%s · %d%%"%[title,int(value)]
			_audio_changed()
		)
	$Center/Panel/Tabs/Audio/VoiceSides.select(PREFERENCES.VOICE_SIDES.find(preferences.voice_sides))
	$Center/Panel/Tabs/Audio/VoiceSides.item_selected.connect(func(_index: int) -> void:_audio_changed())
	$Center/Panel/Tabs.tab_changed.connect(func(_index: int) -> void:_tab_actions())
	_tab_actions()
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
	for description in [$Center/Panel/Tabs/Connection/Default, $Center/Panel/Tabs/Display/Hint, $Center/Panel/Tabs/Display/ResolutionHint, $Center/Panel/Status]:
		description.add_theme_font_size_override("font_size", PALETTE.MENU_TEXT_SIZE)
		description.add_theme_constant_override("line_spacing", PALETTE.INFO_PARAGRAPH_GAP)
	for action in [$Center/Panel/Tabs/Display/Goal, $Center/Panel/Tabs/Display/WindowMode, $Center/Panel/Tabs/Display/Resolution, $Center/Panel/Tabs/Audio/VoiceSides, $Center/Panel/Actions/Save, $Center/Panel/Actions/Cancel]:
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
	for choice in [$Center/Panel/Tabs/Display/Goal,$Center/Panel/Tabs/Display/WindowMode,$Center/Panel/Tabs/Display/Resolution,$Center/Panel/Tabs/Audio/VoiceSides]:
		var popup: PopupMenu=choice.get_popup()
		popup.add_theme_stylebox_override("panel", tab_panel)
		popup.add_theme_stylebox_override("hover", hover)
		popup.add_theme_color_override("font_color", PALETTE.TEXT)
		popup.add_theme_color_override("font_hover_color", PALETTE.TEXT)
		popup.add_theme_font_size_override("font_size", PALETTE.HUD_TITLE_SIZE)
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
	preferences.window_mode=PREFERENCES.WINDOW_MODES[$Center/Panel/Tabs/Display/WindowMode.selected]
	if preferences.window_mode=="windowed":preferences.window_resolution=_window_resolutions[$Center/Panel/Tabs/Display/Resolution.selected]
	preferences.music_volume=roundi($Center/Panel/Tabs/Audio/Music.value)
	preferences.sfx_volume=roundi($Center/Panel/Tabs/Audio/SFX.value)
	preferences.voice_volume=roundi($Center/Panel/Tabs/Audio/Voice.value)
	preferences.voice_sides=PREFERENCES.VOICE_SIDES[$Center/Panel/Tabs/Audio/VoiceSides.selected]
	var error := preferences.write()
	$Center/Panel/Status.text = error
	if error.is_empty():
		DisplaySettings.apply(preferences,get_tree().root)
		GameAudio.instance(get_tree()).apply_preferences(preferences)
		_back()


func _audio_changed() -> void:
	# Persist audio against saved settings; connection/display/key drafts stay local.
	var live := PREFERENCES.new()
	var error: String=live.read()
	if error.is_empty():
		live.music_volume=roundi($Center/Panel/Tabs/Audio/Music.value)
		live.sfx_volume=roundi($Center/Panel/Tabs/Audio/SFX.value)
		live.voice_volume=roundi($Center/Panel/Tabs/Audio/Voice.value)
		live.voice_sides=PREFERENCES.VOICE_SIDES[$Center/Panel/Tabs/Audio/VoiceSides.selected]
		error=live.write()
	$Center/Panel/Status.text=error
	if error.is_empty():GameAudio.instance(get_tree()).apply_preferences(live)


func _tab_actions() -> void:
	_capture_action=""
	_refresh_keys()
	var audio_tab: bool=$Center/Panel/Tabs.current_tab==2
	$Center/Panel/Actions/Save.visible=not audio_tab
	$Center/Panel/Actions/Cancel.text="返回" if audio_tab else "取消"


func _resolution_options() -> void:
	var options: OptionButton=$Center/Panel/Tabs/Display/Resolution
	if not options.disabled and options.item_count>0:
		preferences.window_resolution=_window_resolutions[options.selected]
	options.clear()
	options.disabled=$Center/Panel/Tabs/Display/WindowMode.selected!=0
	if options.disabled:
		var size := DisplayServer.screen_get_size() if DisplayServer.get_name()!="headless" else preferences.window_resolution
		options.add_item("%d × %d（桌面）"%[size.x,size.y])
		$Center/Panel/Tabs/Display/ResolutionHint.text="全屏与无边框全屏使用当前桌面分辨率。"
	else:
		_window_resolutions=DisplaySettings.window_resolutions()
		if _window_resolutions.is_empty():_window_resolutions.append(Vector2i(960,540))
		for size in _window_resolutions:options.add_item("%d × %d"%[size.x,size.y])
		options.select(_window_resolutions.find(DisplaySettings.fitting_resolution(preferences.window_resolution)))
		$Center/Panel/Tabs/Display/ResolutionHint.text="保存后生效；窗口尺寸按当前屏幕可用空间提供。"


func _back() -> void:
	var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
	assert(error == OK, "Cannot return from settings")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PALETTE.BACKGROUND)
	var panel: Rect2 = $Center/Panel.get_global_rect().grow(PALETTE.HUD_PADDING)
	draw_rect(panel, PALETTE.HUD_SURFACE)
	draw_rect(Rect2(panel.position, Vector2(3, panel.size.y)), PALETTE.BLUE)


func _build_keys() -> void:
	for action in Hotkeys.DEFAULT:
		var row := HBoxContainer.new()
		var title := Label.new()
		title.text=Hotkeys.LABELS[action];title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var button := Button.new()
		button.custom_minimum_size=Vector2(210,40)
		button.add_theme_font_size_override("font_size", PALETTE.MENU_TEXT_SIZE)
		button.pressed.connect(func() -> void:
			_capture_action=action
			_refresh_keys()
			$Center/Panel/Status.text="请按新快捷键；Esc取消录入。"
		)
		row.add_child(title);row.add_child(button)
		$Center/Panel/Tabs/Keys/Bindings.add_child(row)
		_key_buttons[action]=button
	$Center/Panel/Tabs/Keys/Reset.pressed.connect(func() -> void:
		_capture_action=""
		preferences.hotkeys=Hotkeys.DEFAULT.duplicate()
		_refresh_keys()
		$Center/Panel/Status.text="默认按键已恢复，保存后生效。"
	)
	_refresh_keys()


func _refresh_keys() -> void:
	for action in _key_buttons:
		_key_buttons[action].text="请按快捷键…" if _capture_action==action else Hotkeys.label(preferences.hotkeys[action])


func _input(event: InputEvent) -> void:
	if _capture_action.is_empty():return
	if not ((event is InputEventKey or event is InputEventMouseButton) and event.pressed):return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode==KEY_ESCAPE:
		_capture_action="";_refresh_keys();$Center/Panel/Status.text="已取消按键录入。";return
	var code := Hotkeys.event_code(event)
	if code==0:return
	var draft := preferences.hotkeys.duplicate()
	draft[_capture_action]=code
	var error := Hotkeys.validation_error(draft)
	$Center/Panel/Status.text=error
	if not error.is_empty():return
	preferences.hotkeys=draft
	_capture_action="";_refresh_keys()
	$Center/Panel/Status.text="快捷键已修改，保存后生效。"
