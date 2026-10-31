extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for id in ["bagpipe","shining"]:
		var data: OperatorData=load("res://resources/operators/%s.tres"%id)
		var state := MatchState.new(3,{id:data})
		var unit := UnitState.new(0,0,id,Vector2i(13,5),data.max_health,0,0,2)
		state.units.append(unit);state.tick=106;unit.last_attack_tick=100;unit.deployed_tick=0
		var model := OperatorSpineVisual.new()
		if not model.initialize(id):push_error(model.last_error);quit(1);return
		for facing in 4:
			unit.facing=facing;unit.last_basic_interrupt_tick=-1
			if not model.prepare(unit,106.0,90) or model.clip=="Idle":push_error("Expected live attack/heal pose");quit(1);return
			var before := state.state_hash()
			unit.slow_next_interrupt_tick=0;StatusRules.add_control(state,unit,"slow",24)
			var controlled := state.state_hash()
			if before==controlled or not model.prepare(unit,106.0,90) or model.clip!="Idle" or state.state_hash()!=controlled:push_error("Interrupted action must return to native idle without view state writes");quit(1);return
	print("CONTROL_VIEW_OK: attack/heal native interruption, four facings, read-only rendering")
	quit(0)
