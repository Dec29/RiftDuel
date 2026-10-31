extends SceneTree

var failures := 0
var data := {}


func _initialize() -> void:
	data.phantom = load("res://resources/operators/phantom.tres")
	var target := data.phantom.duplicate(true) as OperatorData
	target.operator_id = "target"
	target.max_health = 100000
	target.defense = 0
	target.dodge_physical = 0
	data.target = target
	for index in [1, 2]:
		check(data.phantom.skills[index].parameters_are_valid() and MatchState.CLONE_DATA.skills[index].parameters_are_valid(), "Typed body and clone skills")
		var state := fixture(index)
		state.step([deploy(state, "phantom", Vector2i(12, 5))], [])
		state.step([deploy(state, "phantom_clone", Vector2i(13, 5))], [])
		check(state.units.size() == 2 and state.units[1].skill_index == index and state.sides[0].clone_cooldown_ticks == 1050, "Clone carries selected skill and35sec independent cooldown")
		if index == 1:
			check(state.units[0].attack_boost_stacks == 10 and state.units[1].attack_boost_stacks == 10 and SkillRules.attack_value(state.units[0], data.phantom) == 1674 and SkillRules.attack_value(state.units[1], MatchState.CLONE_DATA) == 1644, "Independent ten stacks and own base stats")
		else:
			check(Vector2i(state.units[0].last_attack_target_x, state.units[0].last_attack_target_y) == state.units[0].cell, "Targetless burst feedback stays on own cell")
		state.step([InputCommand.new(state.tick, InputCommand.Kind.RETREAT, "", 0)], [])
		check(state.units.size() == 1 and state.units[0].operator_id == "phantom_clone" and state.units[0].hp > 0 and state.units[0].skill_index == index, "Body withdraw keeps existing clone")
	for mode in ["normal", "dodge", "block", "barrier", "box", "ball", "none"]:
		var state := fixture(1)
		state.step([deploy(state, "phantom", Vector2i(12, 5))], [])
		var source := state.units[0]
		source.attack_ticks_left = 1
		var enemy := data.target.duplicate(true) as OperatorData
		if mode == "dodge": enemy.dodge_physical = 100
		if mode == "block":
			enemy.talent_1.effect_type = "damage_block"
			enemy.talent_1.effect_params = {"chance_percent": 100}
		state._operator_data.target = enemy
		if mode in ["normal", "dodge", "block", "barrier"]:
			state.units.append(UnitState.new(1, 1, "target", Vector2i(13, 5), 100000, 0, 10000))
			state.next_unit_id = 2
			if mode == "barrier":
				state.units[1].physical_shield_hp = 10000
				state.units[1].physical_guard_ticks_left = 100
		elif mode == "box": state.tactical_boxes.append(TacticalBox.new(0, Vector2i(13, 5), 3))
		elif mode == "ball": state.ball.cell = Vector2i(13, 5)
		state.step([], [])
		check(source.attack_boost_stacks == (10 if mode == "none" else 9), "Consume every actual attack including%s" % mode)
		if mode == "normal": check(state.units[1].hp == 99581, "First attack25percent physical fold")
		if mode in ["dodge", "block", "barrier"]: check(state.units[1].hp == 100000, "Zero health damage still consumes%s" % mode)
		if mode == "ball": check(state.ball.accum.x == 1674, "Ball receives first boosted attack")
		if mode == "box": check(state.tactical_boxes[0].hits_left == 2, "Crate counts one attack")
		if mode == "none": check(source.last_attack_tick == -1, "No target is not an attack")
	var outcomes := {}
	for seed in [298, 299, 255]:
		for facing in 4:
			var state := fixture(2, seed)
			state.units = [UnitState.new(0, 1, "target", Vector2i(13, 5), 100000, 0, 10000), UnitState.new(1, 1, "target", Vector2i(12, 6), 100000, 0, 10000), UnitState.new(2, 1, "target", Vector2i(14, 5), 100000, 0, 10000)]
			state.next_unit_id = 3
			state.ball.cell = Vector2i(11, 5)
			state.tactical_boxes.append(TacticalBox.new(0, Vector2i(11, 6), 3))
			state.step([deploy(state, "phantom", Vector2i(12, 5), facing)], [])
			var source := state.units[3]
			outcomes[source.deploy_control_kind] = true
			check(state.units[0].hp == 99581 and state.units[1].hp == 99581 and state.units[2].hp == 100000, "Three-times deployment attack only eight neighbor cells")
			for enemy in [state.units[0], state.units[1]]:
				check((enemy.slow_ticks_left == 135 if source.deploy_control_kind == 0 else enemy.bind_ticks_left == 135 if source.deploy_control_kind == 1 else enemy.stun_ticks_left == 135), "Whole deployment same135tick control")
			check(state.ball.accum == Vector2i.ZERO and state.tactical_boxes[0].hits_left == 3 and state.units[0].cell == Vector2i(14, 5) and state.units[2].cell == Vector2i(15, 5), "Burst does not attack ball or crate; force1 moves the zero-weight rigid pair one cell")
	check(outcomes.size() == 3, "Seeds cover three control kinds")
	for field in ["attack_boost_stacks", "deploy_control_kind"]:
		var hash_state := fixture(1)
		hash_state.step([deploy(hash_state, "phantom", Vector2i(12, 5))], [])
		var before := hash_state.state_hash()
		hash_state.units[0].set(field, hash_state.units[0].get(field) + 1)
		check(hash_state.state_hash() != before, "New field participates in hash: " + field)
	for index in [1, 2]:
		var first := fixture(index)
		var replay := fixture(index)
		for tick in 600:
			var commands: Array[InputCommand] = []
			if tick == 0: commands.append(deploy(first, "phantom", Vector2i(12, 5)))
			if tick == 1: commands.append(deploy(first, "phantom_clone", Vector2i(13, 5)))
			first.step(commands, [])
			replay.step(commands, [])
			check(first.state_hash() == replay.state_hash(), "Replay skill%d tick%d" % [index, tick])
	var importer := GDScript.new()
	importer.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	check(importer.reload() == OK, "Importer compiles")
	var imported := {}
	for file in DirAccess.get_files_at("res://resources/operators"):
		if file.ends_with(".tres"):
			var op := load("res://resources/operators/" + file).duplicate(true) as OperatorData
			op.skills.resize(1)
			imported[op.operator_id] = op
	check(importer.new()._append_skills(imported), "CSV imports")
	for index in [1, 2]: check(imported.phantom.skills[index].effect_params == data.phantom.skills[index].effect_params, "Resource/CSV match")
	print("Phantom skills: stacks/actions/zero damage/box/ball, burst/control3/range4, clone and600tick replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func fixture(index: int, seed: int = 123) -> MatchState:
	var state := MatchState.new(seed, data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [["phantom"], ["phantom"]], [[index], [index]])
	state.sides[0].cost = 99
	state.sides[1].cost = 99
	state.ball.cell = Vector2i(10, 10)
	return state


func deploy(state: MatchState, id: String, cell: Vector2i, facing: int = 0) -> InputCommand:
	return InputCommand.new(state.tick, InputCommand.Kind.DEPLOY, id, -1, cell, -1, facing)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
