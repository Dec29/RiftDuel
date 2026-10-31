extends SceneTree

var failures := 0
var data := {}
var op: OperatorData

func _initialize() -> void:
	op=load("res://resources/operators/stainless.tres");data.stainless=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.attack=1;dummy.defense=0;dummy.magic_resist=0;data.target=dummy
	check(op.validation_error().is_empty(),"Strict original White resource")
	var s := fixture(0);var actor := s.units[0]
	check(s.sides[0].stainless_stock==3,"Initial3 inventory without field owner reset")
	var platform := deploy(s,StainlessRules.IDS[0],Vector2i(12,5))
	check(platform!=null and s.sides[0].stainless_stock==2 and s.sides[0].cost==77,"Real3cost summon card deployment")
	check(SkillRules.attack_value(actor,op)==664,"Platform front one operator12percent attack")
	s.sides[0].cooldowns.erase(StainlessRules.IDS[0])
	var second := deploy(s,StainlessRules.IDS[0],Vector2i(12,6))
	check(second!=null and s.sides[0].stainless_stock==1,"Second same-kind platform allowed")
	s.sides[0].cooldowns.erase(StainlessRules.IDS[0]);check(not s.can_deploy(0,StainlessRules.IDS[0],Vector2i(12,7)),"Max2 field devices")
	actor.sp=45;cast(s)
	check(actor.skill_ticks_left==599 and s.sides[0].stainless_stock==2,"S1 gain1 on activation actual20sec")
	check(SkillRules.attack_value(actor,op)==1755,"S1 platform48percent times200percent attack scale")
	check(SkillRules.attack_value(actor,op,true)==878,"Ignore attack scale preserves base+aura")
	actor.skill_ticks_left=1;s.step([],[])
	check(not platform in s.units and not second in s.units,"S1 destroys all field platforms on skill completion")
	var supply := fixture(1);actor=supply.units[0];platform=deploy(supply,StainlessRules.IDS[1],Vector2i(12,5));platform.hp=2000;platform.stainless_loss_accum=0;platform.stainless_sp_ticks=0;actor.sp=0
	for tick in 30:StainlessRules.maintain(supply)
	check(platform.hp==1992,"Supply0.4percent maxHP per second")
	for tick in 75:StainlessRules.maintain(supply)
	check(actor.sp==1,"One SP at3.5sec")
	actor.sp=50;cast(supply);check(actor.skill_ticks_left==899 and SkillRules.attack_value(actor,op)==949 and SkillRules.defense_value(actor,op)==674,"S2 ATK60DEF60 actual30sec")
	platform.hp=2000;platform.stainless_loss_accum=0;platform.stainless_sp_ticks=0;actor.sp=0;actor.skill_ticks_left=0
	# Active skills retain their SP lock while the support platform keeps ticking.
	actor.skill_ticks_left=800
	for tick in 60:StainlessRules.maintain(supply)
	check(platform.hp==1968 and actor.sp==0,"S2 double loss0.8percent/sec and no SP during skill lock")
	actor.cell=Vector2i(17,5)
	var receiver := UnitState.new(supply.next_unit_id,0,"target",Vector2i(13,5),100000,0,100000)
	supply.units.append(receiver);supply.next_unit_id+=1;platform.stainless_sp_ticks=0
	for tick in 60:StainlessRules.maintain(supply)
	check(receiver.sp==1,"Active S2 platform grants1SP to eligible ally every2seconds")
	actor.skill_ticks_left=1;supply.sides[0].stainless_stock=0;supply.step([],[])
	check(supply.sides[0].stainless_stock==1 and platform in supply.units,"S2 grants1 on completion and retains devices")
	var blocked := fixture(1);blocked.units[0].skill_ticks_left=800;blocked.units[0].attack_ticks_left=0;var east := enemy(blocked,Vector2i(14,5));var west := enemy(blocked,Vector2i(12,5));blocked.step([],[])
	check(east.hp==100000-physical(949) and west.hp==100000-physical(949),"S2 attacks all actually blocked adjacent enemies including rear")
	var artillery := fixture(2);actor=artillery.units[0];var cannon := deploy(artillery,StainlessRules.IDS[2],Vector2i(14,5));var foe := enemy(artillery,Vector2i(15,5));var splash := enemy(artillery,Vector2i(15,6))
	cannon.hp=5000
	for hit in 4:artillery._apply_damage(cannon,artillery._operator_data[cannon.operator_id],100,"physical",actor)
	check(cannon.hp==5120 and cannon.sp==4,"Each actual artisan hit adds1SP and heals1percent through50percent coefficient")
	actor.attack_ticks_left=0;artillery.step([],[])
	check(cannon.sp==0 and cannon.hp==5000 and cannon.last_attack_tick==artillery.tick-1,"Fifth actual normal attack fires immediately, spends5SP/2.5percentHP")
	check(foe.hp==100000-physical(1779) and splash.hp==100000-physical(890),"Cannon300percent primary150percent splash using White current ATK/supporter coefficient")
	check(is_equal_approx(artillery._damage_taken_percent(actor,"physical"),80.0) and is_equal_approx(artillery._damage_taken_percent(actor,"magical"),100.0),"Cannon rear20percent physical protection only")
	artillery.sides[0].cooldowns.erase(StainlessRules.IDS[2]);var rear_cannon := deploy(artillery,StainlessRules.IDS[2],Vector2i(13,6));rear_cannon.facing=1
	check(is_equal_approx(artillery._damage_taken_percent(actor,"physical"),64.0),"Two cannons multiply20percent physical protection")
	artillery.units.erase(rear_cannon)
	var hp := cannon.hp;check(not artillery._apply_damage(cannon,artillery._operator_data[cannon.operator_id],10000,"physical",foe) and cannon.hp==hp and cannon.sp==0,"Opponent cannot charge or damage cannon")
	check(SkillRules.healing_received(cannon,artillery._operator_data[cannon.operator_id],500,actor)==0,"Cannon excludes ordinary heal")
	StatusRules.add_control(artillery,cannon,"cold",100,actor);StatusRules.add_control(artillery,cannon,"stun",100,actor);StatusRules.apply_silence(artillery,cannon,100)
	check(cannon.cold_ticks_left==0 and cannon.stun_ticks_left==0 and cannon.silence_ticks_left==0 and DisplacementRules.apply_unit(artillery,actor,cannon,Vector2i.RIGHT,6)==0,"Cannon cold/stun/silence/displacement immune")
	actor.sp=35;cast(artillery);check(actor.skill_ticks_left==899 and SkillRules.attack_value(actor,op)==919 and SkillRules.attack_interval_ticks(actor,op)==29,"S3 actual30sec ATK55AS55")
	var hash_before := artillery.state_hash();artillery.sides[0].stainless_stock+=1;check(hash_before!=artillery.state_hash(),"Inventory hashed");artillery.sides[0].stainless_stock-=1
	hash_before=artillery.state_hash();cannon.stainless_sp_ticks+=1;check(hash_before!=artillery.state_hash(),"Device timer hashed");cannon.stainless_sp_ticks-=1
	var field := fixture(2);actor=field.units[0];cannon=deploy(field,StainlessRules.IDS[2],Vector2i(14,5));field.rng=RNG.new(4);field.sides[0].stainless_stock=0
	var expected := 1 if RNG.new(4).next_u32()%100<70 else 0
	field._retreat_unit(cannon);check(field.sides[0].stainless_stock==expected,"Manual adjacent retirement triggers deterministic70percent salvage")
	field.sides[0].cooldowns.erase(StainlessRules.IDS[2]);field.sides[0].stainless_stock=2;cannon=deploy(field,StainlessRules.IDS[2],Vector2i(14,5));var before_rng := field.rng.state
	field._retreat_unit(actor);check(not cannon in field.units and field.rng.state==before_rng,"Owner retirement removes devices without salvage RNG")
	var death := fixture(2);cannon=deploy(death,StainlessRules.IDS[2],Vector2i(14,5));death.units[0].hp=0;death.step([],[]);check(not cannon in death.units,"Owner death removes devices same tick")
	var hold := fixture(2);var hold_cannon := deploy(hold,StainlessRules.IDS[2],Vector2i(14,5));hold_cannon.sp=5;StainlessRules.cannon_attack(hold,hold_cannon,hold._operator_data[hold_cannon.operator_id]);check(hold_cannon.sp==5 and hold_cannon.hp==6000,"No target holds cannon SP and life")
	attack_integration()
	for index in 3:
		var a := fixture(index);var b := fixture(index);deploy(a,StainlessRules.IDS[index],Vector2i(14,5));deploy(b,StainlessRules.IDS[index],Vector2i(14,5));enemy(a,Vector2i(15,5));enemy(b,Vector2i(15,5));a.units[0].sp=100;b.units[0].sp=100;a.units[0].attack_ticks_left=0;b.units[0].attack_ticks_left=0
		for tick in 1000:
			var commands: Array[InputCommand]=[]
			if tick==0:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"White replay S%d tick%d"%[index+1,tick])
	print("STAINLESS_OK actual3skills/3devices,stock/caps/recycle/ownership,realhit charge/immune/treatment,SP/life,coefficients,ordinary/dual/AoE/enemypriority,3x1000tick replay; failures=",failures)
	quit(0 if failures==0 else 1)

