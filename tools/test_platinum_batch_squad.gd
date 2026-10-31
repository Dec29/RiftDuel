extends SceneTree
const OUTPUT := "res://.godot/platinum-four-view-evidence"
var original := PackedByteArray()
var had_saved := false
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	had_saved=FileAccess.file_exists(SquadConfig.FILE_PATH)
	if had_saved:original=FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
	var restore := FileAccess.open(OUTPUT+"/squad-restore.json",FileAccess.WRITE)
	restore.store_string(JSON.stringify({"path":ProjectSettings.globalize_path(SquadConfig.FILE_PATH),"existed":had_saved,"bytes":Marshalls.raw_to_base64(original)}));restore.close()
	var fixture := SquadConfig.new();fixture.operator_ids=PackedStringArray(["platinum","specter","perfumer","cuora"]);fixture.skill_indices=PackedInt32Array([0,0,0,0])
	if not check(fixture.write().is_empty(),"Isolated squad fixture"):return
	change_scene_to_file("res://view/squad_menu.tscn");await process_frame;await process_frame
	var menu=current_scene
	for slot in 4:
		menu._open_slot(slot);await process_frame;await process_frame
		var absent: Button=menu.get_node("Margin/Layout/Body/Picker/Details/Content/Skills/Skill3")
		if not check(absent.disabled,"No fabricated third skill"):return
		for index in 2:
			var button: Button=menu.get_node("Margin/Layout/Body/Picker/Details/Content/Skills/Skill%d"%(index+1))
			if not check(not button.disabled,"All eight skill choices enabled"):return
			button.pressed.emit();await process_frame
			var saved := SquadConfig.new()
			if not check(saved.read().is_empty() and saved.operator_ids==fixture.operator_ids and saved.skill_indices[slot]==index,"Actual button persists carried skill"):return
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			if not check(root.get_texture().get_image().save_png(OUTPUT+"/squad-"+fixture.operator_ids[slot]+".png")==OK,"Native portrait and skill detail screenshot"):return
		menu._show_overview();await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		if not check(root.get_texture().get_image().save_png(OUTPUT+"/squad-four-overview.png")==OK,"Four portraits overview"):return
	restore_saved();print("PLATINUM_BATCH_SQUAD_OK: all8 actual skill buttons persist; original user squad restored")
	quit(0)
func restore_saved() -> void:
	if had_saved:
		var file := FileAccess.open(SquadConfig.FILE_PATH,FileAccess.WRITE);file.store_buffer(original);file.close()
	elif FileAccess.file_exists(SquadConfig.FILE_PATH):DirAccess.remove_absolute(SquadConfig.FILE_PATH)
func check(value: bool,label: String) -> bool:
	if not value:restore_saved();push_error(label);quit(1)
	return value
