class_name RNG
extends RefCounted

const MASK_32 := 0xffffffff
const NONZERO_SEED := 0x6d2b79f5

var state: int


func _init(seed: int) -> void:
	state = seed & MASK_32
	if state == 0:
		state = NONZERO_SEED


func next_u32() -> int:
	var value := state
	value ^= (value << 13) & MASK_32
	value ^= value >> 17
	value ^= (value << 5) & MASK_32
	state = value & MASK_32
	return state


func next_percent() -> int:
	return next_u32() % 100
