extends SceneTree

var failures := 0
var data := {}


func _initialize() -> void:
	data["blaze"] = load("res://resources/operators/blaze.tres")
	var dummy := (data["blaze"] as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id = "target"
	dummy.max_health = 100000
	dummy.defense = 100
	dummy.branch_trait.effect_type = ""
	dummy.talent_1.effect_type = ""
	dummy.talent_2.effect_type = ""
	data["target"] = dummy
	var blaze: OperatorData = data["blaze"]
	check(blaze.skills.size() == 3 and blaze.max_health == 2821 and blaze.attack == 765 and blaze.defense == 370, "Raw E2 stats and three skills")
	check(blaze.skills[1].parameters_are_valid() and blaze.skills[2].parameters_are_valid(), "New resources valid")
	var s := fixture(1)
	for _t in 2100:
		s.step([], [])
	check(s.units[0].skill_ticks_left == -2 and s.units[0].sp == 0 and SkillRules.attack_value(s.units[0], blaze) == 1530 and SkillRules.defense_value(s.units[0], blaze) == 500, "S2 70seconds auto, permanent ATK100 DEF35")
	check(AttackRange.effective_offsets(s.units[0], blaze) == [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)], "S2 forward two range")
	for _t in 60:
		s.step([], [])
	check(s.units[0].skill_ticks_left == -2 and s.units[0].sp == 0, "No expiry, no reactivation or SP during permanent skill")
	for facing in 4:
		var b := fixture(1, facing)
		b.units[0].sp = 70
		b.units[0].attack_ticks_left = 1
		b.ball.cell = b.units[0].cell + AttackRange.rotate_offset(Vector2i(2, 0), facing)
		b.step([], [])
		check(b.ball.accum == AttackRange.rotate_offset(Vector2i(1530, 0), facing), "S2 raw push once facing%d" % facing)
		var box := fixture(1, facing)
		box.units[0].sp = 70
		box.units[0].attack_ticks_left = 1
		box.tactical_boxes = [TacticalBox.new(0, box.units[0].cell + AttackRange.rotate_offset(Vector2i(2, 0), facing), 3)]
		box.step([], [])
		check(box.tactical_boxes[0].hits_left == 2, "S2 one box hit facing%d" % facing)
		var a := fixture(2, facing)
		a.units[0].sp = 35
		for offset in [Vector2i(1, 0), Vector2i(2, 1), Vector2i(-1, 0)]:
			a.units.append(UnitState.new(a.units.size(), 1, "target", a.units[0].cell + AttackRange.rotate_offset(offset, facing), 100000, 0, 10000, 0))
		a.next_unit_id = 4
		a.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
		check(a.units[0].skill_elapsed_ticks == 1 and a.units[0].skill_ticks_left == 299 and a.units[1].hp == 100000, "S3 manual, no immediate pulse")
		var total_damage := 0
		for elapsed in range(2, 271):
			a.step([], [])
			if elapsed % 30 == 0:
				var stage := elapsed / 30
				var attack := 765 + stage * 68
				var damage := roundi((attack * (4 if stage == 9 else 1) - 70) * 0.4)
				total_damage += damage
				check(SkillRules.attack_value(a.units[0], blaze) == attack and SkillRules.defense_value(a.units[0], blaze) == roundi(370 * (1 + 0.8 * stage / 9)), "S3 staged attributes %d facing%d" % [stage, facing])
				check(a.units[1].hp == 100000 - total_damage, "S3 pulse/terminal damage guard coefficient at%d" % elapsed)
				check(a.units[2].hp == (97825 if stage == 9 else 100000) and a.units[3].hp == 100000, "Burst distinct forward3x3, excludes back")
		check(a.units[0].hp == 2116 and not a.units[0].emergency_heal_used and a.units[0].skill_elapsed_ticks == 270, "At9s maxHP25 loss705 before burst, no damage talent")
		for _t in 29:
			a.step([], [])
		check(a.units[0].skill_ticks_left == 1 and a.units[0].skill_elapsed_ticks == 299 and a.units[1].hp == 100000 - total_damage, "No repeat burst, buffs last until10s")
		a.step([], [])
		check(a.units[0].skill_ticks_left == 0 and a.units[0].skill_elapsed_ticks == 0 and SkillRules.attack_value(a.units[0], blaze) == 765 and SkillRules.defense_value(a.units[0], blaze) == 370, "Expiry restores attrs and elapsed")
	var loss := fixture(2)
	loss.units[0].sp = 35
	loss.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
	loss.units[0].hp = 1000
	loss.units[0].barrier_hp = PackedInt32Array([1000])
	loss.units[0].barrier_ticks_left = PackedInt32Array([500])
	loss.units[0].barrier_defense_percent = PackedInt32Array([50])
	loss.units[0].barrier_magic_only = PackedInt32Array([0])
	loss.units[0].barrier_magic_resist_add = PackedInt32Array([0])
	loss.units[0].skill_elapsed_ticks = 269
	loss.step([], [])
	check(loss.units[0].hp == 1706 and loss.units[0].barrier_hp[0] == 1000 and loss.units[0].emergency_heal_used and loss.units[0].hp_lock_ticks_left == 179, "705 self loss triggers1411 emergency heal without consuming shield")
	loss.units[0].hp = 1500
	loss.units[0].skill_elapsed_ticks = 269
	loss.step([], [])
	check(loss.units[0].hp == 1411 and loss.units[0].barrier_hp[0] == 1000, "Existing HP protection limits loss to floor1411")
	loss.units[0].hp = 100
	loss.units[0].hp_lock_ticks_left = 0
	loss.units[0].skill_elapsed_ticks = 269
	loss.step([], [])
	check(loss.units[0].hp == 1 and loss.units[0].emergency_heal_used, "Used emergency talent does not repeat; self loss remains nonfatal")
	for facing in 4:
		var pulse := fixture(2, facing)
		pulse.units[0].sp = 35
		pulse.ball.cell = pulse.units[0].cell + AttackRange.rotate_offset(Vector2i.RIGHT, facing)
		pulse.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
		pulse.units[0].skill_elapsed_ticks = 29
		pulse.step([], [])
		check(pulse.ball.accum == AttackRange.rotate_offset(Vector2i(833, 0), facing), "Cut pushes once with raw staged ATK facing%d" % facing)
		var burst := fixture(2, facing)
		burst.units[0].sp = 35
		burst.ball.cell = burst.units[0].cell + AttackRange.rotate_offset(Vector2i(2, 0), facing)
		burst.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
		burst.units[0].skill_elapsed_ticks = 269
		burst.step([], [])
		check(burst.ball.move_direction == AttackRange.rotate_offset(Vector2i.RIGHT, facing) and burst.ball.move_ticks_left > 0 and burst.ball.accum == Vector2i.ZERO, "5508 burst push exceeds2000 kick threshold facing%d" % facing)
		var exact := fixture(2, facing)
		exact._ball_data = MatchState.DEFAULT_BALL_DATA.duplicate(true)
		exact._ball_data.kick_threshold = 10000
		exact.units[0].sp = 35
		exact.ball.cell = exact.units[0].cell + AttackRange.rotate_offset(Vector2i(2, 0), facing)
		exact.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
		exact.units[0].skill_elapsed_ticks = 269
		exact.step([], [])
		check(exact.ball.accum == AttackRange.rotate_offset(Vector2i(5508, 0), facing), "Burst exact400percent raw push without PvP coefficient facing%d" % facing)
	var objects := fixture(2)
	objects.units[0].sp = 35
	objects.ball.cell = Vector2i(13, 5)
	objects.tactical_boxes = [TacticalBox.new(0, Vector2i(14, 6), 3)]
	objects.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
	objects.units[0].skill_elapsed_ticks = 269
	objects.step([], [])
	check(objects.ball.accum == Vector2i.ZERO and objects.ball.move_ticks_left == 0 and objects.tactical_boxes[0].hits_left == 2, "Burst prioritizes box over ball and counts one hit")
	objects.units.append(UnitState.new(1, 1, "target", Vector2i(14, 4), 100000, 0, 10000))
	objects.next_unit_id = 2
	objects.units[0].skill_elapsed_ticks = 269
	objects.step([], [])
	check(objects.units[1].hp == 97825 and objects.tactical_boxes[0].hits_left == 2 and objects.ball.accum == Vector2i.ZERO, "Enemy burst suppresses box hit and ball push")
	var crates := fixture(2)
	crates.units[0].sp = 35
	crates.tactical_boxes = [TacticalBox.new(0, Vector2i(13, 5), 3)]
	crates.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
	for elapsed in [29, 59, 89]:
		crates.units[0].skill_elapsed_ticks = elapsed
		crates.step([], [])
	check(crates.tactical_boxes.is_empty() and crates.sides[0].tactical_items.reduce(func(a: int, b: int) -> int: return a + b, 0) == 1 and crates.sides[1].tactical_items == [0, 0, 0, 0], "Three cuts destroy one box and award exactly one item to attacker")
	var stun := fixture(2)
	stun.units[0].sp = 35
	stun.units.append(UnitState.new(1, 1, "target", Vector2i(13, 5), 100000, 0, 10000))
	stun.next_unit_id = 2
	stun.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
	stun.units[0].stun_ticks_left = 300
	for _t in 269:
		stun.step([], [])
	check(stun.units[1].hp == 100000 and stun.units[0].hp == 2116 and stun.units[0].skill_elapsed_ticks == 270, "Approved stun suppresses damage, timing and scheduled loss continue")
	var withdrawn := fixture(2)
	withdrawn.units[0].sp = 35
	withdrawn.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
	withdrawn.step([InputCommand.new(withdrawn.tick, InputCommand.Kind.RETREAT, "", 0)], [])
	check(withdrawn.units.is_empty(), "Retreat clears active runtime")
	withdrawn.squad_skills[0][withdrawn.squad_ids[0].find("blaze")] = 2
	for _t in 2100:
		withdrawn.step([], [])
	withdrawn.step([InputCommand.new(withdrawn.tick, InputCommand.Kind.DEPLOY, "blaze", -1, Vector2i(12, 5), -1, 0)], [])
	check(withdrawn.units.size() == 1, "Actual redeploy after70s")
	if withdrawn.units.size() == 1:
		check(withdrawn.units[0].unit_id == 1 and withdrawn.units[0].skill_index == 2 and withdrawn.units[0].sp == 25 and withdrawn.units[0].skill_ticks_left == 0 and withdrawn.units[0].skill_elapsed_ticks == 0, "Redeploy fresh instance/initialSP, no old ramp")
	var death := fixture(2)
	death.units[0].sp = 35
	death.step([InputCommand.new(0, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2)], [])
	death.units[0].hp = 0
	death.step([], [])
	check(death.units.is_empty() and death.sides[0].cooldowns.get("blaze", 0) > 0, "Death cancels skill and starts redeploy cooldown")
	var first := fixture(2)
	var second := fixture(2)
	for t in 700:
		var commands: Array[InputCommand] = []
		if t in [300, 650]:
			commands.append(InputCommand.new(t, InputCommand.Kind.SKILL, "", 0, Vector2i.ZERO, 2))
		first.step(commands, [])
		second.step(commands, [])
		check(first.state_hash() == second.state_hash(), "700tick every-tick replay %d" % t)
	var before := first.state_hash()
	first.units[0].skill_elapsed_ticks += 1
	check(before != first.state_hash(), "Elapsed ramp participates in hash")
	var importer_script := GDScript.new()
	importer_script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	check(importer_script.reload() == OK, "Importer compiles")
	var imported := {}
	for file in DirAccess.get_files_at("res://resources/operators"):
		if file.ends_with(".tres"):
			var resource := load("res://resources/operators/" + file) as OperatorData
			imported[resource.operator_id] = resource.duplicate(true)
			imported[resource.operator_id].skills.resize(1)
	check(importer_script.new()._append_skills(imported), "CSV imports all existing skills")
	for index in [1, 2]:
		check(imported["blaze"].skills[index].effect_params == blaze.skills[index].effect_params and imported["blaze"].skills[index].attack_range_override == blaze.skills[index].attack_range_override and imported["blaze"].skills[index].burst_range_override == blaze.skills[index].burst_range_override, "Typed resource equals CSV %d" % index)
	var invalid := blaze.skills[2].duplicate(true) as SkillResource
	invalid.effect_params["pulse_interval_ticks"] = 0
	check(not invalid.parameters_are_valid(), "Reject zero ramp interval")
	invalid = blaze.skills[2].duplicate(true)
	invalid.burst_range_override.clear()
	check(not invalid.parameters_are_valid(), "Reject missing separate burst range")
	print("Blaze S2/S3 verified: failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func fixture(index: int, facing: int = 0) -> MatchState:
	var state := MatchState.new(123, data)
	state.ball.cell = Vector2i(5, 5)
	state.units = [UnitState.new(0, 0, "blaze", Vector2i(12, 5), 2821, 0, 10000, facing, index)]
	state.next_unit_id = 1
	return state


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
