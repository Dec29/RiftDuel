extends SceneTree
var failures := 0
var data := {"mostima":load("res://resources/operators/mostima.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.mostima
	check(op.validation_error().is_empty() and op.attack==834 and op.magic_resist==20 and op.deploy_cost==34 and op.attack_range.size()==9 and op.terrain_requirement=="high","E2 raw stats and exact base range")
	var enemy: OperatorData=data.bagpipe.duplicate(true);enemy.operator_id="enemy_fixture";enemy.max_health=100000;enemy.magic_resist=0
	data.enemy_fixture=enemy
	var natural := fixture(1)
	for tick in 299:natural.step([],[])
	check(natural.units[0].sp==44,"Caster aura gives1.4SP/sec, includes self")
	var normal := fixture(0)
	add_enemies(normal);normal.units[0].attack_ticks_left=0;normal.step([],[])
	check(normal.units[1].hp==99750 and normal.units[2].hp==99750 and normal.units[3].hp==100000,"Normal splash hits primary and orthogonal neighbor, not diagonal")
	var first := fixture(0)
	first.units[0].sp=30;first.step([cast(first,0)],[])
	check(SkillRules.attack_value(first.units[0],op)==1668 and SkillRules.defense_value(first.units[0],op)==132 and first.units[0].skill_ticks_left==899,"S1 +100percentATK30s, no unintended defense boost")
	var lock := fixture(1)
	add_enemies(lock);lock.units[0].sp=50
	lock.step([cast(lock,1)],[])
	check(lock.units[1].hp==99650 and lock.units[2].hp==99650 and lock.units[3].hp==99650 and lock.units[1].stun_ticks_left==30,"S2 immediate whole-range first140percent pulse and1sec stun")
	for tick in 209:lock.step([],[])
	check(lock.units[1].hp==97550 and lock.units[0].skill_ticks_left==0 and lock.units[0].sp==0,"S2 exactly7pulses/7sec, no naturalSP while active")
	var control := fixture(1)
	add_enemies(control);control.units[0].sp=50;control.step([cast(control,1)],[])
	control.units[0].stun_ticks_left=100
	for tick in 30:control.step([],[])
	check(control.units[1].hp==99650,"Source stun suppresses maintained next pulse")
	var wave := fixture(2)
	add_enemies(wave);wave.units[0].sp=110;wave.units[0].attack_ticks_left=0
	wave.step([cast(wave,2)],[])
	check(wave.units[1].hp==99324 and wave.units[2].hp==99324 and wave.units[3].hp==99324 and wave.units[1].cell==Vector2i(12,2),"S3 +170percent whole-range wave, force1 equals light weight1, no movement")
	check(AttackRange.effective_offsets(wave.units[0],op).size()==18 and not SkillRules.talent_is_active(op.talent_2),"Expanded source range, movement slow explicitly has no autonomous movement object")
	StatusRules.apply_silence(wave,wave.units[0],60)
	check(SkillRules.attack_value(wave.units[0],op)==834 and AttackRange.effective_offsets(wave.units[0],op).size()==9 and wave.units[0].sp_recharge_bonus_percent==0,"Silence suspends wave and own casterSP aura")
	for facing in 4:
		var ball := fixture(2)
		ball.units[0].facing=facing;ball.units[0].sp=110;ball.units[0].attack_ticks_left=0
		ball.ball.cell=ball.units[0].cell+AttackRange.rotate_offset(Vector2i(1,0),facing)
		ball.step([cast(ball,2)],[])
		check(ball.ball.accum==AttackRange.rotate_offset(Vector2i(2252,0),facing),"Four-way wave pushes ball once with raw2252")
	var a := fixture(1);var b := fixture(1)
	for state in [a,b]:add_enemies(state);state.units[0].sp=50
	for tick in 900:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(cast(a,1))
		a.step(commands,[]);b.step(commands,[])
		check(a.state_hash()==b.state_hash(),"Aura/pulses/status deterministic replay%d"%tick)
	check(op.attack==834,"Resources read-only")
	print("MOSTIMA_CORE_OK" if failures==0 else "MOSTIMA_FAILED count%d"%failures)
	quit(0 if failures==0 else 1)
func add_enemies(state: MatchState) -> void:
	for cell in [Vector2i(12,2),Vector2i(12,3),Vector2i(11,3)]:state.units.append(UnitState.new(state.units.size(),1,"enemy_fixture",cell,100000,0,100000))
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["mostima"]);var skills := PackedInt32Array([index])
	var state := MatchState.new(213,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=1000000
	state.step([InputCommand.new(0,0,"mostima",-1,Vector2i(13,2),-1,2)],[])
	if state.units.is_empty():push_error("Mostima high tile deploy failed");quit(1);return state
	state.units[0].attack_ticks_left=100000
	return state
func cast(state: MatchState,index: int) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
