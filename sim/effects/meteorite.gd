class_name MeteoriteRules
extends RefCounted


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var found := SwordRules.target(state,unit,data.attack_range,false)
	if found.is_empty():return
	var skill := data.skills[unit.skill_index]
	SkillRules.activate(unit,data)
	unit.skill_ticks_left=0
	resolve(state,unit,data,found,float(skill.effect_params["attack_mult"]),int(skill.effect_params["splash_radius_squared"]),true)


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.last_attack_tick==state.tick or unit.critical_ticks_left>0:return
	if not AttackTimeline.advance(state,unit):return
	var found := SwordRules.target(state,unit,data.attack_range,false)
	found=AttackTimeline.pin_found(state,unit,found)
	if found.is_empty():return
	if not AttackTimeline.windup_found(state,unit,data,found):return
	var skill := data.skills[unit.skill_index]
	var charged := skill.effect_type=="splash_shell" and SkillRules.can_activate(unit,skill)
	if charged:SkillRules.activate(unit,data)
	var multiplier := float(skill.effect_params["attack_mult"]) if charged else 1.0
	var radius := int(skill.effect_params["splash_radius_squared"]) if charged else int(data.branch_trait.effect_params["splash_radius_squared"])
	resolve(state,unit,data,found,multiplier,radius,false)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	if charged:unit.skill_ticks_left=0
	elif unit.skill_ticks_left==0 and skill.sp_recharge_type=="on_hit":unit.sp=mini(SkillRules.sp_limit(skill),unit.sp+1)


static func resolve(state: MatchState, unit: UnitState, data: OperatorData, found: Dictionary, multiplier: float, radius: int, debuff: bool) -> void:
	PusherRules.mark_attack(state,unit,found.cell)
	var victims: Array[UnitState]=[]
	for target in state.units:
		if target.hp>0 and StainlessRules.is_damage_target(unit,target) and target.sleep_ticks_left==0 and (target.cell-found.cell).length_squared()<=radius:victims.append(target)
	var ball_hit: bool= state.ball.move_ticks_left==0 and (state.ball.cell-found.cell).length_squared()<=radius
	var bonus := unit.attack_bonus_percent
	if (not victims.is_empty() or ball_hit) and unit.silence_ticks_left==0 and state.rng.next_percent()<int(data.talent_1.effect_params["chance_percent"]):bonus+=int(data.talent_1.effect_params["attack_bonus_percent"])
	var base := roundi(data.attack*(100+bonus)/100.0)+unit.inspire_attack_add
	var attack_value := roundi(base*multiplier)
	var skill := data.skills[unit.skill_index]
	if not debuff:
		AttackTimeline.area_projectile(state,unit,data,found.cell,attack_value,"physical",radius)
		return
	for target in victims:
		if unit.hp<=0:break
		var target_data: OperatorData=state._operator_data[target.operator_id]
		var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target,"physical"))
		if state._apply_damage(target,target_data,damage,"physical",unit) and target.hp>0 and debuff:
			target.shell_defense_reduce=int(skill.effect_params["defense_reduce"])
			target.shell_ticks_left=int(skill.effect_params["debuff_ticks"])
	if unit.hp<=0:return
	for box in state.tactical_boxes.duplicate():
		if box.hits_left>0 and (box.cell-found.cell).length_squared()<=radius:TacticalRules.strike_box(state,unit,box)
	if ball_hit:state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
