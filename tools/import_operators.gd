@tool
extends EditorScript

const CONFIG := preload("res://data/config.gd")

const CSV_PATH := "res://import/operators.csv"
const OUTPUT_PATH := "res://resources/operators"

const OPERATOR_DATA := preload("res://data/operator_data.gd")
const SKILL_DATA := preload("res://data/skill_resource.gd")
const TALENT_DATA := preload("res://data/talent_resource.gd")
const TRAIT_DATA := preload("res://data/trait_resource.gd")

const OPERATOR_IDS := {
	"Mon3tr":"mon3tr_operator","令":"ling",

	"缇缇":"titi",
	"百炼嘉维尔":"gavial_alter","玛恩纳":"mlynar","歌蕾蒂娅":"gladiia","阿消":"shaw",
	"野鬃":"wildmane","森蚺":"eunectes","缪尔赛思":"muelsyse","涤火杰西卡":"jessica_alter",
	"白铁":"stainless",
	"澄闪":"goldenglow",
	"夕":"dusk",
	"假日威龙陈":"chen_alter",
	"菲亚梅塔":"fiammetta",

	"灵知":"gnosis",
	"淬羽赫默":"silence_alter",
	"伊内丝":"ines","伺夜":"vigil",
	"鸿雪":"pozyomka","老鲤":"lee",
	"焰影苇草":"reed_alter",
	"纯烬艾雅法拉":"eyjafjalla_alter",
	"空弦":"archetto",
	"帕拉斯":"pallas",
	"卡涅利安":"carnelian",
	"林":"lin",
	"瑕光":"blemishine",
	"斥罪":"penance",
	"缄默德克萨斯":"texas_alter",
	"棘刺":"thorns",
	"焰尾":"flametail",
	"极境":"elysium",
	"泥岩":"mudrock",
	"早露":"rosa",
	"异客":"passenger",
	"巫恋":"shamare",
	"食铁兽":"feater",

	"杰西卡":"jessica",
	"夜烟":"haze",
	"苏苏洛":"sussurro",
	"华法琳":"warfarin",
	"古米":"gummy",
	"波登可":"podenco",
	"山":"mountain",
	"史尔特尔":"surtr",
	"水月":"mizuki",

	"崖心":"cliffheart",
	"空":"sora",
	"赫默":"silence",
	"远山":"gitano",
	"陨星":"meteorite",
	"临光":"nearl",
	"赫拉格":"hellagur",
	"桃金娘":"myrtle",
	"凛冬":"zima",
	"雷蛇":"liskarm",
	"蓝毒":"blue_poison",
	"红":"projekt_red",
	"阿米娅":"amiya",
	"天火":"skyfire",
	"真理":"istina",
	"初雪":"pramanix",

	"白金":"platinum", "幽灵鲨":"specter", "调香师":"perfumer", "蛇屠箱":"cuora",
	"德克萨斯":"texas", "拉普兰德":"lappland", "白面鸮":"ptilopsis", "砾":"gravel",
	"浊心斯卡蒂": "skadi_alter",
	"流明": "lumen",
	"嵯峨": "saga",
	"W": "w",
	"凯尔希": "kaltsit",
	"年": "nian",
	"阿": "aak",
	"陈": "chen",
	"麦哲伦": "magallan",
	"温蒂": "weedy",
	"莫斯提马": "mostima",
	"塞雷娅": "saria",
	"推进之王": "siege",
	"伊芙利特": "ifrit",
	"提丰": "typhon",
	"风笛": "bagpipe",
	"煌": "blaze",
	"星熊": "hoshiguma",
	"安洁莉娜": "angelina",
	"能天使": "exusiai",
	"夜莺": "nightingale",
	"琳琅诗怀雅": "swire_alter",
	"刻俄柏": "ceobe",
	"闪灵": "shining",
	"银灰": "silverash",
	"艾雅法拉": "eyjafjalla",
	"铃兰": "suzuran",
	"琴柳": "saileach",
	"号角": "horn",
	"黑": "schwarz",
	"傀影": "phantom",
	"斯卡蒂": "skadi",
}

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
		"race_id", "initial_deploy_cost", "operator_name", "profession", "profession_id", "branch", "group_id", "max_health", "attack", "defense",
		"magic_resist", "damage_type", "block_count", "attack_speed", "deploy_cost",
		"redeploy_time", "dodge_physical", "dodge_magical", "attack_range", "skill_attack_range", "skill_burst_range",
		"terrain_requirement", "trait_name", "trait_description", "trait_effect_type",
		"trait_effect_params", "talent1_name", "talent1_description", "talent1_effect_type",
		"talent1_effect_params", "talent2_name", "talent2_description",
		"talent2_effect_type", "talent2_effect_params", "initial_sp",
		"skill_name", "sp_required", "sp_recharge_type", "skill_description",
		"skill_effect_type", "skill_effect_params", "skill_duration", "ignore_deploy_line", "trigger_type",
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

	var operators := {}
	for row in rows:
		var operator_data := _build_operator(row, columns)
		operators[operator_data.operator_id] = operator_data
	if not _append_skills(operators):
		return false
	for row in rows:
		var operator_data: OperatorData = operators[OPERATOR_IDS[row[columns["operator_name"]]]]
		var save_path := OUTPUT_PATH.path_join(operator_data.operator_id + ".tres")
		var save_error := ResourceSaver.save(operator_data, save_path)
		if save_error != OK:
			return _fail("Cannot save %s: %s" % [save_path, error_string(save_error)])
		print("Imported %s -> %s" % [operator_data.display_name, save_path])

	return true


