class_name LingRules
extends RefCounted

const IDS := ["ling_soul1","ling_soul2","ling_soul3"]

static func owner(state: MatchState, side: int) -> UnitState:
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id=="ling":return unit
	return null

static func owner_for(state: MatchState, soul: UnitState) -> UnitState:
	var source := owner(state,soul.side)
	return source if source!=null and source.unit_id==soul.ling_owner_id else null

static func weighted_count(state: MatchState, side: int) -> int:
	var count := 0
	for unit in state.units:
		if unit.hp>0 and unit.side==side and unit.operator_id in IDS:count+=2 if unit.ling_advanced else 1
	return count

static func available(state: MatchState, side: int, id: String) -> bool:
	var source := owner(state,side)
	if source==null or source.silence_ticks_left>0 or source.skill_index!=IDS.find(id) or state.sides[side].ling_stock<=0:return false
	return weighted_count(state,side)<int(state._operator_data["ling"].talent_1.effect_params["max_count"])

static func deployed(state: MatchState, soul: UnitState) -> void:
	var source := owner(state,soul.side)
	soul.ling_owner_id=source.unit_id
	state.sides[soul.side].ling_stock-=1
	state.sides[soul.side].cooldowns[soul.operator_id]=roundi(state._operator_data[soul.operator_id].redeploy_time*state.CONFIG.TICK_RATE)
	if soul.operator_id!="ling_soul3":return
	var absorber: UnitState
	var material: UnitState
	for old in state.units:
		if old==soul or old.hp<=0 or old.ling_owner_id!=source.unit_id or old.operator_id!="ling_soul3" or old.ling_advanced:continue
		if state._is_in_attack_range(soul,old.cell,state._operator_data[soul.operator_id].attack_range):absorber=old;material=soul;break
	if absorber==null:
		for old in state.units:
			if old==soul or old.hp<=0 or old.ling_owner_id!=source.unit_id or old.operator_id!="ling_soul3" or old.ling_advanced:continue
			if state._is_in_attack_range(old,soul.cell,state._operator_data[old.operator_id].attack_range) and (material==null or old.unit_id>material.unit_id):material=old
		if material!=null:absorber=soul
	if absorber==null:return
	var data: OperatorData=state._operator_data[absorber.operator_id]
	var old_interval := SkillRules.attack_interval_ticks(absorber,data)
	remove(state,material,true,false)
	absorber.ling_advanced=true
	absorber.attack_ticks_left=ceili(float(absorber.attack_ticks_left)*SkillRules.attack_interval_ticks(absorber,data)/old_interval)
	AuraRules.refresh(state)
	absorber.hp=SkillRules.max_health_value(absorber,data)

static func reward(state: MatchState, source: UnitState) -> void:
	if source==null or source.hp<=0 or source.silence_ticks_left>0:return
	var data: OperatorData=state._operator_data[source.operator_id]
	var params := data.talent_2.effect_params
	source.ling_recycle_stacks=mini(int(params["max_stacks"]),source.ling_recycle_stacks+1)
	if source.skill_ticks_left==0 and SkillRules.can_gain_sp(source):source.sp=mini(SkillRules.sp_limit(data.skills[source.skill_index]),source.sp+int(params["sp_add"]))

static func remove(state: MatchState, soul: UnitState, trigger: bool, recover: bool) -> void:
	var source := owner_for(state,soul)
	state.units.erase(soul)
	if recover:state.sides[soul.side].ling_stock=mini(int(state._operator_data["ling"].talent_1.effect_params["stock_count"]),state.sides[soul.side].ling_stock+1)
	if trigger:reward(state,source)
	WArtilleryRules.on_exit(state,soul)

static func remove_owned(state: MatchState, source: UnitState) -> void:
	for soul: UnitState in state.units.duplicate():
		if soul.ling_owner_id==source.unit_id:remove(state,soul,false,false)

static func on_death(state: MatchState, unit: UnitState) -> void:
	if unit.operator_id=="ling":remove_owned(state,unit)
	elif unit.operator_id in IDS:reward(state,owner_for(state,unit))

static func refresh_auras(state: MatchState) -> void:
	for unit in state.units:
		unit.ling_skill_mode=0
		if unit.hp<=0:continue
		if unit.operator_id=="ling" and unit.silence_ticks_left==0:
			unit.attack_bonus_percent+=unit.ling_recycle_stacks*int(state._operator_data["ling"].talent_2.effect_params["attack_percent"])
		if unit.operator_id not in IDS:continue
		var source := owner_for(state,unit)
		if source==null or SkillRules.active_ticks(source)<=0 or unit.silence_ticks_left>0:continue
		var skill: SkillResource=state._operator_data["ling"].skills[source.skill_index]
		if skill.effect_type=="ling_wine":
			unit.ling_skill_mode=1;unit.attack_bonus_percent+=roundi((float(skill.effect_params["attack_mult"])-1.0)*100);unit.attack_speed_bonus+=int(skill.effect_params["attack_speed_add"])
		elif skill.effect_type=="ling_thunder":
			unit.ling_skill_mode=3;unit.attack_bonus_percent+=roundi((float(skill.effect_params["attack_mult"])-1.0)*100);unit.defense_bonus_percent+=roundi((float(skill.effect_params["defense_mult"])-1.0)*100)

static func add_stock(state: MatchState, source: UnitState, amount: int) -> void:
	state.sides[source.side].ling_stock=mini(int(state._operator_data["ling"].talent_1.effect_params["stock_count"]),state.sides[source.side].ling_stock+amount)

