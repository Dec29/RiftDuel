class_name UnitState
extends RefCounted

var reconstruct_owner_id: int = -1
var monstr_origin_cell: Vector2i = Vector2i(-1,-1)
var monstr_token_ready: bool = false
var monstr_echo_tick: int = -1
var monstr_echo_target_id: int = -1
var monstr_echo_amount: int = 0
var monstr_echo_synergy: int = 0
var monstr_synergy_until_tick: int = -1
var monstr_synergy_speed: int = 0
var monstr_overload_until_tick: int = -1
var monstr_overload_speed: int = 0
var monstr_loss_accum: int = 0
var monstr_return_guard_ticks: int = 0


var flow_owner_id: int = -1
var flow_root_id: int = -1
var flow_is_split: bool = false
var flow_copy_id: String = ""
var flow_point_until_tick: int = 0
var flow_expiry_tick: int = 0
var flow_health: int = 0
var flow_attack: int = 0
var flow_defense: int = 0
var flow_resist: int = 0
var flow_block: int = 0
var flow_interval_ticks: int = 45
var flow_range: Array[Vector2i] = []
var flow_melee: bool = true
var flow_magical: bool = true
var flow_can_charge: bool = false
var flow_attack_count: int = 0
var flow_stolen_attack: int = 0
var flow_stolen_defense: int = 0
var flow_attack_loss: int = 0
var flow_defense_loss: int = 0
var flow_victim_ids := PackedInt32Array()
var flow_victim_attack := PackedInt32Array()
var flow_victim_defense := PackedInt32Array()
var flow_regen_accum: int = 0
var flow_sanctuary_percent: int = 0
var jessica_owner_id: int = -1
var jessica_expiry_tick: int = 0
var jessica_shield_extended: bool = false
var jessica_original_facing: int = 0
var jessica_bomb_pending: bool = false
var jessica_bomb_tick: int = -1
var jessica_bomb_cell := Vector2i(-1,-1)


var eunectes_sp_enabled: bool = false
var eunectes_regen_accum: int = 0

var stainless_owner_id: int = -1
var stainless_loss_accum: int = 0
var stainless_sp_ticks: int = 0

var dusk_owner_id: int = -1
var dusk_expiry_tick: int = 0
var dusk_first_attack_used: bool = false
var dusk_kill_stacks: int = 0
var fiammetta_vigor_percent: int = 0
var chen_slime_defense_reduce: int = 0
var golden_target_ids := PackedInt32Array([-2147483648,-2147483648,-2147483648])
var golden_target_x := PackedInt32Array([0,0,0])
var golden_target_y := PackedInt32Array([0,0,0])
var golden_goal_generation := PackedInt32Array([0,0,0])
var golden_trait_hits := PackedInt32Array([0,0,0])
var golden_explosion_stacks := PackedInt32Array([1,1,1])
var golden_cooldowns := PackedInt32Array([0,0,0])


var cold_ticks_left: int = 0
var frozen_ticks_left: int = 0
var silence_grave_until_tick: int = 0
var silence_grave_used: bool = false
var silence_drone_stock: int = 0
var silence_drone_owner_id: int = -1
var silence_regen_accum: int = 0


var ines_stolen_attack: int = 0
var ines_attack_loss: int = 0
var ines_speed_gain: int = 0
var ines_speed_loss: int = 0
var ines_shadow_slow: int = 0
var ines_target_ids := PackedInt32Array()
var ines_target_speed := PackedInt32Array()
var ines_dot_until: int = 0
var ines_dot_next: int = 0
var ines_dot_attack: int = 0
var ines_dot_source: int = -1
var vigil_owner_id: int = -1
var vigil_wolf_layers: int = 0
var vigil_regrow_tick: int = 0
var vigil_enhanced_attack: bool = false
var vigil_enhanced_victim: int = -1


var typewriter_owner_id: int = -1
var typewriter_defense_remaining_percent: int = 100
var typewriter_defense_until_tick: int = 0
var lee_marked: bool = false
var lee_control_charm: bool = false
var lee_mark_target_id: int = -1
var lee_mark_until_tick: int = -1
var lee_mark_stacks: int = 0
var lee_mark_cell: Vector2i = Vector2i(-1,-1)


var texas_first_kill_used: bool = false
var texas_recast_pending: bool = false
var texas_burst_pending: bool = false
var texas_started_tick: int = -1
var texas_rain_next_tick: int = -1
var texas_rain_emissions: int = 0
var texas_dot_until_tick: int = 0
var texas_dot_next_tick: int = 0
var texas_dot_source_id: int = -1
var texas_resist_remaining_percent: int = 100
var texas_resist_until_tick: int = 0

