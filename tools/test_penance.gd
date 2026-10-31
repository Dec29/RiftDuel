extends SceneTree

var failures := 0
var data := {}
var op: OperatorData


func _initialize() -> void:
	op=load("res://resources/operators/penance.tres");data.penance=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	var high := dummy.duplicate(true) as OperatorData;high.operator_id="high_target";high.profession_id="caster";high.terrain_requirement="high";data.high_target=high
	check(op.validation_error().is_empty() and op.max_health==4055 and op.attack==876 and op.defense==616 and op.skills.size()==3,"Original E2, no trust/potential/module, actual three M3 skills")
	var barrier := fixture(2);var actor: UnitState=barrier.units[0];var primary := enemy(barrier,Vector2i(13,5))
	check(actor.penance_barrier_hp==2028,"Actual deployment grants rounded current-maxHP50% barrier")
	barrier._apply_damage(actor,op,100,"true",primary)
	check(actor.hp==4055 and actor.penance_barrier_hp==1928 and actor.sp==1 and primary.hp==100000-damage(438,"magical"),"Own barrier absorbs actual hit, grants native defensiveSP, reflects50% magic once")
	var hp := primary.hp;barrier._apply_damage(actor,op,100,"magical",primary,false)
	check(actor.penance_barrier_hp==1828 and actor.sp==1 and primary.hp==hp,"DOT consumes barrier but neither reflects nor grants defensiveSP")
	actor.penance_barrier_hp=0;barrier._apply_damage(actor,op,100,"true",primary)
	check(actor.hp==3955 and actor.sp==2 and primary.hp==hp,"No own barrier means no reflect; HP hit still grants only one defensiveSP")
	LumenRules.treat_amount(barrier,actor,1000,actor);check(actor.hp==3955,"Unyield trait rejects ordinary healing")
	var muted := fixture(2);actor=muted.units[0];primary=enemy(muted,Vector2i(13,5));StatusRules.apply_silence(muted,actor,60);muted._apply_damage(actor,op,100,"true",primary)
	check(actor.hp==4055 and actor.penance_barrier_hp==1928 and primary.hp==100000,"Existing own barrier survives silence; reflective talent is muted")
	var mirror := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["penance"],["penance"]],[[2],[2]])
	mirror.sides[0].cost=99;mirror.sides[1].cost=99
	mirror.step([InputCommand.new(0,0,"penance",-1,Vector2i(12,5),-1,0)],[InputCommand.new(0,0,"penance",-1,Vector2i(7,5),-1,2)])
	check(mirror.units.size()==2 and mirror.sides[0].cost==63 and mirror.sides[1].cost==63,"Both actual mirror deployments pay36")
	actor=mirror.units[0];primary=mirror.units[1]
	var reflected := Combat.calculate_damage(438,616,10,"magical",0,RNG.new(1),"defender")
	mirror._apply_damage(actor,op,100,"true",primary)
	check(actor.penance_barrier_hp==1928 and primary.penance_barrier_hp==2028-reflected and actor.sp==1 and primary.sp==0,"Mirror reflection is a single non-attack event; no recursion or reflected-hit defensiveSP")
	var external := fixture(2);actor=external.units[0];primary=enemy(external,Vector2i(13,5));actor.penance_barrier_hp=0
	# Controlled external barrier state tests provenance only; this is not a claim that a healer can target an unyield unit.
	actor.barrier_hp=[1000];actor.barrier_ticks_left=[90];actor.barrier_defense_percent=[0];actor.barrier_magic_only=[0];actor.barrier_magic_resist_add=[0]
	external._apply_damage(actor,op,100,"true",primary)
	check(actor.hp==4055 and actor.barrier_hp[0]==900 and actor.penance_barrier_hp==0 and primary.hp==100000,"External shield pool does not falsely enable own-origin reflection")
	var reflected_kill := fixture(2);actor=reflected_kill.units[0];primary=enemy(reflected_kill,Vector2i(13,5));primary.hp=1;reflected_kill._apply_damage(actor,op,100,"true",primary)
	check(primary.hp<=0 and actor.penance_barrier_hp==2334,"Actual reflected kill grants barrier before incoming residual absorption")
	var first := fixture(0);actor=first.units[0];primary=enemy(first,Vector2i(13,5));actor.sp=3;actor.attack_ticks_left=0;first.step([],[])
	check(actor.sp==0 and actor.skill_activation_count==1 and actor.skill_ticks_left==0 and primary.hp==100000-damage(876,"physical")-damage(1752,"magical"),"S1 actual normal three-SP activation gives physical plus200% extra magic")
	var partial := fixture(0);actor=partial.units[0];primary=enemy(partial,Vector2i(13,5));actor.sp=5;actor.attack_ticks_left=0;partial.step([],[])
	check(actor.sp==0 and primary.hp==100000-damage(876,"physical")-damage(1752,"magical") and primary.stun_ticks_left==0,"S1 partial second stage consumes all5 but is not enhanced")
	var charged := fixture(0);actor=charged.units[0]
	for tick in 179:charged.step([],[])
	check(actor.sp==6 and actor.penance_charged_mode and actor.attack_ticks_left==0 and actor.skill_activation_count==0,"Actual natural full charge resets attack cycle even before a target exists")
	primary=enemy(charged,Vector2i(13,5));charged.step([],[])
	check(actor.sp==0 and not actor.penance_charged_mode and primary.hp==100000-damage(1752,"physical")-damage(3504,"magical") and primary.stun_ticks_left==150,"S1 enhanced attack immediately consumes full charge,200% ATK,400% extra magic and5second stun")
	var stunned := fixture(0);actor=stunned.units[0];primary=enemy(stunned,Vector2i(13,5));actor.sp=6;actor.stun_ticks_left=5;stunned.step([],[])
	check(actor.penance_charged_mode and actor.sp==6 and actor.attack_ticks_left==0 and primary.hp==100000,"Entering full-charge mode resets cycle while controlled but cannot attack")
	for tick in 4:stunned.step([],[])
	check(actor.sp==0 and primary.stun_ticks_left==150,"Control expiry permits the pending actual enhanced attack")
	var silent_mode := fixture(0);actor=silent_mode.units[0];primary=enemy(silent_mode,Vector2i(13,5));actor.sp=6;StatusRules.apply_silence(silent_mode,actor,60);silent_mode.step([],[])
	check(actor.penance_charged_mode and actor.sp==6 and primary.hp==100000-damage(876,"physical"),"Full charge enters mode under silence; ordinary attack is unenhanced and does not spend SP")
	var second := fixture(1,Vector2i(13,5));actor=second.units[0];primary=enemy(second,Vector2i(14,5));var other := enemy(second,Vector2i(12,4));var airborne := enemy(second,Vector2i(14,4));airborne.operator_id="high_target";actor.sp=30;actor.attack_ticks_left=1;cast(second)
	check(actor.sp==0 and actor.skill_ticks_left==599 and actor.attack_ticks_left==1 and primary.hp==100000 and AttackRange.effective_offsets(actor,op).is_empty(),"S2 actual30SP,20seconds, stops attacks and loses sight; no invented instant pulse")
	check(second._damage_taken_percent(actor,"physical")==40.0 and second._damage_taken_percent(actor,"magical")==40.0 and second._damage_taken_percent(actor,"true")==100.0,"60% sanctuary reduces physical/magic, never true damage")
	for tick in 29:second.step([],[])
	check(primary.hp==100000-damage(1226,"magical") and other.hp==100000-damage(1226,"magical") and airborne.hp==100000,"S2 first actual pulse at30ticks reaches all ground targets, excludes high tile")
	for tick in 570:second.step([],[])
	check(primary.hp==100000-20*damage(1226,"magical") and actor.skill_ticks_left==0 and AttackRange.effective_offsets(actor,op)==op.attack_range,"Exactly20 pulses, then clean S2 expiry and restored sight")
	var kills := fixture(0);actor=kills.units[0];primary=enemy(kills,Vector2i(13,5));primary.hp=1;actor.attack_ticks_left=1;kills.step([],[])
	check(actor.penance_barrier_hp==2434,"Actual ordinary kill adds rounded maxHP10% barrier")
	kills._apply_damage(primary,dummy,100,"true",actor)
	check(actor.penance_barrier_hp==2434,"Already-dead target cannot duplicate Penance kill credit")
	var enhanced_gain := fixture(1);actor=enhanced_gain.units[0];primary=enemy(enhanced_gain,Vector2i(13,5));primary.hp=1;actor.sp=30;cast(enhanced_gain)
	for tick in 29:enhanced_gain.step([],[])
	check(actor.penance_barrier_hp==2839,"S2 actual pulse kill adds20% maxHP=811, not twice rounded406")
	PenanceRules.grant(enhanced_gain,actor,op,300);check(actor.penance_barrier_hp==12165,"Own barrier caps at current maxHP300%")
	actor.max_health_bonus_percent=100;var old_barrier := actor.penance_barrier_hp
	check(actor.penance_barrier_hp==old_barrier,"Changing maxHP does not rescale existing barrier")
	PenanceRules.grant(enhanced_gain,actor,op,300);check(actor.penance_barrier_hp==24330,"Current doubled maxHP updates cap and new grants")
	actor.max_health_bonus_percent=0;PenanceRules.grant(enhanced_gain,actor,op,10);check(actor.penance_barrier_hp==24330,"Lowering maxHP retains over-cap existing pool and refuses new grants")
	var third := fixture(2);actor=third.units[0];primary=enemy(third,Vector2i(13,5));actor.sp=20;actor.attack_ticks_left=0;cast(third)
	check(actor.sp==0 and actor.skill_ticks_left==899 and actor.penance_barrier_hp==7300 and SkillRules.attack_value(actor,op)==4380 and SkillRules.attack_interval_ticks(actor,op)==75 and SkillRules.taunt_level(actor,op)==1,"S3 actual20SP,30seconds,+130% barrier,+400%ATK,2.5second interval and taunt")
	check(primary.hp==100000-damage(4380,"physical"),"S3 actual ordinary boosted attack")
	hp=primary.hp;third._apply_damage(actor,op,100,"true",primary)
	check(actor.penance_barrier_hp==7200 and actor.hp==4055 and actor.sp==0 and primary.hp==hp-damage(2190,"magical"),"S3 reflection uses current boosted ATK, defensiveSP locked during actual skill")
	actor.skill_ticks_left=1;third.step([],[])
	check(SkillRules.attack_value(actor,op)==876 and SkillRules.attack_interval_ticks(actor,op)==48 and SkillRules.taunt_level(actor,op)==0 and actor.penance_barrier_hp==7200,"S3 end preserves granted barrier, removes combat bonuses")
	var nian := load("res://resources/operators/nian.tres") as OperatorData;data.nian=nian
	var maxhp := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["penance","nian"],["target"]],[[2,0],[0]])
	maxhp.sides[0].cost=99;maxhp.step([InputCommand.new(0,0,"penance",-1,Vector2i(12,5),-1,0)],[])
	check(maxhp.units[0].hp==4704 and maxhp.units[0].penance_barrier_hp==2352 and maxhp.sides[0].cost==63,"Actual deployment after existing Nian team aura uses current maxHP for initial barrier")
	var blemishine := load("res://resources/operators/blemishine.tres") as OperatorData;data.blemishine=blemishine
	var linked := fixture(2);actor=linked.units[0];linked.squad_ids[0].append("blemishine");linked.squad_skills[0].append(0);var cost := linked.sides[0].cost
	linked.step([InputCommand.new(linked.tick,0,"blemishine",-1,Vector2i(11,5),-1,0)],[])
	check(linked.units[1].operator_id=="blemishine" and linked.sides[0].cost==cost-22,"Actual Blemishine provider deployment and exact cost")
	primary=enemy(linked,Vector2i(13,5));actor.attack_ticks_left=1;linked.step([],[])
	check(actor.sp==1,"Penance actual basic attack uses existing defensive attack-SP link")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:enemy(state,Vector2i(13,5));state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=0
		for tick in 1000:
			var commands: Array[InputCommand]=[]
			if tick==0:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Everytick replay S%d tick%d"%[index+1,tick])
	var hashed := fixture(0);var previous := hashed.state_hash();hashed.units[0].penance_barrier_hp+=1;check(previous!=hashed.state_hash(),"Hash includes own barrier pool")
	previous=hashed.state_hash();hashed.units[0].penance_charged_mode=true;check(previous!=hashed.state_hash(),"Hash includes charged mode")
	print("PENANCE_OK all3 skills, actual deploy/cost/SP, barrier provenance/cap/lifecycle, reflection/control, direct Nian/Blemishine links,3x1000tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(index: int, cell: Vector2i = Vector2i(12,5)) -> MatchState:
	var state := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["penance"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"penance",-1,cell,-1,0)],[])
	check(state.units.size()==1 and state.units[0].operator_id=="penance" and state.sides[0].cost==63,"Controlled99 actual legal ground deployment deducts36")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=10000;return state


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,state.units[0].skill_index)],[])


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func damage(value: int, kind: String) -> int:
	return Combat.calculate_damage(value,0,0,kind,0,RNG.new(1),"defender")


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
