class_name BattleOriginalVfx
extends RefCounted
# Render-only event cursors and pooled source clips. No rule callbacks or private battle state.
const Player=preload("res://view/original_vfx_player.gd")
const ROOTS={"weedy":"res://assets/battle/vfx/weedy_s3/","silverash":"res://assets/battle/vfx/silverash_s3/","eyjafjalla":"res://assets/battle/vfx/eyjafjalla_s3/","chen":"res://assets/battle/vfx/chen_s3/","ifrit":"res://assets/battle/vfx/ifrit_s3/","chen_alter":"res://assets/battle/vfx/chen_alter_s3/","surtr":"res://assets/battle/vfx/surtr_s3/","fiammetta":"res://assets/battle/vfx/fiammetta_s3/","mlynar":"res://assets/battle/vfx/mlynar_s3/"}
var viewport: SubViewport
var stage: Node2D
var clips: Dictionary={}
var cursors: Dictionary={}
var events: Array[Dictionary]=[]
var pool: Array=[]
var free_players: Array=[]
var sampling_mounts:=false
var use_drawn_poses:=false
var drawn_poses: Dictionary={}
var last_sample_usec:=0
var prepared_mounts: Dictionary={}
var mount_transforms: Dictionary={}
var live: Dictionary={}
var composite: ArrayMesh
var observed_tick: int=-1
var visual_tick:=0.0
var emitted_events:=0
var emission_counts: Dictionary={}
var visible_events:=0
var warming:=false
var last_signature: int=-1
var seen_projectiles: Dictionary={}
var chen_fields: Dictionary={}
var chen_payloads: Dictionary={}
var chen_bursts: Dictionary={}
var chen_affected: Dictionary={}

func attach(view: MatchView) -> void:
 # Only carried S3s can emit these resources. Other squads need no offscreen viewport.
 visual_tick=view._bone_tick
 var needed: Dictionary={}
 for side in 2:
  for index in view._state.squad_ids[side].size():
   if ROOTS.has(view._state.squad_ids[side][index]) and view._state.squad_skills[side][index]==2:needed[view._state.squad_ids[side][index]]=true
 if needed.is_empty():return
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.transparent_bg=true
 viewport.disable_3d=true
 viewport.use_hdr_2d=false
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 viewport.world_2d=World2D.new()
 view.add_child(viewport)
 stage=Node2D.new();viewport.add_child(stage)
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=PackedVector2Array([Vector2.ZERO,Vector2(1280,0),Vector2(1280,720),Vector2(0,720)])
 # +4 selects already-premultiplied RGBA without changing ordinary / native additive draws.
 arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(4,0),Vector2(5,0),Vector2(5,1),Vector2(4,1)])
 arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
 composite=ArrayMesh.new();composite.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
 for op in needed:
  var ids: Array={"weedy":["start","flight","hit","buff"],"silverash":["activate","slash","hit","aura"],"eyjafjalla":["buff","flight","hit","end"],"chen":["start","start_02","start_03","hit_01","hit_02","hit_03","hit_04","hit_05","hit_06","hit_07","hit_08","hit_09","hit_10"],"ifrit":["start","range","buff"],"chen_alter":["buff_01","buff_01_b","buff_02","buff_02_b","buff_03","buff_03_b","debuff","hit_01","range_01","start_01","start_01_b","start_02","start_02_b","start_03"],"surtr":["buff","buff_02","buff_03","buff_03_b","buff_04","buff_04_b","range","start","start_02","hit"],"fiammetta":["buff","buff_02","start","hit"],"mlynar":["buff_01","buff_02","buff_03","start_01","range_01","hit_01"]}[op]
  for id in ids:clips[op+":"+id]=load(ROOTS[op]+id+".res")
 visual_tick=view._bone_tick
 observe(view)

func emit(op: String,id: String,unit: UnitState,tick: int,anchor: String,speed: float=1.0) -> void:
 # A bounded pool is derived from visible source events, never from simulation RNG.
 emit_at(op,id,unit.unit_id,tick,unit.displacement_origin if unit.displacement_ticks_left>0 else unit.cell,Vector2i(unit.last_attack_target_x,unit.last_attack_target_y),unit.facing,anchor,speed)

