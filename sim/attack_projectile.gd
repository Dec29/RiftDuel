class_name AttackProjectile
extends RefCounted
# A released attack is independent of its owner's continued presence/control.
var source_id: int
var source_side: int
var operator_id: String
var source_cell: Vector2i
var facing: int
var kind: int
var target_id: int
var target_cell: Vector2i
var goal_generation: int
var attack: int
var shots: int
var release_tick: int
var arrival_tick: int

# 0: first simple shooter payload, 1: launch-family physical/arts/splash payload.
var delivery := 0
var damage_type := "physical"
var skill_index := 0
var silenced := false
var active := false
var stun_ticks := 0
var splash_radius_squared := -1

var armor_break := false
var splash_affects_objects := true

var cold_ticks := 0
var slow_ticks := 0
var bind_ticks := 0
var armor_remaining_percent := 100
var armor_ticks := 0
var typewriter_remaining_percent := 100
var typewriter_ticks := 0
var shift_force := -1
var shift_pull := false
var primary_attack := -1
var inner_attack := -1
var inner_radius_squared := -1
var minimum_percent := 5
var resist_ignore := 0

var chain_count := 0

var attack_event := true
var shell_defense_reduce := 0
var shell_ticks := 0

var order_key := 0
var defense_remaining_percent := 100
var defense_ignore_flat := 0
var extra_magic_attack := 0

var skill_use := 0
var first_hit_bonus_percent := 0
var first_hit_slow_ticks := 0

var rupture_damage_per_cell := 0
var rupture_ticks := 0

var can_hit_sleep := false
