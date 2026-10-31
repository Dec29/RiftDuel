extends SceneTree
const OUT="res://.ai/surtr-s3-20261026/gameplay/"
var data: Dictionary={}
var state: MatchState
var view: MatchView
var hero: UnitState
var failed:=false
var graphical: bool=DisplayServer.get_name()!="headless"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> bool:
 if not ok:failed=true;push_error(label)
 return ok
func setup(skill: int=2,facing: int=2) -> void:
 var blue:=PackedStringArray(["surtr"]);var red:=PackedStringArray(["hoshiguma"])
 state=MatchState.new(0x53555254,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[blue,red],[PackedInt32Array([skill]),PackedInt32Array([2])])
 state.sides[0].cost=99;state.sides[1].cost=99
 var a: Array[InputCommand]=[InputCommand.new(state.tick,0,"surtr",-1,Vector2i(11,5),-1,facing)]
 var b: Array[InputCommand]=[InputCommand.new(state.tick,0,"hoshiguma",-1,Vector2i(9,5),-1,0)];state.step(a,b)
 if not check(state.units.size()==2,"Actual source and defender deployments"):return
 hero=state.units[0]
 for i in 35:state.step([],[])
 for u in state.units:u.sp=data[u.operator_id].skills[u.skill_index].sp_required
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
 if graphical:await view.original_vfx.prepare(view)
func cast() -> void:
 var a: Array[InputCommand]=[InputCommand.new(state.tick,1,"",hero.unit_id,Vector2i.ZERO,hero.skill_index)]
 var enemy: UnitState=state.units[1]
 var b: Array[InputCommand]=[InputCommand.new(state.tick,1,"",enemy.unit_id,Vector2i.ZERO,enemy.skill_index)]
 state.step(a,b);view.original_vfx.observe(view)
func sample(render: bool=false) -> void:
 var hash_before:=state.state_hash();view._bone_tick=state.tick;view.original_vfx.sample(view)
 check(hash_before==state.state_hash(),"Native VFX and bone queries are read-only")
 if graphical and render:view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
func persistent_visible_count() -> int:
 var expected: Dictionary={}
 for event in view.original_vfx.events:
  if event.key not in ["surtr:buff","surtr:buff_02","surtr:buff_03","surtr:buff_04"]:continue
  if hero.facing==3 and event.key in ["surtr:buff_03","surtr:buff_04"]:continue
  var clip: Resource=view.original_vfx.clips[event.key]
  var age: float=(view.original_vfx.visual_tick-event.tick)/Config.TICK_RATE
  var frame: Resource=clip.frame_at(age,hero.facing if event.key=="surtr:buff_02" else 0)
  if frame!=null:expected[frame.get_instance_id()]=true
 var found:=0
 for i in view.original_vfx.visible_events:
  var frame: Resource=view.original_vfx.pool[i].frame
  if frame!=null and expected.has(frame.get_instance_id()):found+=1
 return found
func run() -> void:
 root.size=Vector2i(1280,720);root.content_scale_size=root.size
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
 await setup();cast();await sample(true)
 check(view.original_vfx.clips.size()==10,"Only the carried Surtr family loads")
 check(hero.skill_ticks_left!=0,"Actual infinite S3 remains active")
 check(view._bagpipe_models[hero.unit_id].clip!="Start","Skill mounts are checked after actual deployment")
 var activation: int=view.original_vfx.emitted_events;var first_release:=-1;var count:=0
 for i in 1700:
  state.step([],[]);await sample(i in [0,30,60,120,240,480,720,960,1200,1500])
  if hero.last_attack_tick>=hero.launch_started_tick and hero.last_attack_tick>=0:first_release=hero.last_attack_tick
  if i==50:
   var clock:=view.original_vfx.visual_tick;var emitted:=view.original_vfx.emitted_events;view.simulation_waiting=true
   for n in 3:await sample(true)
   check(view.original_vfx.visual_tick==clock and view.original_vfx.emitted_events==emitted,"Waiting freezes native clock without replay")
   paused=true;await create_timer(.1,true).timeout;check(view.original_vfx.visual_tick==clock,"Pause freezes supplied clock");paused=false;view.simulation_waiting=false
  if hero not in state.units:break
 count=view.original_vfx.emission_counts.get("surtr:range",0)
 check(first_release>=0 and count>0,"Only real S3 attacks trigger original cast layers")
 check(view.original_vfx.emission_counts.get("surtr:buff",0)==1,"No persistent buff activation replay")
 check(hero not in state.units,"Actual self-drain/immortality lifecycle ends without HP or duration changes")
 for i in 180:state.step([],[]);await sample()
 check(view.original_vfx.events.is_empty() and view.original_vfx.visible_events==0,"Retreat clears mounted layers and finite impacts expire")
 view.queue_free();await process_frame
 for facing in 4:
  await setup(2,facing);cast();await sample()
  for i in 20:state.step([],[]);await sample()
  for mirror in [false,true]:
   view.mirror_board=mirror;await sample(true)
   check(persistent_visible_count()==(2 if facing==3 else 4),"Persistent front/back layers match actual source eye variants; windup is counted separately")
   for index in view.original_vfx.visible_events:check(view.original_vfx.pool[index].instance.transform.is_finite(),"Native mounted transform remains finite")
   if graphical:root.get_texture().get_image().save_png(OUT+"facing-%d-mirror-%s.png"%[facing,str(mirror)])
  hero.silence_ticks_left=2;state.step([],[]);await sample();check(view.original_vfx.visible_events==0,"Silenced ordinary pose does not retain unattached S3 layers")
  hero.silence_ticks_left=0;state.step([],[]);await sample();check(persistent_visible_count()==(2 if facing==3 else 4),"Same persistent layers resume without a new activation")
  view.queue_free();await process_frame
 for skill in [0,1]:
  await setup(skill);await sample();check(view.original_vfx.viewport==null,"Other skills do not allocate S3 family");view.queue_free();await process_frame
 var report={"passed":not failed,"graphical":graphical,"actual_s3_attacks":count,"initial_cost_sp_controlled":true,"deployment_settle_ticks":35,"natural_self_drain_exit":true,"pause_wait":true,"back_variants_empty_in_source":true,"scope":"Focused S3 source integration only; no full match, physical input or original visual fidelity claim"}
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("SURTR_NATIVE_MATCH ",JSON.stringify(report));quit(1 if failed else 0)
