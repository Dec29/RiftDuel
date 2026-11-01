class_name TacticalItemEffect
extends RefCounted

const CONFIG := preload("res://data/config.gd")

var item_kind: int
var side: int
var cell: Vector2i
var facing: int
var placed_tick: int
var effect_tick: int
var activated: bool


func _init(kind: int, owner: int, position: Vector2i, direction: int, tick: int) -> void:
	item_kind = kind
	side = owner
	cell = position
	facing = direction
	placed_tick = tick
	effect_tick = tick + (CONFIG.ITEM_STUN_WINDUP_TICKS if kind == CONFIG.TACTICAL_ITEM_STUN else 0)
	activated = kind != CONFIG.TACTICAL_ITEM_STUN
