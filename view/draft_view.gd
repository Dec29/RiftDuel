extends Control

const PALETTE := preload("res://view/palette.gd")
const CARDS := preload("res://view/operator_card_visual.gd")
const SORT := preload("res://view/squad_roster_sort.gd")
const PROFESSIONS := ["", "vanguard","guard","defender","sniper","caster","medic","supporter","specialist"]
const PROFESSION_NAMES := ["全部职业","先锋","近卫","重装","狙击","术士","医疗","辅助","特种"]
var session: NetSession
var _stage := -1
var _mine := PackedStringArray()
var _skills := PackedInt32Array()
var _favorites := PackedStringArray()
var _favorite_skills := {}
var _base := PackedStringArray()
var _preview := ""
var _preview_skill := 0
var _passives := false
var _skill_range := false
var _held := false
var _dragged := false
var _press_position := Vector2.ZERO
var _press_scroll := 0
var _press_id := ""
var _buttons: Dictionary = {}
var _slots: Array[Array] = [[],[]]
var _ban_slots: Array[Array] = [[],[]]
var _team_labels: Array[Label] = []
var _phase_label: Label
var _timer: Label
var _search: LineEdit
var _profession: OptionButton
var _scroll: ScrollContainer
var _roster: HBoxContainer
var _name: Label
var _profession_text: Label
var _detail: RichTextLabel
var _range: Control
var _skill_buttons: Array[Button] = []
var _confirm: Button
var _finish: Button
var _status: Label
var _cancel_prompt: ConfirmationDialog
var ordered_ids := PackedStringArray()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var preferences := SquadConfig.new()
	var error := preferences.read(SquadConfig.FILE_PATH,true)
	if not error.is_empty(): session._fail(error); return
	_favorite_skills = preferences.skill_memory.duplicate()
	_favorites = session.local_squad.duplicate()
	for index in _favorites.size(): _favorite_skills[_favorites[index]] = session.local_skills[index]
	_build_ui()
	session.changed.connect(_sync)
	_sync()


