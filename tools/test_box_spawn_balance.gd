extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_weights()
	_test_history_and_availability()
	_test_cell_count_independence()
	_test_distribution()
	_test_replay_and_reset()
	_test_hash()
	print("BOX_SPAWN_BALANCE_OK: weights,history,legal halves,blocked warning,scarce cells,6750tick replay,goal retention,new-round reset and hash" if failures == 0 else "BOX_SPAWN_BALANCE_FAILED count%d" % failures)
	quit(0 if failures == 0 else 1)


func _test_weights() -> void:
	var state := MatchState.new(19)
	check(TacticalRules.box_half_weights(state) == PackedInt32Array([100, 100]), "Initial halves equal")
	state.box_spawn_counts_by_half = PackedInt32Array([1, 0]); state.box_last_spawn_half = 0; state.box_same_half_streak = 1
	check(TacticalRules.box_half_weights(state) == PackedInt32Array([50, 200]), "One leading repeat has20percent chance")
	state.box_spawn_counts_by_half = PackedInt32Array([2, 0]); state.box_same_half_streak = 2
	check(TacticalRules.box_half_weights(state) == PackedInt32Array([33, 300]), "Two leading repeats have33/333 chance")
	state.box_spawn_counts_by_half = PackedInt32Array([0, 2]); state.box_last_spawn_half = 1
	check(TacticalRules.box_half_weights(state) == PackedInt32Array([300, 33]), "World halves symmetric")
	state.box_same_half_streak = 1000
	check(TacticalRules.box_half_weights(state)[1] == 1, "Repeat weight has positive integer floor")
	state.box_spawn_counts_by_half = PackedInt32Array([9, 3]); state.box_last_spawn_half = 1; state.box_same_half_streak = 1
	check(TacticalRules.box_half_weights(state) == PackedInt32Array([100, 350]), "Historical deficit can outweigh last-side penalty")


func _test_history_and_availability() -> void:
	var state := MatchState.new(83)
	state.tick = state.next_box_spawn_tick - Config.BOX_WARNING_TICKS
	TacticalRules.advance_boxes(state)
	var reserved := state.box_warning_cell
	var half := 0 if reserved.x < 10 else 1
	var random := state.rng.state
	check(reserved.x >= 0 and state.box_spawn_counts_by_half == PackedInt32Array([0, 0]) and state.box_last_spawn_half == -1 and state.box_same_half_streak == 0, "Warning does not count as landing")
	TacticalRules.advance_boxes(state)
	check(state.rng.state == random and state.box_warning_cell == reserved, "Warning never rerolls")
	state.ball.cell = reserved; state.tick = state.next_box_spawn_tick
	TacticalRules.advance_boxes(state)
	check(state.tactical_boxes.is_empty() and state.box_spawn_counts_by_half[half] == 0 and state.rng.state == random, "Ball-delayed landing does not count or consume RNG")
	state.ball.cell = Config.BALL_START_CELL
	TacticalRules.advance_boxes(state)
	check(state.box_spawn_counts_by_half[half] == 1 and state.box_spawn_counts_by_half[1-half] == 0 and state.box_last_spawn_half == half and state.box_same_half_streak == 1, "Actual landing updates only its world half")
	state.tactical_boxes.clear()
	check(state.box_spawn_counts_by_half[half] == 1, "Removing claimed box never erases history")
	var blocked := MatchState.new(41)
	for y in Config.GRID_ROWS:
		for x in Config.GRID_COLUMNS:
			if x != 10: blocked.platform_cells.append(Vector2i(x, y))
	blocked.tick = blocked.next_box_spawn_tick
	random = blocked.rng.state
	TacticalRules.advance_boxes(blocked)
	check(blocked.box_warning_cell.x < 0 and blocked.rng.state == random and blocked.box_spawn_counts_by_half == PackedInt32Array([0, 0]), "No legal cells leaves history and RNG unchanged")
	blocked.platform_cells.erase(Vector2i(11, 5))
	TacticalRules.advance_boxes(blocked)
	check(blocked.box_warning_cell == Vector2i(11, 5) and blocked.next_box_spawn_tick == blocked.tick + Config.BOX_WARNING_TICKS, "Only available half receives full warning")
	blocked.tick = blocked.next_box_spawn_tick
	TacticalRules.advance_boxes(blocked)
	check(blocked.box_spawn_counts_by_half == PackedInt32Array([0, 1]), "Single-cell forced landing counted once")


