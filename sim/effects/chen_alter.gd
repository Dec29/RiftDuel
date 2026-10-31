class_name ChenAlterRules
extends RefCounted


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.skill_ticks_left!=0:close(unit,data);return
	var skill := data.skills[unit.skill_index]
	var charged := skill.effect_type=="chen_violet_night" and unit.sp>=SkillRules.sp_limit(skill)
	SkillRules.activate(unit,data)
	unit.sp=0
	unit.skill_ammo_left=int(skill.effect_params["charged_ammo_count"] if charged else skill.effect_params["ammo_count"])


static func close(unit: UnitState, data: OperatorData) -> void:
	var previous := SkillRules.attack_interval_ticks(unit,data)
	unit.skill_ticks_left=0;unit.skill_ammo_left=0;unit.skill_elapsed_ticks=0
	unit.attack_ticks_left=ceili(float(unit.attack_ticks_left)*SkillRules.attack_interval_ticks(unit,data)/previous)


static func consume_ammo(state: MatchState, unit: UnitState, data: OperatorData, amount: int) -> void:
	var chance := 0
	for source in state.units:
		if source.operator_id!="chen_alter" or source.hp<=0 or source.silence_ticks_left>0 or source.side!=unit.side:continue
		var talent: TalentResource=state._operator_data[source.operator_id].talent_1
		if source==unit:chance=maxi(chance,int(talent.effect_params["self_chance_percent"]))
		elif data.profession_id=="sniper":chance=maxi(chance,int(talent.effect_params["ally_chance_percent"]))
	if chance==0 or state.rng.next_u32()%100>=chance:unit.skill_ammo_left=maxi(0,unit.skill_ammo_left-amount)


static func maintain(state: MatchState) -> void:
	var retained: Array[ChenSlime]=[]
	for field in state.chen_slimes:
		if state.tick<field.due_tick:retained.append(field)
	state.chen_slimes=retained


static func refresh(state: MatchState) -> void:
	for target in state.units:
		target.chen_slime_defense_reduce=0
		if target.hp<=0 or state.terrain_at(target.cell)!="ground":continue
		for field in state.chen_slimes:
			if target.side!=field.side and target.cell in field.cells:
				target.chen_slime_defense_reduce=maxi(target.chen_slime_defense_reduce,field.defense_reduce)
				target.attack_speed_remaining_percent=mini(target.attack_speed_remaining_percent,field.speed_remaining_percent)


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="chen_water_pressure" and SkillRules.can_activate(unit,skill):cast(state,unit,data)
	if not AttackTimeline.advance(state,unit):return
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets := PusherRules.targets(state,unit,offsets,false)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,offsets)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	var active := SkillRules.active_ticks(unit)!=0
	if active and skill.effect_type in ["chen_violet_night","chen_holiday_storm"]:
		state.chen_slimes.append(ChenSlime.new(unit,offsets,state.tick+int(skill.effect_params["field_ticks"]),int(skill.effect_params["slow_remaining_percent"]),int(skill.effect_params["defense_reduce"])))
		AuraRules.refresh(state)
	PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var power := SkillRules.attack_value(unit,data)
	var box_target: TacticalBox
	if targets.is_empty():
		for target_box in state.tactical_boxes:
			if target_box.hits_left>0 and target_box.cell==center:box_target=target_box;break
	var shots := 2 if active and skill.effect_type=="chen_holiday_storm" else 1
	for shot in shots:
		for target in targets:
			if target.hp<=0 or unit.hp<=0:continue
			var attack := power
			var delta: Vector2i=target.cell-unit.cell
			if (active and skill.effect_type in ["chen_water_pressure","chen_holiday_storm"]) or delta in [AttackRange.rotate_offset(Vector2i(1,-1),unit.facing),AttackRange.rotate_offset(Vector2i(1,0),unit.facing),AttackRange.rotate_offset(Vector2i(1,1),unit.facing)]:attack=roundi(power*int(data.branch_trait.effect_params["front_attack_percent"])/100.0)
			var projectile:=AttackTimeline.generic_projectile(state,unit,data,target,null,target.cell,attack,"physical")
			projectile.attack_event=shot==0
		if targets.is_empty():
			var front := center-unit.cell in [AttackRange.rotate_offset(Vector2i(1,-1),unit.facing),AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing),AttackRange.rotate_offset(Vector2i(1,1),unit.facing)]
			var amount:=roundi(power*int(data.branch_trait.effect_params["front_attack_percent"])/100.0) if front or (active and skill.effect_type in ["chen_water_pressure","chen_holiday_storm"]) else power
			AttackTimeline.generic_projectile(state,unit,data,null,box_target,center,amount,"physical")

	if active:
		consume_ammo(state,unit,data,int(skill.effect_params["ammo_per_attack"]) if skill.effect_type=="chen_holiday_storm" else 1)
		if unit.skill_ammo_left==0:close(unit,data)
	else:SagaRules.reward(state,unit,1)
