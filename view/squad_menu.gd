extends Control

signal closed
var embedded := false

const PALETTE := preload("res://view/palette.gd")
const CARD_VISUAL := preload("res://view/operator_card_visual.gd")
const ROSTER_SORT := preload("res://view/squad_roster_sort.gd")
const SLOT_COUNT := SquadConfig.MAX_OPERATORS
const PROFESSIONS := {"vanguard": "先锋", "sniper": "狙击", "defender": "重装", "guard": "近卫", "caster": "术士", "medic": "医疗", "supporter": "辅助", "specialist": "特种"}

var squad
var draft := PackedStringArray()
var draft_skills := PackedInt32Array()
var draft_memory: Dictionary = {}
var preview_skill := 0
var detail_tab := 0
var show_skill_range := false
var selected_slot := -1
var preview_id := ""
var quick_mode := false
var profession_filter := ""
var sort_key := "rarity"
var sort_descending := true
var _roster_held := false
var _roster_dragged := false
var _roster_press_position := Vector2.ZERO
var _roster_press_scroll := 0
var _roster_pressed_id := ""
var _scroll_target := 0.0
var _scroll_display := 0.0
var _normal: StyleBoxFlat
var _selected: StyleBoxFlat

@onready var sort_button: Button = $Margin/Layout/Header/Sorting
@onready var sort_sidebar: PanelContainer = $Margin/Layout/Body/Picker/SortSidebar
@onready var sort_options: VBoxContainer = $Margin/Layout/Body/Picker/SortSidebar/Options
@onready var profession_button: Button = $Margin/Layout/Header/ProfessionFilter
@onready var profession_sidebar: PanelContainer = $Margin/Layout/Body/Picker/ProfessionSidebar
@onready var profession_options: VBoxContainer = $Margin/Layout/Body/Picker/ProfessionSidebar/Options
@onready var empty_roster: Label = $Margin/Layout/Body/EmptyRoster
@onready var overview: GridContainer = $Margin/Layout/Body/Overview
@onready var picker: HBoxContainer = $Margin/Layout/Body/Picker
@onready var details: RichTextLabel = $Margin/Layout/Body/Picker/Details/Content/Text
@onready var roster_scroll: ScrollContainer = $Margin/Layout/Body/Picker/RosterScroll
@onready var roster: GridContainer = $Margin/Layout/Body/Picker/RosterScroll/Roster
@onready var status: Label = $Margin/Layout/Actions/Status
@onready var exit_prompt: ColorRect = $ExitPrompt
@onready var clear_prompt: ColorRect = $ClearPrompt
@onready var quick_button: Button = $Margin/Layout/Actions/Quick
@onready var clear_button: Button = $Margin/Layout/Actions/Clear
@onready var quick_confirm: Button = $Margin/Layout/Actions/QuickConfirm
@onready var clear_selection: Button = $Margin/Layout/Actions/ClearSelection


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	overview.add_theme_constant_override("h_separation", PALETTE.SQUAD_OVERVIEW_H_SEPARATION)
	overview.add_theme_constant_override("v_separation", PALETTE.SQUAD_CARD_V_SEPARATION)
	var overview_width := PALETTE.SQUAD_CARD_WIDTH * overview.columns + PALETTE.SQUAD_OVERVIEW_H_SEPARATION * (overview.columns - 1)
	overview.offset_left = -overview_width * 0.5
	overview.offset_right = overview_width * 0.5
	$Margin/Layout/Body/Picker/Details.custom_minimum_size.x = PALETTE.SQUAD_DETAILS_WIDTH
	roster.add_theme_constant_override("h_separation", PALETTE.SQUAD_ROSTER_H_SEPARATION)
	roster.add_theme_constant_override("v_separation", PALETTE.SQUAD_CARD_V_SEPARATION)
	_normal = StyleBoxFlat.new()
	_normal.bg_color = PALETTE.HUD_SURFACE
	_normal.border_color = PALETTE.HUD_RULE
	_normal.set_border_width_all(1)
	_selected = _normal.duplicate() as StyleBoxFlat
	_selected.border_color = PALETTE.BLUE
	_selected.set_border_width_all(2)
	_selected.border_width_left = 3
	var panel := _normal.duplicate() as StyleBoxFlat
	panel.set_content_margin_all(PALETTE.HUD_PADDING)
	$Margin/Layout/Body/Picker/Details.add_theme_stylebox_override("panel", panel)
	$ExitPrompt/Center/Panel.add_theme_stylebox_override("panel", panel)
	$ClearPrompt/Center/Panel.add_theme_stylebox_override("panel", panel)
	for button in find_children("*", "Button", true, false):
		_style_button(button)
	for label in find_children("*", "Label", true, false):
		label.add_theme_color_override("font_color", PALETTE.TEXT)
		if not label.has_theme_font_size_override("font_size"):
			label.add_theme_font_size_override("font_size", PALETTE.MENU_TEXT_SIZE)
	_setup_profession_filter()
	_setup_sorting()
	status.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	$Margin/Layout/Header/Count.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	$Margin/Layout/Body/Picker/Details/Content/Profession.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	details.add_theme_color_override("default_color", PALETTE.TEXT)
	var range_view: Control = $Margin/Layout/Body/Picker/Details/Content/Range
	range_view.draw.connect(func() -> void:
		var font := ThemeDB.fallback_font
		range_view.draw_string(font, Vector2(0, 16), "技能范围 · 固定朝右" if show_skill_range else "攻击范围 · 固定朝右", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PALETTE.MUTED_TEXT)
		if preview_id.is_empty():
			return
		var operator := OperatorDB.get_data(preview_id)
		var attack_range := SkillRangePreview.offsets(operator,operator.skills[preview_skill]) if show_skill_range else AttackRange.acquisition_offsets(operator)
		var minimum := Vector2i.ZERO
		var maximum := Vector2i.ZERO
		for cell in attack_range:
			minimum = minimum.min(cell)
			maximum = maximum.max(cell)
		var extent := maximum - minimum + Vector2i(3, 3)
		var cell_size := minf(16.0, minf(range_view.size.x / extent.x, 72.0 / extent.y))
		var origin := Vector2((range_view.size.x - extent.x * cell_size) * 0.5, 26)
		for row in extent.y:
			for column in extent.x:
				var cell := minimum + Vector2i(column, row) - Vector2i.ONE
				var rect := Rect2(origin + Vector2(column, row) * cell_size, Vector2.ONE * (cell_size - 2))
				range_view.draw_rect(rect, PALETTE.ATTACK_RANGE if cell in attack_range else PALETTE.HUD_INSET)
				range_view.draw_rect(rect, PALETTE.HUD_RULE, false, 1)
				if cell == Vector2i.ZERO:
					range_view.draw_rect(rect, PALETTE.BLUE)
					var center := rect.get_center()
					range_view.draw_colored_polygon(PackedVector2Array([center + Vector2(3, 0), center + Vector2(-2, -3), center + Vector2(-2, 3)]), PALETTE.BALL)
	)
	range_view.resized.connect(range_view.queue_redraw)
	$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Skill.pressed.connect(_set_detail_tab.bind(0))
	$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Passive.pressed.connect(_set_detail_tab.bind(1))
	$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Preview.pressed.connect(func() -> void:
		show_skill_range = not show_skill_range
		$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Preview.text = "普通范围" if show_skill_range else "技能范围"
		$Margin/Layout/Body/Picker/Details/Content/Range.queue_redraw()
	)
	details.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			var bar := details.get_v_scroll_bar()
			_scroll_target = clampf(_scroll_target + direction * PALETTE.INFO_LINE_HEIGHT * 3, bar.min_value, maxf(bar.min_value, bar.max_value - bar.page))
			details.accept_event()
	)
	details.get_v_scroll_bar().value_changed.connect(func(value: float) -> void:
		if absf(value - _scroll_display) > 1.0:
			_scroll_target = value
			_scroll_display = value
	)
	var back_button: Button = $Margin/Layout/Header/Back
	back_button.draw.connect(func() -> void:
		var center := back_button.size * 0.5
		back_button.draw_polyline(PackedVector2Array([center + Vector2(6, -11), center + Vector2(-6, 0), center + Vector2(6, 11)]), PALETTE.TEXT, 2.5, true)
	)
	back_button.pressed.connect(_request_back)
	quick_button.pressed.connect(func() -> void:
		quick_mode = true
		selected_slot = -1
		overview.hide()
		picker.show()
		profession_button.show()
		sort_button.show()
		$Margin/Layout/Header/Title.text = "快速编队"
		quick_button.hide()
		clear_button.hide()
		$Margin/Layout/Actions/Remove.hide()
		quick_confirm.show()
		clear_selection.show()
		_build_roster()
		_preview(draft[0] if not draft.is_empty() else "")
	)
	quick_confirm.pressed.connect(func() -> void:
		_save()
		_show_overview()
	)
	clear_selection.pressed.connect(func() -> void:
		draft.clear()
		draft_skills.clear()
		_refresh_roster()
		_preview(preview_id)
	)
	clear_button.pressed.connect(func() -> void:
		clear_prompt.show()
		$ClearPrompt/Center/Panel/Content/Actions/Cancel.grab_focus()
	)
	$ClearPrompt/Center/Panel/Content/Actions/Cancel.pressed.connect(func() -> void:
		clear_prompt.hide()
		clear_button.grab_focus()
	)
	$ClearPrompt/Center/Panel/Content/Actions/Confirm.pressed.connect(func() -> void:
		draft.clear()
		draft_skills.clear()
		_save()
		clear_prompt.hide()
		_show_overview()
	)
	var clear_actions := $ClearPrompt/Center/Panel/Content/Actions.get_children()
	for index in clear_actions.size():
		clear_actions[index].focus_next = clear_actions[1 - index].get_path()
		clear_actions[index].focus_previous = clear_actions[1 - index].get_path()
	var keep: Button = $ExitPrompt/Center/Panel/Content/Actions/Keep
	keep.focus_next = keep.get_path()
	keep.focus_previous = keep.get_path()

	$Margin/Layout/Actions/Remove.pressed.connect(func() -> void:
		draft.remove_at(selected_slot)
		draft_skills.remove_at(selected_slot)
		_save()
		_show_overview()
	)
	for index in 3:
		$Margin/Layout/Body/Picker/Details/Content/Skills.get_child(index).pressed.connect(_select_skill.bind(index))
	$ExitPrompt/Center/Panel/Content/Actions/Keep.pressed.connect(func() -> void:
		exit_prompt.hide()
		back_button.grab_focus()
	)
	squad = load("res://squad.gd").new()
	var error: String = squad.read(SquadConfig.FILE_PATH, true)
	draft = squad.operator_ids.duplicate()
	draft_skills = squad.skill_indices.duplicate()
	draft_memory = squad.skill_memory.duplicate()
	_show_overview()
	if not error.is_empty():
		push_error(error)
		get_tree().quit(1)


