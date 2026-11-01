extends SceneTree
class Gallery extends Node2D:
 var models: Array[OperatorSpineVisual]=[]
 var labels: Array[String]=[]
 func _draw() -> void:
  draw_rect(Rect2(0,0,1440,1040),Color("202833"))
  for i in models.size():
   var model:=models[i];var anchor:=Vector2(240+(i%3)*480,130+(i/3)*170)
   var scale:=model.scale_for_row(80)
   if model.mesh.get_surface_count()>0:draw_mesh(model.mesh,model.texture,Transform2D(0,Vector2(scale,scale),0,anchor+model.anchor_offset(scale)))
   draw_string(ThemeDB.fallback_font,anchor+Vector2(-210,30),labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,13)
   draw_string(ThemeDB.fallback_font,anchor+Vector2(-210,49),model.clip+" @ "+str(snappedf(model.pose_seconds,.001)),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ebcb8b"))
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1440,1040);root.content_scale_size=Vector2i(1440,1040)
 var content: Dictionary={};var db=root.get_node("OperatorDB")
 for id in db.all_ids():content[id]=db.get_data(id)
 var state:=MatchState.new(22,content)
 var specs: Array=[["weedy",2,"normal"],["gnosis",0,"normal"],["mountain",2,"normal"],["amiya",1,"normal"],["chen",0,"normal"],["bagpipe",2,"normal"],["mon3tr",0,"meltdown"],["ling_soul3",0,"advanced"],["flowing_shape",0,"ranged_copy"],["nian",0,"normal"],["typhon",1,"permanent"],["saria",0,"heal"]]
 var output:="res://.ai/attack-timing-20261024/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var count:=0
 for facing in [0,3]:
  for page in 2:
   var canvas:=Gallery.new();root.add_child(canvas)
   var material:=ShaderMaterial.new();material.shader=load("res://view/native_canvas.gdshader");canvas.material=material
   for row in 6:
    var spec: Array=specs[page*6+row];var id: String=spec[0]
    var source:=UnitState.new(0,0,id,Vector2i(11,5),10000,0,0,facing,spec[1]);source.deployed_tick=-300;source.skill_ticks_left=1000
    var target:=UnitState.new(1,1,"hoshiguma",Vector2i(12,5),100000)
    if spec[2]=="meltdown":source.mon3tr_mode=3
    elif spec[2]=="advanced":source.ling_advanced=true
    elif spec[2]=="ranged_copy":source.flow_copy_id="exusiai";source.flow_melee=false
    elif spec[2]=="permanent":source.skill_repeat_activation_count=2
    state.units=[source,target];state.tick=100
    var chosen: Array[UnitState]=[target];AttackTimeline.begin(state,source,state._operator_data[id],chosen,null,false,spec[2]=="heal")
    var intent:=source.attack_intent
    for phase in 3:
     var model:=OperatorSpineVisual.new()
     if not model.initialize(id):push_error(model.last_error);quit(1);return
     var tick:=maxf(100.0,intent.release_tick-.05) if phase==0 else (float(intent.release_tick)+.8 if phase==1 else 100.0+intent.window_ticks+60)
     source.attack_intent=intent if tick<intent.release_tick else null
     var before:=state.state_hash()
     if not model.prepare(source,tick,intent.interval_ticks) or before!=state.state_hash():push_error("Gallery pose/hash "+id+" "+model.last_error);quit(1);return
     canvas.models.append(model);canvas.labels.append(id+" S"+str(spec[1]+1)+" "+spec[2]+" / "+["before release","after release","idle"][phase]);count+=1
   canvas.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
   var result:=root.get_texture().get_image().save_png(output+"gallery-f"+str(facing)+"-p"+str(page)+".png")
   if result!=OK:push_error("Cannot save gallery");quit(1);return
   canvas.queue_free();await process_frame;await process_frame
 print("ATTACK_FAMILY_GALLERY_OK poses=",count," front/back skill/summon/heal before/after/idle; native rendered fixtures, not full match")
 quit(0)
