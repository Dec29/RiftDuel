extends SceneTree

const IDS := ["mon3tr_reconstruction","ling_soul1","ling_soul2","ling_soul3","flowing_shape","jessica_shield","dusk_freeling","stainless_device_atk","stainless_device_sp","stainless_cannon"]
class VisualUnit extends UnitState:
	var _fixture_advanced := false
	func _get(property: StringName) -> Variant:
		return _fixture_advanced if property=="ling_advanced" else null
	func _set(property: StringName,value: Variant) -> bool:
		if property!="ling_advanced":return false
		_fixture_advanced=bool(value);return true
class Canvas extends Node2D:
	var models := []
	var units := []
	var mirrored := false
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("202833"))
		for i in models.size():
			var model: OperatorSpineVisual=models[i]
			var anchor := Vector2(130+(i%5)*250,275+(i/5)*310)
			draw_line(anchor-Vector2(90,0),anchor+Vector2(90,0),Color("5e9cd3"),2)
			var size: float = model.scale_for_row(88)
			var transform := Transform2D(0,Vector2(-size if mirrored else size,size),0,anchor+model.anchor_offset(size))
			if model.mesh.get_surface_count()>0:draw_mesh(model.mesh,model.texture,transform)
			draw_string(ThemeDB.fallback_font,anchor+Vector2(-105,35),IDS[i],HORIZONTAL_ALIGNMENT_LEFT,-1,15)
			draw_string(ThemeDB.fallback_font,anchor+Vector2(-105,58),model.clip+"  "+str(snappedf(model.pose_seconds,0.01))+"s",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ebcb8b"))
var failures := 0
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/m129-research/summon-visual")
	var canvas := Canvas.new();var mat := ShaderMaterial.new();mat.shader=load("res://view/native_canvas.gdshader");canvas.material=mat;root.add_child(canvas)
	for i in IDS.size():
		var model := OperatorSpineVisual.new();check(model.initialize(IDS[i]),"Native init "+IDS[i]+" "+model.last_error)
		var unit := VisualUnit.new(i,0,IDS[i],Vector2i(12,5),1000,0,30,0)
		canvas.models.append(model);canvas.units.append(unit)
	for mirrored in [false,true]:
		canvas.mirrored=mirrored
		for mode in ["idle","attack","variants","birth"]:
			for i in IDS.size():
				var unit: VisualUnit=canvas.units[i];var model: OperatorSpineVisual=canvas.models[i]
				unit.facing=3 if mirrored else 0;unit.last_attack_tick=-1;unit.deployed_tick=0;unit.set("ling_advanced",false);unit.flow_copy_id="";unit.flow_point_until_tick=0
				var time := 120.0
				if mode=="attack":unit.last_attack_tick=117
				if mode=="birth":time=0.0
				if mode=="variants":
					unit.set("ling_advanced",true);unit.last_attack_tick=117
					if IDS[i]=="flowing_shape":unit.flow_copy_id="silverash";unit.flow_melee=not mirrored
				var ok := model.prepare(unit,time,30)
				check(ok,"Native pose "+IDS[i]+" "+mode+" "+model.last_error)
				if mode!="birth":check(model.mesh.get_surface_count()==1,"Visible native geometry "+IDS[i]+" "+mode)
				if IDS[i]=="ling_soul3" and mode=="variants":check(model.clip=="Attack_02","Advanced Ling source clip")
			canvas.queue_redraw();await process_frame;await process_frame
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png("res://.godot/m129-research/summon-visual/"+mode+"-m"+str(int(mirrored))+".png")==OK,"Screenshot "+mode)
	var flow: VisualUnit=canvas.units[4];var fm: OperatorSpineVisual=canvas.models[4];flow.flow_point_until_tick=999;flow.flow_copy_id="exusiai"
	check(fm.prepare(flow,120,30),"Tactical point native static pose "+fm.last_error)
	check(fm.clip=="Idle_2","Tactical point uses actual Idle_2 static pose")
	print("M129_SUMMON_VISUAL_OK failures=",failures);canvas.queue_free();quit(0 if failures==0 else 1)
