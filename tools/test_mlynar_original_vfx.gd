extends SceneTree
const OUT="res://.ai/mlynar-s3-20261027/gameplay/"
var data: Dictionary={}
var state: MatchState
var view: MatchView
var actor: UnitState
var failed:=false
var graphical:=DisplayServer.get_name()!="headless"
var captures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> bool:
 if not ok:failed=true;push_error(label)
 return ok
func setup(direction: int=2,skill: int=2) -> void:
 var ids:=PackedStringArray(["mlynar"]);var foes:=PackedStringArray(["hoshiguma"])
 state=MatchState.new(0x4d4c594e,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,foes],[PackedInt32Array([skill]),PackedInt32Array([2])])
 state.sides[0].cost=99;state.sides[1].cost=99
 var commands: Array[InputCommand]=[InputCommand.new(0,0,"mlynar",-1,Vector2i(11,5),-1,direction)]
 var red: Array[InputCommand]=[InputCommand.new(0,0,"hoshiguma",-1,Vector2i(9,5),-1,0)]
 state.step(commands,red)
 if not check(state.units.size()==2,"Two real accepted deployments"):return
 actor=state.units[0]
 for i in 35:state.step([],[])
 # Controlled QA durability/SP only. Real rules determine casts, windup, release and expiry.
 actor.sp=data.mlynar.skills[skill].sp_required
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
func cast() -> void:
 var commands: Array[InputCommand]=[InputCommand.new(state.tick,1,"",actor.unit_id,Vector2i.ZERO,actor.skill_index)]
 state.step(commands,[]);sample()
func sample() -> void:
 var before:=state.state_hash();view._bone_tick=state.tick;view.original_vfx.observe(view);view.original_vfx.sample(view)
 check(before==state.state_hash(),"VFX / native bone queries are read-only")
func draw_frame(label: String) -> void:
 if not graphical:return
 view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+label+".png");captures+=1
func cleanup() -> void:
 view.queue_free();await process_frame
