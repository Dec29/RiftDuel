extends SceneTree
var original:=PackedByteArray()
var existed:=false
var output:="res://.ai/skill-memory-20261031"
func _initialize() -> void:call_deferred("run")
func finish(code: int) -> void:
	if existed:
		var f:=FileAccess.open(SquadConfig.FILE_PATH,FileAccess.WRITE);f.store_buffer(original);f.close()
	elif FileAccess.file_exists(SquadConfig.FILE_PATH):DirAccess.remove_absolute(SquadConfig.FILE_PATH)
	quit(code)
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);finish(1)
	return ok
func run() -> void:
	existed=FileAccess.file_exists(SquadConfig.FILE_PATH)
	if existed:original=FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():output=args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var backup:=FileAccess.open(output+"/original-squad.bin",FileAccess.WRITE);backup.store_buffer(original);backup.close()
	var path:=output+"/legacy.cfg"
	var cfg:=ConfigFile.new();cfg.set_value("squad","version",2);cfg.set_value("squad","operators",PackedStringArray(["bagpipe"]));cfg.set_value("squad","skills",PackedInt32Array([2]));cfg.save(path)
	var legacy:=SquadConfig.new()
	if not check(legacy.read(path).is_empty() and legacy.skill_memory.bagpipe==2,"version2 without memory seeds currently carried skill"):return
	legacy.operator_ids=PackedStringArray(["myrtle"]);legacy.skill_indices=PackedInt32Array([1]);legacy.write(path)
	var reload:=SquadConfig.new()
	if not check(reload.read(path).is_empty() and reload.skill_memory.bagpipe==2 and reload.skill_memory.myrtle==1,"removed operator remembered across read/write"):return
	for bad in [{"bagpipe":3},{"myrtle":2},{"unknown":0},{"bagpipe":1.5},[]]:
		if not check(not SquadConfig.validate_memory(bad).is_empty(),"invalid memory rejected"):return
	cfg=ConfigFile.new();cfg.set_value("squad","operators",PackedStringArray(["bagpipe"]));cfg.save(path)
	if not check(legacy.read(path).is_empty() and legacy.skill_indices[0]==0,"version1 migration remains supported"):return
	var fixture:=SquadConfig.new();fixture.operator_ids=PackedStringArray(["bagpipe"]);fixture.skill_indices=PackedInt32Array([2]);fixture.write()
	var menu=load("res://view/squad_menu.tscn").instantiate();menu.embedded=true;root.add_child(menu)
	menu._open_slot(0);menu._select_operator("exusiai");menu._open_slot(0);menu._select_operator("bagpipe")
	if not check(menu.draft_skills[0]==2,"ordinary replace-away and return remembers skill"):return
	menu._open_slot(0);menu.get_node("Margin/Layout/Actions/Remove").pressed.emit();menu._open_slot(0);menu._select_operator("bagpipe")
	if not check(menu.draft_skills[0]==2,"remove then add restores remembered skill"):return
	menu.quick_button.pressed.emit();menu._preview("bagpipe");menu._select_skill(1);menu._select_operator("bagpipe");menu._select_operator("bagpipe")
	if not check(menu.draft_skills[0]==1,"quick remove/readd preserves pending skill"):return
	menu._request_back();menu.quick_button.pressed.emit();menu._preview("bagpipe")
	if not check(menu.draft_skills[0]==2 and menu.preview_skill==2,"quick cancel discards skill memory edits"):return
	menu._select_skill(1);menu._select_operator("bagpipe");menu.quick_confirm.pressed.emit();menu.queue_free();await process_frame
	menu=load("res://view/squad_menu.tscn").instantiate();menu.embedded=true;root.add_child(menu);menu._open_slot(0);menu._select_operator("bagpipe");menu._open_slot(0)
	if not check(menu.draft_skills[0]==1,"quick confirmed preference persists while absent and after menu reload"):return
	var buttons: HBoxContainer=menu.get_node("Margin/Layout/Body/Picker/Details/Content/Skills")
	for button in buttons.get_children():
		if not check(button.text.is_empty() and button.icon!=null,"skills show only icons"):return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/memory-icons.png")
	menu.queue_free();await process_frame
	print("SKILL_MEMORY_OK legacy v1/v2, persisted absent operators, invalid memory, normal replace/remove/readd, quick pending/cancel/confirm, reopen, icon-only buttons; original squad restored")
	finish(0)
