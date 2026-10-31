class_name TexasRules
extends RefCounted


static func activate(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	SkillRules.activate(unit,data)
	unit.skill_ticks_left=0
	unit.texas_cast_tick=state.tick
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(skill.effect_params["cost_add"]))
	var attack_value := roundi(SkillRules.attack_value(unit,data)*float(skill.effect_params["attack_mult"]))
	for wave in int(skill.effect_params["shot_count"]):
		for target in state.units:
			if target.hp<=0 or target.side==unit.side or target.operator_id in ["weedy_cannon","seaborn"] or not state._is_in_attack_range(unit,target.cell,skill.attack_range_override):continue
			var target_data: OperatorData=state._operator_data[target.operator_id]
			var damage := Combat.calculate_damage(attack_value,0,SkillRules.magic_resist_value(target,target_data),"magical",SkillRules.dodge_chance(target,target_data,"magical"),state.rng,data.profession_id,state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
			if state._apply_damage(target,target_data,damage,"magical",unit) and target.hp>0:SwordRules.stun(state,target,int(skill.effect_params["stun_ticks"]),unit)
		for box in state.tactical_boxes:
			if box.hits_left>0 and state._is_in_attack_range(unit,box.cell,skill.attack_range_override):TacticalRules.strike_box(state,unit,box)
		if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,skill.attack_range_override):state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
