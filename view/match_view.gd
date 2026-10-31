class_name MatchView
extends Node2D

signal home_requested
signal room_requested

const CONFIG := preload("res://data/config.gd")
const ARENA := preload("res://resources/map/standard_arena.tres")
const BALL_DATA := preload("res://resources/ball/standard.tres")
const PALETTE := preload("res://view/palette.gd")
const RANGE := preload("res://sim/attack_range.gd")
const CANNON := preload("res://resources/summons/weedy_cannon.tres")
const CLONE := preload("res://resources/summons/phantom_clone.tres")
const PHANTOM := preload("res://resources/summons/nightingale_phantom.tres")
const FLOOR_TILE := preload("res://assets/arena/floor_tile.svg")
const PLATFORM_TILE := preload("res://assets/arena/platform_top.svg")
const ITEM_NAMES := ["雪雉的起重机", "娜丝缇的高台", "轰隆隆先生", "广域支援无人机"]
const ITEM_DESCRIPTIONS := [["面向相邻己方普通干员，使其撤退。", "正常撤退返费，5秒后可再部署。"], ["地面变成本局永久高台部署位。", "允许高台干员，并阻挡球体。"], ["可以放在敌方部署区域。", "放置1秒后爆炸，四邻格敌人眩晕12秒。", "前摇占格挡球，不能被攻击。"], ["空中支援 · 无视地形、占格，持续30秒。", "13格：友方攻速+20%，敌方−20%。", "部署清退敌方召唤物；同类光环不叠加。"]]

enum DeployPhase { IDLE, DRAGGING, FACING }
# COMMAND is only the collapsed inspection state, not a visible tab.
enum InfoTab { COMMAND, TRAIT, TALENT, SKILL }

var _key_preferences := preload("res://preferences.gd").new()

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
var _info_tab := InfoTab.SKILL
var _show_skill_range := false
var simulation_phase := 0
var simulation_waiting := false
var _observed_recovery_side := -1
const SKILL_READY_TEXTURE := preload("res://assets/battle/skill_ready.svg")
const FOOTBALL_TEXTURE := preload("res://assets/battle/football.svg")
var _details_open := false
var _info_scroll := 0
var _info_scroll_display := 0.0
# Derived text layout only; paragraphs are rebuilt from live simulation every frame.
var _info_layout_paragraphs := PackedStringArray()
var _info_layout_lines := PackedStringArray()
var _info_layout_offsets := PackedInt32Array()
var _info_layout_height := 0
var _info_layout_font: Font
# Fixed floor mesh only; terrain and high platforms are read live every frame.
var _floor_mesh: ArrayMesh
var _floor_grid_lines := PackedVector2Array()
var _floor_mesh_mirrored := false
# Render-only skeleton instances and clock; no simulation state copies.
var _w_mine_models: Dictionary = {}
var _bagpipe_models: Dictionary = {}
var _bone_tick := 0.0
var _attack_tick := 0.0
var session: NetSession
var multiplayer_match := false
var result_confirmed := true
var original_vfx: BattleOriginalVfx
var original_props: BattleProps
var renderer := BattleRenderer.new()
var projection := BoardProjection.new()
var mirror_board: bool:
	get: return projection.mirrored
	set(value): projection.mirrored = value


