extends SceneTree
# Real deployment/retreat/skill commands; QA durability/SP only, no rule changes.
const OUT="res://.ai/menu-summons-20261027/battle-props/"
var failed:=false
var hash_checks:=0
var data: Dictionary={}
var state: MatchState
var view: MatchView
var reports: Array=[]
var pause_diagnostics: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failed=true;push_error(label)
func step(blue: Array[InputCommand]=[],red: Array[InputCommand]=[]) -> void:
 state.step(blue,red)
 if view!=null:view._bone_tick=state.tick
func actor(id: String,side: int) -> UnitState:
 for unit in state.units:
  if unit.operator_id==id and unit.side==side:return unit
 return null
func frame(label: String="") -> void:
 var before:=state.state_hash()
 view.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
 check(before==state.state_hash(),"Prop render must not mutate state: "+label);hash_checks+=1
 if not label.is_empty() and DisplayServer.get_name()!="headless":
  check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"Save game prop capture "+label)
 # Atlas isolation: no nontransparent pixels may touch an adjacent slot boundary.
 if DisplayServer.get_name()!="headless" and view.original_props.viewport!=null:
  var image:=view.original_props.viewport.get_texture().get_image()
  var border_alpha:=0.
  for n in 1024:
   for edge in [0,511,512,1023]:
    border_alpha=maxf(border_alpha,maxf(image.get_pixel(n,edge).a,image.get_pixel(edge,n).a))
  check(border_alpha<=.004,"Original prop atlas fits its physical tile without bleeding")