func run() -> void:
 root.size=Vector2i(1280,720);root.content_scale_size=root.size
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
 var durable: OperatorData=data.hoshiguma.duplicate(true);durable.max_health=1000000;durable.attack=1;data.hoshiguma=durable
 if "performance" in OS.get_cmdline_user_args():await performance();return
 if "capture" in OS.get_cmdline_user_args():await capture_sequence();return
 setup();cast()
 check(view.original_vfx.clips.size()==6,"Only carried Mlynar family loads")
 check(view.original_vfx.emission_counts.get("mlynar:buff_02",0)==1 and view.original_vfx.emission_counts.get("mlynar:buff_03",0)==1,"Two persistent source layers once per activation")
 var releases: Dictionary={};var first: int=-1
 for i in 1020:
  state.step([],[]);sample()
  if actor.last_attack_tick>=0:
   releases[actor.last_attack_tick]=true
   if first<0:first=actor.last_attack_tick
  if graphical and i<125:
   view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
   if i%3==0:root.get_texture().get_image().save_png(OUT+"frame-%03d.png"%[i/3]);captures+=1
  if i in [2,14,29,65,124,315,850,1019]:await draw_frame("tick-%04d"%i)
  if i==65:
   var clock:=view.original_vfx.visual_tick;var emitted:=view.original_vfx.emitted_events
   view.simulation_waiting=true
   for n in 8:sample()
   check(view.original_vfx.visual_tick==clock and view.original_vfx.emitted_events==emitted,"Waiting freezes effect clock and avoids replay")
   view.simulation_waiting=false
 check(first>=0,"S3 produces actual native-timeline releases")
 check(view.original_vfx.emission_counts.get("mlynar:range_01",0)==releases.size(),"Exactly one original slash per actual attack release")
 check(actor.skill_ticks_left==0,"Actual finite S3 expires without animation altering rules")
 check(view.original_vfx.events.is_empty() and view.original_vfx.visible_events==0,"Persistent and finite effects clear after natural expiry")
 await cleanup()
 for direction in 4:
  setup(direction);cast()
  for i in 40:state.step([],[]);sample()
  for mirror in [false,true]:
   view.mirror_board=mirror;sample();await draw_frame("facing%d-mirror%d"%[direction,int(mirror)])
   var before_mount:=state.state_hash();var mount:=view.original_vfx.mlynar_attachment(view,actor,view.renderer.unit_row_width(view,actor))
   check(mount.is_finite() and before_mount==state.state_hash(),"Actual front/back special-point bone query is finite and read-only")
   for i in view.original_vfx.visible_events:check(view.original_vfx.pool[i].instance.transform.is_finite(),"Finite native attachment transform across facing/mirror")
  var retreat: Array[InputCommand]=[InputCommand.new(state.tick,2,"",actor.unit_id)]
  state.step(retreat,[]);sample()
  check(view.original_vfx.events.all(func(e: Dictionary)->bool:return not e.anchor.begins_with("mlynar_")),"Retreat cancels held and unlaunched windup layers")
  for i in 150:state.step([],[]);sample()
  check(view.original_vfx.events.is_empty(),"Released slash tails expire after retreat")
  await cleanup()
 for skill in [0,1]:
  setup(2,skill);check(view.original_vfx.viewport==null,"S1/S2 create no S3 offscreen renderer");await cleanup()
 FileAccess.open(OUT+("graphics-checks.json" if graphical else "cpu-checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"captures":captures,"actual_releases":releases.size(),"first_release":first,"graphical":graphical,"scope":"Focused Mlynar VFX lifecycle, clock, 4 facing x mirror, native attachment and read-only checks; not full regression or performance."},"\t"))
 print("MLYNAR_ORIGINAL_VFX_", "FAIL" if failed else "OK", " actual releases=",releases.size()," captures=",captures);quit(1 if failed else 0)

func performance() -> void:
 var results: Array=[]
 for enabled in [true,false]:
  setup()
  if not enabled:
   view.original_vfx.viewport.queue_free()
   view.original_vfx=BattleOriginalVfx.new()
  cast()
  if enabled:await view.original_vfx.prepare(view)
  var cpu: Array[float]=[];var frame_ms: Array[float]=[];var accumulator:=0.0
  var begin:=Time.get_ticks_msec();var count:=0
  while Time.get_ticks_msec()-begin<12000:
   var delta:=root.get_process_delta_time();accumulator+=delta*22.5
   var started:=Time.get_ticks_usec()
   while accumulator>=1.0:state.step([],[]);accumulator-=1.0
   sample();view.queue_redraw()
   cpu.append((Time.get_ticks_usec()-started)/1000.0);frame_ms.append(delta*1000.0);count+=1
   await process_frame;await RenderingServer.frame_post_draw
  var elapsed: float=(Time.get_ticks_msec()-begin)/1000.0
  cpu.sort();frame_ms.sort()
  results.append({"enabled":enabled,"seconds":elapsed,"frames":count,"fps":count/elapsed,"cpu_median_ms":cpu[cpu.size()/2],"cpu_p95_ms":cpu[int(cpu.size()*.95)],"frame_p95_ms":frame_ms[int(frame_ms.size()*.95)]})
  await cleanup()
 FileAccess.open(OUT+"performance.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":results,"scope":"Same 2-actor real battle fixture, 12s each after shader warmup; QA swaps only the renderer for off. Not maximum squad or network/full-match performance."},"	"))
 print("MLYNAR_PERFORMANCE ",JSON.stringify(results));quit(0)

func capture_sequence() -> void:
 setup();cast()
 var folder:=OUT+"sequence/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var frames: Array=[]
 for i in 920:
  state.step([],[]);sample();view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
  var path:=folder+"frame-%04d.png"%i
  root.get_texture().get_image().get_region(Rect2i(430,170,430,320)).save_png(path)
  frames.append({"file":path,"tick":state.tick,"real_seconds":i/22.5,"simulation_seconds":i/30.0})
 check(view.original_vfx.events.is_empty(),"Continuous capture covers natural skill/FX expiry")
 FileAccess.open(folder+"frames.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":frames,"captured_rendered":true,"controlled_enemy_durability":true,"playback_tick_rate":22.5},"	"))
 print("MLYNAR_FULL_SEQUENCE ",frames.size());await cleanup();quit(1 if failed else 0)
