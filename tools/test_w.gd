extends SceneTree
var failures := 0
var data := {"w":load("res://resources/operators/w.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.w
	check(op.validation_error().is_empty() and op.attack==912 and op.max_health==1605 and op.skills.size()==3,"W raw E2/M3 resource")
	var enemy: OperatorData=data.bagpipe.duplicate(true)
	enemy.operator_id="enemy_fixture";enemy.max_health=100000;enemy.defense=0;enemy.magic_resist=0;enemy.talent_1.effect_type="none";enemy.talent_2.effect_type="none"
	data.enemy_fixture=enemy
	var basic := fixture(0);add_enemy(basic,Vector2i(11,2));add_enemy(basic,Vector2i(11,3));add_enemy(basic,Vector2i(10,3));basic.units[0].attack_ticks_left=0
	basic.step([],[])
	check(basic.units[1].hp==99772 and basic.units[2].hp==99772 and basic.units[3].hp==100000,"Normal228 physical splash, diagonal excluded")
	var grenade := fixture(0);add_enemy(grenade,Vector2i(11,2));add_enemy(grenade,Vector2i(11,3));grenade.units[0].sp=16;grenade.step([cast(0)],[])
	check(grenade.units[1].hp==99202 and grenade.units[2].hp==99202 and grenade.units[1].stun_ticks_left==90 and grenade.units[0].sp==0,"S1 two798 hits and3s stun")
	check(is_equal_approx(grenade._damage_taken_percent(grenade.units[1],"physical"),118.0) and grenade._damage_taken_percent(grenade.units[1],"magical")==100.0 and grenade._damage_taken_percent(grenade.units[1],"true")==100.0,"Stunned physical-only18percent aura")
	StatusRules.apply_silence(grenade,grenade.units[0],30)
	check(grenade._damage_taken_percent(grenade.units[1],"physical")==100.0,"Silence suppresses source aura")
	var charging := fixture(1)
	for tick in 239:charging.step([],[])
	check(charging.units[0].sp==8,"W natural SP reaches8 after240ticks")
	var no_target := fixture(0);no_target.units[0].sp=16;no_target.step([cast(0)],[])
	check(no_target.units[0].sp==16 and no_target.units[0].skill_activation_count==0,"No target preserves manual SP")
	var mine := fixture(1);add_enemy(mine,Vector2i(11,2));mine.units[0].sp=8;mine.units[0].attack_ticks_left=0;mine.step([],[])
	check(mine.w_bombs.size()==1 and mine.w_bombs[0].cell==Vector2i(11,2) and mine.w_bombs[0].expire_tick-mine.w_bombs[0].placed_tick==3600,"S2 prioritizes eligible enemy ground and120s lifetime")
	mine.units[0].attack_ticks_left=100000;mine.step([],[])
	check(mine.w_bombs[0].explode_tick==mine.tick-1+45 and mine.w_bombs[0].attack==2554,"Mine trigger snapshots280percent then waits45ticks")
	for tick in 44:mine.step([],[])
	check(mine.units[1].hp==100000,"Mine no early damage")
	mine.step([],[])
	check(mine.w_explosion_events.size()==1 and mine.w_bombs.is_empty() and mine.units[1].hp==99361 and mine.units[1].stun_ticks_left==66,"Mine639 hit and2.2s stun at delay boundary")
	var expiry := fixture(1);expiry.units[0].sp=8;expiry.units[0].attack_ticks_left=0;expiry.step([],[])
	var expiring: WExplosive=expiry.w_bombs[0];expiry.units[0].attack_ticks_left=100000;expiry.units[0].sp=0;expiry.tick=expiring.expire_tick;expiry.step([],[])
	check(expiry.w_bombs.is_empty() and expiry.w_explosion_events.is_empty(),"Untriggered mine expires without blast")
	var exit_mine := fixture(1);exit_mine.units[0].sp=8;exit_mine.units[0].attack_ticks_left=0;exit_mine.step([],[]);exit_mine._retreat_unit(exit_mine.units[0])
	check(exit_mine.w_bombs.is_empty() and exit_mine.w_explosion_events.is_empty(),"W retreat immediately clears mines")
	var marks := fixture(2)
	for index in 5:
		add_enemy(marks,Vector2i(11-index%3,2+index/3));marks.units[-1].hp=10000+index*1000
	marks.units[0].sp=33;marks.step([cast(2)],[])
	var chosen := PackedInt32Array()
	for bomb in marks.w_bombs:chosen.append(bomb.target_id)
	check(chosen==PackedInt32Array([5,4,3,2]) and marks.w_bombs[0].attack==2827,"D12 highest currentHP4 and cast attack snapshot")
	var delayed := fixture(2);add_enemy(delayed,Vector2i(11,2));delayed.units[0].sp=33;delayed.step([cast(2)],[])
	for tick in 89:delayed.step([],[])
	check(delayed.units[1].hp==100000 and delayed.w_bombs.size()==1,"D12 waits exactly3seconds")
	delayed.step([],[])
	check(delayed.units[1].hp==99293 and delayed.units[1].stun_ticks_left==150 and delayed.w_bombs.is_empty(),"D12 single707 hit and5second stun")
	var exit_mark := fixture(2);add_enemy(exit_mark,Vector2i(11,2));add_enemy(exit_mark,Vector2i(11,3));exit_mark.units[2].cell=Vector2i(0,0);exit_mark.units[0].sp=33;exit_mark.step([cast(2)],[])
	exit_mark.units[2].cell=Vector2i(11,3);exit_mark._retreat_unit(exit_mark.units[1])
	check(exit_mark.w_bombs.is_empty() and exit_mark.units[1].hp==99293,"Marked target retreat immediately explodes last position against neighbor")
	var retained := fixture(2);add_enemy(retained,Vector2i(11,2));retained.units[0].sp=33;retained.step([cast(2)],[]);retained._retreat_unit(retained.units[0])
	check(retained.w_bombs.size()==1,"W withdrawal retains D12")
	for tick in 90:retained.step([],[])
	check(retained.units[0].hp==99293 and retained.w_bombs.is_empty(),"Retained bomb deals snapshotted damage after W leaves")
	var ball := fixture(2);ball.ball.cell=Vector2i(11,2);ball.units[0].sp=33;ball.step([cast(2)],[])
	for tick in 90:ball.step([],[])
	check(ball.ball.accum==Vector2i(-2827,0),"D12 ball push uses raw attack, no sniper coefficient")
	var ambush := fixture(0);ambush.tick=300;AuraRules.refresh(ambush)
	check(ambush.units[0].ambush_ready and SkillRules.taunt_level(ambush.units[0],op)==-1 and SkillRules.dodge_chance(ambush.units[0],op,"physical")==60 and SkillRules.dodge_chance(ambush.units[0],op,"magical")==60,"10s ambush both dodges and negative taunt")
	StatusRules.apply_silence(ambush,ambush.units[0],1)
	check(not ambush.units[0].ambush_ready and SkillRules.dodge_chance(ambush.units[0],op,"physical")==0,"Ambush suppressed while silenced")
	data.eyjafjalla=load("res://resources/operators/eyjafjalla.tres")
	var taunt := fixture(0);taunt.tick=300;AuraRules.refresh(taunt)
	var caster := UnitState.new(1,1,"eyjafjalla",Vector2i(11,2),1700,0,0,0);caster.skill_index=2;taunt.units.append(caster)
	SkillRules.activate(caster,data.eyjafjalla);AttackRules.resolve(taunt)
	check(caster.last_attack_tick==300 and caster.last_attack_target_x==12,"Random multi-target can still select sole negative-taunt W")
	var a := fixture(1);var b := fixture(1)
	for state in [a,b]:add_enemy(state,Vector2i(11,2));state.units[0].attack_ticks_left=0;state.units[0].sp=8
	for tick in 180:
		a.step([],[]);b.step([],[]);check(a.state_hash()==b.state_hash(),"W seeded RNG/bomb per-tick replay")
	print("W_CORE_OK" if failures==0 else "W_FAILED %d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["w"]);var skills := PackedInt32Array([index]);var state := MatchState.new(10,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=1000000
	state.step([InputCommand.new(0,0,"w",-1,Vector2i(12,2),-1,2)],[]);state.units[0].attack_ticks_left=100000;return state
func add_enemy(state: MatchState, cell: Vector2i) -> void:state.units.append(UnitState.new(state.units.size(),1,"enemy_fixture",cell,100000,0,100000))
func cast(index: int) -> InputCommand:return InputCommand.new(1,InputCommand.Kind.SKILL,"",0,Vector2i(-1,-1),index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
