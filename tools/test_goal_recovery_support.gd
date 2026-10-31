extends SceneTree

var failures := 0
var data := {}
var empty: Array[InputCommand] = []

func _initialize() -> void:
	for id in ["bagpipe", "blaze", "exusiai", "hoshiguma", "nightingale", "phantom", "muelsyse", "weedy", "magallan"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func fixture() -> MatchState:
	return MatchState.new(148, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [], [], MatchRules.new("score", 1, 1))

func unit(state: MatchState, id: String, side: int, cell: Vector2i) -> UnitState:
	var op: OperatorData = state._operator_data[id]
	var value := UnitState.new(state.next_unit_id, side, id, cell, op.max_health, 0, 10000)
	state.next_unit_id += 1
	state.units.append(value)
	return value

func goal(state: MatchState, conceded: int) -> void:
	state.ball.cell = Vector2i(0 if conceded == 1 else 20, 5)
	state.step([], [])

func run() -> void:
	for side in 2:
		var state := fixture()
		state.sides[side].cost = 30
		state.sides[side].cooldowns = {"blaze":600, "bagpipe":700, "exusiai":500, "hoshiguma":400, "nightingale":500, "phantom_clone":900}
		var deployed := unit(state, "blaze", side, Vector2i(19 if side == 0 else 1, 9))
		deployed.skill_ticks_left = 80
		goal(state, side)
		check(state.goals[1-side] == 1 and state.recovery_side == side, "conceding side owns recovery")
		check(state.sides[side].cost == 80 and not state.sides[side].cooldowns.has("bagpipe") and not state.sides[side].cooldowns.has("exusiai") and not state.sides[side].cooldowns.has("nightingale"), "top three waiting ordinary operators reset")
		check(state.sides[side].cooldowns.blaze == 599 and state.sides[side].cooldowns.hoshiguma == 399 and state.sides[side].cooldowns.phantom_clone == 899, "deployed operators, fourth cooldown and summons excluded")
		var battle_tick := state.tick
		var cost_clock := state.sides[side].cost_regen_ticks
		var hp := deployed.hp
		var skill := deployed.skill_ticks_left
		var rng_seed := state.rng.state
		state.step([], [])
		check(state.tick == battle_tick and state.input_tick == battle_tick+1 and deployed.hp == hp and deployed.skill_ticks_left == skill and state.sides[side].cost_regen_ticks == cost_clock and state.rng.state == rng_seed, "pause freezes battle clocks economy skills HP and RNG")
		var cross := Vector2i(2 if side == 0 else 18, 5)
		check(state.can_deploy(side, "bagpipe", cross) and not state.can_deploy(1-side, "bagpipe", cross), "only conceding side can cross boundary")
		check(not state.can_deploy(side, "bagpipe", Vector2i(3,2)) and not state.can_deploy(side, "exusiai", cross) and not state.can_deploy(side, "bagpipe", Vector2i(10,4)) and not state.can_deploy(side, "hoshiguma", cross), "terrain center and remaining cooldown enforced")
		state.sides[side].cost = 0
		check(not state.can_deploy(side, "bagpipe", cross), "cost still enforced")
		state.sides[side].cost = 80
		var cmds: Array[InputCommand] = [InputCommand.new(state.input_tick, InputCommand.Kind.RECOVERY_DEPLOY, "bagpipe", -1, cross), InputCommand.new(state.input_tick, InputCommand.Kind.RECOVERY_DEPLOY, "nightingale", -1, Vector2i(3,2))]
		state.step(cmds if side == 0 else empty, cmds if side == 1 else empty)
		check(state.recovery_side == -1 and state.units.size() == 2 and state.units[-1].cell == cross and state.sides[side].cost == 80-state.deploy_cost(side,"bagpipe"), "one charged deployment resumes early")
		state.step([InputCommand.new(state.input_tick, InputCommand.Kind.RECOVERY_DEPLOY, "hoshiguma", -1, Vector2i(18,5))], [])
		check(state.units.size() == 2, "late recovery intent cannot become ordinary deployment")
	var timeout := fixture()
	timeout.sides[1].cost = 90
	goal(timeout, 1)
	check(timeout.sides[1].cost == Config.COST_MAX, "compensation caps at99")
	var frozen_tick := timeout.tick
	for frame in Config.GOAL_RECOVERY_INPUT_TICKS-1: timeout.step([], [])
	check(timeout.recovery_ticks_left == 1 and timeout.tick == frozen_tick, "full15 second recovery remains frozen until last frame")
	timeout.step([], [])
	check(timeout.recovery_side == -1 and timeout.tick == frozen_tick and timeout.input_tick == frozen_tick+338, "timeout forfeits without consuming match time")
	timeout.step([], [])
	check(timeout.tick == frozen_tick+1, "battle resumes after timeout")
	var skipped := fixture()
	goal(skipped, 0)
	skipped.step([InputCommand.new(skipped.input_tick, InputCommand.Kind.SKIP_RECOVERY)], [])
	check(skipped.recovery_side == -1 and skipped.tick == 1, "voluntary skip freezes its input frame")
	var no_cards := MatchState.new(1, {}, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [], [], MatchRules.new("score",1,1))
	goal(no_cards, 1)
	check(no_cards.recovery_side == -1, "no legal deployment automatically continues")
	var last := fixture()
	last.tick = last.rules.duration_ticks()-1
	goal(last, 1)
	check(last.result == 1 and last.recovery_side == -1, "final settled goal counts without postgame pause")
	var ai_state := fixture()
	goal(ai_state, 1)
	var before_ai := ai_state.state_hash()
	var ai_commands := AIInput.new(1,data).commands_for_tick(ai_state)
	check(ai_commands.size() == 1 and ai_commands[0].kind == InputCommand.Kind.RECOVERY_DEPLOY and ai_commands[0].cell.x == 9 and before_ai == ai_state.state_hash(), "AI recovery uses one legal near-ball deployment and remains read-only")
	check(AIInput.new(0,data).commands_for_tick(ai_state).is_empty(), "non-conceding AI stays frozen")
	test_drone()
	test_all_summons_and_loot()
	test_codec()
	test_replay()
	print("GOAL_RECOVERY_SUPPORT_OK failures=", failures)
	quit(0 if failures == 0 else 1)

func test_drone() -> void:
	var state := fixture()
	state.sides[0].tactical_items[3] = 10
	var origin := Vector2i(13,5)
	var ally := unit(state,"bagpipe",0,origin)
	var enemy := unit(state,"bagpipe",1,Vector2i(14,5))
	var far := unit(state,"bagpipe",1,Vector2i(15,6))
	var friendly_summon := unit(state,"phantom_clone",0,Vector2i(13,4))
	var target := unit(state,"phantom_clone",1,Vector2i(12,5))
	var protected := unit(state,"medical_drone",1,Vector2i(13,6))
	var outside := unit(state,"weedy_cannon",1,Vector2i(16,5))
	for cell in [origin,Vector2i(12,2),Vector2i(10,5),Vector2i(20,10)]: check(state.can_use_item(0,3,cell), "aerial item ignores terrain ground occupancy and ball")
	check(not state.can_use_item(0,3,Vector2i(9,5)) and not state.can_use_item(0,3,Vector2i(-1,0)), "aerial item retains boundary and arena bounds")
	var range_count := 0
	var caster: OperatorData = load("res://resources/operators/carnelian.tres")
	for row in range(-3,4):
		for column in range(-3,4):
			var offset := Vector2i(column,row)
			check(TacticalRules.support_covers(origin,origin+offset) == (offset in caster.attack_range), "drone matches base phalanx caster range")
			if TacticalRules.support_covers(origin,origin+offset): range_count += 1
	check(range_count == 13,"exact13 cell range")
	var command := InputCommand.new(state.tick,InputCommand.Kind.USE_ITEM,"",-1,origin,-1,-1,3)
	TacticalRules.use_item(state,0,command)
	check(state.sides[0].tactical_items[3] == 9 and target not in state.units and protected not in state.units and friendly_summon in state.units and outside in state.units, "one inventory, remove enemy summons including untargetable, keep friendly and outside")
	check(ally.attack_speed_remaining_percent == 120 and enemy.attack_speed_remaining_percent == 80 and far.attack_speed_remaining_percent == 100, "friendly120 enemy80 outside100 attack rate")
	check(SkillRules.attack_interval_ticks(ally,data.bagpipe) == roundi(data.bagpipe.attack_interval*Config.TICK_RATE/1.2), "support changes actual attack interval")
	state.sides[0].tactical_items[3] = 9
	TacticalRules.use_item(state,0,InputCommand.new(state.tick,3,"",-1,Vector2i(13,6),-1,-1,3))
	check(ally.attack_speed_remaining_percent == 120,"same-side overlap does not stack")
	state.sides[1].tactical_items[3] = 1
	TacticalRules.use_item(state,1,InputCommand.new(state.tick,3,"",-1,Vector2i(12,5),-1,-1,3))
	check(ally.attack_speed_remaining_percent == 100,"opposing fields cancel")
	var effect := state.tactical_item_effects[0]
	state.tick = effect.placed_tick+Config.ITEM_SUPPORT_DRONE_TICKS-1
	TacticalRules.advance_effects(state)
	check(effect in state.tactical_item_effects,"active through final duration tick")
	state.tick += 1
	TacticalRules.advance_effects(state)
	AuraRules.refresh(state)
	check(state.tactical_item_effects.is_empty() and ally.attack_speed_remaining_percent == 100,"expires exactly30 gameplay seconds and restores attack rate")
	check(not state.item_reserves_cell(origin),"aerial support does not reserve ground or block ball")

func test_codec() -> void:
	var ids := PackedStringArray(["bagpipe"])
	for row in [[7,5,"",-1,0,0,-1,-1,-1],[7,6,"bagpipe",-1,2,5,-1,0,-1],[7,3,"",-1,10,5,-1,-1,3]]:
		check(CommandCodec.decode(JSON.parse_string(JSON.stringify([row])),7,ids).has("commands"),"new input roundtrip")
	for row in [[7,5,"bagpipe",-1,0,0,-1,-1,-1],[7,5,"",-1,1,0,-1,-1,-1],[7,6,"bagpipe",-1,2,5,0,0,-1],[7,3,"",-1,10,5,-1,0,3],[7,7,"",-1,0,0,-1,-1,-1]]:
		check(CommandCodec.decode([row],7,ids).has("error"),"strict new input boundary")

func test_replay() -> void:
	var first := fixture()
	var second := fixture()
	for frame in 1500:
		if frame in [2,500,1000]:
			first.ball.cell.x = 0
			second.ball.cell.x = 0
		var blue: Array[InputCommand] = []
		var red: Array[InputCommand] = []
		if first.recovery_side >= 0 and first.recovery_ticks_left < 330:
			red.append(InputCommand.new(first.input_tick,InputCommand.Kind.SKIP_RECOVERY))
		first.step(blue,red)
		second.step(blue,red)
		check(first.state_hash() == second.state_hash(),"mixed recovery replay frame%d" % frame)
	check(first.result == 1 and first.goals[0] == 3 and first.recovery_input_ticks > 0,"replay includes scoring pauses and timed completion")

func test_all_summons_and_loot() -> void:
	var all_data := {}
	for id in root.get_node("OperatorDB").all_ids(): all_data[id] = root.get_node("OperatorDB").get_data(id)
	var content: Dictionary = root.get_node("OperatorDB").network_content()
	var removed := 0
	for id in content.summon_owners:
		var state := MatchState.new(1,all_data)
		state.sides[0].tactical_items[3] = 1
		var token := unit(state,id,1,Vector2i(13,5))
		TacticalRules.use_item(state,0,InputCommand.new(0,3,"",-1,Vector2i(13,5),-1,-1,3))
		check(token not in state.units,"force withdrawal handles registered summon " + id)
		removed += 1
	check(removed == 23,"all23 deployable summon types exercised")
	var seen := PackedInt32Array([0,0,0,0])
	for seed in range(1,161):
		var state := MatchState.new(seed,data)
		var attacker := unit(state,"bagpipe",0,Vector2i(13,5))
		var box := TacticalBox.new(0,Vector2i(12,5),1)
		state.tactical_boxes.append(box)
		TacticalRules.strike_box(state,attacker,box)
		check(state.sides[0].tactical_items.reduce(func(a: int,b: int) -> int:return a+b,0) == 1,"single loot award")
		for kind in 4: seen[kind] += state.sides[0].tactical_items[kind]
	check(seen[0] > 0 and seen[1] > 0 and seen[2] > 0 and seen[3] > 0,"all four items are eligible including support drone")
	for seed in range(1,81):
		var state := MatchState.new(seed,data)
		state.platform_drop_count = 3
		var attacker := unit(state,"bagpipe",0,Vector2i(13,5))
		var box := TacticalBox.new(0,Vector2i(12,5),1)
		state.tactical_boxes.append(box)
		TacticalRules.strike_box(state,attacker,box)
		check(state.sides[0].tactical_items[1] == 0 and state.sides[0].tactical_items.reduce(func(a: int,b: int) -> int:return a+b,0) == 1,"platform cap retains the other three item kinds")
