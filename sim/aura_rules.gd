class_name AuraRules
extends RefCounted

const ATTACK_RANGE := preload("res://sim/attack_range.gd")


# Mutating refresh: preserves blessing RNG, HP ratio and remaining cooldown.
static func refresh(state: MatchState) -> void:
	for side in state.sides:side.sniper_cost_discount=0
	var old_health: Array[int] = []
	var old_intervals: Array[int] = []
	for unit in state.units:
		var data: OperatorData = state._operator_data[unit.operator_id]
		old_health.append(SkillRules.max_health_value(unit, data))
		old_intervals.append(SkillRules.attack_interval_ticks(unit, data))
		unit.pramanix_defense_remaining_percent=100
		unit.pramanix_resist_remaining_percent=100
		unit.ambush_ready=data.talent_1.effect_type=="delayed_ambush" and unit.silence_ticks_left==0 and state.tick-unit.deployed_tick>=int(data.talent_1.effect_params["warmup_ticks"])
		unit.inspire_attack_add=0
		unit.inspire_defense_add=0
		unit.block_bonus=0
		unit.status_resistance_bonus=0
		unit.flame_resist_aura_percent = 0
		unit.healing_output_percent = 100
		unit.dodge_physical_bonus=0
		unit.attack_speed_remaining_percent=unit.speed_debuff_remaining_percent if state.tick<unit.speed_debuff_until_tick else 100
		unit.recon_defense_remaining_percent=100
		unit.curse_defense_remaining_percent=100
		unit.curse_attack_remaining_percent=100
		unit.healing_received_bonus_percent=0
		unit.max_health_bonus_add=0
		unit.attack_bonus_percent = 0
		unit.sp_recharge_bonus_percent = 0
		unit.defense_bonus_percent = 0
		unit.skill_defense_bonus_percent = 0
		unit.flag_defense_bonus_percent = 0
		unit.defense_bonus_add = 0
		unit.attack_speed_bonus = 0
		unit.magic_resist_bonus = 0
		unit.magic_resist_bonus_percent = 0
		unit.dodge_magical_bonus = 0
		unit.max_health_bonus_percent = 0
		if data.branch_trait.effect_type=="bard" and SkillRules.active_ticks(unit)>0 and data.skills[unit.skill_index].effect_type=="bard_share":unit.max_health_bonus_percent=int(data.skills[unit.skill_index].effect_params["health_percent"])
		if SkillRules.active_ticks(unit) > 0 and data.skills[unit.skill_index].effect_type in ["atk_def_health_boost","amiya_chimera"]:
			unit.max_health_bonus_percent += int(data.skills[unit.skill_index].effect_params["health_percent"])
		if SkillRules.active_ticks(unit)>0 and data.skills[unit.skill_index].effect_type=="atk_spd_health_boost":unit.max_health_bonus_percent-=100-int(data.skills[unit.skill_index].effect_params["health_remaining_percent"])
		if SkillRules.active_ticks(unit)!=0 and data.skills[unit.skill_index].effect_type=="twilight":unit.max_health_bonus_add=int(data.skills[unit.skill_index].effect_params["max_health_add"])
		AakRules.refresh_buff(unit)
	for side in 2:
		var member_ids := state.squad_ids[side].duplicate()
		member_ids.sort()
		for id in member_ids:
			if not state._squad_talents_enabled(side, id): continue
			var member: OperatorData = state._operator_data[id]
			if member.talent_1.effect_type=="low_cost_healing_aura":
				for ally in state.units:
					if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
					var ally_data: OperatorData=state._operator_data[ally.operator_id]
					if ally.hp>0 and ally.side==side and ally_data.profession_id!="summon" and ally_data.initial_deploy_cost>=0 and ally_data.initial_deploy_cost<=int(member.talent_1.effect_params["cost_threshold"]):ally.healing_received_bonus_percent=maxi(ally.healing_received_bonus_percent,int(member.talent_1.effect_params["heal_percent"]))
			if member.talent_1.effect_type=="profession_health_aura":
				for ally in state.units:
					if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
					if ally.side==side and ally.hp>0 and state._operator_data[ally.operator_id].profession_id==member.talent_1.effect_params["profession_id"]:ally.max_health_bonus_percent+=int(member.talent_1.effect_params["health_percent"])
			var group_talent := member.talent_1 if member.talent_1.effect_type=="group_attack_aura" else member.talent_2
			if group_talent.effect_type != "group_attack_aura": continue
			for ally in state.units:
				if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
				if ally.side == side and ally.hp > 0 and state._operator_data[ally.operator_id].group_id == group_talent.effect_params["group_id"]:
					ally.attack_bonus_percent += int(group_talent.effect_params["attack_percent"])
	TacticianRules.refresh(state)
	SentinelRules.refresh(state)
	Mon3trRules.refresh_buffs(state)
	for source in state.units:
		if source.hp <= 0 or source.silence_ticks_left > 0:
			continue
		var source_data: OperatorData = state._operator_data[source.operator_id]
		if source_data.talent_1.effect_type=="health_attack_speed":source.attack_speed_bonus+=source.musha_attack_speed
		if source_data.talent_2.effect_type=="defense_dodge":source.defense_bonus_percent+=int(source_data.talent_2.effect_params["defense_percent"])
		if source_data.talent_2.effect_type=="wounded_enemy_attack":
			for enemy in state.units:
				if enemy.hp>0 and enemy.side!=source.side and enemy.hp*100<SkillRules.max_health_value(enemy,state._operator_data[enemy.operator_id])*int(source_data.talent_2.effect_params["hp_threshold_percent"]) and state._is_in_attack_range(source,enemy.cell,AttackRange.effective_offsets(source,source_data)):
					source.attack_bonus_percent+=int(source_data.talent_2.effect_params["attack_percent"]);break
		var first := source_data.talent_1
		if first.effect_type=="unblocked_atk_def" and not CliffheartRules.is_blocking(state,source):
			source.attack_bonus_percent+=int(first.effect_params["attack_percent"])
			source.defense_bonus_percent+=int(first.effect_params["defense_percent"])
		if first.effect_type=="deployment_fortune":
			if source.fortune_choice==0:source.attack_bonus_percent+=int(first.effect_params["attack_percent"])
			elif source.fortune_choice==1:source.attack_speed_bonus+=int(first.effect_params["attack_speed_add"])
			elif source.fortune_choice==2:source.max_health_bonus_percent+=int(first.effect_params["health_percent"])
		if source_data.talent_2.effect_type=="self_magic_resist":source.magic_resist_bonus+=int(source_data.talent_2.effect_params["magic_resist_add"])
		if first.effect_type=="explorer":source.defense_bonus_percent-=int(first.effect_params["defense_reduce_percent"]);source.attack_speed_bonus+=int(first.effect_params["attack_speed_add"])
		var launch_skill := source_data.skills[source.skill_index]
		if SkillRules.active_ticks(source)>0:
			for target in state.units:
				if target.hp<=0:continue
				var target_data: OperatorData=state._operator_data[target.operator_id]
				if launch_skill.effect_type=="zima_warcry" and target.side==source.side and target_data.profession_id=="vanguard":target.attack_bonus_percent+=int(launch_skill.effect_params["attack_percent"]);target.defense_bonus_percent+=int(launch_skill.effect_params["defense_percent"])
				if target.side==source.side or not state._is_in_attack_range(source,target.cell,AttackRange.effective_offsets(source,source_data)):continue
				if launch_skill.effect_type=="pramanix_echo":target.attack_speed_bonus-=int(launch_skill.effect_params["attack_speed_reduce"])
				if launch_skill.effect_type=="pramanix_weaken":target.pramanix_defense_remaining_percent=mini(target.pramanix_defense_remaining_percent,int(launch_skill.effect_params["defense_remaining_percent"]));target.pramanix_resist_remaining_percent=mini(target.pramanix_resist_remaining_percent,int(launch_skill.effect_params["resist_remaining_percent"]))
		if first.effect_type=="abyssal_regeneration":source.max_health_bonus_percent+=int(first.effect_params["health_percent"])
		if first.effect_type=="self_defense":source.defense_bonus_percent+=int(first.effect_params["defense_percent"])
		var nian_skill := source_data.skills[source.skill_index]
		if SkillRules.active_ticks(source)>0 and nian_skill.effect_type=="nian_iron":
			for ally in state.units:
				if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
				if ally.hp>0 and ally.side==source.side and ally!=source and state._is_in_attack_range(source,ally.cell,nian_skill.attack_range_override):
					ally.defense_bonus_percent+=int(nian_skill.effect_params["ally_defense_percent"])
					ally.block_bonus=maxi(ally.block_bonus,int(nian_skill.effect_params["ally_block_add"]))
					ally.status_resistance_bonus=1
		if first.effect_type == "enemy_resist_aura":
			for enemy in state.units:
				if enemy.hp > 0 and enemy.side != source.side and state._is_in_attack_range(source,enemy.cell,source_data.attack_range):
					enemy.flame_resist_aura_percent = maxi(enemy.flame_resist_aura_percent,int(first.effect_params["resist_reduce_percent"]))
		if first.effect_type == "rhine_suit":
			var stacks := mini(int(first.effect_params["max_stacks"]), (state.tick - source.deployed_tick) / int(first.effect_params["interval_ticks"]))
			source.attack_bonus_percent += stacks * int(first.effect_params["attack_percent"])
			source.defense_bonus_percent += stacks * int(first.effect_params["defense_percent"])
		if source_data.branch_trait.effect_type == "summoner" and SkillRules.active_ticks(source)>0:
			var skill := source_data.skills[source.skill_index]
			for ally in state.units:
				if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
				if ally.hp<=0 or (ally.unit_id!=source.unit_id and ally.drone_owner_id!=source.unit_id):continue
				if skill.effect_type=="magallan_laser":ally.attack_speed_bonus+=int(skill.effect_params["attack_speed_add"])
				if skill.effect_type=="magallan_artillery":ally.attack_bonus_percent+=int(skill.effect_params["attack_percent"])
		if source_data.talent_2.effect_type=="sword_training":
			source.attack_bonus_percent+=int(source_data.talent_2.effect_params["attack_percent"])
			source.defense_bonus_percent+=int(source_data.talent_2.effect_params["defense_percent"])
		var second := source_data.talent_2
		if first.effect_type == "attack_redeploy_buff":
			source.attack_bonus_percent += int(first.effect_params["attack_percent"])
		if first.effect_type == "attack_speed_buff":
			source.attack_speed_bonus += int(first.effect_params["attack_speed_add"])
		if second.effect_type == "attack_speed_buff":
			source.attack_speed_bonus += int(second.effect_params["attack_speed_add"])
		if first.effect_type == "flag_attack_speed_aura":
			for target in state.units:
				var offset := target.cell - SkillRules.flag_position(source)
				if target.hp > 0 and target.unit_id != source.unit_id and offset != Vector2i.ZERO and absi(offset.x) <= 1 and absi(offset.y) <= 1:
					target.attack_speed_bonus += int(first.effect_params["ally_attack_speed_add"]) if target.side == source.side else -int(first.effect_params["enemy_attack_speed_reduce"])
		if second.effect_type == "random_blessing":
			if source.blessing_target_id == -1:
				var candidates: Array[UnitState] = []
				for ally in state.units:
					if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
					if ally.side == source.side and ally.unit_id != source.unit_id and ally.hp > 0 and ally.operator_id != "weedy_cannon":
						candidates.append(ally)
				if not candidates.is_empty():
					source.blessing_target_id = candidates[state.rng.next_u32() % candidates.size()].unit_id
			for ally in state.units:
				if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
				if ally.unit_id == source.unit_id or ally.unit_id == source.blessing_target_id:
					ally.attack_bonus_percent += int(second.effect_params["attack_percent"])
					ally.max_health_bonus_percent += int(second.effect_params["max_health_percent"])
		if second.effect_type == "isolated_buff":
			var isolated := true
			for ally in state.units:
				if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
				if ally.side == source.side and ally.unit_id != source.unit_id and ally.hp > 0 and absi(ally.cell.x - source.cell.x) + absi(ally.cell.y - source.cell.y) <= 1:
					isolated = false
					break
			if isolated:
				source.attack_bonus_percent += int(second.effect_params["attack_percent"])
				source.attack_speed_bonus += int(second.effect_params["attack_speed_add"])
		var crossfire_active := false
		if second.effect_type == "sniper_crossfire":
			for ally in state.units:
				if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
				var ally_data: OperatorData = state._operator_data[ally.operator_id]
				if ally.hp > 0 and ally.side == source.side and ally.unit_id != source.unit_id and ally_data.profession_id == second.effect_params["profession_id"]:
					crossfire_active = true
					break
		for ally in state.units:
			if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
			if ally.side != source.side or ally.hp <= 0:
				continue
			var ally_data: OperatorData = state._operator_data[ally.operator_id]
			if crossfire_active and ally_data.profession_id == second.effect_params["profession_id"]:
				ally.attack_bonus_percent += int(second.effect_params["attack_percent"])
			if first.effect_type=="global_sp_recharge":ally.sp_recharge_bonus_percent=maxi(ally.sp_recharge_bonus_percent,int(first.effect_params["sp_recharge_bonus_percent"]))
			if first.effect_type=="low_cost_support" and ally_data.deploy_cost<=int(first.effect_params["cost_threshold"]):ally.defense_bonus_percent+=int(first.effect_params["defense_percent"])
			if first.effect_type == "healing_output_aura":ally.healing_output_percent=maxi(ally.healing_output_percent,100+int(first.effect_params["healing_bonus_percent"]))
			if first.effect_type=="profession_attack_speed_aura" and ally_data.profession_id==first.effect_params["profession_id"]:ally.attack_speed_bonus+=int(first.effect_params["attack_speed_add"])
			if first.effect_type == "attack_speed_aura":
				ally.attack_speed_bonus += int(first.effect_params["attack_speed_add"])
			if first.effect_type == "profession_atk_def_aura" and ally_data.profession_id == first.effect_params["profession_id"]:
				ally.attack_bonus_percent += int(first.effect_params["attack_percent"])
				ally.defense_bonus_percent += int(first.effect_params["defense_percent"])
			if first.effect_type == "attack_aura" and ally_data.profession_id == first.effect_params["profession_id"]:
				ally.attack_bonus_percent += int(first.effect_params["attack_percent"])
			if first.effect_type == "sp_recharge_aura" and ally_data.profession_id == first.effect_params["profession_id"]:
				ally.sp_recharge_bonus_percent = maxi(ally.sp_recharge_bonus_percent, int(first.effect_params["sp_recharge_bonus_percent"]))
			if first.effect_type == "magic_resist_aura" and state._is_in_attack_range(source, ally.cell, ATTACK_RANGE.effective_offsets(source, source_data)):
				ally.magic_resist_bonus += int(first.effect_params["magic_resist_add"])
			if first.effect_type == "defense_flat_aura" and state._is_in_attack_range(source, ally.cell, source_data.attack_range):
				ally.defense_bonus_add += int(first.effect_params["defense_add"])
			if source.skill_ticks_left > 0 and source_data.skills[source.skill_index].effect_type == "heal_defense_aura" and state._is_in_attack_range(source, ally.cell, ATTACK_RANGE.effective_offsets(source, source_data)):
				ally.skill_defense_bonus_percent = maxi(ally.skill_defense_bonus_percent, int(source_data.skills[source.skill_index].effect_params["defense_percent"]))
			if source.skill_ticks_left > 0 and source_data.skills[source.skill_index].effect_type == "heal_magic_aura" and state._is_in_attack_range(source, ally.cell, ATTACK_RANGE.effective_offsets(source, source_data)):
				var params := source_data.skills[source.skill_index].effect_params
				ally.magic_resist_bonus_percent = maxi(ally.magic_resist_bonus_percent, int(params["magic_resist_percent"]))
				ally.dodge_magical_bonus = maxi(ally.dodge_magical_bonus, int(params["dodge_magical_add"]))
			if source.skill_ticks_left > 0 and source_data.skills[source.skill_index].effect_type == "flag_heal" and ally.cell == source.flag_cell and ally_data.profession_id != "summon":
				ally.flag_defense_bonus_percent = maxi(ally.flag_defense_bonus_percent,int(source_data.skills[source.skill_index].effect_params["defense_percent"]))
			if second.effect_type == "defense_aura" and ally_data.profession_id == second.effect_params["profession_id"]:
				ally.defense_bonus_percent += int(second.effect_params["defense_percent"])
	VanguardDefenderRules.refresh(state)
	InesRules.refresh(state)
	LeeRules.refresh_buffs(state)
	MonstrMedicRules.refresh(state)
	LingRules.refresh_auras(state)
	TitiRules.refresh_auras(state)
	GuardSpecialistRules.refresh_auras(state)
	MedicAlterRules.refresh_auras(state)
	ChenAlterRules.refresh(state)
	ClassicTacticalRules.refresh_buffs(state)
	BardRules.refresh_buffs(state)
	StainlessRules.refresh(state)
	TacticalRules.refresh_support(state)
	for index in state.units.size():
		var unit := state.units[index]
		var data: OperatorData = state._operator_data[unit.operator_id]
		var new_max := SkillRules.max_health_value(unit, data)
		if unit.hp > 0 and new_max != old_health[index]:
			unit.hp = maxi(1, roundi(float(unit.hp) * new_max / old_health[index]))
		var interval := SkillRules.attack_interval_ticks(unit, data)
		if interval != old_intervals[index]:
			if not AttackTimeline.uses_start_clock(unit):
				unit.attack_ticks_left = ceili(float(unit.attack_ticks_left) * interval / old_intervals[index])

	LinRules.refresh_shields(state)
	PallasRules.refresh_buffs(state)
