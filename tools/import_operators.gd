@tool
extends EditorScript

const CSV_PATH := "res://import/operators.csv"
const OUTPUT_PATH := "res://resources/operators"

const OPERATOR_DATA := preload("res://data/operator_data.gd")
const SKILL_DATA := preload("res://data/skill_resource.gd")
const TALENT_DATA := preload("res://data/talent_resource.gd")
const TRAIT_DATA := preload("res://data/trait_resource.gd")

const OPERATOR_IDS := {
	"风笛": "bagpipe",
	"煌": "blaze",
	"星熊": "hoshiguma",
	"安洁莉娜": "angelina",
	"能天使": "exusiai",
	"夜莺": "nightingale",
	"琳琅诗怀雅": "swire_alter",
	"刻俄柏": "ceobe",
}

const DAMAGE_TYPES := ["physical", "magical", "true", "healing"]
const TERRAIN_TYPES := ["ground", "high", "both"]
const PROFESSION_IDS := ["vanguard", "guard", "defender", "sniper", "caster", "medic", "supporter", "specialist"]
const SP_TYPES := ["time", "on_hit", "on_damaged", "passive", "on_kill"]
const TRAIT_EFFECT_TYPES := [
	"prioritize_flying",
	"prioritize_blocked",
	"cost_drain",
	"refund_on_kill",
	"attack_all_blocked",
	"multi_target_heal",
	"slow_on_hit",
]
const TALENT_EFFECT_TYPES := ["coin_income", "attack_proc", "initial_sp_aura", "emergency_heal", "status_resistance", "damage_block", "defense_aura", "attack_speed_aura", "inactive_regen_aura", "attack_speed_buff", "random_blessing", "magic_resist_aura", "summon_phantom", "fatal_revive", "defense_damage", "isolated_buff"]
const TALENT_PARAMETERS := TalentResource.PARAMETERS
const SKILL_EFFECT_TYPES := [
	"atk_boost_single",
	"atk_spd_boost",
	"atk_def_boost",
	"atk_boost_auto",
	"multi_shot",
	"heal_boost",
	"charge_shot",
	"passive_heal",
]


func _run() -> void:
	if import_all():
		print("Operator import completed: %d resources" % OPERATOR_IDS.size())


func import_all() -> bool:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return _fail("Cannot open CSV: %s" % CSV_PATH)

	var header := file.get_csv_line()
	var columns := {}
	for index in header.size():
		columns[header[index]] = index

	var required_columns := [
		"operator_name", "profession", "profession_id", "branch", "max_health", "attack", "defense",
		"magic_resist", "damage_type", "block_count", "attack_speed", "deploy_cost",
		"redeploy_time", "dodge_physical", "dodge_magical", "attack_range",
		"terrain_requirement", "trait_name", "trait_description", "trait_effect_type",
		"trait_effect_params", "talent1_name", "talent1_description", "talent1_effect_type",
		"talent1_effect_params", "talent2_name", "talent2_description",
		"talent2_effect_type", "talent2_effect_params", "equipped_skill_index", "initial_sp",
		"skill_name", "sp_required", "sp_recharge_type", "skill_description",
		"skill_effect_type", "skill_effect_params", "skill_duration", "ignore_deploy_line",
	]
	for column in required_columns:
		if not columns.has(column):
			return _fail("CSV missing required column: %s" % column)

	var rows: Array[PackedStringArray] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		if row.size() != header.size():
			return _fail("CSV row has %d fields; expected %d" % [row.size(), header.size()])
		rows.append(row)

	if rows.size() != OPERATOR_IDS.size():
		return _fail("CSV contains %d operators; expected %d" % [rows.size(), OPERATOR_IDS.size()])

	for row in rows:
		if not _validate_row(row, columns):
			return false

	var absolute_output := ProjectSettings.globalize_path(OUTPUT_PATH)
	var make_error := DirAccess.make_dir_recursive_absolute(absolute_output)
	if make_error != OK:
		return _fail("Cannot create operator resource directory: %s" % error_string(make_error))

	for row in rows:
		var operator_data := _build_operator(row, columns)
		var save_path := OUTPUT_PATH.path_join(operator_data.operator_id + ".tres")
		var save_error := ResourceSaver.save(operator_data, save_path)
		if save_error != OK:
			return _fail("Cannot save %s: %s" % [save_path, error_string(save_error)])
		print("Imported %s -> %s" % [operator_data.display_name, save_path])

	return true


