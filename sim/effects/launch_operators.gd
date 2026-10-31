class_name LaunchOperatorRules
extends RefCounted

const IDS := ["zima","liskarm","blue_poison","projekt_red","amiya","skyfire","istina","pramanix"]

static func started(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	unit.launch_started_tick=state.tick
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="liskarm_guard":unit.liskarm_shield_ready=true
	if skill.effect_type=="instant_cost":
		state.sides[unit.side].cost=mini(state.CONFIG.COST_MAX,state.sides[unit.side].cost+int(skill.effect_params["cost_add"]))
		unit.skill_ticks_left=0

static func red_burst(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	var attack := roundi(SkillRules.attack_value(unit,data)*float(skill.effect_params["attack_mult"]))
	unit.launch_started_tick=state.tick
	unit.last_attack_tick=state.tick;unit.last_attack_target_x=unit.cell.x;unit.last_attack_target_y=unit.cell.y
	for enemy in state.units.duplicate():
		if enemy not in state.units or enemy.hp<=0 or not StainlessRules.is_damage_target(unit,enemy) or enemy.operator_id in ["weedy_cannon","seaborn"] or not state._is_in_attack_range(unit,enemy.cell,skill.attack_range_override):continue
		if hit(state,unit,data,enemy,attack,"physical") and enemy.hp>0:SwordRules.stun(state,enemy,int(skill.effect_params["stun_ticks"]),unit)
	for box in state.tactical_boxes:
		if box.hits_left>0 and state._is_in_attack_range(unit,box.cell,skill.attack_range_override):TacticalRules.strike_box(state,unit,box)
	if state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,skill.attack_range_override):state.ball.add_push(unit.cell,attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))

