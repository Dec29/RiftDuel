class_name OperatorData
extends Resource

const PROFESSION_IDS := ["vanguard", "guard", "defender", "sniper", "caster", "medic", "supporter", "specialist"]
const SINGLE_TALENT_IDS := ["wildmane","shaw","elysium","shamare","feater","jessica","haze","sussurro","warfarin","gummy","podenco","cliffheart","sora","silence","gitano","meteorite","nearl","myrtle","zima","blue_poison","projekt_red","amiya","skyfire","istina","platinum","specter","perfumer","cuora","texas","lappland","ptilopsis","gravel"]
const TALENT_SLOTS := {
	"monstr_reconstruct":1,"monstr_synergy":2,
	"ling_supply":1,"ling_recycle":2,"ling_advanced_form":1,
	"titi_frozen_time":1,"titi_courage":2,
	"gavial_blocking":1,"gavial_healing":2,"mlynar_roamer":1,"mlynar_indifference":2,"gladiia_tide":1,"gladiia_predation":2,
	"flowing_shape_supply":1,"rhine_deploy_discount":2,"jessica_shield_supply":1,"shield_damage_sp":2,
	"guard_deploy_discount":1,"duelist_health":1,"duelist_sp":2,
	"stainless_supply":1,"stainless_recycle":2,
	"drone_explosion":1,
	"dusk_kill_stacks":1,
	"dusk_first_freeling":2,
	"ammo_saving":1,
	"chen_holiday_speed":2,
	"fiammetta_suffering":1,
	"fiammetta_finale":2,

	"cold_fragile":1,"kjerag_resistance":2,"abjurer_protection":1,"rhine_regeneration":2,
	"ines_first_strike":1,"ines_shadow":2,"vigil_pack":1,"vigil_penetration":2,
	"typewriter_supply":1,"typewriter_weakness":3,"lee_block_speed":1,"lee_control_charm":2,
	"reed_cinder":1,"reed_reflected_heal":2,"eyja_mist":1,"eyja_health_aura":2,
	"texas_tradition":1,"texas_swordsmanship":2,
	"penance_barrier":1,"barrier_reflect":2,
	"defensive_attack_sp":1,"sleep_mercy":2,
	"glass_wall":1,"damage_sp_proc":2,
	"charged_skill_heal":1,"overcharge_sp":2,
	"minos_vigor":1,"mentor_heal":2,
	"sniper_offensive_sp":1,"shield_break_sp":2,
	"lord_neurotoxin":1,"idle_health_regeneration":2,
	"dodge_counter":1,
	"group_physical_dodge":2,
	"sniper_support":1,
	"regenerating_shield":1,
	"sarkaz_damage_reduction":2,
	"heavy_penetration":1,
	"high_health_damage_mark":1,
	"isolated_enemy_attack":2,
	"physical_dodge":1,

	"hit_resist_reduction":1,
	"low_cost_healing_aura":1,
	"death_sp_in_range":1,
	"stun_attack_proc":1,
	"attack_weaken_proc":1,
	"defense_dodge":2,
	"flat_resist_penetration":3,
	"fatal_delay":2,
	"lowest_health_arts":1,
	"wounded_enemy_attack":2,

	"unblocked_atk_def":1,
	"encore_sp":1,
	"profession_attack_speed_aura":1,
	"deployment_fortune":1,
	"explosive_attack":1,
	"healing_output_aura":1,
	"health_attack_speed":1,"unblocked_regeneration":2,
	"profession_regeneration":1,
	"vanguard_cost":1,
	"defensive_sp":1,
	"self_magic_resist":3,
	"neurotoxin":1,
	"minimum_attack":1,
	"emotional_absorption":1,
	"blocked_magic_vulnerability":1,
	"explorer":1,
	"low_health_fragile":1,
	"double_target":2,

	"charged_attack":1,"abyssal_regeneration":1,"global_attack_regeneration":1,"self_defense":1,
	"initial_cost":1, "attack_silence":1, "global_sp_recharge":1, "low_cost_support":1,
	"summon_seaborn": 1, "bard_predation": 2,
	"heal_resistance": 1, "emergency_control_heal": 2,
	"critical_wound": 1, "saga_focus": 2,
	"delayed_ambush": 1, "stunned_physical_aura": 2,
	"mon3tr_control": 1, "death_rebuild": 2,
	"profession_health_aura": 1, "deploy_shield_layers": 2,
	"mixed_drugs": 1, "healing_received": 2,
	"offensive_sp_aura": 1, "sword_training": 2,
	"drone_supply": 1, "drone_concealment": 2, "cooling_emitter": 1,
	"summon_water_cannon": 1, "water_cannon_support": 2,
	"movement_slow_aura": 2,
	"rhine_suit": 1, "healing_sp": 2,
	"profession_atk_def_aura": 1, "adjacent_death_sp": 2,
	"enemy_resist_aura": 1, "periodic_sp": 2,
	"stack_defense_penetration": 1, "first_skill_hit": 2,
	"none": 3, "attack_proc": 1, "initial_sp_aura": 2, "emergency_heal": 1,
	"status_resistance": 2, "damage_block": 1, "defense_aura": 2,
	"attack_speed_aura": 1, "inactive_regen_aura": 2, "attack_speed_buff": 3,
	"random_blessing": 2, "magic_resist_aura": 1, "summon_phantom": 2,
	"coin_income": 1, "fatal_revive": 2, "defense_damage": 1, "isolated_buff": 2,
	"defense_flat_aura": 1, "attack_redeploy_buff": 1, "reveal_invisible": 2,
	"attack_aura": 1, "random_initial_sp": 2, "sp_recharge_aura": 1,
	"slow_fragile_aura": 2, "flag_attack_speed_aura": 1, "next_deploy_discount": 2,
	"bloodbath": 2, "armor_break_proc": 1, "sniper_crossfire": 2,
	"summon_clone": 1, "clone_redeploy_reduction": 2,
	"group_attack_aura": 3, "redeploy_reduction": 2,
}

