class_name BattleProps
extends RefCounted
# Original non-unit props; neither their meshes nor clocks participate in simulation.
const Player=preload("res://view/original_vfx_player.gd")
const TILE:=512
const FOOT:=Vector2(256,384)
const PATHS={"shadow":"res://assets/battle/props/ines_shadow/shadow.res","flag_02":"res://assets/battle/props/saileach_flag/flag_02.res","flag_03":"res://assets/battle/props/saileach_flag/flag_03.res"}
var viewport: SubViewport
var clips: Dictionary={}
var players: Array=[]
var quads: Array[ArrayMesh]=[]
var entries: Array[Dictionary]=[]
var visual_tick:=0.0
var warming:=false
var bottle_models: Dictionary={}
var _signature: int=-1
var _draw_index:=0
var _shadow_cells: Array[Vector2i]=[Vector2i(-1,-1),Vector2i(-1,-1)]
var _shadow_ticks: Array[float]=[0.,0.]

func attach(view: MatchView) -> void:
 var needed: Dictionary={}
 for side in 2:
  for index in view._state.squad_ids[side].size():
   var id: String=view._state.squad_ids[side][index]
   if id=="ines":needed.shadow=true
   if id=="saileach" and view._state.squad_skills[side][index]>0:needed["flag_02" if view._state.squad_skills[side][index]==1 else "flag_03"]=true
 if needed.is_empty():return
 for key in needed:clips[key]=load(PATHS[key])
 visual_tick=view._bone_tick
 viewport=SubViewport.new();viewport.size=Vector2i(TILE*2,TILE*2);viewport.transparent_bg=true;viewport.disable_3d=true;viewport.use_hdr_2d=false;viewport.world_2d=World2D.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;view.add_child(viewport)
 var stage:=Node2D.new();viewport.add_child(stage)
 for slot in 4:
  var player=Player.new();player.attach(stage);players.append(player)
  var mesh:=ArrayMesh.new();var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=PackedVector2Array([-FOOT,Vector2(TILE,0)-FOOT,Vector2(TILE,TILE)-FOOT,Vector2(0,TILE)-FOOT])
  var uv:=Vector2((slot%2)*.5,(slot/2)*.5)
  # +8 selects an already-premultiplied physical prop, without VFX highlight compression.
  arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([uv+Vector2(8,0),uv+Vector2(8.5,0),uv+Vector2(8.5,.5),uv+Vector2(8,.5)])
  arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3]);mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES);quads.append(mesh)

func sample(view: MatchView) -> void:
 _draw_index=0
 if warming:return
 if not view.get_tree().paused and not view.simulation_waiting:visual_tick=maxf(visual_tick,view.attack_visual_tick())
 entries.clear();sample_bottles(view)
 if viewport==null:
  entries.sort_custom(func(a,b):return a.anchor.y<b.anchor.y or (a.anchor.y==b.anchor.y and a.slot<b.slot))
  return
 var active: Dictionary={};var signatures: Array=[]
 for side in 2:
  var cell: Vector2i=view._state.sides[side].ines_shadow_cell
  if cell.x<0:_shadow_cells[side]=cell;continue
  if cell!=_shadow_cells[side]:_shadow_cells[side]=cell;_shadow_ticks[side]=visual_tick
  var anchor:=view.projection.cell_rect(cell).get_center()
  place(view,side,"shadow",maxf(0.,visual_tick-_shadow_ticks[side])/Config.TICK_RATE,anchor,row_width(view,cell),Color.WHITE,active,signatures)
 for unit in view._state.units:
  if unit.operator_id!="saileach" or unit.hp<=0 or unit.skill_ticks_left<=0 or unit.flag_cell.x<0:continue
  var skill: SkillResource=view._operator_data.saileach.skills[unit.skill_index]
  if skill.effect_type not in ["flag_heal","flag_burst"]:continue
  var anchor:=view.projection.cell_rect(SkillRules.flag_position(unit)).get_center()
  var fraction:=clampf(visual_tick-view._state.tick,0.,1.)
  if unit.flag_landing_ticks_left>0:
   var progress:=clampf(1.-(unit.flag_landing_ticks_left-fraction)/float(skill.effect_params.landing_ticks),0.,1.)
   anchor=view.renderer.unit_screen_center(view,unit).lerp(anchor,progress)-Vector2(0,sin(progress*PI)*view.PALETTE.CELL_SIZE*view.PALETTE.BOARD_ZOOM)
  var age:=maxf(0.,visual_tick-(view._state.tick-unit.skill_elapsed_ticks))/Config.TICK_RATE
  var tint:=Color(.42,.42,.42,1.) if unit.silence_ticks_left>0 else Color.WHITE
  place(view,unit.side+2,"flag_02" if unit.skill_index==1 else "flag_03",age,anchor,row_width(view,unit.flag_cell),tint,active,signatures)
 for slot in players.size():
  if not active.has(slot):players[slot].clear()
 entries.sort_custom(func(a,b):return a.anchor.y<b.anchor.y or (a.anchor.y==b.anchor.y and a.slot<b.slot))
 var signature:=hash(signatures)
 if signature!=_signature:viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if not entries.is_empty() else SubViewport.UPDATE_DISABLED;_signature=signature