func bind(state: MatchState, local_input: LocalInput, operator_data: Dictionary) -> void:
	var settings_error: String=_key_preferences.read()
	if not settings_error.is_empty():
		push_error(settings_error);get_tree().quit(1);return
	_state = state
	projection.state = state
	_bone_tick = float(state.tick)
	_attack_tick=maxf(0.0,float(state.tick)-1.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var native_material := ShaderMaterial.new()
	native_material.shader = preload("res://view/native_canvas.gdshader")
	material = native_material
	_local_input = local_input
	_operator_data = operator_data.duplicate()
	_operator_data["nightingale_phantom"] = PHANTOM
	_operator_data["phantom_clone"] = CLONE
	_operator_data["mon3tr_reconstruction"]=MatchState.MONSTR_RECONSTRUCTION_DATA
	for id in MatchState.LING_DATA:_operator_data[id]=MatchState.LING_DATA[id]
	for token: OperatorData in MatchState.STAINLESS_DATA:_operator_data[token.operator_id]=token
	_operator_data["flowing_shape"]=MatchState.FLOW_DATA
	_operator_data["jessica_shield"]=MatchState.JESSICA_SHIELD_DATA
	_operator_data["vigil_wolf"]=MatchState.VIGIL_WOLF_DATA
	_operator_data["pozyomka_typewriter"]=MatchState.TYPEWRITER_DATA
	_operator_data["silence_alter_drone"]=MatchState.SILENCE_DRONE_DATA
	_operator_data["curse_doll"]=MatchState.CURSE_DOLL_DATA
	_operator_data["medical_drone"]=MatchState.MEDICAL_DRONE_DATA
	_operator_data["seaborn"]=MatchState.SEABORN_DATA
	_operator_data["mon3tr"]=MatchState.MON3TR_DATA
	_operator_data["weedy_cannon"] = CANNON
	for id in MatchState.DRONE_IDS:_operator_data[id] = MatchState.DRONE_DATA[id]
	_operator_ids = state.squad_ids[local_input.side].duplicate()
	original_vfx=BattleOriginalVfx.new()
	original_vfx.attach(self)
	original_props=BattleProps.new()
	original_props.attach(self)
	queue_redraw()


func _process(delta: float) -> void:
	if _observed_recovery_side != _state.recovery_side:
		DeployInteraction.cancel(self)
		_observed_recovery_side = _state.recovery_side
	if _state.result == MatchState.RESULT_RUNNING:
		_bone_tick = float(_state.tick) + _simulation_fraction()
	_info_scroll_display = lerpf(_info_scroll_display, float(_info_scroll), 1.0 - exp(-PALETTE.INFO_SCROLL_SPEED * delta))
	if absf(_info_scroll_display - _info_scroll) < 0.05:
		_info_scroll_display = float(_info_scroll)
	original_vfx.observe(self)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _state.result != MatchState.RESULT_RUNNING:
		if result_confirmed and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _result_home_rect().has_point(event.position):
				home_requested.emit()
			elif multiplayer_match and _result_room_rect().has_point(event.position):
				room_requested.emit()
		return
	if _state.recovery_side >= 0:
		if _state.recovery_side != _local_input.side: return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and PALETTE.RECOVERY_SKIP.has_point(event.position):
			_local_input.queue_skip_recovery(_state.input_tick)
			DeployInteraction.cancel(self)
			return
	if event is InputEventMouseButton:_pointer_position=event.position
	if Hotkeys.matches(event,_key_preferences.hotkeys,"cancel"):
		DeployInteraction.cancel(self);return
	if Hotkeys.matches(event,_key_preferences.hotkeys,"skill"):
		if _state.recovery_side < 0 and _deploy_phase==DeployPhase.IDLE:_activate_selected_skill()
		return
	if Hotkeys.matches(event,_key_preferences.hotkeys,"retreat"):
		if _state.recovery_side >= 0: DeployInteraction.cancel(self); return
		if _deploy_phase!=DeployPhase.IDLE:DeployInteraction.cancel(self)
		elif not (event is InputEventMouseButton and _hud_visible() and _hud_rect().has_point(event.position)):
			var unit := _unit_at_cell(projection.screen_to_cell(_pointer_position),_local_input.side) if event is InputEventMouseButton else _selected_unit()
			if unit!=null and unit.side==_local_input.side:_local_input.queue_retreat(_state.input_tick,unit.unit_id)
		return
	if event is InputEventMouseMotion:
		_pointer_position = event.position
		_hovered_cell = projection.screen_to_cell(event.position)
		DeployInteraction.motion(self, event)
		return
	if not event is InputEventMouseButton:
		return
	_pointer_position = event.position
	var cell := projection.screen_to_cell(event.position)
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _hud_visible() and _hud_expanded() and _info_tab != InfoTab.COMMAND:
		if _info_body_rect().has_point(event.position):
			_info_scroll = maxi(0, _info_scroll + (-36 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 36))
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		DeployInteraction.release(self, event, cell)
		return
	if _hud_visible() and _close_info_rect().has_point(event.position):
		DeployInteraction.cancel(self)
		return
	if _hud_visible() and _details_rect().has_point(event.position) and _deploy_phase == DeployPhase.IDLE:
		_details_open = not _hud_expanded()
		_info_tab = InfoTab.SKILL if _details_open else InfoTab.COMMAND
		_info_scroll = 0
		_info_scroll_display = 0.0
		return
	for tab_index in ([] if not _hud_expanded() or _local_input.selected_item_kind >= 0 else [InfoTab.SKILL,InfoTab.TRAIT,InfoTab.TALENT]):
		if _hud_visible() and _tab_rect(tab_index).has_point(event.position):
			_info_tab = tab_index
			_details_open = tab_index != InfoTab.COMMAND
			_info_scroll = 0
			_info_scroll_display = 0.0
			return
	if (_hud_visible() or _deploy_phase == DeployPhase.DRAGGING) and _cancel_rect().has_point(event.position):
		if _deploy_phase != DeployPhase.IDLE:
			DeployInteraction.cancel(self)
		else:
			var selected := _selected_unit()
			if selected != null and selected.side == _local_input.side and _state.recovery_side < 0:
				_local_input.queue_retreat(_state.input_tick, selected.unit_id)
			elif not _local_input.selected_operator_id.is_empty() or _local_input.selected_item_kind >= 0:
				_local_input.clear_selection()
		return
	if _hud_visible() and _skill_rect().has_point(event.position) and _deploy_phase == DeployPhase.FACING:
		DeployInteraction.confirm(self)
		return
	if _hud_visible() and _skill_rect().has_point(event.position) and _deploy_phase == DeployPhase.IDLE:
		_activate_selected_skill()
		return
	if _range_preview_visible() and _range_preview_rect().has_point(event.position):
		_show_skill_range = not _show_skill_range
		return
	if _hud_visible() and _hud_rect().has_point(event.position):
		return
	if _deploy_phase == DeployPhase.FACING:
		if projection.cell_rect(_preview_cell).grow(PALETTE.CELL_SIZE * 0.35).has_point(event.position):
			_facing_drag = true
		return
	var tray_ids := _tray_operator_ids()
	for index in tray_ids.size():
		if _card_rect(index).has_point(event.position):
			var operator_id := tray_ids[index]
			var flow := _selected_unit()
			if flow!=null and flow.side==_local_input.side and flow.operator_id=="flowing_shape" and flow.skill_ticks_left>0:
				if TacticianRules.can_copy(_state,_local_input.side,flow.unit_id,operator_id):
					_local_input.queue_copy(_state.input_tick,flow.unit_id,operator_id,flow.facing)
					_local_input.select_unit(flow.unit_id)
				return
			var operator := _operator_data[operator_id] as OperatorData
			_info_tab = InfoTab.SKILL
			_show_skill_range = false
			_info_scroll = 0
			_info_scroll_display = 0.0
			_details_open = true
			_local_input.select_operator(operator_id)
			if _operator_available(operator):
				_deploy_phase = DeployPhase.DRAGGING
				_preview_cell = cell
				_preview_facing = 2 if _local_input.side == 0 else 0
			return
	var item_kinds := _tray_item_kinds()
	for index in item_kinds.size():
		var card_index := tray_ids.size() + index
		if _card_rect(card_index).has_point(event.position):
			_details_open = false
			_local_input.select_item(item_kinds[index])
			_info_tab = InfoTab.COMMAND
			_info_scroll = 0
			_info_scroll_display = 0.0
			_deploy_phase = DeployPhase.DRAGGING
			_preview_cell = cell
			_preview_facing = 2 if _local_input.side == 0 else 0
			return
	var selected_unit := _unit_at_cell(cell)
	if selected_unit != null and selected_unit.displacement_ticks_left > 0:
		selected_unit = null
	for unit in _state.units:
		if unit.displacement_ticks_left > 0 and renderer.unit_screen_center(self, unit).distance_to(event.position) < PALETTE.CELL_SIZE * PALETTE.BOARD_ZOOM * 0.4:
			selected_unit = unit
			break
	if selected_unit != null:
		_details_open = true
		_info_tab = InfoTab.SKILL
		_show_skill_range = false
		_local_input.select_unit(selected_unit.unit_id)
		_info_scroll = 0
		_info_scroll_display = 0.0
	else:
		_local_input.clear_selection()


func _draw() -> void:
	var visual_tick := float(_state.tick) + _simulation_fraction()
	var own_color := PALETTE.BLUE if _local_input.side == 0 else PALETTE.RED
	var enemy_color := PALETTE.RED if _local_input.side == 0 else PALETTE.BLUE
	var cell_size := float(PALETTE.CELL_SIZE) * PALETTE.BOARD_ZOOM
	draw_rect(Rect2(Vector2.ZERO, Vector2(PALETTE.SCREEN_SIZE)), PALETTE.BACKGROUND)
	_draw_text(Vector2(PALETTE.BOARD_ORIGIN.x, 40), "RIFT / DUEL", 24, PALETTE.TEXT)
	_draw_text(Vector2(PALETTE.BOARD_ORIGIN.x + 184, 40), "LIVE · 0.75×", 12, PALETTE.MUTED_TEXT)
	var own_goal_left := (_local_input.side == 1) != mirror_board
	_draw_text(Vector2(PALETTE.HUD_ORIGIN.x, 40), "本方 · %s  /  进球目标：%s侧" % ["蓝方" if _local_input.side == 0 else "红方", "右" if own_goal_left else "左"], 16, own_color)
	var frame := {}
	if not renderer.draw(self, visual_tick, own_color, enemy_color, cell_size, frame):
		return
	var selected: UnitState = frame["selected"]
	var ball_center: Vector2 = frame["ball_center"]
	UnitInfo.draw(self, selected, own_color, enemy_color)
	var cost_panel := _cost_rect()
	draw_rect(cost_panel, Color(PALETTE.HUD_SURFACE, 0.55))
	_draw_text(cost_panel.position + Vector2(14, 26), "待部署干员", 16, PALETTE.MUTED_TEXT)
	var cost_x := cost_panel.end.x - 144
	_draw_text(Vector2(cost_x, cost_panel.position.y + 27), "COST", 14, PALETTE.MUTED_TEXT)
	draw_rect(Rect2(Vector2(cost_x + 54, cost_panel.position.y + 4), Vector2(40, 32)), Color(PALETTE.BACKGROUND, 0.8))
	_draw_text(Vector2(cost_x + 58, cost_panel.position.y + 29), "%02d" % _state.sides[_local_input.side].cost, 26, PALETTE.BALL)
	if _state.sides[_local_input.side].cost == CONFIG.COST_MAX:
		_draw_text(Vector2(cost_x + 94, cost_panel.position.y + 29), "MAX", 12, PALETTE.MUTED_TEXT)
	var cost_bar := Rect2(Vector2(cost_x, cost_panel.end.y - 4), Vector2(124, 2))
	draw_rect(cost_bar, PALETTE.HUD_RULE)
	var cost_progress := 1.0 if _state.sides[_local_input.side].cost == CONFIG.COST_MAX else float(_state.sides[_local_input.side].cost_regen_ticks) / CONFIG.COST_REGEN_TICKS
	draw_rect(Rect2(cost_bar.position, Vector2(cost_bar.size.x * cost_progress, 2)), own_color)
	_draw_text(Vector2(130, 688), "TICK  %05d    对手费用  %02d" % [_state.tick, _state.sides[1 - _local_input.side].cost], 12, PALETTE.MUTED_TEXT)
	var elapsed_seconds := _state.tick * CONFIG.PHYSICS_TICKS_PER_SIMULATION_TICK / CONFIG.PHYSICS_TICK_RATE
	_draw_text(Vector2(358, 34), "TIME  %02d:%02d" % [elapsed_seconds / 60, elapsed_seconds % 60], 18, PALETTE.TEXT)
	var overtime := _state.rules.mode=="single" and _state.tick >= _state.rules.duration_ticks() and (_state.result == MatchState.RESULT_RUNNING or _state.tick > _state.rules.duration_ticks())
	var remaining := maxi(0, ((_state.rules.duration_ticks() + (CONFIG.OVERTIME_TICKS if overtime else 0) - _state.tick) * CONFIG.PHYSICS_TICKS_PER_SIMULATION_TICK + CONFIG.PHYSICS_TICK_RATE - 1) / CONFIG.PHYSICS_TICK_RATE)
	_draw_text(Vector2(540, 34), ("加时  " if overtime else "剩余  ") + "%02d:%02d" % [remaining / 60, remaining % 60], 16, PALETTE.ARROW if overtime else PALETTE.MUTED_TEXT)
	if _state.rules.mode == "score" or multiplayer_match:
		var left := 0 if mirror_board else 1
		_draw_text(Vector2(710,34),"%s %d : %d %s" % ["蓝" if left==0 else "红",_state.goals[left],_state.goals[1-left],"红" if left==0 else "蓝"],18,PALETTE.TEXT)
		if session!=null:
			var wins := session.series_wins()
			_draw_text(Vector2(888,70),"第%d/%d局  胜场 %d:%d" % [session.round_number,_state.rules.rounds,wins[left],wins[1-left]],14,PALETTE.MUTED_TEXT)
		if _state.rules.mode=="score" and _state.recovery_side < 0 and _state.last_goal_tick>=0 and _state.tick-_state.last_goal_tick<45 and _state.result==MatchState.RESULT_RUNNING:
			_draw_text(Vector2(530,76),("蓝方" if _state.last_goal_side==0 else "红方")+"进球！",22,PALETTE.ARROW)
	var tray_ids := _tray_operator_ids()
	for index in tray_ids.size():
		var operator_id := tray_ids[index]
		var operator := _operator_data[operator_id] as OperatorData
		var card := _card_rect(index)
		var cost := _state.deploy_cost(_local_input.side,operator.operator_id)
		var cooldown: int = _state.sides[_local_input.side].phantom_cooldown_ticks if operator_id == "nightingale_phantom" else (_state.sides[_local_input.side].clone_cooldown_ticks if operator_id == "phantom_clone" else _state.sides[_local_input.side].cooldowns.get(operator_id, 0))
		if operator_id == "weedy_cannon":cooldown = _state.sides[_local_input.side].cannon_cooldown_ticks
		var stock_text := ""
		if operator_id in LingRules.IDS:stock_text="库存%d · 额度%d/3"%[_state.sides[_local_input.side].ling_stock,LingRules.weighted_count(_state,_local_input.side)]
		if operator_id in StainlessRules.IDS:stock_text="库存%d · 上限2"%_state.sides[_local_input.side].stainless_stock
		if operator_id in MatchState.DRONE_IDS:
			cooldown = _state.sides[_local_input.side].drone_cooldown_ticks
			stock_text = "库存 %d/5 · 上限3架" % _state.sides[_local_input.side].drone_stock
		if operator_id == "nightingale_phantom":
			stock_text = "%d/%d" % [_state.sides[_local_input.side].phantom_count, int((_operator_data["nightingale"] as OperatorData).talent_2.effect_params["stock_limit"])]
		OperatorCardVisual.draw_battle(self,card,operator,_state.carried_skill_index(_local_input.side,operator_id),cost,operator_id==_local_input.selected_operator_id,ceili(float(cooldown)/CONFIG.TICK_RATE),_state.sides[_local_input.side].cost<cost,stock_text)
		var flow := _selected_unit()
		if flow!=null and TacticianRules.can_copy(_state,_local_input.side,flow.unit_id,operator_id):draw_rect(card,PALETTE.ARROW,false,2.0)
	var item_kinds := _tray_item_kinds()
	for index in item_kinds.size():
		var card_index := tray_ids.size() + index
		var kind := item_kinds[index]
		var card := _card_rect(card_index)
		draw_rect(card, PALETTE.HUD_SURFACE)
		draw_rect(Rect2(card.position, Vector2(card.size.x, 3)), PALETTE.ARROW)
		_draw_text(card.position + Vector2(8, 17), "道具", 11, PALETTE.MUTED_TEXT)
		_draw_text(card.position + Vector2(card.size.x - 30, 19), "免费", 11, PALETTE.TEXT)
		var portrait := Rect2(card.position + Vector2(8, 24), Vector2(card.size.x - 16, 56))
		draw_rect(portrait, PALETTE.HUD_INSET)
		var center := portrait.get_center()
		var radius := portrait.size.y * 0.3
		if kind == CONFIG.TACTICAL_ITEM_CRANE:
			draw_polyline(PackedVector2Array([center + Vector2(-radius, radius), center + Vector2(-radius, -radius), center + Vector2(radius, -radius), center + Vector2(radius, radius * 0.3), center + Vector2(radius * 0.6, radius * 0.3)]), PALETTE.ARROW, 2.0)
		elif kind == CONFIG.TACTICAL_ITEM_SUPPORT_DRONE:
			renderer.draw_support_drone(self, center, radius, PALETTE.ARROW)
		elif kind == CONFIG.TACTICAL_ITEM_PLATFORM:
			draw_rect(Rect2(center + Vector2(-radius, -radius * 0.6), Vector2(radius * 2, radius * 0.5)), PALETTE.ARROW, false, 2.0)
			draw_line(center + Vector2(-radius * 0.6, 0), center + Vector2(-radius * 0.6, radius), PALETTE.ARROW, 2.0)
			draw_line(center + Vector2(radius * 0.6, 0), center + Vector2(radius * 0.6, radius), PALETTE.ARROW, 2.0)
		else:
			draw_circle(center, radius * 0.7, PALETTE.ARROW, false, 2.0)
			draw_polyline(PackedVector2Array([center + Vector2(0, -radius * 0.7), center + Vector2(radius * 0.3, -radius), center + Vector2(radius * 0.7, -radius * 0.8)]), PALETTE.ARROW, 2.0)
		if kind == CONFIG.TACTICAL_ITEM_SUPPORT_DRONE:
			_draw_text(card.position + Vector2(7, 92), "广域支援", 11, PALETTE.TEXT)
			_draw_text(card.position + Vector2(7, 108), "无人机", 11, PALETTE.TEXT)
		else:
			_draw_text(card.position + Vector2(7, 99), ITEM_NAMES[kind], mini(11, int((card.size.x - 14) / ITEM_NAMES[kind].length())), PALETTE.TEXT)
		if _local_input.selected_item_kind == kind:
			draw_rect(card, PALETTE.ARROW, false, 2.0)
	renderer.draw_ball_feedback(self, ball_center, cell_size)
	if _range_preview_visible():
		draw_rect(_range_preview_rect(),PALETTE.HUD_HOVER if _show_skill_range else PALETTE.HUD_SURFACE)
		draw_rect(_range_preview_rect(),PALETTE.ARROW,false,1.0)
		_draw_text(_range_preview_rect().position+Vector2(9,23),"当前范围" if _show_skill_range else "技能范围",14,PALETTE.ARROW)
	if _state.recovery_side >= 0:
		var recovering := _state.recovery_side == _local_input.side
		var seconds := mini(CONFIG.GOAL_RECOVERY_SECONDS, ceili(_state.recovery_ticks_left * float(CONFIG.PHYSICS_TICKS_PER_SIMULATION_TICK) / CONFIG.PHYSICS_TICK_RATE))
		draw_rect(PALETTE.RECOVERY_BANNER, PALETTE.HUD_SURFACE)
		draw_rect(PALETTE.RECOVERY_BANNER, PALETTE.ARROW, false, 1.0)
		_draw_text(PALETTE.RECOVERY_BANNER.position + Vector2(12, 15), ("失球支援 · 可越界部署1名干员" if recovering else "对方正在部署失球支援") + "  ·  %d秒" % seconds, 14, PALETTE.ARROW)
		_draw_text(PALETTE.RECOVERY_BANNER.position + Vector2(12, 30), "费用+50（上限99），待部署区冷却最长3人已重置；仍需满足地形、费用与占格要求。" if recovering else "战斗与比赛计时已暂停，部署完成或倒计时结束后继续。", 11, PALETTE.MUTED_TEXT)
		if recovering:
			draw_rect(PALETTE.RECOVERY_SKIP, PALETTE.HUD_HOVER)
			_draw_text(PALETTE.RECOVERY_SKIP.position + Vector2(17, 19), "跳过部署", 14, PALETTE.TEXT)
	if _state.result != MatchState.RESULT_RUNNING:
		var verdict := _state.result
		var text := "平局" if _state.result == MatchState.RESULT_DRAW else ("蓝方胜利" if _state.result == MatchState.RESULT_BLUE_WIN else "红方胜利")
		if session!=null and result_confirmed and not session.has_next_round() and _state.rules.rounds>1:
			verdict=session.series.verdict()
			text="整场平局" if verdict==MatchState.RESULT_DRAW else ("蓝方整场胜利" if verdict==MatchState.RESULT_BLUE_WIN else "红方整场胜利")
		var color := PALETTE.ARROW if verdict == MatchState.RESULT_DRAW else (PALETTE.BLUE if verdict == MatchState.RESULT_BLUE_WIN else PALETTE.RED)
		var center := Vector2(PALETTE.SCREEN_SIZE) * 0.5
		draw_rect(Rect2(Vector2.ZERO, Vector2(PALETTE.SCREEN_SIZE)), Color(PALETTE.BACKGROUND, 0.78))
		var panel := Rect2(center - Vector2(270, 150), Vector2(540, 300))
		draw_rect(panel, PALETTE.HUD_SURFACE)
		draw_rect(panel, color, false, 2.0)
		_draw_text(center + Vector2(-ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,32).x/2,-82), text, 32, color)
		var reason := "进球结束" if _state.ball.cell.x <= 0 or _state.ball.cell.x >= CONFIG.GRID_COLUMNS - 1 else ("加时结束" if overtime else "时间结束")
		_draw_text(center + Vector2(-100, -36), "%s · %02d:%02d" % [reason, elapsed_seconds / 60, elapsed_seconds % 60], 18, PALETTE.MUTED_TEXT)
		_draw_text(center + Vector2(-100, 0), "双方结果已核对" if multiplayer_match and result_confirmed else ("正在核对双方结果…" if multiplayer_match else "对局已结束"), 16, PALETTE.MUTED_TEXT)
		for rect in [_result_home_rect(), _result_room_rect()] if multiplayer_match else [_result_home_rect()]:
			draw_rect(rect, PALETTE.HUD_INSET if result_confirmed else PALETTE.HUD_SURFACE)
			draw_rect(rect, color, false, 1.0)
		_draw_text(_result_home_rect().position + Vector2(35, 30), "返回主页", 18, PALETTE.TEXT)
		if multiplayer_match:
			_draw_text(_result_room_rect().position + Vector2(35, 30), "准备下一局" if session!=null and session.has_next_round() else "返回房间", 18, PALETTE.TEXT)
			var wins := session.series_wins() if session!=null else PackedInt32Array([0,0])
			_draw_text(center+Vector2(-190,-58),"本局进球  蓝 %d : %d 红    胜场 %d : %d" % [_state.goals[0],_state.goals[1],wins[0],wins[1]],15,PALETTE.TEXT)
			_draw_text(center + Vector2(-210, 128), "双方确认后进入下一局" if session!=null and session.has_next_round() else "返回保留原房间；任一方离开才会解散", 14, PALETTE.MUTED_TEXT)

