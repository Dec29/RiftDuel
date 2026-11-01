class_name DraftState
extends RefCounted

const CONFIG := preload("res://data/config.gd")
const NAMES := ["首轮禁用", "首轮选取", "次轮禁用", "次轮选取", "技能配置", "准备完成"]
var stage := 0
var serial := 0
var ban_limits := [CONFIG.DRAFT_FIRST_BANS,CONFIG.DRAFT_FIRST_BANS]
var bans: Array[PackedStringArray] = [PackedStringArray(),PackedStringArray()]
var picks: Array[PackedStringArray] = [PackedStringArray(),PackedStringArray()]
var skills: Array[PackedInt32Array] = [PackedInt32Array(),PackedInt32Array()]
var locked := [false,false]
var pending: Array[PackedStringArray] = [PackedStringArray(),PackedStringArray()]
var pending_skills: Array[PackedInt32Array] = [PackedInt32Array(),PackedInt32Array()]
var preferences: Array[PackedStringArray] = [PackedStringArray(),PackedStringArray()]
var preferred_skills: Array[PackedInt32Array] = [PackedInt32Array(),PackedInt32Array()]
var catalog: Dictionary
var ids := PackedStringArray()


func _init(skill_counts: Dictionary) -> void:
	catalog = skill_counts.duplicate()
	ids = PackedStringArray(catalog.keys())
	ids.sort()


func duration_ms() -> int:
	return (CONFIG.DRAFT_BAN_SECONDS if stage in [0,2] else (CONFIG.DRAFT_PICK_SECONDS if stage in [1,3] else CONFIG.DRAFT_SKILL_SECONDS)) * 1000


func target_count() -> int:
	return CONFIG.DRAFT_FIRST_PICKS if stage == 1 else CONFIG.SQUAD_MAX_OPERATORS


func banned(id: String) -> bool:
	return id in bans[0] or id in bans[1]


func can_ban(side: int, id: String) -> bool:
	return stage in [0,2] and not locked[side] and catalog.has(id) and not banned(id) and id not in picks[0] and id not in picks[1] and bans[side].size() < ban_limits[side]


func ban(side: int, id: String) -> String:
	if not can_ban(side,id): return "该干员已被禁用、已被选取，或本轮禁用已结束"
	bans[side].append(id)
	if bans[side].size() == ban_limits[side]: locked[side] = true
	_advance()
	return ""


func selection_error(side: int, operators: Variant, indices: Variant, complete: bool) -> String:
	if stage not in [1,3,4] or locked[side]: return "本轮已确认或不处于选取阶段"
	if not operators is Array or not indices is Array: return "阵容字段无效"
	var target := target_count()
	if operators.size() > target or (complete and operators.size() != target): return "本轮须选满%d名干员" % target
	var seen := {}
	for id in operators:
		if not id is String or not catalog.has(id) or banned(id) or seen.has(id): return "阵容包含已禁用、重复或未知干员"
		seen[id] = true
	for id in picks[side]:
		if not seen.has(id): return "此前已选干员不能移除"
	if stage == 4:
		if operators.size() != picks[side].size() or indices.size() != operators.size(): return "技能配置须保留完整阵容"
		for index in indices.size():
			if not CommandCodec.is_integer(indices[index],0,int(catalog[operators[index]])-1): return "携带技能尚未开放或无效"
	elif not indices.is_empty(): return "选人阶段不接受技能配置"
	return ""


func update_selection(side: int, operators: Variant, indices: Variant, complete: bool) -> String:
	if stage in [0,2]:
		if not complete or locked[side] or not operators is Array or not indices is Array or not operators.is_empty() or not indices.is_empty(): return "结束禁用指令无效"
		locked[side] = true
		_advance()
		return ""
	var error := selection_error(side,operators,indices,complete)
	if not error.is_empty(): return error
	pending[side] = PackedStringArray(operators)
	pending_skills[side] = PackedInt32Array(indices)
	if complete:
		locked[side] = true
		_advance()
	return ""