func emit_at(op: String,id: String,unit_id: int,tick: int,origin: Vector2i,target: Vector2i,facing: int,anchor: String,speed: float=1.0) -> void:
 events.append({"key":op+":"+id,"unit_id":unit_id,"tick":tick,"origin":origin,"target":target,"facing":facing,"anchor":anchor,"speed":speed})
 emitted_events+=1
 emission_counts[op+":"+id]=int(emission_counts.get(op+":"+id,0))+1

func observe(view: MatchView) -> void:
 if viewport==null:return
 var state:=view._state
 if observed_tick==state.tick:return
 observed_tick=state.tick
 live.clear()
 for unit in state.units:
  if unit.hp<=0:continue
  live[unit.unit_id]=unit
  var op:=unit.operator_id
  if op=="weedy_cannon":op="weedy"
  if not ROOTS.has(op):continue
  var previous: Dictionary=cursors.get(unit.unit_id,{"activation":0,"attack":-1,"nitrogen":-1,"active":false,"chen_slash":-1,"windup":-1})
  var s3:=unit.skill_index==2 and unit.operator_id!="weedy_cannon"
  var active:=s3 and (unit.skill_ticks_left!=0 if op in ["chen_alter","surtr","fiammetta"] else unit.skill_ticks_left>0)
  if s3 and unit.skill_activation_count>previous.activation:
   if op=="silverash":
    emit(op,"activate",unit,state.tick-1,"source")
    emit(op,"aura",unit,state.tick-1,"attached")
   elif op=="eyjafjalla":emit(op,"buff",unit,state.tick-1,"attached")
   elif op=="chen":emit(op,"start",unit,unit.chen_cast_tick,"source")
   elif op=="chen_alter" and active:
    var cast_tick: int=state.tick-1
    emit(op,"buff_01",unit,cast_tick,"chen_attached")
    emit(op,"buff_02",unit,cast_tick,"chen_gun1")
    emit(op,"buff_03",unit,cast_tick,"chen_gun2")
   elif op=="surtr" and active:
    emit(op,"buff",unit,unit.launch_started_tick,"surtr_sword")
    emit(op,"buff_02",unit,unit.launch_started_tick,"surtr_ground")
    emit(op,"buff_03",unit,unit.launch_started_tick,"surtr_eye_left")
    emit(op,"buff_04",unit,unit.launch_started_tick,"surtr_eye_right")
   elif op=="fiammetta" and active:
    emit(op,"buff",unit,state.tick-1,"fiammetta_ground")
    emit(op,"buff_02",unit,state.tick-1,"fiammetta_muzzle")
   elif op=="mlynar":
    emit(op,"buff_02",unit,state.tick-1,"mlynar_ground")
    emit(op,"buff_03",unit,state.tick-1,"mlynar_ground")
   elif op=="ifrit":
    var cast_tick: int=state.tick-unit.skill_elapsed_ticks
    emit(op,"start",unit,cast_tick,"source")
    emit(op,"buff",unit,cast_tick,"ifrit_buff")
    events[-1].facing=0 # Source _rotateType=0 and _useBodyRotation=0; keep fixed billboard layers.
    for offset in view._operator_data[op].attack_range:
     var cell: Vector2i=unit.cell+AttackRange.rotate_offset(offset,unit.facing)
     if not view.projection.cell_is_inside(cell):continue
     emit(op,"range",unit,cast_tick,"ifrit_field")
     events[-1].origin=cell
     events[-1].facing=0 # Source range _rotateType=0; rotate cell offsets, not its fixed art.
  if op=="surtr" and active and unit.attack_action_clip=="Skill_3_Loop" and unit.attack_started_tick>int(previous.get("windup",-1)):
   var playback:=float(unit.attack_action_source_frames)/unit.attack_action_window_ticks
   emit(op,"start",unit,unit.attack_started_tick,"surtr_sword_burst",playback)
   events[-1]["windup"]=unit.attack_started_tick
   emit(op,"start_02",unit,unit.attack_started_tick+roundi(.35/playback*Config.TICK_RATE),"surtr_cast_ground",playback)
   events[-1]["windup"]=unit.attack_started_tick
  if op=="mlynar" and active and unit.attack_action_clip=="Skill_3_Loop" and unit.attack_started_tick>int(previous.get("windup",-1)):
   var playback:=1.2/(float(unit.attack_action_window_ticks)/Config.TICK_RATE)
   emit(op,"buff_01",unit,unit.attack_started_tick+roundi(.2/playback*Config.TICK_RATE),"mlynar_weapon")
   events[-1]["windup"]=unit.attack_started_tick
   emit(op,"start_01",unit,unit.attack_started_tick+roundi(.45/playback*Config.TICK_RATE),"mlynar_windup",playback)
   events[-1]["windup"]=unit.attack_started_tick
  if op=="eyjafjalla" and previous.active and not active:emit(op,"end",unit,state.tick-1,"source")
  if op=="chen" and s3 and unit.chen_slash_tick>previous.chen_slash:
   var count: int=view._operator_data[op].skills[2].effect_params["slash_count"]
   var ordinal: int=count-unit.chen_slashes_left
   assert(ordinal>=1 and ordinal<=count,"Chen actual slash ordinal outside resource family")
   emit(op,"hit_%02d"%ordinal,unit,unit.chen_slash_tick,"target")
   if ordinal==count:emit(op,"start_03",unit,unit.chen_slash_tick,"source")
  if op=="weedy" and unit.nitrogen_shot_tick>previous.nitrogen and unit.nitrogen_shot_tick==unit.last_attack_tick:
   emit(op,"start",unit,unit.nitrogen_shot_tick,"source",2.5)
   emit(op,"flight",unit,unit.nitrogen_shot_tick,"travel",2.5)
   emit(op,"hit",unit,projectile_arrival(state,unit),"target",2.0)
  elif op=="surtr" and active and unit.last_attack_tick>previous.attack and unit.last_attack_tick>=unit.launch_started_tick:
   emit(op,"hit",unit,unit.last_attack_tick,"target")
   emit(op,"range",unit,unit.last_attack_tick,"target")
  elif active and SkillRules.active_ticks(unit)>0 and unit.last_attack_tick>previous.attack:
   if op=="silverash":
    var interval:=float(SkillRules.attack_interval_ticks(unit,view._operator_data[unit.operator_id]))/Config.TICK_RATE
    emit(op,"slash",unit,unit.last_attack_tick,"source",1.6/minf(.5,interval*.8))
    emit(op,"hit",unit,unit.last_attack_tick,"target",2.5)
   elif op=="mlynar":
    var playback:=1.2/(float(unit.attack_action_window_ticks)/Config.TICK_RATE)
    emit(op,"range_01",unit,unit.last_attack_tick,"source",playback)
    emit(op,"hit_01",unit,unit.last_attack_tick,"target")
   elif op=="eyjafjalla":
    emit(op,"flight",unit,unit.last_attack_tick,"travel",2.0)
    emit(op,"hit",unit,projectile_arrival(state,unit),"target",2.0)
  cursors[unit.unit_id]={"activation":unit.skill_activation_count,"attack":unit.last_attack_tick,"nitrogen":unit.nitrogen_shot_tick,"active":active,"chen_slash":unit.chen_slash_tick,"windup":unit.attack_started_tick}
 observe_chen(view)
 observe_fiammetta_projectiles(state)
 # The existing trauma marker supplies the actual affected target and survives its source.
 for target in state.units:
  if target.hp<=0 or target.rupture_until_tick<=state.tick:continue
  var source: UnitState=live.get(target.rupture_source_id)
  if source==null or source.operator_id not in ["weedy","weedy_cannon"]:continue
  var present:=false
  for e in events:
   if e.anchor=="rupture" and e.unit_id==target.unit_id:present=true;break
  if not present:emit("weedy","buff",target,state.tick-1,"rupture")
 for id in cursors.keys():
  if not live.has(id):cursors.erase(id)

