class_name SilenceAlterRules
extends RefCounted


static func drone_owner(state: MatchState, side: int) -> UnitState:
	for source in state.units:
		if source.operator_id=="silence_alter" and source.side==side and source.hp>0 and source.silence_ticks_left==0 and SkillRules.active_ticks(source)>0 and state._operator_data[source.operator_id].skills[source.skill_index].effect_type=="silence_drone_skill":return source
	return null


static func drone_available(state: MatchState, side: int) -> bool:
	var source := drone_owner(state,side)
	if state.result!=state.RESULT_RUNNING or source==null or source.silence_drone_stock<=0 or state.sides[side].cooldowns.get("silence_alter_drone",0)>0:return false
	for unit in state.units:
		if unit.operator_id=="silence_alter_drone" and unit.side==side and unit.hp>0:return false
	return true


static func remove_owned(state: MatchState, source: UnitState) -> void:
	source.silence_drone_stock=0
	var retained: Array[UnitState]=[]
	for unit in state.units:
		if unit.operator_id=="silence_alter_drone" and unit.silence_drone_owner_id==source.unit_id:continue
		retained.append(unit)
	state.units=retained


static func maintain(state: MatchState) -> void:
	var retained: Array[UnitState]=[]
	for unit in state.units:
		if unit.operator_id=="silence_alter_drone":
			var source := WArtilleryRules.owner(state,unit.silence_drone_owner_id)
			if source==null or source.hp<=0 or source.skill_ticks_left<=0:continue
		retained.append(unit)
	state.units=retained


static func protection(state: MatchState, target: UnitState) -> int:
	var value := 0
	var hp_percent := clampi(roundi(target.hp*100.0/SkillRules.max_health_value(target,state._operator_data[target.operator_id])),0,100)
	for source in state.units:
		if source.operator_id!="silence_alter" or source.hp<=0 or source.side!=target.side or source.silence_ticks_left>0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		var talent := data.talent_1
		var amount := int(talent.effect_params["base_percent"])+roundi((100-maxi(hp_percent,int(talent.effect_params["min_hp_percent"])))*(int(talent.effect_params["max_percent"])-int(talent.effect_params["base_percent"]))/float(100-int(talent.effect_params["min_hp_percent"])))
		var skill := data.skills[source.skill_index]
		if state._is_in_attack_range(source,target.cell,AttackRange.effective_offsets(source,data)):
			var scale := int(skill.effect_params["protection_scale_percent"]) if SkillRules.active_ticks(source)>0 and skill.effect_type=="silence_protocol" else 100
			value=maxi(value,roundi(amount*scale/100.0))
		for drone in state.units:
			if drone.hp>0 and drone.operator_id=="silence_alter_drone" and drone.silence_drone_owner_id==source.unit_id and SkillRules.active_ticks(source)>0 and state._is_in_attack_range(drone,target.cell,state.SILENCE_DRONE_DATA.attack_range):value=maxi(value,roundi(amount*int(skill.effect_params["protection_scale_percent"])/100.0))
	return value


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="silence_protocol":
		if unit.skill_ticks_left!=0:unit.skill_ticks_left=0;return
		if state.sides[unit.side].silence_protocol_uses>=int(skill.effect_params["use_limit"]):return
		state.sides[unit.side].silence_protocol_uses+=1
		unit.silence_grave_used=false
	SkillRules.activate(unit,data)
	if skill.effect_type=="silence_drone_skill":unit.silence_drone_stock=1


static func prevent_fatal(state: MatchState, target: UnitState, damage: int) -> int:
	if state.tick<target.silence_grave_until_tick:return mini(damage,maxi(0,target.hp-1))
	if damage<target.hp or state._operator_data[target.operator_id].profession_id=="summon":return damage
	for source in state.units:
		if source.operator_id!="silence_alter" or source.hp<=0 or source.side!=target.side or source.silence_grave_used or SkillRules.active_ticks(source)<=0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		var skill := data.skills[source.skill_index]
		if skill.effect_type!="silence_protocol" or not state._is_in_attack_range(source,target.cell,AttackRange.effective_offsets(source,data)):continue
		source.silence_grave_used=true
		target.silence_grave_until_tick=state.tick+int(skill.effect_params["grave_ticks"])
		return maxi(0,target.hp-1)
	return damage


static func regenerate(state: MatchState) -> void:
	for target in state.units:
		if target.hp<=0 or target.critical_ticks_left>0:continue
		var target_data: OperatorData=state._operator_data[target.operator_id]
		var maximum := SkillRules.max_health_value(target,target_data)
		var recovery := 0
		for source in state.units:
			if source.operator_id!="silence_alter" or source.hp<=0 or source.side!=target.side or source.silence_ticks_left>0:continue
			var data: OperatorData=state._operator_data[source.operator_id]
			var talent := data.talent_2
			if target.hp*100>=maximum*int(talent.effect_params["hp_threshold_percent"]) or not state._is_in_attack_range(source,target.cell,AttackRange.effective_offsets(source,data)):continue
			recovery=maxi(recovery,SkillRules.attack_value(source,data)*int(talent.effect_params["regen_attack_percent"])*(int(talent.effect_params["group_multiplier"]) if target_data.group_id=="rhine" else 1))
		target.silence_regen_accum+=recovery*state.CONFIG.UNIT_HEAL_PERCENT
		var healed := target.silence_regen_accum/(state.CONFIG.TICK_RATE*10000)
		target.silence_regen_accum%=state.CONFIG.TICK_RATE*10000
		if healed>0:target.hp=mini(maximum,target.hp+healed);target.last_heal_tick=state.tick


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,unit):return
	if SkillRules.active_ticks(unit)>0:
		var allies := LumenRules.candidates(state,unit,false)
		if allies.is_empty():return
		var target := AttackTimeline.heal_target(state,unit,allies[0])
		if target==null:return
		var locked: Array[UnitState]=[target]
		if not AttackTimeline.windup(state,unit,data,locked,target.cell,true):return
		unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
		PusherRules.mark_attack(state,unit,target.cell);unit.last_attack_is_heal=true
		LumenRules.treat_amount(state,target,Combat.calculate_healing(SkillRules.attack_value(unit,data),int(data.branch_trait.effect_params["skill_heal_percent"])),unit)
		return
	var found := SwordRules.target(state,unit,data.attack_range,false)
	found=AttackTimeline.pin_found(state,unit,found)
	if found.is_empty():return
	if not AttackTimeline.windup_found(state,unit,data,found):return
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data);PusherRules.mark_attack(state,unit,found.cell)
	AttackTimeline.found_projectile(state,unit,data,found,SkillRules.attack_value(unit,data),"magical")
