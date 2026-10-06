class_name MatchView
extends Node2D

signal home_requested
signal room_requested

const CONFIG := preload("res://data/config.gd")
const ARENA := preload("res://resources/map/standard_arena.tres")
const BALL_DATA := preload("res://resources/ball/standard.tres")
const PALETTE := preload("res://view/palette.gd")
const RANGE := preload("res://sim/attack_range.gd")
const PHANTOM := preload("res://resources/summons/nightingale_phantom.tres")

enum DeployPhase { IDLE, DRAGGING, FACING }
enum InfoTab { COMMAND, PROFILE, PASSIVE, SKILL }

var _state: MatchState
var _local_input: LocalInput
var _operator_data: Dictionary
var _operator_ids: PackedStringArray
var _hovered_cell := Vector2i(-1, -1)
var _pointer_position := Vector2.ZERO
var _deploy_phase := DeployPhase.IDLE
var _preview_cell := Vector2i(-1, -1)
var _preview_facing := 2
var _facing_drag := false
var _info_tab := InfoTab.COMMAND
var _info_scroll := 0
var _info_scroll_display := 0.0
var multiplayer_match := false
var result_confirmed := true
var mirror_board := false


func bind(state: MatchState, local_input: LocalInput, operator_data: Dictionary) -> void:
	_state = state
	_local_input = local_input
	_operator_data = operator_data.duplicate()
	_operator_data["nightingale_phantom"] = PHANTOM
	_operator_ids = PackedStringArray(operator_data.keys())
	_operator_ids.sort()
	queue_redraw()


func _process(delta: float) -> void:
	_info_scroll_display = lerpf(_info_scroll_display, float(_info_scroll), 1.0 - exp(-PALETTE.INFO_SCROLL_SPEED * delta))
	if absf(_info_scroll_display - _info_scroll) < 0.05:
		_info_scroll_display = float(_info_scroll)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _state.result != MatchState.RESULT_RUNNING:
		if result_confirmed and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _result_home_rect().has_point(event.position):
				home_requested.emit()
			elif multiplayer_match and _result_room_rect().has_point(event.position):
				room_requested.emit()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_deploy()
		elif event.keycode == KEY_SPACE and _deploy_phase == DeployPhase.IDLE:
			_activate_selected_skill()
		return
	if event is InputEventMouseMotion:
		_pointer_position = event.position
		_hovered_cell = _screen_to_cell(event.position)
		if _deploy_phase == DeployPhase.DRAGGING:
			_preview_cell = _hovered_cell
		elif _deploy_phase == DeployPhase.FACING and _facing_drag:
			var drag := _view_direction(event.position - _cell_rect(_preview_cell).get_center())
			if drag.length() >= PALETTE.CELL_SIZE * 0.3:
				_preview_facing = (0 if drag.x > 0 else 2) if absf(drag.x) >= absf(drag.y) else (1 if drag.y > 0 else 3)
		return
	if not event is InputEventMouseButton:
		return
	_pointer_position = event.position
	var cell := _screen_to_cell(event.position)
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _info_tab != InfoTab.COMMAND:
		if Rect2(Vector2(PALETTE.HUD_ORIGIN), Vector2(PALETTE.HUD_WIDTH, 396)).has_point(event.position):
			_info_scroll = maxi(0, _info_scroll + (-36 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 36))
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _deploy_phase != DeployPhase.IDLE:
			_cancel_deploy()
		else:
			var unit := _unit_at_cell(cell, _local_input.side)
			if unit != null:
				_local_input.queue_retreat(_state.tick, unit.unit_id)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		if _deploy_phase == DeployPhase.DRAGGING:
			_preview_cell = cell
			if _preview_is_legal():
				if _local_input.selected_operator_id == "nightingale_phantom":
					_confirm_deploy()
				else:
					_deploy_phase = DeployPhase.FACING
			else:
				_cancel_deploy()
		elif _deploy_phase == DeployPhase.FACING and _facing_drag:
			_facing_drag = false
			var drag := _view_direction(event.position - _cell_rect(_preview_cell).get_center())
			if drag.length() >= PALETTE.CELL_SIZE * 0.8:
				_preview_facing = (0 if drag.x > 0 else 2) if absf(drag.x) >= absf(drag.y) else (1 if drag.y > 0 else 3)
				_confirm_deploy()
		return
	for tab_index in 4:
		if _tab_rect(tab_index).has_point(event.position):
			_info_tab = tab_index
			_info_scroll = 0
			_info_scroll_display = 0.0
			return
	if _cancel_rect().has_point(event.position):
		if _deploy_phase != DeployPhase.IDLE:
			_cancel_deploy()
		else:
			var selected := _selected_unit()
			if selected != null and selected.side == _local_input.side:
				_local_input.queue_retreat(_state.tick, selected.unit_id)
		return
	if _skill_rect().has_point(event.position) and _deploy_phase == DeployPhase.FACING:
		_confirm_deploy()
		return
	if _skill_rect().has_point(event.position) and _deploy_phase == DeployPhase.IDLE:
		_activate_selected_skill()
		return
	if Rect2(Vector2(PALETTE.HUD_ORIGIN), Vector2(PALETTE.HUD_WIDTH, 396)).has_point(event.position):
		return
	if _deploy_phase == DeployPhase.FACING:
		if _cell_rect(_preview_cell).grow(PALETTE.CELL_SIZE * 0.35).has_point(event.position):
			_facing_drag = true
		return
	var tray_ids := _tray_operator_ids()
	for index in tray_ids.size():
		if _card_rect(index).has_point(event.position):
			var operator_id := tray_ids[index]
			var operator := _operator_data[operator_id] as OperatorData
			if _operator_available(operator):
				_info_tab = InfoTab.COMMAND
				_info_scroll = 0
				_info_scroll_display = 0.0
				_local_input.select_operator(operator_id)
				_deploy_phase = DeployPhase.DRAGGING
				_preview_cell = cell
				_preview_facing = 2 if _local_input.side == 0 else 0
			return
	var selected_unit := _unit_at_cell(cell)
	if selected_unit != null:
		_local_input.select_unit(selected_unit.unit_id)
		_info_scroll = 0
		_info_scroll_display = 0.0
	else:
		_local_input.clear_selection()


