extends Node

const OPERATORS_PATH := "res://resources/operators"
const SUMMONS_PATH := "res://resources/summons"
const SUMMON_OWNERS := {"stainless_device_atk":"stainless","stainless_device_sp":"stainless","stainless_cannon":"stainless","dusk_freeling":"dusk","flowing_shape":"muelsyse","jessica_shield":"jessica_alter","mon3tr_reconstruction":"mon3tr_operator","ling_soul1":"ling","ling_soul2":"ling","ling_soul3":"ling","pozyomka_typewriter":"pozyomka","vigil_wolf":"vigil","silence_alter_drone":"silence_alter","curse_doll":"shamare","medical_drone":"silence", "seaborn": "skadi_alter", "mon3tr": "kaltsit", "nightingale_phantom": "nightingale", "phantom_clone": "phantom", "weedy_cannon": "weedy", "magallan_drone_f": "magallan", "magallan_drone_l": "magallan", "magallan_drone_a": "magallan"}

var _operators: Dictionary = {}
var _summons: Dictionary = {}


func _ready() -> void:
	_load_all()


func get_data(operator_id: String) -> OperatorData:
	return _operators[operator_id]


func all_ids() -> PackedStringArray:
	var ids := PackedStringArray(_operators.keys())
	ids.sort()
	return ids


func network_content() -> Dictionary:
	var ids := PackedStringArray(_operators.keys())
	ids.append_array(PackedStringArray(_summons.keys()))
	ids.sort()
	var skill_counts := {}
	for id in _operators: skill_counts[id] = _operators[id].skills.size()
	return {"ids": ids, "summon_owners": SUMMON_OWNERS.duplicate(), "skill_counts":skill_counts}


func _load_all() -> void:
	for path: String in [OPERATORS_PATH, SUMMONS_PATH]:
		var directory := DirAccess.open(path)
		if directory == null:
			push_error(path + ": resource directory missing")
			get_tree().quit(1)
			return
		var files := directory.get_files()
		files.sort()
		for file_name in files:
			file_name = file_name.trim_suffix(".remap")
			if not file_name.ends_with(".tres"): continue
			var resource_path := path.path_join(file_name)
			var data := ResourceLoader.load(resource_path) as OperatorData
			if data == null:
				push_error(resource_path + ": expected OperatorData")
				get_tree().quit(1)
				return
			var error := data.validation_error()
			if error.is_empty() and (path == SUMMONS_PATH) != (data.profession_id == "summon"): error = "profession_id: wrong resource directory"
			if error.is_empty() and (_operators.has(data.operator_id) or _summons.has(data.operator_id)): error = "operator_id: duplicate " + data.operator_id
			if not error.is_empty():
				push_error("%s: %s" % [resource_path,error])
				get_tree().quit(1)
				return
			var target := _summons if path == SUMMONS_PATH else _operators
			target[data.operator_id] = data
	if _operators.is_empty() or _summons.size() != SUMMON_OWNERS.size():
		push_error("Resource catalog: missing operators or unmatched summon owners")
		get_tree().quit(1)
		return
	for id in SUMMON_OWNERS:
		if not _summons.has(id) or not _operators.has(SUMMON_OWNERS[id]):
			push_error("Resource catalog summon owner: " + id)
			get_tree().quit(1)
			return
