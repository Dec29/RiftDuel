class_name SideState
extends RefCounted

const CONFIG := preload("res://data/config.gd")

var side_id: int
var cost: int
var cost_regen_ticks: int
var cooldowns: Dictionary
var phantom_count: int = 0
var phantom_cooldown_ticks: int = 0


func _init(id: int) -> void:
	side_id = id
	cost = CONFIG.COST_INITIAL
	cost_regen_ticks = 0
	cooldowns = {}
