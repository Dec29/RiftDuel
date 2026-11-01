class_name SwordRules
extends RefCounted


static func advance_sp(state: MatchState) -> void:
	for source in state.units:
		var data: OperatorData = state._operator_data[source.operator_id]
		if source.hp <= 0 or data.talent_1.effect_type != "offensive_sp_aura": continue
		source.talent_sp_ticks += 1
		if source.talent_sp_ticks < int(data.talent_1.effect_params["interval_ticks"]): continue
		source.talent_sp_ticks = 0
		if source.silence_ticks_left > 0: continue
		for ally in state.units:
			var skill: SkillResource = state._operator_data[ally.operator_id].skills[ally.skill_index]
			if ally.hp > 0 and ally.side == source.side and ally.skill_ticks_left == 0 and skill.sp_recharge_type in ["on_hit", "on_damaged"]:
				ally.sp = mini(SkillRules.sp_limit(skill), ally.sp + int(data.talent_1.effect_params["sp_add"]))


static func activate(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if target(state,unit,skill.attack_range_override,skill.effect_type=="sword_slashes").is_empty(): return
	SkillRules.activate(unit,data)
	unit.chen_cast_tick=state.tick
	if skill.effect_type=="sword_slashes":
		unit.chen_slashes_left=int(skill.effect_params["slash_count"])
		unit.chen_next_slash_tick=state.tick


static func resolve_casts(state: MatchState) -> void:
	for unit in state.units:
		if unit.hp<=0:continue
		var data: OperatorData=state._operator_data[unit.operator_id]
		if data.branch_trait.effect_type!="dual_strike" or unit.skill_ticks_left==0:continue
		var skill := data.skills[unit.skill_index]
		if skill.effect_type=="sword_draw" and unit.chen_cast_tick==state.tick:
			var found := target(state,unit,skill.attack_range_override,false)
			if found.is_empty():finish(unit);continue
			if found.kind==0:
				var enemies := PusherRules.targets(state,unit,skill.attack_range_override,false)
				for index in mini(enemies.size(),int(skill.effect_params["target_count"])):
					var enemy := enemies[index]
					for dtype in ["physical","magical"]:
						if enemy.hp>0 and unit.hp>0:hit(state,unit,data,enemy,dtype)
			else:
				for index in 2:hit_object(state,unit,data,found)
			PusherRules.mark_attack(state,unit,found.cell)
			finish(unit)
		elif unit.chen_slashes_left>0 and state.tick>=unit.chen_next_slash_tick:
			var found := target(state,unit,skill.attack_range_override,true)
			if found.is_empty():finish(unit);continue
			if found.kind==0:
				var enemy: UnitState=found.unit
				var landed := hit(state,unit,data,enemy,"physical")
				if landed and enemy.hp>0 and unit.chen_slashes_left==1:stun(state,enemy,int(skill.effect_params["stun_ticks"]),unit)
			else:hit_object(state,unit,data,found)
			unit.chen_slash_tick=state.tick
			PusherRules.mark_attack(state,unit,found.cell)
			unit.chen_slashes_left-=1
			unit.chen_next_slash_tick=state.tick+int(skill.effect_params["slash_interval_ticks"])
			if unit.chen_slashes_left==0:finish(unit)


static func advance(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.chen_slashes_left>0 or unit.last_attack_tick==state.tick or unit.chen_cast_tick==state.tick:return
	if not AttackTimeline.advance(state,unit):return
	var found := target(state,unit,data.attack_range,false)
	found=AttackTimeline.pin_found(state,unit,found)
	if found.is_empty():return
	var native_intent:=unit.attack_intent
	if not AttackTimeline.windup_found(state,unit,data,found):return
	var skill := data.skills[unit.skill_index]
	var charged := skill.effect_type=="sword_sheath" and SkillRules.can_activate(unit,skill)
	if charged:
		SkillRules.activate(unit,data);unit.attack_action_triggered=true
		unit.chen_sheath_tick=state.tick
	PusherRules.mark_attack(state,unit,found.cell)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var count := 1 if charged else int(data.branch_trait.effect_params["hit_count"])
	var release_phase:=unit.attack_action_event_index
	var indices:=AttackTimeline.release_indices(unit,native_intent,count)
	for index in indices:
		if unit.hp<=0:break
		if found.kind==0:
			var enemy: UnitState=found.unit
			if enemy.hp>0:
				var landed := hit(state,unit,data,enemy,"physical")
				if charged and landed and enemy.hp>0:stun(state,enemy,int(skill.effect_params["stun_ticks"]),unit)
		else:hit_object(state,unit,data,found)
	if unit.skill_ticks_left==-1 and unit.attack_intent==null:unit.skill_ticks_left=0
	if release_phase==0 and not unit.attack_action_triggered and skill.sp_recharge_type=="on_hit":unit.sp=mini(SkillRules.sp_limit(skill),unit.sp+1)


static func target(state: MatchState, unit: UnitState, offsets: Array[Vector2i], nearest: bool) -> Dictionary:
	var enemies := PusherRules.targets(state,unit,offsets,false)
	if nearest:
		enemies.sort_custom(func(a: UnitState,b: UnitState) -> bool:
			if a.side!=b.side:return a.side!=unit.side
			var da := (a.cell-unit.cell).length_squared()
			var db := (b.cell-unit.cell).length_squared()
			return a.unit_id<b.unit_id if da==db else da<db)
	if not enemies.is_empty():return {"kind":0,"unit":enemies[0],"cell":enemies[0].cell}
	for box in state.tactical_boxes:
		if state._is_in_attack_range(unit,box.cell,offsets):return {"kind":1,"box":box,"cell":box.cell}
	if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,offsets):return {"kind":2,"cell":state.ball.cell}
	return {}


static func hit(state: MatchState, source: UnitState, data: OperatorData, enemy: UnitState, dtype: String) -> bool:
	var target_data: OperatorData=state._operator_data[enemy.operator_id]
	var damage := Combat.calculate_damage(SkillRules.attack_output_value(source,data),SkillRules.defense_value(enemy,target_data),SkillRules.magic_resist_value(enemy,target_data),dtype,SkillRules.dodge_chance(enemy,target_data,dtype),state.rng,data.profession_id,state._damage_taken_percent(enemy, dtype),state._magical_damage_taken_percent(enemy))
	return state._apply_damage(enemy,target_data,damage,dtype,source)


static func hit_object(state: MatchState, unit: UnitState, data: OperatorData, found: Dictionary) -> void:
	if found.kind==1:
		var box: TacticalBox=found.box
		if box.hits_left>0:TacticalRules.strike_box(state,unit,box)
	elif found.kind==2 and state.ball.move_ticks_left==0:
		state.ball.add_push(unit.cell,SkillRules.attack_output_value(unit,data),state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))


static func stun(state: MatchState, enemy: UnitState, duration: int, source: UnitState = null) -> void:
	var resistant := StatusRules.has_resistance(state,enemy)
	StatusRules.add_control(state,enemy,"stun",duration*state.CONFIG.STATUS_RESISTANCE_DURATION_PERCENT/100 if resistant else duration,source)


static func finish(unit: UnitState) -> void:
	unit.chen_slashes_left=0
	unit.chen_next_slash_tick=0
	unit.skill_ticks_left=0
