extends Control

signal create_requested
signal join_requested(code: String)
signal address_requested(address: String, code: String, port: int)
signal ready_requested
signal start_requested
signal reset_requested
signal back_requested
signal mode_requested(online: bool)
signal rules_requested(value: Dictionary)
signal squad_requested

var _refreshing := false
var _rules := MatchRules.pvp_default()

signal online_create_requested
signal online_join_requested(code: String)

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
	var draft_toggle := $Center/Panel/Room/Columns/Rules/Draft
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		draft_toggle.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for label in find_children("*", "Label", true, false):
		label.add_theme_color_override("font_color", PALETTE.TEXT)
	$Center/Panel/Hint.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	$Center/Panel/Room/Addresses.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	var field := normal.duplicate() as StyleBoxFlat
	field.content_margin_left = PALETTE.HUD_PADDING * 0.6
	field.content_margin_right = PALETTE.HUD_PADDING * 0.6
	for input_field in [$Center/Panel/JoinRow/Code, $Center/Panel/AddressRow/Address, $Center/Panel/AddressRow/Port.get_line_edit()]:
		input_field.add_theme_stylebox_override("normal", field)
		input_field.add_theme_stylebox_override("focus", focus)
		input_field.add_theme_color_override("font_color", PALETTE.TEXT)
		input_field.add_theme_color_override("font_placeholder_color", PALETTE.MUTED_TEXT)
	for spin in [$Center/Panel/Room/Columns/Rules/MinutesRow/Minutes,$Center/Panel/Room/Columns/Rules/RoundsRow/Rounds]:
		spin.get_line_edit().add_theme_stylebox_override("normal",field)
		spin.get_line_edit().add_theme_color_override("font_color",PALETTE.TEXT)
		spin.value_changed.connect(func(_value: float) -> void: _request_rules())
	$Center/Panel/Room/Columns/Rules/Draft.toggled.connect(func(_enabled: bool) -> void: _request_rules())
	$Center/Panel/Room/Columns/Rules/Mode/Score.pressed.connect(func() -> void: _request_rules("score"))
	$Center/Panel/Room/Columns/Rules/Mode/Single.pressed.connect(func() -> void: _request_rules("single"))
	$Center/Panel.item_rect_changed.connect(queue_redraw)
	$Center/Panel/Mode.item_selected.connect(func(index: int) -> void:
		$Center/Panel/JoinRow/Code.clear()
		mode_requested.emit(index == 0)
	)
	$Center/Panel/Create.pressed.connect(func() -> void:
		if $Center/Panel/Mode.selected == 0:
			online_create_requested.emit()
		else:
			create_requested.emit()
	)
	$Center/Panel/JoinRow/Join.pressed.connect(_request_join)
	$Center/Panel/JoinRow/Code.text_submitted.connect(func(_code: String) -> void: _request_join())
	$Center/Panel/AddressRow/JoinAddress.pressed.connect(func() -> void:
		address_requested.emit($Center/Panel/AddressRow/Address.text.strip_edges(), $Center/Panel/JoinRow/Code.text.strip_edges(), int($Center/Panel/AddressRow/Port.value))
	)
	$Center/Panel/Room/ReadyRow/Squad.pressed.connect(func() -> void: squad_requested.emit())
	$Center/Panel/Room/ReadyRow/Ready.pressed.connect(func() -> void: ready_requested.emit())
	$Center/Panel/Room/ReadyRow/Start.pressed.connect(func() -> void: start_requested.emit())
	$Center/Panel/Footer/Reset.pressed.connect(func() -> void: reset_requested.emit())
	$Center/Panel/Footer/Back.pressed.connect(func() -> void: back_requested.emit())


