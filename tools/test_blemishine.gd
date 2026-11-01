extends SceneTree

var failures := 0
var data := {}
var op: OperatorData


func _initialize() -> void:
	op=load("res://resources/operators/blemishine.tres");data.blemishine=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	check(op.validation_error().is_empty() and op.max_health==3242 and op.attack==491 and op.defense==581 and op.skills.size()==3,"Original E2 no trust/potential/module and three M3 skills")
	var first := fixture(0);var actor: UnitState=first.units[0];var ally := deploy_ally(first,"target",0,Vector2i(11,5));ally.hp=1000;actor.hp=2000;var primary := enemy(first,Vector2i(13,5));actor.sp=12;actor.attack_ticks_left=1;first.step([],[])
	check(actor.sp==8 and actor.skill_ticks_left==0 and actor.skill_activation_count==1,"S1 actual four-SP charge consumed from stored three charges")
	check(primary.hp==100000-damage(1277,"physical") and ally.hp==1368 and actor.hp==2000,"S1 actual260% physical attack and separate150% heal selects lower HP ratio")
	var stored := fixture(0)
	for tick in 400:stored.step([],[])
	check(stored.units[0].sp==12,"S1 actual natural charge caps at three times4SP")
	var self_heal := fixture(0);actor=self_heal.units[0];actor.hp=1000;primary=enemy(self_heal,Vector2i(13,5));actor.sp=4;actor.attack_ticks_left=1;self_heal.step([],[])
	check(actor.hp==1368,"S1 may actually heal self")
	var mercy := fixture(0);actor=mercy.units[0];actor.hp=1000;primary=enemy(mercy,Vector2i(13,5));StatusRules.add_control(mercy,primary,"sleep",100);actor.sp=4;actor.attack_ticks_left=1;mercy.step([],[])
	check(primary.hp==100000-damage(1788,"physical") and primary.sleep_ticks_left>0 and actor.hp==1368,"S1 sleep mercy140% affects attack, not independent heal; attack does not wake target")
	var hidden := fixture(0);actor=hidden.units[0];primary=enemy(hidden,Vector2i(13,5));primary.sleep_ticks_left=90
	check(not hidden.enemy_is_targetable(0,primary) and hidden.enemy_is_targetable(0,primary,actor),"Only eligible source can target sleeping enemy")
	check(not hidden._apply_damage(primary,dummy,100,"true",primary) and primary.hp==100000,"Other source cannot bypass sleep invulnerability")
	StatusRules.apply_silence(hidden,actor,90)
	check(not hidden.enemy_is_targetable(0,primary,actor) and not hidden._apply_damage(primary,dummy,100,"true",actor),"Source silence removes both targeting and damage exception")
	var priority := fixture(0);actor=priority.units[0];primary=enemy(priority,Vector2i(13,5));var sleeper := enemy(priority,Vector2i(14,5));sleeper.sleep_ticks_left=90
	var offsets: Array[Vector2i]=[Vector2i(1,0),Vector2i(2,0)]
	check(PusherRules.targets(priority,actor,offsets,false)[0]==sleeper,"Pure query with explicit two-cell fixture verifies sleep priority; original attack range remains1-1")
	var mudrock := load("res://resources/operators/mudrock.tres") as OperatorData;data.mudrock=mudrock
	var second := fixture(1);actor=second.units[0];ally=deploy_ally(second,"mudrock",0,Vector2i(14,5));ally.facing=2;ally.hp=1000;actor.hp=1000;actor.sp=12;actor.attack_ticks_left=1;ally.attack_ticks_left=1;primary=enemy(second,Vector2i(13,5));cast(second)
	check(actor.sp==0 and actor.skill_ticks_left==299 and primary.sleep_ticks_left==300 and not second.enemy_is_blocked(primary),"S2 actual12SP,10seconds and unified own-blocking target becomes asleep/unblocked")
	check(primary.hp==100000-damage(1443,"physical") and ally.last_attack_tick<second.tick-1,"S2 attack110% plus mercy; existing Mudrock cannot attack the sleeping target")
	actor.attack_ticks_left=10000;ally.attack_ticks_left=100000
	for tick in 29:second.step([],[])
	check(actor.hp==1103 and ally.hp==1103,"S2 exactly one second of20% attack regeneration at current50% factor, including unhealable Mudrock")
	StatusRules.apply_silence(second,actor,90);var hp := ally.hp
	for tick in 30:second.step([],[])
	check(ally.hp==hp,"Muted skill source stops regeneration aura")
	var third := fixture(2);actor=third.units[0];ally=deploy_ally(third,"target",0,Vector2i(14,5));ally.hp=1000;actor.hp=1000;actor.sp=25;actor.attack_ticks_left=1;primary=enemy(third,Vector2i(13,5));var outside := enemy(third,Vector2i(14,6));cast(third)
	check(actor.sp==0 and actor.skill_ticks_left==899 and SkillRules.attack_value(actor,op)==1031 and SkillRules.defense_value(actor,op)==930,"S3 actual25SP,30seconds,110%ATK and60%DEF")
	check(primary.hp==100000-damage(1031,"physical")-damage(1031,"magical") and ally.hp==1516 and actor.hp==1000,"S3 physical+extra magic, one actual other-ally heal, excludes source")
	check(outside.hp==100000 and AttackRange.effective_offsets(actor,op)==op.attack_range,"Healing x-1 does not wrongly expand basic attack range")
	var alone := fixture(2);actor=alone.units[0];actor.hp=1000;actor.sp=25;actor.attack_ticks_left=1;primary=enemy(alone,Vector2i(13,5));cast(alone);check(actor.hp==1000,"S3 cannot heal self when no other injured ally")
	for id in ["mudrock","liskarm"]:
		data[id]=load("res://resources/operators/"+id+".tres")
		var link := fixture(1);actor=link.units[0];ally=deploy_ally(link,id,1 if id=="mudrock" else 0,Vector2i(15,5));primary=enemy(link,Vector2i(16,5));ally.sp=0;ally.attack_ticks_left=1;link.step([],[])
		check(ally.sp==1 and ally.last_attack_tick==link.tick-1,"Actual ordinary "+id+" attack gains1 defensiveSP from field provider")
		if id=="mudrock":
			ally.sp=data[id].skills[1].sp_required;link.step([],[])
			check(ally.sp==0 and ally.skill_activation_count==1,"Existing hammer skill is not miscounted as another ordinary attack for SP")
		StatusRules.apply_silence(link,actor,90);ally.sp=0;ally.attack_ticks_left=1;link.step([],[])
		check(ally.sp==0,"Muted provider disables defensive attack SP for "+id)
		link._retreat_unit(actor);ally.sp=0;ally.attack_ticks_left=1;link.step([],[]);check(ally.sp==0,"Actual provider retreat removes attack-SP link for "+id)
	var ball := fixture(1);actor=ball.units[0];actor.attack_ticks_left=1;ball.ball.cell=Vector2i(13,5);ball.step([],[])
	check(actor.sp==1 and actor.last_attack_tick==1,"Own ordinary ball attack grants one defensiveSP")
	var box := fixture(2);actor=box.units[0];actor.sp=25;actor.attack_ticks_left=1;box.tactical_boxes=[TacticalBox.new(0,Vector2i(13,5),3)];cast(box)
	check(box.tactical_boxes[0].hits_left==1,"S3 base and extra damage yield two box hits, not a third heal hit")
	for facing in 4:
		var rotated := fixture(2);actor=rotated.units[0];actor.facing=facing;actor.sp=25;actor.attack_ticks_left=1;primary=enemy(rotated,actor.cell+AttackRange.rotate_offset(Vector2i(1,0),facing));cast(rotated)
		check(primary.hp==100000-damage(1031,"physical")-damage(1031,"magical"),"S3 actual original attack range facing%d"%facing)
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:enemy(state,Vector2i(13,5));state.units[0].sp=SkillRules.sp_limit(op.skills[index]);state.units[0].attack_ticks_left=1
		for tick in 1000:
			var commands: Array[InputCommand]=[]
			if tick==0:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Everytick replay S%d tick%d"%[index+1,tick])
	var hashed := fixture(1);var previous := hashed.state_hash();hashed.units[0].blemishine_regen_accum+=1;check(previous!=hashed.state_hash(),"Hash includes passive regeneration remainder")
	print("BLEMISHINE_OK all3 skills, actual deploy/cost/SP, sleeping target exception, both talents, direct Liskarm/Mudrock boundaries,3x1000tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(index: int) -> MatchState:
	var state := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["blemishine"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"blemishine",-1,Vector2i(12,5),-1,0)],[])
	check(state.units.size()==1 and state.units[0].operator_id=="blemishine" and state.sides[0].cost==77,"Controlled99 actual legal ground deployment deducts22")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=10000;return state


func deploy_ally(state: MatchState, id: String, index: int, cell: Vector2i) -> UnitState:
	state.squad_ids[0].append(id);state.squad_skills[0].append(index);var cost := state.sides[0].cost
	state.step([InputCommand.new(state.tick,0,id,-1,cell,-1,0)],[])
	check(state.units.size()==2 and state.units[1].operator_id==id and state.sides[0].cost==cost-data[id].deploy_cost,"Actual legal "+id+" deployment and exact cost")
	state.units[1].attack_ticks_left=100000;return state.units[1]


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,state.units[0].skill_index)],[])


func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit


func damage(value: int, kind: String) -> int:
	return Combat.calculate_damage(value,0,0,kind,0,RNG.new(1),"defender")


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
