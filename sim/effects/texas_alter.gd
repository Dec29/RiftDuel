class_name TexasAlterRules
extends RefCounted


static func deployed(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	SkillRules.activate(unit,data)
	unit.texas_started_tick=state.tick;unit.texas_burst_pending=true
	unit.texas_rain_next_tick=state.tick+int(data.skills[unit.skill_index].effect_params["first_rain_ticks"]) if unit.skill_index==2 else -1
	unit.texas_rain_emissions=0


static func reward_kill(state: MatchState, unit: UnitState, target: UnitState) -> void:
	if unit not in state.units or unit.side==target.side or unit.texas_first_kill_used:return
	var data: OperatorData=state._operator_data[unit.operator_id]
	if data.talent_1.effect_type!="texas_tradition":return
	var previous := SkillRules.attack_interval_ticks(unit,data)
	unit.texas_first_kill_used=true;unit.texas_recast_pending=true
	unit.attack_ticks_left=ceili(float(unit.attack_ticks_left)*SkillRules.attack_interval_ticks(unit,data)/previous)


static func resolve_recasts(state: MatchState) -> void:
	for unit in state.units:
		if not unit.texas_recast_pending or unit.frozen_ticks_left>0 or unit.hp<=0 or unit.silence_ticks_left>0 or unit.sleep_ticks_left>0 or unit.stun_ticks_left>0 or unit.displacement_ticks_left>0:continue
		unit.texas_recast_pending=false
		var data: OperatorData=state._operator_data[unit.operator_id]
		unit.hp=SkillRules.max_health_value(unit,data);unit.last_heal_tick=state.tick
		deployed(state,unit,data)
		burst(state,unit,data)


static func advance(state: MatchState) -> void:
	for unit in state.units:
		var data: OperatorData=state._operator_data[unit.operator_id]
		if unit.hp<=0 or data.talent_1.effect_type!="texas_tradition":continue
		if unit.texas_burst_pending and unit.silence_ticks_left==0:burst(state,unit,data)
	resolve_recasts(state)
	for unit in state.units:
		var data: OperatorData=state._operator_data[unit.operator_id]
		var skill := data.skills[unit.skill_index]
		if unit.hp<=0 or SkillRules.active_ticks(unit)<=0 or skill.effect_type!="texas_alter_rain" or state.tick<unit.texas_rain_next_tick:continue
		var targets := PusherRules.targets(state,unit,skill.burst_range_override,false)
		var delay := 0 if unit.texas_rain_emissions==0 else state.rng.next_u32()%(int(skill.effect_params["rain_delay_max_ticks"])+1)
		unit.texas_rain_emissions+=1;unit.texas_rain_next_tick+=int(skill.effect_params["rain_interval_ticks"])
		var rain := TexasRain.new()
		rain.source_id=unit.unit_id;rain.side=unit.side;rain.source_cell=unit.cell;rain.facing=unit.facing
		rain.attack=roundi(SkillRules.attack_value(unit,data)*float(skill.effect_params["rain_attack_mult"]));rain.stun_ticks=int(skill.effect_params["rain_stun_ticks"]);rain.due_tick=state.tick+delay
		for enemy in targets.slice(0,int(skill.effect_params["target_count"])):rain.target_ids.append(enemy.unit_id)
		var remaining := int(skill.effect_params["target_count"])-rain.target_ids.size()
		for box in state.tactical_boxes:
			if remaining>0 and box.hits_left>0 and state._is_in_attack_range(unit,box.cell,skill.burst_range_override):rain.box_ids.append(box.box_id);remaining-=1
		if remaining>0 and state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,skill.burst_range_override):rain.ball_cell=state.ball.cell;rain.goal_generation=state.goals[0]+state.goals[1]
		if not rain.target_ids.is_empty() or not rain.box_ids.is_empty() or rain.ball_cell.x>=0:state.texas_rains.append(rain)
	var alive: Array[TexasRain]=[]
	for rain in state.texas_rains:
		if rain.due_tick>state.tick:alive.append(rain);continue
		var source := WArtilleryRules.owner(state,rain.source_id)
		if source==null:source=UnitState.new(rain.source_id,rain.side,"texas_alter",rain.source_cell,1,0,0,rain.facing,2)
		var data: OperatorData=state._operator_data["texas_alter"]
		for id in rain.target_ids:
			var target := WArtilleryRules.owner(state,id)
			if target!=null and state.enemy_is_targetable(rain.side,target) and hit(state,source,data,target,rain.attack,"magical") and target.hp>0:SwordRules.stun(state,target,rain.stun_ticks,source)
		for id in rain.box_ids:
			for box in state.tactical_boxes:
				if box.box_id==id and box.hits_left>0:TacticalRules.strike_box(state,source,box);break
		if rain.ball_cell.x>=0 and state.ball.cell==rain.ball_cell and state.ball.move_ticks_left==0 and state.goals[0]+state.goals[1]==rain.goal_generation:state.ball.add_push(rain.source_cell,rain.attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,rain.facing))
	state.texas_rains=alive
	for target in state.units.duplicate():
		if target.hp<=0 or target.texas_dot_until_tick<=0:continue
		if state.tick>=target.texas_dot_next_tick and state.tick<=target.texas_dot_until_tick:
			var target_data: OperatorData=state._operator_data[target.operator_id]
			var source := WArtilleryRules.owner(state,target.texas_dot_source_id)
			var damage := Combat.calculate_damage(int(state._operator_data["texas_alter"].skills[0].effect_params["dot_damage"]),0,SkillRules.magic_resist_value(target,target_data),"magical",0,state.rng,"specialist",state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
			state._apply_damage(target,target_data,damage,"magical",source,false)
			target.texas_dot_next_tick+=int(state._operator_data["texas_alter"].skills[0].effect_params["dot_interval_ticks"])
		if state.tick>=target.texas_dot_until_tick:target.texas_dot_until_tick=0;target.texas_dot_next_tick=0;target.texas_dot_source_id=-1


static func burst(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	unit.texas_burst_pending=false
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="texas_silence":return
	var targets := PusherRules.targets(state,unit,skill.burst_range_override,false)
	var attack_value := roundi(SkillRules.attack_value(unit,data)*float(skill.effect_params["burst_attack_mult"]))
	for enemy in targets:
		if unit.hp<=0:break
		var landed := false
		for index in (2 if skill.effect_type=="texas_alter_rain" else 1):
			if enemy.hp>0 and unit.hp>0:landed=hit(state,unit,data,enemy,attack_value,"magical") or landed
		if not landed or enemy.hp<=0:continue
		if skill.effect_type=="texas_arts":enemy.texas_resist_remaining_percent=int(skill.effect_params["resist_remaining_percent"]);enemy.texas_resist_until_tick=state.tick+int(skill.effect_params["resist_duration_ticks"])
		else:SwordRules.stun(state,enemy,int(skill.effect_params["burst_stun_ticks"]),unit)
	if unit.hp<=0:return
	for box in state.tactical_boxes:
		if box.hits_left>0 and state._is_in_attack_range(unit,box.cell,skill.burst_range_override):
			for index in (2 if skill.effect_type=="texas_alter_rain" else 1):
				if box.hits_left>0:TacticalRules.strike_box(state,unit,box)
	if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,skill.burst_range_override):
		for index in (2 if skill.effect_type=="texas_alter_rain" else 1):
			if state.ball.move_ticks_left==0:state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))



