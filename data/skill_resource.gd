class_name SkillResource
extends Resource

const CONFIG := preload("res://data/config.gd")

const PARAMETERS := {
	"monstr_chain":{"attack_mult":TYPE_FLOAT,"heal_percent":TYPE_INT,"target_count":TYPE_INT},
	"monstr_overload":{"attack_mult":TYPE_FLOAT,"talent_multiplier_percent":TYPE_INT,"echo_delay_ticks":TYPE_INT},
	"monstr_meltdown":{"attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT,"block_count_add":TYPE_INT,"max_health_add":TYPE_INT,"life_loss_per_second":TYPE_INT,"self_heal_percent":TYPE_INT},
	"ling_wine":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"stock_add":TYPE_INT},
	"ling_chord":{"attack_mult":TYPE_FLOAT,"burst_attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"bind_ticks":TYPE_INT,"charge_count":TYPE_INT},
	"ling_thunder":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"pulse_ticks":TYPE_INT,"pulse_attack_percent":TYPE_INT,"stock_add":TYPE_INT},

	"titi_corrosion":{"attack_mult":TYPE_FLOAT,"chance_percent":TYPE_INT,"sleep_ticks":TYPE_INT},
	"titi_sanctuary":{"attack_mult":TYPE_FLOAT,"talent_scale_percent":TYPE_INT,"pulse_ticks":TYPE_INT,"sleep_ticks":TYPE_INT,"radius_squared":TYPE_INT},
	"titi_bloom":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"sleep_ticks":TYPE_INT,"min_attack_percent":TYPE_INT,"max_attack_percent":TYPE_INT,"max_sleep_ticks":TYPE_INT,"radius_squared":TYPE_INT},

	"gavial_strike":{"attack_mult":TYPE_FLOAT,"leech_percent":TYPE_INT},
	"gavial_pull":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"shift_force":TYPE_INT},
	"gavial_soul":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"block_count_add":TYPE_INT,"deferred_percent":TYPE_INT,"repay_ticks":TYPE_INT,"pulse_ticks":TYPE_INT},
	"mlynar_anger":{"attack_mult":TYPE_FLOAT,"strike_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT},
	"mlynar_sorrow":{"attack_mult":TYPE_FLOAT,"strike_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT,"shot_count":TYPE_INT},
	"mlynar_glory":{"attack_mult":TYPE_FLOAT,"strike_mult":TYPE_FLOAT,"target_count":TYPE_INT,"trait_multiplier":TYPE_INT,"kill_reduce_percent":TYPE_INT,"true_attack_percent":TYPE_INT},
	"gladiia_strike":{"attack_mult":TYPE_FLOAT,"strike_mult":TYPE_FLOAT,"shift_force":TYPE_INT,"charge_count":TYPE_INT,"channel_ticks":TYPE_INT},
	"gladiia_tide_skill":{"attack_mult":TYPE_FLOAT,"strike_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT,"target_count":TYPE_INT,"shift_force":TYPE_INT,"channel_ticks":TYPE_INT},
	"gladiia_vortex":{"attack_mult":TYPE_FLOAT,"pulse_attack_percent":TYPE_INT,"shift_force":TYPE_INT,"pulse_ticks":TYPE_INT,"lifetime_ticks":TYPE_INT,"damage_pulses":TYPE_INT,"bind_ticks":TYPE_INT,"radius_squared":TYPE_INT,"catch_radius_squared":TYPE_INT,"attack_speed_remaining_percent":TYPE_INT},
	"shaw_strike":{"attack_mult":TYPE_FLOAT,"strike_mult":TYPE_FLOAT,"shift_force":TYPE_INT,"radius_squared":TYPE_INT,"target_count":TYPE_INT},
	"shaw_cannon":{"attack_mult":TYPE_FLOAT,"strike_mult":TYPE_FLOAT,"shift_force":TYPE_INT,"radius_squared":TYPE_INT},

	"muelsyse_progress":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"total_cost":TYPE_INT},
	"muelsyse_ecology":{"attack_mult":TYPE_FLOAT,"cost_add":TYPE_INT,"regen_health_percent":TYPE_INT,"sanctuary_percent":TYPE_INT,"shot_count":TYPE_INT},
	"muelsyse_interaction":{"attack_mult":TYPE_FLOAT,"cost_add":TYPE_INT,"pull_interval_ticks":TYPE_INT,"shift_force":TYPE_INT,"bind_ticks":TYPE_INT},
	"jessica_vigilance":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"shield_defense_mult":TYPE_FLOAT,"shield_duration_add_ticks":TYPE_INT},
	"jessica_cover":{"attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT,"dodge_percent":TYPE_INT},
	"jessica_bombardment":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"shield_defense_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT,"ammo_count":TYPE_INT,"bomb_attack_mult":TYPE_FLOAT,"bomb_stun_ticks":TYPE_INT,"splash_radius_squared":TYPE_INT},
	"flow_copy":{"attack_mult":TYPE_FLOAT},

	"wildmane_deploy":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT},
	"wildmane_charge":{"attack_mult":TYPE_FLOAT,"shift_force":TYPE_INT},
	"eunectes_passive":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT},
	"eunectes_stun":{"attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT},
	"eunectes_engine":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"block_count_add":TYPE_INT,"regen_health_percent":TYPE_INT,"end_stun_ticks":TYPE_INT},

	"stainless_firepower":{"attack_mult":TYPE_FLOAT,"device_scale":TYPE_INT},
	"stainless_supply_boost":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT},
	"stainless_prototype":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT},

	"goldenglow_sparks":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"drone_count":TYPE_INT},
	"goldenglow_current":{"attack_mult":TYPE_FLOAT,"drone_count":TYPE_INT},
	"goldenglow_global":{"attack_mult":TYPE_FLOAT,"drone_count":TYPE_INT,"slow_ticks":TYPE_INT},
	"dusk_paint":{"attack_mult":TYPE_FLOAT,"charge_count":TYPE_INT,"splash_radius_squared":TYPE_INT},
	"dusk_ink":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"hp_threshold_percent":TYPE_INT,"low_health_damage_percent":TYPE_INT},
	"dusk_freehand":{"attack_mult":TYPE_FLOAT,"attack_interval_mult":TYPE_FLOAT,"splash_radius_squared":TYPE_INT,"lifetime_ticks":TYPE_INT},
	"chen_water_pressure":{"attack_mult":TYPE_FLOAT,"ammo_count":TYPE_INT},
	"chen_violet_night":{"attack_mult":TYPE_FLOAT,"ammo_count":TYPE_INT,"charged_ammo_count":TYPE_INT,"charge_count":TYPE_INT,"slow_remaining_percent":TYPE_INT,"defense_reduce":TYPE_INT,"field_ticks":TYPE_INT},
	"chen_holiday_storm":{"attack_mult":TYPE_FLOAT,"ammo_count":TYPE_INT,"ammo_per_attack":TYPE_INT,"shot_count":TYPE_INT,"slow_remaining_percent":TYPE_INT,"defense_reduce":TYPE_INT,"field_ticks":TYPE_INT},
	"fiammetta_confront":{"attack_mult":TYPE_FLOAT,"range_extend":TYPE_INT},
	"fiammetta_repent":{"attack_mult":TYPE_FLOAT,"burst_attack_percent":TYPE_INT,"trail_attack_percent":TYPE_INT,"trail_distance_hundredths":TYPE_INT,"speed_cells_per_second":TYPE_INT,"trail_delay_ticks":TYPE_INT,"splash_radius_hundredths":TYPE_INT,"trail_radius_hundredths":TYPE_INT},
	"fiammetta_repay":{"attack_mult":TYPE_FLOAT,"center_attack_mult":TYPE_FLOAT,"splash_radius_squared":TYPE_INT,"center_radius_squared":TYPE_INT},

	"gnosis_double":{"attack_mult":TYPE_FLOAT,"shot_count":TYPE_INT},
	"gnosis_cold":{"attack_mult":TYPE_FLOAT,"cold_ticks":TYPE_INT,"charge_count":TYPE_INT},
	"gnosis_hypothermia":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"target_count":TYPE_INT,"end_attack_percent":TYPE_INT},
	"silence_drone_skill":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"protection_scale_percent":TYPE_INT},
	"silence_protocol":{"attack_mult":TYPE_FLOAT,"protection_scale_percent":TYPE_INT,"grave_ticks":TYPE_INT,"use_limit":TYPE_INT},
	"ines_bleed":{"attack_mult":TYPE_FLOAT,"cost_add":TYPE_INT,"dot_attack_percent":TYPE_INT,"dot_ticks":TYPE_INT},
	"ines_night":{"attack_mult":TYPE_FLOAT,"cost_add":TYPE_INT,"speed_steal":TYPE_INT,"speed_limit":TYPE_INT},
	"ines_recall":{"attack_mult":TYPE_FLOAT,"cost_add":TYPE_INT,"recall_attack_mult":TYPE_FLOAT,"target_count":TYPE_INT},
	"vigil_call":{"attack_mult":TYPE_FLOAT,"cost_add":TYPE_INT},
	"vigil_hunt":{"attack_mult":TYPE_FLOAT,"cost_add":TYPE_INT,"wolf_attack_mult":TYPE_FLOAT,"wolf_heal_percent":TYPE_INT,"kill_cost":TYPE_INT},
	"vigil_slaughter":{"attack_mult":TYPE_FLOAT,"total_cost":TYPE_INT,"shot_count":TYPE_INT,"magic_attack_percent":TYPE_INT},
	"pozyomka_meter":{"attack_mult":TYPE_FLOAT,"chance_percent":TYPE_INT,"critical_mult":TYPE_FLOAT},
	"pozyomka_burst":{"attack_mult":TYPE_FLOAT,"charge_count":TYPE_INT,"shot_count":TYPE_INT,"redeploy_percent":TYPE_INT},
	"pozyomka_sketch":{"attack_mult":TYPE_FLOAT,"front_attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT},
	"lee_admonition":{"attack_mult":TYPE_FLOAT,"dodge_percent":TYPE_INT},
	"lee_paper":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"base_attack_percent":TYPE_INT,"stack_attack_percent":TYPE_INT,"max_stacks":TYPE_INT,"mark_ticks":TYPE_INT,"splash_radius_squared":TYPE_INT},
	"lee_guest":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"dodge_percent":TYPE_INT,"shift_force":TYPE_INT},

	"reed_fireballs":{"attack_mult":TYPE_FLOAT,"fireball_attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"ball_count":TYPE_INT,"cooldown_ticks":TYPE_INT,"orbit_ticks":TYPE_INT,"orbit_radius_milli":TYPE_INT,"collision_radius_milli":TYPE_INT},
	"reed_lifeseed":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"dot_attack_percent":TYPE_INT,"explosion_attack_percent":TYPE_INT,"explosion_radius_squared":TYPE_INT,"explosion_delay_ticks":TYPE_INT},
	"eyja_permanent":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"elemental_regen_attack_percent":TYPE_INT},
	"eyja_elemental_barrier":{"attack_mult":TYPE_FLOAT,"elemental_barrier_attack_percent":TYPE_INT,"barrier_ticks":TYPE_INT},
	"eyja_volcano":{"attack_mult":TYPE_FLOAT,"heal_percent":TYPE_INT,"heal_count":TYPE_INT,"talent_multiplier":TYPE_INT},
	"texas_silence":{"attack_mult":TYPE_FLOAT,"silence_ticks":TYPE_INT,"dot_damage":TYPE_INT,"dot_duration_ticks":TYPE_INT,"dot_interval_ticks":TYPE_INT},
	"texas_arts":{"attack_mult":TYPE_FLOAT,"burst_attack_mult":TYPE_FLOAT,"resist_remaining_percent":TYPE_INT,"resist_duration_ticks":TYPE_INT},
	"texas_alter_rain":{"attack_mult":TYPE_FLOAT,"burst_attack_mult":TYPE_FLOAT,"burst_stun_ticks":TYPE_INT,"rain_attack_mult":TYPE_FLOAT,"rain_stun_ticks":TYPE_INT,"target_count":TYPE_INT,"first_rain_ticks":TYPE_INT,"rain_interval_ticks":TYPE_INT,"rain_delay_max_ticks":TYPE_INT},
	"penance_hammer":{"attack_mult":TYPE_FLOAT,"charged_attack_mult":TYPE_FLOAT,"magic_attack_mult":TYPE_FLOAT,"charge_count":TYPE_INT,"stun_ticks":TYPE_INT},
	"penance_ascetic":{"attack_mult":TYPE_FLOAT,"pulse_attack_mult":TYPE_FLOAT,"pulse_ticks":TYPE_INT,"sanctuary_percent":TYPE_INT,"barrier_gain_bonus_percent":TYPE_INT},
	"penance_bramble":{"attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT,"barrier_health_percent":TYPE_INT},
	"blemishine_charge":{"attack_mult":TYPE_FLOAT,"heal_attack_percent":TYPE_INT,"charge_count":TYPE_INT},
	"blemishine_sleep":{"attack_mult":TYPE_FLOAT,"sleep_ticks":TYPE_INT,"regen_attack_percent":TYPE_INT},
	"blemishine_radiance":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"magic_attack_mult":TYPE_FLOAT,"heal_attack_percent":TYPE_INT},
	"lin_stance":{"attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT,"slow_ticks":TYPE_INT},
	"lin_shelter":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT},
	"lin_burst":{"attack_mult":TYPE_FLOAT,"threshold_multiplier":TYPE_INT},
	"carnelian_guard":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"charge_count":TYPE_INT},
	"carnelian_bind":{"attack_mult":TYPE_FLOAT,"charged_attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT,"slow_ticks":TYPE_INT,"bind_ticks":TYPE_INT,"charge_count":TYPE_INT},
	"carnelian_feast":{"attack_mult":TYPE_FLOAT,"max_attack_bonus_percent":TYPE_INT,"ramp_steps":TYPE_INT,"ramp_interval_ticks":TYPE_INT,"max_stacks":TYPE_INT,"damage_percent_per_stack":TYPE_INT,"charge_count":TYPE_INT},
	"pallas_whip":{"attack_mult":TYPE_FLOAT,"chance_percent":TYPE_INT,"stun_ticks":TYPE_INT},
	"pallas_blessing":{"check_interval_ticks":TYPE_INT,"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"hp_threshold_percent":TYPE_INT,"vigor_attack_percent":TYPE_INT,"defense_percent":TYPE_INT,"block_count_add":TYPE_INT},
	"archetto_scatter":{"attack_mult":TYPE_FLOAT,"secondary_mult":TYPE_FLOAT,"extra_target_count":TYPE_INT,"jump_radius_squared":TYPE_INT},
	"archetto_chase":{"attack_mult":TYPE_FLOAT,"shot_count":TYPE_INT,"charge_count":TYPE_INT,"jump_radius_squared":TYPE_INT,"pulse_numerator":TYPE_INT,"pulse_denominator":TYPE_INT},
	"archetto_storm":{"attack_mult":TYPE_FLOAT,"shot_count":TYPE_INT,"target_count":TYPE_INT},
	"thorns_counter":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"target_count":TYPE_INT,"cooldown_ticks":TYPE_INT},
	"thorns_destreza":{"attack_mult":TYPE_FLOAT,"repeat_attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"repeat_attack_speed_add":TYPE_INT},
	"cost_dodge":{"cost_add":TYPE_INT},
	"cost_dodge_burst":{"attack_mult":TYPE_FLOAT,"cost_add":TYPE_INT,"shot_count":TYPE_INT,"target_count":TYPE_INT,"stun_ticks":TYPE_INT,"dodge_percent":TYPE_INT,"buff_ticks":TYPE_INT},
	"cost_dodge_mode":{"attack_mult":TYPE_FLOAT,"total_cost":TYPE_INT,"attack_interval_mult":TYPE_FLOAT,"block_count_add":TYPE_INT,"dodge_percent":TYPE_INT},
	"flag_recon":{"attack_mult":TYPE_FLOAT,"total_cost":TYPE_INT,"target_count":TYPE_INT,"attack_speed_reduce":TYPE_INT,"defense_remaining_percent":TYPE_INT},
	"shield_hammer":{"attack_mult":TYPE_FLOAT,"heal_percent":TYPE_INT,"stun_chance_percent":TYPE_INT,"stun_ticks":TYPE_INT},
	"unyield_awakening":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"rest_ticks":TYPE_INT,"attack_interval_mult":TYPE_FLOAT,"attack_speed_reduce":TYPE_INT,"stun_ticks":TYPE_INT},
	"heavy_bind_volley":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"pulse_ticks":TYPE_INT},
	"chain_strike":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"slow_ticks":TYPE_INT},
	"chain_focus":{"attack_mult":TYPE_FLOAT,"attack_interval_mult":TYPE_FLOAT,"target_count":TYPE_INT},
	"chain_storm":{"attack_mult":TYPE_FLOAT,"pulse_attack_percent":TYPE_INT,"lifetime_ticks":TYPE_INT,"pulse_ticks":TYPE_INT,"charge_count":TYPE_INT,"target_count":TYPE_INT},
	"permanent_fragile_attack":{"attack_mult":TYPE_FLOAT,"fragile_multiplier_percent":TYPE_INT},
	"curse_doll_supply":{"stock_limit":TYPE_INT},
	"pusher_slow_strike":{"attack_mult":TYPE_FLOAT,"shift_force":TYPE_INT,"attack_speed_reduce":TYPE_INT,"debuff_ticks":TYPE_INT},
	"pusher_slow_burst":{"attack_mult":TYPE_FLOAT,"shift_force":TYPE_INT,"attack_speed_reduce":TYPE_INT,"debuff_ticks":TYPE_INT,"splash_radius_squared":TYPE_INT},

	"atk_dodge_boost":{"attack_mult":TYPE_FLOAT,"dodge_percent":TYPE_INT},
	"atk_spd_health_boost":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"health_remaining_percent":TYPE_INT},
	"limited_atk_spd_boost":{"attack_mult":TYPE_FLOAT,"attack_speed_add":TYPE_INT,"use_limit":TYPE_INT},
	"percent_charge_heal":{"attack_mult":TYPE_FLOAT,"extra_max_health_percent":TYPE_INT,"charge_count":TYPE_INT,"hp_threshold_percent":TYPE_INT},
	"random_blood_buff":{"attack_mult":TYPE_FLOAT,"attack_percent":TYPE_INT,"hp_loss_percent":TYPE_INT,"buff_ticks":TYPE_INT},
	"guardian_cook":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"warmup_ticks":TYPE_INT,"attack_interval_mult":TYPE_FLOAT},
	"healing_mode":{"attack_mult":TYPE_FLOAT},
	"silence_cloud":{"attack_mult":TYPE_FLOAT,"pulse_attack_percent":TYPE_INT,"lifetime_ticks":TYPE_INT,"pulse_ticks":TYPE_INT,"splash_radius_squared":TYPE_INT},
	"fighter_stance":{"attack_mult":TYPE_FLOAT,"defense_mult":TYPE_FLOAT,"regen_health_percent":TYPE_INT,"block_count_add":TYPE_INT},
	"fighter_barrage":{"attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT,"shot_count":TYPE_INT,"target_count":TYPE_INT,"talent_chance_percent":TYPE_INT,"shift_force":TYPE_INT},
	"kill_refund_strike":{"attack_mult":TYPE_FLOAT},
	"dual_arts_boost":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"single_target_percent":TYPE_INT},
	"twilight":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"max_health_add":TYPE_INT,"ramp_ticks":TYPE_INT,"loss_max_percent":TYPE_INT,"loss_pulse_ticks":TYPE_INT},
	"ambush_charge":{"attack_mult":TYPE_FLOAT,"talent_multiplier":TYPE_INT,"charge_count":TYPE_INT},
	"ambush_bind":{"attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT,"extra_target_count":TYPE_INT,"bind_ticks":TYPE_INT},
	"ambush_stun":{"attack_mult":TYPE_FLOAT,"extra_target_count":TYPE_INT,"stun_ticks":TYPE_INT,"hp_loss_percent":TYPE_INT,"required_targets":TYPE_INT},

	"pull_strike":{"attack_mult":TYPE_FLOAT,"shift_force":TYPE_INT,"channel_ticks":TYPE_INT},
	"pull_chain":{"attack_mult":TYPE_FLOAT,"shift_force":TYPE_INT,"channel_ticks":TYPE_INT,"target_count":TYPE_INT,"stun_ticks":TYPE_INT},
	"bard_sleep":{"regen_attack_percent":TYPE_INT},
	"bard_song":{"regen_attack_percent":TYPE_INT,"inspire_attack_percent":TYPE_INT},
	"medical_drone_supply":{"stock_limit":TYPE_INT},
	"caster_destiny":{"attack_mult":TYPE_FLOAT,"end_attack_stop_ticks":TYPE_INT},
	"splash_shell":{"attack_mult":TYPE_FLOAT,"splash_radius_squared":TYPE_INT},
	"defense_shell":{"attack_mult":TYPE_FLOAT,"splash_radius_squared":TYPE_INT,"defense_reduce":TYPE_INT,"debuff_ticks":TYPE_INT},
	"guardian_mode":{"attack_mult":TYPE_FLOAT,"heal_percent":TYPE_INT,"attack_interval":TYPE_FLOAT},
	"musha_double":{"attack_mult":TYPE_FLOAT,"shot_count":TYPE_INT,"dodge_percent":TYPE_INT},
	"flag_medicine":{"total_cost":TYPE_INT, "heal_percent":TYPE_INT},
	"zima_warcry":{"attack_mult":TYPE_FLOAT,"attack_percent":TYPE_INT,"defense_percent":TYPE_INT,"total_cost":TYPE_INT,"kill_cost":TYPE_INT},
	"liskarm_guard":{"defense_mult":TYPE_FLOAT},
	"liskarm_arc":{"attack_mult":TYPE_FLOAT,"attack_interval_mult":TYPE_FLOAT,"target_count":TYPE_INT,"stun_chance_percent":TYPE_INT,"stun_ticks":TYPE_INT,"end_stun_ticks":TYPE_INT},
	"blue_double":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT},
	"blue_venom":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"primary_shots":TYPE_INT},
	"red_execute":{"attack_mult":TYPE_FLOAT,"dodge_percent":TYPE_INT},
	"red_wolf":{"attack_mult":TYPE_FLOAT,"stun_ticks":TYPE_INT},
	"amiya_burst":{"attack_mult":TYPE_FLOAT,"damage_scale":TYPE_FLOAT,"shot_count":TYPE_INT,"end_stun_ticks":TYPE_INT},
	"amiya_chimera":{"attack_mult":TYPE_FLOAT,"health_percent":TYPE_INT},
	"skyfire_meteor":{"attack_mult":TYPE_FLOAT,"attack_interval_mult":TYPE_FLOAT,"splash_radius_squared":TYPE_INT,"stun_ticks":TYPE_INT},
	"istina_focus":{"attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT},
	"istina_storm":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT},
	"pramanix_echo":{"attack_mult":TYPE_FLOAT,"attack_speed_reduce":TYPE_INT},
	"pramanix_weaken":{"attack_mult":TYPE_FLOAT,"defense_remaining_percent":TYPE_INT,"resist_remaining_percent":TYPE_INT},

	"attack_up":{"attack_mult":TYPE_FLOAT},"defense_up":{"defense_mult":TYPE_FLOAT},
	"platinum_sight":{"attack_mult":TYPE_FLOAT,"attack_speed_reduce":TYPE_INT},
	"specter_survival":{"attack_mult":TYPE_FLOAT,"end_stun_ticks":TYPE_INT},
	"perfumer_blend":{"attack_mult":TYPE_FLOAT,"attack_speed_reduce":TYPE_INT},
	"cuora_shell":{"defense_mult":TYPE_FLOAT,"block_count_add":TYPE_INT,"regen_health_percent":TYPE_INT},
	"texas_sword_rain":{"attack_mult":TYPE_FLOAT,"shot_count":TYPE_INT,"cost_add":TYPE_INT,"stun_ticks":TYPE_INT},
	"lappland_sundial":{"attack_mult":TYPE_FLOAT,"physical_block_percent":TYPE_INT},
	"lappland_wolf":{"attack_mult":TYPE_FLOAT,"target_count":TYPE_INT,"ignore_ranged_penalty":TYPE_BOOL},
	"ptilopsis_healing":{"attack_mult":TYPE_FLOAT,"attack_interval_add":TYPE_FLOAT},
	"gravel_defense":{"defense_percent":TYPE_INT,"decay_ticks":TYPE_INT},
	"gravel_barrier":{"shield_health_percent":TYPE_INT,"decay_ticks":TYPE_INT},
	"bard_share": {"health_percent": TYPE_INT, "regen_attack_percent": TYPE_INT, "share_percent": TYPE_INT},
	"bard_inspire": {"inspire_attack_percent": TYPE_INT, "inspire_defense_percent": TYPE_INT, "regen_attack_percent": TYPE_INT},
	"bard_tide": {"inspire_attack_percent": TYPE_INT, "damage_attack_percent": TYPE_INT, "hp_loss_percent": TYPE_INT, "pulse_ticks": TYPE_INT},
	"lumen_rain": {"heal_percent": TYPE_INT, "pulse_count": TYPE_INT, "pulse_ticks": TYPE_INT},
	"lumen_cleanse": {"heal_percent": TYPE_INT, "target_count": TYPE_INT, "charge_count": TYPE_INT},
	"lumen_lamp": {"attack_mult": TYPE_FLOAT, "attack_speed_add": TYPE_INT, "heal_mult": TYPE_FLOAT, "ammo_count": TYPE_INT},
	"saga_purge": {"attack_mult": TYPE_FLOAT, "cost_add": TYPE_INT, "charge_count": TYPE_INT, "target_count": TYPE_INT, "execute_delay_ticks": TYPE_INT},
	"saga_fury": {"attack_mult": TYPE_FLOAT, "total_cost": TYPE_INT, "attack_interval_add": TYPE_FLOAT},
	"w_grenade": {"attack_mult": TYPE_FLOAT, "stun_ticks": TYPE_INT},
	"w_mine": {"attack_mult": TYPE_FLOAT, "stun_ticks": TYPE_INT, "lifetime_ticks": TYPE_INT, "delay_ticks": TYPE_INT},
	"w_marks": {"attack_mult": TYPE_FLOAT, "stun_ticks": TYPE_INT, "target_count": TYPE_INT, "delay_ticks": TYPE_INT},
	"kaltsit_guard": {"defense_percent": TYPE_INT, "physical_block_percent": TYPE_INT},
	"kaltsit_tactical": {"attack_speed_add": TYPE_INT, "mon3tr_attack_percent": TYPE_INT},
	"kaltsit_meltdown": {"defense_percent": TYPE_INT, "attack_peak_percent": TYPE_INT, "hp_loss_percent": TYPE_INT},
	"nian_magic": {"attack_mult": TYPE_FLOAT, "defense_mult": TYPE_FLOAT},
	"nian_copper": {"defense_mult": TYPE_FLOAT, "block_count_add": TYPE_INT, "reflect_attack_percent": TYPE_INT, "silence_ticks": TYPE_INT},
	"nian_iron": {"attack_mult": TYPE_FLOAT, "ally_defense_percent": TYPE_INT, "ally_block_add": TYPE_INT},
	"aak_defense": {"shot_attack": TYPE_INT, "shot_count": TYPE_INT, "defense_percent": TYPE_INT, "health_percent": TYPE_INT},
	"aak_offense": {"shot_attack": TYPE_INT, "shot_count": TYPE_INT, "attack_percent": TYPE_INT, "attack_speed_add": TYPE_INT},
	"sword_sheath": {"attack_mult": TYPE_FLOAT, "stun_ticks": TYPE_INT},
	"sword_draw": {"attack_mult": TYPE_FLOAT, "target_count": TYPE_INT},
	"sword_slashes": {"attack_mult": TYPE_FLOAT, "slash_count": TYPE_INT, "slash_interval_ticks": TYPE_INT, "stun_ticks": TYPE_INT},
	"magallan_cooling": {"pulse_ticks": TYPE_INT, "slow_ticks": TYPE_INT, "bind_ticks": TYPE_INT},
	"magallan_laser": {"attack_speed_add": TYPE_INT, "splash_radius_squared": TYPE_INT},
	"magallan_artillery": {"attack_percent": TYPE_INT, "splash_radius_squared": TYPE_INT},
	"pusher_strike": {"attack_mult": TYPE_FLOAT, "shift_force": TYPE_INT, "stun_ticks": TYPE_INT},
	"pusher_cannon_mode": {"attack_mult": TYPE_FLOAT, "attack_interval_mult": TYPE_FLOAT, "shift_force": TYPE_INT},
	"nitrogen_blast": {"attack_mult": TYPE_FLOAT, "shift_force": TYPE_INT, "splash_radius_squared": TYPE_INT, "rupture_ticks": TYPE_INT, "rupture_damage_per_cell": TYPE_INT},
	"caster_lock": {"attack_mult": TYPE_FLOAT, "pulse_ticks": TYPE_INT, "stun_ticks": TYPE_INT},
	"caster_wave": {"attack_mult": TYPE_FLOAT, "shift_force": TYPE_INT, "slow_multiplier": TYPE_INT},
	"guardian_aid": {"heal_percent": TYPE_INT, "charge_count": TYPE_INT, "hp_threshold_percent": TYPE_INT},
	"guardian_medicine": {"heal_percent": TYPE_INT},
	"guardian_calcium": {"heal_percent": TYPE_INT, "pulse_ticks": TYPE_INT, "magic_damage_taken_percent": TYPE_INT},
	"instant_cost": {"cost_add": TYPE_INT},
	"pioneer_hammer": {"attack_mult": TYPE_FLOAT, "charge_count": TYPE_INT, "cost_add": TYPE_INT},
	"pioneer_skull": {"attack_mult": TYPE_FLOAT, "attack_interval_add": TYPE_FLOAT, "stun_chance_percent": TYPE_INT, "stun_ticks": TYPE_INT},
	"flame_charge": {"attack_mult": TYPE_FLOAT, "charge_count": TYPE_INT, "burn_attack_percent": TYPE_INT, "burn_ticks": TYPE_INT, "defense_reduce": TYPE_INT},
	"flame_ground": {"attack_mult": TYPE_FLOAT, "pulse_ticks": TYPE_INT, "resist_reduce": TYPE_INT, "resist_ticks": TYPE_INT, "hp_loss_percent": TYPE_INT},
	"dual_arrow_repeat": {"attack_mult": TYPE_FLOAT, "shot_count": TYPE_INT, "stun_chance_percent": TYPE_INT, "stun_ticks": TYPE_INT},
	"marked_arrow_rain": {"attack_mult": TYPE_FLOAT, "shot_count": TYPE_INT, "ammo_count": TYPE_INT, "attack_interval_add": TYPE_FLOAT, "arrow_interval_ticks": TYPE_INT, "splash_radius_squared": TYPE_INT},
	"no_skill": {},
	"deploy_atk_boost": {"attack_mult": TYPE_FLOAT},
	"atk_def_health_boost": {"attack_mult": TYPE_FLOAT, "defense_mult": TYPE_FLOAT, "health_percent": TYPE_INT},
	"deploy_physical_shield": {"dodge_physical_add": TYPE_INT, "shield_health_percent": TYPE_INT},
	"atk_boost_single": {"attack_mult": TYPE_FLOAT},
	"atk_spd_boost": {"attack_mult": TYPE_FLOAT, "attack_speed_add": TYPE_INT},
	"atk_spd_boost_auto": {"attack_mult": TYPE_FLOAT, "attack_speed_add": TYPE_INT},
	"atk_spd_boost_repeat": {"attack_mult": TYPE_FLOAT, "attack_speed_add": TYPE_INT},
	"atk_def_boost": {"attack_mult": TYPE_FLOAT, "defense_mult": TYPE_FLOAT},
	"atk_boost_auto": {"attack_mult": TYPE_FLOAT},
	"heal_boost": {"attack_mult": TYPE_FLOAT},
	"multi_shot": {"shot_count": TYPE_INT, "attack_mult": TYPE_FLOAT},
	"sustained_multi_shot": {"shot_count": TYPE_INT, "attack_mult": TYPE_FLOAT, "attack_interval_add": TYPE_FLOAT},
	"charge_shot": {"attack_mult": TYPE_FLOAT, "charge_count": TYPE_INT, "bind_duration": TYPE_FLOAT},
	"fortress_charge_shot": {"attack_mult": TYPE_FLOAT, "charge_count": TYPE_INT, "splash_radius_squared": TYPE_INT},
	"cost_regen": {"total_cost": TYPE_INT},
	"armor_break_single": {"attack_mult": TYPE_FLOAT, "talent_chance_percent": TYPE_INT},
	"armor_break_boost": {"attack_mult": TYPE_FLOAT, "talent_chance_percent": TYPE_INT, "attack_interval_add": TYPE_FLOAT},
	"passive_heal": {"heal_percent": TYPE_INT, "hp_threshold_percent": TYPE_INT, "heal_radius": TYPE_INT, "coin_limit": TYPE_INT},
	"permanent_multi_target": {"attack_mult": TYPE_FLOAT, "target_count": TYPE_INT},
	"foxfire_aura": {"regen_attack_percent": TYPE_INT, "fragile_multiplier": TYPE_INT},
	"heal_barrier": {"charge_count": TYPE_INT, "shield_attack_percent": TYPE_INT, "defense_percent": TYPE_INT, "barrier_duration_ticks": TYPE_INT},
	"heal_defense_aura": {"attack_mult": TYPE_FLOAT, "defense_percent": TYPE_INT},
	"permanent_atk_def_boost": {"attack_mult": TYPE_FLOAT, "defense_mult": TYPE_FLOAT},
	"ramp_burst": {"attack_bonus_percent": TYPE_INT, "defense_bonus_percent": TYPE_INT, "burst_attack_percent": TYPE_INT, "hp_loss_percent": TYPE_INT, "ramp_steps": TYPE_INT, "pulse_interval_ticks": TYPE_INT},
	"stance_defense_regen": {"attack_mult": TYPE_FLOAT, "defense_mult": TYPE_FLOAT, "regen_health_percent": TYPE_INT, "ignore_ranged_penalty": TYPE_BOOL},
	"multi_target_boost": {"attack_mult": TYPE_FLOAT, "defense_mult": TYPE_FLOAT, "target_count": TYPE_INT, "ignore_ranged_penalty": TYPE_BOOL},
	"charge_multi_shot": {"attack_mult": TYPE_FLOAT, "shot_count": TYPE_INT, "charge_count": TYPE_INT},
	"burst_atk_def_boost": {"attack_mult": TYPE_FLOAT, "defense_mult": TYPE_FLOAT, "shot_count": TYPE_INT, "attack_interval_mult": TYPE_FLOAT, "block_count_add": TYPE_INT},
	"passive_thorns": {"defense_mult": TYPE_FLOAT, "reflect_attack_percent": TYPE_INT},
	"cleave_atk_def_boost": {"attack_mult": TYPE_FLOAT, "defense_mult": TYPE_FLOAT},
	"charge_magic_splash": {"attack_mult": TYPE_FLOAT, "charge_count": TYPE_INT, "splash_radius_squared": TYPE_INT, "resist_remaining_percent": TYPE_INT, "resist_duration_ticks": TYPE_INT},
	"random_multi_target": {"attack_mult": TYPE_FLOAT, "target_count": TYPE_INT, "attack_interval_add": TYPE_FLOAT},
	"heal_magic_barrier": {"shield_attack_percent": TYPE_INT, "charge_count": TYPE_INT, "magic_resist_add": TYPE_INT, "barrier_duration_ticks": TYPE_INT},
	"heal_magic_aura": {"attack_mult": TYPE_FLOAT, "magic_resist_percent": TYPE_INT, "dodge_magical_add": TYPE_INT},
	"shift_attack": {"attack_mult": TYPE_FLOAT, "shift_force": TYPE_INT, "shift_mode": TYPE_STRING},
	"fortress_ammo": {"attack_mult": TYPE_FLOAT, "magic_attack_percent": TYPE_INT, "ammo_count": TYPE_INT, "overload_ammo": TYPE_INT, "hp_loss_percent": TYPE_INT},
	"fortress_overload": {"attack_mult": TYPE_FLOAT, "overload_attack_mult": TYPE_FLOAT, "attack_interval_add": TYPE_FLOAT, "overload_ticks": TYPE_INT, "hp_loss_interval_ticks": TYPE_INT, "hp_loss_max_percent": TYPE_INT},
	"rapid_magic": {"attack_mult": TYPE_FLOAT, "damage_scale": TYPE_FLOAT, "attack_interval_mult": TYPE_FLOAT},
	"weightless_multi_target": {"attack_mult": TYPE_FLOAT, "target_count": TYPE_INT, "weight_reduction": TYPE_INT},
	"deploy_attack_stacks": {"stack_count": TYPE_INT, "attack_percent_per_stack": TYPE_INT},
	"deploy_control_burst": {"attack_mult": TYPE_FLOAT, "control_ticks": TYPE_INT, "shift_force": TYPE_INT},
	"defense_priority_fast": {"attack_mult": TYPE_FLOAT, "attack_interval_mult": TYPE_FLOAT},
	"defense_priority_physical": {"attack_mult": TYPE_FLOAT, "silence_ticks": TYPE_INT},
	"flag_heal": {"attack_mult": TYPE_FLOAT, "total_cost": TYPE_INT, "defense_percent": TYPE_INT, "regen_attack_percent": TYPE_INT},
	"flag_burst": {"attack_mult": TYPE_FLOAT, "burst_attack_percent": TYPE_INT, "stun_ticks": TYPE_INT, "landing_ticks": TYPE_INT, "fragile_percent": TYPE_INT, "instant_cost": TYPE_INT},
	"champagne_traps": {"attack_mult": TYPE_FLOAT, "coin_limit": TYPE_INT, "bomb_attack_percent": TYPE_INT, "slow_ticks": TYPE_INT, "mature_ticks": TYPE_INT, "first_plant_ticks": TYPE_INT, "plant_interval_ticks": TYPE_INT, "plant_attack_delay_ticks": TYPE_INT},
	"coin_barrage": {"attack_mult": TYPE_FLOAT, "coin_limit": TYPE_INT, "shot_count": TYPE_INT, "coin_attack_percent": TYPE_INT, "coin_interval_ticks": TYPE_INT, "shift_force": TYPE_INT},
}

