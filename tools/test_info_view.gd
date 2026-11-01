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
	for cost in [99, 0]:
		state.sides[0].cost = cost
		var tray_hash := state.state_hash()
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = view._card_rect(view._tray_operator_ids().find("bagpipe")).get_center()
		click.pressed = true
		view._unhandled_input(click)
		click.pressed = false
		view._unhandled_input(click)
		if not _check(view._deploy_phase == MatchView.DeployPhase.IDLE and input.selected_operator_id == "bagpipe" and input.take_commands().is_empty(), "Card click must retain inspection for both sufficient and insufficient cost"):
			return
		for tab_index in [MatchView.InfoTab.SKILL,MatchView.InfoTab.TRAIT,MatchView.InfoTab.TALENT]:
			click.pressed = true
			click.position = view._tab_rect(tab_index).get_center()
			view._unhandled_input(click)
			view.labels.clear()
			view.queue_redraw()
			await process_frame
			await process_frame
			var expected: String = {MatchView.InfoTab.TRAIT:"职业：先锋 / 冲锋手", MatchView.InfoTab.TALENT:definitions["bagpipe"].talent_1.talent_name + "（部署后生效）", MatchView.InfoTab.SKILL:definitions["bagpipe"].skills[0].skill_name}[tab_index]
			if not _check(view.labels.has(expected) and state.state_hash() == tray_hash and input.take_commands().is_empty(), "Tray information must share field-unit tabs and remain read-only: %s" % view.labels):
				return
	state.sides[0].cooldowns["bagpipe"] = 30
	var cooldown_hash := state.state_hash()
	view._info_tab = MatchView.InfoTab.COMMAND
	view.labels.clear()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(view.labels.has("再部署冷却 1.0 秒") and state.state_hash() == cooldown_hash, "Cooldown inspection must show actual remaining time without changing simulation"):
		return
	var tray_capture_args := OS.get_cmdline_user_args()
	if not tray_capture_args.is_empty():
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(tray_capture_args[0].get_basename() + "_tray.png") == OK, "Cannot save tray information capture"):
			return
	DeployInteraction.cancel(view)
	state.sides[0].cooldowns.clear()
	var unit := UnitState.new(0, 0, "bagpipe", Vector2i(12, 5), 2484, 35)
	state.units = [unit]
	state.tick = 3661
	state.sides[0].cost = 99
	input.select_unit(0)
	view._details_open = true
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
		if not _check(view.labels.has("TIME  02:42") and view.labels.has("MAX") and state.state_hash() == before, "Timer/MAX must use real-time deadline and drawing stay read-only: %s" % view.labels):
			return
		if not capture_args.is_empty():
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var point := Vector2i(view._cost_rect().end) - Vector2i(24, 4)
			if not _check(image.get_pixelv(point).is_equal_approx(MatchView.PALETTE.BLUE), "MAX bar must stay full for regen=%d: pixel=%s" % [regen, image.get_pixelv(point)]):
				return
	for tab_index in [MatchView.InfoTab.SKILL,MatchView.InfoTab.TRAIT,MatchView.InfoTab.TALENT]:
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = view._tab_rect(tab_index).get_center()
		view._unhandled_input(click)
		view.labels.clear()
		view.queue_redraw()
		await process_frame
		await process_frame
		var expected: String = {MatchView.InfoTab.TRAIT:"职业：先锋 / 冲锋手", MatchView.InfoTab.TALENT:definitions["bagpipe"].talent_1.talent_name + "（已生效）", MatchView.InfoTab.SKILL:skill.skill_name}[tab_index]
		if not _check(view._info_tab == tab_index and view.labels.has(expected) and state.state_hash() == before and input.take_commands().is_empty(), "Tab=%d must show expected information without writing state: %s" % [tab_index, view.labels]):
			return
		if not capture_args.is_empty():
			await RenderingServer.frame_post_draw
			var path := capture_args[0].get_basename() + "_%d.png" % tab_index
			if not _check(root.get_texture().get_image().save_png(path) == OK, "Cannot save screenshot: " + path):
				return
	# Shared live attributes refresh independently from the description tab.
	view._info_tab = MatchView.InfoTab.TRAIT
	unit.skill_ticks_left = 525
	view.queue_redraw()
	await process_frame
	await process_frame
	var boosted_attack := "攻击 %d"%SkillRules.attack_value(unit,definitions.bagpipe)
	unit.skill_ticks_left = 0
	var refreshed_hash := state.state_hash()
	view.labels.clear()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(not view.labels.has(boosted_attack) and view.labels.has("攻击 %d"%SkillRules.attack_value(unit,definitions.bagpipe)) and state.state_hash() == refreshed_hash, "Expired buff must refresh shared attributes without view writes"):
		return
	input.select_operator("ceobe")
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(view._info_layout_paragraphs.has("职业：术士 / 中坚术士") and state.state_hash() == refreshed_hash, "Selection change must refresh trait layout"):
		return
	input.select_unit(0)
	view._info_tab = MatchView.InfoTab.SKILL
	unit.skill_ticks_left = 0
	unit.sp = 35
	view._activate_selected_skill()
	if not _check(input.take_commands().size() == 1, "Default skill information page must allow its ready manual skill"):
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
	view._info_tab = MatchView.InfoTab.TALENT
	var scroll := InputEventMouseButton.new()
	scroll.pressed = true
	scroll.button_index = MOUSE_BUTTON_WHEEL_DOWN
	scroll.position = view._info_body_rect().get_center()
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
