extends SceneTree
var failures := 0
var data := {}
func _initialize() -> void:
	data.gitano=load("res://resources/operators/gitano.tres")
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=10000;dummy.magic_resist=0;data.target=dummy
	var op: OperatorData=data.gitano
	check(op.validation_error().is_empty() and op.attack==715 and op.max_health==1598 and op.skills.size()==2,"E2/M3 original two skills "+op.validation_error())
	var choices := {}
	for seed in [1,109,219,1234,77777]:
		var s := MatchState.new(seed,data);s.squad_ids=[["gitano"],[]];s.ball.cell=Vector2i(5,5);s.sides[0].cost=99;s.platform_cells=[Vector2i(14,4)]
		var rng := RNG.new(seed);var expected := rng.next_u32()%3
		s.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"gitano",-1,Vector2i(14,4),0)],[])
		check(s.units.size()==1,"Legal high-ground deployment")
		if s.units.size()!=1:continue
		var u := s.units[0];choices[u.fortune_choice]=true
		check(u.fortune_choice==expected and s.rng.state==rng.state,"One simulation RNG draw per deployment")
		check(SkillRules.attack_value(u,op)==(808 if expected==0 else 715) and SkillRules.max_health_value(u,op)==(1918 if expected==2 else 1598),"Permanent selected stats only")
		var before := s.rng.state;AuraRules.refresh(s);AuraRules.refresh(s);check(s.rng.state==before,"Aura refresh never rerolls fortune")
	check(choices.size()==3,"All fortune outcomes reached")
	for facing in 4:
		var s := fixture(1);var u := s.units[0];u.facing=facing;u.sp=85;u.attack_ticks_left=1
		for offset in [Vector2i(1,0),Vector2i(2,0),Vector2i(3,1),Vector2i(4,0)]:enemy(s,u.cell+AttackRange.rotate_offset(offset,facing))
		s.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[])
		check(s.units[1].hp==9571 and s.units[2].hp==9571 and s.units[3].hp==9571 and s.units[4].hp==10000,"S2 200%% all in range each once/no outside splash facing%d"%facing)
		check(u.skill_ticks_left==899 and u.sp==0,"S2 cost85 and duration900 ticks")
	var s1 := fixture(0);s1.units[0].sp=35;s1.units[0].attack_ticks_left=87
	s1.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,0)],[])
	check(SkillRules.attack_interval_ticks(s1.units[0],op)==50 and s1.units[0].attack_ticks_left==49,"S1 speed75 and remaining cooldown scaled, no inserted attack")
	var stop := fixture(1);var u := stop.units[0];u.skill_ticks_left=1;u.attack_ticks_left=1000;enemy(stop,Vector2i(16,4));stop.step([],[])
	check(u.destiny_attack_stop_ticks==300 and u.stun_ticks_left==0 and AttackRange.effective_offsets(u,op)==op.attack_range,"End restores range and only stops attacks")
	u.attack_ticks_left=1
	for i in 299:stop.step([],[])
	check(stop.units[1].hp==10000 and u.destiny_attack_stop_ticks==1,"Full attack-stop duration")
	stop.step([],[]);check(stop.units[1].hp<10000 and u.destiny_attack_stop_ticks==0 and u.sp==10,"Stop expiry, SP continues while stopped")
	var bound := fixture(1);bound.units[0].sp=85;bound.units[0].bind_ticks_left=30;enemy(bound,Vector2i(16,4));bound.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[])
	check(bound.units[0].skill_ticks_left==899 and bound.units[1].hp==10000,"Bind permits active cast but forbids enhanced ordinary attack")
	var fresh := UnitState.new(0,0,"gitano",Vector2i(14,4),1598,0,0,0,0)
	check(fresh.fortune_choice==-1 and fresh.destiny_attack_stop_ticks==0,"New deployment state has no previous stop or fortune")
	var life := fixture(1);life.squad_ids=[["gitano"],[]];life.platform_cells=[Vector2i(14,4)];life.units[0].fortune_choice=2;life.units[0].destiny_attack_stop_ticks=90
	life.step([InputCommand.new(0,InputCommand.Kind.RETREAT,"",0)],[])
	check(life.units.is_empty() and life.sides[0].cooldowns.has("gitano"),"Retreat removes active/fortune/stop state")
	life.sides[0].cooldowns["gitano"]=1;life.sides[0].cost=99
	var redeploy_rng := RNG.new(life.rng.state);var redeploy_choice := redeploy_rng.next_u32()%3
	life.step([InputCommand.new(1,InputCommand.Kind.DEPLOY,"gitano",-1,Vector2i(14,4),0)],[])
	check(life.units.size()==1 and life.units[0].unit_id==1 and life.units[0].destiny_attack_stop_ticks==0 and life.units[0].fortune_choice==redeploy_choice and life.rng.state==redeploy_rng.state,"Redeploy new ID, fresh stop, exactly one new RNG draw")
	var a := fixture(1);var b := fixture(1);a.units[0].fortune_choice=1;b.units[0].fortune_choice=1;enemy(a,Vector2i(16,4));enemy(b,Vector2i(16,4))
	for t in 1200:a.step([],[]);b.step([],[]);check(a.state_hash()==b.state_hash(),"Same seed/input per-tick replay%d"%t)
	var hash_before := a.state_hash();a.units[0].destiny_attack_stop_ticks+=1;check(a.state_hash()!=hash_before,"Attack-stop hashed");hash_before=a.state_hash();a.units[0].fortune_choice=2;check(a.state_hash()!=hash_before,"Fortune hashed")
	print("Gitano original skills, deployment RNG, full-range packets, lifecycle, bind and 1200-tick replay; failures=%d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var s := MatchState.new(109,data);s.ball.cell=Vector2i(5,5);s.units=[UnitState.new(0,0,"gitano",Vector2i(14,4),1598,0,0,0,index)];s.next_unit_id=1;return s
func enemy(s: MatchState,cell: Vector2i) -> void:
	s.units.append(UnitState.new(s.next_unit_id,1,"target",cell,10000,0,100000,0));s.next_unit_id+=1
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
