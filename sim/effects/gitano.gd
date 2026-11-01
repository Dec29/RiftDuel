class_name GitanoRules
extends RefCounted


static func advance(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.critical_ticks_left>0:return
	if not AttackTimeline.advance(state,unit):return
	if unit.destiny_attack_stop_ticks>0:return
	var skill := data.skills[unit.skill_index]
	if SkillRules.active_ticks(unit)<=0 or skill.effect_type!="caster_destiny":
		SplashCasterRules.attack(state,unit,data,false,false,true)
		return
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets: Array[UnitState]=[]
	for target in state.units:
		if target.hp>0 and StainlessRules.is_damage_target(unit,target) and state.enemy_is_targetable(unit.side,target) and state._is_in_attack_range(unit,target.cell,offsets):targets.append(target)
	targets=AttackTimeline.pinned(state,unit,targets)
	var boxes: Array[TacticalBox]=[]
	for box in state.tactical_boxes:
		if box.hits_left>0 and state._is_in_attack_range(unit,box.cell,offsets):boxes.append(box)
	var ball_hit := state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,offsets)
	if targets.is_empty() and boxes.is_empty() and not ball_hit:return
	var center:=targets[0].cell if not targets.is_empty() else (boxes[0].cell if not boxes.is_empty() else state.ball.cell)
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	PusherRules.mark_attack(state,unit,targets[0].cell if not targets.is_empty() else (boxes[0].cell if not boxes.is_empty() else state.ball.cell))
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var attack := SkillRules.attack_output_value(unit,data)
	for target in targets:
		if unit.hp<=0:break
		var target_data: OperatorData=state._operator_data[target.operator_id]
		var damage := Combat.calculate_damage(attack,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"magical",SkillRules.dodge_chance(target,target_data,"magical"),state.rng,data.profession_id,state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
		state._apply_damage(target,target_data,damage,"magical",unit)
	if unit.hp<=0:return
	for box in boxes:
		if box.hits_left>0:TacticalRules.strike_box(state,unit,box)
	if ball_hit:state.ball.add_push(unit.cell,attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
