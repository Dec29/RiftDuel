class_name AttackTimeline
extends RefCounted

const IDS := ["surtr","exusiai","skadi","jessica"]
const ADAPTED_IDS := ["zima","projekt_red","wildmane","eunectes","gavial_alter","mlynar","flametail","elysium","mudrock","feater","gummy","mountain","mizuki","siege","texas","hellagur","specter","liskarm","blue_poison","amiya","skyfire","istina","pramanix","pallas","penance","blemishine","lee","texas_alter","mon3tr","ling_soul1","ling_soul3","vigil_wolf","phantom_clone","shining","nightingale","ptilopsis","perfumer","sussurro","silence","warfarin","kaltsit","lumen","bagpipe","angelina","blaze","ceobe","hoshiguma","nian","phantom","saileach","silverash","suzuran","swire_alter","magallan","platinum","haze","lappland","cuora","eyjafjalla","gravel","schwarz","ines","muelsyse","flowing_shape","stainless","stainless_cannon","vigil","dusk","dusk_freeling","goldenglow","pozyomka","pozyomka_typewriter","fiammetta","reed_alter","mon3tr_operator","silence_alter","gnosis","archetto","cliffheart","saga","typhon","meteorite","thorns","carnelian","lin","chen","gladiia","shaw","aak","chen_alter","eyjafjalla_alter","gitano","horn","ifrit","jessica_alter","ling","ling_soul2","magallan_drone_a","magallan_drone_l","mostima","myrtle","passenger","podenco","rosa","shamare","titi","w","weedy","weedy_cannon","nearl","saria"]
const GENERIC_RANGED_IDS := ["angelina","ceobe","suzuran","magallan","platinum","haze","schwarz","eyjafjalla","ling","horn"]

static func begin(state: MatchState, unit: UnitState, data: OperatorData, targets: Array[UnitState], box: TacticalBox, ball: bool, healing: bool=false) -> void:
	assert(unit.attack_intent==null)
	var intent:=AttackIntent.new()
	intent.kind=AttackIntent.TargetKind.HEAL if healing else (AttackIntent.TargetKind.UNIT if not targets.is_empty() else (AttackIntent.TargetKind.BOX if box!=null else AttackIntent.TargetKind.BALL))
	for target in targets:intent.target_ids.append(target.unit_id)
	intent.object_id=box.box_id if box!=null else -1
	intent.cell=targets[0].cell if not targets.is_empty() else (box.cell if box!=null else state.ball.cell)
	assert(not targets.is_empty() or box!=null or ball)
	intent.goal_generation=state.goals[0]+state.goals[1]
	intent.started_tick=state.tick;intent.interval_ticks=SkillRules.attack_interval_ticks(unit,data)
	var carried:=data.skills[unit.skill_index]
	var profile:=AttackActionData.profile(unit,SkillRules.active_ticks(unit)!=0 or (carried.trigger_type=="attack" and SkillRules.can_activate(unit,carried)),healing)
	intent.clip=profile.clip;intent.source_frames=profile.frames;intent.release_frame=profile.release_frame
	# Complete authored action fits the cycle; both windup and pose use this frozen window.
	intent.window_ticks=mini(intent.source_frames,maxi(1,intent.interval_ticks*state.CONFIG.ATTACK_ACTION_WINDOW_PERCENT/100))
	intent.release_tick=state.tick+maxi(0,ceili(float(profile.release_frame)*intent.window_ticks/intent.source_frames))
	var random_shots:=0
	if unit.operator_id=="amiya" and SkillRules.active_ticks(unit)!=0 and carried.effect_type=="amiya_burst":random_shots=int(carried.effect_params.shot_count)
	if unit.operator_id=="flowing_shape" and unit.flow_owner_id>=0 and not unit.flow_melee and not unit.flow_copy_id.is_empty():
		var controller:=TacticianRules.owner_for(state,unit)
		if controller!=null and SkillRules.active_ticks(controller)>0 and state._operator_data.muelsyse.skills[controller.skill_index].effect_type=="muelsyse_ecology":random_shots=int(state._operator_data.muelsyse.skills[controller.skill_index].effect_params.shot_count)
	if random_shots>0 and not targets.is_empty():
		var pool:=targets
		if unit.operator_id=="flowing_shape":
			var enemies: Array[UnitState]=[]
			for candidate in pool:
				if candidate.side!=unit.side:enemies.append(candidate)
			if not enemies.is_empty():pool=enemies
		for index in random_shots:intent.shot_target_ids.append(pool[state.rng.next_u32()%pool.size()].unit_id)
		intent.target_ids=PackedInt32Array()
		for target in targets:
			if target.unit_id in intent.shot_target_ids:intent.target_ids.append(target.unit_id)
	unit.attack_intent=intent
	unit.attack_action_event_frames=PackedInt32Array(profile.events) if profile.has("events") else PackedInt32Array([intent.release_frame])
	unit.attack_action_event_index=0;unit.attack_action_triggered=false;unit.attack_action_proc=false
	unit.attack_started_tick=state.tick;unit.attack_next_ready_tick=state.tick+intent.interval_ticks;unit.attack_action_clip=intent.clip
	unit.attack_action_view_index=int(profile.side) if profile.has("side") else (1 if unit.facing==3 else 0)
	unit.attack_action_window_ticks=intent.window_ticks;unit.attack_action_source_frames=intent.source_frames
	unit.attack_ticks_left=intent.interval_ticks
	unit.last_attack_target_x=intent.cell.x;unit.last_attack_target_y=intent.cell.y