func _validate_row(row: PackedStringArray, columns: Dictionary) -> bool:
	var display_name := row[columns["operator_name"]]
	if not OPERATOR_IDS.has(display_name):
		return _fail("Unknown operator name: %s" % display_name)
	if row[columns["damage_type"]] not in DAMAGE_TYPES:
		return _fail("Unknown damage_type for %s: %s" % [display_name, row[columns["damage_type"]]])
	if row[columns["terrain_requirement"]] not in TERRAIN_TYPES:
		return _fail("Unknown terrain_requirement for %s: %s" % [display_name, row[columns["terrain_requirement"]]])
	if row[columns["profession_id"]] not in PROFESSION_IDS:
		return _fail("Unknown profession_id for %s" % display_name)
	if row[columns["sp_recharge_type"]] not in SP_TYPES:
		return _fail("Unknown sp_recharge_type for %s: %s" % [display_name, row[columns["sp_recharge_type"]]])
	if row[columns["trait_effect_type"]] not in TRAIT_EFFECT_TYPES:
		return _fail("Unknown trait_effect_type for %s: %s" % [display_name, row[columns["trait_effect_type"]]])
	if row[columns["talent1_effect_type"]] not in TALENT_EFFECT_TYPES:
		return _fail("Unknown talent1_effect_type for %s: %s" % [display_name, row[columns["talent1_effect_type"]]])
	if row[columns["talent2_effect_type"]] not in TALENT_EFFECT_TYPES:
		return _fail("Unknown talent2_effect_type for %s: %s" % [display_name, row[columns["talent2_effect_type"]]])
	if row[columns["skill_effect_type"]] not in SKILL_EFFECT_TYPES:
		return _fail("Unknown skill_effect_type for %s: %s" % [display_name, row[columns["skill_effect_type"]]])

	var integer_columns := [
		"max_health", "attack", "defense", "block_count", "deploy_cost",
		"equipped_skill_index", "initial_sp", "sp_required",
	]
	for column in integer_columns:
		if not row[columns[column]].is_valid_int():
			return _fail("Invalid integer in %s.%s: %s" % [display_name, column, row[columns[column]]])

	var float_columns := ["magic_resist", "attack_speed", "redeploy_time", "dodge_physical", "dodge_magical"]
	for column in float_columns:
		if not row[columns[column]].is_valid_float():
			return _fail("Invalid number in %s.%s: %s" % [display_name, column, row[columns[column]]])

	for column in ["attack_range", "trait_effect_params", "talent1_effect_params", "talent2_effect_params", "skill_effect_params"]:
		if JSON.parse_string(row[columns[column]]) == null:
			return _fail("Invalid JSON in %s.%s" % [display_name, column])
	for prefix in ["talent1", "talent2"]:
		var effect := row[columns[prefix + "_effect_type"]]
		var params: Variant = JSON.parse_string(row[columns[prefix + "_effect_params"]])
		if not params is Dictionary or params.size() != TALENT_PARAMETERS[effect].size():
			return _fail("Invalid talent parameter keys for %s.%s" % [display_name, prefix])
		for key in TALENT_PARAMETERS[effect]:
			var value: Variant = params.get(key)
			if key == "profession_id":
				if value not in PROFESSION_IDS:
					return _fail("Invalid talent profession_id for %s.%s" % [display_name, prefix])
			elif not (value is int or value is float) or float(value) != floorf(float(value)) or value <= 0:
				return _fail("Expected positive integer talent parameter %s.%s.%s" % [display_name, prefix, key])
			elif key in ["chance_percent", "hp_threshold_percent", "heal_percent", "lock_hp_percent"] and value > 100:
				return _fail("Talent percent exceeds 100 for %s.%s.%s" % [display_name, prefix, key])
	if row[columns["skill_effect_type"]] == "passive_heal":
		if row[columns["sp_recharge_type"]] != "passive" or row[columns["sp_required"]].to_int() != 0 or row[columns["talent1_effect_type"]] != "coin_income" or row[columns["trait_effect_type"]] != "cost_drain":
			return _fail("Passive healing requires zero SP, coin income and merchant cost drain: " + display_name)
		var parameter_groups := {
			"skill_effect_params": ["heal_percent", "hp_threshold_percent", "heal_radius", "coin_limit"],
			"talent1_effect_params": ["initial_coins", "coins_per_drain", "attack_percent_per_stack", "max_attack_stacks"],
		}
		for column in parameter_groups:
			var parameters: Variant = JSON.parse_string(row[columns[column]])
			if not parameters is Dictionary:
				return _fail("Expected parameter dictionary in %s.%s" % [display_name, column])
			for key in parameter_groups[column]:
				var value: Variant = parameters.get(key)
				if not (value is int or value is float) or float(value) != floorf(float(value)) or value <= 0:
					return _fail("Expected positive integer in %s.%s" % [display_name, key])
		var heal_params: Dictionary = JSON.parse_string(row[columns["skill_effect_params"]])
		if int(heal_params["hp_threshold_percent"]) > 100 or int(heal_params["heal_radius"]) != 1:
			return _fail("Passive healing requires an eight-neighbor range and valid HP threshold: " + display_name)

	var ignore_deploy_line := row[columns["ignore_deploy_line"]]
	if ignore_deploy_line != "true" and ignore_deploy_line != "false":
		return _fail("Invalid bool in %s.ignore_deploy_line: %s" % [display_name, ignore_deploy_line])
	if not _duration_is_valid(row[columns["skill_duration"]]):
		return _fail("Invalid skill duration for %s: %s" % [display_name, row[columns["skill_duration"]]])
	return true