func _validate_row(row: PackedStringArray, columns: Dictionary) -> bool:
	var name := row[columns["operator_name"]]
	if not OPERATOR_IDS.has(name): return _fail("CSV operator_name: unknown " + name)
	for column in ["initial_deploy_cost", "max_health", "attack", "defense", "block_count", "deploy_cost", "initial_sp", "sp_required"]:
		if not row[columns[column]].is_valid_int(): return _fail("CSV %s.%s: expected integer" % [name,column])
	for column in ["magic_resist", "attack_speed", "redeploy_time", "dodge_physical", "dodge_magical"]:
		if not row[columns[column]].is_valid_float() or not is_finite(row[columns[column]].to_float()): return _fail("CSV %s.%s: expected finite number" % [name,column])
	for column in ["magic_resist", "dodge_physical", "dodge_magical"]:
		if row[columns[column]].to_float() < 0 or row[columns[column]].to_float() > 1: return _fail("CSV %s.%s: expected fraction in 0..1" % [name,column])
	if row[columns["ignore_deploy_line"]] not in ["true","false"]: return _fail("CSV %s.ignore_deploy_line: expected bool" % name)
	if not _duration_is_valid(row[columns["skill_duration"]]): return _fail("CSV %s.skill_duration: invalid duration" % name)
	var error := _range_parse_error(row[columns["attack_range"]])
	if not error.is_empty(): return _fail("CSV %s.attack_range: %s" % [name,error])
	for column in ["skill_attack_range","skill_burst_range"]:
		error = _range_parse_error(row[columns[column]])
		if not error.is_empty(): return _fail("CSV %s.%s: %s" % [name,column,error])
	for column in ["trait_effect_params","talent1_effect_params","talent2_effect_params","skill_effect_params"]:
		error = _parameters_parse_error(row[columns[column]])
		if not error.is_empty(): return _fail("CSV %s.%s: %s" % [name,column,error])
	return true


func _integer_parameter_keys() -> PackedStringArray:
	var result := PackedStringArray()
	for table in [SkillResource.PARAMETERS,TraitResource.PARAMETERS]:
		for fields: Dictionary in table.values():
			for key in fields:
				if fields[key] == TYPE_INT and key not in result: result.append(key)
	for fields in TalentResource.PARAMETERS.values():
		for key in fields:
			if key not in ["profession_id", "group_id"] and key not in result: result.append(key)
	return result


func _parameters_parse_error(text: String) -> String:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary: return "expected JSON dictionary"
	for key in _integer_parameter_keys():
		if parsed.has(key) and (not parsed[key] is float or not is_finite(parsed[key]) or parsed[key] != floorf(parsed[key])): return "%s: expected integer value" % key
	return ""


func _range_parse_error(text: String) -> String:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Array: return "expected JSON coordinate array"
	for pair in parsed:
		if not pair is Array or pair.size() != 2: return "expected two coordinates"
		for value in pair:
			if not value is float or not is_finite(value) or value != floorf(value): return "expected integer coordinate"
			if absf(value) >= maxi(CONFIG.GRID_COLUMNS, CONFIG.GRID_ROWS): return "coordinate outside map extent"
	return ""


func _build_operator(row: PackedStringArray, columns: Dictionary) -> OperatorData:
	var operator_data := OPERATOR_DATA.new() as OperatorData
	operator_data.operator_id = OPERATOR_IDS[row[columns["operator_name"]]]
	operator_data.display_name = row[columns["operator_name"]]
	operator_data.group_id = row[columns["group_id"]]
	operator_data.race_id = row[columns["race_id"]]
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
	operator_data.initial_deploy_cost = row[columns["initial_deploy_cost"]].to_int()
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
		if key not in ["profession_id", "group_id"]:
			talent.effect_params[key] = int(talent.effect_params[key])
	return talent


