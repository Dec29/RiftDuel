extends SceneTree

const CONFIG := preload("res://data/config.gd")
const RANGE := preload("res://sim/attack_range.gd")
var failures := 0
var data := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id in ["blaze", "bagpipe", "hoshiguma", "nightingale", "phantom", "saileach", "angelina"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	_test_crane()
	_test_platform()
	_test_platform_collision()
	_test_windup()
	_test_stun()
	_test_resistance()
	_test_codec()
	_test_replay()
	_test_ai()
	print("Tactical items: crane/refund/cooldown5, platform/deployment/ball, windup1/blocking/current targets, stun12/timers/resistance6, strict codec9, replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _unit(id: int, side: int, op: String, cell: Vector2i, facing: int = 0) -> UnitState:
	var operator: OperatorData = MatchState.CLONE_DATA if op == "phantom_clone" else data[op]
	return UnitState.new(id, side, op, cell, operator.max_health, 0, 1, facing)


func _use(state: MatchState, kind: int, cell: Vector2i, facing: int = -1, side: int = 0) -> void:
	var commands: Array[InputCommand] = [InputCommand.new(state.tick, InputCommand.Kind.USE_ITEM, "", -1, cell, -1, facing, kind)]
	var empty: Array[InputCommand] = []
	state.step(commands if side == 0 else empty, commands if side == 1 else empty)


func _test_crane() -> void:
	for facing in 4:
		var state := MatchState.new(101, data)
		state.ball.cell = Vector2i(10, 0)
		state.sides[0].cost = 20
		state.sides[0].tactical_items = [2, 0, 0, 0]
		var cell := Vector2i(12, 5)
		var target := cell + RANGE.rotate_offset(Vector2i.RIGHT, facing)
		state.units.append(_unit(0, 0, "blaze", target))
		_expect(state.can_use_item(0, 0, cell, facing), "Crane points at adjacent own operator facing%d" % facing)
		_use(state, 0, cell, facing)
		_expect(state.units.is_empty() and state.sides[0].tactical_items[0] == 1 and state.sides[0].cost == 20 + roundi(data["blaze"].deploy_cost * 0.5) and state.sides[0].cooldowns["blaze"] == 150, "Crane consumes once, normal refund, fixed150 cooldown")
		for elapsed in 148:
			state.step([], [])
		state.step([InputCommand.new(state.tick, 0, "blaze", -1, target)], [])
		_expect(state.units.is_empty(), "Crane redeployment rejected before5 seconds")
		state.sides[0].cost = 99
		var deploy_tick := state.tick
		state.step([InputCommand.new(state.tick, 0, "blaze", -1, target)], [])
		_expect(state.units.size() == 1 and state.units[0].deployed_tick == deploy_tick, "Crane redeployment allowed at5 seconds and warmup resets")
	var invalid := MatchState.new(102, data)
	invalid.sides[0].tactical_items[0] = 3
	invalid.units = [_unit(0, 1, "blaze", Vector2i(12, 5)), _unit(1, 0, "phantom_clone", Vector2i(13, 6))]
	for cell in [Vector2i(11, 5), Vector2i(12, 6), Vector2i(12, 4)]:
		_use(invalid, 0, cell, 0)
	_expect(invalid.units.size() == 2 and invalid.sides[0].tactical_items[0] == 3, "Crane cannot target enemy, summon, empty or non-facing cell")


func _test_platform() -> void:
	var state := MatchState.new(103, data)
	state.sides[0].cost = 99
	state.sides[0].tactical_items[1] = 3
	var cell := Vector2i(12, 5)
	_use(state, 1, cell)
	_expect(state.platform_cells == [cell] and state.terrain_at(cell) == "high" and MatchState.DEFAULT_ARENA.terrain_at(cell) == "ground", "Platform changes match overlay, never map resource")
	_expect(state.can_deploy(0, "nightingale", cell) and not state.can_deploy(0, "bagpipe", cell), "Converted tile allows high operator and rejects ground-only operator")
	state.ball.cell = Vector2i(11, 5)
	state.ball.move_direction = Vector2i.RIGHT
	state.ball.move_ticks_left = 1
	_expect(state.ball_move_is_blocked(), "Constructed platform blocks ball immediately")
	state.step([], [])
	_expect(state.ball.cell == Vector2i(11, 5), "Ball actually rebounds from constructed platform")
	state.ball.cell = Vector2i(10, 5)
	for forbidden in [cell, Vector2i(12, 2), Vector2i(10, 3), Vector2i(9, 5), Vector2i(-1, 5)]:
		_use(state, 1, forbidden)
	_expect(state.sides[0].tactical_items[1] == 2 and state.platform_cells.size() == 1, "High/midline/enemy area/outside/repeated platform attempts consume nothing")
	state.box_warning_cell = Vector2i(11, 5)
	_use(state, 1, Vector2i(11, 5))
	_expect(state.sides[0].tactical_items[1] == 2, "Warning reservation rejects item too")
	state.box_warning_cell = Vector2i(-1, -1)
	state.tactical_boxes.append(TacticalBox.new(0, Vector2i(11, 5), 3))
	_use(state, 1, Vector2i(11, 5))
	_expect(state.sides[0].tactical_items[1] == 2, "Box rejects item")
	var before := state.state_hash()
	state.platform_cells.append(Vector2i(13, 5))
	_expect(state.state_hash() != before, "Platform overlay participates in hash")


func _test_platform_collision() -> void:
	for side in 2:
		for facing in 4:
			var state := MatchState.new(120, data)
			var replay := MatchState.new(120, data)
			var cell := Vector2i(12 if side == 0 else 8, 5)
			var direction := RANGE.rotate_offset(Vector2i.RIGHT, facing)
			for match_state: MatchState in [state, replay]:
				match_state.sides[side].tactical_items[1] = 1
				_use(match_state, 1, cell, -1, side)
			for elapsed in CONFIG.ITEM_FEEDBACK_TICKS:
				state.step([], [])
				replay.step([], [])
			_expect(state.tactical_item_effects.is_empty(), "Platform feedback expires before permanent collision check")
			for occupied in 2:
				for match_state: MatchState in [state, replay]:
					if occupied == 1:
						match_state.ball.cell = CONFIG.BALL_START_CELL
						match_state.sides[side].cost = 99
						var deploy: Array[InputCommand] = [InputCommand.new(match_state.tick, 0, "nightingale", -1, cell)]
						var empty: Array[InputCommand] = []
						match_state.step(deploy if side == 0 else empty, deploy if side == 1 else empty)
						_expect(match_state.units.size() == 1, "High operator deploys on blocking platform")
					match_state.ball.cell = cell - direction
					match_state.ball.add_push(cell - direction * 2, 100000, match_state._ball_data)
				var origin := cell - direction
				for elapsed in CONFIG.BALL_MOVE_TICKS:
					var before := state.state_hash()
					_expect(state.ball_move_is_blocked(), "Platform blocks every moving tick side%d facing%d occupied%d" % [side, facing, occupied])
					_expect(state.state_hash() == before, "Collision query remains read-only")
					state.step([], [])
					replay.step([], [])
					_expect(state.state_hash() == replay.state_hash() and state.ball.cell == origin, "Platform rebound preserves origin and deterministic replay")
				_expect(state.ball.move_ticks_left == 0 and state.ball.move_direction == Vector2i.ZERO, "Blocked move ends at exact8tick boundary")
	var open := MatchState.new(121, data)
	open.sides[0].tactical_items[1] = 1
	_use(open, 1, Vector2i(12, 5))
	for destination in [Vector2i(12, 6), Vector2i(10, 5)]:
		open.ball.cell = destination - Vector2i.RIGHT
		open.ball.move_direction = Vector2i.RIGHT
		open.ball.move_ticks_left = 1
		_expect(not open.ball_move_is_blocked(), "Adjacent ground and nondeployable middle remain passable")
		open.step([], [])
		_expect(open.ball.cell == destination, "Passable tile accepts actual movement")


func _wait_for_blast(state: MatchState) -> void:
	for elapsed in CONFIG.ITEM_STUN_WINDUP_TICKS:
		state.step([], [])


func _test_windup() -> void:
	var state := MatchState.new(119, data)
	state.sides[0].tactical_items[2] = 2
	state.sides[1].cost = 99
	state.units.append(_unit(0, 1, "bagpipe", Vector2i(7, 5)))
	state.units[0].attack_ticks_left = 100
	state.next_unit_id = 1
	var cell := Vector2i(8, 5)
	_use(state, 2, cell)
	_expect(state.sides[0].tactical_items[2] == 1 and state.item_reserves_cell(cell) and state.units[0].stun_ticks_left == 0, "Placement consumes immediately, reserves cell, no early stun")
	_use(state, 2, cell)
	_expect(state.sides[0].tactical_items[2] == 1 and state.tactical_item_effects.size() == 1, "Repeated placement on pending cell consumes nothing")
	_expect(not state.can_deploy(1, "bagpipe", cell) and not state.can_use_item(0, 2, cell) and not TacticalRules.box_cell_is_available(state, cell), "Pending bomb rejects operators, another item and box spawn")
	var before := state.state_hash()
	state.tactical_item_effects[0].effect_tick += 1
	_expect(state.state_hash() != before, "Pending detonation schedule participates in hash")
	state.tactical_item_effects[0].effect_tick -= 1
	state.ball.cell = Vector2i(9, 5)
	state.ball.move_direction = Vector2i.LEFT
	state.ball.move_ticks_left = 1
	_expect(state.ball_move_is_blocked(), "Bomb blocks ball during one-second windup")
	state.step([], [InputCommand.new(state.tick, InputCommand.Kind.RETREAT, "", 0)])
	_expect(state.ball.cell == Vector2i(9, 5) and state.units.is_empty(), "Ball actually rebounds; previous adjacent target retreats before blast")
	state.ball.cell = Vector2i(10, 0)
	state.step([], [InputCommand.new(state.tick, InputCommand.Kind.DEPLOY, "hoshiguma", -1, Vector2i(9, 5))])
	while state.tick < CONFIG.ITEM_STUN_WINDUP_TICKS:
		state.step([], [])
	_expect(state.item_reserves_cell(cell) and state.units[0].stun_ticks_left == 0, "All 30 pre-blast ticks retain occupancy and no stun")
	state.step([], [])
	_expect(not state.item_reserves_cell(cell) and state.units[0].operator_id == "hoshiguma" and state.units[0].stun_ticks_left == 360, "Exact blast tick stuns newly present adjacent enemy and frees cell")
	state.ball.cell = Vector2i(9, 5)
	state.ball.move_direction = Vector2i.LEFT
	state.ball.move_ticks_left = 1
	_expect(not state.ball_move_is_blocked(), "Explosion frees ball passage even while visual feedback remains")
	state.ball.move_ticks_left = 0
	for elapsed in CONFIG.ITEM_FEEDBACK_TICKS:
		state.step([], [])
	_expect(state.tactical_item_effects.is_empty(), "Expired feedback removed; no unbounded event history")
	_use(state, 2, cell)
	state.result = MatchState.RESULT_DRAW
	before = state.state_hash()
	state.step([], [])
	_expect(state.state_hash() == before, "Result freezes pending detonation and feedback state")


func _test_stun() -> void:
	var state := MatchState.new(104, data)
	state.ball.cell = Vector2i(10, 0)
	state.sides[0].tactical_items[2] = 2
	state.platform_cells.append(Vector2i(8, 4))
	state.units = [_unit(0, 1, "bagpipe", Vector2i(7, 5), 3), _unit(1, 1, "hoshiguma", Vector2i(9, 5)), _unit(2, 1, "nightingale", Vector2i(8, 4)), _unit(3, 1, "phantom_clone", Vector2i(8, 6)), _unit(4, 0, "bagpipe", Vector2i(7, 4), 3), _unit(5, 1, "blaze", Vector2i(9, 6))]
	for unit in state.units:
		unit.attack_ticks_left = 60
	state.units[1].hp -= 100
	state.units[0].sp = data["bagpipe"].skills[0].sp_required
	_use(state, 2, Vector2i(8, 5))
	_wait_for_blast(state)
	for index in 4:
		_expect(state.units[index].stun_ticks_left == 360 and state.units[index].last_attack_tick == -1, "Cross enemy index%d stunned for360 ticks, no attack or heal" % index)
	_expect(state.units[4].stun_ticks_left == 0 and state.units[5].stun_ticks_left == 0 and state.sides[0].tactical_items[2] == 1, "Allies and diagonal enemies unaffected; enemy area placement consumes once")
	state.ball.cell = Vector2i(8, 5)
	state.ball.move_direction = Vector2i.RIGHT
	state.ball.move_ticks_left = 2
	_expect(not state.ball_move_is_blocked() and SkillRules.block_count_value(state.units[1], data["hoshiguma"]) == 0, "Stunned blocker stops blocking ball")
	state.ball.cell = Vector2i(10, 0)
	state.ball.move_ticks_left = 0
	state.ball.move_direction = Vector2i.ZERO
	var manual: Array[InputCommand] = [InputCommand.new(state.tick, 1, "", 0, Vector2i.ZERO, 0)]
	state.step([], manual)
	_expect(state.units[0].skill_ticks_left == 0 and state.units[0].sp >= data["bagpipe"].skills[0].sp_required, "Stun prevents manual skill without spending SP")
	for elapsed in 358:
		state.step([], [])
	_expect(state.units[0].stun_ticks_left == 1 and state.units[0].last_attack_tick == -1 and state.units[2].last_attack_tick == -1, "Attacks and healing attacks remain stopped through final stun tick")
	state.step([], [])
	_expect(state.units[0].stun_ticks_left == 0 and state.units[0].attack_started_tick == 390 and SkillRules.block_count_value(state.units[1], data["hoshiguma"]) == 3, "Attack start and blocking resume at exact12-second boundary; release follows windup")
	var timers := MatchState.new(105, data)
	timers.sides[0].tactical_items[2] = 1
	timers.units.append(_unit(0, 1, "saileach", Vector2i(8, 5)))
	timers.units[0].skill_ticks_left = 240
	timers.units[0].attack_ticks_left = 30
	_use(timers, 2, Vector2i(9, 5))
	_wait_for_blast(timers)
	for elapsed in 29:
		timers.step([], [])
	_expect(timers.units[0].skill_ticks_left == 180 and timers.units[0].stun_ticks_left == 331 and timers.sides[1].cost > 10, "Active skill and income timers continue while stunned")


func _test_resistance() -> void:
	var state := MatchState.new(106, data)
	state.tick = 419
	state.next_box_spawn_tick = 12000
	state.sides[0].tactical_items[2] = 3
	state.units.append(_unit(0, 1, "blaze", Vector2i(8, 5)))
	_use(state, 2, Vector2i(9, 5))
	_wait_for_blast(state)
	_expect(state.units[0].stun_ticks_left == 360, "Blaze before15-second warmup gets12-second stun")
	state.step([], [])
	_expect(state.units[0].stun_ticks_left == 359, "Warmup completion does not shorten already applied stun")
	_use(state, 2, Vector2i(9, 5))
	_wait_for_blast(state)
	_expect(state.units[0].stun_ticks_left == 180, "Warmup complete: newly applied stun shortened to6 seconds")
	for elapsed in 30:
		state.step([], [])
	_use(state, 2, Vector2i(9, 5))
	_wait_for_blast(state)
	_expect(state.units[0].stun_ticks_left == 180, "Repeated stun refreshes adapted duration without stacking")
	for elapsed in 179:
		state.step([], [])
	_expect(state.units[0].stun_ticks_left == 1, "Resisted stun retains last active tick")
	state.step([], [])
	_expect(state.units[0].stun_ticks_left == 0, "Resisted stun ends exactly180 ticks later")
	var before := state.state_hash()
	state.units[0].deployed_tick += 1
	_expect(state.state_hash() != before, "Deployment warmup origin participates in hash")
	before = state.state_hash()
	state.units[0].stun_ticks_left = 1
	_expect(state.state_hash() != before, "Stun timer participates in hash")


func _test_codec() -> void:
	var commands: Array[InputCommand] = []
	for kind in 3:
		commands.append(InputCommand.new(12, 3, "", -1, Vector2i(12, 5), -1, 2 if kind == 0 else -1, kind))
	var decoded := CommandCodec.decode(JSON.parse_string(JSON.stringify(CommandCodec.encode(commands))), 12, Engine.get_main_loop().root.get_node("OperatorDB").network_content()["ids"])
	_expect(decoded.has("commands") and decoded.commands.size() == 3 and decoded.commands[0].item_kind == 0 and decoded.commands[1].item_kind == 1 and decoded.commands[2].item_kind == 2, "All items roundtrip through nine-field codec")
	for row: Array in [[12, 3, "", -1, 12, 5, -1, -1, 0], [12, 3, "", -1, 12, 5, -1, 0, 1], [12, 3, "", -1, 12, 5, -1, -1, 4], [12, 3, "bagpipe", -1, 12, 5, -1, 0, 0], [12, 3, "", 0, 12, 5, -1, 0, 0], [12, 3, "", -1, 21, 5, -1, 0, 0], [12, 3, "", -1, 12, 5, 0, 0, 0], [12, 0, "bagpipe", -1, 12, 5, -1, 0, 0], [12, 3, "", -1, 12, 5, -1, 0, 0.5], [12, 0, "bagpipe", -1, 12, 5, -1, 0]]:
		_expect(CommandCodec.decode([row], 12, Engine.get_main_loop().root.get_node("OperatorDB").network_content()["ids"]).has("error"), "Invalid tactical command must reject: %s" % [row])


func _test_replay() -> void:
	var first := MatchState.new(107, data)
	var second := MatchState.new(107, data)
	for state: MatchState in [first, second]:
		state.sides[0].cost = 99
		state.sides[1].cost = 99
		state.sides[0].tactical_items = [1, 1, 1, 0]
		state.sides[1].tactical_items = [0, 0, 1, 0]
	for tick in 900:
		var blue: Array[InputCommand] = []
		var red: Array[InputCommand] = []
		if tick == 0:
			blue = [InputCommand.new(tick, 0, "blaze", -1, Vector2i(11, 5), -1, 2)]
			red = [InputCommand.new(tick, 0, "hoshiguma", -1, Vector2i(9, 5), -1, 0)]
		if tick == 1: blue = [InputCommand.new(tick, 3, "", -1, Vector2i(12, 5), -1, 2, 0)]
		if tick == 2: blue = [InputCommand.new(tick, 3, "", -1, Vector2i(12, 5), -1, -1, 1)]
		if tick == 3: blue = [InputCommand.new(tick, 0, "nightingale", -1, Vector2i(12, 5))]
		if tick == 4: blue = [InputCommand.new(tick, 3, "", -1, Vector2i(8, 5), -1, -1, 2)]
		if tick == 151: blue = [InputCommand.new(tick, 0, "blaze", -1, Vector2i(11, 5))]
		if tick == 160: red = [InputCommand.new(tick, 3, "", -1, Vector2i(12, 4), -1, -1, 2)]
		var encoded := CommandCodec.decode(CommandCodec.encode(blue), tick, Engine.get_main_loop().root.get_node("OperatorDB").network_content()["ids"])
		_expect(encoded.has("commands"), "Replay command uses strict wire format")
		first.step(blue, red)
		second.step(encoded.commands, red)
		_expect(first.state_hash() == second.state_hash(), "Tactical item replay diverged tick%d" % tick)
	_expect(first.platform_cells == [Vector2i(12, 5)] and first.sides[0].tactical_items == [0, 0, 0, 0] and first.sides[1].tactical_items == [0, 0, 0, 0], "Replay actually consumes all three kinds on both sides")


func _test_ai() -> void:
	for kind in 3:
		var ai_data := {"blaze": data["blaze"]}
		var arena := MatchState.DEFAULT_ARENA
		if kind == 1:
			ai_data = {"nightingale": data["nightingale"]}
			arena = ArenaData.new()
			for row in CONFIG.GRID_ROWS:
				arena.terrain_rows.append("ggggggggggngggggggggg")
		var state := MatchState.new(118, data, MatchState.DEFAULT_BALL_DATA, arena)
		state.sides[0].tactical_items[kind] = 1
		state.sides[0].cost = 99 if kind == 1 else 0
		if kind == 0:
			state.units.append(_unit(0, 0, "blaze", Vector2i(12, 1)))
		if kind == 2:
			state.units.append(_unit(0, 1, "bagpipe", Vector2i(8, 5)))
		var before := state.state_hash()
		var ai := AIInput.new(0, ai_data)
		while state.tick < Config.AI_DECISION_INTERVAL_TICKS:
			_expect(ai.commands_for_tick(state).is_empty(), "Item AI waits for decision interval")
			state.step([], [])
		before = state.state_hash()
		var commands := ai.commands_for_tick(state)
		_expect(commands.size() == 1 and commands[0].kind == InputCommand.Kind.USE_ITEM and commands[0].item_kind == kind and state.state_hash() == before, "AI kind%d emits intent only" % kind)
		state.step(commands, [])
		_expect(state.sides[0].tactical_items[kind] == 0, "AI kind%d chooses a legal item target" % kind)