func _draw() -> void:
	var visual_tick := float(_state.tick) + Engine.get_physics_interpolation_fraction()
	var own_color := PALETTE.BLUE if _local_input.side == 0 else PALETTE.RED
	var enemy_color := PALETTE.RED if _local_input.side == 0 else PALETTE.BLUE
	var cell_size := float(PALETTE.CELL_SIZE)
	draw_rect(Rect2(Vector2.ZERO, Vector2(PALETTE.SCREEN_SIZE)), PALETTE.BACKGROUND)
	_draw_text(Vector2(PALETTE.BOARD_ORIGIN.x, 40), "RIFT / DUEL", 24, PALETTE.TEXT)
	_draw_text(Vector2(PALETTE.BOARD_ORIGIN.x + 184, 40), "TACTICAL ARENA", 14, PALETTE.MUTED_TEXT)
	var own_goal_left := (_local_input.side == 1) != mirror_board
	_draw_text(Vector2(PALETTE.HUD_ORIGIN.x, 40), "本方 · %s  /  进球目标：%s侧" % ["蓝方" if _local_input.side == 0 else "红方", "右" if own_goal_left else "左"], 16, own_color)
	for row in CONFIG.GRID_ROWS:
		for column in CONFIG.GRID_COLUMNS:
			var cell := Vector2i(column, row)
			var terrain := ARENA.terrain_at(cell)
			var color := PALETTE.BACKGROUND
			if terrain == "ground" or terrain == "ground_no_deploy":
				color = PALETTE.GROUND
			elif terrain == "high":
				color = PALETTE.HIGH
			draw_rect(_cell_rect(cell), color)
			if terrain == "high":
				var platform := _cell_rect(cell).grow(-cell_size * 0.1)
				draw_rect(platform, PALETTE.ARENA_GRID, false, 1.0)
				draw_line(platform.position, platform.position + Vector2(platform.size.x, 0), PALETTE.PLATFORM_EDGE, 2.0)
				draw_line(platform.position, platform.position + Vector2(0, platform.size.y), PALETTE.PLATFORM_EDGE, 1.0)
				draw_rect(Rect2(platform.position + Vector2(0, platform.size.y - cell_size * 0.08), Vector2(platform.size.x, cell_size * 0.08)), PALETTE.HUD_SURFACE)
			elif terrain == "ground_no_deploy":
				var mark := _cell_rect(cell).grow(-6)
				for edge in [Vector2.RIGHT, Vector2.DOWN]:
					for segment in 3:
						var start: Vector2 = mark.position + edge * segment * mark.size.x / 3.0
						draw_line(start, start + edge * mark.size.x / 6.0, Color(PALETTE.ARROW, 0.5), 1.0)
						var opposite := Vector2(0, mark.size.y) if edge == Vector2.RIGHT else Vector2(mark.size.x, 0)
						draw_line(start + opposite, start + opposite + edge * mark.size.x / 6.0, Color(PALETTE.ARROW, 0.5), 1.0)
	if _deploy_phase != DeployPhase.IDLE:
		var operator := _operator_data[_local_input.selected_operator_id] as OperatorData
		if _deploy_phase == DeployPhase.DRAGGING:
			for row in CONFIG.GRID_ROWS:
				for column in CONFIG.GRID_COLUMNS:
					var cell := Vector2i(column, row)
					var legal := _state.phantom_can_deploy(_local_input.side, cell) if operator.operator_id == "nightingale_phantom" else DeployRules.is_legal(_local_input.side, operator, cell, _state.ball.cell, _state.units, _state.sides[_local_input.side], ARENA)
					if legal:
						draw_rect(_cell_rect(cell).grow(-2), PALETTE.LEGAL)
		if _preview_cell.x >= 0:
			_draw_range(operator, _preview_cell, _preview_facing)
	var selected := _selected_unit()
	if selected != null:
		_draw_range(_operator_data[selected.operator_id] as OperatorData, selected.cell, selected.facing)
	for column in CONFIG.GRID_COLUMNS + 1:
		var x := PALETTE.BOARD_ORIGIN.x + column * PALETTE.CELL_SIZE
		draw_line(Vector2(x, PALETTE.BOARD_ORIGIN.y), Vector2(x, PALETTE.BOARD_ORIGIN.y + PALETTE.BOARD_SIZE.y), PALETTE.ARENA_GRID)
	for row in CONFIG.GRID_ROWS + 1:
		var y := PALETTE.BOARD_ORIGIN.y + row * PALETTE.CELL_SIZE
		draw_line(Vector2(PALETTE.BOARD_ORIGIN.x, y), Vector2(PALETTE.BOARD_ORIGIN.x + PALETTE.BOARD_SIZE.x, y), PALETTE.ARENA_GRID)
	draw_rect(_goal_line(0), PALETTE.BLUE)
	draw_rect(_goal_line(1), PALETTE.RED)
	var boundary_x := _cell_rect(_state.ball.cell).get_center().x
	draw_line(Vector2(boundary_x, PALETTE.BOARD_ORIGIN.y), Vector2(boundary_x, PALETTE.BOARD_ORIGIN.y + PALETTE.BOARD_SIZE.y), Color(PALETTE.BALL, 0.18), 2.0)
	for unit in _state.units:
		var operator := _operator_data[unit.operator_id] as OperatorData
		var unit_rect := _cell_rect(unit.cell).grow(-cell_size * PALETTE.UNIT_INSET_RATIO)
		var attack_age := visual_tick - unit.last_attack_tick
		var damage_age := visual_tick - unit.last_damage_tick
		if unit.last_attack_tick >= 0 and attack_age >= 0.0 and attack_age < 8.0:
			var attack_direction := _view_direction(Vector2(unit.last_attack_target_x, unit.last_attack_target_y) - Vector2(unit.cell)).normalized()
			unit_rect.position += attack_direction * sin(attack_age / 8.0 * PI) * cell_size * 0.075
		var unit_color := PALETTE.BLUE if unit.side == 0 else PALETTE.RED
		if unit.last_damage_tick >= 0 and damage_age >= 0.0 and damage_age < 8.0:
			var progress := damage_age / 8.0
			unit_rect.position.x += sin(progress * TAU * 2.0) * (1.0 - progress) * cell_size * 0.045
			unit_color = unit_color.lerp(PALETTE.BALL, (1.0 - progress) * 0.7)
		draw_rect(Rect2(unit_rect.position + Vector2(2, 4), unit_rect.size), Color(PALETTE.BACKGROUND, 0.65))
		draw_rect(unit_rect, PALETTE.UNIT_SURFACE)
		draw_rect(unit_rect, unit_color, false, 1.5)
		if unit.operator_id == "nightingale_phantom":
			for offset in [-0.22, 0.0, 0.22]:
				var start := unit_rect.get_center() + Vector2(offset * cell_size, -cell_size * 0.28)
				draw_line(start, start + Vector2(0, cell_size * 0.56), Color(PALETTE.HEAL_RANGE, 0.45), 1.0)
		if unit.hp_lock_ticks_left > 0:
			draw_arc(unit_rect.get_center(), cell_size * 0.45, 0, TAU, 24, Color(PALETTE.ARROW, 0.55), 2.0, true)
		var block_age := visual_tick - unit.last_damage_block_tick
		if unit.last_damage_block_tick >= 0 and block_age >= 0.0 and block_age < 8.0:
			draw_arc(unit_rect.get_center(), cell_size * (0.38 + block_age * 0.025), 0, TAU, 24, Color(PALETTE.HEAL_RANGE, 1.0 - block_age / 8.0), 2.0, true)
		if unit.last_damage_tick >= 0 and damage_age >= 0.0 and damage_age < 8.0:
			draw_rect(unit_rect, Color(PALETTE.BALL, (1.0 - damage_age / 8.0) * 0.35))
		if operator.block_count >= CONFIG.BLOCK_BALL_MIN:
			draw_rect(unit_rect.grow(2), PALETTE.BLOCKER, false, 2.0)
		if unit.unit_id == _local_input.selected_unit_id:
			draw_rect(unit_rect.grow(3), PALETTE.ARROW, false, 2.0)
		var direction := _view_direction(Vector2(RANGE.rotate_offset(Vector2i.RIGHT, unit.facing)))
		var center := unit_rect.get_center()
		var side := Vector2(-direction.y, direction.x)
		var facing_tip := center + direction * cell_size * PALETTE.UNIT_DIRECTION_RATIO
		if unit.operator_id != "nightingale_phantom":
			draw_colored_polygon(PackedVector2Array([facing_tip, facing_tip - direction * cell_size * 0.13 + side * cell_size * 0.075, facing_tip - direction * cell_size * 0.13 - side * cell_size * 0.075]), unit_color)
		var hp_back := Rect2(unit_rect.position - Vector2(0, 4), Vector2(unit_rect.size.x, 3))
		draw_rect(hp_back, PALETTE.GROUND)
		draw_rect(Rect2(hp_back.position, Vector2(hp_back.size.x * float(unit.hp) / SkillRules.max_health_value(unit, operator), 3)), PALETTE.RED)
		var skill := operator.skills[0]
		if SkillRules.sp_limit(skill) > 0 or skill.effect_type == "passive_heal":
			var sp_back := Rect2(unit_rect.position + Vector2(0, unit_rect.size.y), Vector2(unit_rect.size.x, 3))
			draw_rect(sp_back, PALETTE.GROUND)
			draw_rect(Rect2(sp_back.position, Vector2(sp_back.size.x * _skill_bar_ratio(unit, skill), 3)), PALETTE.ARROW if unit.skill_ticks_left > 0 or skill.effect_type == "passive_heal" else PALETTE.BLUE)
			if skill.effect_type == "passive_heal":
				for slot in int(skill.effect_params["coin_limit"]):
					var coin_center := sp_back.position + Vector2((slot + 0.5) * sp_back.size.x / int(skill.effect_params["coin_limit"]), cell_size * 0.16)
					draw_circle(coin_center, cell_size * 0.065, PALETTE.ARROW if slot < unit.coins else PALETTE.DISABLED)
		if unit.skill_ticks_left != 0:
			draw_rect(unit_rect.grow(1), PALETTE.ARROW, false, 1.5)
		if unit.bind_ticks_left > 0:
			draw_line(unit_rect.position, unit_rect.end, PALETTE.HEAL_RANGE, 2.0)
		var name := operator.display_name.left(2)
		var name_width := ThemeDB.fallback_font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, PALETTE.UNIT_NAME_SIZE).x
		_draw_text(center + Vector2(-name_width * 0.5, PALETTE.UNIT_NAME_SIZE * 0.35), name, PALETTE.UNIT_NAME_SIZE, PALETTE.MUTED_TEXT)
	for unit in _state.units:
		var center := _cell_rect(unit.cell).get_center()
		var coin_age := visual_tick - unit.last_coin_gain_tick
		if unit.last_coin_gain_tick >= 0 and coin_age >= 0.0 and coin_age < 12.0:
			var progress := coin_age / 12.0
			var coin_center := center + Vector2(cell_size * 0.3, -cell_size * (0.25 + progress * 0.4))
			draw_circle(coin_center, cell_size * 0.1, Color(PALETTE.ARROW, 1.0 - progress))
			draw_line(coin_center - Vector2(0, cell_size * 0.06), coin_center + Vector2(0, cell_size * 0.06), Color(PALETTE.BACKGROUND, 1.0 - progress), cell_size * 0.04, true)
		var attack_age := visual_tick - unit.last_attack_tick
		if unit.last_attack_tick >= 0 and attack_age >= 0.0 and attack_age < 8.0:
			var operator := _operator_data[unit.operator_id] as OperatorData
			var target := _cell_rect(Vector2i(unit.last_attack_target_x, unit.last_attack_target_y)).get_center()
			var progress := attack_age / 8.0
			var opacity := 1.0 - progress
			var direction := (target - center).normalized()
			if unit.last_attack_is_heal or operator.damage_type == "healing":
				draw_arc(center, cell_size * (0.25 + progress * 0.35), 0.0, TAU, 24, Color(PALETTE.HEAL_RANGE, opacity * 0.85), cell_size * 0.045, true)
				draw_line(center, target, Color(PALETTE.HEAL_RANGE, opacity * 0.35), cell_size * 0.035, true)
				if unit.last_coin_spend_tick == unit.last_attack_tick:
					var coin_center := center.lerp(target, minf(1.0, progress * 1.5)) - Vector2(0, sin(progress * PI) * cell_size * 0.2)
					draw_circle(coin_center, cell_size * 0.1, Color(PALETTE.ARROW, opacity))
					draw_arc(target, cell_size * (0.15 + progress * 0.3), 0.0, TAU, 24, Color(PALETTE.HEAL_RANGE, opacity), cell_size * 0.055, true)
			elif operator.damage_type == "magical":
				var head := center.lerp(target, minf(1.0, progress * 1.8))
				draw_line(center.lerp(head, 0.5), head, Color(PALETTE.HEAL_RANGE, opacity * 0.9), cell_size * 0.075, true)
				draw_circle(head, cell_size * 0.09, Color(PALETTE.HEAL_RANGE, opacity * 0.9))
				draw_arc(target, cell_size * (0.12 + progress * 0.35), 0.0, TAU, 24, Color(PALETTE.HEAL_RANGE, opacity * 0.5), cell_size * 0.035, true)
			elif center.distance_to(target) > cell_size * 1.5:
				var head := center.lerp(target, minf(1.0, progress * 1.8))
				var tail := head - direction * minf(cell_size * 0.35, center.distance_to(head))
				draw_line(tail, head, Color(PALETTE.ARROW, opacity * 0.85), cell_size * 0.06, true)
				draw_circle(head, cell_size * 0.055, Color(PALETTE.BALL, opacity * 0.75))
			else:
				var angle := direction.angle() - 0.8 + progress * 0.8
				draw_arc(center + direction * cell_size * 0.12, cell_size * (0.42 + progress * 0.14), angle, angle + 1.25, 12, Color(PALETTE.ARROW, opacity * 0.75), cell_size * 0.075, true)
		var damage_age := visual_tick - unit.last_damage_tick
		if unit.last_damage_tick >= 0 and damage_age >= 0.0 and damage_age < 8.0:
			var progress := damage_age / 8.0
			draw_arc(center, cell_size * (0.38 + progress * 0.2), 0.0, TAU, 24, Color(PALETTE.RED, (1.0 - progress) * 0.65), cell_size * 0.04, true)
		var heal_age := visual_tick - unit.last_heal_tick
		if unit.last_heal_tick >= 0 and heal_age >= 0.0 and heal_age < 8.0:
			var progress := heal_age / 8.0
			var cross_center := center + Vector2(cell_size * 0.28, -cell_size * (0.1 + progress * 0.4))
			var radius := cell_size * 0.09
			var color := Color(PALETTE.HEAL_RANGE, (1.0 - progress) * 0.9)
			draw_line(cross_center - Vector2(radius, 0), cross_center + Vector2(radius, 0), color, cell_size * 0.065, true)
			draw_line(cross_center - Vector2(0, radius), cross_center + Vector2(0, radius), color, cell_size * 0.065, true)
	if _deploy_phase != DeployPhase.IDLE:
		var center := _pointer_position if _preview_cell.x < 0 else _cell_rect(_preview_cell).get_center()
		var preview := Rect2(center - Vector2.ONE * cell_size * 0.35, Vector2.ONE * cell_size * 0.7)
		draw_rect(preview, Color(own_color, 0.55))
		draw_rect(preview, PALETTE.LEGAL if _preview_is_legal() else PALETTE.RED, false, 2.0)
		if _deploy_phase == DeployPhase.FACING:
			for facing in 4:
				var direction := _view_direction(Vector2(RANGE.rotate_offset(Vector2i.RIGHT, facing)))
				var tip := center + direction * cell_size * 1.1
				var side := Vector2(-direction.y, direction.x)
				draw_colored_polygon(PackedVector2Array([tip, tip - direction * cell_size * 0.25 + side * cell_size * 0.14, tip - direction * cell_size * 0.25 - side * cell_size * 0.14]), PALETTE.ARROW if facing == _preview_facing else PALETTE.DISABLED)
			draw_arc(center, cell_size * 0.82, 0.0, TAU, 48, Color(PALETTE.ARROW, 0.35), 1.5, true)
	var ball_center := _cell_rect(_state.ball.cell).get_center()
	var roll := 0.0
	if _state.ball.move_ticks_left > 0:
		var progress := clampf((CONFIG.BALL_MOVE_TICKS - _state.ball.move_ticks_left + Engine.get_physics_interpolation_fraction()) / CONFIG.BALL_MOVE_TICKS, 0.0, 1.0)
		var travel := progress * progress * (3.0 - 2.0 * progress)
		if _state.ball_move_is_blocked():
			travel = sin(progress * PI) * 0.22
		else:
			ball_center.y -= sin(progress * PI) * cell_size * 0.08
		ball_center += _view_direction(Vector2(_state.ball.move_direction)) * cell_size * travel
		roll = travel * TAU
		draw_line(ball_center - _view_direction(Vector2(_state.ball.move_direction)) * cell_size * 0.25, ball_center, Color(PALETTE.BALL, 0.18), cell_size * 0.32, true)
	draw_circle(ball_center + Vector2(1, cell_size * 0.12), cell_size * 0.34, Color(PALETTE.BACKGROUND, 0.7))
	draw_circle(ball_center, cell_size * 0.32, PALETTE.BALL)
	draw_circle(ball_center, cell_size * 0.32, PALETTE.GRID, false, 2.0)
	var seam := Vector2(cos(roll), sin(roll)) * cell_size * 0.22
	draw_line(ball_center - seam, ball_center + seam, Color(PALETTE.GRID, 0.55), 1.5, true)
	if _state.ball.accum != Vector2i.ZERO:
		var ratio := minf(1.0, sqrt(float(_state.ball.accum.length_squared())) / BALL_DATA.kick_threshold)
		var bar := Rect2(ball_center + Vector2(-cell_size * 0.5, cell_size * 0.45), Vector2(cell_size, 4))
		draw_rect(bar, PALETTE.GROUND)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 4)), PALETTE.ARROW)
	var hud := Vector2(PALETTE.HUD_ORIGIN)
	draw_rect(Rect2(hud, Vector2(PALETTE.HUD_WIDTH, PALETTE.BOARD_SIZE.y)), PALETTE.HUD_SURFACE)
	var inspecting_enemy := selected != null and selected.side != _local_input.side
	draw_rect(Rect2(hud, Vector2(4, 396)), enemy_color if inspecting_enemy else own_color)
	_draw_text(hud + Vector2(PALETTE.HUD_PADDING, 30), "敌方干员 · 作战信息" if inspecting_enemy else "作战指令", PALETTE.HUD_TITLE_SIZE, enemy_color if inspecting_enemy else PALETTE.MUTED_TEXT)
	var skill_text := "选择干员查看技能"
	var skill_color := PALETTE.DISABLED
	var cancel_text := "撤退"
	if _info_tab != InfoTab.COMMAND:
		var operator: OperatorData
		if not _local_input.selected_operator_id.is_empty():
			operator = _operator_data[_local_input.selected_operator_id]
		elif selected != null:
			operator = _operator_data[selected.operator_id]
		if operator != null:
			var skill := operator.skills[0]
			var paragraphs := PackedStringArray([operator.display_name])
			if _info_tab == InfoTab.PROFILE:
				paragraphs.append_array(["职业：%s / %s" % [operator.profession, operator.branch], "生命上限 %d   攻击 %d" % [operator.max_health, operator.attack], "防御 %d   法抗 %d%%" % [operator.defense, operator.magic_resist], "阻挡 %d   攻击间隔 %.2f 秒" % [operator.block_count, operator.attack_interval], "部署费用 %d   再部署 %.0f 秒" % [operator.deploy_cost, operator.redeploy_time]])
				if selected != null:
					paragraphs.append_array(["实战生命上限 %d" % SkillRules.max_health_value(selected, operator), "实战攻击 %d · 防御 %d" % [SkillRules.attack_value(selected, operator), SkillRules.defense_value(selected, operator)], "实战法抗 %d%% · 攻击间隔 %.2f 秒" % [SkillRules.magic_resist_value(selected, operator), float(SkillRules.attack_interval_ticks(selected, operator)) / CONFIG.TICK_RATE]])
			elif _info_tab == InfoTab.PASSIVE:
				paragraphs.append_array(["分支特性：" + operator.branch_trait.trait_name, operator.branch_trait.description])
				for talent in [operator.talent_1, operator.talent_2]:
					var status := "已生效" if SkillRules.talent_is_active(talent) else "本作无适用机制"
					paragraphs.append_array([talent.talent_name + "（%s）" % status, talent.description])
			else:
				if skill.effect_type == "no_skill":
					paragraphs.append_array(["无主动技能 / 无技力", skill.description])
				else:
					paragraphs.append_array([skill.skill_name, "自动触发" if SkillRules.is_auto_trigger(skill) else ("被动 · 部署即生效" if skill.sp_recharge_type == "passive" else "手动触发"), "无技力消耗 · 持续至撤退" if skill.sp_recharge_type == "passive" else "技力消耗 %d   持续 %.0f 秒" % [skill.sp_required, maxf(0.0, skill.duration)], skill.description])
			var lines := PackedStringArray()
			var line_offsets := PackedInt32Array()
			var content_height := 0
			for paragraph in paragraphs:
				var line := ""
				for character in paragraph:
					if character == "\n" or (not line.is_empty() and ThemeDB.fallback_font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, PALETTE.INFO_FONT_SIZE).x > PALETTE.HUD_WIDTH - 40):
						lines.append(line)
						line_offsets.append(content_height)
						content_height += PALETTE.INFO_LINE_HEIGHT
						line = ""
					if character != "\n":
						line += character
				lines.append(line)
				line_offsets.append(content_height)
				content_height += PALETTE.INFO_LINE_HEIGHT + PALETTE.INFO_PARAGRAPH_GAP
			content_height -= PALETTE.INFO_PARAGRAPH_GAP
			var body := Rect2(hud + Vector2(20, 86), Vector2(PALETTE.HUD_WIDTH - 40, 188))
			_info_scroll = mini(_info_scroll, maxi(0, content_height - int(body.size.y)))
			_info_scroll_display = minf(_info_scroll_display, maxf(0.0, content_height - body.size.y))
			for index in lines.size():
				var y := body.position.y + 17 + line_offsets[index] - _info_scroll_display
				if y >= body.position.y - PALETTE.INFO_LINE_HEIGHT and y <= body.end.y + PALETTE.INFO_LINE_HEIGHT:
					_draw_text(Vector2(body.position.x, y), lines[index], PALETTE.INFO_FONT_SIZE, PALETTE.TEXT if index == 0 else PALETTE.MUTED_TEXT)
			draw_rect(Rect2(body.position - Vector2(1, PALETTE.INFO_LINE_HEIGHT * 2), Vector2(body.size.x + 2, PALETTE.INFO_LINE_HEIGHT * 2)), PALETTE.HUD_SURFACE)
			draw_rect(Rect2(Vector2(body.position.x - 1, body.end.y), Vector2(body.size.x + 2, PALETTE.INFO_LINE_HEIGHT * 2)), PALETTE.HUD_SURFACE)
			if content_height > body.size.y:
				var scroll_track := Rect2(Vector2(body.end.x + 8, body.position.y), Vector2(2, body.size.y))
				var thumb_height := body.size.y * body.size.y / content_height
				var thumb_y := (body.size.y - thumb_height) * _info_scroll_display / (content_height - body.size.y)
				draw_rect(scroll_track, PALETTE.HUD_RULE)
				draw_rect(Rect2(scroll_track.position + Vector2(0, thumb_y), Vector2(2, thumb_height)), PALETTE.MUTED_TEXT)
		else:
			_draw_text(hud + Vector2(20, 120), "选择干员查看信息", 17, PALETTE.MUTED_TEXT)
		if _deploy_phase != DeployPhase.IDLE:
			cancel_text = "撤退 / 取消部署"
			if _deploy_phase == DeployPhase.FACING:
				skill_text = "确认部署"
				skill_color = PALETTE.BLUE if _preview_is_legal() else PALETTE.DISABLED
		elif selected != null:
			skill_text = "敌方干员 · 仅查看" if inspecting_enemy else "返回作战页操作技能"
			cancel_text = "不可撤退" if inspecting_enemy else "撤退"
	elif _deploy_phase != DeployPhase.IDLE:
		var operator := _operator_data[_local_input.selected_operator_id] as OperatorData
		_draw_text(hud + Vector2(20, 104), operator.display_name, 24, PALETTE.TEXT)
		_draw_text(hud + Vector2(20, 132), "%s · 部署费用 %d" % [operator.profession, operator.deploy_cost], 16, PALETTE.MUTED_TEXT)
		_draw_text(hud + Vector2(20, 164), "01  拖动至绿色部署格", 16, PALETTE.LEGAL)
		if operator.operator_id == "nightingale_phantom":
			_draw_text(hud + Vector2(20, 196), "02  松手即部署，不需要选择朝向", 16, PALETTE.TEXT)
			_draw_text(hud + Vector2(20, 228), "吸引火力 · 不攻击 · 不可治疗", 16, PALETTE.MUTED_TEXT)
		else:
			_draw_text(hud + Vector2(20, 196), "02  松手后，从干员向外拖动", 16, PALETTE.TEXT)
			_draw_text(hud + Vector2(20, 228), "03  松手确认朝向并完成部署", 16, PALETTE.MUTED_TEXT)
		_draw_text(hud + Vector2(20, 260), "确认前不消耗部署费用", 14, PALETTE.MUTED_TEXT)
		cancel_text = "撤退 / 取消部署"
		skill_text = "拖动干员至部署位置"
		if _deploy_phase == DeployPhase.FACING:
			var display_facing := 2 - _preview_facing if mirror_board and _preview_facing % 2 == 0 else _preview_facing
			skill_text = "确认部署 · " + ["向右", "向下", "向左", "向上"][display_facing]
			skill_color = PALETTE.BLUE if _preview_is_legal() else PALETTE.DISABLED
	elif selected != null:
		var operator := _operator_data[selected.operator_id] as OperatorData
		var skill := operator.skills[0]
		_draw_text(hud + Vector2(20, 104), operator.display_name, 24, PALETTE.TEXT)
		var max_health := SkillRules.max_health_value(selected, operator)
		_draw_text(hud + Vector2(20, PALETTE.HUD_HEALTH_TEXT_Y), "生命  %d / %d" % [selected.hp, max_health], 16, PALETTE.TEXT)
		var hp_bar := Rect2(hud + Vector2(20, PALETTE.HUD_HEALTH_TEXT_Y + PALETTE.HUD_STATUS_BAR_GAP), Vector2(PALETTE.HUD_WIDTH - 40, 4))
		draw_rect(hp_bar, PALETTE.HUD_RULE)
		draw_rect(Rect2(hp_bar.position, Vector2(hp_bar.size.x * float(selected.hp) / max_health, hp_bar.size.y)), PALETTE.RED)
		if operator.operator_id == "nightingale_phantom":
			var taunt := int(operator.branch_trait.effect_params["taunt_level"])
			_draw_text(hud + Vector2(20, PALETTE.HUD_HEALTH_TEXT_Y + PALETTE.HUD_STATUS_ROW_GAP), "嘲讽 +%d · 物理闪避 %d%%" % [taunt, operator.dodge_physical], 16, Color(PALETTE.HEAL_RANGE, 1.0))
		elif skill.effect_type == "passive_heal":
			_draw_text(hud + Vector2(20, PALETTE.HUD_HEALTH_TEXT_Y + PALETTE.HUD_STATUS_ROW_GAP), "金币  %d / %d" % [selected.coins, int(skill.effect_params["coin_limit"])], 16, PALETTE.ARROW)
			for slot in int(skill.effect_params["coin_limit"]):
				draw_circle(hud + Vector2(PALETTE.HUD_WIDTH - 58 + slot * 16, PALETTE.HUD_HEALTH_TEXT_Y + PALETTE.HUD_STATUS_ROW_GAP - 5), 4, PALETTE.ARROW if slot < selected.coins else PALETTE.HUD_RULE)
		elif selected.skill_ticks_left > 0:
			_draw_text(hud + Vector2(20, PALETTE.HUD_HEALTH_TEXT_Y + PALETTE.HUD_STATUS_ROW_GAP), "持续时间  %.1f / %.0f 秒" % [maxf(0.0, selected.skill_ticks_left - Engine.get_physics_interpolation_fraction()) / CONFIG.TICK_RATE, skill.duration], 16, PALETTE.ARROW)
		else:
			_draw_text(hud + Vector2(20, PALETTE.HUD_HEALTH_TEXT_Y + PALETTE.HUD_STATUS_ROW_GAP), "技力  %d / %d" % [selected.sp, skill.sp_required], 16, PALETTE.BLUE)
		if operator.operator_id == "nightingale_phantom":
			skill_text = "幻影 · 不攻击 / 不可治疗"
			_draw_text(hud + Vector2(20, PALETTE.HUD_DETAIL_TEXT_Y), "法抗 %d%% · 持续失去生命" % SkillRules.magic_resist_value(selected, operator), 15, PALETTE.MUTED_TEXT)
		elif skill.sp_recharge_type == "passive":
			skill_text = "被动治疗 · 自动消耗金币"
		elif selected.skill_ticks_left > 0:
			skill_text = "技能生效 · 剩余 %ds" % ceili(float(selected.skill_ticks_left) / CONFIG.TICK_RATE)
		elif selected.skill_ticks_left == -1:
			skill_text = "下次攻击已强化"
		elif SkillRules.is_auto_trigger(skill):
			skill_text = ("技能就绪" if inspecting_enemy else "自动触发 · 等待攻击条件") if SkillRules.can_activate(selected, skill) else "自动触发 · 技力回复中"
		elif SkillRules.can_manually_activate(selected, skill):
			skill_text = "技能就绪" if inspecting_enemy else "释放技能 · 空格 / 点击"
			skill_color = PALETTE.DISABLED if inspecting_enemy else PALETTE.BLUE
		else:
			skill_text = "技力回复中"
		if skill.effect_type == "charge_shot":
			_draw_text(hud + Vector2(20, PALETTE.HUD_DETAIL_TEXT_Y), "充能 %d / %d" % [selected.sp / skill.sp_required, int(skill.effect_params["charge_count"])], 16, PALETTE.ARROW)
		if skill.effect_type == "atk_boost_auto":
			_draw_text(hud + Vector2(20, PALETTE.HUD_DETAIL_TEXT_Y), "技力充满后自动开启", 15, PALETTE.MUTED_TEXT)
		if skill.effect_type == "passive_heal":
			var attack := SkillRules.attack_value(selected, operator)
			var boost := selected.coin_attack_stacks * int(operator.talent_1.effect_params["attack_percent_per_stack"])
			_draw_text(hud + Vector2(20, PALETTE.HUD_DETAIL_TEXT_Y), "攻击 +%d%% · 单次治疗 %d" % [boost, Combat.calculate_healing(attack, int(skill.effect_params["heal_percent"]))], 15, PALETTE.MUTED_TEXT)
			var drain := operator.branch_trait.effect_params
			_draw_text(hud + Vector2(20, PALETTE.HUD_DETAIL_TEXT_Y + PALETTE.HUD_DETAIL_LINE_HEIGHT), "每%.0f秒扣%d费用 · 下次 %.1f秒" % [float(drain["drain_interval"]), int(drain["drain_amount"]), maxf(0.0, float(drain["drain_interval"]) - (selected.cost_drain_ticks + Engine.get_physics_interpolation_fraction()) / CONFIG.TICK_RATE)], 13, PALETTE.MUTED_TEXT)
		if operator.operator_id != "nightingale_phantom":
			var panel_bar := Rect2(hud + Vector2(20, PALETTE.HUD_HEALTH_TEXT_Y + PALETTE.HUD_STATUS_ROW_GAP + PALETTE.HUD_STATUS_BAR_GAP), Vector2(PALETTE.HUD_WIDTH - 40, 5))
			draw_rect(panel_bar, PALETTE.HUD_RULE)
			draw_rect(Rect2(panel_bar.position, Vector2(panel_bar.size.x * _skill_bar_ratio(selected, skill), 5)), PALETTE.ARROW if selected.skill_ticks_left > 0 or skill.effect_type == "passive_heal" else PALETTE.BLUE)
		if inspecting_enemy:
			if skill.effect_type != "passive_heal":
				_draw_text(hud + Vector2(20, PALETTE.HUD_DETAIL_TEXT_Y + PALETTE.HUD_DETAIL_LINE_HEIGHT), skill_text, 15, PALETTE.ARROW)
			skill_text = "敌方干员 · 仅查看"
			skill_color = PALETTE.DISABLED
			cancel_text = "不可撤退"
	else:
		_draw_text(hud + Vector2(20, 104), "拖动卡片 → 位置 → 朝向", 17, PALETTE.TEXT)
		_draw_text(hud + Vector2(20, 140), "点击任意干员查看攻击范围与技能", 15, PALETTE.MUTED_TEXT)
		_draw_text(hud + Vector2(20, 176), "右键撤退 · Esc 取消部署", 15, PALETTE.MUTED_TEXT)
		_draw_text(hud + Vector2(20, 212), "球与黄色箭头指示推进方向", 15, PALETTE.ARROW)
	for tab_index in 4:
		var tab := _tab_rect(tab_index)
		draw_rect(tab, PALETTE.HUD_INSET if _info_tab == tab_index else PALETTE.HUD_SURFACE)
		if _info_tab == tab_index:
			draw_rect(Rect2(tab.position + Vector2(0, tab.size.y - 2), Vector2(tab.size.x, 2)), enemy_color if inspecting_enemy else own_color)
		_draw_text(tab.position + Vector2(10, 20), ["作战", "干员", "被动", "技能"][tab_index], 14, PALETTE.TEXT if _info_tab == tab_index else PALETTE.MUTED_TEXT)
	var action_ready := skill_color == PALETTE.BLUE
	draw_rect(_skill_rect(), PALETTE.HUD_HOVER if action_ready and _skill_rect().has_point(_pointer_position) else PALETTE.HUD_INSET)
	if action_ready:
		draw_rect(Rect2(_skill_rect().position, Vector2(3, _skill_rect().size.y)), own_color)
	_draw_text(_skill_rect().position + Vector2(16, 30), skill_text, 16, PALETTE.TEXT if action_ready else PALETTE.MUTED_TEXT)
	draw_rect(_cancel_rect(), PALETTE.HUD_INSET)
	_draw_text(_cancel_rect().position + Vector2(16, 26), cancel_text, 15, PALETTE.MUTED_TEXT if inspecting_enemy else PALETTE.TEXT)
	_draw_text(Vector2(PALETTE.BOARD_ORIGIN.x, 504), "TICK  %05d    对手费用  %02d" % [_state.tick, _state.sides[1 - _local_input.side].cost], 12, PALETTE.MUTED_TEXT)
	var elapsed_seconds := _state.tick / CONFIG.TICK_RATE
	_draw_text(Vector2(PALETTE.BOARD_ORIGIN.x, 530), "TIME  %02d:%02d" % [elapsed_seconds / 60, elapsed_seconds % 60], 18, PALETTE.TEXT)
	var overtime := _state.tick >= CONFIG.MATCH_TICKS and (_state.result == MatchState.RESULT_RUNNING or _state.tick > CONFIG.MATCH_TICKS)
	var remaining := maxi(0, (CONFIG.MATCH_TICKS + (CONFIG.OVERTIME_TICKS if overtime else 0) - _state.tick + CONFIG.TICK_RATE - 1) / CONFIG.TICK_RATE)
	_draw_text(Vector2(PALETTE.BOARD_ORIGIN.x + 200, 530), ("加时  " if overtime else "剩余  ") + "%02d:%02d" % [remaining / 60, remaining % 60], 16, PALETTE.ARROW if overtime else PALETTE.MUTED_TEXT)
	var cost_panel := _cost_rect()
	draw_rect(cost_panel, PALETTE.HUD_SURFACE)
	_draw_text(cost_panel.position + Vector2(14, 26), "待部署干员", 16, PALETTE.MUTED_TEXT)
	var cost_x := cost_panel.end.x - 144
	_draw_text(Vector2(cost_x, cost_panel.position.y + 27), "COST", 14, PALETTE.MUTED_TEXT)
	_draw_text(Vector2(cost_x + 58, cost_panel.position.y + 29), "%02d" % _state.sides[_local_input.side].cost, 26, PALETTE.BALL)
	if _state.sides[_local_input.side].cost == CONFIG.COST_MAX:
		_draw_text(Vector2(cost_x + 94, cost_panel.position.y + 29), "MAX", 12, PALETTE.MUTED_TEXT)
	var cost_bar := Rect2(Vector2(cost_x, cost_panel.end.y - 4), Vector2(124, 2))
	draw_rect(cost_bar, PALETTE.HUD_RULE)
	var cost_progress := 1.0 if _state.sides[_local_input.side].cost == CONFIG.COST_MAX else float(_state.sides[_local_input.side].cost_regen_ticks) / CONFIG.COST_REGEN_TICKS
	draw_rect(Rect2(cost_bar.position, Vector2(cost_bar.size.x * cost_progress, 2)), own_color)
	var tray_ids := _tray_operator_ids()
	for index in tray_ids.size():
		var operator_id := tray_ids[index]
		var operator := _operator_data[operator_id] as OperatorData
		var card := _card_rect(index)
		var available := _operator_available(operator)
		draw_rect(card, PALETTE.HUD_SURFACE)
		draw_rect(Rect2(card.position, Vector2(card.size.x, 3)), own_color if available else PALETTE.GRID)
		var portrait := Rect2(card.position + Vector2(10, 23), Vector2(card.size.x - 20, 57))
		draw_rect(portrait, PALETTE.HUD_INSET)
		var symbol_color := PALETTE.MUTED_TEXT if available else PALETTE.HUD_DISABLED_TEXT
		var center := portrait.get_center()
		var radius := PALETTE.CARD_SYMBOL_RADIUS
		if operator_id == "nightingale_phantom":
			draw_rect(Rect2(center - Vector2(radius * 0.7, radius), Vector2(radius * 1.4, radius * 2)), symbol_color, false, 2.0)
			draw_line(center - Vector2(0, radius), center + Vector2(0, radius), symbol_color, 2.0)
		var vertices := PackedVector2Array()
		match operator.profession:
			"先锋":
				draw_polyline(PackedVector2Array([center + Vector2(-radius, -radius * 0.7), center + Vector2(radius, 0), center + Vector2(-radius, radius * 0.7)]), symbol_color, 2.0, true)
			"近卫":
				draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.45, 0), center + Vector2(0, radius), center + Vector2(-radius * 0.45, 0)]), symbol_color)
			"重装":
				draw_polyline(PackedVector2Array([center + Vector2(-radius * 0.75, -radius), center + Vector2(radius * 0.75, -radius), center + Vector2(radius * 0.75, radius * 0.4), center + Vector2(0, radius), center + Vector2(-radius * 0.75, radius * 0.4), center + Vector2(-radius * 0.75, -radius)]), symbol_color, 2.0, true)
			"狙击":
				draw_circle(center, radius * 0.7, symbol_color, false, 2.0, true)
				draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), symbol_color, 2.0, true)
				draw_line(center - Vector2(0, radius), center + Vector2(0, radius), symbol_color, 2.0, true)
			"术士":
				for vertex in 7:
					vertices.append(center + Vector2.from_angle(vertex * TAU / 6.0) * radius)
				draw_polyline(vertices, symbol_color, 2.0, true)
			"医疗":
				draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), symbol_color, 3.0, true)
				draw_line(center - Vector2(0, radius), center + Vector2(0, radius), symbol_color, 3.0, true)
			"辅助":
				draw_circle(center - Vector2(radius * 0.4, 0), radius * 0.65, symbol_color, false, 2.0, true)
				draw_circle(center + Vector2(radius * 0.4, 0), radius * 0.65, symbol_color, false, 2.0, true)
			"特种":
				draw_rect(Rect2(center - Vector2.ONE * radius * 0.8, Vector2.ONE * radius * 1.6), symbol_color, false, 2.0)
				draw_line(center - Vector2(radius * 0.4, 0), center + Vector2(radius * 0.4, 0), symbol_color, 2.0, true)
		_draw_text(card.position + Vector2(card.size.x - 30, 19), "%02d" % operator.deploy_cost, 18, PALETTE.TEXT if available else PALETTE.HUD_DISABLED_TEXT)
		_draw_text(card.position + Vector2(8, 17), operator.profession, 11, PALETTE.MUTED_TEXT)
		_draw_text(card.position + Vector2(7, 99), operator.display_name, 12, PALETTE.TEXT)
		if operator_id == _local_input.selected_operator_id:
			draw_rect(card, PALETTE.ARROW, false, 2.0)
		var cooldown: int = _state.sides[_local_input.side].phantom_cooldown_ticks if operator_id == "nightingale_phantom" else _state.sides[_local_input.side].cooldowns.get(operator_id, 0)
		if operator_id == "nightingale_phantom":
			var stock_limit := int((_operator_data["nightingale"] as OperatorData).talent_2.effect_params["stock_limit"])
			var stock := _state.sides[_local_input.side].phantom_count
			var stock_text := "%d/%d · 费用不足" % [stock, stock_limit] if _state.sides[_local_input.side].cost < operator.deploy_cost and cooldown == 0 else "持有 %d / %d" % [stock, stock_limit]
			_draw_text(card.position + Vector2(7, 112), stock_text, 10, PALETTE.MUTED_TEXT)
		if cooldown > 0:
			var seconds := ceili(float(cooldown) / CONFIG.TICK_RATE)
			draw_rect(portrait, Color(PALETTE.HUD_SURFACE, 0.85))
			_draw_text(portrait.position + Vector2(17, 36), "%ds" % seconds, 22, PALETTE.ARROW)
		elif not available and operator_id != "nightingale_phantom":
			_draw_text(card.position + Vector2(7, 112), "费用不足", 11, PALETTE.HUD_DISABLED_TEXT)
	var arrow_direction := _state.ball.move_direction
	if arrow_direction == Vector2i.ZERO and _state.ball.accum != Vector2i.ZERO:
		arrow_direction = Vector2i(signi(_state.ball.accum.x), 0) if absi(_state.ball.accum.x) >= absi(_state.ball.accum.y) else Vector2i(0, signi(_state.ball.accum.y))
	if arrow_direction != Vector2i.ZERO:
		var forward := _view_direction(Vector2(arrow_direction))
		var side := Vector2(-forward.y, forward.x)
		var start := ball_center + forward * cell_size * 0.42
		var tip := ball_center + forward * cell_size * 0.9
		draw_line(start, tip, PALETTE.BACKGROUND, 8.0, true)
		draw_line(start, tip, PALETTE.ARROW, 4.0, true)
		draw_colored_polygon(PackedVector2Array([tip + forward * cell_size * 0.2, tip - forward * cell_size * 0.14 + side * cell_size * 0.2, tip - forward * cell_size * 0.14 - side * cell_size * 0.2]), PALETTE.ARROW)
	if _state.result != MatchState.RESULT_RUNNING:
		var text := "平局" if _state.result == MatchState.RESULT_DRAW else ("蓝方胜利" if _state.result == MatchState.RESULT_BLUE_WIN else "红方胜利")
		var color := PALETTE.ARROW if _state.result == MatchState.RESULT_DRAW else (PALETTE.BLUE if _state.result == MatchState.RESULT_BLUE_WIN else PALETTE.RED)
		var center := Vector2(PALETTE.SCREEN_SIZE) * 0.5
		draw_rect(Rect2(Vector2.ZERO, Vector2(PALETTE.SCREEN_SIZE)), Color(PALETTE.BACKGROUND, 0.78))
		var panel := Rect2(center - Vector2(270, 150), Vector2(540, 300))
		draw_rect(panel, PALETTE.HUD_SURFACE)
		draw_rect(panel, color, false, 2.0)
		_draw_text(center + Vector2(-64, -82), text, 32, color)
		var reason := "进球结束" if _state.ball.cell.x <= 0 or _state.ball.cell.x >= CONFIG.GRID_COLUMNS - 1 else ("加时结束" if overtime else "时间结束")
		_draw_text(center + Vector2(-100, -36), "%s · %02d:%02d" % [reason, elapsed_seconds / 60, elapsed_seconds % 60], 18, PALETTE.MUTED_TEXT)
		_draw_text(center + Vector2(-100, 0), "双方结果已核对" if multiplayer_match and result_confirmed else ("正在核对双方结果…" if multiplayer_match else "对局已结束"), 16, PALETTE.MUTED_TEXT)
		for rect in [_result_home_rect(), _result_room_rect()] if multiplayer_match else [_result_home_rect()]:
			draw_rect(rect, PALETTE.HUD_INSET if result_confirmed else PALETTE.HUD_SURFACE)
			draw_rect(rect, color, false, 1.0)
		_draw_text(_result_home_rect().position + Vector2(35, 30), "返回主页", 18, PALETTE.TEXT)
		if multiplayer_match:
			_draw_text(_result_room_rect().position + Vector2(35, 30), "返回房间", 18, PALETTE.TEXT)
			_draw_text(center + Vector2(-154, 128), "返回房间入口后，可重新创建或加入", 14, PALETTE.MUTED_TEXT)


