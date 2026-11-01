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


static func acquisition_offsets(operator: OperatorData) -> Array[Vector2i]:
	var offsets := operator.attack_range.duplicate()
	if operator.branch_trait.effect_type == "fortress":
		offsets.append(Vector2i.ZERO)
	return offsets


static func effective_offsets(unit: UnitState, operator: OperatorData) -> Array[Vector2i]:
	if unit.operator_id=="flowing_shape" and not unit.flow_copy_id.is_empty():return unit.flow_range.duplicate()
	var skill := operator.skills[unit.skill_index]
	if SkillRules.active_ticks(unit)!=0 and skill.effect_type=="eyja_volcano":
		var global_range: Array[Vector2i]=[]
		for y in range(-SkillRules.CONFIG.GRID_ROWS+1,SkillRules.CONFIG.GRID_ROWS):
			for x in range(-SkillRules.CONFIG.GRID_COLUMNS+1,SkillRules.CONFIG.GRID_COLUMNS):global_range.append(Vector2i(x,y))
		return global_range
	if SkillRules.active_ticks(unit)>0 and skill.effect_type=="penance_ascetic":return []
	if skill.effect_type=="unyield_awakening":return acquisition_offsets(operator)
	if skill.effect_type=="pull_chain":return acquisition_offsets(operator)
	if SkillRules.active_ticks(unit) != 0 and skill.effect_type == "marked_arrow_rain":return SiegeRules.rain_offsets(unit,skill)
	if SkillRules.active_ticks(unit) != 0 and skill.effect_type!="nian_iron" and not skill.attack_range_override.is_empty():
		return skill.attack_range_override.duplicate()
	return acquisition_offsets(operator)
