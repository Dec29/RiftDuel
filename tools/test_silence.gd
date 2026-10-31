extends SceneTree

var failures := 0
var data := {}


func _initialize() -> void:
	for file in DirAccess.get_files_at("res://resources/operators"):
		if file.ends_with(".tres"):
			var op: OperatorData = load("res://resources/operators/" + file)
			data[op.operator_id] = op
	var buff := fixture("bagpipe", 2)
	var unit := buff.units[0]
	unit.sp = data.bagpipe.skills[2].sp_required
	buff.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)], [])
	check(SkillRules.attack_value(unit, data.bagpipe) > data.bagpipe.attack and SkillRules.block_count_value(unit, data.bagpipe) == 2, "Active attack and block boost")
	var remaining := unit.skill_ticks_left
	StatusRules.apply_silence(buff, unit, 30)
	check(SkillRules.attack_value(unit, data.bagpipe) == data.bagpipe.attack and SkillRules.block_count_value(unit, data.bagpipe) == 1 and not SkillRules.can_manually_activate(unit, data.bagpipe.skills[2]), "Silence disables skill, not base identity")
	for tick in 29: buff.step([], [])
	check(unit.skill_ticks_left == remaining - 29 and unit.silence_ticks_left == 1 and SkillRules.attack_value(unit, data.bagpipe) == data.bagpipe.attack, "Duration continues while effect pauses")
	buff.step([], [])
	check(unit.silence_ticks_left == 0 and SkillRules.attack_value(unit, data.bagpipe) > data.bagpipe.attack, "Surviving skill resumes")
	var expiry := fixture("bagpipe", 2)
	expiry.units[0].skill_ticks_left = 3
	StatusRules.apply_silence(expiry, expiry.units[0], 30)
	for tick in 30: expiry.step([], [])
	check(expiry.units[0].skill_ticks_left == 0 and SkillRules.attack_value(expiry.units[0], data.bagpipe) == data.bagpipe.attack, "Expired skill does not return")
	var shield := fixture("phantom", 0)
	shield.units[0].physical_shield_hp = 1000
	shield.units[0].physical_guard_ticks_left = 300
	StatusRules.apply_silence(shield, shield.units[0], 150)
	shield._apply_damage(shield.units[0], data.phantom, 100, "physical")
	check(shield.units[0].physical_shield_hp == 900 and shield.units[0].hp == 1645 and SkillRules.dodge_chance(shield.units[0], data.phantom, "physical") == 0, "Existing shield remains, passive dodge pauses")
	var stacks := fixture("phantom", 1)
	stacks.units[0].attack_boost_stacks = 10
	stacks.ball.cell = Vector2i(13,5)
	stacks.units[0].attack_ticks_left = 1
	StatusRules.apply_silence(stacks, stacks.units[0], 150)
	stacks.step([], [])
	check(stacks.units[0].attack_boost_stacks == 10 and stacks.ball.accum.x == 558, "Paused stacks grant no attack bonus and are not consumed")
	var flags := fixture("saileach", 0)
	flags.units[0].skill_ticks_left = 100
	flags.ball.cell = Vector2i(13,5)
	flags.units[0].attack_ticks_left = 1
	StatusRules.apply_silence(flags, flags.units[0], 150)
	flags.step([], [])
	check(SkillRules.block_count_value(flags.units[0], data.saileach) == 0 and flags.ball.accum == Vector2i.ZERO, "Standard-bearer branch remains, skill cost regen pauses")
	var slow := fixture("angelina", 2)
	slow.units[0].skill_ticks_left = 100
	slow.units.append(UnitState.new(1,1,"bagpipe",Vector2i(13,5),2000,0,10000))
	slow.next_unit_id = 2
	slow.units[0].attack_ticks_left = 1
	StatusRules.apply_silence(slow, slow.units[0],150)
	check(AttackRange.effective_offsets(slow.units[0],data.angelina).size() == 12 and DisplacementRules.effective_weight(slow,slow.units[1]) == 1, "Skill range and weight aura pause")
	slow.units[0].attack_ticks_left = 1
	slow.step([], [])
	check(slow.units[1].slow_ticks_left == 24, "Slow-on-hit branch remains while silenced")
	var regen := fixture("angelina", 1)
	regen.units[0].hp = 1000
	StatusRules.apply_silence(regen, regen.units[0],31)
	for tick in 30: regen.step([], [])
	check(regen.units[0].hp == 1000 and regen.units[0].sp == 1, "Own regen talent pauses, natural SP continues")
	var thorns := fixture("hoshiguma", 1)
	var original := SkillRules.defense_value(thorns.units[0],data.hoshiguma)
	StatusRules.apply_silence(thorns, thorns.units[0],150)
	check(SkillRules.defense_value(thorns.units[0],data.hoshiguma) == data.hoshiguma.defense and original > data.hoshiguma.defense, "Passive thorns and defense aura pause")
	var life := fixture("horn", 0)
	StatusRules.apply_silence(life, life.units[0],150)
	life._apply_damage(life.units[0],data.horn,100000,"true")
	check(life.units[0].hp <= 0 and not life.units[0].bloodbath_used, "Silence prevents new fatal revival")
	var received := fixture("shining",2)
	received.units[0].skill_ticks_left = 100
	received.units.append(UnitState.new(1,0,"bagpipe",Vector2i(13,5),2484,0,10000))
	received.next_unit_id = 2
	AuraRules.refresh(received)
	check(SkillRules.defense_value(received.units[1],data.bagpipe) == 884, "Live source grants defense skill aura and flat talent")
	StatusRules.apply_silence(received, received.units[1],150)
	check(SkillRules.defense_value(received.units[1],data.bagpipe) == 884, "Silenced recipient still receives external buffs")
	StatusRules.apply_silence(received, received.units[0],150)
	check(SkillRules.defense_value(received.units[1],data.bagpipe) == 382, "Silenced source loses both skill aura and talent")
	var merchant := fixture("swire_alter",0)
	merchant.sides[0].cost = 99
	merchant.units[0].coins = 0
	merchant.units[0].coin_attack_stacks = 0
	merchant.units[0].cost_drain_ticks = roundi(float(data.swire_alter.branch_trait.effect_params["drain_interval"]) * 30) - 1
	StatusRules.apply_silence(merchant, merchant.units[0],150)
	merchant.step([],[])
	check(merchant.sides[0].cost == 99 - int(data.swire_alter.branch_trait.effect_params["drain_amount"]) and merchant.units[0].coins == 0 and merchant.units[0].coin_attack_stacks == 0, "Merchant branch still drains, talent produces no coins or stacks")
	var squad := fixture("silverash",0)
	check(squad._redeploy_ticks(0,data.bagpipe) == 1890, "Off-field squad redeploy talent normally active")
	StatusRules.apply_silence(squad, squad.units[0],150)
	check(squad._redeploy_ticks(0,data.bagpipe) == 2100, "Present silenced squad owner suppresses new cooldown reduction")
	var guard := fixture("hoshiguma",0)
	var guaranteed := data.hoshiguma.duplicate(true) as OperatorData
	guaranteed.talent_1.effect_params["chance_percent"] = 100
	guard._operator_data.hoshiguma = guaranteed
	var guard_hp := guard.units[0].hp
	guard._apply_damage(guard.units[0],guaranteed,100,"true")
	check(guard.units[0].hp == guard_hp, "Guaranteed block fixture protects health")
	StatusRules.apply_silence(guard, guard.units[0],150)
	var rng_before := guard.rng.state
	guard._apply_damage(guard.units[0],guaranteed,100,"true")
	check(guard.units[0].hp == guard_hp - 100 and guard.rng.state == rng_before, "Silenced probability talent does not roll or block")
	var clock := fixture("horn",2)
	clock.units[0].skill_ticks_left = 100
	clock.units[0].skill_elapsed_ticks = 400
	StatusRules.apply_silence(clock, clock.units[0],31)
	var hp := clock.units[0].hp
	for tick in 30: clock.step([], [])
	check(clock.units[0].skill_elapsed_ticks == 430 and clock.units[0].skill_ticks_left == 70 and clock.units[0].hp == hp, "Overload elapsed clock continues but HP drain pauses")
	var ramp := fixture("blaze",2)
	ramp.units[0].skill_ticks_left = 100
	StatusRules.apply_silence(ramp, ramp.units[0],31)
	for tick in 30: ramp.step([], [])
	check(ramp.units[0].skill_elapsed_ticks == 30 and ramp.units[0].skill_ticks_left == 70, "Ramp elapsed clock continues")
	var first := fixture("bagpipe",2)
	var replay := fixture("bagpipe",2)
	for state in [first,replay]:
		state.units[0].skill_ticks_left = 100
		StatusRules.apply_silence(state, state.units[0],150)
	for tick in 300:
		first.step([],[])
		replay.step([],[])
		check(first.state_hash() == replay.state_hash(), "Silence replay tick%d" % tick)
	var before := first.state_hash()
	first.units[0].silence_ticks_left = 1
	check(first.state_hash() != before, "Silence timer participates in hash")
	print("Silence: pause/resume/expiry, clocks/SP, passive/talent suppression, branches and existing shields, replay; failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func fixture(id: String, index: int) -> MatchState:
	var state := MatchState.new(123,data)
	var op: OperatorData = data[id]
	state.units = [UnitState.new(0,0,id,Vector2i(12,5),op.max_health,0,10000,0,index)]
	state.next_unit_id = 1
	state.ball.cell = Vector2i(10,10)
	AuraRules.refresh(state)
	return state


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
