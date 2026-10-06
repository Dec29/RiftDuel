extends SceneTree

const BALL_DATA := preload("res://resources/ball/standard.tres")
const MATCH_STATE := preload("res://sim/match_state.gd")
const AI_INPUT := preload("res://decision/ai_input.gd")
const LOCAL_INPUT := preload("res://decision/local_input.gd")
const OPERATOR_IDS := [
	"angelina",
	"bagpipe",
	"blaze",
	"ceobe",
	"exusiai",
	"hoshiguma",
	"nightingale",
	"swire_alter",
]


func _initialize() -> void:
	var definitions := {}
	for operator_id in OPERATOR_IDS:
		definitions[operator_id] = ResourceLoader.load("res://resources/operators/%s.tres" % operator_id) as OperatorData

	var local_input := LOCAL_INPUT.new(0) as LocalInput
	local_input.select_operator("bagpipe")
	local_input.queue_deploy(0, Vector2i(11, 5))
	var local_commands := local_input.take_commands()
	if (
		local_commands.size() != 1
		or local_commands[0].kind != InputCommand.Kind.DEPLOY
		or local_commands[0].operator_id != "bagpipe"
		or local_commands[0].cell != Vector2i(11, 5)
		or not local_input.take_commands().is_empty()
	):
		_fail("LocalInput did not produce a valid deploy command")
		return
	local_input.select_unit(7)
	local_input.queue_retreat(1, 7)
	local_commands = local_input.take_commands()
	if local_commands.size() != 1 or local_commands[0].kind != InputCommand.Kind.RETREAT or local_commands[0].unit_id != 7:
		_fail("LocalInput did not produce a valid retreat command")
		return

	var random := RNG.new(0x12345678)
	var expected_random := [2274908837, 358294691, 1210119364, 2176035992, 1882851208]
	for expected_value in expected_random:
		var actual_value := random.next_u32()
		if actual_value != expected_value:
			_fail("RNG mismatch: expected=%d actual=%d" % [expected_value, actual_value])
			return

	var cancellation := BallState.new()
	cancellation.add_push(Vector2i(11, 5), 1000, BALL_DATA)
	cancellation.add_push(Vector2i(9, 5), 1000, BALL_DATA)
	if cancellation.accum != Vector2i.ZERO or cancellation.move_ticks_left != 0:
		_fail("Opposing pushes did not cancel")
		return
	var tie_break := BallState.new()
	tie_break.add_push(Vector2i(9, 4), 2000, BALL_DATA)
	if tie_break.move_direction != Vector2i.RIGHT:
		_fail("Equal push components did not choose horizontal movement")
		return
	tie_break.add_push(Vector2i(11, 5), 2000, BALL_DATA)
	if tie_break.accum != Vector2i.ZERO or tie_break.move_direction != Vector2i.RIGHT:
		_fail("Moving ball accepted a new push")
		return
	var wall_stop := BallState.new(Vector2i(0, 5))
	wall_stop.add_push(Vector2i(1, 5), 2000, BALL_DATA)
	for _wall_tick in 8:
		wall_stop.advance_move()
	if wall_stop.cell != Vector2i(0, 5):
		_fail("Out-of-bounds movement did not stop at the wall")
		return

	var red_goal := MATCH_STATE.new(99, definitions) as MatchState
	while red_goal.result == MatchState.RESULT_RUNNING:
		for _hit in 4:
			red_goal.ball.add_push(red_goal.ball.cell + Vector2i.LEFT, 500, BALL_DATA)
		for _move_tick in 8:
			red_goal.step([], [])
	if red_goal.ball.cell != Vector2i(20, 5) or red_goal.result != MatchState.RESULT_RED_WIN:
		_fail("Red goal regression: cell=%s result=%d" % [red_goal.ball.cell, red_goal.result])
		return

	var schedule := {}
	var first := _run_match(definitions, schedule, true)
	var second := _run_match(definitions, schedule, false)
	if first.ball.cell != Vector2i(0, 5) or first.result != MatchState.RESULT_BLUE_WIN:
		_fail("Expected blue win at (0, 5), got cell=%s result=%d" % [first.ball.cell, first.result])
		return
	if first.tick > 9000:
		_fail("Match exceeded 9000 ticks: %d" % first.tick)
		return
	if first.state_hash() != second.state_hash():
		_fail("Determinism mismatch: first=%d second=%d" % [first.state_hash(), second.state_hash()])
		return
	var ai_schedule := {}
	var ai_hashes: Array[int] = []
	var ai_first := _run_ai_match(definitions, ai_schedule, true, ai_hashes)
	var ai_second := _run_ai_match(definitions, ai_schedule, false, ai_hashes)
	var skill_commands := 0
	for command_tick in ai_schedule:
		for command in ai_schedule[command_tick]:
			if command.kind == InputCommand.Kind.SKILL:
				skill_commands += 1
	var skill_first := MATCH_STATE.new(991, definitions) as MatchState
	var skill_second := MATCH_STATE.new(991, definitions) as MatchState
	skill_first.sides[0].cost = 13
	skill_second.sides[0].cost = 13
	for skill_tick in 650:
		var skill_inputs: Array[InputCommand] = []
		if skill_tick == 0:
			skill_inputs.append(InputCommand.new(skill_tick, InputCommand.Kind.DEPLOY, "bagpipe", -1, Vector2i(11, 5)))
		elif skill_tick == 600:
			skill_inputs.append(InputCommand.new(skill_tick, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 0))
			skill_commands += 1
		skill_first.step(skill_inputs, [])
		skill_second.step(skill_inputs, [])
		if skill_first.state_hash() != skill_second.state_hash():
			_fail("Manual skill replay diverged at tick %d" % skill_tick)
			return
		if skill_tick == 600 and (skill_first.units[0].skill_ticks_left != 1049 or skill_first.units[0].sp != 0):
			_fail("Manual skill command did not activate Bagpipe")
			return
	if ai_first.result != MatchState.RESULT_BLUE_WIN or ai_first.tick > 9000:
		_fail("AIInput did not finish a match: result=%d tick=%d cell=%s" % [ai_first.result, ai_first.tick, ai_first.ball.cell])
		return
	if ai_first.state_hash() != ai_second.state_hash():
		_fail("AIInput replay mismatch: first=%d second=%d" % [ai_first.state_hash(), ai_second.state_hash()])
		return
	var hash_a := MATCH_STATE.new(77, definitions) as MatchState
	var hash_b := MATCH_STATE.new(77, definitions) as MatchState
	hash_a.sides[0].cooldowns["blaze"] = 3
	hash_a.sides[0].cooldowns["bagpipe"] = 2
	hash_b.sides[0].cooldowns["bagpipe"] = 2
	hash_b.sides[0].cooldowns["blaze"] = 3
	if hash_a.state_hash() != hash_b.state_hash():
		_fail("State hash depends on Dictionary insertion order")
		return

	var deploy_state := MATCH_STATE.new(11, definitions) as MatchState
	deploy_state.sides[0].cost = 99
	var invalid_line: Array[InputCommand] = [InputCommand.new(0, InputCommand.Kind.DEPLOY, "bagpipe", -1, Vector2i(9, 5))]
	deploy_state.step(invalid_line, [])
	var invalid_terrain: Array[InputCommand] = [InputCommand.new(1, InputCommand.Kind.DEPLOY, "bagpipe", -1, Vector2i(14, 4))]
	deploy_state.step(invalid_terrain, [])
	if not deploy_state.units.is_empty():
		_fail("Invalid deployment command changed unit state")
		return
	var valid_deploy: Array[InputCommand] = [InputCommand.new(2, InputCommand.Kind.DEPLOY, "bagpipe", -1, Vector2i(11, 5))]
	deploy_state.step(valid_deploy, [])
	if deploy_state.units.size() != 1 or deploy_state.sides[0].cost != 86:
		_fail("Valid deployment failed: units=%d cost=%d" % [deploy_state.units.size(), deploy_state.sides[0].cost])
		return
	var retreat: Array[InputCommand] = [InputCommand.new(3, InputCommand.Kind.RETREAT, "", 0)]
	deploy_state.step(retreat, [])
	if not deploy_state.units.is_empty() or deploy_state.sides[0].cost != 99 or deploy_state.sides[0].cooldowns["bagpipe"] != 2100:
		_fail("Vanguard full retreat refund or cooldown mismatch")
		return

	var combat_state := MATCH_STATE.new(22, definitions) as MatchState
	combat_state.units = [
		UnitState.new(0, 0, "swire_alter", Vector2i(11, 5), 2360, 0, 1),
		UnitState.new(1, 1, "hoshiguma", Vector2i(10, 5), 1, 0, 1),
	]
	combat_state.next_unit_id = 2
	combat_state.step([], [])
	if combat_state.units.size() != 1 or combat_state.units[0].operator_id != "swire_alter":
		_fail("Enemy-first targeting or defeat removal failed")
		return
	if combat_state.ball.accum != Vector2i.ZERO or combat_state.sides[1].cooldowns["hoshiguma"] != 2100:
		_fail("Defeat cooldown or target priority failed")
		return

	var healing_state := MATCH_STATE.new(33, definitions) as MatchState
	healing_state.units = [
		UnitState.new(0, 0, "swire_alter", Vector2i(11, 5), 1000, 0, 100),
		UnitState.new(1, 0, "nightingale", Vector2i(12, 4), 1705, 0, 1),
	]
	healing_state.next_unit_id = 2
	healing_state.step([], [])
	if healing_state.units[0].hp != 1175 or healing_state.ball.accum != Vector2i.ZERO:
		_fail("Healing resolution failed: hp=%d accum=%s" % [healing_state.units[0].hp, healing_state.ball.accum])
		return

	var blocker_state := MATCH_STATE.new(44, definitions) as MatchState
	blocker_state.units = [UnitState.new(0, 1, "hoshiguma", Vector2i(9, 5), 3850, 0, 100)]
	blocker_state.next_unit_id = 1
	blocker_state.ball.add_push(Vector2i(11, 5), 2000, BALL_DATA)
	for _move_tick in 8:
		blocker_state.step([], [])
	if blocker_state.ball.cell != Vector2i(10, 5):
		_fail("Block-count 3 unit did not stop the ball: %s" % blocker_state.ball.cell)
		return

	var economy_state := MATCH_STATE.new(55, definitions) as MatchState
	for _cost_tick in 30:
		economy_state.step([], [])
	if economy_state.sides[0].cost != 11 or economy_state.sides[1].cost != 11:
		_fail("Cost regeneration mismatch: %d / %d" % [economy_state.sides[0].cost, economy_state.sides[1].cost])
		return

	print("L2 OK: result=%d tick=%d commands=%d hash=%d ai_tick=%d skills=%d" % [
		first.result,
		first.tick,
		schedule.size(),
		first.state_hash(),
		ai_first.tick,
		skill_commands,
	])
	quit(0)


