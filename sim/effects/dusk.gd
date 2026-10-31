class_name DuskRules
extends RefCounted


static func owner_for(state: MatchState, token: UnitState) -> UnitState:
	for unit in state.units:
		if unit.unit_id==token.dusk_owner_id and unit.operator_id=="dusk" and unit.hp>0:return unit
	return null


static func maintain(state: MatchState) -> void:
	for token in state.units.duplicate():
		if token.operator_id=="dusk_freeling" and (owner_for(state,token)==null or state.tick>=token.dusk_expiry_tick):state.units.erase(token)


static func remove_owned(state: MatchState, source: UnitState) -> void:
	for token in state.units.duplicate():
		if token.dusk_owner_id==source.unit_id:state.units.erase(token)


static func reward_kill(state: MatchState, source: UnitState, target: UnitState) -> void:
	if source==null or source.side==target.side:return
	var owner := owner_for(state,source) if source.operator_id=="dusk_freeling" else source
	if owner==null or owner.operator_id!="dusk" or owner.hp<=0 or owner.silence_ticks_left>0:return
	var data: OperatorData=state._operator_data[owner.operator_id]
	owner.dusk_kill_stacks=mini(int(data.talent_1.effect_params["max_stacks"]),owner.dusk_kill_stacks+1)


static func legal_cell(state: MatchState, source: UnitState, cell: Vector2i) -> bool:
	if cell.x<0 or cell.y<0 or cell.x>=state.CONFIG.GRID_COLUMNS or cell.y>=state.CONFIG.GRID_ROWS or state.terrain_at(cell)!="ground":return false
	if (source.side==0 and cell.x<state.ball.cell.x) or (source.side==1 and cell.x>state.ball.cell.x):return false
	if state.item_reserves_cell(cell) or state.box_reserves_cell(cell):return false
	for unit in state.units:
		if unit.cell==cell:return false
	return true


# Approved fixed-station adaptation: nearest legal own-side free cell in current range.
static func summon(state: MatchState, source: UnitState, data: OperatorData, center: Vector2i, refresh: bool) -> void:
	var offsets := AttackRange.effective_offsets(source,data)
	var candidates: Array[Vector2i]=[]
	for offset in offsets:
		var cell := source.cell+AttackRange.rotate_offset(offset,source.facing)
		if legal_cell(state,source,cell):candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i,b: Vector2i)->bool:
		var aa := (a-center).length_squared();var bb := (b-center).length_squared()
		return (a.x<b.x if a.y==b.y else a.y<b.y) if aa==bb else aa<bb)
	if refresh:
		var tokens: Array[UnitState]=[]
		for token in state.units:
			if token.dusk_owner_id==source.unit_id and token.hp>0 and (token.cell-center).length_squared()<=1:tokens.append(token)
		tokens.sort_custom(func(a: UnitState,b: UnitState)->bool:
			var aa := (a.cell-center).length_squared();var bb := (b.cell-center).length_squared()
			return a.unit_id<b.unit_id if aa==bb else aa<bb)
		if not tokens.is_empty():
			var token := tokens[0]
			var token_data: OperatorData=state._operator_data[token.operator_id]
			var max_hp := SkillRules.max_health_value(token,token_data)
			token.hp=mini(max_hp,token.hp+Combat.calculate_healing(max_hp));token.last_heal_tick=state.tick
			token.dusk_expiry_tick=state.tick+750
			return
	if candidates.is_empty():return
	var token_data: OperatorData=state._operator_data["dusk_freeling"]
	var token := UnitState.new(state.next_unit_id,source.side,"dusk_freeling",candidates[0],token_data.max_health,0,roundi(token_data.attack_interval*state.CONFIG.TICK_RATE),source.facing,0)
	state.next_unit_id+=1
	token.deployed_tick=state.tick;token.dusk_expiry_tick=state.tick+750;token.dusk_owner_id=source.unit_id
	state.units.append(token)


