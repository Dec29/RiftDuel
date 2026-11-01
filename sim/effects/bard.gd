class_name BardRules
extends RefCounted


static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id=="skadi_alter":return unit
	return null


static func token_for(state: MatchState, source: UnitState) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.operator_id=="seaborn" and unit.bard_owner_id==source.unit_id:return unit
	return null


static func visible(state: MatchState, side: int) -> bool:
	var source := owner(state,side)
	return source!=null and source.silence_ticks_left==0 and token_for(state,source)==null


static func available(state: MatchState, side: int) -> bool:
	return state.result==state.RESULT_RUNNING and visible(state,side) and state.sides[side].cooldowns.get("seaborn",0)==0 and state.sides[side].cost>=state.SEABORN_DATA.deploy_cost


static func remove_token(state: MatchState, token: UnitState) -> void:
	state.sides[token.side].cooldowns["seaborn"]=roundi(state.SEABORN_DATA.redeploy_time*state.CONFIG.TICK_RATE)
	state.units.erase(token)


static func remove_owned(state: MatchState, source: UnitState) -> void:
	var retained: Array[UnitState]=[]
	for unit in state.units:
		if unit.operator_id=="seaborn" and unit.bard_owner_id==source.unit_id:state.sides[unit.side].cooldowns["seaborn"]=roundi(state.SEABORN_DATA.redeploy_time*state.CONFIG.TICK_RATE)
		else:retained.append(unit)
	state.units=retained


static func maintain_binding(state: MatchState) -> void:
	var retained: Array[UnitState]=[]
	for unit in state.units:
		if unit.operator_id=="seaborn":
			var source := WArtilleryRules.owner(state,unit.bard_owner_id)
			if source==null or source.operator_id!="skadi_alter" or state.tick-unit.deployed_tick>=int(state.SEABORN_DATA.branch_trait.effect_params["lifetime_ticks"]):
				state.sides[unit.side].cooldowns["seaborn"]=roundi(state.SEABORN_DATA.redeploy_time*state.CONFIG.TICK_RATE)
				continue
		retained.append(unit)
	state.units=retained


static func covers(state: MatchState, source: UnitState, cell: Vector2i) -> bool:
	var data: OperatorData=state._operator_data[source.operator_id]
	if data.talent_1.effect_type=="encore_sp":return state._is_in_attack_range(source,cell,AttackRange.effective_offsets(source,data))
	if state._is_in_attack_range(source,cell,data.attack_range):return true
	var token := token_for(state,source)
	return source.silence_ticks_left==0 and token!=null and state._is_in_attack_range(token,cell,state.SEABORN_DATA.attack_range)


static func refresh_buffs(state: MatchState) -> void:
	for token in state.units:
		if token.operator_id=="seaborn":
			var source := WArtilleryRules.owner(state,token.bard_owner_id)
			token.bard_mode=source.skill_index+1 if source!=null and SkillRules.active_ticks(source)!=0 else 0
	for source in state.units:
		var data: OperatorData=state._operator_data[source.operator_id]
		if source.hp<=0 or source.silence_ticks_left>0 or data.branch_trait.effect_type!="bard" or data.talent_2.effect_type!="bard_predation":continue
		var bonus := 0
		for ally in state.units:
			var ally_data: OperatorData=state._operator_data[ally.operator_id]
			if ally==source or ally.hp<=0 or ally.side!=source.side or ally_data.profession_id=="summon" or not covers(state,source,ally.cell):continue
			bonus=maxi(bonus,int(data.talent_2.effect_params["abyssal_attack_percent"] if ally_data.group_id=="abyssal" else data.talent_2.effect_params["attack_percent"]))
		source.attack_bonus_percent+=bonus
	_refresh_inspiration(state)


static func _refresh_inspiration(state: MatchState) -> void:
	var sources: Array[UnitState] = []
	for source in state.units:
		var data: OperatorData = state._operator_data[source.operator_id]
		if source.hp > 0 and data.branch_trait.effect_type == "bard" and SkillRules.active_ticks(source) != 0 and data.skills[source.skill_index].effect_type in ["bard_song", "bard_inspire", "bard_tide"]:
			sources.append(source)
	if sources.is_empty():return
	for ally in state.units:
		var ally_data: OperatorData = state._operator_data[ally.operator_id]
		if ally.hp <= 0 or ally_data.branch_trait.effect_type in ["bard","pozyomka_typewriter","silence_drone"]:continue
		var accepts_song := ally_data.branch_trait.effect_type not in ["medical_drone", "water_cannon", "seaborn"]
		var song_present := false
		var highest_ratio := 0
		var ratio_attack := 0
		for source in sources:
			if source.side != ally.side or not covers(state, source, ally.cell):continue
			var data: OperatorData = state._operator_data[source.operator_id]
			var skill := data.skills[source.skill_index]
			var ratio := int(skill.effect_params["inspire_attack_percent"])
			var attack_add := roundi(SkillRules.attack_value(source, data) * ratio / 100.0)
			if skill.effect_type != "bard_song":
				ally.inspire_attack_add = maxi(ally.inspire_attack_add, attack_add)
				if skill.effect_type == "bard_inspire":
					ally.inspire_defense_add = maxi(ally.inspire_defense_add, roundi(SkillRules.defense_value(source, data) * int(skill.effect_params["inspire_defense_percent"]) / 100.0))
			# Preserve the approved mixed-song policy and device exclusions. Permanent
			# Skadi-only inspiration keeps its existing highest-final-value selection.
			if accepts_song and SkillRules.active_ticks(source) > 0:
				song_present = song_present or skill.effect_type == "bard_song"
				if ratio > highest_ratio:
					highest_ratio = ratio
					ratio_attack = attack_add
				elif ratio == highest_ratio:
					ratio_attack = maxi(ratio_attack, attack_add)
		if song_present:ally.inspire_attack_add = ratio_attack