func _result_home_rect() -> Rect2:
	return Rect2(Vector2(PALETTE.SCREEN_SIZE) * 0.5 + Vector2(-190 if multiplayer_match else -90, 40), Vector2(180, 48))


func _result_room_rect() -> Rect2:
	return Rect2(Vector2(PALETTE.SCREEN_SIZE) * 0.5 + Vector2(10, 40), Vector2(180, 48))


func _range_offsets(operator: OperatorData, cell: Vector2i) -> Array[Vector2i]:
	var selected := _selected_unit()
	var index := selected.skill_index if selected != null and selected.operator_id == operator.operator_id else _state.carried_skill_index(_local_input.side,operator.operator_id)
	if _show_skill_range and SkillRangePreview.available(operator,operator.skills[index]):
		return SkillRangePreview.offsets(operator,operator.skills[index])
	if selected != null and selected.cell == cell and selected.operator_id == operator.operator_id:
		var skill := operator.skills[selected.skill_index]
		if SkillRules.active_ticks(selected) > 0 and skill.effect_type == "ramp_burst":
			return skill.burst_range_override.duplicate()
		return RANGE.effective_offsets(selected, operator)
	return RANGE.acquisition_offsets(operator)


func _activate_selected_skill() -> void:
	if _state.recovery_side >= 0: return
	var selected := _selected_unit()
	if selected != null and selected.side == _local_input.side:
		var operator := _operator_data[selected.operator_id] as OperatorData
		if SkillRules.can_manually_activate(selected, operator.skills[selected.skill_index]):
			_local_input.queue_skill(_state.input_tick, selected.unit_id, selected.skill_index)


