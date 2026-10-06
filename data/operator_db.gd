extends Node

const OPERATORS_PATH := "res://resources/operators"

var _operators: Dictionary = {}


func _ready() -> void:
	_load_all()


func get_data(operator_id: String) -> OperatorData:
	return _operators[operator_id]


func all_ids() -> PackedStringArray:
	var ids := PackedStringArray(_operators.keys())
	ids.sort()
	return ids


func _load_all() -> void:
	var directory := DirAccess.open(OPERATORS_PATH)
	if directory == null:
		push_error("Operator resource directory not found: %s" % OPERATORS_PATH)
		get_tree().quit(1)
		return

	var files := directory.get_files()
	files.sort()
	for file_name in files:
		file_name = file_name.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var operator_data := ResourceLoader.load(OPERATORS_PATH.path_join(file_name)) as OperatorData
		if operator_data == null or operator_data.operator_id.is_empty():
			push_error("Invalid operator resource: %s" % file_name)
			get_tree().quit(1)
			return
		if _operators.has(operator_data.operator_id):
			push_error("Duplicate operator_id: %s" % operator_data.operator_id)
			get_tree().quit(1)
			return
		if operator_data.profession_id not in OperatorData.PROFESSION_IDS:
			push_error("Invalid operator profession_id: " + operator_data.operator_id)
			get_tree().quit(1)
			return
		for talent in [operator_data.talent_1, operator_data.talent_2]:
			if not talent.parameters_are_valid():
				push_error("Invalid talent data: %s / %s" % [operator_data.operator_id, talent.talent_name])
				get_tree().quit(1)
				return
		_operators[operator_data.operator_id] = operator_data
	if _operators.is_empty():
		push_error("No operator resources found: %s" % OPERATORS_PATH)
		get_tree().quit(1)
		return
	var phantom: OperatorData = load("res://resources/summons/nightingale_phantom.tres")
	if phantom.operator_id != "nightingale_phantom" or phantom.profession_id != "summon" or phantom.max_health <= 0 or phantom.deploy_cost < 0 or phantom.redeploy_time <= 0 or phantom.terrain_requirement not in ["ground", "high", "both"] or phantom.block_count != 0 or phantom.attack != 0 or phantom.magic_resist < 0 or phantom.magic_resist > 100 or phantom.dodge_physical < 0 or phantom.dodge_physical > 100 or phantom.branch_trait.effect_type != "phantom" or phantom.skills.size() != 1 or phantom.skills[0].effect_type != "no_skill" or phantom.skills[0].sp_recharge_type != "passive" or phantom.skills[0].sp_required != 0 or phantom.talent_1.effect_type != "none" or phantom.talent_2.effect_type != "none":
		push_error("Invalid nightingale phantom resource")
		get_tree().quit(1)
		return
	var params := phantom.branch_trait.effect_params
	if params.size() != 2 or not params.get("life_loss_percent") is int or not params.get("taunt_level") is int or params["life_loss_percent"] <= 0 or params["life_loss_percent"] > 100 or params["taunt_level"] <= 0:
		push_error("Invalid nightingale phantom trait parameters")
		get_tree().quit(1)
