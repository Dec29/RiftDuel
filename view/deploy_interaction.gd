class_name DeployInteraction
extends RefCounted


static func preview_is_legal(view: MatchView) -> bool:
	if view._local_input.selected_item_kind >= 0:
		return view._item_can_place(view._preview_cell) if view._deploy_phase == MatchView.DeployPhase.DRAGGING else view._state.can_use_item(view._local_input.side, view._local_input.selected_item_kind, view._preview_cell, view._preview_facing if view._local_input.selected_item_kind == MatchView.CONFIG.TACTICAL_ITEM_CRANE else -1)
	if view._local_input.selected_operator_id == "phantom_clone":
		return view._state.clone_can_deploy(view._local_input.side, view._preview_cell)
	if view._local_input.selected_operator_id == "nightingale_phantom":
		return view._state.phantom_can_deploy(view._local_input.side, view._preview_cell)
	var operator := view._operator_data[view._local_input.selected_operator_id] as OperatorData
	return view._state.can_deploy(view._local_input.side, operator.operator_id, view._preview_cell)


static func confirm(view: MatchView) -> void:
	if preview_is_legal(view):
		if view._local_input.selected_item_kind >= 0:
			view._local_input.queue_item(view._state.input_tick, view._local_input.selected_item_kind, view._preview_cell, view._preview_facing if view._local_input.selected_item_kind == MatchView.CONFIG.TACTICAL_ITEM_CRANE else -1)
		else:
			view._local_input.queue_deploy(view._state.input_tick, view._preview_cell, view._preview_facing, view._state.recovery_side >= 0)
		view._deploy_phase = MatchView.DeployPhase.IDLE
		view._preview_cell = Vector2i(-1, -1)
		view._facing_drag = false


static func cancel(view: MatchView) -> void:
	view._deploy_phase = MatchView.DeployPhase.IDLE
	view._preview_cell = Vector2i(-1, -1)
	view._facing_drag = false
	view._local_input.clear_selection()
	view._show_skill_range = false
	view._details_open = false
	view._info_tab = MatchView.InfoTab.COMMAND


static func motion(view: MatchView, event: InputEventMouseMotion) -> void:
	if view._deploy_phase == MatchView.DeployPhase.DRAGGING:
		view._preview_cell = view._hovered_cell
	elif view._deploy_phase == MatchView.DeployPhase.FACING and view._facing_drag:
		var drag := view.projection.board_direction(event.position - view.projection.cell_rect(view._preview_cell).get_center(), view._preview_cell)
		if drag.length() >= MatchView.PALETTE.CELL_SIZE * 0.3:
			view._preview_facing = (0 if drag.x > 0 else 2) if absf(drag.x) >= absf(drag.y) else (1 if drag.y > 0 else 3)


static func release(view: MatchView, event: InputEventMouseButton, cell: Vector2i) -> void:
	if view._deploy_phase == MatchView.DeployPhase.DRAGGING:
		var tray_ids := view._tray_operator_ids()
		var card_index := tray_ids.find(view._local_input.selected_operator_id)
		if view._local_input.selected_item_kind >= 0:
			card_index = tray_ids.size() + view._tray_item_kinds().find(view._local_input.selected_item_kind)
		if card_index >= 0 and view._card_rect(card_index).has_point(event.position):
			view._deploy_phase = MatchView.DeployPhase.IDLE
			view._preview_cell = Vector2i(-1, -1)
			return
		view._preview_cell = cell
		if preview_is_legal(view):
			if view._local_input.selected_item_kind in [MatchView.CONFIG.TACTICAL_ITEM_PLATFORM, MatchView.CONFIG.TACTICAL_ITEM_STUN, MatchView.CONFIG.TACTICAL_ITEM_SUPPORT_DRONE] or view._local_input.selected_operator_id == "nightingale_phantom":
				confirm(view)
			else:
				view._deploy_phase = MatchView.DeployPhase.FACING
		else:
			cancel(view)
	elif view._deploy_phase == MatchView.DeployPhase.FACING and view._facing_drag:
		view._facing_drag = false
		var drag := view.projection.board_direction(event.position - view.projection.cell_rect(view._preview_cell).get_center(), view._preview_cell)
		if drag.length() >= MatchView.PALETTE.CELL_SIZE * 0.8:
			view._preview_facing = (0 if drag.x > 0 else 2) if absf(drag.x) >= absf(drag.y) else (1 if drag.y > 0 else 3)
			confirm(view)
	return
