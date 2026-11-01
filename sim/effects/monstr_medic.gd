class_name MonstrMedicRules
extends RefCounted

const ID := "mon3tr_operator"
const TOKEN_ID := "mon3tr_reconstruction"

static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id==ID:return unit
	return null

static func controller(state: MatchState, token: UnitState) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.unit_id==token.reconstruct_owner_id and unit.operator_id==ID:return unit
	return null

static func token_for(state: MatchState, source: UnitState) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.operator_id==TOKEN_ID and unit.reconstruct_owner_id==source.unit_id:return unit
	return null

static func transformed(unit: UnitState) -> bool:
	return unit.operator_id==ID and unit.monstr_origin_cell.x>=0

static func clamp_life_loss(unit: UnitState, loss: int) -> int:
	if unit.hp>0 and (transformed(unit) or unit.monstr_return_guard_ticks>0):return mini(loss,maxi(0,unit.hp-1))
	return loss

static func reserves_cell(state: MatchState, cell: Vector2i) -> bool:
	for unit in state.units:
		if unit.hp>0 and transformed(unit) and unit.monstr_origin_cell==cell:return true
	return false

static func available(state: MatchState, side: int) -> bool:
	var source := owner(state,side)
	return source!=null and source.silence_ticks_left==0 and token_for(state,source)==null and state.sides[side].cooldowns.get(TOKEN_ID,0)==0

static func can_place(state: MatchState, side: int, cell: Vector2i) -> bool:
	var source := owner(state,side)
	return available(state,side) and state._is_in_attack_range(source,cell,AttackRange.effective_offsets(source,state._operator_data[ID]))

static func deployed(state: MatchState, unit: UnitState) -> void:
	if unit.operator_id==TOKEN_ID:
		unit.reconstruct_owner_id=owner(state,unit.side).unit_id

static func exit_token(state: MatchState, token: UnitState) -> void:
	state.units.erase(token)
	state.sides[token.side].cooldowns[TOKEN_ID]=roundi((state._operator_data[TOKEN_ID] as OperatorData).redeploy_time*state.CONFIG.TICK_RATE)

static func remove_owned(state: MatchState, source: UnitState) -> void:
	for token in state.units.duplicate():
		if token.operator_id==TOKEN_ID and token.reconstruct_owner_id==source.unit_id:exit_token(state,token)

static func can_receive(state: MatchState, source: UnitState, target: UnitState) -> bool:
	if target.hp<=0 or target.side!=source.side:return false
	if target.operator_id==TOKEN_ID:return target.reconstruct_owner_id==source.unit_id and target.critical_ticks_left==0
	return LumenRules.can_heal(state,target)

static func by_health(state: MatchState, a: UnitState, b: UnitState) -> bool:
	var am := SkillRules.max_health_value(a,state._operator_data[a.operator_id])
	var bm := SkillRules.max_health_value(b,state._operator_data[b.operator_id])
	return a.unit_id<b.unit_id if a.hp*bm==b.hp*am else a.hp*bm<b.hp*am

static func synergy(state: MatchState, source: UnitState, target: UnitState, strength: int) -> void:
	if source.silence_ticks_left>0:return
	var params: Dictionary=state._operator_data[ID].talent_2.effect_params
	for ally in [source,target]:
		if strength>int(params["attack_speed_add"]):
			ally.monstr_overload_speed=strength
			ally.monstr_overload_until_tick=state.tick+int(params["duration_ticks"])
		else:
			ally.monstr_synergy_speed=strength
			ally.monstr_synergy_until_tick=state.tick+int(params["duration_ticks"])

static func heal_event(state: MatchState, source: UnitState, target: UnitState, amount: int, strength: int) -> void:
	if not can_receive(state,source,target):return
	var td: OperatorData=state._operator_data[target.operator_id]
	var old_hp := target.hp
	target.hp=mini(SkillRules.max_health_value(target,td),target.hp+SkillRules.healing_received(target,td,amount,source))
	if target.hp>old_hp:target.last_heal_tick=state.tick
	synergy(state,source,target,strength)

