extends SceneTree

const CONFIG := preload("res://data/config.gd")
const COMBAT := preload("res://sim/combat.gd")
const OPERATOR_DB := preload("res://data/operator_db.gd")
const ARENA := preload("res://resources/map/standard_arena.tres")
const EXPECTED_IDS := [
	"angelina",
	"bagpipe",
	"blaze",
	"ceobe",
	"exusiai",
	"hoshiguma",
	"nightingale",
	"swire_alter",
]
const DAMAGE_TYPES := ["physical", "magical", "true", "healing"]
const TERRAIN_TYPES := ["ground", "high", "both"]
const EXPECTED_DATA := {
	"angelina": ["安洁莉娜", 542, 25, "atk_boost_auto", 35.0],
	"bagpipe": ["风笛", 586, 0, "atk_spd_boost", 35.0],
	"blaze": ["煌", 765, 0, "atk_boost_single", 0.0],
	"ceobe": ["刻俄柏", 667, 20, "charge_shot", 0.0],
	"exusiai": ["能天使", 540, 0, "multi_shot", 0.0],
	"hoshiguma": ["星熊", 430, 0, "atk_def_boost", 30.0],
	"nightingale": ["夜莺", 350, 5, "heal_boost", 30.0],
	"swire_alter": ["琳琅诗怀雅", 810, 0, "passive_heal", -1.0],
}


func _initialize() -> void:
	var directory := DirAccess.open("res://resources/operators")
	if directory == null:
		_fail("Operator resource directory is missing")
		return

	var actual_ids: Array[String] = []
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var operator_data := ResourceLoader.load("res://resources/operators".path_join(file_name)) as OperatorData
		if operator_data == null:
			_fail("Failed to load operator resource: %s" % file_name)
			return
		if operator_data.operator_id.is_empty() or operator_data.display_name.is_empty():
			_fail("Operator identity is empty: %s" % file_name)
			return
		if operator_data.damage_type not in DAMAGE_TYPES:
			_fail("Invalid damage_type for %s: %s" % [operator_data.operator_id, operator_data.damage_type])
			return
		if operator_data.terrain_requirement not in TERRAIN_TYPES:
			_fail("Invalid terrain for %s: %s" % [operator_data.operator_id, operator_data.terrain_requirement])
			return
		if operator_data.magic_resist < 0 or operator_data.magic_resist > 100:
			_fail("Invalid magic_resist for %s: %d" % [operator_data.operator_id, operator_data.magic_resist])
			return
		if operator_data.skills.size() != 1:
			_fail("Expected one imported skill for %s, got %d" % [operator_data.operator_id, operator_data.skills.size()])
			return
		if operator_data.branch_trait == null or operator_data.talent_1 == null or operator_data.talent_2 == null:
			_fail("Missing nested resource for %s" % operator_data.operator_id)
			return
		if operator_data.attack_range.is_empty():
			_fail("Empty attack range for %s" % operator_data.operator_id)
			return
		if operator_data.ignore_deploy_line:
			_fail("M0 operator unexpectedly ignores deploy line: %s" % operator_data.operator_id)
			return

		var expected: Array = EXPECTED_DATA[operator_data.operator_id]
		var skill := operator_data.skills[0]
		if operator_data.display_name != expected[0] or operator_data.attack != expected[1]:
			_fail("Core data mismatch for %s" % operator_data.operator_id)
			return
		if operator_data.magic_resist != expected[2]:
			_fail("Magic resistance conversion mismatch for %s: %d" % [operator_data.operator_id, operator_data.magic_resist])
			return
		if skill.effect_type != expected[3] or skill.duration != expected[4]:
			_fail("Skill conversion mismatch for %s: %s / %s" % [operator_data.operator_id, skill.effect_type, skill.duration])
			return
		actual_ids.append(operator_data.operator_id)

	actual_ids.sort()
	if actual_ids != EXPECTED_IDS:
		_fail("Operator ids mismatch. Expected %s, got %s" % [EXPECTED_IDS, actual_ids])
		return
	var operator_db := OPERATOR_DB.new()
	operator_db._ready()
	if Array(operator_db.all_ids()) != EXPECTED_IDS:
		_fail("OperatorDB did not load the expected ids")
		return
	operator_db.free()
	if CONFIG.TICK_RATE != 30 or CONFIG.BALL_START_CELL != Vector2i(10, 5):
		_fail("Config baseline mismatch")
		return

	var ball := ResourceLoader.load("res://resources/ball/standard.tres") as BallData
	if ball == null:
		_fail("Failed to load standard ball resource")
		return
	if ball.kick_threshold != 2000 or ball.push_ratio != 1:
		_fail("Unexpected ball tuning: threshold=%d ratio=%d" % [ball.kick_threshold, ball.push_ratio])
		return
	if ARENA.terrain_rows.size() != CONFIG.GRID_ROWS:
		_fail("Arena row count mismatch")
		return
	for row in ARENA.terrain_rows:
		if row.length() != CONFIG.GRID_COLUMNS:
			_fail("Arena column count mismatch")
			return
		for marker in row:
			if marker not in [".", "g", "h", "n"]:
				_fail("Arena contains an unknown terrain marker: %s" % marker)
				return

	if COMBAT.calculate_damage(810, 161, 0, "physical", 0, RNG.new(1), "specialist") != 174:
		_fail("Physical damage calculation mismatch")
		return
	if COMBAT.calculate_damage(667, 0, 20, "magical", 0, RNG.new(1), "caster") != 160:
		_fail("Magical damage calculation mismatch")
		return
	if COMBAT.calculate_damage(500, 999, 99, "true", 100, RNG.new(1), "guard") != 200:
		_fail("True damage calculation mismatch")
		return
	if COMBAT.calculate_damage(100, 999, 0, "physical", 0, RNG.new(1), "guard") != 2:
		_fail("Minimum physical damage mismatch")
		return
	if COMBAT.calculate_damage(500, 0, 0, "physical", 40, RNG.new(0x12345678), "guard") != 0:
		_fail("Physical dodge calculation mismatch")
		return

	print("L1 OK: data, damage, dodge, and ball parameters")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
