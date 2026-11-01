extends SceneTree

var failures := 0
var data := {}
var op: OperatorData


func _initialize() -> void:
	op=load("res://resources/operators/archetto.tres");data.archetto=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.skills[0].sp_recharge_type="on_hit";data.target=dummy
	check(op.validation_error().is_empty(),"Resource: "+op.validation_error())
	check(op.max_health==1705 and op.attack==528 and op.defense==172 and op.skills.size()==3,"E2 zero trust/potential/module stats")
	var first := fixture(0);var actor: UnitState=first.units[0]
	var primary := enemy(first,Vector2i(15,2))
	var near := enemy(first,Vector2i(15,3));var diagonal := enemy(first,Vector2i(16,3));var other := enemy(first,Vector2i(16,2));var outside := enemy(first,Vector2i(17,2))
	actor.sp=3;actor.attack_ticks_left=1;first.step([],[])
	check(actor.sp==0 and actor.skill_activation_count==1 and actor.skill_ticks_left==0,"S1 automatic attack consumes actual3SP")
	check(primary.hp==100000-damage(1214),"S1 primary230% and inherited sniper factor")
	for target in [near,diagonal,other]:check(target.hp==100000-damage(950),"S1 actual three extra180% hits")
	check(outside.hp==100000,"S1 rejects distance2")
	var crowded := fixture(0);var main := enemy(crowded,Vector2i(15,2))
	var tied: Array[UnitState]=[]
	for cell in [Vector2i(14,2),Vector2i(15,1),Vector2i(16,2),Vector2i(16,3)]:tied.append(enemy(crowded,cell))
	crowded.units[0].sp=3;crowded.units[0].attack_ticks_left=1;crowded.step([],[])
	check(main.hp<100000 and tied[0].hp<100000 and tied[1].hp<100000 and tied[2].hp<100000 and tied[3].hp==100000,"Nearest3 extras; equal distance uses ID")
	var shield := fixture(1);actor=shield.units[0]
	check(actor.nian_shield_layers==1,"Actual deploy gives one shield")
	shield._apply_damage(actor,op,100,"true")
	check(actor.hp==1705 and actor.sp==7 and actor.nian_shield_layers==0,"Shield blocks actual true damage and gives7SP once")
	shield._apply_damage(actor,op,100,"physical")
	check(actor.hp==1605 and actor.sp==7,"Second hit damages, no repeat7SP")
	var silenced := fixture(1);StatusRules.apply_silence(silenced,silenced.units[0],90)
	silenced._apply_damage(silenced.units[0],op,100,"magical")
	check(silenced.units[0].hp==1705 and silenced.units[0].sp==0 and silenced.units[0].nian_shield_layers==0,"Existing shield survives silence; muted talent cannot grant SP")
	var aura := fixture(1);actor=aura.units[0]
	var sniper := dummy.duplicate(true) as OperatorData;sniper.operator_id="ally_sniper";sniper.profession_id="sniper";sniper.skills[0].sp_recharge_type="on_hit";data.ally_sniper=sniper;aura._operator_data.ally_sniper=sniper
	var ally := UnitState.new(1,0,"ally_sniper",Vector2i(13,1),100000,0,100000);aura.units.append(ally);aura.next_unit_id=2
	var foe := enemy(aura,Vector2i(3,1));foe.operator_id="ally_sniper"
	var guard := UnitState.new(aura.next_unit_id,0,"target",Vector2i(13,3),100000,0,100000);aura.units.append(guard);aura.next_unit_id+=1
	while aura.tick<75:aura.step([],[])
	check(actor.sp==0 and ally.sp==0,"Aura not before own75ticks")
	aura.step([],[])
	check(actor.sp==1 and ally.sp==1 and foe.sp==0 and guard.sp==0,"Aura self+ally sniper attack-SP only")
	StatusRules.apply_silence(aura,actor,200)
	while aura.tick<151:aura.step([],[])
	check(actor.sp==1 and ally.sp==1,"Silenced provider stops periodic SP")
	var pursuit := fixture(1);actor=pursuit.units[0];primary=enemy(pursuit,Vector2i(15,2))
	actor.sp=27;cast(pursuit)
	check(actor.sp==18 and pursuit.archetto_volleys.size()==1 and primary.hp==100000-damage(739),"S2 actual9SP, first140% hit, three-charge cap27")
	actor.attack_ticks_left=10000
	var start := pursuit.tick;var hits := PackedInt32Array([0]);var hp := primary.hp
	for tick in 18:
		pursuit.step([],[])
		if primary.hp!=hp:hits.append(pursuit.tick-start);hp=primary.hp
	check(hits==PackedInt32Array([0,5,9,14,18]) and primary.hp==100000-5*damage(739) and pursuit.archetto_volleys.is_empty(),"Five hits at cumulative rounded0.15seconds; clean lifecycle")
	var chain := fixture(1);actor=chain.units[0];var chain_targets: Array[UnitState]=[]
	for cell in [Vector2i(15,2),Vector2i(16,2),Vector2i(17,2),Vector2i(18,2),Vector2i(19,2)]:chain_targets.append(enemy(chain,cell))
	actor.sp=9;cast(chain);actor.attack_ticks_left=10000
	for tick in 64:chain.step([],[])
	for index in 5:check(chain_targets[index].hp==100000-(5-index)*damage(739),"S2 bounce %d has %d hits"%[index,5-index])
	check(chain.archetto_volleys.is_empty(),"No sixth bounce or revisit")
	var death := fixture(1);actor=death.units[0];primary=enemy(death,Vector2i(15,2));primary.hp=1;near=enemy(death,Vector2i(16,2));outside=enemy(death,Vector2i(18,2));actor.sp=9;cast(death);actor.attack_ticks_left=10000
	for tick in 20:death.step([],[])
	check(primary.hp<=0 and near.hp==100000-4*damage(739) and outside.hp==100000 and death.archetto_volleys.is_empty(),"Dead primary immediately redirects four-hit segment; distance bound")
	var overlap := fixture(1);actor=overlap.units[0];primary=enemy(overlap,Vector2i(15,2));actor.sp=27
	for index in 3:cast(overlap)
	actor.attack_ticks_left=10000
	check(actor.sp==0 and overlap.archetto_volleys.size()==3,"Three stored casts retain independent projectiles")
	for tick in 18:overlap.step([],[])
	check(primary.hp==100000-15*damage(739) and overlap.archetto_volleys.is_empty(),"Overlapping casts each finish all5hits")
	var departed := fixture(1);actor=departed.units[0];primary=enemy(departed,Vector2i(15,2));actor.sp=9;cast(departed)
	departed.step([InputCommand.new(departed.tick,2,"",actor.unit_id)],[])
	for tick in 17:departed.step([],[])
	check(primary.hp==100000-5*damage(739) and departed.archetto_volleys.is_empty(),"Launched arrows finish after actual retreat")
	var missing := fixture(1);missing.units[0].sp=9;cast(missing)
	check(missing.units[0].sp==9 and missing.archetto_volleys.is_empty(),"No target cannot consume a charge")
	for facing in 4:
		var third := fixture(2);actor=third.units[0];actor.facing=facing;actor.sp=30;actor.attack_ticks_left=1
		primary=enemy(third,actor.cell+AttackRange.rotate_offset(Vector2i(4,0),facing))
		near=enemy(third,actor.cell+AttackRange.rotate_offset(Vector2i(4,1),facing))
		outside=enemy(third,actor.cell+AttackRange.rotate_offset(Vector2i(3,0),facing))
		cast(third)
		check(actor.sp==0 and actor.skill_ticks_left==599 and SkillRules.attack_value(actor,op)==686,"S3 actual30SP/20seconds/+30%%ATK facing%d"%facing)
		check(primary.hp==100000-3*damage(686) and near.hp==100000-3*damage(686) and outside.hp==100000,"S3 three shots against two targets including forward extension facing%d"%facing)
		StatusRules.apply_silence(third,actor,60)
		check(SkillRules.attack_value(actor,op)==528 and not Vector2i(4,0) in AttackRange.effective_offsets(actor,op),"Silence suppresses S3 bonus/range")
	var boxes := fixture(1);actor=boxes.units[0];actor.sp=9;boxes.tactical_boxes=[TacticalBox.new(0,Vector2i(15,2),3)];cast(boxes);actor.attack_ticks_left=10000
	for tick in 9:boxes.step([],[])
	check(boxes.tactical_boxes.is_empty() and boxes.archetto_volleys.is_empty(),"Pursuit stops when actual box breaks after three hits")
	var ball := fixture(1);actor=ball.units[0];actor.sp=9;ball.ball.cell=Vector2i(15,2);ball._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);ball._ball_data.kick_threshold=1000000000;cast(ball);actor.attack_ticks_left=10000
	check(ball.archetto_volleys.size()==1,"S2 ball target launches actual field")
	ball.ball.cell=Vector2i(16,2)
	for tick in 5:ball.step([],[])
	check(ball.archetto_volleys.is_empty(),"Ball moved away cancels remaining object hits")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:enemy(state,Vector2i(15,2));enemy(state,Vector2i(16,2));state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=1
		for tick in 800:
			var commands: Array[InputCommand]=[]
			if tick==0 or (index==1 and tick in [1,2]):commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Replay S%d tick%d"%[index+1,tick])
	var hashed := fixture(1);enemy(hashed,Vector2i(15,2));hashed.units[0].sp=9;cast(hashed)
	var field: ArchettoVolley=hashed.archetto_volleys[0]
	for key in ["source_id","side","facing","target_kind","target_id","attack","shots_left","segment_shots","total_shots","next_tick","start_tick","goal_generation"]:
		var previous := hashed.state_hash();field.set(key,field.get(key)+1);check(previous!=hashed.state_hash(),"Hash includes field."+key)
	for key in ["source_cell","cell"]:
		var previous := hashed.state_hash();field.set(key,field.get(key)+Vector2i.ONE);check(previous!=hashed.state_hash(),"Hash includes vector."+key)
	var previous := hashed.state_hash();field.visited_ids.append(999);check(previous!=hashed.state_hash(),"Hash includes visited set")
	print("ARCHETTO_OK all3 skills, actual deployment/cost/SP, both talents, field lifecycle, four directions,3x800tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(index: int) -> MatchState:
	var state := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["archetto"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"archetto",-1,Vector2i(13,2),-1,0)],[])
	check(state.units.size()==1 and state.units[0].operator_id=="archetto" and state.sides[0].cost==85,"Controlled99 legal high-tile deployment deducts14")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=10000;return state


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,state.units[0].skill_index)],[])


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func damage(value: int) -> int:
	return Combat.calculate_damage(value,0,0,"physical",0,RNG.new(1),"sniper")


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