func default_skill(side: int, id: String) -> int:
	var slot := preferences[side].find(id)
	return preferred_skills[side][slot] if slot >= 0 else 0


func expire() -> void:
	for side in 2:
		if locked[side]: continue
		if stage in [1,3]:
			var selected := pending[side].duplicate() if not pending[side].is_empty() else picks[side].duplicate()
			var order := preferences[side].duplicate()
			order.append_array(ids)
			for id in order:
				if selected.size() >= target_count(): break
				if catalog.has(id) and not banned(id) and id not in selected: selected.append(id)
			pending[side] = selected
		elif stage == 4 and pending_skills[side].is_empty():
			pending[side] = picks[side].duplicate()
			for id in picks[side]: pending_skills[side].append(default_skill(side,id))
		locked[side] = true
	_advance()


func _advance() -> void:
	if not locked[0] or not locked[1]: return
	if stage in [1,3,4]:
		for side in 2:
			picks[side] = pending[side].duplicate()
			if stage == 4: skills[side] = pending_skills[side].duplicate()
	stage += 1
	if stage == 2: ban_limits = [bans[0].size()+2,bans[1].size()+2]
	locked = [stage == 5,stage == 5]
	pending = [PackedStringArray(),PackedStringArray()]
	pending_skills = [PackedInt32Array(),PackedInt32Array()]


func snapshot() -> Dictionary:
	# Pending picks and skill updates never enter the public room control event.
	return {"stage":stage,"step":serial,"bans":[Array(bans[0]),Array(bans[1])],"picks":[Array(picks[0]),Array(picks[1])],"skills":[Array(skills[0]),Array(skills[1])],"locked":locked.duplicate()}


func read_snapshot(value: Variant) -> String:
	if not value is Dictionary or value.size() != 8 or not value.get("draft_id") is String or value.draft_id.length()!=32 or not value.draft_id.is_valid_hex_number(false): return "禁选标识或字段无效"
	if not CommandCodec.is_integer(value.get("stage"),0,5) or not CommandCodec.is_integer(value.get("step"),serial+1,serial+1) or not CommandCodec.is_integer(value.get("remaining_ms"),0,100000): return "禁选阶段、序号或计时无效"
	for key in ["bans","picks","skills","locked"]:
		if not value.get(key) is Array or value[key].size()!=2: return "禁选双方数据无效"
	var all_bans := {}
	for side in 2:
		if not value.locked[side] is bool or not value.bans[side] is Array or value.bans[side].size()>CONFIG.DRAFT_TOTAL_BANS or not value.picks[side] is Array or value.picks[side].size()>CONFIG.SQUAD_MAX_OPERATORS or not value.skills[side] is Array: return "禁选阵容字段无效"
		for id in value.bans[side]:
			if not id is String or not catalog.has(id) or all_bans.has(id): return "禁用干员重复或未知"
			all_bans[id] = true
	for side in 2:
		var seen := {}
		var expected := 0 if int(value.stage)<2 else (CONFIG.DRAFT_FIRST_PICKS if int(value.stage)<4 else CONFIG.SQUAD_MAX_OPERATORS)
		if value.picks[side].size()!=expected or value.skills[side].size()!=(expected if int(value.stage)==5 else 0): return "公开阵容与阶段不匹配"
		for id in value.picks[side]:
			if not id is String or not catalog.has(id) or all_bans.has(id) or seen.has(id): return "公开阵容无效"
			seen[id] = true
		for index in value.skills[side].size():
			if not CommandCodec.is_integer(value.skills[side][index],0,int(catalog[value.picks[side][index]])-1): return "公开技能无效"
	if int(value.stage) < stage or int(value.stage) > stage+1: return "禁选阶段不能跳转"
	if int(value.stage)==2 and stage==1: ban_limits = [bans[0].size()+2,bans[1].size()+2]
	stage = int(value.stage)
	serial = int(value.step)
	for side in 2:
		bans[side] = PackedStringArray(value.bans[side])
		picks[side] = PackedStringArray(value.picks[side])
		skills[side] = PackedInt32Array(value.skills[side])
		locked[side] = value.locked[side]
	return ""
