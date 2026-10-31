class_name Combat
extends RefCounted

const CONFIG := preload("res://data/config.gd")


static func calculate_damage(
	attack: int,
	defense: int,
	magic_resist: int,
	damage_type: String,
	dodge_chance: int,
	rng: RNG,
	profession_id: String,
	damage_taken_percent: float = 100.0,
	magical_damage_taken_percent: int = 100,
	minimum_damage_percent: int = CONFIG.UNIT_MIN_DAMAGE_PERCENT,
) -> int:
	var damage_percent: int = CONFIG.UNIT_DAMAGE_PERCENT_BY_PROFESSION[profession_id]
	if damage_percent == 0:
		return 0
	if damage_type != "true" and dodge_chance > 0 and rng.next_percent() < dodge_chance:
		return 0

	var base_damage: float
	if damage_type == "physical":
		base_damage = maxf(attack * minimum_damage_percent / 100.0, attack - defense * CONFIG.UNIT_EFFECTIVE_DEFENSE_PERCENT / 100.0)
	elif damage_type == "magical":
		base_damage = maxf(attack * minimum_damage_percent / 100.0, attack * (100 - magic_resist) / 100.0)
	else:
		assert(damage_type == "true")
		base_damage = attack
	var magical_multiplier := magical_damage_taken_percent / 100.0 if damage_type == "magical" else 1.0
	return maxi(1, roundi(base_damage * damage_percent / 100.0 * (damage_taken_percent / 100.0) * magical_multiplier))


static func calculate_healing(attack: int, heal_percent: int = 100) -> int:
	return roundi(attack * heal_percent * CONFIG.UNIT_HEAL_PERCENT / 10000.0)
