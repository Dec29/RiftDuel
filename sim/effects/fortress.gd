class_name FortressRules
extends RefCounted


static func targets(state: MatchState, source: UnitState, data: OperatorData, center: Vector2i) -> Array[UnitState]:
	var radius_squared := int(data.branch_trait.effect_params["splash_radius_squared"])
	if SkillRules.active_ticks(source) != 0 and data.skills[source.skill_index].effect_type == "fortress_charge_shot":
		radius_squared = int(data.skills[source.skill_index].effect_params["splash_radius_squared"])
	var targets: Array[UnitState] = []
	for target in state.units:
		if target.hp > 0 and StainlessRules.is_damage_target(source,target) and (target.cell - center).length_squared() <= radius_squared:
			targets.append(target)
	return targets


static func close_skill(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var old_interval := SkillRules.attack_interval_ticks(unit, data)
	unit.skill_ticks_left = 0
	unit.skill_ammo_left = 0
	unit.skill_dump_pending = false
	unit.skill_elapsed_ticks = 0
	unit.attack_ticks_left = ceili(float(unit.attack_ticks_left) * SkillRules.attack_interval_ticks(unit, data) / old_interval)


static func attack_ammo(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	var offsets := state.ATTACK_RANGE.effective_offsets(unit, data)
	var enemy_target: UnitState
	var taunt := -1
	for enemy in state.units:
		if state.enemy_is_targetable(unit.side, enemy) and state._is_in_attack_range(unit, enemy.cell, offsets):
			var enemy_data: OperatorData = state._operator_data[enemy.operator_id]
			var priority := SkillRules.taunt_level(enemy,enemy_data)
			if enemy_target==null or priority > taunt:
				enemy_target = enemy
				taunt = priority
	var box_target: TacticalBox
	if enemy_target == null:
		for box in state.tactical_boxes:
			if state._is_in_attack_range(unit, box.cell, offsets):
				box_target = box
				break
	var ball_target := enemy_target == null and box_target == null and state.ball.move_ticks_left == 0 and state._is_in_attack_range(unit, state.ball.cell, offsets)
	var found: Dictionary={"kind":0,"unit":enemy_target,"cell":enemy_target.cell} if enemy_target!=null else ({"kind":1,"box":box_target,"cell":box_target.cell} if box_target!=null else ({"kind":2,"cell":state.ball.cell} if ball_target else {}))
	found=AttackTimeline.pin_found(state,unit,found)
	var dump:=unit.skill_dump_pending
	if found.is_empty():
		if dump:
			state._apply_skill_life_loss(unit,data,unit.hp*int(skill.effect_params.hp_loss_percent)/100)
			close_skill(state,unit,data)
		return
	if not AttackTimeline.windup_found(state,unit,data,found):return
	var overloaded:=unit.skill_ammo_left<=int(skill.effect_params.overload_ammo)
	var rounds:=unit.skill_ammo_left if dump else 1
	var physical:=SkillRules.attack_value(unit,data)
	var magical:=roundi(data.attack*(100+unit.attack_bonus_percent)/100.0*int(skill.effect_params.magic_attack_percent)/100.0)
	if dump:
		state._apply_skill_life_loss(unit,data,unit.hp*int(skill.effect_params.hp_loss_percent)/100)
		unit.skill_ammo_left=0;unit.skill_dump_pending=false
	PusherRules.mark_attack(state,unit,found.cell)
	var radius:=int(data.branch_trait.effect_params.splash_radius_squared)
	for index in rounds:
		if unit.hp<=0:break
		if found.kind!=0:AttackTimeline.found_projectile(state,unit,data,found,physical,"physical")
		if found.kind!=1:
			for kind in (["physical","magical"] if overloaded else ["physical"]):
				var blast:=AttackTimeline.area_projectile(state,unit,data,found.cell,physical if kind=="physical" else magical,kind,radius)
				blast.splash_affects_objects=false
	if not dump:unit.skill_ammo_left-=1
	if unit.skill_ammo_left==0:close_skill(state,unit,data)