func observe_chen(view: MatchView) -> void:
 if not clips.has("chen_alter:range_01"):return
 var orders: Dictionary={}
 for shot in view._state.attack_projectiles:
  if shot.operator_id!="chen_alter" or shot.skill_index!=2 or not shot.active or not shot.attack_event:continue
  # Unit and object payloads mark their second damage differently; one visual impact per target/release.
  var impact_key:=Vector4i(shot.source_id,shot.release_tick,shot.kind,shot.target_id)
  orders[impact_key]=true
  if chen_payloads.has(impact_key):continue
  chen_payloads[impact_key]=true
  # Paired damage produces one splash; a live unit destination is sampled on arrival.
  emit_at("chen_alter","hit_01",shot.source_id,shot.arrival_tick,shot.source_cell,shot.target_cell,shot.facing,"target")
  if shot.kind==AttackIntent.TargetKind.UNIT:events[-1].impact_unit_id=shot.target_id
  if int(chen_bursts.get(shot.source_id,-1))<shot.release_tick:
   chen_bursts[shot.source_id]=shot.release_tick
   emit_at("chen_alter","start_01",shot.source_id,shot.release_tick,shot.source_cell,shot.target_cell,shot.facing,"chen_muzzle1")
   emit_at("chen_alter","start_02",shot.source_id,shot.release_tick,shot.source_cell,shot.target_cell,shot.facing,"chen_muzzle2")
   emit_at("chen_alter","start_03",shot.source_id,shot.release_tick,shot.source_cell,shot.target_cell,shot.facing,"chen_blast")
 for key in chen_payloads.keys():
  if not orders.has(key):chen_payloads.erase(key)
 chen_affected.clear()
 var present_fields: Dictionary={}
 var data: OperatorData=view._operator_data["chen_alter"]
 var offsets: Array[Vector2i]=data.skills[2].attack_range_override
 for field in view._state.chen_slimes:
  var key: int=field.get_instance_id();present_fields[key]=true
  var source: UnitState=live.get(field.source_id)
  if not chen_fields.has(key):
   if source==null or source.skill_index!=2 or field.cells.size()!=offsets.size():continue
   chen_fields[key]=true
   var origin: Vector2i=field.cells[offsets.find(Vector2i.ZERO)]
   # Refreshing the same actual area replaces its old visual layer, avoiding stacked brightness.
   for index in range(events.size()-1,-1,-1):
    if events[index].anchor=="chen_field" and events[index].unit_id==field.source_id and events[index].origin==origin and events[index].facing==source.facing:retire_event(index)
   var start: int=field.due_tick-int(data.skills[2].effect_params["field_ticks"])
   emit_at("chen_alter","range_01",field.source_id,start,origin,origin,source.facing,"chen_field")
   events[-1]["until"]=field.due_tick
  if not chen_fields.has(key):continue
  for target in live.values():
   if target.side!=field.side and target.cell in field.cells and target.chen_slime_defense_reduce>0 and view._state.terrain_at(target.cell)=="ground":chen_affected[target.unit_id]=true
 for key in chen_fields.keys():
  if not present_fields.has(key):chen_fields.erase(key)
 for target_id in chen_affected:
  var found:=false
  for event in events:
   if event.anchor=="chen_debuff" and event.unit_id==target_id:found=true;break
  if not found:emit("chen_alter","debuff",live[target_id],view._state.tick-1,"chen_debuff")

