class_name VanguardDefenderRules
extends RefCounted

const SIMPLE_IDS := ["wildmane","eunectes"]

static func deployed(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type in ["wildmane_deploy","eunectes_passive"]:
		unit.skill_ticks_left=roundi(skill.duration*state.CONFIG.TICK_RATE) if skill.duration>0 else -2
		unit.skill_activation_count+=1
	if data.talent_1.effect_type=="guard_deploy_discount":
		for id in state.squad_ids[unit.side]:
			if state._operator_data[id].profession_id!="guard":continue
			var present := false
			for ally in state.units:
				if ally.hp>0 and ally.side==unit.side and ally.operator_id==id:present=true;break
			if not present:state.sides[unit.side].wildmane_discounts[id]=mini(int(data.talent_1.effect_params["max_discount"]),int(state.sides[unit.side].wildmane_discounts.get(id,0))+int(data.talent_1.effect_params["discount_per_deploy"]))
	if data.profession_id=="guard":state.sides[unit.side].wildmane_discounts.erase(unit.operator_id)

static func blocking(state: MatchState, unit: UnitState) -> bool:
	for enemy in state.units:
		if enemy.hp>0 and enemy.side!=unit.side and state.enemy_is_blocked(enemy,unit.unit_id):return true
	return false

static func refresh(state: MatchState) -> void:
	for unit in state.units:
		if unit.operator_id=="eunectes":unit.eunectes_sp_enabled=blocking(state,unit)

static func advance(state: MatchState) -> void:
	for unit in state.units:
		if unit.hp<=0 or unit.operator_id!="eunectes":continue
		var data: OperatorData=state._operator_data[unit.operator_id]
		var skill := data.skills[unit.skill_index]
		if SkillRules.active_ticks(unit)<=0:continue
		if skill.effect_type=="eunectes_stun":
			for enemy in state.units:
				if enemy.hp>0 and enemy.side!=unit.side and state.enemy_is_blocked(enemy,unit.unit_id):StatusRules.add_control(state,enemy,"stun",2,unit)
		elif skill.effect_type=="eunectes_engine" and unit.critical_ticks_left==0:
			unit.eunectes_regen_accum+=SkillRules.max_health_value(unit,data)*int(skill.effect_params["regen_health_percent"])*state.CONFIG.UNIT_HEAL_PERCENT
			var divisor: int=state.CONFIG.TICK_RATE*10000
			var heal := unit.eunectes_regen_accum/divisor;unit.eunectes_regen_accum%=divisor
			if heal>0:unit.hp=mini(SkillRules.max_health_value(unit,data),unit.hp+heal);unit.last_heal_tick=state.tick

static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,unit):return
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets := PusherRules.targets(state,unit,offsets,false,true)
	targets.sort_custom(func(a:UnitState,b:UnitState)->bool:
		var at := SkillRules.taunt_level(a,state._operator_data[a.operator_id]);var bt := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
		if at!=bt:return at>bt
		var ab := state.enemy_is_blocked(a,unit.unit_id);var bb := state.enemy_is_blocked(b,unit.unit_id)
		return ab if ab!=bb else a.unit_id<b.unit_id)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,offsets)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var amount := SkillRules.attack_value(unit,data)
	var skill := data.skills[unit.skill_index]
	if not targets.is_empty():
		var target := targets[0];var td: OperatorData=state._operator_data[target.operator_id]
		var damage_percent := 100
		if data.talent_1.effect_type=="duelist_health" and unit.silence_ticks_left==0 and unit.hp*100>SkillRules.max_health_value(unit,data)*int(data.talent_1.effect_params["hp_threshold_percent"]):damage_percent=int(data.talent_1.effect_params["damage_percent"])
		var damage := Combat.calculate_damage(amount,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),"physical",SkillRules.dodge_chance(target,td,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target,"physical")*damage_percent/100.0)
		if state._apply_damage(target,td,damage,"physical",unit) and target.hp>0 and SkillRules.active_ticks(unit)>0 and skill.effect_type=="wildmane_charge":DisplacementRules.apply_unit(state,unit,target,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing),int(skill.effect_params["shift_force"]))
	else:
		var found := false
		for box in state.tactical_boxes:
			if box.cell==center and box.hits_left>0:TacticalRules.strike_box(state,unit,box);found=true;break
		if not found and state.ball.move_ticks_left==0:
			state.ball.add_push(unit.cell,amount,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
			if SkillRules.active_ticks(unit)>0 and skill.effect_type=="wildmane_charge":DisplacementRules.apply_ball(state,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing),int(skill.effect_params["shift_force"]))
