extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;push_error(label)
func fixture(id: String,index: int=0) -> MatchState:
	var source: OperatorData=load("res://resources/operators/"+id+".tres")
	var target: OperatorData=load("res://resources/operators/bagpipe.tres").duplicate(true)
	target.max_health=100000
	var state:=MatchState.new(123,{id:source,"bagpipe":target})
	state.ball.cell=Vector2i(10,10)
	state.units=[UnitState.new(0,0,id,Vector2i(12,2) if source.terrain_requirement=="high" else Vector2i(11,5),source.max_health,0,0,2,index),UnitState.new(1,1,"bagpipe",Vector2i(10,2) if source.terrain_requirement=="high" else Vector2i(10,5),100000,0,99999,0,0)]
	state.next_unit_id=2
	return state
func fire(state: MatchState) -> void:
	var deadline:=state.tick+90
	while state.units[0].last_attack_tick<0 and state.tick<deadline:state.step([],[])
	check(state.units[0].last_attack_tick>=0,"Measured attack eventually releases")
func impact(state: MatchState) -> void:
	var deadline:=state.tick+90
	while not state.attack_projectiles.is_empty() and state.tick<deadline:state.step([],[])
	check(state.attack_projectiles.is_empty(),"Released shot eventually settles")
func run() -> void:
	# Locked windup, no speculative damage/SP and no retargeting.
	for id in ["surtr","exusiai"]:
		var state:=fixture(id);var unit:=state.units[0];var victim:=state.units[1]
		state.step([],[])
		check(unit.attack_intent!=null and unit.attack_started_tick==0 and unit.last_attack_tick==-1 and victim.hp==100000 and unit.sp==0,id+" begins before damage and recovery SP")
		var intent:=unit.attack_intent
		var before:=state.state_hash();intent.release_tick+=1;check(before!=state.state_hash(),"Pending release contributes to hash");intent.release_tick-=1
		var start:=unit.attack_started_tick;var interval:=intent.interval_ticks
		fire(state)
		check(unit.last_attack_tick==intent.release_tick and unit.attack_started_tick==start and unit.sp==1,id+" recovery and fire timestamp belong to release")
		if id=="surtr":check(victim.hp<100000 and state.attack_projectiles.is_empty(),"Melee hits at release")
		else:
			check(victim.hp==100000 and state.attack_projectiles.size()==1,"Projectile release precedes impact")
			before=state.state_hash();state.attack_projectiles[0].attack+=1;check(state.state_hash()!=before,"Released snapshot contributes to hash");state.attack_projectiles[0].attack-=1
			var arrival:=state.attack_projectiles[0].arrival_tick
			impact(state);check(victim.hp<100000 and victim.last_damage_tick==arrival,"Projectile settles on scheduled simulation tick")
		while unit.attack_started_tick==start and state.tick<interval+4:state.step([],[])
		check(unit.attack_started_tick-start==interval,id+" next cycle measured from attack start")
		for control in ["stun","freeze","sleep"]:
			state=fixture(id);unit=state.units[0];victim=state.units[1];state.step([],[])
			if control=="freeze":StatusRules.add_control(state,unit,"frozen",1)
			else:StatusRules.add_control(state,unit,control,1)
			state.step([],[])
			check(unit.attack_intent==null and unit.last_attack_tick==-1 and victim.hp==100000,id+" pre-release "+control+" cancels")
		state=fixture(id);unit=state.units[0];victim=state.units[1];state.step([],[])
		state.units.append(UnitState.new(2,1,"bagpipe",victim.cell,100000,0,99999));state.next_unit_id=3
		victim.hp=0
		for tick in 18:state.step([],[])
		check(unit.last_attack_tick==-1 and state.units[-1].hp==100000,id+" invalid target never replaced inside the windup")
	var slowed:=fixture("exusiai");slowed.step([],[])
	var slow_unit:=slowed.units[0];var old_ready:=slow_unit.attack_next_ready_tick
	StatusRules.add_control(slowed,slow_unit,"slow",30)
	check(slow_unit.attack_intent==null and slow_unit.attack_next_ready_tick==old_ready+Config.SLOW_INTERRUPT_DELAY_TICKS,"Existing explicit slow interruption penalty remains on next-ready tick")
	# The same core also covers ordinary attribute melee and single-target firearm profiles.
	for id in ["skadi","jessica"]:
		var expanded:=fixture(id);var actor:=expanded.units[0]
		expanded.step([],[])
		check(actor.attack_intent!=null and expanded.units[1].hp==100000,id+" begins a source-specific windup")
		fire(expanded)
		if id=="jessica":impact(expanded)
		check(expanded.units[1].hp<100000,id+" settles through the shared timeline")
		var doze:=fixture(id);doze.step([],[]);doze.units[0].titi_doze_owner_id=42
		AttackRules.resolve(doze)
		check(doze.units[0].attack_intent==null,"Independent doze gate cancels pending "+id+" attack")
	var shifted:=fixture("skadi");shifted.step([],[])
	var shifting_actor:=shifted.units[0]
	var distance:=DisplacementRules.apply_unit(shifted,shifted.units[1],shifting_actor,Vector2i.RIGHT,4)
	check(distance>0 and shifting_actor.attack_intent==null and shifting_actor.last_basic_interrupt_tick==shifted.tick,"Actual displacement immediately cancels windup even after this actor's attack phase")
	# Actual accepted deployments still enter the same ordinary attack phase (SP/CD controlled only in QA).
	for id in ["surtr","exusiai"]:
		var definitions: Dictionary={id:load("res://resources/operators/"+id+".tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
		var squads: Array=[PackedStringArray([id]),PackedStringArray(["bagpipe"])]
		var skills: Array=[PackedInt32Array([2]),PackedInt32Array([0])]
		var live:=MatchState.new(11,definitions,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,squads,skills)
		live.sides[0].cost=99;live.sides[1].cost=99
		var row:=5 if id=="surtr" else 2
		live.step([InputCommand.new(0,0,id,-1,Vector2i(11 if id=="surtr" else 12,row),2,2)],[InputCommand.new(0,0,"bagpipe",-1,Vector2i(9,row),0,0)])
		check(live.units.size()==2,"Two legal real deployments for "+id)
		live.units[0].sp=definitions[id].skills[2].sp_required;live.units[0].attack_ticks_left=0;live.units[1].attack_ticks_left=99999
		if id=="surtr":live.step([InputCommand.new(live.tick,1,"",0,Vector2i.ZERO,2)],[])
		fire(live)
		check(live.units[0].attack_started_tick<live.units[0].last_attack_tick,"Actual deployment and skill lead through measured windup")
	# All carried skills use the same phases, with native action selection for Surtr S2/S3.
	for id in ["surtr","exusiai"]:
		for index in 3:
			var state:=fixture(id,index);var unit:=state.units[0]
			var data: OperatorData=state._operator_data[id];unit.sp=data.skills[index].sp_required
			if data.skills[index].trigger_type=="manual":state.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,index)],[])
			else:state.step([],[])
			fire(state)
			if id=="surtr" and index>0:check(unit.attack_action_clip==("Skill_2" if index==1 else "Skill_3_Loop"),"Surtr skill action maps to actual source clip")
			if id=="exusiai":
				var expected: int=data.skills[index].effect_params.shot_count
				check(state.attack_projectiles.size()==1 and state.attack_projectiles[0].shots==expected,"Carried Exusiai volley snapshot "+str(index))
				impact(state)
	var single:=fixture("surtr",1);single.units[0].sp=18
	single.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[]);fire(single)
	check(single.units[1].hp==99054,"Surtr S2 single target retains 160 percent bonus and 946 damage")
	var dual:=fixture("surtr",1);dual.units[0].sp=18
	dual.units.append(UnitState.new(2,1,"bagpipe",Vector2i(9,5),100000,0,99999));dual.next_unit_id=3
	dual.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[]);fire(dual)
	check(dual.units[1].hp==99409 and dual.units[2].hp==99409,"Surtr S2 locks two targets without single-target bonus")
	var refund:=fixture("surtr",0);refund.units[0].sp=2;refund.units[1].hp=1
	refund.step([],[]);fire(refund)
	check(refund.units[0].sp==2 and refund.units[0].skill_ticks_left==0,"Surtr S1 lethal release still refunds full skill SP")
	# Selection priority never changes the existing unit_id damage settlement order.
	var ordered:=fixture("surtr",1);var order_source:=ordered.units[0]
	ordered._operator_data.surtr=ordered._operator_data.surtr.duplicate(true)
	ordered._operator_data.surtr.talent_2.effect_type="none"
	var thorns: OperatorData=load("res://resources/operators/hoshiguma.tres").duplicate(true)
	thorns.max_health=100000;thorns.talent_1.effect_type="none";ordered._operator_data.hoshiguma=thorns
	var low:=UnitState.new(1,1,"hoshiguma",Vector2i(10,5),100000,0,99999,0,1)
	var high:=UnitState.new(2,1,"bagpipe",Vector2i(9,5),100000,0,99999);high.lee_marked=true
	ordered.units=[order_source,low,high];ordered.next_unit_id=3
	order_source.hp=1;order_source.skill_ticks_left=300
	var selected:=PusherRules.targets(ordered,order_source,AttackRange.effective_offsets(order_source,ordered._operator_data.surtr),false)
	check(selected[0]==high,"Higher-id marked target wins actual taunt selection")
	AttackTimeline.begin(ordered,order_source,ordered._operator_data.surtr,selected,null,false)
	while order_source.last_attack_tick<0 and ordered.tick<60:ordered.step([],[])
	check(order_source.hp<=0 and high.hp==100000,"Lower-id thorns settles first; lethal counter prevents later higher-id hit")
	# Mid-windup activation changes output at release, but never changes the current action/cycle.
	var state:=fixture("exusiai",1);var unit:=state.units[0]
	unit.sp=35;state.step([],[]);var release:=unit.attack_intent.release_tick;var interval:=unit.attack_intent.interval_ticks
	unit.aak_buff_ticks=90;unit.aak_speed_add=50
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,1)],[])
	check(SkillRules.attack_interval_ticks(unit,state._operator_data.exusiai)<interval,"Actual Aak attack speed buff changes next interval")
	check(unit.attack_intent.release_tick==release and unit.attack_ticks_left==interval-1,"Mid-cycle speed/stat changes preserve pending timing")
	fire(state)
	var shot:=state.attack_projectiles[0];var snapshot:=shot.attack
	check(shot.shots==4 and snapshot==SkillRules.attack_output_value(unit,state._operator_data.exusiai),"Offense and shot count sampled at release")
	unit.silence_ticks_left=60;unit.stun_ticks_left=60;unit.attack_bonus_percent=999
	state._retreat_unit(unit)
	impact(state);check(state.units[0].hp==99552,"Released four-shot snapshot survives silence/control and actual retreat with unchanged 448 damage")
	var lost:=fixture("exusiai");lost.step([],[]);fire(lost)
	lost.units[1].hp=0;lost.units.append(UnitState.new(2,1,"bagpipe",Vector2i(10,2),100000,0,99999));lost.next_unit_id=3
	impact(lost);check(lost.units[-1].hp==100000,"Released bullet cannot hit a replacement unit in the same cell")
	# Locked object identity and ball generation prohibit hitting a newly substituted target.
	state=fixture("exusiai");state.units.resize(1);state.tactical_boxes=[TacticalBox.new(7,Vector2i(10,2),3)];state.step([],[]);fire(state)
	state.tactical_boxes=[TacticalBox.new(8,Vector2i(10,2),3)];impact(state)
	check(state.tactical_boxes[0].hits_left==3,"Destroyed/replaced box is not retargeted")
	state=fixture("exusiai");state.units.resize(1);state.ball.cell=Vector2i(10,2);state.step([],[]);fire(state)
	state.goals[0]+=1;impact(state);check(state.ball.accum==Vector2i.ZERO,"Scored ball cannot be hit by previous generation")
	# Continuous same-seed replay includes windup, flight and skill expiry.
	var a:=fixture("exusiai",1);var b:=fixture("exusiai",1)
	a.units[0].sp=35;b.units[0].sp=35
	for tick in 600:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(InputCommand.new(0,1,"",0,Vector2i.ZERO,1))
		var wire:=CommandCodec.decode(JSON.parse_string(JSON.stringify(CommandCodec.encode(commands))),tick,root.get_node("OperatorDB").network_content()["ids"])
		a.step(commands,[]);b.step(wire.commands,[])
		check(a.state_hash()==b.state_hash(),"600tick replay divergence at "+str(tick))
	print("ATTACK_TIMELINE_OK: four measured operators / focused skill and control paths, begin-release-impact, cancellation, source retreat, locked target/object/ball generation, snapshot/hash/cadence and 600tick replay; failures=",failures)
	quit(0 if failures==0 else 1)
