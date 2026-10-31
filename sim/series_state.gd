class_name SeriesState
extends RefCounted

# Verified per-round results; no transport or view dependencies.
var results := PackedInt32Array()

func record(round_number: int, result: int) -> void:
	assert(round_number>0 and result in [1,2,3])
	if results.size()==round_number:
		assert(results[-1]==result)
		return
	assert(results.size()==round_number-1)
	results.append(result)

func wins() -> PackedInt32Array:
	var counts := PackedInt32Array([0,0])
	for result in results:
		if result in [1,2]:counts[result-1]+=1
	return counts

func verdict() -> int:
	var counts := wins()
	return 3 if counts[0]==counts[1] else (1 if counts[0]>counts[1] else 2)

func state_hash() -> int:
	var value := results.size()
	for result in results:value=(value*31+result)&0x7fffffff
	return value