func _result_home_rect() -> Rect2:
	return Rect2(Vector2(PALETTE.SCREEN_SIZE) * 0.5 + Vector2(-190 if multiplayer_match else -90, 40), Vector2(180, 48))


func _result_room_rect() -> Rect2:
	return Rect2(Vector2(PALETTE.SCREEN_SIZE) * 0.5 + Vector2(10, 40), Vector2(180, 48))


func _draw_range(operator: OperatorData, cell: Vector2i, facing: int) -> void:
	var skill := operator.skills[0]
	if skill.effect_type == "passive_heal":
		var radius := int(skill.effect_params["heal_radius"])
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var heal_cell := cell + Vector2i(x, y)
				if (x != 0 or y != 0) and _cell_is_inside(heal_cell):
					draw_rect(_cell_rect(heal_cell).grow(-3), PALETTE.HEAL_RANGE)
	for offset in operator.attack_range:
		var range_cell := cell + RANGE.rotate_offset(offset, facing)
		if _cell_is_inside(range_cell):
			draw_rect(_cell_rect(range_cell).grow(-3), PALETTE.HEAL_RANGE if operator.damage_type == "healing" else PALETTE.ATTACK_RANGE)


func _preview_is_legal() -> bool:
	if _local_input.selected_operator_id == "nightingale_phantom":
		return _state.phantom_can_deploy(_local_input.side, _preview_cell)
	var operator := _operator_data[_local_input.selected_operator_id] as OperatorData
	return DeployRules.is_legal(_local_input.side, operator, _preview_cell, _state.ball.cell, _state.units, _state.sides[_local_input.side], ARENA)


