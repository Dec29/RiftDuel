extends SceneTree

var failures := 0
var original := PackedByteArray()
var had_saved := false
var evidence := "res://.ai/solo-support-20261030"

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames() -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(evidence.path_join(name+".png")) == OK,"capture"+name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	had_saved = FileAccess.file_exists(SquadConfig.FILE_PATH)
	if had_saved:
		original = FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)
		var backup := FileAccess.open(evidence.path_join("squad-original.cfg"),FileAccess.WRITE)
		backup.store_buffer(original)
	var squad := SquadConfig.new()
	squad.operator_ids = PackedStringArray(["bagpipe","blaze"])
	squad.skill_indices = PackedInt32Array([0,0])
	check(squad.write().is_empty(),"prepare reversible squad fixture")
	change_scene_to_file("res://view/start_menu.tscn")
	await frames()
	current_scene.get_node("Menu/SinglePlayer").pressed.emit()
	await frames()
	var solo = current_scene
	check(solo.scene_file_path == "res://solo_setup.tscn" and solo.rules.mode == "score","single entry opens score preparation")
	var panel: Control = solo.get_node("RoomView/Center/Panel")
	check(root.get_visible_rect().encloses(panel.get_global_rect()),"solo layout fits viewport")
	capture("solo-score")
	panel.get_node("Room/Columns/Rules/Mode/Single").pressed.emit()
	panel.get_node("Room/Columns/Rules/MinutesRow/Minutes").value = 3
	panel.get_node("Room/ReadyRow/Squad").pressed.emit()
	await frames()
	var editor: Control = solo._squad_editor
	check(editor != null and editor.embedded and not solo.get_node("RoomView").visible,"embedded squad keeps preparation alive")
	editor.draft = PackedStringArray(["bagpipe","nightingale"])
	editor.draft_skills = PackedInt32Array([1,2])
	editor._save()
	editor._back()
	await frames()
	check(current_scene == solo and solo.rules.mode == "single" and solo.rules.minutes == 3 and solo._squad_editor == null,"back preserves chosen rules")
	panel.get_node("Room/Columns/Rules/Mode/Score").pressed.emit()
	panel.get_node("Room/ReadyRow/Start").pressed.emit()
	await frames()
	var battle = current_scene
	check(battle.match_state.rules.mode == "score" and battle.match_state.rules.minutes == 3 and battle.match_state.squad_ids[0] == PackedStringArray(["bagpipe","nightingale"]) and battle.match_state.squad_skills[0] == PackedInt32Array([1,2]),"selected solo rules and updated skills reach mirror battle")
	battle.set_physics_process(false)
	change_scene_to_file("res://lobby.tscn")
	await frames()
	var lobby = current_scene
	panel = lobby.get_node("RoomView/Center/Panel")
	panel.get_node("Mode").select(1)
	panel.get_node("Mode").item_selected.emit(1)
	panel.get_node("Create").pressed.emit()
	var session: NetSession = lobby.session
	var code := session.room_code
	var guest := NetSession.new(root.get_node("OperatorDB").network_content())
	root.add_child(guest)
	guest.join_address("127.0.0.1",code,NetSession.PORT)
	var deadline := Time.get_ticks_msec()+5000
	while guest.phase != "room" or session.phase != "room":
		if Time.get_ticks_msec() > deadline: check(false,"room join deadline"); break
		await process_frame
	session.local_squad = squad.operator_ids
	session.local_skills = squad.skill_indices
	session.set_ready(true)
	await frames()
	panel.get_node("Room/ReadyRow/Squad").pressed.emit()
	await frames()
	check(lobby._squad_editor != null and not session.local_ready and session.room_code == code and session.phase == "room","editing unsets own ready and preserves connection and room code")
	lobby._squad_editor.draft = PackedStringArray(["bagpipe","blaze"])
	lobby._squad_editor.draft_skills = PackedInt32Array([2,1])
	lobby._squad_editor._save()
	lobby._squad_editor._back()
	await frames()
	panel.get_node("Room/ReadyRow/Ready").pressed.emit()
	while not guest.remote_ready:
		if Time.get_ticks_msec() > deadline: check(false,"updated squad deadline"); break
		await process_frame
	check(guest.remote_squad == PackedStringArray(["bagpipe","blaze"]) and guest.remote_skills == PackedInt32Array([2,1]),"same connected peer receives edited loadout on ready")
	check(root.get_visible_rect().encloses(panel.get_global_rect()),"multiplayer layout fits viewport")
	await frames()
	capture("room-squad")
	guest.close()
	guest.free()
	change_scene_to_file("res://view/start_menu.tscn")
	await frames()
	current_scene.free()
	current_scene = null
	await test_battle_view()
	if had_saved:
		var output := FileAccess.open(SquadConfig.FILE_PATH,FileAccess.WRITE)
		output.store_buffer(original)
		output.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(SquadConfig.FILE_PATH))
	print("PREPARATION_SUPPORT_VIEW_OK solo rule routing, room-retained edited loadout, recovery HUD, drone projection/read-only; failures=",failures)
	quit(0 if failures == 0 else 1)

