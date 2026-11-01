class_name PusherRules
extends RefCounted


static func maintain_cannon(state: MatchState, unit: UnitState, data: OperatorData) -> bool:
	if data.branch_trait.effect_type != "water_cannon":
		return true
	var elapsed := state.tick - unit.deployed_tick
	if elapsed >= int(data.branch_trait.effect_params["lifetime_ticks"]) or not owner_present(state, unit.side):
		state.sides[unit.side].cannon_cooldown_ticks = roundi(data.redeploy_time * state.CONFIG.TICK_RATE)
		return false
	var owner_data: OperatorData = state._operator_data["weedy"]
	var params := owner_data.talent_2.effect_params
	if elapsed > 0 and elapsed % int(params["sp_interval_ticks"]) == 0:
		for owner in state.units:
			if owner.operator_id == "weedy" and owner.side == unit.side and owner.hp > 0 and owner.silence_ticks_left == 0 and owner.skill_ticks_left == 0 and absi(owner.cell.x-unit.cell.x)+absi(owner.cell.y-unit.cell.y) == 1:
				owner.sp = mini(SkillRules.sp_limit(owner_data.skills[owner.skill_index]), owner.sp + int(params["sp_add"]))
	return true


static func advance(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if data.branch_trait.effect_type == "water_cannon" and not owner_present(state,unit.side):return
	var skill := data.skills[unit.skill_index]
	if data.branch_trait.effect_type == "pusher" and skill.effect_type == "pusher_cannon_mode" and SkillRules.can_activate(unit, skill):
		SkillRules.activate(unit, data)
		unit.pusher_mode_started_tick=state.tick
	if unit.nitrogen_shot_tick==state.tick or (unit.operator_id=="weedy" and skill.effect_type=="nitrogen_blast" and unit.skill_ticks_left==-1) or (unit.operator_id=="weedy_cannon" and unit.attack_intent!=null and unit.attack_action_clip in ["Skill","Skill_Down"]):
		return
	if not AttackTimeline.advance(state,unit):return
	var offsets := AttackRange.effective_offsets(unit, data)
	var enemies := targets(state, unit, offsets, data.branch_trait.effect_type == "water_cannon")
	enemies=AttackTimeline.pinned(state,unit,enemies)
	var box_target: TacticalBox
	if enemies.is_empty():
		for box in state.tactical_boxes:
			if state._is_in_attack_range(unit, box.cell, offsets):box_target=box;break
	var ball_target := enemies.is_empty() and box_target == null and state.ball.move_ticks_left == 0 and state._is_in_attack_range(unit, state.ball.cell, offsets)
	if enemies.is_empty() and box_target == null and not ball_target:
		return
	if not AttackTimeline.windup(state,unit,data,enemies,enemies[0].cell if not enemies.is_empty() else (box_target.cell if box_target!=null else state.ball.cell)):return
	var charged := skill.effect_type == "pusher_strike" and SkillRules.can_activate(unit, skill)
	if charged:
		SkillRules.activate(unit,data)
		unit.pusher_strike_tick=state.tick
	var attack := SkillRules.attack_output_value(unit,data)
	var force := -1
	if data.branch_trait.effect_type == "water_cannon":force=state.CONFIG.WATER_CANNON_BASE_SHIFT_FORCE+int((state._operator_data["weedy"] as OperatorData).talent_2.effect_params["shift_force_add"])
	elif SkillRules.active_ticks(unit) != 0 and skill.effect_type in ["pusher_strike","pusher_cannon_mode"]:force=int(skill.effect_params["shift_force"])
	var primary: UnitState = enemies[0] if not enemies.is_empty() else null
	var center := primary.cell if primary != null else (box_target.cell if box_target != null else state.ball.cell)
	mark_attack(state,unit,center)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var count := mini(enemies.size(),data.block_count) if data.branch_trait.effect_type == "pusher" else mini(1,enemies.size())
	# S2 original splash radius0.9 contains only the primary cell on this integer grid.
	if SkillRules.active_ticks(unit) != 0 and skill.effect_type == "pusher_cannon_mode":count=mini(1,enemies.size())
	for index in count:
		var target := enemies[index]
		if unit.hp <= 0:break
		if data.branch_trait.effect_type=="water_cannon" or (SkillRules.active_ticks(unit)!=0 and skill.effect_type=="pusher_cannon_mode"):
			var shot:=AttackTimeline.generic_projectile(state,unit,data,target,null,target.cell,attack,"physical")
			shot.shift_force=force
			continue
		var target_data: OperatorData = state._operator_data[target.operator_id]
		var damage := Combat.calculate_damage(attack,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,SkillRules.damage_profession_id(data),state._damage_taken_percent(target, "physical"))
		var hit := state._apply_damage(target,target_data,damage,"physical",unit)
		if hit and target.hp > 0:
			if charged:
				var duration := int(skill.effect_params["stun_ticks"])
				var resistant := StatusRules.has_resistance(state,target)
				StatusRules.add_control(state,target,"stun",duration*state.CONFIG.STATUS_RESISTANCE_DURATION_PERCENT/100 if resistant else duration,unit)
			if force >= 0:DisplacementRules.apply_unit(state,unit,target,DisplacementRules.direction(unit,target.cell,"push"),force)
	if box_target!=null or ball_target:
		if data.branch_trait.effect_type=="water_cannon" or (SkillRules.active_ticks(unit)!=0 and skill.effect_type=="pusher_cannon_mode"):
			var shot:=AttackTimeline.generic_projectile(state,unit,data,null,box_target,center,attack,"physical")
			shot.shift_force=force
		elif box_target!=null:TacticalRules.strike_box(state,unit,box_target)
		else:
			state.ball.add_push(unit.cell,attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
			if force>=0:DisplacementRules.apply_ball(state,DisplacementRules.direction(unit,state.ball.cell,"push"),force)
	if charged:unit.skill_ticks_left=0


static func targets(state: MatchState, unit: UnitState, offsets: Array[Vector2i], nearest: bool, include_blocked: bool = false) -> Array[UnitState]:
	var result: Array[UnitState]=[]
	for target in state.units:
		if state.enemy_is_targetable(unit.side,target,unit) and (state._is_in_attack_range(unit,target.cell,offsets) or (include_blocked and state.enemy_is_blocked(target,unit.unit_id))):result.append(target)
	result.sort_custom(func(a: UnitState,b: UnitState) -> bool:
		var ad: OperatorData=state._operator_data[a.operator_id]
		var bd: OperatorData=state._operator_data[b.operator_id]
		var at := SkillRules.taunt_level(a,ad)
		var bt := SkillRules.taunt_level(b,bd)
		if at!=bt:return at>bt
		if state.can_attack_sleeping(unit) and (a.sleep_ticks_left>0)!=(b.sleep_ticks_left>0):return a.sleep_ticks_left>0
		if nearest:
			var aa := (a.cell-unit.cell).length_squared();var bb := (b.cell-unit.cell).length_squared()
			if aa!=bb:return aa<bb
		return a.unit_id<b.unit_id)
	return result


static func nitrogen_begin(state: MatchState, source: UnitState, data: OperatorData, skill: SkillResource) -> bool:
	var enemies:=targets(state,source,skill.attack_range_override,source.operator_id=="weedy_cannon")
	var center:=enemies[0].cell if not enemies.is_empty() else AttackTimeline.object_cell(state,source,skill.attack_range_override)
	if center.x<0:return false
	AttackTimeline.area_windup(state,source,data,center)
	source.attack_action_triggered=true
	if source.last_basic_interrupt_tick==state.tick:source.last_basic_interrupt_tick=state.tick-1
	if source.operator_id=="weedy_cannon":
		var clip:="Skill_Down" if source.facing==1 else "Skill"
		var side:=1 if source.facing==3 else 0
		var record: Array=AttackActionData.CATALOG.EVENTS.weedy_cannon[clip][str(side)]
		var intent:=source.attack_intent
		intent.clip=clip;intent.source_frames=int(record[0]);intent.release_frame=int(record[1][0])
		intent.window_ticks=mini(intent.source_frames,maxi(1,intent.interval_ticks*state.CONFIG.ATTACK_ACTION_WINDOW_PERCENT/100))
		intent.release_tick=state.tick+ceili(float(intent.release_frame)*intent.window_ticks/intent.source_frames)
		source.attack_action_clip=clip;source.attack_action_source_frames=intent.source_frames;source.attack_action_window_ticks=intent.window_ticks
	return true

static func nitrogen_release(state: MatchState, source: UnitState, data: OperatorData, skill: SkillResource, attack: int, force: int) -> void:
	var center:=source.attack_intent.cell
	source.attack_intent=null
	var shot:=AttackTimeline.area_projectile(state,source,data,center,attack,"magical",int(skill.effect_params.splash_radius_squared))
	shot.delivery=3;shot.shift_force=force;shot.rupture_damage_per_cell=int(skill.effect_params.rupture_damage_per_cell);shot.rupture_ticks=int(skill.effect_params.rupture_ticks)
	source.nitrogen_shot_tick=state.tick;mark_attack(state,source,center)

static func nitrogen_impact(state: MatchState, shot: AttackProjectile, source: UnitState) -> void:
	var push_targets: Array[UnitState]=[]
	var data: OperatorData=state._operator_data[shot.operator_id]
	var marker:=UnitState.new(shot.source_id,shot.source_side,shot.operator_id,shot.source_cell,0,0,0,shot.facing)
	# Mark every target before rigid-group displacement can move its neighbours.
	for target in state.units.duplicate():
		if target.hp<=0 or target.side==shot.source_side or target.operator_id=="weedy_cannon" or (target.cell-shot.target_cell).length_squared()>shot.splash_radius_squared:continue
		var td: OperatorData=state._operator_data[target.operator_id]
		var damage:=Combat.calculate_damage(shot.attack,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),"magical",SkillRules.dodge_chance(target,td,"magical"),state.rng,SkillRules.damage_profession_id(data),state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
		if state._apply_damage(target,td,damage,"magical",source) and target.hp>0:
			if target.rupture_until_tick<=state.tick:
				target.rupture_source_id=shot.source_id;target.rupture_damage_per_cell=shot.rupture_damage_per_cell;target.rupture_until_tick=state.tick+shot.rupture_ticks
			push_targets.append(target)
	for target in push_targets:
		if target.hp>0:DisplacementRules.apply_unit(state,marker,target,DisplacementRules.direction(marker,target.cell,"push"),shot.shift_force)
	for box in state.tactical_boxes:
		if box.hits_left>0 and box.cell==shot.target_cell:TacticalRules.strike_box(state,marker,box);return
	if state.goals[0]+state.goals[1]==shot.goal_generation and state.ball.cell==shot.target_cell and state.ball.move_ticks_left==0:
		state.ball.add_push(shot.source_cell,shot.attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,shot.facing))
		DisplacementRules.apply_ball(state,DisplacementRules.direction(marker,state.ball.cell,"push"),shot.shift_force)


static func apply_rupture_damage(state: MatchState, target: UnitState) -> void:
	if target.hp<=0 or target.rupture_until_tick<=state.tick:return
	var data: OperatorData=state._operator_data[target.operator_id]
	var damage := Combat.calculate_damage(target.rupture_damage_per_cell,0,0,"true",0,state.rng,"specialist",state._damage_taken_percent(target, "true"))
	var source: UnitState
	for unit in state.units:
		if unit.unit_id==target.rupture_source_id:source=unit;break
	state._apply_damage(target,data,damage,"true",source)


static func mark_attack(state: MatchState, unit: UnitState, cell: Vector2i) -> void:
	unit.last_attack_tick=state.tick
	unit.last_attack_is_heal=false
	unit.last_attack_target_x=cell.x
	unit.last_attack_target_y=cell.y


static func resolve_nitrogen(state: MatchState) -> void:
	for unit in state.units:
		if unit.operator_id!="weedy" or unit.hp<=0:continue
		var data: OperatorData=state._operator_data.weedy
		var skill:=data.skills[unit.skill_index]
		if unit.skill_ticks_left!=-1 or skill.effect_type!="nitrogen_blast":continue
		if unit.attack_intent!=null and unit.attack_action_clip not in ["Skill_3","Skill_3_Down"]:StatusRules.interrupt_basic(state,unit)
		if unit.attack_intent==null:
			if not SkillRules.can_manually_activate(unit,skill) and (unit.stun_ticks_left>0 or unit.frozen_ticks_left>0 or unit.sleep_ticks_left>0):unit.skill_ticks_left=0;continue
			if not nitrogen_begin(state,unit,data,skill):unit.skill_ticks_left=0;continue
		elif not AttackTimeline.advance(state,unit):continue
		if unit.attack_intent==null or state.tick<unit.attack_intent.release_tick:continue
		var attack:=SkillRules.attack_output_value(unit,data)
		nitrogen_release(state,unit,data,skill,attack,int(skill.effect_params.shift_force))
		for cannon in state.units:
			if cannon.hp>0 and cannon.side==unit.side and cannon.operator_id=="weedy_cannon" and absi(cannon.cell.x-unit.cell.x)+absi(cannon.cell.y-unit.cell.y)==1:
				if cannon.attack_intent!=null:StatusRules.interrupt_basic(state,cannon)
				if nitrogen_begin(state,cannon,state.CANNON_DATA,skill):
					# Owner offensive attributes are sampled when the independent cannon actually fires.
					cannon.nitrogen_shot_tick=state.tick
		unit.skill_ticks_left=0
	for cannon in state.units:
		if cannon.hp<=0 or cannon.operator_id!="weedy_cannon" or cannon.attack_intent==null or cannon.attack_action_clip not in ["Skill","Skill_Down"]:continue
		if not AttackTimeline.advance(state,cannon):continue
		var source: UnitState
		for unit in state.units:
			if unit.hp>0 and unit.side==cannon.side and unit.operator_id=="weedy":source=unit;break
		if source==null:StatusRules.interrupt_basic(state,cannon);continue
		var data: OperatorData=state._operator_data.weedy
		var skill:=data.skills[2]
		var attack:=roundi(SkillRules.attack_value(source,data)*float(skill.effect_params.attack_mult))
		nitrogen_release(state,cannon,state.CANNON_DATA,skill,attack,int(skill.effect_params.shift_force)+int(data.talent_2.effect_params.shift_force_add))


static func owner_present(state: MatchState, side: int) -> bool:
	for unit in state.units:
		if unit.operator_id == "weedy" and unit.side == side and unit.hp > 0:
			return true
	return false


static func remove_orphan_cannons(state: MatchState) -> void:
	var retained: Array[UnitState] = []
	for unit in state.units:
		if unit.operator_id == "weedy_cannon" and not owner_present(state, unit.side):
			state.sides[unit.side].cannon_cooldown_ticks = roundi(state.CANNON_DATA.redeploy_time * state.CONFIG.TICK_RATE)
		else:
			retained.append(unit)
	state.units = retained
