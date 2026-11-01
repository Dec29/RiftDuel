extends SceneTree
var failures := 0
var data := {}
func _initialize() -> void:
	data.cliffheart=load("res://resources/operators/cliffheart.tres")
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="patient";dummy.max_health=10000;dummy.defense=0;dummy.magic_resist=0;data.patient=dummy
	var op: OperatorData=data.cliffheart
	check(op.validation_error().is_empty() and op.attack==765 and op.max_health==1970 and op.skills.size()==2,"Original E2/actual two skills "+op.validation_error())
	var aura := fixture(0);enemy(aura,Vector2i(16,5));aura.units.append(UnitState.new(2,0,"patient",Vector2i(15,5),10000,0,10000,0));aura.next_unit_id=3;AuraRules.refresh(aura)
	check(aura.units[0].attack_bonus_percent==12 and SkillRules.defense_value(aura.units[0],op)==381,"Other ally blocking is not own blocking")
	aura.units[1].cell=Vector2i(13,5);AuraRules.refresh(aura);check(aura.units[0].attack_bonus_percent==0,"Own ground blocking removes12%")
	aura.platform_cells=[Vector2i(14,5)];AuraRules.refresh(aura);check(aura.units[0].attack_bonus_percent==12 and not aura.enemy_is_blocked(aura.units[1],0),"Actual high tile cannot count puller as ground blocker")
	var back := fixture(0);enemy(back,Vector2i(13,5));back.units[0].attack_ticks_left=1;back.step([],[])
	check(back.units[1].hp==9809,"Normal attack prioritizes own blocked target outside facing range")
	var far := fixture(0);enemy(far,Vector2i(16,5));enemy(far,Vector2i(17,5));far.units[0].sp=4;far.units[0].attack_ticks_left=1;var rng_before := far.rng.state;far.step([],[])
	check(far.units[1].hp==10000 and far.units[2].hp==9614 and far.units[0].sp==0 and far.units[0].skill_ticks_left==149,"S1 selects farthest,180% magical386, one SP4 use and150tick channel")
	check(far.rng.state==rng_before,"No unneeded random rolls")
	far.units[0].attack_ticks_left=1;far.step([],[]);check(far.units[1].hp==9809 and far.enemy_is_blocked(far.units[1],0) and far.units[0].sp==0,"Ordinary attack continues during SP-only channel; pulled adjacent target removes unblocked ATK bonus")
	var pull := fixture(1);enemy(pull,Vector2i(17,5));pull.units[0].sp=15;pull.units[0].attack_ticks_left=999
	pull.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[])
	check(pull.units[1].hp==9571 and pull.units[1].cell==Vector2i(15,5) and pull.units[1].displacement_ticks_left==8 and pull.units[1].stun_ticks_left==0,"S2 true429, force3-weight1=2 pull, no premature stun")
	check(AttackRange.effective_offsets(pull.units[0],op)==op.attack_range,"Independent S2 cast range never expands ordinary range during channel")
	for i in 8:pull.step([],[])
	check(pull.units[1].stun_ticks_left==90 and pull.units[1].hook_owner_id==-1,"Stun90 only after8tick displacement finishes")
	for facing in 4:
		var s := fixture(1);s.units[0].facing=facing;s.units[0].sp=15;s.units[0].attack_ticks_left=999
		for offset in [Vector2i(3,1),Vector2i(3,-1),Vector2i(3,0),Vector2i(2,0)]:enemy(s,s.units[0].cell+AttackRange.rotate_offset(offset,facing))
		s.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[])
		check(s.units[1].hp==9571 and s.units[2].hp==9571 and s.units[3].hp==9571 and s.units[4].hp==10000,"S2 three farthest exactly once, rotated range facing%d"%facing)
	var heavy := fixture(1);enemy(heavy,Vector2i(15,5));heavy._operator_data.patient=dummy.duplicate(true);heavy._operator_data.patient.profession_id="defender";heavy.units[0].sp=15;heavy.units[0].attack_ticks_left=999;heavy.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[])
	check(heavy.units[1].displacement_ticks_left==0 and heavy.units[1].hook_due_tick==150 and heavy.units[1].stun_ticks_left==0,"No force movement on equal weight; pending until150tick timeout")
	heavy.step([InputCommand.new(1,InputCommand.Kind.RETREAT,"",0)],[])
	check(heavy.units.size()==1 and heavy.units[0].stun_ticks_left==90 and heavy.units[0].hook_owner_id==-1,"Source retreat ends pending chain and applies stun")
	var killed := fixture(1);enemy(killed,Vector2i(15,5));killed._operator_data.patient=dummy.duplicate(true);killed._operator_data.patient.profession_id="defender";killed.units[0].sp=15;killed.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[])
	killed._apply_damage(killed.units[0],op,999999,"true")
	check(killed.units[1].stun_ticks_left==90 and killed.units[1].hook_owner_id==-1,"Lethal damage ends owned chain immediately, no duplicate delayed event")
	var bound := fixture(1);enemy(bound,Vector2i(17,5));bound.units[0].sp=15;bound.units[0].bind_ticks_left=30;bound.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[])
	check(bound.units[1].hp==9571 and bound.units[0].sp==0,"Bind permits independent S2, not ordinary attack")
	var empty := fixture(1);empty.units[0].sp=15;empty.ball.cell=Vector2i(17,5);empty.units[0].attack_ticks_left=999;empty.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[])
	check(empty.units[0].sp==0 and empty.units[0].skill_ticks_left==0 and empty.ball.accum==Vector2i(-1714,0),"Approved S2 fallback pulls stationary ball toward source at raw200% force")
	var box := fixture(0);box.units[0].sp=4;box.units[0].attack_ticks_left=1;box.tactical_boxes=[TacticalBox.new(0,Vector2i(16,5),3)];box.step([],[])
	check(box.tactical_boxes[0].hits_left==2 and box.units[0].sp==0 and box.units[0].skill_ticks_left==0,"Approved S1 box fallback spends charge and strikes once")
	var life := fixture(0);enemy(life,Vector2i(17,5));life.units[0].sp=4;life.units[0].attack_ticks_left=1
	for t in 150:life.step([],[])
	check(life.units[0].sp==0 and life.units[0].skill_ticks_left==0,"Full150tick role-target SP lock")
	var a := fixture(1);var b := fixture(1);enemy(a,Vector2i(17,5));enemy(b,Vector2i(17,5));a.units[0].sp=15;b.units[0].sp=15
	for t in 900:
		var cmds: Array[InputCommand]=[]
		if t==0:cmds.append(InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1))
		a.step(cmds,[]);b.step(cmds,[]);check(a.state_hash()==b.state_hash(),"900tick chain/stun/recharge replay%d"%t)
	var before := a.state_hash();a.units[1].hook_due_tick+=1;check(a.state_hash()!=before,"Pending due tick hashed");before=a.state_hash();a.units[1].hook_owner_id+=1;check(a.state_hash()!=before,"Pending owner hashed");before=a.state_hash();a.units[1].hook_stun_ticks+=1;check(a.state_hash()!=before,"Pending duration hashed")
	print("Cliffheart far-target two hooks, delayed stun, PvP shift/weight, own blocking, channel SP, lifecycle and replay; failures=%d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var arena := ArenaData.new()
	for row in 11:arena.terrain_rows.append("g".repeat(10)+"n"+"g".repeat(10))
	var s := MatchState.new(173,data,MatchState.DEFAULT_BALL_DATA,arena);s.ball.cell=Vector2i(5,5);s.units=[UnitState.new(0,0,"cliffheart",Vector2i(14,5),1970,0,0,0,index)];s.next_unit_id=1;AuraRules.refresh(s);return s
func enemy(s: MatchState,cell: Vector2i) -> void:
	s.units.append(UnitState.new(s.next_unit_id,1,"patient",cell,10000,0,100000,0));s.next_unit_id+=1
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