func update_room(info: Dictionary) -> void:
	_refreshing=true
	var choosing: bool=info.phase in ["idle","failed"]
	var inside: bool=info.phase in ["hosting","room","starting","loading","returning"]
	var online: bool=info.online
	_rules=info.rules
	$Center/Panel.custom_minimum_size.x=1080 if inside else 620
	$Center/Panel/Title.text="多人房间" if inside else "多人模式"
	$Center/Panel/Title.add_theme_font_size_override("font_size",30)
	$Center/Panel/Mode.visible=choosing
	$Center/Panel/Hint.visible=choosing
	$Center/Panel/Hint.text="互联网 · 创建房间或输入好友的6位数字配对码" if online else "同一局域网 · 两人对战"
	$Center/Panel/JoinRow/Code.max_length=6
	$Center/Panel/JoinRow/Code.placeholder_text="输入 6 位数字配对码"
	if online and info.phase not in ["idle","failed","connecting","requesting"]:$Center/Panel/JoinRow/Code.clear()
	$Center/Panel/Create.visible=choosing
	$Center/Panel/JoinRow.visible=choosing
	$Center/Panel/AddressRow.visible=choosing and not online
	$Center/Panel/Room.visible=inside
	$Center/Panel/Room/Header/Code.text=("互联网" if online else "局域网")+" · 配对码  "+info.code
	$Center/Panel/Room/Header/Copy.disabled=online and info.phase!="hosting"
	$Center/Panel/Room/Addresses.text=info.addresses if not online else ""
	$Center/Panel/Room/Addresses.visible=not online and not info.addresses.is_empty()
	for side in 2:
		var label: Label=$Center/Panel/Room/Columns/Members/Blue if side==0 else $Center/Panel/Room/Columns/Members/Red
		var local: bool=side==info.side
		var ready: bool=info.local_ready if local else info.remote_ready
		var ready_text := "等待开始" if side==0 else ("已准备" if ready else "未准备")
		if info.phase=="returning":ready_text="已确认" if local or info.remote_returned else "结算中"
		if info.phase=="hosting" and side==1:ready_text="等待加入"
		label.text=("房主 · 蓝方" if side==0 else "加入者 · 红方")+("  （你）" if local else "")+"\n"+ready_text
		label.add_theme_color_override("font_color",PALETTE.BLUE if side==0 else PALETTE.RED)
	var locked: bool=not info.can_edit
	$Center/Panel/Room/Columns/Rules/Title.text="对局规则 · "+("整场已锁定" if info.round>0 else ("仅房主可修改" if info.side==0 else "由房主设置"))
	$Center/Panel/Room/Columns/Rules/Mode/Score.button_pressed=_rules.mode=="score"
	$Center/Panel/Room/Columns/Rules/Mode/Single.button_pressed=_rules.mode=="single"
	$Center/Panel/Room/Columns/Rules/Draft.set_pressed_no_signal(_rules.draft_enabled)
	$Center/Panel/Room/Columns/Rules/Draft.disabled=locked
	$Center/Panel/Room/Columns/Rules/Mode/Score.disabled=locked
	$Center/Panel/Room/Columns/Rules/Mode/Single.disabled=locked
	for pair in [["MinutesRow/Minutes",_rules.minutes],["RoundsRow/Rounds",_rules.rounds]]:
		var spin: SpinBox=$Center/Panel/Room/Columns/Rules.get_node(pair[0])
		spin.set_value_no_signal(pair[1])
		spin.editable=not locked
	$Center/Panel/Room/Columns/Rules/Description.visible=false
	$Center/Panel/Room/Columns/Members/Hint.hide()
	$Center/Panel/Room/Summary.hide()
	$Center/Panel/Room/Columns/Rules/Description.text=("失球方：待部署区冷却最长3人重置、费用+50（上限99），暂停15秒，可越界部署1人或跳过；到时同分平局。" if _rules.mode=="score" else "先入一球获胜；到时按球位置判胜，正中加时最多1分钟。")+("\n固定打满，胜场多者获胜；每局重置部署、费用及技能次数。" if _rules.rounds>1 else "")
	$Center/Panel/Room/Summary.text=_rules.summary()+(" · 第%d局"%info.round if info.round>0 else "")
	$Center/Panel/Room/Summary.add_theme_color_override("font_color",PALETTE.ARROW)
	$Center/Panel/Room/ReadyRow/Squad.disabled=info.phase not in ["hosting", "room"] or info.round>0 or info.pending
	$Center/Panel/Room/ReadyRow/Ready.visible=info.side==1
	$Center/Panel/Room/ReadyRow/Ready.disabled=info.phase!="room" or info.round>0 or info.pending
	$Center/Panel/Room/ReadyRow/Ready.text="取消准备" if info.local_ready else "准备"
	$Center/Panel/Room/ReadyRow/Start.visible=info.side==0
	$Center/Panel/Room/ReadyRow/Start.disabled=info.phase!="room" or not info.remote_ready or info.pending
	$Center/Panel/Room/ReadyRow/Start.text="开始下一局" if info.round>0 else "开始对局"
	$Center/Panel/Status.text=info.status
	$Center/Panel/Status.add_theme_color_override("font_color",PALETTE.RED if info.phase=="failed" else PALETTE.MUTED_TEXT)
	$Center/Panel/Footer/Reset.visible=not choosing
	$Center/Panel/Footer/Reset.text="退出房间" if inside else "取消 / 重新选择"
	_refreshing=false
	queue_redraw()


