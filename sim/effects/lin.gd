class_name LinRules
extends RefCounted


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="lin_burst" and unit.skill_ticks_left>0:
		var old_interval := SkillRules.attack_interval_ticks(unit,data)
		unit.skill_ticks_left=0;unit.skill_elapsed_ticks=0
		unit.attack_ticks_left=ceili(float(unit.attack_ticks_left)*SkillRules.attack_interval_ticks(unit,data)/old_interval)
	else:SkillRules.activate(unit,data)


static func refresh_shields(state: MatchState) -> void:
	var desired := {}
	for source in state.units:
		var data: OperatorData=state._operator_data[source.operator_id]
		if source.hp<=0 or data.talent_1.effect_type!="glass_wall":continue
		desired[source.unit_id]=source.unit_id
		if source.silence_ticks_left>0 or SkillRules.active_ticks(source)<=0 or data.skills[source.skill_index].effect_type!="lin_shelter":continue
		for ally in state.units:
			if ally.hp>0 and ally.side==source.side and state._is_in_attack_range(source,ally.cell,data.attack_range):desired[ally.unit_id]=source.unit_id
	for target in state.units:
		var owner_id := int(desired.get(target.unit_id,-1))
		if owner_id!=target.lin_wall_owner_id:
			target.lin_wall_owner_id=owner_id;target.lin_wall_ready_tick=state.tick if owner_id>=0 else 0;target.lin_wall_active=owner_id>=0
		elif owner_id>=0 and state.tick>=target.lin_wall_ready_tick:target.lin_wall_active=true


static func received(state: MatchState, target: UnitState, data: OperatorData, source: UnitState) -> void:
	if source==null or source.side==target.side or target.hp<=0 or target.silence_ticks_left>0 or data.talent_2.effect_type!="damage_sp_proc":return
	var skill := data.skills[target.skill_index]
	if target.skill_ticks_left!=0 and skill.effect_type!="lin_stance":return
	if state.rng.next_percent()<int(data.talent_2.effect_params["chance_percent"]):target.sp=mini(SkillRules.sp_limit(skill),target.sp+int(data.talent_2.effect_params["sp_add"]))


# Returns [remaining damage, post-damage shatter]. Normal wall shatters before damage;
# S3 wall is resolved after other shields, and its shatter follows HP damage.
static func absorb(state: MatchState, target: UnitState, damage: int, late: bool) -> PackedInt32Array:
	if damage<=0 or not target.lin_wall_active:return PackedInt32Array([damage,0])
	var source := WArtilleryRules.owner(state,target.lin_wall_owner_id)
	if source==null or source.silence_ticks_left>0:return PackedInt32Array([damage,0])
	var data: OperatorData=state._operator_data[source.operator_id]
	var skill := data.skills[source.skill_index]
	var boosted := target==source and SkillRules.active_ticks(source)>0 and skill.effect_type=="lin_burst"
	if boosted!=late:return PackedInt32Array([damage,0])
	var threshold := int(data.talent_1.effect_params["damage_threshold"])*(int(skill.effect_params["threshold_multiplier"]) if boosted else 1)
	if damage<=threshold:
		target.last_damage_block_tick=state.tick
		return PackedInt32Array([0,0])
	target.lin_wall_active=false;target.lin_wall_ready_tick=state.tick+int(data.talent_1.effect_params["recovery_ticks"])
	if not late:burst(state,source,target.cell)
	return PackedInt32Array([damage-threshold,int(late)])


static func burst(state: MatchState, source: UnitState, center: Vector2i) -> void:
	var data: OperatorData=state._operator_data[source.operator_id]
	var offsets := AttackRange.effective_offsets(source,data)
	var targets: Array[UnitState]=[]
	for enemy in state.units:
		if state.enemy_is_targetable(source.side,enemy) and enemy.cell-center in offsets:targets.append(enemy)
	for enemy in targets:
		if enemy.hp<=0:continue
		SwordRules.stun(state,enemy,int(data.talent_1.effect_params["stun_ticks"]),source)
		var target_data: OperatorData=state._operator_data[enemy.operator_id]
		var damage := Combat.calculate_damage(roundi(SkillRules.attack_value(source,data)*int(data.talent_1.effect_params["attack_percent"])/100.0),SkillRules.defense_value(enemy,target_data),SkillRules.magic_resist_value(enemy,target_data),"magical",SkillRules.dodge_chance(enemy,target_data,"magical"),state.rng,data.profession_id,state._damage_taken_percent(enemy,"magical"),state._magical_damage_taken_percent(enemy))
		state._apply_damage(enemy,target_data,damage,"magical",source,false)


static func kill_burst(state: MatchState, source: UnitState) -> void:
	if source.hp<=0 or source.silence_ticks_left>0:return
	var had_wall := source.lin_wall_active
	source.lin_wall_active=false
	if had_wall:burst(state,source,source.cell)
	if source.hp>0:source.lin_wall_active=true;source.lin_wall_ready_tick=state.tick
