class_name TacticianRules
extends RefCounted


static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.operator_id=="muelsyse" and unit.side==side and unit.hp>0:return unit
	return null


static func owner_for(state: MatchState, unit: UnitState) -> UnitState:
	for source in state.units:
		if source.unit_id==unit.flow_owner_id and source.hp>0 and source.operator_id=="muelsyse":return source
	return null


static func original(state: MatchState, source: UnitState) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.flow_owner_id==source.unit_id and not unit.flow_is_split:return unit
	return null


static func visible(state: MatchState, side: int) -> bool:
	var source := owner(state,side)
	return source!=null and source.silence_ticks_left==0 and original(state,source)==null


static func can_deploy(state: MatchState, side: int, cell: Vector2i) -> bool:
	var source := owner(state,side)
	return visible(state,side) and state._is_in_attack_range(source,cell,(state._operator_data[source.operator_id] as OperatorData).attack_range)


static func deployed(state: MatchState, unit: UnitState) -> void:
	var source := owner(state,unit.side)
	unit.flow_owner_id=source.unit_id
	unit.flow_root_id=unit.unit_id
	unit.flow_can_charge=SkillRules.active_ticks(source)==0


static func can_copy(state: MatchState, side: int, unit_id: int, operator_id: String) -> bool:
	if state.result!=state.RESULT_RUNNING or operator_id not in state.squad_ids[side]:return false
	var data: OperatorData=state._operator_data[operator_id]
	if data.profession_id=="summon":return false
	var selected: UnitState
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id==operator_id:return false
		if unit.unit_id==unit_id:selected=unit
	if selected==null or selected.side!=side or selected.operator_id!="flowing_shape" or selected.flow_is_split or selected.flow_point_until_tick>0:return false
	if selected.hp<=0 or selected.silence_ticks_left>0 or selected.stun_ticks_left>0 or selected.frozen_ticks_left>0 or selected.sleep_ticks_left>0 or selected.displacement_ticks_left>0 or selected.skill_ticks_left<=0:return false
	var source := owner_for(state,selected)
	return source!=null and source.silence_ticks_left==0 and SkillRules.active_ticks(source)==0


static func copy(state: MatchState, side: int, unit_id: int, operator_id: String, facing: int) -> bool:
	if facing not in range(4) or not can_copy(state,side,unit_id,operator_id):return false
	var unit: UnitState
	for candidate in state.units:
		if candidate.unit_id==unit_id:unit=candidate;break
	var data: OperatorData=state._operator_data[operator_id]
	var source := owner_for(state,unit)
	var percent := int((state._operator_data[source.operator_id] as OperatorData).talent_1.effect_params["copy_percent"])
	clear_steal(state,unit)
	unit.flow_copy_id=operator_id
	unit.flow_health=roundi(data.max_health*percent/100.0)
	unit.flow_attack=roundi(data.attack*percent/100.0)
	unit.flow_defense=roundi(data.defense*percent/100.0)
	unit.flow_resist=roundi(data.magic_resist*percent/100.0)
	unit.flow_block=data.block_count
	unit.flow_interval_ticks=roundi(data.attack_interval*state.CONFIG.TICK_RATE)
	unit.flow_range=data.attack_range.duplicate()
	if Vector2i.ZERO not in unit.flow_range:unit.flow_range.append(Vector2i.ZERO)
	unit.flow_melee=data.terrain_requirement!="high"
	unit.flow_magical=data.damage_type!="physical"
	unit.flow_attack_count=0
	unit.facing=facing
	unit.skill_ticks_left=0
	unit.skill_elapsed_ticks=0
	unit.sp=0
	unit.sp_regen_ticks=0
	unit.hp=SkillRules.max_health_value(unit,state._operator_data[unit.operator_id])
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,state._operator_data[unit.operator_id])
	AuraRules.refresh(state)
	return true


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.operator_id=="flowing_shape":
		if unit.flow_is_split or unit.flow_point_until_tick>0 or owner_for(state,unit)==null or SkillRules.active_ticks(owner_for(state,unit))!=0:return
		if unit.skill_ticks_left>0:unit.skill_ticks_left=0;unit.sp=0
		else:SkillRules.activate(unit,data)
		return
	SkillRules.activate(unit,data)
	var skill := data.skills[unit.skill_index]
	if skill.effect_type!="muelsyse_progress":state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(skill.effect_params["cost_add"]))
	for flow in state.units:
		if flow.flow_owner_id==unit.unit_id:flow.skill_ticks_left=0;flow.flow_can_charge=false
	var root := original(state,unit)
	if root!=null and root.flow_point_until_tick==0 and not root.flow_melee and not root.flow_copy_id.is_empty() and skill.effect_type=="muelsyse_interaction":
		for flow in state.units:
			if flow.flow_owner_id==unit.unit_id and flow.flow_point_until_tick==0:
				flow.hp=SkillRules.max_health_value(flow,state._operator_data[flow.operator_id])
				if flow.flow_is_split:flow.flow_expiry_tick=state.tick+int((state._operator_data[flow.operator_id] as OperatorData).branch_trait.effect_params["split_lifetime_ticks"])
		for index in 4:split(state,root,true)
	AuraRules.refresh(state)


