class_name GnosisRules
extends RefCounted


static func has_group_resistance(state: MatchState, target: UnitState) -> bool:
	if state._operator_data[target.operator_id].group_id!="kjerag":return false
	for source in state.units:
		if source.operator_id=="gnosis" and source.side==target.side and source.hp>0 and source.silence_ticks_left==0 and state.tick-source.deployed_tick>=int(state._operator_data[source.operator_id].talent_2.effect_params["warmup_ticks"]):return true
	return false


static func fragile_percent(state: MatchState, target: UnitState) -> int:
	if target.cold_ticks_left==0 and target.frozen_ticks_left==0:return 0
	var value := 0
	for source in state.units:
		if source.operator_id!="gnosis" or source.hp<=0 or source.side==target.side or source.silence_ticks_left>0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		if state._is_in_attack_range(source,target.cell,AttackRange.effective_offsets(source,data)):value=maxi(value,int(data.talent_1.effect_params["frozen_fragile_percent" if target.frozen_ticks_left>0 else "cold_fragile_percent"]))
	return value


static func cold(state: MatchState, source: UnitState, target: UnitState, ticks: int) -> void:
	if source.silence_ticks_left>0:return
	if StatusRules.has_resistance(state,target):ticks=maxi(1,ticks*state.CONFIG.STATUS_RESISTANCE_DURATION_PERCENT/100)
	StatusRules.add_control(state,target,"cold",ticks,source)


static func extend_frozen(state: MatchState, target: UnitState) -> void:
	if target.frozen_ticks_left==0:return
	for source in state.units:
		if source.operator_id!="gnosis" or source.hp<=0 or source.side==target.side or SkillRules.active_ticks(source)<=0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		if data.skills[source.skill_index].effect_type=="gnosis_hypothermia" and state._is_in_attack_range(source,target.cell,AttackRange.effective_offsets(source,data)):target.frozen_ticks_left=maxi(target.frozen_ticks_left,source.skill_ticks_left)


static func maintain(state: MatchState) -> void:
	for target in state.units:extend_frozen(state,target)


static func deal(state: MatchState, source: UnitState, target: UnitState, attack: int) -> void:
	var data: OperatorData=state._operator_data[target.operator_id]
	var damage := Combat.calculate_damage(attack,SkillRules.defense_value(target,data),SkillRules.magic_resist_value(target,data),"magical",SkillRules.dodge_chance(target,data,"magical"),state.rng,"supporter",state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
	state._apply_damage(target,data,damage,"magical",source)


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	var charged := unit.sp>=SkillRules.sp_limit(skill)
	SkillRules.activate(unit,data)
	if skill.effect_type!="gnosis_cold":return
	unit.sp=0;unit.skill_ticks_left=0
	PusherRules.mark_attack(state,unit,unit.cell)
	for target in state.units:
		if not state.enemy_is_targetable(unit.side,target,unit) or not state._is_in_attack_range(unit,target.cell,data.attack_range):continue
		cold(state,unit,target,int(skill.effect_params["cold_ticks"]))
		if charged:cold(state,unit,target,int(skill.effect_params["cold_ticks"]))
		deal(state,unit,target,roundi(SkillRules.attack_value(unit,data)*float(skill.effect_params["attack_mult"])))


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,unit):return
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets := PusherRules.targets(state,unit,offsets,false)
	var skill := data.skills[unit.skill_index]
	var active := SkillRules.active_ticks(unit)>0 and skill.effect_type=="gnosis_hypothermia"
	if active:targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
		if a.side!=b.side:return a.side!=unit.side
		if (a.frozen_ticks_left>0)!=(b.frozen_ticks_left>0):return a.frozen_ticks_left==0
		return a.unit_id<b.unit_id)
	targets=AttackTimeline.pinned(state,unit,targets.slice(0,int(skill.effect_params["target_count"]) if active else 1))
	var found := SwordRules.target(state,unit,offsets,false)
	if not targets.is_empty():found={"kind":0,"unit":targets[0],"cell":targets[0].cell}
	found=AttackTimeline.pin_found(state,unit,found)
	if found.is_empty():return
	var native_intent:=unit.attack_intent
	if not AttackTimeline.windup(state,unit,data,targets,found.cell):return
	var double := skill.effect_type=="gnosis_double" and SkillRules.can_activate(unit,skill)
	if double:SkillRules.activate(unit,data);unit.attack_action_triggered=true
	PusherRules.mark_attack(state,unit,found.cell);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var shots := int(skill.effect_params["shot_count"]) if double or unit.attack_action_triggered else 1
	var indices:=AttackTimeline.release_indices(unit,native_intent,shots)
	if not targets.is_empty():
		for index in mini(targets.size(),int(skill.effect_params["target_count"]) if active else 1):
			var target := targets[index]
			for shot in indices:
				if target.hp<=0 or unit.hp<=0:break
				var pending:=AttackTimeline.generic_projectile(state,unit,data,target,null,target.cell,SkillRules.attack_value(unit,data),"magical")
				if unit.silence_ticks_left==0:pending.cold_ticks=int(data.talent_1.effect_params.cold_ticks)
	else:
		for index in indices:AttackTimeline.found_projectile(state,unit,data,found,SkillRules.attack_value(unit,data),"magical")
	if unit.skill_ticks_left==-1 and unit.attack_intent==null:unit.skill_ticks_left=0


static func finish(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var skill := data.skills[source.skill_index]
	if skill.effect_type!="gnosis_hypothermia" or source.hp<=0:return
	for target in state.units:
		if target.hp<=0 or target.side==source.side or target.frozen_ticks_left==0 or not state._is_in_attack_range(source,target.cell,AttackRange.effective_offsets(source,data)):continue
		deal(state,source,target,roundi(SkillRules.attack_value(source,data)*int(skill.effect_params["end_attack_percent"])/100.0))
		target.frozen_ticks_left=0;target.cold_ticks_left=0