func _build_operator(row: PackedStringArray, columns: Dictionary) -> OperatorData:
	var operator_data := OPERATOR_DATA.new() as OperatorData
	operator_data.operator_id = OPERATOR_IDS[row[columns["operator_name"]]]
	operator_data.display_name = row[columns["operator_name"]]
	operator_data.profession = row[columns["profession"]]
	operator_data.profession_id = row[columns["profession_id"]]
	operator_data.branch = row[columns["branch"]]
	operator_data.max_health = row[columns["max_health"]].to_int()
	operator_data.attack = row[columns["attack"]].to_int()
	operator_data.defense = row[columns["defense"]].to_int()
	operator_data.magic_resist = roundi(row[columns["magic_resist"]].to_float() * 100.0)
	operator_data.damage_type = row[columns["damage_type"]]
	operator_data.attack_interval = row[columns["attack_speed"]].to_float()
	operator_data.block_count = row[columns["block_count"]].to_int()
	operator_data.deploy_cost = row[columns["deploy_cost"]].to_int()
	operator_data.redeploy_time = row[columns["redeploy_time"]].to_float()
	operator_data.dodge_physical = roundi(row[columns["dodge_physical"]].to_float() * 100.0)
	operator_data.dodge_magical = roundi(row[columns["dodge_magical"]].to_float() * 100.0)
	operator_data.attack_range = _parse_attack_range(row[columns["attack_range"]])
	operator_data.terrain_requirement = row[columns["terrain_requirement"]]
	operator_data.ignore_deploy_line = row[columns["ignore_deploy_line"]] == "true"
	operator_data.branch_trait = _build_trait(row, columns)
	operator_data.talent_1 = _build_talent(row, columns, "talent1")
	operator_data.talent_2 = _build_talent(row, columns, "talent2")
	operator_data.skills = [_build_skill(row, columns)]
	operator_data.equipped_skill_index = row[columns["equipped_skill_index"]].to_int()
	operator_data.initial_sp = row[columns["initial_sp"]].to_int()
	return operator_data


func _build_trait(row: PackedStringArray, columns: Dictionary) -> TraitResource:
	var trait_data := TRAIT_DATA.new() as TraitResource
	trait_data.trait_name = row[columns["trait_name"]]
	trait_data.description = row[columns["trait_description"]]
	trait_data.effect_type = row[columns["trait_effect_type"]]
	trait_data.effect_params = _parse_effect_params(row[columns["trait_effect_params"]])
	return trait_data


func _build_talent(row: PackedStringArray, columns: Dictionary, prefix: String) -> TalentResource:
	var talent := TALENT_DATA.new() as TalentResource
	talent.talent_name = row[columns[prefix + "_name"]]
	talent.description = row[columns[prefix + "_description"]]
	talent.effect_type = row[columns[prefix + "_effect_type"]]
	talent.effect_params = _parse_effect_params(row[columns[prefix + "_effect_params"]])
	for key in talent.effect_params:
		if key != "profession_id":
			talent.effect_params[key] = int(talent.effect_params[key])
	return talent


func _build_skill(row: PackedStringArray, columns: Dictionary) -> SkillResource:
	var skill := SKILL_DATA.new() as SkillResource
	skill.skill_name = row[columns["skill_name"]]
	skill.sp_required = row[columns["sp_required"]].to_int()
	skill.sp_recharge_type = row[columns["sp_recharge_type"]]
	skill.description = row[columns["skill_description"]]
	skill.effect_type = row[columns["skill_effect_type"]]
	skill.effect_params = _parse_effect_params(row[columns["skill_effect_params"]])
	skill.duration = _parse_duration(row[columns["skill_duration"]])
	return skill


func _parse_attack_range(text: String) -> Array[Vector2i]:
	var parsed: Array = JSON.parse_string(text)
	var result: Array[Vector2i] = []
	for pair in parsed:
		result.append(Vector2i(pair[0], pair[1]))
	return result


func _parse_effect_params(text: String) -> Dictionary:
	var result: Dictionary = JSON.parse_string(text)
	for key in ["attack_speed_add", "charge_count", "drain_amount", "refund_amount", "shot_count", "target_count", "heal_percent", "hp_threshold_percent", "heal_radius", "coin_limit", "initial_coins", "coins_per_drain", "attack_percent_per_stack", "max_attack_stacks"]:
		if result.has(key):
			result[key] = int(result[key])
	return result


func _duration_is_valid(text: String) -> bool:
	if text.begins_with("瞬时") or text.begins_with("常驻"):
		return true
	if not text.ends_with("秒"):
		return false
	return text.trim_suffix("秒").is_valid_float()


func _parse_duration(text: String) -> float:
	if text.begins_with("瞬时"):
		return 0.0
	if text.begins_with("常驻"):
		return -1.0
	return text.trim_suffix("秒").to_float()


func _fail(message: String) -> bool:
	push_error(message)
	return false
