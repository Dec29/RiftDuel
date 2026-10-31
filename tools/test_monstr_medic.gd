extends SceneTree
var failures := 0
const ID := "mon3tr_operator"
const TOKEN := "mon3tr_reconstruction"
var operators := {}
func check(value: bool, label: String) -> void:
	if not value:failures+=1;push_error(label)
func _initialize() -> void:
	operators[ID]=load("res://resources/operators/mon3tr_operator.tres")
	var ally := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true)
	ally.operator_id="ally";ally.max_health=10000;ally.attack=0;ally.terrain_requirement="both"
	operators.ally=ally
	var foe := ally.duplicate(true);foe.operator_id="foe";foe.max_health=100000;foe.defense=10000;foe.magic_resist=100
	operators.foe=foe
	var s := fixture(0);var actor := s.units[0]
	for cell in [Vector2i(12,2),Vector2i(12,3),Vector2i(13,3),Vector2i(14,3)]:add(s,"ally",0,cell,1000)
	actor.sp=2;actor.attack_ticks_left=0;s.step([],[])
	check(actor.skill_activation_count==1 and actor.sp==1,"S1 actual attack-trigger spends2SP and heals restore1SP")
	check(s.units[1].hp==1528 and s.units[2].hp==1396 and s.units[3].hp==1297 and s.units[4].hp==1223,"S1 four-link200% heal with75% jump decay and one50% profession healing factor")
	check(actor.last_attack_is_heal,"Actual chain heal marks presentation event")
	s=fixture(1);actor=s.units[0];var token := deploy_token(s)
	check(token!=null and token.reconstruct_owner_id==actor.unit_id,"Reconstruction real3cost deployment and owner")
	check(s.sides[0].cost==78 and not MonstrMedicRules.available(s,0),"Summon paid3 after owner18; unique simultaneous summon")
	var a := add(s,"ally",0,Vector2i(12,3),1000);add(s,"ally",0,Vector2i(14,3),1000)
	actor.sp=15;actor.attack_ticks_left=0
	s.step([InputCommand.new(s.tick,1,"",actor.unit_id,Vector2i.ZERO,1)],[])
	check(actor.skill_ticks_left==899 and actor.sp==0,"S2 actual manual30second activation")
	check(actor.last_attack_target_x==token.cell.x and actor.last_attack_target_y==token.cell.y,"S2 full-health reconstruction has priority")
	check(actor.monstr_overload_speed==56 and a.monstr_overload_speed==56,"S2 synergy20 multiplied2.8, applied to healer and link targets")
	var before := a.hp;var due := actor.monstr_echo_tick
	while s.tick<=due:s.step([],[])
	check(a.hp>before and actor.monstr_echo_tick==-1,"S2 independent0.6second delayed second chain")
	actor.monstr_overload_until_tick=s.tick+10;actor.monstr_synergy_until_tick=s.tick+100;actor.monstr_synergy_speed=20
	s.tick+=11;AuraRules.refresh(s)
	check(actor.attack_speed_bonus==20,"Baseline and strengthened synergy have independent expiry; later baseline survives boost expiry")
	check(SkillRules.healing_received(token,s._operator_data[TOKEN],100,s.units[2])==0,"Other units cannot directly heal reconstruction")
	check(SkillRules.healing_received(token,s._operator_data[TOKEN],100,actor)==100,"Bound Mon3tr bypasses reconstruction healing exclusion")
	s=fixture(2);actor=s.units[0];actor.sp=15
	s.step([InputCommand.new(s.tick,1,"",actor.unit_id,Vector2i.ZERO,2)],[])
	check(actor.sp==15 and actor.skill_ticks_left==0,"S3 no reconstruction rejects without spendingSP")
	token=deploy_token(s);var destination := token.cell;var origin := actor.cell
	var enemy := add(s,"foe",1,Vector2i(12,3),100000)
	actor.attack_ticks_left=0
	s.step([InputCommand.new(s.tick,1,"",actor.unit_id,Vector2i.ZERO,2)],[])
	check(actor.cell==destination and actor.monstr_origin_cell==origin and MonstrMedicRules.token_for(s,actor)==null,"S3 real instant transition consumes reconstruction and reserves origin")
	check(SkillRules.max_health_value(actor,operators[ID])==6735 and SkillRules.block_count_value(actor,operators[ID])==3,"S3 HP+5000 and block+2")
	check(SkillRules.attack_interval_ticks(actor,operators[ID])==34,"S3 interval2.85-1.5 with self-heal synergy20AS rounds34ticks")
	check(enemy.hp<100000,"S3 true attack deals damage through100RES and10000DEF using medic output coefficient")
	check(s.item_reserves_cell(origin) and not DeployRules.is_legal(0,operators.ally,origin,s.ball.cell,s.units,s.sides[0],s._arena,s.platform_cells),"Reserved return cell blocks deployment and shared tactical/displacement occupancy")
	s._apply_damage(actor,operators[ID],1000000,"true")
	check(actor.cell==origin and actor.hp==1 and actor.skill_ticks_left==0 and actor.monstr_return_guard_ticks==30,"S3 lethal hit returns alive at1HP with1second fatal guard")
	check(not s.item_reserves_cell(origin) and MonstrMedicRules.available(s,0),"Return clears reservation and releases reconstruction cooldown if absent")
	s._apply_damage(actor,operators[ID],1000000,"true");check(actor.hp==1,"Return guard prevents immediate lethal followup")
	s=fixture(2);actor=s.units[0];token=deploy_token(s);origin=actor.cell;actor.sp=15
	s.step([InputCommand.new(s.tick,1,"",actor.unit_id,Vector2i.ZERO,2)],[])
	actor.skill_ticks_left=1;s.step([],[])
	check(actor.cell==origin and actor.monstr_origin_cell==Vector2i(-1,-1) and actor.skill_ticks_left==0,"Natural duration ends at original cell")
	s=fixture(0);actor=s.units[0];token=deploy_token(s)
	actor.attack_ticks_left=100000;var hp := token.hp
	for tick in 3:s.step([],[])
	check(hp-token.hp==8,"Reconstruction loses8HP every3ticks independently of owner basic attacks")
	s._retreat_unit(actor)
	check(s.units.is_empty() and not s.item_reserves_cell(Vector2i(13,2)),"Owner retreat removes bound reconstruction and all reserved cells")
	var first := fixture(2);var second := fixture(2)
	for state in [first,second]:deploy_token(state);state.units[0].sp=15
	for tick in 900:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(InputCommand.new(first.tick,1,"",first.units[0].unit_id,Vector2i.ZERO,2))
		first.step(commands,[]);second.step(commands,[])
		check(first.state_hash()==second.state_hash(),"Everytick deterministic reconstruction/transformation replay%d"%tick)
	print("MONSTR_MEDIC_OK failures=",failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var state := MatchState.new(129,operators,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[[ID,"ally"],["foe"]],[[index,0],[0]])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state.step([InputCommand.new(0,0,ID,-1,Vector2i(13,2),-1,2)],[])
	return state
func deploy_token(state: MatchState) -> UnitState:
	state.step([InputCommand.new(state.tick,0,TOKEN,-1,Vector2i(13,3),-1,2)],[])
	return MonstrMedicRules.token_for(state,state.units[0])
func add(state: MatchState, id: String, side: int, cell: Vector2i, hp: int) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,side,id,cell,hp,0,100000)
	state.next_unit_id+=1;state.units.append(unit);return unit
