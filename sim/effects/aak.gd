class_name AakRules
extends RefCounted


static func refresh_buff(unit: UnitState) -> void:
	# Values are stored from the selected M3 resource when the injection completes.
	if unit.aak_buff_ticks<=0 or (unit.aak_buff_source_id==unit.unit_id and unit.silence_ticks_left>0):return
	unit.attack_bonus_percent+=unit.aak_attack_percent
	unit.attack_speed_bonus+=unit.aak_speed_add
	unit.defense_bonus_percent+=unit.aak_defense_percent
	unit.max_health_bonus_percent+=unit.aak_health_percent


static func friendly_target(state: MatchState, unit: UnitState, data: OperatorData) -> UnitState:
	var result: UnitState
	var direction := AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing)
	for ally in state.units:
		if ally.hp<=0 or ally.side!=unit.side or ally==unit or state._operator_data[ally.operator_id].profession_id=="summon" or not state._is_in_attack_range(unit,ally.cell,data.attack_range):continue
		if result==null:result=ally;continue
		var offset := ally.cell-unit.cell
		var previous := result.cell-unit.cell
		var straight := (offset.x*direction.x+offset.y*direction.y)>0 and (offset.x*direction.y-offset.y*direction.x)==0
		var old_straight := (previous.x*direction.x+previous.y*direction.y)>0 and (previous.x*direction.y-previous.y*direction.x)==0
		if (straight and not old_straight) or (straight==old_straight and offset.length_squared()<previous.length_squared()):result=ally
	return result


static func activate(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var target := friendly_target(state,unit,data)
	if target==null:return
	var skill := data.skills[unit.skill_index]
	SkillRules.activate(unit,data)
	unit.aak_injection_tick=state.tick
	var target_data: OperatorData=state._operator_data[target.operator_id]
	for shot in int(skill.effect_params["shot_count"]):
		if target.hp<=0 or unit.hp<=0:break
		var damage := Combat.calculate_damage(int(skill.effect_params["shot_attack"]),SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target, "physical"))
		state._apply_damage(target,target_data,damage,"physical",unit)
	PusherRules.mark_attack(state,unit,target.cell)
	for recipient in [unit,target]:
		if recipient.hp<=0:continue
		recipient.aak_buff_ticks=roundi(skill.duration*state.CONFIG.TICK_RATE)
		recipient.aak_buff_index=unit.skill_index
		recipient.aak_buff_source_id=unit.unit_id
		recipient.aak_attack_percent=int(skill.effect_params["attack_percent"]) if skill.effect_type=="aak_offense" else 0
		recipient.aak_speed_add=int(skill.effect_params["attack_speed_add"]) if skill.effect_type=="aak_offense" else 0
		recipient.aak_defense_percent=int(skill.effect_params["defense_percent"]) if skill.effect_type=="aak_defense" else 0
		recipient.aak_health_percent=int(skill.effect_params["health_percent"]) if skill.effect_type=="aak_defense" else 0
	AuraRules.refresh(state)


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.last_attack_tick==state.tick:return
	if not AttackTimeline.advance(state,unit):return
	var found := SwordRules.target(state,unit,data.attack_range,false)
	found=AttackTimeline.pin_found(state,unit,found)
	if found.is_empty():return
	if not AttackTimeline.windup_found(state,unit,data,found):return
	var proc := int(state.rng.next_u32()%4) if unit.silence_ticks_left==0 else -1
	var attack_value := SkillRules.attack_output_value(unit,data)
	var params := data.talent_1.effect_params
	if proc==0:
		var max_hp := SkillRules.max_health_value(unit,data)
		var amount := SkillRules.healing_received(unit,data,Combat.calculate_healing(max_hp,int(params["heal_percent"])),unit)
		unit.hp=mini(max_hp,unit.hp+amount);unit.last_heal_tick=state.tick
	elif proc==1:attack_value=roundi(attack_value*int(params["attack_percent"])/100.0)
	PusherRules.mark_attack(state,unit,found.cell)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var shot:=AttackTimeline.found_projectile(state,unit,data,found,attack_value,"physical")
	if proc==2:shot.slow_ticks=int(params.slow_ticks)
	elif proc==3:shot.stun_ticks=int(params.stun_ticks)
