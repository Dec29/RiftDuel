class_name LumenRules
extends RefCounted

# Verified near-range diagram: source, its lateral neighbors, front three and second-front center.
const NEAR_RANGE: Array[Vector2i]=[Vector2i(0,-1),Vector2i.ZERO,Vector2i(0,1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(2,0)]


static func can_heal(state: MatchState, target: UnitState) -> bool:
	var data: OperatorData=state._operator_data[target.operator_id]
	return target.hp>0 and target.critical_ticks_left==0 and data.profession_id!="summon" and data.branch_trait.effect_type not in ["musha","unyield"]


static func has_control(target: UnitState) -> bool:
	return target.titi_doze_owner_id>=0 or target.cold_ticks_left>0 or target.frozen_ticks_left>0 or target.sleep_ticks_left>0 or target.stun_ticks_left>0 or target.silence_ticks_left>0 or target.bind_ticks_left>0 or target.slow_ticks_left>0


static func candidates(state: MatchState, source: UnitState, priority: bool, full_control: bool=false) -> Array[UnitState]:
	var result: Array[UnitState]=[]
	var data: OperatorData=state._operator_data[source.operator_id]
	for ally in state.units:
		if ally.side!=source.side or not can_heal(state,ally) or not state._is_in_attack_range(source,ally.cell,data.attack_range):continue
		if ally.hp<SkillRules.max_health_value(ally,state._operator_data[ally.operator_id]) or (full_control and has_control(ally)):result.append(ally)
	result.sort_custom(func(a: UnitState,b: UnitState) -> bool:
		if priority and has_control(a)!=has_control(b):return has_control(a)
		var am := SkillRules.max_health_value(a,state._operator_data[a.operator_id])
		var bm := SkillRules.max_health_value(b,state._operator_data[b.operator_id])
		return a.unit_id<b.unit_id if a.hp*bm==b.hp*am else a.hp*bm<b.hp*am)
	return result


static func treat(state: MatchState, source: UnitState, target: UnitState, heal_percent: int) -> void:
	var data: OperatorData=state._operator_data[source.operator_id]
	var distance_percent := 100 if state._is_in_attack_range(source,target.cell,NEAR_RANGE) else int(data.branch_trait.effect_params["far_heal_percent"])
	var amount := roundi(SkillRules.attack_value(source,data)*heal_percent*distance_percent*state.CONFIG.UNIT_HEAL_PERCENT/1000000.0)
	treat_amount(state,target,amount,source)


static func treat_amount(state: MatchState, target: UnitState, amount: int, source: UnitState) -> void:
	if not can_heal(state,target):return
	var data: OperatorData=state._operator_data[target.operator_id]
	var maximum := SkillRules.max_health_value(target,data)
	if source!=null and source.silence_ticks_left==0 and state._operator_data[source.operator_id].talent_1.effect_type=="heal_resistance":
		var talent: TalentResource=state._operator_data[source.operator_id].talent_1
		target.lumen_resistance_ticks=maxi(target.lumen_resistance_ticks,int(talent.effect_params["high_ticks"] if target.hp*100>maximum*int(talent.effect_params["hp_threshold_percent"]) else talent.effect_params["base_ticks"]))
	var before := target.hp
	target.hp=mini(maximum,target.hp+SkillRules.healing_received(target,data,amount,source))
	if target.hp>before:target.last_heal_tick=state.tick
	if target.titi_doze_mode==3 and target.hp==maximum:TitiRules.clear_doze(target)


static func clear_controls(state: MatchState, target: UnitState) -> void:
	var data: OperatorData=state._operator_data[target.operator_id]
	var old_interval := SkillRules.attack_interval_ticks(target,data)
	var old_remaining := target.attack_ticks_left
	target.cold_ticks_left=0;target.frozen_ticks_left=0
	target.sleep_ticks_left=0
	TitiRules.clear_doze(target)
	target.stun_ticks_left=0
	target.silence_ticks_left=0
	if target.bind_ticks_left > 0:target.bind_immunity_ticks_left = state.CONFIG.BIND_IMMUNITY_TICKS
	target.bind_ticks_left=0
	target.slow_ticks_left=0
	AuraRules.refresh(state)
	target.attack_ticks_left=ceili(float(old_remaining)*SkillRules.attack_interval_ticks(target,data)/old_interval)


static func emergency(state: MatchState, target: UnitState) -> void:
	if not can_heal(state,target) or target.hp>=SkillRules.max_health_value(target,state._operator_data[target.operator_id]):return
	for source in state.units:
		var data: OperatorData=state._operator_data[source.operator_id]
		if source.hp<=0 or source.side!=target.side or source.silence_ticks_left>0 or data.talent_2.effect_type!="emergency_control_heal" or state.tick<source.lumen_emergency_ready_tick:continue
		if not state._is_in_attack_range(source,target.cell,data.attack_range):continue
		source.lumen_emergency_ready_tick=state.tick+int(data.talent_2.effect_params["cooldown_ticks"])
		treat(state,source,target,int(data.talent_2.effect_params["heal_percent"]))
		source.lumen_special_tick=state.tick


static func activate(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="lumen_lamp":
		if unit.skill_ticks_left!=0:close_lamp(state,unit,data)
		else:
			SkillRules.activate(unit,data)
			unit.skill_ammo_left=int(skill.effect_params["ammo_count"])
			unit.lumen_lamp_started_tick=state.tick
		return
	var charged := unit.sp>=skill.sp_required*int(skill.effect_params["charge_count"])
	SkillRules.activate(unit,data)
	unit.sp=0
	unit.skill_ticks_left=0
	unit.lumen_special_tick=state.tick
	unit.lumen_cast_tick=state.tick
	var allies := candidates(state,unit,false,charged)
	for index in mini(allies.size(),int(skill.effect_params["target_count"])):
		treat(state,unit,allies[index],int(skill.effect_params["heal_percent"]))
		if charged:clear_controls(state,allies[index])


static func close_lamp(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var old_interval := SkillRules.attack_interval_ticks(unit,data)
	unit.skill_ticks_left=0
	unit.skill_ammo_left=0
	unit.lumen_lamp_closed_tick=state.tick
	unit.skill_elapsed_ticks=0
	unit.attack_ticks_left=ceili(float(unit.attack_ticks_left)*SkillRules.attack_interval_ticks(unit,data)/old_interval)


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,unit):return
	var skill := data.skills[unit.skill_index]
	var lamp := SkillRules.active_ticks(unit)!=0 and skill.effect_type=="lumen_lamp"
	var allies := candidates(state,unit,lamp)
	allies=AttackTimeline.pinned(state,unit,allies)
	if allies.is_empty():return
	if not AttackTimeline.windup(state,unit,data,allies.slice(0,1),allies[0].cell,true):return
	var target := allies[0]
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	unit.last_attack_tick=state.tick
	unit.last_attack_is_heal=true
	unit.last_attack_target_x=target.cell.x
	unit.last_attack_target_y=target.cell.y
	if skill.effect_type=="lumen_rain" and SkillRules.can_activate(unit,skill):
		SkillRules.activate(unit,data)
		unit.skill_ticks_left=0
		unit.lumen_special_tick=state.tick
		unit.lumen_cast_tick=state.tick
		var field := LumenRainField.new()
		field.field_id=state.next_lumen_field_id
		state.next_lumen_field_id+=1
		field.source_id=unit.unit_id;field.side=unit.side;field.cell=target.cell;field.source_cell=unit.cell;field.facing=unit.facing
		field.attack=SkillRules.attack_value(unit,data);field.pulse_ticks=int(skill.effect_params["pulse_ticks"]);field.pulses_left=int(skill.effect_params["pulse_count"]);field.heal_percent=int(skill.effect_params["heal_percent"])
		field.next_pulse_tick=state.tick+field.pulse_ticks
		state.lumen_rain_fields.append(field)
		return
	var consumes := lamp and has_control(target)
	treat(state,unit,target,roundi(float(skill.effect_params["heal_mult"])*100) if consumes else 100)
	if consumes:
		clear_controls(state,target)
		unit.skill_ammo_left-=1
		if unit.skill_ammo_left==0:close_lamp(state,unit,data)


static func advance_rain(state: MatchState) -> void:
	var alive: Array[LumenRainField]=[]
	for field in state.lumen_rain_fields:
		if state.tick>=field.next_pulse_tick:
			var source := WArtilleryRules.owner(state,field.source_id)
			var origin := UnitState.new(-1,field.side,"lumen",field.source_cell,1,0,0,field.facing)
			for target in state.units:
				if target.side!=field.side or not can_heal(state,target) or absi(target.cell.x-field.cell.x)>1 or absi(target.cell.y-field.cell.y)>1:continue
				var distance_percent := 100 if state._is_in_attack_range(origin,target.cell,NEAR_RANGE) else int(state._operator_data["lumen"].branch_trait.effect_params["far_heal_percent"])
				var amount := roundi(field.attack*field.heal_percent*distance_percent*state.CONFIG.UNIT_HEAL_PERCENT/1000000.0)
				treat_amount(state,target,amount,source)
			field.pulses_left-=1
			field.next_pulse_tick+=field.pulse_ticks
		if field.pulses_left>0:alive.append(field)
	state.lumen_rain_fields=alive
