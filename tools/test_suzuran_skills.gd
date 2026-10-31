extends SceneTree

const CONFIG := preload("res://data/config.gd")
var failures := 0
var data := {}


func _initialize() -> void:
	for id in ["suzuran", "bagpipe", "phantom"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var suzuran: OperatorData = data["suzuran"]
	check(suzuran.skills.size() == 3 and suzuran.attack == 521, "Three skills, unchanged raw attack")
	check(suzuran.skills[1].initial_sp == 0 and suzuran.skills[1].sp_required == 80 and suzuran.skills[1].duration == -1.0, "S2M3 0/80/infinite")
	check(suzuran.skills[2].initial_sp == 50 and suzuran.skills[2].sp_required == 70 and suzuran.skills[2].duration == 35.0 and suzuran.skills[2].parameters_are_valid(), "S3M3 50/70/35s valid")
	var s := solo(1)
	for id in 4:
		s.units.append(UnitState.new(id + 1, 1, "bagpipe", Vector2i(12 + id % 2, 4 + id / 2), 10000, 0, 10000))
	s.units[0].sp = 80
	s.units[0].attack_ticks_left = 1
	s.step([], [])
	check(s.units[0].skill_ticks_left == -2 and SkillRules.attack_value(s.units[0], suzuran) == 834, "S2 auto activates as persistent additive ATK60")
	var damaged := 0
	for target in s.units:
		if target.side == 1 and target.hp < 10000:
			damaged += 1
	check(damaged == 3, "S2 attacks exactly three unique enemies")
	for _tick in 300:
		s.step([], [])
	check(s.units[0].skill_ticks_left == -2 and s.units[0].sp == 0, "S2 stays active, no recharge or one-shot reset")
	var b := solo(1)
	b.ball.cell = Vector2i(13, 5)
	b.units[0].sp = 80
	b.units[0].attack_ticks_left = 1
	b.step([], [])
	check(b.ball.accum == Vector2i(834, 0), "S2 ball is one raw push, no triple shot")
	var f := solo(2)
	f.units[0].hp = 500
	f.units.append(UnitState.new(1, 1, "bagpipe", Vector2i(15, 5), 10000, 0, 10000))
	f.units.append(UnitState.new(2, 0, "phantom_clone", Vector2i(13, 5), 500, 0, 10000))
	f.units.append(UnitState.new(3, 0, "nightingale_phantom", Vector2i(12, 6), 5000, 0, 10000))
	f.units[0].sp = 70
	var activation: Array[InputCommand] = [InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)]
	f.step(activation, [])
	check(f.units[0].skill_ticks_left == 1049 and f.units[0].last_attack_tick == -1 and f.ball.accum == Vector2i.ZERO, "S3 manual stop attack, no push")
	check(AttackRange.effective_offsets(f.units[0], suzuran).size() == 23 and f._fragile_damage_percent(f.units[1]) == 140 and f.units[1].slow_ticks_left == 1, "S3 expanded23, continuous marker, fragile40")
	check(SkillRules.attack_interval_ticks(f.units[1], data["bagpipe"]) == 30, "Marker never reduces attack speed")
	for _tick in 29:
		f.step([], [])
	check(f.units[0].hp == 500 and f.units[0].skill_regen_attack == 0, "First30ticks no regeneration")
	for _tick in 30:
		f.step([], [])
	check(f.units[0].hp == 552 and f.units[2].hp == 552 and f.units[3].hp == 4692, "Next second52HP with fraction, includes self/clone/phantom; phantom independent180HP/s loss")
	check(f.units[0].skill_hp_regen_accum == 30000, "52.1/s keeps0.1 fractional HP")
	for field in ["skill_elapsed_ticks", "skill_regen_attack", "skill_hp_regen_accum"]:
		var before := f.state_hash()
		f.units[0].set(field, f.units[0].get(field) + 1)
		check(before != f.state_hash(), "Hash includes " + field)
		f.units[0].set(field, f.units[0].get(field) - 1)
	for facing in 4:
		f.units[0].facing = facing
		check(f._is_in_attack_range(f.units[0], f.units[0].cell + AttackRange.rotate_offset(Vector2i(3, 0), facing), AttackRange.effective_offsets(f.units[0], suzuran)), "S3 range rotates facing%d" % facing)
	f.units[0].facing = 0
	f.units[0].skill_ticks_left = 1
	f.step([], [])
	check(f.units[0].skill_ticks_left == 0 and f.units[0].skill_elapsed_ticks == 0 and f.units[0].skill_regen_attack == 0 and AttackRange.effective_offsets(f.units[0], suzuran).size() == 12 and f._fragile_damage_percent(f.units[1]) == 100, "Expiry restores base range and removes expanded fragile")
	f.step([InputCommand.new(f.tick, InputCommand.Kind.RETREAT, "", 0)], [])
	check(f.units[0].unit_id == 1 and f._fragile_damage_percent(f.units[0]) == 100, "Retreat removes source")
	var fresh := UnitState.new(9, 0, "suzuran", Vector2i(12, 5), 1480, 50, 57, 0, 2)
	check(fresh.skill_elapsed_ticks == 0 and fresh.skill_regen_attack == 0 and fresh.skill_hp_regen_accum == 0 and fresh.skill_ticks_left == 0, "New deployment resets all skill runtime")
	var a := solo(2)
	var c := solo(2)
	for state in [a, c]:
		state.units[0].sp = 70
		state.units[0].hp = 500
	for t in 1100:
		var commands: Array[InputCommand] = []
		if t == 0:
			commands = activation
		a.step(commands, [])
		c.step(commands, [])
		check(a.state_hash() == c.state_hash(), "Every-tick replay %d" % t)
	var importer_script := GDScript.new()
	importer_script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	check(importer_script.reload() == OK, "Importer compiles")
	var imported := {}
	for file in DirAccess.get_files_at("res://resources/operators"):
		if file.ends_with(".tres"):
			var resource := load("res://resources/operators/" + file) as OperatorData
			imported[resource.operator_id] = resource.duplicate(true)
			imported[resource.operator_id].skills.resize(1)
	check(importer_script.new()._append_skills(imported), "Additional CSV imports")
	check(imported["suzuran"].skills[2].attack_range_override == suzuran.skills[2].attack_range_override and imported["suzuran"].skills[1].effect_params == suzuran.skills[1].effect_params, "CSV/resources typed params match")
	var invalid := suzuran.skills[2].duplicate(true) as SkillResource
	invalid.effect_params["regen_attack_percent"] = 20.5
	check(not invalid.parameters_are_valid(), "Reject fractional percent")
	print("Suzuran S2/S3 verified: failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func solo(index: int) -> MatchState:
	var state := MatchState.new(123, data)
	state.ball.cell = Vector2i(5, 5)
	state.units = [UnitState.new(0, 0, "suzuran", Vector2i(12, 5), 1480, 0, 10000, 0, index)]
	state.next_unit_id = 1
	return state


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