func _style_button(button: Button) -> void:
	var hover := _normal.duplicate() as StyleBoxFlat
	hover.bg_color = PALETTE.HUD_HOVER
	var disabled := _normal.duplicate() as StyleBoxFlat
	disabled.bg_color = PALETTE.HUD_INSET
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = PALETTE.ARROW
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", _normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", _selected)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", PALETTE.TEXT)
	button.add_theme_color_override("font_hover_color", PALETTE.TEXT)
	button.add_theme_color_override("font_pressed_color", PALETTE.TEXT)
	button.add_theme_color_override("font_disabled_color", PALETTE.HUD_DISABLED_TEXT)
	button.add_theme_font_size_override("font_size", PALETTE.HUD_TITLE_SIZE)


func _setup_sorting() -> void:
	sort_sidebar.custom_minimum_size.x = PALETTE.SQUAD_SORT_WIDTH
	for key in ROSTER_SORT.LABELS:
		var row := PanelContainer.new()
		row.name = key
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var background := StyleBoxFlat.new()
		background.bg_color = PALETTE.HUD_SURFACE if sort_options.get_child_count() % 2 == 0 else PALETTE.HUD_INSET
		row.add_theme_stylebox_override("panel", background)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 0)
		row.add_child(line)
		var label := Button.new()
		label.name = "Criterion"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.tooltip_text = "点击切换排序方向；同值按固定干员顺序排列"
		if key == "attack_frequency": label.tooltip_text = "按基础攻击频率（次/秒）排序；不计技能及战场加成"
		if key == "deploy_cost": label.tooltip_text = "按编队卡片费用排序；不计队友折扣及战场临时变化"
		_style_sort_control(label)
		label.draw.connect(func() -> void:
			var color := PALETTE.SQUAD_FILTER_ACCENT if sort_key == key else PALETTE.TEXT
			var icon := Rect2(Vector2(10, (label.size.y - PALETTE.SQUAD_SORT_ICON_SIZE) * 0.5), Vector2.ONE * PALETTE.SQUAD_SORT_ICON_SIZE)
			label.draw_rect(icon, PALETTE.SQUAD_FILTER_BACKGROUND)
			label.draw_texture_rect(ROSTER_SORT.ICONS[key], icon, false, color)
			var font := ThemeDB.fallback_font
			var baseline := (label.size.y + font.get_ascent(PALETTE.SQUAD_SORT_TEXT_SIZE) - font.get_descent(PALETTE.SQUAD_SORT_TEXT_SIZE)) * 0.5
			label.draw_string(font, Vector2(icon.end.x + 8, baseline), ROSTER_SORT.LABELS[key], HORIZONTAL_ALIGNMENT_LEFT, -1, PALETTE.SQUAD_SORT_TEXT_SIZE, color)
		)
		label.pressed.connect(func() -> void: _select_sort(key, not sort_descending if sort_key == key else true))
		line.add_child(label)
		for descending: bool in [true, false]:
			var arrow := Button.new()
			arrow.name = "Descending" if descending else "Ascending"
			arrow.custom_minimum_size.x = PALETTE.SQUAD_SORT_ARROW_WIDTH
			arrow.toggle_mode = true
			arrow.tooltip_text = "%s · %s" % [ROSTER_SORT.LABELS[key], "降序：从大到小" if descending else "升序：从小到大"]
			_style_sort_control(arrow)
			arrow.draw.connect(func() -> void:
				var center := arrow.size * 0.5
				var sign_y := 1.0 if descending else -1.0
				var color := PALETTE.SQUAD_FILTER_ACCENT if sort_key == key and sort_descending == descending else PALETTE.MUTED_TEXT
				arrow.draw_polyline(PackedVector2Array([center + Vector2(-6, -3 * sign_y), center + Vector2(0, 3 * sign_y), center + Vector2(6, -3 * sign_y)]), color, 2, true)
			)
			arrow.pressed.connect(_select_sort.bind(key, descending))
			line.add_child(arrow)
		sort_options.add_child(row)
	sort_button.pressed.connect(func() -> void: _set_sort_sidebar(not sort_sidebar.visible))
	_refresh_sorting()


