extends SceneTree
# Focused 24-actor fixture, not an AI/network/balance test. No source resources mutated.
const OriginalVfxPlayerClass=preload("res://view/original_vfx_player.gd")
var OUT="res://.ai/vfx-release-20261027/nine-family/"
var OPS=["weedy","silverash","mlynar","eyjafjalla","chen","ifrit","chen_alter","surtr","fiammetta","hoshiguma","nian","skadi"]
var CELLS=[Vector2i(11,3),Vector2i(11,5),Vector2i(11,7),Vector2i(12,2),Vector2i(11,4),Vector2i(13,8),Vector2i(12,8),Vector2i(11,6),Vector2i(13,2),Vector2i(11,2),Vector2i(11,8),Vector2i(12,5)]
var state: MatchState
var view: MatchView
var data: Dictionary={}
var failed:=false
var hash_checks:=0
var peak_events:=0
var peak_layers:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failed=true;push_error(label)
func setup(enabled: bool=true) -> void:
 peak_events=0;peak_layers=0
 var ids:=PackedStringArray(OPS);var skills:=PackedInt32Array([2,2,2,2]) if OPS.size()==4 else PackedInt32Array([2,2,2,2,2,2,2,2,2,0,0,0])
 state=MatchState.new(0x43524f57,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
 for i in OPS.size():
  state.sides[0].cost=99;state.sides[1].cost=99
  var cell: Vector2i=CELLS[i];var red:=Vector2i(20-cell.x,cell.y)
  if (OPS.size()==12 and i==3) or (OPS.size()==4 and i==0):red=Vector2i(8,2)
  check(state.can_deploy(0,OPS[i],cell) and state.can_deploy(1,OPS[i],red),"Legal paired deployment "+OPS[i])
  var a: Array[InputCommand]=[InputCommand.new(state.tick,0,OPS[i],-1,cell,-1,2)]
  var b: Array[InputCommand]=[InputCommand.new(state.tick,0,OPS[i],-1,red,-1,0)]
  state.step(a,b)
 check(state.units.size()==OPS.size()*2,"All paired real deployment commands accepted")
 for i in 40:state.step([],[])
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
 if not enabled:view.original_vfx.viewport.queue_free();view.original_vfx=BattleOriginalVfx.new()
 cast()
func cast() -> void:
 var commands: Array=[[],[]]
 for unit in state.units:
  if unit.operator_id in OPS.slice(0,9):
   unit.sp=data[unit.operator_id].skills[2].sp_required
   commands[unit.side].append(InputCommand.new(state.tick,1,"",unit.unit_id,Vector2i.ZERO,2))
 var blue: Array[InputCommand]=[];blue.assign(commands[0]);var red: Array[InputCommand]=[];red.assign(commands[1]);state.step(blue,red)
func sample(hash_check: bool=false) -> void:
 var before: Variant=state.state_hash() if hash_check else null
 view.original_vfx.sample(view)
 if hash_check:check(before==state.state_hash(),"Crowded VFX and bone queries read-only");hash_checks+=1
 peak_events=maxi(peak_events,view.original_vfx.visible_events)
 var layers:=0
 for player in view.original_vfx.pool:
  for layer in player._layers:
   if player.instance.visible and layer.visible:layers+=1
 peak_layers=maxi(peak_layers,layers)
func capture(label: String) -> void:
 if DisplayServer.get_name()=="headless":return
 view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+label+".png")
func cleanup() -> void:
 view.queue_free();await process_frame
