class_name SkillRules
extends RefCounted

const CONFIG := preload("res://data/config.gd")


static func sp_limit(skill: SkillResource) -> int:
	if skill.effect_type == "charge_shot":
		return skill.sp_required * int(skill.effect_params["charge_count"])
	return skill.sp_required


static func can_activate(unit: UnitState, skill: SkillResource) -> bool:
	return unit.hp > 0 and unit.skill_ticks_left == 0 and skill.sp_recharge_type != "passive" and unit.sp >= skill.sp_required


static func is_auto_trigger(skill: SkillResource) -> bool:
	return skill.effect_type in ["atk_boost_auto", "atk_boost_single", "multi_shot", "charge_shot"]


static func can_manually_activate(unit: UnitState, skill: SkillResource) -> bool:
	return not is_auto_trigger(skill) and can_activate(unit, skill)


static func activate(unit: UnitState, operator: OperatorData) -> void:
	var skill := operator.skills[0]
	var old_interval := attack_interval_ticks(unit, operator)
	unit.sp -= skill.sp_required
	if skill.effect_type != "charge_shot":
		unit.sp_regen_ticks = 0
	unit.skill_ticks_left = roundi(skill.duration * CONFIG.TICK_RATE) if skill.duration > 0 else -1
	var new_interval := attack_interval_ticks(unit, operator)
	unit.attack_ticks_left = ceili(float(unit.attack_ticks_left) * new_interval / old_interval)


static func attack_value(unit: UnitState, operator: OperatorData) -> int:
	var bonus := unit.attack_bonus_percent
	if operator.talent_1.effect_type == "coin_income":
		bonus += unit.coin_attack_stacks * int(operator.talent_1.effect_params["attack_percent_per_stack"])
	if unit.skill_ticks_left == 0:
		return roundi(operator.attack * (100 + bonus) / 100.0)
	var skill := operator.skills[0]
	var multiplier := float(skill.effect_params["attack_mult"])
	if skill.effect_type in ["atk_spd_boost", "atk_def_boost", "atk_boost_auto", "heal_boost"]:
		return roundi(operator.attack * (multiplier + bonus / 100.0))
	return roundi(operator.attack * (100 + bonus) / 100.0 * multiplier)


static func defense_value(unit: UnitState, operator: OperatorData) -> int:
	var skill := operator.skills[0]
	var multiplier := 1.0 + unit.defense_bonus_percent / 100.0
	if unit.skill_ticks_left != 0 and skill.effect_type == "atk_def_boost":
		multiplier += float(skill.effect_params["defense_mult"]) - 1.0
	return roundi(operator.defense * multiplier)


static func max_health_value(unit: UnitState, operator: OperatorData) -> int:
	return roundi(operator.max_health * (100 + unit.max_health_bonus_percent) / 100.0)


static func magic_resist_value(unit: UnitState, operator: OperatorData) -> int:
	return mini(100, operator.magic_resist + unit.magic_resist_bonus)


static func talent_is_active(talent: TalentResource) -> bool:
	return talent.effect_type in ["coin_income", "attack_proc", "initial_sp_aura", "emergency_heal", "damage_block", "defense_aura", "attack_speed_aura", "inactive_regen_aura", "attack_speed_buff", "random_blessing", "magic_resist_aura", "summon_phantom", "fatal_revive", "defense_damage", "isolated_buff"]


static func attack_interval_ticks(unit: UnitState, operator: OperatorData) -> int:
	var skill := operator.skills[0]
	var speed := 100 + unit.attack_speed_bonus
	if unit.skill_ticks_left != 0 and skill.effect_type == "atk_spd_boost":
		speed += int(skill.effect_params["attack_speed_add"])
	return maxi(1, roundi(operator.attack_interval * CONFIG.TICK_RATE * 100.0 / speed))
