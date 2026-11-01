class_name StatusRules
extends RefCounted


static func expire_before_commands(state: MatchState, expired_silence_intervals: Dictionary) -> void:
	for unit in state.units:
		if unit.cold_ticks_left==1:expired_silence_intervals[unit.unit_id]=[SkillRules.attack_interval_ticks(unit,state._operator_data[unit.operator_id]),unit.attack_ticks_left]
		unit.cold_ticks_left=maxi(0,unit.cold_ticks_left-1)
		unit.frozen_ticks_left=maxi(0,unit.frozen_ticks_left-1)
		if unit.texas_resist_until_tick>0 and state.tick>=unit.texas_resist_until_tick:unit.texas_resist_remaining_percent=100;unit.texas_resist_until_tick=0
		if unit.weaken_until_tick>=0 and state.tick>=unit.weaken_until_tick:unit.weaken_until_tick=-1;unit.weaken_attack_remaining_percent=100
		if unit.blood_buff_until_tick>=0 and state.tick>=unit.blood_buff_until_tick:unit.blood_buff_until_tick=-1;unit.blood_buff_attack_percent=0;unit.blood_buff_loss_percent=0;unit.blood_buff_next_tick=-1
		if unit.fatal_until_tick>=0 and state.tick>=unit.fatal_until_tick:unit.hp=0
		if unit.speed_debuff_until_tick>=0 and state.tick>=unit.speed_debuff_until_tick:unit.speed_debuff_until_tick=-1;unit.speed_debuff_remaining_percent=100
		unit.shell_ticks_left=maxi(0,unit.shell_ticks_left-1)
		if unit.shell_ticks_left==0:unit.shell_defense_reduce=0
		for index in range(unit.barrier_ticks_left.size() - 1, -1, -1):
			unit.barrier_ticks_left[index] -= 1
			if unit.barrier_ticks_left[index] == 0:
				unit.barrier_hp.remove_at(index)
				unit.barrier_ticks_left.remove_at(index)
				unit.barrier_defense_percent.remove_at(index)
				unit.barrier_magic_only.remove_at(index)
				unit.barrier_magic_resist_add.remove_at(index)
		if unit.silence_ticks_left == 1 and not expired_silence_intervals.has(unit.unit_id):
			expired_silence_intervals[unit.unit_id] = [SkillRules.attack_interval_ticks(unit, state._operator_data[unit.operator_id]), unit.attack_ticks_left]
		if unit.rupture_until_tick > 0 and state.tick >= unit.rupture_until_tick:
			unit.rupture_until_tick = 0
			unit.rupture_source_id = -1
			unit.rupture_damage_per_cell = 0
		unit.sleep_ticks_left=maxi(0,unit.sleep_ticks_left-1)
		unit.destiny_attack_stop_ticks=maxi(0,unit.destiny_attack_stop_ticks-1)
		unit.flame_resist_ticks = maxi(0, unit.flame_resist_ticks - 1)
		if unit.flame_resist_ticks == 0:unit.flame_resist_reduce = 0
		if unit.gravel_ticks_left>0:
			unit.gravel_ticks_left-=1
			var skill: SkillResource=state._operator_data[unit.operator_id].skills[unit.skill_index]
			if skill.effect_type=="gravel_barrier":
				unit.gravel_decay_accum+=unit.gravel_barrier_initial
				var loss := unit.gravel_decay_accum/int(skill.effect_params["decay_ticks"])
				unit.gravel_decay_accum%=int(skill.effect_params["decay_ticks"])
				unit.gravel_barrier_hp=maxi(0,unit.gravel_barrier_hp-loss)
		unit.lumen_resistance_ticks=maxi(0,unit.lumen_resistance_ticks-1)
		unit.saga_focus_ticks=maxi(0,unit.saga_focus_ticks-1)
		if unit.critical_ticks_left>0:
			unit.critical_ticks_left-=1
			if unit.critical_ticks_left==0:unit.hp=0;WArtilleryRules.on_exit(state,unit)
		unit.silence_ticks_left = maxi(0, unit.silence_ticks_left - 1)
		unit.flag_landing_ticks_left = maxi(0, unit.flag_landing_ticks_left - 1)
		unit.aak_buff_ticks=maxi(0,unit.aak_buff_ticks-1)
		unit.stun_ticks_left = maxi(0, unit.stun_ticks_left - 1)
		unit.displacement_ticks_left = maxi(0, unit.displacement_ticks_left - 1)
		unit.physical_guard_ticks_left = maxi(0, unit.physical_guard_ticks_left - 1)
		if unit.physical_guard_ticks_left == 0:
			unit.physical_shield_hp = 0