func _run_match(definitions: Dictionary, schedule: Dictionary, generate_schedule: bool) -> MatchState:
	var state := MATCH_STATE.new(0x12345678, definitions) as MatchState
	while state.result == MatchState.RESULT_RUNNING and state.tick < 9000:
		var blue_commands: Array[InputCommand] = []
		if generate_schedule:
			if not state.units.is_empty():
				var unit := state.units[0]
				if unit.cell.x - state.ball.cell.x > 1 and state.ball.move_ticks_left == 0:
					blue_commands.append(InputCommand.new(state.tick, InputCommand.Kind.RETREAT, "", unit.unit_id))
			elif state.sides[0].cooldowns.get("swire_alter", 0) == 0 and state.sides[0].cost >= definitions["swire_alter"].deploy_cost:
				var cell := Vector2i(11, 5) if state.ball.cell.x == 10 else state.ball.cell
				blue_commands.append(InputCommand.new(state.tick, InputCommand.Kind.DEPLOY, "swire_alter", -1, cell, -1, 2))
			if not blue_commands.is_empty():
				schedule[state.tick] = blue_commands.duplicate()
		elif schedule.has(state.tick):
			for command in schedule[state.tick]:
				blue_commands.append(command)
		state.step(blue_commands, [])
	return state


func _run_ai_match(definitions: Dictionary, schedule: Dictionary, generate_schedule: bool, hashes: Array[int]) -> MatchState:
	var state := MATCH_STATE.new(0x12345678, definitions) as MatchState
	var ai := AI_INPUT.new(0, definitions) as AIInput
	while state.result == MatchState.RESULT_RUNNING and state.tick < 9000:
		var blue_commands: Array[InputCommand] = []
		if generate_schedule:
			var before_hash := state.state_hash()
			blue_commands = ai.commands_for_tick(state)
			if before_hash != state.state_hash():
				_fail("AIInput wrote simulation state at tick %d" % state.tick)
				return state
			if not blue_commands.is_empty():
				schedule[state.tick] = blue_commands.duplicate()
		elif schedule.has(state.tick):
			for command in schedule[state.tick]:
				blue_commands.append(command)
		state.step(blue_commands, [])
		if generate_schedule:
			hashes.append(state.state_hash())
		elif state.state_hash() != hashes[state.tick - 1]:
			_fail("AI replay diverged at tick %d: expected=%d actual=%d" % [state.tick, hashes[state.tick - 1], state.state_hash()])
			return state
	return state


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