func _style_sort_control(button: Button) -> void:
	_style_button(button)
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", clear)
	var active := clear.duplicate() as StyleBoxFlat
	active.bg_color = Color(PALETTE.SQUAD_FILTER_ACCENT, 0.16)
	button.add_theme_stylebox_override("pressed", active)


func _refresh_sorting() -> void:
	sort_button.text = "%s %s" % [ROSTER_SORT.LABELS[sort_key], "↓" if sort_descending else "↑"]
	sort_button.tooltip_text = "排序：%s · %s" % [ROSTER_SORT.LABELS[sort_key], "降序" if sort_descending else "升序"]
	for row in sort_options.get_children():
		for button in row.get_child(0).get_children():
			if button.name != "Criterion": button.set_pressed_no_signal(str(row.name) == sort_key and (button.name == "Descending") == sort_descending)
			button.queue_redraw()


func _select_sort(key: String, descending: bool) -> void:
	sort_key = key
	sort_descending = descending
	_refresh_sorting()
	_build_roster()


func _set_sort_sidebar(open: bool) -> void:
	sort_sidebar.visible = open
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		sort_button.add_theme_color_override(color_name, PALETTE.SQUAD_FILTER_ACCENT if open else PALETTE.TEXT)
	_update_empty_roster_bounds()