static func pending(state: MatchState, unit: UnitState, data: OperatorData) -> bool:
	if unit.attack_intent==null:return false
	if unit.hp<=0 or unit.stun_ticks_left>0 or unit.frozen_ticks_left>0 or unit.sleep_ticks_left>0 or unit.displacement_ticks_left>0 or unit.titi_doze_owner_id>=0:
		StatusRules.interrupt_basic(state,unit)
		return true
	var intent:=unit.attack_intent
	if state.tick<intent.release_tick:return true
	unit.attack_intent=null
	var targets: Array[UnitState]=[]
	for id in intent.target_ids:
		var target:=WArtilleryRules.owner(state,id)
		if target!=null and state.enemy_is_targetable(unit.side,target,unit) and state._is_in_attack_range(unit,target.cell,AttackRange.effective_offsets(unit,data)):targets.append(target)
	var box: TacticalBox
	if intent.kind==AttackIntent.TargetKind.BOX:
		for candidate in state.tactical_boxes:
			if candidate.box_id==intent.object_id and candidate.hits_left>0 and state._is_in_attack_range(unit,candidate.cell,AttackRange.effective_offsets(unit,data)):box=candidate;break
	var ball:=intent.kind==AttackIntent.TargetKind.BALL and state.goals[0]+state.goals[1]==intent.goal_generation and state.ball.move_ticks_left==0 and state.ball.cell==intent.cell and state._is_in_attack_range(unit,intent.cell,AttackRange.effective_offsets(unit,data))
	if targets.is_empty() and box==null and not ball:
		StatusRules.interrupt_basic(state,unit)
		return true
	fire(state,unit,data,intent,targets,box,ball)
	return true