func _confirm_deploy() -> void:
	if _preview_is_legal():
		_local_input.queue_deploy(_state.tick, _preview_cell, _preview_facing)
		_deploy_phase = DeployPhase.IDLE
		_preview_cell = Vector2i(-1, -1)
		_facing_drag = false


func _cancel_deploy() -> void:
	_deploy_phase = DeployPhase.IDLE
	_preview_cell = Vector2i(-1, -1)
	_facing_drag = false
	_local_input.clear_selection()


func _activate_selected_skill() -> void:
	var selected := _selected_unit()
	if selected != null and selected.side == _local_input.side and _info_tab == InfoTab.COMMAND:
		var operator := _operator_data[selected.operator_id] as OperatorData
		if SkillRules.can_manually_activate(selected, operator.skills[0]):
			_local_input.queue_skill(_state.tick, selected.unit_id)


func _operator_available(operator: OperatorData) -> bool:
	if operator.operator_id == "nightingale_phantom":
		return _state.phantom_available(_local_input.side)
	if _state.sides[_local_input.side].cost < operator.deploy_cost or _state.sides[_local_input.side].cooldowns.has(operator.operator_id):
		return false
	for unit in _state.units:
		if unit.operator_id == operator.operator_id and unit.side == _local_input.side:
			return false
	return true


