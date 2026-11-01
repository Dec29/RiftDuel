class_name SiegeRules
extends RefCounted

# Only the siege-sniper branch enters this path; existing attack branches retain their semantics.
static func targets(state: MatchState, unit: UnitState, offsets: Array[Vector2i]) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for enemy in state.units:
		if state.enemy_is_targetable(unit.side, enemy) and state._is_in_attack_range(unit,enemy.cell,offsets):result.append(enemy)
	result.sort_custom(func(a: UnitState,b: UnitState) -> bool:
		var ad: OperatorData=state._operator_data[a.operator_id]
		var bd: OperatorData=state._operator_data[b.operator_id]
		var at := SkillRules.taunt_level(a,ad)
		var bt := SkillRules.taunt_level(b,bd)
		if at!=bt:return at>bt
		var aw := DisplacementRules.effective_weight(state,a)
		var bw := DisplacementRules.effective_weight(state,b)
		return aw>bw if aw!=bw else a.unit_id<b.unit_id)
	return result

static func mark_target(state: MatchState,unit: UnitState,data: OperatorData) -> bool:
	var enemies := targets(state,unit,data.attack_range)
	if not enemies.is_empty():
		unit.mark_kind=0;unit.mark_id=enemies[0].unit_id;unit.mark_cell=enemies[0].cell
	else:
		unit.mark_kind=-1
		for box in state.tactical_boxes:
			if state._is_in_attack_range(unit,box.cell,data.attack_range):
				unit.mark_kind=1;unit.mark_id=box.box_id;unit.mark_cell=box.cell;break
		if unit.mark_kind==-1 and state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,data.attack_range):
			unit.mark_kind=2;unit.mark_id=-1;unit.mark_cell=state.ball.cell
	if unit.mark_kind==-1:return false
	unit.mark_refresh_ticks=0
	return true

static func refresh_mark(state: MatchState,unit: UnitState) -> void:
	if unit.mark_refresh_ticks>0:unit.mark_refresh_ticks-=1;return
	unit.mark_refresh_ticks=5
	if unit.mark_kind==0:
		for enemy in state.units:
			if enemy.unit_id==unit.mark_id and enemy.hp>0:unit.mark_cell=enemy.cell;return
	elif unit.mark_kind==1:
		for box in state.tactical_boxes:
			if box.box_id==unit.mark_id:unit.mark_cell=box.cell;return
	elif unit.mark_kind==2:unit.mark_cell=state.ball.cell

static func rain_offsets(unit: UnitState,skill: SkillResource) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	var radius := int(skill.effect_params["splash_radius_squared"])
	for y in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			if x*x+y*y<=radius:result.append(AttackRange.rotate_offset(unit.mark_cell+Vector2i(x,y)-unit.cell,(4-unit.facing)%4))
	return result

static func close_skill(unit: UnitState,data: OperatorData) -> void:
	var old := SkillRules.attack_interval_ticks(unit,data)
	unit.skill_ticks_left=0;unit.skill_ammo_left=0;unit.rain_arrows_left=0
	unit.mark_kind=-1;unit.mark_id=-1;unit.mark_cell=Vector2i(-1,-1)
	unit.skill_hit_ids.clear()
	unit.attack_ticks_left=ceili(float(unit.attack_ticks_left)*SkillRules.attack_interval_ticks(unit,data)/old)

