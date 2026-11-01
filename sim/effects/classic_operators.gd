class_name ClassicOperatorRules
extends RefCounted

# Distinct casts use the same attribute, damage, healing, targeting and control paths.
const IDS := ["flametail","elysium","mudrock","rosa","passenger","shamare","feater","jessica","haze","sussurro","warfarin","gummy","podenco","mountain","surtr","mizuki"]
const ATTACK_IDS := ["flametail","elysium","mudrock","rosa","passenger","shamare","feater","warfarin","gummy","podenco","mountain","surtr","mizuki"]

static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.operator_id in ClassicTacticalRules.IDS:ClassicTacticalRules.cast(state,unit,data);return
	var skill := data.skills[unit.skill_index]
	var center := Vector2i(-1,-1)
	if skill.effect_type=="silence_cloud":
		center=target_cell(state,unit,AttackRange.effective_offsets(unit,data))
		if center.x<0:return
	SkillRules.activate(unit,data)
	unit.launch_started_tick=state.tick
	if skill.effect_type=="limited_atk_spd_boost":
		unit.limited_skill_uses+=1
		state.sides[unit.side].sussurro_skill_uses=unit.limited_skill_uses
	if skill.effect_type=="twilight":
		AuraRules.refresh(state)
		unit.hp=SkillRules.max_health_value(unit,data)
		unit.last_heal_tick=state.tick
	if skill.effect_type=="random_blood_buff":
		var allies: Array[UnitState]=[]
		for ally in state.units:
			if ally.hp>0 and ally.side==unit.side and ally!=unit and state._is_in_attack_range(unit,ally.cell,data.attack_range):allies.append(ally)
		var targets: Array[UnitState]=[unit]
		if not allies.is_empty():targets.append(allies[state.rng.next_u32()%allies.size()])
		for target in targets:
			target.blood_buff_until_tick=state.tick+int(skill.effect_params["buff_ticks"])
			target.blood_buff_attack_percent=int(skill.effect_params["attack_percent"])
			target.blood_buff_loss_percent=int(skill.effect_params["hp_loss_percent"])
			target.blood_buff_next_tick=state.tick+state.CONFIG.TICK_RATE-1
		unit.skill_ticks_left=0
	if skill.effect_type=="silence_cloud":
		var field := ClassicAttackField.new()
		field.source_id=unit.unit_id;field.side=unit.side;field.cell=center;field.source_cell=unit.cell;field.facing=unit.facing
		field.attack=roundi(SkillRules.attack_value(unit,data)*int(skill.effect_params["pulse_attack_percent"])/100.0)
		field.pulse_ticks=int(skill.effect_params["pulse_ticks"]);field.next_tick=state.tick+field.pulse_ticks;field.end_tick=state.tick+int(skill.effect_params["lifetime_ticks"]);field.radius_squared=int(skill.effect_params["splash_radius_squared"])
		state.classic_attack_fields.append(field)
		unit.skill_ticks_left=0


