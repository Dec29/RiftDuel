class_name CommandCodec
extends RefCounted

const CONFIG := preload("res://data/config.gd")


static func encode(commands: Array[InputCommand]) -> Array:
	var rows := []
	for command in commands:
		rows.append([command.tick, command.kind, command.operator_id, command.unit_id, command.cell.x, command.cell.y, command.skill_index, command.facing, command.item_kind])
	return rows


static func decode(rows: Variant, tick: int, allowed_ids: PackedStringArray, copy_ids: PackedStringArray = PackedStringArray()) -> Dictionary:
	if not rows is Array or rows.size() > 64:
		return {"error": "无效的指令批次"}
	var commands: Array[InputCommand] = []
	for row: Variant in rows:
		if not row is Array or row.size() != 9 or not row[2] is String:
			return {"error": "无效的指令字段"}
		for index in [0, 1, 3, 4, 5, 6, 7, 8]:
			if not is_integer(row[index], -1, 1000000000):
				return {"error": "指令字段必须是整数"}
		if int(row[0]) != tick or int(row[1]) not in [0, 1, 2, 3, 4, 5, 6] or int(row[7]) not in [-1, 0, 1, 2, 3]:
			return {"error": "指令帧或类型无效"}
		if int(row[1]) != InputCommand.Kind.USE_ITEM and int(row[8]) != -1:
			return {"error": "普通指令不能携带道具种类"}
		if int(row[1]) in [InputCommand.Kind.DEPLOY, InputCommand.Kind.RECOVERY_DEPLOY]:
			if row[2] not in allowed_ids or int(row[3]) != -1 or int(row[4]) not in range(CONFIG.GRID_COLUMNS) or int(row[5]) not in range(CONFIG.GRID_ROWS) or int(row[6]) != -1:
				return {"error": "部署指令无效"}
		elif int(row[1]) == InputCommand.Kind.SKIP_RECOVERY:
			if row[2] != "" or int(row[3]) != -1 or int(row[4]) != 0 or int(row[5]) != 0 or int(row[6]) != -1 or int(row[7]) != -1 or int(row[8]) != -1:
				return {"error": "暂停部署跳过指令无效"}
		elif int(row[1]) == InputCommand.Kind.COPY:
			if row[2] not in copy_ids or row[2] not in allowed_ids or int(row[3]) < 0 or int(row[4]) != 0 or int(row[5]) != 0 or int(row[6]) != -1 or int(row[7]) not in range(4):
				return {"error": "复制指令无效"}
		elif int(row[1]) == InputCommand.Kind.USE_ITEM:
			if row[2] != "" or int(row[3]) != -1 or int(row[4]) not in range(CONFIG.GRID_COLUMNS) or int(row[5]) not in range(CONFIG.GRID_ROWS) or int(row[6]) != -1 or int(row[8]) not in range(CONFIG.TACTICAL_ITEM_COUNT):
				return {"error": "道具指令无效"}
			if (int(row[7]) not in range(4) if int(row[8]) == CONFIG.TACTICAL_ITEM_CRANE else int(row[7]) != -1):
				return {"error": "道具朝向无效"}
		elif row[2] != "" or int(row[3]) < 0 or int(row[4]) != 0 or int(row[5]) != 0 or int(row[7]) != -1 or (int(row[6]) not in range(3) if int(row[1]) == InputCommand.Kind.SKILL else int(row[6]) != -1):
			return {"error": "技能或撤退指令无效"}
		commands.append(InputCommand.new(tick, int(row[1]), row[2], int(row[3]), Vector2i(int(row[4]), int(row[5])), int(row[6]), int(row[7]), int(row[8])))
	return {"commands": commands}


static func is_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