func _operator_available(operator: OperatorData) -> bool:
	if operator.operator_id in ["flowing_shape","jessica_shield","mon3tr_reconstruction"]+LingRules.IDS+StainlessRules.IDS:
		var visible := TacticianRules.visible(_state,_local_input.side) if operator.operator_id=="flowing_shape" else (SentinelRules.visible(_state,_local_input.side) if operator.operator_id=="jessica_shield" else operator.operator_id in _tray_operator_ids())
		if not visible:return false
		for x in CONFIG.GRID_COLUMNS:
			for y in CONFIG.GRID_ROWS:
				if _state.can_deploy(_local_input.side,operator.operator_id,Vector2i(x,y)):return true
		return false
	if operator.operator_id=="vigil_wolf":return VigilRules.available(_state,_local_input.side)
	if operator.operator_id=="pozyomka_typewriter":return PozyomkaRules.available(_state,_local_input.side)
	if operator.operator_id=="silence_alter_drone":return SilenceAlterRules.drone_available(_state,_local_input.side)
	if operator.operator_id=="curse_doll":return CurseDollRules.available(_state,_local_input.side)
	if operator.operator_id=="medical_drone":return MedicalDroneRules.available(_state,_local_input.side)
	if operator.operator_id=="seaborn":return BardRules.available(_state,_local_input.side)
	if operator.operator_id=="mon3tr":return Mon3trRules.available(_state,_local_input.side)
	if operator.operator_id == "weedy_cannon":return _state.cannon_available(_local_input.side)
	if operator.operator_id in MatchState.DRONE_IDS:return _state.drone_available(_local_input.side,operator.operator_id)
	if operator.operator_id == "phantom_clone":
		return _state.clone_available(_local_input.side)
	if operator.operator_id == "nightingale_phantom":
		return _state.phantom_available(_local_input.side)
	if _state.sides[_local_input.side].cost < _state.deploy_cost(_local_input.side,operator.operator_id) or _state.sides[_local_input.side].cooldowns.has(operator.operator_id):
		return false
	for unit in _state.units:
		if unit.operator_id == operator.operator_id and unit.side == _local_input.side:
			return false
	return true


