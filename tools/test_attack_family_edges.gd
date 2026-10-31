extends "res://tools/test_attack_families.gd"
var edge_cases:=0
func run() -> void:
 create_timer(100).timeout.connect(func()->void:push_error("Attack family edge watchdog");quit(1))
 var db=root.get_node("OperatorDB")
 for id in db.all_ids():content[id]=db.get_data(id)
 var audit:=MatchState.new(1,content)
 var passive:=["curse_doll","jessica_shield","magallan_drone_f","medical_drone","mon3tr_reconstruction","nightingale_phantom","seaborn","silence_alter_drone","skadi_alter","sora","stainless_device_atk","stainless_device_sp","w_mine","phantom"]
 for id in audit._operator_data:
  check(id in AttackTimeline.IDS+AttackTimeline.ADAPTED_IDS+passive,"Unclassified attack entry "+id)
 print("ATTACK_COVERAGE ordinary=",db.all_ids().size()," actors=",AttackTimeline.IDS.size()+AttackTimeline.ADAPTED_IDS.size()," passive=",passive.size())
 var mode:="all" if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()[0]
 if mode in ["all","stages"]:
  for spec in [["chen",1,false],["mountain",2,true],["hellagur",0,false],["hellagur",1,true],["bagpipe",1,false],["bagpipe",2,true],["gnosis",0,false],["texas_alter",1,true],["vigil",2,true],["mlynar",1,true]]:
   stages(spec,false);stages(spec,true)
 if mode in ["all","shots"]:
  for id in ["reed_alter","titi","vigil","chen_alter","silence_alter","stainless_cannon","magallan_drone_l","magallan_drone_a","weedy_cannon","cliffheart","gladiia","pozyomka","gnosis","goldenglow","fiammetta","dusk","thorns","archetto","aak","muelsyse","horn","typhon"]:released(id)
 if mode in ["all","replay"]:replays()
 if mode in ["all","nitrogen"]:nitrogen()
 if mode in ["all","objects"]:objects()
 if mode in ["all","mode_switch"]:mode_switch()
 print("ATTACK_FAMILY_EDGES_OK mode=",mode," cases=",edge_cases," failures=",failures)
 quit(0 if failures==0 else 1)
func stages(spec: Array, cancel: bool) -> void:
 var id: String=spec[0];var f:=fixture(id);var state: MatchState=f.state;var source: UnitState=f.source
 source.skill_index=spec[1];source.skill_ticks_left=1000 if spec[2] else 0
 if not spec[2] and id in ["hellagur","bagpipe","gnosis"]:source.sp=state._operator_data[id].skills[source.skill_index].sp_required
 if id=="chen":source.sp=0
 var op: OperatorData=state._operator_data[id]
 var event_ticks:=PackedInt32Array();var expected:=PackedInt32Array();var start:=-1;var interrupted:=false
 for tick in 180:
  var previous:=source.last_attack_tick
  state.step([],[])
  if start<0 and source.attack_intent!=null:
   start=source.attack_started_tick
   for frame in source.attack_action_event_frames:expected.append(start+ceili(float(frame)*source.attack_action_window_ticks/source.attack_action_source_frames))
   check(expected.size()>1,"Expected authored multi-event "+id+str(spec[1]))
  if source.last_attack_tick!=previous:event_ticks.append(source.last_attack_tick)
  if start>=0 and not event_ticks.is_empty() and cancel and not interrupted:
   StatusRules.add_control(state,source,"stun",2);interrupted=true
  if start>=0 and state.tick>expected[-1]+2:break
 check(event_ticks==PackedInt32Array([expected[0]]) if cancel else event_ticks==expected,"Native stage release mismatch %s S%d cancel%s expected%s actual%s"%[id,spec[1]+1,cancel,expected,event_ticks])
 if cancel:check(source.attack_intent==null and source.skill_ticks_left!=-1,"Interrupted staged skill does not remain pending "+id)
 if id=="chen" and not cancel:check(source.sp==1,"Chen whole double attack grants exactly one SP")
 edge_cases+=1
func released(id: String) -> void:
 var f:=fixture(id);var state: MatchState=f.state;var source: UnitState=f.source;var target: UnitState=f.target
 if id in ["cliffheart","gladiia","thorns"]:target.cell=source.cell+AttackRange.rotate_offset(Vector2i(2,0),source.facing)
 # Keep all assertions about the released hit independent of later newly started attacks.
 var shot: AttackProjectile
 for tick in 180:
  state.step([],[])
  if not state.attack_projectiles.is_empty():shot=state.attack_projectiles[0];break
 check(shot!=null,"Missing ranged release "+id)
 if shot==null:return
 var hp:=target.hp;var attack:=shot.attack;var arrival:=shot.arrival_tick
 check(hp==100000,"Ranged hit before arrival "+id)
 var hash_before:=state.state_hash();shot.defense_ignore_flat+=1;check(state.state_hash()!=hash_before,"Flat penetration participates in hash "+id);shot.defense_ignore_flat-=1
 state._retreat_unit(source)
 while state.tick<=arrival:state.step([],[])
 check(target.hp<hp,"Released hit survives source removal "+id+" snapshot"+str(attack))
 check(target.last_damage_tick==arrival,"Hit settles on actual arrival "+id)
 check(source.last_attack_tick==shot.release_tick,"Impact never overwrites release timestamp "+id)
 edge_cases+=1
