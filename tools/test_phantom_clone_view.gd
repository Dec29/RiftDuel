extends SceneTree

class CloneView extends MatchView:
	var labels := PackedStringArray()
	func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
		labels.append(text)
		super._draw_text(position,text,font_size,color)

const DIRECTIONS := [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(40.0).timeout.connect(func() -> void: quit(1))
	var data := {}
	var db := root.get_node("OperatorDB")
	for id in db.all_ids(): data[id] = db.get_data(id)
	var squad := PackedStringArray(["phantom","nightingale","bagpipe","blaze","ceobe","exusiai","eyjafjalla","horn","hoshiguma","saileach","shining","silverash"])
	var roster := {}
	for id in squad: roster[id] = data[id]
	for side in 2:
		for mirrored in [false,true]:
			for facing in 4:
				var state := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[squad,squad])
				state.sides[side].cost = 99
				var cmds: Array[InputCommand] = [InputCommand.new(0,0,"phantom",-1,Vector2i(12 if side == 0 else 8,5)),InputCommand.new(0,0,"nightingale",-1,Vector2i(12 if side == 0 else 8,2))]
				var empty: Array[InputCommand] = []
				state.step(cmds if side == 0 else empty,cmds if side == 1 else empty)
				var input := LocalInput.new(side)
				var view := CloneView.new()
				view.bind(state,input,roster)
				view.mirror_board = mirrored
				root.add_child(view)
				var ids := view._tray_operator_ids()
				if not check(ids.size() == 12 and ids.has("phantom_clone") and ids.has("nightingale_phantom") and not ids.has("phantom") and not ids.has("nightingale"), "Two summons replace their parents within12 slots"): return
				for index in ids.size():
					if not check(Rect2(Vector2.ZERO,Vector2(ViewPalette.SCREEN_SIZE)).encloses(view._card_rect(index)) and view._card_rect(index).position.y == ViewPalette.CARD_ORIGIN.y and not view._card_rect(index).intersects(view._cost_rect()),"12 tray stays one horizontal row with no overflow"): return
				var before := state.state_hash()
				var cell := Vector2i(13 if side == 0 else 7,5)
				var center := view.projection.cell_rect(cell).get_center()
				mouse(view,view._card_rect(ids.find("phantom_clone")).get_center(),true)
				motion(view,center)
				mouse(view,center,false)
				if not check(view._deploy_phase == MatchView.DeployPhase.FACING and input.take_commands().is_empty() and state.state_hash() == before,"Clone requires normal facing stage, preview read-only"): return
				var direction: Vector2 = DIRECTIONS[facing]
				if mirrored: direction.x = -direction.x
				mouse(view,center,true)
				motion(view,center+direction*80)
				mouse(view,center+direction*80,false)
				cmds = input.take_commands()
				if not check(cmds.size() == 1 and cmds[0].operator_id == "phantom_clone" and cmds[0].facing == facing and cmds[0].cell == cell and state.state_hash() == before,"Direction%d both side/mirror command" % facing): return
				state.step(cmds if side == 0 else empty,cmds if side == 1 else empty)
				var twin := state.units[2]
				input.select_unit(twin.unit_id)
				view._info_tab = MatchView.InfoTab.COMMAND
				before = state.state_hash()
				view.labels.clear()
				view.queue_redraw()
				await process_frame
				await process_frame
				if not check(state.state_hash() == before and view.labels.has("物盾 1133 · 物闪 50%") and not view.labels.has("被动治疗 · 自动消耗金币") and not view.labels.has("技力  0 / 0"),"Own shield/dodge info read-only"): return
				if side == 0 and not mirrored:
					if not await screenshot("phantom-clone-facing%d-view.png" % facing): return
				view._info_tab = MatchView.InfoTab.TALENT
				view.labels.clear()
				view.queue_redraw()
				await process_frame
				await process_frame
				if not check(state.state_hash() == before and view.labels.has("虚影精通（已生效）") and not view.labels.has("（本作无适用机制）"),"Actual clone talent visible, hidden first omitted"): return
				if side == 0 and not mirrored and facing == 0:
					if not await screenshot("phantom-clone-passive-view.png"): return
				view._info_tab = MatchView.InfoTab.COMMAND
				for i in 300: state.step([],[])
				before = state.state_hash()
				view.labels.clear()
				view.queue_redraw()
				await process_frame
				await process_frame
				if not check(state.state_hash() == before and view.labels.has("物盾 0 · 物闪 0%") and view._skill_bar_ratio(twin,MatchState.CLONE_DATA.skills[0]) == 0.0,"Expiry safe0/0 and render unchanged"): return
				if side == 0 and not mirrored and facing == 0:
					if not await screenshot("phantom-clone-expired-view.png"): return
				mouse(view,view._cancel_rect().get_center(),true)
				cmds = input.take_commands()
				if not check(cmds.size() == 1 and cmds[0].kind == InputCommand.Kind.RETREAT and state.state_hash() == before,"Clone retreat read-only"): return
				state.step(cmds if side == 0 else empty,cmds if side == 1 else empty)
				ids = view._tray_operator_ids()
				before = state.state_hash()
				mouse(view,view._card_rect(ids.find("phantom_clone")).get_center(),true)
				if not check(input.selected_operator_id == "phantom_clone" and view._deploy_phase == MatchView.DeployPhase.IDLE and input.take_commands().is_empty() and state.state_hash() == before,"Cooldown card inspectable but cannot deploy"): return
				view.queue_redraw()
				await process_frame
				await process_frame
				if side == 0 and not mirrored and facing == 0:
					if not await screenshot("phantom-clone-tray12-view.png"): return
				cmds = [InputCommand.new(state.tick,InputCommand.Kind.RETREAT,"",0)]
				state.step(cmds if side == 0 else empty,cmds if side == 1 else empty)
				if not check(not view._tray_operator_ids().has("phantom_clone"),"Absent parent hides new clone card"): return
				view.free()
	print("Phantom clone view OK:12 slots/two summons/direction4/side2/mirror2/shield/dodge/expiry/talents/cooldown/retreat/render hash")
	quit(0)

func screenshot(name: String) -> bool:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		return check(root.get_texture().get_image().save_png("res://.godot/"+name) == OK,"Screenshot save "+name)
	return true
func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
func mouse(view: MatchView, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.pressed = pressed
	event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event)
func motion(view: MatchView, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	view._unhandled_input(event)
