class_name LeeRules
extends RefCounted


static func before_control(state: MatchState, target: UnitState, kind: String, source: UnitState = null) -> bool:
	if kind not in ["stun","frozen"] or target.operator_id!="lee" or not target.lee_control_charm or target.silence_ticks_left>0:return false
	target.lee_control_charm=false
	if source!=null and source.hp>0 and source.side!=target.side:
		var data: OperatorData=state._operator_data[target.operator_id]
		var duration := int(data.talent_2.effect_params["stun_ticks"])
		if StatusRules.has_resistance(state,source):duration=maxi(1,roundi(duration*0.5))
		StatusRules.add_control(state,source,"stun",duration,target)
	return true


static func source_dodges(state: MatchState, target: UnitState, data: OperatorData, source: UnitState, damage_type: String) -> bool:
	if target.operator_id!="lee" or damage_type not in ["physical","magical"] or SkillRules.active_ticks(target)==0 or data.skills[target.skill_index].effect_type!="lee_guest":return false
	# The source explicitly treats unattributed damage as coming from outside.
	if source!=null and state._is_in_attack_range(target,source.cell,AttackRange.effective_offsets(target,data)):return false
	return state.rng.next_u32()%100<int(data.skills[target.skill_index].effect_params["dodge_percent"])


static func refresh_buffs(state: MatchState) -> void:
	for unit in state.units:
		if unit.operator_id!="lee" or unit.hp<=0 or unit.silence_ticks_left>0:continue
		var data: OperatorData=state._operator_data[unit.operator_id]
		var count := 0
		for target in state.units:
			if target.hp>0 and target.side!=unit.side and absi(target.cell.x-unit.cell.x)<=1 and absi(target.cell.y-unit.cell.y)<=1:count+=1
		var blocking := false
		for target in state.units:
			if target.hp<=0 or target.side==unit.side or not state.enemy_is_blocked(target,unit.unit_id):continue
			blocking=true
			target.attack_speed_bonus-=int(data.talent_1.effect_params["enemy_attack_speed_reduce"])*(2 if count==1 else 1)
		if blocking:unit.attack_speed_bonus+=int(data.talent_1.effect_params["attack_speed_add"])*(2 if count==1 else 1)


static func cast(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var targets := PusherRules.targets(state,source,data.attack_range,false)
	if targets.is_empty():return
	if source.lee_mark_target_id>=0:explode(state,source)
	SkillRules.activate(source,data)
	source.skill_ticks_left=0
	source.lee_mark_target_id=targets[0].unit_id
	targets[0].lee_marked=true
	source.lee_mark_cell=targets[0].cell
	source.lee_mark_until_tick=state.tick+int(data.skills[source.skill_index].effect_params["mark_ticks"])
	source.lee_mark_stacks=0


static func marked_target(state: MatchState, source: UnitState) -> UnitState:
	for target in state.units:
		if target.unit_id==source.lee_mark_target_id:return target
	return null


static func target_priority(state: MatchState, unit: UnitState) -> bool:
	return unit.lee_marked


static func advance(state: MatchState) -> void:
	for source in state.units:
		if source.operator_id!="lee" or source.lee_mark_target_id<0:continue
		var target := marked_target(state,source)
		if target!=null:source.lee_mark_cell=target.cell
		if target==null or target.hp<=0 or state.tick>=source.lee_mark_until_tick:explode(state,source)


static func after_damage(state: MatchState, target: UnitState, attacker: UnitState) -> void:
	for source in state.units:
		if source.operator_id!="lee" or source.lee_mark_target_id!=target.unit_id:continue
		source.lee_mark_cell=target.cell
		var params: Dictionary=state._operator_data[source.operator_id].skills[source.skill_index].effect_params
		if attacker!=null and attacker.side==source.side and target.side!=source.side:source.lee_mark_stacks=mini(int(params["max_stacks"]),source.lee_mark_stacks+1)
		if target.hp<=0 or source.lee_mark_stacks>=int(params["max_stacks"]):explode(state,source)


static func on_exit(state: MatchState, source: UnitState, died: bool) -> void:
	if source.operator_id!="lee" or source.lee_mark_target_id<0:return
	var target := marked_target(state,source)
	if died or (target!=null and state.enemy_is_blocked(target,source.unit_id)):explode(state,source)
	else:clear_mark(state,source)


static func clear_mark(state: MatchState, source: UnitState) -> void:
	var target := marked_target(state,source)
	if target!=null:target.lee_marked=false
	source.lee_mark_target_id=-1
	source.lee_mark_until_tick=-1
	source.lee_mark_stacks=0
	source.lee_mark_cell=Vector2i(-1,-1)


static func explode(state: MatchState, source: UnitState) -> void:
	var data: OperatorData=state._operator_data[source.operator_id]
	var params := data.skills[source.skill_index].effect_params
	var power := roundi(SkillRules.attack_value(source,data,true)*(int(params["base_attack_percent"])+source.lee_mark_stacks*int(params["stack_attack_percent"]))/100.0)
	var center := source.lee_mark_cell
	clear_mark(state,source) # Clear first, so the explosion cannot feed its own mark.
	PusherRules.mark_attack(state,source,center)
	for target in state.units:
		if target.hp<=0 or target.side==source.side or (target.cell-center).length_squared()>int(params["splash_radius_squared"]):continue
		var target_data: OperatorData=state._operator_data[target.operator_id]
		var damage := Combat.calculate_damage(power,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"magical",SkillRules.dodge_chance(target,target_data,"magical"),state.rng,data.profession_id,state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
		state._apply_damage(target,target_data,damage,"magical",source,false)


static func attack(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var skill := data.skills[source.skill_index]
	if skill.effect_type in ["lee_admonition","lee_guest"] and SkillRules.can_activate(source,skill):SkillRules.activate(source,data)
	if not AttackTimeline.advance(state,source):return
	var offsets := AttackRange.effective_offsets(source,data)
	var found := SwordRules.target(state,source,offsets,false)
	found=AttackTimeline.pin_found(state,source,found)
	if found.is_empty():return
	if not AttackTimeline.windup_found(state,source,data,found):return
	PusherRules.mark_attack(state,source,found.cell)
	source.attack_ticks_left=SkillRules.attack_interval_ticks(source,data)
	var power := SkillRules.attack_value(source,data)
	if found.kind==0:
		var target_data: OperatorData=state._operator_data[found.unit.operator_id]
		var damage := Combat.calculate_damage(power,SkillRules.defense_value(found.unit,target_data),SkillRules.magic_resist_value(found.unit,target_data),"physical",SkillRules.dodge_chance(found.unit,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(found.unit,"physical"))
		state._apply_damage(found.unit,target_data,damage,"physical",source)
	elif found.kind==1:TacticalRules.strike_box(state,source,found.box)
	else:state.ball.add_push(source.cell,power,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,source.facing))
	if source.hp<=0 or SkillRules.active_ticks(source)==0 or skill.effect_type!="lee_guest":return
	for target in PusherRules.targets(state,source,offsets,false):
		if found.kind==0 and target==found.unit:continue
		DisplacementRules.apply_unit(state,source,target,DisplacementRules.direction(source,target.cell,"push"),int(skill.effect_params["shift_force"]))