var penance_barrier_hp: int = 0
var penance_charged_mode: bool = false

var blemishine_regen_accum: int = 0

var lin_wall_owner_id: int = -1
var lin_wall_ready_tick: int = 0
var lin_wall_active: bool = false

var carnelian_charged: bool = false
var carnelian_mark_owner_id: int = -1
var carnelian_mark_stacks: int = 0
var carnelian_mark_until_tick: int = 0

var pallas_vigor_next_tick: int = 0
var pallas_vigor_percent: int = 0
var pallas_blessing_next_tick: int = 0
var pallas_blessing_vigor_percent: int = 0

var thorns_last_active_attack_tick: int = -1
var thorns_counter_ready_tick: int = 0
var thorns_regen_accum: int = 0
var thorns_poison_until_tick: int = 0
var thorns_poison_next_tick: int = 0
var thorns_poison_source_id: int = -1
var thorns_poison_damage: int = 0

var dodge_physical_bonus: int = 0
var dodge_next_physical: bool = false
var dodge_attack_ready: bool = false
var dodge_aura_until_tick: int = -1
var dodge_aura_next_tick: int = -1
var dodge_aura_ids := PackedInt32Array()
var attack_speed_remaining_percent: int = 100
var speed_debuff_until_tick: int = -1
var speed_debuff_remaining_percent: int = 100
var recon_defense_remaining_percent: int = 100
var curse_defense_remaining_percent: int = 100
var curse_attack_remaining_percent: int = 100
var bind_link_owner_id: int = -1
var shield_charge_ticks: int = 0
var curse_doll_stock: int = 0
var curse_doll_owner_id: int = -1
var analysis_target_ids := PackedInt32Array()
var analysis_expiry_ticks := PackedInt32Array()
var death_sp_resolved: bool = false

var healing_received_bonus_percent: int = 0
var max_health_bonus_add: int = 0
var limited_skill_uses: int = 0
var fatal_until_tick: int = -1
var weaken_until_tick: int = -1
var weaken_attack_remaining_percent: int = 100
var blood_buff_until_tick: int = -1
var blood_buff_attack_percent: int = 0
var blood_buff_loss_percent: int = 0
var blood_buff_next_tick: int = -1

var hook_owner_id: int = -1
var hook_due_tick: int = -1
var hook_stun_ticks: int = 0
var sleep_ticks_left: int = 0
var medical_drone_stock: int = 0
var medical_drone_owner_id: int = -1
var fortune_choice: int = -1
var destiny_attack_stop_ticks: int = 0
var shell_ticks_left: int = 0
var shell_defense_reduce: int = 0

var healing_output_percent: int = 100

var musha_speed_accum: int = 0
var musha_attack_speed: int = 0

var launch_started_tick: int = -1
var launch_end_tick: int = -1
var poison_until_tick: int = 0
var poison_next_tick: int = 0
var poison_source_id: int = -1
var poison_damage: int = 0
var poison_pulse_ticks: int = 0
var pramanix_defense_remaining_percent: int = 100
var pramanix_resist_remaining_percent: int = 100
var liskarm_shield_ready: bool = false
var amiya_retreat_pending: bool = false