static func fire(state: MatchState, unit: UnitState, data: OperatorData, intent: AttackIntent, targets: Array[UnitState], box: TacticalBox, ball: bool) -> void:
	var skill:=data.skills[unit.skill_index]
	var triggered:=skill.trigger_type=="attack" and SkillRules.can_activate(unit,skill)
	if triggered:SkillRules.activate(unit,data);unit.launch_started_tick=state.tick
	var active:=SkillRules.active_ticks(unit)!=0
	var attack:=SkillRules.attack_output_value(unit,data)
	if unit.operator_id=="surtr" and active and skill.effect_type=="dual_arts_boost" and targets.size()==1:attack=roundi(attack*int(skill.effect_params.single_target_percent)/100.0)
	var center:=targets[0].cell if not targets.is_empty() else (box.cell if box!=null else intent.cell)
	PusherRules.mark_attack(state,unit,center)
	BlemishineRules.on_basic_attack(state,unit)
	# Attack-recovery SP belongs to release, even if the projectile later loses its target.
	if not triggered and skill.sp_recharge_type=="on_hit" and unit.skill_ticks_left==0:SagaRules.reward(state,unit,1)
	if unit.operator_id in ["exusiai","jessica"]:
		var projectile:=AttackProjectile.new()
		projectile.source_id=unit.unit_id;projectile.source_side=unit.side;projectile.operator_id=unit.operator_id
		projectile.source_cell=unit.cell;projectile.facing=unit.facing;projectile.kind=intent.kind
		projectile.target_id=targets[0].unit_id if not targets.is_empty() else intent.object_id
		projectile.target_cell=center;projectile.goal_generation=intent.goal_generation
		projectile.attack=attack;projectile.shots=int(skill.effect_params.shot_count) if active and skill.effect_type in ["multi_shot","sustained_multi_shot"] else 1
		projectile.release_tick=state.tick
		var distance:=sqrt(float(unit.cell.distance_squared_to(center)))
		projectile.arrival_tick=state.tick+maxi(1,ceili(distance*state.CONFIG.TICK_RATE/state.CONFIG.BASIC_PROJECTILE_SPEED_CELLS_PER_SECOND))
		projectile.order_key=state.next_projectile_order;state.next_projectile_order+=1
		state.attack_projectiles.append(projectile)
	else:
		var killed:=false
		targets.sort_custom(func(a: UnitState,b: UnitState)->bool:return a.unit_id<b.unit_id)
		for target in targets:
			if unit.hp<=0:break
			LaunchOperatorRules.hit(state,unit,data,target,attack,data.damage_type,int(data.talent_1.effect_params.resist_ignore) if unit.silence_ticks_left==0 and data.talent_1.effect_type=="flat_resist_penetration" else 0)
			killed=killed or target.hp<=0
		if box!=null:TacticalRules.strike_box(state,unit,box)
		elif ball:state.ball.add_push(unit.cell,attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
		if active and skill.effect_type=="kill_refund_strike" and killed:unit.sp=SkillRules.sp_limit(skill)
	if unit.skill_ticks_left==-1:unit.skill_ticks_left=0

static func advance_projectiles(state: MatchState) -> void:
	var pending_shots: Array[AttackProjectile]=[]
	# Release order follows unit_id order; stable sort preserves order for one source.
	state.attack_projectiles.sort_custom(func(a: AttackProjectile,b: AttackProjectile)->bool:return a.source_id<b.source_id if a.source_id!=b.source_id else (a.release_tick<b.release_tick if a.release_tick!=b.release_tick else a.order_key<b.order_key))
	for shot in state.attack_projectiles:
		if state.tick<shot.arrival_tick:pending_shots.append(shot);continue
		var data: OperatorData=state._operator_data[shot.operator_id]
		var source:=WArtilleryRules.owner(state,shot.source_id)
		if source==null:source=UnitState.new(shot.source_id,shot.source_side,shot.operator_id,shot.source_cell,0,0,0,shot.facing)
		if shot.delivery==3:
			PusherRules.nitrogen_impact(state,shot,source)
			continue
		if shot.delivery in [1,2]:
			LaunchOperatorRules.impact(state,shot,source)
			continue
		if shot.kind==AttackIntent.TargetKind.UNIT:
			var target:=WArtilleryRules.owner(state,shot.target_id)
			if target==null or not state.enemy_is_targetable(shot.source_side,target,source):continue
			var target_data: OperatorData=state._operator_data[target.operator_id]
			for index in shot.shots:
				if target not in state.units or target.hp<=0:break
				var damage:=Combat.calculate_damage(shot.attack,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),data.damage_type,SkillRules.dodge_chance(target,target_data,data.damage_type),state.rng,data.profession_id,state._damage_taken_percent(target,data.damage_type),state._magical_damage_taken_percent(target))
				state._apply_damage(target,target_data,damage,data.damage_type,source)
		elif shot.kind==AttackIntent.TargetKind.BOX:
			for box in state.tactical_boxes:
				if box.box_id!=shot.target_id:continue
				# Box impact must not rewrite the live owner's fire timestamp.
				var owner_marker:=UnitState.new(shot.source_id,shot.source_side,shot.operator_id,shot.source_cell,0)
				for index in shot.shots:
					if box.hits_left<=0:break
					TacticalRules.strike_box(state,owner_marker,box)
				break
		elif state.goals[0]+state.goals[1]==shot.goal_generation and state.ball.cell==shot.target_cell and state.ball.move_ticks_left==0:
			for index in shot.shots:state.ball.add_push(shot.source_cell,shot.attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,shot.facing))
	state.attack_projectiles=pending_shots
	var retained_hits: Array[PackedInt32Array]=[]
	for entry in state.attack_skill_hits:
		for shot in pending_shots:
			if shot.source_id==entry[0] and shot.skill_use==entry[1]:retained_hits.append(entry);break
	state.attack_skill_hits=retained_hits

