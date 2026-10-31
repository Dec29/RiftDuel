class_name FiammettaRules
extends RefCounted


static func maintain(state: MatchState) -> void:
	for unit in state.units:
		if unit.operator_id!="fiammetta" or unit.hp<=0:continue
		var data: OperatorData=state._operator_data[unit.operator_id]
		var params := data.talent_1.effect_params
		if unit.silence_ticks_left>0:unit.fiammetta_vigor_percent=0;continue
		if state.tick<=unit.deployed_tick or (state.tick-unit.deployed_tick)%int(params["pulse_ticks"])!=0:continue
		unit.hp=maxi(1,unit.hp-ceili(unit.hp*int(params["loss_basis_points"])/10000.0))
		var max_hp := SkillRules.max_health_value(unit,data)
		unit.fiammetta_vigor_percent=int(params["high_attack_percent"]) if unit.hp*100>max_hp*int(params["high_hp_threshold_percent"]) else (int(params["attack_percent"]) if unit.hp*100>max_hp*int(params["hp_threshold_percent"]) else 0)


static func cast(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if skill.effect_type=="fiammetta_repay" and unit.skill_ticks_left!=0:
		close(unit,data);return
	SkillRules.activate(unit,data)
	if skill.effect_type!="fiammetta_repent":return
	unit.skill_ticks_left=0
	var params := skill.effect_params
	var power := SkillRules.attack_value(unit,data,true)
	var direction := AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing)
	var distance := 4
	var endpoint := unit.cell*100+direction*distance*100
	var end_tick := state.tick+roundi(distance*state.CONFIG.TICK_RATE/float(params["speed_cells_per_second"]))
	state.fiammetta_explosions.append(FiammettaExplosion.new(unit,endpoint,roundi(power*int(params["burst_attack_percent"])/100.0),int(params["splash_radius_hundredths"]),end_tick))
	var step_distance := int(params["trail_distance_hundredths"])
	for mark in range(1,distance*100/step_distance+1):
		var offset := mark*step_distance
		var due := state.tick+roundi(offset*state.CONFIG.TICK_RATE/(100.0*int(params["speed_cells_per_second"])))+int(params["trail_delay_ticks"])
		state.fiammetta_explosions.append(FiammettaExplosion.new(unit,unit.cell*100+direction*offset,roundi(power*int(params["trail_attack_percent"])/100.0),int(params["trail_radius_hundredths"]),due))
	PusherRules.mark_attack(state,unit,unit.cell+direction*distance)


static func close(unit: UnitState, data: OperatorData) -> void:
	var previous := SkillRules.attack_interval_ticks(unit,data)
	unit.skill_ticks_left=0;unit.skill_elapsed_ticks=0
	unit.attack_ticks_left=ceili(float(unit.attack_ticks_left)*SkillRules.attack_interval_ticks(unit,data)/previous)


static func advance_explosions(state: MatchState) -> void:
	var retained: Array[FiammettaExplosion]=[]
	for field in state.fiammetta_explosions:
		if state.tick<field.due_tick:retained.append(field);continue
		var source := WArtilleryRules.owner(state,field.source_id)
		if source==null:source=UnitState.new(field.source_id,field.side,"fiammetta",field.source_cell,1,0,0,field.facing,1)
		splash(state,source,state._operator_data["fiammetta"],field.center_hundredths,field.attack,field.radius_hundredths,0,0,false)
	state.fiammetta_explosions=retained


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.last_attack_tick==state.tick or not AttackTimeline.advance(state,unit):return
	var skill := data.skills[unit.skill_index]
	var fixed := SkillRules.active_ticks(unit)!=0 and skill.effect_type=="fiammetta_repay"
	var center := unit.cell+AttackRange.rotate_offset(Vector2i(4,0),unit.facing) if fixed else ClassicOperatorRules.target_cell(state,unit,AttackRange.effective_offsets(unit,data))
	if unit.attack_intent!=null and unit.attack_intent.kind==AttackIntent.TargetKind.CELL:center=unit.attack_intent.cell
	if center.x<0 or center.y<0 or center.x>=state.CONFIG.GRID_COLUMNS or center.y>=state.CONFIG.GRID_ROWS:return
	if not AttackTimeline.area_windup(state,unit,data,center):return
	PusherRules.mark_attack(state,unit,center)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var power := SkillRules.attack_value(unit,data,true)
	var shell:=AttackTimeline.area_projectile(state,unit,data,center,roundi(power*float(skill.effect_params.attack_mult)) if fixed else SkillRules.attack_value(unit,data),"physical",4 if fixed else 1)
	if fixed:shell.inner_attack=roundi(power*float(skill.effect_params.center_attack_mult));shell.inner_radius_squared=1
	if unit.skill_ticks_left==0:SagaRules.reward(state,unit,1)


static func splash(state: MatchState, source: UnitState, data: OperatorData, center: Vector2i, power: int, radius: int, inner_power: int, inner_radius: int, attack_event: bool) -> void:
	for target in state.units.duplicate():
		if target not in state.units or target.hp<=0 or not StainlessRules.is_damage_target(source,target) or (target.cell*100-center).length_squared()>radius*radius:continue
		var target_data: OperatorData=state._operator_data[target.operator_id]
		var attack := inner_power if inner_radius>0 and (target.cell*100-center).length_squared()<=inner_radius*inner_radius else power
		var damage := Combat.calculate_damage(attack,SkillRules.defense_value(target,target_data),SkillRules.magic_resist_value(target,target_data),"physical",SkillRules.dodge_chance(target,target_data,"physical"),state.rng,data.profession_id,state._damage_taken_percent(target,"physical"))
		state._apply_damage(target,target_data,damage,"physical",source,attack_event)
	for box in state.tactical_boxes:
		if box.hits_left>0 and (box.cell*100-center).length_squared()<=radius*radius:TacticalRules.strike_box(state,source,box)
	if state.ball.move_ticks_left==0 and (state.ball.cell*100-center).length_squared()<=radius*radius:
		var ball_power := inner_power if inner_radius>0 and (state.ball.cell*100-center).length_squared()<=inner_radius*inner_radius else power
		state.ball.add_push(source.cell,ball_power,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,source.facing))