func chen_attachment(view: MatchView,unit: UnitState,gun: int,width: float) -> Transform2D:
 return mounted_attachment(view,unit,"Pazooka_A" if gun==1 else "Pazooka_A2",width,"Pazooka_U" if gun==1 else "Pazooka_U2")


func sample(view: MatchView) -> void:
 last_sample_usec=0
 var sample_started:=Time.get_ticks_usec()
 if viewport==null:return
 if warming:return
 observe(view)
 # Waiting can remove interpolation; retain the last visual sample instead of rewinding.
 visual_tick=maxf(visual_tick,view.attack_visual_tick())
 visible_events=0
 pool.clear()
 prepared_mounts.clear();mount_transforms.clear()
 sampling_mounts=true
 for event in events:
  if event.has("player"):event.player.instance.visible=false
 var signature: Array=[]
 for i in range(events.size()-1,-1,-1):
  var e: Dictionary=events[i]
  var clip: Resource=clips[e.key]
  var age: float=(visual_tick-e.tick)/Config.TICK_RATE*e.speed
  var attached: bool=e.anchor=="attached"
  var active:=true if e.anchor in ["source","travel","target","launch"] else live.has(e.unit_id)
  if attached and active:active=live[e.unit_id].skill_ticks_left>0
  if e.anchor in ["chen_attached","chen_gun1","chen_gun2","chen_muzzle1","chen_muzzle2"] and active:active=live[e.unit_id].skill_index==2 and live[e.unit_id].skill_ticks_left!=0
  if e.anchor in ["surtr_sword","surtr_ground","surtr_eye_left","surtr_eye_right","fiammetta_ground","fiammetta_muzzle"] and active:active=live[e.unit_id].skill_index==2 and live[e.unit_id].skill_ticks_left!=0
  if e.anchor.begins_with("mlynar_") and active:
   active=live[e.unit_id].skill_index==2 and live[e.unit_id].skill_ticks_left>0
   if active and e.has("windup"):active=live[e.unit_id].last_basic_interrupt_tick<int(e.windup)
  if e.anchor in ["surtr_sword_burst","surtr_cast_ground"] and active:active=live[e.unit_id].skill_ticks_left!=0 and live[e.unit_id].last_basic_interrupt_tick<int(e.windup)
  if e.anchor=="chen_debuff":active=chen_affected.has(e.unit_id)
  if e.anchor=="chen_field":active=visual_tick<e.until
  if e.anchor in ["ifrit_buff","ifrit_field"] and active:
   # Only a natural duration tail can outlive the active skill; death/retreat removes it.
   active=live[e.unit_id].skill_ticks_left>0 or visual_tick-e.tick>=roundi(clip.emission_seconds*Config.TICK_RATE)-1
  if e.anchor=="rupture" and active:active=live[e.unit_id].rupture_until_tick>view._state.tick
  if not active or (e.anchor!="rupture" and clip.loop_from_seconds<0 and age>=clip.duration_seconds):retire_event(i)
 for e in events:
  var unit: UnitState=live.get(e.unit_id)
  if e.anchor=="attached" and unit.silence_ticks_left>0:continue
  if e.anchor in ["ifrit_buff","ifrit_field"] and (unit.silence_ticks_left>0 or unit.stun_ticks_left>0 or unit.displacement_ticks_left>0):continue
  if e.anchor in ["chen_attached","chen_gun1","chen_gun2","chen_muzzle1","chen_muzzle2"] and (unit.silence_ticks_left>0 or unit.stun_ticks_left>0 or unit.displacement_ticks_left>0):continue
  if (e.anchor.begins_with("surtr_") or e.anchor.begins_with("fiammetta_") or e.anchor.begins_with("mlynar_")) and (unit.silence_ticks_left>0 or unit.displacement_ticks_left>0):continue
  if e.anchor in ["surtr_eye_left","surtr_eye_right"] and unit.facing==3:continue
  var clip_key: String=e.key
  if e.anchor in ["chen_attached","chen_gun1","chen_gun2","chen_muzzle1","chen_muzzle2"] and unit.facing==3:clip_key+="_b"
  var clip: Resource=clips[clip_key]
  var age: float=(visual_tick-e.tick)/Config.TICK_RATE*e.speed
  if age<0.0:continue
  if e.has("impact_unit_id") and not e.has("impact_point"):
   # Freeze a render-only landing point; later movement must not drag the completed splash.
   var destination: Vector2=view.renderer.unit_screen_center(view,live[e.impact_unit_id]) if live.has(e.impact_unit_id) else view.projection.cell_rect(e.target).get_center()
   var point:=view.projection.board_unproject(destination)
   if view.mirror_board:point.x=Config.GRID_COLUMNS-point.x
   e.impact_point=point
  if e.anchor=="rupture":age=fposmod(age,clip.emission_seconds)
  var origin:=view.projection.cell_rect(e.origin).get_center()
  if unit!=null and e.anchor in ["source","attached","rupture","ifrit_buff","mlynar_ground","mlynar_weapon","mlynar_windup","fiammetta_ground","fiammetta_muzzle","surtr_cast_ground"]:origin=view.renderer.unit_screen_center(view,unit)
  if e.anchor=="ifrit_field":origin=view.projection.cell_rect(e.origin,false).get_center()
  var target: Vector2=view.projection.board_point(e.impact_point) if e.has("impact_point") else view.projection.cell_rect(e.target).get_center()
  var width:=view.projection.cell_rect(e.origin).size.x
  if unit!=null and e.anchor in ["source","attached","rupture","ifrit_buff","mlynar_ground","mlynar_weapon","mlynar_windup","fiammetta_ground","fiammetta_muzzle","surtr_cast_ground"]:width=view.renderer.unit_row_width(view,unit)
  elif e.anchor=="target":width=view.projection.cell_rect(e.target).size.x
  elif e.anchor=="ifrit_field":width=(view.projection.board_point(Vector2(e.origin)+Vector2(1.5,.5))-view.projection.board_point(Vector2(e.origin)+Vector2(.5,.5))).length()
  var anchor: Vector2=target if e.anchor=="target" else origin
  if e.anchor=="travel":
   var progress:=clampf(age/clip.emission_seconds,0,1)
   # Source frames are already centred on their canonical projectile head.
   anchor=origin.lerp(target,progress)
  if not e.has("player"):
   if free_players.is_empty():
    var created=Player.new();created.attach(stage);e.player=created
   else:e.player=free_players.pop_back()
  var player=e.player
  pool.append(player)
  player.presentation_gain=view.PALETTE.ORIGINAL_VFX_TRAUMA_GAIN if e.key=="weedy:buff" else (view.PALETTE.ORIGINAL_VFX_ATTACHED_GAIN if e.anchor in ["attached","fiammetta_ground","fiammetta_muzzle","mlynar_ground"] else view.PALETTE.ORIGINAL_VFX_BURST_GAIN)
  var fixed: bool=e.anchor.begins_with("chen_") or e.anchor in ["surtr_sword","surtr_sword_burst","surtr_eye_left","surtr_eye_right","mlynar_weapon","fiammetta_muzzle"]
  player.sample(clip,age,0 if fixed else e.facing,anchor,width,view.mirror_board,roundi(anchor.y))
  if e.anchor in ["chen_attached","chen_debuff"]:
   anchor=view.renderer.unit_screen_center(view,unit);width=view.renderer.unit_row_width(view,unit)
   player.instance.transform=Transform2D(Vector2(-width if ((unit.facing==2 and e.anchor=="chen_attached")!=view.mirror_board) else width,0),Vector2(0,width),anchor)
  elif e.anchor in ["chen_gun1","chen_gun2","chen_muzzle1","chen_muzzle2"]:
   width=view.renderer.unit_row_width(view,unit)
   var gun:=1 if e.anchor in ["chen_gun1","chen_muzzle1"] else 2
   var bone:=chen_attachment(view,unit,gun,width)
   var flip: bool=(unit.facing==2)!=view.mirror_board
   var screen:=Transform2D(Vector2(-1 if flip else 1,0),Vector2.DOWN,view.renderer.unit_screen_center(view,unit))
   player.instance.transform=screen*Transform2D(bone.x*width,bone.y*width,bone.origin)
  elif e.anchor in ["chen_field","chen_blast"]:
   var center:=Vector2(e.origin)+Vector2(.5,.5)
   anchor=view.projection.board_point(center)
   var right:=view.projection.board_point(center+Vector2(AttackRange.rotate_offset(Vector2i.RIGHT,e.facing)))-anchor
   var down: Vector2=(view.projection.board_point(center+Vector2(AttackRange.rotate_offset(Vector2i.DOWN,e.facing)))-anchor)/.8660254
   player.instance.transform=Transform2D(right,down,anchor)
  elif e.anchor in ["surtr_sword","surtr_sword_burst","surtr_eye_left","surtr_eye_right","mlynar_weapon","fiammetta_muzzle"]:
   width=view.renderer.unit_row_width(view,unit)
   var bone: Transform2D
   if e.anchor=="mlynar_weapon":bone=mlynar_attachment(view,unit,width)
   elif e.anchor=="fiammetta_muzzle":bone=fiammetta_attachment(view,unit,width)
   else:bone=surtr_attachment(view,unit,e.anchor,width)
   var screen:=Transform2D(Vector2(-1 if ((unit.facing==2)!=view.mirror_board) else 1,0),Vector2.DOWN,view.renderer.unit_screen_center(view,unit))
   player.instance.transform=screen*Transform2D(bone.x*width,bone.y*width,bone.origin)
  elif e.key=="mlynar:buff_03":
   var center:=Vector2(e.origin)+Vector2(.5,.5)
   var foot:=view.projection.board_point(center)
   player.instance.transform=Transform2D(view.projection.board_point(center+Vector2.RIGHT)-foot,view.projection.board_point(center+Vector2.DOWN)-foot,foot)
  elif e.anchor=="surtr_ground":player.instance.position=view.renderer.unit_screen_center(view,unit)
  signature.append([player.frame.get_instance_id(),player.instance.transform,player.presentation_gain,floori(age*30)])
  visible_events+=1
 sampling_mounts=false
 var next_signature:=hash(signature)
 if next_signature!=last_signature:
  viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if visible_events>0 else SubViewport.UPDATE_DISABLED
  last_signature=next_signature
 last_sample_usec=Time.get_ticks_usec()-sample_started

