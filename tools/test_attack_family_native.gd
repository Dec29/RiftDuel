extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 create_timer(45).timeout.connect(func()->void:push_error("Native family pose watchdog");quit(1))
 var db=root.get_node("OperatorDB");var data: Dictionary={}
 for id in db.all_ids():data[id]=db.get_data(id)
 var state:=MatchState.new(17,data)
 var count:=0
 for id in AttackTimeline.IDS+AttackTimeline.ADAPTED_IDS:
  var op: OperatorData=state._operator_data[id]
  var model:=OperatorSpineVisual.new()
  if not model.initialize(id):push_error(model.last_error);quit(1);return
  for skill_index in op.skills.size():
   for active in [false,true]:
    for facing in 4:
     var source:=UnitState.new(0,0,id,Vector2i(11,5),10000,0,0,facing,skill_index)
     source.skill_ticks_left=1000 if active else 0
     var target:=UnitState.new(1,1,"hoshiguma",Vector2i(10,5),100000)
     state.units=[source,target];state.tick=100
     var chosen: Array[UnitState]=[target]
     AttackTimeline.begin(state,source,op,chosen,null,false)
     var intent:=source.attack_intent
     for offset in [0.0,maxf(0.0,float(intent.release_tick-state.tick)-.05),float(intent.release_tick-state.tick)+.75,float(intent.window_ticks)+.1]:
      source.attack_intent=intent if offset<intent.release_tick-state.tick else null
      var before:=state.state_hash()
      if not model.prepare(source,state.tick+offset,intent.interval_ticks):push_error("Native family pose "+id+" skill"+str(skill_index)+" active"+str(active)+" facing"+str(facing)+" "+model.last_error);quit(1);return
      if before!=state.state_hash():push_error("Native family changed simulation "+id);quit(1);return
      count+=1
  model=null
  await process_frame
 print("ATTACK_FAMILY_NATIVE_OK ",count," measured native poses; skills/active/front/back/directions/before-fire/after-fire/idle; read-only fixture, not full gameplay")
 quit(0)