@export var skill_name: String
@export var initial_sp: int
@export var trigger_type: String = "manual"
@export var sp_required: int
@export var sp_recharge_type: String
@export_multiline var description: String
@export var effect_type: String
@export var effect_params: Dictionary
@export var duration: float
@export var attack_range_override: Array[Vector2i] = []
@export var burst_range_override: Array[Vector2i] = []


func parameters_are_valid() -> bool:
	return validation_error().is_empty()


func validation_error() -> String:
	if not PARAMETERS.has(effect_type): return "effect_type: unknown effect " + effect_type
	var required: Dictionary = PARAMETERS[effect_type]
	for key in required:
		if not effect_params.has(key): return "effect_params.%s: required" % key
	for key in effect_params:
		if key == "ignore_ranged_penalty" and effect_type == "atk_boost_single":
			if not effect_params[key] is bool: return "effect_params.ignore_ranged_penalty: expected bool"
			continue
		if not required.has(key): return "effect_params.%s: unknown parameter" % key
		var value: Variant = effect_params[key]
		if typeof(value) != required[key]: return "effect_params.%s: expected %s" % [key, type_string(required[key])]
		if value is float and not is_finite(value): return "effect_params.%s: must be finite" % key
		if value is int or value is float:
			if key == "shift_force":
				if value < 0: return "effect_params.shift_force: must be nonnegative"
			elif key == "talent_chance_percent":
				if value < 0 or value > 100: return "effect_params.talent_chance_percent: expected 0..100"
			elif key == "splash_radius_squared" and effect_type in ["magallan_laser","silence_cloud","pusher_slow_burst"]:
				if value < 0: return "effect_params.splash_radius_squared: must be nonnegative"
			elif key != "attack_interval_add" and value <= 0: return "effect_params.%s: must be positive" % key
			if key in ["shield_health_percent", "dodge_physical_add", "hp_threshold_percent"] and value > 100 and not (effect_type=="gravel_barrier" and key=="shield_health_percent"): return "effect_params.%s: maximum 100" % key
	if effect_type=="gavial_soul" and (int(effect_params["deferred_percent"])>100 or int(effect_params["repay_ticks"])%int(effect_params["pulse_ticks"])!=0):return "effect_params: deferred percent <=100 and whole repayment pulses required"
	if effect_type=="titi_corrosion" and int(effect_params["chance_percent"])>100:return "effect_params.chance_percent: maximum 100"
	if effect_type=="titi_bloom" and int(effect_params["max_attack_percent"])<int(effect_params["min_attack_percent"]):return "effect_params.max_attack_percent: below minimum"
	if effect_type=="gladiia_vortex" and (int(effect_params["attack_speed_remaining_percent"])>100 or int(effect_params["damage_pulses"])*int(effect_params["pulse_ticks"])!=int(effect_params["lifetime_ticks"])):return "effect_params: vortex requires final pull-only pulse and valid slow"
	if skill_name.is_empty(): return "skill_name: required"
	if trigger_type not in ["manual", "auto", "attack", "passive"]: return "trigger_type: unknown value"
	if sp_recharge_type not in ["time", "on_hit", "on_damaged", "on_kill", "passive"]: return "sp_recharge_type: unknown value"
	if (trigger_type == "passive") != (sp_recharge_type == "passive"): return "trigger_type/sp_recharge_type: passive must agree"
	if not is_finite(duration) or duration < -1.0: return "duration: expected finite value >= -1"
	if sp_required < 0 or (sp_required == 0 and sp_recharge_type != "passive"): return "sp_required: must be positive for active skills"
	var limit := sp_required * int(effect_params["charge_count"]) if effect_params.has("charge_count") else sp_required
	if initial_sp < 0 or initial_sp > limit: return "initial_sp: outside stored SP limit"
	for entry in [["attack_range_override", attack_range_override], ["burst_range_override", burst_range_override]]:
		var error := range_error(entry[1])
		if not error.is_empty(): return "%s: %s" % [entry[0], error]
	if effect_type == "fortress_ammo" and effect_params["overload_ammo"] >= effect_params["ammo_count"]: return "effect_params.overload_ammo: must be below ammo_count"
	if effect_type == "fortress_overload" and effect_params["overload_ticks"] >= roundi(duration * CONFIG.TICK_RATE): return "effect_params.overload_ticks: must be before duration end"
	if effect_type == "ramp_burst" and effect_params["ramp_steps"] * effect_params["pulse_interval_ticks"] >= roundi(duration * CONFIG.TICK_RATE): return "effect_params.ramp_steps/pulse_interval_ticks: ramp must finish before duration end"
	if not _effect_relationships_are_valid(): return "effect_params/duration/trigger_type/sp_recharge_type: incompatible " + effect_type
	return ""