static func advance(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.trigger_type=="auto" and SkillRules.can_activate(unit,skill):SkillRules.activate(unit,data);started(state,unit,data)
	if SkillRules.active_ticks(unit)>0 and skill.effect_type=="zima_warcry":
		SkillRules.advance_cost_regen(state, unit, skill)
	if not AttackTimeline.advance(state,unit):return
	var offsets := AttackRange.effective_offsets(unit,data)
	var targets := PusherRules.targets(state,unit,offsets,false)
	targets=AttackTimeline.pinned(state,unit,targets)
	var box: TacticalBox
	if targets.is_empty():
		for candidate in state.tactical_boxes:
			if candidate.hits_left>0 and state._is_in_attack_range(unit,candidate.cell,offsets):box=candidate;break
	var ball := targets.is_empty() and box==null and state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,offsets)
	if targets.is_empty() and box==null and not ball:return
	var native_action:=unit.attack_intent
	if not AttackTimeline.windup(state,unit,data,targets,targets[0].cell if not targets.is_empty() else (box.cell if box!=null else state.ball.cell)):return
	if skill.trigger_type=="attack" and SkillRules.can_activate(unit,skill):SkillRules.activate(unit,data);started(state,unit,data)
	var active := SkillRules.active_ticks(unit)!=0
	var attack := SkillRules.attack_output_value(unit,data)
	var damage_type := "true" if active and skill.effect_type=="amiya_chimera" else ("magical" if active and skill.effect_type=="liskarm_arc" else data.damage_type)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	unit.last_attack_tick=state.tick;unit.last_attack_is_heal=false
	BlemishineRules.on_basic_attack(state,unit)
	var center := targets[0].cell if not targets.is_empty() else (box.cell if box!=null else state.ball.cell)
	unit.last_attack_target_x=center.x;unit.last_attack_target_y=center.y
	if unit.operator_id in ["liskarm","blue_poison","amiya","skyfire","istina","pramanix"]:
		release_projectiles(state,unit,data,targets,box,center,attack,damage_type,active,native_action)
		if skill.sp_recharge_type=="on_hit" and unit.skill_ticks_left==0:SagaRules.reward(state,unit,1)
		if unit.skill_ticks_left==-1:unit.skill_ticks_left=0
		return
	if unit.operator_id=="skyfire":
		splash(state,unit,data,center,attack,active and skill.effect_type=="skyfire_meteor")
	elif active and skill.effect_type=="amiya_burst":
		for shot in int(skill.effect_params["shot_count"]):
			if unit.hp<=0:break
			var enemies := PusherRules.targets(state,unit,offsets,false)
			if not enemies.is_empty():hit(state,unit,data,enemies[state.rng.next_u32()%enemies.size()],roundi(attack*float(skill.effect_params["damage_scale"])),"magical")
			elif box!=null and box.hits_left>0:TacticalRules.strike_box(state,unit,box)
			elif state.ball.move_ticks_left==0 and state._is_in_attack_range(unit,state.ball.cell,offsets):state.ball.add_push(unit.cell,roundi(attack*float(skill.effect_params["damage_scale"])),state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
	elif not targets.is_empty():
		var count := int(data.talent_2.effect_params["target_count"]) if unit.silence_ticks_left==0 and data.talent_2.effect_type=="double_target" else 1
		if active and skill.effect_type in ["blue_double","blue_venom","liskarm_arc","istina_storm"]:count=int(skill.effect_params["target_count"])
		targets=targets.slice(0,count);targets.sort_custom(func(a: UnitState,b: UnitState)->bool:return a.unit_id<b.unit_id)
		var primary_id := PusherRules.targets(state,unit,offsets,false)[0].unit_id
		for target in targets:
			if unit.hp<=0:break
			var shots := int(skill.effect_params["primary_shots"]) if active and skill.effect_type=="blue_venom" and target.unit_id==primary_id else 1
			for shot in shots:
				if unit.hp<=0:break
				if target in state.units and target.hp>0:hit(state,unit,data,target,attack,damage_type)
		if unit.silence_ticks_left==0 and data.talent_1.effect_type=="emotional_absorption":SagaRules.reward(state,unit,int(data.talent_1.effect_params["attack_sp"]))
	else:
		var shots := int(skill.effect_params["primary_shots"]) if active and skill.effect_type=="blue_venom" else 1
		for shot in shots:
			if box!=null:
				if box.hits_left>0:TacticalRules.strike_box(state,unit,box)
			elif state.ball.move_ticks_left==0:state.ball.add_push(unit.cell,attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
	if skill.sp_recharge_type=="on_hit" and unit.skill_ticks_left==0:SagaRules.reward(state,unit,1)
	if unit.skill_ticks_left==-1:unit.skill_ticks_left=0

static func hit(state: MatchState, source: UnitState, data: OperatorData, target: UnitState, attack: int, damage_type: String, resist_ignore: int = 0) -> bool:
	var target_data: OperatorData=state._operator_data[target.operator_id]
	var minimum := int(data.talent_1.effect_params["minimum_percent"]) if source.silence_ticks_left==0 and data.talent_1.effect_type=="minimum_attack" else state.CONFIG.UNIT_MIN_DAMAGE_PERCENT
	var damage := Combat.calculate_damage(attack,SkillRules.defense_value(target,target_data),maxi(0,SkillRules.magic_resist_value(target,target_data)-resist_ignore),damage_type,SkillRules.dodge_chance(target,target_data,damage_type),state.rng,data.profession_id,state._damage_taken_percent(target,damage_type),state._magical_damage_taken_percent(target),minimum)
	var landed := state._apply_damage(target,target_data,damage,damage_type,source)
	if landed and target.hp>0:
		if source.silence_ticks_left==0 and data.talent_1.effect_type=="neurotoxin":
			if target.poison_until_tick<=state.tick:target.poison_next_tick=state.tick+int(data.talent_1.effect_params["pulse_ticks"])
			target.poison_until_tick=state.tick+int(data.talent_1.effect_params["duration_ticks"]);target.poison_source_id=source.unit_id;target.poison_damage=int(data.talent_1.effect_params["damage"]);target.poison_pulse_ticks=int(data.talent_1.effect_params["pulse_ticks"])
		if data.branch_trait.effect_type=="slow_on_hit":StatusRules.add_control(state,target,"slow",roundi(float(data.branch_trait.effect_params["slow_duration"])*state.CONFIG.TICK_RATE))
		var skill := data.skills[source.skill_index]
		if SkillRules.active_ticks(source)>0 and skill.effect_type=="liskarm_arc" and state.rng.next_percent()<int(skill.effect_params["stun_chance_percent"]):SwordRules.stun(state,target,int(skill.effect_params["stun_ticks"]),source)
	return landed

static func splash(state: MatchState, source: UnitState, data: OperatorData, center: Vector2i, attack: int, meteor: bool) -> void:
	var skill := data.skills[source.skill_index]
	var radius := int(skill.effect_params["splash_radius_squared"]) if meteor else int(data.branch_trait.effect_params["splash_radius_squared"])
	for enemy in state.units.duplicate():
		if enemy not in state.units or enemy.hp<=0 or not StainlessRules.is_damage_target(source,enemy) or enemy.operator_id in ["weedy_cannon","seaborn"] or (enemy.cell-center).length_squared()>radius:continue
		if hit(state,source,data,enemy,attack,"magical") and enemy.hp>0 and meteor:SwordRules.stun(state,enemy,int(skill.effect_params["stun_ticks"]),source)
	for box in state.tactical_boxes:
		if box.hits_left>0 and (box.cell-center).length_squared()<=radius:TacticalRules.strike_box(state,source,box)
	if state.ball.move_ticks_left==0 and (state.ball.cell-center).length_squared()<=radius:state.ball.add_push(source.cell,attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,source.facing))

static func poison(state: MatchState) -> void:
	for target in state.units.duplicate():
		if target not in state.units or target.hp<=0 or target.poison_until_tick<=0:continue
		if state.tick>=target.poison_next_tick and state.tick<=target.poison_until_tick:
			var data: OperatorData=state._operator_data[target.operator_id]
			var source: UnitState
			for unit in state.units:
				if unit.unit_id==target.poison_source_id:source=unit;break
			var damage := Combat.calculate_damage(target.poison_damage,0,SkillRules.magic_resist_value(target,data),"magical",0,state.rng,state._operator_data["blue_poison"].profession_id,state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
			state._apply_damage(target,data,damage,"magical",source,false);target.poison_next_tick+=target.poison_pulse_ticks
		if state.tick>=target.poison_until_tick:target.poison_until_tick=0;target.poison_next_tick=0;target.poison_source_id=-1;target.poison_damage=0;target.poison_pulse_ticks=0

static func received(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.hp<=0 or unit.silence_ticks_left>0 or data.talent_1.effect_type!="defensive_sp":return
	SagaRules.reward(state,unit,int(data.talent_1.effect_params["sp_add"]))
	var targets: Array[UnitState]=[]
	for ally in state.units:
		if ally.hp>0 and ally.side==unit.side and absi(ally.cell.x-unit.cell.x)+absi(ally.cell.y-unit.cell.y)<=1 and state._operator_data[ally.operator_id].skills[ally.skill_index].sp_recharge_type!="passive":targets.append(ally)
	if not targets.is_empty():SagaRules.reward(state,targets[state.rng.next_u32()%targets.size()],int(data.talent_1.effect_params["sp_add"]))

static func reward_kill(state: MatchState, source: UnitState) -> void:
	var data: OperatorData=state._operator_data[source.operator_id]
	if source.silence_ticks_left==0 and data.talent_1.effect_type=="emotional_absorption":SagaRules.reward(state,source,int(data.talent_1.effect_params["kill_sp"]))
	if data.profession_id!="vanguard":return
	for unit in state.units:
		var skill: SkillResource=state._operator_data[unit.operator_id].skills[unit.skill_index]
		if unit.hp>0 and unit.side==source.side and SkillRules.active_ticks(unit)>0 and skill.effect_type=="zima_warcry":state.sides[source.side].cost=mini(state.CONFIG.COST_MAX,state.sides[source.side].cost+int(skill.effect_params["kill_cost"]));return

static func finish_retreats(state: MatchState) -> void:
	for unit in state.units.duplicate():
		if not unit.amiya_retreat_pending:continue
		state.sides[unit.side].cooldowns[unit.operator_id]=state._redeploy_ticks(unit.side,state._operator_data[unit.operator_id])
		state.units.erase(unit);WArtilleryRules.on_exit(state,unit)

static func release_projectiles(state: MatchState, source: UnitState, data: OperatorData, targets: Array[UnitState], box: TacticalBox, center: Vector2i, attack: int, damage_type: String, active: bool, native_action: AttackIntent) -> void:
	var skill:=data.skills[source.skill_index]
	var shots: Array[AttackProjectile]=[]
	if source.operator_id=="skyfire":
		var shot:=AttackTimeline.projectile(state,source,targets[0] if not targets.is_empty() else null,box,center,attack)
		shot.splash_radius_squared=int(skill.effect_params.splash_radius_squared) if active and skill.effect_type=="skyfire_meteor" else int(data.branch_trait.effect_params.splash_radius_squared)
		if active and skill.effect_type=="skyfire_meteor":shot.stun_ticks=int(skill.effect_params.stun_ticks)
		shots.append(shot)
	elif active and skill.effect_type=="amiya_burst":
		for index in int(skill.effect_params.shot_count):
			var target: UnitState
			if native_action!=null and not native_action.shot_target_ids.is_empty():
				target=WArtilleryRules.owner(state,native_action.shot_target_ids[index%native_action.shot_target_ids.size()])
				if target==null or target not in targets:continue
			elif not targets.is_empty():target=targets[0]
			shots.append(AttackTimeline.projectile(state,source,target,box,target.cell if target!=null else center,roundi(attack*float(skill.effect_params.damage_scale))))
	else:
		var count:=int(data.talent_2.effect_params.target_count) if source.silence_ticks_left==0 and data.talent_2.effect_type=="double_target" else 1
		if active and skill.effect_type in ["blue_double","blue_venom","liskarm_arc","istina_storm"]:count=int(skill.effect_params.target_count)
		var primary:=targets[0].unit_id if not targets.is_empty() else -1
		var chosen:=targets.slice(0,count)
		chosen.sort_custom(func(a: UnitState,b: UnitState)->bool:return a.unit_id<b.unit_id)
		if chosen.is_empty():
			var repetitions:=int(skill.effect_params.primary_shots) if active and skill.effect_type=="blue_venom" else 1
			for index in repetitions:shots.append(AttackTimeline.projectile(state,source,null,box,center,attack))
		for target in chosen:
			var repetitions:=int(skill.effect_params.primary_shots) if active and skill.effect_type=="blue_venom" and target.unit_id==primary else 1
			for index in repetitions:
				var shot:=AttackTimeline.projectile(state,source,target,null,target.cell,attack)
				if active and skill.effect_type=="liskarm_arc" and state.rng.next_percent()<int(skill.effect_params.stun_chance_percent):shot.stun_ticks=int(skill.effect_params.stun_ticks)
				shots.append(shot)
		if source.silence_ticks_left==0 and data.talent_1.effect_type=="emotional_absorption" and not chosen.is_empty():SagaRules.reward(state,source,int(data.talent_1.effect_params.attack_sp))
	for shot in shots:
		shot.delivery=1;shot.damage_type=damage_type;shot.skill_index=source.skill_index
		shot.silenced=source.silence_ticks_left>0;shot.active=active

static func impact(state: MatchState, shot: AttackProjectile, source: UnitState) -> void:
	var center:=shot.target_cell
	var target: UnitState
	if shot.kind==AttackIntent.TargetKind.UNIT:
		target=WArtilleryRules.owner(state,shot.target_id)
		if target==null or not state.enemy_is_targetable(shot.source_side,target,source,shot.can_hit_sleep):return
		center=target.cell
	elif shot.kind==AttackIntent.TargetKind.BOX:
		var exists:=false
		for box in state.tactical_boxes:
			if box.box_id==shot.target_id and box.hits_left>0:exists=true;center=box.cell;break
		if not exists:return
	elif shot.kind==AttackIntent.TargetKind.CELL:pass
	elif state.goals[0]+state.goals[1]!=shot.goal_generation or state.ball.cell!=shot.target_cell or state.ball.move_ticks_left!=0:return
	var marker:=UnitState.new(shot.source_id,shot.source_side,shot.operator_id,shot.source_cell,0,0,0,shot.facing)
	if shot.splash_radius_squared>=0:
		for enemy: UnitState in state.units.duplicate():
			if enemy in state.units and enemy.hp>0 and StainlessRules.is_damage_target(marker,enemy) and enemy.operator_id not in ["weedy_cannon","seaborn"] and (enemy.cell-center).length_squared()<=shot.splash_radius_squared:impact_unit(state,shot,source,enemy)
		for box in state.tactical_boxes:
			if shot.splash_affects_objects and box.hits_left>0 and (box.cell-center).length_squared()<=shot.splash_radius_squared:TacticalRules.strike_box(state,marker,box)
		if shot.splash_affects_objects and state.goals[0]+state.goals[1]==shot.goal_generation and state.ball.move_ticks_left==0 and (state.ball.cell-center).length_squared()<=shot.splash_radius_squared:
			var ball_attack:=shot.inner_attack if shot.inner_attack>=0 and (state.ball.cell-shot.target_cell).length_squared()<=shot.inner_radius_squared else shot.attack
			state.ball.add_push(shot.source_cell,ball_attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,shot.facing))
	elif target!=null:impact_unit(state,shot,source,target)
	elif shot.kind==AttackIntent.TargetKind.BOX:
		for box in state.tactical_boxes:
			if box.box_id==shot.target_id:TacticalRules.strike_box(state,marker,box);break
	else:
		var direction:=DisplacementRules.direction(marker,state.ball.cell,"pull" if shot.shift_pull else "push")
		var origin:=state.ball.cell-direction if shot.shift_pull else shot.source_cell
		state.ball.add_push(origin,shot.attack,state._ball_data,direction if shot.shift_force>=0 or shot.shift_pull else AttackRange.rotate_offset(Vector2i.RIGHT,shot.facing))
		if shot.shift_force>=0:DisplacementRules.apply_ball(state,direction,shot.shift_force)

static func impact_unit(state: MatchState, shot: AttackProjectile, source: UnitState, target: UnitState) -> void:
	if shot.operator_id=="reed_alter":MedicAlterRules.projectile_hit(state,shot,source,target);return
	if shot.operator_id=="titi":TitiRules.projectile_hit(state,shot,source,target);return
	if shot.chain_count>0:
		ClassicTacticalRules.chain(state,source,state._operator_data[shot.operator_id],target,shot.attack,shot.chain_count,shot.slow_ticks,shot)
		return
	if shot.delivery==2:AttackRules.projectile_hit(state,shot,source,target);return
	var data: OperatorData=state._operator_data[shot.operator_id]
	var td: OperatorData=state._operator_data[target.operator_id]
	var damage:=Combat.calculate_damage(shot.attack,SkillRules.defense_value(target,td),SkillRules.magic_resist_value(target,td),shot.damage_type,SkillRules.dodge_chance(target,td,shot.damage_type),state.rng,data.profession_id,state._damage_taken_percent(target,shot.damage_type),state._magical_damage_taken_percent(target))
	if not state._apply_damage(target,td,damage,shot.damage_type,source) or target.hp<=0:return
	if not shot.silenced and data.talent_1.effect_type=="neurotoxin":
		if target.poison_until_tick<=state.tick:target.poison_next_tick=state.tick+int(data.talent_1.effect_params.pulse_ticks)
		target.poison_until_tick=state.tick+int(data.talent_1.effect_params.duration_ticks);target.poison_source_id=shot.source_id
		target.poison_damage=int(data.talent_1.effect_params.damage);target.poison_pulse_ticks=int(data.talent_1.effect_params.pulse_ticks)
	if data.branch_trait.effect_type=="slow_on_hit":StatusRules.add_control(state,target,"slow",roundi(float(data.branch_trait.effect_params.slow_duration)*state.CONFIG.TICK_RATE))
	if shot.stun_ticks>0:SwordRules.stun(state,target,shot.stun_ticks,source)