static func hash_intent(value: int, intent: AttackIntent) -> int:
	if intent==null:return (value*31)&0x7fffffff
	for field in [1,intent.kind,intent.object_id,intent.cell.x,intent.cell.y,intent.goal_generation,intent.started_tick,intent.release_tick,intent.release_frame,intent.interval_ticks,intent.clip.hash(),intent.source_frames,intent.window_ticks,intent.target_ids.size(),int(intent.requires_primary),intent.shot_target_ids.size()]:value=(value*31+field)&0x7fffffff
	for id in intent.target_ids:value=(value*31+id)&0x7fffffff
	for id in intent.shot_target_ids:value=(value*31+id)&0x7fffffff
	return value

static func hash_projectiles(value: int, shots: Array[AttackProjectile]) -> int:
	value=(value*31+shots.size())&0x7fffffff
	for shot in shots:
		for field in [shot.source_id,shot.source_side,shot.operator_id.hash(),shot.source_cell.x,shot.source_cell.y,shot.facing,shot.kind,shot.target_id,shot.target_cell.x,shot.target_cell.y,shot.goal_generation,shot.attack,shot.shots,shot.release_tick,shot.arrival_tick,shot.delivery,shot.damage_type.hash(),shot.skill_index,int(shot.silenced),int(shot.active),shot.stun_ticks,shot.splash_radius_squared,int(shot.armor_break),int(shot.splash_affects_objects),shot.cold_ticks,shot.slow_ticks,shot.bind_ticks,shot.armor_remaining_percent,shot.armor_ticks,shot.typewriter_remaining_percent,shot.typewriter_ticks,shot.shift_force,int(shot.shift_pull),shot.primary_attack,shot.inner_attack,shot.inner_radius_squared,shot.minimum_percent,shot.resist_ignore,shot.chain_count,int(shot.attack_event),shot.shell_defense_reduce,shot.shell_ticks,shot.order_key,shot.defense_remaining_percent,shot.defense_ignore_flat,shot.extra_magic_attack,shot.skill_use,shot.first_hit_bonus_percent,shot.first_hit_slow_ticks,shot.rupture_damage_per_cell,shot.rupture_ticks,int(shot.can_hit_sleep)]:value=(value*31+field)&0x7fffffff
	return value

static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.attack_started_tick>=0:unit.attack_ticks_left=maxi(0,unit.attack_next_ready_tick-state.tick)
	if pending(state,unit,data):return
	if unit.attack_started_tick>=0:
		if unit.attack_ticks_left>0 or unit.stun_ticks_left>0 or unit.frozen_ticks_left>0 or unit.sleep_ticks_left>0 or unit.bind_ticks_left>0 or unit.displacement_ticks_left>0 or unit.titi_doze_owner_id>=0:return
	elif not StatusRules.advance_basic_attack(unit):return
	# Twilight's authored cast precedes its first new attack; existing windup remains locked.
	if unit.operator_id=="surtr" and SkillRules.active_ticks(unit)!=0 and unit.skill_index==2 and state.tick-unit.launch_started_tick<AttackActionData.SURTR_TWILIGHT_BEGIN_TICKS:return
	var targets:=PusherRules.targets(state,unit,AttackRange.effective_offsets(unit,data),false)
	var count:=1
	if unit.operator_id=="surtr" and SkillRules.active_ticks(unit)!=0 and unit.skill_index in [1,2]:count=int(data.skills[unit.skill_index].effect_params.target_count)
	targets=targets.slice(0,count)
	var box: TacticalBox
	if targets.is_empty():
		for candidate in state.tactical_boxes:
			if candidate.hits_left>0 and state._is_in_attack_range(unit,candidate.cell,AttackRange.effective_offsets(unit,data)):box=candidate;break
	var ball:=targets.is_empty() and box==null and state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,AttackRange.effective_offsets(unit,data))
	if targets.is_empty() and box==null and not ball:return
	begin(state,unit,data,targets,box,ball)


static func uses_start_clock(unit: UnitState) -> bool:
	return unit.attack_started_tick>=0

