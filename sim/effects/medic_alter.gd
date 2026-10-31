class_name MedicAlterRules
extends RefCounted

const IDS := ["reed_alter","eyjafjalla_alter"]


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	SkillRules.activate(unit,data)
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="reed_fireballs":
		unit.reed_fireball_started_tick=state.tick
		unit.reed_fireball_carriers.clear();unit.reed_fireball_ready_ticks.clear()
		var candidates: Array[UnitState]=[]
		for ally in state.units:
			if ally.hp>0 and ally.side==unit.side and state._operator_data[ally.operator_id].profession_id!="summon" and state._is_in_attack_range(unit,ally.cell,data.attack_range):candidates.append(ally)
		candidates.sort_custom(func(a: UnitState,b: UnitState)->bool:
			var ag := state.terrain_at(a.cell)=="ground";var bg := state.terrain_at(b.cell)=="ground"
			return ag if ag!=bg else a.unit_id>b.unit_id)
		for ally in candidates.slice(0,int(skill.effect_params["target_count"])):
			unit.reed_fireball_carriers.append(ally.unit_id)
			for ball in int(skill.effect_params["ball_count"]):unit.reed_fireball_ready_ticks.append(state.tick)
	elif skill.effect_type=="eyja_elemental_barrier":
		unit.skill_ticks_left=0
		unit.eyja_elemental_barrier=roundi(SkillRules.attack_value(unit,data)*int(skill.effect_params["elemental_barrier_attack_percent"])/100.0)
		unit.eyja_elemental_barrier_until_tick=state.tick+int(skill.effect_params["barrier_ticks"])
		for ally in state.units:
			if ally.side==unit.side and LumenRules.can_heal(state,ally) and state._is_in_attack_range(unit,ally.cell,data.attack_range):heal(state,unit,ally,Combat.calculate_healing(SkillRules.attack_value(unit,data)),false)
	AuraRules.refresh(state)


static func global_healing(unit: UnitState, data: OperatorData) -> bool:
	return SkillRules.active_ticks(unit)!=0 and data.skills[unit.skill_index].effect_type=="eyja_volcano"


static func candidates(state: MatchState, source: UnitState, global_range: bool) -> Array[UnitState]:
	var result: Array[UnitState]=[]
	var data: OperatorData=state._operator_data[source.operator_id]
	for ally in state.units:
		if ally.side==source.side and LumenRules.can_heal(state,ally) and ally.hp<SkillRules.max_health_value(ally,state._operator_data[ally.operator_id]) and (global_range or state._is_in_attack_range(source,ally.cell,data.attack_range)):result.append(ally)
	result.sort_custom(func(a: UnitState,b: UnitState)->bool:
		var am := SkillRules.max_health_value(a,state._operator_data[a.operator_id]);var bm := SkillRules.max_health_value(b,state._operator_data[b.operator_id])
		return a.unit_id<b.unit_id if a.hp*bm==b.hp*am else a.hp*bm<b.hp*am)
	return result


