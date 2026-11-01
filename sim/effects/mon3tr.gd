class_name Mon3trRules
extends RefCounted


static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id=="kaltsit":return unit
	return null


static func owner_for(state: MatchState, token: UnitState) -> UnitState:
	for unit in state.units:
		if unit.unit_id==token.mon3tr_owner_id and unit.hp>0 and unit.operator_id=="kaltsit":return unit
	return null


static func summon_for(state: MatchState, source: UnitState) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.operator_id=="mon3tr" and unit.mon3tr_owner_id==source.unit_id:return unit
	return null


static func visible(state: MatchState, side: int) -> bool:
	var source := owner(state,side)
	return source!=null and source.silence_ticks_left==0 and summon_for(state,source)==null


static func available(state: MatchState, side: int) -> bool:
	return state.result==state.RESULT_RUNNING and visible(state,side) and state.sides[side].cooldowns.get("mon3tr",0)==0 and state.sides[side].cost>=state.MON3TR_DATA.deploy_cost


static func can_charge(state: MatchState, unit: UnitState, skill: SkillResource) -> bool:
	return skill.effect_type not in ["kaltsit_tactical","kaltsit_meltdown"] or summon_for(state,unit)!=null


static func end_binding(source: UnitState) -> void:
	if source.skill_index==0:return
	source.sp=0
	source.sp_regen_ticks=0
	source.sp_regen_accum=0
	source.skill_ticks_left=0
	source.skill_elapsed_ticks=0


static func remove_token(state: MatchState, token: UnitState) -> void:
	state.sides[token.side].cooldowns["mon3tr"]=roundi(state.MON3TR_DATA.redeploy_time*state.CONFIG.TICK_RATE)
	var source := owner_for(state,token)
	state.units.erase(token)
	if source!=null:end_binding(source)


static func remove_owned(state: MatchState, source: UnitState) -> void:
	var retained: Array[UnitState]=[]
	for unit in state.units:
		if unit.operator_id=="mon3tr" and unit.mon3tr_owner_id==source.unit_id:
			state.sides[unit.side].cooldowns["mon3tr"]=roundi(state.MON3TR_DATA.redeploy_time*state.CONFIG.TICK_RATE)
		else:retained.append(unit)
	state.units=retained
	end_binding(source)


static func maintain_binding(state: MatchState) -> void:
	var retained: Array[UnitState]=[]
	for unit in state.units:
		if unit.operator_id=="mon3tr" and owner_for(state,unit)==null:
			state.sides[unit.side].cooldowns["mon3tr"]=roundi(state.MON3TR_DATA.redeploy_time*state.CONFIG.TICK_RATE)
		else:retained.append(unit)
	state.units=retained
	for unit in state.units:
		if unit.hp>0 and unit.operator_id=="kaltsit" and unit.skill_index>0 and summon_for(state,unit)==null:end_binding(unit)


static func activate(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var token := summon_for(state,source)
	if source.skill_index>0 and token==null:return
	SkillRules.activate(source,data)
	if source.skill_index==2:token.mon3tr_killed=false
	AuraRules.refresh(state)


static func refresh_range(state: MatchState) -> void:
	for token in state.units:
		if token.operator_id!="mon3tr":continue
		var source := owner_for(state,token)
		token.mon3tr_outside_range=source==null or not state._is_in_attack_range(source,token.cell,(state._operator_data["kaltsit"] as OperatorData).attack_range)


static func refresh_buffs(state: MatchState) -> void:
	refresh_range(state)
	for token in state.units:
		if token.operator_id!="mon3tr":continue
		token.mon3tr_mode=0
		var source := owner_for(state,token)
		if source==null or token.hp<=0 or SkillRules.active_ticks(source)<=0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		var skill := data.skills[source.skill_index]
		token.mon3tr_mode=source.skill_index+1
		if skill.effect_type in ["kaltsit_guard","kaltsit_meltdown"]:token.defense_bonus_percent+=int(skill.effect_params["defense_percent"])
		if skill.effect_type=="kaltsit_tactical":token.attack_bonus_percent+=int(skill.effect_params["mon3tr_attack_percent"])
		if skill.effect_type=="kaltsit_meltdown":
			token.mon3tr_decay_ticks_left=source.skill_ticks_left
			token.mon3tr_decay_duration_ticks=roundi(skill.duration*state.CONFIG.TICK_RATE)
			token.mon3tr_attack_peak_percent=int(skill.effect_params["attack_peak_percent"])


static func heal(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,unit):return
	var target: UnitState
	var maximum := 1
	var priority := false
	for ally in state.units:
		if ally.hp<=0 or ally.critical_ticks_left>0 or ally.side!=unit.side:continue
		var ally_data: OperatorData=state._operator_data[ally.operator_id]
		if ally_data.branch_trait.effect_type in ["musha","unyield"]:continue
		if ally_data.profession_id=="summon" and ally.mon3tr_owner_id!=unit.unit_id:continue
		var max_hp := SkillRules.max_health_value(ally,ally_data)
		if ally.hp>=max_hp or not state._is_in_attack_range(unit,ally.cell,data.attack_range):continue
		var preferred := unit.silence_ticks_left==0 and (ally==unit or ally.mon3tr_owner_id==unit.unit_id)
		if target==null or (preferred and not priority) or (preferred==priority and ally.hp*maximum<target.hp*max_hp):
			target=ally;maximum=max_hp;priority=preferred
	target=AttackTimeline.heal_target(state,unit,target)
	if target==null:return
	var locked_heals: Array[UnitState]=[target]
	if not AttackTimeline.windup(state,unit,data,locked_heals,target.cell,true):return
	var target_data: OperatorData=state._operator_data[target.operator_id]
	var amount := SkillRules.healing_received(target,target_data,Combat.calculate_healing(SkillRules.attack_value(unit,data)),unit)
	target.hp=mini(maximum,target.hp+amount)
	target.last_heal_tick=state.tick
	PusherRules.mark_attack(state,unit,target.cell)
	unit.last_attack_is_heal=true
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)


