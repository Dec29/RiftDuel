class_name SplashCasterRules
extends RefCounted


static func advance(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	if SkillRules.active_ticks(unit) > 0 and skill.effect_type == "caster_lock":
		if unit.stun_ticks_left == 0 and unit.displacement_ticks_left == 0 and unit.skill_elapsed_ticks % int(skill.effect_params["pulse_ticks"]) == 0:
			attack(state, unit, data, true, false)
		return
	if not AttackTimeline.advance(state,unit):return
	attack(state, unit, data, false, SkillRules.active_ticks(unit) > 0 and skill.effect_type == "caster_wave")


static func attack(state: MatchState, unit: UnitState, data: OperatorData, lock: bool, wave: bool, independent_objects: bool=false) -> void:
	var offsets := AttackRange.effective_offsets(unit, data)
	var enemies: Array[UnitState] = []
	for target in state.units:
		if target.hp > 0 and StainlessRules.is_damage_target(unit,target) and target.operator_id != "weedy_cannon" and state._is_in_attack_range(unit, target.cell, offsets):
			enemies.append(target)
	var primary: UnitState
	for target in enemies:
		if lock or state.enemy_is_targetable(unit.side, target):
			if primary == null or SkillRules.taunt_level(target,state._operator_data[target.operator_id])>SkillRules.taunt_level(primary,state._operator_data[primary.operator_id]):
				primary = target
			if state._operator_data[target.operator_id].branch_trait.effect_type == "phantom":
				break
	var box_target: TacticalBox
	if primary == null:
		for box in state.tactical_boxes:
			if state._is_in_attack_range(unit, box.cell, offsets):
				box_target = box
				break
	var ball_target := primary == null and box_target == null and state.ball.move_ticks_left == 0 and state._is_in_attack_range(unit, state.ball.cell, offsets)
	if primary == null and box_target == null and not ball_target:
		return
	var center := primary.cell if primary != null else (box_target.cell if box_target != null else state.ball.cell)
	if not lock:
		var found: Dictionary={"kind":0,"unit":primary,"cell":primary.cell} if primary!=null else ({"kind":1,"box":box_target,"cell":box_target.cell} if box_target!=null else {"kind":2,"cell":state.ball.cell})
		found=AttackTimeline.pin_found(state,unit,found)
		if found.is_empty():return
		primary=found.unit if found.kind==0 else null
		box_target=found.box if found.kind==1 else null
		ball_target=found.kind==2
		center=found.cell
		if not AttackTimeline.windup_found(state,unit,data,found):return
	var attack_value := SkillRules.attack_output_value(unit, data)
	unit.last_attack_tick = state.tick
	unit.last_attack_is_heal = false
	unit.last_attack_target_x = center.x
	unit.last_attack_target_y = center.y
	if not lock:
		unit.attack_ticks_left = SkillRules.attack_interval_ticks(unit, data)
	var targets: Array[UnitState] = enemies
	if not lock and not wave:
		targets = []
		for target in state.units:
			if target.hp > 0 and StainlessRules.is_damage_target(unit,target) and target.operator_id != "weedy_cannon" and (target.cell - center).length_squared() <= int(data.branch_trait.effect_params["splash_radius_squared"]):
				targets.append(target)
	var skill := data.skills[unit.skill_index]
	if not lock and not wave:
		var shell:=AttackTimeline.area_projectile(state,unit,data,center,attack_value,"magical",int(data.branch_trait.effect_params.splash_radius_squared))
		shell.splash_affects_objects=independent_objects or primary==null
		return
	for target in targets:
		var target_data: OperatorData = state._operator_data[target.operator_id]
		var damage := Combat.calculate_damage(attack_value, SkillRules.defense_value(target, target_data), SkillRules.magic_resist_value(target, target_data), "magical", SkillRules.dodge_chance(target, target_data, "magical"), state.rng, data.profession_id, state._damage_taken_percent(target, "magical"), state._magical_damage_taken_percent(target))
		var hit := state._apply_damage(target, target_data, damage, "magical", unit)
		if hit and target.hp > 0 and lock:
			var duration := int(skill.effect_params["stun_ticks"])
			var resistant := StatusRules.has_resistance(state,target)
			StatusRules.add_control(state,target,"stun",duration * state.CONFIG.STATUS_RESISTANCE_DURATION_PERCENT / 100 if resistant else duration,unit)
		if hit and target.hp > 0 and wave:
			DisplacementRules.apply_unit(state, unit, target, DisplacementRules.direction(unit, target.cell, "push"), int(skill.effect_params["shift_force"]))
	if independent_objects:
		var radius := int(data.branch_trait.effect_params["splash_radius_squared"])
		for box in state.tactical_boxes.duplicate():
			if box.hits_left>0 and (box.cell-center).length_squared()<=radius:TacticalRules.strike_box(state,unit,box)
		if state.ball.move_ticks_left==0 and (state.ball.cell-center).length_squared()<=radius:state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
		return
	if box_target != null:
		TacticalRules.strike_box(state, unit, box_target)
	elif ball_target:
		state.ball.add_push(unit.cell, attack_value, state._ball_data, AttackRange.rotate_offset(Vector2i.RIGHT, unit.facing))
		if wave:
			DisplacementRules.apply_ball(state, DisplacementRules.direction(unit, state.ball.cell, "push"), int(skill.effect_params["shift_force"]))
