class_name GuardSpecialistRules
extends RefCounted

const IDS := ["gavial_alter","mlynar","gladiia","shaw"]


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="mlynar_sorrow" and unit.skill_ticks_left>0:
		unit.skill_ticks_left=0;finish(state,unit,data);AuraRules.refresh(state);return
	if unit.operator_id=="shaw":
		shaw_cast(state,unit,data);return
	SkillRules.activate(unit,data)
	if unit.operator_id=="mlynar":
		unit.mlynar_skill_killed=false
		if skill.effect_type=="mlynar_glory":unit.mlynar_charge_bonus_percent*=int(skill.effect_params["trait_multiplier"])
	if skill.effect_type=="gladiia_vortex":
		var targets := CliffheartRules.hook_targets(state,unit,data.attack_range)
		if not targets.is_empty():
			var target := targets[0]
			unit.gladiia_vortex_cell=target.cell;unit.gladiia_vortex_started_tick=state.tick;unit.gladiia_vortex_next_pulse=state.tick;unit.gladiia_vortex_pulses=0
			unit.gladiia_vortex_attack=SkillRules.attack_value(unit,data)
			StatusRules.add_control(state,target,"bind",int(skill.effect_params["bind_ticks"]),unit)
	AuraRules.refresh(state)


static func finish(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if data.branch_trait.effect_type=="liberator":
		if skill.effect_type!="mlynar_sorrow" or not unit.mlynar_skill_killed:unit.mlynar_charge_ticks=0;unit.mlynar_charge_bonus_percent=0
	if skill.effect_type=="gavial_soul" and unit.gavial_deferred_damage>0:
		unit.gavial_debt_total=unit.gavial_deferred_damage;unit.gavial_deferred_damage=0
		unit.gavial_debt_ticks_left=int(skill.effect_params["repay_ticks"]);unit.gavial_debt_accum=0;unit.gavial_debt_pulse_ticks=0


static func blocked_targets(state: MatchState, unit: UnitState, offsets: Array[Vector2i]) -> Array[UnitState]:
	var targets := PusherRules.targets(state,unit,offsets,false,true)
	targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
		var ab := state.enemy_is_blocked(a,unit.unit_id);var bb := state.enemy_is_blocked(b,unit.unit_id)
		return ab if ab!=bb else a.unit_id<b.unit_id)
	return targets


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.operator_id=="shaw":shaw_attack(state,unit,data);return
	if unit.operator_id=="gladiia":gladiia_attack(state,unit,data);return
	if unit.operator_id=="mlynar" and SkillRules.active_ticks(unit)==0:return
	if not AttackTimeline.advance(state,unit):return
	var skill := data.skills[unit.skill_index]
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets := blocked_targets(state,unit,offsets)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,offsets)
	if center.x<0:return
	var native_intent:=unit.attack_intent
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var count := SkillRules.block_count_value(unit,data) if unit.operator_id=="gavial_alter" else (int(skill.effect_params["target_count"]) if skill.effect_type=="mlynar_glory" else 1)
	var shots := int(skill.effect_params["shot_count"]) if skill.effect_type=="mlynar_sorrow" else 1
	var indices:=AttackTimeline.release_indices(unit,native_intent,shots)
	var value := SkillRules.attack_value(unit,data)
	if unit.operator_id=="mlynar":value=roundi(value*float(skill.effect_params["strike_mult"])*mlynar_attack_percent(state,unit,data)/100.0)
	for enemy in targets.slice(0,count):
		for index in indices:
			if unit.hp<=0 or enemy.hp<=0:break
			var landed := hit(state,unit,enemy,value,"physical")
			if landed and enemy.hp<=0 and state._operator_data[enemy.operator_id].profession_id!="summon" and unit.operator_id=="mlynar":
				unit.mlynar_skill_killed=true
				if skill.effect_type=="mlynar_glory":unit.mlynar_charge_bonus_percent=maxi(0,unit.mlynar_charge_bonus_percent-int(skill.effect_params["kill_reduce_percent"]))
			if landed and enemy.hp>0 and unit.hp>0 and SkillRules.active_ticks(unit)>0 and skill.effect_type=="gavial_pull" and not state.enemy_is_blocked(enemy):DisplacementRules.apply_unit(state,unit,enemy,DisplacementRules.direction(unit,enemy.cell,"pull"),int(skill.effect_params["shift_force"]))
	if not targets.is_empty():return
	for box in state.tactical_boxes:
		if box.hits_left>0 and box.cell==center:
			for index in indices:
				if box.hits_left>0:TacticalRules.strike_box(state,unit,box)
			return
	for index in indices:
		if state.ball.move_ticks_left==0:state.ball.add_push(unit.cell,value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))


