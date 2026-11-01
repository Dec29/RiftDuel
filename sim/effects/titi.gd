class_name TitiRules
extends RefCounted


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="titi_sanctuary" and unit.skill_ticks_left>0:
		unit.skill_ticks_left=0;finish(state,unit,data);AuraRules.refresh(state);return
	SkillRules.activate(unit,data)
	unit.titi_dot_next_tick=state.tick+int(data.talent_1.effect_params["first_dot_ticks"])
	unit.titi_sleep_ids.clear();unit.titi_sleep_elapsed.clear()
	if skill.effect_type=="titi_sanctuary":
		var target: UnitState
		for ally in state.units:
			if ally.hp<=0 or ally.side!=unit.side or state._operator_data[ally.operator_id].profession_id=="summon" or not state._is_in_attack_range(unit,ally.cell,data.attack_range):continue
			if target==null or ally.hp*SkillRules.max_health_value(target,state._operator_data[target.operator_id])<target.hp*SkillRules.max_health_value(ally,state._operator_data[ally.operator_id]):target=ally
		unit.titi_sanctuary_target_id=target.unit_id if target!=null else -1
		set_doze(unit,unit,2)
		if target!=null:set_doze(target,unit,2)
	AuraRules.refresh(state)


static func set_doze(target: UnitState, source: UnitState, mode: int) -> void:
	target.titi_doze_owner_id=source.unit_id;target.titi_doze_mode=mode


static func clear_doze(target: UnitState) -> void:
	target.titi_doze_owner_id=-1;target.titi_doze_mode=0


static func maintain_doze(state: MatchState) -> void:
	for target in state.units:
		if target.titi_doze_owner_id<0:continue
		var source := WArtilleryRules.owner(state,target.titi_doze_owner_id)
		if source==null or source.hp<=0 or source.skill_ticks_left<=0 or (target.titi_doze_mode==3 and target.hp>=SkillRules.max_health_value(target,state._operator_data[target.operator_id])):clear_doze(target)


static func prevent_fatal(state: MatchState, target: UnitState, damage: int) -> int:
	if target.titi_doze_mode==3:return mini(damage,maxi(0,target.hp-1))
	if damage<target.hp or target.hp<=0 or state._operator_data[target.operator_id].profession_id=="summon":return damage
	for source in state.units:
		if source.hp<=0 or source.operator_id!="titi" or source.side!=target.side or source==target or SkillRules.active_ticks(source)<=0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		if data.skills[source.skill_index].effect_type=="titi_bloom" and state._is_in_attack_range(source,target.cell,data.attack_range):
			set_doze(target,source,3);return maxi(0,target.hp-1)
	return damage


static func refresh_auras(state: MatchState) -> void:
	for ally in state.units:
		var data: OperatorData=state._operator_data[ally.operator_id]
		if ally.hp<=0 or data.profession_id=="summon" or data.group_id not in ["minos","sargon"]:continue
		var bonus := 0
		for source in state.units:
			if source.hp<=0 or source.operator_id!="titi" or source.side!=ally.side or source.silence_ticks_left>0:continue
			var talent: TalentResource=state._operator_data[source.operator_id].talent_2
			if ally.hp*100>SkillRules.max_health_value(ally,data)*int(talent.effect_params["hp_threshold_percent"]):bonus=maxi(bonus,int(talent.effect_params["attack_speed_add"]))
		ally.attack_speed_bonus+=bonus


