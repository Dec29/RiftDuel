extends SceneTree

var failures := 0
var data := {}
var op: OperatorData


func _initialize() -> void:
	op=load("res://resources/operators/lin.tres");data.lin=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	check(op.validation_error().is_empty() and op.max_health==2048 and op.attack==849 and op.defense==242 and op.magic_resist==15 and op.skills.size()==3,"Original E2 no trust/potential/module, actual3 M3 skills")
	var wall := fixture(0);var actor: UnitState=wall.units[0];var primary := enemy(wall,Vector2i(15,2))
	check(actor.lin_wall_active and actor.lin_wall_owner_id==actor.unit_id and SkillRules.defense_value(actor,op)==726 and SkillRules.magic_resist_value(actor,op)==35,"Actual deployment gives glass wall and idle trait")
	for kind in ["physical","magical","true"]:
		check(not wall._apply_damage(actor,op,200,kind,primary) and actor.hp==2048 and actor.lin_wall_active,"Wall blocks threshold200 inclusive for "+kind)
	wall._apply_damage(actor,op,201,"true",primary)
	check(actor.hp==2047 and not actor.lin_wall_active and actor.lin_wall_ready_tick==wall.tick+240,"Strictly201 breaks wall, absorbs200, leaves1damage and8second recovery")
	check(primary.hp==100000-damage(849) and primary.stun_ticks_left==30,"Normal shatter deals100% magic damage from Lin and stuns1second")
	wall._apply_damage(actor,op,100,"true",primary)
	check(actor.hp==1947,"Broken wall cannot absorb the next hit")
	var ready := actor.lin_wall_ready_tick
	while wall.tick<ready:wall.step([],[])
	check(not actor.lin_wall_active,"Wall not regenerated before recovery phase")
	wall.step([],[]);check(actor.lin_wall_active,"Wall regenerated at exact ready tick")
	var fatal := fixture(0);actor=fatal.units[0];actor.hp=1;primary=enemy(fatal,Vector2i(15,2));fatal._apply_damage(actor,op,202,"true",primary)
	check(actor.hp<=0 and primary.hp==100000-damage(849) and primary.stun_ticks_left==30,"Normal fatal incoming damage shatters before HP loss")
	var muted := fixture(0);actor=muted.units[0];primary=enemy(muted,Vector2i(15,2));StatusRules.apply_silence(muted,actor,90);muted._apply_damage(actor,op,100,"true",primary)
	check(actor.hp==1948 and primary.hp==100000,"Muted source cannot use glass talent")
	var first := fixture(0);actor=first.units[0];primary=enemy(first,Vector2i(15,2));actor.sp=5;actor.attack_ticks_left=0;cast(first)
	check(actor.sp==0 and actor.skill_ticks_left==-2 and actor.skill_activation_count==1 and SkillRules.attack_value(actor,op)==1358 and SkillRules.attack_interval_ticks(actor,op)==90,"S1 actual five-SP toggle,60%ATK and3second interval")
	check(primary.hp==100000-damage(1358) and primary.slow_ticks_left==30 and SkillRules.defense_value(actor,op)==242 and SkillRules.magic_resist_value(actor,op)==15,"S1 active-state attack/slow and no idle defenses")
	actor.attack_ticks_left=10000
	for tick in 150:first.step([],[])
	check(actor.sp==5 and actor.skill_ticks_left==-2,"S1 stance continues actual natural SP to cap5")
	cast(first)
	check(actor.sp==0 and actor.skill_ticks_left==0 and SkillRules.defense_value(actor,op)==726 and SkillRules.magic_resist_value(actor,op)==35,"S1 actual paid toggle returns to idle")
	var second := fixture(1);actor=second.units[0];var ally := deploy_ally(second,Vector2i(14,2));actor.sp=30;cast(second)
	check(actor.sp==0 and actor.skill_ticks_left==749 and SkillRules.attack_interval_ticks(actor,op)==26 and SkillRules.taunt_level(actor,op)==-1,"S2 actual30SP,25seconds,+130ASPD and lower taunt")
	check(ally.lin_wall_active and ally.lin_wall_owner_id==actor.unit_id and actor.lin_wall_active,"S2 grants independent wall to real deployed ally")
	primary=enemy(second,Vector2i(16,2));var before := primary.hp
	second._apply_damage(ally,dummy,250,"true",primary)
	check(ally.hp==dummy.max_health-50 and not ally.lin_wall_active and actor.lin_wall_active,"Ally250hit loses50HP, breaks only ally wall")
	check(primary.hp==before-damage(849) and primary.stun_ticks_left==30,"Ally-centered shatter uses original Lin attack/source, not ally attack")
	for tick in 5:second.step([],[])
	second._apply_damage(actor,op,250,"true",primary)
	check(actor.hp==1998 and not actor.lin_wall_active and actor.lin_wall_ready_tick==ally.lin_wall_ready_tick+5,"Owner wall breaks independently")
	var outside := deploy_ally_fixture(second,Vector2i(18,5));second.step([],[])
	check(outside.lin_wall_owner_id==-1,"S2 does not gift out of original range")
	ally.cell=Vector2i(18,4);second.step([],[]);check(ally.lin_wall_owner_id==-1 and not ally.lin_wall_active,"Leaving range removes external wall")
	ally.cell=Vector2i(14,2);second.step([],[]);check(ally.lin_wall_active,"Reentering range obtains a new independent effect")
	actor.skill_ticks_left=1;second.step([],[])
	check(ally.lin_wall_owner_id==-1 and not ally.lin_wall_active and actor.lin_wall_owner_id==actor.unit_id,"S2 expiry removes external effect, retains owner's own talent")
	var nian := load("res://resources/operators/nian.tres") as OperatorData;data.nian=nian
	var shared := fixture(1);actor=shared.units[0];shared.squad_ids[0].append("nian");shared.squad_skills[0].append(0)
	var original_cost := shared.sides[0].cost
	shared.step([InputCommand.new(shared.tick,0,"nian",-1,Vector2i(14,2),-1,0)],[])
	ally=shared.units[1]
	check(ally.operator_id=="nian" and shared.sides[0].cost==original_cost-nian.deploy_cost and ally.nian_shield_layers==3,"Actual Nian deploy/cost and three native shield layers")
	actor.sp=30;cast(shared);primary=enemy(shared,Vector2i(16,2));var nian_hp := ally.hp
	shared._apply_damage(ally,nian,200,"true",primary)
	check(ally.nian_shield_layers==3 and ally.lin_wall_active and ally.hp==nian_hp,"Normal glass wall absorbs before Nian layers")
	shared._apply_damage(ally,nian,201,"true",primary)
	check(ally.nian_shield_layers==2 and not ally.lin_wall_active and ally.hp==nian_hp,"Normal glass shatters before residual damage reaches Nian layer")
	var third := fixture(2);actor=third.units[0];primary=enemy(third,Vector2i(15,3));actor.sp=50;actor.attack_ticks_left=1;cast(third)
	check(actor.sp==0 and actor.skill_ticks_left==899 and SkillRules.attack_value(actor,op)==2547 and primary.hp==100000-damage(2547),"S3 actual50SP,30seconds,+200%ATK and expanded corner")
	third._apply_damage(actor,op,600,"true",primary);check(actor.hp==2048 and actor.lin_wall_active,"S3 threshold600 inclusive")
	var before_hp := primary.hp;third._apply_damage(actor,op,650,"true",primary)
	check(actor.hp==1998 and not actor.lin_wall_active and primary.hp==before_hp-damage(2547),"S3 absorbs600, takes50, then shatters with current attack")
	var late_fatal := fixture(2);actor=late_fatal.units[0];actor.sp=50;cast(late_fatal);primary=enemy(late_fatal,Vector2i(15,3));actor.hp=1;late_fatal._apply_damage(actor,op,601,"true",primary)
	check(actor.hp<=0 and primary.hp==100000,"S3 fatal HP damage does not produce a post-mortem burst")
	var kill := fixture(2);actor=kill.units[0];actor.sp=50;actor.attack_ticks_left=1;primary=enemy(kill,Vector2i(15,3));primary.hp=1;var other := enemy(kill,Vector2i(14,2));var third_target := enemy(kill,Vector2i(13,4));cast(kill)
	check(primary.hp<=0 and other.hp==100000-2*damage(2547) and third_target.hp==100000-2*damage(2547) and actor.lin_wall_active,"S3 ordinary attack kill triggers one extra burst and immediate regeneration")
	var multi := fixture(2);actor=multi.units[0];actor.sp=50;actor.attack_ticks_left=1;primary=enemy(multi,Vector2i(15,3));primary.hp=1;other=enemy(multi,Vector2i(14,2));other.hp=1;third_target=enemy(multi,Vector2i(13,4));cast(multi)
	check(third_target.hp==100000-2*damage(2547),"Multiple normal-attack kills still trigger only one burst")
	var broken := fixture(2);actor=broken.units[0];actor.sp=50;cast(broken);primary=enemy(broken,Vector2i(15,3));primary.hp=1;other=enemy(broken,Vector2i(14,2));actor.lin_wall_active=false;actor.lin_wall_ready_tick=broken.tick+240;actor.attack_ticks_left=1;broken.step([],[])
	check(actor.lin_wall_active and other.hp==100000-damage(2547),"Kill while no wall restores it without inventing nonexistent-wall shatter")
	var stopped := fixture(2);actor=stopped.units[0];actor.sp=50;cast(stopped);check(actor.sp==0,"S3 spent all requiredSP")
	cast(stopped);check(actor.skill_ticks_left==0 and actor.sp<=1 and SkillRules.defense_value(actor,op)==726,"S3 actual command stops early at zeroSP and restores idle")
	for facing in 4:
		var rotated := fixture(2);actor=rotated.units[0];actor.facing=facing;actor.sp=50;actor.attack_ticks_left=1;primary=enemy(rotated,actor.cell+AttackRange.rotate_offset(Vector2i(2,1),facing));var distant := enemy(rotated,actor.cell+AttackRange.rotate_offset(Vector2i(2,2),facing));cast(rotated)
		check(primary.hp<100000 and distant.hp==100000,"Original expanded radial range facing%d"%facing)
	var chance := fixture(0);actor=chance.units[0];primary=enemy(chance,Vector2i(15,2));var proc_count := 0
	for index in 100:
		actor.sp=0;chance._apply_damage(actor,op,1,"physical",primary);proc_count+=actor.sp
	check(proc_count>=35 and proc_count<=65 and actor.hp==2048,"Actual50%% on-attacked SP can proc behind unbroken wall, observed%d"%proc_count)
	var dots := fixture(0);actor=dots.units[0];primary=enemy(dots,Vector2i(15,2));dots._apply_damage(actor,op,100,"magical",primary,false)
	check(actor.sp==0 and actor.hp==2048,"DOT blocked by wall but cannot trigger attacked-SP")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:enemy(state,Vector2i(15,2));state.units[0].sp=op.skills[index].sp_required;state.units[0].attack_ticks_left=1
		for tick in 1000:
			var commands: Array[InputCommand]=[]
			if tick==0 or (index==2 and tick==20):commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Everytick replay S%d tick%d"%[index+1,tick])
	var hashed := fixture(0)
	for key in ["lin_wall_owner_id","lin_wall_ready_tick"]:
		var previous := hashed.state_hash();hashed.units[0].set(key,hashed.units[0].get(key)+1);check(previous!=hashed.state_hash(),"Hash includes "+key)
	var previous := hashed.state_hash();hashed.units[0].lin_wall_active=false;check(previous!=hashed.state_hash(),"Hash includes wall active flag")
	print("LIN_OK all3 skills, actual deploy/cost/SP, both talents, normal/S3 damage priority, shield lifecycles and3x1000tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(index: int) -> MatchState:
	var state := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["lin","target"],["target"]],[[index,0],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"lin",-1,Vector2i(13,2),-1,0)],[])
	check(state.units.size()==1 and state.units[0].operator_id=="lin" and state.sides[0].cost==75,"Controlled99 actual legal high-tile deployment deducts24")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=10000;return state


func deploy_ally(state: MatchState, cell: Vector2i) -> UnitState:
	var cost := state.sides[0].cost
	state.step([InputCommand.new(state.tick,0,"target",-1,cell,-1,0)],[])
	check(state.units.size()==2 and state.units[1].operator_id=="target" and state.sides[0].cost==cost-data.target.deploy_cost,"Actual legal ground ally deployment and exact paid cost")
	state.units[1].attack_ticks_left=100000;return state.units[1]


func deploy_ally_fixture(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,0,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,state.units[0].skill_index)],[])


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func damage(value: int) -> int:
	return Combat.calculate_damage(value,0,0,"magical",0,RNG.new(1),"caster")


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
