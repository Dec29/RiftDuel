class_name SoraRules
extends RefCounted


static func activate(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	SkillRules.activate(unit,data)
	unit.bard_skill_started_tick=state.tick
	AuraRules.refresh(state)
	if data.skills[unit.skill_index].effect_type=="bard_sleep":apply_sleep(state,unit,data)


static func apply_sleep(state: MatchState, source: UnitState, data: OperatorData) -> void:
	for enemy in state.units:
		if enemy.hp<=0 or enemy.side==source.side or not state._is_in_attack_range(source,enemy.cell,AttackRange.effective_offsets(source,data)):continue
		var duration := SkillRules.active_ticks(source)
		StatusRules.add_control(state,enemy,"sleep",duration)


static func advance_sleep(state: MatchState) -> void:
	for source in state.units:
		var data: OperatorData=state._operator_data[source.operator_id]
		if source.hp>0 and SkillRules.active_ticks(source)>0 and data.skills[source.skill_index].effect_type=="bard_sleep":apply_sleep(state,source,data)


static func encore(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.hp<=0 or unit.silence_ticks_left>0:return
	if state.rng.next_percent()<int(data.talent_1.effect_params["chance_percent"]):
		var skill := data.skills[unit.skill_index]
		unit.sp=mini(SkillRules.sp_limit(skill),unit.sp+roundi(SkillRules.sp_limit(skill)*int(data.talent_1.effect_params["sp_percent"])/100.0))