static func refresh_costs(state: MatchState) -> void:
	for side in 2:
		state.sides[side].rhine_cost_reduction=0;state.sides[side].rhine_first_cost_reduction=0
		if "muelsyse" in state.squad_ids[side] and state._squad_talents_enabled(side,"muelsyse"):
			state.sides[side].rhine_cost_reduction=int((state._operator_data["muelsyse"] as OperatorData).talent_2.effect_params["cost_reduction"])
			state.sides[side].rhine_first_cost_reduction=int((state._operator_data["muelsyse"] as OperatorData).talent_2.effect_params["first_reduction"])


static func refresh(state: MatchState) -> void:
	refresh_costs(state)
	for unit in state.units:
		unit.flow_sanctuary_percent=0
		if unit.flow_owner_id<0:continue
		var source := owner_for(state,unit)
		unit.flow_can_charge=source!=null and SkillRules.active_ticks(source)==0 and not unit.flow_is_split and unit.flow_point_until_tick==0
		if source==null or SkillRules.active_ticks(source)<=0 or unit.flow_point_until_tick>0:continue
		var skill := (state._operator_data[source.operator_id] as OperatorData).skills[source.skill_index]
		unit.attack_bonus_percent+=roundi((float(skill.effect_params["attack_mult"])-1.0)*100)
		if skill.effect_type=="muelsyse_progress":unit.attack_speed_bonus+=int(skill.effect_params["attack_speed_add"])
		if skill.effect_type=="muelsyse_ecology" and unit.flow_melee:unit.flow_sanctuary_percent=int(skill.effect_params["sanctuary_percent"])


static func advance(state: MatchState) -> void:
	for unit: UnitState in state.units.duplicate():
		if unit.operator_id=="muelsyse" and unit.hp>0 and SkillRules.active_ticks(unit)>0:
			var skill := (state._operator_data[unit.operator_id] as OperatorData).skills[unit.skill_index]
			if skill.effect_type=="muelsyse_progress":SkillRules.advance_cost_regen(state,unit,skill)
		if unit.flow_owner_id<0:continue
		var source := owner_for(state,unit)
		if source==null:clear_steal(state,unit);state.units.erase(unit);continue
		if unit.flow_is_split and state.tick>=unit.flow_expiry_tick:state.units.erase(unit);continue
		if unit.flow_point_until_tick>0:
			if state.tick>=unit.flow_point_until_tick:
				unit.flow_point_until_tick=0;unit.hp=SkillRules.max_health_value(unit,state._operator_data[unit.operator_id]);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,state._operator_data[unit.operator_id])
			continue
		if SkillRules.active_ticks(source)<=0:continue
		var skill := (state._operator_data[source.operator_id] as OperatorData).skills[source.skill_index]
		if unit.flow_melee and not unit.flow_copy_id.is_empty():
			if skill.effect_type=="muelsyse_ecology" and unit.critical_ticks_left==0:
				unit.flow_regen_accum+=SkillRules.max_health_value(unit,state._operator_data[unit.operator_id])*int(skill.effect_params["regen_health_percent"])*state.CONFIG.UNIT_HEAL_PERCENT
				var divisor: int=state.CONFIG.TICK_RATE*10000
				var healed := unit.flow_regen_accum/divisor;unit.flow_regen_accum%=divisor
				unit.hp=mini(SkillRules.max_health_value(unit,state._operator_data[unit.operator_id]),unit.hp+healed)
				if healed>0:unit.last_heal_tick=state.tick
			elif skill.effect_type=="muelsyse_interaction":
				for target: UnitState in state.units.duplicate():
					if target.hp<=0 or target.side==unit.side:continue
					if state.enemy_is_blocked(target,unit.unit_id):StatusRules.add_control(state,target,"stun",2,unit)
					if source.skill_elapsed_ticks%int(skill.effect_params["pull_interval_ticks"])==0 and target.cell!=unit.cell and absi(target.cell.x-unit.cell.x)<=1 and absi(target.cell.y-unit.cell.y)<=1:DisplacementRules.apply_unit(state,unit,target,DisplacementRules.direction(unit,target.cell,"pull"),int(skill.effect_params["shift_force"]))