static func cast(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var skill := data.skills[source.skill_index]
	SkillRules.activate(source,data)
	source.ling_pulse_ticks=0
	if skill.effect_type=="ling_wine":add_stock(state,source,int(skill.effect_params["stock_add"]))
	elif skill.effect_type=="ling_chord":
		var casters: Array[UnitState]=[source]
		for soul in state.units:
			if soul.hp>0 and soul.ling_owner_id==source.unit_id and soul.operator_id=="ling_soul2":casters.append(soul)
		for caster in casters:
			if caster.hp<=0 or caster.silence_ticks_left>0:continue
			var cd: OperatorData=state._operator_data[caster.operator_id]
			for target in PusherRules.targets(state,caster,cd.attack_range,false).slice(0,int(skill.effect_params["target_count"])):
				hit(state,caster,target,roundi(SkillRules.attack_value(caster,cd)*float(skill.effect_params["burst_attack_mult"])),"magical",false)
				if target.hp>0:StatusRules.add_control(state,target,"bind",int(skill.effect_params["bind_ticks"]))
		# The instant skill has finished before recovery grants SP.
		source.skill_ticks_left=0
		for soul: UnitState in state.units.duplicate():
			if soul.hp>0 and soul.ling_owner_id==source.unit_id and soul.operator_id=="ling_soul2" and soul.hp*2<SkillRules.max_health_value(soul,state._operator_data[soul.operator_id]):remove(state,soul,true,true)
	AuraRules.refresh(state)

static func finish(state: MatchState, source: UnitState, data: OperatorData) -> void:
	if source.hp>0 and data.skills[source.skill_index].effect_type=="ling_thunder":add_stock(state,source,int(data.skills[source.skill_index].effect_params["stock_add"]))

static func advance(state: MatchState) -> void:
	for source: UnitState in state.units.duplicate():
		if source.operator_id!="ling" or source.hp<=0 or SkillRules.active_ticks(source)<=0:continue
		var data: OperatorData=state._operator_data["ling"]
		var skill := data.skills[source.skill_index]
		if skill.effect_type!="ling_thunder":continue
		source.ling_pulse_ticks+=1
		if source.ling_pulse_ticks<int(skill.effect_params["pulse_ticks"]):continue
		source.ling_pulse_ticks=0
		var amount := roundi(SkillRules.attack_value(source,data)*int(skill.effect_params["pulse_attack_percent"])/100.0)
		for soul: UnitState in state.units.duplicate():
			if soul.hp<=0 or soul.ling_owner_id!=source.unit_id:continue
			for target: UnitState in state.units.duplicate():
				if target.hp>0 and StainlessRules.is_damage_target(source,target) and (target.cell-soul.cell).length_squared()==1:hit(state,source,target,amount,"magical",false)

static func hit(state: MatchState, source: UnitState, target: UnitState, value: int, type: String, event: bool) -> void:
	var data: OperatorData=state._operator_data[source.operator_id]
	var td: OperatorData=state._operator_data[target.operator_id]
	var damage := Combat.calculate_damage(value,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),type,SkillRules.dodge_chance(target,td,type) if event else 0,state.rng,SkillRules.damage_profession_id(data),state._damage_taken_percent(target,type),state._magical_damage_taken_percent(target))
	state._apply_damage(target,td,damage,type,source,event)

static func attack(state: MatchState, soul: UnitState, data: OperatorData) -> void:
	if owner_for(state,soul)==null or not AttackTimeline.advance(state,soul):return
	var targets := PusherRules.targets(state,soul,data.attack_range,false)
	if soul.operator_id=="ling_soul3":
		for target in state.units:
			if target not in targets and state.enemy_is_targetable(soul.side,target,soul) and state.enemy_is_blocked(target,soul.unit_id):targets.append(target)
		targets.sort_custom(func(a: UnitState,b: UnitState)->bool:
			var ab := state.enemy_is_blocked(a,soul.unit_id);var bb := state.enemy_is_blocked(b,soul.unit_id)
			if ab!=bb:return ab
			var at := SkillRules.taunt_level(a,state._operator_data[a.operator_id]);var bt := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
			return at>bt if at!=bt else a.unit_id<b.unit_id)

	targets=AttackTimeline.pinned(state,soul,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,soul,data.attack_range)
	if center.x<0:return
	if not AttackTimeline.windup(state,soul,data,targets,center):return
	PusherRules.mark_attack(state,soul,center);soul.attack_ticks_left=SkillRules.attack_interval_ticks(soul,data)
	var value := SkillRules.attack_value(soul,data)
	if not targets.is_empty():
		var count := SkillRules.block_count_value(soul,data) if soul.operator_id=="ling_soul3" else 1
		for target in targets.slice(0,count):
			if soul.hp<=0:break
			if soul.operator_id=="ling_soul2":AttackTimeline.generic_projectile(state,soul,data,target,null,target.cell,value,SkillRules.damage_type(soul,data))
			else:hit(state,soul,target,value,SkillRules.damage_type(soul,data),true)
		return
	for box in state.tactical_boxes:
		if box.cell==center:
			if soul.operator_id=="ling_soul2":AttackTimeline.generic_projectile(state,soul,data,null,box,center,value,SkillRules.damage_type(soul,data))
			else:TacticalRules.strike_box(state,soul,box)
			return
	if state.ball.move_ticks_left==0:
		if soul.operator_id=="ling_soul2":AttackTimeline.generic_projectile(state,soul,data,null,null,center,value,SkillRules.damage_type(soul,data))
		else:state.ball.add_push(soul.cell,value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,soul.facing))