static func heal(state: MatchState, source: UnitState, target: UnitState, amount: int, ordinary: bool) -> void:
	if not LumenRules.can_heal(state,target):return
	var data: OperatorData=state._operator_data[source.operator_id]
	LumenRules.treat_amount(state,target,amount,source)
	if source.silence_ticks_left>0:return
	if data.talent_2.effect_type=="reed_reflected_heal" and target!=source:
		# This is half of the unscaled event, after the shared healing factor once.
		LumenRules.treat_amount(state,source,roundi(amount*int(data.talent_2.effect_params["heal_percent"])/100.0),source)
	if ordinary and data.talent_1.effect_type=="eyja_mist":
		target.eyja_mist_stacks=mini(int(data.talent_1.effect_params["max_stacks"]),target.eyja_mist_stacks+1)
		target.eyja_mist_until_tick=state.tick+int(data.talent_1.effect_params["duration_ticks"])
		if target.eyja_mist_next_tick<=state.tick:target.eyja_mist_next_tick=state.tick+state.CONFIG.TICK_RATE
		target.eyja_mist_heal=roundi(amount*int(data.talent_1.effect_params["heal_percent"])/100.0)
		target.eyja_mist_source_id=source.unit_id


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.trigger_type=="auto" and SkillRules.can_activate(unit,skill):cast(state,unit,data)
	if not AttackTimeline.advance(state,unit):return
	if unit.operator_id=="eyjafjalla_alter":
		var global_range := global_healing(unit,data)
		var lock_count:=int(skill.effect_params.heal_count) if global_range else (int(skill.effect_params.target_count) if SkillRules.active_ticks(unit)!=0 and skill.effect_type=="eyja_permanent" else 1)
		var targets := candidates(state,unit,global_range).slice(0,lock_count)
		targets=AttackTimeline.pinned(state,unit,targets)
		if targets.is_empty():return
		if not AttackTimeline.windup(state,unit,data,targets,targets[0].cell,true):return
		unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
		PusherRules.mark_attack(state,unit,targets[0].cell);unit.last_attack_is_heal=true
		var count := int(skill.effect_params["heal_count"]) if global_range else (int(skill.effect_params["target_count"]) if SkillRules.active_ticks(unit)!=0 and skill.effect_type=="eyja_permanent" else 1)
		var locked:=targets.duplicate()
		var visited := PackedInt32Array()
		for index in count:
			targets=candidates(state,unit,global_range).filter(func(ally: UnitState)->bool:return ally in locked)
			if targets.is_empty():break
			if not global_range and index>=targets.size()+visited.size():break
			var target: UnitState
			for ally in targets:
				if ally.unit_id not in visited:target=ally;break
			if target==null:
				if not global_range:break
				target=targets[0]
			visited.append(target.unit_id)
			heal(state,unit,target,Combat.calculate_healing(SkillRules.attack_value(unit,data),int(skill.effect_params["heal_percent"]) if global_range else 100),true)
		return
	var targets := PusherRules.targets(state,unit,data.attack_range,false)
	targets=AttackTimeline.pinned(state,unit,targets)
	var center := targets[0].cell if not targets.is_empty() else ClassicOperatorRules.target_cell(state,unit,data.attack_range)
	if center.x<0:return
	if not AttackTimeline.windup(state,unit,data,targets,center):return
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data);PusherRules.mark_attack(state,unit,center)
	var count := int(skill.effect_params["target_count"]) if SkillRules.active_ticks(unit)!=0 and skill.effect_type=="reed_lifeseed" else 1
	if not targets.is_empty():
		for target in targets.slice(0,count):
			if unit.hp>0:hit(state,unit,target,SkillRules.attack_value(unit,data),true)
	else:
		var box: TacticalBox
		for candidate in state.tactical_boxes:
			if candidate.cell==center and candidate.hits_left>0:box=candidate;break
		AttackTimeline.generic_projectile(state,unit,data,null,box,center,SkillRules.attack_value(unit,data),"magical")



static func mark(state: MatchState, source: UnitState, target: UnitState, force: bool=false) -> void:
	var data: OperatorData=state._operator_data[source.operator_id]
	if source.hp<=0 or source.silence_ticks_left>0:return
	var active := SkillRules.active_ticks(source)!=0 and data.skills[source.skill_index].effect_type=="reed_lifeseed"
	if not force and not active and state.rng.next_percent()>=int(data.talent_1.effect_params["chance_percent"]):return
	target.reed_cinder_source_id=source.unit_id
	target.reed_cinder_until_tick=state.tick+int(data.talent_1.effect_params["duration_ticks"])
	target.reed_cinder_attack_reduce_percent=int(data.talent_1.effect_params["attack_reduce_percent"])
	target.reed_cinder_magic_fragile_percent=int(data.talent_1.effect_params["magic_fragile_percent"])
	if active:
		target.reed_cinder_until_tick=-1
		target.reed_lifeseed_mark=true
		if target.reed_dot_next_tick<=state.tick:target.reed_dot_next_tick=state.tick+state.CONFIG.TICK_RATE


static func hit(state: MatchState, source: UnitState, target: UnitState, attack_value: int, attack_event: bool, carrier: UnitState=null) -> int:
	var data: OperatorData=state._operator_data[source.operator_id]
	if attack_event:
		AttackTimeline.generic_projectile(state,source,data,target,null,target.cell,attack_value,"magical")
		return 0
	var target_data: OperatorData=state._operator_data[target.operator_id]
	var dodge := SkillRules.dodge_chance(target,target_data,"magical") if attack_event else 0
	if dodge>0 and state.rng.next_percent()<dodge:return 0
	var before := [target.reed_cinder_source_id,target.reed_cinder_until_tick,target.reed_cinder_attack_reduce_percent,target.reed_cinder_magic_fragile_percent,int(target.reed_lifeseed_mark),target.reed_dot_next_tick]
	mark(state,source,target)
	var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"magical",0,state.rng,data.profession_id,state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
	var applied: Array[int]=[0]
	var landed := state._apply_damage(target,target_data,damage,"magical",source,attack_event,applied)
	if not landed:
		target.reed_cinder_source_id=before[0];target.reed_cinder_until_tick=before[1];target.reed_cinder_attack_reduce_percent=before[2];target.reed_cinder_magic_fragile_percent=before[3];target.reed_lifeseed_mark=before[4]==1;target.reed_dot_next_tick=before[5]
		return 0
	var amount := applied[0] if not applied.is_empty() else 0
	if amount>0 and source.hp>0:
		var recipient := carrier
		if recipient==null:
			var allies := candidates(state,source,false)
			if not allies.is_empty():recipient=allies[0]
		if recipient!=null:heal(state,source,recipient,Combat.calculate_healing(amount,int(data.branch_trait.effect_params["heal_damage_percent"])),false)
	return amount


