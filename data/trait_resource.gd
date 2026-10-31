class_name TraitResource
extends Resource

const PARAMETERS := {
	"chain_medic":{"target_count":TYPE_INT,"jump_heal_percent":TYPE_INT,"jump_radius_squared":TYPE_INT},
	"monstr_reconstruction":{"life_loss_per_second":TYPE_INT},
	"ling_summon":{"source_profession_id":TYPE_STRING,"module_index":TYPE_INT},

	"liberator":{"charge_ticks":TYPE_INT,"max_attack_bonus_percent":TYPE_INT},
	"sentinel":{},"flowing_shape":{"source_profession_id":TYPE_STRING,"split_lifetime_ticks":TYPE_INT,"split_attack_count":TYPE_INT,"steal_per_hit":TYPE_INT,"steal_limit":TYPE_INT},"jessica_shield":{"taunt_level":TYPE_INT},

	"duelist":{},
	"artisan":{},
	"stainless_device_1":{"mode":TYPE_INT,"attack_percent":TYPE_INT},
	"stainless_device_2":{"mode":TYPE_INT,"interval_ticks":TYPE_INT,"active_interval_ticks":TYPE_INT,"loss_basis_points":TYPE_INT},
	"stainless_device_3":{"mode":TYPE_INT,"charge_sp":TYPE_INT,"primary_percent":TYPE_INT,"splash_percent":TYPE_INT,"splash_radius_squared":TYPE_INT,"heal_percent":TYPE_INT,"loss_basis_points":TYPE_INT,"physical_reduction_percent":TYPE_INT},

	"dusk_freeling":{"source_profession_id":TYPE_STRING},
	"mechanical_float":{"initial_attack_percent":TYPE_INT,"attack_step_percent":TYPE_INT,"max_attack_percent":TYPE_INT},
	"spread_shot":{"front_attack_percent":TYPE_INT},

	"abjurer":{"skill_heal_percent":TYPE_INT},
	"silence_drone":{},
	"agent":{},
	"tactician":{"blocked_attack_percent":TYPE_INT},
	"vigil_wolf":{"source_profession_id":TYPE_STRING},
	"pozyomka_typewriter":{"source_profession_id":TYPE_STRING,"lifetime_ticks":TYPE_INT},
	"incantation_medic":{"heal_damage_percent":TYPE_INT},
	"wandering_medic":{"elemental_heal_percent":TYPE_INT},
	"phalanx":{"idle_defense_percent":TYPE_INT,"idle_resist_add":TYPE_INT},
	"mentor":{"unblocked_attack_mult":TYPE_FLOAT},
	"unyield":{},
	"chain_magic":{"target_count":TYPE_INT,"jump_radius_squared":TYPE_INT,"damage_remaining_percent":TYPE_INT,"slow_ticks":TYPE_INT},
	"curse_doll":{"lifetime_ticks":TYPE_INT,"attack_remaining_percent":TYPE_INT,"defense_remaining_percent":TYPE_INT},
	"ambusher":{"dodge_percent":TYPE_INT},
	"puller":{},
	"medical_drone":{"lifetime_ticks":TYPE_INT},
	"musha":{"heal_per_hit":TYPE_INT},
	"bard": {"regen_attack_percent": TYPE_INT},
	"seaborn": {"lifetime_ticks": TYPE_INT},
	"therapist": {"far_heal_percent": TYPE_INT},
	"physical_splash": {"splash_radius_squared": TYPE_INT},
	"mon3tr": {"source_profession_id": TYPE_STRING},
	"geek": {"life_loss_percent": TYPE_INT},
	"dual_strike": {"hit_count": TYPE_INT},
	"summoner": {},
	"summoner_drone": {"source_profession_id": TYPE_STRING, "module_index": TYPE_INT, "splash_radius_squared": TYPE_INT},
	"pusher": {},
	"water_cannon": {"source_profession_id": TYPE_STRING, "lifetime_ticks": TYPE_INT},
	"magic_splash": {"splash_radius_squared": TYPE_INT},
	"guardian": {},
	"line_magic": {},
	"prioritize_heavy": {},
	"fast_redeploy": {},
	"close_range_shot": {},
	"fortress": {"splash_radius_squared": TYPE_INT},
	"flag_bearer": {},
	"magical_attack": {},
	"ranged_attack": {"attack_percent": TYPE_INT},
	"prioritize_flying": {},
	"prioritize_blocked": {},
	"cost_drain": {"drain_amount": TYPE_INT, "drain_interval": TYPE_FLOAT},
	"refund_on_kill": {"refund_amount": TYPE_INT},
	"attack_all_blocked": {},
	"multi_target_heal": {"target_count": TYPE_INT},
	"single_target_heal": {},
	"slow_on_hit": {"slow_duration": TYPE_FLOAT},
	"phantom": {"life_loss_percent": TYPE_INT, "taunt_level": TYPE_INT},
	"executor_clone": {"source_profession_id": TYPE_STRING},
}

@export var trait_name: String
@export_multiline var description: String
@export var effect_type: String
@export var effect_params: Dictionary


func parameters_are_valid() -> bool:
	return validation_error().is_empty()


func validation_error() -> String:
	if not PARAMETERS.has(effect_type): return "effect_type: unknown effect " + effect_type
	var required: Dictionary = PARAMETERS[effect_type]
	for key in required:
		if not effect_params.has(key): return "effect_params.%s: required" % key
	for key in effect_params:
		if not required.has(key): return "effect_params.%s: unknown parameter" % key
		var value: Variant = effect_params[key]
		if typeof(value) != required[key]: return "effect_params.%s: expected %s" % [key,type_string(required[key])]
		if value is float and not is_finite(value): return "effect_params.%s: must be finite" % key
		if (value is int or value is float) and (value < 0 if key == "splash_radius_squared" and effect_type == "summoner_drone" else value <= 0): return "effect_params.%s: must be positive" % key
		if key == "source_profession_id" and value not in OperatorData.PROFESSION_IDS: return "effect_params.source_profession_id: unknown profession"
		if key == "attack_percent" and value > 100: return "effect_params.attack_percent: maximum 100"
	return ""