func _draw_cell_color(cell: Vector2i, color: Color, inset: float = 0.0) -> void:
	draw_colored_polygon(projection.cell_polygon(cell, inset), color)


func _card_rect(index: int) -> Rect2:
	var operators := _tray_operator_ids().size()
	var items := _tray_item_kinds().size()
	var item_width := items*PALETTE.ITEM_CARD_WIDTH+maxi(0,items-1)*PALETTE.CARD_GAP
	var group_gap := PALETTE.CARD_GROUP_GAP if operators>0 and items>0 else 0
	var width := minf(PALETTE.CARD_SIZE.x,float(PALETTE.SCREEN_SIZE.x-2*PALETTE.CARD_RIGHT_MARGIN-item_width-group_gap-maxi(0,operators-1)*PALETTE.CARD_GAP)/maxi(1,operators))
	var operator_width := operators*width+maxi(0,operators-1)*PALETTE.CARD_GAP
	var origin := Vector2(PALETTE.SCREEN_SIZE.x-PALETTE.CARD_RIGHT_MARGIN-operator_width-group_gap-item_width,PALETTE.CARD_ORIGIN.y)
	if index<operators:return Rect2(origin+Vector2(index*(width+PALETTE.CARD_GAP),0),Vector2(width,PALETTE.CARD_SIZE.y))
	return Rect2(origin+Vector2(operator_width+group_gap+(index-operators)*(PALETTE.ITEM_CARD_WIDTH+PALETTE.CARD_GAP),0),Vector2(PALETTE.ITEM_CARD_WIDTH,PALETTE.CARD_SIZE.y))


