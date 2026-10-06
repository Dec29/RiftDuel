extends SceneTree

const ATTACK_RANGE := preload("res://sim/attack_range.gd")
var _failures: int = 0


func _initialize() -> void:
	var fighter := load("res://resources/operators/bagpipe.tres").duplicate(true) as OperatorData
	fighter.attack_range.assign([Vector2i.ZERO, Vector2i.RIGHT])
	fighter.dodge_physical = 0
	var healer := load("res://resources/operators/nightingale.tres").duplicate(true) as OperatorData
	healer.attack_range.assign([Vector2i.ZERO])
	var definitions := {"bagpipe": fighter, "nightingale": healer}
	definitions["hoshiguma"] = load("res://resources/operators/hoshiguma.tres")
	var directions := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for facing in 4:
		var state := MatchState.new(73, definitions)
		state.ball.cell = Vector2i(1, 0)
		var target_cell: Vector2i = Vector2i(12, 5) + directions[facing]
		state.units = [UnitState.new(0, 0, "bagpipe", Vector2i(12, 5), fighter.max_health, 0, 1, facing), UnitState.new(1, 1, "bagpipe", target_cell, fighter.max_health, 0, 100)]
		state.next_unit_id = 2
		state.step([], [])
		_expect(state.units[1].hp < fighter.max_health, "Facing %d failed to attack front cell %s" % [facing, target_cell])
		_expect(state.units[0].last_attack_tick == 0 and state.units[0].last_attack_target_x == target_cell.x and state.units[0].last_attack_target_y == target_cell.y and state.units[1].last_damage_tick == 0, "Facing %d attack/damage markers incorrect" % facing)
		state.units[1].cell = Vector2i(12, 5) - directions[facing]
		state.units[0].attack_ticks_left = 1
		var hp := state.units[1].hp
		state.step([], [])
		_expect(state.units[1].hp == hp and state.units[0].last_attack_tick == 0, "Facing %d incorrectly attacked rear cell" % facing)
		_expect(ATTACK_RANGE.rotate_offset(Vector2i(2, 1), facing) == [Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, -1), Vector2i(1, -2)][facing], "Facing %d lateral offset rotation incorrect" % facing)
		var own_ball := MatchState.new(73, definitions)
		own_ball.units = [UnitState.new(0, 0, "bagpipe", own_ball.ball.cell, fighter.max_health, 0, 1, facing)]
		own_ball.next_unit_id = 1
		own_ball.step([], [])
		_expect(own_ball.ball.accum == directions[facing] * fighter.attack, "Facing %d same-cell ball push ignored facing" % facing)

	var self_heal := MatchState.new(73, definitions)
	self_heal.units = [UnitState.new(0, 0, "nightingale", Vector2i(12, 4), 1000, 0, 1, 3)]
	self_heal.next_unit_id = 1
	self_heal.step([], [])
	_expect(self_heal.units[0].hp == mini(healer.max_health, 1000 + roundi(healer.attack * 0.5)) and self_heal.units[0].last_heal_tick == 0, "Own-cell range failed 50%-scaled self-healing")
	var same_cell := MatchState.new(73, definitions)
	same_cell.units = [UnitState.new(0, 0, "bagpipe", Vector2i(12, 5), fighter.max_health, 0, 1, 3), UnitState.new(1, 1, "bagpipe", Vector2i(12, 5), fighter.max_health, 0, 100)]
	same_cell.next_unit_id = 2
	same_cell.step([], [])
	_expect(same_cell.units[1].hp < fighter.max_health, "Own-cell range failed same-cell attack")
	fighter.dodge_physical = 100
	same_cell.units[0].attack_ticks_left = 1
	var before_hp := same_cell.units[1].hp
	same_cell.step([], [])
	_expect(same_cell.units[1].hp == before_hp and same_cell.units[0].last_attack_tick == 1 and same_cell.units[1].last_damage_tick == 0, "Dodge must mark attack but not damage")

	var local_input := LocalInput.new(0)
	local_input.select_operator("bagpipe")
	local_input.queue_deploy(0, Vector2i(12, 5), 1)
	var commands := local_input.take_commands()
	_expect(commands[0].facing == 1, "LocalInput discarded deployment facing")
	var first := MatchState.new(73, definitions)
	var replay := MatchState.new(73, definitions)
	first.sides[0].cost = 99
	replay.sides[0].cost = 99
	first.step(commands, [])
	replay.step(commands, [])
	_expect(first.units[0].facing == 1 and first.state_hash() == replay.state_hash(), "Deployment facing or replay hash mismatch")
	_expect(UnitState.new(0, 0).facing == 2 and UnitState.new(0, 1).facing == 0 and InputCommand.new().facing == -1, "Default commands must preserve side-facing behavior")
	var blocked := MatchState.new(73, definitions)
	blocked.units = [UnitState.new(0, 0, "hoshiguma", Vector2i(11, 5), 3850, 0, 100)]
	blocked.ball.move_ticks_left = 1
	blocked.ball.move_direction = Vector2i.RIGHT
	_expect(blocked.ball_move_is_blocked(), "Ball movement preview missed heavy blocker")
	blocked.step([], [])
	_expect(blocked.ball.cell == Vector2i(10, 5) and not blocked.ball_move_is_blocked(), "Blocked ball moved or stationary ball reported blocked")
	blocked.ball.cell = Vector2i(0, 5)
	blocked.ball.move_ticks_left = 1
	blocked.ball.move_direction = Vector2i.LEFT
	_expect(blocked.ball_move_is_blocked(), "Ball movement preview missed arena boundary")
	for field in ["facing", "last_attack_tick", "last_attack_target_x", "last_attack_target_y", "last_damage_tick", "last_heal_tick"]:
		var before: int = first.units[0].get(field)
		var base_hash := first.state_hash()
		first.units[0].set(field, before + 1)
		_expect(first.state_hash() != base_hash, "State hash omits %s" % field)
		first.units[0].set(field, before)
	print("Facing: four directions, own cell, event markers, command replay; failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
