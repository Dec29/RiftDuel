class_name SkillRules
extends RefCounted

const CONFIG := preload("res://data/config.gd")


static func dodge_chance(unit: UnitState, operator: OperatorData, damage_type: String) -> int:
	var skill := operator.skills[unit.skill_index]
	var musha_dodge := int(skill.effect_params["dodge_percent"]) if damage_type=="physical" and active_ticks(unit)>0 and skill.effect_type=="musha_double" else 0
	var ambush := int(operator.talent_1.effect_params["dodge_percent"]) if unit.ambush_ready and unit.silence_ticks_left==0 else 0
	var chance := musha_dodge+ambush+(operator.dodge_physical if damage_type=="physical" else operator.dodge_magical)
	if damage_type=="physical" and unit.silence_ticks_left==0 and unit.physical_guard_ticks_left>0:chance+=int(skill.effect_params["dodge_physical_add"])
	if damage_type=="physical" and unit.silence_ticks_left==0 and operator.talent_2.effect_type=="sword_training":chance+=int(operator.talent_2.effect_params["dodge_physical_add"])
	if damage_type=="physical" and unit.saga_focus_ticks>0 and unit.silence_ticks_left==0:chance+=int(operator.talent_2.effect_params["dodge_percent"])
	if active_ticks(unit)!=0 and skill.effect_type=="lee_admonition" and damage_type=="magical":chance=mini(100,chance+int(skill.effect_params["dodge_percent"]))
	if active_ticks(unit)>0 and skill.effect_type=="jessica_cover":chance+=int(skill.effect_params["dodge_percent"])
	if active_ticks(unit)>0 and skill.effect_type=="red_execute":chance+=int(skill.effect_params["dodge_percent"])
	chance=mini(100,chance+(unit.dodge_magical_bonus if damage_type=="magical" else 0))
	if damage_type=="physical" and unit.dodge_next_physical and unit.silence_ticks_left==0:return 100
	var added: Array[int]=[]
	if damage_type=="physical":added.append(unit.dodge_physical_bonus)
	if active_ticks(unit)>0 and skill.effect_type in ["atk_dodge_boost","cost_dodge_mode"]:added.append(int(skill.effect_params["dodge_percent"]))
	if operator.branch_trait.effect_type=="ambusher":added.append(int(operator.branch_trait.effect_params["dodge_percent"]))
	if damage_type=="physical" and unit.silence_ticks_left==0:
		if operator.talent_2.effect_type=="defense_dodge":added.append(int(operator.talent_2.effect_params["dodge_percent"]))
		if operator.talent_1.effect_type=="physical_dodge":added.append(int(operator.talent_1.effect_params["dodge_percent"]))
	# New independent dodge sources multiply their failure probabilities; keep existing profiles unchanged.
	var failure := (100-chance)/100.0
	for value in added:failure*=(100-value)/100.0
	return clampi(roundi((1.0-failure)*100),0,100)


static func healing_output(source: UnitState, amount: int) -> int:
	return roundi(amount*source.healing_output_percent/100.0)


static func healing_received(unit: UnitState, data: OperatorData, amount: int, source: UnitState = null) -> int:
	if data.branch_trait.effect_type=="monstr_reconstruction" and (source==null or source.unit_id!=unit.reconstruct_owner_id):return 0
	if unit.critical_ticks_left>0 or data.branch_trait.effect_type in ["ling_summon","stainless_device_1","stainless_device_2","stainless_device_3","dusk_freeling","flowing_shape","jessica_shield","pozyomka_typewriter","musha","unyield"]:return 0
	if unit.silence_ticks_left==0 and data.talent_2.effect_type=="gavial_healing":amount=roundi(amount*int(data.talent_2.effect_params["low_heal_percent"] if unit.hp*100<max_health_value(unit,data)*int(data.talent_2.effect_params["hp_threshold_percent"]) else data.talent_2.effect_params["heal_percent"])/100.0)
	if source!=null:amount=healing_output(source,amount)
	amount=roundi(amount*(100+unit.healing_received_bonus_percent)/100.0)
	return roundi(amount*int(data.talent_2.effect_params["heal_percent"])/100.0) if unit.silence_ticks_left==0 and data.talent_2.effect_type=="healing_received" else amount


static func damage_type(unit: UnitState, operator: OperatorData) -> String:
	if unit.operator_id=="flowing_shape":return "magical" if unit.flow_magical else "physical"
	if unit.ling_advanced or unit.ling_skill_mode==1:return "magical"
	if active_ticks(unit)!=0 and operator.skills[unit.skill_index].effect_type=="lappland_wolf":return "magical"
	if unit.mon3tr_mode==3 or MonstrMedicRules.transformed(unit):return "true"
	if active_ticks(unit)>0 and operator.skills[unit.skill_index].effect_type=="nian_magic":return "magical"
	if active_ticks(unit)>0 and operator.skills[unit.skill_index].effect_type=="healing_mode":return "healing"
	return "physical" if active_ticks(unit) > 0 and operator.skills[unit.skill_index].effect_type == "defense_priority_physical" else operator.damage_type