static func hit(state: MatchState, source: UnitState, target: UnitState, value: int, kind: String, attack_event: bool=true) -> bool:
	var data: OperatorData=state._operator_data[source.operator_id]
	var td: OperatorData=state._operator_data[target.operator_id]
	if source.silence_ticks_left==0 and data.talent_2.effect_type=="gladiia_predation" and DisplacementRules.effective_weight(state,target)<=int(data.talent_2.effect_params["max_weight"]):value=roundi(value*int(data.talent_2.effect_params["attack_percent"])/100.0)
	var damage := Combat.calculate_damage(value,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),kind,SkillRules.dodge_chance(target,td,kind) if attack_event else 0,state.rng,data.profession_id,state._damage_taken_percent(target,kind),state._magical_damage_taken_percent(target))
	return state._apply_damage(target,td,damage,kind,source,attack_event)


static func mlynar_surrounded(state: MatchState, unit: UnitState) -> bool:
	var count := 0
	for enemy in state.units:
		if enemy.hp>0 and enemy.side!=unit.side and absi(enemy.cell.x-unit.cell.x)<=1 and absi(enemy.cell.y-unit.cell.y)<=1:count+=1
	return count>=int(state._operator_data[unit.operator_id].talent_1.effect_params["enemy_count"])


static func mlynar_attack_percent(state: MatchState, unit: UnitState, data: OperatorData) -> int:
	if unit.silence_ticks_left>0:return 100
	return int(data.talent_1.effect_params["surrounded_attack_percent"] if mlynar_surrounded(state,unit) else data.talent_1.effect_params["attack_percent"])


static func reflect(state: MatchState, target: UnitState, source: UnitState) -> void:
	if source==null or source.hp<=0 or source.side==target.side or state._operator_data[target.operator_id].group_id!="kazimierz":return
	for owner: UnitState in state.units.duplicate():
		if owner.operator_id!="mlynar" or owner.hp<=0 or owner.side!=target.side or owner.silence_ticks_left>0:continue
		var data: OperatorData=state._operator_data[owner.operator_id]
		var td: OperatorData=state._operator_data[source.operator_id]
		var amount := roundi(SkillRules.attack_value(owner,data)*int(data.talent_2.effect_params["reflect_attack_percent"])/100.0)
		var damage := Combat.calculate_damage(amount,0,0,"true",0,state.rng,data.profession_id,state._damage_taken_percent(source,"true"))
		state._apply_damage(source,td,damage,"true",owner,false)


static func after_damage(state: MatchState, target: UnitState, source: UnitState, damage: int, attack_event: bool) -> void:
	if source==null or source.hp<=0 or damage<=0:return
	var data: OperatorData=state._operator_data[source.operator_id]
	var skill := data.skills[source.skill_index]
	if source.operator_id=="gavial_alter" and SkillRules.active_ticks(source)>0 and skill.effect_type=="gavial_strike":
		LumenRules.treat_amount(state,source,Combat.calculate_healing(damage,int(skill.effect_params["leech_percent"])),source)
	if not attack_event or target.hp<=0 or target.side==source.side or data.group_id!="kazimierz":return
	for owner: UnitState in state.units.duplicate():
		if owner.operator_id!="mlynar" or owner.hp<=0 or owner.side!=source.side or SkillRules.active_ticks(owner)<=0:continue
		var od: OperatorData=state._operator_data[owner.operator_id]
		var oskill := od.skills[owner.skill_index]
		if oskill.effect_type!="mlynar_glory" or not state._is_in_attack_range(owner,target.cell,oskill.attack_range_override):continue
		var amount := roundi(SkillRules.attack_value(owner,od)*int(oskill.effect_params["true_attack_percent"])/100.0)
		var td: OperatorData=state._operator_data[target.operator_id]
		var extra := Combat.calculate_damage(amount,0,0,"true",0,state.rng,od.profession_id,state._damage_taken_percent(target,"true"))
		state._apply_damage(target,td,extra,"true",owner,false)


