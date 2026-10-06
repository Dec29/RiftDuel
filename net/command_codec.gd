class_name CommandCodec
extends RefCounted

const IDS := ["angelina", "bagpipe", "blaze", "ceobe", "exusiai", "hoshiguma", "nightingale", "swire_alter", "nightingale_phantom"]
const CONFIG := preload("res://data/config.gd")


static func encode(commands: Array[InputCommand]) -> Array:
	var rows := []
	for command in commands:
		rows.append([command.tick, command.kind, command.operator_id, command.unit_id, command.cell.x, command.cell.y, command.skill_index, command.facing])
	return rows


static func decode(rows: Variant, tick: int) -> Dictionary:
	if not rows is Array or rows.size() > 64:
		return {"error": "无效的指令批次"}
	var commands: Array[InputCommand] = []
	for row: Variant in rows:
		if not row is Array or row.size() != 8 or not row[2] is String:
			return {"error": "无效的指令字段"}
		for index in [0, 1, 3, 4, 5, 6, 7]:
			if not is_integer(row[index], -1, 1000000000):
				return {"error": "指令字段必须是整数"}
		if int(row[0]) != tick or int(row[1]) not in [0, 1, 2] or int(row[7]) not in [-1, 0, 1, 2, 3]:
			return {"error": "指令帧或类型无效"}
		if int(row[1]) == InputCommand.Kind.DEPLOY:
			if row[2] not in IDS or int(row[3]) != -1 or int(row[4]) not in range(CONFIG.GRID_COLUMNS) or int(row[5]) not in range(CONFIG.GRID_ROWS) or int(row[6]) != -1:
				return {"error": "部署指令无效"}
		elif row[2] != "" or int(row[3]) < 0 or int(row[4]) != 0 or int(row[5]) != 0 or int(row[7]) != -1 or int(row[6]) != (0 if int(row[1]) == InputCommand.Kind.SKILL else -1):
			return {"error": "技能或撤退指令无效"}
		commands.append(InputCommand.new(tick, int(row[1]), row[2], int(row[3]), Vector2i(int(row[4]), int(row[5])), int(row[6]), int(row[7])))
	return {"commands": commands}


static func is_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
