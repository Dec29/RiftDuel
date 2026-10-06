extends Control

signal create_requested
signal join_requested(code: String)
signal address_requested(address: String, code: String, port: int)
signal ready_requested
signal start_requested
signal reset_requested
signal back_requested
signal mode_requested(online: bool)
signal online_create_requested
signal online_join_requested(code: String, invite: String)

const PALETTE := preload("res://view/palette.gd")


func _ready() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = PALETTE.HUD_INSET
	normal.border_color = PALETTE.HUD_RULE
	normal.set_border_width_all(1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = PALETTE.HUD_HOVER
	hover.border_color = PALETTE.BLUE
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = PALETTE.HUD_SURFACE
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = PALETTE.ARROW
	focus.set_border_width_all(1)
	for button in find_children("*", "Button", true, false):
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("disabled", disabled)
		button.add_theme_stylebox_override("focus", focus)
		button.add_theme_color_override("font_color", PALETTE.TEXT)
		button.add_theme_color_override("font_hover_color", PALETTE.TEXT)
		button.add_theme_color_override("font_disabled_color", PALETTE.HUD_DISABLED_TEXT)
	for label in find_children("*", "Label", true, false):
		label.add_theme_color_override("font_color", PALETTE.TEXT)
	$Center/Panel/Hint.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	$Center/Panel/Room/Addresses.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	$Center/Panel/Room/Players.add_theme_constant_override("line_spacing", PALETTE.INFO_PARAGRAPH_GAP)
	var field := normal.duplicate() as StyleBoxFlat
	field.content_margin_left = PALETTE.HUD_PADDING * 0.6
	field.content_margin_right = PALETTE.HUD_PADDING * 0.6
	for input_field in [$Center/Panel/JoinRow/Code, $Center/Panel/AddressRow/Address, $Center/Panel/AddressRow/Port.get_line_edit()]:
		input_field.add_theme_stylebox_override("normal", field)
		input_field.add_theme_stylebox_override("focus", focus)
		input_field.add_theme_color_override("font_color", PALETTE.TEXT)
		input_field.add_theme_color_override("font_placeholder_color", PALETTE.MUTED_TEXT)
	$Center/Panel.item_rect_changed.connect(queue_redraw)
	$Center/Panel/Mode.item_selected.connect(func(index: int) -> void:
		$Center/Panel/JoinRow/Code.clear()
		mode_requested.emit(index == 1)
	)
	$Center/Panel/Create.pressed.connect(func() -> void:
		if $Center/Panel/Mode.selected == 1:
			online_create_requested.emit()
		else:
			create_requested.emit()
	)
	$Center/Panel/JoinRow/Join.pressed.connect(_request_join)
	$Center/Panel/JoinRow/Code.text_submitted.connect(func(_code: String) -> void: _request_join())
	$Center/Panel/AddressRow/JoinAddress.pressed.connect(func() -> void:
		address_requested.emit($Center/Panel/AddressRow/Address.text.strip_edges(), $Center/Panel/JoinRow/Code.text.strip_edges(), int($Center/Panel/AddressRow/Port.value))
	)
	$Center/Panel/Room/ReadyRow/Ready.pressed.connect(func() -> void: ready_requested.emit())
	$Center/Panel/Room/ReadyRow/Start.pressed.connect(func() -> void: start_requested.emit())
	$Center/Panel/Reset.pressed.connect(func() -> void: reset_requested.emit())
	$Center/Panel/Back.pressed.connect(func() -> void: back_requested.emit())


func update_room(info: Dictionary) -> void:
	var choosing: bool = info.phase in ["idle", "failed"]
	var online: bool = info.online
	$Center/Panel/Mode.disabled = not choosing
	$Center/Panel/JoinRow/Code.max_length = 39 if online else 6
	$Center/Panel/JoinRow/Code.placeholder_text = "粘贴邀请码（配对码:凭证）" if online else "输入 6 位配对码"
	$Center/Panel/Hint.text = "互联网 · 创建房间或粘贴好友的邀请码" if online else "同一局域网 · 两人对战 · 无外部服务器"
	$Center/Panel/Room/Copy.text = "复制邀请码" if online else "复制配对码"
	$Center/Panel/Room/Copy.disabled = online and info.phase != "hosting"
	if online and info.phase not in ["idle", "failed", "connecting", "requesting"]:
		$Center/Panel/JoinRow/Code.clear()
	$Center/Panel/Create.visible = choosing
	$Center/Panel/JoinRow.visible = choosing
	$Center/Panel/AddressRow.visible = choosing and not online
	$Center/Panel/Status.text = info.status
	$Center/Panel/Status.add_theme_color_override("font_color", PALETTE.RED if info.phase == "failed" else PALETTE.MUTED_TEXT)
	$Center/Panel/Room.visible = info.phase in ["hosting", "room", "starting", "loading"]
	$Center/Panel/Room/Code.text = "配对码  " + info.code
	$Center/Panel/Room/Addresses.text = info.addresses
	$Center/Panel/Room/Players.text = ("房主 · 蓝方" if info.side == 0 else "加入者 · 红方") + "     " + ("已准备" if info.local_ready else "未准备") + "\n对方     " + ("已准备" if info.remote_ready else "未准备")
	$Center/Panel/Room/Players.add_theme_color_override("font_color", PALETTE.BLUE if info.side == 0 else PALETTE.RED)
	$Center/Panel/Room/ReadyRow/Ready.disabled = info.phase != "room"
	$Center/Panel/Room/ReadyRow/Ready.text = "取消准备" if info.local_ready else "准备"
	$Center/Panel/Room/ReadyRow/Start.visible = info.side == 0
	$Center/Panel/Room/ReadyRow/Start.disabled = info.phase != "room" or not info.local_ready or not info.remote_ready
	$Center/Panel/Reset.visible = not choosing
	queue_redraw()


func _request_join() -> void:
	var code: String = $Center/Panel/JoinRow/Code.text.strip_edges()
	if $Center/Panel/Mode.selected == 1:
		var parts := code.split(":")
		online_join_requested.emit(parts[0] if parts.size() == 2 else "", parts[1] if parts.size() == 2 else "")
	else:
		join_requested.emit(code)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PALETTE.BACKGROUND)
	var panel: Rect2 = $Center/Panel.get_global_rect().grow(PALETTE.HUD_PADDING)
	draw_rect(panel, PALETTE.HUD_SURFACE)
	draw_rect(Rect2(panel.position, Vector2(3, panel.size.y)), $Center/Panel/Room/Players.get_theme_color("font_color") if $Center/Panel/Room.visible else PALETTE.BLUE)