func draw(view: MatchView,ball_center: Vector2) -> void:
 if visible_events==0:return
 var shader:=view.material as ShaderMaterial
 shader.set_shader_parameter("vfx_ball_center",ball_center)
 shader.set_shader_parameter("vfx_ball_radius",view.projection.cell_rect(view._state.ball.cell,false).size.x*view.PALETTE.ORIGINAL_VFX_BALL_CLEAR_RATIO)
 view.draw_mesh(composite,viewport.get_texture(),Transform2D.IDENTITY,Color(1,1,1,0.000001 if warming else view.PALETTE.ORIGINAL_VFX_GAIN))

func handles_attack(unit: UnitState) -> bool:
 if viewport==null:return false
 if unit.operator_id in ["weedy","weedy_cannon"]:return unit.nitrogen_shot_tick>=0 and unit.nitrogen_shot_tick==unit.last_attack_tick
 if unit.operator_id=="chen":return unit.chen_slashes_left>0 or unit.chen_slash_tick==unit.last_attack_tick
 if unit.operator_id in ["surtr","chen_alter","fiammetta"]:return unit.skill_index==2 and SkillRules.active_ticks(unit)!=0
 return unit.operator_id in ["silverash","eyjafjalla","mlynar","ifrit"] and unit.skill_index==2 and SkillRules.active_ticks(unit)>0