static func damage_profession_id(operator: OperatorData) -> String:
	if operator.branch_trait.effect_type=="stainless_device_3":return "supporter"
	return operator.branch_trait.effect_params["source_profession_id"] if operator.branch_trait.effect_type in ["ling_summon","flowing_shape","dusk_freeling","pozyomka_typewriter","vigil_wolf","mon3tr", "executor_clone", "water_cannon", "summoner_drone"] else operator.profession_id


static func sp_limit(skill: SkillResource) -> int:
	if skill.effect_type in ["ling_chord","gladiia_strike","chen_violet_night","dusk_paint","pozyomka_burst","gnosis_cold","penance_hammer","blemishine_charge","carnelian_guard","carnelian_bind","carnelian_feast","archetto_chase","chain_storm","percent_charge_heal","ambush_charge","lumen_cleanse", "saga_purge", "guardian_aid", "pioneer_hammer", "flame_charge", "charge_shot", "fortress_charge_shot", "heal_barrier", "heal_magic_barrier", "charge_multi_shot", "charge_magic_splash"]:
		return skill.sp_required * int(skill.effect_params["charge_count"])
	return skill.sp_required


static func can_gain_sp(unit: UnitState) -> bool:
	if unit.operator_id=="eunectes" and not unit.eunectes_sp_enabled:return false
	return (unit.operator_id!="flowing_shape" or unit.flow_can_charge) and unit.medical_drone_stock==0 and unit.curse_doll_stock==0


static func can_activate(unit: UnitState, skill: SkillResource) -> bool:
	return unit.titi_doze_owner_id<0 and (skill.effect_type!="monstr_meltdown" or unit.monstr_token_ready) and (skill.effect_type!="limited_atk_spd_boost" or unit.limited_skill_uses<int(skill.effect_params["use_limit"])) and (can_gain_sp(unit) or unit.operator_id=="eunectes") and unit.frozen_ticks_left==0 and unit.sleep_ticks_left==0 and unit.hp > 0 and unit.silence_ticks_left == 0 and unit.stun_ticks_left == 0 and unit.displacement_ticks_left == 0 and (active_ticks(unit) == 0 or (skill.effect_type in ["lin_stance","stance_defense_regen","fighter_stance"] and active_ticks(unit) == -2)) and skill.sp_recharge_type != "passive" and not unit.coin_firing and unit.sp >= skill.sp_required


static func is_auto_trigger(skill: SkillResource) -> bool:
	return skill.trigger_type in ["auto", "attack"]


static func can_manually_activate(unit: UnitState, skill: SkillResource) -> bool:
	if skill.effect_type=="titi_sanctuary" and unit.skill_ticks_left>0:return unit.hp>0 and unit.silence_ticks_left==0 and unit.frozen_ticks_left==0 and unit.stun_ticks_left==0 and unit.sleep_ticks_left==0 and unit.displacement_ticks_left==0
	if unit.titi_doze_owner_id>=0:return false
	if skill.effect_type in ["flow_copy","jessica_bombardment","mlynar_sorrow","chen_violet_night","chen_holiday_storm","fiammetta_repay","silence_protocol", "lin_burst", "lumen_lamp", "marked_arrow_rain", "fortress_ammo", "fortress_overload", "coin_barrage"] and active_ticks(unit) != 0:
		return unit.frozen_ticks_left==0 and unit.sleep_ticks_left==0 and unit.hp > 0 and unit.silence_ticks_left == 0 and unit.stun_ticks_left == 0 and unit.displacement_ticks_left == 0 and not unit.skill_dump_pending
	return not is_auto_trigger(skill) and can_activate(unit, skill)


static func activate(unit: UnitState, operator: OperatorData) -> void:
	var skill := operator.skills[unit.skill_index]
	var old_interval := attack_interval_ticks(unit, operator)
	unit.sp -= skill.sp_required
	if skill.effect_type in ["thorns_destreza", "atk_spd_boost_repeat", "dual_arrow_repeat"]:
		unit.skill_repeat_activation_count += 1
	if skill.effect_type in ["cost_regen", "flag_heal", "flag_medicine"]:
		unit.skill_cost_accum = 0
	if skill.effect_type not in ["blemishine_charge","percent_charge_heal","ambush_charge","saga_purge", "guardian_aid", "pioneer_hammer", "flame_charge", "charge_shot", "fortress_charge_shot", "charge_multi_shot", "charge_magic_splash"]:
		unit.sp_regen_ticks = 0
		unit.sp_regen_accum = 0
	if skill.effect_type in ["lin_stance","stance_defense_regen","fighter_stance"]:
		unit.skill_ticks_left = 0 if unit.skill_ticks_left == -2 else -2
	else:
		unit.skill_ticks_left = roundi(skill.duration * CONFIG.TICK_RATE) if skill.duration > 0 else (-2 if skill.duration < 0 else -1)
	if skill.effect_type in ["thorns_destreza", "dual_arrow_repeat"] and unit.skill_repeat_activation_count >= 2:
		unit.skill_ticks_left = -2
	if operator.talent_2.effect_type == "first_skill_hit":unit.skill_hit_ids.clear()
	if skill.effect_type == "marked_arrow_rain":unit.skill_ammo_left = int(skill.effect_params["ammo_count"])
	if unit.skill_ticks_left!=0:unit.skill_activation_count+=1
	if skill.effect_type == "coin_barrage":
		unit.coins = int(operator.talent_1.effect_params["initial_coins"])
	unit.skill_elapsed_ticks = 0
	unit.skill_regen_attack = 0
	if skill.effect_type == "fortress_ammo":
		unit.skill_ammo_left = int(skill.effect_params["ammo_count"])
		unit.skill_dump_pending = false
	if skill.effect_type == "fortress_overload":
		unit.skill_hp_regen_accum = 0
	var new_interval := attack_interval_ticks(unit, operator)
	if not AttackTimeline.uses_start_clock(unit):
		unit.attack_ticks_left = ceili(float(unit.attack_ticks_left) * new_interval / old_interval)


