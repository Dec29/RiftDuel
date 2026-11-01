extends SceneTree
var failures := 0
var data := {}
var op: OperatorData

func _initialize() -> void:
 op=load("res://resources/operators/reed_alter.tres");data.reed_alter=op
 var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
 dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
 check(op.validation_error().is_empty() and op.max_health==1583 and op.attack==550 and op.skills.size()==3,"E2 original Reed stats and all three M3 skills")
 var state := fixture(0);var actor := state.units[0];var ally := add_unit(state,0,Vector2i(13,5),1000);var target := add_unit(state,1,Vector2i(13,4),100000);actor.hp=1000;actor.attack_ticks_left=1
 var before := target.hp;state.step([],[])
 check(target.hp<before and ally.hp>1000 and actor.hp>1000,"Real basic magical damage heals lower-HP ally and reflected half to source")
 check(actor.last_attack_tick==state.tick-1 and not actor.last_attack_is_heal,"Basic damage records attack event rather than direct healing action")
 var first := fixture(0);actor=first.units[0];actor.sp=35;cast(first)
 check(actor.sp==0 and actor.skill_ticks_left==1049 and SkillRules.attack_value(actor,op)==798 and SkillRules.attack_interval_ticks(actor,op)==33,"S1 actual35SP,35seconds,45%ATK/45AS")
 var immune := fixture(0);actor=immune.units[0];target=add_unit(immune,1,Vector2i(13,4),100000);target.nian_shield_layers=1;ally=add_unit(immune,0,Vector2i(13,5),1000);actor.attack_ticks_left=1;immune.step([],[])
 check(target.hp==100000 and ally.hp==1000 and target.reed_cinder_source_id==-1,"A complete layer shield produces neither damage healing nor cinder")
 var weak := fixture(0);actor=weak.units[0];target=add_unit(weak,1,Vector2i(13,4),100000);MedicAlterRules.mark(weak,actor,target,true)
 check(SkillRules.attack_value(target,dummy)==roundi(dummy.attack*0.8) and weak._magical_damage_taken_percent(target)==130,"Cinder debuffs20%ATK and30%magic vulnerability")
 var remaining := target.reed_cinder_until_tick-weak.tick
 actor.attack_ticks_left=100000
 for tick in remaining+1:weak.step([],[])
 check(target.reed_cinder_source_id==-1 and SkillRules.attack_value(target,dummy)==dummy.attack,"Normal cinder expires after6seconds")
 var second := fixture(1);actor=second.units[0];ally=add_unit(second,0,Vector2i(13,5),1000);var later := add_unit(second,0,Vector2i(12,5),1000);var high := add_unit(second,0,Vector2i(12,2),1000);target=add_unit(second,1,Vector2i(13,6),100000);actor.sp=27;cast(second)
 check(actor.reed_fireball_carriers==PackedInt32Array([later.unit_id,ally.unit_id]) and actor.reed_fireball_ready_ticks.size()==6,"S2 two ground carriers selected by latest deployment, each independent3balls")
 before=target.hp
 for tick in 90:second.step([],[])
 check(target.hp<before and ally.hp>1000,"Actual orbit collision causes240% magic and heals only its carrier")
 check(high.hp==1000,"Fireball healing does not leak to unrelated high-ground ally")
 var marked := false
 for ready in actor.reed_fireball_ready_ticks:marked=marked or ready>second.tick
 check(marked,"Individual balls retain45tick cooldown")
 second._retreat_unit(actor);second.step([],[])
 for enemy in second.units:check(enemy.reed_cinder_source_id==-1,"Owner exit removes its cinder")
 var third := fixture(2);actor=third.units[0];var a := add_unit(third,1,Vector2i(13,4),100000);var b := add_unit(third,1,Vector2i(12,4),100000);var c := add_unit(third,1,Vector2i(12,5),100000);actor.sp=40;actor.attack_ticks_left=1;cast(third)
 check(actor.sp==0 and actor.skill_ticks_left==899 and a.reed_lifeseed_mark and b.reed_lifeseed_mark and not c.reed_lifeseed_mark,"S3 actual40SP,30sec, attacks exactly2 and guaranteed skill cinder")
 before=a.hp;actor.attack_ticks_left=100000
 for tick in 30:third.step([],[])
 check(a.hp<before and a.reed_dot_next_tick>third.tick-1,"S3 independent60% DOT occurs after one second")
 third._apply_damage(a,dummy,100000,"true",actor,false)
 check(a.hp<=0 and third.reed_blasts.size()==1,"A lethal hit to skill cinder queues a delayed corpse blast")
 before=c.hp
 for tick in 4:third.step([],[])
 check(b.hp<100000 and c.hp<before and c.reed_lifeseed_mark,"Delayed140% explosion at1.7 radius spreads skill cinder")
 actor.skill_ticks_left=1;third.step([],[]);third.step([],[])
 check(not b.reed_lifeseed_mark and not c.reed_lifeseed_mark,"S3 end removes only its enhanced cinder")
 var oldmark := fixture(2);actor=oldmark.units[0];target=add_unit(oldmark,1,Vector2i(13,4),100000);MedicAlterRules.mark(oldmark,actor,target,true);actor.sp=40;cast(oldmark)
 check(not target.reed_lifeseed_mark,"Pre-skill cinder is not retroactively upgraded into S3DOT")
 for index in 3:
  var x := fixture(index);var y := fixture(index)
  for item in [x,y]:add_unit(item,0,Vector2i(13,5),1000);add_unit(item,1,Vector2i(13,4),100000);item.units[0].sp=op.skills[index].sp_required;item.units[0].attack_ticks_left=1
  for tick in 1000:
   var commands: Array[InputCommand]=[]
   if tick==0:commands.append(InputCommand.new(x.tick,1,"",x.units[0].unit_id,Vector2i.ZERO,index))
   x.step(commands,[]);y.step(commands,[])
   if x.state_hash()!=y.state_hash():check(false,"Same seed/input replay differs S%d tick%d"%[index+1,tick]);break
 var hashed := fixture(1);var h := hashed.state_hash();hashed.units[0].reed_fireball_ready_ticks.append(30);check(hashed.state_hash()!=h,"Independent fireball timers participate in hash")
 print("REED_ALTER_OK all3 skills, original talents, actual damage/healing, cinder expiration, carriers, delayed corpse spread,3x1000tick replay; failures=",failures)
 quit(0 if failures==0 else 1)

func fixture(index: int) -> MatchState:
 var state := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["reed_alter"],["target"]],[[index],[0]])
 state.sides[0].cost=99;state.step([InputCommand.new(0,0,"reed_alter",-1,Vector2i(14,4),-1,2)],[])
 check(state.units.size()==1 and state.sides[0].cost==82,"Controlled99 actual legal high deployment costs17")
 state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=100000;return state

func add_unit(state: MatchState, side: int, cell: Vector2i, hp: int) -> UnitState:
 var unit := UnitState.new(state.next_unit_id,side,"target",cell,hp,0,100000)
 state.units.append(unit);state.next_unit_id+=1;return unit

func cast(state: MatchState) -> void:
 state.step([InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,state.units[0].skill_index)],[])

func check(ok: bool, message: String) -> void:
 if not ok:failures+=1;push_error(message)
