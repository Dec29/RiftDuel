extends SceneTree
var failures := 0
var data := {"ifrit":load("res://resources/operators/ifrit.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.ifrit
	check(op.validation_error().is_empty() and op.max_health==1680 and op.attack==870 and op.defense==130 and op.magic_resist==20 and op.deploy_cost==34,"Pinned E2 raw stats")
	check(op.attack_range==[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(4,0),Vector2i(5,0)],"Exact six-cell straight range5-1")
	var target: OperatorData=data.bagpipe.duplicate(true)
	target.operator_id="enemy_fixture";target.max_health=100000;target.defense=500;target.magic_resist=50
	data.enemy_fixture=target
	var natural := fixture(0)
	for tick in 179:natural.step([],[])
	check(natural.units[0].sp==28,"6seconds natural6 plus Rhine2 from initial20")
	for tick in 300:natural.step([],[])
	check(natural.units[0].sp==40,"S1 ready naturally with periodicSP")
	natural.step([cast(natural,0)],[])
	check(SkillRules.attack_value(natural.units[0],op)==1044 and SkillRules.attack_interval_ticks(natural.units[0],op)==48 and natural.units[0].skill_ticks_left==599,"S1 ATK20percent/speed80,20seconds")
	var charged := fixture(1)
	for id in [1,2]:charged.units.append(UnitState.new(id,1,"enemy_fixture",Vector2i(13-id,2),100000,0,100000))
	charged.units[0].sp=21;charged.units[0].attack_ticks_left=0
	charged.step([],[])
	check(charged.units[0].sp==14 and charged.units[0].skill_activation_count==1,"All targets share one of3 stored charges")
	for index in [1,2]:
		check(charged.units[index].hp==99543 and SkillRules.defense_value(charged.units[index],target)==200 and SkillRules.magic_resist_value(charged.units[index],target)==30,"Line-wide250percent magic, flat300DEF reduction and40percent resist aura")
	charged.units[1].armor_break_defense_percent=80;charged.units[1].armor_break_ticks_left=120
	check(SkillRules.defense_value(charged.units[1],target)==160,"FlatDEF reduction composes before Schwarz final80percent")
	var hp := charged.units[1].hp
	charged.step([InputCommand.new(charged.tick,2,"",0)],[])
	for tick in 89:charged.step([],[])
	check(charged.units[0].hp==hp-129 and charged.units[1].hp==hp-129,"Three33percent burn pulses persist after source retreat using snapshot, no dodge rerolls")
	check(charged.units[0].burn_until_tick==0 and charged.units[0].burn_defense_reduce==0 and SkillRules.defense_value(charged.units[0],target)==400,"Burn/DEF reduction expire while independent armor break remains")
	var ground := fixture(2)
	ground.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(11,2),100000,0,100000))
	ground.units[0].sp=28;ground.step([cast(ground,2)],[])
	for tick in 29:ground.step([],[])
	check(ground.units[0].hp==1646 and ground.units[1].hp==99700 and SkillRules.magic_resist_value(ground.units[1],target)==18,"S3 first1second pulse:140percent, flat20 then40percent aura,2percentHP loss")
	ground.units[0].stun_ticks_left=100
	for tick in 30:ground.step([],[])
	check(ground.units[0].hp==1612 and ground.units[1].hp==99700,"Stun suppresses maintained damage but not scheduled HP loss")
	StatusRules.apply_silence(ground,ground.units[0],100)
	check(SkillRules.magic_resist_value(ground.units[1],target)==50,"Silenced source immediately removes resist aura; expired flat reduction not retained")
	for tick in 30:ground.step([],[])
	check(ground.units[0].hp==1612,"Silence pauses skill effects, clock still advances")
	var exact := fixture(2)
	exact.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(11,2),100000,0,100000))
	exact.units[0].sp=28;exact.step([cast(exact,2)],[])
	for tick in 599:exact.step([],[])
	check(exact.units[0].skill_ticks_left==0 and exact.units[0].hp==1000 and exact.units[1].hp==94000 and exact.units[0].sp==0,"Exactly20 pulses,600tick expiry, freezeSP during skill")
	for tick in 30:exact.step([],[])
	check(exact.units[1].flame_resist_ticks==0 and SkillRules.magic_resist_value(exact.units[1],target)==30,"One-second flat resist expires, live aura remains")
	for facing in 4:
		var ball := fixture(1)
		ball.units[0].facing=facing;ball.units[0].sp=7;ball.units[0].attack_ticks_left=0
		ball.ball.cell=ball.units[0].cell+AttackRange.rotate_offset(Vector2i(2,0),facing)
		ball._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);ball._ball_data.kick_threshold=100000
		ball.step([],[])
		check(ball.ball.accum==AttackRange.rotate_offset(Vector2i(2175,0),facing) and ball.units[0].sp==0,"Four-way charged ball uses raw2175, one charge, no AoE multiplied push")
		var box := fixture(1)
		box.units[0].facing=facing;box.units[0].sp=7;box.units[0].attack_ticks_left=0
		box.tactical_boxes=[TacticalBox.new(0,box.units[0].cell+AttackRange.rotate_offset(Vector2i(2,0),facing),3)]
		box.ball.cell=box.tactical_boxes[0].cell
		box.step([],[])
		check(box.tactical_boxes[0].hits_left==2 and box.ball.accum==Vector2i.ZERO and box.units[0].sp==0,"Line attack hits one prioritized box, not ball")
	var a := fixture(1);var b := fixture(1)
	for state in [a,b]:
		state.units[0].sp=21;state.units[0].attack_ticks_left=0
		state.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(11,2),100000,0,100000))
	for tick in 900:
		a.step([],[]);b.step([],[])
		check(a.state_hash()==b.state_hash(),"Burn/SP/aura per-tick replay%d"%tick)
	check(op.attack==870 and op.skills[1].effect_params.burn_attack_percent==33,"Resources stay read-only")
	print("IFRIT_CORE_OK" if failures==0 else "IFRIT_FAILED count%d"%failures)
	quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["ifrit"]);var skills := PackedInt32Array([index])
	var state := MatchState.new(134,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state.step([InputCommand.new(0,0,"ifrit",-1,Vector2i(13,2),-1,2)],[])
	state.units[0].attack_ticks_left=100000
	return state
func cast(state: MatchState,index: int) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