static func heal_chain(state: MatchState, source: UnitState, first: UnitState, amount: int, count: int, strength: int, echo_allowed: bool=false) -> void:
	var data: OperatorData=state._operator_data[ID]
	var initial_amount := amount
	var visited: Array[int]=[]
	var target := first
	var remaining := count
	while target!=null and remaining>0:
		visited.append(target.unit_id)
		heal_event(state,source,target,amount,strength)
		remaining-=1
		var free_jump := (target.operator_id==TOKEN_ID or (target==source and transformed(source))) and source.silence_ticks_left==0
		if echo_allowed and target.operator_id==TOKEN_ID:
			source.monstr_echo_tick=state.tick+int(data.skills[source.skill_index].effect_params["echo_delay_ticks"])
			source.monstr_echo_target_id=target.unit_id;source.monstr_echo_amount=initial_amount;source.monstr_echo_synergy=strength
		if free_jump:remaining+=1
		if remaining<=0:break
		var choices: Array[UnitState]=[]
		for ally in state.units:
			if ally.unit_id not in visited and can_receive(state,source,ally) and (ally.cell-target.cell).length_squared()<=int(data.branch_trait.effect_params["jump_radius_squared"]):choices.append(ally)
		choices.sort_custom(func(a: UnitState,b: UnitState)->bool:return by_health(state,a,b))
		target=choices[0] if not choices.is_empty() else null
		if not free_jump:amount=roundi(amount*int(data.branch_trait.effect_params["jump_heal_percent"])/100.0)

