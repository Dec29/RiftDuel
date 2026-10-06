class_name AttackRange
extends RefCounted


static func rotate_offset(offset: Vector2i, facing: int) -> Vector2i:
	if facing == 1:
		return Vector2i(-offset.y, offset.x)
	if facing == 2:
		return -offset
	if facing == 3:
		return Vector2i(offset.y, -offset.x)
	return offset
