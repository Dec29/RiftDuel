extends SceneTree
const OUT="res://.ai/ifrit-s3-20261025/gameplay/"
var data: Dictionary={}
var state: MatchState
var view: MatchView
var failed:=false
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> bool:
 if not ok:failed=true;push_error(label)
 return ok
func make_battle(facing: int=2) -> void:
 var ids:=PackedStringArray(["ifrit","specter"]);var skills:=PackedInt32Array([2,1])
 state=MatchState.new(0x49465249,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
 state.sides[0].cost=99;state.sides[1].cost=99
 var blue: Array[InputCommand]=[InputCommand.new(0,0,"ifrit",-1,Vector2i(14,4),-1,facing)]
 var red: Array[InputCommand]=[InputCommand.new(0,0,"specter",-1,Vector2i(9,4),-1,0)]
 state.step(blue,red)
 if not check(state.units.size()==2,"Actual high-ground Ifrit and ground Specter deployments"):return
 for u in state.units:u.sp=data[u.operator_id].skills[u.skill_index].sp_required
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
func cast() -> void:
 var blue: Array[InputCommand]=[InputCommand.new(state.tick,1,"",state.units[0].unit_id,Vector2i.ZERO,2)]
 var red: Array[InputCommand]=[InputCommand.new(state.tick,1,"",state.units[1].unit_id,Vector2i.ZERO,1)]
 var cast_tick:=state.tick
 state.step(blue,red);view.original_vfx.observe(view)
 for event in view.original_vfx.events:
  if event.key.begins_with("ifrit:"):check(event.tick==cast_tick,"Activation clip starts at actual command tick")
func sample() -> void:
 var before:=state.state_hash();view._bone_tick=state.tick;view.original_vfx.sample(view)
 check(state.state_hash()==before,"Read-only VFX sampling")
 view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
func run() -> void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
 make_battle()
 if failed:quit(1);return
 await view.original_vfx.prepare(view);check(view.original_vfx.clips.size()==3,"Only carried Ifrit S3 family loads")
 cast();var peak:=0;var pulse_ticks: Array[int]=[];var previous:=-1
 for i in 666:
  var capture: bool=i in [0,10,30,60,120,300,590,603,630,665]
  if capture:await sample()
  else:
   var before:=state.state_hash();view._bone_tick=state.tick;view.original_vfx.sample(view);check(state.state_hash()==before,"Read-only VFX sampling")
  peak=maxi(peak,view.original_vfx.visible_events)
  if state.units[0].last_attack_tick>previous:pulse_ticks.append(state.units[0].last_attack_tick);previous=state.units[0].last_attack_tick
  if i in [0,10,30,60,120,300,590,603,630,665]:root.get_texture().get_image().save_png(OUT+"frame-%03d.png"%i)
  if i==603:check(state.units[0].skill_ticks_left==0 and view.original_vfx.visible_events==7,"Natural skill end retains the source fade tail")
  if i==60:
   var visible:=view.original_vfx.visible_events;var with_vfx:=root.get_texture().get_image()
   view.original_vfx.visible_events=0;view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
   var plain:=root.get_texture().get_image()
   with_vfx.save_png(OUT+"clarity-with.png");plain.save_png(OUT+"clarity-without.png")
   for u in state.units:
    var rect:=Rect2i(view.renderer.unit_health_rect(view,u)).grow(-1)
    check(with_vfx.get_region(rect).get_data()==plain.get_region(rect).get_data(),"Health overlay stays above VFX")
   view.original_vfx.visible_events=visible
   var clock:=view.original_vfx.visual_tick;var events:=view.original_vfx.emitted_events;view.simulation_waiting=true
   for n in 3:view.original_vfx.sample(view);await process_frame
   check(view.original_vfx.visual_tick==clock and events==view.original_vfx.emitted_events,"Network wait freezes clock without re-emission")
   paused=true;await create_timer(.1,true).timeout;check(view.original_vfx.visual_tick==clock,"Pause freezes VFX");paused=false;view.simulation_waiting=false
  state.step([],[])
 check(view.original_vfx.emission_counts.get("ifrit:buff",0)==1 and view.original_vfx.emission_counts.get("ifrit:range",0)==6,"One source buff and six actual range cells, no per-pulse fabrication")
 check(view.original_vfx.visible_events==0,"Natural expiry including source tail")
 var first_counts: Dictionary=view.original_vfx.emission_counts.duplicate()
 view.queue_free();await process_frame
 make_battle();await view.original_vfx.prepare(view);cast()
 for n in 75:state.step([],[])
 await sample()
 var original_age:=view.original_vfx.visual_tick
 for prop in ["silence_ticks_left","stun_ticks_left","displacement_ticks_left"]:
  state.units[0].set(prop,3);state.step([],[]);await sample()
  check(view.original_vfx.visible_events==0,"Suppressed active flame during "+prop)
  state.units[0].set(prop,0);state.step([],[]);await sample()
  check(view.original_vfx.visible_events==7,"Flame returns using same cast age after "+prop)
 check(view.original_vfx.visual_tick>original_age and view.original_vfx.emission_counts.get("ifrit:range",0)==6,"Control release does not restart/re-emit source clips")
 state._retreat_unit(state.units[0]);state.step([],[]);await sample();check(view.original_vfx.visible_events==0,"Retreat removes persistent flames")
 for facing in 4:
  view.queue_free();await process_frame
  make_battle(facing);await view.original_vfx.prepare(view);cast()
  for n in 75:state.step([],[])
  var expected: Array[Vector2i]=[]
  for offset in data.ifrit.attack_range:
   var cell: Vector2i=state.units[0].cell+AttackRange.rotate_offset(offset,facing)
   if view.projection.cell_is_inside(cell):expected.append(cell)
  var actual: Array[Vector2i]=[]
  for event in view.original_vfx.events:
   if event.anchor=="ifrit_field":actual.append(event.origin);check(event.facing==0,"Fixed source art does not rotate edge-on")
  check(actual==expected,"Actual cast facing maps only in-board attack cells")
  for mirrored in [false,true]:
   view.mirror_board=mirrored;await sample()
   root.get_texture().get_image().save_png(OUT+"facing%d-mirror%d.png"%[facing,int(mirrored)])
 var report: Dictionary={"passed":not failed,"counts":first_counts,"peak_visible":peak,"actual_damage_markers":pulse_ticks,"controlled_initial_cost_sp":true,"target_survival":"Actual Specter S2; no synthetic health/damage changes","note":"666-tick real MatchState/MatchView lifecycle plus controlled status inputs. Not full-match/network/physical input acceptance."}
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 view.queue_free();await process_frame
 print("IFRIT_NATIVE_MATCH_OK ",JSON.stringify(report));quit(1 if failed else 0)