static func advance(state: MatchState) -> void:
	maintain_doze(state)
	for source: UnitState in state.units.duplicate():
		if source.hp<=0 or source.operator_id!="titi":continue
		var data: OperatorData=state._operator_data[source.operator_id]
		var skill := data.skills[source.skill_index]
		if source.titi_dot_next_tick<0:source.titi_dot_next_tick=source.deployed_tick+int(data.talent_1.effect_params["first_dot_ticks"])
		if SkillRules.active_ticks(source)>0 and skill.effect_type=="titi_bloom":
			for target: UnitState in state.units.duplicate():
				if target.side==source.side:continue
				var index := source.titi_sleep_ids.find(target.unit_id)
				if target.hp<=0:continue
				if target.sleep_ticks_left>0 or target.titi_doze_owner_id>=0:note_sleep(source,target)
				elif index>=0:release(state,source,target,index,true)
		if source.silence_ticks_left>0:continue
		if SkillRules.active_ticks(source)>0 and skill.effect_type=="titi_sanctuary" and source.skill_elapsed_ticks%int(skill.effect_params["pulse_ticks"])==0:
			var anchors: Array[UnitState]=[source]
			var other := WArtilleryRules.owner(state,source.titi_sanctuary_target_id)
			if other!=null and other!=source and other.hp>0:anchors.append(other)
			for anchor in anchors:
				for target in state.units:
					if target.hp>0 and target.side!=source.side and (target.cell-anchor.cell).length_squared()<=int(skill.effect_params["radius_squared"]):StatusRules.add_control(state,target,"sleep",int(skill.effect_params["sleep_ticks"]))
		if state.tick<source.titi_dot_next_tick:continue
		source.titi_dot_next_tick=state.tick+int(data.talent_1.effect_params["dot_interval_ticks"])
		var percent := int(data.talent_1.effect_params["dot_attack_percent"])
		if SkillRules.active_ticks(source)>0 and skill.effect_type=="titi_sanctuary":percent=roundi(percent*int(skill.effect_params["talent_scale_percent"])/100.0)
		for target: UnitState in state.units.duplicate():
			if target.hp>0 and target.side!=source.side and target.sleep_ticks_left>0:hit(state,source,target,roundi(SkillRules.attack_value(source,data)*percent/100.0),false)


static func note_sleep(source: UnitState, target: UnitState) -> void:
	var index := source.titi_sleep_ids.find(target.unit_id)
	if index<0:source.titi_sleep_ids.append(target.unit_id);source.titi_sleep_elapsed.append(1)
	else:source.titi_sleep_elapsed[index]+=1


static func release(state: MatchState, source: UnitState, target: UnitState, index: int, damage: bool) -> void:
	var elapsed := source.titi_sleep_elapsed[index]
	source.titi_sleep_ids.remove_at(index);source.titi_sleep_elapsed.remove_at(index)
	var data: OperatorData=state._operator_data[source.operator_id]
	var params := data.skills[source.skill_index].effect_params
	if damage and target.hp>0:
		var percent := int(params["min_attack_percent"])+(int(params["max_attack_percent"])-int(params["min_attack_percent"]))*mini(elapsed,int(params["max_sleep_ticks"]))/int(params["max_sleep_ticks"])
		hit(state,source,target,roundi(SkillRules.attack_value(source,data)*percent/100.0),false)
	var choices: Array[UnitState]=[]
	for other in state.units:
		if other==target or other.hp<=0 or other.side==source.side or (other.cell-target.cell).length_squared()>int(params["radius_squared"]) or not state.enemy_is_targetable(source.side,other,source,true):continue
		choices.append(other)
	choices.sort_custom(func(a: UnitState,b: UnitState)->bool:
		if (a.sleep_ticks_left>0)!=(b.sleep_ticks_left>0):return a.sleep_ticks_left==0
		var at := SkillRules.taunt_level(a,state._operator_data[a.operator_id]);var bt := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
		return at>bt if at!=bt else a.unit_id<b.unit_id)
	if not choices.is_empty():StatusRules.add_control(state,choices[0],"sleep",int(params["sleep_ticks"]))


static func finish(state: MatchState, source: UnitState, data: OperatorData, exiting: bool=false) -> void:
	if data.skills[source.skill_index].effect_type=="titi_bloom":
		for id in source.titi_sleep_ids.duplicate():
			var index := source.titi_sleep_ids.find(id)
			var target := WArtilleryRules.owner(state,id)
			if target!=null and index>=0:release(state,source,target,index,not exiting)
		source.titi_sleep_ids.clear();source.titi_sleep_elapsed.clear()
	for ally in state.units:
		if ally.titi_doze_owner_id==source.unit_id:clear_doze(ally)
	source.titi_sanctuary_target_id=-1
	source.titi_dot_next_tick=state.tick+int(data.talent_1.effect_params["first_dot_ticks"])


