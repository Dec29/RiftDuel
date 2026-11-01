extends SceneTree
const OUTPUT := "res://.godot/m129-final-graphics/squad"
const GROUPS := [["wildmane","gavial_alter","eunectes","chen_alter","goldenglow","mon3tr_operator","stainless","gladiia"],["muelsyse","mlynar","jessica_alter","fiammetta","dusk","titi","ling","shaw"]]
var original := PackedByteArray()
var had_saved := false
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	had_saved=FileAccess.file_exists(SquadConfig.FILE_PATH)
	if had_saved:original=FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
	var counts := {}
	for id in root.get_node("OperatorDB").all_ids():
		var data: OperatorData=root.get_node("OperatorDB").get_data(id)
		counts[data.profession_id]=counts.get(data.profession_id,0)+1
	for id in OperatorData.PROFESSION_IDS:
		if not check(counts[id]==13,"Each profession has13 operators"):return
	for group in GROUPS:
		var fixture := SquadConfig.new();fixture.operator_ids=PackedStringArray(group);fixture.skill_indices=PackedInt32Array([0,0,0,0,0,0,0,0])
		if not check(fixture.write().is_empty(),"Isolated squad fixture"):return
		change_scene_to_file("res://view/squad_menu.tscn");await process_frame;await process_frame
		var menu=current_scene
		for slot in 8:
			menu._open_slot(slot);await process_frame;await process_frame
			var operator: OperatorData=root.get_node("OperatorDB").get_data(group[slot])
			var third: Button=menu.get_node("Margin/Layout/Body/Picker/Details/Content/Skills/Skill3")
			if not check(third.disabled==(operator.skills.size()==2),"Actual third skill availability"):return
			for index in operator.skills.size():
				var button: Button=menu.get_node("Margin/Layout/Body/Picker/Details/Content/Skills/Skill%d"%(index+1))
				if not check(not button.disabled,"Actual skill enabled"):return
				button.pressed.emit();await process_frame
				var saved := SquadConfig.new()
				if not check(saved.read().is_empty() and saved.operator_ids==fixture.operator_ids and saved.skill_indices[slot]==index,"Actual choice persists"):return
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				if not check(root.get_texture().get_image().save_png(OUTPUT+"/squad-"+group[slot]+".png")==OK,"New portrait/detail screenshot"):return
			menu._show_overview();await process_frame
	restore_saved();print("M129_SQUAD_OK:104 ordinary/13 per profession,16 portraits/46 actual skill choices persist, user squad restored")
	quit(0)
func restore_saved() -> void:
	if had_saved:
		var file := FileAccess.open(SquadConfig.FILE_PATH,FileAccess.WRITE);file.store_buffer(original);file.close()
	elif FileAccess.file_exists(SquadConfig.FILE_PATH):DirAccess.remove_absolute(SquadConfig.FILE_PATH)
func check(value: bool,label: String) -> bool:
	if not value:restore_saved();push_error(label);quit(1)
	return value
