class_name ArenaData
extends Resource

@export var terrain_rows: PackedStringArray


func terrain_at(cell: Vector2i) -> String:
	var marker := terrain_rows[cell.y].substr(cell.x, 1)
	if marker == "g":
		return "ground"
	if marker == "h":
		return "high"
	if marker == "n":
		return "ground_no_deploy"
	return ""
