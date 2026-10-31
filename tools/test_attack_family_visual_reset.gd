extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var db=root.get_node("OperatorDB");var content: Dictionary={}
 for id in db.all_ids():content[id]=db.get_data(id)
 var state:=MatchState.new(2,content);var failures:=0;var cases:=0
 for id in AttackTimeline.ADAPTED_IDS:
  if not OS.get_cmdline_user_args().is_empty() and id not in OS.get_cmdline_user_args():continue
  var op: OperatorData=state._operator_data[id]
  for index in op.skills.size():
   for facing in [0,3]:
    var unit:=UnitState.new(0,0,id,Vector2i.ZERO,10000,0,0,facing,index);unit.deployed_tick=-300
    var target:=UnitState.new(1,1,"hoshiguma",Vector2i(1,0),100000)
    unit.skill_ticks_left=1000;unit.skill_activation_count=1
    var chosen: Array[UnitState]=[target]
    state.tick=100;state.units=[unit,target];AttackTimeline.begin(state,unit,op,chosen,null,false)
    var interval:=unit.attack_intent.interval_ticks
    if 100.0+unit.attack_action_window_ticks*.5>=unit.attack_intent.release_tick:unit.last_attack_tick=unit.attack_intent.release_tick;unit.attack_intent=null
    var model:=OperatorSpineVisual.new()
    var initialized:=model.initialize(id)
    var prepared:=false
    if initialized:prepared=model.prepare(unit,100.0+unit.attack_action_window_ticks*.5,interval)
    if not prepared:print("INIT_DETAIL initialized",initialized," clip",model.clip," window",unit.attack_action_window_ticks," raw",unit.attack_action_clip," side",unit.attack_action_view_index);push_error("Reset test native init %s S%d facing%d: %s"%[id,index+1,facing,model.last_error]);quit(1);return
    unit.attack_intent=null;unit.skill_ticks_left=0;model.prepare(unit,400,60)
    var fresh:=OperatorSpineVisual.new();fresh.initialize(id)
    if not model.prepare(unit,700,60) or not fresh.prepare(unit,700,60):push_error("Reset test idle "+id);quit(1);return
    var equal:=model.mesh.get_surface_count()==fresh.mesh.get_surface_count()
    var pixel_delta:=0.0
    if equal and model.mesh.get_surface_count()>0:
     var a:=model.mesh.surface_get_arrays(0);var b:=fresh.mesh.surface_get_arrays(0)
     equal=a[0].size()==b[0].size() and a[3]==b[3] and a[4]==b[4] and a[12]==b[12]
     if equal:
      for k in a[0].size():pixel_delta=maxf(pixel_delta,a[0][k].distance_to(b[0][k])*model.scale_for_row(72))
    # Native float32 transform history can differ by a few ULPs. Attachment topology,
    # colors and UVs remain exact; projected geometry must stay below 0.01 screen pixel.
    if not equal or pixel_delta>=.01:failures+=1;push_error("Native attachment/pose residue %s S%d facing%d pixel_delta%.8f"%[id,index+1,facing,pixel_delta])
    cases+=1
  await process_frame
 print("ATTACK_FAMILY_VISUAL_RESET cases=",cases," failures=",failures)
 quit(0 if failures==0 else 1)