static func on_death(state: MatchState, target: UnitState) -> void:
	if not target.reed_lifeseed_mark or target.reed_explosion_queued:return
	var source := WArtilleryRules.owner(state,target.reed_cinder_source_id)
	if source==null or source.hp<=0 or SkillRules.active_ticks(source)==0:return
	var data: OperatorData=state._operator_data[source.operator_id]
	if data.skills[source.skill_index].effect_type!="reed_lifeseed":return
	target.reed_explosion_queued=true
	var blast := ReedBlast.new()
	blast.source_id=source.unit_id;blast.side=source.side;blast.cell=target.cell
	blast.attack=roundi(SkillRules.attack_value(source,data)*int(data.skills[source.skill_index].effect_params["explosion_attack_percent"])/100.0)
	blast.due_tick=state.tick+int(data.skills[source.skill_index].effect_params["explosion_delay_ticks"])
	state.reed_blasts.append(blast)


static func refresh_auras(state: MatchState) -> void:
	for source in state.units:
		var data: OperatorData=state._operator_data[source.operator_id]
		if source.hp<=0 or source.silence_ticks_left>0 or data.talent_2.effect_type!="eyja_health_aura":continue
		var global_range := global_healing(source,data)
		var multiplier := int(data.skills[source.skill_index].effect_params["talent_multiplier"]) if global_range else 1
		for ally in state.units:
			if state._operator_data[ally.operator_id].branch_trait.effect_type in ["pozyomka_typewriter","silence_drone"]:continue
			if ally.side==source.side and ally.hp>0 and (global_range or state._is_in_attack_range(source,ally.cell,data.attack_range)):
				ally.max_health_bonus_percent+=int(data.talent_2.effect_params["health_percent"])*multiplier


static func advance(state: MatchState) -> void:
	for target in state.units.duplicate():
		if target.eyja_elemental_barrier_until_tick>0 and state.tick>=target.eyja_elemental_barrier_until_tick:target.eyja_elemental_barrier=0;target.eyja_elemental_barrier_until_tick=0
		if target.reed_cinder_source_id>=0:
			var source := WArtilleryRules.owner(state,target.reed_cinder_source_id)
			if source==null or source.hp<=0 or (target.reed_lifeseed_mark and (source.skill_ticks_left==0)) or (target.reed_cinder_until_tick>=0 and state.tick>=target.reed_cinder_until_tick):
				clear_cinder(target)
			elif target.hp>0 and target.reed_lifeseed_mark and source.silence_ticks_left==0 and state.tick>=target.reed_dot_next_tick:
				target.reed_dot_next_tick+=state.CONFIG.TICK_RATE
				var data: OperatorData=state._operator_data[source.operator_id]
				hit(state,source,target,roundi(SkillRules.attack_value(source,data)*int(data.skills[source.skill_index].effect_params["dot_attack_percent"])/100.0),false)
		if target.hp>0 and target.eyja_mist_stacks>0:
			if state.tick>target.eyja_mist_until_tick:target.eyja_mist_stacks=0;target.eyja_mist_heal=0;target.eyja_mist_source_id=-1
			elif state.tick>=target.eyja_mist_next_tick:
				target.eyja_mist_next_tick+=state.CONFIG.TICK_RATE
				LumenRules.treat_amount(state,target,target.eyja_mist_heal*target.eyja_mist_stacks,WArtilleryRules.owner(state,target.eyja_mist_source_id))
	var pending := state.reed_blasts.duplicate()
	state.reed_blasts.clear()
	for blast in pending:
		var source := WArtilleryRules.owner(state,blast.source_id)
		if source==null or source.hp<=0 or source.skill_ticks_left==0:continue
		if state.tick<blast.due_tick:state.reed_blasts.append(blast);continue
		var skill: SkillResource=state._operator_data[source.operator_id].skills[source.skill_index]
		for enemy in state.units.duplicate():
			if state.enemy_is_targetable(blast.side,enemy) and (enemy.cell-blast.cell).length_squared()<=int(skill.effect_params["explosion_radius_squared"]) and state.tick>=enemy.reed_explosion_immunity_until_tick:
				enemy.reed_explosion_immunity_until_tick=state.tick+int(skill.effect_params["explosion_delay_ticks"])
				hit(state,source,enemy,blast.attack,false)
	for source in state.units:
		var data: OperatorData=state._operator_data[source.operator_id]
		if source.hp<=0 or source.operator_id!="reed_alter":continue
		var skill := data.skills[source.skill_index]
		if source.skill_ticks_left==0 or skill.effect_type!="reed_fireballs":
			source.reed_fireball_carriers.clear();source.reed_fireball_ready_ticks.clear();continue
		if source.silence_ticks_left>0:continue
		for carrier_index in source.reed_fireball_carriers.size():
			var carrier := WArtilleryRules.owner(state,source.reed_fireball_carriers[carrier_index])
			if carrier==null or carrier.hp<=0:continue
			for index in int(skill.effect_params["ball_count"]):
				var slot := carrier_index*int(skill.effect_params["ball_count"])+index
				if state.tick<source.reed_fireball_ready_ticks[slot]:continue
				var phase := (state.tick-source.reed_fireball_started_tick+index*int(skill.effect_params["orbit_ticks"])/int(skill.effect_params["ball_count"]))%int(skill.effect_params["orbit_ticks"])
				var angle := float(phase)*TAU/int(skill.effect_params["orbit_ticks"])
				var center := Vector2(carrier.cell)+Vector2(cos(angle),sin(angle))*int(skill.effect_params["orbit_radius_milli"])/1000.0
				for enemy in state.units:
					if state.enemy_is_targetable(source.side,enemy) and state.terrain_at(enemy.cell)!="high" and Vector2(enemy.cell).distance_squared_to(center)<=pow(float(skill.effect_params["collision_radius_milli"])/1000.0,2):
						if hit(state,source,enemy,roundi(SkillRules.attack_value(source,data)*float(skill.effect_params["fireball_attack_mult"])),false,carrier)>0:source.reed_fireball_ready_ticks[slot]=state.tick+int(skill.effect_params["cooldown_ticks"])
						break