func _screen_to_cell(position: Vector2) -> Vector2i:
	var local := position - Vector2(PALETTE.BOARD_ORIGIN)
	var cell := Vector2i(floori(local.x / PALETTE.CELL_SIZE), floori(local.y / PALETTE.CELL_SIZE))
	if not _cell_is_inside(cell):
		return Vector2i(-1, -1)
	return Vector2i(CONFIG.GRID_COLUMNS - 1 - cell.x, cell.y) if mirror_board else cell


func _cell_is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < CONFIG.GRID_COLUMNS and cell.y >= 0 and cell.y < CONFIG.GRID_ROWS


func _cell_rect(cell: Vector2i) -> Rect2:
	var display_cell := Vector2i(CONFIG.GRID_COLUMNS - 1 - cell.x, cell.y) if mirror_board else cell
	return Rect2(Vector2(PALETTE.BOARD_ORIGIN + display_cell * PALETTE.CELL_SIZE), Vector2.ONE * PALETTE.CELL_SIZE)


func _view_direction(direction: Vector2) -> Vector2:
	return Vector2(-direction.x, direction.y) if mirror_board else direction


func _goal_line(side: int) -> Rect2:
	var left := (side == 1) != mirror_board
	var x := PALETTE.BOARD_ORIGIN.x + (0 if left else PALETTE.BOARD_SIZE.x)
	return Rect2(Vector2(x - 1.5, PALETTE.BOARD_ORIGIN.y), Vector2(3, PALETTE.BOARD_SIZE.y))


