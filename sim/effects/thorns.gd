class_name ThornsRules
extends RefCounted


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if SkillRules.active_ticks(unit)>0 and data.skills[unit.skill_index].effect_type=="thorns_counter":return
	if not AttackTimeline.advance(state,unit):return
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets := PusherRules.targets(state,unit,offsets,false,true)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,offsets)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	PusherRules.mark_attack(state,unit,center)
	unit.thorns_last_active_attack_tick=state.tick
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var attack_value := SkillRules.attack_output_value(unit,data)
	if not targets.is_empty():
		var target := targets[0]
		if state.enemy_is_blocked(target,unit.unit_id):attack_value=SkillRules.attack_value(unit,data)
		if not state.enemy_is_blocked(target,unit.unit_id):AttackTimeline.generic_projectile(state,unit,data,target,null,target.cell,attack_value,"physical")
		else:hit(state,unit,data,target,attack_value)
	else:
		var box_hit := false
		for box in state.tactical_boxes:
			if box.hits_left>0 and box.cell==center:AttackTimeline.generic_projectile(state,unit,data,null,box,center,attack_value,"physical");box_hit=true;break
		if not box_hit and state.ball.move_ticks_left==0:AttackTimeline.generic_projectile(state,unit,data,null,null,center,attack_value,"physical")
	var skill := data.skills[unit.skill_index]
	if unit.skill_ticks_left==0 and skill.sp_recharge_type=="on_hit":SagaRules.reward(state,unit,1)


static func counter(state: MatchState, unit: UnitState, data: OperatorData, source: UnitState) -> void:
	var skill := data.skills[unit.skill_index]
	if unit.hp<=0 or source==null or source.side==unit.side or SkillRules.active_ticks(unit)<=0 or skill.effect_type!="thorns_counter":return
	if unit.stun_ticks_left>0 or unit.sleep_ticks_left>0 or unit.displacement_ticks_left>0 or unit.thorns_counter_ready_tick>state.tick:return
	unit.thorns_counter_ready_tick=state.tick+int(skill.effect_params["cooldown_ticks"])
	var targets := PusherRules.targets(state,unit,AttackRange.effective_offsets(unit,data),false)
	for index in mini(targets.size(),int(skill.effect_params["target_count"])):
		if unit.hp<=0:break
		hit(state,unit,data,targets[index],SkillRules.attack_output_value(unit,data))


static func hit(state: MatchState, unit: UnitState, data: OperatorData, target: UnitState, attack_value: int) -> void:
	var target_data: OperatorData=state._operator_data[target.operator_id]
	var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target,"physical"))
	if not state._apply_damage(target,target_data,damage,"physical",unit) or target.hp<=0 or unit.hp<=0 or unit.silence_ticks_left>0:return
	var params := data.talent_1.effect_params
	if target.thorns_poison_until_tick<=state.tick:target.thorns_poison_next_tick=state.tick+state.CONFIG.TICK_RATE
	target.thorns_poison_until_tick=state.tick+int(params["duration_ticks"])
	target.thorns_poison_source_id=unit.unit_id
	var ranged := target_data.profession_id in ["sniper","caster","medic","supporter"] or target_data.branch_trait.effect_type in ["ranged_attack","summoner"]
	target.thorns_poison_damage=int(params["ranged_damage"] if ranged else params["damage"])


static func regenerate(state: MatchState) -> void:
	for unit in state.units.duplicate():
		if unit.hp<=0 or unit not in state.units:continue
		var data: OperatorData=state._operator_data[unit.operator_id]
		if unit.thorns_poison_until_tick>0:
			if state.tick>=unit.thorns_poison_next_tick and state.tick<=unit.thorns_poison_until_tick:
				var source := WArtilleryRules.owner(state,unit.thorns_poison_source_id)
				var damage := Combat.calculate_damage(unit.thorns_poison_damage,0,SkillRules.magic_resist_value(unit,data),"magical",0,state.rng,"guard",state._damage_taken_percent(unit,"magical"),state._magical_damage_taken_percent(unit))
				state._apply_damage(unit,data,damage,"magical",source,false)
				unit.thorns_poison_next_tick+=state.CONFIG.TICK_RATE
			if state.tick>=unit.thorns_poison_until_tick:
				unit.thorns_poison_until_tick=0;unit.thorns_poison_next_tick=0;unit.thorns_poison_source_id=-1;unit.thorns_poison_damage=0
		if unit.hp<=0 or unit.critical_ticks_left>0 or unit.silence_ticks_left>0 or data.talent_2.effect_type!="idle_health_regeneration":continue
		var params := data.talent_2.effect_params
		if state.tick-maxi(unit.deployed_tick,unit.thorns_last_active_attack_tick)<int(params["idle_ticks"]):continue
		unit.thorns_regen_accum+=SkillRules.max_health_value(unit,data)*int(params["health_basis_points"])*state.CONFIG.UNIT_HEAL_PERCENT
		var denominator: int = state.CONFIG.TICK_RATE*1000000
		var healed: int = unit.thorns_regen_accum/denominator
		unit.thorns_regen_accum%=denominator
		if healed>0 and unit.hp<SkillRules.max_health_value(unit,data):
			unit.hp=mini(SkillRules.max_health_value(unit,data),unit.hp+healed)
			unit.last_heal_tick=state.tick