@export var operator_id: String
@export var display_name: String
@export var profession: String
@export var profession_id: String
@export var branch: String
@export var race_id: String = ""
@export var group_id: String = ""
@export var max_health: int
@export var attack: int
@export var defense: int
@export var magic_resist: int
@export var damage_type: String
@export var attack_interval: float
@export var block_count: int
@export var initial_deploy_cost: int = -1
@export var deploy_cost: int
@export var redeploy_time: float
@export var dodge_physical: int
@export var dodge_magical: int
@export var attack_range: Array[Vector2i]
@export var terrain_requirement: String
@export var ignore_deploy_line: bool
@export var branch_trait: TraitResource
@export var talent_1: TalentResource
@export var talent_2: TalentResource
@export var skills: Array[SkillResource]


func validation_error() -> String:
	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z][a-z0-9_]{0,63}$")
	if id_pattern.search(operator_id) == null: return "operator_id: invalid ID"
	if display_name.is_empty(): return "display_name: required"
	if group_id not in ["", "abyssal", "ursus_student", "kazimierz", "minos", "kjerag", "rhine", "sargon"]: return "group_id: unknown group"
	if race_id not in ["","sarkaz"]:return "race_id: unknown race"
	if profession_id not in PROFESSION_IDS and profession_id != "summon": return "profession_id: unknown profession"
	if damage_type not in ["physical", "magical", "true", "healing"]: return "damage_type: unknown value"
	if terrain_requirement not in ["ground", "high", "both"]: return "terrain_requirement: unknown value"
	if max_health <= 0: return "max_health: must be positive"
	for entry in [["attack",attack],["defense",defense],["block_count",block_count],["deploy_cost",deploy_cost]]:
		if entry[1] < 0: return "%s: must be nonnegative" % entry[0]
	for entry in [["magic_resist",magic_resist],["dodge_physical",dodge_physical],["dodge_magical",dodge_magical]]:
		if entry[1] < 0 or entry[1] > 100: return "%s: expected 0..100" % entry[0]
	for entry in [["attack_interval",attack_interval],["redeploy_time",redeploy_time]]:
		if not is_finite(entry[1]) or entry[1] <= 0.0: return "%s: must be finite and positive" % entry[0]
	var error := SkillResource.range_error(attack_range)
	if not error.is_empty(): return "attack_range: " + error
	if attack_range.is_empty() and not (profession_id == "summon" and attack == 0): return "attack_range: required for attacking operators"
	if branch_trait == null: return "branch_trait: required"
	error = branch_trait.validation_error()
	if not error.is_empty(): return "branch_trait." + error
	for index in 2:
		var talent: TalentResource = [talent_1, talent_2][index]
		if talent == null: return "talent_%d: required" % (index+1)
		error = talent.validation_error()
		if not error.is_empty(): return "talent_%d.%s" % [index+1,error]
		if (TALENT_SLOTS[talent.effect_type] & (1 << index)) == 0: return "talent_%d.effect_type: %s requires its supported slot" % [index+1,talent.effect_type]
		if talent.effect_type == "redeploy_reduction" and talent.effect_params["reduction_seconds"] >= redeploy_time: return "talent_%d.effect_params.reduction_seconds: must be below redeploy_time" % (index+1)
	if skills.is_empty() or skills.size() > 3: return "skills: expected 1..3 resources"
	for index in skills.size():
		var skill := skills[index]
		if skill == null: return "skills[%d]: required" % index
		error = skill.validation_error()
		if not error.is_empty(): return "skills[%d].%s" % [index,error]
		if skill.effect_params.has("attack_interval_add") and attack_interval + skill.effect_params["attack_interval_add"] <= 0: return "skills[%d].effect_params.attack_interval_add: final interval must be positive" % index
		if skill.effect_type in ["armor_break_single","armor_break_boost"] and talent_1.effect_type != "armor_break_proc": return "skills[%d]/talent_1: armor break requires armor_break_proc" % index
		if skill.effect_type in ["passive_heal","champagne_traps","coin_barrage"] and (branch_trait.effect_type != "cost_drain" or talent_1.effect_type != "coin_income"): return "skills[%d]/branch_trait/talent_1: coin mechanism requires cost_drain and coin_income" % index
	if branch_trait.effect_type in ["magical_attack", "line_magic"] and damage_type != "magical": return "damage_type: magical_attack requires magical"
	if branch_trait.effect_type == "close_range_shot" and damage_type != "physical": return "damage_type: close_range_shot requires physical"
	if profession_id == "summon": return _summon_validation_error()
	if initial_deploy_cost<0:return "initial_deploy_cost: original initial cost required"
	if branch_trait.effect_type in ["stainless_device_1","stainless_device_2","stainless_device_3","dusk_freeling","flowing_shape","jessica_shield","monstr_reconstruction","ling_summon","ling_summon","pozyomka_typewriter","silence_drone","curse_doll","medical_drone","seaborn","mon3tr","phantom","executor_clone","water_cannon","summoner_drone"] or talent_1.effect_type == "none" or (talent_2.effect_type == "none" and operator_id not in SINGLE_TALENT_IDS): return "branch_trait/talents: summon profile used by ordinary operator"
	if operator_id in SINGLE_TALENT_IDS and (talent_2.effect_type!="none" or skills.size()!=(3 if operator_id=="amiya" else 2)):return "talent_2/skills: original operator requires its actual talent and skill count"
	return ""