func test_battle_view() -> void:
	var data := {"bagpipe":load("res://resources/operators/bagpipe.tres"),"blaze":load("res://resources/operators/blaze.tres")}
	var state := MatchState.new(1,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[],[],MatchRules.new("score",5,1))
	state.ball.cell.x = 20
	state.step([],[])
	var input := LocalInput.new(0)
	var view := MatchView.new()
	root.add_child(view)
	view.bind(state,input,data)
	for mirrored in [false,true]:
		view.mirror_board = mirrored
		var before := state.state_hash()
		await frames()
		check(before == state.state_hash() and view._simulation_fraction() == 0,"recovery drawing frozen/read-only")
		input.select_operator("bagpipe")
		view._preview_cell = Vector2i(2,5)
		view._deploy_phase = MatchView.DeployPhase.FACING
		check(DeployInteraction.preview_is_legal(view),"recovery view shows cross-boundary placement")
		DeployInteraction.confirm(view)
		check(input.take_commands()[0].kind == InputCommand.Kind.RECOVERY_DEPLOY,"view sends recovery-specific intent")
		capture("recovery-mirror%d" % int(mirrored))
	var skip := InputEventMouseButton.new()
	skip.button_index = MOUSE_BUTTON_LEFT
	skip.pressed = true
	skip.position = ViewPalette.RECOVERY_SKIP.get_center()
	view._unhandled_input(skip)
	check(input.take_commands()[0].kind == InputCommand.Kind.SKIP_RECOVERY,"actual skip hit target")
	state.recovery_side = -1
	state.recovery_ticks_left = 0
	state.sides[0].tactical_items = [1,1,1,2]
	TacticalRules.use_item(state,0,InputCommand.new(state.input_tick,3,"",-1,Vector2i(13,5),-1,-1,3))
	for mirrored in [false,true]:
		view.mirror_board = mirrored
		await frames()
		input.select_item(3)
		view._preview_cell = Vector2i(12,2)
		view._deploy_phase = MatchView.DeployPhase.DRAGGING
		var before := state.state_hash()
		await frames()
		check(before == state.state_hash() and view._tray_item_kinds().has(3),"drone preview and air drawing read-only")
		capture("drone-mirror%d" % int(mirrored))
		var release := InputEventMouseButton.new()
		release.position = view.projection.cell_rect(view._preview_cell).get_center()
		DeployInteraction.release(view,release,view._preview_cell)
		var commands := input.take_commands()
		check(commands.size() == 1 and commands[0].item_kind == 3 and commands[0].facing == -1 and view._deploy_phase == MatchView.DeployPhase.IDLE,"air-item release uses no facing phase")
	input.select_item(3)
	await frames()
	capture("drone-info")
	view.free()
