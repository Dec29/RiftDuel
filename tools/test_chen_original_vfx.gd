extends SceneTree
const OUT="res://.ai/chen-s3-20261025/gameplay/"
var data: Dictionary={}
var state: MatchState
var view: MatchView
var failed:=false
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> bool:
 if not ok:failed=true;push_error(label)
 return ok
func make_battle() -> void:
 var ids:=PackedStringArray(["chen","specter"]);var skills:=PackedInt32Array([2,1])
 state=MatchState.new(0x4348454e,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
 state.sides[0].cost=99;state.sides[1].cost=99
 var blue: Array[InputCommand]=[InputCommand.new(0,0,"chen",-1,Vector2i(11,5),-1,2)]
 var red: Array[InputCommand]=[InputCommand.new(0,0,"specter",-1,Vector2i(9,5),-1,0)]
 state.step(blue,red)
 check(state.units.size()==2,"Actual deployments")
 for u in state.units:u.sp=data[u.operator_id].skills[u.skill_index].sp_required
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
func cast() -> void:
 var blue: Array[InputCommand]=[InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,2)]
 var red: Array[InputCommand]=[InputCommand.new(state.tick,1,"",state.units[1].unit_id,Vector2i.ZERO,1)]
 state.step(blue,red);view.original_vfx.observe(view)
func run() -> void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
 make_battle();await view.original_vfx.prepare(view)
 check(view.original_vfx.clips.size()==13,"Only carried native family loads, not previous three operators")
 cast()
 var actual: Array[int]=[];var previous:=-1;var peak:=0;var frozen_checked:=false
 for i in 135:
  var before:=state.state_hash();view.original_vfx.observe(view);view._bone_tick=state.tick;view.original_vfx.sample(view)
  check(state.state_hash()==before,"Read-only observe/sample")
  var emitted:=view.original_vfx.emitted_events;view.original_vfx.observe(view);check(view.original_vfx.emitted_events==emitted,"No replay on repeated observe")
  if state.units[0].chen_slash_tick>previous:actual.append(state.units[0].chen_slash_tick);previous=state.units[0].chen_slash_tick
  peak=maxi(peak,view.original_vfx.visible_events)
  view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
  if "capture" in OS.get_cmdline_user_args() or i in [0,3,9,20,35,50,54,60,75,105]:root.get_texture().get_image().save_png(OUT+"frame-%03d.png"%i)
  if i==20:
   var with_vfx:=root.get_texture().get_image();var visible:=view.original_vfx.visible_events;view.original_vfx.visible_events=0;view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
   var plain:=root.get_texture().get_image();with_vfx.save_png(OUT+"clarity-with.png");plain.save_png(OUT+"clarity-without.png")
   for u in state.units:
    var rect:=Rect2i(view.renderer.unit_health_rect(view,u)).grow(-1);check(with_vfx.get_region(rect).get_data()==plain.get_region(rect).get_data(),"Health overlay stays above VFX")
   view.original_vfx.visible_events=visible
   var clock:=view.original_vfx.visual_tick;view.simulation_waiting=true
   for wait in 3:view.original_vfx.sample(view);await process_frame
   check(view.original_vfx.visual_tick==clock,"Network wait freezes VFX")
   paused=true;await create_timer(.1,true).timeout;check(view.original_vfx.visual_tick==clock,"Pause freezes VFX");paused=false;view.simulation_waiting=false;frozen_checked=true
  state.step([],[])
 check(actual.size()==10,"Ten actual slash markers")
 for n in 10:check(view.original_vfx.emission_counts.get("chen:hit_%02d"%(n+1),0)==1,"One original resource per actual slash %d"%(n+1))
 check(state.units[0].cell==Vector2i(11,5),"Caster remains at actual origin; no VFX teleport")
 check(view.original_vfx.visible_events==0,"Natural expiry without stale VFX")
 var full_counts: Dictionary=view.original_vfx.emission_counts.duplicate()
 view.queue_free();await process_frame
 make_battle();await view.original_vfx.prepare(view);cast();state._retreat_unit(state.units[1]);
 for i in 12:state.step([],[]);view.original_vfx.observe(view)
 check(view.original_vfx.emission_counts.get("chen:hit_01",0)==1 and not view.original_vfx.emission_counts.has("chen:hit_10"),"Target removal never fabricates final slash")
 # Mirroring samples the same confirmed target facts and does not write state.
 for facing in 4:
  for mirrored in [false,true]:
   state.units[0].facing=facing;view.mirror_board=mirrored
   var before:=state.state_hash();view._bone_tick=state.tick;view.original_vfx.sample(view);view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw;check(state.state_hash()==before,"Facing and mirror read-only")
 var report: Dictionary={"passed":not failed,"actual_slash_ticks":actual,"counts":full_counts,"peak_visible":peak,"pause_wait":frozen_checked,"target_loss_no_fake_finisher":true,"controlled_initial_cost_sp":true,"target_survival":"Actual Specter S2, no artificial HP or damage changes","note":"135-tick controlled real MatchState/MatchView, not full-match/network/physical input acceptance"}
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 view.queue_free();await process_frame
 print("CHEN_NATIVE_MATCH_OK ",JSON.stringify(report));quit(1 if failed else 0)
