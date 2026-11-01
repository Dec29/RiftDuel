class_name PallasRules
extends RefCounted


static func refresh_buffs(state: MatchState) -> void:
	var vigor := {}
	for unit in state.units:
		if unit.operator_id=="fiammetta" and unit.hp>0 and unit.silence_ticks_left==0:vigor[unit.unit_id]=unit.fiammetta_vigor_percent
	var talent_recipients := PackedInt32Array()
	var blessing_recipients := PackedInt32Array()
	for source in state.units:
		var data: OperatorData=state._operator_data[source.operator_id]
		if source.hp<=0 or source.silence_ticks_left>0 or data.branch_trait.effect_type!="mentor":continue
		var talent := data.talent_1
		for ally in state.units:
			var ally_data: OperatorData=state._operator_data[ally.operator_id]
			if ally.hp<=0 or ally.side!=source.side or ally_data.group_id!=talent.effect_params["group_id"]:continue
			talent_recipients.append(ally.unit_id)
			if state.tick>=ally.pallas_vigor_next_tick:
				ally.pallas_vigor_percent=int(talent.effect_params["attack_percent"]) if ally.hp*100>SkillRules.max_health_value(ally,ally_data)*int(talent.effect_params["hp_threshold_percent"]) else 0
				ally.pallas_vigor_next_tick=state.tick+int(talent.effect_params["check_interval_ticks"])
			vigor[ally.unit_id]=maxi(int(vigor.get(ally.unit_id,0)),ally.pallas_vigor_percent)
		var skill := data.skills[source.skill_index]
		if SkillRules.active_ticks(source)<=0 or skill.effect_type!="pallas_blessing":continue
		var recipient := source
		var front := source.cell+AttackRange.rotate_offset(Vector2i.RIGHT,source.facing)
		if front.x>=0 and front.x<state.CONFIG.GRID_COLUMNS and front.y>=0 and front.y<state.CONFIG.GRID_ROWS and state.terrain_at(front) in ["ground","ground_no_deploy"]:
			for ally in state.units:
				if ally.hp>0 and ally.side==source.side and ally.cell==front and state._operator_data[ally.operator_id].branch_trait.effect_type not in ["pozyomka_typewriter","silence_drone"]:recipient=ally;break
		recipient.defense_bonus_percent+=int(skill.effect_params["defense_percent"])
		recipient.block_bonus+=int(skill.effect_params["block_count_add"])
		var recipient_data: OperatorData=state._operator_data[recipient.operator_id]
		blessing_recipients.append(recipient.unit_id)
		if state.tick>=recipient.pallas_blessing_next_tick:
			recipient.pallas_blessing_vigor_percent=int(skill.effect_params["vigor_attack_percent"]) if recipient.hp*100>SkillRules.max_health_value(recipient,recipient_data)*int(skill.effect_params["hp_threshold_percent"]) else 0
			recipient.pallas_blessing_next_tick=state.tick+int(skill.effect_params["check_interval_ticks"])
		vigor[recipient.unit_id]=maxi(int(vigor.get(recipient.unit_id,0)),recipient.pallas_blessing_vigor_percent)
	for ally in state.units:
		ally.attack_bonus_percent+=int(vigor.get(ally.unit_id,0))
		if ally.unit_id not in talent_recipients:ally.pallas_vigor_next_tick=0;ally.pallas_vigor_percent=0
		if ally.unit_id not in blessing_recipients:ally.pallas_blessing_next_tick=0;ally.pallas_blessing_vigor_percent=0



static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if not AttackTimeline.advance(state,unit):return
	var found := SwordRules.target(state,unit,AttackRange.effective_offsets(unit,data),false)
	found=AttackTimeline.pin_found(state,unit,found)
	if found.is_empty():return
	var locked:=AttackTimeline.pinned(state,unit,PusherRules.targets(state,unit,AttackRange.effective_offsets(unit,data),false))
	if not AttackTimeline.windup(state,unit,data,locked,found.cell):return
	var skill := data.skills[unit.skill_index]
	var charged := skill.effect_type=="multi_shot" and SkillRules.can_activate(unit,skill)
	if charged:SkillRules.activate(unit,data)
	var active := SkillRules.active_ticks(unit)>0
	PusherRules.mark_attack(state,unit,found.cell);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var count := int(skill.effect_params["target_count"]) if active and skill.effect_type=="pallas_blessing" else 1
	var shots := int(skill.effect_params["shot_count"]) if charged else 1
	if found.kind==0:
		var targets := locked
		for index in mini(targets.size(),count):
			var target := targets[index]
			for shot in shots:
				if unit.hp<=0 or target.hp<=0:break
				var target_data: OperatorData=state._operator_data[target.operator_id]
				var amount := SkillRules.attack_value(unit,data)
				if not state.enemy_is_blocked(target,unit.unit_id):amount=roundi(amount*float(data.branch_trait.effect_params["unblocked_attack_mult"]))
				var damage := Combat.calculate_damage(amount,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target,"physical"))
				var landed := state._apply_damage(target,target_data,damage,"physical",unit)
				if unit.hp>0 and unit.silence_ticks_left==0:heal_on_attack(state,unit,data)
				if landed and target.hp>0 and active and skill.effect_type=="pallas_whip" and state.rng.next_percent()<int(skill.effect_params["chance_percent"]):SwordRules.stun(state,target,int(skill.effect_params["stun_ticks"]),unit)
	else:
		for shot in shots:
			if found.kind==1:
				if found.box.hits_left>0:TacticalRules.strike_box(state,unit,found.box)
			elif state.ball.move_ticks_left==0:
				state.ball.add_push(unit.cell,roundi(SkillRules.attack_value(unit,data)*float(data.branch_trait.effect_params["unblocked_attack_mult"])),state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
	if charged:unit.skill_ticks_left=0
	elif unit.skill_ticks_left==0 and skill.sp_recharge_type=="on_hit":SagaRules.reward(state,unit,1)


static func heal_on_attack(state: MatchState, source: UnitState, data: OperatorData) -> void:
	var front := source.cell+AttackRange.rotate_offset(Vector2i.RIGHT,source.facing)
	var amount := Combat.calculate_healing(int(data.talent_2.effect_params["heal_per_hit"]))
	for ally in state.units:
		if ally.hp<=0 or ally.side!=source.side or (ally!=source and ally.cell!=front):continue
		LumenRules.treat_amount(state,ally,amount,source)