func replays() -> void:
 var ticks:=0;var activated:=0
 var empty: Array[InputCommand]=[]
 for id in AttackTimeline.ADAPTED_IDS:
  var count: int=content[id].skills.size() if content.has(id) else 1
  if id not in content:count=fixture(id).state._operator_data[id].skills.size()
  for index in count:
   var a:=fixture(id);var b:=fixture(id)
   for f in [a,b]:
    f.source.skill_index=index;f.source.sp=SkillRules.sp_limit(f.state._operator_data[id].skills[index])
   for tick in 180:
    var ca: Array[InputCommand]=[];var cb: Array[InputCommand]=[]
    if tick in [0,100]:
     ca.append(InputCommand.new(a.state.tick,InputCommand.Kind.SKILL,"",0,Vector2i(-1,-1),index))
     cb.append(InputCommand.new(b.state.tick,InputCommand.Kind.SKILL,"",0,Vector2i(-1,-1),index))
    if tick==60:
     StatusRules.add_control(a.state,a.source,"stun",3);StatusRules.add_control(b.state,b.source,"stun",3)
    a.state.step(ca,empty);b.state.step(cb,empty)
    if a.state.state_hash()!=b.state.state_hash():check(false,"Replay mismatch "+id+"/"+str(index)+"/"+str(tick));return
    ticks+=1
   if a.source.skill_activation_count>0:activated+=1
   edge_cases+=1
 print("FAMILY_REPLAY ticks=",ticks," activated_profiles=",activated,"; controlled skill commands and interruption, not full operator regression")
func nitrogen() -> void:
 for cancel in [false,true]:
  var f:=fixture("weedy");var state: MatchState=f.state;var source: UnitState=f.source;var target: UnitState=f.target
  source.skill_index=2;source.sp=33
  state.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i(-1,-1),2)],[])
  check(source.attack_intent!=null and target.hp==100000,"Nitrogen cast waits for native release")
  if source.attack_intent==null:continue
  var due:=source.attack_intent.release_tick
  if cancel:StatusRules.add_control(state,source,"stun",2)
  while state.tick<=due:state.step([],[])
  if cancel:check(state.attack_projectiles.is_empty() and source.skill_ticks_left==0,"Nitrogen pre-release control cancels")
  else:
   check(not state.attack_projectiles.is_empty() and target.hp==100000,"Nitrogen release starts independent flight")
   if not state.attack_projectiles.is_empty():
    var shot: AttackProjectile=state.attack_projectiles[0]
    state.units.erase(source)
    while state.tick<=shot.arrival_tick:state.step([],[])
    check(target.hp<100000 and target.rupture_until_tick>0,"Nitrogen independent impact retains damage and rupture")
  edge_cases+=1

func objects() -> void:
 for id in ["liskarm","blue_poison","amiya","skyfire","istina","pramanix","reed_alter","titi","vigil","chen_alter","silence_alter","stainless_cannon","magallan_drone_l","magallan_drone_a","weedy_cannon","cliffheart","gladiia","pozyomka","gnosis","goldenglow","fiammetta","dusk","thorns","archetto","aak","muelsyse","horn","typhon","meteorite","w"]:
  for kind in ["box","ball"]:
   var f:=fixture(id);var state: MatchState=f.state;var source: UnitState=f.source;var cell: Vector2i=f.target.cell
   state.units.erase(f.target)
   if id in ["cliffheart","gladiia","thorns"]:cell=source.cell+AttackRange.rotate_offset(Vector2i(2,0),source.facing)
   var box:=TacticalBox.new(42,cell,3)
   if kind=="box":state.tactical_boxes.append(box)
   else:state.ball.cell=cell
   var shot: AttackProjectile
   for tick in 180:
    state.step([],[])
    if not state.attack_projectiles.is_empty():shot=state.attack_projectiles[0];break
   check(shot!=null,"No independent object release "+id+"/"+kind)
   if shot==null:continue
   if kind=="box":
    check(box.hits_left==3,"Crate struck before projectile arrival "+id)
    state.tactical_boxes.clear();state.tactical_boxes.append(TacticalBox.new(43,cell,3))
   else:state.goals[0]+=1
   # Observe this emission only; prevent the next action from entering the fixture.
   source.attack_next_ready_tick=state.tick+9999
   var until:=state.tick+30
   for pending in state.attack_projectiles:until=maxi(until,pending.arrival_tick)
   while state.tick<=until:state.step([],[])
   if kind=="ball":check(state.ball.accum==Vector2i.ZERO and state.ball.move_ticks_left==0,"Old generation ball hit "+id)
   elif shot.kind!=AttackIntent.TargetKind.CELL:check(state.tactical_boxes[0].hits_left==3,"Substituted box hit "+id)
   edge_cases+=1

func mode_switch() -> void:
 var f:=fixture("silence_alter");var state: MatchState=f.state;var source: UnitState=f.source
 source.skill_index=2;source.sp=SkillRules.sp_limit(state._operator_data.silence_alter.skills[2])
 state.step([],[])
 check(source.attack_intent!=null,"Silence starts ranged attack before mode switch")
 state.step([InputCommand.new(state.tick,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,2)],[])
 check(source.attack_intent==null and state.attack_projectiles.is_empty(),"Switch to healing cancels old offensive windup even with no wounded ally")
 edge_cases+=1
