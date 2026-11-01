extends SceneTree
const PREF := preload("res://preferences.gd")
var failures := 0
var original := PackedByteArray()
var existed := false
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func key(code: int, ctrl: bool=false) -> InputEventKey:
	var event := InputEventKey.new();event.keycode=code;event.pressed=true;event.ctrl_pressed=ctrl;return event
func run() -> void:
	existed=FileAccess.file_exists(PREF.FILE_PATH)
	if existed:original=FileAccess.get_file_as_bytes(PREF.FILE_PATH)
	var pref := PREF.new()
	check(Hotkeys.matches(key(KEY_SPACE),pref.hotkeys,"skill"),"Legacy defaults retain Space skill")
	check(Hotkeys.validation_error({"skill":KEY_Q,"retreat":KEY_Q,"cancel":KEY_ESCAPE})!="","Duplicate bindings rejected")
	check(Hotkeys.validation_error({"skill":KEY_ESCAPE,"retreat":KEY_R,"cancel":KEY_C})!="","Esc reserved for safe cancellation")
	check(Hotkeys.validation_error({"skill":KEY_Q,"retreat":-1,"cancel":KEY_ESCAPE})!="","Primary click cannot be rebound")
	check(Hotkeys.validation_error({"skill":1<<45,"retreat":KEY_R,"cancel":KEY_ESCAPE})!="","Malformed codes rejected")
	check(Hotkeys.validation_error({"skill":1,"retreat":KEY_R,"cancel":KEY_ESCAPE})!="","Unknown stored key codes rejected")
	var held := key(KEY_Q);held.echo=true;check(Hotkeys.event_code(held)==0,"Held key does not repeat commands")
	pref.hotkeys.skill=KEY_Q|KEY_MASK_CTRL;pref.hotkeys.retreat=KEY_R
	check(pref.write("user://hotkeys-test.cfg").is_empty(),"Custom binding saves")
	var loaded := PREF.new();check(loaded.read("user://hotkeys-test.cfg").is_empty() and loaded.hotkeys==pref.hotkeys,"Key and modifier round trip")
	check(Hotkeys.matches(key(KEY_Q,true),loaded.hotkeys,"skill") and not Hotkeys.matches(key(KEY_Q),loaded.hotkeys,"skill"),"Modifiers required exactly")
	var legacy := ConfigFile.new();legacy.set_value("display","goal_position","right");legacy.save("user://hotkeys-test.cfg")
	check(loaded.read("user://hotkeys-test.cfg").is_empty() and loaded.hotkeys==Hotkeys.DEFAULT,"Legacy file acquires defaults even on reused object")
	pref=PREF.new();check(pref.write().is_empty(),"Isolated defaults established")
	change_scene_to_file("res://view/settings_menu.tscn");await process_frame;await process_frame
	var menu := current_scene
	check(menu.get_node("Center/Panel/Tabs").get_tab_count()==4,"Keys is fourth settings tab")
	menu.get_node("Center/Panel/Tabs").current_tab=3
	menu._key_buttons.skill.pressed.emit();menu._input(key(KEY_Q))
	check(menu.preferences.hotkeys.skill==KEY_Q,"Button captures custom skill key")
	menu._key_buttons.retreat.pressed.emit();menu._input(key(KEY_Q))
	check(menu._capture_action=="retreat" and menu.preferences.hotkeys.retreat==-2,"Conflict keeps old binding and capture active")
	menu._input(key(KEY_R));check(menu.preferences.hotkeys.retreat==KEY_R,"Capture accepts corrected key")
	menu._key_buttons.cancel.pressed.emit();menu._input(key(KEY_ESCAPE));check(menu.preferences.hotkeys.cancel==KEY_ESCAPE,"Escape cancels capture")
	var disk := PREF.new();disk.read();check(disk.hotkeys==Hotkeys.DEFAULT,"Draft changes do not persist before Save")
	menu.get_node("Center/Panel/Tabs/Keys/Reset").pressed.emit();check(menu.preferences.hotkeys==Hotkeys.DEFAULT,"Restore defaults updates draft")
	menu._key_buttons.skill.pressed.emit();menu._input(key(KEY_Q))
	menu._key_buttons.retreat.pressed.emit();menu._input(key(KEY_R))
	menu._save();await process_frame;await process_frame
	check(disk.read().is_empty() and disk.hotkeys.skill==KEY_Q and disk.hotkeys.retreat==KEY_R,"Save persists new bindings")
	var operator: OperatorData=root.get_node("OperatorDB").get_data("bagpipe")
	var state := MatchState.new(15,{"bagpipe":operator},MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[PackedStringArray(["bagpipe"]),PackedStringArray(["bagpipe"])],[PackedInt32Array([0]),PackedInt32Array([0])])
	var unit := UnitState.new(0,0,"bagpipe",Vector2i(13,5),operator.max_health,99,0,2);state.units.append(unit);state.next_unit_id=1
	var input := LocalInput.new(0);var view := MatchView.new();root.add_child(view);view.bind(state,input,{"bagpipe":operator})
	var before := state.state_hash();input.select_unit(0)
	view._unhandled_input(key(KEY_SPACE));check(input.take_commands().is_empty(),"Old Space shortcut inactive after rebinding")
	view._unhandled_input(key(KEY_Q));var commands := input.take_commands()
	check(commands.size()==1 and commands[0].kind==InputCommand.Kind.SKILL and state.state_hash()==before,"New skill shortcut only queues input")
	view._unhandled_input(key(KEY_R));commands=input.take_commands()
	check(commands.size()==1 and commands[0].kind==InputCommand.Kind.RETREAT and commands[0].unit_id==0 and state.state_hash()==before,"Keyboard retreat acts on selected own unit without changing simulation")
	view._key_preferences.hotkeys.retreat=-MOUSE_BUTTON_MIDDLE
	var mouse := InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_MIDDLE;mouse.pressed=true;mouse.position=view.projection.cell_rect(unit.cell).get_center()
	view._unhandled_input(mouse);commands=input.take_commands();check(commands.size()==1 and commands[0].kind==InputCommand.Kind.RETREAT,"Rebound mouse shortcut uses pointed unit")
	input.select_unit(0);view._unhandled_input(key(KEY_ESCAPE));check(input.selected_unit_id==-1 and input.take_commands().is_empty(),"Cancel is local and does not retreat")
	check(view.hotkey_label("skill")=="Q","Live skill hint uses binding")
	if DisplayServer.get_name()!="headless":
		change_scene_to_file("res://view/settings_menu.tscn");await process_frame;await process_frame;current_scene.get_node("Center/Panel/Tabs").current_tab=3;await process_frame
		root.get_texture().get_image().save_png("res://.godot/hotkeys-settings.png")
	view.queue_free()
	if existed:
		var file := FileAccess.open(PREF.FILE_PATH,FileAccess.WRITE);file.store_buffer(original);file.close()
	else:DirAccess.remove_absolute(ProjectSettings.globalize_path(PREF.FILE_PATH))
	check(FileAccess.get_file_as_bytes(PREF.FILE_PATH)==original if existed else not FileAccess.file_exists(PREF.FILE_PATH),"User preferences restored byte for byte")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://hotkeys-test.cfg"))
	print("HOTKEYS_OK: legacy/save/draft/reset/conflict/modifiers, keyboard+mouse actual battle input, read-only state, preferences restored" if failures==0 else "HOTKEYS_FAILED%d"%failures)
	quit(0 if failures==0 else 1)