# Caller checks that the continuous skill is active; rounding/capping is shared.
static func advance_cost_regen(state: MatchState, unit: UnitState, skill: SkillResource) -> void:
	unit.skill_cost_accum += int(skill.effect_params["total_cost"])
	var duration_ticks := roundi(skill.duration * CONFIG.TICK_RATE)
	state.sides[unit.side].cost = mini(CONFIG.COST_MAX, state.sides[unit.side].cost + unit.skill_cost_accum / duration_ticks)
	unit.skill_cost_accum %= duration_ticks


static func attack_value(unit: UnitState, operator: OperatorData, ignore_attack_scale: bool = false) -> int:
	return maxi(0,roundi(_attack_value(unit,operator,ignore_attack_scale)*unit.weaken_attack_remaining_percent/100.0*unit.curse_attack_remaining_percent/100.0*(100-unit.reed_cinder_attack_reduce_percent)/100.0)+unit.flow_stolen_attack-unit.flow_attack_loss)


static func _attack_value(unit: UnitState, operator: OperatorData, ignore_attack_scale: bool) -> int:
	var base_attack := maxi(0,(unit.flow_attack if not unit.flow_copy_id.is_empty() else operator.attack)+unit.ines_stolen_attack-unit.ines_attack_loss)
	var inspiration := 0 if operator.branch_trait.effect_type=="bard" else unit.inspire_attack_add
	var bonus := unit.attack_bonus_percent
	if unit.ling_advanced:bonus+=int(operator.talent_1.effect_params["attack_percent"])
	if operator.branch_trait.effect_type=="liberator":bonus+=unit.mlynar_charge_bonus_percent
	if unit.silence_ticks_left==0 and operator.operator_id=="dusk":bonus+=unit.dusk_kill_stacks*int(operator.talent_1.effect_params["attack_percent_per_kill"])
	if unit.silence_ticks_left==0 and unit.skill_ticks_left>0 and operator.talent_1.effect_type=="texas_tradition":bonus+=int(operator.talent_1.effect_params["attack_percent"])
	if unit.blood_buff_until_tick>0:bonus+=unit.blood_buff_attack_percent
	if unit.mon3tr_mode==3:
		return roundi(base_attack*(1.0+bonus/100.0+unit.mon3tr_attack_peak_percent*unit.mon3tr_decay_ticks_left/(100.0*unit.mon3tr_decay_duration_ticks)))+inspiration
	if unit.silence_ticks_left == 0 and operator.skills[unit.skill_index].effect_type == "deploy_attack_stacks":
		bonus += unit.attack_boost_stacks * int(operator.skills[unit.skill_index].effect_params["attack_percent_per_stack"])
	if unit.silence_ticks_left == 0 and operator.talent_1.effect_type == "coin_income":
		bonus += unit.coin_attack_stacks * int(operator.talent_1.effect_params["attack_percent_per_stack"])
	if (active_ticks(unit)>0 and operator.skills[unit.skill_index].effect_type=="guardian_cook" and unit.skill_elapsed_ticks<int(operator.skills[unit.skill_index].effect_params["warmup_ticks"])) or ClassicTacticalRules.is_resting(unit,operator):return roundi(base_attack*(100+bonus)/100.0)+inspiration
	if active_ticks(unit) == 0 or operator.skills[unit.skill_index].effect_type in ["pull_strike","pull_chain","bard_sleep","bard_song","liskarm_guard", "defense_up", "cuora_shell", "bard_share", "bard_inspire", "bard_tide", "instant_cost", "kaltsit_guard", "kaltsit_tactical", "kaltsit_meltdown", "nian_copper", "aak_defense", "aak_offense", "magallan_cooling", "magallan_laser", "magallan_artillery", "guardian_aid", "guardian_medicine", "guardian_calcium", "flag_medicine", "cost_regen", "deploy_physical_shield", "foxfire_aura", "heal_barrier", "heal_magic_barrier"]:
		return roundi(base_attack * (100 + bonus) / 100.0)+inspiration
	var skill := operator.skills[unit.skill_index]
	if skill.effect_type=="carnelian_feast":
		var stage := mini(int(skill.effect_params["ramp_steps"]),unit.skill_elapsed_ticks/int(skill.effect_params["ramp_interval_ticks"]))
		return roundi(base_attack*(1.0+bonus/100.0+int(skill.effect_params["max_attack_bonus_percent"])*stage/(100.0*int(skill.effect_params["ramp_steps"]))))+inspiration
	if skill.effect_type=="carnelian_bind":return roundi(base_attack*((float(skill.effect_params["charged_attack_mult"]) if unit.carnelian_charged else 1.0)+bonus/100.0))+inspiration
	if skill.effect_type=="thorns_destreza":
		var thorns_multiplier := float(skill.effect_params["repeat_attack_mult"] if unit.skill_repeat_activation_count>=2 else skill.effect_params["attack_mult"])
		return roundi(base_attack*(thorns_multiplier+bonus/100.0))+inspiration
	if skill.effect_type == "ramp_burst":
		var stage := mini(int(skill.effect_params["ramp_steps"]), unit.skill_elapsed_ticks / int(skill.effect_params["pulse_interval_ticks"]))
		return roundi(base_attack * (1.0 + bonus / 100.0 + int(skill.effect_params["attack_bonus_percent"]) * stage / (100.0 * int(skill.effect_params["ramp_steps"]))))+inspiration
	if skill.effect_type == "atk_spd_boost_repeat" and unit.skill_repeat_activation_count == 1:
		return roundi(base_attack * (100 + bonus) / 100.0)+inspiration
	if ignore_attack_scale:return roundi(base_attack*(100+bonus)/100.0)+inspiration
	var multiplier := float(skill.effect_params["attack_mult"])
	if skill.effect_type == "fortress_overload" and unit.skill_elapsed_ticks >= int(skill.effect_params["overload_ticks"]):
		multiplier = float(skill.effect_params["overload_attack_mult"])
	if skill.effect_type in ["stainless_supply_boost","stainless_prototype","muelsyse_progress","muelsyse_ecology","muelsyse_interaction","jessica_vigilance","jessica_cover","jessica_bombardment","wildmane_charge","eunectes_passive","eunectes_stun","eunectes_engine","ling_wine","ling_chord","ling_thunder","titi_corrosion","titi_sanctuary","titi_bloom","gavial_strike","gavial_pull","gavial_soul","mlynar_anger","mlynar_sorrow","mlynar_glory","gladiia_strike","gladiia_tide_skill","gladiia_vortex","shaw_strike","shaw_cannon","goldenglow_sparks","goldenglow_current","goldenglow_global","dusk_ink","dusk_freehand","chen_water_pressure","chen_violet_night","chen_holiday_storm","fiammetta_confront","reed_fireballs","reed_lifeseed","eyja_permanent","eyja_elemental_barrier","eyja_volcano","pozyomka_meter","lee_admonition","lee_guest","silence_protocol","ines_night","ines_recall","vigil_slaughter","texas_silence","texas_arts","texas_alter_rain","penance_bramble","penance_ascetic","blemishine_sleep","blemishine_radiance","lin_stance","lin_burst","lin_shelter","carnelian_guard","pallas_whip","pallas_blessing","archetto_storm","thorns_counter","cost_dodge_mode","permanent_fragile_attack","chain_focus","heavy_bind_volley","unyield_awakening","atk_dodge_boost","atk_spd_health_boost","limited_atk_spd_boost","guardian_cook","healing_mode","fighter_stance","fighter_barrage","dual_arts_boost","twilight","ambush_bind","ambush_stun","caster_destiny","guardian_mode","musha_double","zima_warcry","liskarm_arc","blue_venom","red_execute","amiya_chimera","istina_storm", "attack_up", "platinum_sight", "specter_survival", "perfumer_blend", "lappland_sundial", "lappland_wolf", "lumen_lamp", "saga_fury", "nian_magic", "nian_iron", "pusher_cannon_mode", "caster_wave", "dual_arrow_repeat", "deploy_atk_boost", "atk_def_health_boost", "atk_spd_boost", "atk_spd_boost_repeat", "atk_spd_boost_auto", "atk_def_boost", "atk_boost_auto", "heal_boost", "armor_break_boost", "permanent_multi_target", "heal_defense_aura", "permanent_atk_def_boost", "stance_defense_regen", "multi_target_boost", "burst_atk_def_boost", "cleave_atk_def_boost", "random_multi_target", "heal_magic_aura", "fortress_overload", "weightless_multi_target", "defense_priority_physical"]:
		return roundi(base_attack * (multiplier + bonus / 100.0))+inspiration
	return roundi((base_attack * (100 + bonus) / 100.0 + inspiration) * multiplier)


