class_name TalentResource
extends Resource

const PARAMETERS := {
	"monstr_reconstruct":["max_count","attack_percent"],
	"monstr_synergy":["attack_speed_add","duration_ticks"],
	"ling_supply":["stock_count","max_count"],
	"ling_recycle":["sp_add","attack_percent","max_stacks"],

	"ling_advanced_form":["health_percent","attack_percent","defense_percent","resist_percent","interval_add_ticks","block_add"],
	"titi_frozen_time":["extra_attack_percent","dot_attack_percent","first_dot_ticks","dot_interval_ticks"],
	"titi_courage":["attack_speed_add","hp_threshold_percent"],

	"gavial_blocking":["base_percent","percent_per_block"],
	"gavial_healing":["heal_percent","low_heal_percent","hp_threshold_percent"],
	"mlynar_roamer":["attack_percent","surrounded_attack_percent","enemy_count","damage_reduce_percent"],
	"mlynar_indifference":["taunt_level","reflect_attack_percent"],
	"gladiia_tide":["regen_max_health_permille","seaborn_damage_reduce_percent"],
	"gladiia_predation":["max_weight","attack_percent"],

	"flowing_shape_supply":["copy_percent","refresh_ticks"],"rhine_deploy_discount":["cost_reduction","first_reduction"],"jessica_shield_supply":["shield_lifetime_ticks","behind_defense_percent"],"shield_damage_sp":["chance_percent","sp_add"],

	"guard_deploy_discount":["discount_per_deploy","max_discount"],"duelist_health":["hp_threshold_percent","damage_percent","sanctuary_percent"],"duelist_sp":["sp_bonus_percent"],
	"stainless_supply":["stock_count","max_count"],
	"stainless_recycle":["chance_percent"],
	"drone_explosion":["probability_step_basis_points", "max_stacks", "attack_percent", "splash_radius_squared"],
	"dusk_kill_stacks":["attack_percent_per_kill", "max_stacks"],
	"dusk_first_freeling":["lifetime_ticks"],
	"ammo_saving":["self_chance_percent", "ally_chance_percent"],
	"chen_holiday_speed":["attack_speed_add", "water_attack_speed_add"],
	"fiammetta_suffering":["pulse_ticks", "loss_basis_points", "hp_threshold_percent", "attack_percent", "high_hp_threshold_percent", "high_attack_percent"],
	"fiammetta_finale":["attack_speed_add"],

	"cold_fragile":{"cold_ticks":TYPE_INT,"cold_fragile_percent":TYPE_INT,"frozen_fragile_percent":TYPE_INT},
	"kjerag_resistance":{"warmup_ticks":TYPE_INT},
	"abjurer_protection":{"base_percent":TYPE_INT,"max_percent":TYPE_INT,"min_hp_percent":TYPE_INT},
	"rhine_regeneration":{"hp_threshold_percent":TYPE_INT,"regen_attack_percent":TYPE_INT,"group_multiplier":TYPE_INT},
	"ines_first_strike":["attack_steal","attack_limit","bind_ticks"],
	"ines_shadow":["speed_reduce"],
	"vigil_pack":["initial_layers","max_layers","regrow_ticks"],
	"vigil_penetration":["defense_ignore"],
	"typewriter_supply":["max_count", "lifetime_ticks"],
	"typewriter_weakness":["defense_remaining_percent", "adjacent_defense_remaining_percent", "duration_ticks"],
	"lee_block_speed":["attack_speed_add", "enemy_attack_speed_reduce"],
	"lee_control_charm":["drain_amount", "stun_ticks"],

	"reed_cinder":["chance_percent","attack_reduce_percent","magic_fragile_percent","duration_ticks"],
	"reed_reflected_heal":["heal_percent"],
	"eyja_mist":["heal_percent","duration_ticks","max_stacks"],
	"eyja_health_aura":["health_percent","elemental_resistance_percent"],
	"texas_tradition":["attack_percent"],
	"texas_swordsmanship":["attack_speed_add","damage_remaining_percent"],
	"penance_barrier":["deploy_health_percent","kill_health_percent","cap_health_percent"],
	"barrier_reflect":["attack_percent"],
	"defensive_attack_sp":["sp_add"],
	"sleep_mercy":["attack_percent"],
	"glass_wall":["damage_threshold","attack_percent","stun_ticks","recovery_ticks"],
	"damage_sp_proc":["chance_percent","sp_add"],
	"charged_skill_heal":["heal_percent","charged_heal_percent"],
	"overcharge_sp":["sp_recharge_bonus_percent"],
	"minos_vigor":["group_id","hp_threshold_percent","attack_percent","check_interval_ticks"],
	"mentor_heal":["heal_per_hit"],
	"sniper_offensive_sp":["interval_ticks","sp_add"],
	"shield_break_sp":["shield_count","sp_add"],
	"lord_neurotoxin":["damage","ranged_damage","duration_ticks"],
	"idle_health_regeneration":["idle_ticks","health_basis_points"],
	"dodge_counter":["shot_count"],
	"group_physical_dodge":["group_id", "dodge_percent"],
	"sniper_support":["cost_reduction", "attack_speed_add"],
	"regenerating_shield":["interval_ticks", "max_layers", "initial_layers", "heal_percent"],
	"sarkaz_damage_reduction":["damage_remaining_percent"],
	"heavy_penetration":["weight_threshold", "defense_ignore_percent"],
	"high_health_damage_mark":["hp_threshold_percent", "damage_percent", "duration_ticks"],
	"isolated_enemy_attack":["attack_percent"],
	"physical_dodge":["dodge_percent"],

	"hit_resist_reduction":["resist_remaining_percent", "duration_ticks"],
	"low_cost_healing_aura":["cost_threshold", "heal_percent"],
	"death_sp_in_range":["sp_add"],
	"stun_attack_proc":["chance_percent", "attack_percent", "stun_ticks"],
	"attack_weaken_proc":["chance_percent", "attack_percent", "attack_remaining_percent", "duration_ticks"],
	"defense_dodge":["defense_percent", "dodge_percent"],
	"flat_resist_penetration":["resist_ignore"],
	"fatal_delay":["duration_ticks"],
	"lowest_health_arts":["attack_percent", "target_count"],
	"wounded_enemy_attack":["hp_threshold_percent", "attack_percent"],

	"unblocked_atk_def":["attack_percent","defense_percent"],
	"encore_sp":["chance_percent","sp_percent"],
	"profession_attack_speed_aura":["profession_id","attack_speed_add"],
	"deployment_fortune":["attack_percent","attack_speed_add","health_percent"],
	"explosive_attack":["chance_percent","attack_bonus_percent"],
	"healing_output_aura":["healing_bonus_percent"],
	"health_attack_speed":["max_attack_speed", "loss_cap_percent", "samples_per_second"],
	"unblocked_regeneration":["heal_per_second"],
	"profession_regeneration":["profession_id", "heal_per_second"],
	"vanguard_cost":["cost_reduction"],
	"defensive_sp":["sp_add"],
	"self_magic_resist":["magic_resist_add"],
	"neurotoxin":["damage", "duration_ticks", "pulse_ticks"],
	"minimum_attack":["minimum_percent"],
	"emotional_absorption":["attack_sp", "kill_sp"],
	"blocked_magic_vulnerability":["damage_percent"],
	"explorer":["defense_reduce_percent", "attack_speed_add"],
	"low_health_fragile":["hp_threshold_percent", "fragile_percent"],
	"double_target":["target_count"],

	"charged_attack":["min_ticks","max_ticks","max_attack_percent"],
	"abyssal_regeneration":["health_percent","regen_health_percent"],
	"global_attack_regeneration":["regen_attack_percent"],"self_defense":["defense_percent"],
	"initial_cost":["cost_add"], "attack_silence":["duration_ticks"],
	"global_sp_recharge":["sp_recharge_bonus_percent"],
	"low_cost_support":["cost_reduction","cost_threshold","defense_percent"],
	"summon_seaborn": ["max_count"],
	"bard_predation": ["attack_percent", "abyssal_attack_percent"],
	"heal_resistance": ["base_ticks", "high_ticks", "hp_threshold_percent"],
	"emergency_control_heal": ["heal_percent", "cooldown_ticks"],
	"critical_wound": ["duration_ticks", "attack_speed_remaining_percent", "sp_add"],
	"saga_focus": ["hp_threshold_percent", "dodge_percent", "regen_health_percent", "duration_ticks"],
	"delayed_ambush": ["warmup_ticks", "dodge_percent"],
	"stunned_physical_aura": ["damage_percent"],
	"mon3tr_control": ["max_count"],
	"death_rebuild": ["damage", "stun_ticks"],
	"profession_health_aura": ["profession_id", "health_percent"],
	"deploy_shield_layers": ["shield_count"],
	"mixed_drugs": ["heal_percent", "attack_percent", "slow_ticks", "stun_ticks"],
	"healing_received": ["heal_percent"],
	"offensive_sp_aura": ["interval_ticks", "sp_add"],
	"sword_training": ["attack_percent", "defense_percent", "dodge_physical_add"],
	"drone_supply": ["stock_count", "max_count"],
	"drone_concealment": ["hidden_ticks"],
	"cooling_emitter": ["pulse_ticks", "slow_ticks", "bind_ticks"],
	"summon_water_cannon": ["max_count"],
	"water_cannon_support": ["shift_force_add", "sp_interval_ticks", "sp_add"],
	"movement_slow_aura": ["move_speed_reduce_percent"],
	"rhine_suit": ["interval_ticks", "max_stacks", "attack_percent", "defense_percent"],
	"healing_sp": ["sp_add"],
	"profession_atk_def_aura": ["profession_id", "attack_percent", "defense_percent"],
	"adjacent_death_sp": ["sp_add"],
	"enemy_resist_aura": ["resist_reduce_percent"],
	"periodic_sp": ["sp_add", "interval_ticks"],
	"stack_defense_penetration": ["max_stacks", "penetration_per_stack", "reset_ticks"],
	"first_skill_hit": ["attack_percent", "slow_ticks"],
	"none": [],
	"group_attack_aura": ["group_id", "attack_percent"],
	"redeploy_reduction": ["reduction_seconds"],
	"summon_clone": ["max_count"],
	"clone_redeploy_reduction": ["reduction_seconds"],
	"armor_break_proc": ["chance_percent", "attack_percent", "defense_remaining_percent", "duration_ticks"],
	"sniper_crossfire": ["profession_id", "attack_percent"],
	"bloodbath": ["max_health_percent", "attack_speed_add", "defense_percent"],
	"flag_attack_speed_aura": ["ally_attack_speed_add", "enemy_attack_speed_reduce"],
	"next_deploy_discount": ["deploy_cost_reduction"],
	"sp_recharge_aura": ["profession_id", "sp_recharge_bonus_percent"],
	"slow_fragile_aura": ["damage_taken_bonus_percent"],
	"attack_aura": ["profession_id", "attack_percent"],
	"random_initial_sp": ["sp_min", "sp_max_exclusive"],
	"attack_redeploy_buff": ["attack_percent", "redeploy_reduction_percent"],
	"reveal_invisible": [],
	"defense_flat_aura": ["defense_add"],
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
	return validation_error().is_empty()


func validation_error() -> String:
	if not PARAMETERS.has(effect_type): return "effect_type: unknown effect " + effect_type
	for key in PARAMETERS[effect_type]:
		if not effect_params.has(key): return "effect_params.%s: required" % key
	for key in effect_params:
		if key not in PARAMETERS[effect_type]: return "effect_params.%s: unknown parameter" % key
		var value: Variant = effect_params[key]
		if key == "group_id":
			if value not in ["abyssal","ursus_student","kazimierz","minos"]: return "effect_params.group_id: unknown group"
		elif key == "profession_id":
			if value not in OperatorData.PROFESSION_IDS: return "effect_params.profession_id: unknown profession"
		elif not value is int or value <= 0: return "effect_params.%s: expected positive int" % key
		elif not (effect_type in ["healing_received","gavial_healing"] and key=="heal_percent") and key in ["resist_reduce_percent", "chance_percent", "defense_remaining_percent", "hp_threshold_percent", "heal_percent", "lock_hp_percent"] and value > 100: return "effect_params.%s: maximum 100" % key
		elif key == "redeploy_reduction_percent" and value >= 100: return "effect_params.redeploy_reduction_percent: must be below 100"
	if effect_type=="encore_sp" and effect_params["sp_percent"]>100:return "effect_params.sp_percent: maximum100"
	if effect_type=="charged_attack" and (effect_params["min_ticks"]>=effect_params["max_ticks"] or effect_params["max_attack_percent"]<100):return "effect_params: invalid charge interval or multiplier"
	if effect_type == "random_initial_sp" and effect_params["sp_min"] >= effect_params["sp_max_exclusive"]: return "effect_params.sp_min: must be below sp_max_exclusive"
	if effect_type == "stack_defense_penetration" and effect_params["max_stacks"] * effect_params["penetration_per_stack"] > 100: return "effect_params: penetration exceeds 100"
	return ""