static func regenerate(state: MatchState) -> void:
	for target in state.units:
		if target.hp<=0 or target.critical_ticks_left>0 or target.operator_id=="seaborn":continue
		var recovery := 0
		for source in state.units:
			var data: OperatorData=state._operator_data[source.operator_id]
			if source.hp<=0 or source.side!=target.side or data.branch_trait.effect_type!="bard" or not covers(state,source,target.cell):continue
			var skill := data.skills[source.skill_index]
			var percent := int(data.branch_trait.effect_params["regen_attack_percent"])
			if SkillRules.active_ticks(source)!=0:
				if skill.effect_type=="bard_tide":continue
				percent=int(skill.effect_params["regen_attack_percent"])
			recovery+=SkillRules.attack_value(source,data)*percent
		target.bard_regen_accum+=recovery*state.CONFIG.UNIT_HEAL_PERCENT
		var healed := target.bard_regen_accum/(10000*state.CONFIG.TICK_RATE)
		target.bard_regen_accum%=10000*state.CONFIG.TICK_RATE
		var maximum := SkillRules.max_health_value(target,state._operator_data[target.operator_id])
		if healed>0 and target.hp<maximum:
			target.hp=mini(maximum,target.hp+healed)
			target.last_heal_tick=state.tick


static func activate(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if data.skills[unit.skill_index].effect_type=="bard_share":
		unit.hp=SkillRules.max_health_value(unit,data)
		unit.last_heal_tick=state.tick
	SkillRules.activate(unit,data)
	unit.bard_skill_started_tick=state.tick
	unit.bard_loss_accum=0
	AuraRules.refresh(state)


static func share_damage(state: MatchState, target: UnitState, damage: int) -> int:
	var chosen: UnitState
	var percent := 0
	for source in state.units:
		var data: OperatorData=state._operator_data[source.operator_id]
		if source==target or source.hp<=0 or source.side!=target.side or SkillRules.active_ticks(source)<=0 or data.skills[source.skill_index].effect_type!="bard_share" or not covers(state,source,target.cell):continue
		var candidate := int(data.skills[source.skill_index].effect_params["share_percent"])
		if candidate>percent:chosen=source;percent=candidate
	if chosen==null:return damage
	var transferred := damage*percent/100
	state._apply_skill_life_loss(chosen,state._operator_data[chosen.operator_id],transferred)
	if chosen.hp<=0:
		remove_owned(state,chosen)
		WArtilleryRules.on_exit(state,chosen)
		AuraRules.refresh(state)
	return damage-transferred


static func advance(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var skill := data.skills[source.skill_index]
	if skill.effect_type=="bard_inspire" and SkillRules.can_activate(source,skill):
		SkillRules.activate(source,data)
		source.bard_skill_started_tick=state.tick
		AuraRules.refresh(state)
	if SkillRules.active_ticks(source)<=0 or skill.effect_type!="bard_tide" or (source.skill_elapsed_ticks+1)%int(skill.effect_params["pulse_ticks"])!=0:return
	source.bard_pulse_tick=state.tick
	var attack_value := roundi(SkillRules.attack_value(source,data)*int(skill.effect_params["damage_attack_percent"])/100.0)
	var token := token_for(state,source)
	if token!=null:token.bard_pulse_tick=state.tick
	var enemy_found := false
	for enemy in state.units:
		if enemy.hp<=0 or enemy.side==source.side or enemy.operator_id in ["weedy_cannon","seaborn"]:continue
		var count := 1 if state._is_in_attack_range(source,enemy.cell,data.attack_range) else 0
		if token!=null and state._is_in_attack_range(token,enemy.cell,state.SEABORN_DATA.attack_range):count+=1
		if count==0:continue
		enemy_found=true
		var enemy_data: OperatorData=state._operator_data[enemy.operator_id]
		for pulse in count:
			if enemy.hp<=0:break
			var damage := Combat.calculate_damage(attack_value,0,0,"true",0,state.rng,data.profession_id,state._damage_taken_percent(enemy,"true"))
			state._apply_damage(enemy,enemy_data,damage,"true",source)
	if not enemy_found:
		var box_found := false
		for box in state.tactical_boxes:
			if covers(state,source,box.cell):TacticalRules.strike_box(state,source,box);box_found=true;break
		if not box_found and state.ball.move_ticks_left==0 and covers(state,source,state.ball.cell):
			var origin := source if state._is_in_attack_range(source,state.ball.cell,data.attack_range) else token
			state.ball.add_push(origin.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,origin.facing))
	source.bard_loss_accum+=SkillRules.max_health_value(source,data)*int(skill.effect_params["hp_loss_percent"])
	var loss := source.bard_loss_accum/100
	source.bard_loss_accum%=100
	state._apply_skill_life_loss(source,data,loss)
	if source.hp<=0:
		remove_owned(state,source)
		WArtilleryRules.on_exit(state,source)
		AuraRules.refresh(state)
