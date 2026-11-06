extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func run() -> void:
	var db := root.get_node("OperatorDB")
	# All registered summons must bypass ordinary-operator icon lookup, including
	# passive and manually activated summons. Missing ordinary mappings stay errors.
	for id in db.SUMMON_OWNERS:
		var summon: OperatorData = load("res://resources/summons/%s.tres" % id)
		for index in summon.skills.size():
			if not check(SkillIconVisual.texture(id, index) == null, "Summon fallback " + id): return
	var data := {}
	for id in ["kaltsit", "muelsyse"]:
		data[id] = db.get_data(id)
		for index in data[id].skills.size():
			if not check(SkillIconVisual.texture(id, index) != null, "Owner icon " + id): return
	for owner in ["kaltsit", "muelsyse"]:
		var summon_id := "mon3tr" if owner == "kaltsit" else "flowing_shape"
		for skill in 3:
			for side in 2:
				var ids := PackedStringArray([owner])
				var skills := PackedInt32Array([skill])
				var state := MatchState.new(155, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [ids, ids], [skills, skills])
				state.sides[side].cost = 99
				state.ball.cell = Vector2i(10, 10)
				var empty: Array[InputCommand] = []
				var commands: Array[InputCommand] = [InputCommand.new(0, 0, owner, -1, Vector2i(13 if side == 0 else 7, 2), -1, 2 if side == 0 else 0)]
				state.step(commands if side == 0 else empty, commands if side == 1 else empty)
				if not check(state.units.size() == 1, "Owner deployed " + owner): return
				var input := LocalInput.new(side)
				var view := MatchView.new()
				view.bind(state, input, data)
				view.multiplayer_match = true
				root.add_child(view)
				if not check(summon_id in view._tray_operator_ids(), "New summon tray " + summon_id): return
				for mirror in [false, true]:
					view.mirror_board = mirror
					var before := state.state_hash()
					view.queue_redraw()
					await process_frame
					await process_frame
					if not check(state.state_hash() == before, "Tray rendering is read-only"): return
				state.sides[side].cost = 99
				commands = [InputCommand.new(state.tick, 0, summon_id, -1, Vector2i(13 if side == 0 else 7, 3), -1, 2 if side == 0 else 0)]
				state.step(commands if side == 0 else empty, commands if side == 1 else empty)
				if not check(state.units.size() == 2, "Summon deployed " + summon_id): return
				input.select_unit(state.units[-1].unit_id)
				var before := state.state_hash()
				view.queue_redraw()
				await process_frame
				await process_frame
				if not check(state.state_hash() == before, "Summon info is read-only"): return
				view.queue_free()
				await process_frame
	print("SUMMON_SKILL_ICONS_OK: 23 summon mappings, 2 owners x3 skills x2 sides x2 mirrors; actual tray, deployment and selected-unit HUD")
	quit(0)