static func cast(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var skill := data.skills[source.skill_index]
	if skill.effect_type=="monstr_meltdown" and token_for(state,source)==null:return
	var previous_health := SkillRules.max_health_value(source,data)
	SkillRules.activate(source,data)
	if skill.effect_type!="monstr_meltdown":return
	var token := token_for(state,source)
	source.monstr_origin_cell=source.cell
	source.cell=token.cell
	exit_token(state,token)
	source.hp=maxi(1,ceili(float(source.hp)*SkillRules.max_health_value(source,data)/previous_health))
	source.monstr_loss_accum=0
	AuraRules.refresh(state)

static func finish(state: MatchState, source: UnitState) -> void:
	if not transformed(source):return
	var data: OperatorData=state._operator_data[ID]
	var previous_health := SkillRules.max_health_value(source,data)
	source.cell=source.monstr_origin_cell
	source.monstr_origin_cell=Vector2i(-1,-1)
	source.skill_ticks_left=0
	source.hp=maxi(1,ceili(float(source.hp)*SkillRules.max_health_value(source,data)/previous_health))
	source.monstr_return_guard_ticks=state.CONFIG.TICK_RATE
	source.monstr_loss_accum=0
	var token := token_for(state,source)
	if token!=null and not state._is_in_attack_range(source,token.cell,data.attack_range):exit_token(state,token);token=null
	if token==null:state.sides[source.side].cooldowns[TOKEN_ID]=0
	AuraRules.refresh(state)

static func advance(state: MatchState) -> void:
	for source in state.units.duplicate():
		if source.hp<=0:continue
		if source.operator_id==TOKEN_ID:
			if controller(state,source)==null:exit_token(state,source);continue
			source.monstr_loss_accum+=1
			var loss: int=0
			if source.monstr_loss_accum>=3:
				loss=int((state._operator_data[TOKEN_ID] as OperatorData).branch_trait.effect_params["life_loss_per_second"])*3/state.CONFIG.TICK_RATE
				source.monstr_loss_accum-=3
			source.hp=maxi(0,source.hp-loss)
			if loss>0:source.last_damage_tick=state.tick
			continue
		if source.operator_id!=ID:continue
		if source.monstr_return_guard_ticks>0:source.monstr_return_guard_ticks-=1
		if transformed(source):
			if source.skill_ticks_left==0:finish(state,source)
			else:
				var params: Dictionary=state._operator_data[ID].skills[source.skill_index].effect_params
				source.monstr_loss_accum+=1
				var loss: int=0
				if source.monstr_loss_accum>=3:
					loss=int(params["life_loss_per_second"])*3/state.CONFIG.TICK_RATE
					source.monstr_loss_accum-=3
				if loss>=source.hp:source.hp=1;finish(state,source)
				else:source.hp-=loss
		if source.monstr_echo_tick>=0 and state.tick>=source.monstr_echo_tick:
			source.monstr_echo_tick=-1
			for target in state.units:
				if target.unit_id==source.monstr_echo_target_id and target.hp>0:
					heal_chain(state,source,target,source.monstr_echo_amount,3,source.monstr_echo_synergy)
					break

static func refresh(state: MatchState) -> void:
	for unit in state.units:
		if unit.hp<=0:continue
		var speed := unit.monstr_synergy_speed if state.tick<unit.monstr_synergy_until_tick else 0
		if state.tick<unit.monstr_overload_until_tick:speed=maxi(speed,unit.monstr_overload_speed)
		unit.attack_speed_bonus+=speed
		if unit.operator_id==ID:unit.monstr_token_ready=token_for(state,unit)!=null
		if unit.operator_id!=TOKEN_ID:continue
		var source := controller(state,unit)
		if source==null or source.silence_ticks_left>0:continue
		var params: Dictionary=state._operator_data[ID].talent_1.effect_params
		for ally in state.units:
			if ally.hp>0 and ally.side==unit.side and ally.operator_id!=TOKEN_ID and absi(ally.cell.x-unit.cell.x)<=1 and absi(ally.cell.y-unit.cell.y)<=1:ally.attack_bonus_percent+=int(params["attack_percent"])

static func attack(state: MatchState, source: UnitState, data: OperatorData) -> void:
	if source.operator_id==TOKEN_ID:return
	if not AttackTimeline.advance(state,source):return
	var skill := data.skills[source.skill_index]
	if transformed(source):
		var targets := PusherRules.targets(state,source,AttackRange.effective_offsets(source,data),false,true)
		targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
			var ab := state.enemy_is_blocked(a,source.unit_id);var bb := state.enemy_is_blocked(b,source.unit_id)
			if ab!=bb:return ab
			var at := SkillRules.taunt_level(a,state._operator_data[a.operator_id]);var bt := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
			return at>bt if at!=bt else a.unit_id<b.unit_id)
		targets=AttackTimeline.pinned(state,source,targets)
		var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,source,AttackRange.effective_offsets(source,data))
		if center.x<0:return
		if not AttackTimeline.windup(state,source,data,targets,center):return
		PusherRules.mark_attack(state,source,center);source.attack_ticks_left=SkillRules.attack_interval_ticks(source,data)
		var amount := SkillRules.attack_value(source,data)
		for target in targets.slice(0,SkillRules.block_count_value(source,data)):
			var td: OperatorData=state._operator_data[target.operator_id]
			var damage := Combat.calculate_damage(amount,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),"true",0,state.rng,data.profession_id,state._damage_taken_percent(target,"true"))
			state._apply_damage(target,td,damage,"true",source)
		if targets.is_empty():
			var box_found := false
			for box in state.tactical_boxes:
				if box.cell==center:TacticalRules.strike_box(state,source,box);box_found=true;break
			if not box_found:state.ball.add_push(source.cell,amount,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,source.facing))
		if SkillRules.active_ticks(source)>0:
			heal_chain(state,source,source,Combat.calculate_healing(amount,int(skill.effect_params["self_heal_percent"])),int(data.branch_trait.effect_params["target_count"]),int(data.talent_2.effect_params["attack_speed_add"]))
		return
	var choices: Array[UnitState]=[]
	var overload := SkillRules.active_ticks(source)>0 and skill.effect_type=="monstr_overload"
	for ally in state.units:
		if can_receive(state,source,ally) and state._is_in_attack_range(source,ally.cell,data.attack_range) and (ally.hp<SkillRules.max_health_value(ally,state._operator_data[ally.operator_id]) or (overload and ally.operator_id==TOKEN_ID)):choices.append(ally)
	choices.sort_custom(func(a: UnitState,b: UnitState)->bool:
		if overload and (a.operator_id==TOKEN_ID)!=(b.operator_id==TOKEN_ID):return a.operator_id==TOKEN_ID
		return by_health(state,a,b))
	choices=AttackTimeline.pinned(state,source,choices)
	if choices.is_empty():return
	if not AttackTimeline.windup(state,source,data,choices.slice(0,1),choices[0].cell,true):return
	var charged := skill.effect_type=="monstr_chain" and SkillRules.can_activate(source,skill)
	if charged:SkillRules.activate(source,data)
	var amount := Combat.calculate_healing(SkillRules.attack_value(source,data),int(skill.effect_params["heal_percent"]) if charged else 100)
	var strength := int(data.talent_2.effect_params["attack_speed_add"])
	if overload:strength=roundi(strength*int(skill.effect_params["talent_multiplier_percent"])/100.0)
	PusherRules.mark_attack(state,source,choices[0].cell);source.last_attack_is_heal=true
	source.attack_ticks_left=SkillRules.attack_interval_ticks(source,data)
	heal_chain(state,source,choices[0],amount,int(skill.effect_params["target_count"]) if charged else int(data.branch_trait.effect_params["target_count"]),strength,overload)
	if charged:source.skill_ticks_left=0
	if source.skill_ticks_left==0:source.sp=mini(SkillRules.sp_limit(skill),source.sp+1)
