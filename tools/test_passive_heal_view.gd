extends SceneTree

class CoinView extends MatchView:
	var labels := PackedStringArray()

	func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
		labels.append(text)
		super._draw_text(position, text, font_size, color)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		push_error("Passive healing view test timed out")
		quit(1)
	)
	var definitions := {}
	for id in root.get_node("OperatorDB").all_ids():
		definitions[id] = root.get_node("OperatorDB").get_data(id)
	var state := MatchState.new(12345, definitions)
	state.sides[0].cost = 99
	state.step([InputCommand.new(0, 0, "swire_alter", -1, Vector2i(11, 5))], [])
	var input := LocalInput.new(0)
	input.select_unit(0)
	var view := CoinView.new()
	view.bind(state, input, definitions)
	view._info_tab = MatchView.InfoTab.COMMAND
	state.squad_skills[0].fill(0)
	root.add_child(view)
	var unit := state.units[0]
	var skill: SkillResource = definitions.swire_alter.skills[0]
	for coins in 4:
		unit.coins = coins
		if not _check(is_equal_approx(view._skill_bar_ratio(unit, skill), float(coins) / 3), "Coin bar must show discrete coins, not SP or duration"):
			return
	unit.coins = 1
	var hash_before := state.state_hash()
	await process_frame
	await process_frame
	if not _check(view.labels.has("金币  1 / 3") and view.labels.has("被动治疗 · 自动消耗金币") and view.labels.has("攻击 +0% · 单次治疗 324") and state.state_hash() == hash_before, "Passive status, adjusted healing amount or read-only drawing failed: " + str(view.labels)):
		return
	view._activate_selected_skill()
	if not _check(input.take_commands().is_empty(), "Passive skill must not create a manual command"):
		return
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		var point := Vector2i(view.projection.cell_rect(Vector2i(12, 4)).get_center())
		if not _check(not frame.get_pixelv(point).is_equal_approx(MatchView.PALETTE.GROUND), "Healing range must include the rear diagonal independently of facing"):
			return
		if not _check(frame.save_png(args[0].get_basename() + "_gain.png") == OK, "Cannot save coin gain screenshot"):
			return
	state.units.append(UnitState.new(1, 0, "bagpipe", Vector2i(12, 5), 1000, 0, 10000))
	state.next_unit_id = 2
	unit.attack_ticks_left = 1
	state.step([], [])
	for _tick in 3:
		state.step([], [])
	view.labels.clear()
	hash_before = state.state_hash()
	await process_frame
	await process_frame
	if not _check(unit.last_attack_is_heal and unit.last_coin_spend_tick == 1 and view.labels.has("金币  0 / 3") and state.units[1].hp == 1324 and state.state_hash() == hash_before, "Actual coin/healing animation must follow simulation without changing it"):
		return
	if not args.is_empty():
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(args[0].get_basename() + "_heal.png") == OK, "Cannot save healing screenshot"):
			return
	unit.coins = 3
	unit.side = 1
	view.labels.clear()
	hash_before = state.state_hash()
	await process_frame
	await process_frame
	view._activate_selected_skill()
	if not _check(view.labels.has("金币  3 / 3") and view.labels.has("敌方干员 · 仅查看") and input.take_commands().is_empty() and state.state_hash() == hash_before, "Enemy coin information must be read-only"):
		return
	view._info_tab = MatchView.InfoTab.TALENT
	view.labels.clear()
	await process_frame
	await process_frame
	if not _check(view.labels.has("大买家（已生效）"), "Buyer talent must not be labelled unimplemented"):
		return
	view._info_scroll = 100
	view._info_scroll_display = 100.0
	await process_frame
	await process_frame
	if not _check(view.labels.has("破财消灾（已生效）"), "Fatal revival talent must be labelled implemented"):
		return
	view._info_tab = MatchView.InfoTab.SKILL
	view._info_scroll = 0
	view._info_scroll_display = 0.0
	view.labels.clear()
	await process_frame
	await process_frame
	if not _check(view.labels.has("被动 · 部署即生效") and view.labels.has("无技力消耗 · 持续至撤退"), "Passive skill information must not imply activation or duration countdown"):
		return
	if not args.is_empty():
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(args[0].get_basename() + "_enemy.png") == OK, "Cannot save enemy information screenshot"):
			return
	print("Passive healing view OK: coin count/bar, both ranges, coin gain/transfer/healing markers, enemy read-only, talent/skill labels")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