func _update_empty_roster_bounds() -> void:
	empty_roster.offset_right = -((PALETTE.SQUAD_FILTER_WIDTH + 16 if profession_sidebar.visible else 0) + (PALETTE.SQUAD_SORT_WIDTH + 16 if sort_sidebar.visible else 0))


func _setup_profession_filter() -> void:
	profession_button.custom_minimum_size.x = PALETTE.SQUAD_FILTER_WIDTH
	profession_sidebar.custom_minimum_size.x = PALETTE.SQUAD_FILTER_WIDTH
	var background := StyleBoxFlat.new()
	background.bg_color = PALETTE.SQUAD_FILTER_BACKGROUND
	profession_sidebar.add_theme_stylebox_override("panel", background)
	var ids := PackedStringArray([""])
	ids.append_array(PackedStringArray(PROFESSIONS.keys()))
	for id in ids:
		var button := Button.new()
		button.name = "All" if id.is_empty() else id
		button.toggle_mode = true
		button.button_pressed = id.is_empty()
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "全部职业" if id.is_empty() else PROFESSIONS[id]
		_style_button(button)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color.TRANSPARENT
		var active := normal.duplicate() as StyleBoxFlat
		active.bg_color = Color(PALETTE.SQUAD_FILTER_ACCENT, 0.16)
		active.border_color = PALETTE.SQUAD_FILTER_ACCENT
		active.border_width_right = 3
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("pressed", active)
		button.draw.connect(func() -> void:
			var color := PALETTE.SQUAD_FILTER_ACCENT if profession_filter == id else PALETTE.MUTED_TEXT
			if id.is_empty():
				var font := ThemeDB.fallback_font
				var width := font.get_string_size("ALL", HORIZONTAL_ALIGNMENT_LEFT, -1, PALETTE.SQUAD_FILTER_TEXT_SIZE).x
				button.draw_string(font, Vector2((button.size.x - width) * 0.5, (button.size.y + font.get_ascent(PALETTE.SQUAD_FILTER_TEXT_SIZE) - font.get_descent(PALETTE.SQUAD_FILTER_TEXT_SIZE)) * 0.5), "ALL", HORIZONTAL_ALIGNMENT_LEFT, -1, PALETTE.SQUAD_FILTER_TEXT_SIZE, color)
			else:
				var icon_size := Vector2.ONE * minf(PALETTE.SQUAD_FILTER_ICON_SIZE, button.size.y - 8)
				button.draw_texture_rect(CARD_VISUAL.profession_texture(id), Rect2((button.size - icon_size) * 0.5, icon_size), false, color)
		)
		button.pressed.connect(_select_profession.bind(id))
		profession_options.add_child(button)
	profession_button.pressed.connect(func() -> void: _set_profession_sidebar(not profession_sidebar.visible))