static func point(state: MatchState, unit: UnitState) -> void:
	if unit.flow_is_split:unit.hp=0;return
	unit.hp=1
	unit.flow_point_until_tick=state.tick+int((state._operator_data["muelsyse"] as OperatorData).talent_1.effect_params["refresh_ticks"])
	unit.skill_ticks_left=0;unit.sp=0;unit.sp_regen_ticks=0;unit.flow_can_charge=false
	unit.stun_ticks_left=0;unit.silence_ticks_left=0;unit.frozen_ticks_left=0;unit.cold_ticks_left=0;unit.sleep_ticks_left=0;unit.bind_ticks_left=0;unit.displacement_ticks_left=0


static func clear_steal(state: MatchState, unit: UnitState) -> void:
	for index in unit.flow_victim_ids.size():
		for target in state.units:
			if target.unit_id==unit.flow_victim_ids[index]:
				target.flow_attack_loss=maxi(0,target.flow_attack_loss-unit.flow_victim_attack[index]);target.flow_defense_loss=maxi(0,target.flow_defense_loss-unit.flow_victim_defense[index]);break
	unit.flow_victim_ids.clear();unit.flow_victim_attack.clear();unit.flow_victim_defense.clear();unit.flow_stolen_attack=0;unit.flow_stolen_defense=0


static func remove_owned(state: MatchState, source: UnitState) -> void:
	for unit: UnitState in state.units.duplicate():
		if unit.flow_owner_id==source.unit_id:clear_steal(state,unit);state.units.erase(unit)


