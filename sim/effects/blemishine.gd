class_name BlemishineRules
extends RefCounted


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	SkillRules.activate(unit,data)
	var skill := data.skills[unit.skill_index]
	if skill.effect_type!="blemishine_sleep":return
	for enemy in state.units:
		if state.enemy_is_targetable(unit.side,enemy) and ((enemy.cell==unit.cell and state.terrain_at(enemy.cell)!="high") or state.enemy_is_blocked(enemy,unit.unit_id)):
			StatusRules.add_control(state,enemy,"sleep",int(skill.effect_params["sleep_ticks"]))


static func on_basic_attack(state: MatchState, unit: UnitState) -> void:
	var skill: SkillResource=state._operator_data[unit.operator_id].skills[unit.skill_index]
	if unit.hp<=0 or unit.skill_ticks_left!=0 or skill.sp_recharge_type!="on_damaged":return
	for source in state.units:
		var data: OperatorData=state._operator_data[source.operator_id]
		if source.hp>0 and source.side==unit.side and source.silence_ticks_left==0 and data.talent_1.effect_type=="defensive_attack_sp":
			SagaRules.reward(state,unit,int(data.talent_1.effect_params["sp_add"]));return


static func regenerate(state: MatchState) -> void:
	for ally in state.units:
		if ally.hp<=0 or ally.critical_ticks_left>0:continue
		var total := 0
		for source in state.units:
			var data: OperatorData=state._operator_data[source.operator_id]
			var skill := data.skills[source.skill_index]
			if source.hp<=0 or source.side!=ally.side or SkillRules.active_ticks(source)<=0 or skill.effect_type!="blemishine_sleep" or not state._is_in_attack_range(source,ally.cell,skill.burst_range_override):continue
			total+=SkillRules.attack_value(source,data)*int(skill.effect_params["regen_attack_percent"])*state.CONFIG.UNIT_HEAL_PERCENT
		if total==0:ally.blemishine_regen_accum=0;continue
		ally.blemishine_regen_accum+=total
		var divisor: int=state.CONFIG.TICK_RATE*10000
		var amount: int=ally.blemishine_regen_accum/divisor
		ally.blemishine_regen_accum%=divisor
		var maximum := SkillRules.max_health_value(ally,state._operator_data[ally.operator_id])
		if amount>0 and ally.hp<maximum:
			ally.hp=mini(maximum,ally.hp+amount);ally.last_heal_tick=state.tick


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,unit):return
	var targets := PusherRules.targets(state,unit,data.attack_range,false)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,data.attack_range)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	var skill := data.skills[unit.skill_index]
	var charged := skill.effect_type=="blemishine_charge" and SkillRules.can_activate(unit,skill)
	if charged:SkillRules.activate(unit,data)
	var radiant := SkillRules.active_ticks(unit)>0 and skill.effect_type=="blemishine_radiance"
	PusherRules.mark_attack(state,unit,center);on_basic_attack(state,unit);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var attack_value := SkillRules.attack_value(unit,data)
	if not targets.is_empty():
		var enemy := targets[0]
		if state.can_attack_sleeping(unit) and enemy.sleep_ticks_left>0:attack_value=roundi(attack_value*int(data.talent_2.effect_params["attack_percent"])/100.0)
		hit(state,unit,data,enemy,attack_value,"physical")
		if radiant and enemy.hp>0 and unit.hp>0:hit(state,unit,data,enemy,roundi(attack_value*float(skill.effect_params["magic_attack_mult"])),"magical")
	else:
		for box in state.tactical_boxes:
			if box.hits_left>0 and box.cell==center:
				for index in (2 if radiant else 1):
					if box.hits_left>0:TacticalRules.strike_box(state,unit,box)
				if charged:heal(state,unit,data,false)
				elif radiant:heal(state,unit,data,true)
				if charged:unit.skill_ticks_left=0
				return
		if state.ball.move_ticks_left==0:
			for index in (2 if radiant else 1):
				if state.ball.move_ticks_left==0:state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
	if unit.hp>0:
		if charged:heal(state,unit,data,false)
		elif radiant:heal(state,unit,data,true)
	if charged:unit.skill_ticks_left=0


static func hit(state: MatchState, source: UnitState, data: OperatorData, target: UnitState, attack_value: int, kind: String) -> void:
	var target_data: OperatorData=state._operator_data[target.operator_id]
	var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),kind,SkillRules.dodge_chance(target,target_data,kind),state.rng,data.profession_id,state._damage_taken_percent(target,kind),state._magical_damage_taken_percent(target))
	state._apply_damage(target,target_data,damage,kind,source)


static func heal(state: MatchState, source: UnitState, data: OperatorData, exclude_self: bool) -> void:
	var skill := data.skills[source.skill_index]
	var targets: Array[UnitState]=[]
	for ally in state.units:
		var ally_data: OperatorData=state._operator_data[ally.operator_id]
		if ally.side==source.side and (ally!=source or not exclude_self) and LumenRules.can_heal(state,ally) and ally.hp<SkillRules.max_health_value(ally,ally_data) and state._is_in_attack_range(source,ally.cell,skill.burst_range_override):targets.append(ally)
	targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
		var am := SkillRules.max_health_value(a,state._operator_data[a.operator_id]);var bm := SkillRules.max_health_value(b,state._operator_data[b.operator_id])
		return a.unit_id<b.unit_id if a.hp*bm==b.hp*am else a.hp*bm<b.hp*am)
	if targets.is_empty():return
	var value := SkillRules.attack_value(source,data,skill.effect_type=="blemishine_charge")
	LumenRules.treat_amount(state,targets[0],Combat.calculate_healing(value,int(skill.effect_params["heal_attack_percent"])),source)
