extends SceneTree
const OUT="res://.ai/menu-summons-20261027/cards/"
const IDS=["curse_doll","dusk_freeling","flowing_shape","jessica_shield","ling_soul1","ling_soul2","ling_soul3","magallan_drone_a","magallan_drone_f","magallan_drone_l","medical_drone","mon3tr","mon3tr_reconstruction","nightingale_phantom","phantom_clone","pozyomka_typewriter","seaborn","silence_alter_drone","stainless_cannon","stainless_device_atk","stainless_device_sp","vigil_wolf","weedy_cannon"]
class Gallery extends Node2D:
 var operators: Array[OperatorData]=[]
 var mode:=0
 func _draw() -> void:
  draw_rect(Rect2(0,0,1280,720),Color("182029"))
  for i in operators.size():
   var pos:=Vector2(32+(i%6)*208,38+(i/6)*166)
   OperatorCardVisual.draw_battle(self,Rect2(pos,Vector2(98,116)),operators[i],0,5,mode==3,12 if mode==2 else 0,mode==1,"库存2")
   draw_string(ThemeDB.fallback_font,pos+Vector2(104,24),operators[i].operator_id,HORIZONTAL_ALIGNMENT_LEFT,98,11)
   draw_string(ThemeDB.fallback_font,pos+Vector2(104,44),["normal","unaffordable","cooldown","selected"][mode],HORIZONTAL_ALIGNMENT_LEFT,98,11)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,720);root.content_scale_size=root.size
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var canvas:=Gallery.new();var mat:=ShaderMaterial.new();mat.shader=load("res://view/native_canvas.gdshader");canvas.material=mat
 for id in IDS:
  var texture:=OperatorCardVisual.texture(id,true)
  if texture==null or texture.get_size()!=Vector2(180,180) or texture.resource_path!="res://assets/cards/%s/avatar.png"%id:push_error("Wrong original summon avatar "+id);quit(1);return
  canvas.operators.append(load("res://resources/summons/%s.tres"%id))
 canvas.operators.append(load("res://resources/operators/weedy.tres"));root.add_child(canvas)
 for mode in 4:
  canvas.mode=mode;canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OUT+["normal","unaffordable","cooldown","selected"][mode]+".png")
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"summon_avatars":IDS.size(),"actual_size":[98,116],"gallery_states":4,"ordinary_avatar_control":"weedy","scope":"Original asset paths, sizes and actual card drawing; real deployment tray/click coverage belongs to test_m129_summon_cards"},"\t"))
 canvas.queue_free();await process_frame;print("SUMMON_CARD_ASSETS_OK 23 originals x4 states");quit(0)
