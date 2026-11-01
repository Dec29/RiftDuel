extends SceneTree

var failures := 0
var data := {}


func _initialize() -> void:
	data.horn = load("res://resources/operators/horn.tres")
	var enemy := data.horn.duplicate(true) as OperatorData
	enemy.operator_id = "target"
	enemy.max_health = 100000
	enemy.defense = 0
	enemy.talent_1.effect_type = ""
	enemy.talent_2.effect_type = ""
	data.target = enemy
	check(data.horn.skills.size() == 3 and data.horn.skills[1].skill_name == "暴风号令" and data.horn.skills[2].skill_name == "终极防线", "Three original named skills")
	for index in [1, 2]: check(data.horn.skills[index].parameters_are_valid(), "Typed resource index%d" % index)
	for facing in 4:
		var state := fixture(1, facing)
		var target := state.units[0].cell + AttackRange.rotate_offset(Vector2i(3, 0), facing)
		state.units.append(UnitState.new(1, 1, "target", target, 100000, 0, 10000))
		state.units.append(UnitState.new(2, 1, "target", target - AttackRange.rotate_offset(Vector2i.RIGHT, facing), 100000, 0, 10000))
		state.next_unit_id = 3
		state.units[0].sp = 25
		state.units[0].attack_ticks_left = 1
		state.step([skill_command(state, 1)], [])
		check(state.units[0].skill_ammo_left == 9 and state.units[1].hp == 99542 and state.units[2].hp == 99542, "S2 first round physical splash including blind zone facing%d" % facing)
		for shot in 4:
			state.units[0].attack_ticks_left = 1
			state.step([], [])
		check(state.units[0].skill_ammo_left == 5 and state.units[1].hp == 97710, "First five rounds do not receive overload magic")
		state.units[0].hp = 1000
		state.step([skill_command(state, 1)], [])
		check(state.units[0].hp == 400 and state.units[0].skill_ticks_left == 0 and state.units[0].skill_ammo_left == 0 and state.units[1].hp == 94845, "Five-round dump caches physical attack, magic packets and currentHP60percent cost facing%d" % facing)
	var box := fixture(1)
	box.units[0].skill_ticks_left = -2
	box.units[0].skill_ammo_left = 5
	box.tactical_boxes = [TacticalBox.new(0, Vector2i(15, 5), 3)]
	box.units[0].hp = 999
	box.step([skill_command(box, 1)], [])
	check(box.tactical_boxes.is_empty() and box.sides[0].tactical_items.reduce(func(a: int, b: int) -> int: return a + b, 0) == 1 and box.units[0].hp == 400 and box.units[0].skill_ticks_left == 0, "Crate counts each ammunition, third breaks once, floor currentHP cost")
	var none := fixture(1)
	none.units[0].skill_ticks_left = -2
	none.units[0].skill_ammo_left = 5
	none.units[0].hp = 1
	none.step([skill_command(none, 1)], [])
	check(none.units[0].hp == 1 and not none.units[0].bloodbath_used and none.units[0].skill_ticks_left == 0, "No target closes; currentHP floor cost cannot kill")
	var early := fixture(1)
	early.units[0].sp = 25
	early.step([skill_command(early, 1)], [])
	check(early.units[0].skill_ammo_left == 10 and early.units[0].skill_ticks_left == -2, "Without target ammo persists")
	early.step([skill_command(early, 1)], [])
	check(early.units[0].hp == 3067 and early.units[0].skill_ticks_left == 0, "Before overload close has no HP cost")
	for threshold in [100000, 2000]:
		var ball := fixture(1)
		ball._ball_data = MatchState.DEFAULT_BALL_DATA.duplicate(true)
		ball._ball_data.kick_threshold = threshold
		ball.ball.cell = Vector2i(15, 5)
		ball.units[0].skill_ticks_left = -2
		ball.units[0].skill_ammo_left = 5
		ball.step([skill_command(ball, 1)], [])
		check(ball.units[0].skill_ammo_left == 0 and ball.units[0].skill_ticks_left == 0, "Dump spends entire recorded magazine")
		check(ball.ball.accum == Vector2i(13480, 0) if threshold == 100000 else ball.ball.move_ticks_left > 0, "Ball receives only physical per-round pushes and stops hits once moving")
	var s3 := fixture(2)
	var thorns := load("res://resources/operators/hoshiguma.tres").duplicate(true) as OperatorData
	thorns.operator_id = "thorns"
	thorns.max_health = 100000
	thorns.attack = 100000
	thorns.defense = 0
	thorns.talent_1.effect_type = ""
	thorns.talent_2.effect_type = ""
	data.thorns = thorns
	var reflected := fixture(1)
	var caster := reflected.units[0]
	caster.skill_ticks_left = -2
	caster.skill_ammo_left = 5
	caster.hp = 500
	reflected.ball.cell = Vector2i(17, 5)
	var reflector := UnitState.new(1, 1, "thorns", Vector2i(17, 4), 100000, 0, 10000, 0, 1)
	var bystander := UnitState.new(2, 1, "target", Vector2i(18, 5), 100000, 0, 10000)
	reflected.units.append(reflector)
	reflected.units.append(bystander)
	reflected.step([skill_command(reflected, 1)], [])
	check(caster.bloodbath_used and caster.hp <= 0 and bystander.hp == 99542, "Ball splash resolves physical IDs before magical IDs; source death stops extra packets")
	s3.units[0].sp = 35
	s3.step([skill_command(s3, 2)], [])
	check(SkillRules.attack_value(s3.units[0], data.horn) == 1778 and SkillRules.attack_interval_ticks(s3.units[0], data.horn) == 30, "S3 additive talent/70percent and base interval minus1.8")
	for tick in 358: s3.step([], [])
	check(s3.units[0].skill_elapsed_ticks == 359 and s3.units[0].hp == 3067, "First half has no life loss")
	s3.step([], [])
	check(s3.units[0].skill_elapsed_ticks == 360 and SkillRules.attack_value(s3.units[0], data.horn) == 2434 and s3.units[0].hp == 3067, "360tick overload boundary")
	var oracle := 0
	var total_loss := 0
	for tick in 360:
		s3.step([], [])
		if (tick + 1) % 6 == 0:
			oracle += 3067 * 12 * (tick + 1) * 6
			total_loss += oracle / 1080000
			oracle %= 1080000
	check(s3.units[0].hp == 3067 - total_loss and s3.units[0].skill_ticks_left == 0 and SkillRules.attack_value(s3.units[0], data.horn) == 1123 and SkillRules.attack_interval_ticks(s3.units[0], data.horn) == 84, "720ticks exact0.2s linear current-maxHP drain and expiration")
	var interrupted := fixture(2)
	interrupted.units[0].sp = 35
	interrupted.step([skill_command(interrupted, 2)], [])
	interrupted.units[0].skill_elapsed_ticks = 365
	interrupted.units[0].skill_ticks_left = 355
	interrupted.units[0].hp = 1
	interrupted.units[0].barrier_hp.append(9999)
	interrupted.units[0].barrier_ticks_left.append(1000)
	interrupted.units[0].barrier_defense_percent.append(0)
	interrupted.units[0].barrier_magic_only.append(0)
	interrupted.units[0].barrier_magic_resist_add.append(0)
	interrupted.step([], [])
	check(interrupted.units[0].bloodbath_used and interrupted.units[0].hp == 1534 and interrupted.units[0].barrier_hp[0] == 9999, "Life loss skips barrier and triggers one bloodbath")
	interrupted.step([skill_command(interrupted, 2)], [])
	var saved_hp := interrupted.units[0].hp
	for tick in 12: interrupted.step([], [])
	check(interrupted.units[0].hp == saved_hp and interrupted.units[0].skill_ticks_left == 0 and SkillRules.attack_interval_ticks(interrupted.units[0], data.horn) == 71, "Manual close stops drain and retains bloodbath speed")
	for index in [1, 2]:
		var first := fixture(index)
		var replay := fixture(index)
		first.units[0].sp = data.horn.skills[index].sp_required
		replay.units[0].sp = first.units[0].sp
		for tick in 900:
			var commands: Array[InputCommand] = []
			if tick == 0: commands.append(skill_command(first, index))
			first.step(commands, [])
			replay.step(commands, [])
			check(first.state_hash() == replay.state_hash(), "Replay index%d tick%d" % [index, tick])
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
	for index in [1, 2]: check(imported.horn.skills[index].effect_params == data.horn.skills[index].effect_params, "Typed resource/CSV match")
	print("Horn S2/S3: ammo/overload/dump/currentHP cost, splash/box/ball, linear drain/bloodbath/close, CSV and900tick replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func fixture(index: int, facing: int = 0) -> MatchState:
	var state := MatchState.new(123, data)
	state.units = [UnitState.new(0, 0, "horn", Vector2i(12, 5), 3067, 0, 10000, facing, index)]
	state.next_unit_id = 1
	state.ball.cell = Vector2i(5, 5)
	return state


func skill_command(state: MatchState, index: int) -> InputCommand:
	return InputCommand.new(state.tick, 1, "", 0, Vector2i.ZERO, index)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