# Existing family resolvers retain their skill effects; only their action gate is shared.
static func advance(state: MatchState, unit: UnitState) -> bool:
	observe_skill(state,unit)
	if unit.operator_id not in ADAPTED_IDS:return StatusRules.advance_basic_attack(unit)
	if unit.hp<=0 or unit.stun_ticks_left>0 or unit.frozen_ticks_left>0 or unit.sleep_ticks_left>0 or unit.displacement_ticks_left>0 or unit.titi_doze_owner_id>=0:
		if unit.attack_intent!=null:StatusRules.interrupt_basic(state,unit)
		unit.attack_ticks_left=maxi(0,unit.attack_next_ready_tick-state.tick) if unit.attack_started_tick>=0 else maxi(0,unit.attack_ticks_left-1)
		return false
	if unit.attack_intent!=null:
		var intent:=unit.attack_intent
		var valid:=true
		if intent.kind==AttackIntent.TargetKind.BALL:valid=state.goals[0]+state.goals[1]==intent.goal_generation and state.ball.move_ticks_left==0 and state.ball.cell==intent.cell
		elif intent.kind==AttackIntent.TargetKind.BOX:
			valid=false
			for box in state.tactical_boxes:
				if box.box_id==intent.object_id and box.hits_left>0:valid=true;break
		elif intent.kind in [AttackIntent.TargetKind.UNIT,AttackIntent.TargetKind.HEAL]:
			valid=false
			for target in state.units:
				if target.unit_id in intent.target_ids and target.hp>0:valid=true;break
		if valid and intent.requires_primary:
			var primary:=WArtilleryRules.owner(state,intent.target_ids[0])
			valid=primary!=null and state.enemy_is_targetable(unit.side,primary,unit) and (state._is_in_attack_range(unit,primary.cell,AttackRange.effective_offsets(unit,state._operator_data[unit.operator_id])) or state.enemy_is_blocked(primary,unit.unit_id))
		if not valid:StatusRules.interrupt_basic(state,unit);return false
		return state.tick>=intent.release_tick
	if unit.skill_started_tick>=0 and state.tick-unit.skill_started_tick<AttackActionData.skill_begin_frames(unit):
		unit.attack_ticks_left=maxi(0,unit.attack_next_ready_tick-state.tick) if unit.attack_started_tick>=0 else maxi(0,unit.attack_ticks_left-1)
		return false
	if unit.skill_dump_pending and unit.silence_ticks_left==0:return true
	if unit.attack_started_tick>=0:
		unit.attack_ticks_left=maxi(0,unit.attack_next_ready_tick-state.tick)
		return unit.bind_ticks_left==0 and unit.attack_ticks_left==0
	return StatusRules.advance_basic_attack(unit)

static func pinned(state: MatchState, unit: UnitState, candidates: Array[UnitState]) -> Array[UnitState]:
	if unit.operator_id not in ADAPTED_IDS or unit.attack_intent==null:return candidates
	var intent:=unit.attack_intent
	if intent.kind not in [AttackIntent.TargetKind.UNIT,AttackIntent.TargetKind.HEAL]:return []
	var result: Array[UnitState]=[]
	for id in intent.target_ids:
		for candidate in candidates:
			if candidate.unit_id==id and candidate.hp>0:result.append(candidate);break
	if result.is_empty():StatusRules.interrupt_basic(state,unit)
	return result

static func pinned_center(state: MatchState, unit: UnitState, center: Vector2i) -> Vector2i:
	if unit.operator_id not in ADAPTED_IDS or unit.attack_intent==null:return center
	var intent:=unit.attack_intent
	if intent.kind==AttackIntent.TargetKind.UNIT:return center
	if intent.kind==AttackIntent.TargetKind.BOX:
		for box in state.tactical_boxes:
			if box.box_id==intent.object_id and box.hits_left>0:return box.cell
	else:
		if state.goals[0]+state.goals[1]==intent.goal_generation and state.ball.move_ticks_left==0 and state.ball.cell==intent.cell:return intent.cell
	StatusRules.interrupt_basic(state,unit)
	return Vector2i(-1,-1)

static func windup(state: MatchState, unit: UnitState, data: OperatorData, candidates: Array[UnitState], center: Vector2i, healing: bool=false) -> bool:
	if unit.operator_id not in ADAPTED_IDS:return true
	if unit.attack_intent!=null:
		if unit.attack_intent.kind not in [AttackIntent.TargetKind.UNIT,AttackIntent.TargetKind.HEAL] and pinned_center(state,unit,center)!=center:
			if unit.attack_intent!=null:StatusRules.interrupt_basic(state,unit)
			return false
		unit.attack_intent=null
		return true
	if unit.attack_started_tick>=0 and state.tick<unit.attack_next_ready_tick:return false
	var box: TacticalBox
	if candidates.is_empty():
		for candidate in state.tactical_boxes:
			if candidate.cell==center and candidate.hits_left>0:box=candidate;break
	var selected:=candidates if healing else selected_targets(state,unit,data,candidates)
	begin(state,unit,data,selected,box,selected.is_empty() and box==null,healing)
	unit.attack_intent.requires_primary=not healing and selected.size()==1
	if unit.attack_intent.release_tick==state.tick:unit.attack_intent=null;return true
	return false