func _summon_validation_error() -> String:
	match branch_trait.effect_type:
		"monstr_reconstruction":
			if operator_id!="mon3tr_reconstruction" or attack!=0 or block_count!=0 or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!="none" or talent_2.effect_type!="none":return "branch_trait: invalid reconstruction profile"
		"flowing_shape":
			if operator_id!="flowing_shape" or terrain_requirement!="ground" or deploy_cost!=0 or skills.size()!=1 or skills[0].effect_type!="flow_copy" or talent_1.effect_type!="none" or talent_2.effect_type!="none":return "branch_trait/skills: incompatible flowing shape profile"
		"jessica_shield":
			if operator_id!="jessica_shield" or terrain_requirement!="ground" or deploy_cost!=5 or attack!=0 or block_count!=2 or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!="none" or talent_2.effect_type!="none":return "branch_trait/skills: incompatible Jessica shield profile"
		"stainless_device_1","stainless_device_2","stainless_device_3":
			var mode: int=branch_trait.effect_params["mode"]
			if mode not in [1,2,3] or operator_id!=["stainless_device_atk","stainless_device_sp","stainless_cannon"][mode-1] or branch_trait.effect_type!="stainless_device_"+str(mode) or block_count!=0 or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!="none" or talent_2.effect_type!="none":return "branch_trait: incompatible Stainless device"
		"dusk_freeling":
			if operator_id!="dusk_freeling" or block_count!=2 or terrain_requirement!="ground" or deploy_cost!=0 or branch_trait.effect_params["source_profession_id"]!="caster" or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!="none" or talent_2.effect_type!="none":return "branch_trait/skills/talents: incompatible Dusk freeling profile"
		"ling_summon":
			var mode: int=branch_trait.effect_params["module_index"]
			if mode not in [1,2,3] or operator_id!=["ling_soul1","ling_soul2","ling_soul3"][mode-1] or branch_trait.effect_params["source_profession_id"]!="supporter" or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!=("ling_advanced_form" if mode==3 else "none") or talent_2.effect_type!="none":return "branch_trait: invalid Ling summon profile"
		"silence_drone":
			if operator_id!="silence_alter_drone" or attack!=0 or block_count!=0 or deploy_cost!=0 or terrain_requirement!="both" or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!="none" or talent_2.effect_type!="none":return "branch_trait/skills/talents: incompatible Silence drone profile"
		"vigil_wolf":
			if operator_id!="vigil_wolf" or terrain_requirement!="ground" or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!="none" or talent_2.effect_type!="none":return "branch_trait: incompatible vigil wolf profile"
		"pozyomka_typewriter":
			if operator_id!="pozyomka_typewriter" or attack!=866 or max_health!=500 or block_count!=0 or deploy_cost!=5 or terrain_requirement!="high" or damage_type!="physical" or branch_trait.effect_params["source_profession_id"]!="sniper" or skills.size()!=3 or talent_1.effect_type!="typewriter_weakness" or talent_2.effect_type!="none":return "branch_trait/skills/talents: incompatible typewriter profile"
			for index in 3:
				if skills[index].effect_type != ["pozyomka_meter","pozyomka_burst","pozyomka_sketch"][index]:return "skills: incompatible typewriter variant"

		"curse_doll":
			if operator_id!="curse_doll" or block_count!=0 or deploy_cost!=5 or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!="none" or talent_2.effect_type!="none":return "branch_trait/skills/talents: incompatible curse doll profile"
		"medical_drone":
			if operator_id!="medical_drone" or attack!=125 or block_count!=0 or terrain_requirement!="both" or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!="none" or talent_2.effect_type!="none":return "branch_trait/skills/talents: incompatible medical drone profile"
		"seaborn":
			if operator_id!="seaborn" or attack!=100 or block_count!=0 or terrain_requirement!="both" or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!="none" or talent_2.effect_type!="none":return "branch_trait/skills/talents: incompatible seaborn profile"
		"mon3tr":
			if operator_id!="mon3tr" or block_count!=3 or terrain_requirement!="ground" or branch_trait.effect_params["source_profession_id"]!="guard" or skills.size()!=1 or skills[0].effect_type!="no_skill" or talent_1.effect_type!="none" or talent_2.effect_type!="death_rebuild":return "branch_trait/skills/talents: incompatible Mon3tr profile"
		"phantom":
			if operator_id != "nightingale_phantom" or attack != 0 or block_count != 0 or skills.size() != 1 or skills[0].effect_type != "no_skill" or talent_1.effect_type != "none" or talent_2.effect_type != "none": return "branch_trait/skills/talents: incompatible phantom profile"
		"summoner_drone":
			var module: int = branch_trait.effect_params["module_index"]
			if module not in [1,2,3] or operator_id != ["magallan_drone_f","magallan_drone_l","magallan_drone_a"][module-1] or block_count != 0 or skills.size() != 1 or skills[0].effect_type != "no_skill" or talent_2.effect_type != "drone_concealment": return "branch_trait/skills/talents: incompatible drone profile"
			if (module == 1 and (attack != 0 or talent_1.effect_type != "cooling_emitter")) or (module != 1 and (attack <= 0 or talent_1.effect_type != "none")): return "attack/talent_1: incompatible drone module"
		"water_cannon":
			if operator_id != "weedy_cannon" or block_count != 0 or skills.size() != 1 or skills[0].effect_type != "no_skill" or talent_1.effect_type != "none" or talent_2.effect_type != "none" or terrain_requirement != "both": return "branch_trait/skills/talents: incompatible water cannon profile"
		"executor_clone":
			if operator_id != "phantom_clone" or attack <= 0 or terrain_requirement != "ground" or block_count != 1 or damage_type != "physical" or talent_1.effect_type != "none" or talent_2.effect_type != "clone_redeploy_reduction": return "branch_trait/talents: incompatible executor clone profile"
			if talent_2.effect_params["reduction_seconds"] >= redeploy_time: return "talent_2.effect_params.reduction_seconds: must be below redeploy_time"
			if skills.size() != 3: return "skills: clone requires three carried-skill variants"
			for index in 3:
				if skills[index].effect_type != ["deploy_physical_shield","deploy_attack_stacks","deploy_control_burst"][index]: return "skills[%d].effect_type: incompatible clone variant" % index
		_: return "branch_trait.effect_type: unsupported summon profile"
	return ""