func fixture(index: int) -> MatchState:
	var state := MatchState.new(129,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["stainless"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"stainless",-1,Vector2i(13,5),-1,0)],[])
	check(state.units.size()==1 and state.sides[0].cost==80,"Actual19cost ground supporter deployment")
	state.units[0].attack_ticks_left=100000;return state

func deploy(state: MatchState, id: String, cell: Vector2i) -> UnitState:
	state.step([InputCommand.new(state.tick,0,id,-1,cell,-1,0)],[])
	for unit in state.units:
		if unit.operator_id==id and unit.cell==cell:return unit
	check(false,"Device did not deploy: "+id+" cell"+str(cell));return null

func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit

func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)],[])

func physical(power: int) -> int:
	return Combat.calculate_damage(power,0,0,"physical",0,RNG.new(1),"supporter")

func attack_integration() -> void:
	for id in ["bagpipe","chen","dusk","chen_alter","goldenglow","horn","fiammetta","mostima","meteorite","w"]:
		var state := fixture(2);var cannon := deploy(state,StainlessRules.IDS[2],Vector2i(14,5));var attacker_data := load("res://resources/operators/"+id+".tres") as OperatorData
		state._operator_data[id]=attacker_data
		var ally := UnitState.new(state.next_unit_id,0,id,Vector2i(13,4),attacker_data.max_health,0,0,1,0)
		if id=="dusk":ally.cell=Vector2i(12,5);ally.facing=0
		elif id in ["horn","fiammetta","w"]:ally.cell=Vector2i(11,5);ally.facing=0
		elif id in ["chen_alter","goldenglow","mostima","meteorite","w"]:ally.cell=Vector2i(13,5);ally.facing=0
		else:ally.cell=Vector2i(13,5);ally.facing=0
		state.units[0].cell=Vector2i(17,9);state.units.append(ally);state.next_unit_id+=1
		AttackRules.resolve(state)
		var count := 2 if id in ["chen","goldenglow"] else 1
		check(cannon.sp==count,id+" actual normal hit count expected"+str(count)+" got"+str(cannon.sp))
		cannon.sp=0;ally.attack_ticks_left=0;var foe := enemy(state,Vector2i(14,4));state.tick+=1;AttackRules.resolve(state)
		# Both units must be in range to verify targeting order.
		if state._is_in_attack_range(ally,foe.cell,AttackRange.effective_offsets(ally,attacker_data)):
			check(ally.last_attack_target_x==foe.cell.x and ally.last_attack_target_y==foe.cell.y,id+" enemy before friendly cannon")
			if id in ["dusk","horn","fiammetta","mostima","meteorite","w"]:check(cannon.sp==1,id+" actual AoE also charges nearby friendly cannon")

	var multi := fixture(2);var cannon := deploy(multi,StainlessRules.IDS[2],Vector2i(14,5));var chen := load("res://resources/operators/chen_alter.tres") as OperatorData
	multi._operator_data.chen_alter=chen;multi.units[0].cell=Vector2i(17,9)
	var shooter := UnitState.new(multi.next_unit_id,0,"chen_alter",Vector2i(13,5),chen.max_health,chen.skills[2].sp_required,0,0,2)
	multi.units.append(shooter);multi.next_unit_id+=1;ChenAlterRules.cast(multi,shooter,chen);shooter.attack_ticks_left=0;AttackRules.resolve(multi)
	check(cannon.sp==2,"Chen S3 two real shots charge cannon twice")
	var priority := fixture(2);cannon=deploy(priority,StainlessRules.IDS[2],Vector2i(14,5));var caster := load("res://resources/operators/goldenglow.tres") as OperatorData
	priority._operator_data.goldenglow=caster;priority.units[0].cell=Vector2i(17,9)
	var body := UnitState.new(priority.next_unit_id,0,"goldenglow",Vector2i(13,5),caster.max_health,0,0,0,0)
	priority.units.append(body);priority.next_unit_id+=1;var box := TacticalBox.new(0,Vector2i(14,4),3);priority.tactical_boxes.append(box);priority.ball.cell=Vector2i(14,6)
	AttackRules.resolve(priority);check(cannon.sp==2 and box.hits_left==3,"Friendly cannon priority before box/ball; body and attached float both actual hits")

func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