static func projectile(state: MatchState, unit: UnitState, target: UnitState, box: TacticalBox, cell: Vector2i, attack_value: int) -> AttackProjectile:
	var shot:=AttackProjectile.new()
	shot.source_id=unit.unit_id;shot.source_side=unit.side;shot.operator_id=unit.operator_id
	shot.source_cell=unit.cell;shot.facing=unit.facing
	shot.kind=AttackIntent.TargetKind.UNIT if target!=null else (AttackIntent.TargetKind.BOX if box!=null else AttackIntent.TargetKind.BALL)
	shot.target_id=target.unit_id if target!=null else (box.box_id if box!=null else -1)
	shot.target_cell=cell;shot.goal_generation=state.goals[0]+state.goals[1]
	shot.attack=attack_value;shot.shots=1;shot.release_tick=state.tick
	shot.arrival_tick=state.tick+maxi(1,ceili(sqrt(float(unit.cell.distance_squared_to(cell)))*state.CONFIG.TICK_RATE/state.CONFIG.BASIC_PROJECTILE_SPEED_CELLS_PER_SECOND))
	shot.order_key=state.next_projectile_order;state.next_projectile_order+=1
	state.attack_projectiles.append(shot)
	return shot

static func pin_found(state: MatchState, unit: UnitState, found: Dictionary) -> Dictionary:
	if unit.operator_id not in ADAPTED_IDS or unit.attack_intent==null:return found
	var intent:=unit.attack_intent
	if intent.kind==AttackIntent.TargetKind.UNIT:
		var target:=WArtilleryRules.owner(state,intent.target_ids[0])
		var data: OperatorData=state._operator_data[unit.operator_id]
		if target!=null and state.enemy_is_targetable(unit.side,target,unit) and (state._is_in_attack_range(unit,target.cell,AttackRange.effective_offsets(unit,data)) or state.enemy_is_blocked(target,unit.unit_id)):return {"kind":0,"unit":target,"cell":target.cell}
	else:
		var center:=pinned_center(state,unit,intent.cell)
		if center.x>=0:
			if intent.kind==AttackIntent.TargetKind.BALL:return {"kind":2,"cell":center}
			for box in state.tactical_boxes:
				if box.box_id==intent.object_id:return {"kind":1,"box":box,"cell":center}
	StatusRules.interrupt_basic(state,unit)
	return {}

static func windup_found(state: MatchState, unit: UnitState, data: OperatorData, found: Dictionary) -> bool:
	var targets: Array[UnitState]=[]
	if found.kind==0:targets.append(found.unit)
	return windup(state,unit,data,targets,found.cell)

static func healing_candidates(state: MatchState, source: UnitState, data: OperatorData, count: int) -> Array[UnitState]:
	var candidates: Array[UnitState]=[]
	for ally in state.units:
		if ally.side==source.side and LumenRules.can_heal(state,ally) and ally.hp<SkillRules.max_health_value(ally,state._operator_data[ally.operator_id]) and state._is_in_attack_range(source,ally.cell,AttackRange.effective_offsets(source,data)):candidates.append(ally)
	candidates.sort_custom(func(a: UnitState,b: UnitState)->bool:
		var am:=SkillRules.max_health_value(a,state._operator_data[a.operator_id]);var bm:=SkillRules.max_health_value(b,state._operator_data[b.operator_id])
		return a.unit_id<b.unit_id if a.hp*bm==b.hp*am else a.hp*bm<b.hp*am)
	return pinned(state,source,candidates).slice(0,count)

static func heal_target(state: MatchState, unit: UnitState, target: UnitState) -> UnitState:
	if unit.operator_id not in ADAPTED_IDS or unit.attack_intent==null:return target
	var chosen: Array[UnitState]=[]
	for ally in state.units:
		if ally.unit_id in unit.attack_intent.target_ids and ally.side==unit.side and LumenRules.can_heal(state,ally) and state._is_in_attack_range(unit,ally.cell,AttackRange.effective_offsets(unit,state._operator_data[unit.operator_id])):chosen.append(ally)
	chosen=pinned(state,unit,chosen)
	return chosen[0] if not chosen.is_empty() else null

