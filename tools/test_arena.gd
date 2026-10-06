extends SceneTree

const ARENA := preload("res://resources/map/standard_arena.tres")
const BALL_DATA := preload("res://resources/ball/standard.tres")
var _failures := 0


func _initialize() -> void:
	var high_cells: Array[Vector2i] = []
	for y in [2, 8]:
		for x in [3, 4, 7, 8, 12, 13, 16, 17]:
			high_cells.append(Vector2i(x, y))
	for y in [4, 6]:
		for x in [6, 14]:
			high_cells.append(Vector2i(x, y))
	var high_count := 0
	var no_deploy_count := 0
	for y in 11:
		_expect(ARENA.terrain_rows[y].length() == 21, "Map row %d must contain 21 cells" % y)
		for x in 21:
			var cell := Vector2i(x, y)
			var expected := "ground_no_deploy" if x == 10 else ("high" if cell in high_cells else "ground")
			var terrain := ARENA.terrain_at(cell)
			_expect(terrain == expected, "Terrain at %s: expected=%s actual=%s" % [cell, expected, terrain])
			_expect(terrain == ARENA.terrain_at(Vector2i(20 - x, y)) and terrain == ARENA.terrain_at(Vector2i(x, 10 - y)), "Map mirror mismatch at %s" % cell)
			high_count += int(terrain == "high")
			no_deploy_count += int(terrain == "ground_no_deploy")
	_expect(high_count == 20 and no_deploy_count == 11, "Map counts: high=%d no_deploy=%d" % [high_count, no_deploy_count])
	var ground := load("res://resources/operators/bagpipe.tres") as OperatorData
	var high := load("res://resources/operators/exusiai.tres") as OperatorData
	var both := ground.duplicate(true) as OperatorData
	both.terrain_requirement = "both"
	both.ignore_deploy_line = true
	var empty: Array[UnitState] = []
	var custom := ARENA.duplicate(true) as ArenaData
	custom.terrain_rows[5] = custom.terrain_rows[5].substr(0, 12) + "." + custom.terrain_rows[5].substr(13)
	for side in 2:
		var side_state := SideState.new(side)
		side_state.cost = 99
		for operator in [ground, high, both]:
			_expect(not DeployRules.is_legal(side, operator, Vector2i(10, 5), Vector2i(10, 5), empty, side_state, ARENA), "Side %d allowed deployment on center strip: %s" % [side, operator.terrain_requirement])
			_expect(not DeployRules.is_legal(side, operator, Vector2i(12, 5), Vector2i(10, 5), empty, side_state, custom), "Side %d allowed void deployment: %s" % [side, operator.terrain_requirement])
		var ground_cell := Vector2i(11 if side == 0 else 9, 5)
		var high_cell := Vector2i(14 if side == 0 else 6, 4)
		_expect(DeployRules.is_legal(side, ground, ground_cell, Vector2i(10, 5), empty, side_state, ARENA), "Side %d rejected valid ground" % side)
		_expect(DeployRules.is_legal(side, high, high_cell, Vector2i(10, 5), empty, side_state, ARENA), "Side %d rejected valid high" % side)
		_expect(not DeployRules.is_legal(side, ground, high_cell, Vector2i(10, 5), empty, side_state, ARENA), "Side %d allowed ground operator on high" % side)
		_expect(not DeployRules.is_legal(side, high, ground_cell, Vector2i(10, 5), empty, side_state, ARENA), "Side %d allowed high operator on ground" % side)
		_expect(DeployRules.is_legal(side, both, ground_cell, Vector2i(10, 5), empty, side_state, ARENA) and DeployRules.is_legal(side, both, high_cell, Vector2i(10, 5), empty, side_state, ARENA), "Side %d rejected both operator on deployable terrain" % side)
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var start: Vector2i = Vector2i(10, 5) - direction
		var state := MatchState.new(91, {}, BALL_DATA, ARENA)
		var replay := MatchState.new(91, {}, BALL_DATA, ARENA)
		state.ball.cell = start
		replay.ball.cell = start
		state.ball.add_push(start - direction, BALL_DATA.kick_threshold, BALL_DATA)
		replay.ball.add_push(start - direction, BALL_DATA.kick_threshold, BALL_DATA)
		_expect(not state.ball_move_is_blocked(), "Center strip blocks movement %s" % direction)
		for move_tick in 8:
			state.step([], [])
			replay.step([], [])
			_expect(state.state_hash() == replay.state_hash(), "Movement replay mismatch: direction=%s tick=%d" % [direction, move_tick])
		_expect(state.ball.cell == Vector2i(10, 5), "Ball failed to enter center strip from %s" % start)
		state.ball.add_push(state.ball.cell - direction, BALL_DATA.kick_threshold, BALL_DATA)
		for move_tick in 8:
			state.step([], [])
		_expect(state.ball.cell == Vector2i(10, 5) + direction, "Ball failed to exit center strip: %s" % direction)
		var target := Vector2i(14, 4)
		for blocked_arena in [ARENA, custom]:
			if blocked_arena == custom:
				target = Vector2i(12, 5)
			var blocked := MatchState.new(91, {}, BALL_DATA, blocked_arena)
			blocked.ball.cell = target - direction
			blocked.ball.add_push(blocked.ball.cell - direction, BALL_DATA.kick_threshold, BALL_DATA)
			_expect(blocked.ball_move_is_blocked(), "Terrain failed to block: target=%s direction=%s" % [target, direction])
			for move_tick in 8:
				blocked.step([], [])
			_expect(blocked.ball.cell == target - direction and blocked.ball.move_ticks_left == 0 and blocked.ball.accum == Vector2i.ZERO, "Blocked movement did not stop/reset: target=%s direction=%s" % [target, direction])
	print("Arena: 20 high cells, fixed no-deploy center, deployment and four-way terrain movement; failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