static func advance(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.operator_id=="surtr":AttackTimeline.attack(state,unit,data);return
	var skill := data.skills[unit.skill_index]
	if unit.operator_id in ClassicTacticalRules.IDS and ClassicTacticalRules.before_attack(state,unit,data):return
	if data.operator_id=="gummy" and skill.effect_type=="guardian_aid" and unit.bind_ticks_left==0 and GuardianRules.advance(state,unit,data):return
	if SkillRules.active_ticks(unit)>0 and skill.effect_type=="guardian_cook" and unit.skill_elapsed_ticks<int(skill.effect_params["warmup_ticks"]):
		StatusRules.advance_basic_attack(unit)
		return
	if not AttackTimeline.advance(state,unit):return
	if data.talent_2.effect_type=="wounded_enemy_attack":AuraRules.refresh(state)
	if SkillRules.damage_type(unit,data)=="healing" or (SkillRules.active_ticks(unit)>0 and skill.effect_type=="guardian_cook"):
		heal(state,unit,data)
		return
	var offsets := AttackRange.effective_offsets(unit,data)
	var enemies := SiegeRules.targets(state,unit,offsets) if unit.operator_id=="rosa" else PusherRules.targets(state,unit,offsets,false,unit.operator_id in ["mountain","gummy","mudrock","flametail"])
	if data.branch_trait.effect_type=="ambusher":
		enemies.clear()
		for enemy in state.units:
			if enemy.hp>0 and StainlessRules.is_damage_target(unit,enemy) and enemy.sleep_ticks_left==0 and state._operator_data[enemy.operator_id].branch_trait.effect_type not in ["pozyomka_typewriter","silence_drone","medical_drone","water_cannon","seaborn"] and state._is_in_attack_range(unit,enemy.cell,offsets):enemies.append(enemy)
	enemies=AttackTimeline.pinned(state,unit,enemies)
	var center := enemies[0].cell if not enemies.is_empty() else target_cell(state,unit,offsets)
	if center.x<0:return
	var native_action:=unit.attack_intent
	var native_phase:=unit.attack_action_event_index
	if not AttackTimeline.windup(state,unit,data,enemies,center):return
	var triggered := skill.trigger_type=="attack" and SkillRules.can_activate(unit,skill)
	if triggered:SkillRules.activate(unit,data);unit.launch_started_tick=state.tick
	var active := SkillRules.active_ticks(unit)!=0
	var area := data.branch_trait.effect_type=="ambusher" or (active and skill.effect_type=="fighter_barrage")
	var count := enemies.size() if data.branch_trait.effect_type=="ambusher" else (data.block_count if data.branch_trait.effect_type=="pusher" else 1)
	if active and skill.effect_type in ["blue_double","dual_arts_boost","twilight","fighter_barrage","multi_target_boost"]:count=int(skill.effect_params["target_count"])
	if active and skill.effect_type in ["fighter_stance","unyield_awakening"]:count=SkillRules.block_count_value(unit,data)
	if unit.dodge_attack_ready and unit.silence_ticks_left==0:count=SkillRules.block_count_value(unit,data)
	enemies=enemies.slice(0,count)
	var physical_targets := enemies.duplicate()
	var extra_targets: Array[UnitState]=[]
	if data.talent_1.effect_type=="lowest_health_arts" and unit.silence_ticks_left==0:
		extra_targets.assign(enemies)
		extra_targets.sort_custom(func(a: UnitState,b: UnitState)->bool:return a.hp<b.hp if a.hp!=b.hp else a.unit_id<b.unit_id)
		var extra_count := int(data.talent_1.effect_params["target_count"])
		if active and skill.effect_type in ["ambush_bind","ambush_stun"]:extra_count+=int(skill.effect_params["extra_target_count"])
		extra_targets=extra_targets.slice(0,extra_count)
	var attack := SkillRules.attack_output_value(unit,data)
	var proc := false
	if unit.silence_ticks_left==0 and data.talent_1.effect_type in ["attack_weaken_proc","stun_attack_proc"]:
		var chance := int(skill.effect_params["talent_chance_percent"]) if active and skill.effect_type=="fighter_barrage" else int(data.talent_1.effect_params["chance_percent"])
		proc=unit.attack_action_proc if native_phase>0 else state.rng.next_percent()<chance
		if native_phase==0:unit.attack_action_proc=proc
		if proc:attack=roundi(attack*int(data.talent_1.effect_params["attack_percent"])/100.0)
	if active and skill.effect_type=="dual_arts_boost" and enemies.size()==1:attack=roundi(attack*int(skill.effect_params["single_target_percent"])/100.0)
	if data.branch_trait.effect_type=="chain_magic" and not enemies.is_empty():
		var chain_count := int(skill.effect_params["target_count"]) if active and skill.effect_type in ["chain_strike","chain_focus"] else int(data.branch_trait.effect_params["target_count"])
		var slow_ticks := int(skill.effect_params["slow_ticks"]) if active and skill.effect_type=="chain_strike" else int(data.branch_trait.effect_params["slow_ticks"])
		var chain_shot:=AttackTimeline.generic_projectile(state,unit,data,enemies[0],null,enemies[0].cell,attack,"magical")
		chain_shot.chain_count=chain_count;chain_shot.slow_ticks=slow_ticks
		PusherRules.mark_attack(state,unit,center);unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
		if unit.skill_ticks_left==-1:unit.skill_ticks_left=0
		return
	PusherRules.mark_attack(state,unit,center)
	BlemishineRules.on_basic_attack(state,unit)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var counter := unit.dodge_attack_ready and unit.silence_ticks_left==0
	var shots := int(data.talent_1.effect_params["shot_count"]) if counter else (int(skill.effect_params["shot_count"]) if active and skill.effect_type=="fighter_barrage" else 1)
	var strike_indices:=AttackTimeline.release_indices(unit,native_action,shots)
	unit.dodge_attack_ready=false
	var killed := false
	physical_targets.sort_custom(func(a: UnitState,b: UnitState)->bool:return a.unit_id<b.unit_id)
	for target: UnitState in physical_targets:
		for shot in strike_indices:
			if unit.hp<=0 or target.hp<=0:break
			if unit.operator_id in ["rosa","podenco","shamare"]:
				AttackTimeline.generic_projectile(state,unit,data,target,null,target.cell,attack,data.damage_type)
				continue
			var landed := ClassicTacticalRules.hit(state,unit,data,target,attack,data.damage_type) if unit.operator_id=="rosa" else LaunchOperatorRules.hit(state,unit,data,target,attack,data.damage_type,int(data.talent_1.effect_params["resist_ignore"]) if unit.silence_ticks_left==0 and data.talent_1.effect_type=="flat_resist_penetration" else 0)
			killed=killed or target.hp<=0
			if landed and target.hp>0:
				if proc and data.talent_1.effect_type=="attack_weaken_proc":target.weaken_until_tick=state.tick+int(data.talent_1.effect_params["duration_ticks"]);target.weaken_attack_remaining_percent=int(data.talent_1.effect_params["attack_remaining_percent"])
				if active and skill.effect_type=="pusher_slow_strike":ClassicTacticalRules.slow_push(state,unit,target,skill)
				if proc and data.talent_1.effect_type=="stun_attack_proc":SwordRules.stun(state,target,int(data.talent_1.effect_params["stun_ticks"]),unit)
				if active and skill.effect_type=="fighter_barrage":DisplacementRules.apply_unit(state,unit,target,DisplacementRules.direction(unit,target.cell,"push"),int(skill.effect_params["shift_force"]))
	var extra_multiplier := int(data.talent_1.effect_params["attack_percent"]) if not extra_targets.is_empty() else 0
	if active and skill.effect_type=="ambush_charge":extra_multiplier*=int(skill.effect_params["talent_multiplier"])
	var extra_attack := roundi(SkillRules.attack_value(unit,data,active and skill.effect_type=="ambush_charge")*extra_multiplier/100.0)
	extra_targets.sort_custom(func(a: UnitState,b: UnitState)->bool:return a.unit_id<b.unit_id)
	for target in extra_targets:
		if unit.hp<=0 or target.hp<=0:continue
		if LaunchOperatorRules.hit(state,unit,data,target,extra_attack,"magical") and target.hp>0 and active:
			if skill.effect_type=="ambush_bind":StatusRules.add_control(state,target,"bind",int(skill.effect_params["bind_ticks"]))
			if skill.effect_type=="ambush_stun":SwordRules.stun(state,target,int(skill.effect_params["stun_ticks"]),unit)
	if area:hit_objects(state,unit,offsets,attack,strike_indices.size())
	elif enemies.is_empty():
		if unit.operator_id in ["rosa","podenco","shamare","passenger"]:
			var box_target: TacticalBox
			for candidate in state.tactical_boxes:
				if candidate.cell==center and candidate.hits_left>0:box_target=candidate;break
			for index in shots:AttackTimeline.generic_projectile(state,unit,data,null,box_target,center,attack,data.damage_type)
			if unit.skill_ticks_left==-1:unit.skill_ticks_left=0
			if not triggered and skill.sp_recharge_type=="on_hit" and unit.skill_ticks_left==0:SagaRules.reward(state,unit,1)
			return
		var found_box := false
		for box in state.tactical_boxes:
			if box.hits_left>0 and box.cell==center:
				found_box=true
				for shot in strike_indices:
					if box.hits_left>0:TacticalRules.strike_box(state,unit,box)
				break
		if not found_box and state.ball.move_ticks_left==0 and center==state.ball.cell:
			for shot in strike_indices:state.ball.add_push(unit.cell,attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
			if active and skill.effect_type=="pusher_slow_strike":DisplacementRules.apply_ball(state,DisplacementRules.direction(unit,state.ball.cell,"push"),int(skill.effect_params["shift_force"]))
	if active and skill.effect_type=="ambush_stun" and enemies.size()<int(skill.effect_params["required_targets"]):lose_health(state,unit,roundi(SkillRules.max_health_value(unit,data)*int(skill.effect_params["hp_loss_percent"])/100.0))
	if unit.skill_ticks_left==-1:unit.skill_ticks_left=0
	if active and skill.effect_type=="kill_refund_strike" and killed:unit.sp=SkillRules.sp_limit(skill)
	elif native_phase==0 and not triggered and skill.sp_recharge_type=="on_hit" and unit.skill_ticks_left==0:SagaRules.reward(state,unit,1)


static func heal(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var chosen: UnitState
	for ally in state.units:
		if ally.hp<=0 or ally.side!=unit.side or not LumenRules.can_heal(state,ally) or not state._is_in_attack_range(unit,ally.cell,AttackRange.effective_offsets(unit,data)):continue
		var maximum := SkillRules.max_health_value(ally,state._operator_data[ally.operator_id])
		if ally.hp>=maximum:continue
		if chosen==null or ally.hp*SkillRules.max_health_value(chosen,state._operator_data[chosen.operator_id])<chosen.hp*maximum:chosen=ally
	chosen=AttackTimeline.heal_target(state,unit,chosen)
	if chosen==null:return
	var locked_heals: Array[UnitState]=[chosen]
	if not AttackTimeline.windup(state,unit,data,locked_heals,chosen.cell,true):return
	var skill := data.skills[unit.skill_index]
	var maximum := SkillRules.max_health_value(chosen,state._operator_data[chosen.operator_id])
	var charged := false
	if skill.effect_type=="percent_charge_heal" and chosen.hp*100<maximum*int(skill.effect_params["hp_threshold_percent"]) and SkillRules.can_activate(unit,skill):
		SkillRules.activate(unit,data)
		charged=true
		LumenRules.treat_amount(state,chosen,Combat.calculate_healing(maximum,int(skill.effect_params["extra_max_health_percent"])),unit)
		unit.skill_ticks_left=0
	LumenRules.treat_amount(state,chosen,Combat.calculate_healing(SkillRules.attack_value(unit,data)),unit)
	unit.last_attack_tick=state.tick;unit.last_attack_is_heal=true;unit.last_attack_target_x=chosen.cell.x;unit.last_attack_target_y=chosen.cell.y
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	if not charged and skill.sp_recharge_type=="on_hit":SagaRules.reward(state,unit,1)


static func target_cell(state: MatchState, unit: UnitState, offsets: Array[Vector2i]) -> Vector2i:
	var enemies := SiegeRules.targets(state,unit,offsets) if unit.operator_id=="rosa" else PusherRules.targets(state,unit,offsets,false)
	if not enemies.is_empty():return enemies[0].cell
	for box in state.tactical_boxes:
		if box.hits_left>0 and state._is_in_attack_range(unit,box.cell,offsets):return box.cell
	return state.ball.cell if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,offsets) else Vector2i(-1,-1)


static func hit_objects(state: MatchState, unit: UnitState, offsets: Array[Vector2i], attack: int, shots: int = 1) -> void:
	for box in state.tactical_boxes:
		if box.hits_left>0 and state._is_in_attack_range(unit,box.cell,offsets):
			for shot in shots:
				if box.hits_left>0:TacticalRules.strike_box(state,unit,box)
	if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,offsets):
		for shot in shots:state.ball.add_push(unit.cell,attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))


