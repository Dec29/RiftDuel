extends SceneTree
var failures := 0
var data := {"weedy":load("res://resources/operators/weedy.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.weedy
	check(op.validation_error().is_empty() and op.attack==677 and op.max_health==2133 and op.terrain_requirement=="both","Pinned E2 pusher raw stats/both terrain")
	var enemy: OperatorData=data.bagpipe.duplicate(true);enemy.operator_id="enemy_fixture";enemy.max_health=100000;enemy.defense=0
	data.enemy_fixture=enemy
	var strike := fixture(0)
	strike.units[0].sp=5;strike.units[0].attack_ticks_left=0
	strike.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(14,5),100000,0,100000))
	strike.step([],[])
	check(strike.units[1].hp==99746 and strike.units[1].cell==Vector2i(16,5) and strike.units[1].stun_ticks_left==36 and strike.units[0].sp==0,"S1 150percent physical, force3 minus weight1, stun1.2sec")
	var mode := fixture(1)
	mode.units[0].sp=70;mode.units[0].attack_ticks_left=0
	mode.step([],[])
	check(mode.units[0].skill_ticks_left==-2 and SkillRules.attack_value(mode.units[0],op)==2031 and SkillRules.attack_interval_ticks(mode.units[0],op)==115 and AttackRange.effective_offsets(mode.units[0],op).size()==4,"S2 automatic indefinite+200percent ATK,+220percent interval and extended range")
	StatusRules.apply_silence(mode,mode.units[0],30)
	check(SkillRules.attack_value(mode.units[0],op)==677 and AttackRange.effective_offsets(mode.units[0],op).size()==2,"Silence suspends permanent mode")
	var blast := fixture(2)
	blast.units[0].sp=33
	blast.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(14,5),100000,0,100000))
	blast.step([cast(blast)],[])
	check(blast.units[1].hp==98507 and blast.units[1].cell==Vector2i(17,5) and blast.units[1].rupture_until_tick==241,"S3 350percent magic593 plus three actual cells of300 true each")
	var hp := blast.units[1].hp
	check(DisplacementRules.apply_unit(blast,blast.units[0],blast.units[1],Vector2i.RIGHT,3)==0 and blast.units[1].hp==hp,"Already moving/blocked shift creates no phantom distance damage")
	blast.units[1].displacement_ticks_left=0;blast.units[1].cell=Vector2i(20,5)
	check(DisplacementRules.apply_unit(blast,blast.units[0],blast.units[1],Vector2i.RIGHT,3)==0 and blast.units[1].hp==hp,"Map edge blocks all distance and damage")
	blast.units[1].cell=Vector2i(16,5)
	var mover := blast.units[0]
	blast._retreat_unit(mover)
	check(DisplacementRules.apply_unit(blast,mover,blast.units[0],Vector2i.RIGHT,3)==2 and blast.units[0].hp==hp-600,"Existing trauma survives source retreat and other later pushes")
	blast.tick=241;StatusRules.expire_before_commands(blast,{})
	check(blast.units[0].rupture_until_tick==0 and blast.units[0].rupture_damage_per_cell==0,"Trauma expires and clears source state")
	var device := fixture(0)
	device.sides[0].next_deploy_discount=2
	var before := device.sides[0].cost
	device.step([InputCommand.new(device.tick,0,"weedy_cannon",-1,Vector2i(13,4),-1,0)],[])
	check(device.units.size()==2 and device.sides[0].cost==before-5 and device.sides[0].next_deploy_discount==2 and device.sides[0].cannon_cooldown_ticks==0,"Cannon consumes5, not Saileach discount, no cooldown until exit")
	check(not device.enemy_is_targetable(1,device.units[1]) and not device._apply_damage(device.units[1],MatchState.CANNON_DATA,99999,"true") and device.units[1].hp==100,"Device cannot be selected or damaged")
	device.units[0].sp=0
	for tick in 90:device.step([],[])
	check(device.units[0].sp==4,"Adjacent cannon grants one SP each3sec in addition to natural3")
	device.step([InputCommand.new(device.tick,2,"",1)],[])
	check(device.units.size()==1 and device.sides[0].cannon_cooldown_ticks==1050 and not device.cannon_available(0),"Manual cannon exit starts exact35sec independent cooldown")
	var life := fixture(2)
	life.step([InputCommand.new(life.tick,0,"weedy_cannon",-1,Vector2i(13,4),-1,0)],[])
	for tick in 600:life.step([],[])
	check(life.units.size()==1 and life.sides[0].cannon_cooldown_ticks==1050,"Exactly20sec cannon lifetime then35sec cooldown")
	var volley := fixture(2)
	volley.step([InputCommand.new(volley.tick,0,"weedy_cannon",-1,Vector2i(13,4),-1,0)],[])
	volley.units.append(UnitState.new(2,1,"enemy_fixture",Vector2i(14,4),100000,0,100000))
	volley.units[0].sp=33;volley.units[1].attack_ticks_left=0
	volley.step([cast(volley)],[])
	check(volley.units[2].hp==99407 and volley.units[1].nitrogen_shot_tick==volley.tick-1,"Adjacent cannon uses owner ATK for S3, no extra ordinary same-tick shot")
	var nearest := fixture(0)
	nearest.step([InputCommand.new(nearest.tick,0,"weedy_cannon",-1,Vector2i(13,4),-1,0)],[])
	nearest.units.append(UnitState.new(2,1,"enemy_fixture",Vector2i(16,4),100000,0,100000))
	nearest.units.append(UnitState.new(3,1,"enemy_fixture",Vector2i(14,4),100000,0,100000))
	nearest.units[1].attack_ticks_left=0;nearest.step([],[])
	check(nearest.units[2].hp==100000 and nearest.units[3].hp==99854,"Cannon ordinary attack uses585ATK, specialist coefficient and nearest target")
	var unauthorized := fixture(0)
	unauthorized.units.clear();var saved_cost := unauthorized.sides[0].cost
	unauthorized.step([InputCommand.new(unauthorized.tick,0,"weedy_cannon",-1,Vector2i(13,4),-1,0)],[])
	check(unauthorized.units.is_empty() and unauthorized.sides[0].cost==saved_cost,"No active owner cannot deploy a forged cannon")
	var high := MatchState.new(400,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[PackedStringArray(["weedy"]),PackedStringArray(["weedy"])])
	high.sides[0].cost=99;high.ball.cell=Vector2i(10,10)
	high.step([InputCommand.new(0,0,"weedy",-1,Vector2i(13,2),-1,0)],[])
	high.step([InputCommand.new(1,0,"weedy_cannon",-1,Vector2i(12,2),-1,0)],[])
	check(high.units.size()==2 and high.terrain_at(high.units[0].cell)=="high" and high.terrain_at(high.units[1].cell)=="high","Weedy and cannon both genuinely deploy on high terrain")
	var content: Dictionary=root.get_node("OperatorDB").network_content()
	for session: NetSession in [NetSession.new(content),RelaySession.new(content)]:
		var command: Array[InputCommand]=[InputCommand.new(0,0,"weedy_cannon",-1,Vector2i(13,4),-1,0)]
		session.remote_squad=PackedStringArray(["bagpipe"])
		check(not session.validate_squad_commands(command).is_empty(),"Both transports reject cannon without roster owner")
		session.remote_squad=PackedStringArray(["weedy"])
		check(session.validate_squad_commands(command).is_empty(),"Both transports admit registered owned cannon")
		session.free()
	for defeated in [false,true]:
		var owner_exit := fixture(0)
		owner_exit.step([InputCommand.new(owner_exit.tick,0,"weedy_cannon",-1,Vector2i(13,4),-1,0)],[])
		if defeated:
			owner_exit.units[0].hp=0
			owner_exit.step([],[])
		else:owner_exit._retreat_unit(owner_exit.units[0])
		check(owner_exit.units.is_empty() and owner_exit.sides[0].cannon_cooldown_ticks==1050,"Owner exit removes cannon and starts independent35sec cooldown, defeat=%s"%defeated)
	var a := fixture(2);var b := fixture(2)
	for state in [a,b]:state.units[0].sp=33;state.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(14,5),100000,0,100000))
	for tick in 900:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(cast(a))
		a.step(commands,[]);b.step(commands,[])
		check(a.state_hash()==b.state_hash(),"Shift/trauma/cooldown deterministic replay%d"%tick)
	print("WEEDY_CORE_OK" if failures==0 else "WEEDY_FAILED count%d"%failures)
	quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["weedy"]);var skills := PackedInt32Array([index])
	var state := MatchState.new(400,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state.step([InputCommand.new(0,0,"weedy",-1,Vector2i(13,5),-1,0)],[])
	if state.units.is_empty():push_error("Weedy legal deploy fixture failed");quit(1);return state
	state.units[0].attack_ticks_left=100000
	return state
func cast(state: MatchState) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,2)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
