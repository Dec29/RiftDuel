class_name ClassicTacticalRules
extends RefCounted

const IDS := ["flametail","elysium","mudrock","rosa","passenger","shamare","feater"]

static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	var targets := SiegeRules.targets(state,unit,data.attack_range) if unit.operator_id=="rosa" else PusherRules.targets(state,unit,skill.attack_range_override if not skill.attack_range_override.is_empty() else data.attack_range,false)
	var center := Vector2i(-1,-1)
	if skill.effect_type=="heavy_bind_volley":
		unit.skill_hit_ids.clear();unit.mark_kind=-1
		for target in targets.slice(0,int(skill.effect_params["target_count"])):unit.skill_hit_ids.append(target.unit_id)
		if targets.is_empty():
			center=ClassicOperatorRules.target_cell(state,unit,data.attack_range)
			if center.x<0:return
			unit.mark_cell=center;unit.mark_kind=2 if state.ball.cell==center else 1
	if skill.effect_type=="chain_storm":
		targets.sort_custom(func(a: UnitState,b: UnitState)->bool:return a.hp>b.hp if a.hp!=b.hp else a.unit_id<b.unit_id)
		center=targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,skill.attack_range_override)
		if center.x<0:return
	if skill.effect_type=="pusher_slow_burst":
		targets.sort_custom(func(a: UnitState,b: UnitState)->bool:return (a.cell-unit.cell).length_squared()<(b.cell-unit.cell).length_squared() if (a.cell-unit.cell).length_squared()!=(b.cell-unit.cell).length_squared() else a.unit_id<b.unit_id)
		center=targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,skill.attack_range_override)
		if center.x<0:return
	SkillRules.activate(unit,data)
	unit.launch_started_tick=state.tick
	if skill.effect_type=="cost_dodge":
		state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(skill.effect_params["cost_add"]))
		unit.dodge_next_physical=true;unit.skill_ticks_left=0
	if skill.effect_type=="curse_doll_supply":unit.curse_doll_stock=1;unit.skill_ticks_left=0
	if skill.effect_type=="flag_recon":
		unit.skill_hit_ids.clear()
		for target in targets.slice(0,int(skill.effect_params["target_count"])):unit.skill_hit_ids.append(target.unit_id)
	if skill.effect_type=="cost_dodge_burst":
		state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(skill.effect_params["cost_add"]))
		unit.dodge_aura_until_tick=state.tick+int(skill.effect_params["buff_ticks"]);unit.dodge_aura_ids.clear();unit.dodge_aura_next_tick=state.tick+6
		var attack := roundi(SkillRules.attack_value(unit,data))
		for target in targets.slice(0,int(skill.effect_params["target_count"])):
			for shot in int(skill.effect_params["shot_count"]):
				if target.hp>0 and LaunchOperatorRules.hit(state,unit,data,target,attack,"physical") and target.hp>0:SwordRules.stun(state,target,int(skill.effect_params["stun_ticks"]),unit)
		ClassicOperatorRules.hit_objects(state,unit,skill.attack_range_override,attack,int(skill.effect_params["shot_count"]))
		PusherRules.mark_attack(state,unit,unit.cell);unit.skill_ticks_left=0
	if skill.effect_type=="chain_storm":
		var field := ClassicAttackField.new()
		field.kind=1;field.source_id=unit.unit_id;field.side=unit.side;field.cell=center;field.source_cell=unit.cell;field.facing=unit.facing
		field.pulse_ticks=int(skill.effect_params["pulse_ticks"]);field.next_tick=state.tick;field.end_tick=state.tick+int(skill.effect_params["lifetime_ticks"]);field.offsets=skill.burst_range_override.duplicate()
		state.classic_attack_fields.append(field);unit.skill_ticks_left=0
	if skill.effect_type=="pusher_slow_burst":
		var attack := SkillRules.attack_output_value(unit,data)
		for target in state.units.duplicate():
			if target.hp<=0 or target.side==unit.side or (target.cell-center).length_squared()>int(skill.effect_params["splash_radius_squared"]):continue
			if LaunchOperatorRules.hit(state,unit,data,target,attack,"physical") and target.hp>0:slow_push(state,unit,target,skill)
		for box in state.tactical_boxes:
			if box.hits_left>0 and (box.cell-center).length_squared()<=int(skill.effect_params["splash_radius_squared"]):TacticalRules.strike_box(state,unit,box)
		if state.ball.move_ticks_left==0 and (state.ball.cell-center).length_squared()<=int(skill.effect_params["splash_radius_squared"]):
			state.ball.add_push(unit.cell,attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
			DisplacementRules.apply_ball(state,DisplacementRules.direction(unit,state.ball.cell,"push"),int(skill.effect_params["shift_force"]))
		PusherRules.mark_attack(state,unit,center);unit.skill_ticks_left=0


# Returns true when this tick is fully handled (independent effects may precede basics).
static func before_attack(state: MatchState, unit: UnitState, data: OperatorData) -> bool:
	var skill := data.skills[unit.skill_index]
	if skill.trigger_type=="auto" and skill.effect_type not in ["shield_hammer"] and SkillRules.can_activate(unit,skill):cast(state,unit,data)
	if unit.dodge_aura_until_tick>state.tick and state.tick>=unit.dodge_aura_next_tick:
		unit.dodge_aura_next_tick=state.tick+6
		for ally in state.units:
			if ally.hp>0 and ally.side==unit.side and ally.unit_id not in unit.dodge_aura_ids and state._is_in_attack_range(unit,ally.cell,skill.attack_range_override):unit.dodge_aura_ids.append(ally.unit_id)
		AuraRules.refresh(state)
	if SkillRules.active_ticks(unit)>0 and skill.effect_type in ["cost_regen","flag_recon","cost_dodge_mode"]:SkillRules.advance_cost_regen(state,unit,skill)
	if SkillRules.active_ticks(unit)>0 and data.branch_trait.effect_type=="flag_bearer":return true
	if skill.effect_type=="heavy_bind_volley" and unit.skill_ticks_left>0:
		if unit.stun_ticks_left>0 or unit.silence_ticks_left>0:close_links(state,unit);return false
		var alive := PackedInt32Array()
		for id in unit.skill_hit_ids:
			var target := WArtilleryRules.owner(state,id)
			if target==null or not state.enemy_is_targetable(unit.side,target):continue
			alive.append(id)
			var before := target.bind_ticks_left
			StatusRules.add_control(state,target,"bind",unit.skill_ticks_left)
			if before==0 and target.bind_ticks_left>0:target.bind_link_owner_id=unit.unit_id
			if unit.skill_elapsed_ticks%int(skill.effect_params["pulse_ticks"])==0:hit(state,unit,data,target,SkillRules.attack_value(unit,data),"physical")
		unit.skill_hit_ids=alive
		if unit.mark_kind>=0 and unit.skill_elapsed_ticks%int(skill.effect_params["pulse_ticks"])==0:
			if unit.mark_kind==1:
				for box in state.tactical_boxes:
					if box.hits_left>0 and box.cell==unit.mark_cell:TacticalRules.strike_box(state,unit,box)
			elif state.ball.move_ticks_left==0 and state.ball.cell==unit.mark_cell:state.ball.add_push(unit.cell,SkillRules.attack_value(unit,data),state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
		if unit.skill_hit_ids.is_empty() and unit.mark_kind<0:close_links(state,unit)
		return true
	if skill.effect_type=="unyield_awakening" and unit.skill_ticks_left>0:
		if unit.skill_elapsed_ticks<int(skill.effect_params["rest_ticks"]):
			StatusRules.advance_basic_attack(unit)
			return true
		if unit.skill_elapsed_ticks==int(skill.effect_params["rest_ticks"]):
			for enemy in state.units:
				if enemy.hp>0 and enemy.side!=unit.side and state.terrain_at(enemy.cell)=="ground" and state._is_in_attack_range(unit,enemy.cell,skill.attack_range_override):SwordRules.stun(state,enemy,int(skill.effect_params["stun_ticks"]),unit)
	if skill.effect_type=="shield_hammer" and SkillRules.can_activate(unit,skill) and ClassicOperatorRules.target_cell(state,unit,skill.attack_range_override).x>=0:
		SkillRules.activate(unit,data)
		unit.hp=mini(SkillRules.max_health_value(unit,data),unit.hp+Combat.calculate_healing(SkillRules.max_health_value(unit,data),int(skill.effect_params["heal_percent"])))
		var attack := SkillRules.attack_value(unit,data)
		for enemy in state.units.duplicate():
			if enemy.hp<=0 or enemy.side==unit.side or state.terrain_at(enemy.cell)!="ground" or not state._is_in_attack_range(unit,enemy.cell,skill.attack_range_override):continue
			if hit(state,unit,data,enemy,attack,"physical") and enemy.hp>0 and state.rng.next_percent()<int(skill.effect_params["stun_chance_percent"]):SwordRules.stun(state,enemy,int(skill.effect_params["stun_ticks"]),unit)
		ClassicOperatorRules.hit_objects(state,unit,skill.attack_range_override,attack)
		PusherRules.mark_attack(state,unit,unit.cell);unit.skill_ticks_left=0;unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
		return true
	if unit.launch_started_tick==state.tick and skill.effect_type in ["cost_dodge_burst","pusher_slow_burst"]:return true
	return false


static func hit(state: MatchState, source: UnitState, data: OperatorData, target: UnitState, attack: int, damage_type: String) -> bool:
	var target_data: OperatorData=state._operator_data[target.operator_id]
	var defense := SkillRules.defense_value(target,target_data)
	if source.silence_ticks_left==0 and data.talent_1.effect_type=="heavy_penetration" and DisplacementRules.effective_weight(state,target)>=int(data.talent_1.effect_params["weight_threshold"]):defense=roundi(defense*(100-int(data.talent_1.effect_params["defense_ignore_percent"]))/100.0)
	var damage := Combat.calculate_damage(attack,defense,SkillRules.magic_resist_value(target,target_data),damage_type,SkillRules.dodge_chance(target,target_data,damage_type),state.rng,data.profession_id,state._damage_taken_percent(target,damage_type),state._magical_damage_taken_percent(target))
	return state._apply_damage(target,target_data,damage,damage_type,source)


static func chain(state: MatchState, source: UnitState, data: OperatorData, first: UnitState, attack: int, count: int, slow_ticks: int, shot: AttackProjectile=null) -> void:
	var target := first
	var used := PackedInt32Array()
	for bounce in count:
		used.append(target.unit_id)
		var center := target.cell
		var enhanced := false
		if not shot.silenced if shot!=null else source.silence_ticks_left==0:
			var talent := data.talent_1
			var index := source.analysis_target_ids.find(target.unit_id)
			if target.hp*100>SkillRules.max_health_value(target,state._operator_data[target.operator_id])*int(talent.effect_params["hp_threshold_percent"]):
				if index<0:source.analysis_target_ids.append(target.unit_id);source.analysis_expiry_ticks.append(state.tick+int(talent.effect_params["duration_ticks"]))
				else:source.analysis_expiry_ticks[index]=state.tick+int(talent.effect_params["duration_ticks"])
				index=source.analysis_target_ids.find(target.unit_id)
			enhanced=index>=0 and source.analysis_expiry_ticks[index]>state.tick
		var amount := roundi(attack*(100+int(data.talent_1.effect_params["damage_percent"]))/100.0) if enhanced else attack
		if LaunchOperatorRules.hit(state,source,data,target,amount,"magical") and target.hp>0:StatusRules.add_control(state,target,"slow",slow_ticks)
		var next: UnitState
		for enemy in state.units:
			if enemy.unit_id in used or not state.enemy_is_targetable(source.side,enemy) or (enemy.cell-center).length_squared()>int(data.branch_trait.effect_params["jump_radius_squared"]):continue
			if next==null or (enemy.cell-center).length_squared()<(next.cell-center).length_squared():next=enemy
		if next==null:break
		target=next
		attack=roundi(attack*int(data.branch_trait.effect_params["damage_remaining_percent"])/100.0)


static func slow_push(state: MatchState, source: UnitState, target: UnitState, skill: SkillResource) -> void:
	target.speed_debuff_until_tick=state.tick+int(skill.effect_params["debuff_ticks"])
	target.speed_debuff_remaining_percent=100-int(skill.effect_params["attack_speed_reduce"])
	DisplacementRules.apply_unit(state,source,target,DisplacementRules.direction(source,target.cell,"push"),int(skill.effect_params["shift_force"]))


static func close_links(state: MatchState, source: UnitState) -> void:
	for target in state.units:
		if target.bind_link_owner_id==source.unit_id:
			target.bind_link_owner_id=-1
			if target.bind_ticks_left>0:target.bind_ticks_left=0;target.bind_immunity_ticks_left=state.CONFIG.BIND_IMMUNITY_TICKS
	source.skill_hit_ids.clear();source.mark_kind=-1;source.skill_ticks_left=0


static func is_resting(unit: UnitState, data: OperatorData) -> bool:
	var skill := data.skills[unit.skill_index]
	return unit.skill_ticks_left>0 and skill.effect_type=="unyield_awakening" and unit.skill_elapsed_ticks<int(skill.effect_params["rest_ticks"])


static func on_dodge(state: MatchState, target: UnitState, data: OperatorData, damage_type: String, source: UnitState) -> void:
	if source==null or data.talent_1.effect_type!="dodge_counter" or target.silence_ticks_left>0:return
	if state.CONFIG.UNIT_DAMAGE_PERCENT_BY_PROFESSION[SkillRules.damage_profession_id(state._operator_data[source.operator_id])]==0:return
	if damage_type=="physical":target.dodge_next_physical=false
	target.dodge_attack_ready=true


static func refresh_buffs(state: MatchState) -> void:
	for unit in state.units:
		var data: OperatorData=state._operator_data[unit.operator_id]
		if unit.hp<=0:continue
		if unit.silence_ticks_left==0 and data.talent_2.effect_type=="isolated_enemy_attack":
			var isolated := true
			for enemy in state.units:
				if enemy.hp>0 and enemy.side!=unit.side and absi(enemy.cell.x-unit.cell.x)+absi(enemy.cell.y-unit.cell.y)==1:isolated=false;break
			if isolated:unit.attack_bonus_percent+=int(data.talent_2.effect_params["attack_percent"])
		if unit.operator_id=="curse_doll":
			for enemy in state.units:
				if enemy.hp>0 and enemy.side!=unit.side and state._is_in_attack_range(unit,enemy.cell,data.attack_range):enemy.curse_attack_remaining_percent=int(data.branch_trait.effect_params["attack_remaining_percent"]);enemy.curse_defense_remaining_percent=int(data.branch_trait.effect_params["defense_remaining_percent"])
		if unit.silence_ticks_left>0:continue
		var skill := data.skills[unit.skill_index]
		if data.talent_2.effect_type=="group_physical_dodge":
			for ally in state.units:
				if ally.hp>0 and ally.side==unit.side and state._operator_data[ally.operator_id].group_id==data.talent_2.effect_params["group_id"]:ally.dodge_physical_bonus=maxi(ally.dodge_physical_bonus,int(data.talent_2.effect_params["dodge_percent"]))
		if unit.dodge_aura_until_tick>state.tick:
			for ally in state.units:
				if ally.hp>0 and ally.unit_id in unit.dodge_aura_ids:ally.dodge_physical_bonus=maxi(ally.dodge_physical_bonus,int(skill.effect_params["dodge_percent"]))
		if data.talent_1.effect_type=="sniper_support":state.sides[unit.side].sniper_cost_discount=maxi(state.sides[unit.side].sniper_cost_discount,int(data.talent_1.effect_params["cost_reduction"]))
		if data.talent_1.effect_type=="sniper_support" and unit.skill_ticks_left>0:
			for ally in state.units:
				if ally.hp>0 and ally.side==unit.side and state._operator_data[ally.operator_id].profession_id=="sniper":ally.attack_speed_bonus+=int(data.talent_1.effect_params["attack_speed_add"])
		if unit.skill_ticks_left>0 and skill.effect_type=="flag_recon":
			for enemy in state.units:
				if enemy.hp>0 and enemy.unit_id in unit.skill_hit_ids:enemy.attack_speed_remaining_percent=mini(enemy.attack_speed_remaining_percent,100-int(skill.effect_params["attack_speed_reduce"]));enemy.recon_defense_remaining_percent=mini(enemy.recon_defense_remaining_percent,int(skill.effect_params["defense_remaining_percent"]))
		if is_resting(unit,data):
			for enemy in state.units:
				if enemy.hp>0 and enemy.side!=unit.side and state._is_in_attack_range(unit,enemy.cell,skill.attack_range_override):enemy.attack_speed_remaining_percent=mini(enemy.attack_speed_remaining_percent,100-int(skill.effect_params["attack_speed_reduce"]))


static func revealed(state: MatchState, side: int, target: UnitState) -> bool:
	for source in state.units:
		if source.hp<=0 or source.side!=side or source.silence_ticks_left>0 or source.skill_ticks_left<=0:continue
		var skill: SkillResource=state._operator_data[source.operator_id].skills[source.skill_index]
		if skill.effect_type=="flag_recon" and target.unit_id in source.skill_hit_ids:return true
	return false


static func advance_passives(state: MatchState) -> void:
	for unit in state.units:
		for index in range(unit.analysis_expiry_ticks.size()-1,-1,-1):
			if state.tick>=unit.analysis_expiry_ticks[index]:unit.analysis_expiry_ticks.remove_at(index);unit.analysis_target_ids.remove_at(index)
		var data: OperatorData=state._operator_data[unit.operator_id]
		if unit.hp>0 and unit.silence_ticks_left==0 and data.talent_1.effect_type=="regenerating_shield":
			unit.shield_charge_ticks+=1
			if unit.shield_charge_ticks>=int(data.talent_1.effect_params["interval_ticks"]):unit.shield_charge_ticks=0;unit.nian_shield_layers=mini(int(data.talent_1.effect_params["max_layers"]),unit.nian_shield_layers+1)