static func attack_output_value(unit: UnitState, operator: OperatorData) -> int:
	var attack := attack_value(unit, operator)
	if active_ticks(unit) > 0 and operator.skills[unit.skill_index].effect_type == "rapid_magic":
		attack = roundi(attack * float(operator.skills[unit.skill_index].effect_params["damage_scale"]))
	if operator.branch_trait.effect_type == "ranged_attack":
		var skill := operator.skills[unit.skill_index]
		if active_ticks(unit)!=0 and skill.effect_type=="thorns_destreza":return attack
		if active_ticks(unit) != 0 and skill.effect_params.has("ignore_ranged_penalty") and skill.effect_params["ignore_ranged_penalty"]:
			return attack
		return roundi(attack * int(operator.branch_trait.effect_params["attack_percent"]) / 100.0)
	return attack


static func defense_value(unit: UnitState, operator: OperatorData) -> int:
	if operator.branch_trait.effect_type=="mon3tr" and unit.mon3tr_outside_range:return 0
	var skill := operator.skills[unit.skill_index]
	var bonus := unit.defense_bonus_percent
	if unit.ling_advanced:bonus+=int(operator.talent_1.effect_params["defense_percent"])
	if unit.silence_ticks_left==0 and unit.gravel_ticks_left>0 and skill.effect_type=="gravel_defense":bonus+=roundi(int(skill.effect_params["defense_percent"])*unit.gravel_ticks_left/float(skill.effect_params["decay_ticks"]))
	if active_ticks(unit)>0 and skill.effect_type=="stainless_supply_boost":bonus+=roundi((float(skill.effect_params.defense_mult)-1.0)*100)
	if active_ticks(unit)>0 and skill.effect_type=="kaltsit_guard":bonus+=int(skill.effect_params["defense_percent"])
	var barrier_bonus := 0
	for percent in unit.barrier_defense_percent:
		barrier_bonus = maxi(barrier_bonus, percent)
	bonus += barrier_bonus + unit.skill_defense_bonus_percent + unit.flag_defense_bonus_percent
	if unit.bloodbath_used and unit.silence_ticks_left == 0:
		bonus += int(operator.talent_2.effect_params["defense_percent"])
	if active_ticks(unit)>0 and skill.effect_type=="guardian_cook" and unit.skill_elapsed_ticks<int(skill.effect_params["warmup_ticks"]):bonus+=roundi((float(skill.effect_params["defense_mult"])-1.0)*100)
	if active_ticks(unit)>0 and skill.effect_type=="unyield_awakening" and not ClassicTacticalRules.is_resting(unit,operator):bonus+=roundi((float(skill.effect_params["defense_mult"])-1.0)*100)
	var multiplier := 1.0 + bonus / 100.0
	if active_ticks(unit)!=0 and skill.effect_type in ["jessica_vigilance","jessica_bombardment","eunectes_passive","eunectes_engine"]:multiplier+=float(skill.effect_params["defense_mult"])-1.0
	if PhalanxRules.guarding(unit,operator):multiplier+=int(operator.branch_trait.effect_params["idle_defense_percent"])/100.0
	if active_ticks(unit)>0 and skill.effect_type in ["ling_thunder","gavial_pull","mlynar_anger"]:multiplier+=float(skill.effect_params["defense_mult"])-1.0
	if active_ticks(unit)>0 and skill.effect_type=="blemishine_radiance":multiplier+=float(skill.effect_params["defense_mult"])-1.0
	if active_ticks(unit)>0 and skill.effect_type=="carnelian_guard":multiplier+=float(skill.effect_params["defense_mult"])-1.0
	if active_ticks(unit)>0 and skill.effect_type=="thorns_counter":multiplier+=float(skill.effect_params["defense_mult"])-1.0
	if unit.silence_ticks_left == 0 and skill.effect_type == "passive_thorns":
		multiplier += float(skill.effect_params["defense_mult"]) - 1.0
	if active_ticks(unit) != 0 and skill.effect_type in ["lee_guest","liskarm_guard", "defense_up", "cuora_shell", "nian_magic", "nian_copper", "fighter_stance", "atk_def_health_boost", "atk_def_boost", "permanent_atk_def_boost", "stance_defense_regen", "multi_target_boost", "burst_atk_def_boost", "cleave_atk_def_boost"]:
		multiplier += float(skill.effect_params["defense_mult"]) - 1.0
	if active_ticks(unit) > 0 and skill.effect_type == "ramp_burst":
		var stage := mini(int(skill.effect_params["ramp_steps"]), unit.skill_elapsed_ticks / int(skill.effect_params["pulse_interval_ticks"]))
		multiplier += int(skill.effect_params["defense_bonus_percent"]) * stage / (100.0 * int(skill.effect_params["ramp_steps"]))
	return maxi(0,roundi((((unit.flow_defense if not unit.flow_copy_id.is_empty() else operator.defense) + unit.defense_bonus_add) * multiplier + unit.inspire_defense_add - unit.burn_defense_reduce - unit.shell_defense_reduce - unit.chen_slime_defense_reduce) * unit.armor_break_defense_percent / 100.0 * unit.pramanix_defense_remaining_percent / 100.0 * unit.recon_defense_remaining_percent / 100.0 * unit.curse_defense_remaining_percent / 100.0 * unit.typewriter_defense_remaining_percent / 100.0)+unit.flow_stolen_defense-unit.flow_defense_loss)