static func regenerate(state: MatchState) -> void:
	advance_fields(state)
	for unit in state.units:
		if unit.hp<=0:continue
		var data: OperatorData=state._operator_data[unit.operator_id]
		if unit.blood_buff_until_tick>state.tick and state.tick>=unit.blood_buff_next_tick:
			unit.blood_buff_next_tick+=state.CONFIG.TICK_RATE
			lose_health(state,unit,roundi(SkillRules.max_health_value(unit,data)*unit.blood_buff_loss_percent/100.0))
		var skill := data.skills[unit.skill_index]
		if SkillRules.active_ticks(unit)!=0 and skill.effect_type=="fighter_stance" and unit.critical_ticks_left==0:
			unit.skill_hp_regen_accum+=SkillRules.max_health_value(unit,data)*int(skill.effect_params["regen_health_percent"])*state.CONFIG.UNIT_HEAL_PERCENT
			var denominator := state.CONFIG.TICK_RATE*10000
			var healed := unit.skill_hp_regen_accum/denominator
			unit.skill_hp_regen_accum%=denominator
			if healed>0:unit.hp=mini(SkillRules.max_health_value(unit,data),unit.hp+healed);unit.last_heal_tick=state.tick
		if SkillRules.active_ticks(unit)!=0 and skill.effect_type=="twilight":
			unit.skill_elapsed_ticks+=1
			if unit.skill_elapsed_ticks%int(skill.effect_params["loss_pulse_ticks"])==0:
				var loss := roundi(SkillRules.max_health_value(unit,data)*int(skill.effect_params["loss_max_percent"])*mini(unit.skill_elapsed_ticks,int(skill.effect_params["ramp_ticks"]))*int(skill.effect_params["loss_pulse_ticks"])/(100.0*int(skill.effect_params["ramp_ticks"])*state.CONFIG.TICK_RATE))
				lose_health(state,unit,loss)