func update_solo(rules: MatchRules, squad_summary: String) -> void:
	update_room({"rules":rules,"can_edit":true,"round":0,"pending":false,"phase":"room","online":false,"status":"选择玩法与时长后开始，AI使用相同编队与技能。","side":0,"code":"","local_ready":false,"remote_ready":true,"local_returned":false,"remote_returned":false,"addresses":""})
	$Center/Panel/Title.text = "单人模式 · 对局准备"
	$Center/Panel/Room/Header.hide()
	$Center/Panel/Room/Columns/Members/Title.text = "对局双方"
	$Center/Panel/Room/Columns/Members/Blue.text = "你 · 蓝方\n" + squad_summary
	$Center/Panel/Room/Columns/Members/Red.text = "镜像 AI · 红方\n与本方使用相同编队和技能"
	$Center/Panel/Room/Columns/Members/Hint.text = "可在此调整编队，再选择玩法与对局时长。"
	$Center/Panel/Room/Columns/Rules/Title.text = "对局规则"
	$Center/Panel/Room/Columns/Rules/RoundsRow.hide()
	$Center/Panel/Room/Columns/Rules/Draft.hide()
	$Center/Panel/Room/ReadyRow/Ready.hide()
	$Center/Panel/Room/ReadyRow/Start.disabled = false
	$Center/Panel/Footer/Reset.hide()


func _request_rules(mode: String = "") -> void:
	if _refreshing:return
	if not mode.is_empty():
		$Center/Panel/Room/Columns/Rules/Mode/Score.set_pressed_no_signal(mode=="score")
		$Center/Panel/Room/Columns/Rules/Mode/Single.set_pressed_no_signal(mode=="single")
	var value := {"mode":_rules.mode if mode.is_empty() else mode,"minutes":int($Center/Panel/Room/Columns/Rules/MinutesRow/Minutes.value),"rounds":int($Center/Panel/Room/Columns/Rules/RoundsRow/Rounds.value),"draft_enabled":$Center/Panel/Room/Columns/Rules/Draft.button_pressed}
	if value!=_rules.to_wire():rules_requested.emit(value)


func _request_join() -> void:
	var code: String = $Center/Panel/JoinRow/Code.text.strip_edges()
	if $Center/Panel/Mode.selected == 0:
		online_join_requested.emit(code)
	else:
		join_requested.emit(code)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PALETTE.BACKGROUND)
	var panel: Rect2 = $Center/Panel.get_global_rect().grow(PALETTE.HUD_PADDING)
	draw_rect(panel, PALETTE.HUD_SURFACE)
	draw_rect(Rect2(panel.position, Vector2(3, panel.size.y)), PALETTE.BLUE)
	if $Center/Panel/Room.visible:
		for section in [$Center/Panel/Room/Columns/Members,$Center/Panel/Room/Columns/Rules]:
			draw_rect(section.get_global_rect().grow(12),PALETTE.HUD_INSET)
