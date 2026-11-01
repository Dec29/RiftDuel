class_name FlagRules
extends RefCounted


static func advance(state: MatchState) -> void:
	for source in state.units:
		var source_data: OperatorData = state._operator_data[source.operator_id]
		var flag_skill := source_data.skills[source.skill_index]
		if source.hp > 0 and SkillRules.active_ticks(source) > 0 and flag_skill.effect_type == "flag_burst":
			for enemy in state.units:
				if enemy.hp > 0 and enemy.side != source.side and enemy.operator_id != "weedy_cannon" and absi(enemy.cell.x - source.flag_cell.x) <= 1 and absi(enemy.cell.y - source.flag_cell.y) <= 1:
					StatusRules.add_control(state,enemy,"slow",1)
		if source.flag_burst_pending and source.flag_landing_ticks_left == 0:
			source.flag_burst_pending = false
			if source.hp > 0 and SkillRules.active_ticks(source) > 0:
				var attack := roundi(SkillRules.attack_value(source,source_data) * int(flag_skill.effect_params["burst_attack_percent"]) / 100.0)
				for enemy in state.units:
					if source.hp <= 0: break
					if enemy.hp <= 0 or enemy.side == source.side or enemy.operator_id == "weedy_cannon" or absi(enemy.cell.x - source.flag_cell.x) > 1 or absi(enemy.cell.y - source.flag_cell.y) > 1: continue
					var enemy_data: OperatorData = state._operator_data[enemy.operator_id]
					var damage := Combat.calculate_damage(attack,SkillRules.defense_value(enemy,enemy_data),SkillRules.magic_resist_value(enemy,enemy_data),"physical",SkillRules.dodge_chance(enemy,enemy_data,"physical"),state.rng,SkillRules.damage_profession_id(source_data),state._damage_taken_percent(enemy, "physical"))
					state._apply_damage(enemy,enemy_data,damage,"physical",source)
					if enemy.hp > 0 and enemy.chen_slashes_left==0:
						var resistant := StatusRules.has_resistance(state,enemy)
						var duration := int(flag_skill.effect_params["stun_ticks"])
						StatusRules.add_control(state,enemy,"stun",duration * state.CONFIG.STATUS_RESISTANCE_DURATION_PERCENT / 100 if resistant else duration,source)


static func activate(state: MatchState, unit: UnitState, skill: SkillResource, side: int) -> void:
	unit.flag_cell = unit.cell
	var chosen: UnitState = null
	for candidate in state.units:
		if candidate.hp <= 0 or not state._is_in_attack_range(unit, candidate.cell, skill.attack_range_override): continue
		var candidate_data: OperatorData = state._operator_data[candidate.operator_id]
		if skill.effect_type == "flag_heal":
			if candidate.side != unit.side or candidate_data.profession_id == "summon": continue
			if chosen == null or candidate.hp * SkillRules.max_health_value(chosen, state._operator_data[chosen.operator_id]) < chosen.hp * SkillRules.max_health_value(candidate, candidate_data): chosen = candidate
		else:
			if not state.enemy_is_targetable(unit.side,candidate): continue
			var priority := SkillRules.taunt_level(candidate,candidate_data)
			var selected_priority := -1
			if chosen != null:
				var chosen_data: OperatorData = state._operator_data[chosen.operator_id]
				selected_priority = SkillRules.taunt_level(chosen,chosen_data)
			var candidate_ground := state.terrain_at(candidate.cell) == "ground"
			var chosen_ground := chosen != null and state.terrain_at(chosen.cell) == "ground"
			if chosen == null or (candidate_ground and not chosen_ground) or (candidate_ground == chosen_ground and priority > selected_priority): chosen = candidate
	if chosen != null: unit.flag_cell = chosen.cell
	if chosen != null and skill.effect_type == "flag_burst" and state.terrain_at(chosen.cell) != "ground":
		var best_occupied := 2
		var best_distance := 2147483647
		for row in state.CONFIG.GRID_ROWS:
			for column in state.CONFIG.GRID_COLUMNS:
				var candidate_cell := Vector2i(column,row)
				if state.terrain_at(candidate_cell) != "ground" or not state._is_in_attack_range(unit,candidate_cell,skill.attack_range_override): continue
				var occupied := 0
				for occupant in state.units:
					if occupant.hp > 0 and occupant.cell == candidate_cell: occupied = 1
				var distance := (candidate_cell - chosen.cell).length_squared()
				if occupied < best_occupied or (occupied == best_occupied and distance < best_distance):
					best_occupied = occupied
					best_distance = distance
					unit.flag_cell = candidate_cell
	if skill.effect_type == "flag_burst":
		state.sides[side].cost = mini(state.CONFIG.COST_MAX, state.sides[side].cost + int(skill.effect_params["instant_cost"]))
		unit.flag_landing_ticks_left = int(skill.effect_params["landing_ticks"])
		unit.flag_burst_pending = true
