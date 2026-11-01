extends SceneTree
const OUT="res://.ai/vfx-battle-20261023/"
var view: MatchView
var state: MatchState
var data: Dictionary={}
var failure:=false
var captures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> bool:
 if not ok:failure=true;push_error(label);quit(1)
 return ok
func run() -> void:
 root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
 var ids:=PackedStringArray(["weedy","silverash","eyjafjalla","hoshiguma"])
 var skills:=PackedInt32Array([2,2,2,0])
 state=MatchState.new(0x564658,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
 state.sides[0].cost=99;state.sides[1].cost=99
 var cells: Array[Vector2i]=[Vector2i(11,5),Vector2i(11,9),Vector2i(12,2),Vector2i(11,2)]
 var blue: Array[InputCommand]=[];var red: Array[InputCommand]=[]
 for i in 4:
  blue.append(InputCommand.new(0,0,ids[i],-1,cells[i],2,2))
  red.append(InputCommand.new(0,0,ids[i],-1,Vector2i(8 if i==2 else 9,cells[i].y),2,0))
 state.step(blue,red)
 print("DEPLOYED ",state.units.map(func(u):return [u.operator_id,u.side,u.cell]))
 if not check(state.units.size()==8,"Eight actual accepted deployment commands"):return
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
 await view.original_vfx.prepare(view)
 # Controlled SP only in QA, not in production. Damage, push, targets and cooldown remain actual rules.
 for unit in state.units:unit.sp=data[unit.operator_id].skills[unit.skill_index].sp_required
 blue.clear();red.clear()
 for unit in state.units:
  var c:=InputCommand.new(state.tick,1,"",unit.unit_id,Vector2i.ZERO,unit.skill_index)
  if unit.side==0:blue.append(c)
  else:red.append(c)
 state.step(blue,red)
 print("CAST_STATE ",state.units.map(func(u):return [u.operator_id,u.skill_activation_count,u.skill_ticks_left,u.attack_ticks_left]))
 var hash_before:=state.state_hash();view.original_vfx.observe(view)
 if not check(state.state_hash()==hash_before,"Observation is read-only"):return
 # Real windups precede native emissions; do not require cast and release in one tick.
 var emission_deadline:=state.tick+90
 while view.original_vfx.emitted_events<10 and state.tick<emission_deadline:
  state.step([],[])
  hash_before=state.state_hash();view.original_vfx.observe(view)
  if not check(state.state_hash()==hash_before,"Waiting for release observation is read-only"):return
 if not check(view.original_vfx.emitted_events>=10,"Actual skill activations produce native clips"):return
 view._bone_tick=float(state.tick);view.original_vfx.sample(view)
 var visible_index:=0
 for e: Dictionary in view.original_vfx.events:
  if view.original_vfx.visual_tick<e.tick:continue
  if e.key=="weedy:start":
   var owner: UnitState=view.original_vfx.live[e.unit_id]
   if not check(view.original_vfx.pool[visible_index].instance.position.distance_to(view.renderer.unit_screen_center(view,owner))<.01,"Muzzle follows visible caster after simultaneous displacement"):return
  visible_index+=1
 var emitted:=view.original_vfx.emitted_events
 view.original_vfx.observe(view)
 if not check(emitted==view.original_vfx.emitted_events,"Repeated observation does not replay events"):return
 if "performance" in OS.get_cmdline_user_args():
  await runtime();return
 for tick in 135:
  var before:=state.state_hash()
  view._bone_tick=float(state.tick)
  view.original_vfx.sample(view)
  view.queue_redraw()
  await process_frame;await RenderingServer.frame_post_draw
  if not check(state.state_hash()==before,"Native sample/draw preserves state hash at%d"%state.tick):return
  if "capture" in OS.get_cmdline_user_args():root.get_texture().get_image().save_png(OUT+"frame-%03d.png"%tick)
  if tick in [0,2,5,10,20,40,75,110]:
   root.get_texture().get_image().save_png(OUT+"battle-%03d.png"%tick);captures+=1
  state.step([],[]);view.original_vfx.observe(view)
 for key in ["weedy:flight","silverash:slash","eyjafjalla:flight","eyjafjalla:hit"]:
  if not check(int(view.original_vfx.emission_counts.get(key,0))>0,"Actual event observed "+key):return
 var slash_before: int=view.original_vfx.emission_counts.get("silverash:slash",0)
 var fire_before: int=view.original_vfx.emission_counts.get("eyjafjalla:flight",0)
 for unit in state.units:
  if unit.operator_id in ["silverash","eyjafjalla"]:unit.silence_ticks_left=60;unit.attack_ticks_left=0
 state.step([],[]);view.original_vfx.observe(view)
 if not check(view.original_vfx.emission_counts.get("silverash:slash",0)==slash_before and view.original_vfx.emission_counts.get("eyjafjalla:flight",0)==fire_before,"Silenced basic attacks never masquerade as S3 native attacks"):return
 # Freeze supplied simulation time during network wait and pause, including repeated draws.
 view.simulation_waiting=true
 view.original_vfx.sample(view)
 var frozen:=view.original_vfx.visual_tick
 for i in 4:
  view.original_vfx.sample(view);view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 if not check(view.original_vfx.visual_tick==frozen,"Waiting cannot advance native VFX clock"):return
 paused=true
 await create_timer(.1,true).timeout
 if not check(view.original_vfx.visual_tick==frozen,"Pause cannot advance native VFX clock"):return
 paused=false
 # Four directions and mirrored projection reuse the current factual event cursors.
 for facing in 4:
  for mirror in [false,true]:
   view.mirror_board=mirror
   for unit in state.units:unit.facing=facing
   var before:=state.state_hash()
   view.original_vfx.sample(view);view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
   if not check(state.state_hash()==before,"Facing/mirror render is read-only"):return
 # Compare status/ball regions against the exact same frame without the composite.
 view.mirror_board=false;view.original_vfx.sample(view);view.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 var with_vfx:=root.get_texture().get_image()
 var native_renderer:=view.original_vfx
 view.original_vfx=BattleOriginalVfx.new();view.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 var without_vfx:=root.get_texture().get_image()
 with_vfx.save_png(OUT+"clarity-with.png");without_vfx.save_png(OUT+"clarity-without.png")
 native_renderer.viewport.get_texture().get_image().save_png(OUT+"native-composite.png")
 for unit in state.units:
  var region:=Rect2i(view.renderer.unit_health_rect(view,unit)).grow(-1)
  if not check(with_vfx.get_region(region).get_data()==without_vfx.get_region(region).get_data(),"Native composite never covers health bar"):return
 view.original_vfx=native_renderer
 view.original_vfx.sample(view)
 var pool_size:=view.original_vfx.pool.size()
 # Existing skill termination removes attached emitters; no stale ghosts after actual retreat.
 for unit in state.units.duplicate():state._retreat_unit(unit)
 state.step([],[]);view.original_vfx.observe(view);view._bone_tick=state.tick;view.original_vfx.sample(view)
 if not check(not view.original_vfx.events.any(func(e: Dictionary)->bool:return e.anchor in ["attached","rupture"]),"Source removal clears attached native nodes"):return
 # Released independent clips complete their own lifetime after source removal.
 for tick in 150:
  state.step([],[]);view.original_vfx.observe(view);view._bone_tick=state.tick;view.original_vfx.sample(view)
 if not check(view.original_vfx.visible_events==0 and view.original_vfx.events.is_empty(),"Released native clips expire without stale nodes"):return
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"real_deployments":8,"captures":captures,"pool_peak":pool_size,"emitted":view.original_vfx.emitted_events,"read_only_hash":true,"wait_pause":true,"status_overlay":true,"note":"Controlled SP short actual MatchState/MatchView fixture, not full match or live network."},"  "))
 print("ORIGINAL_VFX_MATCH_OK ",captures," captures pool",pool_size)
 quit(0)