static func max_health_value(unit: UnitState, operator: OperatorData) -> int:
	var multiplier := int(operator.talent_2.effect_params["max_health_percent"]) if unit.bloodbath_used else 100
	if MonstrMedicRules.transformed(unit):return roundi((operator.max_health+unit.max_health_bonus_add+int(operator.skills[unit.skill_index].effect_params["max_health_add"]))* (100+unit.max_health_bonus_percent)/100.0)
	return roundi(((unit.flow_health if not unit.flow_copy_id.is_empty() else operator.max_health)+unit.max_health_bonus_add) * (100 + unit.max_health_bonus_percent + (int(operator.talent_1.effect_params["health_percent"]) if unit.ling_advanced else 0)) / 100.0 * multiplier / 100.0)


static func block_count_value(unit: UnitState, operator: OperatorData) -> int:
	if unit.titi_doze_owner_id>=0:return 0
	if unit.operator_id=="flowing_shape":return 0 if unit.flow_point_until_tick>0 or unit.stun_ticks_left>0 or unit.frozen_ticks_left>0 or unit.sleep_ticks_left>0 or unit.critical_ticks_left>0 else ((unit.flow_block if not unit.flow_copy_id.is_empty() else 1)+unit.block_bonus)
	if operator.operator_id=="vigil_wolf":return unit.vigil_wolf_layers if unit.frozen_ticks_left==0 and unit.stun_ticks_left==0 and unit.sleep_ticks_left==0 else 0
	if operator.branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:return 0
	if ClassicTacticalRules.is_resting(unit,operator):return 0
	if operator.branch_trait.effect_type=="liberator" and active_ticks(unit)==0:return 0
	if unit.frozen_ticks_left>0 or unit.sleep_ticks_left>0 or unit.chen_slashes_left>0 or unit.critical_ticks_left>0:return 0
	var count := operator.block_count+unit.block_bonus+(int(operator.talent_1.effect_params["block_add"]) if unit.ling_advanced else 0)
	if active_ticks(unit)>0 and operator.skills[unit.skill_index].effect_type=="eunectes_engine":count+=int(operator.skills[unit.skill_index].effect_params["block_count_add"])
	if MonstrMedicRules.transformed(unit):count+=int(operator.skills[unit.skill_index].effect_params["block_count_add"])
	if active_ticks(unit)>0 and operator.skills[unit.skill_index].effect_type in ["gavial_soul","cost_dodge_mode"]:count+=int(operator.skills[unit.skill_index].effect_params["block_count_add"])
	if active_ticks(unit)!=0 and operator.skills[unit.skill_index].effect_type=="fighter_stance":count+=int(operator.skills[unit.skill_index].effect_params["block_count_add"])
	if active_ticks(unit)>0 and operator.skills[unit.skill_index].effect_type=="cuora_shell":count+=int(operator.skills[unit.skill_index].effect_params["block_count_add"])
	if active_ticks(unit)>0 and operator.skills[unit.skill_index].effect_type=="nian_copper":count+=int(operator.skills[unit.skill_index].effect_params["block_count_add"])
	if active_ticks(unit) > 0 and operator.skills[unit.skill_index].effect_type == "burst_atk_def_boost":
		count += int(operator.skills[unit.skill_index].effect_params["block_count_add"])
	return 0 if unit.stun_ticks_left > 0 or (unit.skill_ticks_left > 0 and operator.branch_trait.effect_type == "flag_bearer") else count


