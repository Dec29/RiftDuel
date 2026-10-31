class_name SagaRules
extends RefCounted


static func mark_critical(state: MatchState, target: UnitState, source: UnitState) -> void:
	var data: OperatorData=state._operator_data[target.operator_id]
	var talent: TalentResource=state._operator_data[source.operator_id].talent_1
	var old_interval := SkillRules.attack_interval_ticks(target,data)
	target.critical_ticks_left=int(talent.effect_params["duration_ticks"])
	target.critical_speed_percent=int(talent.effect_params["attack_speed_remaining_percent"])
	target.critical_sp_add=int(talent.effect_params["sp_add"])
	target.attack_ticks_left=ceili(float(target.attack_ticks_left)*SkillRules.attack_interval_ticks(target,data)/old_interval)


static func reward(state: MatchState, source: UnitState, amount: int) -> void:
	if source.hp<=0 or source.skill_ticks_left!=0 or not SkillRules.can_gain_sp(source):return
	var skill: SkillResource=state._operator_data[source.operator_id].skills[source.skill_index]
	if skill.sp_recharge_type!="passive":source.sp=mini(SkillRules.sp_limit(skill),source.sp+amount)


static func trigger_focus(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.hp<=0 or unit.silence_ticks_left>0 or unit.saga_focus_used or data.talent_2.effect_type!="saga_focus":return
	var talent := data.talent_2
	if unit.hp*100<SkillRules.max_health_value(unit,data)*int(talent.effect_params["hp_threshold_percent"]):
		unit.saga_focus_used=true
		unit.saga_focus_ticks=int(talent.effect_params["duration_ticks"])


static func regenerate(state: MatchState) -> void:
	for unit in state.units:
		var data: OperatorData=state._operator_data[unit.operator_id]
		trigger_focus(state,unit,data)
		if unit.hp<=0 or unit.saga_focus_ticks<=0 or unit.silence_ticks_left>0 or unit.critical_ticks_left>0:continue
		var maximum := SkillRules.max_health_value(unit,data)
		unit.saga_regen_accum+=maximum*int(data.talent_2.effect_params["regen_health_percent"])*state.CONFIG.UNIT_HEAL_PERCENT
		var healed := unit.saga_regen_accum/(10000*state.CONFIG.TICK_RATE)
		unit.saga_regen_accum%=10000*state.CONFIG.TICK_RATE
		if healed>0 and unit.hp<maximum:
			unit.hp=mini(maximum,unit.hp+healed)
			unit.last_heal_tick=state.tick


static func activate_purge(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	SkillRules.activate(unit,data)
	unit.skill_ticks_left=0
	unit.saga_cast_tick=state.tick
	state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(skill.effect_params["cost_add"]))
	var targets := PusherRules.targets(state,unit,skill.attack_range_override,false)
	var hit_count := 0
	var attack_value := roundi(SkillRules.attack_value(unit,data)*float(skill.effect_params["attack_mult"]))
	for enemy in targets:
		if hit_count>=int(skill.effect_params["target_count"]):break
		if state.terrain_at(enemy.cell)!="ground":continue
		hit_count+=1
		PusherRules.mark_attack(state,unit,enemy.cell)
		hit(state,unit,data,enemy,attack_value)
		if enemy.hp>0:
			enemy.critical_execute_tick=state.tick+int(skill.effect_params["execute_delay_ticks"])
			enemy.critical_executor_id=unit.unit_id
	if hit_count==0:
		for box in state.tactical_boxes:
			if box.hits_left>0 and state._is_in_attack_range(unit,box.cell,skill.attack_range_override):
				PusherRules.mark_attack(state,unit,box.cell)
				TacticalRules.strike_box(state,unit,box)
				return
		if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,skill.attack_range_override):
			PusherRules.mark_attack(state,unit,state.ball.cell)
			state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))


static func advance_executions(state: MatchState) -> void:
	for unit in state.units:
		if unit.critical_execute_tick<0 or state.tick<unit.critical_execute_tick:continue
		unit.critical_execute_tick=-1
		if unit.hp<=0 or unit.critical_ticks_left<=0:continue
		var source := WArtilleryRules.owner(state,unit.critical_executor_id)
		unit.hp=0
		unit.last_damage_tick=state.tick
		if source!=null:reward(state,source,unit.critical_sp_add)
		WArtilleryRules.on_exit(state,unit)
		if unit.operator_id=="mon3tr":Mon3trRules.on_death(state,unit)
		elif unit.operator_id=="kaltsit":Mon3trRules.remove_owned(state,unit)


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="instant_cost" and SkillRules.can_activate(unit,skill):
		SkillRules.activate(unit,data)
		unit.skill_ticks_left=0
		state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(skill.effect_params["cost_add"]))
	if SkillRules.active_ticks(unit)>0 and skill.effect_type=="saga_fury" and (unit.skill_elapsed_ticks+1)%state.CONFIG.TICK_RATE==0:
		state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+1)
	if unit.saga_cast_tick==state.tick:return
	if not AttackTimeline.advance(state,unit):return
	var targets := PusherRules.targets(state,unit,AttackRange.effective_offsets(unit,data),false)
	if unit.silence_ticks_left==0:
		var filtered: Array[UnitState]=[]
		for enemy in targets:
			if enemy.critical_ticks_left==0:filtered.append(enemy)
		targets=filtered
	targets=AttackTimeline.pinned(state,unit,targets)
	var center:=targets[0].cell if not targets.is_empty() else AttackTimeline.object_cell(state,unit,AttackRange.effective_offsets(unit,data))
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	var active := SkillRules.active_ticks(unit)>0 and skill.effect_type=="saga_fury"
	var attack_value := SkillRules.attack_output_value(unit,data)
	if targets.is_empty():
		for box in state.tactical_boxes:
			if state._is_in_attack_range(unit,box.cell,AttackRange.effective_offsets(unit,data)):
				PusherRules.mark_attack(state,unit,box.cell)
				TacticalRules.strike_box(state,unit,box)
				unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
				return
		if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,AttackRange.effective_offsets(unit,data)):
			PusherRules.mark_attack(state,unit,state.ball.cell)
			state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
			unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
		return
	PusherRules.mark_attack(state,unit,targets[0].cell)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	for index in mini(targets.size(),SkillRules.block_count_value(unit,data) if active else 1):
		var enemy := targets[index]
		var target_data: OperatorData=state._operator_data[enemy.operator_id]
		var extra := active and enemy.hp*2<SkillRules.max_health_value(enemy,target_data)
		hit(state,unit,data,enemy,attack_value)
		if extra and unit.hp>0 and enemy.hp>0 and (enemy.critical_ticks_left==0 or unit.silence_ticks_left>0):hit(state,unit,data,enemy,attack_value)


static func hit(state: MatchState, source: UnitState, data: OperatorData, enemy: UnitState, attack_value: int) -> void:
	var target_data: OperatorData=state._operator_data[enemy.operator_id]
	var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(enemy,target_data),SkillRules.magic_resist_value(enemy,target_data),"physical",SkillRules.dodge_chance(enemy,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(enemy,"physical"))
	state._apply_damage(enemy,target_data,damage,"physical",source)
