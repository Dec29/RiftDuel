class_name GoldenglowRules
extends RefCounted

const NO_TARGET := -2147483648


static func cast(state: MatchState, source: UnitState, data: OperatorData) -> void:
	SkillRules.activate(source,data)
	source.golden_target_ids=PackedInt32Array([NO_TARGET,NO_TARGET,NO_TARGET])
	source.golden_trait_hits=PackedInt32Array([0,0,0])
	source.golden_cooldowns=PackedInt32Array([0,0,0])


static func advance_released(state: MatchState) -> void:
	for source in state.units.duplicate():
		if source not in state.units or source.operator_id!="goldenglow" or source.hp<=0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		if SkillRules.active_ticks(source)==0:continue
		var count := int(data.skills[source.skill_index].effect_params["drone_count"])
		for index in count:
			if source.hp<=0:break
			source.golden_cooldowns[index]=maxi(0,source.golden_cooldowns[index]-1)
			if source.golden_cooldowns[index]>0:continue
			var target := locked_target(state,source,index)
			if target.is_empty():target=acquire(state,source,data)
			if target.is_empty():continue
			fire(state,source,data,index,target,true)
			source.golden_cooldowns[index]=SkillRules.attack_interval_ticks(source,data)


static func acquire(state: MatchState, source: UnitState, data: OperatorData) -> Dictionary:
	var global := data.skills[source.skill_index].effect_type=="goldenglow_global"
	if not global:return SwordRules.target(state,source,AttackRange.effective_offsets(source,data),false)
	var targets: Array[UnitState]=[]
	for enemy in state.units:
		if state.enemy_is_targetable(source.side,enemy,source):targets.append(enemy)
	targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
		var aa := SkillRules.taunt_level(a,state._operator_data[a.operator_id]);var bb := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
		return a.unit_id<b.unit_id if aa==bb else aa>bb)
	if not targets.is_empty():return {"kind":0,"unit":targets[0],"cell":targets[0].cell}
	# Objects retain local acquisition range; only enemy units use global acquisition.
	return SwordRules.target(state,source,data.attack_range,false)


static func locked_target(state: MatchState, source: UnitState, index: int) -> Dictionary:
	var id := source.golden_target_ids[index]
	if id==NO_TARGET:return {}
	if id>=0:
		for enemy in state.units:
			if enemy.unit_id==id and state.enemy_is_targetable(source.side,enemy,source):return {"kind":0,"unit":enemy,"cell":enemy.cell}
	elif id<=-2:
		for box in state.tactical_boxes:
			if box.box_id==-id-2 and box.hits_left>0:return {"kind":1,"box":box,"cell":box.cell}
	elif state.ball.move_ticks_left==0 and source.golden_goal_generation[index]==state.goals[0]+state.goals[1] and state.ball.cell==Vector2i(source.golden_target_x[index],source.golden_target_y[index]):return {"kind":2,"cell":state.ball.cell}
	return {}


static func fire(state: MatchState, source: UnitState, data: OperatorData, index: int, found: Dictionary, released: bool) -> void:
	var id: int=found.unit.unit_id if found.kind==0 else (-found.box.box_id-2 if found.kind==1 else -1)
	if source.golden_target_ids[index]!=id:source.golden_trait_hits[index]=0
	source.golden_target_ids[index]=id
	source.golden_target_x[index]=found.cell.x;source.golden_target_y[index]=found.cell.y
	source.golden_goal_generation[index]=state.goals[0]+state.goals[1]
	var power := SkillRules.attack_value(source,data)
	var explode := false
	if released and source.silence_ticks_left==0:
		var params := data.talent_1.effect_params
		explode=source.golden_explosion_stacks[index]>=int(params["max_stacks"]) or state.rng.next_u32()%10000<source.golden_explosion_stacks[index]*int(params["probability_step_basis_points"])
		source.golden_explosion_stacks[index]=1 if explode else source.golden_explosion_stacks[index]+1
	if explode:
		power=roundi(power*int(data.talent_1.effect_params["attack_percent"])/100.0)
		for enemy in state.units.duplicate():
			if enemy in state.units and enemy.hp>0 and StainlessRules.is_damage_target(source,enemy) and (enemy.cell-found.cell).length_squared()<=int(data.talent_1.effect_params["splash_radius_squared"]):hit(state,source,data,enemy,power,false)
		source.golden_target_ids[index]=NO_TARGET;source.golden_trait_hits[index]=0
	else:
		var branch_params := data.branch_trait.effect_params
		var ratio := mini(int(branch_params["max_attack_percent"]),int(branch_params["initial_attack_percent"])+source.golden_trait_hits[index]*int(branch_params["attack_step_percent"]))
		power=roundi(power*ratio/100.0)
		source.golden_trait_hits[index]+=1
		if found.kind==0:hit(state,source,data,found.unit,power,not released)
	if found.kind!=0 and not released:AttackTimeline.found_projectile(state,source,data,found,power,"magical")
	elif found.kind==1:TacticalRules.strike_box(state,source,found.box)
	elif found.kind==2 and state.ball.move_ticks_left==0:state.ball.add_push(source.cell,power,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,source.facing))
	PusherRules.mark_attack(state,source,found.cell)


static func hit(state: MatchState, source: UnitState, data: OperatorData, enemy: UnitState, power: int, attack_event: bool) -> void:
	if attack_event:
		var pending:=AttackTimeline.generic_projectile(state,source,data,enemy,null,enemy.cell,power,"magical")
		if source.silence_ticks_left==0:pending.resist_ignore=int(data.talent_2.effect_params.resist_ignore)
		return
	var target_data: OperatorData=state._operator_data[enemy.operator_id]
	var resistance := SkillRules.magic_resist_value(enemy,target_data)
	if source.silence_ticks_left==0:resistance=maxi(0,resistance-int(data.talent_2.effect_params["resist_ignore"]))
	var damage := Combat.calculate_damage(power,SkillRules.defense_value(enemy,target_data),resistance,"magical",SkillRules.dodge_chance(enemy,target_data,"magical"),state.rng,data.profession_id,state._damage_taken_percent(enemy,"magical"),state._magical_damage_taken_percent(enemy))
	if state._apply_damage(enemy,target_data,damage,"magical",source,attack_event) and enemy.hp>0 and SkillRules.active_ticks(source)!=0 and data.skills[source.skill_index].effect_type=="goldenglow_global":StatusRules.add_control(state,enemy,"slow",int(data.skills[source.skill_index].effect_params["slow_ticks"]),source)


static func attack(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var skill := data.skills[source.skill_index]
	if skill.effect_type=="goldenglow_current" and SkillRules.can_activate(source,skill):cast(state,source,data)
	if SkillRules.active_ticks(source)!=0 and skill.effect_type=="goldenglow_global":return
	if not AttackTimeline.advance(state,source):return
	var found := SwordRules.target(state,source,AttackRange.effective_offsets(source,data),false)
	found=AttackTimeline.pin_found(state,source,found)
	if found.is_empty():return
	if not AttackTimeline.windup_found(state,source,data,found):return
	source.attack_ticks_left=SkillRules.attack_interval_ticks(source,data)
	PusherRules.mark_attack(state,source,found.cell)
	var power := SkillRules.attack_value(source,data)
	if found.kind==0:hit(state,source,data,found.unit,power,true)
	else:AttackTimeline.found_projectile(state,source,data,found,power,data.damage_type)
	if source.skill_ticks_left==0:
		fire(state,source,data,0,found,false)
		SagaRules.reward(state,source,1)