static func range_error(offsets: Array[Vector2i]) -> String:
	var seen: Array[Vector2i] = []
	for offset in offsets:
		if absi(offset.x) >= maxi(CONFIG.GRID_COLUMNS, CONFIG.GRID_ROWS) or absi(offset.y) >= maxi(CONFIG.GRID_COLUMNS, CONFIG.GRID_ROWS): return "offset outside map extent"
		if offset in seen: return "duplicate offset " + str(offset)
		seen.append(offset)
	return ""


func _basic_relationships_are_valid() -> bool:
	match effect_type:
		"no_skill": return sp_recharge_type == "passive" and initial_sp == 0 and sp_required == 0 and duration == 0.0
		"deploy_physical_shield": return sp_recharge_type == "passive" and initial_sp == 0 and sp_required == 0 and duration > 0.0
		"passive_heal": return sp_recharge_type == "passive" and initial_sp == 0 and sp_required == 0 and duration == -1.0 and effect_params["heal_radius"] == 1
		"atk_boost_single", "multi_shot", "charge_shot", "fortress_charge_shot", "armor_break_single": return trigger_type == "attack" and duration == 0.0
		"atk_spd_boost_auto", "atk_boost_auto": return trigger_type == "auto" and duration > 0.0
		"sustained_multi_shot": return trigger_type in ["auto", "manual"] and duration > 0.0
		"atk_spd_boost", "atk_spd_boost_repeat", "atk_def_boost", "heal_boost", "cost_regen", "armor_break_boost": return trigger_type == "manual" and duration > 0.0
	return false