static func magic_resist_value(unit: UnitState, operator: OperatorData) -> int:
	var barrier_bonus := 0
	for bonus in unit.barrier_magic_resist_add:
		barrier_bonus = maxi(barrier_bonus, bonus)
	var phalanx_resist := int(operator.branch_trait.effect_params["idle_resist_add"]) if PhalanxRules.guarding(unit,operator) else 0
	var resist := roundi(maxi(0,phalanx_resist+(unit.flow_resist if not unit.flow_copy_id.is_empty() else operator.magic_resist) + unit.magic_resist_bonus + barrier_bonus - unit.flame_resist_reduce - (15 if unit.frozen_ticks_left>0 else 0)) * (100 + unit.magic_resist_bonus_percent + (int(operator.talent_1.effect_params["resist_percent"]) if unit.ling_advanced else 0)) / 100.0)
	return roundi(mini(100, resist) * (100-unit.flame_resist_aura_percent)/100.0 * unit.resist_remaining_percent / 100.0 * unit.pramanix_resist_remaining_percent / 100.0 * unit.texas_resist_remaining_percent / 100.0)


static func talent_is_active(talent: TalentResource) -> bool:
	if talent.effect_type in ["ling_supply","ling_recycle","ling_advanced_form","titi_frozen_time","titi_courage","gavial_blocking","gavial_healing","mlynar_roamer","mlynar_indifference","gladiia_tide","gladiia_predation","monstr_reconstruct","monstr_synergy","ling_supply","ling_recycle","flowing_shape_supply","rhine_deploy_discount","jessica_shield_supply","shield_damage_sp","guard_deploy_discount","duelist_health","duelist_sp","reed_cinder","reed_reflected_heal","eyja_mist","eyja_health_aura","ines_first_strike","ines_shadow","vigil_pack","vigil_penetration","cold_fragile","kjerag_resistance","abjurer_protection","rhine_regeneration","texas_tradition","texas_swordsmanship","penance_barrier","barrier_reflect","defensive_attack_sp","sleep_mercy","glass_wall","damage_sp_proc","charged_skill_heal","overcharge_sp","minos_vigor","mentor_heal","sniper_offensive_sp","shield_break_sp","lord_neurotoxin","idle_health_regeneration"]:return true
	if talent.effect_type == "status_resistance":
		return true
	return talent.effect_type in ["dodge_counter","group_physical_dodge","sniper_support","regenerating_shield","sarkaz_damage_reduction","heavy_penetration","high_health_damage_mark","isolated_enemy_attack","physical_dodge","hit_resist_reduction","low_cost_healing_aura","death_sp_in_range","stun_attack_proc","attack_weaken_proc","defense_dodge","flat_resist_penetration","fatal_delay","lowest_health_arts","wounded_enemy_attack","unblocked_atk_def","encore_sp","profession_attack_speed_aura","deployment_fortune","explosive_attack","healing_output_aura","health_attack_speed","unblocked_regeneration","profession_regeneration","vanguard_cost","defensive_sp","self_magic_resist","neurotoxin","minimum_attack","emotional_absorption","blocked_magic_vulnerability","explorer","low_health_fragile","double_target","charged_attack","abyssal_regeneration","global_attack_regeneration","self_defense","initial_cost", "attack_silence", "global_sp_recharge", "low_cost_support","summon_seaborn", "bard_predation", "heal_resistance", "emergency_control_heal", "critical_wound", "saga_focus", "delayed_ambush", "stunned_physical_aura", "mon3tr_control", "death_rebuild", "profession_health_aura", "deploy_shield_layers", "mixed_drugs", "healing_received", "offensive_sp_aura", "sword_training", "drone_supply", "drone_concealment", "cooling_emitter", "reveal_invisible", "summon_water_cannon", "water_cannon_support", "rhine_suit", "healing_sp", "profession_atk_def_aura", "adjacent_death_sp", "enemy_resist_aura", "periodic_sp", "stack_defense_penetration", "first_skill_hit", "group_attack_aura", "redeploy_reduction", "summon_clone", "clone_redeploy_reduction", "armor_break_proc", "sniper_crossfire", "bloodbath", "flag_attack_speed_aura", "next_deploy_discount", "sp_recharge_aura", "slow_fragile_aura", "attack_redeploy_buff", "attack_aura", "random_initial_sp", "coin_income", "attack_proc", "initial_sp_aura", "emergency_heal", "damage_block", "defense_aura", "defense_flat_aura", "attack_speed_aura", "inactive_regen_aura", "attack_speed_buff", "random_blessing", "magic_resist_aura", "summon_phantom", "fatal_revive", "defense_damage", "isolated_buff"]