func run() -> void:
 if "standard" in OS.get_cmdline_user_args():
  OPS=["chen_alter","surtr","fiammetta","mlynar"];CELLS=[Vector2i(12,2),Vector2i(11,5),Vector2i(13,8),Vector2i(11,7)]
  OUT="res://.ai/vfx-release-20261027/eight-family-performance/"
 root.size=Vector2i(1280,720);root.content_scale_size=root.size
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
 for id in OPS:
  var copy: OperatorData=data[id].duplicate(true);copy.max_health=10000000;copy.attack=1;data[id]=copy
 if "performance" in OS.get_cmdline_user_args():await performance();return
 setup();view._bone_tick=state.tick;sample(true)
 for i in 1200:
  state.step([],[]);view._bone_tick=state.tick;sample(true)
  if i in [0,10,25,40,65,95,150,300,600,1000,1199]:await capture("tick-%04d"%i)
  if i==65:
   var clock:=view.original_vfx.visual_tick;var emissions:=view.original_vfx.emitted_events
   view.simulation_waiting=true
   for j in 6:sample(true);await capture("waiting-%d"%j)
   check(clock==view.original_vfx.visual_tick and emissions==view.original_vfx.emitted_events,"Crowded network wait freezes and does not replay")
   view.simulation_waiting=false
   paused=true
   for j in 4:sample(true)
   paused=false;check(clock==view.original_vfx.visual_tick,"Crowded pause freezes clock")
   for mirror in [true,false]:view.mirror_board=mirror;sample(true);await capture("mirror-%d"%int(mirror))
 check(state.result==MatchState.RESULT_RUNNING,"Fixture remains running until effects naturally expire")
 for op in OPS.slice(0,9):
  check(view.original_vfx.emission_counts.keys().any(func(k):return k.begins_with(op+":")),"Actual source events observed for "+op)
 check(view.original_vfx.emission_counts.get("eyjafjalla:flight",0)>0,"Volcano actually releases projectiles with a legal reachable target")
 check(view.original_vfx.events.any(func(e):return e.key.begins_with("fiammetta:") or e.key.begins_with("chen_alter:")),"Infinite/ammo skills retain only actual active source effects")
 var emissions: Dictionary=view.original_vfx.emission_counts.duplicate()
 state.step([],[]);view._bone_tick=state.tick;sample(true);await capture("before-retreat")
 var commands: Array=[[],[]]
 for unit in state.units:commands[unit.side].append(InputCommand.new(state.tick,2,"",unit.unit_id))
 var blue: Array[InputCommand]=[];blue.assign(commands[0]);var red: Array[InputCommand]=[];red.assign(commands[1]);state.step(blue,red)
 view._bone_tick=state.tick;sample(true)
 var remaining_seconds:=0.0
 for event in view.original_vfx.events:
  var clip: Resource=view.original_vfx.clips[event.key]
  if clip.loop_from_seconds<0:remaining_seconds=maxf(remaining_seconds,clip.duration_seconds/event.speed-(view.original_vfx.visual_tick-event.tick)/Config.TICK_RATE)
 var tail_ticks:=int(ceil(remaining_seconds*Config.TICK_RATE))+2
 for i in tail_ticks:state.step([],[]);view._bone_tick=state.tick;sample(true)
 await capture("retreated")
 check(state.units.is_empty(),"All 24 real retreat commands accepted")
 check(view.original_vfx.events.is_empty() and view.original_vfx.visible_events==0,"No retained visible effects after retreat and released tails")
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"hash_checks":hash_checks,"peak_events":peak_events,"peak_layers":peak_layers,"tail_ticks":tail_ticks,"emissions":emissions,"scope":"24 real deployed actors, nine source families, QA durability/attack/SP; combined nine-family integration, not an AI/network test"},"\t"))
 await cleanup();print("CROWDED_VFX ",not failed," peak=",peak_events," layers=",peak_layers);quit(1 if failed else 0)
func performance() -> void:
 var results: Array=[]
 for enabled in [true,false]:
  setup(enabled)
  if enabled:await view.original_vfx.prepare(view)
  var frames: Array[float]=[];var submit: Array[float]=[];var sim: Array[float]=[];var accumulator:=0.0
  var start:=Time.get_ticks_msec()
  while Time.get_ticks_msec()-start<14000:
   var delta:=root.get_process_delta_time();accumulator+=delta*22.5
   var begin:=Time.get_ticks_usec()
   while accumulator>=1.0:state.step([],[]);accumulator-=1.0
   var sim_us:=Time.get_ticks_usec()-begin;var render_start:=Time.get_ticks_usec()
   view._bone_tick=state.tick+accumulator;view.original_vfx.observe(view);view.queue_redraw()
   await process_frame;await RenderingServer.frame_post_draw
   peak_events=maxi(peak_events,view.original_vfx.visible_events)
   var visible_layers:=0
   for player in view.original_vfx.pool:
    for layer in player._layers:
     if player.instance.visible and layer.visible:visible_layers+=1
   peak_layers=maxi(peak_layers,visible_layers)
   if Time.get_ticks_msec()-start>=2000:frames.append(delta*1000.0);submit.append(view.original_vfx.last_sample_usec/1000.0);sim.append(sim_us/1000.0)
  frames.sort();submit.sort();sim.sort()
  results.append({"enabled":enabled,"fps":frames.size()/12.0,"frame_p95_ms":frames[int(frames.size()*.95)],"submit_p95_ms":submit[int(submit.size()*.95)],"sim_p95_ms":sim[int(sim.size()*.95)],"live_actors":state.units.size(),"peak_events":peak_events,"peak_layers":peak_layers,"buffer_creations":OriginalVfxPlayerClass.buffer_creations,"buffer_reuses":OriginalVfxPlayerClass.buffer_reuses})
  if "standard" in OS.get_cmdline_user_args():check(frames.size()/12.0>=45 and frames[int(frames.size()*.95)]<50,"Standard eight-actor device threshold 45 FPS / P95 <50ms")
  await cleanup()
 FileAccess.open(OUT+"performance.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":results,"scope":"4+4 actors / four new families with 45 FPS gate when standard; otherwise 12+12 / nine families, extreme-load measurement only. Initial SP, QA maxHP and attack; 2s warm +12s measured per case. No AI/network or isolated GPU claim."},"\t"));print("CROWDED_PERFORMANCE ",JSON.stringify(results));quit(1 if failed else 0)
