extends SceneTree
var failures := 0
var data := {"magallan":load("res://resources/operators/magallan.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres"),"silverash":load("res://resources/operators/silverash.tres"),"ifrit":load("res://resources/operators/ifrit.tres"),"mostima":load("res://resources/operators/mostima.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.magallan
	check(op.validation_error().is_empty() and op.max_health==1103 and op.attack==469 and op.skills.size()==3,"Pinned Magallan stats and three skills")
	for id in MatchState.DRONE_IDS:check((MatchState.DRONE_DATA[id] as OperatorData).validation_error().is_empty(),"Validated drone "+id)
	var s := fixture(0)
	check(s.sides[0].drone_stock==5 and not s.drone_available(0,"magallan_drone_l"),"Initial5 and carried-skill module restriction")
	s.sides[0].next_deploy_discount=2
	var cost := s.sides[0].cost
	deploy(s,Vector2i(13,3))
	check(s.units.size()==2 and s.sides[0].drone_stock==4 and s.sides[0].cost==cost-3 and s.sides[0].next_deploy_discount==2 and s.sides[0].drone_cooldown_ticks==300,"Deployment binding, stock, exact3cost, independent10sec cooldown, no discount consumption")
	check(s.units[1].drone_owner_id==0 and not s.enemy_is_targetable(1,s.units[1]),"Bound drone concealed from direct selection")
	s.sides[0].drone_cooldown_ticks=0;deploy(s,Vector2i(14,3))
	s.sides[0].drone_cooldown_ticks=0;deploy(s,Vector2i(15,3))
	check(s.units.size()==4 and s.sides[0].drone_stock==2 and not s.drone_available(0,"magallan_drone_f"),"Three same-module drones coexist; fourth rejected")
	var drone := s.units[1]
	s.tick=drone.deployed_tick+599
	check(not s.enemy_is_targetable(1,drone),"Concealment remains before20sec")
	s.tick+=1
	check(s.enemy_is_targetable(1,drone),"Concealment expires exactly20sec")
	s.tick=drone.deployed_tick+1
	var reveal := UnitState.new(8,1,"silverash",drone.cell+Vector2i.RIGHT,2560,0,100000,2)
	s.units.append(reveal)
	check(s.enemy_is_targetable(1,drone),"SilverAsh live attack-range reveal exposes hidden drone")
	reveal.silence_ticks_left=10
	check(not s.enemy_is_targetable(1,drone),"Silenced SilverAsh cannot reveal")
	reveal.silence_ticks_left=0;reveal.cell=Vector2i(1,1)
	check(not s.enemy_is_targetable(1,drone),"Leaving reveal range conceals again")
	drone.silence_ticks_left=10
	check(s.enemy_is_targetable(1,drone),"Drone talent silence exposes it")
	drone.silence_ticks_left=0;s.units.erase(reveal)
	s.units[0].sp=30;s.step([cast(s)],[])
	check(s.units[0].skill_ticks_left==449,"S1 manual15sec activation")
	for tick in 449:s.step([],[])
	check(s.units.size()==1 and s.sides[0].drone_stock==5,"Skill end recalls all live drones and returns stock")
	var lost := fixture(0);deploy(lost,Vector2i(13,3));var paid := lost.sides[0].cost
	lost._retreat_unit(lost.units[1])
	check(lost.sides[0].drone_stock==4 and lost.sides[0].cost==paid,"Manual drone retreat refunds neither stock nor cost")
	lost.sides[0].drone_cooldown_ticks=0;deploy(lost,Vector2i(13,3));lost.units[1].hp=0;lost.step([],[])
	check(lost.units.size()==1 and lost.sides[0].drone_stock==3,"Destroyed drone does not return inventory")
	lost.sides[0].drone_cooldown_ticks=0;deploy(lost,Vector2i(13,3));lost._retreat_unit(lost.units[0])
	check(lost.units.is_empty() and lost.sides[0].drone_stock==2,"Owner retreat removes bound drones without inventory return")
	var death := fixture(0);deploy(death,Vector2i(13,3));death.units[0].hp=0;death.step([],[])
	check(death.units.is_empty(),"Owner defeat removes bound drones")
	var expired_dead := fixture(0);deploy(expired_dead,Vector2i(13,3))
	expired_dead.units[0].skill_ticks_left=1;expired_dead.units[0].hp=0;expired_dead.step([],[])
	check(expired_dead.units.is_empty() and expired_dead.sides[0].drone_stock==4,"Owner death on skill-final tick does not refund drones")
	var enemy: OperatorData=data.bagpipe.duplicate(true);enemy.operator_id="enemy_fixture";enemy.max_health=100000;enemy.defense=0;data.enemy_fixture=enemy
	var control := fixture(0);deploy(control,Vector2i(13,3));var target := UnitState.new(2,1,"enemy_fixture",Vector2i(14,3),100000,0,100000)
	control.units.append(target);control.tick=91;DroneRules.advance_control(control)
	check(target.slow_ticks_left==30 and SkillRules.attack_interval_ticks(target,enemy)==30,"F passive pulse slows1sec without attack-speed change")
	control.units[0].sp=30;control.step([cast(control)],[])
	check(target.bind_ticks_left==75,"F S1 immediately binds2.5sec")
	check(DisplacementRules.apply_unit(control,control.units[0],target,Vector2i.RIGHT,2)==1,"Bind does not block external displacement")
	var laser := fixture(1);deploy(laser,Vector2i(13,3));laser.units[0].sp=38;laser.step([cast(laser)],[])
	check(SkillRules.attack_interval_ticks(laser.units[0],op)==19 and SkillRules.attack_interval_ticks(laser.units[1],MatchState.DRONE_DATA.magallan_drone_l)==12,"S2 +150speed applies to body and drone")
	check(Array((MatchState.DRONE_DATA.magallan_drone_l as OperatorData).attack_range)==[Vector2i.ZERO,Vector2i.RIGHT],"Approved L range self plus forward cell")
	laser.units.append(UnitState.new(2,1,"enemy_fixture",Vector2i(14,3),100000,0,100000))
	laser.units.append(UnitState.new(3,1,"enemy_fixture",Vector2i(15,3),100000,0,100000))
	laser.units[1].attack_ticks_left=0;DroneRules.attack(laser,laser.units[1],MatchState.DRONE_DATA.magallan_drone_l)
	check(laser.units[2].hp==99898 and laser.units[3].hp==99898,"Approved L active cardinal splash retains509ATK supporter coefficient")
	for facing in 4:
		var ball_test := fixture(1);deploy(ball_test,Vector2i(13,3));var unit := ball_test.units[1]
		unit.facing=facing;unit.attack_ticks_left=0
		ball_test.ball.cell=unit.cell+AttackRange.rotate_offset(Vector2i.RIGHT,facing)
		var before: Vector2i=ball_test.ball.accum
		DroneRules.attack(ball_test,unit,MatchState.DRONE_DATA.magallan_drone_l)
		check(unit.last_attack_tick==ball_test.tick and ball_test.ball.accum==before+AttackRange.rotate_offset(Vector2i.RIGHT,facing)*509,"L four-facing ball push remains raw509, facing%d"%facing)
	var gun := fixture(2);deploy(gun,Vector2i(12,2));gun.units[0].sp=38;gun.step([cast(gun)],[])
	check(SkillRules.attack_value(gun.units[0],op)==1173 and SkillRules.attack_value(gun.units[1],MatchState.DRONE_DATA.magallan_drone_a)==1883,"S3 +150percent ATK body and owned drone")
	gun.units.append(UnitState.new(2,1,"enemy_fixture",Vector2i(13,2),100000,0,100000));gun.units.append(UnitState.new(3,1,"enemy_fixture",Vector2i(14,2),100000,0,100000));gun.units[1].attack_ticks_left=0
	DroneRules.attack(gun,gun.units[1],MatchState.DRONE_DATA.magallan_drone_a)
	check(gun.units[2].hp==99623 and gun.units[3].hp==99623,"Active A splash uses1.25 radius on grid and supporter20percent damage")
	var hidden := fixture(0);deploy(hidden,Vector2i(13,3));var flame := UnitState.new(2,1,"ifrit",Vector2i(14,3),1680,0,0,2,2);hidden.units.append(flame)
	FlameRules.attack(hidden,flame,data.ifrit,false)
	check(hidden.units[1].hp==2000 and flame.last_attack_tick==-1,"Ifrit does not fire normal attack at concealed-only drone")
	FlameRules.attack(hidden,flame,data.ifrit,true)
	check(hidden.units[1].hp<2000,"Maintained ground AoE hits hidden drone")
	var caster := UnitState.new(3,1,"mostima",Vector2i(14,3),1831,0,0,2,1);hidden.units.append(caster);var hp := hidden.units[1].hp
	SplashCasterRules.attack(hidden,caster,data.mostima,true,false)
	check(hidden.units[1].hp<hp and hidden.units[1].stun_ticks_left==30,"Mostima whole-field lock hits hidden drone")
	var no_owner := fixture(0);no_owner.units.clear();deploy(no_owner,Vector2i(13,3));check(no_owner.units.is_empty(),"Forged drone without active owner rejected")
	var content: Dictionary=root.get_node("OperatorDB").network_content()
	for session: NetSession in [NetSession.new(content),RelaySession.new(content)]:
		var commands: Array[InputCommand]=[InputCommand.new(0,0,"magallan_drone_f",-1,Vector2i(13,3),-1,0)]
		session.remote_squad=PackedStringArray(["bagpipe"]);check(not session.validate_squad_commands(commands).is_empty(),"Both transports reject missing-owner drone")
		session.remote_squad=PackedStringArray(["magallan"]);check(session.validate_squad_commands(commands).is_empty(),"Both transports accept owned drone ID")
		session.free()
	var a := fixture(2);var b := fixture(2)
	for tick in 900:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(InputCommand.new(a.tick,0,"magallan_drone_a",-1,Vector2i(12,2),-1,0))
		if tick==300:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,2))
		a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Deterministic drone stock/recall/conceal replay%d"%tick)
	print("MAGALLAN_CORE_OK" if failures==0 else "MAGALLAN_CORE_FAILED count%d"%failures)
	quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["magallan"]);var skills := PackedInt32Array([index])
	var state := MatchState.new(400,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state.step([InputCommand.new(0,0,"magallan",-1,Vector2i(13,2),-1,0)],[])
	state.units[0].attack_ticks_left=100000
	return state
func deploy(state: MatchState, cell: Vector2i) -> void:
	var source := DroneRules.owner(state,0)
	var id: String=MatchState.DRONE_IDS[source.skill_index] if source!=null else "magallan_drone_f"
	state.step([InputCommand.new(state.tick,0,id,-1,cell,-1,0)],[])
func cast(state: MatchState) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