func prepare(view: MatchView) -> void:
 await view.original_props.prepare(view)
 if viewport==null:return
 # Exercise the actual offscreen blend paths before the match clock starts.
 # A tiny nonzero composite alpha avoids canvas culling the warmup draw.
 warming=true
 var warm: Array=[]
 for key in clips:
  var player=Player.new();player.attach(stage);warm.append(player)
 for age in [.15,.65,1.1]:
  var index:=0
  for key in clips:
   warm[index].sample(clips[key],minf(age,clips[key].duration_seconds-.04),0,Vector2(640,360),50,false,index)
   index+=1
  visible_events=1
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  view.queue_redraw()
  await view.get_tree().process_frame
  await RenderingServer.frame_post_draw
 for player in warm:player.dispose()
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 visible_events=0;warming=false

func projectile_arrival(state: MatchState, unit: UnitState) -> int:
 for shot in state.attack_projectiles:
  if shot.source_id==unit.unit_id and shot.release_tick==unit.last_attack_tick:return shot.arrival_tick
 assert(false,"Released native projectile has no simulation payload: "+unit.operator_id)
 return -1

func surtr_attachment(view: MatchView,unit: UnitState,anchor: String,width: float) -> Transform2D:
 if anchor in ["surtr_sword","surtr_sword_burst"]:return mounted_attachment(view,unit,"F_Rb_Weapon2",width,"B_Rb_Weapon2")
 return mounted_attachment(view,unit,"F_Face_Default_j" if anchor=="surtr_eye_left" else "F_Face_Default_k",width)


