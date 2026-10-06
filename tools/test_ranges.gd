extends SceneTree

# 精英 2 基础范围：PRTS 干员页面及游戏 range_table 的 1-1 / 3-1 / 3-3 / y-2。
# 所有坐标以干员向右为基准；自身格固定为 (0, 0)。
const EXPECTED := {
	"bagpipe": [Vector2i(0, 0), Vector2i(1, 0)],
	"blaze": [Vector2i(0, 0), Vector2i(1, 0)],
	"hoshiguma": [Vector2i(0, 0), Vector2i(1, 0)],
	"swire_alter": [Vector2i(0, 0), Vector2i(1, 0)],
	"exusiai": [Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, -1), Vector2i(3, 0), Vector2i(3, 1)],
	"ceobe": [Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 0)],
	"angelina": [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1)],
	"nightingale": [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1)],
}
const NAME_TO_ID := {
	"风笛": "bagpipe",
	"煌": "blaze",
	"星熊": "hoshiguma",
	"琳琅诗怀雅": "swire_alter",
	"能天使": "exusiai",
	"刻俄柏": "ceobe",
	"安洁莉娜": "angelina",
	"夜莺": "nightingale",
}


func _initialize() -> void:
	for operator_id in EXPECTED:
		var operator_data := load("res://resources/operators/%s.tres" % operator_id) as OperatorData
		var expected: Array = EXPECTED[operator_id]
		if Array(operator_data.attack_range) != expected:
			push_error("%s range: expected %s, got %s" % [operator_id, expected, operator_data.attack_range])
			quit(1)
			return
	var csv := FileAccess.open("res://import/operators.csv", FileAccess.READ)
	var header := csv.get_csv_line()
	var name_column := header.find("operator_name")
	var range_column := header.find("attack_range")
	var checked_ids: Array[String] = []
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		var operator_id: String = NAME_TO_ID[row[name_column]]
		var coordinates: Array = JSON.parse_string(row[range_column])
		var actual: Array[Vector2i] = []
		for coordinate in coordinates:
			actual.append(Vector2i(int(coordinate[0]), int(coordinate[1])))
		if Array(actual) != EXPECTED[operator_id]:
			push_error("%s CSV range: expected %s, got %s" % [operator_id, EXPECTED[operator_id], actual])
			quit(1)
			return
		checked_ids.append(operator_id)
	if checked_ids.size() != EXPECTED.size():
		push_error("Expected %d CSV operators, got %s" % [EXPECTED.size(), checked_ids])
		quit(1)
		return
	print("L1 OK: eight E2 attack ranges include own cell; resources and CSV agree")
	quit(0)