func _set_profession_sidebar(open: bool) -> void:
	profession_sidebar.visible = open
	profession_button.text = "收起 ›" if open else "职业 ≡"
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		profession_button.add_theme_color_override(color_name, PALETTE.SQUAD_FILTER_ACCENT if open or not profession_filter.is_empty() else PALETTE.TEXT)
	profession_button.tooltip_text = "筛选职业：" + ("全部" if profession_filter.is_empty() else PROFESSIONS[profession_filter])
	_update_empty_roster_bounds()


func _select_profession(id: String) -> void:
	profession_filter = id
	_build_roster()
	_set_profession_sidebar(profession_sidebar.visible)
	for button in profession_options.get_children():
		button.button_pressed = str(button.name) == ("All" if id.is_empty() else id)
		button.queue_redraw()


func _show_overview() -> void:
	_roster_held = false
	selected_slot = -1
	quick_mode = false
	preview_id = ""
	picker.hide()
	sort_button.hide()
	_set_sort_sidebar(false)
	profession_button.hide()
	_set_profession_sidebar(false)
	empty_roster.hide()
	overview.show()
	$Margin/Layout/Header/Title.text = "编队"
	$Margin/Layout/Header/Count.text = "已编入 %d / %d" % [draft.size(), SLOT_COUNT]
	$Margin/Layout/Actions/Remove.hide()
	quick_button.show()
	clear_button.show()
	clear_button.disabled = draft.is_empty()
	quick_confirm.hide()
	clear_selection.hide()
	status.hide()
	for child in overview.get_children():
		overview.remove_child(child)
		child.queue_free()
	for slot in SLOT_COUNT:
		var button := Button.new()
		button.name = "Slot%d" % (slot + 1)
		button.custom_minimum_size = Vector2(PALETTE.SQUAD_CARD_WIDTH, PALETTE.SQUAD_CARD_HEIGHT)
		var operator_id := draft[slot] if slot < draft.size() else ""
		button.tooltip_text = "第 %02d 槽 · %s" % [slot + 1, OperatorDB.get_data(operator_id).display_name if not operator_id.is_empty() else "添加干员"]
		_style_button(button)
		button.draw.connect(func() -> void: _draw_card(button, operator_id, draft_skills[slot] if not operator_id.is_empty() else 0))
		button.pressed.connect(_open_slot.bind(slot))
		overview.add_child(button)
	$Margin/Layout/Header/Back.grab_focus()