func _tray_item_kinds() -> Array[int]:
	var kinds: Array[int] = []
	if _state.recovery_side >= 0: return kinds
	for kind in CONFIG.TACTICAL_ITEM_COUNT:
		if _state.sides[_local_input.side].tactical_items[kind] > 0:
			kinds.append(kind)
	return kinds


func _tray_count() -> int:
	return _tray_operator_ids().size() + _tray_item_kinds().size()


func _item_can_place(cell: Vector2i) -> bool:
	var kind := _local_input.selected_item_kind
	if kind == CONFIG.TACTICAL_ITEM_CRANE:
		for facing in 4:
			if _state.can_use_item(_local_input.side, kind, cell, facing):
				return true
		return false
	return _state.can_use_item(_local_input.side, kind, cell)


func _tray_operator_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if _state.recovery_side >= 0 and _state.recovery_side != _local_input.side: return ids
	for operator_id in _operator_ids:
		var deployed := false
		for unit in _state.units:
			if unit.side == _local_input.side and unit.operator_id == operator_id:
				deployed = true
				break
		if not deployed:
			ids.append(operator_id)
	if _state.recovery_side >= 0: return ids
	var reconstruct_owner := MonstrMedicRules.owner(_state,_local_input.side)
	if reconstruct_owner!=null and MonstrMedicRules.token_for(_state,reconstruct_owner)==null:ids.append("mon3tr_reconstruction")
	var ling_owner := LingRules.owner(_state,_local_input.side)
	if ling_owner!=null:ids.append(LingRules.IDS[ling_owner.skill_index])
	var stainless_owner := StainlessRules.owner(_state,_local_input.side)
	if stainless_owner!=null:ids.append(StainlessRules.IDS[stainless_owner.skill_index])
	if TacticianRules.visible(_state,_local_input.side):ids.append("flowing_shape")
	if SentinelRules.visible(_state,_local_input.side):ids.append("jessica_shield")
	if VigilRules.owner(_state,_local_input.side)!=null:ids.append("vigil_wolf")
	if PozyomkaRules.owner(_state,_local_input.side)!=null:ids.append("pozyomka_typewriter")
	if SilenceAlterRules.drone_owner(_state,_local_input.side)!=null:ids.append("silence_alter_drone")
	if CurseDollRules.owner(_state,_local_input.side)!=null:ids.append("curse_doll")
	if MedicalDroneRules.owner(_state,_local_input.side)!=null:ids.append("medical_drone")
	if BardRules.visible(_state,_local_input.side):ids.append("seaborn")
	if Mon3trRules.visible(_state,_local_input.side):ids.append("mon3tr")
	if _state.cannon_visible(_local_input.side):ids.append("weedy_cannon")
	if _state.drone_visible(_local_input.side):ids.append(MatchState.DRONE_IDS[DroneRules.owner(_state,_local_input.side).skill_index])
	if _state.clone_visible(_local_input.side):
		ids.append("phantom_clone")
	if _state.sides[_local_input.side].phantom_count > 0:
		for unit in _state.units:
			if unit.side == _local_input.side and unit.operator_id == "nightingale" and unit.hp > 0:
				ids.append("nightingale_phantom")
				break
	return ids