static func restore_silence_intervals(state: MatchState, expired_silence_intervals: Dictionary) -> void:
	for unit in state.units:
		if expired_silence_intervals.has(unit.unit_id):
			var previous: Array = expired_silence_intervals[unit.unit_id]
			if not AttackTimeline.uses_start_clock(unit):
				unit.attack_ticks_left = ceili(float(previous[1]) * SkillRules.attack_interval_ticks(unit, state._operator_data[unit.operator_id]) / int(previous[0]))


static func regenerate(state: MatchState) -> void:
	LingRules.advance(state)
	TitiRules.advance(state)
	GuardSpecialistRules.advance(state)
	TacticianRules.advance(state)
	SentinelRules.maintain(state)
	VanguardDefenderRules.advance(state)
	FiammettaRules.advance_explosions(state)
	GoldenglowRules.advance_released(state)
	SilenceAlterRules.regenerate(state)
	InesRules.advance(state)
	TexasAlterRules.advance(state)
	PenanceRules.pulse(state)
	BlemishineRules.regenerate(state)
	PhalanxRules.maintain(state)
	ArchettoRules.advance(state)
	ThornsRules.regenerate(state)
	ClassicOperatorRules.regenerate(state)
	LaunchOperatorRules.poison(state)
	BardRules.regenerate(state)
	SagaRules.regenerate(state)
	MushaRules.regenerate(state)
	for unit in state.units:
		if unit.hp <= 0 or unit.critical_ticks_left>0:
			continue
		var data: OperatorData = state._operator_data[unit.operator_id]
		if data.branch_trait.effect_type == "phantom":
			unit.life_loss_ticks += 1
			if unit.life_loss_ticks == state.CONFIG.TICK_RATE:
				unit.life_loss_ticks = 0
				unit.hp -= roundi(SkillRules.max_health_value(unit, data) * int(data.branch_trait.effect_params["life_loss_percent"]) / 100.0)
				unit.last_damage_tick = state.tick
		if data.branch_trait.effect_type=="geek":
			unit.life_loss_ticks+=1
			if unit.life_loss_ticks==state.CONFIG.TICK_RATE:
				unit.life_loss_ticks=0
				unit.hp=maxi(1,unit.hp-roundi(SkillRules.max_health_value(unit,data)*int(data.branch_trait.effect_params["life_loss_percent"])/100.0))
				unit.last_damage_tick=state.tick
		var recovery := 0
		var skill_recovery := 0
		if unit.silence_ticks_left==0 and data.talent_1.effect_type=="abyssal_regeneration":skill_recovery+=SkillRules.max_health_value(unit,data)*int(data.talent_1.effect_params["regen_health_percent"])
		for source in state.units:
			var source_data: OperatorData = state._operator_data[source.operator_id]
			if source.side==unit.side and source.hp>0 and source.silence_ticks_left==0 and source_data.talent_1.effect_type=="global_attack_regeneration":skill_recovery+=SkillRules.attack_value(source,source_data)*int(source_data.talent_1.effect_params["regen_attack_percent"])
			if source.side == unit.side and source.hp > 0 and source.silence_ticks_left == 0 and source_data.talent_1.effect_type == "profession_regeneration" and data.profession_id == source_data.talent_1.effect_params["profession_id"]:
				recovery += int(source_data.talent_1.effect_params["heal_per_second"])
			if source.side == unit.side and source.hp > 0 and source.silence_ticks_left == 0 and source.skill_ticks_left == 0 and source_data.talent_2.effect_type == "inactive_regen_aura":
				recovery += int(source_data.talent_2.effect_params["heal_per_second"])
			if source.side == unit.side and source.hp > 0 and SkillRules.active_ticks(source) > 0 and source_data.skills[source.skill_index].effect_type == "foxfire_aura" and state._is_in_attack_range(source, unit.cell, state.ATTACK_RANGE.effective_offsets(source, source_data)):
				skill_recovery += source.skill_regen_attack * int(source_data.skills[source.skill_index].effect_params["regen_attack_percent"])
			if source.side == unit.side and source.hp > 0 and SkillRules.active_ticks(source) > 0 and source_data.skills[source.skill_index].effect_type == "flag_heal" and unit.cell == source.flag_cell and data.profession_id != "summon":
				skill_recovery += SkillRules.attack_value(source,source_data) * int(source_data.skills[source.skill_index].effect_params["regen_attack_percent"])
		var active_skill := data.skills[unit.skill_index]
		if SkillRules.active_ticks(unit)>0 and active_skill.effect_type=="cuora_shell":skill_recovery+=SkillRules.max_health_value(unit,data)*int(active_skill.effect_params["regen_health_percent"])
		if SkillRules.active_ticks(unit) == -2 and active_skill.effect_type == "stance_defense_regen":
			skill_recovery += SkillRules.max_health_value(unit, data) * int(active_skill.effect_params["regen_health_percent"])
		if unit.hp > 0 and skill_recovery > 0:
			unit.skill_hp_regen_accum += skill_recovery * state.CONFIG.UNIT_HEAL_PERCENT
			var healed := unit.skill_hp_regen_accum / (state.CONFIG.TICK_RATE * 10000)
			unit.skill_hp_regen_accum %= state.CONFIG.TICK_RATE * 10000
			if healed > 0 and unit.hp < SkillRules.max_health_value(unit, data):
				unit.hp = mini(SkillRules.max_health_value(unit, data), unit.hp + healed)
				unit.last_heal_tick = state.tick
		if unit.hp > 0 and recovery > 0:
			unit.hp_regen_accum += recovery * state.CONFIG.UNIT_HEAL_PERCENT
			var healed := unit.hp_regen_accum / (state.CONFIG.TICK_RATE * 100)
			unit.hp_regen_accum %= state.CONFIG.TICK_RATE * 100
			if healed > 0 and unit.hp < SkillRules.max_health_value(unit, data):
				unit.hp = mini(SkillRules.max_health_value(unit, data), unit.hp + healed)
				unit.last_heal_tick = state.tick


