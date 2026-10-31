class_name FlameRules
extends RefCounted

static func advance(state: MatchState,unit: UnitState,data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	unit.talent_sp_ticks+=1
	if unit.talent_sp_ticks>=int(data.talent_2.effect_params["interval_ticks"]):
		unit.talent_sp_ticks=0
		if unit.skill_ticks_left==0 and unit.silence_ticks_left==0:unit.sp=mini(SkillRules.sp_limit(skill),unit.sp+int(data.talent_2.effect_params["sp_add"]))
	if unit.skill_ticks_left>0 and skill.effect_type=="flame_ground" and unit.silence_ticks_left==0:
		if (unit.skill_elapsed_ticks+1)%int(skill.effect_params["pulse_ticks"])==0 and unit.silence_ticks_left==0:
			state._apply_skill_life_loss(unit,data,roundi(SkillRules.max_health_value(unit,data)*int(skill.effect_params["hp_loss_percent"])/100.0))
			if unit.hp>0 and unit.stun_ticks_left==0 and unit.displacement_ticks_left==0:attack(state,unit,data,true)
		return
	if not AttackTimeline.advance(state,unit):return
	attack(state,unit,data,false)

static func attack(state: MatchState,unit: UnitState,data: OperatorData,ground: bool) -> void:
	var enemies: Array[UnitState]=[]
	var primary: UnitState
	for target in state.units:
		if target.hp>0 and StainlessRules.is_damage_target(unit,target) and target.operator_id not in ["weedy_cannon","seaborn"] and state._is_in_attack_range(unit,target.cell,data.attack_range):
			enemies.append(target)
			if (ground or state.enemy_is_targetable(unit.side,target)) and (primary==null or SkillRules.taunt_level(target,state._operator_data[target.operator_id])>SkillRules.taunt_level(primary,state._operator_data[primary.operator_id])):primary=target
	var box_target: TacticalBox
	if primary==null:
		for box in state.tactical_boxes:
			if state._is_in_attack_range(unit,box.cell,data.attack_range):box_target=box;break
	var ball_target := primary==null and box_target==null and state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,data.attack_range)
	if primary==null and box_target==null and not ball_target:return
	if not ground:
		var found: Dictionary={"kind":0,"unit":primary,"cell":primary.cell} if primary!=null else ({"kind":1,"box":box_target,"cell":box_target.cell} if box_target!=null else {"kind":2,"cell":state.ball.cell})
		found=AttackTimeline.pin_found(state,unit,found)
		if found.is_empty():return
		primary=found.unit if found.kind==0 else null
		box_target=found.box if found.kind==1 else null
		ball_target=found.kind==2
		if not AttackTimeline.windup_found(state,unit,data,found):return
	var skill := data.skills[unit.skill_index]
	var charged := not ground and skill.effect_type=="flame_charge" and SkillRules.can_activate(unit,skill)
	if charged:SkillRules.activate(unit,data)
	var attack_value := SkillRules.attack_value(unit,data)
	if not ground:unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	unit.last_attack_tick=state.tick;unit.last_attack_is_heal=false
	var center := primary.cell if primary!=null else (box_target.cell if box_target!=null else state.ball.cell)
	unit.last_attack_target_x=center.x;unit.last_attack_target_y=center.y
	for target in enemies:
		var target_data: OperatorData=state._operator_data[target.operator_id]
		if ground:
			target.flame_resist_reduce=int(skill.effect_params["resist_reduce"])
			target.flame_resist_ticks=int(skill.effect_params["resist_ticks"])
		var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"magical",SkillRules.dodge_chance(target,target_data,"magical"),state.rng,data.profession_id,state._damage_taken_percent(target, "magical"), state._magical_damage_taken_percent(target))
		if state._apply_damage(target,target_data,damage,"magical",unit) and charged and target.hp>0:
			target.burn_until_tick=state.tick+int(skill.effect_params["burn_ticks"])
			target.burn_next_tick=state.tick+state.CONFIG.TICK_RATE
			target.burn_source_id=unit.unit_id
			target.burn_attack=roundi(data.attack*(100+unit.attack_bonus_percent)/100.0)
			target.burn_attack_percent=int(skill.effect_params["burn_attack_percent"])
			target.burn_defense_reduce=int(skill.effect_params["defense_reduce"])
	if box_target!=null:TacticalRules.strike_box(state,unit,box_target)
	elif ball_target:state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
	if charged:unit.skill_ticks_left=0

static func advance_burns(state: MatchState) -> void:
	for target in state.units:
		if target.hp<=0 or target.burn_until_tick==0:continue
		if state.tick<=target.burn_until_tick and state.tick>=target.burn_next_tick:
			var attack_value := target.burn_attack
			for source in state.units:
				if source.unit_id==target.burn_source_id and source.hp>0:
					var source_data: OperatorData=state._operator_data[source.operator_id]
					attack_value=roundi(source_data.attack*(100+source.attack_bonus_percent)/100.0)
					target.burn_attack=attack_value
					break
			var target_data: OperatorData=state._operator_data[target.operator_id]
			var damage := Combat.calculate_damage(roundi(attack_value*target.burn_attack_percent/100.0),SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"magical",0,state.rng,"caster",state._damage_taken_percent(target, "magical"), state._magical_damage_taken_percent(target))
			state._apply_damage(target,target_data,damage,"magical")
			target.burn_next_tick+=state.CONFIG.TICK_RATE
		if state.tick>=target.burn_until_tick:
			target.burn_until_tick=0;target.burn_next_tick=0;target.burn_source_id=-1
			target.burn_defense_reduce=0;target.burn_attack=0;target.burn_attack_percent=0