func _label(text: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",PALETTE.TEXT)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = PALETTE.DRAFT_BUTTON_HEIGHT
	button.pressed.connect(action)
	var normal := StyleBoxFlat.new()
	normal.bg_color = PALETTE.HUD_INSET
	normal.border_color = PALETTE.HUD_RULE
	normal.set_border_width_all(1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = PALETTE.HUD_HOVER
	hover.border_color = PALETTE.BLUE
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",hover)
	button.add_theme_color_override("font_color",PALETTE.TEXT)
	button.add_theme_color_override("font_disabled_color",PALETTE.HUD_DISABLED_TEXT)
	return button


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,PALETTE.DRAFT_MARGIN)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",PALETTE.DRAFT_GAP)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",PALETTE.DRAFT_GAP)
	layout.add_child(header)
	var title := _label("赛前禁选 / BAN & PICK",26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_timer = _label("20秒",24)
	_timer.add_theme_color_override("font_color",PALETTE.ARROW)
	header.add_child(_timer)
	header.add_child(_button("返回房间",func() -> void: _cancel_prompt.popup_centered()))
	_phase_label = _label("",16)
	layout.add_child(_phase_label)
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation",24)
	layout.add_child(teams)
	for displayed_side in 2:
		var team := VBoxContainer.new()
		team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		teams.add_child(team)
		var caption := HBoxContainer.new()
		team.add_child(caption)
		var label := _label("我方" if displayed_side==0 else "对方",14)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color",PALETTE.BLUE if displayed_side==0 else PALETTE.RED)
		_team_labels.append(label)
		caption.add_child(label)
		caption.add_child(_label("禁用",12))
		for slot in 5:
			var ban := Control.new()
			ban.custom_minimum_size = Vector2.ONE*PALETTE.DRAFT_BAN_SIZE
			ban.draw.connect(_draw_ban.bind(ban,displayed_side,slot))
			caption.add_child(ban)
			_ban_slots[displayed_side].append(ban)
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation",3)
		team.add_child(strip)
		for slot in 12:
			var card := Button.new()
			card.custom_minimum_size = Vector2.ONE*PALETTE.DRAFT_SLOT_SIZE
			card.draw.connect(_draw_slot.bind(card,displayed_side,slot))
			card.pressed.connect(_inspect_slot.bind(displayed_side,slot))
			strip.add_child(card)
			_slots[displayed_side].append(card)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",16)
	layout.add_child(body)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = PALETTE.DRAFT_DETAILS_WIDTH
	body.add_child(details)
	_name = _label("选择干员",22)
	details.add_child(_name)
	_profession_text = _label("查看技能、特性与天赋",13)
	details.add_child(_profession_text)
	var skill_row := HBoxContainer.new()
	details.add_child(skill_row)
	for index in 3:
		var button := _button("S%d"%(index+1),_choose_skill.bind(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_row.add_child(button)
		_skill_buttons.append(button)
	var tabs := HBoxContainer.new()
	details.add_child(tabs)
	tabs.add_child(_button("技能",func() -> void: _passives=false; _refresh_detail()))
	tabs.add_child(_button("特性 / 天赋",func() -> void: _passives=true; _refresh_detail()))
	tabs.add_child(_button("范围",func() -> void: _skill_range=not _skill_range; _range.queue_redraw()))
	_range = Control.new()
	_range.custom_minimum_size.y = PALETTE.DRAFT_RANGE_HEIGHT
	_range.draw.connect(_draw_range)
	details.add_child(_range)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = false
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for font in ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"]: _detail.add_theme_font_size_override(font,14)
	_detail.add_theme_color_override("default_color",PALETTE.TEXT)
	details.add_child(_detail)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(list)
	var filters := HBoxContainer.new()
	list.add_child(filters)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索干员名称"
	_search.custom_minimum_size.x = 210
	_search.text_changed.connect(func(_text: String) -> void: _build_roster())
	filters.add_child(_search)
	_profession = OptionButton.new()
	for title_text in PROFESSION_NAMES: _profession.add_item(title_text)
	_profession.item_selected.connect(func(_index: int) -> void: _build_roster())
	filters.add_child(_profession)
	filters.add_child(_label("编队优先 · 上下成列，向左浏览",12))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.resized.connect(_resize_cards)
	list.add_child(_scroll)
	_roster = HBoxContainer.new()
	_roster.add_theme_constant_override("separation",PALETTE.DRAFT_GAP)
	_scroll.add_child(_roster)
	var footer := HBoxContainer.new()
	layout.add_child(footer)
	_status = _label("",13)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	footer.add_child(_status)
	_finish = _button("结束本轮禁用 / 空BAN",func() -> void: session.draft.request("submit"))
	footer.add_child(_finish)
	_confirm = _button("确认禁用",_confirm_action)
	_confirm.custom_minimum_size.x = 150
	footer.add_child(_confirm)
	_cancel_prompt = ConfirmationDialog.new()
	_cancel_prompt.dialog_text = "取消本次禁选并返回原房间？双方需要重新准备。"
	_cancel_prompt.confirmed.connect(func() -> void: session.draft.request("cancel"))
	add_child(_cancel_prompt)


func _sync() -> void:
	if session.phase != "draft" or session.draft.state == null: return
	var state := session.draft.state
	if _stage != state.stage:
		_stage = state.stage
		_base = state.picks[session.side].duplicate()
		_mine = _base.duplicate()
		_skills.clear()
		for id in _mine: _skills.append(int(_favorite_skills.get(id,0)))
		if _stage==4: session.draft.request("update",Array(_mine),Array(_skills))
		_build_roster()
	_refresh()


func _build_roster() -> void:
	if _roster == null: return
	for child in _roster.get_children():
		_roster.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var pool := session.draft.state.ids if _stage != 4 else _mine
	var sorted := SORT.ordered_ids(pool,"rarity",true,OperatorDB.get_data)
	ordered_ids.clear()
	if _stage in [1,3,4]:
		for id in _favorites:
			if id in sorted: ordered_ids.append(id)
	for id in sorted:
		if id not in ordered_ids: ordered_ids.append(id)
	var filtered := PackedStringArray()
	for id in ordered_ids:
		var data := OperatorDB.get_data(id)
		if not _search.text.is_empty() and not data.display_name.contains(_search.text) and not id.contains(_search.text.to_lower()): continue
		if _profession.selected > 0 and data.profession_id != PROFESSIONS[_profession.selected]: continue
		filtered.append(id)
	ordered_ids = filtered
	# Rank zero starts at the right edge: upper, lower, then the column to its left.
	for column in range(ceili(ordered_ids.size()/2.0)-1,-1,-1):
		var pair := VBoxContainer.new()
		pair.add_theme_constant_override("separation",PALETTE.DRAFT_GAP)
		_roster.add_child(pair)
		for row in 2:
			var rank := column*2+row
			if rank >= ordered_ids.size():
				var blank := Control.new()
				blank.custom_minimum_size = Vector2(PALETTE.DRAFT_CARD_WIDTH,PALETTE.DRAFT_CARD_HEIGHT)
				pair.add_child(blank)
				continue
			var id := ordered_ids[rank]
			var button := Button.new()
			button.name = id
			button.custom_minimum_size = Vector2(PALETTE.DRAFT_CARD_WIDTH,PALETTE.DRAFT_CARD_HEIGHT)
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.focus_mode = Control.FOCUS_NONE
			button.clip_contents = true
			button.draw.connect(_draw_card.bind(button,id))
			pair.add_child(button)
			_buttons[id] = button
	_resize_cards.call_deferred()
	_scroll_to_start.call_deferred()


func _resize_cards() -> void:
	if _scroll == null or _roster == null: return
	for column in _roster.get_children():
		for card in column.get_children(): card.custom_minimum_size.y = maxf(120,(_scroll.size.y-PALETTE.DRAFT_GAP-16)*0.5)


func _scroll_to_start() -> void:
	await get_tree().process_frame
	if not is_inside_tree(): return
	_scroll.scroll_horizontal = int(_scroll.get_h_scroll_bar().max_value)


func _refresh() -> void:
	var state := session.draft.state
	_phase_label.text = " → ".join(DraftState.NAMES.slice(0,5)) + "    /    当前：" + DraftState.NAMES[_stage]
	_status.text = session.status
	_status.add_theme_color_override("font_color",PALETTE.MUTED_TEXT)
	var locked: bool = state.locked[session.side]
	_finish.visible = _stage in [0,2]
	_finish.disabled = locked
	if _stage in [0,2]:
		_confirm.text = "确认禁用"
		_confirm.disabled = _preview.is_empty() or not state.can_ban(session.side,_preview)
		_status.text += " · 本方禁用 %d / %d（可空BAN）" % [state.bans[session.side].size(),state.ban_limits[session.side]]
	else:
		_confirm.text = "确认技能" if _stage == 4 else "确认选人 %d / %d" % [_mine.size(),state.target_count()]
		_confirm.disabled = locked or _mine.size()!=state.target_count()
	if locked: _status.text = "本方已确认，等待对方完成；可继续查看干员资料。"
	for index in 2:
		var side := session.side if index==0 else 1-session.side
		var chosen := _mine if index==0 and _stage in [1,3,4] else state.picks[side]
		_team_labels[index].text = ("我方" if index==0 else "对方") + "  %d / 12 · "%chosen.size() + ("已确认" if state.locked[side] else "操作中")
		for slot in 12:
			_slots[index][slot].tooltip_text = OperatorDB.get_data(chosen[slot]).display_name if slot<chosen.size() else "尚未公开"
			_slots[index][slot].queue_redraw()
		for slot in 5:
			_ban_slots[index][slot].tooltip_text = OperatorDB.get_data(state.bans[side][slot]).display_name if slot<state.bans[side].size() else "空BAN位"
			_ban_slots[index][slot].queue_redraw()
	for button in _buttons.values(): button.queue_redraw()
	_refresh_detail()


func _select(id: String) -> void:
	_preview = id
	_preview_skill = _skills[_mine.find(id)] if _stage==4 and id in _mine else int(_favorite_skills.get(id,0))
	var state := session.draft.state
	if _stage in [1,3] and not state.locked[session.side] and not state.banned(id) and id not in _base:
		if id in _mine: _mine.remove_at(_mine.find(id))
		elif _mine.size()<state.target_count(): _mine.append(id)
		session.draft.request("update",Array(_mine))
	_refresh()


func _choose_skill(index: int) -> void:
	if _preview.is_empty(): return
	_preview_skill = index
	if _stage==4 and not session.draft.state.locked[session.side] and _preview in _mine:
		_skills[_mine.find(_preview)] = index
		session.draft.request("update",Array(_mine),Array(_skills))
	_refresh_detail()
	for button in _buttons.values(): button.queue_redraw()


func _confirm_action() -> void:
	if _stage in [0,2]: session.draft.request("ban",[],[],_preview)
	else: session.draft.request("submit",Array(_mine),Array(_skills) if _stage==4 else [])


func _inspect_slot(displayed_side: int, slot: int) -> void:
	var side := session.side if displayed_side==0 else 1-session.side
	var ids := _mine if displayed_side==0 and _stage in [1,3,4] else session.draft.state.picks[side]
	if slot>=ids.size(): return
	_preview = ids[slot]
	_preview_skill = _skills[slot] if _stage==4 and displayed_side==0 else 0
	_refresh_detail()


func _refresh_detail() -> void:
	for index in 3:
		_skill_buttons[index].disabled = _preview.is_empty() or index>=OperatorDB.get_data(_preview).skills.size()
		SkillIconVisual.configure_button(_skill_buttons[index],_preview,index,not _skill_buttons[index].disabled)
		_skill_buttons[index].text = ""
		_skill_buttons[index].tooltip_text = OperatorDB.get_data(_preview).skills[index].skill_name if not _skill_buttons[index].disabled else "尚未开放"
		_skill_buttons[index].toggle_mode = true
		_skill_buttons[index].set_pressed_no_signal(not _skill_buttons[index].disabled and index==_preview_skill)
	if _preview.is_empty(): return
	var data := OperatorDB.get_data(_preview)
	_name.text = data.display_name
	_profession_text.text = "%s / %s · 费用%d" % [data.profession,data.branch,DeployRules.base_cost(data)]
	if _passives:
		_detail.text = "特性 · %s\n%s\n\n%s\n%s\n\n%s\n%s"%[data.branch_trait.trait_name,data.branch_trait.description,data.talent_1.talent_name,data.talent_1.description,data.talent_2.talent_name,data.talent_2.description]
	else:
		var skill := data.skills[_preview_skill]
		_detail.text = "%s\n技力 %d · 持续 %.0f秒\n\n%s" % [skill.skill_name,skill.sp_required,skill.duration,skill.description]
	_range.queue_redraw()


func _draw_range() -> void:
	if _preview.is_empty(): return
	var data := OperatorDB.get_data(_preview)
	var offsets := SkillRangePreview.offsets(data,data.skills[_preview_skill]) if _skill_range else AttackRange.acquisition_offsets(data)
	var minimum := Vector2i.ZERO
	var maximum := Vector2i.ZERO
	for cell in offsets: minimum=minimum.min(cell); maximum=maximum.max(cell)
	var extent := maximum-minimum+Vector2i(3,3)
	var cell_size := minf(14,minf(_range.size.x/extent.x,(_range.size.y-18)/extent.y))
	var origin := Vector2((_range.size.x-extent.x*cell_size)*0.5,18)
	_range.draw_string(ThemeDB.fallback_font,Vector2(0,12),"技能范围" if _skill_range else "攻击范围 · 固定朝右",HORIZONTAL_ALIGNMENT_LEFT,-1,12,PALETTE.MUTED_TEXT)
	for row in extent.y:
		for column in extent.x:
			var cell := minimum+Vector2i(column,row)-Vector2i.ONE
			var rect := Rect2(origin+Vector2(column,row)*cell_size,Vector2.ONE*(cell_size-2))
			_range.draw_rect(rect,PALETTE.BLUE if cell==Vector2i.ZERO else (PALETTE.ATTACK_RANGE if cell in offsets else PALETTE.HUD_INSET))


func _draw_card(button: Button,id: String) -> void:
	var index := _mine.find(id)
	var skill := _skills[index] if _stage==4 and index>=0 else int(_favorite_skills.get(id,0))
	CARDS.draw_squad(button,Rect2(Vector2.ZERO,button.size),OperatorDB.get_data(id),skill,str(index+1) if index>=0 else "",index>=0)
	if session.draft.state.banned(id):
		button.draw_rect(Rect2(Vector2.ZERO,button.size),Color(PALETTE.BACKGROUND,0.75))
		button.draw_line(Vector2(4,4),button.size-Vector2(4,4),PALETTE.RED,3)
		button.draw_string(ThemeDB.fallback_font,Vector2(12,42),"已禁用",HORIZONTAL_ALIGNMENT_LEFT,-1,18,PALETTE.RED)
	elif id in session.draft.state.picks[1-session.side]:
		button.draw_string(ThemeDB.fallback_font,Vector2(8,46),"双方已选" if index>=0 else "对方已选",HORIZONTAL_ALIGNMENT_LEFT,-1,13,PALETTE.RED)
	if id==_preview: button.draw_rect(Rect2(Vector2.ONE,button.size-Vector2.ONE*2),PALETTE.ARROW,false,2)
	if id in _favorites: button.draw_string(ThemeDB.fallback_font,Vector2(8,65),"常用编队",HORIZONTAL_ALIGNMENT_LEFT,-1,12,PALETTE.ARROW)


func _draw_slot(button: Button, displayed_side: int, slot: int) -> void:
	var side := session.side if displayed_side==0 else 1-session.side
	var ids := _mine if displayed_side==0 and _stage in [1,3,4] else session.draft.state.picks[side]
	button.draw_rect(Rect2(Vector2.ZERO,button.size),PALETTE.HUD_INSET)
	if slot<ids.size(): button.draw_texture_rect(CARDS.texture(ids[slot],true),Rect2(Vector2.ZERO,button.size),false)
	button.draw_rect(Rect2(Vector2.ZERO,button.size),PALETTE.BLUE if displayed_side==0 else PALETTE.RED,false,1)


func _draw_ban(control: Control, displayed_side: int, slot: int) -> void:
	var side := session.side if displayed_side==0 else 1-session.side
	var ids := session.draft.state.bans[side]
	control.draw_rect(Rect2(Vector2.ZERO,control.size),PALETTE.HUD_INSET)
	if slot<ids.size():
		control.draw_texture_rect(CARDS.texture(ids[slot],true),Rect2(Vector2.ZERO,control.size),false,Color(0.7,0.7,0.7))
		control.draw_line(Vector2.ZERO,control.size,PALETTE.RED,2)


func _input(event: InputEvent) -> void:
	if session.phase!="draft" or _cancel_prompt.visible: return
	if event is InputEventMouseButton and _scroll.get_global_rect().has_point(event.position) and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll.scroll_horizontal += (-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)*PALETTE.DRAFT_CARD_WIDTH
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and _scroll.get_global_rect().has_point(event.position):
			_held=true;_dragged=false;_press_position=event.position;_press_scroll=_scroll.scroll_horizontal;_press_id=""
			for id in _buttons:
				if _buttons[id].get_global_rect().has_point(event.position): _press_id=id;break
			get_viewport().set_input_as_handled()
		elif not event.pressed and _held:
			_held=false
			if not _dragged and not _press_id.is_empty() and _buttons.has(_press_id) and _scroll.get_global_rect().has_point(event.position) and _buttons[_press_id].get_global_rect().has_point(event.position): _select(_press_id)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _held:
		if event.position.distance_to(_press_position)>PALETTE.SQUAD_ROSTER_DRAG_THRESHOLD: _dragged=true
		if _dragged: _scroll.scroll_horizontal=_press_scroll+roundi(_press_position.x-event.position.x)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if session.phase=="draft": _timer.text = "%d秒"%ceili(maxi(0,session.draft.deadline_ms-Time.get_ticks_msec())/1000.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),PALETTE.BACKGROUND)