func _test_cell_count_independence() -> void:
	var left := 0
	for seed in range(1, 513):
		var state := MatchState.new(seed)
		for y in Config.GRID_ROWS:
			for x in 10:
				if Vector2i(x, y) != Vector2i(1, 5): state.platform_cells.append(Vector2i(x, y))
		state.tick = state.next_box_spawn_tick - Config.BOX_WARNING_TICKS
		TacticalRules.advance_boxes(state)
		if state.box_warning_cell.x < 10:
			left += 1
			check(state.box_warning_cell == Vector2i(1, 5), "Left-half draw only selects legal left cell")
	check(left >= 200 and left <= 312, "One legal left cell still receives approximately half of512 initial draws, actual%d" % left)
	print("BOX_SPARSE_HALF_SAMPLE left=%d right=%d" % [left, 512-left])


func _test_distribution() -> void:
	var repeats := 0
	var pairs := 0
	var gap_sum := 0
	var large_gaps := 0
	for seed in range(1, 513):
		var state := MatchState.new(seed)
		var last := -1
		while state.next_box_spawn_tick <= Config.MATCH_TICKS:
			state.tick = state.next_box_spawn_tick - Config.BOX_WARNING_TICKS
			TacticalRules.advance_boxes(state)
			state.tick = state.next_box_spawn_tick
			TacticalRules.advance_boxes(state)
			check(not state.tactical_boxes.is_empty(), "Distribution sample actually lands a box")
			if state.tactical_boxes.is_empty(): return
			var half := 0 if state.tactical_boxes.back().cell.x < 10 else 1
			if last >= 0: pairs += 1
			if last == half: repeats += 1
			last = half
			state.tactical_boxes.clear()
		var gap := absi(state.box_spawn_counts_by_half[0] - state.box_spawn_counts_by_half[1])
		gap_sum += gap
		if gap >= 3: large_gaps += 1
	var repeat_rate := float(repeats) / pairs
	var mean_gap := float(gap_sum) / 512
	check(repeat_rate < 0.35 and mean_gap < 1.0 and large_gaps < 40, "512 fixed-seed normal five-minute samples reduce repeated halves and final imbalance")
	print("BOX_DISTRIBUTION_SAMPLE seeds512 repeat_rate=%.6f mean_gap=%.6f games_gap3=%d" % [repeat_rate, mean_gap, large_gaps])


func _test_replay_and_reset() -> void:
	var first := MatchState.new(733)
	var replay := MatchState.new(733)
	for tick in Config.MATCH_TICKS:
		first.step([], []); replay.step([], [])
		check(first.state_hash() == replay.state_hash(), "New spawn history every-tick replay%d" % tick)
	check(first.next_box_id >= 3 and first.box_spawn_counts_by_half[0] + first.box_spawn_counts_by_half[1] == first.next_box_id, "Actual normal schedule counts all spawned boxes")
	var scored := MatchState.new(3)
	scored.rules.mode = "score"
	scored.box_spawn_counts_by_half = PackedInt32Array([3, 2]); scored.box_last_spawn_half = 0; scored.box_same_half_streak = 1
	scored.ball.cell = Vector2i(0, 5)
	scored.step([], [])
	check(scored.goals[0] == 1 and scored.result == MatchState.RESULT_RUNNING and scored.box_spawn_counts_by_half == PackedInt32Array([3, 2]) and scored.box_last_spawn_half == 0 and scored.box_same_half_streak == 1, "Score-mode goal retains whole-round history")
	var fresh := MatchState.new(3)
	check(fresh.box_spawn_counts_by_half == PackedInt32Array([0, 0]) and fresh.box_last_spawn_half == -1 and fresh.box_same_half_streak == 0, "New round resets history without aliasing old state")


func _test_hash() -> void:
	for half in 2:
		var state := MatchState.new(1)
		var before := state.state_hash()
		state.box_spawn_counts_by_half[half] += 1
		check(state.state_hash() != before, "Half%d count participates in hash" % half)
	for field in ["box_last_spawn_half", "box_same_half_streak"]:
		var state := MatchState.new(1)
		var before := state.state_hash()
		state.set(field, state.get(field) + 1)
		check(state.state_hash() != before, field + " participates in hash")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
