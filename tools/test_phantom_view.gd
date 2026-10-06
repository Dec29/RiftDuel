extends SceneTree

class PhantomView extends MatchView:
	var labels := PackedStringArray()
	func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
		labels.append(text)
		super._draw_text(position, text, font_size, color)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(1))
	var definitions := {}
	var db := root.get_node("OperatorDB")
	for id in db.all_ids():
		definitions[id] = db.get_data(id)
	assert(definitions.size() == 8)
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(72, definitions)
			state.sides[side].cost = 99
			var deploy: Array[InputCommand] = [InputCommand.new(state.tick, 0, "nightingale", -1, Vector2i(12 if side == 0 else 8, 2))]
			var empty: Array[InputCommand] = []
			state.step(deploy if side == 0 else empty, deploy if side == 1 else empty)
			assert(state.sides[side].phantom_count == 2)
			var input := LocalInput.new(side)
			var view := PhantomView.new()
			view.bind(state, input, definitions)
			view.mirror_board = mirrored
			root.add_child(view)
			assert(not definitions.has("nightingale_phantom"))
			var ids := view._tray_operator_ids()
			assert(ids.size() == 8 and ids.has("nightingale_phantom") and not ids.has("nightingale"))
			var hash_before := state.state_hash()
			var cost_before: int = state.sides[side].cost
			_mouse(view, view._card_rect(ids.find("nightingale_phantom")).get_center(), true)
			assert(view._deploy_phase == MatchView.DeployPhase.DRAGGING)
			_mouse(view, view._cancel_rect().get_center(), true)
			assert(input.take_commands().is_empty() and state.state_hash() == hash_before)
			_mouse(view, view._card_rect(ids.find("nightingale_phantom")).get_center(), true)
			var phantom_cell := Vector2i(11 if side == 0 else 9, 2)
			_mouse(view, view._cell_rect(phantom_cell).get_center(), false)
			var commands := input.take_commands()
			assert(commands.size() == 1 and commands[0].operator_id == "nightingale_phantom" and commands[0].cell == phantom_cell)
			assert(view._deploy_phase == MatchView.DeployPhase.IDLE and state.state_hash() == hash_before)
			assert(CommandCodec.decode(CommandCodec.encode(commands), state.tick).has("commands"))
			state.step(commands if side == 0 else empty, commands if side == 1 else empty)
			assert(state.units.size() == 2 and state.sides[side].phantom_count == 1 and state.sides[side].cost == cost_before - 5)
			assert(view._tray_operator_ids().has("nightingale_phantom") and not state.phantom_available(side))
			_mouse(view, view._cell_rect(phantom_cell).get_center(), true)
			assert(input.selected_unit_id == 1)
			var space := InputEventKey.new()
			space.pressed = true
			space.keycode = KEY_SPACE
			view._unhandled_input(space)
			assert(input.take_commands().is_empty())
			hash_before = state.state_hash()
			view.labels.clear()
			view.queue_redraw()
			await process_frame
			await process_frame
			assert(state.state_hash() == hash_before)
			assert(view.labels.has("幻影 · 不攻击 / 不可治疗") and not view.labels.has("技力  0 / 0"))
			var args := OS.get_cmdline_user_args()
			if not args.is_empty():
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(args[0].get_basename() + "_%d_%d.png" % [side, int(mirrored)]) == OK)
			view._info_tab = MatchView.InfoTab.SKILL
			view.labels.clear()
			view.queue_redraw()
			await process_frame
			await process_frame
			assert(view.labels.has("无主动技能 / 无技力") and not view.labels.has("无技力消耗 · 持续至撤退"))
			view._info_tab = MatchView.InfoTab.COMMAND
			_mouse(view, view._card_rect(view._tray_operator_ids().find("nightingale_phantom")).get_center(), true)
			assert(view._deploy_phase == MatchView.DeployPhase.IDLE and input.take_commands().is_empty())
			input.side = 1 - side
			_mouse(view, view._cell_rect(phantom_cell).get_center(), true)
			_mouse(view, view._skill_rect().get_center(), true)
			_mouse(view, view._cancel_rect().get_center(), true)
			assert(input.take_commands().is_empty())
			input.side = side
			state.sides[side].phantom_cooldown_ticks = 0
			state.sides[side].cost = 0
			_mouse(view, view._card_rect(view._tray_operator_ids().find("nightingale_phantom")).get_center(), true)
			assert(view._deploy_phase == MatchView.DeployPhase.IDLE and input.take_commands().is_empty())
			state.sides[side].cost = 99
			assert(state.phantom_available(side))
			commands = [InputCommand.new(state.tick, 0, "nightingale_phantom", -1, Vector2i(11 if side == 0 else 9, 3))]
			state.step(commands if side == 0 else empty, commands if side == 1 else empty)
			assert(state.units.size() == 3 and state.sides[side].phantom_count == 0 and not view._tray_operator_ids().has("nightingale_phantom"))
			view.free()
	print("Phantom view OK: stock/card/cooldown, one-drag deployment, cancellation, both sides/mirrors, multiple summons and no manual skill")
	quit(0)


func _mouse(view: MatchView, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.pressed = pressed
	event.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(event)
