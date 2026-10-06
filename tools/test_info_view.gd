extends SceneTree

class InfoView extends MatchView:
	var labels := PackedStringArray()

	func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
		labels.append(text)
		super._draw_text(position, text, font_size, color)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := {}
	var database := root.get_node("OperatorDB")
	for id in database.all_ids():
		definitions[id] = database.get_data(id)
	var state := MatchState.new(0x52494654, definitions)
	var input := LocalInput.new(0)
	var view := InfoView.new()
	view.bind(state, input, definitions)
	root.add_child(view)
	var unit := UnitState.new(0, 0, "bagpipe", Vector2i(12, 5), 2484, 35)
	state.units = [unit]
	state.tick = 3661
	state.sides[0].cost = 99
	input.select_unit(0)
	var skill: SkillResource = definitions["bagpipe"].skills[0]
	if not _check(is_equal_approx(view._skill_bar_ratio(unit, skill), 1.0), "Full SP must fill the bar"):
		return
	unit.sp = 0
	var charging := 0.0
	for regen in [0, 15, 29]:
		unit.sp_regen_ticks = regen
		var ratio := view._skill_bar_ratio(unit, skill)
		if not _check(ratio >= charging and ratio <= 1.0 / skill.sp_required, "SP progress must grow with recharge ticks: %f" % ratio):
			return
		charging = ratio
	unit.sp_regen_ticks = 0
	var previous := 1.0
	for ticks in [1050, 525, 1, 0]:
		unit.skill_ticks_left = ticks
		var ratio := view._skill_bar_ratio(unit, skill)
		if not _check(ratio <= previous and absf(ratio - float(ticks) / 1050) < 0.002, "Duration bar must decrease to zero: ticks=%d ratio=%f" % [ticks, ratio]):
			return
		previous = ratio
	unit.skill_ticks_left = 525
	var before := state.state_hash()
	var capture_args := OS.get_cmdline_user_args()
	for regen in [0, 15, 29]:
		state.sides[0].cost_regen_ticks = regen
		before = state.state_hash()
		view.labels.clear()
		view.queue_redraw()
		await process_frame
		await process_frame
		if not _check(view.labels.has("TIME  02:02") and view.labels.has("MAX") and state.state_hash() == before, "Timer/MAX must be correct and drawing read-only: %s" % view.labels):
			return
		if not capture_args.is_empty():
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var point := Vector2i(view._cost_rect().end) - Vector2i(24, 4)
			if not _check(image.get_pixelv(point).is_equal_approx(MatchView.PALETTE.BLUE), "MAX bar must stay full for regen=%d: pixel=%s" % [regen, image.get_pixelv(point)]):
				return
	for tab_index in 4:
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = view._tab_rect(tab_index).get_center()
		view._unhandled_input(click)
		view.labels.clear()
		view.queue_redraw()
		await process_frame
		await process_frame
		var expected: String = ["技能生效 · 剩余 18s", "职业：先锋 / 冲锋手", definitions["bagpipe"].talent_1.talent_name + "（已生效）", skill.skill_name][tab_index]
		if not _check(view._info_tab == tab_index and view.labels.has(expected) and state.state_hash() == before and input.take_commands().is_empty(), "Tab=%d must show expected information without writing state: %s" % [tab_index, view.labels]):
			return
		if not capture_args.is_empty():
			await RenderingServer.frame_post_draw
			var path := capture_args[0].get_basename() + "_%d.png" % tab_index
			if not _check(root.get_texture().get_image().save_png(path) == OK, "Cannot save screenshot: " + path):
				return
	unit.skill_ticks_left = 0
	unit.sp = 35
	view._activate_selected_skill()
	if not _check(input.take_commands().is_empty(), "Info tab must not activate a manual skill"):
		return
	view._info_tab = MatchView.InfoTab.COMMAND
	view._activate_selected_skill()
	if not _check(input.take_commands().size() == 1, "Command tab must allow a ready manual skill"):
		return
	unit.operator_id = "ceobe"
	unit.sp = 18
	view._activate_selected_skill()
	if not _check(input.take_commands().is_empty(), "Automatic skill must not create a manual command"):
		return
	unit.side = 1
	view._info_tab = MatchView.InfoTab.PASSIVE
	var scroll := InputEventMouseButton.new()
	scroll.pressed = true
	scroll.button_index = MOUSE_BUTTON_WHEEL_DOWN
	scroll.position = Vector2(MatchView.PALETTE.HUD_ORIGIN) + Vector2(80, 180)
	view._unhandled_input(scroll)
	if not _check(view._info_scroll == 36 and input.selected_unit_id == 0 and input.take_commands().is_empty(), "Enemy information scrolling must preserve selection without commands"):
		return
	var scroll_hash := state.state_hash()
	view._process(1.0 / 60.0)
	if not _check(view._info_scroll_display > 0.0 and view._info_scroll_display < 36.0, "Wheel scrolling must show an intermediate position before reaching its target"):
		return
	for frame in 40:
		view._process(1.0 / 60.0)
	if not _check(view._info_scroll_display > 35.5 and view._info_scroll_display <= 36.0, "Smooth scrolling must converge without overshooting"):
		return
	scroll.button_index = MOUSE_BUTTON_WHEEL_UP
	view._unhandled_input(scroll)
	view._process(1.0 / 60.0)
	if not _check(view._info_scroll == 0 and view._info_scroll_display > 0.0 and view._info_scroll_display < 36.0 and state.state_hash() == scroll_hash and input.take_commands().is_empty(), "Reverse scrolling must remain smooth and read-only"):
		return
	print("Info view OK: tabs, read-only information, duration/SP bars, match clock, static MAX cost, automatic skill controls")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