static func clear_cinder(target: UnitState) -> void:
	target.reed_cinder_source_id=-1;target.reed_cinder_until_tick=0;target.reed_cinder_attack_reduce_percent=0;target.reed_cinder_magic_fragile_percent=0;target.reed_lifeseed_mark=false;target.reed_dot_next_tick=0


static func on_exit(state: MatchState, source: UnitState) -> void:
	if source.operator_id!="reed_alter":return
	for target in state.units:
		if target.reed_cinder_source_id==source.unit_id:clear_cinder(target)
	source.reed_fireball_carriers.clear();source.reed_fireball_ready_ticks.clear()
	var alive: Array[ReedBlast]=[]
	for blast in state.reed_blasts:
		if blast.source_id!=source.unit_id:alive.append(blast)
	state.reed_blasts=alive

static func projectile_hit(state: MatchState, shot: AttackProjectile, source: UnitState, target: UnitState) -> void:
	var data: OperatorData=state._operator_data[shot.operator_id]
	var td: OperatorData=state._operator_data[target.operator_id]
	var dodge:=SkillRules.dodge_chance(target,td,"magical")
	if dodge>0 and state.rng.next_percent()<dodge:return
	var previous: Array=[target.reed_cinder_source_id,target.reed_cinder_until_tick,target.reed_cinder_attack_reduce_percent,target.reed_cinder_magic_fragile_percent,int(target.reed_lifeseed_mark),target.reed_dot_next_tick]
	var lifeseed:=shot.active and data.skills[shot.skill_index].effect_type=="reed_lifeseed"
	if source.hp>0 and not shot.silenced and (lifeseed or state.rng.next_percent()<int(data.talent_1.effect_params.chance_percent)):
		target.reed_cinder_source_id=shot.source_id;target.reed_cinder_until_tick=state.tick+int(data.talent_1.effect_params.duration_ticks)
		target.reed_cinder_attack_reduce_percent=int(data.talent_1.effect_params.attack_reduce_percent);target.reed_cinder_magic_fragile_percent=int(data.talent_1.effect_params.magic_fragile_percent)
		if lifeseed:
			target.reed_cinder_until_tick=-1;target.reed_lifeseed_mark=true
			if target.reed_dot_next_tick<=state.tick:target.reed_dot_next_tick=state.tick+state.CONFIG.TICK_RATE
	var damage:=Combat.calculate_damage(shot.attack,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),"magical",0,state.rng,data.profession_id,state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
	var applied: Array[int]=[0]
	if not state._apply_damage(target,td,damage,"magical",source,true,applied):
		target.reed_cinder_source_id=previous[0];target.reed_cinder_until_tick=previous[1];target.reed_cinder_attack_reduce_percent=previous[2];target.reed_cinder_magic_fragile_percent=previous[3];target.reed_lifeseed_mark=previous[4]==1;target.reed_dot_next_tick=previous[5]
		return
	if applied[0]>0 and source.hp>0:
		var allies:=candidates(state,source,false)
		if not allies.is_empty():heal(state,source,allies[0],Combat.calculate_healing(applied[0],int(data.branch_trait.effect_params.heal_damage_percent)),false)