func _cost_rect() -> Rect2:
	return Rect2(Vector2(PALETTE.SCREEN_SIZE.x - PALETTE.BOARD_ORIGIN.x / 2 - 350, PALETTE.CARD_ORIGIN.y - 56), Vector2(350, 48))


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
	return Rect2(_hud_origin() + Vector2(20, 200 if _local_input.selected_item_kind >= 0 else 192), Vector2(PALETTE.HUD_WIDTH - 40, 38 if _local_input.selected_item_kind >= 0 else 34))


func _tab_rect(index: int) -> Rect2:
	var slot := [InfoTab.SKILL,InfoTab.TRAIT,InfoTab.TALENT].find(index)
	var width := float(PALETTE.HUD_WIDTH - 52) / 3.0
	return Rect2(_hud_origin() + Vector2(20 + slot * (width + 6), PALETTE.HUD_INFO_TAB_Y), Vector2(width, 28))


func _info_body_rect() -> Rect2:
	return Rect2(_hud_origin()+Vector2(20,PALETTE.HUD_INFO_BODY_Y),Vector2(PALETTE.HUD_WIDTH-40,PALETTE.HUD_INFO_BODY_HEIGHT))


func _skill_bar_ratio(unit: UnitState, skill: SkillResource) -> float:
	if skill.effect_type == "deploy_attack_stacks":
		return float(unit.attack_boost_stacks) / int(skill.effect_params["stack_count"])
	if skill.effect_type in ["fortress_ammo", "marked_arrow_rain", "lumen_lamp"] and unit.skill_ticks_left != 0:
		return float(unit.skill_ammo_left) / int(skill.effect_params["ammo_count"])
	if skill.effect_type == "deploy_physical_shield":
		return float(unit.physical_guard_ticks_left) / roundi(skill.duration * CONFIG.TICK_RATE)
	if _skill_bar_uses_coins(unit, skill):
		return float(unit.coins) / int(skill.effect_params["coin_limit"])
	var fraction := _simulation_fraction()
	if skill.effect_type == "stance_defense_regen":
		return float(unit.sp) / skill.sp_required
	if unit.skill_ticks_left == -2:
		return 1.0
	if unit.skill_ticks_left > 0:
		return clampf((unit.skill_ticks_left - fraction) / roundi(skill.duration * CONFIG.TICK_RATE), 0.0, 1.0)
	var limit := SkillRules.sp_limit(skill)
	if limit == 0:
		return 0.0
	var sp := float(unit.sp)
	if skill.sp_recharge_type == "time" and unit.skill_ticks_left == 0 and unit.sp < limit and unit.sp_regen_ticks > 0:
		sp += (unit.sp_regen_ticks + fraction) / CONFIG.TICK_RATE
	return clampf(sp / limit, 0.0, 1.0)


