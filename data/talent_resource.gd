class_name TalentResource
extends Resource

const PARAMETERS := {
	"coin_income": ["initial_coins", "coins_per_drain", "attack_percent_per_stack", "max_attack_stacks"],
	"attack_proc": ["chance_percent", "attack_percent", "target_count"],
	"initial_sp_aura": ["profession_id", "initial_sp_add"],
	"emergency_heal": ["hp_threshold_percent", "heal_percent", "lock_hp_percent", "lock_duration"],
	"status_resistance": ["warmup_seconds"],
	"damage_block": ["chance_percent"],
	"defense_aura": ["profession_id", "defense_percent"],
	"attack_speed_aura": ["attack_speed_add"],
	"inactive_regen_aura": ["heal_per_second"],
	"attack_speed_buff": ["attack_speed_add"],
	"random_blessing": ["attack_percent", "max_health_percent", "target_count"],
	"magic_resist_aura": ["magic_resist_add"],
	"summon_phantom": ["stock_per_deploy", "stock_limit"],
	"fatal_revive": ["initial_cost", "heal_percent", "cost_multiplier"],
	"defense_damage": ["defense_damage_percent"],
	"isolated_buff": ["attack_percent", "attack_speed_add"],
}

@export var talent_name: String
@export_multiline var description: String
@export var effect_type: String
@export var effect_params: Dictionary


func parameters_are_valid() -> bool:
	if not PARAMETERS.has(effect_type) or effect_params.size() != PARAMETERS[effect_type].size():
		return false
	for key in PARAMETERS[effect_type]:
		var value: Variant = effect_params.get(key)
		if key == "profession_id":
			if value not in OperatorData.PROFESSION_IDS:
				return false
		elif not value is int or value <= 0:
			return false
		elif key in ["chance_percent", "hp_threshold_percent", "heal_percent", "lock_hp_percent"] and value > 100:
			return false
	return true
