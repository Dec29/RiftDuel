extends SceneTree
var failures := 0
var data := {}
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	for id in ["ines","vigil"]:
		data[id]=load("res://resources/operators/"+id+".tres")
		check(data[id].validation_error().is_empty(),id+": "+data[id].validation_error())
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;data.target=dummy
	check(MatchState.VIGIL_WOLF_DATA.validation_error().is_empty(),"wolf strict validation")
	for index in 3:
		var state := fixture("ines",index)
		var unit := deploy(state,"ines",Vector2i(12,5))
		if index==2:
			check(unit==null and state.sides[0].cost==99 and state.sides[0].ines_shadow_cell==Vector2i(12,5) and not state.sides[0].cooldowns.has("ines"),"S3 first deploy zero fee, immediate retreat, sentinel, no cooldown")
			unit=deploy(state,"ines",Vector2i(14,5))
			check(unit!=null and unit.cell==Vector2i(14,5) and unit.skill_ticks_left==479 and state.sides[0].cost==88,"S3 second deployment original11 cost, fixed cell and16sec")
			check(SkillRules.attack_value(unit,data.ines)==1531,"S3 original ATK+160%")
			continue
		check(unit!=null and state.sides[0].cost==88,"Ines deployment costs11")
		var enemy := add_enemy(state,Vector2i(13,5));unit.attack_ticks_left=1
		if index==1:unit.sp=20
		var commands: Array[InputCommand]=[]
		if index==1:commands.append(InputCommand.new(state.tick,1,"",unit.unit_id,Vector2i.ZERO,1))
		state.step(commands,[])
		check(enemy.bind_ticks_left>0 and unit.ines_stolen_attack==90 and enemy.ines_attack_loss==90,"First hit bind and90 attack steal S%d"%(index+1))
		if index==0:
			check(state.sides[0].cost==90 and enemy.ines_dot_until>0,"S1 two cost and original DOT")
			unit.attack_ticks_left=10000;var hp := enemy.hp
			for t in 90:state.step([],[])
			check(enemy.hp<hp and enemy.ines_dot_until==0,"S1 independent3sec DOT expires")
		else:
			check(unit.ines_speed_gain==7 and enemy.ines_speed_loss==7 and state.sides[0].cost==89,"S2 7AS steal and1 cost")
			check(SkillRules.attack_value(unit,data.ines)==1426,"S2 original110% additive with flat stolen90")
			unit.skill_ticks_left=1;state.step([],[]);state.step([],[])
			check(unit.ines_speed_gain==0 and enemy.ines_speed_loss==0,"S2 attack speed steal expires")
		state._retreat_unit(unit);AuraRules.refresh(state)
		check(enemy.ines_attack_loss==0 and state.sides[0].ines_shadow_cell==Vector2i(12,5) and enemy.ines_shadow_slow==30,"Exit releases steals, persists stationary shadow slow")
	for index in 3:
		var state := fixture("vigil",index)
		var unit := deploy(state,"vigil",Vector2i(14,4))
		check(unit!=null and state.sides[0].cost==82,"Vigil high tile17cost")
		var token := deploy(state,"vigil_wolf",Vector2i(15,5))
		check(token!=null and token.vigil_wolf_layers==2 and SkillRules.block_count_value(token,MatchState.VIGIL_WOLF_DATA)==2,"Zero cost wolf starts2 shadows andblock2")
		check(not state.can_deploy(0,"vigil_wolf",Vector2i(14,5)),"Max1wolf")
		state._apply_damage(token,MatchState.VIGIL_WOLF_DATA,99999,"true")
		check(token.hp==1100 and token.vigil_wolf_layers==1,"Lethal loses1 shadow andfully heals")
		token.vigil_regrow_tick=state.tick;state.step([],[])
		check(token.vigil_wolf_layers==2,"25sec regeneration timer")
		unit.sp=data.vigil.skills[index].sp_required;var before := state.sides[0].cost
		if index==2:state.step([InputCommand.new(state.tick,1,"",unit.unit_id,Vector2i.ZERO,2)],[])
		else:state.step([],[])
		if index==0:check(state.sides[0].cost==before+7 and token.vigil_wolf_layers==3,"S1 automatic7cost and1shadow")
		elif index==1:check(state.sides[0].cost==before+2 and token.vigil_enhanced_attack,"S2 auto2cost and next wolf200%")
		else:
			check(unit.skill_ticks_left==449 and unit.sp==0,"S3 manual15sec consumes35SP")
			unit.attack_ticks_left=10000;token.attack_ticks_left=10000
			for t in 449:state.step([],[])
			check(state.sides[0].cost==99,"S3 total12cost plus natural income capped99")
		state._retreat_unit(unit)
		check(token not in state.units,"Owner exits removes wolf")
	var damage_state := fixture("vigil",2);var owner := deploy(damage_state,"vigil",Vector2i(14,4));var wolf := deploy(damage_state,"vigil_wolf",Vector2i(15,5));var enemy := add_enemy(damage_state,Vector2i(14,5));owner.attack_ticks_left=1;wolf.attack_ticks_left=1
	damage_state.step([],[])
	check(enemy.hp<100000 and damage_state.enemy_is_blocked(enemy,wolf.unit_id),"Wolf attacks adjacent blocked enemy outside self range")
	var precise := fixture("vigil",2)
	var shooter := deploy(precise,"vigil",Vector2i(14,4));var blocker := deploy(precise,"vigil_wolf",Vector2i(15,5));var blocked := add_enemy(precise,Vector2i(14,5))
	precise._operator_data.target=precise._operator_data.target.duplicate(true);precise._operator_data.target.defense=400
	blocker.attack_ticks_left=10000;shooter.attack_ticks_left=1;precise.step([],[])
	var expected := Combat.calculate_damage(693,225,0,"physical",0,RNG.new(1),"vanguard")
	check(blocked.hp==100000-expected,"Vigil exactly150% and175DEF ignored on wolf blocked target")
	shooter.attack_ticks_left=10000;blocker.attack_ticks_left=1;var prior := blocked.hp;precise.step([],[])
	expected=2*Combat.calculate_damage(371,225,0,"physical",0,RNG.new(1),"vanguard")
	check(blocked.hp==prior-expected,"Two wolf shadows hit twice and inherit vanguard coefficient/175DEF ignore")
	for id in ["ines","vigil"]:
		for index in 3:
			var a := fixture(id,index);var b := fixture(id,index)
			for s in [a,b]:deploy(s,id,Vector2i(12,5) if id=="ines" else Vector2i(14,4));add_enemy(s,Vector2i(15,5))
			for t in 500:a.step([],[]);b.step([],[]);check(a.state_hash()==b.state_hash(),"Deterministic replay %s%d tick%d"%[id,index,t])
	var recall := fixture("ines",2)
	deploy(recall,"ines",Vector2i(12,5))
	var touched := add_enemy(recall,Vector2i(13,5));var distant := add_enemy(recall,Vector2i(13,8))
	var recalled := deploy(recall,"ines",Vector2i(15,5))
	check(touched.hp<100000 and distant.hp==100000 and recalled.cell==Vector2i(15,5) and recall.sides[0].ines_shadow_cell.x<0,"S3 real stationary recall corridor excludes remote target")
	var hashed := fixture("ines",0);deploy(hashed,"ines",Vector2i(12,5))
	for field in ["ines_stolen_attack","ines_attack_loss","ines_speed_gain","ines_speed_loss","ines_shadow_slow","ines_dot_until","ines_dot_next","ines_dot_attack","ines_dot_source","vigil_owner_id","vigil_wolf_layers","vigil_regrow_tick","vigil_enhanced_victim"]:
		var old := hashed.state_hash();hashed.units[0].set(field,hashed.units[0].get(field)+1);check(old!=hashed.state_hash(),"Hash sensitivity "+field)
	var old := hashed.state_hash();hashed.units[0].ines_target_ids.append(99);check(old!=hashed.state_hash(),"Target ID hash")
	old=hashed.state_hash();hashed.units[0].ines_target_speed.append(7);check(old!=hashed.state_hash(),"Target speed hash")
	old=hashed.state_hash();hashed.sides[0].ines_first_shadow_used=true;check(old!=hashed.state_hash(),"First shadow use hash")
	old=hashed.state_hash();hashed.sides[0].ines_shadow_cell=Vector2i(12,5);check(old!=hashed.state_hash(),"Shadow cell hash")
	print("VANGUARD_OK failures=",failures)
	quit(0 if failures==0 else 1)
func fixture(id: String,index:int) -> MatchState:
	var state := MatchState.new(812,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[[id],["target"]],[[index],[0]])
	state.sides[0].cost=99;return state
func deploy(state: MatchState,id:String,cell:Vector2i) -> UnitState:
	state.step([InputCommand.new(state.tick,0,id,-1,cell,-1,0)],[])
	state.ball.cell=Vector2i(5,5)
	for unit in state.units:
		if unit.operator_id==id:return unit
	return null
func add_enemy(state:MatchState,cell:Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.next_unit_id+=1;state.units.append(unit);return unit
