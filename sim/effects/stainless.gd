class_name StainlessRules
extends RefCounted

const IDS := ["stainless_device_atk","stainless_device_sp","stainless_cannon"]


static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id=="stainless":return unit
	return null


static func owner_for(state: MatchState, token: UnitState) -> UnitState:
	var source := owner(state,token.side)
	return source if source!=null and source.unit_id==token.stainless_owner_id else null


static func available(state: MatchState, side: int, id: String) -> bool:
	var source := owner(state,side)
	if source==null or source.silence_ticks_left>0 or IDS[source.skill_index]!=id or state.sides[side].stainless_stock<=0:return false
	var count := 0
	for unit in state.units:
		if unit.hp>0 and unit.stainless_owner_id==source.unit_id:count+=1
	return count<int(state._operator_data.stainless.talent_1.effect_params.max_count)


static func deployed(state: MatchState, token: UnitState) -> void:
	var source := owner(state,token.side)
	token.stainless_owner_id=source.unit_id
	state.sides[token.side].stainless_stock-=1
	state.sides[token.side].cooldowns[token.operator_id]=roundi(state._operator_data[token.operator_id].redeploy_time*state.CONFIG.TICK_RATE)


static func gain_stock(state: MatchState, source: UnitState) -> void:
	state.sides[source.side].stainless_stock=mini(int(state._operator_data.stainless.talent_1.effect_params.stock_count),state.sides[source.side].stainless_stock+1)


static func recycle(state: MatchState, token: UnitState) -> void:
	var source := owner_for(state,token)
	if source==null or source.silence_ticks_left>0:return
	var delta := token.cell-source.cell
	if delta==Vector2i.ZERO or absi(delta.x)>1 or absi(delta.y)>1:return
	if state.rng.next_u32()%100<int(state._operator_data.stainless.talent_2.effect_params.chance_percent):gain_stock(state,source)


static func remove_owned(state: MatchState, source: UnitState) -> void:
	for token in state.units.duplicate():
		if token.stainless_owner_id==source.unit_id:state.units.erase(token)


static func target_ally(state: MatchState, token: UnitState, data: OperatorData) -> UnitState:
	for ally in state.units:
		if ally.hp>0 and ally.side==token.side and state._operator_data[ally.operator_id].profession_id!="summon" and state._is_in_attack_range(token,ally.cell,data.attack_range):return ally
	return null


static func refresh(state: MatchState) -> void:
	for token in state.units:
		if token.hp<=0 or token.operator_id!="stainless_device_atk":continue
		var source := owner_for(state,token)
		if source==null:continue
		var data: OperatorData=state._operator_data[token.operator_id]
		var ally := target_ally(state,token,data)
		if ally==null:continue
		var scale := int(state._operator_data.stainless.skills[0].effect_params.device_scale) if SkillRules.active_ticks(source)>0 else 1
		ally.attack_bonus_percent+=int(data.branch_trait.effect_params.attack_percent)*scale


# Called before skill expiration; marks destruction without mutating the iterated array.
static func finish_skills(state: MatchState) -> void:
	for source in state.units:
		if source.hp<=0 or source.operator_id!="stainless" or source.skill_ticks_left!=1:continue
		if source.skill_index==1:gain_stock(state,source)
		elif source.skill_index==0:
			for token in state.units:
				if token.stainless_owner_id==source.unit_id and token.operator_id==IDS[0]:token.hp=0


static func maintain(state: MatchState, advance: bool = true) -> void:
	for token in state.units.duplicate():
		if token.operator_id not in IDS:continue
		var source := owner_for(state,token)
		if source==null:state.units.erase(token);continue
		if not advance or token.hp<=0 or token.operator_id!=IDS[1]:continue
		var params: Dictionary=state._operator_data[token.operator_id].branch_trait.effect_params
		var active := SkillRules.active_ticks(source)>0
		# Keep fractional HP and SP timing as integers across activation boundaries.
		token.stainless_loss_accum+=int(params.loss_basis_points)*(2 if active else 1)*state._operator_data[token.operator_id].max_health
		var divisor := 10000*state.CONFIG.TICK_RATE
		token.hp-=token.stainless_loss_accum/divisor;token.stainless_loss_accum%=divisor
		var ally := target_ally(state,token,state._operator_data[token.operator_id])
		if ally==null:continue
		token.stainless_sp_ticks+=1
		var interval := int(params.active_interval_ticks if active else params.interval_ticks)
		if token.stainless_sp_ticks>=interval:
			token.stainless_sp_ticks=0
			var skill: SkillResource=state._operator_data[ally.operator_id].skills[ally.skill_index]
			if SkillRules.can_gain_sp(ally) and ally.skill_ticks_left==0 and skill.sp_recharge_type!="passive":ally.sp=mini(SkillRules.sp_limit(skill),ally.sp+1)


static func cast(state: MatchState, source: UnitState, data: OperatorData) -> void:
	SkillRules.activate(source,data)
	if source.skill_index!=1:gain_stock(state,source)


static func is_damage_target(source: UnitState, target: UnitState) -> bool:
	if target.operator_id in IDS:return target.operator_id==IDS[2] and target.side==source.side and source!=target
	return target.side!=source.side


