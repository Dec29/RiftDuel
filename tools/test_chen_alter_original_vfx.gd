extends SceneTree
const OUT="res://.ai/chen-alter-s3-20261026/gameplay/"
var data: Dictionary={}
var state: MatchState
var view: MatchView
var failed:=false
var hero: UnitState
var graphical: bool=DisplayServer.get_name()!="headless"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> bool:
 if not ok:failed=true;push_error(label)
 return ok
func make_battle(skill: int=2,multi: bool=false,facing: int=2) -> void:
 var blue_ids:=PackedStringArray(["chen_alter"]);var blue_skills:=PackedInt32Array([skill])
 var red_ids:=PackedStringArray(["hoshiguma","shining","nian","nightingale"]);var red_skills:=PackedInt32Array([2,2,2,2])
 state=MatchState.new(0x43414c54,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[blue_ids,red_ids],[blue_skills,red_skills])
 state.sides[0].cost=99;state.sides[1].cost=99
 state.sides[0].tactical_items[Config.TACTICAL_ITEM_PLATFORM]=1
 var platform: Array[InputCommand]=[InputCommand.new(state.tick,InputCommand.Kind.USE_ITEM,"",-1,Vector2i(11,2),-1,-1,Config.TACTICAL_ITEM_PLATFORM)]
 state.step(platform,[])
 check(state.terrain_at(Vector2i(11,2))=="high","Actual tactical platform creates legal source tile")
 var blue: Array[InputCommand]=[InputCommand.new(state.tick,0,"chen_alter",-1,Vector2i(11,2),-1,facing)]
 var red: Array[InputCommand]=[InputCommand.new(state.tick,0,"hoshiguma",-1,Vector2i(9,2),-1,0)]
 state.step(blue,red)
 for spec in [["shining",Vector2i(8,2)],["nian",Vector2i(9,3) if multi else Vector2i(8,3)],["nightingale",Vector2i(7,2)]]:
  var command: Array[InputCommand]=[InputCommand.new(state.tick,0,spec[0],-1,spec[1],-1,0)];state.step([],command)
 print("DEPLOYED ",state.units.map(func(u):return [u.operator_id,u.cell])," cost ",state.sides[0].cost," / ",state.sides[1].cost)
 if not check(state.units.size()==5,"Real source, defender and support deployments"):return
 hero=state.units[0]
 # Finish the real deployment animation before the controlled ready-SP cast.
 for i in 35:state.step([],[])
 for unit in state.units:unit.sp=data[unit.operator_id].skills[unit.skill_index].sp_required
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
func prepare() -> void:
 if graphical:await view.original_vfx.prepare(view)

func cast() -> void:
 var tick:=state.tick
 var blue: Array[InputCommand]=[InputCommand.new(tick,1,"",hero.unit_id,Vector2i.ZERO,hero.skill_index)]
 var red: Array[InputCommand]=[]
 for unit in state.units:
  if unit.side==1:red.append(InputCommand.new(tick,1,"",unit.unit_id,Vector2i.ZERO,unit.skill_index))
 state.step(blue,red);view.original_vfx.observe(view)
 for event in view.original_vfx.events:
  if event.anchor in ["chen_attached","chen_gun1","chen_gun2"]:check(event.tick==tick,"Actual activation tick")
func sample(render: bool=true) -> void:
 var before:=state.state_hash();view._bone_tick=state.tick;view.original_vfx.sample(view)
 check(state.state_hash()==before,"Observer / native bone attachments / sampling are read-only")
 if render and graphical:view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
