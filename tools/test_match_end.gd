extends SceneTree

var failures := 0

func _initialize() -> void:
	for column in [9, 10, 11]:
		var state := MatchState.new(31)
		state.tick = Config.MATCH_TICKS - 2
		state.ball.cell.x = column
		state.step([], [])
		_expect(state.result == 0, "Must not end before 9000 ticks")
		state.step([], [])
		_expect(state.result == (1 if column < 10 else (2 if column > 10 else 0)), "Normal-time column verdict: %d" % column)
	for column in [9, 10, 11]:
		var state := MatchState.new(32)
		state.tick = Config.MATCH_TICKS
		state.ball.cell.x = column
		state.step([], [])
		_expect(state.result == 0, "Overtime must not end on merely crossing center")
		state.tick = Config.MATCH_TICKS + Config.OVERTIME_TICKS - 1
		state.step([], [])
		_expect(state.result == (1 if column < 10 else (2 if column > 10 else 3)), "Overtime column verdict: %d" % column)
		var frozen := state.state_hash()
		state.step([], [])
		_expect(state.state_hash() == frozen, "Completed match must freeze all state")
	for boundary in [Config.MATCH_TICKS, Config.MATCH_TICKS + Config.OVERTIME_TICKS]:
		for column in [0, 20]:
			var state := MatchState.new(33)
			state.tick = boundary - 1
			state.ball.cell.x = column
			state.step([], [])
			_expect(state.result == (1 if column == 0 else 2), "Goal must take precedence over timeout")
	var moving := MatchState.new(34)
	moving.tick = Config.MATCH_TICKS - 1
	moving.ball.cell = Vector2i(10, 5)
	moving.ball.move_direction = Vector2i.LEFT
	moving.ball.move_ticks_left = 2
	moving.step([], [])
	_expect(moving.result == 0 and moving.ball.cell.x == 10, "Unfinished movement must use settled column")
	var first := MatchState.new(35)
	var second := MatchState.new(35)
	for tick in Config.MATCH_TICKS + Config.OVERTIME_TICKS:
		first.step([], [])
		second.step([], [])
		_expect(first.state_hash() == second.state_hash(), "Timeout replay diverged: %d" % tick)
	_expect(first.result == 3 and first.tick == 10800, "Empty match must draw at exactly six minutes")
	print("Match end: normal time, overtime, goals, settled position, frozen result, 10800-tick replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