static func attack_interval_ticks(unit: UnitState, operator: OperatorData) -> int:
	var skill := operator.skills[unit.skill_index]
	if active_ticks(unit)>0 and skill.effect_type=="flag_medicine":return CONFIG.TICK_RATE
	var speed := maxi(1,100 + unit.attack_speed_bonus - (30 if unit.cold_ticks_left>0 else 0)+unit.ines_speed_gain-unit.ines_speed_loss)
	if unit.silence_ticks_left==0 and operator.operator_id=="chen_alter":speed+=int(operator.talent_2.effect_params["attack_speed_add"])
	if unit.silence_ticks_left==0 and operator.operator_id=="fiammetta" and active_ticks(unit)==0:speed+=int(operator.talent_2.effect_params["attack_speed_add"])
	speed=maxi(1,roundi(speed*(100-unit.ines_shadow_slow)/100.0))
	if active_ticks(unit)>0 and skill.effect_type=="muelsyse_progress":speed+=int(skill.effect_params["attack_speed_add"])
	if active_ticks(unit)>0 and skill.effect_type=="wildmane_deploy":speed+=int(skill.effect_params["attack_speed_add"])
	if unit.silence_ticks_left==0 and skill.effect_type=="lee_paper":speed+=int(skill.effect_params["attack_speed_add"])
	if unit.silence_ticks_left==0 and not unit.texas_first_kill_used and operator.talent_2.effect_type=="texas_swordsmanship":speed+=int(operator.talent_2.effect_params["attack_speed_add"])
	if active_ticks(unit)!=0 and skill.effect_type=="thorns_destreza":speed+=int(skill.effect_params["repeat_attack_speed_add"] if unit.skill_repeat_activation_count>=2 else skill.effect_params["attack_speed_add"])
	if unit.bloodbath_used and unit.silence_ticks_left == 0:
		speed += int(operator.talent_2.effect_params["attack_speed_add"])
	if active_ticks(unit)>0 and skill.effect_type=="kaltsit_tactical":speed+=int(skill.effect_params["attack_speed_add"])
	if active_ticks(unit) != 0 and skill.effect_type in ["stainless_prototype","ling_wine","gavial_soul","goldenglow_sparks","dusk_ink","gnosis_hypothermia","silence_drone_skill","lin_shelter","atk_spd_health_boost","limited_atk_spd_boost","lumen_lamp", "atk_spd_boost", "atk_spd_boost_repeat", "atk_spd_boost_auto"]:
		speed += int(skill.effect_params["attack_speed_add"])
	if active_ticks(unit)!=0 and skill.effect_type in ["platinum_sight","perfumer_blend"]:speed=maxi(1,speed-int(skill.effect_params["attack_speed_reduce"]))
	if unit.critical_ticks_left>0:speed=maxi(1,roundi(speed*unit.critical_speed_percent/100.0))
	var interval := float(skill.effect_params["attack_interval"]) if active_ticks(unit)>0 and skill.effect_type=="guardian_mode" else (unit.flow_interval_ticks/float(CONFIG.TICK_RATE) if not unit.flow_copy_id.is_empty() else operator.attack_interval)
	if active_ticks(unit) != 0 and skill.effect_type in ["dusk_freehand","chain_focus","cost_dodge_mode","guardian_cook","liskarm_arc","skyfire_meteor", "pusher_cannon_mode", "burst_atk_def_boost", "rapid_magic", "defense_priority_fast"]:
		interval *= float(skill.effect_params["attack_interval_mult"])
	if active_ticks(unit) != 0 and skill.effect_type in ["mlynar_sorrow","gladiia_tide_skill","monstr_meltdown","jessica_cover","jessica_bombardment","eunectes_stun","pozyomka_sketch","penance_bramble","lin_stance","carnelian_bind","ambush_bind","fighter_barrage","istina_focus", "ptilopsis_healing", "saga_fury", "pioneer_skull", "marked_arrow_rain", "sustained_multi_shot", "armor_break_boost", "random_multi_target", "fortress_overload"]:
		interval += float(skill.effect_params["attack_interval_add"])
	if active_ticks(unit)>0 and skill.effect_type=="unyield_awakening" and not ClassicTacticalRules.is_resting(unit,operator):interval*=float(skill.effect_params["attack_interval_mult"])
	if unit.ling_advanced:interval+=int(operator.talent_1.effect_params["interval_add_ticks"])/float(CONFIG.TICK_RATE)
	speed=maxi(1,roundi(speed*unit.attack_speed_remaining_percent/100.0))
	return maxi(1, roundi(interval * CONFIG.TICK_RATE * 100.0 / speed))