func run() -> void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
 make_battle()
 if failed:quit(1);return
 await prepare();check(view.original_vfx.clips.size()==14,"Only carried native S3 family loads")
 cast();check(hero.skill_ticks_left==-2,"Real infinite-duration ammunition skill")
 var start:=state.tick;var releases: Array[int]=[];var last:=-1;var last_release_tick:=-1;var max_due:=0;var waits:=false;var peak:=0
 for i in 2600:
  var draw: bool=i in [0,10,30,60,90,150,300,600,900,1200,1500,1800,2100,2400]
  await sample(draw);peak=maxi(peak,view.original_vfx.visible_events)
  if hero.last_attack_tick>last and hero.last_attack_tick>=start:
   last=hero.last_attack_tick
   if state.chen_slimes.any(func(field):return field.source_id==hero.unit_id and field.due_tick-int(data.chen_alter.skills[2].effect_params["field_ticks"])==last):releases.append(last);last_release_tick=last
  for field in state.chen_slimes:max_due=maxi(max_due,field.due_tick)
  if draw and graphical:root.get_texture().get_image().save_png(OUT+"frame-%04d.png"%i)
  if i==90:
   var clock:=view.original_vfx.visual_tick;var count:=view.original_vfx.emitted_events
   view.simulation_waiting=true
   for n in 3:await sample()
   check(view.original_vfx.visual_tick==clock and view.original_vfx.emitted_events==count,"Waiting freezes supplied clock without replay")
   paused=true;await create_timer(.1,true).timeout;check(view.original_vfx.visual_tick==clock,"Pause freezes supplied clock");paused=false;view.simulation_waiting=false;waits=true
  if hero.skill_ticks_left==0 and state.tick>max_due+100:break
  state.step([],[])
 check(hero.skill_ticks_left==0 and hero.skill_ammo_left==0,"Full real ammunition exhaustion, no artificial ammo/HP/damage changes")
 check(releases.size()>=16,"At least sixteen actual attacks for 32 rounds")
 check(view.original_vfx.emission_counts.get("chen_alter:start_03",0)==releases.size(),"One area burst per actual release, no second-damage duplicate")
 check(view.original_vfx.emission_counts.get("chen_alter:buff_01",0)==1,"No periodic activation replay")
 check(view.original_vfx.visible_events==0,"Natural ammo end and final area expiry clear")
 var counts: Dictionary=view.original_vfx.emission_counts.duplicate();var full_ticks:=state.tick-start
 view.queue_free();await process_frame
 make_battle(2,true);await prepare();cast()
 while state.tick<hero.last_attack_tick+2 or view.original_vfx.emission_counts.get("chen_alter:start_03",0)<2:state.step([],[]);view.original_vfx.observe(view)
 await sample();check(view.original_vfx.emission_counts.get("chen_alter:hit_01",0)>=4,"Real payloads supply both affected destinations")
 var before_close:=state.tick
 var close: Array[InputCommand]=[InputCommand.new(state.tick,1,"",hero.unit_id,Vector2i.ZERO,2)];state.step(close,[]);await sample()
 check(hero.skill_ticks_left==0,"Actual manual close")
 check(view.original_vfx.events.filter(func(e):return e.anchor in ["chen_attached","chen_gun1","chen_gun2","chen_muzzle1","chen_muzzle2"]).is_empty(),"Manual close clears attached layers")
 check(view.original_vfx.events.any(func(e):return e.anchor=="chen_field"),"Actual slime survives closing the skill")
 state._retreat_unit(hero);state.step([],[]);await sample();check(view.original_vfx.events.any(func(e):return e.anchor=="chen_field"),"Actual slime survives caster retreat")
 for i in 250:state.step([],[]);await sample(false)
 check(view.original_vfx.visible_events==0,"Independent area and queued impacts expire after retreat")
 view.queue_free();await process_frame
 for facing in 4:
  make_battle(2,false,facing);await prepare();cast();await sample()
  check(view.original_vfx.visible_events==3,"Three activation layers before a real release")
  for mirror in [false,true]:
   view.mirror_board=mirror;await sample()
   for index in view.original_vfx.visible_events:
    check(view.original_vfx.pool[index].instance.transform.is_finite(),"Native front/back attachment geometry is finite")
  var emitted:=view.original_vfx.emitted_events
  for prop in ["silence_ticks_left","stun_ticks_left","displacement_ticks_left"]:
   hero.set(prop,2);state.step([],[]);await sample()
   check(view.original_vfx.visible_events==0,"Control suppresses attached S3 layer: "+prop)
   hero.set(prop,0);state.step([],[]);await sample()
   check(view.original_vfx.visible_events==3,"Control resumes same activation layers: "+prop)
  check(view.original_vfx.emitted_events==emitted,"Control/mirror never re-emits activation")
  var clip: Resource=view.original_vfx.clips["chen_alter:buff_01"]
  check(clip.frame_at(2.,0)==clip.frame_at(5.,0),"Declared steady loop reuses frames")
  var player=view.original_vfx.pool[0]
  player.sample(clip,65.,0,Vector2.ZERO,50.,false,0)
  check(player.instance.visible,"Indefinite ammunition idle does not expire at an arbitrary duration")
  for layer in player._layers:
   if layer.visible and layer.material.get_meta("original_vfx_clock",false):check(is_equal_approx(float(layer.get_instance_shader_parameter("source_time")),65.),"Continuous UV receives full battle age after geometry loops")
  view.queue_free();await process_frame
 await moving_impact()
 await object_splash(false)
 await object_splash(true)
 make_battle(1);await prepare();cast();await sample()
 check(view.original_vfx.viewport==null,"S2 does not load or emit S3 resources")
 var report: Dictionary={"passed":not failed,"actual_releases":releases,"full_skill_ticks":full_ticks,"counts":counts,"peak_visible":peak,"pause_wait":waits,"controlled_initial_cost_sp":true,"graphical":graphical,"deployment_settle_ticks":35,"moving_impact_position":true,"paired_object_splash":true,"actual_tactical_platform_initial_stock":1,"survival":"Actual Hoshiguma/Nian/Shining/Nightingale skills; no artificial HP, ammo or damage","note":"Focused real-simulation VFX acceptance; not full-match, physical input or network-device acceptance"}
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CHEN_ALTER_NATIVE_MATCH ",JSON.stringify(report));view.queue_free();await process_frame;quit(1 if failed else 0)