func _build_skill(row: PackedStringArray, columns: Dictionary) -> SkillResource:
	var skill := SKILL_DATA.new() as SkillResource
	skill.initial_sp = row[columns["initial_sp"]].to_int()
	skill.trigger_type = row[columns["trigger_type"]]
	skill.skill_name = row[columns["skill_name"]]
	skill.sp_required = row[columns["sp_required"]].to_int()
	skill.sp_recharge_type = row[columns["sp_recharge_type"]]
	skill.description = row[columns["skill_description"]]
	skill.effect_type = row[columns["skill_effect_type"]]
	skill.effect_params = _parse_effect_params(row[columns["skill_effect_params"]])
	skill.duration = _parse_duration(row[columns["skill_duration"]])
	skill.attack_range_override = _parse_attack_range(row[columns["skill_attack_range"]])
	skill.burst_range_override = _parse_attack_range(row[columns["skill_burst_range"]])
	return skill


func _parse_attack_range(text: String) -> Array[Vector2i]:
	var parsed: Array = JSON.parse_string(text)
	var result: Array[Vector2i] = []
	for pair in parsed:
		result.append(Vector2i(pair[0], pair[1]))
	return result


func _parse_effect_params(text: String) -> Dictionary:
	var result: Dictionary = JSON.parse_string(text)
	for key in _integer_parameter_keys():
		if result.has(key): result[key] = int(result[key])
	return result


func _duration_is_valid(text: String) -> bool:
	if text.begins_with("瞬时") or (text.begins_with("常驻") or text in ["无限", "状态切换"]):
		return true
	if not text.ends_with("秒"):
		return false
	return text.trim_suffix("秒").is_valid_float() and is_finite(text.trim_suffix("秒").to_float())


func _parse_duration(text: String) -> float:
	if text.begins_with("瞬时"):
		return 0.0
	if (text.begins_with("常驻") or text in ["无限", "状态切换"]):
		return -1.0
	return text.trim_suffix("秒").to_float()


func _fail(message: String) -> bool:
	push_error(message)
	return false


func _append_skills(operators: Dictionary) -> bool:
	var file := FileAccess.open("res://import/skills.csv", FileAccess.READ)
	if file == null:
		return _fail("Cannot open additional skills CSV")
	var header := file.get_csv_line()
	var columns := {}
	for index in header.size():
		columns[header[index]] = index
	for column in ["operator_id", "skill_index", "initial_sp", "skill_name", "sp_required", "sp_recharge_type", "trigger_type", "skill_description", "skill_effect_type", "skill_effect_params", "skill_duration", "skill_attack_range", "skill_burst_range"]:
		if not columns.has(column):
			return _fail("Additional skills CSV missing column: " + column)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		if row.size() != header.size() or not operators.has(row[columns["operator_id"]]):
			return _fail("Invalid additional skill operator/columns")
		var operator: OperatorData = operators[row[columns["operator_id"]]]
		for column in ["skill_index", "initial_sp", "sp_required"]:
			if not row[columns[column]].is_valid_int():
				return _fail("Invalid additional skill integer: " + column)
		if row[columns["skill_index"]].to_int() != operator.skills.size() or operator.skills.size() >= 3:
			return _fail("Additional skill indices must be contiguous after S1")
		if not _duration_is_valid(row[columns["skill_duration"]]): return _fail("skills.csv %s.skill_duration: invalid duration" % operator.operator_id)
		var error := _parameters_parse_error(row[columns["skill_effect_params"]])
		if not error.is_empty(): return _fail("skills.csv %s.skill_effect_params: %s" % [operator.operator_id,error])
		var skill := _build_skill(row, columns)
		for column in ["skill_attack_range", "skill_burst_range"]:
			error = _range_parse_error(row[columns[column]])
			if not error.is_empty(): return _fail("skills.csv %s.%s: %s" % [operator.operator_id,column,error])
			var offsets := _parse_attack_range(row[columns[column]])
			if column == "skill_attack_range": skill.attack_range_override = offsets
			else: skill.burst_range_override = offsets
		operator.skills.append(skill)
	for operator: OperatorData in operators.values():
		var error := operator.validation_error()
		if not error.is_empty(): return _fail("CSV %s: %s" % [operator.operator_id,error])
	return true