static func defer_damage(unit: UnitState, data: OperatorData, damage: int) -> int:
	var skill := data.skills[unit.skill_index]
	if SkillRules.active_ticks(unit)<=0 or skill.effect_type!="gavial_soul":return damage
	var immediate := roundi(damage*(100-int(skill.effect_params["deferred_percent"]))/100.0)
	unit.gavial_deferred_damage+=damage-immediate
	return immediate


static func refresh_auras(state: MatchState) -> void:
	for unit in state.units:
		var data: OperatorData=state._operator_data[unit.operator_id]
		if unit.hp>0 and unit.silence_ticks_left==0 and data.talent_1.effect_type=="gavial_blocking":
			var count := 0
			for enemy in state.units:
				if enemy.hp>0 and enemy.side!=unit.side and state.enemy_is_blocked(enemy,unit.unit_id):count+=1
			count=mini(SkillRules.block_count_value(unit,data),count)
			var bonus := int(data.talent_1.effect_params["base_percent"])+count*int(data.talent_1.effect_params["percent_per_block"])
			unit.attack_bonus_percent+=bonus;unit.defense_bonus_percent+=bonus
		if unit.hp>0 and unit.silence_ticks_left==0 and unit.operator_id=="shaw":unit.magic_resist_bonus+=int(data.talent_1.effect_params["magic_resist_add"])
		unit.gladiia_vortex_slow_remaining_percent=100
		for owner in state.units:
			if owner.hp<=0 or owner.side==unit.side or owner.gladiia_vortex_started_tick<0:continue
			var oskill: SkillResource=state._operator_data[owner.operator_id].skills[owner.skill_index]
			if state.tick-owner.gladiia_vortex_started_tick<=int(oskill.effect_params["lifetime_ticks"]) and (unit.cell-owner.gladiia_vortex_cell).length_squared()<=int(oskill.effect_params["radius_squared"]):unit.gladiia_vortex_slow_remaining_percent=mini(unit.gladiia_vortex_slow_remaining_percent,int(oskill.effect_params["attack_speed_remaining_percent"]))
		unit.attack_speed_remaining_percent=roundi(unit.attack_speed_remaining_percent*unit.gladiia_vortex_slow_remaining_percent/100.0)


static func advance(state: MatchState) -> void:
	for unit: UnitState in state.units.duplicate():
		if unit.hp<=0:continue
		var data: OperatorData=state._operator_data[unit.operator_id]
		if data.branch_trait.effect_type=="liberator" and unit.skill_ticks_left==0:
			unit.mlynar_charge_ticks=mini(int(data.branch_trait.effect_params["charge_ticks"]),unit.mlynar_charge_ticks+1)
			unit.mlynar_charge_bonus_percent=unit.mlynar_charge_ticks*int(data.branch_trait.effect_params["max_attack_bonus_percent"])/int(data.branch_trait.effect_params["charge_ticks"])
		if unit.gavial_debt_ticks_left>0:
			unit.gavial_debt_ticks_left-=1;unit.gavial_debt_pulse_ticks+=1
			var skill := data.skills[unit.skill_index]
			if unit.gavial_debt_pulse_ticks>=int(skill.effect_params["pulse_ticks"]):
				unit.gavial_debt_pulse_ticks=0;unit.gavial_debt_accum+=unit.gavial_debt_total
				var pulses := int(skill.effect_params["repay_ticks"])/int(skill.effect_params["pulse_ticks"])
				var loss: int= unit.gavial_debt_accum/pulses;unit.gavial_debt_accum%=pulses
				state._apply_skill_life_loss(unit,data,loss)
			if unit.gavial_debt_ticks_left==0:unit.gavial_debt_total=0;unit.gavial_debt_accum=0
		if data.group_id=="abyssal" and unit.critical_ticks_left==0:
			var regen := 0
			for owner in state.units:
				var od: OperatorData=state._operator_data[owner.operator_id]
				if owner.hp>0 and owner.side==unit.side and owner.silence_ticks_left==0 and od.talent_1.effect_type=="gladiia_tide":regen=maxi(regen,int(od.talent_1.effect_params["regen_max_health_permille"]))
			if regen>0:
				var maximum := SkillRules.max_health_value(unit,data)
				unit.gladiia_regen_accum+=maximum*regen*state.CONFIG.UNIT_HEAL_PERCENT
				var divisor := state.CONFIG.TICK_RATE*100000
				var amount: int=unit.gladiia_regen_accum/divisor;unit.gladiia_regen_accum%=divisor
				if amount>0 and unit.hp<maximum:unit.hp=mini(maximum,unit.hp+amount);unit.last_heal_tick=state.tick
		if unit.gladiia_hook_ticks_left>0:unit.gladiia_hook_ticks_left-=1
	advance_vortices(state)