static func expire_skills(state: MatchState) -> bool:
	var defense_aura_expired := false
	for unit in state.units:
		if unit.skill_ticks_left==1 and unit.operator_id=="eunectes" and unit.skill_index==2:SwordRules.stun(state,unit,int(state._operator_data[unit.operator_id].skills[unit.skill_index].effect_params["end_stun_ticks"]),unit)
		if unit.skill_ticks_left==1 and unit.operator_id=="gnosis":GnosisRules.finish(state,unit,state._operator_data[unit.operator_id])
		if unit.skill_ticks_left==1 and unit.operator_id=="silence_alter":SilenceAlterRules.remove_owned(state,unit)
		if unit.skill_ticks_left==1 and state._operator_data[unit.operator_id].skills[unit.skill_index].effect_type=="heavy_bind_volley":ClassicTacticalRules.close_links(state,unit)
		unit.hp_lock_ticks_left = maxi(0, unit.hp_lock_ticks_left - 1)
		if unit.skill_ticks_left > 0:
			var operator := state._operator_data[unit.operator_id] as OperatorData
			var old_interval := SkillRules.attack_interval_ticks(unit, operator)
			if operator.skills[unit.skill_index].effect_type not in ["ramp_burst", "fortress_overload"]:
				unit.skill_elapsed_ticks += 1
			if unit.skill_ticks_left==1 and state._operator_data[unit.operator_id].skills[unit.skill_index].effect_type=="ptilopsis_healing":unit.ptilopsis_end_tick=state.tick
			if unit.skill_ticks_left==1 and operator.skills[unit.skill_index].effect_type=="cuora_shell":unit.cuora_end_tick=state.tick
			unit.skill_ticks_left -= 1
			if unit.skill_ticks_left == 0:
				if unit.operator_id=="ling":LingRules.finish(state,unit,operator)
				if unit.operator_id=="titi":TitiRules.finish(state,unit,operator)
				if unit.operator_id in GuardSpecialistRules.IDS:GuardSpecialistRules.finish(state,unit,operator)
				if operator.talent_1.effect_type=="encore_sp":SoraRules.encore(state,unit,operator)
				if operator.skills[unit.skill_index].effect_type=="caster_destiny" and unit.hp>0:unit.destiny_attack_stop_ticks=int(operator.skills[unit.skill_index].effect_params["end_attack_stop_ticks"])
				if unit.operator_id in LaunchOperatorRules.IDS:
					unit.launch_end_tick=state.tick;unit.liskarm_shield_ready=false
					var effect := operator.skills[unit.skill_index].effect_type
					if effect in ["amiya_burst","liskarm_arc"] and unit.hp>0:SwordRules.stun(state,unit,int(operator.skills[unit.skill_index].effect_params["end_stun_ticks"]))
					if effect=="amiya_chimera":unit.amiya_retreat_pending=true;defense_aura_expired=true
				if operator.skills[unit.skill_index].effect_type=="specter_survival" and unit.hp>0:SwordRules.stun(state,unit,int(operator.skills[unit.skill_index].effect_params["end_stun_ticks"]))
				if operator.skills[unit.skill_index].effect_type=="kaltsit_meltdown":Mon3trRules.finish_meltdown(state,unit,operator.skills[unit.skill_index])
				if operator.operator_id=="magallan":DroneRules.remove_owned(state,unit,unit.hp>0)
				if unit.operator_id=="mon3tr_operator" and MonstrMedicRules.transformed(unit):MonstrMedicRules.finish(state,unit)
				defense_aura_expired = defense_aura_expired or operator.skills[unit.skill_index].effect_type in ["lin_shelter","bard_sleep","bard_song","kaltsit_guard", "kaltsit_tactical", "kaltsit_meltdown", "nian_iron", "heal_defense_aura", "heal_magic_aura", "flag_heal", "flag_burst"]
				unit.skill_elapsed_ticks = 0
				unit.flag_cell = Vector2i(-1,-1)
				unit.flag_burst_pending = false
				unit.flag_landing_ticks_left = 0
				unit.skill_regen_attack = 0
				if not AttackTimeline.uses_start_clock(unit):
					unit.attack_ticks_left = ceili(float(unit.attack_ticks_left) * SkillRules.attack_interval_ticks(unit, operator) / old_interval)
	LaunchOperatorRules.finish_retreats(state)
	return defense_aura_expired