static func generic_projectile(state: MatchState, source: UnitState, data: OperatorData, target: UnitState, box: TacticalBox, center: Vector2i, attack_value: int, damage_type: String, armor_break: bool=false) -> AttackProjectile:
	var shot:=projectile(state,source,target,box,center,attack_value)
	shot.minimum_percent=state.CONFIG.UNIT_MIN_DAMAGE_PERCENT
	shot.delivery=2;shot.damage_type=damage_type;shot.skill_index=source.skill_index;shot.skill_use=source.skill_activation_count
	shot.silenced=source.silence_ticks_left>0;shot.active=SkillRules.active_ticks(source)!=0;shot.armor_break=armor_break
	shot.can_hit_sleep=state.can_attack_sleeping(source)
	return shot

static func object_cell(state: MatchState, unit: UnitState, offsets: Array[Vector2i]) -> Vector2i:
	for box in state.tactical_boxes:
		if box.hits_left>0 and state._is_in_attack_range(unit,box.cell,offsets):return box.cell
	return state.ball.cell if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,offsets) else Vector2i(-1,-1)

static func area_windup(state: MatchState, unit: UnitState, data: OperatorData, center: Vector2i) -> bool:
	if unit.attack_intent!=null:unit.attack_intent=null;return true
	var targets: Array[UnitState]=[]
	begin(state,unit,data,targets,null,true)
	unit.attack_intent.kind=AttackIntent.TargetKind.CELL;unit.attack_intent.cell=center
	unit.last_attack_target_x=center.x;unit.last_attack_target_y=center.y
	if unit.attack_intent.release_tick==state.tick:unit.attack_intent=null;return true
	return false

static func found_projectile(state: MatchState, unit: UnitState, data: OperatorData, found: Dictionary, attack_value: int, damage_type: String) -> AttackProjectile:
	return generic_projectile(state,unit,data,found.unit if found.kind==0 else null,found.box if found.kind==1 else null,found.cell,attack_value,damage_type)

static func area_projectile(state: MatchState, unit: UnitState, data: OperatorData, center: Vector2i, attack_value: int, damage_type: String, radius_squared: int) -> AttackProjectile:
	var shot:=generic_projectile(state,unit,data,null,null,center,attack_value,damage_type)
	shot.kind=AttackIntent.TargetKind.CELL;shot.splash_radius_squared=radius_squared
	return shot