func setup(ines_skill: int,flag_skill: int) -> void:
 var ids:=PackedStringArray(["ines","saileach","hoshiguma"])
 var skills:=PackedInt32Array([ines_skill,flag_skill,0])
 state=MatchState.new(0x50524f50,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
 state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=1000000000
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
 await view.original_vfx.prepare(view)
func deploy_pair(id: String,cell: Vector2i) -> void:
 state.sides[0].cost=99;state.sides[1].cost=99
 check(state.can_deploy(0,id,cell) and state.can_deploy(1,id,Vector2i(20-cell.x,cell.y)),"Legal paired prop owner "+id)
 step([InputCommand.new(state.tick,0,id,-1,cell,-1,2)],[InputCommand.new(state.tick,0,id,-1,Vector2i(20-cell.x,cell.y),-1,0)])
func cleanup() -> void:
 view.queue_free();await process_frame;view=null
func run() -> void:
 root.size=Vector2i(1280,720);root.content_scale_size=root.size
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
 for id in ["ines","saileach","hoshiguma"]:
  data[id]=data[id].duplicate(true);data[id].max_health=1000000;data[id].attack=1
 for flag_skill in [1,2]:
  await setup(2,flag_skill)
  deploy_pair("ines",Vector2i(12,7))
  check(state.units.is_empty() and state.sides[0].ines_first_shadow_used and state.sides[1].ines_first_shadow_used,"S3 first free deployment produces both real sentinels")
  await frame("s%d-shadow"%(flag_skill+1))
  check(view.original_props.entries.size()==2,"Both sentinels visible")
  deploy_pair("saileach",Vector2i(12,5) if flag_skill==1 else Vector2i(11,5))
  deploy_pair("hoshiguma",Vector2i(13,5) if flag_skill==1 else Vector2i(12,5))
  for i in 40:step()
  for side in 2:
   var unit:=actor("saileach",side);unit.sp=data.saileach.skills[flag_skill].sp_required
   if flag_skill==1:actor("hoshiguma",side).hp=100
  step([InputCommand.new(state.tick,1,"",actor("saileach",0).unit_id,Vector2i.ZERO,flag_skill)],[InputCommand.new(state.tick,1,"",actor("saileach",1).unit_id,Vector2i.ZERO,flag_skill)])
  for side in 2:check(actor("saileach",side).skill_ticks_left>0,"Real flag skill started")
  for offset in 95:
   if offset>0:step()
   if offset in [0,8,16,29,40,60,94]:await frame("s%d-t%03d"%[flag_skill+1,offset])
  check(view.original_props.entries.size()==4,"Two sentinels and two real planted flags")
  var prop_clock: float=view.original_props.visual_tick
  var prop_signature: int=view.original_props._signature
  var pixels:=hash(root.get_texture().get_image().get_data())
  view.simulation_waiting=true
  view._bone_tick+=9.
  await frame()
  check(prop_clock==view.original_props.visual_tick and prop_signature==view.original_props._signature,"Network wait freezes prop clock/frame")
  view._bone_tick=state.tick;view.simulation_waiting=false
  await frame()
  pixels=hash(root.get_texture().get_image().get_data())
  var atlas_pixels:=hash(view.original_props.viewport.get_texture().get_image().get_data())
  var poses:=pose_hash();paused=true
  await frame()
  check(prop_clock==view.original_props.visual_tick and atlas_pixels==hash(view.original_props.viewport.get_texture().get_image().get_data()) and poses==pose_hash(),"Pause freezes prop atlas pixels and native body poses")
  pause_diagnostics.append({"skill":flag_skill+1,"whole_frame_same":pixels==hash(root.get_texture().get_image().get_data()),"prop_atlas_same":atlas_pixels==hash(view.original_props.viewport.get_texture().get_image().get_data()),"native_poses_same":poses==pose_hash()})
  paused=false
  for mirror in [true,false]:
   view.mirror_board=mirror
   for facing in 4:
    for unit in state.units:unit.facing=facing
    await frame("s%d-m%d-f%d"%[flag_skill+1,int(mirror),facing])
  # Actual Ines redeploy recalls the old shadow, then retreat leaves a new one.
  deploy_pair("ines",Vector2i(14,7));await frame("s%d-recall"%(flag_skill+1))
  check(state.sides[0].ines_shadow_cell.x<0 and state.sides[1].ines_shadow_cell.x<0,"S3 real redeployment recalls sentinels")
  check(view.original_props.entries.size()==2,"Recalled sentinel meshes removed")
  step([InputCommand.new(state.tick,2,"",actor("ines",0).unit_id)],[InputCommand.new(state.tick,2,"",actor("ines",1).unit_id)])
  await frame("s%d-new-shadow"%(flag_skill+1))
  check(view.original_props.entries.size()==4,"Retreat moves persistent shadow to new cell")
  for i in 480:step()
  await frame("s%d-expired"%(flag_skill+1))
  check(view.original_props.entries.size()==2,"Expired skill removes flag; persistent sentinels remain")
  reports.append({"flag_skill":flag_skill+1,"remaining_props":view.original_props.entries.size()})
  await cleanup()
 # Ordinary Ines also leaves the sentinel on a real retreat; Sai S1 has no thrown flag.
 await setup(0,0);deploy_pair("ines",Vector2i(12,5));deploy_pair("saileach",Vector2i(13,5))
 for i in 40:step()
 step([InputCommand.new(state.tick,2,"",actor("ines",0).unit_id)],[InputCommand.new(state.tick,2,"",actor("ines",1).unit_id)])
 await frame("s1-retreat-shadow")
 check(view.original_props.entries.size()==2 and not view.original_props.clips.has("flag_02") and not view.original_props.clips.has("flag_03"),"Ordinary retreat creates shadow; S1 holds body flag without duplicate prop")
 await cleanup()
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"hash_checks":hash_checks,"pause_diagnostics":pause_diagnostics,"cases":reports,"scope":"Real paired S3 sentinel deploy/recall/retreat; Saileach S2/S3 landing/loop/expiry, S1 no duplicate; mirror/facing; pause/wait; native atlas edge isolation. No AI/network transport or full regression."},"\t"))
 print("BATTLE_PROPS_OK ",not failed," hashes=",hash_checks);quit(1 if failed else 0)


func pose_hash() -> int:
 var result: Array=[]
 for id in view._bagpipe_models:
  var model: OperatorSpineVisual=view._bagpipe_models[id]
  result.append([id,model.clip,model.pose_seconds,model.mesh.surface_get_arrays(0) if model.mesh.get_surface_count()>0 else []])
 return hash(result)
