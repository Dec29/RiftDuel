extends SceneTree

class InspectView extends MatchView:
	var draw_us: Array[int] = []
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		draw_us.append(Time.get_ticks_usec()-start)

var data: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id in root.get_node("OperatorDB").all_ids(): data[id]=root.get_node("OperatorDB").get_data(id)
	for side in 2:
		for mirrored in [false,true]:
			for facing in 4:
				var state := MatchState.new(117,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["bagpipe","silverash"],["bagpipe","silverash"]],[[0,2],[0,2]])
				state.sides[side].cost=99
				var input := LocalInput.new(side)
				var view := InspectView.new()
				view.bind(state,input,data)
				view.mirror_board=mirrored
				root.add_child(view)
				var cell := Vector2i(20 if side==0 else 0,5)
				var center := view.projection.cell_rect(cell).get_center()
				mouse(view,view._card_rect(view._tray_operator_ids().find("bagpipe")).get_center())
				mouse(view,center,false)
				if not check(view._deploy_phase==MatchView.DeployPhase.FACING and not view._hud_rect().has_point(center),"Own-edge facing anchor is free, side%d/mirror%s"%[side,mirrored]):return
				var hash_before := state.state_hash()
				mouse(view,center)
				var tip := center+view.projection.view_direction(Vector2(AttackRange.rotate_offset(Vector2i.RIGHT,facing)),cell).normalized()*60.0
				var motion := InputEventMouseMotion.new()
				motion.position=tip
				view._unhandled_input(motion)
				mouse(view,tip,false)
				var commands := input.take_commands()
				if not check(commands.size()==1 and commands[0].cell==cell and commands[0].facing==facing and state.state_hash()==hash_before,"Four facing drags queue exactly one unchanged-simulation intent"):return
				if side==0: state.step(commands,[])
				else: state.step([],commands)
				if not check(not view._hud_visible() or not view._hud_rect().has_point(center),"Placement leaves the new unit's click position unobstructed"):return
				mouse(view,center)
				if not check(input.selected_unit_id==0 and view._info_tab==MatchView.InfoTab.SKILL,"New edge unit is selectable and defaults to skill"):return
				await process_frame
				await process_frame
				if facing==0 and not await capture("edge-%d-%s"%[side,mirrored]):return
				view.free()
	var state := MatchState.new(117,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["silverash"],["silverash"]],[[2],[2]])
	state.units.append(UnitState.new(0,0,"silverash",Vector2i(12,5),2560,90,10000,0,2))
	state.next_unit_id=1
	var input := LocalInput.new(0)
	var view := InspectView.new()
	view.bind(state,input,data)
	root.add_child(view)
	mouse(view,view.projection.cell_rect(state.units[0].cell).get_center())
	var hash_before := state.state_hash()
	for mirrored in [false,true]:
		view.mirror_board=mirrored
		for facing in 4:
			state.units[0].facing=facing
			hash_before=state.state_hash()
			if not check(view._range_preview_visible(),"Changed-range skill exposes preview button"):return
			mouse(view,view._range_preview_rect().get_center())
			if not check(view._show_skill_range and view._range_offsets(data.silverash,state.units[0].cell)==data.silverash.skills[2].attack_range_override and state.units[0].skill_ticks_left==0 and input.take_commands().is_empty(),"Preview reads actual resource range without activation"):return
			view.queue_redraw()
			await process_frame
			await process_frame
			if not check(state.state_hash()==hash_before,"Rotated/mirrored preview is read-only"):return
			if facing==0 and not await capture("range-%s"%mirrored):return
			mouse(view,view._range_preview_rect().get_center())
			if not check(not view._show_skill_range and view._range_offsets(data.silverash,state.units[0].cell)==data.silverash.attack_range,"Toggle restores current range"):return
	mouse(view,view._tab_rect(MatchView.InfoTab.TALENT).get_center())
	await process_frame
	await process_frame
	if not check(view._info_tab==MatchView.InfoTab.TALENT and input.take_commands().is_empty(),"Battle passive tab is independent and read-only"):return
	view.free()
	var saved_exists := FileAccess.file_exists(SquadConfig.FILE_PATH)
	var saved := FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH) if saved_exists else PackedByteArray()
	var squad_view = load("res://view/squad_menu.tscn").instantiate()
	root.add_child(squad_view)
	squad_view.draft=PackedStringArray(["silverash"])
	squad_view.draft_skills=PackedInt32Array([2])
	squad_view._open_slot(0)
	var tabs: HBoxContainer = squad_view.get_node("Margin/Layout/Body/Picker/Details/Content/DetailTabs")
	if not check(squad_view.detail_tab==0 and squad_view.details.text.contains("真银斩") and not squad_view.details.text.contains("领袖"),"Squad defaults to only equipped skill without scrolling through talents"):return
	tabs.get_node("Passive").pressed.emit()
	if not check(squad_view.detail_tab==1 and squad_view.details.text.contains("领袖") and not squad_view.details.text.contains("真银斩"),"Passive tab contains talents separately"):return
	tabs.get_node("Skill").pressed.emit()
	tabs.get_node("Preview").pressed.emit()
	if not check(squad_view.show_skill_range and squad_view.details.text.contains("真银斩") and (FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)==saved if saved_exists else not FileAccess.file_exists(SquadConfig.FILE_PATH)),"Tabs and range preview never save or alter squad"):return
	await process_frame
	await process_frame
	if not await capture("squad-skill"):return
	squad_view.free()
	# Dense pose: inspect actual enemy silhouettes and measure warmed drawing cost.
	state=MatchState.new(117,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[[],[]])
	for index in 12:
		var id := str(data.keys()[index])
		state.units.append(UnitState.new(index,1,id,Vector2i(7+index%4,3+index/4),data[id].max_health,0,10000,index%4))
	state.next_unit_id=12
	input=LocalInput.new(0)
	view=InspectView.new()
	view.bind(state,input,data)
	root.add_child(view)
	view.set_process(false)
	hash_before=state.state_hash()
	for frame in 20:
		view.queue_redraw()
		await process_frame
	var cache_count := OperatorSpineVisual._outline_textures.size()
	view.draw_us.clear()
	for frame in 30:
		view.queue_redraw()
		await process_frame
	var enemy_times := view.draw_us.duplicate()
	if not check(OperatorSpineVisual._outline_textures.size()==cache_count and state.state_hash()==hash_before,"Dense enemy drawing reuses alpha masks and remains read-only"):return
	if not await capture("dense-enemies"):return
	input.side=1
	view.draw_us.clear()
	for frame in 30:
		view.queue_redraw()
		await process_frame
	var friendly_times := view.draw_us.duplicate()
	if not check(state.state_hash()==hash_before,"Friendly comparison also keeps simulation unchanged"):return
	enemy_times.sort()
	friendly_times.sort()
	print("Dense warmed draw CPU us: enemy median=",enemy_times[enemy_times.size()/2]," friendly median=",friendly_times[friendly_times.size()/2],"; not whole-match FPS")
	view.free()
	print("BATTLE_UI_OK: edge deployment/facing4/side2/mirror2, skill/passive defaults, readonly range previews and dense enemy masks")
	quit(0)

func mouse(view: MatchView,position: Vector2,pressed: bool=true) -> void:
	var event := InputEventMouseButton.new()
	event.position=position
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	view._unhandled_input(event)

func capture(label: String) -> bool:
	if DisplayServer.get_name()=="headless":return true
	await RenderingServer.frame_post_draw
	return check(root.get_texture().get_image().save_png("res://.godot/battle-ui-%s.png"%label)==OK,"Save actual graphics evidence")

func check(ok: bool,message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