func _skill_bar_uses_coins(unit: UnitState, skill: SkillResource) -> bool:
	return skill.effect_type in ["passive_heal", "champagne_traps"] or (skill.effect_type == "coin_barrage" and (unit.skill_ticks_left != 0 or unit.coin_firing))


func _skill_bar_color(unit: UnitState, skill: SkillResource) -> Color:
	return PALETTE.ARROW if unit.silence_ticks_left == 0 and (SkillRules.active_ticks(unit) != 0 or _skill_bar_uses_coins(unit, skill)) else PALETTE.SP_GREEN


func _cancel_rect() -> Rect2:
	if _deploy_phase == DeployPhase.DRAGGING:
		return Rect2(Vector2(1196, 48), Vector2(52, 28))
	return Rect2(_hud_origin() + Vector2(20, 244 if _local_input.selected_item_kind >= 0 else 232), Vector2(PALETTE.HUD_WIDTH - 40, 28))


func _hud_visible() -> bool:
	return _deploy_phase != DeployPhase.DRAGGING and (_selected_unit() != null or not _local_input.selected_operator_id.is_empty() or _local_input.selected_item_kind >= 0)


func _hud_expanded() -> bool:
	return _local_input.selected_item_kind < 0 and _deploy_phase == DeployPhase.IDLE and (_details_open or _info_tab != InfoTab.COMMAND)


func _hud_rect() -> Rect2:
	return Rect2(_hud_origin(), Vector2(PALETTE.HUD_WIDTH, 280 if _local_input.selected_item_kind >= 0 else (PALETTE.HUD_INFO_HEIGHT if _hud_expanded() else PALETTE.HUD_COMPACT_HEIGHT)))


func _details_rect() -> Rect2:
	return Rect2(_hud_origin() + Vector2(PALETTE.HUD_WIDTH - 100, 8), Vector2(52, 28))


func _close_info_rect() -> Rect2:
	return Rect2(_hud_origin() + Vector2(PALETTE.HUD_WIDTH - 40, 8), Vector2(32, 28))


func _hud_origin() -> Vector2:
	var origin := Vector2(PALETTE.HUD_ORIGIN)
	if _local_input.selected_item_kind < 0: origin.y = PALETTE.HUD_INFO_TOP_Y
	var anchor := _preview_cell if _deploy_phase == DeployPhase.FACING else Vector2i(-1,-1)
	var selected := _selected_unit()
	if selected != null and _deploy_phase == DeployPhase.IDLE: anchor = selected.cell
	if anchor.x >= 0 and Rect2(origin,Vector2(PALETTE.HUD_WIDTH,PALETTE.HUD_INFO_HEIGHT)).intersects(projection.cell_rect(anchor).grow(PALETTE.CELL_SIZE*1.5)):
		origin.x = PALETTE.SCREEN_SIZE.x - PALETTE.HUD_ORIGIN.x - PALETTE.HUD_WIDTH
	return origin


func _range_preview_visible() -> bool:
	if not _hud_visible() or _deploy_phase != DeployPhase.IDLE or _local_input.selected_item_kind >= 0: return false
	var selected := _selected_unit()
	var id := selected.operator_id if selected != null else _local_input.selected_operator_id
	var operator: OperatorData = _operator_data[id]
	var index := selected.skill_index if selected != null else _state.carried_skill_index(_local_input.side,id)
	return SkillRangePreview.available(operator,operator.skills[index])


func _range_preview_rect() -> Rect2:
	var origin := _hud_origin()
	return Rect2(origin+Vector2(PALETTE.HUD_WIDTH+8 if origin.x<PALETTE.SCREEN_SIZE.x/2.0 else -104,44),Vector2(96,34))


func _simulation_fraction() -> float:
	if simulation_waiting or get_tree().paused or _state.recovery_side >= 0 or _state.result != MatchState.RESULT_RUNNING:
		return 0.0
	return (simulation_phase + Engine.get_physics_interpolation_fraction()) / CONFIG.PHYSICS_TICKS_PER_SIMULATION_TICK


func hotkey_label(action: String) -> String:
	return Hotkeys.label(_key_preferences.hotkeys[action])


func attack_visual_tick() -> float:
	# State.tick is the next battle tick; attack events identify the completed step.
	# Retain the last interpolation sample when network waiting removes its fraction.
	var next_tick:=float(_state.tick)
	var completed_tick:=maxf(0.0,next_tick-1.0)
	if simulation_waiting or get_tree().paused or _state.recovery_side >= 0 or _state.result!=MatchState.RESULT_RUNNING:
		_attack_tick=maxf(_attack_tick,completed_tick)
		return _attack_tick
	var interpolated:=clampf(_bone_tick-1.0,completed_tick,maxf(0.0,next_tick-0.000001))
	_attack_tick=maxf(_attack_tick,interpolated)
	return _attack_tick