func _open_slot(slot: int) -> void:
	# Saved squads are ordered lists; additions fill the first free slot.
	slot = mini(slot, draft.size())
	selected_slot = slot
	quick_mode = false
	preview_id = draft[slot] if slot < draft.size() else ""
	overview.hide()
	picker.show()
	profession_button.show()
	sort_button.show()
	$Margin/Layout/Header/Title.text = "编辑第 %02d 槽" % (slot + 1)
	$Margin/Layout/Actions/Remove.visible = slot < draft.size()
	status.hide()
	quick_button.hide()
	clear_button.hide()
	quick_confirm.hide()
	clear_selection.hide()
	_build_roster()
	_preview(preview_id)


func _build_roster() -> void:
	var ids := PackedStringArray()
	for id in OperatorDB.all_ids():
		if not quick_mode and draft.has(id):
			continue
		if not profession_filter.is_empty() and OperatorDB.get_data(id).profession_id != profession_filter:
			continue
		ids.append(id)
	ids = ROSTER_SORT.ordered_ids(ids, sort_key, sort_descending, OperatorDB.get_data)
	empty_roster.visible = ids.is_empty()
	_roster_held = false
	roster_scroll.scroll_horizontal = 0
	roster.columns = maxi(1, ceili(ids.size() / 2.0))
	for child in roster.get_children():
		roster.remove_child(child)
		child.queue_free()
	# GridContainer fills rows: supply even ranks above, odd ranks below.
	var display_ids := PackedStringArray()
	for row in 2:
		for index in range(row, ids.size(), 2):
			display_ids.append(ids[index])
	for operator_id in display_ids:
		var button := Button.new()
		button.name = operator_id
		button.custom_minimum_size = Vector2(PALETTE.SQUAD_ROSTER_CARD_WIDTH, PALETTE.SQUAD_CARD_HEIGHT)
		button.tooltip_text = "%s · %s %s" % [OperatorDB.get_data(operator_id).display_name, ROSTER_SORT.LABELS[sort_key], ROSTER_SORT.value_text(OperatorDB.get_data(operator_id), sort_key)]
		_style_button(button)
		button.draw.connect(func() -> void:
			var assigned := draft.find(operator_id)
			_draw_card(button, operator_id, draft_skills[assigned] if assigned >= 0 else int(draft_memory.get(operator_id,0)), "%02d" % (assigned + 1) if quick_mode and assigned >= 0 else "", quick_mode and assigned >= 0)
		)
		button.pressed.connect(_select_operator.bind(operator_id))
		roster.add_child(button)
	_refresh_roster()


func _refresh_roster() -> void:
	$Margin/Layout/Header/Count.text = "%s %d / %d" % ["已选择" if quick_mode else "已编入", draft.size(), SLOT_COUNT]
	for button in roster.get_children():
		button.add_theme_stylebox_override("normal", _selected if (draft.has(str(button.name)) if quick_mode else button.name == preview_id) else _normal)
		button.queue_redraw()


func _preview(operator_id: String) -> void:
	detail_tab = 0
	show_skill_range = false
	$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Skill.button_pressed = true
	$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Passive.button_pressed = false
	preview_id = operator_id
	preview_skill = draft_skills[draft.find(operator_id)] if draft.has(operator_id) else int(draft_memory.get(operator_id,0))
	for index in 3:
		var button: Button = $Margin/Layout/Body/Picker/Details/Content/Skills.get_child(index)
		button.disabled = operator_id.is_empty() or index >= OperatorDB.get_data(operator_id).skills.size()
		button.button_pressed = not button.disabled and index == preview_skill
		SkillIconVisual.configure_button(button,operator_id,index,not button.disabled)
		button.tooltip_text = OperatorDB.get_data(operator_id).skills[index].skill_name if not button.disabled else "尚未开放"
		button.text = ""
	$Margin/Layout/Body/Picker/Details/Content/Range.queue_redraw()
	_scroll_display = 0.0
	_scroll_target = 0.0
	details.get_v_scroll_bar().value = 0
	for button in roster.get_children():
		button.add_theme_stylebox_override("normal", _selected if (draft.has(str(button.name)) if quick_mode else button.name == operator_id) else _normal)
		button.queue_redraw()
	status.hide()
	if operator_id.is_empty():
		$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Preview.hide()
		$Margin/Layout/Body/Picker/Details/Content/Name.text = "选择干员"
		$Margin/Layout/Body/Picker/Details/Content/Profession.text = "按住右侧卡片左右拖动浏览"
		details.text = ("点击卡片加入或移除，确认后保存。" if quick_mode else "点击右侧干员直接加入本槽。") + "\n\n选择已开放技能，未开放位置留空。"
		return
	var operator := OperatorDB.get_data(operator_id)
	$Margin/Layout/Body/Picker/Details/Content/Name.text = operator.display_name
	$Margin/Layout/Body/Picker/Details/Content/Profession.text = "%s / %s · 费用 %d" % [operator.profession, operator.branch, DeployRules.base_cost(operator)]
	$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Preview.visible = SkillRangePreview.available(operator,operator.skills[preview_skill])
	$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Preview.text = "技能范围"
	_refresh_detail_text()


