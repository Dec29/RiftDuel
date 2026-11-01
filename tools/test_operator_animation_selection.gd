extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id in ["bagpipe", "blaze", "hoshiguma"]:
		var model := OperatorSpineVisual.new()
		if not _check(model.initialize(id), model.last_error): return
		for facing in 4:
			var unit := UnitState.new(1, 0, id, Vector2i(4, 5), 1000, 0, 30, facing)
			unit.last_attack_tick = 0
			if not _check(model.prepare(unit, 9.0, 60), model.last_error): return
			var expected := "Attack_Loop_Down" if facing == 1 else "Attack_Loop"
			if id != "bagpipe": expected = "Attack_Down" if facing == 1 else "Attack"
			if not _check(model.clip == expected, "%s facing=%d expected=%s actual=%s" % [id, facing, expected, model.clip]): return
	# The recorded attack target, rather than deployment facing, determines Horn's mode.
	var horn := OperatorSpineVisual.new()
	if not _check(horn.initialize("horn"), horn.last_error): return
	for facing in 4:
		var unit := UnitState.new(1, 0, "horn", Vector2i(4, 5), 1000, 0, 30, facing)
		unit.last_attack_tick = 0
		unit.last_attack_target_x = 4
		unit.last_attack_target_y = 5
		if not _check(horn.prepare(unit, 9.0, 84) and horn.clip == "Attack_B", "Horn own-cell target must use melee B"): return
		unit.last_attack_target_x = 8
		if not _check(horn.prepare(unit, 9.0, 84) and horn.clip == "Attack_A", "Horn distant target must use ranged A"): return
	# Both equipped skills share the same source action; S3 must reach its end
	# within the shorter real interval, without changing the simulation or resource.
	var operator: OperatorData = load("res://resources/operators/exusiai.tres")
	var data := {"exusiai": operator}
	var state := MatchState.new(172, data)
	for selected in [1, 2]:
		var unit := UnitState.new(selected, selected - 1, "exusiai", Vector2i(13, 2), 1000, 0, 30, 0, selected)
		unit.skill_ticks_left = 450
		unit.last_attack_tick = 0
		state.units.append(unit)
		var model := OperatorSpineVisual.new()
		if not _check(model.initialize("exusiai"), model.last_error): return
		var interval := SkillRules.attack_interval_ticks(unit, operator)
		var before := state.state_hash()
		if not _check(model.prepare(unit, interval * 0.8, interval) and model.clip == "Attack" and model.pose_seconds > 0.9, "Exusiai skill %d full attack phase within %d ticks" % [selected + 1, interval]): return
		if not _check(model.prepare(unit, interval * 0.9, interval) and model.clip == "Idle", "Exusiai completes action before next attack"): return
		if not _check(before == state.state_hash(), "Animation changed combat state"): return
	print("OPERATOR_ANIMATION_SELECTION_OK")
	quit(0)

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