static func fatal_damage(state: MatchState, unit: UnitState, data: OperatorData, amount: int) -> int:
	if unit.fatal_until_tick>state.tick:return mini(amount,maxi(0,unit.hp-1))
	if amount>=unit.hp and unit.silence_ticks_left==0 and data.talent_2.effect_type=="fatal_delay":
		unit.fatal_until_tick=state.tick+int(data.talent_2.effect_params["duration_ticks"])
		return maxi(0,unit.hp-1)
	return amount


static func lose_health(state: MatchState, unit: UnitState, amount: int) -> void:
	var data: OperatorData=state._operator_data[unit.operator_id]
	var monstr_return := unit.hp>0 and MonstrMedicRules.transformed(unit) and amount>=unit.hp
	unit.hp-=MonstrMedicRules.clamp_life_loss(unit,fatal_damage(state,unit,data,amount))
	if monstr_return:MonstrMedicRules.finish(state,unit)
	unit.last_damage_tick=state.tick
	if unit.hp<=0:WArtilleryRules.on_exit(state,unit)


static func after_hit(state: MatchState, target: UnitState, source: UnitState) -> void:
	if source==null or source.hp<=0 or source.silence_ticks_left>0 or target.hp<=0:return
	var talent: TalentResource=state._operator_data[source.operator_id].talent_1
	if talent.effect_type=="hit_resist_reduction":
		target.resist_break_ticks_left=int(talent.effect_params["duration_ticks"])
		target.resist_remaining_percent=int(talent.effect_params["resist_remaining_percent"])