func _set_detail_tab(index: int) -> void:
	detail_tab = index
	_scroll_display = 0.0
	_scroll_target = 0.0
	details.get_v_scroll_bar().value = 0
	_refresh_detail_text()


func _refresh_detail_text() -> void:
	$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Skill.button_pressed = detail_tab == 0
	$Margin/Layout/Body/Picker/Details/Content/DetailTabs/Passive.button_pressed = detail_tab == 1
	if preview_id.is_empty(): return
	var operator := OperatorDB.get_data(preview_id)
	if detail_tab == 1:
		var muted := PALETTE.MUTED_TEXT.to_html(false)
		var paragraphs := PackedStringArray(["[color=#%s]基础属性[/color]" % muted, "生命 %d   攻击 %d\n防御 %d   法抗 %d%%\n阻挡 %d   攻击间隔 %.2f 秒\n再部署 %.0f 秒" % [operator.max_health, operator.attack, operator.defense, operator.magic_resist, operator.block_count, operator.attack_interval, operator.redeploy_time], "\n[color=#%s]特性 · %s[/color]" % [muted, operator.branch_trait.trait_name], operator.branch_trait.description])
		for talent in [operator.talent_1, operator.talent_2]:
			paragraphs.append("\n[color=#%s]%s · %s[/color]" % [muted, talent.talent_name, ("编队初始化生效" if talent.effect_type=="initial_cost" else "部署后生效") if SkillRules.talent_is_active(talent) else ("原作无此天赋" if talent.effect_type=="none" else "本作无适用机制")])
			paragraphs.append(talent.description)
		details.text = "\n".join(paragraphs)
		return
	var paragraphs := PackedStringArray()
	var skill := operator.skills[preview_skill]
	paragraphs.append("\n[color=#%s]技能 %d · %s[/color]" % [PALETTE.BLUE.to_html(false), preview_skill + 1, skill.skill_name])
	paragraphs.append("自动触发" if SkillRules.is_auto_trigger(skill) else ("被动 · 部署即生效" if skill.sp_recharge_type == "passive" else "手动触发"))
	paragraphs.append(("无技力消耗 · 部署起 %.0f 秒" % skill.duration if skill.duration > 0 else "无技力消耗 · 持续至撤退") if skill.sp_recharge_type == "passive" else ("每次切换消耗 %d 技力" % skill.sp_required if skill.effect_type == "stance_defense_regen" else ("技力消耗 %d · 持续无限" % skill.sp_required if skill.duration < 0 else "技力消耗 %d · 持续 %.0f 秒" % [skill.sp_required, skill.duration])))
	paragraphs.append(skill.description)
	details.text = "\n".join(paragraphs)


func _select_operator(operator_id: String) -> void:
	if quick_mode:
		if draft.has(operator_id):
			var slot := draft.find(operator_id)
			draft.remove_at(slot)
			draft_skills.remove_at(slot)
		elif draft.size() >= SLOT_COUNT:
			_preview(operator_id)
			status.text = "最多编入十二名干员"
			status.show()
			return
		else:
			draft.append(operator_id)
			draft_skills.append(int(draft_memory.get(operator_id,0)))
		_refresh_roster()
		_preview(operator_id)
		return
	_preview(operator_id)
	if draft.has(operator_id) and (selected_slot >= draft.size() or draft[selected_slot] != operator_id):
		status.text = "该干员已编入其他槽位"
		status.show()
		return
	if selected_slot < draft.size():
		if draft[selected_slot] != operator_id:
			draft_skills[selected_slot] = int(draft_memory.get(operator_id,0))
		draft[selected_slot] = operator_id
	else:
		draft.append(operator_id)
		draft_skills.append(int(draft_memory.get(operator_id,0)))
	_save()
	_show_overview()