static func attack(state: MatchState, source: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,source):return
	var token := source.operator_id=="dusk_freeling"
	var skill := data.skills[source.skill_index]
	var offsets := AttackRange.effective_offsets(source,data)
	var targets := PusherRules.targets(state,source,offsets,false,true) if token else PusherRules.targets(state,source,offsets,false)
	if token:
		targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
			if a.side!=b.side:return a.side!=source.side
			var aa := state.enemy_is_blocked(a,source.unit_id);var bb := state.enemy_is_blocked(b,source.unit_id)
			return a.unit_id<b.unit_id if aa==bb else aa)
	elif SkillRules.active_ticks(source)>0 and skill.effect_type=="dusk_freehand":
		targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
			if a.side!=b.side:return a.side!=source.side
			var aa := state.enemy_is_blocked(a);var bb := state.enemy_is_blocked(b)
			return a.unit_id<b.unit_id if aa==bb else not aa)
	targets=AttackTimeline.pinned(state,source,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,source,offsets)
	if center.x<0:return
	if not AttackTimeline.windup(state,source,data,targets,center):return
	var charged := not token and skill.effect_type=="dusk_paint" and SkillRules.can_activate(source,skill)
	if charged:SkillRules.activate(source,data)
	if not token and not targets.is_empty() and source.silence_ticks_left==0:
		if not source.dusk_first_attack_used:
			source.dusk_first_attack_used=true;summon(state,source,data,center,false)
		elif SkillRules.active_ticks(source)>0 and skill.effect_type=="dusk_freehand":summon(state,source,data,center,true)
	PusherRules.mark_attack(state,source,center);source.attack_ticks_left=SkillRules.attack_interval_ticks(source,data)
	var power := SkillRules.attack_value(source,data)
	var all_range := not token and SkillRules.active_ticks(source)>0 and skill.effect_type=="dusk_ink"
	var radius := int(skill.effect_params["splash_radius_squared"]) if not token and ((charged and skill.effect_type=="dusk_paint") or (SkillRules.active_ticks(source)>0 and skill.effect_type=="dusk_freehand")) else (0 if token else int(data.branch_trait.effect_params["splash_radius_squared"]))
	if not token:
		if all_range:
			for target in state.units:
				if target.hp>0 and StainlessRules.is_damage_target(source,target) and state._is_in_attack_range(source,target.cell,offsets):AttackTimeline.generic_projectile(state,source,data,target,null,target.cell,power,"magical")
		else:
			var paint:=AttackTimeline.area_projectile(state,source,data,center,power,"magical",radius)
			paint.splash_affects_objects=targets.is_empty()
		if charged:source.skill_ticks_left=0
		elif source.skill_ticks_left==0:SagaRules.reward(state,source,1)
		return
	for target in state.units.duplicate():
		if target not in state.units or target.hp<=0 or not StainlessRules.is_damage_target(source,target):continue
		if (not all_range and (target.cell-center).length_squared()>radius) or (all_range and not state._is_in_attack_range(source,target.cell,offsets)):continue
		var target_data: OperatorData=state._operator_data[target.operator_id]
		var scale := int(skill.effect_params["low_health_damage_percent"]) if all_range and target.hp*100<SkillRules.max_health_value(target,target_data)*int(skill.effect_params["hp_threshold_percent"]) else 100
		var damage := Combat.calculate_damage(power,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"magical",SkillRules.dodge_chance(target,target_data,"magical"),state.rng,SkillRules.damage_profession_id(data),state._damage_taken_percent(target,"magical")*scale/100.0,state._magical_damage_taken_percent(target))
		state._apply_damage(target,target_data,damage,"magical",source)
	if targets.is_empty():
		var box := false
		for target_box in state.tactical_boxes:
			if target_box.hits_left>0 and target_box.cell==center:TacticalRules.strike_box(state,source,target_box);box=true;break
		if not box and state.ball.move_ticks_left==0:state.ball.add_push(source.cell,power,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,source.facing))
	if charged:source.skill_ticks_left=0
	elif not token and source.skill_ticks_left==0:SagaRules.reward(state,source,1)
