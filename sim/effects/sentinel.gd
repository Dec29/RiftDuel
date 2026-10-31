class_name SentinelRules
extends RefCounted


static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.operator_id=="jessica_alter" and unit.side==side and unit.hp>0:return unit
	return null


static func owner_for(state: MatchState, shield: UnitState) -> UnitState:
	for unit in state.units:
		if unit.unit_id==shield.jessica_owner_id and unit.hp>0:return unit
	return null


static func shield_for(state: MatchState, source: UnitState) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.jessica_owner_id==source.unit_id:return unit
	return null


static func visible(state: MatchState, side: int) -> bool:
	var source := owner(state,side)
	return source!=null and source.silence_ticks_left==0 and shield_for(state,source)==null


static func can_deploy(state: MatchState, side: int, cell: Vector2i) -> bool:
	var source := owner(state,side)
	return visible(state,side) and absi(source.cell.x-cell.x)+absi(source.cell.y-cell.y)==1


static func deployed(state: MatchState, shield: UnitState) -> void:
	var source := owner(state,shield.side)
	shield.jessica_owner_id=source.unit_id
	shield.jessica_expiry_tick=state.tick+int((state._operator_data[source.operator_id] as OperatorData).talent_1.effect_params["shield_lifetime_ticks"])
	source.jessica_original_facing=source.facing
	var offset := shield.cell-source.cell
	for facing in range(4):
		if AttackRange.rotate_offset(Vector2i.RIGHT,facing)==offset:source.facing=facing;break
	state.sides[shield.side].cooldowns["jessica_shield"]=roundi((state._operator_data[shield.operator_id] as OperatorData).redeploy_time*state.CONFIG.TICK_RATE)
	var skill := (state._operator_data[source.operator_id] as OperatorData).skills[source.skill_index]
	if SkillRules.active_ticks(source)!=0 and skill.effect_type=="jessica_bombardment":source.jessica_bomb_pending=true
	extend_shield(source,shield,skill)


static func extend_shield(source: UnitState, shield: UnitState, skill: SkillResource) -> void:
	if not shield.jessica_shield_extended and SkillRules.active_ticks(source)!=0 and skill.effect_type=="jessica_vigilance":
		shield.jessica_expiry_tick+=int(skill.effect_params["shield_duration_add_ticks"]);shield.jessica_shield_extended=true


static func remove_shield(state: MatchState, shield: UnitState) -> void:
	var source := owner_for(state,shield)
	if source!=null:source.facing=source.jessica_original_facing
	state.units.erase(shield)


static func remove_owned(state: MatchState, source: UnitState) -> void:
	for shield: UnitState in state.units.duplicate():
		if shield.jessica_owner_id==source.unit_id:remove_shield(state,shield)


static func maintain(state: MatchState) -> void:
	for shield: UnitState in state.units.duplicate():
		if shield.jessica_owner_id<0:continue
		var source := owner_for(state,shield)
		if source==null or shield.hp<=0 or state.tick>=shield.jessica_expiry_tick:remove_shield(state,shield)
		else:extend_shield(source,shield,(state._operator_data[source.operator_id] as OperatorData).skills[source.skill_index])


static func refresh(state: MatchState) -> void:
	for source in state.units:
		if source.hp<=0 or source.operator_id!="jessica_alter":continue
		var shield := shield_for(state,source)
		if shield==null or source.silence_ticks_left>0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		var behind := source.cell-AttackRange.rotate_offset(Vector2i.RIGHT,source.facing)
		for ally in state.units:
			if ally.hp>0 and ally.side==source.side and (ally==source or ally.cell==behind):ally.defense_bonus_percent+=int(data.talent_1.effect_params["behind_defense_percent"])
		var skill := data.skills[source.skill_index]
		if SkillRules.active_ticks(source)!=0 and skill.effect_type in ["jessica_vigilance","jessica_bombardment"]:shield.defense_bonus_percent+=roundi((float(skill.effect_params["shield_defense_mult"])-1.0)*100)


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="jessica_bombardment" and SkillRules.active_ticks(unit)!=0:
		unit.skill_ticks_left=0;unit.skill_ammo_left=0;unit.jessica_bomb_pending=false;AuraRules.refresh(state);return
	SkillRules.activate(unit,data)
	if skill.effect_type=="jessica_bombardment":
		unit.skill_ammo_left=int(skill.effect_params["ammo_count"]);unit.jessica_bomb_pending=shield_for(state,unit)!=null
	var shield := shield_for(state,unit)
	if shield!=null:extend_shield(unit,shield,skill)
	AuraRules.refresh(state)