func _request_back() -> void:
	if quick_mode:
		draft = squad.operator_ids.duplicate()
		draft_skills = squad.skill_indices.duplicate()
		draft_memory = squad.skill_memory.duplicate()
		_show_overview()
	elif selected_slot >= 0:
		_show_overview()
	elif draft.is_empty():
		exit_prompt.show()
		$ExitPrompt/Center/Panel/Content/Actions/Keep.grab_focus()
	else:
		_back()


func _save() -> void:
	squad.operator_ids = draft.duplicate()
	squad.skill_indices = draft_skills.duplicate()
	squad.skill_memory = draft_memory.duplicate()
	var error: String = squad.write(SquadConfig.FILE_PATH, true)
	if not error.is_empty():
		push_error(error)
		get_tree().quit(1)


func _back() -> void:
	if embedded:
		closed.emit()
		queue_free()
		return
	var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
	assert(error == OK, "Cannot return from squad menu")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if clear_prompt.visible:
			clear_prompt.hide()
			clear_button.grab_focus()
		elif exit_prompt.visible:
			exit_prompt.hide()
			$Margin/Layout/Header/Back.grab_focus()
		elif sort_sidebar.visible:
			_set_sort_sidebar(false)
			sort_button.grab_focus()
		elif profession_sidebar.visible:
			_set_profession_sidebar(false)
		else:
			_request_back()
	elif picker.visible and not exit_prompt.visible and not clear_prompt.visible and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var direction := -1 if event.keycode == KEY_PAGEUP else 1
		roster_scroll.scroll_horizontal += roundi(direction * roster_scroll.size.x * 0.9)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not picker.visible or exit_prompt.visible or clear_prompt.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and roster_scroll.get_global_rect().has_point(event.position):
			_roster_held = true
			_roster_dragged = false
			_roster_press_position = event.position
			_roster_press_scroll = roster_scroll.scroll_horizontal
			_roster_pressed_id = ""
			for button in roster.get_children():
				if button.get_global_rect().has_point(event.position):
					_roster_pressed_id = str(button.name)
					break
			get_viewport().set_input_as_handled()
		elif not event.pressed and _roster_held:
			_roster_held = false
			get_viewport().set_input_as_handled()
			if not _roster_dragged and not _roster_pressed_id.is_empty() and roster_scroll.get_global_rect().has_point(event.position) and roster.get_node(_roster_pressed_id).get_global_rect().has_point(event.position):
				_select_operator(_roster_pressed_id)
	elif event is InputEventMouseMotion and _roster_held:
		if event.position.distance_to(_roster_press_position) >= PALETTE.SQUAD_ROSTER_DRAG_THRESHOLD:
			_roster_dragged = true
		if _roster_dragged:
			roster_scroll.scroll_horizontal = _roster_press_scroll + roundi(_roster_press_position.x - event.position.x)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_roster_held = false



func _process(delta: float) -> void:
	if picker.visible:
		_scroll_display = lerpf(_scroll_display, _scroll_target, 1.0 - exp(-PALETTE.INFO_SCROLL_SPEED * delta))
		details.get_v_scroll_bar().value = _scroll_display


func _draw_card(button: Button, operator_id: String, skill_index: int, number: String = "", assigned: bool = false) -> void:
	if not operator_id.is_empty():
		CARD_VISUAL.draw_squad(button, Rect2(Vector2.ONE * 2, button.size - Vector2.ONE * 4), OperatorDB.get_data(operator_id), skill_index, number, assigned)
		return
	var center := button.size * Vector2(0.5, 0.42)
	button.draw_line(center - Vector2(18, 0), center + Vector2(18, 0), PALETTE.MUTED_TEXT, 2, true)
	button.draw_line(center - Vector2(0, 18), center + Vector2(0, 18), PALETTE.MUTED_TEXT, 2, true)
	var font := ThemeDB.fallback_font
	var text := "添加干员"
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	button.draw_string(font, Vector2((button.size.x - text_width) / 2, button.size.y - 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PALETTE.MUTED_TEXT)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PALETTE.BACKGROUND)


func _select_skill(index: int) -> void:
	var slot := draft.find(preview_id)
	if slot < 0 or (not quick_mode and slot != selected_slot):
		return
	draft_skills[slot] = index
	draft_memory[preview_id] = index
	if not quick_mode:
		_save()
	_preview(preview_id)