var cuora_started_tick: int = -1
var cuora_end_tick: int = -1
var lappland_skill_tick: int = -1
var ptilopsis_skill_tick: int = -1
var ptilopsis_end_tick: int = -1
var texas_cast_tick: int = -1
var gravel_ticks_left: int = 0
var gravel_barrier_initial: int = 0
var gravel_barrier_hp: int = 0
var gravel_decay_accum: int = 0
var bard_skill_started_tick: int = -1
var bard_mode: int = 0
var bard_owner_id: int = -1
var inspire_attack_add: int = 0
var inspire_defense_add: int = 0
var bard_regen_accum: int = 0
var bard_loss_accum: int = 0
var bard_pulse_tick: int = -1
var lumen_resistance_ticks: int = 0
var lumen_emergency_ready_tick: int = 0
var lumen_lamp_started_tick: int = -1
var lumen_lamp_closed_tick: int = -1
var lumen_cast_tick: int = -1
var lumen_special_tick: int = -1
var critical_speed_percent: int = 100
var critical_sp_add: int = 0
var critical_ticks_left: int = 0
var critical_execute_tick: int = -1
var critical_executor_id: int = -1
var saga_focus_ticks: int = 0
var saga_focus_used: bool = false
var saga_regen_accum: int = 0
var saga_cast_tick: int = -1
var ambush_ready: bool = false
var w_action_tick: int = -1
var w_action_kind: int = -1
var mon3tr_owner_id: int = -1
var mon3tr_mode: int = 0
var mon3tr_outside_range: bool = true
var mon3tr_killed: bool = false
var mon3tr_death_triggered: bool = false
var mon3tr_decay_ticks_left: int = 0
var mon3tr_decay_duration_ticks: int = 0
var mon3tr_attack_peak_percent: int = 0
var nian_shield_layers: int = 0
var block_bonus: int = 0
var status_resistance_bonus: int = 0
var aak_injection_tick: int = -1
var aak_attack_percent: int = 0
var aak_speed_add: int = 0
var aak_defense_percent: int = 0
var aak_health_percent: int = 0
var aak_buff_ticks: int = 0
var aak_buff_index: int = -1
var aak_buff_source_id: int = -1
var chen_slash_tick: int = -1
var chen_slashes_left: int = 0
var chen_next_slash_tick: int = 0
var chen_cast_tick: int = -1
var chen_sheath_tick: int = -1
var rupture_until_tick: int = 0
var rupture_source_id: int = -1
var rupture_damage_per_cell: int = 0
var nitrogen_shot_tick: int = -1
var pusher_strike_tick: int = -1
var pusher_mode_started_tick: int = -1
var drone_owner_id: int = -1
var unit_id: int
var side: int
var operator_id: String
var cell: Vector2i
var facing: int
var hp: int
var sp: int
var attack_ticks_left: int
var sp_regen_ticks: int = 0
var sp_regen_accum: int = 0
var sp_recharge_bonus_percent: int = 0
var skill_ticks_left: int = 0
var skill_repeat_activation_count: int = 0
var skill_activation_count: int = 0
var skill_cost_accum: int = 0
var skill_elapsed_ticks: int = 0
var skill_regen_attack: int = 0
var skill_hp_regen_accum: int = 0
var bind_ticks_left: int = 0
var slow_ticks_left: int = 0
var slow_next_interrupt_tick: int = 0
var last_basic_interrupt_tick: int = -1
var bind_immunity_ticks_left: int = 0
var resist_break_ticks_left: int = 0
var resist_remaining_percent: int = 100
var armor_break_ticks_left: int = 0
var armor_break_defense_percent: int = 100
var attack_intent: AttackIntent
var attack_started_tick: int = -1
var attack_next_ready_tick := 0
var attack_action_clip := ""
var attack_action_view_index := -1
var attack_action_event_frames:=PackedInt32Array()
var attack_action_event_index:=0
var attack_action_triggered:=false
var attack_action_proc:=false
var skill_started_tick: int=-1
var skill_start_observed_count: int=0
var attack_action_window_ticks := 0
var attack_action_source_frames := 0
var last_attack_tick: int = -1
var last_attack_target_x: int = 0
var last_attack_target_y: int = 0
var last_damage_tick: int = -1
var last_heal_tick: int = -1
var bomb_next_tick: int = 0
var coin_firing: bool = false
var coin_fire_ticks_left: int = 0
var coin_target_ids: PackedInt32Array = PackedInt32Array()
var coins: int = 0
var coin_attack_stacks: int = 0
var cost_drain_ticks: int = 0
var last_coin_gain_tick: int = -1
var last_coin_spend_tick: int = -1
var last_attack_is_heal: bool = false
var attack_bonus_percent: int = 0
var defense_bonus_percent: int = 0
var defense_bonus_add: int = 0
var attack_speed_bonus: int = 0
var magic_resist_bonus: int = 0
var magic_resist_bonus_percent: int = 0
var dodge_magical_bonus: int = 0
var max_health_bonus_percent: int = 0
var blessing_target_id: int = -1
var emergency_heal_used: bool = false
var hp_lock_ticks_left: int = 0
var revive_cost: int = 0
var hp_regen_accum: int = 0
var last_damage_block_tick: int = -1
var life_loss_ticks: int = 0
var physical_shield_hp: int = 0
var physical_guard_ticks_left: int = 0
var barrier_hp: PackedInt32Array = PackedInt32Array()
var barrier_ticks_left: PackedInt32Array = PackedInt32Array()
var barrier_defense_percent: PackedInt32Array = PackedInt32Array()
var barrier_magic_only: PackedInt32Array = PackedInt32Array()
var barrier_magic_resist_add: PackedInt32Array = PackedInt32Array()
var skill_defense_bonus_percent: int = 0
var bloodbath_used: bool = false
var last_bloodbath_tick: int = -1
var deployed_tick: int = 0
var stun_ticks_left: int = 0
var silence_ticks_left: int = 0
var flag_cell: Vector2i = Vector2i(-1,-1)
var flag_landing_ticks_left: int = 0
var flag_burst_pending: bool = false
var flag_defense_bonus_percent: int = 0
var skill_index: int = 0
var displacement_origin: Vector2i = Vector2i.ZERO
var displacement_ticks_left: int = 0
var displacement_duration_ticks: int = 0
var attack_boost_stacks: int = 0
var deploy_control_kind: int = -1
var talent_sp_ticks: int = 0
var flame_resist_aura_percent: int = 0
var flame_resist_ticks: int = 0
var flame_resist_reduce: int = 0
var burn_until_tick: int = 0
var burn_next_tick: int = 0
var burn_source_id: int = -1
var burn_attack: int = 0
var burn_attack_percent: int = 0
var burn_defense_reduce: int = 0
var penetration_stacks: int = 0
var penetration_last_tick: int = -1
var skill_hit_ids := PackedInt32Array()
var mark_kind: int = -1
var mark_id: int = -1
var mark_cell := Vector2i(-1,-1)
var mark_refresh_ticks: int = 0
var rain_arrows_left: int = 0
var rain_next_tick: int = 0
var skill_ammo_left: int = 0
var skill_dump_pending: bool = false


