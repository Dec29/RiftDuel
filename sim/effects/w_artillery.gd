class_name WArtilleryRules
extends RefCounted


static func activate(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	var skill := data.skills[unit.skill_index]
	var found := SwordRules.target(state,unit,data.attack_range,false)
	if found.is_empty():return
	SkillRules.activate(unit,data)
	unit.skill_ticks_left=0
	unit.w_action_tick=state.tick
	unit.w_action_kind=unit.skill_index
	var attack_value := roundi(SkillRules.attack_value(unit,data)*float(skill.effect_params["attack_mult"]))
	if skill.effect_type=="w_grenade":
		PusherRules.mark_attack(state,unit,found.cell)
		splash(state,unit.side,found.cell,attack_value,int(skill.effect_params["stun_ticks"]),unit)
		hit_object(state,unit,found,attack_value)
		unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
		return
	var targets := PusherRules.targets(state,unit,data.attack_range,false)
	targets.sort_custom(func(a: UnitState,b: UnitState) -> bool:return a.side!=unit.side if a.side!=b.side else (a.unit_id<b.unit_id if a.hp==b.hp else a.hp>b.hp))
	if targets.is_empty():
		var bomb := create_bomb(state,unit,found.cell,found.kind+1,skill)
		bomb.target_id=found.box.box_id if found.kind==1 else -1
		bomb.attack=attack_value
	else:
		for index in mini(targets.size(),int(skill.effect_params["target_count"])):
			var target := targets[index]
			var bomb := create_bomb(state,unit,target.cell,1,skill)
			bomb.target_id=target.unit_id
			bomb.attack=attack_value


static func create_bomb(state: MatchState, unit: UnitState, cell: Vector2i, kind: int, skill: SkillResource) -> WExplosive:
	var bomb := WExplosive.new()
	bomb.bomb_id=state.next_w_bomb_id
	state.next_w_bomb_id+=1
	bomb.source_id=unit.unit_id
	bomb.side=unit.side
	bomb.kind=kind
	bomb.cell=cell
	bomb.source_cell=unit.cell
	bomb.facing=unit.facing
	bomb.placed_tick=state.tick
	bomb.stun_ticks=int(skill.effect_params["stun_ticks"])
	if kind==0:bomb.expire_tick=state.tick+int(skill.effect_params["lifetime_ticks"])
	else:bomb.explode_tick=state.tick+int(skill.effect_params["delay_ticks"])
	state.w_bombs.append(bomb)
	return bomb


static func attack(state: MatchState, unit: UnitState, data: OperatorData) -> void:
	if unit.w_action_tick==state.tick or unit.displacement_ticks_left>0:return
	if unit.sleep_ticks_left>0:return
	if not AttackTimeline.advance(state,unit):return
	var skill := data.skills[unit.skill_index]
	if unit.attack_intent==null and skill.effect_type=="w_mine" and SkillRules.can_activate(unit,skill):
		var cells := mine_cells(state,unit,data)
		if not cells.is_empty():
			var cell := choose_mine_cell(state,unit,cells)
			SkillRules.activate(unit,data)
			unit.skill_ticks_left=0
			create_bomb(state,unit,cell,0,skill)
			unit.w_action_tick=state.tick
			unit.w_action_kind=1
			PusherRules.mark_attack(state,unit,cell)
			unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
			return
	if unit.bind_ticks_left > 0:return
	var found := SwordRules.target(state,unit,data.attack_range,false)
	found=AttackTimeline.pin_found(state,unit,found)
	if found.is_empty():return
	if not AttackTimeline.windup_found(state,unit,data,found):return
	var attack_value := SkillRules.attack_output_value(unit,data)
	PusherRules.mark_attack(state,unit,found.cell)
	unit.attack_ticks_left=SkillRules.attack_interval_ticks(unit,data)
	var grenade:=AttackTimeline.area_projectile(state,unit,data,found.cell,attack_value,"physical",1)
	grenade.splash_affects_objects=found.kind!=0


static func mine_cells(state: MatchState, unit: UnitState, data: OperatorData) -> Array[Vector2i]:
	var cells: Array[Vector2i]=[]
	for offset in data.attack_range:
		var cell := unit.cell+AttackRange.rotate_offset(offset,unit.facing)
		if cell.x<0 or cell.x>=state.CONFIG.GRID_COLUMNS or cell.y<0 or cell.y>=state.CONFIG.GRID_ROWS or state.terrain_at(cell)!="ground":continue
		if (unit.side==0 and cell.x<state.ball.cell.x) or (unit.side==1 and cell.x>state.ball.cell.x):continue
		if state.box_reserves_cell(cell) or state.item_reserves_cell(cell):continue
		var occupied := false
		for other in state.units:
			if other.hp>0 and other.side==unit.side and other.cell==cell:occupied=true
		for bomb in state.w_bombs:
			if bomb.kind==0 and bomb.cell==cell:occupied=true
		if not occupied:cells.append(cell)
	return cells


static func choose_mine_cell(state: MatchState, unit: UnitState, cells: Array[Vector2i]) -> Vector2i:
	var targets: Array[UnitState]=[]
	for enemy in state.units:
		if state.enemy_is_targetable(unit.side,enemy):targets.append(enemy)
	targets.sort_custom(func(a: UnitState,b: UnitState) -> bool:
		var at := SkillRules.taunt_level(a,state._operator_data[a.operator_id])
		var bt := SkillRules.taunt_level(b,state._operator_data[b.operator_id])
		return a.unit_id<b.unit_id if at==bt else at>bt)
	for enemy in targets:
		if enemy.cell in cells:return enemy.cell
	var closest: Array[Vector2i]=[]
	var distance := 100000
	for cell in cells:
		var candidate_distance := 100000
		for enemy in targets:candidate_distance=mini(candidate_distance,(enemy.cell-cell).length_squared())
		if candidate_distance<distance:closest.clear();distance=candidate_distance
		if candidate_distance==distance:closest.append(cell)
	return closest[0] if closest.size()==1 else closest[state.rng.next_u32()%closest.size()]


static func advance_bombs(state: MatchState) -> void:
	for bomb in state.w_bombs.duplicate():
		if not state.w_bombs.has(bomb):continue
		var source := owner(state,bomb.source_id)
		if bomb.kind==0:
			if source==null or state.tick>=bomb.expire_tick:
				state.w_bombs.erase(bomb)
				continue
			if bomb.explode_tick<0:
				for enemy in state.units:
					if state.enemy_is_targetable(bomb.side,enemy) and (enemy.cell-bomb.cell).length_squared()<=1:
						var skill: SkillResource=state._operator_data[source.operator_id].skills[source.skill_index]
						bomb.attack=roundi(SkillRules.attack_value(source,state._operator_data[source.operator_id])*float(skill.effect_params["attack_mult"]))
						bomb.explode_tick=state.tick+int(skill.effect_params["delay_ticks"])
						break
		elif bomb.kind==1:
			var target := owner(state,bomb.target_id)
			if target!=null:bomb.cell=target.cell
			else:bomb.explode_tick=state.tick
		elif bomb.kind==2:
			var exists := false
			for box in state.tactical_boxes:
				if box.box_id==bomb.target_id and box.hits_left>0:exists=true;bomb.cell=box.cell
			if not exists:bomb.explode_tick=state.tick
		elif bomb.kind==3:bomb.cell=state.ball.cell
		if bomb.explode_tick>=0 and state.tick>=bomb.explode_tick:detonate(state,bomb)


static func owner(state: MatchState, id: int) -> UnitState:
	for unit in state.units:
		if unit.unit_id==id and unit.hp>0:return unit
	return null


static func on_exit(state: MatchState, unit: UnitState) -> void:
	for bomb in state.w_bombs.duplicate():
		if not state.w_bombs.has(bomb):continue
		if bomb.kind==0 and bomb.source_id==unit.unit_id:state.w_bombs.erase(bomb)
		elif bomb.kind==1 and bomb.target_id==unit.unit_id:
			bomb.cell=unit.cell
			detonate(state,bomb)


static func detonate(state: MatchState, bomb: WExplosive) -> void:
	state.w_bombs.erase(bomb)
	state.w_explosion_events.append(PackedInt32Array([state.next_w_explosion_id,bomb.cell.x,bomb.cell.y,bomb.side,state.tick]))
	state.next_w_explosion_id+=1
	splash(state,bomb.side,bomb.cell,bomb.attack,bomb.stun_ticks,null)
	if bomb.kind==2:
		for box in state.tactical_boxes:
			if box.box_id==bomb.target_id and box.hits_left>0:
				# Box rewards require an actual source side; retained snapshot only carries identity.
				var source := UnitState.new(bomb.source_id,bomb.side,"w",bomb.source_cell,1,0,0,bomb.facing)
				TacticalRules.strike_box(state,source,box)
				break
	elif bomb.kind==3 and state.ball.move_ticks_left==0:
		state.ball.add_push(bomb.source_cell,bomb.attack,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,bomb.facing))


