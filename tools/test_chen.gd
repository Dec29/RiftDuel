extends SceneTree
var failures := 0
var data := {"chen":load("res://resources/operators/chen.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.chen
	check(op.validation_error().is_empty() and op.attack==610 and op.max_health==2880 and op.skills.size()==3,"Raw E2 stats and M3 data")
	var enemy: OperatorData=data.bagpipe.duplicate(true);enemy.operator_id="enemy_fixture";enemy.max_health=100000;enemy.defense=0;enemy.magic_resist=0;enemy.talent_1.effect_type="none";enemy.talent_2.effect_type="none"
	data.enemy_fixture=enemy
	var normal := fixture(0);add_enemy(normal);normal.units[0].attack_ticks_left=0
	normal.step([],[])
	check(normal.units[1].hp==99488 and normal.units[0].sp==1,"Dual physical256 hits but one attackSP")
	var sheath := fixture(0);add_enemy(sheath);sheath.units[0].attack_ticks_left=0;sheath.units[0].sp=4;sheath.step([],[])
	check(sheath.units[1].hp==99180 and sheath.units[1].stun_ticks_left==45 and sheath.units[0].sp==0,"S1 single820 hit and45tick stun")
	var draw := fixture(1);add_enemy(draw);draw.units[0].sp=20;draw.step([cast(draw,1)],[])
	check(draw.units[1].hp==97438 and draw.units[0].sp==0 and draw.units[0].skill_ticks_left==0,"S2 two1281 physical/magic strikes")
	var slash := fixture(2);add_enemy(slash);slash.units[0].sp=30;slash.step([cast(slash,2)],[])
	check(slash.units[1].hp==99180 and slash.units[0].chen_slashes_left==9 and not slash.enemy_is_targetable(1,slash.units[0]) and SkillRules.block_count_value(slash.units[0],op)==0,"S3 first slash and invulnerability target/block state")
	var before := slash.units[0].hp
	check(not slash._apply_damage(slash.units[0],op,99999,"true",slash.units[1]) and slash.units[0].hp==before,"S3 blocks direct and periodic damage")
	for tick in 53:slash.step([],[])
	check(slash.units[1].hp==92620 and slash.units[0].chen_slashes_left==1,"Nine slashes by53 ticks")
	slash.step([],[])
	check(slash.units[1].hp==91800 and slash.units[1].stun_ticks_left==120 and slash.units[0].chen_slashes_left==0 and slash.units[0].cell==Vector2i(13,5),"Tenth slash at54 restores normal state without teleport")
	var aura := fixture(0)
	for tick in 119:aura.step([],[])
	check(aura.units[0].sp==1,"Four-second attackSP aura includes source")
	for facing in 4:
		var ball := fixture(0);ball.units[0].attack_ticks_left=0;ball.units[0].facing=facing;ball.ball.cell=ball.units[0].cell+AttackRange.rotate_offset(Vector2i.RIGHT,facing);ball.step([],[])
		check(ball.ball.accum==AttackRange.rotate_offset(Vector2i(1282,0),facing),"Dual raw641 ball push in all directions")
	var early := fixture(2);add_enemy(early);early.units[0].sp=30;early.step([cast(early,2)],[])
	early.units[1].cell=Vector2i(0,0)
	for tick in 6:early.step([],[])
	check(early.units[0].chen_slashes_left==0 and early.units[0].chen_slash_tick==1,"No target endsS3 and retains last actual slash event")
	early.units[1].cell=Vector2i(12,5);early.units[0].attack_ticks_left=0;early.step([],[])
	check(early.units[0].last_attack_tick!=early.units[0].chen_slash_tick,"Post-cancel ordinary attack is not a slash event")
	var a := fixture(2);var b := fixture(2)
	for state in [a,b]:add_enemy(state);state.units[0].sp=30
	for tick in 150:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(cast(a,2))
		a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Seeded per-tick replay")
	print("CHEN_CORE_OK" if failures==0 else "CHEN_FAILED %d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["chen"]);var skills := PackedInt32Array([index]);var state := MatchState.new(10,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=1000000
	state.step([InputCommand.new(0,0,"chen",-1,Vector2i(13,5),-1,2)],[]);state.units[0].attack_ticks_left=100000;return state
func add_enemy(state: MatchState) -> void:state.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(12,5),100000,0,100000))
func cast(state: MatchState,index: int) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
