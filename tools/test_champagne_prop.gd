extends SceneTree
const OUT="res://.ai/menu-summons-20261027/champagne-prop/"
var failed:=false
var hash_checks:=0
var state: MatchState
var view: MatchView
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failed=true;push_error(label)
func step() -> void:
 for side in 2:state.sides[side].cost=99
 state.step([],[]);view._bone_tick=state.tick
func frame(label: String="") -> void:
 var before:=state.state_hash();view.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
 check(before==state.state_hash(),"Champagne rendering is read-only "+label);hash_checks+=1
 if not label.is_empty():root.get_texture().get_image().save_png(OUT+label+".png")
func run() -> void:
 root.size=Vector2i(1280,720);root.content_scale_size=root.size
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var data: Dictionary={}
 for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
 data.swire_alter=data.swire_alter.duplicate(true);data.swire_alter.max_health=1000000;data.swire_alter.attack=1
 var ids:=PackedStringArray(["swire_alter"]);var skills:=PackedInt32Array([1])
 state=MatchState.new(0x424f5454,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
 for side in 2:state.sides[side].cost=99
 state.step([InputCommand.new(0,0,"swire_alter",-1,Vector2i(13,5),-1,2)],[InputCommand.new(0,0,"swire_alter",-1,Vector2i(7,5),-1,0)])
 check(state.units.size()==2,"Real paired owner deployment")
 view=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
 check(view.original_props.viewport==null,"Bottle alone does not allocate the shadow/flag atlas")
 for i in 600:
  step()
  if i in [45,55,75,140,300,599]:await frame("tick-%03d"%i)
 check(state.champagne_bombs.size()>4 and view.original_props.bottle_models.size()==state.champagne_bombs.size(),"All live real bombs have native bottle meshes")
 var selected: ChampagneBomb=state.champagne_bombs[0]
 var center:=view.projection.cell_rect(selected.cell).get_center()
 for mirror in [true,false]:view.mirror_board=mirror;await frame("mirror-%d"%int(mirror))
 var clock: float=view.original_props.visual_tick;var pixels:=hash(root.get_texture().get_image().get_data())
 view.simulation_waiting=true;await frame();check(clock==view.original_props.visual_tick,"Waiting freezes bottle clock")
 paused=true;await frame();check(pixels==hash(root.get_texture().get_image().get_data()),"Paused native bottle pixels freeze");paused=false;view.simulation_waiting=false
 var frame_ms: Array[float]=[];var begin:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-begin<5000:
  view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
  frame_ms.append(root.get_process_delta_time()*1000.)
 frame_ms.sort()
 var performance: Dictionary={"actors":state.units.size(),"bottles":view.original_props.bottle_models.size(),"measured_seconds":5,"frames":frame_ms.size(),"fps":frame_ms.size()/5.,"frame_p95_ms":frame_ms[int(frame_ms.size()*.95)],"scope":"Real-time rendering of two owners and existing full trap field, frozen simulation; not combined battle/AI/network benchmark"}
 # QA enemy at the actual chosen trap; the existing merchant rule performs impact.
 var victim:=UnitState.new(state.next_unit_id,1-selected.side,"swire_alter",selected.cell,1000000,0,100000,0,1)
 state.next_unit_id+=1;state.units.append(victim);step()
 check(selected.triggered_tick>=0,"Actual existing trap rule triggered")
 await frame("impact")
 for i in 14:step()
 await frame("impact-ended");check(not view.original_props.bottle_models.has(selected.bomb_id),"Spent bottle mesh removed")
 var commands: Array=[[],[]]
 for unit in state.units:commands[unit.side].append(InputCommand.new(state.tick,2,"",unit.unit_id))
 var blue: Array[InputCommand]=[];blue.assign(commands[0]);var red: Array[InputCommand]=[];red.assign(commands[1]);state.step(blue,red);view._bone_tick=state.tick
 await frame("retreated")
 check(state.champagne_bombs.is_empty() and view.original_props.bottle_models.is_empty(),"Real owner retreat clears all models")
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"hash_checks":hash_checks,"performance":performance,"scope":"Actual paired S2 traps, native Start/Idle/Attack, maturity tint, mirror, pause/wait, impact and owner retreat; QA durability/cost and single impact target."},"\t"))
 view.queue_free();await process_frame;print("CHAMPAGNE_PROP_OK ",not failed," ",JSON.stringify(performance));quit(1 if failed else 0)
