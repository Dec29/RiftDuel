extends SceneTree
var failures := 0
var data := {}
var op: OperatorData

func _initialize() -> void:
 op=load("res://resources/operators/eyjafjalla_alter.tres");data.eyjafjalla_alter=op
 var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
 dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
 check(op.validation_error().is_empty() and op.max_health==1439 and op.attack==424 and op.skills.size()==3,"Original E2 no trust/potential/module stats and all3 M3 skills")
 check(op.branch_trait.effect_params["elemental_heal_percent"]==50 and op.talent_2.effect_params["elemental_resistance_percent"]==12,"Elemental numeric facts preserved without inventing HP recovery/shields")
 var basic := fixture(0);var actor := basic.units[0];var ally := add_unit(basic,Vector2i(13,5),1000);AuraRules.refresh(basic)
 check(SkillRules.max_health_value(ally,dummy)==106000 and SkillRules.max_health_value(actor,op)==1525,"Normal aura6%maxHP includes self and allies in original3-17 range")
 actor.attack_ticks_left=1;basic.step([],[])
 check(ally.hp==1272 and ally.eyja_mist_stacks==1 and ally.eyja_mist_heal==21,"Actual basic heal424 at50% plus6%HP-ratio adaptation, one cached10% mist stack")
 actor.attack_ticks_left=100000;var before := ally.hp
 for tick in 30:basic.step([],[])
 check(ally.hp==before+21,"Exactly one second triggers one10% cached normal-heal pulse; shared50% applied once")
 for index in 4:
  actor.attack_ticks_left=1;basic.step([],[])
 check(ally.eyja_mist_stacks==3 and ally.eyja_mist_until_tick==basic.tick-1+180,"Normal heals cap3stacks and refresh full6sec duration/cache")
 before=ally.hp;actor.attack_ticks_left=100000
 for tick in 180:basic.step([],[])
 check(ally.hp==before+6*63,"All3 cached mist stacks pulse6times over refreshed duration")
 basic.step([],[]);check(ally.eyja_mist_stacks==0,"Mist expires after last6second pulse")
 var first := fixture(0);actor=first.units[0];ally=add_unit(first,Vector2i(13,5),1000);var other := add_unit(first,Vector2i(12,5),1000);actor.sp=60;actor.attack_ticks_left=1;first.step([],[])
 check(actor.skill_ticks_left==-2 and actor.sp==0 and SkillRules.attack_value(actor,op)==594,"S1 auto60SP permanent40%ATK")
 check(ally.hp>1000 and other.hp>1000 and ally.eyja_mist_stacks==1 and other.eyja_mist_stacks==1,"S1 ordinary attack treats exactly2 distinct injured allies and applies mist to both")
 StatusRules.apply_silence(first,actor,90);check(SkillRules.attack_value(actor,op)==424 and SkillRules.max_health_value(ally,dummy)==100000,"Source silence pauses permanent skill and aura")
 var second := fixture(1);actor=second.units[0];ally=add_unit(second,Vector2i(13,5),1000);other=add_unit(second,Vector2i(12,5),2000);actor.sp=20;cast(second)
 check(actor.sp==0 and actor.skill_ticks_left==0 and ally.hp==1272 and other.hp==2332,"S2 instant20SP AoE normal HP heal with ratio-scaled aura to all eligible allies")
 check(actor.eyja_elemental_barrier==3816 and actor.eyja_elemental_barrier_until_tick==second.tick-1+600,"S2 independent20second elemental barrier snapshot is900%ATK")
 check(ally.barrier_hp.is_empty() and actor.barrier_hp.is_empty() and ally.eyja_mist_stacks==0,"S2 elemental barrier never becomes HP shield, active cast does not falsely count as ordinary treatment")
 var hp := ally.hp;second._apply_damage(ally,dummy,100,"true",actor,false)
 check(ally.hp==hp-100 and actor.eyja_elemental_barrier==3816,"Physical/magic/true HP damage never consumes elemental-only barrier")
 actor.attack_ticks_left=100000
 for tick in 600:second.step([],[])
 check(actor.eyja_elemental_barrier==0 and actor.eyja_elemental_barrier_until_tick==0,"Inert elemental barrier still expires after20seconds")
 var third := fixture(2);actor=third.units[0];ally=add_unit(third,Vector2i(2,1),1000);other=add_unit(third,Vector2i(18,9),1000);var near := add_unit(third,Vector2i(13,5),2000);var extra := add_unit(third,Vector2i(4,1),1000);var fifth := add_unit(third,Vector2i(5,1),1000);var sixth := add_unit(third,Vector2i(6,1),1000);actor.sp=60;actor.attack_ticks_left=1;cast(third)
 check(actor.skill_ticks_left==1499 and actor.sp==0,"S3 actual60SP/50seconds")
 check(SkillRules.max_health_value(ally,dummy)==130000 and SkillRules.max_health_value(sixth,dummy)==130000,"S3 second talent5x30%HP applies to whole battlefield, including beyond original attack range")
 check(ally.eyja_mist_stacks==1 and other.eyja_mist_stacks==1 and extra.eyja_mist_stacks==1 and fifth.eyja_mist_stacks==1 and sixth.eyja_mist_stacks==1 and near.eyja_mist_stacks==0,"S3 five60% healing packets prioritize different allies, then lowestHP ratio, with old deployment tie-break")
 check(ally.hp==1427 and other.hp==1427 and sixth.hp==1427,"S3 each60%heal is127 after shared50%, alongside30%HP-ratio aura")
 check(third._is_in_attack_range(actor,ally.cell,AttackRange.effective_offsets(actor,op)),"Shared view/query exposes actual whole-map S3 range")
 actor.skill_ticks_left=1;actor.attack_ticks_left=100000;third.step([],[]);third.step([],[])
 check(SkillRules.max_health_value(ally,dummy)==100000 and SkillRules.max_health_value(near,dummy)==106000,"S3 end restores only original range6%HP aura")
 var single := fixture(2);actor=single.units[0];ally=add_unit(single,Vector2i(2,1),1000);actor.sp=60;actor.attack_ticks_left=1;cast(single)
 check(ally.eyja_mist_stacks==3 and ally.hp==1935,"S3 may heal same wounded ally5times when no different candidate remains")
 var unhealable := fixture(2);var mudrock := load("res://resources/operators/mudrock.tres") as OperatorData;unhealable._operator_data.mudrock=mudrock;var mud := UnitState.new(unhealable.next_unit_id,0,"mudrock",Vector2i(2,1),1000,0,100000);unhealable.units.append(mud);unhealable.next_unit_id+=1;actor=unhealable.units[0];actor.sp=60;cast(unhealable)
 check(mud.hp==1300 and mud.eyja_mist_stacks==0,"Musha/unyield external direct-heal prohibition remains; HP aura still applies proportionally")
 for index in 3:
  var a := fixture(index);var b := fixture(index)
  for state in [a,b]:add_unit(state,Vector2i(13,5),1000);add_unit(state,Vector2i(2,1),1000);state.units[0].sp=op.skills[index].sp_required;state.units[0].attack_ticks_left=1
  for tick in 1700:
   var commands: Array[InputCommand]=[]
   if tick==0 and index>0:commands.append(InputCommand.new(a.tick,1,"",a.units[0].unit_id,Vector2i.ZERO,index))
   a.step(commands,[]);b.step(commands,[])
   if a.state_hash()!=b.state_hash():check(false,"Same-seed/input replay differs S%d tick%d"%[index+1,tick]);break
 var hashed := fixture(2);var hash_before := hashed.state_hash();hashed.units[0].eyja_mist_heal+=1;check(hashed.state_hash()!=hash_before,"Mist cache participates in state hash")
 print("EYJA_ALTER_OK all3skills, cached3stack mist,HP aura and silence/expiry,elemental-only20sec barrier,global5packet heal,3x1700tick replay; failures=",failures)
 quit(0 if failures==0 else 1)

func fixture(index: int) -> MatchState:
 var state := MatchState.new(811,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["eyjafjalla_alter"],["target"]],[[index],[0]])
 state.sides[0].cost=99;state.step([InputCommand.new(0,0,"eyjafjalla_alter",-1,Vector2i(14,4),-1,2)],[])
 check(state.units.size()==1 and state.sides[0].cost==83,"Controlled99 actual legal high deployment deducts16")
 state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=100000;return state

func add_unit(state: MatchState, cell: Vector2i, hp: int) -> UnitState:
 var unit := UnitState.new(state.next_unit_id,0,"target",cell,hp,0,100000)
 state.units.append(unit);state.next_unit_id+=1;AuraRules.refresh(state);return unit

func cast(state: MatchState) -> void:
 state.step([InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,state.units[0].skill_index)],[])

func check(ok: bool, message: String) -> void:
 if not ok:failures+=1;push_error(message)
