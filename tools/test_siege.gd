extends SceneTree
var failures := 0
var data := {"siege":load("res://resources/operators/siege.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData = data.siege
	check(op.validation_error().is_empty() and op.attack == 515 and op.max_health == 2251 and op.block_count == 2,"E2 raw stats/contract")
	var enemy: OperatorData = data.bagpipe.duplicate(true)
	enemy.operator_id = "enemy_fixture";enemy.max_health = 100000;enemy.defense = 0
	data.enemy_fixture = enemy
	var cost := fixture(0)
	check(cost.units[0].attack_bonus_percent == 8 and cost.units[0].defense_bonus_percent == 8,"In-field vanguard aura includes self")
	cost.sides[0].cost = 0;cost.units[0].sp = 35
	cost.step([],[])
	check(cost.sides[0].cost == 12 and cost.units[0].sp == 0 and cost.units[0].skill_ticks_left == 0,"S1 instant cost, no pending attack or frozen SP")
	cost.step([],[])
	check(cost.sides[0].cost == 12 and cost.units[0].sp_regen_ticks == 1,"S1 does not repeat, naturalSP resumes")
	var hammer := fixture(1)
	for cell in [Vector2i(12,5),Vector2i(13,4),Vector2i(13,6)]:
		hammer.units.append(UnitState.new(hammer.units.size(),1,"enemy_fixture",cell,100000,0,100000))
	hammer.units[0].sp_regen_ticks = 17
	hammer.units[0].sp = 30;hammer.units[0].attack_ticks_left = 0
	var before_cost := hammer.sides[0].cost
	hammer.step([],[])
	check(hammer.units[0].sp_regen_ticks == 17 and hammer.units[0].sp == 20 and hammer.sides[0].cost == mini(99,before_cost+3) and hammer.units[0].skill_activation_count == 1,"S2 one charge/one cost grant for entire AoE")
	for index in [1,2,3]:check(hammer.units[index].hp == 99527,"S2 340percent after8percentATK, vanguard25percent damage")
	var no_target := fixture(1)
	no_target.units[0].sp = 30;no_target.units[0].attack_ticks_left = 0
	no_target.step([],[])
	check(no_target.units[0].sp == 30 and no_target.units[0].skill_activation_count == 0,"No target does not spend hammer charge")
	var skull := fixture(2)
	skull.units[0].sp = 30;skull.step([InputCommand.new(skull.tick,1,"",0,Vector2i.ZERO,2)],[])
	
	check(SkillRules.attack_output_value(skull.units[0],op) == 2114 and SkillRules.attack_interval_ticks(skull.units[0],op) == 61,"S3 multiplicative380percent and +1second interval")
	skull.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(12,5),0,0,100000))
	skull.step([],[])
	check(skull.units[0].sp == 1,"Nearby enemy death grants SP even while S3 active")
	skull.step([],[])
	check(skull.units[0].sp == 1,"Removed enemy is rewarded once")
	StatusRules.apply_silence(skull,skull.units[0],60)
	check(SkillRules.attack_output_value(skull.units[0],op) == 515 and SkillRules.defense_value(skull.units[0],op) == 384,"Silence removes aura and skill, without modifying resource")
	for facing in 4:
		var ball := fixture(1)
		ball.units[0].facing = facing;ball.units[0].attack_ticks_left = 0
		ball.ball.cell = ball.units[0].cell+AttackRange.rotate_offset(Vector2i(1,0),facing)
		ball.step([],[])
		check(ball.ball.accum == AttackRange.rotate_offset(Vector2i(1891,0),facing),"Four-way S2 ball rawATK, one push")
	var a := fixture(2);var b := fixture(2)
	for state in [a,b]:
		state.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(12,5),100000,0,100000))
		state.units[0].sp = 30;state.units[0].attack_ticks_left = 0
	for tick in 900:
		var commands: Array[InputCommand] = []
		if tick == 0:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,2))
		a.step(commands,[]);b.step(commands,[])
		check(a.state_hash() == b.state_hash(),"Per-tick seeded stun replay%d"%tick)
	check(op.attack == 515 and op.defense == 384,"Resources unchanged")
	print("SIEGE_CORE_OK" if failures == 0 else "SIEGE_FAILED count%d"%failures)
	quit(0 if failures == 0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["siege"]);var skills := PackedInt32Array([index])
	var state := MatchState.new(112,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost = 99;state.ball.cell = Vector2i(10,10)
	state._ball_data = MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold = 100000
	state.step([InputCommand.new(0,0,"siege",-1,Vector2i(13,5),-1,2)],[])
	if state.units.is_empty():push_error("Ground deploy fixture must be legal");quit(1);return state
	state.units[0].attack_ticks_left = 100000
	return state
func check(value: bool,label: String) -> void:
	if not value:failures += 1;push_error(label)