static func received(state: MatchState, shield: UnitState) -> void:
	if shield.jessica_owner_id<0:return
	var source := owner_for(state,shield)
	if source==null or source.silence_ticks_left>0:return
	var talent := (state._operator_data[source.operator_id] as OperatorData).talent_2
	if state.rng.next_percent()<int(talent.effect_params["chance_percent"]):SagaRules.reward(state,source,int(talent.effect_params["sp_add"]))


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.operator_id=="jessica_shield":return
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="jessica_vigilance" and SkillRules.can_activate(unit,skill):cast(state,unit,data)
	var ready := AttackTimeline.advance(state,unit)
	if unit.jessica_bomb_pending and SkillRules.active_ticks(unit)!=0 and unit.stun_ticks_left==0 and unit.frozen_ticks_left==0 and unit.sleep_ticks_left==0 and unit.displacement_ticks_left==0 and unit.bind_ticks_left==0:fire_bomb(state,unit,data)
	if not ready:return
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets := PusherRules.targets(state,unit,offsets,false,true)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,offsets)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var amount := SkillRules.attack_value(unit,data)
	if not targets.is_empty():
		var target := targets[0]
		AttackTimeline.generic_projectile(state,unit,data,target,null,target.cell,amount,"physical")
	else:
		var found := false
		for box in state.tactical_boxes:
			if box.cell==center and box.hits_left>0:AttackTimeline.generic_projectile(state,unit,data,null,box,center,amount,"physical");found=true;break
		if not found and state.ball.move_ticks_left==0:AttackTimeline.generic_projectile(state,unit,data,null,null,center,amount,"physical")
	if SkillRules.active_ticks(unit)!=0 and skill.effect_type=="jessica_bombardment":
		unit.skill_ammo_left-=1
		if unit.skill_ammo_left==0:unit.skill_ticks_left=0;unit.jessica_bomb_pending=false;AuraRules.refresh(state)


static func fire_bomb(state: MatchState, source: UnitState, data: OperatorData) -> void:
	source.jessica_bomb_pending=false
	var skill := data.skills[source.skill_index]
	var direction := AttackRange.rotate_offset(Vector2i.RIGHT,source.facing)
	var distance := 0
	for offset in AttackRange.effective_offsets(source,data):
		if offset.y==0:distance=maxi(distance,offset.x)
	var center := source.cell+direction*distance
	for step in range(1,distance+1):
		var cell := source.cell+direction*step
		var collided := false
		for target in state.units:
			if StainlessRules.is_damage_target(source,target) and target.hp>0 and target.cell==cell:collided=true;break
		if collided:center=cell;break
	source.jessica_bomb_tick=state.tick;source.jessica_bomb_cell=center
	var attack := roundi(SkillRules.attack_value(source,data)*float(skill.effect_params["bomb_attack_mult"]))
	var found := false
	for target: UnitState in state.units.duplicate():
		if target.hp<=0 or not StainlessRules.is_damage_target(source,target) or (target.cell-center).length_squared()>int(skill.effect_params["splash_radius_squared"]):continue
		found=true
		var td: OperatorData=state._operator_data[target.operator_id]
		var damage := Combat.calculate_damage(attack,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),"physical",SkillRules.dodge_chance(target,td,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target,"physical"))
		if state._apply_damage(target,td,damage,"physical",source) and target.hp>0:SwordRules.stun(state,target,int(skill.effect_params["bomb_stun_ticks"]),source)
	if found:return
	for box in state.tactical_boxes:
		if (box.cell-center).length_squared()<=int(skill.effect_params["splash_radius_squared"]):TacticalRules.strike_box(state,source,box);return
	if state.ball.move_ticks_left==0 and (state.ball.cell-center).length_squared()<=int(skill.effect_params["splash_radius_squared"]):state.ball.add_push(source.cell,attack,state._ball_data,direction)