static func receive_hit(state: MatchState, target: UnitState, source: UnitState, damage: int) -> bool:
	if target.hp<=0 or target.operator_id!=IDS[2] or source==null or source.side!=target.side or source==target or damage<=0:return false
	var params: Dictionary=state._operator_data[target.operator_id].branch_trait.effect_params
	target.sp=mini(int(params.charge_sp),target.sp+1)
	var source_data: OperatorData=state._operator_data[source.operator_id]
	if source_data.profession_id=="supporter" and source_data.branch_trait.effect_type=="artisan":
		var token_data: OperatorData=state._operator_data[target.operator_id]
		var heal := Combat.calculate_healing(roundi(token_data.max_health*int(params.heal_percent)/100.0))
		target.hp=mini(token_data.max_health,target.hp+heal);target.last_heal_tick=state.tick
	return true


static func physical_remaining(state: MatchState, target: UnitState) -> float:
	var remaining := 1.0
	for token in state.units:
		if token.hp<=0 or token.side!=target.side or token.operator_id!=IDS[2] or owner_for(state,token)==null:continue
		if target.cell==token.cell or target.cell==token.cell+AttackRange.rotate_offset(Vector2i.LEFT,token.facing):remaining*=1.0-int(state._operator_data[token.operator_id].branch_trait.effect_params.physical_reduction_percent)/100.0
	return remaining


static func attack(state: MatchState, source: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,source):return
	var found := SwordRules.target(state,source,data.attack_range,false)
	if source.skill_index==1 and SkillRules.active_ticks(source)>0:
		for target in state.units:
			if state.enemy_is_targetable(source.side,target,source) and state.enemy_is_blocked(target,source.unit_id):
				found={"kind":0,"unit":target,"cell":target.cell};break
	found=AttackTimeline.pin_found(state,source,found)
	if found.is_empty():return
	if not AttackTimeline.windup_found(state,source,data,found):return
	PusherRules.mark_attack(state,source,found.cell);source.attack_ticks_left=SkillRules.attack_interval_ticks(source,data)
	var power := SkillRules.attack_value(source,data)
	if found.kind==0:
		var targets: Array[UnitState]=[found.unit]
		if source.skill_index==1 and SkillRules.active_ticks(source)>0:
			targets.clear()
			for target in state.units:
				if state.enemy_is_targetable(source.side,target,source) and state.enemy_is_blocked(target,source.unit_id):targets.append(target)
			# Without a blocked enemy the artisan can still service its cannon.
			if targets.is_empty() and found.unit.operator_id==IDS[2]:targets.append(found.unit)
		for target in targets:
			var target_data: OperatorData=state._operator_data[target.operator_id]
			var damage := Combat.calculate_damage(power,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target,"physical"))
			state._apply_damage(target,target_data,damage,"physical",source)
	elif found.kind==1:TacticalRules.strike_box(state,source,found.box)
	elif state.ball.move_ticks_left==0:state.ball.add_push(source.cell,power,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,source.facing))


static func cannon_attack(state: MatchState, token: UnitState, data: OperatorData) -> void:
	var source := owner_for(state,token)
	var params := data.branch_trait.effect_params
	if source==null or token.sp<int(params.charge_sp):return
	if not AttackTimeline.advance(state,token):return
	var targets: Array[UnitState]=[]
	for enemy in state.units:
		if enemy.operator_id not in IDS and state.enemy_is_targetable(token.side,enemy,token) and state._is_in_attack_range(token,enemy.cell,data.attack_range):targets.append(enemy)
	targets=AttackTimeline.pinned(state,token,targets)
	var box: TacticalBox
	if targets.is_empty():
		for candidate in state.tactical_boxes:
			if state._is_in_attack_range(token,candidate.cell,data.attack_range):box=candidate;break
	var ball := targets.is_empty() and box==null and state.ball.move_ticks_left==0 and state._is_in_attack_range(token,state.ball.cell,data.attack_range)
	if targets.is_empty() and box==null and not ball:return
	if not AttackTimeline.windup(state,token,data,targets,targets[0].cell if not targets.is_empty() else (box.cell if box!=null else state.ball.cell)):return
	token.sp-=int(params.charge_sp)
	token.hp-=ceili(data.max_health*int(params.loss_basis_points)/10000.0)
	var center := targets[0].cell if not targets.is_empty() else (box.cell if box!=null else state.ball.cell)
	PusherRules.mark_attack(state,token,center)
	var power := SkillRules.attack_value(source,state._operator_data.stainless)
	var primary: UnitState=targets[0] if not targets.is_empty() else null
	var shot:=AttackTimeline.generic_projectile(state,token,data,primary,box,center,roundi(power*int(params.splash_percent)/100.0),"physical")
	shot.primary_attack=roundi(power*int(params.primary_percent)/100.0)
	shot.splash_radius_squared=int(params.splash_radius_squared);shot.splash_affects_objects=false
	if primary==null:AttackTimeline.generic_projectile(state,token,data,null,box,center,shot.primary_attack,"physical")
