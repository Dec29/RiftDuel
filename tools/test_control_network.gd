extends "res://tools/test_balanced_batch_network.gd"

func prepare(state: MatchState) -> void:
	super.prepare(state)
	for unit in state.units:
		if state.tick>=60 and state.tick%3==0:StatusRules.add_control(state,unit,"slow",24)
		if state.tick in [60,150]:StatusRules.add_control(state,unit,"bind",75)
