class_name InesRules
extends RefCounted

static func on_exit(state: MatchState, unit: UnitState) -> void:
	if unit.operator_id!="ines":return
	state.sides[unit.side].ines_shadow_cell=unit.cell;state.sides[unit.side].ines_shadow_facing=unit.facing
	unit.ines_target_ids.clear();unit.ines_target_speed.clear();unit.ines_stolen_attack=0;unit.ines_speed_gain=0
	AuraRules.refresh(state)

static func deployed(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if data.skills[unit.skill_index].effect_type!="ines_recall":return
	var side := state.sides[unit.side]
	if not side.ines_first_shadow_used:
		side.ines_first_shadow_used=true
		on_exit(state,unit);state.units.erase(unit);side.cooldowns.erase("ines")
		return
	unit.skill_ticks_left=roundi(data.skills[unit.skill_index].duration*state.CONFIG.TICK_RATE);unit.skill_activation_count+=1
	var origin := side.ines_shadow_cell;side.ines_shadow_cell=Vector2i(-1,-1)
	if origin.x<0:return
	var targets: Array[UnitState]=[]
	var delta := unit.cell-origin
	for enemy in state.units:
		if not state.enemy_is_targetable(unit.side,enemy):continue
		var relative := enemy.cell-origin
		var along := relative.x*delta.x+relative.y*delta.y
		var cross := relative.x*delta.y-relative.y*delta.x
		# Original projectile_range1.4, quantized cell centres within the stationary recall corridor.
		if ((enemy.cell-origin).length_squared()*100<=196 if delta==Vector2i.ZERO else (along>=0 and along<=delta.length_squared() and cross*cross*100<=196*delta.length_squared())):targets.append(enemy)
	targets.sort_custom(func(a:UnitState,b:UnitState)->bool:
		var aa := (a.cell-origin).length_squared();var bb := (b.cell-origin).length_squared()
		return aa<bb if aa!=bb else a.unit_id<b.unit_id)
	for enemy in targets.slice(0,int(data.skills[unit.skill_index].effect_params["target_count"])):
		if unit.hp<=0:break
		land(state,unit,data,enemy,roundi(SkillRules.attack_value(unit,data)*float(data.skills[unit.skill_index].effect_params["recall_attack_mult"])),"physical")

static func refresh(state: MatchState) -> void:
	for unit in state.units:
		unit.ines_attack_loss=0;unit.ines_speed_loss=0;unit.ines_shadow_slow=0
	for source in state.units:
		if source.hp<=0 or source.operator_id!="ines":continue
		var source_data: OperatorData=state._operator_data[source.operator_id]
		var first := source_data.talent_1.effect_params
		source.ines_stolen_attack=0;source.ines_speed_gain=0
		for index in range(source.ines_target_ids.size()-1,-1,-1):
			var enemy := WArtilleryRules.owner(state,source.ines_target_ids[index])
			if enemy==null or enemy.hp<=0:source.ines_target_ids.remove_at(index);source.ines_target_speed.remove_at(index);continue
			source.ines_stolen_attack=mini(int(first["attack_limit"]),source.ines_stolen_attack+int(first["attack_steal"]));enemy.ines_attack_loss+=int(first["attack_steal"])
			if SkillRules.active_ticks(source)>0 and source.skill_index==1:
				source.ines_speed_gain+=source.ines_target_speed[index];enemy.ines_speed_loss+=source.ines_target_speed[index]
			else:source.ines_target_speed[index]=0
		if source.skill_index==1:source.ines_speed_gain=mini(int(source_data.skills[1].effect_params["speed_limit"]),source.ines_speed_gain)
		if source.silence_ticks_left>0:continue
		for enemy in state.units:
			if enemy.hp>0 and enemy.side!=source.side and state._is_in_attack_range(source,enemy.cell,AttackRange.effective_offsets(source,state._operator_data[source.operator_id])):enemy.ines_shadow_slow=30
	for side in 2:
		var cell := state.sides[side].ines_shadow_cell
		if cell.x<0:continue
		var shadow := UnitState.new(-1,side,"ines",cell,1,0,1,state.sides[side].ines_shadow_facing)
		for enemy in state.units:
			if enemy.hp>0 and enemy.side!=side and state._is_in_attack_range(shadow,enemy.cell,state._operator_data["ines"].attack_range):enemy.ines_shadow_slow=30

static func reveals(state: MatchState, side: int, target: UnitState) -> bool:
	for source in state.units:
		if source.operator_id=="ines" and source.hp>0 and source.side==side and source.silence_ticks_left==0 and state._is_in_attack_range(source,target.cell,AttackRange.effective_offsets(source,state._operator_data[source.operator_id])):return true
	var cell := state.sides[side].ines_shadow_cell
	if cell.x<0:return false
	var shadow := UnitState.new(-1,side,"ines",cell,1,0,1,state.sides[side].ines_shadow_facing)
	return state._is_in_attack_range(shadow,target.cell,state._operator_data["ines"].attack_range)

static func advance(state: MatchState) -> void:
	for target in state.units.duplicate():
		if target.hp<=0 or target.ines_dot_until==0:continue
		if state.tick>=target.ines_dot_next and state.tick<=target.ines_dot_until:
			var td: OperatorData=state._operator_data[target.operator_id]
			var source := WArtilleryRules.owner(state,target.ines_dot_source)
			var damage := Combat.calculate_damage(target.ines_dot_attack,0,SkillRules.magic_resist_value(target,td),"magical",0,state.rng,"vanguard",state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
			state._apply_damage(target,td,damage,"magical",source,false);target.ines_dot_next+=30
		if state.tick>=target.ines_dot_until:target.ines_dot_until=0;target.ines_dot_next=0;target.ines_dot_source=-1;target.ines_dot_attack=0

static func land(state: MatchState, unit: UnitState, data: OperatorData, enemy: UnitState, amount: int, kind: String) -> bool:
	var landed := TexasAlterRules.hit(state,unit,data,enemy,amount,kind)
	if not landed:return false
	if unit.silence_ticks_left==0 and enemy.hp>0:
		var index := unit.ines_target_ids.find(enemy.unit_id)
		if index<0:
			unit.ines_target_ids.append(enemy.unit_id);unit.ines_target_speed.append(0);index=unit.ines_target_ids.size()-1
			StatusRules.add_control(state,enemy,"bind",int(data.talent_1.effect_params["bind_ticks"]))
		if SkillRules.active_ticks(unit)>0 and unit.skill_index==1:unit.ines_target_speed[index]=mini(int(data.skills[1].effect_params["speed_limit"]),unit.ines_target_speed[index]+int(data.skills[1].effect_params["speed_steal"]))
		AuraRules.refresh(state)
	if SkillRules.active_ticks(unit)>0 and unit.skill_index==2:state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(data.skills[unit.skill_index].effect_params["cost_add"]))
	return true

static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,unit):return
	var targets := PusherRules.targets(state,unit,AttackRange.effective_offsets(unit,data),false,true)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,AttackRange.effective_offsets(unit,data))
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	var skill := data.skills[unit.skill_index]
	var bleed := skill.effect_type=="ines_bleed" and SkillRules.can_activate(unit,skill)
	if bleed:SkillRules.activate(unit,data)
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var amount := SkillRules.attack_value(unit,data)
	if not targets.is_empty():
		var target := targets[0]
		if land(state,unit,data,target,amount,"physical") and target.hp>0 and bleed:
			if target.ines_dot_until<=state.tick:target.ines_dot_next=state.tick+30
			target.ines_dot_until=state.tick+int(skill.effect_params["dot_ticks"]);target.ines_dot_attack=roundi(SkillRules.attack_value(unit,data)*int(skill.effect_params["dot_attack_percent"])/100.0);target.ines_dot_source=unit.unit_id
	else:
		var struck := false
		for box in state.tactical_boxes:
			if box.cell==center and box.hits_left>0:TacticalRules.strike_box(state,unit,box);struck=true;break
		if not struck and state.ball.move_ticks_left==0:state.ball.add_push(unit.cell,amount,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
	if bleed:state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(skill.effect_params["cost_add"]));unit.skill_ticks_left=0
	elif SkillRules.active_ticks(unit)>0 and skill.effect_type=="ines_night":state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(data.skills[unit.skill_index].effect_params["cost_add"]))
	if skill.sp_recharge_type=="on_hit" and unit.skill_ticks_left==0:unit.sp=mini(SkillRules.sp_limit(skill),unit.sp+1)