static func on_death(state: MatchState, target: UnitState) -> void:
	if target.operator_id=="shamare":CurseDollRules.remove_owned(state,target)
	if target.operator_id=="rosa":ClassicTacticalRules.close_links(state,target)
	if target.death_sp_resolved:return
	target.death_sp_resolved=true
	for source in state.units:
		if source.hp<=0 or source.side==target.side or source.silence_ticks_left>0:continue
		var data: OperatorData=state._operator_data[source.operator_id]
		if data.talent_1.effect_type!="death_sp_in_range" or not state._is_in_attack_range(source,target.cell,data.attack_range):continue
		var allies: Array[UnitState]=[]
		for ally in state.units:
			if ally.hp>0 and ally.side==source.side and ally!=source and state._is_in_attack_range(source,ally.cell,data.attack_range):allies.append(ally)
		SagaRules.reward(state,source,int(data.talent_1.effect_params["sp_add"]))
		if not allies.is_empty():SagaRules.reward(state,allies[state.rng.next_u32()%allies.size()],int(data.talent_1.effect_params["sp_add"]))


static func advance_fields(state: MatchState) -> void:
	var alive: Array[ClassicAttackField]=[]
	for field in state.classic_attack_fields:
		if field.kind==1:
			advance_storm(state,field,alive)
			continue
		if state.tick>field.end_tick:continue
		var source := WArtilleryRules.owner(state,field.source_id)
		if source==null:source=UnitState.new(field.source_id,field.side,"podenco",field.source_cell,1,0,0,field.facing,1)
		var pulse := state.tick>=field.next_tick
		for enemy in state.units.duplicate():
			if enemy.hp<=0 or enemy.side==field.side or (enemy.cell-field.cell).length_squared()>field.radius_squared:continue
			StatusRules.add_control(state,enemy,"slow",1)
			StatusRules.apply_silence(state,enemy,1)
			if pulse:LaunchOperatorRules.hit(state,source,state._operator_data["podenco"],enemy,field.attack,"magical")
		if pulse:
			for box in state.tactical_boxes:
				if box.hits_left>0 and (box.cell-field.cell).length_squared()<=field.radius_squared:TacticalRules.strike_box(state,source,box)
			if state.ball.move_ticks_left==0 and (state.ball.cell-field.cell).length_squared()<=field.radius_squared:state.ball.add_push(field.source_cell,field.attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,field.facing))
			field.next_tick+=field.pulse_ticks
		if state.tick<field.end_tick:alive.append(field)
	state.classic_attack_fields=alive


