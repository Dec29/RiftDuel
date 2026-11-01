class_name SideState
extends RefCounted

var rhine_cost_reduction: int = 0
var rhine_first_cost_reduction: int = 0
var rhine_first_discount_used: bool = false

var wildmane_discounts: Dictionary = {}

var stainless_stock: int = 0

var ines_first_shadow_used: bool = false
var ines_shadow_cell := Vector2i(-1,-1)
var ines_shadow_facing: int = 0

const CONFIG := preload("res://data/config.gd")

var sniper_cost_discount: int = 0
var sussurro_skill_uses: int = 0
var silence_protocol_uses: int = 0

var side_id: int
var cost: int
var cost_regen_ticks: int
var cooldowns: Dictionary
var phantom_count: int = 0
var phantom_cooldown_ticks: int = 0
var ling_stock: int = 0
var drone_stock: int = 0
var drone_cooldown_ticks: int = 0
var cannon_cooldown_ticks: int = 0
var clone_cooldown_ticks: int = 0
var vanguard_cost_discount: int = 0
var next_deploy_discount: int = 0
var tactical_items: Array[int] = [0, 0, 0, 0]


func _init(id: int) -> void:
	side_id = id
	cost = CONFIG.COST_INITIAL
	cost_regen_ticks = 0
	cooldowns = {}
