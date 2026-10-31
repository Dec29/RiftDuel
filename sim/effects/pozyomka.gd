class_name PozyomkaRules
extends RefCounted


static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.operator_id=="pozyomka" and unit.side==side and unit.hp>0:return unit
	return null


static func owner_for(state: MatchState, token: UnitState) -> UnitState:
	for unit in state.units:
		if unit.unit_id==token.typewriter_owner_id and unit.operator_id=="pozyomka" and unit.hp>0:return unit
	return null


static func available(state: MatchState, side: int) -> bool:
	var source := owner(state,side)
	if source==null or source.silence_ticks_left>0 or state.sides[side].cost<state.TYPEWRITER_DATA.deploy_cost or state.sides[side].cooldowns.get("pozyomka_typewriter",0)>0:return false
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id=="pozyomka_typewriter":return false
	return true


static func deployed(state: MatchState, token: UnitState) -> void:
	var source := owner(state,token.side)
	token.typewriter_owner_id=source.unit_id
	# S1 is a permanent owner stance. Newly placed devices share the completed stance.
	if source.skill_index==0 and source.skill_ticks_left==-2:token.skill_ticks_left=-2


static func remove_token(state: MatchState, token: UnitState) -> void:
	var seconds := 20 if token.skill_index==1 else 40
	state.sides[token.side].cooldowns[token.operator_id]=seconds*state.CONFIG.TICK_RATE
	state.units.erase(token)


static func remove_owned(state: MatchState, source: UnitState) -> void:
	for token in state.units.duplicate():
		if token.typewriter_owner_id==source.unit_id:remove_token(state,token)


static func maintain(state: MatchState) -> void:
	for unit in state.units.duplicate():
		if unit.operator_id=="pozyomka_typewriter" and (owner_for(state,unit)==null or state.tick-unit.deployed_tick>=750):remove_token(state,unit)
	for target in state.units:
		if target.typewriter_defense_until_tick>0 and state.tick>=target.typewriter_defense_until_tick:
			target.typewriter_defense_until_tick=0
			target.typewriter_defense_remaining_percent=100


static func cast(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var skill := data.skills[source.skill_index]
	if skill.effect_type=="pozyomka_burst":
		if SwordRules.target(state,source,data.attack_range,false).is_empty():return
		SkillRules.activate(source,data)
		source.skill_ticks_left=0
		burst(state,source,data)
	else:SkillRules.activate(source,data)
	for token in state.units:
		if token.typewriter_owner_id!=source.unit_id or token.hp<=0:continue
		var token_data: OperatorData=state._operator_data[token.operator_id]
		if skill.effect_type=="pozyomka_burst":burst(state,token,token_data)
		else:
			var previous := SkillRules.attack_interval_ticks(token,token_data)
			token.skill_ticks_left=source.skill_ticks_left
			token.skill_elapsed_ticks=0
			token.skill_activation_count+=1
			token.attack_ticks_left=ceili(float(token.attack_ticks_left)*SkillRules.attack_interval_ticks(token,token_data)/previous)


static func burst(state: MatchState, source: UnitState, data: OperatorData) -> void:
	# S2 affects the forward skill range without changing the normal acquisition range.
	var offsets := data.skills[source.skill_index].attack_range_override
	if offsets.is_empty():offsets=data.attack_range
	var found := SwordRules.target(state,source,offsets,false)
	if found.is_empty():return
	PusherRules.mark_attack(state,source,found.cell)
	var power := roundi(SkillRules.attack_value(source,data,true)*float(data.skills[source.skill_index].effect_params["attack_mult"]))
	for shot in 3:
		if found.kind==0:
			if found.unit.hp<=0:break
			hit(state,source,data,found.unit,power,shot==0)
		elif found.kind==1:
			if found.box.hits_left<=0:break
			TacticalRules.strike_box(state,source,found.box)
		elif state.ball.move_ticks_left==0:
			state.ball.add_push(source.cell,power,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,source.facing))


static func attack(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var skill := data.skills[source.skill_index]
	var token := source.operator_id=="pozyomka_typewriter"
	if token and owner_for(state,source)==null:return
	if not token and skill.effect_type=="pozyomka_meter" and SkillRules.can_activate(source,skill):cast(state,source,data)
	if source.last_attack_tick==state.tick or not AttackTimeline.advance(state,source):return
	var offsets := AttackRange.effective_offsets(source,data)
	var found := SwordRules.target(state,source,offsets,false)
	found=AttackTimeline.pin_found(state,source,found)
	if found.is_empty():return
	if not AttackTimeline.windup_found(state,source,data,found):return
	var power := SkillRules.attack_value(source,data)
	if SkillRules.active_ticks(source)!=0 and skill.effect_type=="pozyomka_meter" and state.rng.next_u32()%100<int(skill.effect_params["chance_percent"]):power=roundi(power*float(skill.effect_params["critical_mult"]))
	if SkillRules.active_ticks(source)!=0 and skill.effect_type=="pozyomka_sketch" and not token:
		var delta: Vector2i=found.cell-source.cell
		if delta in [AttackRange.rotate_offset(Vector2i(1,0),source.facing),AttackRange.rotate_offset(Vector2i(2,0),source.facing),AttackRange.rotate_offset(Vector2i(3,0),source.facing)]:power=roundi(SkillRules.attack_value(source,data,true)*float(skill.effect_params["front_attack_mult"]))
	PusherRules.mark_attack(state,source,found.cell)
	source.attack_ticks_left=SkillRules.attack_interval_ticks(source,data)
	if found.kind==0:hit(state,source,data,found.unit,power)
	else:AttackTimeline.found_projectile(state,source,data,found,power,data.damage_type)
	if not token and source.skill_ticks_left==0:SagaRules.reward(state,source,1)


static func hit(state: MatchState, source: UnitState, data: OperatorData, target: UnitState, power: int, attack_event: bool = true) -> void:
	if not attack_event:
		var td: OperatorData=state._operator_data[target.operator_id]
		var damage:=Combat.calculate_damage(power,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),"physical",SkillRules.dodge_chance(target,td,"physical"),state.rng,SkillRules.damage_profession_id(data),state._damage_taken_percent(target,"physical"))
		var landed:=state._apply_damage(target,td,damage,"physical",source,false)
		if landed and target.hp>0 and source.operator_id=="pozyomka_typewriter":
			var controller:=owner_for(state,source)
			if controller!=null and controller.silence_ticks_left==0:
				var params: Dictionary=state._operator_data.pozyomka.talent_2.effect_params
				target.typewriter_defense_remaining_percent=int(params.adjacent_defense_remaining_percent) if (source.cell-controller.cell).length_squared()==1 else int(params.defense_remaining_percent)
				target.typewriter_defense_until_tick=state.tick+int(params.duration_ticks)
		return
	var shot:=AttackTimeline.generic_projectile(state,source,data,target,null,target.cell,power,"physical")
	if source.operator_id=="pozyomka_typewriter":
		var controller:=owner_for(state,source)
		if controller!=null and controller.silence_ticks_left==0:
			var params: Dictionary=state._operator_data.pozyomka.talent_2.effect_params
			shot.typewriter_remaining_percent=int(params.adjacent_defense_remaining_percent) if (source.cell-controller.cell).length_squared()==1 else int(params.defense_remaining_percent)
			shot.typewriter_ticks=int(params.duration_ticks)
