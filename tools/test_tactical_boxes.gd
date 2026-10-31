extends SceneTree

const CONFIG := preload("res://data/config.gd")
const RANGE := preload("res://sim/attack_range.gd")
var failures := 0
var data := {}


func _initialize() -> void:
	for id in ["bagpipe", "exusiai", "horn", "nightingale", "phantom", "hoshiguma"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	if "--loot" not in OS.get_cmdline_user_args(): _test_attacks()
	_test_schedule()
	_test_deployment_and_ball()
	_test_loot_limit()
	_test_hash()
	_test_combat_replay()
	print("Tactical boxes: ", "loot/schedule/deployment/ball/hash/replay only" if "--loot" in OS.get_cmdline_user_args() else "attack actions/targeting/third-hit ownership plus loot/schedule/deployment/ball/hash/replay", "; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _test_schedule() -> void:
	var first := MatchState.new(91, data)
	var second := MatchState.new(91, data)
	var last_spawn := 0
	var next_spawn := CONFIG.BOX_FIRST_SPAWN_TICKS
	for elapsed in range(1, CONFIG.MATCH_TICKS + CONFIG.OVERTIME_TICKS + 1):
		first.step([], [])
		second.step([], [])
		_expect(first.state_hash() == second.state_hash(), "Box replay diverged at tick%d" % elapsed)
		if elapsed == 1649:
			_expect(first.box_warning_cell == Vector2i(-1, -1) and first.tactical_boxes.is_empty(), "No box or warning before55 seconds")
		if elapsed == next_spawn - CONFIG.BOX_WARNING_TICKS:
			_expect(first.box_warning_cell.x >= 0 and TacticalRules.box_cell_is_available(first, first.box_warning_cell), "Warning begins exactly5 seconds before scheduled spawn")
		if elapsed == 1799:
			_expect(first.tactical_boxes.is_empty(), "First box is absent before60 seconds")
		if first.next_box_id > last_spawn:
			_expect(elapsed == next_spawn and first.box_warning_cell.x < 0, "Spawn at scheduled tick and clear warning")
			var box: TacticalBox = first.tactical_boxes.back()
			_expect(box.box_id == last_spawn and box.cell.x != 10 and MatchState.DEFAULT_ARENA.terrain_at(box.cell) == "ground" and box.cell != first.ball.cell, "Spawn only on empty ground outside fixed midline")
			var interval := first.next_box_spawn_tick - elapsed
			_expect(interval >= CONFIG.BOX_INTERVAL_MIN_TICKS and interval <= CONFIG.BOX_INTERVAL_MAX_TICKS and interval % CONFIG.TICK_RATE == 0, "Next interval is an integer40–70 seconds")
			next_spawn = first.next_box_spawn_tick
			last_spawn = first.next_box_id
	var minimum_boxes := (CONFIG.MATCH_TICKS + CONFIG.OVERTIME_TICKS - CONFIG.BOX_FIRST_SPAWN_TICKS) / CONFIG.BOX_INTERVAL_MAX_TICKS + 1
	_expect(first.result == MatchState.RESULT_DRAW and last_spawn >= minimum_boxes, "Multiple boxes coexist during full six active real minutes at slow combat pace")
	var frozen := first.state_hash()
	first.step([], [])
	_expect(first.state_hash() == frozen, "Finished match freezes spawn state")
	var delayed := MatchState.new(92, data)
	delayed.tick = 1649
	delayed.step([], [])
	var reserved := delayed.box_warning_cell
	delayed.ball.cell = reserved
	delayed.tick = 1799
	delayed.step([], [])
	_expect(delayed.tactical_boxes.is_empty() and delayed.box_warning_cell == reserved, "Ball occupies warning: preserve warning and delay box")
	delayed.ball.cell = Vector2i(10, 5)
	delayed.step([], [])
	_expect(delayed.tactical_boxes.size() == 1 and delayed.tactical_boxes[0].cell == reserved and delayed.next_box_spawn_tick - delayed.tick >= CONFIG.BOX_INTERVAL_MIN_TICKS, "Delayed box lands on original tile and interval starts at actual landing")
	var scarce := MatchState.new(93, data)
	for row in CONFIG.GRID_ROWS:
		for column in CONFIG.GRID_COLUMNS:
			var cell := Vector2i(column, row)
			if TacticalRules.box_cell_is_available(scarce, cell) and cell != Vector2i(11, 5):
				scarce.tactical_boxes.append(TacticalBox.new(scarce.next_box_id, cell, 3))
				scarce.next_box_id += 1
	scarce.tick = 1649
	scarce.step([], [])
	_expect(scarce.box_warning_cell == Vector2i(11, 5), "Single candidate is selected")
	scarce.box_warning_cell = Vector2i(-1, -1)
	scarce.tactical_boxes.append(TacticalBox.new(scarce.next_box_id, Vector2i(11, 5), 3))
	scarce.tick = 1799
	var rng_before := scarce.rng.state
	scarce.step([], [])
	_expect(scarce.box_warning_cell.x < 0 and scarce.rng.state == rng_before, "No candidate: no box and no modulo-zero/random draw")
	scarce.tactical_boxes.pop_back()
	scarce.step([], [])
	_expect(scarce.box_warning_cell == Vector2i(11, 5) and scarce.next_box_spawn_tick == scarce.tick + CONFIG.BOX_WARNING_TICKS, "Newly vacant tile still receives full5-second warning")


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _fighter(id: int, side: int, op: String, cell: Vector2i, facing: int = 0) -> UnitState:
	var operator: OperatorData = MatchState.CLONE_DATA if op == "phantom_clone" else data[op]
	return UnitState.new(id, side, op, cell, operator.max_health, 0, 1, facing)


func _test_attacks() -> void:
	for op in ["bagpipe", "exusiai", "horn", "phantom_clone"]:
		for facing in 4:
			var state := MatchState.new(41, data)
			var unit := _fighter(0, 0, op, Vector2i(12, 5), facing)
			state.units.append(unit)
			var operator: OperatorData = state._operator_data[op]
			var offset := operator.attack_range[0]
			if offset == Vector2i.ZERO:
				offset = operator.attack_range[1]
			var target := unit.cell + RANGE.rotate_offset(offset, facing)
			state.tactical_boxes.append(TacticalBox.new(0, target, 3))
			state.ball.cell = Vector2i(10, 0)
			unit.sp = SkillRules.sp_limit(operator.skills[0])
			if op == "exusiai":
				unit.skill_ticks_left = 10
			for action in 3:
				unit.attack_ticks_left = 1
				state.step([], [])
				_expect(state.tactical_boxes.size() == (0 if op == "exusiai" or action == 2 else 1), "%s facing%d action%d: each direct shot counts" % [op, facing, action])
				if op != "exusiai" and action < 2:
					_expect(state.tactical_boxes[0].hits_left == 2 - action, "Single shot counts once; splash does not add hits")
			_expect(state.sides[0].tactical_items.reduce(func(a: int, b: int) -> int: return a + b, 0) == 1, "Third action gives one item")
			_expect(state.sides[1].tactical_items == [0, 0, 0, 0], "Opponent receives nothing")
	var priority := MatchState.new(42, data)
	priority.units = [_fighter(0, 0, "bagpipe", Vector2i(12, 5)), _fighter(1, 1, "hoshiguma", Vector2i(13, 5), 2)]
	priority.units[1].attack_ticks_left = 1000
	priority.tactical_boxes.append(TacticalBox.new(0, Vector2i(12, 5), 3))
	priority.ball.cell = Vector2i(12, 5)
	priority.step([], [])
	_expect(priority.tactical_boxes[0].hits_left == 3 and priority.units[1].hp < data["hoshiguma"].max_health, "Enemy takes priority over box and ball")
	priority.units.remove_at(1)
	priority.units[0].attack_ticks_left = 1
	priority.step([], [])
	_expect(priority.tactical_boxes[0].hits_left == 2 and priority.ball.accum == Vector2i.ZERO, "Box takes priority over ball")
	var contested := MatchState.new(43, data)
	contested.units = [_fighter(0, 0, "bagpipe", Vector2i(11, 5)), _fighter(1, 1, "bagpipe", Vector2i(13, 5), 2)]
	contested.ball.cell = Vector2i(10, 0)
	contested.tactical_boxes.append(TacticalBox.new(0, Vector2i(12, 5), 1))
	contested.step([], [])
	_expect(contested.tactical_boxes.is_empty() and contested.sides[0].tactical_items.reduce(func(a: int, b: int) -> int: return a + b, 0) == 1 and contested.sides[1].tactical_items == [0, 0, 0, 0], "Same tick final hit resolves in ascending unit id")
	var healing := MatchState.new(44, data)
	healing.units.append(_fighter(0, 0, "nightingale", Vector2i(12, 5)))
	healing.tactical_boxes.append(TacticalBox.new(0, Vector2i(13, 5), 3))
	healing.step([], [])
	_expect(healing.tactical_boxes[0].hits_left == 3, "Healing attacks do not break boxes")
	var splash := MatchState.new(45, data)
	splash.units = [_fighter(0, 0, "horn", Vector2i(12, 5)), _fighter(1, 1, "hoshiguma", Vector2i(15, 5))]
	splash.units[1].attack_ticks_left = 1000
	splash.tactical_boxes.append(TacticalBox.new(0, Vector2i(15, 6), 3))
	splash.ball.cell = Vector2i(10, 0)
	splash.step([], [])
	_expect(splash.tactical_boxes[0].hits_left == 3, "Fortress splash does not add a box hit")


func _test_deployment_and_ball() -> void:
	var state := MatchState.new(46, data)
	state.sides[0].cost = 99
	state.box_warning_cell = Vector2i(11, 5)
	_expect(not state.can_deploy(0, "bagpipe", state.box_warning_cell), "Warning reserves ground for ordinary deployment")
	state.step([InputCommand.new(state.tick, InputCommand.Kind.DEPLOY, "bagpipe", -1, state.box_warning_cell)], [])
	_expect(state.units.is_empty() and state.sides[0].cost == 99, "Reserved deployment has no cost or unit")
	state.units = [_fighter(0, 0, "nightingale", Vector2i(12, 2)), _fighter(1, 0, "phantom", Vector2i(12, 5))]
	state.sides[0].phantom_count = 1
	_expect(not state.phantom_can_deploy(0, Vector2i(11, 5)) and not state.clone_can_deploy(0, Vector2i(11, 5)), "Warning also reserves summon deployment")
	state.box_warning_cell = Vector2i(-1, -1)
	state.tactical_boxes.append(TacticalBox.new(0, Vector2i(11, 5), 3))
	_expect(not state.can_deploy(0, "bagpipe", Vector2i(11, 5)) and not state.phantom_can_deploy(0, Vector2i(11, 5)) and not state.clone_can_deploy(0, Vector2i(11, 5)), "Box blocks all deployments")
	state.units.clear()
	state.ball.move_direction = Vector2i.RIGHT
	state.ball.move_ticks_left = 1
	_expect(state.ball_move_is_blocked(), "Box blocks ball target")
	state.step([], [])
	_expect(state.ball.cell == Vector2i(10, 5) and state.ball.move_ticks_left == 0, "Ball settles with no overlap")
	state.tactical_boxes.clear()
	state.ball.move_direction = Vector2i.RIGHT
	state.ball.move_ticks_left = 1
	state.step([], [])
	_expect(state.ball.cell == Vector2i(11, 5), "Removing box reopens ball path")


func _test_loot_limit() -> void:
	var platforms := 0
	for seed in range(1, 100):
		var state := MatchState.new(seed, data)
		state.platform_drop_count = CONFIG.PLATFORM_DROP_LIMIT - 1
		state.units.append(_fighter(0, 0, "bagpipe", Vector2i(11, 5)))
		state.ball.cell = Vector2i(10, 0)
		for drop in 30:
			state.tactical_boxes.append(TacticalBox.new(drop, Vector2i(12, 5), 1))
			state.units[0].attack_ticks_left = 1
			state.step([], [])
		_expect(state.sides[0].tactical_items[CONFIG.TACTICAL_ITEM_PLATFORM] <= 1 and state.platform_drop_count <= 3, "Platform drops stop at global cap across future boxes")
		platforms += state.sides[0].tactical_items[CONFIG.TACTICAL_ITEM_PLATFORM]
	_expect(platforms > 0, "Platform is still eligible below cap")


func _test_hash() -> void:
	var state := MatchState.new(48, data)
	var before := state.state_hash()
	state.sides[0].tactical_items[0] += 1
	_expect(state.state_hash() != before, "Inventory participates in hash")
	before = state.state_hash()
	state.platform_drop_count += 1
	_expect(state.state_hash() != before, "Drop cap participates in hash")
	before = state.state_hash()
	state.box_warning_cell = Vector2i(11, 5)
	_expect(state.state_hash() != before, "Warning cell participates in hash")
	state.tactical_boxes.append(TacticalBox.new(0, Vector2i(12, 5), 3))
	before = state.state_hash()
	state.tactical_boxes[0].hits_left -= 1
	_expect(state.state_hash() != before, "Box hit count participates in hash")


func _test_combat_replay() -> void:
	for seed in range(1, 10):
		var first := MatchState.new(seed, data)
		var second := MatchState.new(seed, data)
		for state in [first, second]:
			state.tick = 1800
			state.next_box_spawn_tick = 12000
			state.ball.cell = Vector2i(12, 0)
			state.sides[0].cost = 99
			state.sides[1].cost = 99
			state.platform_drop_count = 2
		var opened := 0
		for frame in 1400:
			var blue: Array[InputCommand] = []
			var red: Array[InputCommand] = []
			if frame == 0:
				red.append(InputCommand.new(first.tick, InputCommand.Kind.DEPLOY, "bagpipe", -1, Vector2i(11, 5), -1, 0))
			if frame == 1:
				blue.append(InputCommand.new(first.tick, InputCommand.Kind.DEPLOY, "bagpipe", -1, Vector2i(13, 5), -1, 2))
			if frame % 100 == 2:
				for state in [first, second]:
					state.tactical_boxes.append(TacticalBox.new(opened, Vector2i(12, 5), 3))
					state.next_box_id += 1
				opened += 1
			first.step(blue, red)
			second.step(blue, red)
			_expect(first.state_hash() == second.state_hash(), "Deployment/combat/loot replay seed%d tick%d" % [seed, first.tick])
		_expect(first.tactical_boxes.is_empty() and first.units.size() == 2, "Both deployments and all three-hit boxes complete")
		var total := 0
		var platforms := 0
		for side in 2:
			for kind in CONFIG.TACTICAL_ITEM_COUNT:
				total += first.sides[side].tactical_items[kind]
			platforms += first.sides[side].tactical_items[CONFIG.TACTICAL_ITEM_PLATFORM]
		_expect(total == opened and platforms <= 1 and first.platform_drop_count == 2 + platforms, "Loot deterministic and shared platform cap enforced through later drops")
		_expect(first.sides[1].tactical_items.reduce(func(a: int, b: int) -> int: return a + b, 0) > 0, "Red can claim third-hit loot")