func place(view: MatchView,slot: int,key: String,age: float,anchor: Vector2,width: float,tint: Color,active: Dictionary,signatures: Array) -> void:
 assert(clips.has(key),"Original prop not carried: "+key)
 assert(not active.has(slot),"Multiple original props in one side's fixed slot")
 var tile_origin:=Vector2((slot%2)*TILE,(slot/2)*TILE)
 var player=players[slot];player.presentation_gain=1.;player.sample(clips[key],age,0,tile_origin+FOOT,width,view.mirror_board,slot)
 active[slot]=true;entries.append({"slot":slot,"key":key,"anchor":anchor,"tint":tint,"age":age,"width":width})
 signatures.append([slot,player.frame.get_instance_id(),width,view.mirror_board,floori(age*30)])

func row_width(view: MatchView,cell: Vector2i) -> float:
 return (view.projection.board_point(Vector2(cell)+Vector2(1.5,.5))-view.projection.board_point(Vector2(cell)+Vector2(.5,.5))).length()

func draw_through(view: MatchView,depth: float,inclusive: bool=true) -> void:
 if warming:return
 while _draw_index<entries.size():
  var entry: Dictionary=entries[_draw_index]
  if entry.anchor.y>depth or (not inclusive and entry.anchor.y==depth):break
  if entry.has("model"):
   var model: OperatorSpineVisual=entry.model;var scale: float=entry.scale
   view.draw_set_transform(entry.anchor+model.anchor_offset(scale),0.,Vector2(-scale if view.mirror_board else scale,scale))
   if model.mesh.get_surface_count()>0:view.draw_mesh(model.mesh,model.texture,Transform2D.IDENTITY,entry.tint)
   view.draw_set_transform(Vector2.ZERO)
  else:view.draw_mesh(quads[entry.slot],viewport.get_texture(),Transform2D(0.,entry.anchor),entry.tint)
  _draw_index+=1

func prepare(view: MatchView) -> void:
 if viewport==null:return
 warming=true;var slot:=0
 for key in clips:
  players[slot].sample(clips[key],.7,0,Vector2((slot%2)*TILE,(slot/2)*TILE)+FOOT,70.,false,slot);slot+=1
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 await view.get_tree().process_frame;await RenderingServer.frame_post_draw
 for player in players:player.clear()
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;warming=false

func sample_bottles(view: MatchView) -> void:
 var live: Dictionary={}
 for bomb in view._state.champagne_bombs:
  # Preserve the existing impact ring; the native bottle Attack lasts six ticks.
  if bomb.triggered_tick>=0 and visual_tick-bomb.triggered_tick>=6.:continue
  live[bomb.bomb_id]=true
  if not bottle_models.has(bomb.bomb_id):
   var model:=OperatorSpineVisual.new()
   if not model.initialize("champagne_bottle"):
    push_error(model.last_error);view.get_tree().quit(1);return
   bottle_models[bomb.bomb_id]=model
  var model: OperatorSpineVisual=bottle_models[bomb.bomb_id]
  var unit:=UnitState.new(bomb.bomb_id,bomb.side,"champagne_bottle",bomb.cell,1,0,0,0)
  unit.deployed_tick=bomb.placed_tick;unit.last_attack_tick=bomb.triggered_tick
  if not model.prepare(unit,visual_tick,6):
   push_error(model.last_error);view.get_tree().quit(1);return
  var tint:=Color.WHITE if view._state.bomb_is_mature(bomb) else Color(.62,.62,.62,1.)
  entries.append({"slot":bomb.bomb_id+4,"anchor":view.projection.cell_rect(bomb.cell).get_center(),"key":"bottle","model":model,"scale":model.scale_for_row(row_width(view,bomb.cell)),"tint":tint})
 for id in bottle_models.keys():
  if not live.has(id):bottle_models.erase(id)