static func shaw_attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.last_attack_tick==state.tick or not AttackTimeline.advance(state,unit):return
	var targets := PusherRules.targets(state,unit,data.attack_range,false)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,data.attack_range)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	var skill := data.skills[unit.skill_index]
	var charged := skill.effect_type=="shaw_strike" and SkillRules.can_activate(unit,skill)
	if charged:SkillRules.activate(unit,data)
	var value := SkillRules.attack_value(unit,data)
	if charged:value=roundi(value*float(skill.effect_params["strike_mult"]))
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var affected: Array[UnitState]=[]
	if charged:
		for enemy in state.units:
			if state.enemy_is_targetable(unit.side,enemy,unit) and (enemy.cell-center).length_squared()<=int(skill.effect_params["radius_squared"]):affected.append(enemy)
	else:affected=targets.slice(0,data.block_count)
	var maximum := int(skill.effect_params["target_count"]) if charged else data.block_count
	for enemy in affected.slice(0,maximum):
		if hit(state,unit,enemy,value,"physical") and enemy.hp>0 and charged:DisplacementRules.apply_unit(state,unit,enemy,DisplacementRules.direction(unit,enemy.cell,"push"),int(skill.effect_params["shift_force"]))
	if targets.is_empty():object_hit(state,unit,center,value,int(skill.effect_params["shift_force"]) if charged else -1,"push")
	if charged:unit.skill_ticks_left=0


static func shaw_cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	var targets := PusherRules.targets(state,unit,skill.attack_range_override,true)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,skill.attack_range_override)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	if center.x<0:return
	SkillRules.activate(unit,data);unit.skill_ticks_left=0;PusherRules.mark_attack(state,unit,center)
	var value := roundi(SkillRules.attack_value(unit,data)*float(skill.effect_params["strike_mult"]))
	if not targets.is_empty():
		for enemy: UnitState in state.units.duplicate():
			if state.enemy_is_targetable(unit.side,enemy,unit) and (enemy.cell-center).length_squared()<=int(skill.effect_params["radius_squared"]) and hit(state,unit,enemy,value,"physical") and enemy.hp>0:DisplacementRules.apply_unit(state,unit,enemy,DisplacementRules.direction(unit,enemy.cell,"push"),int(skill.effect_params["shift_force"]))
	else:object_hit(state,unit,center,value,int(skill.effect_params["shift_force"]),"push")


static func object_hit(state: MatchState, unit: UnitState, center: Vector2i, value: int, force: int, mode: String) -> void:
	for box in state.tactical_boxes:
		if box.cell==center and box.hits_left>0:TacticalRules.strike_box(state,unit,box);return
	if state.ball.move_ticks_left==0 and state.ball.cell==center:
		var direction := DisplacementRules.direction(unit,center,mode)
		var origin := unit.cell if mode=="push" else center-direction
		state.ball.add_push(origin,value,state._ball_data,direction)
		if force>=0:DisplacementRules.apply_ball(state,direction,force)


