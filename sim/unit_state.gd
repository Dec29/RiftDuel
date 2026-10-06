class_name UnitState
extends RefCounted

var unit_id: int
var side: int
var operator_id: String
var cell: Vector2i
var facing: int
var hp: int
var sp: int
var attack_ticks_left: int
var sp_regen_ticks: int = 0
var skill_ticks_left: int = 0
var bind_ticks_left: int = 0
var last_attack_tick: int = -1
var last_attack_target_x: int = 0
var last_attack_target_y: int = 0
var last_damage_tick: int = -1
var last_heal_tick: int = -1
var coins: int = 0
var coin_attack_stacks: int = 0
var cost_drain_ticks: int = 0
var last_coin_gain_tick: int = -1
var last_coin_spend_tick: int = -1
var last_attack_is_heal: bool = false
var attack_bonus_percent: int = 0
var defense_bonus_percent: int = 0
var attack_speed_bonus: int = 0
var magic_resist_bonus: int = 0
var max_health_bonus_percent: int = 0
var blessing_target_id: int = -1
var emergency_heal_used: bool = false
var hp_lock_ticks_left: int = 0
var revive_cost: int = 0
var hp_regen_accum: int = 0
var last_damage_block_tick: int = -1
var life_loss_ticks: int = 0


func _init(
	id: int = 0,
	unit_side: int = 0,
	data_id: String = "",
	unit_cell: Vector2i = Vector2i.ZERO,
	unit_hp: int = 0,
	unit_sp: int = 0,
	attack_cooldown: int = 0,
	unit_facing: int = -1,
) -> void:
	unit_id = id
	side = unit_side
	operator_id = data_id
	cell = unit_cell
	facing = unit_facing if unit_facing != -1 else (2 if unit_side == 0 else 0)
	hp = unit_hp
	sp = unit_sp
	attack_ticks_left = attack_cooldown
