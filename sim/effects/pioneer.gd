class_name PioneerRules
extends RefCounted


static func advance(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type == "instant_cost" and SkillRules.can_activate(unit, skill):
		SkillRules.activate(unit, data)
		state.sides[unit.side].cost = mini(state.CONFIG.COST_MAX, state.sides[unit.side].cost + int(skill.effect_params["cost_add"]))
		unit.skill_ticks_left = 0
	if not AttackTimeline.advance(state,unit):return
	var charged := skill.effect_type == "pioneer_hammer" and SkillRules.can_activate(unit, skill)
	var offsets := skill.attack_range_override if charged else data.attack_range
	var enemies: Array[UnitState] = []
	for target in state.units:
		if state.enemy_is_targetable(unit.side, target) and state._is_in_attack_range(unit, target.cell, offsets):
			enemies.append(target)
	if not charged and not enemies.is_empty():
		enemies=PusherRules.targets(state,unit,offsets,false).slice(0,1)
	enemies=AttackTimeline.pinned(state,unit,enemies)
	var box_target: TacticalBox
	if enemies.is_empty():
		for box in state.tactical_boxes:
			if state._is_in_attack_range(unit, box.cell, offsets):
				box_target = box
				break
	var ball_target := enemies.is_empty() and box_target == null and state.ball.move_ticks_left == 0 and state._is_in_attack_range(unit, state.ball.cell, offsets)
	if enemies.is_empty() and box_target == null and not ball_target:
		return
	if not AttackTimeline.windup(state,unit,data,enemies,enemies[0].cell if not enemies.is_empty() else (box_target.cell if box_target!=null else state.ball.cell)):return
	if charged:
		SkillRules.activate(unit, data)
		state.sides[unit.side].cost = mini(state.CONFIG.COST_MAX, state.sides[unit.side].cost + int(skill.effect_params["cost_add"]))
	var attack := SkillRules.attack_output_value(unit, data)
	unit.attack_ticks_left = SkillRules.attack_interval_ticks(unit, data)
	unit.last_attack_tick = state.tick
	unit.last_attack_is_heal = false
	var center := enemies[0].cell if not enemies.is_empty() else (box_target.cell if box_target != null else state.ball.cell)
	unit.last_attack_target_x = center.x
	unit.last_attack_target_y = center.y
	if charged:
		enemies = []
		for target in state.units:
			if target.hp > 0 and StainlessRules.is_damage_target(unit,target) and target.operator_id != "weedy_cannon" and state._is_in_attack_range(unit, target.cell, offsets):
				enemies.append(target)
	for target in enemies:
		var target_data: OperatorData = state._operator_data[target.operator_id]
		var damage := Combat.calculate_damage(attack, SkillRules.defense_value(target, target_data), SkillRules.magic_resist_value(target, target_data), "physical", SkillRules.dodge_chance(target, target_data, "physical"), state.rng, data.profession_id, state._damage_taken_percent(target, "physical"))
		var hit := state._apply_damage(target, target_data, damage, "physical", unit)
		if hit and target.hp > 0 and SkillRules.active_ticks(unit) > 0 and skill.effect_type == "pioneer_skull" and state.rng.next_percent() < int(skill.effect_params["stun_chance_percent"]):
			var duration := int(skill.effect_params["stun_ticks"])
			var resistant := StatusRules.has_resistance(state,target)
			StatusRules.add_control(state,target,"stun",duration * state.CONFIG.STATUS_RESISTANCE_DURATION_PERCENT / 100 if resistant else duration,unit)
	if box_target != null:
		TacticalRules.strike_box(state, unit, box_target)
	elif ball_target:
		state.ball.add_push(unit.cell, attack, state._ball_data, AttackRange.rotate_offset(Vector2i.RIGHT, unit.facing))
	if charged:
		unit.skill_ticks_left = 0


static func reward_deaths(state: MatchState) -> void:
	for dead in state.units:
		if dead.hp > 0:
			continue
		for source in state.units:
			var data: OperatorData = state._operator_data[source.operator_id]
			if source.hp <= 0 or source.side == dead.side or source.silence_ticks_left > 0 or data.talent_2.effect_type != "adjacent_death_sp":
				continue
			if absi(source.cell.x - dead.cell.x) + absi(source.cell.y - dead.cell.y) == 1:
				source.sp = mini(SkillRules.sp_limit(data.skills[source.skill_index]), source.sp + int(data.talent_2.effect_params["sp_add"]))
