class_name ArchettoRules
extends RefCounted


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type!="archetto_chase":SkillRules.activate(unit,data);return
	var found := SwordRules.target(state,unit,data.attack_range,false)
	if found.is_empty():return
	SkillRules.activate(unit,data)
	unit.skill_ticks_left=0
	var field := ArchettoVolley.new()
	field.source_id=unit.unit_id;field.side=unit.side;field.source_cell=unit.cell;field.facing=unit.facing
	field.cell=found.cell;field.attack=roundi(SkillRules.attack_value(unit,data)*float(skill.effect_params["attack_mult"]))
	field.start_tick=state.tick;field.next_tick=state.tick;field.goal_generation=state.goals[0]+state.goals[1]
	field.shots_left=int(skill.effect_params["shot_count"]);field.segment_shots=field.shots_left
	if found.kind==0:field.target_id=found.unit.unit_id;field.visited_ids.append(field.target_id)
	elif found.kind==1:field.target_kind=1;field.target_id=found.box.box_id
	else:field.target_kind=2
	state.archetto_volleys.append(field)
	PusherRules.mark_attack(state,unit,found.cell)


static func advance(state: MatchState) -> void:
	for source in state.units:
		if source.hp<=0 or source.silence_ticks_left>0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		if data.talent_1.effect_type!="sniper_offensive_sp":continue
		var interval := int(data.talent_1.effect_params["interval_ticks"])
		if state.tick<=source.deployed_tick or (state.tick-source.deployed_tick)%interval!=0:continue
		for ally in state.units:
			var ally_data: OperatorData=state._operator_data[ally.operator_id]
			if ally.side==source.side and ally_data.profession_id=="sniper" and ally_data.skills[ally.skill_index].sp_recharge_type=="on_hit":SagaRules.reward(state,ally,int(data.talent_1.effect_params["sp_add"]))
	var alive: Array[ArchettoVolley]=[]
	for field in state.archetto_volleys:
		if state.tick<field.next_tick:alive.append(field);continue
		var source := WArtilleryRules.owner(state,field.source_id)
		if source==null:source=UnitState.new(field.source_id,field.side,"archetto",field.source_cell,1,0,0,field.facing,1)
		var data: OperatorData=state._operator_data["archetto"]
		var params := data.skills[1].effect_params
		if field.target_kind==0:
			var target := WArtilleryRules.owner(state,field.target_id)
			if target!=null:
				field.cell=target.cell;hit(state,source,data,target,field.attack)
				field.shots_left-=1;field.total_shots+=1
			if target==null or target.hp<=0 or field.shots_left==0:
				field.segment_shots-=1
				var candidates: Array[UnitState]=[]
				for enemy in state.units:
					if state.enemy_is_targetable(field.side,enemy) and enemy.unit_id not in field.visited_ids and (enemy.cell-field.cell).length_squared()<=int(params["jump_radius_squared"]):candidates.append(enemy)
				candidates.sort_custom(func(a: UnitState,b: UnitState)->bool:
					var aa := (a.cell-field.cell).length_squared();var bb := (b.cell-field.cell).length_squared()
					return a.unit_id<b.unit_id if aa==bb else aa<bb)
				if field.segment_shots<=0 or candidates.is_empty():continue
				field.target_id=candidates[0].unit_id;field.visited_ids.append(field.target_id);field.shots_left=field.segment_shots
		elif field.target_kind==1:
			var box: TacticalBox
			for candidate in state.tactical_boxes:
				if candidate.box_id==field.target_id:box=candidate;break
			if box==null or box.hits_left<=0:continue
			TacticalRules.strike_box(state,source,box);field.shots_left-=1;field.total_shots+=1
			if box.hits_left<=0 or field.shots_left==0:continue
		else:
			if field.goal_generation!=state.goals[0]+state.goals[1] or state.ball.move_ticks_left>0 or state.ball.cell!=field.cell:continue
			state.ball.add_push(field.source_cell,field.attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,field.facing));field.shots_left-=1;field.total_shots+=1
			if field.shots_left==0:continue
		# Original 0.15s: 9/2 simulation ticks, rounded cumulatively rather than to a constant5tick interval.
		var denominator := int(params["pulse_denominator"])
		field.next_tick=field.start_tick+(field.total_shots*int(params["pulse_numerator"])+denominator/2)/denominator
		if field.next_tick<=state.tick:field.next_tick=state.tick+1
		alive.append(field)
	state.archetto_volleys=alive


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.last_attack_tick==state.tick or not AttackTimeline.advance(state,unit):return
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets := PusherRules.targets(state,unit,offsets,false)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,offsets)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	var skill := data.skills[unit.skill_index]
	var charged := skill.effect_type=="archetto_scatter" and SkillRules.can_activate(unit,skill)
	if charged:SkillRules.activate(unit,data)
	var storm := SkillRules.active_ticks(unit)>0 and skill.effect_type=="archetto_storm"
	var attack_value := SkillRules.attack_value(unit,data)
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	if not targets.is_empty():
		var count := mini(targets.size(),int(skill.effect_params["target_count"]) if storm else 1)
		for index in count:
			for shot in (int(skill.effect_params["shot_count"]) if storm else 1):
				if unit.hp<=0 or targets[index].hp<=0:break
				hit(state,unit,data,targets[index],attack_value)
		if charged:
			var extras: Array[UnitState]=[]
			for enemy in state.units:
				if enemy!=targets[0] and state.enemy_is_targetable(unit.side,enemy) and (enemy.cell-center).length_squared()<=int(skill.effect_params["jump_radius_squared"]):extras.append(enemy)
			extras.sort_custom(func(a: UnitState,b: UnitState)->bool:
				var aa := (a.cell-center).length_squared();var bb := (b.cell-center).length_squared()
				return a.unit_id<b.unit_id if aa==bb else aa<bb)
			for index in mini(extras.size(),int(skill.effect_params["extra_target_count"])):
				if unit.hp<=0:break
				hit(state,unit,data,extras[index],roundi(SkillRules.attack_value(unit,data,true)*float(skill.effect_params["secondary_mult"])))
	else:
		var box: TacticalBox
		for candidate in state.tactical_boxes:
			if candidate.hits_left>0 and candidate.cell==center:box=candidate;break
		for shot in (int(skill.effect_params["shot_count"]) if storm else 1):AttackTimeline.generic_projectile(state,unit,data,null,box,center,attack_value,"physical")
	if charged:unit.skill_ticks_left=0
	elif unit.skill_ticks_left==0:SagaRules.reward(state,unit,1)


static func hit(state: MatchState, source: UnitState, data: OperatorData, target: UnitState, attack_value: int) -> void:
	AttackTimeline.generic_projectile(state,source,data,target,null,target.cell,attack_value,"physical")
