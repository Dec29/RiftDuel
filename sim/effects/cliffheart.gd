class_name CliffheartRules
extends RefCounted


static func is_blocking(state: MatchState, source: UnitState) -> bool:
	if state.terrain_at(source.cell)!="ground":return false
	for target in state.units:
		if target.hp>0 and target.side!=source.side and state.enemy_is_blocked(target,source.unit_id):return true
	return false


static func hook_targets(state: MatchState, unit: UnitState, offsets: Array[Vector2i]) -> Array[UnitState]:
	var found := PusherRules.targets(state,unit,offsets,false)
	found.sort_custom(func(a: UnitState,b: UnitState) -> bool:
		if a.side!=b.side:return a.side!=unit.side
		var ad := (a.cell-unit.cell).length_squared();var bd := (b.cell-unit.cell).length_squared()
		return ad>bd if ad!=bd else a.unit_id<b.unit_id)
	return found


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	var found := hook_targets(state,unit,skill.attack_range_override)
	if found.is_empty():
		hook_object(state,unit,data,skill.attack_range_override);return
	found.resize(mini(found.size(),int(skill.effect_params["target_count"])))
	resolve_hook(state,unit,data,found,true)


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.last_attack_tick==state.tick or unit.critical_ticks_left>0:return
	if not AttackTimeline.advance(state,unit):return
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="pull_strike" and SkillRules.can_activate(unit,skill):
		var found := AttackTimeline.pinned(state,unit,hook_targets(state,unit,data.attack_range).slice(0,1))
		if not found.is_empty():
			if not AttackTimeline.windup(state,unit,data,found,found[0].cell):return
			var selected: Array[UnitState]=[found[0]]
			resolve_hook(state,unit,data,selected,false)
			unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
			return
		var object:=AttackTimeline.pin_found(state,unit,SwordRules.target(state,unit,data.attack_range,false))
		if not object.is_empty() and object.kind!=0 and not AttackTimeline.windup_found(state,unit,data,object):return
		if hook_object(state,unit,data,data.attack_range):
			unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data);return
	var found := SwordRules.target(state,unit,data.attack_range,false)
	if state.terrain_at(unit.cell)=="ground":
		for enemy in state.units:
			if state.enemy_is_targetable(unit.side,enemy) and state.enemy_is_blocked(enemy,unit.unit_id):found={"kind":0,"cell":enemy.cell,"unit":enemy};break
	found=AttackTimeline.pin_found(state,unit,found)
	if found.is_empty():return
	if not AttackTimeline.windup_found(state,unit,data,found):return
	PusherRules.mark_attack(state,unit,found.cell)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var attack_value := SkillRules.attack_output_value(unit,data)
	if found.kind!=0 or not state.enemy_is_blocked(found.unit,unit.unit_id):
		AttackTimeline.found_projectile(state,unit,data,found,attack_value,"physical")
	else:
		var target: UnitState=found.unit;var target_data: OperatorData=state._operator_data[target.operator_id]
		var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target,"physical"))
		state._apply_damage(target,target_data,damage,"physical",unit)



static func resolve_hook(state: MatchState, source: UnitState, data: OperatorData, targets: Array[UnitState], chain: bool) -> void:
	var skill := data.skills[source.skill_index]
	var attack_value := roundi(SkillRules.attack_value(source,data)*float(skill.effect_params["attack_mult"]))
	PusherRules.mark_attack(state,source,targets[0].cell)
	SkillRules.activate(source,data)
	source.skill_ticks_left=int(skill.effect_params["channel_ticks"])
	source.pusher_strike_tick=state.tick
	targets.sort_custom(func(a: UnitState,b: UnitState) -> bool:return a.unit_id<b.unit_id)
	for target in targets:
		if source.hp<=0:break
		if not chain:
			var shot:=AttackTimeline.generic_projectile(state,source,data,target,null,target.cell,attack_value,"magical")
			shot.shift_force=int(skill.effect_params.shift_force);shot.shift_pull=true
			continue
		var target_data: OperatorData=state._operator_data[target.operator_id]
		var kind := "true" if chain else "magical"
		var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),kind,SkillRules.dodge_chance(target,target_data,kind),state.rng,data.profession_id,state._damage_taken_percent(target,kind),state._magical_damage_taken_percent(target))
		if not state._apply_damage(target,target_data,damage,kind,source) or target.hp<=0:continue
		DisplacementRules.apply_unit(state,source,target,DisplacementRules.direction(source,target.cell,"pull"),int(skill.effect_params["shift_force"]))
		if chain:
			target.hook_owner_id=source.unit_id
			target.hook_due_tick=state.tick+(target.displacement_ticks_left if target.displacement_ticks_left>0 else int(skill.effect_params["channel_ticks"]))
			target.hook_stun_ticks=int(skill.effect_params["stun_ticks"])
	AuraRules.refresh(state)


static func advance_hooks(state: MatchState) -> void:
	for target in state.units:
		if target.hook_owner_id<0:continue
		var hook_source := WArtilleryRules.owner(state,target.hook_owner_id)
		var owner_present := hook_source!=null and hook_source.hp>0
		if state.tick<target.hook_due_tick and owner_present and target.hp>0:continue
		var duration := target.hook_stun_ticks
		target.hook_owner_id=-1;target.hook_due_tick=-1;target.hook_stun_ticks=0
		if target.hp>0:SwordRules.stun(state,target,duration,hook_source)


static func on_exit(state: MatchState, source: UnitState) -> void:
	for target in state.units:
		if target.hook_owner_id!=source.unit_id:continue
		var duration := target.hook_stun_ticks
		target.hook_owner_id=-1;target.hook_due_tick=-1;target.hook_stun_ticks=0
		if target.hp>0:SwordRules.stun(state,target,duration,source)


static func hook_object(state: MatchState, source: UnitState, data: OperatorData, offsets: Array[Vector2i]) -> bool:
	var found := SwordRules.target(state,source,offsets,false)
	if found.is_empty() or found.kind==0:return false
	var skill := data.skills[source.skill_index]
	SkillRules.activate(source,data)
	source.skill_ticks_left=0
	source.pusher_strike_tick=state.tick
	PusherRules.mark_attack(state,source,found.cell)
	if found.kind==1:TacticalRules.strike_box(state,source,found.box)
	else:
		var direction := Vector2i(signi(source.cell.x-state.ball.cell.x),signi(source.cell.y-state.ball.cell.y))
		if direction==Vector2i.ZERO:direction=AttackRange.rotate_offset(Vector2i.LEFT,source.facing)
		state.ball.add_push(state.ball.cell,roundi(SkillRules.attack_value(source,data)*float(skill.effect_params["attack_mult"])),state._ball_data,direction)
	return true
