extends SceneTree

var failures := 0


func _initialize() -> void:
	var caster: OperatorData = load("res://resources/operators/ceobe.tres")
	var target := caster.duplicate(true) as OperatorData
	target.operator_id = "target"
	target.max_health = 100000
	target.defense = 100
	target.talent_1.effect_type = ""
	target.talent_2.effect_type = ""
	var armored := target.duplicate(true) as OperatorData
	armored.operator_id = "armored"
	armored.defense = 1000
	var data := {"ceobe":caster,"target":target,"armored":armored}
	for index in [1,2]:
		for facing in 4:
			var state := MatchState.new(123,data)
			state.units = [UnitState.new(0,0,"ceobe",Vector2i(12,5),1565,0,1,facing,index),UnitState.new(1,1,"target",Vector2i(12,5)+AttackRange.rotate_offset(Vector2i(1,0),facing),100000,0,10000),UnitState.new(2,1,"armored",Vector2i(12,5)+AttackRange.rotate_offset(Vector2i(2,0),facing),100000,0,10000)]
			state.next_unit_id = 3
			state.ball.cell = Vector2i(10,10)
			state.units[0].sp = caster.skills[index].sp_required
			state.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,index)],[])
			var picked := state.units[2] if index == 1 else state.units[1]
			check(Vector2i(state.units[0].last_attack_target_x,state.units[0].last_attack_target_y) == picked.cell and picked.hp < 100000, "Actual defense priority and damage index%d facing%d" % [index,facing])
			check(SkillRules.attack_interval_ticks(state.units[0],caster) == (15 if index == 1 else 44) and SkillRules.attack_value(state.units[0],caster) == (720 if index == 1 else 2121), "M3 interval and additive attack bonus")
			check(SkillRules.damage_type(state.units[0],caster) == ("magical" if index == 1 else "physical") and AttackRange.effective_offsets(state.units[0],caster).size() == (10 if index == 1 else 12), "Active type and exact range")
			StatusRules.apply_silence(state, state.units[0],150)
			check(SkillRules.attack_value(state.units[0],caster) == 667 and SkillRules.damage_type(state.units[0],caster) == "magical" and AttackRange.effective_offsets(state.units[0],caster).size() == 10, "Own silence removes skill and isolated talent")
	var defender: OperatorData = load("res://resources/operators/hoshiguma.tres")
	var fortress: OperatorData = load("res://resources/operators/horn.tres")
	var phantom: OperatorData = load("res://resources/operators/phantom.tres")
	for enemy in [defender, fortress, phantom]:
		var state := MatchState.new(123, {"ceobe":caster, enemy.operator_id:enemy})
		state.ball.cell = Vector2i(10,10)
		state.units = [UnitState.new(0,0,"ceobe",Vector2i(12,5),1565,0,1,2,2), UnitState.new(1,1,enemy.operator_id,Vector2i(11,5),enemy.max_health,0,10000,0,1 if enemy == defender else 0)]
		state.next_unit_id = 2
		var victim := state.units[1]
		if enemy == fortress: victim.hp = 1
		if enemy == phantom:
			victim.physical_shield_hp = 10000
			victim.physical_guard_ticks_left = 300
		state.units[0].sp = caster.skills[2].sp_required
		state.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
		check(victim.silence_ticks_left == 150, "First strike applies silence before damage")
		check(state.units[0].hp == 1565, "First strike prevents reflection")
		if enemy == fortress: check(victim.hp <= 0 and not victim.bloodbath_used, "First strike prevents fatal revival")
		if enemy == phantom: check(victim.physical_shield_hp < 10000 and victim.physical_shield_hp > 0, "First strike retains existing shield")
		if enemy == defender:
			var expected := Combat.calculate_damage(2121,enemy.defense,enemy.magic_resist,"physical",0,RNG.new(123),"caster")
			var extra := Combat.calculate_damage(roundi(enemy.defense * 0.4),0,enemy.magic_resist,"magical",0,RNG.new(123),"caster")
			check(victim.hp == enemy.max_health - expected - extra, "First strike removes passive defense before both damage components")
			state.units[0].attack_ticks_left = 1
			state.step([],[])
			check(victim.silence_ticks_left == 150, "Repeat strike refreshes five seconds")
	print("Ceobe priority/interval/attack/type/range4, own silence and first-hit suppression/shields/refresh; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