func _effect_relationships_are_valid() -> bool:
	if effect_type=="monstr_chain":return trigger_type=="attack" and sp_recharge_type=="on_hit" and duration==0.0 and effect_params["target_count"]==4
	if effect_type in ["monstr_overload","monstr_meltdown"]:return trigger_type=="manual" and sp_recharge_type=="on_hit" and duration>0.0
	if effect_type=="ling_chord":return trigger_type=="manual" and sp_recharge_type=="time" and duration==0.0 and effect_params["charge_count"]==2
	if effect_type in ["ling_wine","ling_thunder"]:return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type in ["titi_corrosion","titi_sanctuary","titi_bloom"]:return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0

	if effect_type in ["gavial_strike","gavial_pull","gavial_soul","mlynar_anger","mlynar_sorrow","mlynar_glory","gladiia_tide_skill","gladiia_vortex"]:return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type in ["shaw_strike","gladiia_strike"]:return trigger_type=="attack" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="shaw_cannon":return trigger_type=="manual" and sp_recharge_type=="time" and duration==0.0 and not attack_range_override.is_empty()
	if effect_type.begins_with("muelsyse_"):return trigger_type=="manual" and sp_recharge_type=="time" and duration==15.0
	if effect_type=="flow_copy":return trigger_type=="manual" and sp_recharge_type=="time" and duration==20.0 and initial_sp==95 and sp_required==100
	if effect_type=="jessica_vigilance":return trigger_type=="auto" and sp_recharge_type=="time" and duration==-1.0
	if effect_type=="jessica_cover":return trigger_type=="manual" and sp_recharge_type=="time" and duration==15.0 and not attack_range_override.is_empty()
	if effect_type=="jessica_bombardment":return trigger_type=="manual" and sp_recharge_type=="time" and duration==-1.0 and effect_params["ammo_count"]==20
	if effect_type=="wildmane_deploy":return sp_recharge_type=="passive" and trigger_type=="passive" and duration==30.0 and initial_sp==0 and sp_required==0
	if effect_type=="wildmane_charge":return sp_recharge_type=="time" and trigger_type=="manual" and duration==20.0 and not attack_range_override.is_empty() and effect_params["shift_force"]==2
	if effect_type=="eunectes_passive":return sp_recharge_type=="passive" and trigger_type=="passive" and duration==-1.0 and initial_sp==0 and sp_required==0
	if effect_type in ["eunectes_stun","eunectes_engine"]:return sp_recharge_type=="time" and trigger_type=="manual" and duration>0.0 and sp_required>0
	if effect_type in ["stainless_firepower","stainless_supply_boost","stainless_prototype"]:return sp_recharge_type=="time" and trigger_type=="manual" and duration==(20.0 if effect_type=="stainless_firepower" else 30.0)
	if effect_type in ["goldenglow_sparks","goldenglow_current","goldenglow_global"]:return sp_recharge_type=="time" and trigger_type==("auto" if effect_type=="goldenglow_current" else "manual") and duration==(-1.0 if effect_type=="goldenglow_current" else (25.0 if effect_type=="goldenglow_sparks" else 30.0))
	if effect_type=="dusk_paint":return sp_recharge_type=="time" and trigger_type=="attack" and duration==0.0 and effect_params["charge_count"]==3
	if effect_type in ["dusk_ink","dusk_freehand"]:return sp_recharge_type=="time" and trigger_type=="manual" and duration==(20.0 if effect_type=="dusk_ink" else 60.0) and not attack_range_override.is_empty()
	if effect_type in ["chen_water_pressure","chen_violet_night","chen_holiday_storm"]:return duration==-1.0 and trigger_type==("auto" if effect_type=="chen_water_pressure" else "manual") and sp_recharge_type==("on_hit" if effect_type=="chen_water_pressure" else "time")
	if effect_type in ["fiammetta_confront","fiammetta_repent","fiammetta_repay"]:return trigger_type=="manual" and sp_recharge_type=="on_hit" and duration==(30.0 if effect_type=="fiammetta_confront" else (0.0 if effect_type=="fiammetta_repent" else -1.0))

	if effect_type=="gnosis_double":return sp_recharge_type=="time" and trigger_type=="attack" and duration==0.0 and effect_params["shot_count"]==2
	if effect_type=="gnosis_cold":return sp_recharge_type=="time" and trigger_type=="manual" and duration==0.0 and effect_params["charge_count"]==2
	if effect_type in ["gnosis_hypothermia","silence_drone_skill","silence_protocol"]:return sp_recharge_type=="time" and trigger_type=="manual" and duration>0.0
	if effect_type=="ines_bleed":return sp_recharge_type=="on_hit" and trigger_type=="attack" and duration==0.0 and sp_required==3 and effect_params["dot_ticks"]==90
	if effect_type=="ines_night":return sp_recharge_type=="time" and trigger_type=="manual" and duration==12.0 and not attack_range_override.is_empty() and effect_params["speed_limit"]==70
	if effect_type=="ines_recall":return sp_recharge_type=="passive" and trigger_type=="passive" and duration==16.0 and sp_required==0 and initial_sp==0
	if effect_type in ["vigil_call","vigil_hunt"]:return sp_recharge_type=="time" and trigger_type=="auto" and duration==0.0 and sp_required>0
	if effect_type=="vigil_slaughter":return sp_recharge_type=="time" and trigger_type=="manual" and duration==15.0 and effect_params["shot_count"]==3
	if effect_type=="pozyomka_meter":return trigger_type=="auto" and sp_recharge_type=="on_hit" and duration==-1.0 and effect_params["chance_percent"]<=100 and effect_params["critical_mult"]>=1.0
	if effect_type=="pozyomka_burst":return trigger_type=="manual" and sp_recharge_type=="time" and duration==0.0 and effect_params["charge_count"]==2 and effect_params["shot_count"]==3 and effect_params["redeploy_percent"]==50
	if effect_type=="pozyomka_sketch":return trigger_type=="manual" and sp_recharge_type=="time" and duration==30.0
	if effect_type in ["lee_admonition","lee_guest"]:return trigger_type=="auto" and sp_recharge_type=="time" and duration==-1.0 and effect_params["dodge_percent"]<=100
	if effect_type=="lee_paper":return trigger_type=="manual" and sp_recharge_type=="time" and duration==0.0

	if effect_type in ["reed_fireballs","reed_lifeseed"]:return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="eyja_permanent":return trigger_type=="auto" and sp_recharge_type=="time" and duration==-1.0
	if effect_type=="eyja_elemental_barrier":return trigger_type=="manual" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="eyja_volcano":return trigger_type=="manual" and sp_recharge_type=="time" and duration==50.0
	if effect_type in ["texas_silence","texas_arts","texas_alter_rain"]:return trigger_type=="passive" and sp_recharge_type=="passive" and sp_required==0 and initial_sp==0 and duration>0.0 and (effect_type=="texas_silence" or not burst_range_override.is_empty())
	if effect_type=="penance_hammer":return trigger_type=="attack" and sp_recharge_type=="time" and duration==0.0 and int(effect_params["charge_count"])==2
	if effect_type=="penance_ascetic":return trigger_type=="manual" and sp_recharge_type=="time" and duration==20.0 and not burst_range_override.is_empty()
	if effect_type=="penance_bramble":return trigger_type=="manual" and sp_recharge_type=="on_damaged" and duration==30.0
	if effect_type=="blemishine_charge":return trigger_type=="attack" and sp_recharge_type=="time" and duration==0.0 and not burst_range_override.is_empty()
	if effect_type in ["blemishine_sleep","blemishine_radiance"]:return trigger_type=="manual" and sp_recharge_type=="on_damaged" and duration>0.0 and not burst_range_override.is_empty()
	if effect_type=="lin_stance":return trigger_type=="manual" and sp_recharge_type=="time" and duration==-1.0
	if effect_type in ["lin_shelter","lin_burst"]:return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type in ["carnelian_guard","carnelian_bind","carnelian_feast"]:return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0 and int(effect_params["charge_count"])==2
	if effect_type=="pallas_whip":return trigger_type=="manual" and sp_recharge_type=="time" and duration==25.0 and not attack_range_override.is_empty()
	if effect_type=="pallas_blessing":return trigger_type=="manual" and sp_recharge_type=="time" and duration==30.0
	if effect_type=="archetto_scatter":return trigger_type=="attack" and sp_recharge_type=="on_hit" and duration==0.0
	if effect_type=="archetto_chase":return trigger_type=="manual" and sp_recharge_type=="on_hit" and duration==0.0
	if effect_type=="archetto_storm":return trigger_type=="manual" and sp_recharge_type=="on_hit" and duration==20.0 and not attack_range_override.is_empty()
	if effect_type=="thorns_counter":return trigger_type=="manual" and sp_recharge_type=="time" and duration==40.0 and not attack_range_override.is_empty()
	if effect_type=="thorns_destreza":return trigger_type=="manual" and sp_recharge_type=="on_hit" and duration==30.0 and not attack_range_override.is_empty()
	if effect_type=="cost_dodge":return trigger_type=="auto" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="cost_dodge_burst":return trigger_type=="manual" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="cost_dodge_mode":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="flag_recon":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="shield_hammer":return trigger_type=="auto" and sp_recharge_type=="on_damaged" and duration==0.0
	if effect_type=="unyield_awakening":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="heavy_bind_volley":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="chain_strike":return trigger_type=="attack" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="chain_focus":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="chain_storm":return trigger_type=="manual" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="permanent_fragile_attack":return trigger_type=="auto" and sp_recharge_type=="time" and duration==-1.0
	if effect_type=="curse_doll_supply":return trigger_type=="auto" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="pusher_slow_strike":return trigger_type=="attack" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="pusher_slow_burst":return trigger_type=="manual" and sp_recharge_type=="time" and duration==0.0

	if effect_type=="atk_dodge_boost":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="atk_spd_health_boost":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="limited_atk_spd_boost":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="percent_charge_heal":return trigger_type=="attack" and sp_recharge_type=="on_hit" and duration==0.0
	if effect_type=="random_blood_buff":return trigger_type=="manual" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="guardian_cook":return trigger_type=="manual" and sp_recharge_type=="time" and duration==40.0 and not attack_range_override.is_empty()
	if effect_type=="healing_mode":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="silence_cloud":return trigger_type=="manual" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="fighter_stance":return trigger_type=="manual" and sp_recharge_type=="time" and duration==-1.0 and not attack_range_override.is_empty()
	if effect_type=="fighter_barrage":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0 and not attack_range_override.is_empty()
	if effect_type=="kill_refund_strike":return trigger_type=="attack" and sp_recharge_type=="on_hit" and duration==0.0
	if effect_type=="dual_arts_boost":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="twilight":return trigger_type=="manual" and sp_recharge_type=="time" and duration==-1.0
	if effect_type=="ambush_charge":return trigger_type=="attack" and sp_recharge_type=="time" and duration==0.0
	if effect_type=="ambush_bind":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0
	if effect_type=="ambush_stun":return trigger_type=="manual" and sp_recharge_type=="time" and duration>0.0

	if effect_type in ["red_execute","red_wolf"]:return sp_recharge_type=="passive" and trigger_type=="passive" and sp_required==0 and initial_sp==0 and duration==(10.0 if effect_type=="red_execute" else 0.0)
	if effect_type=="liskarm_guard":return sp_recharge_type=="on_damaged" and trigger_type=="auto" and duration==8.0
	if effect_type=="liskarm_arc":return sp_recharge_type=="on_damaged" and trigger_type=="manual" and duration==20.0
	if effect_type=="blue_double":return sp_recharge_type=="on_hit" and trigger_type=="attack" and duration==0.0
	if effect_type=="amiya_burst":return sp_recharge_type=="time" and trigger_type=="auto" and duration==25.0
	if effect_type in ["zima_warcry","blue_venom","amiya_chimera","skyfire_meteor","istina_focus","istina_storm","pramanix_echo","pramanix_weaken"]:return sp_recharge_type=="time" and trigger_type=="manual" and duration>0.0
	if effect_type=="platinum_sight":return sp_recharge_type=="time" and trigger_type=="auto" and duration==-1.0 and not attack_range_override.is_empty() and int(effect_params["attack_speed_reduce"])<100
	if effect_type in ["attack_up","defense_up","specter_survival","perfumer_blend","cuora_shell"]:return sp_recharge_type=="time" and trigger_type=="manual" and duration>0.0 and (effect_type!="perfumer_blend" or int(effect_params["attack_speed_reduce"])<100)
	if effect_type=="texas_sword_rain":return sp_recharge_type=="time" and trigger_type=="manual" and duration==0.0 and not attack_range_override.is_empty()
	if effect_type in ["lappland_sundial","lappland_wolf"]:return sp_recharge_type=="on_hit" and trigger_type=="auto" and duration==(-1.0 if effect_type=="lappland_sundial" else 20.0)
	if effect_type=="ptilopsis_healing":return sp_recharge_type=="time" and trigger_type=="manual" and duration==40.0 and not attack_range_override.is_empty()
	if effect_type in ["gravel_defense","gravel_barrier"]:return sp_recharge_type=="passive" and trigger_type=="passive" and sp_required==0 and initial_sp==0 and roundi(duration*CONFIG.TICK_RATE)==int(effect_params["decay_ticks"])
	if effect_type in ["bard_share","bard_inspire","bard_tide"]:return sp_recharge_type=="time" and trigger_type==("auto" if effect_type=="bard_inspire" else "manual") and duration==(-1.0 if effect_type=="bard_inspire" else (30.0 if effect_type=="bard_share" else 20.0))
	if effect_type in ["lumen_rain","lumen_cleanse","lumen_lamp"]:return sp_recharge_type=="time" and trigger_type==("attack" if effect_type=="lumen_rain" else "manual") and duration==(-1.0 if effect_type=="lumen_lamp" else 0.0)
	if effect_type in ["saga_purge","saga_fury"]:return sp_recharge_type=="time" and trigger_type=="manual" and duration==(0.0 if effect_type=="saga_purge" else 20.0) and not attack_range_override.is_empty()
	if effect_type in ["w_grenade", "w_mine", "w_marks"]:return sp_recharge_type=="time" and trigger_type==("attack" if effect_type=="w_mine" else "manual") and duration==0.0
	if effect_type in ["kaltsit_guard","kaltsit_tactical","kaltsit_meltdown"]:return sp_recharge_type=="time" and trigger_type=="manual" and duration>0.0
	if effect_type in ["nian_magic","nian_copper","nian_iron"]:return sp_recharge_type=="time" and trigger_type=="manual" and duration>0.0 and (effect_type!="nian_iron" or not attack_range_override.is_empty())
	if effect_type in ["aak_defense","aak_offense"]:return sp_recharge_type=="time" and trigger_type=="manual" and duration>0.0
	if effect_type == "sword_sheath":return sp_recharge_type=="on_hit" and trigger_type=="attack" and duration==0.0
	if effect_type in ["sword_draw","sword_slashes"]:return sp_recharge_type=="on_hit" and trigger_type=="manual" and duration==0.0 and not attack_range_override.is_empty()
	if effect_type in ["magallan_cooling", "magallan_laser", "magallan_artillery"]:
		return trigger_type == "manual" and sp_recharge_type == "time" and duration > 0.0
	if effect_type == "pusher_strike":
		return trigger_type == "attack" and sp_recharge_type == "time" and duration == 0.0 and effect_params["shift_force"] >= 0
	if effect_type == "pusher_cannon_mode":
		return trigger_type == "auto" and sp_recharge_type == "time" and duration == -1.0 and effect_params["attack_interval_mult"] > 1.0 and not attack_range_override.is_empty()
	if effect_type == "nitrogen_blast":
		return trigger_type == "manual" and sp_recharge_type == "time" and duration == 0.0 and not attack_range_override.is_empty()
	if effect_type == "caster_lock":
		return trigger_type == "manual" and sp_recharge_type == "time" and duration > 0.0 and effect_params["pulse_ticks"] == CONFIG.TICK_RATE
	if effect_type == "caster_wave":
		return trigger_type == "manual" and sp_recharge_type == "time" and duration > 0.0 and not attack_range_override.is_empty() and effect_params["shift_force"] >= 0
	if effect_type in ["guardian_aid", "guardian_medicine"]:
		return trigger_type == "auto" and sp_recharge_type == "time" and duration == 0.0 and not attack_range_override.is_empty()
	if effect_type == "guardian_calcium":
		return trigger_type == "manual" and sp_recharge_type == "time" and duration > 0.0 and not attack_range_override.is_empty() and effect_params["magic_damage_taken_percent"] > 100
	if effect_type == "instant_cost":
		return sp_recharge_type == "time" and trigger_type == "auto" and duration == 0.0
	if effect_type == "pioneer_hammer":
		return sp_recharge_type == "time" and trigger_type == "attack" and duration == 0.0 and not attack_range_override.is_empty()
	if effect_type == "pioneer_skull":
		return sp_recharge_type == "time" and trigger_type == "manual" and duration > 0.0 and effect_params["stun_chance_percent"] <= 100
	if effect_type == "flame_charge":
		return sp_recharge_type == "time" and trigger_type == "attack" and duration == 0.0 and effect_params["attack_mult"] > 1.0 and effect_params["burn_ticks"] >= CONFIG.TICK_RATE and effect_params["burn_ticks"] % CONFIG.TICK_RATE == 0
	if effect_type == "flame_ground":
		return sp_recharge_type == "time" and trigger_type == "manual" and duration > 0.0 and effect_params["hp_loss_percent"] <= 100 and effect_params["pulse_ticks"] <= roundi(duration * CONFIG.TICK_RATE)
	if effect_type == "dual_arrow_repeat":
		return sp_recharge_type == "time" and trigger_type == "manual" and duration > 0.0 and effect_params["attack_mult"] > 1.0 and effect_params["shot_count"] == 2 and effect_params["stun_chance_percent"] <= 100
	if effect_type == "marked_arrow_rain":
		return sp_recharge_type == "time" and trigger_type == "manual" and duration == -1.0 and effect_params["attack_mult"] > 1.0 and effect_params["attack_interval_add"] > 0.0 and effect_params["shot_count"] > 1
	if effect_type == "deploy_atk_boost":
		return sp_recharge_type == "passive" and trigger_type == "passive" and initial_sp == 0 and sp_required == 0 and duration > 0.0 and effect_params["attack_mult"] > 1.0
	if effect_type == "atk_def_health_boost":
		return sp_recharge_type == "time" and trigger_type == "manual" and duration > 0.0 and effect_params["attack_mult"] > 1.0 and effect_params["defense_mult"] > 1.0 and effect_params["health_percent"] > 0
	if effect_type == "champagne_traps":
		if sp_recharge_type != "passive" or trigger_type != "passive" or initial_sp != 0 or sp_required != 0 or duration != -1.0 or burst_range_override.is_empty() or effect_params["attack_mult"] != 1.0:
			return false
		for key in ["coin_limit", "bomb_attack_percent", "slow_ticks", "mature_ticks", "first_plant_ticks", "plant_interval_ticks", "plant_attack_delay_ticks"]:
			if not effect_params.get(key) is int or effect_params[key] <= 0: return false
		return true
	if effect_type == "coin_barrage":
		if sp_recharge_type != "time" or trigger_type != "auto" or initial_sp != 0 or sp_required <= 0 or duration != -1.0 or burst_range_override.is_empty() or effect_params["attack_mult"] != 1.0:
			return false
		for key in ["coin_limit", "shot_count", "coin_attack_percent", "coin_interval_ticks", "shift_force"]:
			if not effect_params.get(key) is int or effect_params[key] <= 0: return false
		return true
	if effect_type == "splash_shell":
		return sp_recharge_type == "on_hit" and trigger_type == "attack" and duration == 0.0
	if effect_type == "defense_shell":
		return sp_recharge_type == "time" and trigger_type == "manual" and duration == 0.0
	if effect_type == "guardian_mode":
		return sp_recharge_type == "time" and trigger_type == "manual" and duration > 0 and not attack_range_override.is_empty()
	if effect_type == "musha_double":
		return sp_recharge_type == "time" and trigger_type == "manual" and duration > 0 and effect_params["dodge_percent"] <= 100
	if effect_type == "flag_medicine":
		return sp_recharge_type == "time" and trigger_type == "manual" and duration > 0 and not attack_range_override.is_empty()
	if effect_type == "flag_heal":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration > 0 and not attack_range_override.is_empty() and effect_params["attack_mult"] == 1.0 and effect_params["total_cost"] > 0 and effect_params["defense_percent"] > 0 and effect_params["regen_attack_percent"] > 0
	if effect_type == "flag_burst":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration > 0 and not attack_range_override.is_empty() and effect_params["attack_mult"] == 1.0 and effect_params["burst_attack_percent"] > 0 and effect_params["stun_ticks"] > 0 and effect_params["landing_ticks"] > 0 and effect_params["fragile_percent"] > 0 and effect_params["instant_cost"] > 0
	if effect_type == "defense_priority_fast":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration > 0.0 and effect_params["attack_mult"] == 1.0 and effect_params["attack_interval_mult"] > 0.0 and effect_params["attack_interval_mult"] < 1.0
	if effect_type == "defense_priority_physical":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration > 0.0 and not attack_range_override.is_empty() and effect_params["attack_mult"] > 1.0 and effect_params["silence_ticks"] > 0
	if effect_type == "deploy_attack_stacks":
		return sp_recharge_type == "passive" and trigger_type == "passive" and initial_sp == 0 and sp_required == 0 and duration == -1.0 and effect_params["stack_count"] > 0 and effect_params["attack_percent_per_stack"] > 0
	if effect_type == "deploy_control_burst":
		return sp_recharge_type == "passive" and trigger_type == "passive" and initial_sp == 0 and sp_required == 0 and duration == -1.0 and not burst_range_override.is_empty() and effect_params["attack_mult"] > 1.0 and effect_params["control_ticks"] > 0 and effect_params["shift_force"] >= 0
	if effect_type == "rapid_magic":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration > 0.0 and effect_params["attack_mult"] == 1.0 and effect_params["damage_scale"] > 0.0 and effect_params["damage_scale"] <= 1.0 and effect_params["attack_interval_mult"] > 0.0
	if effect_type == "weightless_multi_target":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration > 0.0 and not attack_range_override.is_empty() and effect_params["attack_mult"] > 1.0 and effect_params["target_count"] > 1 and effect_params["weight_reduction"] > 0
	if effect_type == "fortress_ammo":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration == -1.0 and effect_params["attack_mult"] > 0.0 and effect_params["magic_attack_percent"] > 0 and effect_params["ammo_count"] > 0 and effect_params["overload_ammo"] > 0 and effect_params["overload_ammo"] < effect_params["ammo_count"] and effect_params["hp_loss_percent"] > 0 and effect_params["hp_loss_percent"] < 100
	if effect_type == "fortress_overload":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration > 0 and effect_params["attack_mult"] > 1.0 and effect_params["overload_attack_mult"] > effect_params["attack_mult"] and effect_params["overload_ticks"] > 0 and effect_params["overload_ticks"] < roundi(duration * CONFIG.TICK_RATE) and effect_params["hp_loss_interval_ticks"] > 0 and effect_params["hp_loss_max_percent"] > 0
	if effect_type == "shift_attack":
		return sp_recharge_type in ["time", "on_hit"] and trigger_type == "attack" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration == 0.0 and effect_params["attack_mult"] > 0.0 and effect_params["shift_force"] >= 0 and effect_params["shift_mode"] in ["push", "pull"]
	if effect_type == "heal_magic_barrier":
		return sp_recharge_type == "time" and trigger_type == "auto" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration == 0.0 and effect_params["shield_attack_percent"] > 0 and effect_params["charge_count"] > 0 and effect_params["magic_resist_add"] > 0 and effect_params["barrier_duration_ticks"] > 0
	if effect_type == "heal_magic_aura":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration > 0.0 and not attack_range_override.is_empty() and effect_params["attack_mult"] > 1.0 and effect_params["magic_resist_percent"] > 0 and effect_params["dodge_magical_add"] > 0 and effect_params["dodge_magical_add"] <= 100
	if effect_type in ["pull_strike","pull_chain"]:
		return sp_recharge_type=="time" and trigger_type==("attack" if effect_type=="pull_strike" else "manual") and initial_sp>=0 and initial_sp<=sp_required and sp_required>0 and duration==0.0 and effect_params["attack_mult"]>1.0 and effect_params["shift_force"]>=0 and effect_params["channel_ticks"]>0 and (effect_type!="pull_chain" or (not attack_range_override.is_empty() and effect_params["target_count"]>0 and effect_params["stun_ticks"]>0))
	if effect_type in ["bard_sleep","bard_song"]:
		return sp_recharge_type=="time" and trigger_type=="manual" and initial_sp>=0 and initial_sp<=sp_required and sp_required>0 and duration>0.0 and (effect_type!="bard_sleep" or not attack_range_override.is_empty())
	if effect_type == "medical_drone_supply":
		return sp_recharge_type=="time" and trigger_type=="auto" and initial_sp==0 and sp_required>0 and duration==0.0 and effect_params["stock_limit"]==1
	if effect_type == "caster_destiny":
		return sp_recharge_type=="time" and trigger_type=="manual" and initial_sp>=0 and initial_sp<=sp_required and sp_required>0 and duration>0.0 and not attack_range_override.is_empty() and effect_params["attack_mult"]>1.0 and effect_params["end_attack_stop_ticks"]>0
	if effect_type == "charge_magic_splash":
		return sp_recharge_type == "time" and trigger_type == "attack" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration == 0.0 and effect_params["attack_mult"] > 1.0 and effect_params["charge_count"] > 0 and effect_params["splash_radius_squared"] > 0 and effect_params["resist_remaining_percent"] > 0 and effect_params["resist_remaining_percent"] < 100 and effect_params["resist_duration_ticks"] > 0
	if effect_type == "random_multi_target":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration > 0.0 and not attack_range_override.is_empty() and effect_params["attack_mult"] > 1.0 and effect_params["target_count"] > 1
	if effect_type == "passive_thorns":
		return sp_recharge_type == "passive" and trigger_type == "passive" and initial_sp == 0 and sp_required == 0 and duration == -1.0 and effect_params["defense_mult"] > 1.0 and effect_params["reflect_attack_percent"] > 0
	if effect_type == "cleave_atk_def_boost":
		return sp_recharge_type == "time" and trigger_type == "manual" and initial_sp >= 0 and initial_sp <= sp_required and sp_required > 0 and duration > 0.0 and effect_params["attack_mult"] > 1.0 and effect_params["defense_mult"] > 1.0
	if effect_type in ["no_skill", "deploy_physical_shield", "atk_boost_single", "atk_spd_boost", "atk_spd_boost_auto", "atk_spd_boost_repeat", "atk_def_boost", "atk_boost_auto", "heal_boost", "multi_shot", "sustained_multi_shot", "charge_shot", "fortress_charge_shot", "cost_regen", "armor_break_single", "armor_break_boost", "passive_heal"]:
		return _basic_relationships_are_valid()
	if sp_recharge_type != "time" or sp_required <= 0 or initial_sp < 0 or initial_sp > sp_required:
		return false
	if effect_type == "charge_multi_shot":
		return trigger_type == "attack" and duration == 0.0 and effect_params["attack_mult"] > 1.0 and effect_params["shot_count"] > 1 and effect_params["charge_count"] > 0
	if effect_type == "burst_atk_def_boost":
		return trigger_type == "manual" and duration > 0.0 and effect_params["attack_mult"] > 1.0 and effect_params["defense_mult"] > 1.0 and effect_params["shot_count"] > 1 and effect_params["attack_interval_mult"] > 0.0 and effect_params["block_count_add"] > 0
	if effect_type in ["stance_defense_regen", "multi_target_boost"]:
		if trigger_type != "manual" or attack_range_override.is_empty() or not effect_params["ignore_ranged_penalty"]:
			return false
		if effect_type == "stance_defense_regen":
			return duration == -1.0 and effect_params["attack_mult"] == 1.0 and effect_params["defense_mult"] > 1.0 and effect_params["regen_health_percent"] > 0
		return duration > 0.0 and effect_params["attack_mult"] > 1.0 and effect_params["defense_mult"] > 0.0 and effect_params["target_count"] > 1
	if effect_type == "permanent_atk_def_boost":
		return trigger_type == "auto" and duration == -1.0 and not attack_range_override.is_empty() and effect_params["attack_mult"] > 1.0 and effect_params["defense_mult"] > 1.0
	if effect_type == "ramp_burst":
		if trigger_type != "manual" or duration <= 0 or attack_range_override.is_empty() or burst_range_override.is_empty():
			return false
		for key in ["attack_bonus_percent", "defense_bonus_percent", "burst_attack_percent", "hp_loss_percent", "ramp_steps", "pulse_interval_ticks"]:
			if not effect_params.get(key) is int or effect_params[key] <= 0:
				return false
		return effect_params["hp_loss_percent"] <= 100 and effect_params["ramp_steps"] > 1 and effect_params["ramp_steps"] * effect_params["pulse_interval_ticks"] < roundi(duration * CONFIG.TICK_RATE)
	if effect_type == "heal_barrier":
		return trigger_type == "auto" and duration == 0.0 and effect_params["charge_count"] > 0 and effect_params["shield_attack_percent"] > 0 and effect_params["defense_percent"] > 0 and effect_params["barrier_duration_ticks"] > 0
	if effect_type == "heal_defense_aura":
		return trigger_type == "manual" and duration > 0 and effect_params["attack_mult"] > 1.0 and effect_params["defense_percent"] > 0
	if effect_type == "permanent_multi_target":
		return trigger_type == "auto" and duration == -1.0 and effect_params["attack_mult"] > 1.0 and effect_params["target_count"] > 0
	return trigger_type == "manual" and duration > 0 and not attack_range_override.is_empty() and effect_params["regen_attack_percent"] > 0 and effect_params["fragile_multiplier"] > 0