static func on_death(state: MatchState, target: UnitState) -> void:
	for source: UnitState in state.units.duplicate():
		if source.operator_id!="titi" or source==target or source.side==target.side or SkillRules.active_ticks(source)<=0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		if data.skills[source.skill_index].effect_type!="titi_bloom":continue
		var index := source.titi_sleep_ids.find(target.unit_id)
		if index>=0:release(state,source,target,index,false)
	if target.operator_id=="titi":finish(state,target,state._operator_data[target.operator_id],true)


static func targets(state: MatchState, source: UnitState, offsets: Array[Vector2i]) -> Array[UnitState]:
	var result: Array[UnitState]=[]
	for target in state.units:
		if state.enemy_is_targetable(source.side,target,source) and state._is_in_attack_range(source,target.cell,offsets):result.append(target)
	result.sort_custom(func(a: UnitState,b: UnitState)->bool:
		var at := SkillRules.taunt_level(a,state._operator_data[a.operator_id]);var bt := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
		return at>bt if at!=bt else a.unit_id<b.unit_id)
	return result


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if SkillRules.active_ticks(unit)>0 and skill.effect_type=="titi_sanctuary":return
	if not AttackTimeline.advance(state,unit):return
	var offsets := AttackRange.effective_offsets(unit,data)
	var candidates := targets(state,unit,offsets)
	candidates=AttackTimeline.pinned(state,unit,candidates)
	var center := candidates[0].cell if not candidates.is_empty() else ClassicOperatorRules.target_cell(state,unit,offsets)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,candidates,center):return
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var count := int(skill.effect_params["target_count"]) if SkillRules.active_ticks(unit)>0 and skill.effect_type=="titi_bloom" else 1
	var value := SkillRules.attack_value(unit,data)
	for target in candidates.slice(0,count):
		AttackTimeline.generic_projectile(state,unit,data,target,null,target.cell,value,"magical")
	if not candidates.is_empty():return
	var box: TacticalBox
	for candidate in state.tactical_boxes:
		if candidate.hits_left>0 and candidate.cell==center:box=candidate;break
	AttackTimeline.generic_projectile(state,unit,data,null,box,center,value,"magical")



static func hit(state: MatchState, source: UnitState, target: UnitState, value: int, attack_event: bool) -> int:
	var data: OperatorData=state._operator_data[source.operator_id]
	var td: OperatorData=state._operator_data[target.operator_id]
	var damage := Combat.calculate_damage(value,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),"magical",SkillRules.dodge_chance(target,td,"magical") if attack_event else 0,state.rng,data.profession_id,state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
	var applied: Array[int]=[0]
	if not state._apply_damage(target,td,damage,"magical",source,attack_event,applied):return 0
	if applied[0]>0 and source.hp>0:
		var allies := MedicAlterRules.candidates(state,source,false)
		if not allies.is_empty():LumenRules.treat_amount(state,allies[0],Combat.calculate_healing(applied[0],int(data.branch_trait.effect_params["heal_damage_percent"])),source)
	return applied[0]

static func projectile_hit(state: MatchState, shot: AttackProjectile, source: UnitState, target: UnitState) -> void:
	var data: OperatorData=state._operator_data[shot.operator_id]
	var skill:=data.skills[shot.skill_index]
	if hit(state,source,target,shot.attack,true)<=0 or target.hp<=0 or shot.silenced:return
	hit(state,source,target,roundi(shot.attack*int(data.talent_1.effect_params.extra_attack_percent)/100.0),false)
	if target.hp<=0 or not shot.active:return
	if skill.effect_type=="titi_corrosion" and state.rng.next_percent()<int(skill.effect_params.chance_percent):StatusRules.add_control(state,target,"sleep",int(skill.effect_params.sleep_ticks))
	elif skill.effect_type=="titi_bloom" and target.sleep_ticks_left==0:
		StatusRules.add_control(state,target,"sleep",int(skill.effect_params.sleep_ticks))
		if source.hp>0:note_sleep(source,target)