static func advance_storm(state: MatchState, field: ClassicAttackField, alive: Array[ClassicAttackField]) -> void:
	var source := WArtilleryRules.owner(state,field.source_id)
	if source==null or source.hp<=0 or state.tick>=field.end_tick:return
	if state.tick>=field.next_tick:
		var data: OperatorData=state._operator_data[source.operator_id]
		var skill := data.skills[source.skill_index]
		var enemies: Array[UnitState]=[]
		var origin := UnitState.new(-1,source.side,source.operator_id,field.cell,1,0,0,0)
		for enemy in state.units:
			if state.enemy_is_targetable(source.side,enemy) and state._is_in_attack_range(origin,enemy.cell,field.offsets):enemies.append(enemy)
		var attack := roundi(SkillRules.attack_value(source,data)*int(skill.effect_params["pulse_attack_percent"])/100.0)
		if not enemies.is_empty():ClassicTacticalRules.chain(state,source,data,enemies[state.rng.next_u32()%enemies.size()],attack,int(skill.effect_params["target_count"]),int(data.branch_trait.effect_params["slow_ticks"]))
		for box in state.tactical_boxes:
			if box.hits_left>0 and state._is_in_attack_range(origin,box.cell,field.offsets):TacticalRules.strike_box(state,source,box)
		if state.ball.move_ticks_left==0 and state._is_in_attack_range(origin,state.ball.cell,field.offsets):state.ball.add_push(field.source_cell,attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,field.facing))
		field.next_tick+=field.pulse_ticks
	alive.append(field)
