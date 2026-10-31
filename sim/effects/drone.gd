class_name DroneRules
extends RefCounted


static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id=="magallan":return unit
	return null


static func owner_for(state: MatchState, drone: UnitState) -> UnitState:
	for unit in state.units:
		if unit.unit_id==drone.drone_owner_id and unit.hp>0 and unit.operator_id=="magallan":return unit
	return null


static func hidden_ticks_left(state: MatchState, unit: UnitState) -> int:
	if unit.operator_id not in state.DRONE_IDS or unit.silence_ticks_left>0:return 0
	var data: OperatorData=state._operator_data[unit.operator_id]
	return maxi(0,int(data.talent_2.effect_params["hidden_ticks"])-state.tick+unit.deployed_tick)


static func remove_owned(state: MatchState, source: UnitState, recover: bool) -> void:
	var retained: Array[UnitState]=[]
	var count := 0
	for unit in state.units:
		if unit.drone_owner_id==source.unit_id and unit.hp>0:
			count+=1
		else:
			# Dead units stay until the existing ordered death rewards/cleanup phase.
			retained.append(unit)
	state.units=retained
	if recover:
		var data: OperatorData=state._operator_data[source.operator_id]
		state.sides[source.side].drone_stock=mini(int(data.talent_1.effect_params["stock_count"]),state.sides[source.side].drone_stock+count)


static func remove_orphans(state: MatchState) -> void:
	var retained: Array[UnitState]=[]
	for unit in state.units:
		if unit.operator_id not in state.DRONE_IDS or owner_for(state,unit)!=null:retained.append(unit)
	state.units=retained


static func advance_control(state: MatchState) -> void:
	for source in state.units:
		if source.hp<=0 or source.silence_ticks_left>0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		var params: Dictionary
		var controller: UnitState
		if source.operator_id=="magallan" and data.skills[source.skill_index].effect_type=="magallan_cooling":
			params=data.skills[source.skill_index].effect_params
			controller=source
		elif source.operator_id=="magallan_drone_f":
			params=data.talent_1.effect_params
			controller=owner_for(state,source)
		else:continue
		if controller==null:continue
		var active := controller.skill_index==0 and SkillRules.active_ticks(controller)>0
		var elapsed := controller.skill_elapsed_ticks if active else state.tick-source.deployed_tick
		if (not active and elapsed<=0) or elapsed%int(params["pulse_ticks"])!=0:continue
		for target in state.units:
			if target.hp<=0 or not StainlessRules.is_damage_target(source,target) or target.operator_id=="weedy_cannon" or not state._is_in_attack_range(source,target.cell,data.attack_range):continue
			if active:StatusRules.add_control(state,target,"bind",int(params["bind_ticks"]))
			else:StatusRules.add_control(state,target,"slow",int(params["slow_ticks"]))


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var controller := owner_for(state,unit)
	if controller==null or data.attack==0:return
	if not AttackTimeline.advance(state,unit):return
	var enemies := PusherRules.targets(state,unit,data.attack_range,false)
	enemies=AttackTimeline.pinned(state,unit,enemies)
	var primary: UnitState=enemies[0] if not enemies.is_empty() else null
	var box_target: TacticalBox
	if primary==null:
		for box in state.tactical_boxes:
			if state._is_in_attack_range(unit,box.cell,data.attack_range):box_target=box;break
	var ball_target := primary==null and box_target==null and state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,data.attack_range)
	if primary==null and box_target==null and not ball_target:return
	var center := primary.cell if primary!=null else (box_target.cell if box_target!=null else state.ball.cell)
	if not AttackTimeline.windup(state,unit,data,enemies,center):return
	var radius := int(data.branch_trait.effect_params["splash_radius_squared"]) if unit.operator_id=="magallan_drone_a" else -1
	if SkillRules.active_ticks(controller)>0:
		var skill := (state._operator_data[controller.operator_id] as OperatorData).skills[controller.skill_index]
		if skill.effect_type in ["magallan_laser","magallan_artillery"]:radius=int(skill.effect_params["splash_radius_squared"])
	var attack_value := SkillRules.attack_output_value(unit,data)
	PusherRules.mark_attack(state,unit,center)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var shot:=AttackTimeline.generic_projectile(state,unit,data,primary,box_target,center,attack_value,data.damage_type)
	shot.splash_radius_squared=radius;shot.splash_affects_objects=false
	if radius>=0 and primary==null:
		AttackTimeline.generic_projectile(state,unit,data,null,box_target,center,attack_value,data.damage_type)