static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,unit):return
	var targets := PusherRules.targets(state,unit,data.attack_range,false,true)
	# Executor branch includes its own approved blocking relation before ordinary range targets.
	targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
		var at := SkillRules.taunt_level(a,state._operator_data[a.operator_id]);var bt := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
		if at!=bt:return at>bt
		var aa := state.enemy_is_blocked(a,unit.unit_id);var bb := state.enemy_is_blocked(b,unit.unit_id)
		return aa if aa!=bb else a.unit_id<b.unit_id)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,data.attack_range)
	if center.x<0:return
	var native_action:=unit.attack_intent
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	var skill := data.skills[unit.skill_index]
	var active := SkillRules.active_ticks(unit)>0
	var arts := active and skill.effect_type=="texas_arts"
	var stages:=AttackTimeline.release_indices(unit,native_action,2 if arts else 1)
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var attack_value := SkillRules.attack_value(unit,data)
	if not targets.is_empty():
		var target := targets[0]
		for index in stages:
			if unit.hp<=0 or target.hp<=0:break
			var landed := hit(state,unit,data,target,attack_value,"magical" if arts else "physical")
			if landed and target.hp>0 and active and skill.effect_type=="texas_silence":
				StatusRules.apply_silence(state,target,int(skill.effect_params["silence_ticks"]))
				if target.texas_dot_until_tick<=state.tick:target.texas_dot_next_tick=state.tick+int(skill.effect_params["dot_interval_ticks"])
				target.texas_dot_until_tick=state.tick+int(skill.effect_params["dot_duration_ticks"]);target.texas_dot_source_id=unit.unit_id
	else:
		for box in state.tactical_boxes:
			if box.hits_left>0 and box.cell==center:
				for index in stages:
					if box.hits_left>0:TacticalRules.strike_box(state,unit,box)
				return
		for index in stages:
			if state.ball.move_ticks_left==0:state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))


static func hit(state: MatchState, source: UnitState, data: OperatorData, target: UnitState, amount: int, kind: String) -> bool:
	var target_data: OperatorData=state._operator_data[target.operator_id]
	var damage := Combat.calculate_damage(amount,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),kind,SkillRules.dodge_chance(target,target_data,kind),state.rng,data.profession_id,state._damage_taken_percent(target,kind),state._magical_damage_taken_percent(target))
	return state._apply_damage(target,target_data,damage,kind,source)
