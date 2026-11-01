class_name PenanceRules
extends RefCounted


static func initialize_barriers(state: MatchState) -> void:
	for unit in state.units:
		if unit.penance_barrier_hp>=0:continue
		unit.penance_barrier_hp=0
		var data: OperatorData=state._operator_data[unit.operator_id]
		grant(state,unit,data,int(data.talent_1.effect_params["deploy_health_percent"]))


static func grant(state: MatchState, unit: UnitState, data: OperatorData, percent: int) -> void:
	var maximum := SkillRules.max_health_value(unit,data)
	var cap := roundi(maximum*int(data.talent_1.effect_params["cap_health_percent"])/100.0)
	if unit.penance_barrier_hp<cap:unit.penance_barrier_hp=mini(cap,unit.penance_barrier_hp+roundi(maximum*percent/100.0))


static func reward_kill(state: MatchState, source: UnitState, target: UnitState) -> void:
	var data: OperatorData=state._operator_data[source.operator_id]
	if source.side==target.side or source.silence_ticks_left>0 or data.talent_1.effect_type!="penance_barrier":return
	var percent := int(data.talent_1.effect_params["kill_health_percent"])
	var skill := data.skills[source.skill_index]
	if SkillRules.active_ticks(source)>0 and skill.effect_type=="penance_ascetic":percent=percent*(100+int(skill.effect_params["barrier_gain_bonus_percent"]))/100
	grant(state,source,data,percent)


static func reflect(state: MatchState, target: UnitState, data: OperatorData, source: UnitState) -> void:
	if source==null or source.hp<=0 or source.side==target.side or target.hp<=0 or target.silence_ticks_left>0 or target.penance_barrier_hp<=0 or data.talent_2.effect_type!="barrier_reflect":return
	var source_data: OperatorData=state._operator_data[source.operator_id]
	var attack := roundi(SkillRules.attack_value(target,data)*int(data.talent_2.effect_params["attack_percent"])/100.0)
	var damage := Combat.calculate_damage(attack,SkillRules.defense_value(source,source_data),SkillRules.magic_resist_value(source,source_data),"magical",SkillRules.dodge_chance(source,source_data,"magical"),state.rng,data.profession_id,state._damage_taken_percent(source,"magical"),state._magical_damage_taken_percent(source))
	state._apply_damage(source,source_data,damage,"magical",target,false)


static func absorb(state: MatchState, target: UnitState, data: OperatorData, damage: int, attack_event: bool) -> int:
	if target.penance_barrier_hp<=0:return damage
	var absorbed := mini(damage,target.penance_barrier_hp)
	target.penance_barrier_hp-=absorbed;damage-=absorbed
	if damage==0:
		target.last_damage_block_tick=state.tick
		if attack_event and data.skills[target.skill_index].sp_recharge_type=="on_damaged" and target.skill_ticks_left==0:SagaRules.reward(state,target,1)
	return damage


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	SkillRules.activate(unit,data)
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="penance_bramble":grant(state,unit,data,int(skill.effect_params["barrier_health_percent"]))


static func pulse(state: MatchState) -> void:
	for source in state.units:
		var data: OperatorData=state._operator_data[source.operator_id]
		var skill := data.skills[source.skill_index]
		if source.hp<=0 or SkillRules.active_ticks(source)<=0 or skill.effect_type!="penance_ascetic" or (source.skill_elapsed_ticks+1)%int(skill.effect_params["pulse_ticks"])!=0:continue
		var attack := roundi(SkillRules.attack_value(source,data)*float(skill.effect_params["pulse_attack_mult"]))
		for enemy in state.units.duplicate():
			if source.hp<=0:break
			if enemy.hp>0 and enemy.side!=source.side and state.terrain_at(enemy.cell)=="ground" and state._is_in_attack_range(source,enemy.cell,skill.burst_range_override):hit(state,source,data,enemy,attack,"magical",false)


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="penance_hammer" and unit.sp>=SkillRules.sp_limit(skill) and not unit.penance_charged_mode:
		unit.penance_charged_mode=true;unit.attack_ticks_left=0
	if SkillRules.active_ticks(unit)>0 and skill.effect_type=="penance_ascetic":return
	if not AttackTimeline.advance(state,unit):return
	var found := SwordRules.target(state,unit,data.attack_range,false)
	found=AttackTimeline.pin_found(state,unit,found)
	if found.is_empty():return
	if not AttackTimeline.windup_found(state,unit,data,found):return
	var triggered := skill.effect_type=="penance_hammer" and SkillRules.can_activate(unit,skill)
	var enhanced := triggered and unit.penance_charged_mode
	if triggered:SkillRules.activate(unit,data);unit.sp=0
	PusherRules.mark_attack(state,unit,found.cell);BlemishineRules.on_basic_attack(state,unit)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var attack_value := SkillRules.attack_value(unit,data)
	if enhanced:attack_value=roundi(attack_value*float(skill.effect_params["charged_attack_mult"]))
	if found.kind==0:
		var landed := hit(state,unit,data,found.unit,attack_value,"physical")
		if triggered and found.unit.hp>0 and unit.hp>0:landed=hit(state,unit,data,found.unit,roundi(attack_value*float(skill.effect_params["magic_attack_mult"])),"magical") or landed
		if enhanced and landed and found.unit.hp>0:SwordRules.stun(state,found.unit,int(skill.effect_params["stun_ticks"]),unit)
	else:
		var shots := 2 if triggered else 1
		for index in shots:
			if found.kind==1:
				if found.box.hits_left>0:TacticalRules.strike_box(state,unit,found.box)
			elif state.ball.move_ticks_left==0:
				var power := roundi(attack_value*float(skill.effect_params["magic_attack_mult"])) if triggered and index==1 else attack_value
				state.ball.add_push(unit.cell,power,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
	if triggered:unit.skill_ticks_left=0;unit.penance_charged_mode=false


static func hit(state: MatchState, source: UnitState, data: OperatorData, target: UnitState, attack_value: int, kind: String, attack_event: bool = true) -> bool:
	var target_data: OperatorData=state._operator_data[target.operator_id]
	var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),kind,SkillRules.dodge_chance(target,target_data,kind),state.rng,data.profession_id,state._damage_taken_percent(target,kind),state._magical_damage_taken_percent(target))
	return state._apply_damage(target,target_data,damage,kind,source,attack_event)