func handles_projectile(shot: AttackProjectile) -> bool:
 return clips.has("fiammetta:start") and shot.operator_id=="fiammetta" and shot.skill_index==2 and shot.active and not shot.silenced


func observe_fiammetta_projectiles(state: MatchState) -> void:
 var retained: Dictionary={}
 for shot in state.attack_projectiles:
  if not handles_projectile(shot):continue
  retained[shot.order_key]=true
  if seen_projectiles.has(shot.order_key):continue
  # The release snapshot remains valid after close/retreat; one area shell, one blast.
  for id in ["start","hit"]:
   events.append({"key":"fiammetta:"+id,"unit_id":shot.source_id,"tick":shot.release_tick if id=="start" else shot.arrival_tick,"origin":shot.source_cell,"target":shot.target_cell,"facing":shot.facing,"anchor":"launch" if id=="start" else "target","speed":1.0})
   emitted_events+=1
   emission_counts["fiammetta:"+id]=int(emission_counts.get("fiammetta:"+id,0))+1
 seen_projectiles=retained


func fiammetta_attachment(view: MatchView,unit: UnitState,width: float) -> Transform2D:
 return mounted_attachment(view,unit,"F_Muzzle",width,"B_Muzzle")


func mlynar_attachment(view: MatchView,unit: UnitState,width: float) -> Transform2D:
 return mounted_attachment(view,unit,"F_Weapon3",width,"B_Weapon2")


