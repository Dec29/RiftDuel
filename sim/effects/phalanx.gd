class_name PhalanxRules
extends RefCounted


static func guarding(unit: UnitState, data: OperatorData) -> bool:
	return data.branch_trait.effect_type=="phalanx" and (unit.skill_ticks_left==0 or (SkillRules.active_ticks(unit)>0 and unit.carnelian_charged and data.skills[unit.skill_index].effect_type=="carnelian_guard"))


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	unit.carnelian_charged=unit.sp>=SkillRules.sp_limit(skill)
	SkillRules.activate(unit,data)
	unit.sp=0
	var talent := data.talent_1
	LumenRules.treat_amount(state,unit,Combat.calculate_healing(SkillRules.max_health_value(unit,data),int(talent.effect_params["charged_heal_percent"] if unit.carnelian_charged else talent.effect_params["heal_percent"])),unit)


static func maintain(state: MatchState) -> void:
	for target in state.units:
		if target.carnelian_mark_owner_id<0:continue
		var source := WArtilleryRules.owner(state,target.carnelian_mark_owner_id)
		if source==null or source.skill_ticks_left<=0 or state.tick>=target.carnelian_mark_until_tick:
			target.carnelian_mark_owner_id=-1;target.carnelian_mark_stacks=0;target.carnelian_mark_until_tick=0


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if SkillRules.active_ticks(unit)==0 or not AttackTimeline.advance(state,unit):return
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets := PusherRules.targets(state,unit,offsets,false)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,offsets)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var skill := data.skills[unit.skill_index]
	var attack_value := SkillRules.attack_value(unit,data)
	var killed := false
	if not targets.is_empty():
		for target in targets:
			if unit.hp<=0:break
			var target_data: OperatorData=state._operator_data[target.operator_id]
			var amplification := 100
			if skill.effect_type=="carnelian_feast" and unit.carnelian_charged:
				if target.carnelian_mark_owner_id<0:target.carnelian_mark_owner_id=unit.unit_id
				target.carnelian_mark_stacks=mini(int(skill.effect_params["max_stacks"]),target.carnelian_mark_stacks+1)
				target.carnelian_mark_until_tick=state.tick+unit.skill_ticks_left
				if target.carnelian_mark_owner_id==unit.unit_id:amplification+=target.carnelian_mark_stacks*int(skill.effect_params["damage_percent_per_stack"])
			var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"magical",SkillRules.dodge_chance(target,target_data,"magical"),state.rng,data.profession_id,state._damage_taken_percent(target,"magical")*amplification/100.0,state._magical_damage_taken_percent(target))
			var landed := state._apply_damage(target,target_data,damage,"magical",unit)
			killed=killed or (landed and target.hp<=0)
			if landed and target.hp>0 and skill.effect_type=="lin_stance":StatusRules.add_control(state,target,"slow",int(skill.effect_params["slow_ticks"]))
			if landed and target.hp>0 and skill.effect_type=="carnelian_bind":StatusRules.add_control(state,target,"bind" if unit.carnelian_charged else "slow",int(skill.effect_params["bind_ticks"] if unit.carnelian_charged else skill.effect_params["slow_ticks"]))
		if killed and skill.effect_type=="lin_burst":LinRules.kill_burst(state,unit)
	else:
		for box in state.tactical_boxes:
			if box.hits_left>0 and box.cell==center:TacticalRules.strike_box(state,unit,box);return
		if state.ball.move_ticks_left==0:state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
