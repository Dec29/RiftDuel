extends SceneTree
var output_path: String="res://.ai/fiammetta-s3-20261026/gameplay/"
var data: Dictionary={}
var state: MatchState
var view: MatchView
var actor: UnitState
var failed:=false
var cases: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> bool:
 if not ok:failed=true;push_error(message)
 return ok
func sample() -> void:
 var before:=state.state_hash()
 view._bone_tick=state.tick
 view.original_vfx.observe(view)
 view.original_vfx.sample(view)
 check(before==state.state_hash(),"VFX observation, native bones and sampling leave simulation hash unchanged")
func render(label: String) -> void:
 if DisplayServer.get_name()=="headless":return
 var before:=state.state_hash();view.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 check(before==state.state_hash(),"Actual Fiammetta drawing preserves simulation hash")
 root.get_texture().get_image().save_png(output_path+label+".png")
func setup(facing: int,skill: int=2) -> void:
 state=MatchState.new(0x5048454e,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[PackedStringArray(["fiammetta"]),PackedStringArray(["hoshiguma"])],[PackedInt32Array([skill]),PackedInt32Array([0])])
 state.sides[0].cost=99
 var cell:=Vector2i(13,8) if facing==3 else Vector2i(13,2)
 var commands: Array[InputCommand]=[InputCommand.new(state.tick,0,"fiammetta",-1,cell,-1,facing)]
 state.step(commands,[])
 if not check(state.units.size()==1,"Actual legal high-tile deployment"):return
 actor=state.units[0]
 # Only QA supplies ready SP; cast, shot release, arrival and retreat use real commands.
 for i in 35:state.step([],[])
 actor.sp=data.fiammetta.skills[skill].sp_required
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
func cast() -> void:
 var commands: Array[InputCommand]=[InputCommand.new(state.tick,1,"",actor.unit_id,Vector2i.ZERO,actor.skill_index)]
 state.step(commands,[]);sample()
func cleanup() -> void:
 view.queue_free();await process_frame
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()==1:output_path=args[0].trim_suffix("/")+"/"
 root.size=Vector2i(1280,720);root.content_scale_size=root.size
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path))
 for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
 for direction in 4:
  setup(direction);cast()
  if not check(actor.skill_ticks_left!=0,"S3 infinite duration is active"):quit(1);return
  check(view.original_vfx.clips.size()==4,"Only carried Fiammetta S3 source clips load")
  var first: AttackProjectile
  for i in 160:
   state.step([],[]);sample()
   for shot in state.attack_projectiles:
    if view.original_vfx.handles_projectile(shot):first=shot;break
   if first!=null:break
  if not check(first!=null,"S3 releases actual shell at empty fixed area"):quit(1);return
  check(first.target_cell==first.source_cell+AttackRange.rotate_offset(Vector2i(4,0),direction),"Real projectile snapshot supplies fixed center")
  check(view.original_vfx.emission_counts.get("fiammetta:start",0)==1 and view.original_vfx.emission_counts.get("fiammetta:hit",0)==1,"Exactly one cast and one scheduled blast per real shell")
  var due: int=first.arrival_tick
  for event in view.original_vfx.events:
   if event.key=="fiammetta:hit":check(event.tick==due and event.target==first.target_cell,"Blast uses actual arrival tick and fixed cell")
  var emitted: int=view.original_vfx.emitted_events
  var clock: float=view.original_vfx.visual_tick
  for i in 6:sample()
  check(emitted==view.original_vfx.emitted_events and clock==view.original_vfx.visual_tick,"Repeated/waiting observation does not replay or advance")
  for mirror in [false,true]:
   view.mirror_board=mirror;sample()
   await render("facing%d-mirror%d"%[direction,int(mirror)])
   for i in view.original_vfx.visible_events:check(view.original_vfx.pool[i].instance.transform.is_finite(),"Front/back muzzle transform remains finite under mirror")
  # Closing removes only attached effects. An already released area shell is independent.
  cast()
  check(actor.skill_ticks_left==0,"Actual toggle closes S3")
  check(view.original_vfx.events.all(func(e: Dictionary)->bool:return not e.anchor.begins_with("fiammetta_")),"Close removes both persistent layers")
  var retreat: Array[InputCommand]=[InputCommand.new(state.tick,2,"",actor.unit_id)]
  state.step(retreat,[]);sample()
  check(actor not in state.units,"Actual retreat removes caster")
  check(state.attack_projectiles.has(first),"Released shell survives caster close/retreat")
  while state.tick<=due+3:state.step([],[]);sample()
  await render("impact-after-retreat-%d"%direction)
  check(not state.attack_projectiles.has(first),"Simulation resolves its own shell on arrival")
  check(view.original_vfx.events.any(func(e: Dictionary)->bool:return e.key=="fiammetta:hit" and e.tick==due),"Scheduled blast survives caster removal")
  for i in 270:state.step([],[]);sample()
  check(view.original_vfx.events.is_empty() and view.original_vfx.visible_events==0,"Finite trails and blast expire; no attached leak")
  await render("expired-%d"%direction)
  cases.append({"facing":direction,"release_tick":first.release_tick,"arrival_tick":due,"target":[first.target_cell.x,first.target_cell.y]})
  await cleanup()
 setup(0);cast()
 var shot_orders: Dictionary={}
 for i in 315:
  state.step([],[]);sample()
  for shot in state.attack_projectiles:
   if view.original_vfx.handles_projectile(shot):shot_orders[shot.order_key]=true
 check(view.original_vfx.events.filter(func(e: Dictionary)->bool:return e.anchor.begins_with("fiammetta_")).size()==2,"Both infinite attached layers survive their baked loop horizons")
 check(view.original_vfx.emission_counts.get("fiammetta:start",0)==shot_orders.size(),"Sustained firing emits once per unique released shell")
 check(view.original_vfx.emission_counts.get("fiammetta:buff",0)==1 and view.original_vfx.emission_counts.get("fiammetta:buff_02",0)==1,"Looped geometry never re-emits activation")
 cast()
 for i in 300:state.step([],[]);sample()
 check(view.original_vfx.events.is_empty(),"Closing after a loop clears all finite tails")
 await cleanup()
 for skill in [0,1]:
  setup(0,skill)
  check(view.original_vfx.viewport==null and view.original_vfx.clips.is_empty(),"S1/S2 carry no S3 renderer or resources")
  await cleanup()
 FileAccess.open(output_path+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"cases":cases,"graphical":DisplayServer.get_name()!="headless","scope":"Actual source events, native transforms and optional real rendered direction/mirror, impact-after-retreat and expiry screenshots; no packaged build, performance or full-match claim."},"\t"))
 print("FIAMMETTA_ORIGINAL_VFX_", "FAIL" if failed else "OK", " real empty-area shells; fixed impact; 4 facing x mirror; wait; toggle; retreat; read-only hash; no S1/S2 load")
 quit(1 if failed else 0)