func moving_impact() -> void:
 make_battle();await prepare();cast()
 var shot: AttackProjectile
 for i in 200:
  for payload in state.attack_projectiles:
   if payload.operator_id=="chen_alter" and payload.attack_event:shot=payload;break
  if shot!=null:break
  state.step([],[]);view.original_vfx.observe(view)
 if not check(shot!=null,"Real released payload exists before displacement"):return
 var target: UnitState=state.units[1]
 var original_cell:=target.cell
 var distance:=DisplacementRules.apply_unit(state,hero,target,Vector2i.DOWN,DisplacementRules.effective_weight(state,target)+1)
 if not check(distance==1,"Existing displacement rules move the actual target one cell"):return
 while state.tick<=shot.arrival_tick:
  state.step([],[]);await sample()
 var hit: Dictionary={}
 for event in view.original_vfx.events:
  if event.get("impact_unit_id",-1)==target.unit_id and event.tick==shot.arrival_tick:hit=event;break
 if not check(not hit.is_empty() and hit.has("impact_point"),"Arrival captures the moved target landing point"):return
 var expected:=view.projection.board_unproject(view.renderer.unit_screen_center(view,target))
 check(hit.impact_point.distance_to(expected)<.01,"Splash follows current displayed target position at arrival")
 check(hit.impact_point.distance_to(Vector2(original_cell)+Vector2(.5,.5))>.01,"Splash is not pinned to the released old cell")
 var landing: Vector2=hit.impact_point
 for i in 2:state.step([],[]);await sample()
 check(hit.impact_point==landing,"Completed splash remains at its landing point during later movement")
 view.mirror_board=true;await sample()
 check(hit.impact_point==landing,"Mirroring reprojects without changing the landing point")
 if graphical:root.get_texture().get_image().save_png(OUT+"moving-impact.png")
 view.queue_free();await process_frame

func object_splash(use_box: bool) -> void:
 var ids:=PackedStringArray(["chen_alter"]);var skills:=PackedInt32Array([2])
 state=MatchState.new(0x43414c54,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
 state.sides[0].cost=99;state.sides[0].tactical_items[Config.TACTICAL_ITEM_PLATFORM]=1
 # A single controlled initial box exercises the same object branch without changing its three-hit rule.
 if use_box:state.tactical_boxes.append(TacticalBox.new(0,Vector2i(9,5),Config.BOX_REQUIRED_HITS));state.next_box_id=1
 var platform: Array[InputCommand]=[InputCommand.new(state.tick,InputCommand.Kind.USE_ITEM,"",-1,Vector2i(11,5),-1,-1,Config.TACTICAL_ITEM_PLATFORM)]
 state.step(platform,[])
 var deploy: Array[InputCommand]=[InputCommand.new(state.tick,0,"chen_alter",-1,Vector2i(11,5),-1,2)];state.step(deploy,[])
 if not check(state.units.size()==1,"Actual deployment for paired object payloads"):return
 hero=state.units[0]
 for i in 35:state.step([],[])
 hero.sp=data.chen_alter.skills[2].sp_required
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
 await prepare();cast()
 var shots: Array[AttackProjectile]=[]
 for i in 200:
  state.step([],[]);view.original_vfx.observe(view)
  for payload in state.attack_projectiles:
   if payload.operator_id=="chen_alter" and payload.active:shots.append(payload)
  if not shots.is_empty():break
 if not check(shots.size()==2,"Both real S3 damage payloads remain present"):return
 var kind: int=AttackIntent.TargetKind.BOX if use_box else AttackIntent.TargetKind.BALL
 check(shots.all(func(p):return p.kind==kind),"Real object selection uses the expected target kind")
 check(view.original_vfx.emission_counts.get("chen_alter:hit_01",0)==1,"One splash for paired box/ball damage")
 check(view.original_vfx.emission_counts.get("chen_alter:start_03",0)==1,"One area burst for paired box/ball damage")
 var arrival: int=shots[0].arrival_tick
 while state.tick<=arrival:state.step([],[]);await sample()
 if use_box:check(state.tactical_boxes.size()==1 and state.tactical_boxes[0].hits_left==1,"Paired box damage still consumes two of three hits")
 if graphical:root.get_texture().get_image().save_png(OUT+("object-box.png" if use_box else "object-ball.png"))
 view.queue_free();await process_frame