func _card_rect(index: int) -> Rect2:
	var slot := _operator_ids.size() - _tray_operator_ids().size() + index
	return Rect2(Vector2(PALETTE.CARD_ORIGIN + Vector2i(slot * (PALETTE.CARD_SIZE.x + PALETTE.CARD_GAP), 0)), Vector2(PALETTE.CARD_SIZE))


func _tray_operator_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for operator_id in _operator_ids:
		var deployed := false
		for unit in _state.units:
			if unit.side == _local_input.side and unit.operator_id == operator_id:
				deployed = true
				break
		if not deployed:
			ids.append(operator_id)
	if _state.sides[_local_input.side].phantom_count > 0:
		for unit in _state.units:
			if unit.side == _local_input.side and unit.operator_id == "nightingale" and unit.hp > 0:
				ids.append("nightingale_phantom")
				break
	return ids


func _cost_rect() -> Rect2:
	return Rect2(Vector2(PALETTE.CARD_ORIGIN.x, PALETTE.CARD_ORIGIN.y - 48), Vector2(8 * (PALETTE.CARD_SIZE.x + PALETTE.CARD_GAP) - PALETTE.CARD_GAP, 40))


func _unit_at_cell(cell: Vector2i, side: int = -1) -> UnitState:
	for unit in _state.units:
		if unit.cell == cell and (side == -1 or unit.side == side):
			return unit
	return null