static func apply_silence(state: MatchState, target: UnitState, duration: int) -> void:
	if target.titi_doze_owner_id>=0:return
	var data: OperatorData = state._operator_data[target.operator_id]
	if data.branch_trait.effect_type in ["stainless_device_1","stainless_device_2","stainless_device_3","pozyomka_typewriter","silence_drone","curse_doll","medical_drone","seaborn","water_cannon"] or target.chen_slashes_left>0: return
	var old_interval := SkillRules.attack_interval_ticks(target, data)
	var old_remaining := target.attack_ticks_left
	target.silence_ticks_left = maxi(target.silence_ticks_left, duration)
	AuraRules.refresh(state)
	LumenRules.emergency(state,target)
	if not AttackTimeline.uses_start_clock(target):
		target.attack_ticks_left = ceili(float(old_remaining) * SkillRules.attack_interval_ticks(target, data) / old_interval)


static func has_resistance(state: MatchState, unit: UnitState) -> bool:
	if GnosisRules.has_group_resistance(state,unit):return true
	if unit.status_resistance_bonus>0 or unit.lumen_resistance_ticks>0:return true
	var data: OperatorData=state._operator_data[unit.operator_id]
	return unit.silence_ticks_left==0 and data.talent_2.effect_type=="status_resistance" and state.tick-unit.deployed_tick>=int(data.talent_2.effect_params["warmup_seconds"])*state.CONFIG.TICK_RATE


# Shared ordinary attack/heal clock. Independent skill effects run before this gate.
# Sleep/displacement freeze the clock; stun/bind suppress attacks while it counts down.
static func advance_basic_attack(unit: UnitState) -> bool:
	if unit.titi_doze_owner_id>=0:return false
	if unit.sleep_ticks_left > 0 or unit.displacement_ticks_left > 0:
		return false
	unit.attack_ticks_left = maxi(0, unit.attack_ticks_left - 1)
	return unit.frozen_ticks_left==0 and unit.stun_ticks_left == 0 and unit.bind_ticks_left == 0 and unit.attack_ticks_left == 0


