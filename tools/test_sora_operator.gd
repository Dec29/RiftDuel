extends SceneTree
var failures := 0
var data := {}
func _initialize() -> void:
	data.sora=load("res://resources/operators/sora.tres")
	data.skadi_alter=load("res://resources/operators/skadi_alter.tres")
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="patient";dummy.max_health=10000;dummy.attack=500;data.patient=dummy
	var op: OperatorData=data.sora
	check(op.validation_error().is_empty() and op.attack==335 and op.max_health==1356 and op.skills.size()==2,"Original E2/actual two skills "+op.validation_error())
	var normal := fixture(1);add(normal,0,Vector2i(16,4),5000)
	for t in 120:normal.step([],[])
	check(normal.units[1].hp==5067 and normal.units[0].last_attack_tick==-1 and normal.ball.accum==Vector2i.ZERO,"Trait10% ATK/s folded50%, integer remainder, no attack")
	for facing in 4:
		var s := fixture(0,3);var u := s.units[0];u.facing=facing;u.sp=60
		add(s,1,u.cell+AttackRange.rotate_offset(Vector2i(2,1),facing),10000);add(s,1,u.cell+AttackRange.rotate_offset(Vector2i(2,2),facing),10000);add(s,0,u.cell+AttackRange.rotate_offset(Vector2i(1,1),facing),5000)
		s.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,0)],[])
		check(s.units[1].sleep_ticks_left==210 and s.units[2].sleep_ticks_left==0 and u.skill_ticks_left==209,"S1 exact x-2 rotated range facing%d"%facing)
		check(not s.enemy_is_targetable(0,s.units[1]) and SkillRules.block_count_value(s.units[1],data.patient)==0 and not s.enemy_is_blocked(s.units[1]),"Sleep invulnerable/untargetable/unblockable")
		for kind in ["physical","magical","true"]:check(not s._apply_damage(s.units[1],data.patient,999999,kind) and s.units[1].hp==10000,"No sleep damage "+kind)
		s.units[1].sp=data.patient.skills[0].sp_required
		check(not SkillRules.can_activate(s.units[1],data.patient.skills[0]),"Sleep forbids new skill")
		var cool := s.units[1].attack_ticks_left
		for t in 209:s.step([],[])
		check(s.units[3].hp==6172 and u.skill_ticks_left==0 and u.sp==30 and s.units[1].attack_ticks_left==cool,"7sec boosted regen, attacks paused, encore50%=30")
		check(AttackRange.effective_offsets(u,op)==op.attack_range,"Range restored")
		s.step([],[]);check(s.units[1].sleep_ticks_left==0,"Sleep ends at shared skill boundary")
	var song := fixture(1,3);song.units[0].sp=45;add(song,0,Vector2i(16,4),5000)
	song.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[])
	check(song.units[1].inspire_attack_add==335 and song.units[0].inspire_attack_add==0 and SkillRules.attack_value(song.units[1],data.patient)==835,"S2 final-add335, bard self excluded")
	var mixed := fixture(1);mixed.units[0].skill_ticks_left=900;add(mixed,0,Vector2i(15,4),5000)
	var other := (data.skadi_alter as OperatorData).duplicate(true);other.attack=2000;mixed._operator_data.skadi_alter=other
	var skadi := UnitState.new(2,0,"skadi_alter",Vector2i(14,5),1603,0,100000,0,1);skadi.skill_ticks_left=900;mixed.units.append(skadi);mixed.next_unit_id=3;AuraRules.refresh(mixed)
	check(mixed.units[1].inspire_attack_add==335,"Sora100% beats higher numeric Skadi60% by original ratio selection")
	skadi.skill_index=2;AuraRules.refresh(mixed)
	check(mixed.units[1].inspire_attack_add==roundi(SkillRules.attack_value(skadi,other)*1.1),"Skadi110% beats Sora100% and does not stack")
	var endpoint := fixture(1,3);endpoint.units[0].skill_ticks_left=1;var expected := RNG.new(3);check(expected.next_percent()<50,"Fixed encore success seed");endpoint.step([],[])
	check(endpoint.units[0].sp==23 and endpoint.rng.state==expected.state,"45SP50%=22.5 uses documented integer23, one RNG")
	var muted := fixture(1,3);muted.units[0].skill_ticks_left=1;muted.units[0].silence_ticks_left=90;var before := muted.rng.state;muted.step([],[]);check(muted.rng.state==before and muted.units[0].sp==0,"Silence suppresses encore without RNG")
	var cleanse := fixture(1);add(cleanse,0,Vector2i(15,4),5000);StatusRules.add_control(cleanse,cleanse.units[1],"sleep",30);check(LumenRules.has_control(cleanse.units[1]),"Sleep is cleansable control");LumenRules.clear_controls(cleanse,cleanse.units[1]);check(cleanse.units[1].sleep_ticks_left==0,"Existing cleanse handles new status")
	var a := fixture(0,3);var b := fixture(0,3);a.units[0].sp=60;b.units[0].sp=60;add(a,1,Vector2i(16,4),10000);add(b,1,Vector2i(16,4),10000)
	for t in 900:
		var cmds: Array[InputCommand]=[]
		if t==0:cmds.append(InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,0))
		a.step(cmds,[]);b.step(cmds,[]);check(a.state_hash()==b.state_hash(),"900tick sleep/encore replay%d"%t)
	before=a.state_hash();a.units[1].sleep_ticks_left+=1;check(a.state_hash()!=before,"Sleep hashed")
	print("Sora traits, two songs, sleep, ratio selection, encore, cleansing and deterministic replay; failures=%d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int,seed: int=1) -> MatchState:
	var s := MatchState.new(seed,data);s.ball.cell=Vector2i(5,5);s.units=[UnitState.new(0,0,"sora",Vector2i(14,4),1356,0,0,0,index)];s.next_unit_id=1;return s
func add(s: MatchState,side: int,cell: Vector2i,hp: int) -> void:
	s.units.append(UnitState.new(s.next_unit_id,side,"patient",cell,hp,0,100000,0));s.next_unit_id+=1
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
