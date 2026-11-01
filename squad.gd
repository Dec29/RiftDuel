class_name SquadConfig
extends RefCounted

const FILE_PATH := "user://squad.cfg"
const MAX_OPERATORS := preload("res://data/config.gd").SQUAD_MAX_OPERATORS

var operator_ids := PackedStringArray()
var skill_indices := PackedInt32Array()
var skill_memory: Dictionary = {}


static func available_ids() -> PackedStringArray:
	return Engine.get_main_loop().root.get_node("OperatorDB").all_ids()


static func validate_ids(ids: Variant, allow_empty: bool = false) -> String:
	if not (ids is Array or ids is PackedStringArray) or (ids.is_empty() and not allow_empty) or ids.size() > MAX_OPERATORS:
		return "编队须包含 1 至 12 名干员"
	var seen := {}
	var known_ids := available_ids()
	for id in ids:
		if not id is String or id not in known_ids:
			return "编队包含未知干员"
		if seen.has(id):
			return "编队不能重复携带干员"
		seen[id] = true
	return ""


func read(path: String = FILE_PATH, allow_empty: bool = false) -> String:
	skill_memory.clear()
	skill_indices.clear()
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		operator_ids = PackedStringArray(preload("res://data/config.gd").DEFAULT_SQUAD_IDS)
		skill_indices.resize(operator_ids.size())
		return validate_loadout(operator_ids, skill_indices, allow_empty)
	if error != OK:
		return "无法读取编队：" + error_string(error)
	var ids = config.get_value("squad", "operators")
	var validation := validate_ids(ids, allow_empty)
	if not validation.is_empty():
		return validation
	operator_ids = PackedStringArray(ids)
	if not config.has_section_key("squad", "version") and not config.has_section_key("squad", "skills"):
		# Version 1 stored only IDs; its sole selectable skill was S1.
		skill_indices = PackedInt32Array()
		skill_indices.resize(operator_ids.size())
		return write(path, allow_empty)
	if config.get_value("squad", "version", -1) != 2:
		return "不支持的编队存档版本"
	var indices = config.get_value("squad", "skills", null)
	validation = validate_loadout(ids, indices, allow_empty)
	if not validation.is_empty():
		return validation
	skill_indices = PackedInt32Array(indices)
	var memory: Variant = config.get_value("skill_memory","selected",{})
	validation = validate_memory(memory)
	if not validation.is_empty(): return validation
	skill_memory = memory.duplicate()
	for slot in operator_ids.size(): skill_memory[operator_ids[slot]] = skill_indices[slot]
	return ""


func write(path: String = FILE_PATH, allow_empty: bool = false) -> String:
	var validation := validate_loadout(operator_ids, skill_indices, allow_empty)
	if not validation.is_empty():
		return validation
	validation = validate_memory(skill_memory)
	if not validation.is_empty(): return validation
	for slot in operator_ids.size(): skill_memory[operator_ids[slot]] = skill_indices[slot]
	var config := ConfigFile.new()
	config.set_value("skill_memory","selected",skill_memory)
	config.set_value("squad", "version", 2)
	config.set_value("squad", "operators", operator_ids)
	config.set_value("squad", "skills", skill_indices)
	var error := config.save(path)
	return "" if error == OK else "无法保存编队：" + error_string(error)


static func validate_loadout(ids: Variant, indices: Variant, allow_empty: bool = false) -> String:
	var error := validate_ids(ids, allow_empty)
	if not error.is_empty():
		return error
	if not (indices is Array or indices is PackedInt32Array or indices is PackedInt64Array) or indices.size() != ids.size():
		return "编队技能与干员数量不一致"
	var db = Engine.get_main_loop().root.get_node("OperatorDB")
	for slot in ids.size():
		var index: Variant = indices[slot]
		if not (index is int or index is float) or not is_finite(float(index)) or float(index) != floorf(float(index)) or index < 0 or index >= db.get_data(ids[slot]).skills.size():
			return "编队包含未开放的技能"
	return ""


static func validate_memory(memory: Variant) -> String:
	if not memory is Dictionary: return "技能记忆存档格式无效"
	var known := available_ids()
	var db = Engine.get_main_loop().root.get_node("OperatorDB")
	for id in memory:
		if not id is String or id not in known: return "技能记忆包含未知干员"
		var index: Variant = memory[id]
		if not index is int or index<0 or index>=db.get_data(id).skills.size(): return "技能记忆包含未开放的技能"
	return ""