static func advance_controls(unit: UnitState) -> void:
	unit.bind_immunity_ticks_left = maxi(0, unit.bind_immunity_ticks_left - 1)
	if unit.bind_ticks_left > 0:
		unit.bind_ticks_left -= 1
		if unit.bind_ticks_left == 0:
			unit.bind_link_owner_id=-1
			unit.bind_immunity_ticks_left = SkillRules.CONFIG.BIND_IMMUNITY_TICKS
	unit.slow_ticks_left = maxi(0, unit.slow_ticks_left - 1)


static func interrupt_basic(state: MatchState, target: UnitState) -> void:
	if target.attack_intent!=null and target.attack_action_triggered and target.skill_ticks_left==-1:target.skill_ticks_left=0
	target.attack_intent=null
	target.last_basic_interrupt_tick = state.tick
	if target.rain_arrows_left > 0:
		target.rain_arrows_left = 0
		var data: OperatorData = state._operator_data[target.operator_id]
		if data.skills[target.skill_index].effect_type == "marked_arrow_rain" and target.skill_ammo_left == 0:
			SiegeRules.close_skill(target, data)


static func add_control(state: MatchState, target: UnitState, kind: String, duration: int, source: UnitState = null) -> void:
	if target.titi_doze_owner_id>=0:return
	if target.flow_point_until_tick>0:return
	if duration<=0 or target.hp<=0 or state._operator_data[target.operator_id].branch_trait.effect_type in ["stainless_device_1","stainless_device_2","stainless_device_3","silence_drone","pozyomka_typewriter","medical_drone","curse_doll"]:return
	if LeeRules.before_control(state,target,kind,source):return
	match kind:
		"cold":
			var old_interval := SkillRules.attack_interval_ticks(target,state._operator_data[target.operator_id])
			if target.cold_ticks_left>0 or target.frozen_ticks_left>0:
				if LeeRules.before_control(state,target,"frozen",source):return
				target.cold_ticks_left=0;target.frozen_ticks_left=maxi(target.frozen_ticks_left,duration)
			else:target.cold_ticks_left=duration
			GnosisRules.extend_frozen(state,target)
			if not AttackTimeline.uses_start_clock(target):
				target.attack_ticks_left=ceili(float(target.attack_ticks_left)*SkillRules.attack_interval_ticks(target,state._operator_data[target.operator_id])/old_interval)
		"frozen":
			target.cold_ticks_left=0;target.frozen_ticks_left=maxi(target.frozen_ticks_left,duration)
			GnosisRules.extend_frozen(state,target)
		"sleep":
			if state._operator_data[target.operator_id].branch_trait.effect_type in ["water_cannon","seaborn"] or target.chen_slashes_left>0:return
			if target.sleep_ticks_left==0:
				interrupt_basic(state,target)
				if not AttackTimeline.uses_start_clock(target):
					target.attack_ticks_left=SkillRules.attack_interval_ticks(target,state._operator_data[target.operator_id])
			target.sleep_ticks_left=maxi(target.sleep_ticks_left,duration)
		"stun":target.stun_ticks_left=maxi(target.stun_ticks_left,duration)
		"bind":
			if target.bind_ticks_left > 0 or target.bind_immunity_ticks_left > 0:return
			target.bind_ticks_left = duration
			interrupt_basic(state, target)
		"slow":
			target.slow_ticks_left = maxi(target.slow_ticks_left, duration)
			if state.tick >= target.slow_next_interrupt_tick:
				interrupt_basic(state, target)
				var data: OperatorData = state._operator_data[target.operator_id]
				target.attack_ticks_left += mini(state.CONFIG.SLOW_INTERRUPT_DELAY_TICKS, SkillRules.attack_interval_ticks(target, data))
				if AttackTimeline.uses_start_clock(target):target.attack_next_ready_tick+=mini(state.CONFIG.SLOW_INTERRUPT_DELAY_TICKS, SkillRules.attack_interval_ticks(target,data))
				target.slow_next_interrupt_tick = state.tick + state.CONFIG.SLOW_INTERRUPT_COOLDOWN_TICKS
		_:assert(false,"Unknown internal control kind")
	if target.attack_intent!=null and (target.stun_ticks_left>0 or target.frozen_ticks_left>0 or target.sleep_ticks_left>0):
		interrupt_basic(state,target)
	LumenRules.emergency(state,target)