static func active_ticks(unit: UnitState) -> int:
	return unit.skill_ticks_left if unit.silence_ticks_left == 0 else 0


static func flag_position(unit: UnitState) -> Vector2i:
	return unit.flag_cell if unit.skill_ticks_left > 0 and unit.flag_cell.x >= 0 else unit.cell


static func sanctuary_percent(unit: UnitState, data: OperatorData) -> int:
	if unit.flow_sanctuary_percent>0:return unit.flow_sanctuary_percent
	if data.talent_1.effect_type=="duelist_health" and unit.silence_ticks_left==0 and unit.hp*100<=max_health_value(unit,data)*int(data.talent_1.effect_params["hp_threshold_percent"]):return int(data.talent_1.effect_params["sanctuary_percent"])
	return int(data.skills[unit.skill_index].effect_params["sanctuary_percent"]) if active_ticks(unit)>0 and data.skills[unit.skill_index].effect_type=="penance_ascetic" else 0


static func taunt_level(unit: UnitState, data: OperatorData) -> int:
	return _base_taunt_level(unit,data)+(1 if unit.lee_marked else 0)


static func _base_taunt_level(unit: UnitState, data: OperatorData) -> int:
	if unit.silence_ticks_left==0 and data.talent_2.effect_type=="mlynar_indifference":return int(data.talent_2.effect_params["taunt_level"])
	if data.branch_trait.effect_type=="jessica_shield":return int(data.branch_trait.effect_params["taunt_level"])
	if unit.operator_id=="stainless_cannon":return -2
	if active_ticks(unit)!=0 and data.skills[unit.skill_index].effect_type=="lee_guest":return 1
	if active_ticks(unit)>0 and data.skills[unit.skill_index].effect_type=="penance_bramble":return 1
	if active_ticks(unit)>0 and data.skills[unit.skill_index].effect_type=="lin_shelter":return -1
	if data.branch_trait.effect_type=="phantom":return int(data.branch_trait.effect_params["taunt_level"])
	if data.branch_trait.effect_type=="ambusher":return -1
	return -1 if unit.ambush_ready and unit.silence_ticks_left==0 else 0