func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _selected_unit() -> UnitState:
	for unit in _state.units:
		if unit.unit_id == _local_input.selected_unit_id:
			return unit
	return null


func _skill_rect() -> Rect2:
	return Rect2(Vector2(PALETTE.HUD_ORIGIN) + Vector2(20, 282), Vector2(PALETTE.HUD_WIDTH - 40, 46))


func _tab_rect(index: int) -> Rect2:
	return Rect2(Vector2(PALETTE.HUD_ORIGIN) + Vector2(20 + index * 86, 44), Vector2(80, 28))


func _skill_bar_ratio(unit: UnitState, skill: SkillResource) -> float:
	if skill.effect_type == "passive_heal":
		return float(unit.coins) / int(skill.effect_params["coin_limit"])
	var fraction := Engine.get_physics_interpolation_fraction()
	if unit.skill_ticks_left > 0:
		return clampf((unit.skill_ticks_left - fraction) / roundi(skill.duration * CONFIG.TICK_RATE), 0.0, 1.0)
	var limit := SkillRules.sp_limit(skill)
	if limit == 0:
		return 0.0
	var sp := float(unit.sp)
	if skill.sp_recharge_type == "time" and unit.skill_ticks_left == 0 and unit.sp < limit and unit.sp_regen_ticks > 0:
		sp += (unit.sp_regen_ticks + fraction) / CONFIG.TICK_RATE
	return clampf(sp / limit, 0.0, 1.0)


func _cancel_rect() -> Rect2:
	return Rect2(Vector2(PALETTE.HUD_ORIGIN) + Vector2(20, 340), Vector2(PALETTE.HUD_WIDTH - 40, 38))