static func splash(state: MatchState, side: int, cell: Vector2i, attack_value: int, stun_ticks: int, source: UnitState) -> void:
	for enemy in state.units:
		var hit_source := source
		if enemy.operator_id=="stainless_cannon" and hit_source==null:hit_source=UnitState.new(-1,side,"w",cell,1,0,0)
		if enemy.hp<=0 or (not StainlessRules.is_damage_target(hit_source,enemy) if hit_source!=null else enemy.side==side) or (enemy.cell-cell).length_squared()>1:continue
		var data: OperatorData=state._operator_data[enemy.operator_id]
		var damage := Combat.calculate_damage(attack_value,SkillRules.defense_value(enemy,data),SkillRules.magic_resist_value(enemy,data),"physical",SkillRules.dodge_chance(enemy,data,"physical"),state.rng,"sniper",state._damage_taken_percent(enemy,"physical"))
		if state._apply_damage(enemy,data,damage,"physical",hit_source) and enemy.hp>0 and stun_ticks>0:SwordRules.stun(state,enemy,stun_ticks,source)


static func hit_object(state: MatchState, unit: UnitState, found: Dictionary, attack_value: int) -> void:
	if found.kind==1 and found.box.hits_left>0:TacticalRules.strike_box(state,unit,found.box)
	elif found.kind==2 and state.ball.move_ticks_left==0:state.ball.add_push(unit.cell,attack_value,state._ball_data,AttackRange.rotate_offset(Vector2i.RIGHT,unit.facing))
