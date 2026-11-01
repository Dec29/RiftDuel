class_name NianRules
extends RefCounted


static func reflect(state: MatchState, target: UnitState, data: OperatorData, source: UnitState) -> void:
	if source==null or source.hp<=0 or target.hp<=0 or source.side==target.side or SkillRules.active_ticks(target)<=0:return
	var skill := data.skills[target.skill_index]
	if skill.effect_type!="nian_copper":return
	var source_data: OperatorData=state._operator_data[source.operator_id]
	var attack := roundi(SkillRules.attack_value(target,data)*int(skill.effect_params["reflect_attack_percent"])/100.0)
	var damage := Combat.calculate_damage(attack,SkillRules.defense_value(source,source_data),SkillRules.magic_resist_value(source,source_data),"magical",SkillRules.dodge_chance(source,source_data,"magical"),state.rng,data.profession_id,state._damage_taken_percent(source, "magical"),state._magical_damage_taken_percent(source))
	# A reflected hit has no direct attacker, so two copper seals cannot recurse.
	state._apply_damage(source,source_data,damage,"magical")
	if source.hp>0:StatusRules.apply_silence(state,source,int(skill.effect_params["silence_ticks"]))
