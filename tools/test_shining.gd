extends SceneTree

const EXPECTED_RANGE := [Vector2i(0,-1),Vector2i(0,0),Vector2i(0,1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(2,-1),Vector2i(2,0),Vector2i(2,1),Vector2i(3,-1),Vector2i(3,0),Vector2i(3,1)]
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := {}
	for id in ["shining", "blaze", "bagpipe", "ceobe", "hoshiguma"]:
		definitions[id] = load("res://resources/operators/%s.tres" % id)
	var shining: OperatorData = definitions["shining"]
	_expect(shining.profession_id == "medic" and shining.branch == "医师" and shining.branch_trait.effect_type == "single_target_heal" and Array(shining.attack_range) == EXPECTED_RANGE, "Shining must be a physician with exact 3-3 E2 range, not a multi-target medic")
	var state := _fixture(definitions)
	var ball_before := state.ball.accum
	state.step([], [])
	_expect(state.units[1].hp == 1265 and state.units[2].hp == 1500 and state.units[3].hp == 1000 and state.units[4].hp == 1000, "Physician must heal only the weakest friendly ratio: +265, no other or enemy target")
	_expect(state.ball.accum == ball_before and state.units[0].last_attack_is_heal, "Physician must not attack or push the ball")
	_expect(state.units[1].defense_bonus_add == 60 and state.units[4].defense_bonus_add == 0, "Flat aura must affect friendly units only")
	_expect(SkillRules.defense_value(state.units[0], shining) == 198 and SkillRules.attack_interval_ticks(state.units[0], shining) == 78, "Aura includes self; talent2 gives +10 speed (78 ticks)")
	state.units[1].defense_bonus_percent = 30
	_expect(SkillRules.defense_value(state.units[1], definitions["bagpipe"]) == 575, "Flat +60 defense is direct addition before 30% multiplication: round((382+60)*1.3)=575")
	state.units[0].sp = 40
	state.units[0].attack_ticks_left = 0
	var cast: Array[InputCommand] = [InputCommand.new(state.tick, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 0)]
	state.step(cast, [])
	_expect(state.units[1].hp == 1742 and SkillRules.attack_value(state.units[0], shining) == 954 and SkillRules.attack_interval_ticks(state.units[0], shining) == 66, "S1M3 must heal +477 with attack 954 and speed +10+20 (66 ticks)")
	_expect(state.units[0].sp == 0 and state.units[0].skill_ticks_left == 599, "S1 must consume 40 SP and last 20 seconds")
	state.units[0].skill_ticks_left = 1
	state.step([], [])
	_expect(SkillRules.attack_value(state.units[0], shining) == 530 and SkillRules.attack_interval_ticks(state.units[0], shining) == 78, "S1 expiry restores base attack and talent-only interval")
	for facing in 4:
		var range_state := _fixture(definitions)
		range_state.units[0].facing = facing
		for index in range(1, range_state.units.size()):
			range_state.units[index].cell = range_state.units[0].cell + preload("res://sim/attack_range.gd").rotate_offset(Vector2i(index, 0), facing)
		AuraRules.refresh(range_state)
		_expect(range_state.units[1].defense_bonus_add == 60 and range_state.units[3].defense_bonus_add == 60 and range_state.units[4].defense_bonus_add == 0, "Four facing rotations must include front three cells and exclude the fourth")
	var outside := _fixture(definitions)
	outside.units[1].cell = Vector2i(11, 4)
	AuraRules.refresh(outside)
	_expect(outside.units[1].defense_bonus_add == 0, "Physician 3-3 range must not inherit Nightingale's rear column")
	var retreat := _fixture(definitions)
	AuraRules.refresh(retreat)
	retreat.step([InputCommand.new(0, InputCommand.Kind.RETREAT, "", 0)], [])
	_expect(retreat.units[0].defense_bonus_add == 0, "Source retreat must remove defense aura immediately")
	var first := _fixture(definitions)
	var second := _fixture(definitions)
	for tick in 700:
		var commands: Array[InputCommand] = []
		if tick == 600:
			commands = [InputCommand.new(tick, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 0)]
		first.step(commands, [])
		second.step(commands, [])
		_expect(first.state_hash() == second.state_hash(), "Shining replay divergence at tick %d" % tick)
	var decoded := CommandCodec.decode([[1,0,"shining",-1,12,4,-1,0,-1]], 1, Engine.get_main_loop().root.get_node("OperatorDB").network_content()["ids"])
	_expect(not decoded.has("error"), "Network boundary must accept Shining deploy ID")
	print("Shining: exact physician range/four facings, single-target heal, direct-add defense, source removal, S1M3, 700-tick replay; failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _fixture(definitions: Dictionary) -> MatchState:
	var state := MatchState.new(101, definitions)
	state.units = [UnitState.new(0,0,"shining",Vector2i(12,4),1613,20,0,0),UnitState.new(1,0,"bagpipe",Vector2i(13,4),1000,0,1000),UnitState.new(2,0,"blaze",Vector2i(14,4),1500,0,1000),UnitState.new(3,0,"ceobe",Vector2i(15,4),1000,0,1000),UnitState.new(4,1,"bagpipe",Vector2i(13,5),1000,0,1000)]
	state.next_unit_id = 5
	return state


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
