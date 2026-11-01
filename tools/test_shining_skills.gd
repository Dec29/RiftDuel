extends SceneTree

var failures := 0
var data := {}


func _initialize() -> void:
	for id in ["shining", "bagpipe", "phantom"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var shining: OperatorData = data["shining"]
	check(shining.skills.size() == 3 and shining.attack == 530 and shining.defense == 138, "Three skills, original raw values")
	var s := fixture(1)
	check(SkillRules.sp_limit(shining.skills[1]) == 15 and shining.skills[1].parameters_are_valid(), "S2 3charges, 5SP each")
	for _tick in 450:
		s.step([], [])
	check(s.units[0].sp == 15 and s.units[0].skill_ticks_left == 0 and s.units[1].barrier_hp.is_empty(), "FullHP allies do not trigger; cap15")
	s.units[1].hp = 1000
	s.units[2].hp = 1000
	s.units[0].attack_ticks_left = 1
	s.step([], [])
	check(s.units[0].sp == 10 and s.units[1].hp == 1265 and s.units[1].barrier_hp == PackedInt32Array([265]) and s.units[2].barrier_hp.is_empty(), "LowestHP fraction then lowestID, one charge,265 heal/265 barrier")
	check(s.units[1].barrier_ticks_left == PackedInt32Array([90]) and SkillRules.defense_value(s.units[1], data["bagpipe"]) == 663, "90tick shield, (382+60)*1.5=663DEF")
	s.units[2].hp = 2484
	s.units[0].attack_ticks_left = 1
	s.step([], [])
	check(s.units[1].barrier_hp == PackedInt32Array([265, 265]) and s.units[1].barrier_ticks_left == PackedInt32Array([89, 90]) and SkillRules.defense_value(s.units[1], data["bagpipe"]) == 663, "Independent stacking shields, defense max50 not100")
	for type in ["physical", "magical", "true"]:
		var t := fixture(1)
		t.units[1].barrier_hp = PackedInt32Array([100, 200])
		t.units[1].barrier_ticks_left = PackedInt32Array([20, 30])
		t.units[1].barrier_defense_percent = PackedInt32Array([50, 50])
		t.units[1].barrier_magic_only = PackedInt32Array([0, 0])
		t.units[1].barrier_magic_resist_add = PackedInt32Array([0, 0])
		var hp := t.units[1].hp
		check(not t._apply_damage(t.units[1], data["bagpipe"], 150, type) and t.units[1].hp == hp and t.units[1].barrier_hp == PackedInt32Array([0, 150]) and t.units[1].last_damage_tick == -1, "All-damage barrier oldest first, full absorption blocked: " + type)
		check(t._apply_damage(t.units[1], data["bagpipe"], 200, type) and t.units[1].hp == hp - 50, "Only overflow50 entersHP: " + type)
	var p := fixture(1)
	p.units[1].physical_shield_hp = 300
	p.units[1].physical_guard_ticks_left = 90
	p.units[1].barrier_hp = PackedInt32Array([100])
	p.units[1].barrier_ticks_left = PackedInt32Array([90])
	p.units[1].barrier_defense_percent = PackedInt32Array([50])
	p.units[1].barrier_magic_only = PackedInt32Array([0])
	p.units[1].barrier_magic_resist_add = PackedInt32Array([0])
	p._apply_damage(p.units[1], data["bagpipe"], 150, "magical")
	check(p.units[1].hp == 2434 and p.units[1].physical_shield_hp == 300, "Magic bypasses Phantom physical shield, barrier still absorbs100")
	s.units[0].attack_ticks_left = 10000
	for _tick in 89:
		s.step([], [])
	check(s.units[1].barrier_hp.size() == 1 and s.units[1].barrier_ticks_left[0] == 1, "First shield expires independently")
	s.step([], [])
	check(s.units[1].barrier_hp.is_empty() and SkillRules.defense_value(s.units[1], data["bagpipe"]) == 442, "Last shield expiry restoresDEF")
	var retained := fixture(1)
	retained.units[0].sp = 5
	retained.units[1].hp = 1000
	retained.units[0].attack_ticks_left = 1
	retained.step([], [])
	retained._apply_damage(retained.units[1], data["bagpipe"], 265, "true")
	check(retained.units[1].barrier_hp[0] == 0 and SkillRules.defense_value(retained.units[1], data["bagpipe"]) == 663, "Depleted barrier retainsDEF50 until its own expiry")
	retained.step([InputCommand.new(retained.tick, InputCommand.Kind.RETREAT, "", 0)], [])
	check(retained.units[0].barrier_ticks_left[0] == 89 and SkillRules.defense_value(retained.units[0], data["bagpipe"]) == 573, "Caster retreat removes flat60 but retains granted DEF50")
	for _tick in 89:
		retained.step([], [])
	check(retained.units[0].barrier_hp.is_empty() and SkillRules.defense_value(retained.units[0], data["bagpipe"]) == 382, "Depleted barrier DEF expires at original90tick deadline")
	var a := fixture(2)
	a.units[0].sp = 120
	a.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
	check(a.units[0].skill_ticks_left == 1799 and SkillRules.attack_value(a.units[0], shining) == 795 and SkillRules.defense_value(a.units[1], data["bagpipe"]) == 884 and SkillRules.defense_value(a.units[0], shining) == 396, "S3 additive ATK50/DEF100 including self")
	a.units[0].skill_ticks_left = 1
	a.step([], [])
	check(a.units[1].skill_defense_bonus_percent == 0 and SkillRules.defense_value(a.units[1], data["bagpipe"]) == 442, "S3 expiry removes cached aura immediately")
	a.units[0].sp = 120
	a.step([InputCommand.new(a.tick, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
	a.step([InputCommand.new(a.tick, InputCommand.Kind.RETREAT, "", 0)], [])
	check(a.units[0].skill_defense_bonus_percent == 0 and SkillRules.defense_value(a.units[0], data["bagpipe"]) == 382, "Retreat removes both60 flat and100percent")
	var hash_state := fixture(1)
	hash_state.units[1].barrier_hp = PackedInt32Array([100])
	hash_state.units[1].barrier_ticks_left = PackedInt32Array([90])
	hash_state.units[1].barrier_defense_percent = PackedInt32Array([50])
	hash_state.units[1].barrier_magic_only = PackedInt32Array([0])
	hash_state.units[1].barrier_magic_resist_add = PackedInt32Array([0])
	for field in ["barrier_hp", "barrier_ticks_left", "barrier_defense_percent"]:
		var before := hash_state.state_hash()
		var values: PackedInt32Array = hash_state.units[1].get(field)
		values[0] += 1
		hash_state.units[1].set(field, values)
		check(before != hash_state.state_hash(), "Queue participates in hash " + field)
	var first := fixture(1)
	var second := fixture(1)
	for t in 600:
		for state: MatchState in [first, second]:
			if t % 50 == 0:
				state._apply_damage(state.units[1], data["bagpipe"], 100, "true")
			state.step([], [])
		check(first.state_hash() == second.state_hash(), "600tick replay " + str(t))
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
	check(imported["shining"].skills[1].effect_params == shining.skills[1].effect_params and imported["shining"].skills[2].effect_params == shining.skills[2].effect_params, "Typed resource equalsCSV")
	var invalid := shining.skills[1].duplicate(true) as SkillResource
	invalid.effect_params["barrier_duration_ticks"] = 0
	check(not invalid.parameters_are_valid(), "Rejectzero shield duration")
	print("Shining S2/S3 verified: failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func fixture(index: int) -> MatchState:
	var state := MatchState.new(123, data)
	state.ball.cell = Vector2i(5, 5)
	state.units = [UnitState.new(0, 0, "shining", Vector2i(12, 5), 1613, 0, 10000, 0, index), UnitState.new(1, 0, "bagpipe", Vector2i(13, 5), 2484, 0, 10000), UnitState.new(2, 0, "bagpipe", Vector2i(14, 5), 2484, 0, 10000)]
	state.next_unit_id = 3
	return state


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
