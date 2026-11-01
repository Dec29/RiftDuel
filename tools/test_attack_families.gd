extends SceneTree
var content: Dictionary={}
var failures:=0
var cases:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
 if not ok:failures+=1;push_error(label)
func fixture(id: String) -> Dictionary:
 var ids:=PackedStringArray([id,"hoshiguma"])
 var state:=MatchState.new(123,content,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids])
 var source:=UnitState.new(0,0,id,Vector2i(11,5),100000,0,0,2,0)
 var healer: bool=state._operator_data[id].damage_type=="healing"
 if healer:source.hp=state._operator_data[id].max_health
 var target:=UnitState.new(1,0 if healer else 1,"hoshiguma",Vector2i(10,5),content.hoshiguma.max_health/2 if healer else 100000,0,99999,0)
 for offset in state._operator_data[id].attack_range:
  if offset!=Vector2i.ZERO:target.cell=source.cell+AttackRange.rotate_offset(offset,source.facing);break
 if id in ["carnelian","lin","mlynar"]:source.skill_ticks_left=1000
 if state._operator_data[id].attack_range.size()==1 and state._operator_data[id].attack_range[0]==Vector2i.ZERO:target.cell=source.cell
 state.units=[source,target];state.next_unit_id=2;state.ball.cell=Vector2i(10,10)
 var owner_id: String={"mon3tr":"kaltsit","ling_soul1":"ling","ling_soul2":"ling","ling_soul3":"ling","vigil_wolf":"vigil","dusk_freeling":"dusk","pozyomka_typewriter":"pozyomka","stainless_cannon":"stainless","magallan_drone_a":"magallan","magallan_drone_l":"magallan","weedy_cannon":"weedy"}.get(id,"")
 if not owner_id.is_empty():
  var owner:=UnitState.new(2,0,owner_id,Vector2i(18,9),100000,0,99999,2)
  state.units.append(owner);state.next_unit_id=3
  if id=="mon3tr":source.mon3tr_owner_id=2
  elif id.begins_with("ling_"):source.ling_owner_id=2
  elif id=="vigil_wolf":source.vigil_owner_id=2;source.vigil_wolf_layers=2
  elif id=="dusk_freeling":source.dusk_owner_id=2;source.dusk_expiry_tick=10000
  elif id=="pozyomka_typewriter":source.typewriter_owner_id=2
  elif id=="stainless_cannon":source.stainless_owner_id=2;source.sp=100
  elif id.begins_with("magallan_drone_"):source.drone_owner_id=2
 return {"state":state,"source":source,"target":target}
func run() -> void:
 create_timer(45).timeout.connect(func()->void:push_error("Attack family watchdog timeout");quit(1))
 var db=root.get_node("OperatorDB")
 for id in db.all_ids():content[id]=db.get_data(id)
 var catalog_state:=MatchState.new(1,content)
 var profiles:=0
 for id in AttackTimeline.ADAPTED_IDS:
  if not OS.get_cmdline_user_args().is_empty() and id not in OS.get_cmdline_user_args():continue
  var op: OperatorData=catalog_state._operator_data[id]
  for skill_index in op.skills.size():
   for facing in 4:
    var actor:=UnitState.new(0,0,id,Vector2i.ZERO,1000,0,0,facing,skill_index)
    var profile:=AttackActionData.profile(actor,true)
    if profile.is_empty():quit(1);return
    check(profile.release_frame>=0 and profile.release_frame<=profile.frames,"Invalid source action "+id)
    profiles+=1
  for scenario in ["release","stun","replacement"]:exercise(id,scenario)
 print("ATTACK_FAMILIES_OK cases=",cases," profiles=",profiles," failures=",failures,"; controlled ordinary/heal/summon fixtures, not full skill regression")
 quit(0 if failures==0 else 1)
func exercise(id: String, scenario: String) -> void:
 var f:=fixture(id);var state: MatchState=f.state;var source: UnitState=f.source;var target: UnitState=f.target
 var intent: AttackIntent
 for tick in 120:
  state.step([],[])
  if source.attack_intent!=null:intent=source.attack_intent;break
 if intent==null:check(false,"No intent "+id);return
 var expected_release:=intent.release_tick
 var hp:=target.hp
 if scenario=="stun":
  StatusRules.add_control(state,source,"stun",1)
  check(source.attack_intent!=null if id in ["stainless_cannon","pozyomka_typewriter"] else source.attack_intent==null,"Control immunity/cancellation mismatch "+id)
 elif scenario=="replacement":
  state.units.erase(target)
  var replacement:=UnitState.new(state.next_unit_id,target.side,"hoshiguma",target.cell,hp,0,99999,0)
  state.next_unit_id+=1;state.units.append(replacement)
 while state.tick<=expected_release:
  state.step([],[])
  if scenario=="release" and id!="perfumer" and state.tick<=expected_release:check(target.hp==hp,"Early damage/heal "+id)
 if scenario=="release":
  check(source.last_attack_tick==expected_release,"Wrong actual release "+id)
  if id in ["liskarm","blue_poison","amiya","skyfire","istina","pramanix"]+AttackTimeline.GENERIC_RANGED_IDS:
   check(not state.attack_projectiles.is_empty(),"Missing independent projectile "+id)
   check(target.hp==hp,"Projectile hit at release "+id)
 elif scenario=="stun":check(source.last_attack_tick==expected_release if id in ["stainless_cannon","pozyomka_typewriter"] else source.last_attack_tick<0,"Control immunity/release mismatch "+id)
 elif intent.kind in [AttackIntent.TargetKind.UNIT,AttackIntent.TargetKind.HEAL]:check(source.last_attack_tick<0,"Retargeted replacement unit "+id)
 elif intent.kind==AttackIntent.TargetKind.CELL:check(Vector2i(source.last_attack_target_x,source.last_attack_target_y)==intent.cell,"Retargeted fixed splash cell "+id)
 cases+=1
