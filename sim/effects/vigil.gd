class_name VigilRules
extends RefCounted

static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id=="vigil":return unit
	return null

static func wolf(state: MatchState, source: UnitState) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.vigil_owner_id==source.unit_id:return unit
	return null

static func available(state: MatchState, side: int) -> bool:
	var source := owner(state,side)
	return source!=null and source.silence_ticks_left==0 and wolf(state,source)==null and state.sides[side].cooldowns.get("vigil_wolf",0)==0

static func deployed(state: MatchState, unit: UnitState) -> void:
	var source := owner(state,unit.side)
	var params: Dictionary=state._operator_data[source.operator_id].talent_1.effect_params
	unit.vigil_owner_id=source.unit_id;unit.vigil_wolf_layers=int(params["initial_layers"]);unit.vigil_regrow_tick=state.tick+int(params["regrow_ticks"])

static func remove_owned(state: MatchState, source: UnitState) -> void:
	for unit in state.units.duplicate():
		if unit.vigil_owner_id==source.unit_id:state.units.erase(unit)

static func maintain(state: MatchState) -> void:
	for unit in state.units.duplicate():
		if unit.operator_id!="vigil_wolf":continue
		var source := WArtilleryRules.owner(state,unit.vigil_owner_id)
		if source==null or source.hp<=0:state.units.erase(unit);continue
		if state.tick>=unit.vigil_regrow_tick:
			var params: Dictionary=state._operator_data[source.operator_id].talent_1.effect_params
			unit.vigil_wolf_layers=mini(int(params["max_layers"]),unit.vigil_wolf_layers+1);unit.vigil_regrow_tick+=int(params["regrow_ticks"])

static func fatal(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.hp<=0 and unit.operator_id=="vigil_wolf" and unit.vigil_wolf_layers>1:
		unit.vigil_wolf_layers-=1;unit.hp=SkillRules.max_health_value(unit,data);unit.last_heal_tick=state.tick

static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	SkillRules.activate(unit,data)
	if skill.effect_type=="vigil_slaughter":return
	state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(skill.effect_params["cost_add"]))
	var token := wolf(state,unit)
	if token!=null:
		if skill.effect_type=="vigil_call":token.vigil_wolf_layers=mini(int(data.talent_1.effect_params["max_layers"]),token.vigil_wolf_layers+1)
		else:
			token.vigil_enhanced_attack=true
			var token_data: OperatorData=state._operator_data[token.operator_id]
			token.hp=mini(SkillRules.max_health_value(token,token_data),token.hp+SkillRules.healing_received(token,token_data,Combat.calculate_healing(roundi(token_data.max_health*int(skill.effect_params["wolf_heal_percent"])/100.0)),unit));token.last_heal_tick=state.tick
	unit.skill_ticks_left=0

static func blocks(state: MatchState, source: UnitState, target: UnitState) -> bool:
	var token := wolf(state,source)
	return token!=null and state.enemy_is_blocked(target,token.unit_id)

static func hit(state: MatchState, unit: UnitState, source: UnitState, target: UnitState, amount: int, kind: String) -> bool:
	var td: OperatorData=state._operator_data[target.operator_id]
	var od: OperatorData=state._operator_data[source.operator_id]
	var defense := SkillRules.defense_value(target,td)
	if source.silence_ticks_left==0 and blocks(state,source,target):defense=maxi(0,defense-int(od.talent_2.effect_params["defense_ignore"]))
	var damage := Combat.calculate_damage(amount,defense,SkillRules.magic_resist_value(target,td),kind,SkillRules.dodge_chance(target,td,kind),state.rng,"vanguard",state._damage_taken_percent(target,kind),state._magical_damage_taken_percent(target))
	return state._apply_damage(target,td,damage,kind,unit)

