class_name NearlRules
extends RefCounted


static func advance(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="guardian_aid" and GuardianRules.advance(state,unit,data):return
	if unit.critical_ticks_left>0:return
	if not AttackTimeline.advance(state,unit):return
	if SkillRules.active_ticks(unit)>0 and skill.effect_type=="guardian_mode":
		var chosen: UnitState
		for ally in GuardianRules.targets(state,unit,data,false):
			if chosen==null or ally.hp*SkillRules.max_health_value(chosen,state._operator_data[chosen.operator_id])<chosen.hp*SkillRules.max_health_value(ally,state._operator_data[ally.operator_id]):chosen=ally
		chosen=AttackTimeline.heal_target(state,unit,chosen)
		if chosen!=null:
			var selected: Array[UnitState]=[chosen]
			if not AttackTimeline.windup(state,unit,data,selected,chosen.cell,true):return
			GuardianRules.heal_targets(state,unit,data,[chosen])
			unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
		return
	# The original base range is its own cell; blocked enemies remain valid targets.
	var target: UnitState
	for enemy in state.units:
		if not state.enemy_is_targetable(unit.side,enemy) or not (state._is_in_attack_range(unit,enemy.cell,data.attack_range) or state.enemy_is_blocked(enemy,unit.unit_id)):continue
		if target==null or SkillRules.taunt_level(enemy,state._operator_data[enemy.operator_id])>SkillRules.taunt_level(target,state._operator_data[target.operator_id]):target=enemy
	var candidates: Array[UnitState]=[]
	if unit.attack_intent!=null:candidates=PusherRules.targets(state,unit,data.attack_range,false,true)
	elif target!=null:candidates.append(target)
	candidates=AttackTimeline.pinned(state,unit,candidates)
	target=candidates[0] if not candidates.is_empty() else null
	var center:=target.cell if target!=null else AttackTimeline.object_cell(state,unit,data.attack_range)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,candidates,center):return
	if target!=null:
		var target_data: OperatorData=state._operator_data[target.operator_id]
		var damage := Combat.calculate_damage(SkillRules.attack_output_value(unit,data),SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target,"physical"))
		state._apply_damage(target,target_data,damage,"physical",unit)
		PusherRules.mark_attack(state,unit,target.cell)
		unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
		return
	for box in state.tactical_boxes:
		if state._is_in_attack_range(unit,box.cell,data.attack_range):
			TacticalRules.strike_box(state,unit,box);PusherRules.mark_attack(state,unit,box.cell);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data);return
	if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,data.attack_range):
		state.ball.add_push(unit.cell,SkillRules.attack_output_value(unit,data),state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
		PusherRules.mark_attack(state,unit,state.ball.cell);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