func runtime() -> void:
 view.set_process(false)
 var native_enabled: bool="baseline" not in OS.get_cmdline_user_args()
 var step_ms: Array[float]=[]
 var ai_data: Dictionary={}
 for id in state.squad_ids[1]:ai_data[id]=data[id]
 var ai:=AIInput.new(1,ai_data)
 var clock:=0.0
 var next_tick:=0.0
 var cpu: Array[float]=[]
 var frame_times: Array[float]=[]
 var bins: Dictionary={}
 var begin:=Time.get_ticks_usec()
 while clock<23:
  var frame_begin:=Time.get_ticks_usec()
  var delta:=root.get_process_delta_time()
  clock=(Time.get_ticks_usec()-begin)/1000000.0
  while clock>=next_tick and state.result==MatchState.RESULT_RUNNING:
   next_tick+=1.0/22.5
   var step_begin:=Time.get_ticks_usec()
   state.step(view._local_input.take_commands(),ai.commands_for_tick(state));view.original_vfx.observe(view)
   step_ms.append((Time.get_ticks_usec()-step_begin)/1000.0)
  view._bone_tick=float(state.tick)
  var sample_begin:=Time.get_ticks_usec()
  if native_enabled:view.original_vfx.sample(view)
  else:
   view.original_vfx.visible_events=0;view.original_vfx.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
  bins[int(clock)]=int(bins.get(int(clock),0))+1
  cpu.append((Time.get_ticks_usec()-sample_begin)/1000.0)
  frame_times.append(delta*1000)
  view.queue_redraw();await process_frame
 cpu.sort();frame_times.sort();step_ms.sort()
 var result: Dictionary={"fps_per_second":bins,"native_enabled":native_enabled,"sim_ai_ms_p95":step_ms[int(step_ms.size()*.95)],"video_memory_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),"seconds":clock,"frames":cpu.size(),"average_fps":cpu.size()/clock,"vfx_submit_ms_p95":cpu[int(cpu.size()*.95)],"frame_ms_p95":frame_times[int(frame_times.size()*.95)],"simulation_ticks":state.tick,"emitted_events":view.original_vfx.emitted_events,"emission_counts":view.original_vfx.emission_counts,"pool_size":view.original_vfx.pool.size(),"note":"Actual MatchState/AI/MatchView wall-clock runtime; initial eight deploys and SP controlled, no low-end or full-match claim."}
 FileAccess.open(OUT+("runtime.json" if native_enabled else "baseline.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 root.get_texture().get_image().save_png(OUT+"runtime.png")
 if not check(state.tick>=450,"Real-time driver maintained simulation throughput"):return
 print("ORIGINAL_VFX_RUNTIME_OK ",JSON.stringify(result));quit(0)