var reed_cinder_source_id: int = -1
var reed_cinder_until_tick: int = 0
var reed_cinder_attack_reduce_percent: int = 0
var reed_cinder_magic_fragile_percent: int = 0
var reed_lifeseed_mark: bool = false
var reed_dot_next_tick: int = 0
var reed_explosion_queued: bool = false
var reed_explosion_immunity_until_tick: int = 0
var reed_fireball_started_tick: int = 0
var reed_fireball_carriers := PackedInt32Array()
var reed_fireball_ready_ticks := PackedInt32Array()
var eyja_mist_stacks: int = 0
var eyja_mist_until_tick: int = 0
var eyja_mist_next_tick: int = 0
var eyja_mist_heal: int = 0
var eyja_mist_source_id: int = -1
var eyja_elemental_barrier: int = 0
var eyja_elemental_barrier_until_tick: int = 0


var mlynar_charge_ticks: int = 0
var mlynar_charge_bonus_percent: int = 0
var mlynar_skill_killed: bool = false
var gavial_deferred_damage: int = 0
var gavial_debt_total: int = 0
var gavial_debt_ticks_left: int = 0
var gavial_debt_accum: int = 0
var gavial_debt_pulse_ticks: int = 0
var gladiia_regen_accum: int = 0
var gladiia_hook_ticks_left: int = 0
var gladiia_vortex_cell := Vector2i(-1,-1)
var gladiia_vortex_started_tick: int = -1
var gladiia_vortex_next_pulse: int = 0
var gladiia_vortex_pulses: int = 0
var gladiia_vortex_attack: int = 0
var gladiia_vortex_slow_remaining_percent: int = 100


var ling_owner_id: int = -1
var ling_advanced: bool = false
var ling_recycle_stacks: int = 0
var ling_pulse_ticks: int = 0
var ling_skill_mode: int = 0

var titi_dot_next_tick: int = -1
var titi_doze_owner_id: int = -1
var titi_doze_mode: int = 0
var titi_sanctuary_target_id: int = -1
var titi_sleep_ids := PackedInt32Array()
var titi_sleep_elapsed := PackedInt32Array()

func _init(
	id: int = 0,
	unit_side: int = 0,
	data_id: String = "",
	unit_cell: Vector2i = Vector2i.ZERO,
	unit_hp: int = 0,
	unit_sp: int = 0,
	attack_cooldown: int = 0,
	unit_facing: int = -1,
	carried_skill: int = 0,
) -> void:
	unit_id = id
	side = unit_side
	operator_id = data_id
	skill_index = carried_skill
	cell = unit_cell
	facing = unit_facing if unit_facing != -1 else (2 if unit_side == 0 else 0)
	hp = unit_hp
	sp = unit_sp
	attack_ticks_left = attack_cooldown