static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var source := WArtilleryRules.owner(state,unit.vigil_owner_id) if unit.operator_id=="vigil_wolf" else unit
	if source==null:return
	var od: OperatorData=state._operator_data[source.operator_id]
	var skill := od.skills[source.skill_index]
	if unit==source:
		if skill.trigger_type=="auto" and SkillRules.can_activate(unit,skill):cast(state,unit,data)
		if SkillRules.active_ticks(unit)>0 and skill.effect_type=="vigil_slaughter":SkillRules.advance_cost_regen(state,unit,skill)
	if not AttackTimeline.advance(state,unit):return
	var targets := PusherRules.targets(state,unit,data.attack_range,false,true)
	if unit==source:
		targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
			if a.side!=b.side:return a.side!=unit.side
			var ta := SkillRules.taunt_level(a,state._operator_data[a.operator_id]);var tb := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
			if ta!=tb:return ta>tb
			var ba := blocks(state,source,a);var bb := blocks(state,source,b)
			return ba if ba!=bb else a.unit_id<b.unit_id)
	else:
		for enemy in state.units:
			if state.enemy_is_targetable(unit.side,enemy) and state.enemy_is_blocked(enemy,unit.unit_id) and enemy not in targets:targets.append(enemy)
		targets.sort_custom(func(a:UnitState,b:UnitState)->bool:return a.side!=unit.side if a.side!=b.side else a.unit_id<b.unit_id)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,data.attack_range)
	if center.x<0:return
	var native_action:=unit.attack_intent
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var active := SkillRules.active_ticks(source)>0 and skill.effect_type=="vigil_slaughter"
	var count := (int(skill.effect_params["shot_count"]) if active else 1) if unit==source else unit.vigil_wolf_layers
	var stages:=AttackTimeline.release_indices(unit,native_action,count) if unit==source else PackedInt32Array(range(count))
	var amount := SkillRules.attack_value(unit,data)
	var enhanced := unit!=source and unit.vigil_enhanced_attack
	if enhanced:amount=roundi(amount*float(od.skills[1].effect_params["wolf_attack_mult"]))
	if not targets.is_empty():
		var target := targets[0]
		var blocked := blocks(state,source,target)
		if blocked and unit==source:amount=roundi(amount*int(od.branch_trait.effect_params["blocked_attack_percent"])/100.0)
		for index in stages:
			if unit.hp<=0 or target.hp<=0:break
			if unit==source:
				var shot:=AttackTimeline.generic_projectile(state,unit,data,target,null,target.cell,amount,"physical")
				if blocked and source.silence_ticks_left==0:shot.defense_ignore_flat=int(od.talent_2.effect_params["defense_ignore"])
				if active and blocked:shot.extra_magic_attack=roundi(SkillRules.attack_value(source,od)*int(skill.effect_params["magic_attack_percent"])/100.0)
				continue
			var landed := hit(state,unit,source,target,amount,"physical")
			if landed and target.hp>0 and active and blocked:hit(state,unit,source,target,roundi(SkillRules.attack_value(source,od)*int(skill.effect_params["magic_attack_percent"])/100.0),"magical")
			if enhanced and landed:unit.vigil_enhanced_victim=target.unit_id
			if enhanced and target.hp<=0:state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(od.skills[1].effect_params["kill_cost"]));unit.vigil_enhanced_victim=-1
	else:
		for index in stages:
			if unit==source:
				var box: TacticalBox
				for candidate in state.tactical_boxes:
					if candidate.cell==center and candidate.hits_left>0:box=candidate;break
				AttackTimeline.generic_projectile(state,unit,data,null,box,center,amount,"physical")
				continue
			var struck := false
			for box in state.tactical_boxes:
				if box.cell==center and box.hits_left>0:TacticalRules.strike_box(state,unit,box);struck=true;break
			if not struck and center==state.ball.cell and state.ball.move_ticks_left==0:state.ball.add_push(unit.cell,amount,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
	if enhanced:unit.vigil_enhanced_attack=false