static func attack(state: MatchState, token: UnitState, data: OperatorData) -> void:
	if owner_for(state,token)==null:return
	if not AttackTimeline.advance(state,token):return
	var found := SwordRules.target(state,token,data.attack_range,false)
	found=AttackTimeline.pin_found(state,token,found)
	if found.is_empty():return
	var locked:=AttackTimeline.pinned(state,token,PusherRules.targets(state,token,data.attack_range,false,true))
	if not AttackTimeline.windup(state,token,data,locked,found.cell):return
	PusherRules.mark_attack(state,token,found.cell)
	token.attack_ticks_left=SkillRules.attack_interval_ticks(token,data)
	if found.kind==0:
		var targets: Array[UnitState]=[found.unit]
		if token.mon3tr_mode==2:
			targets=locked
			targets.resize(mini(targets.size(),SkillRules.block_count_value(token,data)))
		for enemy in targets:
			if token.hp<=0:break
			var target_data: OperatorData=state._operator_data[enemy.operator_id]
			var dtype := SkillRules.damage_type(token,data)
			var damage := Combat.calculate_damage(SkillRules.attack_output_value(token,data),SkillRules.defense_value(enemy,target_data),SkillRules.magic_resist_value(enemy,target_data),dtype,SkillRules.dodge_chance(enemy,target_data,dtype),state.rng,SkillRules.damage_profession_id(data),state._damage_taken_percent(enemy, dtype),state._magical_damage_taken_percent(enemy))
			state._apply_damage(enemy,target_data,damage,dtype,token)
	else:SwordRules.hit_object(state,token,data,found)


static func finish_meltdown(state: MatchState, source: UnitState, skill: SkillResource) -> void:
	var token := summon_for(state,source)
	if token==null or token.mon3tr_killed:return
	var loss := roundi(SkillRules.max_health_value(token,state.MON3TR_DATA)*int(skill.effect_params["hp_loss_percent"])/100.0)
	state._apply_skill_life_loss(token,state.MON3TR_DATA,loss)
	if token.hp<=0:on_death(state,token)


static func resolve_deaths(state: MatchState) -> void:
	maintain_binding(state)
	for unit in state.units:
		if unit.operator_id=="mon3tr" and unit.hp<=0:on_death(state,unit)


static func on_death(state: MatchState, token: UnitState) -> void:
	if token.mon3tr_death_triggered:return
	token.mon3tr_death_triggered=true
	state.sides[token.side].cooldowns["mon3tr"]=roundi(state.MON3TR_DATA.redeploy_time*state.CONFIG.TICK_RATE)
	var source := owner_for(state,token)
	if source==null:return
	end_binding(source)
	if source.silence_ticks_left>0:return
	var params := (state._operator_data[source.operator_id] as OperatorData).talent_2.effect_params
	for enemy in state.units:
		var offset := enemy.cell-token.cell
		if enemy.hp<=0 or enemy.side==token.side or offset==Vector2i.ZERO or absi(offset.x)>1 or absi(offset.y)>1:continue
		var data: OperatorData=state._operator_data[enemy.operator_id]
		var damage := Combat.calculate_damage(int(params["damage"]),0,0,"true",0,state.rng,SkillRules.damage_profession_id(state.MON3TR_DATA),state._damage_taken_percent(enemy, "true"))
		var landed := state._apply_damage(enemy,data,damage,"true",token)
		if landed and enemy.hp>0:SwordRules.stun(state,enemy,int(params["stun_ticks"]),token)