static func cancel_incompatible(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.attack_intent==null:return
	var skill:=data.skills[unit.skill_index]
	var active:=SkillRules.active_ticks(unit)!=0
	var blocked:=unit.critical_ticks_left>0 or unit.flow_point_until_tick>0 or unit.chen_slashes_left>0
	blocked=blocked or (data.branch_trait.effect_type=="flag_bearer" and unit.skill_ticks_left>0)
	blocked=blocked or (data.branch_trait.effect_type in ["phalanx","liberator"] and not active)
	blocked=blocked or (active and skill.effect_type in ["foxfire_aura","thorns_counter","penance_ascetic","gladiia_vortex","caster_lock","flame_ground","goldenglow_global","nian_copper","cuora_shell"])
	blocked=blocked or (not active and skill.effect_type in ["rapid_magic","weightless_multi_target"] and unit.silence_ticks_left==0)
	blocked=blocked or (active and skill.effect_type in ["healing_mode","guardian_cook"] and unit.attack_intent.kind!=AttackIntent.TargetKind.HEAL)
	blocked=blocked or (unit.operator_id=="silence_alter" and active!=(unit.attack_intent.kind==AttackIntent.TargetKind.HEAL))
	if blocked:StatusRules.interrupt_basic(state,unit)

static func release_indices(unit: UnitState, intent: AttackIntent, count: int) -> PackedInt32Array:
	var phase:=unit.attack_action_event_index
	if intent==null or (phase==0 and (count<2 or count!=unit.attack_action_event_frames.size())):return PackedInt32Array(range(count))
	if phase+1<unit.attack_action_event_frames.size():
		var next_frame:=unit.attack_action_event_frames[phase+1]
		intent.release_frame=next_frame
		intent.release_tick=unit.attack_started_tick+ceili(float(next_frame)*unit.attack_action_window_ticks/unit.attack_action_source_frames)
		unit.attack_action_event_index=phase+1
		unit.attack_intent=intent
	return PackedInt32Array([phase])

static func generic_target_count(unit: UnitState, data: OperatorData) -> int:
	var skill:=data.skills[unit.skill_index]
	var count:=data.block_count if data.branch_trait.effect_type=="attack_all_blocked" else 1
	if SkillRules.active_ticks(unit)!=0 and skill.effect_type in ["lappland_wolf","permanent_multi_target","multi_target_boost","weightless_multi_target","random_multi_target"]:count=int(skill.effect_params.target_count)
	return count

static func generic_targets(state: MatchState, unit: UnitState, data: OperatorData, primary: UnitState) -> Array[UnitState]:
	var skill:=data.skills[unit.skill_index]
	var count:=generic_target_count(unit,data)
	var active:=SkillRules.active_ticks(unit)!=0
	if active and skill.effect_type=="cleave_atk_def_boost":count=state.units.size()
	if data.talent_1.effect_type=="attack_proc":count=maxi(count,int(data.talent_1.effect_params.target_count))
	var candidates: Array[UnitState]=[]
	for enemy in state.units:
		if state.enemy_is_targetable(unit.side,enemy,unit) and state._is_in_attack_range(unit,enemy.cell,AttackRange.effective_offsets(unit,data)):candidates.append(enemy)
	if active and skill.effect_type=="random_multi_target":
		var result: Array[UnitState]=[]
		for priority in [1,0,-1]:
			var group: Array[UnitState]=[]
			for enemy in candidates:
				if SkillRules.taunt_level(enemy,state._operator_data[enemy.operator_id])==priority:group.append(enemy)
			var slots:=count-result.size()
			if group.size()<=slots:result.append_array(group)
			else:
				for pick in slots:
					var index:=state.rng.next_u32()%group.size();result.append(group[index]);group.remove_at(index)
		result.sort_custom(func(a: UnitState,b: UnitState)->bool:return a.unit_id<b.unit_id)
		return result
	var result: Array[UnitState]=[primary]
	for enemy in candidates:
		if result.size()>=count:break
		if enemy!=primary:result.append(enemy)
	return result

static func observe_skill(state: MatchState, unit: UnitState) -> void:
	if unit.skill_start_observed_count!=unit.skill_activation_count:
		unit.skill_start_observed_count=unit.skill_activation_count
		unit.skill_started_tick=state.tick

# Lock only actual recipients, rather than every spare candidate from the targeting query.
static func selected_targets(state: MatchState, unit: UnitState, data: OperatorData, candidates: Array[UnitState]) -> Array[UnitState]:
	var skill:=data.skills[unit.skill_index]
	var active:=SkillRules.active_ticks(unit)!=0 or (skill.trigger_type=="attack" and SkillRules.can_activate(unit,skill))
	var count:=1
	if active and skill.effect_type=="amiya_burst":return candidates
	if unit.operator_id=="flowing_shape":
		var controller:=TacticianRules.owner_for(state,unit)
		if controller!=null and SkillRules.active_ticks(controller)>0 and controller.skill_index==1 and not unit.flow_melee and not unit.flow_copy_id.is_empty():return candidates
	if data.branch_trait.effect_type in ["ambusher","phalanx"] or unit.operator_id in ["chen_alter","ifrit"]:return candidates
	if data.branch_trait.effect_type in ["attack_all_blocked","pusher"]:count=SkillRules.block_count_value(unit,data)
	if data.branch_trait.effect_type=="ling_summon" and unit.operator_id!="ling_soul2":count=SkillRules.block_count_value(unit,data)
	if data.branch_trait.effect_type=="double_target" or (data.talent_2.effect_type=="double_target" and unit.silence_ticks_left==0):count=int(data.talent_2.effect_params.target_count)
	if active and skill.effect_type in ["blue_double","blue_venom","liskarm_arc","istina_storm","dual_arts_boost","twilight","fighter_barrage","multi_target_boost","mlynar_glory","gnosis_hypothermia","pallas_blessing","reed_lifeseed","titi_bloom","archetto_storm"]:count=int(skill.effect_params.target_count)
	if active and skill.effect_type in ["fighter_stance","unyield_awakening","saga_fury"]:count=SkillRules.block_count_value(unit,data)
	if active and skill.effect_type=="dual_arrow_repeat":count=2
	if active and skill.effect_type=="pusher_cannon_mode":count=1
	if unit.dodge_attack_ready and unit.silence_ticks_left==0:count=SkillRules.block_count_value(unit,data)
	if unit.operator_id=="mon3tr_operator" and MonstrMedicRules.transformed(unit):count=SkillRules.block_count_value(unit,data)
	if unit.operator_id=="mon3tr" and unit.mon3tr_mode==2:count=SkillRules.block_count_value(unit,data)
	if active and skill.effect_type in ["cleave_atk_def_boost","dusk_ink"]:return candidates
	# Generic resolver has already frozen random recipients and possible talent collateral.
	if unit.operator_id in GENERIC_RANGED_IDS or data.talent_1.effect_type=="attack_proc":return candidates
	return candidates.slice(0,count)