static func gladiia_attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if unit.gladiia_hook_ticks_left>0 and skill.effect_type=="gladiia_tide_skill":return
	if SkillRules.active_ticks(unit)>0 and skill.effect_type=="gladiia_vortex":return
	if not AttackTimeline.advance(state,unit):return
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets := blocked_targets(state,unit,offsets)
	var charged := skill.effect_type=="gladiia_strike" and SkillRules.can_activate(unit,skill)
	var active := SkillRules.active_ticks(unit)>0 and skill.effect_type=="gladiia_tide_skill"
	if charged:targets=CliffheartRules.hook_targets(state,unit,offsets)
	if active:
		targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
			var ab := state.enemy_is_blocked(a);var bb := state.enemy_is_blocked(b)
			return ab if ab!=bb else a.unit_id<b.unit_id)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,offsets)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	if charged:SkillRules.activate(unit,data);unit.skill_ticks_left=int(skill.effect_params["channel_ticks"])
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var value := SkillRules.attack_value(unit,data)
	if charged or active:value=roundi(value*float(skill.effect_params["strike_mult"]))
	var count := int(skill.effect_params["target_count"]) if active else 1
	for enemy in targets.slice(0,count):
		if charged or active or not state.enemy_is_blocked(enemy,unit.unit_id):
			var amount:=value
			if unit.silence_ticks_left==0 and DisplacementRules.effective_weight(state,enemy)<=int(data.talent_2.effect_params.max_weight):amount=roundi(amount*int(data.talent_2.effect_params.attack_percent)/100.0)
			var shot:=AttackTimeline.generic_projectile(state,unit,data,enemy,null,enemy.cell,amount,"physical")
			if charged or active:shot.shift_force=int(skill.effect_params.shift_force);shot.shift_pull=true
		else:hit(state,unit,enemy,value,"physical")
	if (charged or active) and not targets.is_empty():
		unit.gladiia_hook_ticks_left=int(skill.effect_params["channel_ticks"])
		if active:unit.skill_ticks_left=maxi(unit.skill_ticks_left,unit.gladiia_hook_ticks_left)
	if targets.is_empty():
		var box: TacticalBox
		for candidate in state.tactical_boxes:
			if candidate.cell==center and candidate.hits_left>0:box=candidate;break
		var shot:=AttackTimeline.generic_projectile(state,unit,data,null,box,center,value,"physical")
		shot.shift_force=int(skill.effect_params.shift_force) if charged or active else -1;shot.shift_pull=true
		if charged:unit.skill_ticks_left=0


static func advance_vortices(state: MatchState) -> void:
	for unit: UnitState in state.units.duplicate():
		if unit.hp<=0 or unit.gladiia_vortex_started_tick<0:continue
		var data: OperatorData=state._operator_data[unit.operator_id]
		var skill := data.skills[unit.skill_index]
		var elapsed: int= state.tick-unit.gladiia_vortex_started_tick
		if elapsed>int(skill.effect_params["lifetime_ticks"]):unit.gladiia_vortex_started_tick=-1;unit.gladiia_vortex_cell=Vector2i(-1,-1);continue
		if state.tick<unit.gladiia_vortex_next_pulse:continue
		unit.gladiia_vortex_next_pulse+=int(skill.effect_params["pulse_ticks"])
		var does_damage: bool= unit.gladiia_vortex_pulses<int(skill.effect_params["damage_pulses"])
		unit.gladiia_vortex_pulses+=1
		for enemy: UnitState in state.units.duplicate():
			if not state.enemy_is_targetable(unit.side,enemy,unit) or (enemy.cell-unit.gladiia_vortex_cell).length_squared()>int(skill.effect_params["radius_squared"]):continue
			if does_damage:hit(state,unit,enemy,roundi(unit.gladiia_vortex_attack*int(skill.effect_params["pulse_attack_percent"])/100.0),"magical",false)
			var direction := Vector2i(signi(unit.gladiia_vortex_cell.x-enemy.cell.x),signi(unit.gladiia_vortex_cell.y-enemy.cell.y))
			if enemy.hp>0 and direction!=Vector2i.ZERO:DisplacementRules.apply_unit(state,unit,enemy,direction,int(skill.effect_params["shift_force"]))
		if elapsed>=int(skill.effect_params["lifetime_ticks"]):
			for enemy: UnitState in state.units.duplicate():
				if state.enemy_is_targetable(unit.side,enemy,unit) and (enemy.cell-unit.gladiia_vortex_cell).length_squared()<=int(skill.effect_params["catch_radius_squared"]):DisplacementRules.apply_unit(state,unit,enemy,DisplacementRules.direction(unit,enemy.cell,"pull"),int(skill.effect_params["shift_force"]))
			unit.gladiia_vortex_started_tick=-1;unit.gladiia_vortex_cell=Vector2i(-1,-1)