static func split(state: MatchState, unit: UnitState, fill_only: bool = false) -> void:
	for offset in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
		var cell: Vector2i=unit.cell+AttackRange.rotate_offset(offset,unit.facing)
		var existing: UnitState
		for other in state.units:
			if other.hp>0 and other.cell==cell:existing=other;break
		if existing!=null:
			if not fill_only and existing.flow_is_split and existing.flow_root_id==unit.unit_id:
				existing.hp=SkillRules.max_health_value(existing,state._operator_data[existing.operator_id]);existing.flow_expiry_tick=state.tick+int((state._operator_data[unit.operator_id] as OperatorData).branch_trait.effect_params["split_lifetime_ticks"]);return
			continue
		if not DeployRules.is_legal(unit.side,state._operator_data[unit.operator_id],cell,state.ball.cell,state.units,state.sides[unit.side],state._arena,state.platform_cells) or (state.box_reserves_cell(cell) or state.item_reserves_cell(cell)):continue
		var child := UnitState.new(state.next_unit_id,unit.side,"flowing_shape",cell,1,0,unit.flow_interval_ticks,unit.facing)
		state.next_unit_id+=1;child.deployed_tick=state.tick;child.flow_owner_id=unit.flow_owner_id;child.flow_root_id=unit.unit_id;child.flow_is_split=true;child.flow_copy_id=unit.flow_copy_id;child.flow_melee=false;child.flow_magical=unit.flow_magical
		child.flow_health=unit.flow_health;child.flow_attack=unit.flow_attack;child.flow_defense=unit.flow_defense;child.flow_resist=unit.flow_resist;child.flow_block=unit.flow_block;child.flow_interval_ticks=unit.flow_interval_ticks;child.flow_range=unit.flow_range.duplicate();child.flow_expiry_tick=state.tick+int((state._operator_data[unit.operator_id] as OperatorData).branch_trait.effect_params["split_lifetime_ticks"])
		state.units.append(child);child.hp=SkillRules.max_health_value(child,state._operator_data[child.operator_id]);return


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.flow_owner_id>=0 and (unit.flow_point_until_tick>0 or owner_for(state,unit)==null):return
	if not AttackTimeline.advance(state,unit):return
	var targets := PusherRules.targets(state,unit,AttackRange.effective_offsets(unit,data),false,true)
	targets.sort_custom(func(a:UnitState,b:UnitState)->bool:
		var at := SkillRules.taunt_level(a,state._operator_data[a.operator_id]);var bt := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
		if at!=bt:return at>bt
		var ab := state.enemy_is_blocked(a,unit.unit_id);var bb := state.enemy_is_blocked(b,unit.unit_id)
		return ab if ab!=bb else a.unit_id<b.unit_id)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,AttackRange.effective_offsets(unit,data))
	if center.x<0:return
	var native_action:=unit.attack_intent
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	var controller := owner_for(state,unit) if unit.flow_owner_id>=0 else unit
	var skill := (state._operator_data[controller.operator_id] as OperatorData).skills[controller.skill_index]
	var shots := int(skill.effect_params["shot_count"]) if unit.flow_owner_id>=0 and not unit.flow_melee and not unit.flow_copy_id.is_empty() and SkillRules.active_ticks(controller)>0 and skill.effect_type=="muelsyse_ecology" else 1
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	for shot in shots:
		if unit.hp<=0:break
		var amount := SkillRules.attack_value(unit,data)
		if not targets.is_empty():
			var shot_targets := targets
			if shots>1 and targets.any(func(candidate: UnitState)->bool:return candidate.operator_id=="stainless_cannon"):
				var enemies := targets.filter(func(candidate: UnitState)->bool:return candidate.hp>0 and candidate.side!=unit.side)
				shot_targets=enemies if not enemies.is_empty() else targets.filter(func(candidate: UnitState)->bool:return candidate.hp>0)
			if shot_targets.is_empty():continue
			var target: UnitState=shot_targets[0]
			if native_action!=null and not native_action.shot_target_ids.is_empty():
				target=WArtilleryRules.owner(state,native_action.shot_target_ids[shot%native_action.shot_target_ids.size()])
				if target==null or target not in shot_targets:continue
			if target.hp<=0:continue
			if unit.operator_id=="muelsyse":
				var root := original(state,unit)
				if root!=null and state.enemy_is_blocked(target,root.unit_id):amount=roundi(amount*int(data.branch_trait.effect_params["blocked_attack_percent"])/100.0)
			if unit.operator_id=="muelsyse" or (unit.flow_owner_id>=0 and not unit.flow_melee):
				var pending:=AttackTimeline.generic_projectile(state,unit,data,target,null,target.cell,amount,SkillRules.damage_type(unit,data))
				if unit.flow_owner_id>=0 and SkillRules.active_ticks(controller)>0 and skill.effect_type=="muelsyse_interaction":pending.bind_ticks=int(skill.effect_params.bind_ticks)
				continue
			var td: OperatorData=state._operator_data[target.operator_id]
			var dtype := SkillRules.damage_type(unit,data)
			var damage := Combat.calculate_damage(amount,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),dtype,SkillRules.dodge_chance(target,td,dtype),state.rng,SkillRules.damage_profession_id(data),state._damage_taken_percent(target,dtype),state._magical_damage_taken_percent(target))
			if state._apply_damage(target,td,damage,dtype,unit) and target.hp>0 and unit.flow_owner_id>=0 and unit.silence_ticks_left==0:
				if unit.flow_melee and not unit.flow_copy_id.is_empty():steal(state,unit,target,td)
				if not unit.flow_melee and SkillRules.active_ticks(controller)>0 and skill.effect_type=="muelsyse_interaction":StatusRules.add_control(state,target,"bind",int(skill.effect_params["bind_ticks"]),unit)
		else:
			var found := false
			for box in state.tactical_boxes:
				if box.cell==center and box.hits_left>0:
					if unit.operator_id=="muelsyse" or (unit.flow_owner_id>=0 and not unit.flow_melee):AttackTimeline.generic_projectile(state,unit,data,null,box,center,amount,SkillRules.damage_type(unit,data))
					else:TacticalRules.strike_box(state,unit,box)
					found=true;break
			if not found and state.ball.move_ticks_left==0:
				if unit.operator_id=="muelsyse" or (unit.flow_owner_id>=0 and not unit.flow_melee):AttackTimeline.generic_projectile(state,unit,data,null,null,center,amount,SkillRules.damage_type(unit,data))
				else:state.ball.add_push(unit.cell,amount,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
	if unit.flow_owner_id>=0 and not unit.flow_is_split and not unit.flow_melee and not unit.flow_copy_id.is_empty():
		unit.flow_attack_count+=1
		if unit.flow_attack_count==int(data.branch_trait.effect_params["split_attack_count"]):unit.flow_attack_count=0;split(state,unit)


static func steal(state: MatchState, source: UnitState, target: UnitState, data: OperatorData) -> void:
	var params: Dictionary=(state._operator_data[source.operator_id] as OperatorData).branch_trait.effect_params
	var attack := mini(int(params["steal_per_hit"]),mini(int(params["steal_limit"])-source.flow_stolen_attack,SkillRules.attack_value(target,data)))
	var defense := mini(int(params["steal_per_hit"]),mini(int(params["steal_limit"])-source.flow_stolen_defense,SkillRules.defense_value(target,data)))
	var index := source.flow_victim_ids.find(target.unit_id)
	if index<0:
		index=source.flow_victim_ids.size();source.flow_victim_ids.append(target.unit_id);source.flow_victim_attack.append(0);source.flow_victim_defense.append(0)
	source.flow_stolen_attack+=attack;source.flow_stolen_defense+=defense;target.flow_attack_loss+=attack;target.flow_defense_loss+=defense;source.flow_victim_attack[index]+=attack;source.flow_victim_defense[index]+=defense