static func advance(state: MatchState,unit: UnitState,data: OperatorData) -> void:
	if unit.penetration_last_tick>=0 and state.tick-unit.penetration_last_tick>=int(data.talent_1.effect_params["reset_ticks"]):unit.penetration_stacks=0
	var skill := data.skills[unit.skill_index]
	var rain := unit.skill_ticks_left!=0 and skill.effect_type=="marked_arrow_rain"
	if rain:refresh_mark(state,unit)
	if unit.rain_arrows_left>0 and state.tick>=unit.rain_next_tick:
		unit.rain_arrows_left-=1;unit.rain_next_tick=state.tick+int(skill.effect_params["arrow_interval_ticks"])
		if unit.silence_ticks_left==0:rain_arrow(state,unit,data)
		if unit.rain_arrows_left==0 and unit.skill_ammo_left==0:
			close_skill(unit,data)
			return
	if not AttackTimeline.advance(state,unit):return
	var offsets := rain_offsets(unit,skill) if rain and unit.silence_ticks_left==0 else data.attack_range
	var enemies := targets(state,unit,offsets)
	enemies=AttackTimeline.pinned(state,unit,enemies)
	var box_target: TacticalBox
	if enemies.is_empty():
		for box in state.tactical_boxes:
			if state._is_in_attack_range(unit,box.cell,offsets):box_target=box;break
	var ball_target := enemies.is_empty() and box_target==null and state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,offsets)
	if enemies.is_empty() and box_target==null and not ball_target:return
	if not AttackTimeline.windup(state,unit,data,enemies,enemies[0].cell if not enemies.is_empty() else (box_target.cell if box_target!=null else state.ball.cell)):return
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	if unit.silence_ticks_left==0:
		unit.penetration_stacks=mini(int(data.talent_1.effect_params["max_stacks"]),unit.penetration_stacks+1)
		unit.penetration_last_tick=state.tick
	unit.last_attack_tick=state.tick;unit.last_attack_is_heal=false
	var center := enemies[0].cell if not enemies.is_empty() else (box_target.cell if box_target!=null else state.ball.cell)
	unit.last_attack_target_x=center.x;unit.last_attack_target_y=center.y
	if rain and unit.silence_ticks_left==0:
		ChenAlterRules.consume_ammo(state,unit,data,1);unit.rain_arrows_left=int(skill.effect_params["shot_count"])-1
		unit.rain_next_tick=state.tick+int(skill.effect_params["arrow_interval_ticks"])
		rain_arrow(state,unit,data)
		return
	var shots := 2 if skill.effect_type=="dual_arrow_repeat" and SkillRules.active_ticks(unit)!=0 else 1
	if not enemies.is_empty():
		for index in shots:
			var target := enemies[mini(index,enemies.size()-1)]
			if target.hp>0:hit(state,unit,data,target,SkillRules.attack_value(unit,data),true)
	elif box_target!=null:
		for index in shots:
			if box_target.hits_left>0:AttackTimeline.generic_projectile(state,unit,data,null,box_target,box_target.cell,SkillRules.attack_value(unit,data),"physical")
	else:
		for index in shots:
			if state.ball.move_ticks_left==0:AttackTimeline.generic_projectile(state,unit,data,null,null,state.ball.cell,SkillRules.attack_value(unit,data),"physical")

static func rain_arrow(state: MatchState,unit: UnitState,data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	var offsets := rain_offsets(unit,skill)
	var enemies: Array[UnitState]=[]
	for target in state.units:
		if state.enemy_is_targetable(unit.side,target) and state._is_in_attack_range(unit,target.cell,offsets):enemies.append(target)
	if not enemies.is_empty():
		var index := state.rng.next_u32()%enemies.size() if enemies.size()>1 else 0
		hit(state,unit,data,enemies[index],SkillRules.attack_value(unit,data),false)
		return
	for box in state.tactical_boxes:
		if state._is_in_attack_range(unit,box.cell,offsets):AttackTimeline.generic_projectile(state,unit,data,null,box,box.cell,SkillRules.attack_value(unit,data),"physical");return
	if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,offsets):AttackTimeline.generic_projectile(state,unit,data,null,null,state.ball.cell,SkillRules.attack_value(unit,data),"physical")

static func hit(state: MatchState,unit: UnitState,data: OperatorData,target: UnitState,attack: int,ordinary: bool) -> void:
	var skill:=data.skills[unit.skill_index]
	var pending:=AttackTimeline.generic_projectile(state,unit,data,target,null,target.cell,attack,"physical")
	if unit.silence_ticks_left==0:pending.defense_remaining_percent=100-unit.penetration_stacks*int(data.talent_1.effect_params.penetration_per_stack)
	if SkillRules.active_ticks(unit)!=0:
		pending.first_hit_bonus_percent=int(data.talent_2.effect_params.attack_percent)
		pending.first_hit_slow_ticks=int(data.talent_2.effect_params.slow_ticks)
	if not ordinary:pending.stun_ticks=12
	elif SkillRules.active_ticks(unit)!=0 and skill.effect_type=="dual_arrow_repeat" and state.rng.next_percent()<int(skill.effect_params.stun_chance_percent):pending.stun_ticks=int(skill.effect_params.stun_ticks)
