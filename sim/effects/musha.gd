class_name MushaRules
extends RefCounted


static func sample_speed(state: MatchState) -> void:
	for unit in state.units:
		var data: OperatorData=state._operator_data[unit.operator_id]
		if unit.hp<=0 or data.branch_trait.effect_type!="musha":continue
		var params := data.talent_1.effect_params
		unit.musha_speed_accum+=int(params["samples_per_second"])
		if unit.musha_speed_accum>=state.CONFIG.TICK_RATE:
			unit.musha_speed_accum%=state.CONFIG.TICK_RATE
			var maximum := SkillRules.max_health_value(unit,data)
			unit.musha_attack_speed=clampi(roundi(int(params["max_attack_speed"])*(maximum-unit.hp)*100.0/(maximum*int(params["loss_cap_percent"]))),0,int(params["max_attack_speed"]))


static func regenerate(state: MatchState) -> void:
	for unit in state.units:
		var data: OperatorData=state._operator_data[unit.operator_id]
		if unit.hp<=0 or unit.critical_ticks_left>0 or unit.silence_ticks_left>0 or data.branch_trait.effect_type!="musha":continue
		var blocking := false
		for enemy in state.units:
			if enemy.hp>0 and enemy.side!=unit.side and state.enemy_is_blocked(enemy,unit.unit_id):blocking=true;break
		if blocking:continue
		unit.hp_regen_accum+=int(data.talent_2.effect_params["heal_per_second"])*state.CONFIG.UNIT_HEAL_PERCENT
		var recovered := unit.hp_regen_accum/(state.CONFIG.TICK_RATE*100)
		unit.hp_regen_accum%=state.CONFIG.TICK_RATE*100
		if recovered>0 and unit.hp<SkillRules.max_health_value(unit,data):
			unit.hp=mini(SkillRules.max_health_value(unit,data),unit.hp+recovered)
			unit.last_heal_tick=state.tick


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.critical_ticks_left>0:return
	if not AttackTimeline.advance(state,unit):return
	var skill := data.skills[unit.skill_index]
	var offsets := AttackRange.effective_offsets(unit,data)
	var enemies: Array[UnitState]=[]
	for target in state.units:
		if state.enemy_is_targetable(unit.side,target) and (state._is_in_attack_range(unit,target.cell,offsets) or state.enemy_is_blocked(target,unit.unit_id)):enemies.append(target)
	enemies.sort_custom(func(a: UnitState,b: UnitState) -> bool:
		if a.side!=b.side:return a.side!=unit.side
		var blocked_a := state.enemy_is_blocked(a,unit.unit_id)
		var blocked_b := state.enemy_is_blocked(b,unit.unit_id)
		if blocked_a!=blocked_b:return blocked_a
		var ta := SkillRules.taunt_level(a,state._operator_data[a.operator_id]);var tb := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
		return a.unit_id<b.unit_id if ta==tb else ta>tb)
	enemies=AttackTimeline.pinned(state,unit,enemies)
	var box: TacticalBox
	if enemies.is_empty():
		for candidate in state.tactical_boxes:
			if state._is_in_attack_range(unit,candidate.cell,offsets):box=candidate;break
	var ball := enemies.is_empty() and box==null and state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,offsets)
	if enemies.is_empty() and box==null and not ball:return
	var native_intent:=unit.attack_intent
	if not AttackTimeline.windup(state,unit,data,enemies,enemies[0].cell if not enemies.is_empty() else (box.cell if box!=null else state.ball.cell)):return
	var charged := skill.trigger_type=="attack" and SkillRules.can_activate(unit,skill)
	if charged:SkillRules.activate(unit,data);unit.attack_action_triggered=true
	var attack_value := SkillRules.attack_output_value(unit,data)
	var active := SkillRules.active_ticks(unit)!=0
	var count := int(skill.effect_params["target_count"]) if active and skill.effect_type=="multi_target_boost" else 1
	var shots := int(skill.effect_params["shot_count"]) if active and skill.effect_type in ["multi_shot","musha_double"] else 1
	var center := enemies[0].cell if not enemies.is_empty() else (box.cell if box!=null else state.ball.cell)
	PusherRules.mark_attack(state,unit,center)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var release_phase:=unit.attack_action_event_index
	var indices:=AttackTimeline.release_indices(unit,native_intent,shots)
	for index in mini(count,enemies.size()):
		var target := enemies[index]
		var target_data: OperatorData=state._operator_data[target.operator_id]
		for shot in indices:
			if target.hp<=0 or unit.hp<=0:break
			var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target,"physical"))
			if state._apply_damage(target,target_data,damage,"physical",unit) and unit.hp>0:
				unit.hp=mini(SkillRules.max_health_value(unit,data),unit.hp+SkillRules.healing_output(unit,Combat.calculate_healing(int(data.branch_trait.effect_params["heal_per_hit"]))))
				unit.last_heal_tick=state.tick
	if box!=null:
		for shot in indices:
			if box.hits_left>0:TacticalRules.strike_box(state,unit,box)
	elif ball:
		for shot in indices:state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
	if unit.skill_ticks_left==-1 and unit.attack_intent==null:unit.skill_ticks_left=0
	if release_phase==0 and not unit.attack_action_triggered and unit.skill_ticks_left==0 and skill.sp_recharge_type=="on_hit":unit.sp=mini(SkillRules.sp_limit(skill),unit.sp+1)
