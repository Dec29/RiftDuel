class_name SkillRangePreview
extends RefCounted


static func offsets(operator: OperatorData, skill: SkillResource) -> Array[Vector2i]:
	return skill.burst_range_override.duplicate() if skill.effect_type == "ramp_burst" else skill.attack_range_override.duplicate()


static func available(operator: OperatorData, skill: SkillResource) -> bool:
	var changed := offsets(operator,skill)
	var base := AttackRange.acquisition_offsets(operator)
	if changed.is_empty(): return false
	if changed.size()!=base.size(): return true
	for cell in changed:
		if cell not in base: return true
	return false
