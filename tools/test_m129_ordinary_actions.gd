extends SceneTree
const IDS := ["wildmane","gavial_alter","eunectes","chen_alter","goldenglow","mon3tr_operator","stainless","gladiia","muelsyse","mlynar","jessica_alter","fiammetta","dusk","titi","ling","shaw"]
class Canvas extends Node2D:
	var models := []
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("202833"))
		for i in models.size():
			var model: OperatorSpineVisual=models[i]
			var anchor := Vector2(85+(i%8)*160,230+(i/8)*330)
			var size := model.scale_for_row(64)
			if model.mesh.get_surface_count()>0:draw_mesh(model.mesh,model.texture,Transform2D(0,Vector2(size,size),0,anchor+model.anchor_offset(size)))
			draw_string(ThemeDB.fallback_font,anchor+Vector2(-72,25),IDS[i],HORIZONTAL_ALIGNMENT_LEFT,-1,12)
			draw_string(ThemeDB.fallback_font,anchor+Vector2(-72,44),model.clip,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("ebcb8b"))
var failures := 0
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/m129-research/ordinary-actions")
	var canvas := Canvas.new();root.add_child(canvas);var mat := ShaderMaterial.new();mat.shader=load("res://view/native_canvas.gdshader");canvas.material=mat
	for i in IDS.size():
		var model := OperatorSpineVisual.new();check(model.initialize(IDS[i]),"Init "+IDS[i]+" "+model.last_error);canvas.models.append(model)
	for facing in 4:
		for skill_index in 3:
			for phase in ["begin","attack","idle","end","control","birth"]:
				for i in IDS.size():
					var id: String=IDS[i];var model: OperatorSpineVisual=canvas.models[i]
					var carried := mini(skill_index,1) if id in ["wildmane","shaw"] else skill_index
					var unit := UnitState.new(i,0,id,Vector2i.ZERO,1000,0,30,facing,carried)
					unit.deployed_tick=-300;unit.skill_ticks_left=90;unit.skill_elapsed_ticks=3 if phase=="begin" else 60;unit.skill_activation_count=1
					unit.last_attack_tick=117 if phase=="attack" else -1
					var tick := 120.0
					# Observe a real inactive->active transition for each independent fixture.
					unit.skill_ticks_left=0;unit.skill_activation_count=0;model.prepare(unit,57,60)
					unit.skill_ticks_left=90;unit.skill_activation_count=1
					if phase=="end":model.prepare(unit,120,60);unit.skill_ticks_left=0;tick=123
					if phase=="control":unit.frozen_ticks_left=20
					if phase=="birth":unit.deployed_tick=120;unit.last_attack_tick=-1;unit.skill_ticks_left=0
					var ok := model.prepare(unit,tick,60)
					check(ok and (model.mesh.get_surface_count()==1 or (id=="mon3tr_operator" and carried==2 and phase=="end") or (phase=="birth" and id in ["gladiia","muelsyse","titi"])),"Actual pose "+id+" S"+str(carried+1)+" face"+str(facing)+" "+phase+" "+model.last_error)
					if phase=="birth" and id in ["gladiia","muelsyse","titi"]:check(model.prepare(unit,142,60) and model.mesh.get_surface_count()==1,"Native transparent birth becomes visible "+id)
					if id=="mon3tr_operator" and carried==2 and phase=="end":check(model.prepare(unit,141,60) and model.mesh.get_surface_count()==1,"Native return action becomes visible")
					if id=="mlynar" and phase=="idle":check(model.clip.begins_with("Skill_"),"Mlynar stays active sword stance")
					if id=="shaw" and phase=="begin":check(model.clip==("Skill_Down" if facing==1 else ("Skill_Up" if facing==3 else "Skill_Right")),"Shaw authored directional skill")
					if id=="mon3tr_operator" and carried==2 and phase=="attack":check(model.clip=="Skill_3_Loop" and model.view_index==0,"Monstr true melee front family for authored single facing")
				if facing in [0,3] and phase in ["attack","idle"]:
					canvas.queue_redraw();await process_frame;await process_frame
					if DisplayServer.get_name()!="headless":
						await RenderingServer.frame_post_draw
						check(root.get_texture().get_image().save_png("res://.godot/m129-research/ordinary-actions/s"+str(skill_index+1)+"-f"+str(facing)+"-"+phase+".png")==OK,"Screenshot")

	var roamer := OperatorSpineVisual.new();check(roamer.initialize("mlynar"),"Roamer native init")
	var inactive := UnitState.new(0,0,"mlynar",Vector2i.ZERO,1000,0,30,0,2);inactive.deployed_tick=-300;inactive.last_attack_tick=120
	check(roamer.prepare(inactive,121,60) and roamer.clip=="Idle","Mlynar inactive ignores recent attack clock and retains native noncombat idle")
	var bomb_model: OperatorSpineVisual=canvas.models[10]
	var bomb := UnitState.new(10,0,"jessica_alter",Vector2i.ZERO,1000,0,30,1,2);bomb.deployed_tick=-300;bomb.skill_ticks_left=90;bomb.skill_elapsed_ticks=60;bomb.skill_activation_count=2;bomb.jessica_bomb_tick=120
	check(bomb_model.prepare(bomb,123,60) and bomb_model.clip=="Skill_Down_3_Skill","Jessica actual bomb event selects authored downward free-bomb action")
	print("M129_ORDINARY_ACTIONS_OK failures=",failures);canvas.queue_free();quit(0 if failures==0 else 1)