func retire_event(index: int) -> void:
 var event: Dictionary=events[index]
 if event.has("player"):
  event.player.clear();free_players.append(event.player)
 events.remove_at(index)

func mounted_attachment(view: MatchView,unit: UnitState,bone: String,width: float,back_bone: String="") -> Transform2D:
 var key:=str(unit.unit_id)+"/"+bone+"/"+str(width)
 if sampling_mounts and mount_transforms.has(key):return mount_transforms[key]
 if not view._bagpipe_models.has(unit.unit_id):
  var created:=OperatorSpineVisual.new()
  if not created.initialize(unit.operator_id):push_error(created.last_error);view.get_tree().quit(1);return Transform2D.IDENTITY
  view._bagpipe_models[unit.unit_id]=created
 var model: OperatorSpineVisual=view._bagpipe_models[unit.unit_id]
 if not (use_drawn_poses and drawn_poses.has(unit.unit_id)) and (not sampling_mounts or not prepared_mounts.has(unit.unit_id)):
  if not model.prepare(unit,view.attack_visual_tick(),SkillRules.attack_interval_ticks(unit,view._operator_data[unit.operator_id])):push_error(model.last_error);view.get_tree().quit(1);return Transform2D.IDENTITY
  if sampling_mounts:prepared_mounts[unit.unit_id]=true
 # Attack snapshots can retain their original side even if current facing changes.
 var transform:=model.bone_attachment(back_bone if model.view_index==1 and not back_bone.is_empty() else bone,width)
 if sampling_mounts:mount_transforms[key]=transform
 return transform
