extends SceneTree

var failures := 0
var data := {}
var op: OperatorData


func _initialize() -> void:
	op=load("res://resources/operators/pallas.tres");data.pallas=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	check(op.validation_error().is_empty() and op.max_health==1963 and op.attack==687 and op.defense==455 and op.skills.size()==3,"Original E2/no trust/no potential/no module, three M3 skills")
	var plain := fixture(0);var actor: UnitState=plain.units[0]
	check(SkillRules.attack_value(actor,op)==859,"In-field Minos vigor25% includes self at fullHP")
	actor.hp=1570
	plain.step([],[]);check(SkillRules.attack_value(actor,op)==859,"Threshold sampling retains previous vigor before0.1second")
	while plain.tick<4:plain.step([],[])
	check(SkillRules.attack_value(actor,op)==687,"80% threshold is strict,1570/1963 is below")
	actor.hp=1571
	while plain.tick<7:plain.step([],[])
	check(SkillRules.attack_value(actor,op)==859,"1571/1963 exceeds80%")
	StatusRules.apply_silence(plain,actor,60)
	check(SkillRules.attack_value(actor,op)==687,"Source silence removes vigor")
	var group := dummy.duplicate(true) as OperatorData;group.operator_id="minos_ally";group.group_id="minos";data.minos_ally=group
	var aura := fixture(0);var ally := friend(aura,"minos_ally",Vector2i(18,5));var ordinary := friend(aura,"target",Vector2i(17,5));var foe := enemy(aura,Vector2i(2,5));foe.operator_id="minos_ally";aura.step([],[])
	check(SkillRules.attack_value(ally,group)==roundi(group.attack*1.25) and SkillRules.attack_value(ordinary,dummy)==dummy.attack and SkillRules.attack_value(foe,group)==group.attack,"Vigor filters Minos, own side, anywhere on board")
	aura._retreat_unit(aura.units[0]);aura.step([],[])
	check(SkillRules.attack_value(ally,group)==group.attack,"Vigor removed when source actually retreats")
	var first := fixture(0,true);actor=first.units[0];actor.hp=1000;ally=friend(first,"target",Vector2i(13,5));ally.hp=1000
	var primary := enemy(first,Vector2i(14,5));actor.sp=2;actor.attack_ticks_left=1;first.step([],[])
	check(actor.sp==0 and actor.skill_activation_count==1 and actor.skill_ticks_left==0,"S1 actual two-SP automatic double attack")
	check(primary.hp==100000-2*damage(1442),"S1 two175% strikes with120% unblocked trait and guard factor")
	check(actor.hp==1040 and ally.hp==1040,"Two actual enemy attacks each heal self/front20 at current50% healing")
	var blocked := fixture(0,true);actor=blocked.units[0];actor.hp=1000;primary=enemy(blocked,Vector2i(13,5));actor.sp=2;actor.attack_ticks_left=1;blocked.step([],[])
	check(blocked.enemy_is_blocked(primary,actor.unit_id) and primary.hp==100000-2*damage(1202),"Own approved blocking suppresses120% trait")
	var silenced := fixture(0,true);actor=silenced.units[0];actor.hp=1000;primary=enemy(silenced,Vector2i(14,5));StatusRules.apply_silence(silenced,actor,60);actor.sp=2;actor.attack_ticks_left=1;silenced.step([],[])
	check(actor.sp==2 and actor.hp==1000 and primary.hp==100000-damage(824),"Silence suppresses both talents and S1, retains branch trait and ordinary attack")
	var second := fixture(1,true);actor=second.units[0];actor.hp=1000;primary=enemy(second,Vector2i(15,5));actor.sp=25;actor.attack_ticks_left=1;cast(second)
	check(actor.sp==0 and actor.skill_ticks_left==749 and SkillRules.attack_value(actor,op)==1237 and primary.hp==100000-damage(1484),"S2 actual25SP,25seconds,+80% and third-front range")
	var stun_count := int(primary.stun_ticks_left==6)
	for index in 99:
		actor.hp=1000;actor.attack_ticks_left=1;primary.hp=100000;primary.stun_ticks_left=0;second.step([],[])
		if primary.stun_ticks_left==6:stun_count+=1
	check(stun_count>=70 and stun_count<100,"Actual85%% stun gives successes and failures with deterministic seed; observed%d"%stun_count)
	var blaze := load("res://resources/operators/blaze.tres") as OperatorData;data.blaze=blaze
	var resistant := fixture(1,true);actor=resistant.units[0];actor.hp=1000;actor.sp=25;primary=enemy(resistant,Vector2i(15,5));primary.operator_id="blaze";primary.deployed_tick=-500;actor.attack_ticks_left=1;cast(resistant)
	for index in 20:
		if primary.stun_ticks_left==3:break
		actor.hp=1000;actor.attack_ticks_left=1;primary.hp=100000;resistant.step([],[])
	check(primary.stun_ticks_left==3,"New0.2second stun is halved once by existing resistance")
	var third := fixture(2);actor=third.units[0];actor.sp=50;cast(third)
	check(actor.sp==0 and actor.skill_ticks_left==899 and SkillRules.attack_value(actor,op)==1718 and SkillRules.defense_value(actor,op)==614 and SkillRules.block_count_value(actor,op)==3,"S3 self fallback:100%ATK plus maximum50% vigor,35%DEF,+1block")
	actor.hp=1000
	for tick in 3:third.step([],[])
	check(SkillRules.attack_value(actor,op)==1374 and SkillRules.defense_value(actor,op)==614 and SkillRules.block_count_value(actor,op)==3,"Below80% removes vigor only")
	third.squad_ids[0].append("minos_ally");third.squad_skills[0].append(0)
	var before_cost := third.sides[0].cost
	third.step([InputCommand.new(third.tick,0,"minos_ally",-1,Vector2i(13,5),-1,0)],[])
	ally=third.units[1]
	check(ally.operator_id=="minos_ally" and third.sides[0].cost==before_cost-group.deploy_cost,"Actual legal front deployment and exact cost before transfer")
	check(SkillRules.attack_value(actor,op)==1374 and SkillRules.block_count_value(actor,op)==2 and SkillRules.attack_value(ally,group)==roundi(group.attack*1.5) and SkillRules.defense_value(ally,group)==roundi(group.defense*1.35) and SkillRules.block_count_value(ally,group)==group.block_count+1,"Front ground ally gets packet; own packet removed; Minos25 does not stack with50")
	StatusRules.apply_silence(third,ally,90)
	check(SkillRules.attack_value(ally,group)==roundi(group.attack*1.5),"External blessing survives recipient silence")
	third._retreat_unit(ally);actor.hp=1963;third.step([],[])
	check(SkillRules.attack_value(actor,op)==1718 and SkillRules.block_count_value(actor,op)==3,"Front actual retreat immediately returns packet to source at refresh")
	var high := fixture(2);actor=high.units[0];high.platform_cells.append(Vector2i(13,5));ally=friend(high,"target",Vector2i(13,5));actor.sp=50;cast(high)
	check(SkillRules.block_count_value(actor,op)==3 and SkillRules.block_count_value(ally,dummy)==dummy.block_count,"Front high tile rejects ally packet, source retains it")
	for facing in 4:
		var mult := fixture(2,true);actor=mult.units[0];actor.facing=facing;actor.hp=1000;actor.sp=50;actor.attack_ticks_left=1
		var enemies: Array[UnitState]=[]
		for x in [1,2,3]:enemies.append(enemy(mult,actor.cell+AttackRange.rotate_offset(Vector2i(x,0),facing)))
		cast(mult)
		check(actor.hp==1040,"S3 two reachable actual targets each heal20 facing%d"%facing)
		check(enemies[0].hp<100000 and enemies[1].hp<100000 and enemies[2].hp==100000,"S3 respects original two-front-cell reach and unique occupancy facing%d"%facing)
		ally=friend(mult,"target",actor.cell+AttackRange.rotate_offset(Vector2i(1,0),facing));enemies[0].hp=0;mult.step([],[])
		check(SkillRules.block_count_value(ally,dummy)==dummy.block_count+1,"Front rotates with facing%d"%facing)
	var objects := fixture(0,true);actor=objects.units[0];actor.hp=1000;actor.sp=2;actor.attack_ticks_left=1;objects.tactical_boxes=[TacticalBox.new(0,Vector2i(14,5),3)];objects.step([],[])
	check(objects.tactical_boxes[0].hits_left==1 and actor.hp==1000 and actor.sp==0,"Box S1 double hit consumesSP but does not invent enemy-heal trigger")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:enemy(state,Vector2i(14,5));state.units[0].sp=op.skills[index].sp_required;state.units[0].attack_ticks_left=1
		for tick in 950:
			var commands: Array[InputCommand]=[]
			if tick==0:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Replay S%d tick%d"%[index+1,tick])
	var hashed := fixture(2)
	for key in ["pallas_vigor_next_tick","pallas_vigor_percent","pallas_blessing_next_tick","pallas_blessing_vigor_percent"]:
		var previous := hashed.state_hash();hashed.units[0].set(key,hashed.units[0].get(key)+1);check(previous!=hashed.state_hash(),"Hash includes "+key)
	print("PALLAS_OK all3 skills, actual deployment/cost/SP, trait and both talents, dynamic blessing, resistance and3x950tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(index: int, low: bool = false) -> MatchState:
	var state := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["pallas"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"pallas",-1,Vector2i(12,5),-1,0)],[])
	check(state.units.size()==1 and state.units[0].operator_id=="pallas" and state.sides[0].cost==82,"Controlled99 actual legal deployment deducts17")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=10000
	if low:
		state.units[0].hp=1000
		for tick in 3:state.step([],[])
	return state


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,state.units[0].skill_index)],[])


func friend(state: MatchState, id: String, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,0,id,cell,data[id].max_health,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func damage(value: int) -> int:
	return Combat.calculate_damage(value,0,0,"physical",0,RNG.new(1),"guard")


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
