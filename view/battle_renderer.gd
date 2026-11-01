class_name BattleRenderer
extends RefCounted


func draw(view: MatchView, visual_tick: float, own_color: Color, enemy_color: Color, cell_size: float, frame: Dictionary) -> bool:
	view.original_vfx.drawn_poses.clear()
	draw_arena(view)
	view.original_props.sample(view)
	draw_bombs(view)
	draw_m129_markers(view)
	if view._deploy_phase != MatchView.DeployPhase.IDLE:
		if view._local_input.selected_item_kind >= 0:
			if view._deploy_phase == MatchView.DeployPhase.DRAGGING:
				for row in MatchView.CONFIG.GRID_ROWS:
					for column in MatchView.CONFIG.GRID_COLUMNS:
						var cell := Vector2i(column, row)
						if view._item_can_place(cell):
							view._draw_cell_color(cell, MatchView.PALETTE.LEGAL, 0.06)
			if view._preview_cell.x >= 0:
				var offsets: Array[Vector2i] = []
				if view._local_input.selected_item_kind == MatchView.CONFIG.TACTICAL_ITEM_CRANE:
					offsets.append(MatchView.RANGE.rotate_offset(Vector2i.RIGHT, view._preview_facing))
				elif view._local_input.selected_item_kind == MatchView.CONFIG.TACTICAL_ITEM_SUPPORT_DRONE:
					for row in range(-2, 3):
						for column in range(-2, 3):
							if absi(row) + absi(column) <= 2: offsets.append(Vector2i(column, row))
				elif view._local_input.selected_item_kind == MatchView.CONFIG.TACTICAL_ITEM_STUN:
					offsets.assign([Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP])
				else:
					offsets.append(Vector2i.ZERO)
				for offset in offsets:
					if view.projection.cell_is_inside(view._preview_cell + offset):
						view._draw_cell_color(view._preview_cell + offset, MatchView.PALETTE.ATTACK_RANGE, 0.08)
		else:
			var operator := view._operator_data[view._local_input.selected_operator_id] as OperatorData
			if view._deploy_phase == MatchView.DeployPhase.DRAGGING:
				for row in MatchView.CONFIG.GRID_ROWS:
					for column in MatchView.CONFIG.GRID_COLUMNS:
						var cell := Vector2i(column, row)
						var legal := view._state.phantom_can_deploy(view._local_input.side, cell) if operator.operator_id == "nightingale_phantom" else (view._state.clone_can_deploy(view._local_input.side, cell) if operator.operator_id == "phantom_clone" else view._state.can_deploy(view._local_input.side, operator.operator_id, cell))
						if legal:
							view._draw_cell_color(cell, MatchView.PALETTE.LEGAL, 0.06)
			if view._preview_cell.x >= 0:
				draw_range(view, operator, view._preview_cell, view._preview_facing)
	var selected := view._selected_unit()
	if selected != null and selected.displacement_ticks_left == 0:
		draw_range(view, view._operator_data[selected.operator_id] as OperatorData, selected.cell, selected.facing)
	var boundary := float(view._state.ball.cell.x) + 0.5
	view.draw_line(view.projection.board_point(Vector2(boundary, 0)), view.projection.board_point(Vector2(boundary, MatchView.CONFIG.GRID_ROWS)), Color(MatchView.PALETTE.BALL, 0.18), 2.0)
	if view._state.box_warning_cell.x >= 0:
		var warning := view.projection.cell_rect(view._state.box_warning_cell)
		view._draw_cell_color(view._state.box_warning_cell, Color(MatchView.PALETTE.ARROW, 0.18), 0.08)
		view.draw_polyline(view.projection.closed_polygon(view.projection.cell_polygon(view._state.box_warning_cell, 0.08)), MatchView.PALETTE.ARROW, 2.0, true)
		view._draw_text(warning.get_center() + Vector2(-5, 9), "!", 26, MatchView.PALETTE.ARROW)
	for box in view._state.tactical_boxes:
		var box_rect := view.projection.cell_rect(box.cell).grow(-7)
		view.draw_rect(box_rect, MatchView.PALETTE.HUD_INSET)
		view.draw_rect(box_rect, MatchView.PALETTE.BLOCKER, false, 2.0)
		view.draw_line(box_rect.position, box_rect.end, MatchView.PALETTE.BLOCKER, 1.5)
		view.draw_line(Vector2(box_rect.end.x, box_rect.position.y), Vector2(box_rect.position.x, box_rect.end.y), MatchView.PALETTE.BLOCKER, 1.5)
		for hit in box.hits_left:
			view.draw_circle(box_rect.position + Vector2(3 + hit * 7, box_rect.size.y + 4), 2, MatchView.PALETTE.ARROW)

	var ball_center := view.projection.cell_rect(view._state.ball.cell, false).get_center()
	var ball_depth := ball_center.y
	var roll := 0.0
	if view._state.ball.move_ticks_left > 0:
		var progress := clampf((MatchView.CONFIG.BALL_MOVE_TICKS - view._state.ball.move_ticks_left + view._simulation_fraction()) / MatchView.CONFIG.BALL_MOVE_TICKS, 0.0, 1.0)
		var travel := progress * progress * (3.0 - 2.0 * progress)
		if view._state.ball_move_is_blocked():
			travel = sin(progress * PI) * 0.22
		ball_center += view.projection.view_direction(Vector2(view._state.ball.move_direction), view._state.ball.cell) / MatchView.PALETTE.BOARD_ZOOM * cell_size * travel
		ball_depth = ball_center.y
		if not view._state.ball_move_is_blocked():
			ball_center.y -= sin(progress * PI) * cell_size * 0.08
		var screen_direction := view.projection.view_direction(Vector2(view._state.ball.move_direction), view._state.ball.cell)
		roll = travel * PI * (-1.0 if screen_direction.x < 0.0 or (is_zero_approx(screen_direction.x) and screen_direction.y < 0.0) else 1.0)

	var draw_units: Array[UnitState] = view._state.units.duplicate()
	draw_units.sort_custom(func(a: UnitState, b: UnitState) -> bool:
		var depth_a := unit_screen_center(view, a).y
		var depth_b := unit_screen_center(view, b).y
		return depth_a < depth_b or (depth_a == depth_b and a.unit_id < b.unit_id))
	var live_models := {}
	for unit in draw_units:
		if OperatorSpineMap.has(unit.operator_id):
			live_models[unit.unit_id] = true
	for id in view._bagpipe_models.keys():
		if not live_models.has(id):
			view._bagpipe_models.erase(id)
	var ball_drawn := false
	for unit in draw_units:
		if not ball_drawn and ball_depth <= unit_screen_center(view, unit).y:
			view.original_props.draw_through(view,ball_depth,false)
			draw_football(view, ball_center,roll)
			ball_drawn = true
		view.original_props.draw_through(view,unit_screen_center(view,unit).y)
		var operator := view._operator_data[unit.operator_id] as OperatorData
		var unit_rect := view.projection.cell_rect(unit.cell).grow(-cell_size * MatchView.PALETTE.UNIT_INSET_RATIO)
		unit_rect.position += unit_screen_center(view, unit) - view.projection.cell_rect(unit.cell).get_center()
		# Non-null only for units whose operator has a registered battle skeleton;
		# every other unit keeps the existing geometry rendering.
		var model: OperatorSpineVisual = null
		var attack_age := visual_tick - unit.last_attack_tick
		var damage_age := visual_tick - unit.last_damage_tick
		# Bone-rendered units express their attack through the skeleton, not the
		# geometric lunge, so the lunge stays with the geometry-rendered units.
		if not OperatorSpineMap.has(unit.operator_id) and unit.last_attack_tick >= 0 and attack_age >= 0.0 and attack_age < 8.0:
			var attack_direction := view.projection.view_direction(Vector2(unit.last_attack_target_x, unit.last_attack_target_y) - Vector2(unit.cell), unit.cell).normalized()
			unit_rect.position += attack_direction * sin(attack_age / 8.0 * PI) * cell_size * 0.075
		var unit_color := MatchView.PALETTE.BLUE if unit.side == 0 else MatchView.PALETTE.RED
		if unit.last_damage_tick >= 0 and damage_age >= 0.0 and damage_age < 8.0:
			var progress := damage_age / 8.0
			unit_rect.position.x += sin(progress * TAU * 2.0) * (1.0 - progress) * cell_size * 0.045
			unit_color = unit_color.lerp(MatchView.PALETTE.BALL, (1.0 - progress) * 0.7)
		if OperatorSpineMap.has(unit.operator_id):
			if not view._bagpipe_models.has(unit.unit_id):
				var created := OperatorSpineVisual.new()
				if not created.initialize(unit.operator_id):
					push_error(created.last_error)
					view.get_tree().quit(1)
					return false
				view._bagpipe_models[unit.unit_id] = created
			model = view._bagpipe_models[unit.unit_id]
			if (model.mesh.get_surface_count() == 0 or (view._state.result == MatchState.RESULT_RUNNING and not view.get_tree().paused)) and not model.prepare(unit, view.attack_visual_tick() if unit.operator_id in AttackTimeline.IDS or unit.operator_id in AttackTimeline.ADAPTED_IDS else view._bone_tick, SkillRules.attack_interval_ticks(unit, operator)):
				push_error(model.last_error)
				view.get_tree().quit(1)
				return false
			view.original_vfx.drawn_poses[unit.unit_id]=true
			# The foot anchor sits on the projection cell centre, which for a high
			# tile is its real top surface; scale comes from the row's own projected
			# cell width and this model's measured visible body height.
			var projected := unit_screen_center(view, unit)
			view.draw_set_transform(projected + Vector2(0, 3), 0, Vector2(1, 0.3))
			view.draw_circle(Vector2.ZERO, cell_size * 0.35, Color(MatchView.PALETTE.BACKGROUND, 0.65))
			var row_width := unit_row_width(view, unit)
			var actor_scale := model.scale_for_row(row_width)
			var flipped := (unit.facing == 2) != view.mirror_board
			var actor_origin := projected + model.anchor_offset(actor_scale)
			var actor_size := Vector2(-actor_scale if flipped else actor_scale,actor_scale)
			if unit.side != view._local_input.side and model.mesh.get_surface_count()>0:
				var mask := model.outline_texture()
				if mask == null:
					push_error(model.last_error)
					view.get_tree().quit(1)
					return false
				for offset in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
					view.draw_set_transform(actor_origin + offset * MatchView.PALETTE.ENEMY_OUTLINE_WIDTH,0,actor_size)
					view.draw_mesh(model.mesh,mask,Transform2D.IDENTITY,MatchView.PALETTE.ENEMY_OUTLINE)
			view.draw_set_transform(actor_origin,0,actor_size)
			if model.mesh.get_surface_count()>0:view.draw_mesh(model.mesh, model.texture)
			view.draw_set_transform(Vector2.ZERO)
		else:
			view.draw_rect(Rect2(unit_rect.position + Vector2(2, 4), unit_rect.size), Color(MatchView.PALETTE.BACKGROUND, 0.65))
			view.draw_rect(unit_rect, MatchView.PALETTE.UNIT_SURFACE)
			view.draw_rect(unit_rect, MatchView.PALETTE.ENEMY_OUTLINE if unit.side != view._local_input.side else MatchView.PALETTE.HUD_RULE, false, 1.5)
		if unit.hp_lock_ticks_left > 0:
			view.draw_arc(unit_rect.get_center(), cell_size * 0.45, 0, TAU, 24, Color(MatchView.PALETTE.ARROW, 0.55), 2.0, true)
		if unit.critical_ticks_left>0:view._draw_text(unit_rect.position+Vector2(-1,-19),"重伤 · 攻速-80%",11,MatchView.PALETTE.RED)
		if unit.stun_ticks_left > 0:
			view._draw_text(unit_rect.position + Vector2(-1, -5), "晕", 12, MatchView.PALETTE.ARROW)
		var bloodbath_age := visual_tick - unit.last_bloodbath_tick
		if unit.last_bloodbath_tick >= 0 and bloodbath_age >= 0.0 and bloodbath_age < 12.0:
			view.draw_arc(unit_rect.get_center(), cell_size * 0.48, 0, TAU, 24, MatchView.PALETTE.ARROW, 2.0)
		var block_age := visual_tick - unit.last_damage_block_tick
		if unit.last_damage_block_tick >= 0 and block_age >= 0.0 and block_age < 8.0:
			view.draw_arc(unit_rect.get_center(), cell_size * (0.38 + block_age * 0.025), 0, TAU, 24, Color(MatchView.PALETTE.HEAL_RANGE, 1.0 - block_age / 8.0), 2.0, true)
		if unit.last_damage_tick >= 0 and damage_age >= 0.0 and damage_age < 8.0:
			view.draw_rect(unit_rect, Color(MatchView.PALETTE.BALL, (1.0 - damage_age / 8.0) * 0.35))
		if SkillRules.block_count_value(unit, operator) >= MatchView.CONFIG.BLOCK_BALL_MIN:
			view.draw_rect(unit_rect.grow(2), MatchView.PALETTE.BLOCKER, false, 2.0)
		if unit.unit_id == view._local_input.selected_unit_id:
			view.draw_rect(unit_rect.grow(3), MatchView.PALETTE.ARROW, false, 2.0)
		if unit.cold_ticks_left>0 or unit.frozen_ticks_left>0:
			view.draw_rect(unit_rect.grow(2),MatchView.PALETTE.FROZEN_STATUS if unit.frozen_ticks_left>0 else MatchView.PALETTE.COLD_STATUS,false,2.0)
			view._draw_text(unit_rect.position+Vector2(0,-5),"冻" if unit.frozen_ticks_left>0 else "寒",14,MatchView.PALETTE.FROZEN_STATUS)
		if unit.silence_ticks_left > 0:
			view._draw_text(unit_rect.position + Vector2(0, -4), "默", 14, MatchView.PALETTE.ARROW)
		if unit.bind_ticks_left > 0:
			view.draw_line(unit_rect.position, unit_rect.end, MatchView.PALETTE.HEAL_RANGE, 2.0)
	if not ball_drawn:
		view.original_props.draw_through(view,ball_depth,false)
		draw_football(view, ball_center,roll)
	view.original_props.draw_through(view,INF)
	for unit in view._state.units:
		var center := unit_screen_center(view, unit)
		var coin_age := visual_tick - unit.last_coin_gain_tick
		if unit.last_coin_gain_tick >= 0 and coin_age >= 0.0 and coin_age < 12.0:
			var progress := coin_age / 12.0
			var coin_center := center + Vector2(cell_size * 0.3, -cell_size * (0.25 + progress * 0.4))
			view.draw_circle(coin_center, cell_size * 0.1, Color(MatchView.PALETTE.ARROW, 1.0 - progress))
			view.draw_line(coin_center - Vector2(0, cell_size * 0.06), coin_center + Vector2(0, cell_size * 0.06), Color(MatchView.PALETTE.BACKGROUND, 1.0 - progress), cell_size * 0.04, true)
		var attack_age := (view.attack_visual_tick() if unit.operator_id in AttackTimeline.IDS+AttackTimeline.ADAPTED_IDS else visual_tick)-unit.last_attack_tick
		var in_flight:=false
		for shot in view._state.attack_projectiles:
			if shot.source_id==unit.unit_id and shot.release_tick==unit.last_attack_tick:in_flight=true;break
		if unit.last_attack_tick >= 0 and attack_age >= 0.0 and attack_age < 8.0 and not in_flight and not view.original_vfx.handles_attack(unit) and unit.operator_id not in ["exusiai","jessica"]:
			var operator := view._operator_data[unit.operator_id] as OperatorData
			var target := view.projection.cell_rect(Vector2i(unit.last_attack_target_x, unit.last_attack_target_y)).get_center()
			var progress := attack_age / 8.0
			var opacity := 1.0 - progress
			var direction := (target - center).normalized()
			if unit.last_attack_is_heal or operator.damage_type == "healing":
				view.draw_arc(center, cell_size * (0.25 + progress * 0.35), 0.0, TAU, 24, Color(MatchView.PALETTE.HEAL_RANGE, opacity * 0.85), cell_size * 0.045, true)
				view.draw_line(center, target, Color(MatchView.PALETTE.HEAL_RANGE, opacity * 0.35), cell_size * 0.035, true)
				if unit.last_coin_spend_tick == unit.last_attack_tick:
					var coin_center := center.lerp(target, minf(1.0, progress * 1.5)) - Vector2(0, sin(progress * PI) * cell_size * 0.2)
					view.draw_circle(coin_center, cell_size * 0.1, Color(MatchView.PALETTE.ARROW, opacity))
					view.draw_arc(target, cell_size * (0.15 + progress * 0.3), 0.0, TAU, 24, Color(MatchView.PALETTE.HEAL_RANGE, opacity), cell_size * 0.055, true)
			elif SkillRules.damage_type(unit, operator) == "magical":
				var head := center.lerp(target, minf(1.0, progress * 1.8))
				view.draw_line(center.lerp(head, 0.5), head, Color(MatchView.PALETTE.HEAL_RANGE, opacity * 0.9), cell_size * 0.075, true)
				view.draw_circle(head, cell_size * 0.09, Color(MatchView.PALETTE.HEAL_RANGE, opacity * 0.9))
				view.draw_arc(target, cell_size * (0.12 + progress * 0.35), 0.0, TAU, 24, Color(MatchView.PALETTE.HEAL_RANGE, opacity * 0.5), cell_size * 0.035, true)
			elif center.distance_to(target) > cell_size * 1.5:
				var head := center.lerp(target, minf(1.0, progress * 1.8))
				var tail := head - direction * minf(cell_size * 0.35, center.distance_to(head))
				view.draw_line(tail, head, Color(MatchView.PALETTE.ARROW, opacity * 0.85), cell_size * 0.06, true)
				view.draw_circle(head, cell_size * 0.055, Color(MatchView.PALETTE.BALL, opacity * 0.75))
			else:
				var angle := direction.angle() - 0.8 + progress * 0.8
				view.draw_arc(center + direction * cell_size * 0.12, cell_size * (0.42 + progress * 0.14), angle, angle + 1.25, 12, Color(MatchView.PALETTE.ARROW, opacity * 0.75), cell_size * 0.075, true)
		var damage_age := visual_tick - unit.last_damage_tick
		if unit.last_damage_tick >= 0 and damage_age >= 0.0 and damage_age < 8.0:
			var progress := damage_age / 8.0
			view.draw_arc(center, cell_size * (0.38 + progress * 0.2), 0.0, TAU, 24, Color(MatchView.PALETTE.RED, (1.0 - progress) * 0.65), cell_size * 0.04, true)
		var heal_age := visual_tick - unit.last_heal_tick
		if unit.last_heal_tick >= 0 and heal_age >= 0.0 and heal_age < 8.0:
			var progress := heal_age / 8.0
			var cross_center := center + Vector2(cell_size * 0.28, -cell_size * (0.1 + progress * 0.4))
			var radius := cell_size * 0.09
			var color := Color(MatchView.PALETTE.HEAL_RANGE, (1.0 - progress) * 0.9)
			view.draw_line(cross_center - Vector2(radius, 0), cross_center + Vector2(radius, 0), color, cell_size * 0.065, true)
			view.draw_line(cross_center - Vector2(0, radius), cross_center + Vector2(0, radius), color, cell_size * 0.065, true)
	if view._deploy_phase != MatchView.DeployPhase.IDLE:
		var center := view._pointer_position if view._preview_cell.x < 0 else view.projection.cell_rect(view._preview_cell).get_center()
		var preview := Rect2(center - Vector2.ONE * cell_size * 0.35, Vector2.ONE * cell_size * 0.7)
		view.draw_rect(preview, Color(own_color, 0.55))
		view.draw_rect(preview, MatchView.PALETTE.LEGAL if DeployInteraction.preview_is_legal(view) else MatchView.PALETTE.RED, false, 2.0)
		if view._deploy_phase == MatchView.DeployPhase.FACING:
			for facing in 4:
				var direction := view.projection.view_direction(Vector2(MatchView.RANGE.rotate_offset(Vector2i.RIGHT, facing)), view._preview_cell) / MatchView.PALETTE.BOARD_ZOOM
				var tip := center + direction * cell_size * 1.1
				var side := Vector2(-direction.y, direction.x)
				view.draw_colored_polygon(PackedVector2Array([tip, tip - direction * cell_size * 0.25 + side * cell_size * 0.14, tip - direction * cell_size * 0.25 - side * cell_size * 0.14]), MatchView.PALETTE.ARROW if facing == view._preview_facing else MatchView.PALETTE.DISABLED)
			view.draw_arc(center, cell_size * 0.82, 0.0, TAU, 48, Color(MatchView.PALETTE.ARROW, 0.35), 1.5, true)
	draw_six_star_effects(view,visual_tick)
	draw_tactical_effects(view, visual_tick)
	draw_attack_projectiles(view,visual_tick)
	# Native poses are already current; attached effects must use those exact same poses.
	view.original_vfx.use_drawn_poses=true
	view.original_vfx.sample(view)
	view.original_vfx.use_drawn_poses=false
	view.original_vfx.draw(view,ball_center)
	# Status overlays remain readable after all scene bodies and combat effects.
	for unit in draw_units:
		var operator: OperatorData = view._operator_data[unit.operator_id]
		var skill := operator.skills[unit.skill_index]
		var hp_back := unit_health_rect(view, unit)
		view.draw_rect(hp_back, MatchView.PALETTE.GROUND)
		view.draw_rect(Rect2(hp_back.position, Vector2(hp_back.size.x * float(unit.hp) / SkillRules.max_health_value(unit, operator), hp_back.size.y)), MatchView.PALETTE.BLUE if unit.side == view._local_input.side else MatchView.PALETTE.RED)
		var barrier_health := unit.gravel_barrier_hp
		for health in unit.barrier_hp:
			barrier_health += health
		if barrier_health > 0:
			view.draw_rect(Rect2(hp_back.position - Vector2(0, MatchView.PALETTE.UNIT_STATUS_BAR_HEIGHT + MatchView.PALETTE.UNIT_STATUS_BAR_GAP), Vector2(hp_back.size.x * minf(1.0, float(barrier_health) / SkillRules.max_health_value(unit, operator)), hp_back.size.y)), MatchView.PALETTE.BLUE)
		var label_y := hp_back.end.y + MatchView.PALETTE.UNIT_NAME_SIZE + 2
		if SkillRules.sp_limit(skill) > 0 or skill.effect_type in ["passive_heal", "champagne_traps", "coin_barrage"]:
			var sp_back := Rect2(hp_back.position + Vector2(0, MatchView.PALETTE.UNIT_STATUS_BAR_HEIGHT + MatchView.PALETTE.UNIT_STATUS_BAR_GAP), hp_back.size)
			view.draw_rect(sp_back, MatchView.PALETTE.GROUND)
			view.draw_rect(Rect2(sp_back.position, Vector2(sp_back.size.x * view._skill_bar_ratio(unit, skill), sp_back.size.y)), view._skill_bar_color(unit, skill))
			label_y = sp_back.end.y + MatchView.PALETTE.UNIT_NAME_SIZE + 2
		var name := operator.display_name if unit.operator_id=="mon3tr" else ("海嗣" if unit.operator_id=="seaborn" else operator.display_name.left(2))
		var name_width := ThemeDB.fallback_font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, MatchView.PALETTE.UNIT_NAME_SIZE).x
		view._draw_text(Vector2(hp_back.get_center().x - name_width * 0.5, label_y), name, MatchView.PALETTE.UNIT_NAME_SIZE, MatchView.PALETTE.MUTED_TEXT)
		if view._state.result == MatchState.RESULT_RUNNING and skill.trigger_type == "manual" and SkillRules.can_activate(unit,skill):
			view.draw_texture_rect(MatchView.SKILL_READY_TEXTURE,skill_ready_rect(view, unit),false)
	frame["selected"] = selected
	frame["ball_center"] = ball_center
	return true


func draw_arena(view: MatchView) -> void:
	var uv := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	if view._floor_mesh == null or view._floor_mesh_mirrored != view.mirror_board:
		var vertices := PackedVector2Array()
		var texture_uv := PackedVector2Array()
		var indices := PackedInt32Array()
		view._floor_grid_lines.clear()
		for row in MatchView.CONFIG.GRID_ROWS:
			for column in MatchView.CONFIG.GRID_COLUMNS:
				var start := vertices.size()
				var quad := view.projection.cell_polygon(Vector2i(column, row), 0.0, false)
				vertices.append_array(quad)
				for edge in 4:
					view._floor_grid_lines.append_array(PackedVector2Array([quad[edge], quad[(edge + 1) % 4]]))
				texture_uv.append_array(uv)
				indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = texture_uv
		arrays[Mesh.ARRAY_INDEX] = indices
		view._floor_mesh = ArrayMesh.new()
		view._floor_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		view._floor_mesh_mirrored = view.mirror_board
	view.draw_mesh(view._floor_mesh, MatchView.FLOOR_TILE)
	view.draw_multiline(view._floor_grid_lines, Color(MatchView.PALETTE.ARENA_GRID, 0.65), 1.0, true)
	for row in MatchView.CONFIG.GRID_ROWS:
		for column in MatchView.CONFIG.GRID_COLUMNS:
			var cell := Vector2i(column, row)
			var terrain := view._state.terrain_at(cell)
			if terrain == "high":
				var base := view.projection.cell_polygon(cell, 0.0, false)
				var top := view.projection.cell_polygon(cell)
				var shadow := base.duplicate()
				for index in shadow.size(): shadow[index] += Vector2(5, 5)
				view.draw_colored_polygon(shadow, Color(MatchView.PALETTE.BACKGROUND, 0.45))
				for edge in 4:
					var next := (edge + 1) % 4
					view.draw_colored_polygon(PackedVector2Array([top[edge], top[next], base[next], base[edge]]), MatchView.PALETTE.HUD_RULE if edge == 2 else MatchView.PALETTE.HUD_INSET)
				view.draw_polygon(top, PackedColorArray([Color.WHITE]), uv, MatchView.PLATFORM_TILE)
				view.draw_polyline(view.projection.closed_polygon(top), MatchView.PALETTE.ARROW if cell in view._state.platform_cells else MatchView.PALETTE.PLATFORM_EDGE, 1.0, true)
			elif terrain == "ground_no_deploy":
				var mark := view.projection.cell_polygon(cell, 0.17)
				for edge in 4:
					for segment in 3:
						var start := mark[edge].lerp(mark[(edge + 1) % 4], segment / 3.0)
						var end := mark[edge].lerp(mark[(edge + 1) % 4], (segment + 0.5) / 3.0)
						view.draw_line(start, end, Color(MatchView.PALETTE.ARROW, 0.5), 1.0, true)
	for side in 2:
		var goal := view.projection.goal_line(side)
		var color := MatchView.PALETTE.BLUE if side == 0 else MatchView.PALETTE.RED
		view.draw_line(goal[0], goal[1], color, 3.0, true)
		var column := 0 if side == 1 else MatchView.CONFIG.GRID_COLUMNS
		for row in MatchView.CONFIG.GRID_ROWS:
			var front := view.projection.board_point(Vector2(column, row + 0.1))
			var back := view.projection.board_point(Vector2(column, row + 0.9))
			var lift := Vector2(0, MatchView.PALETTE.CELL_SIZE * MatchView.PALETTE.BOARD_ZOOM * 0.4)
			var outward := view.projection.view_direction(Vector2(-1 if side == 1 else 1, 0), Vector2i(column, row)) * MatchView.PALETTE.CELL_SIZE * 0.4
			var base := PackedVector2Array([front, front + outward, back + outward, back])
			view.draw_colored_polygon(base, Color(color, 0.08))
			var roof := PackedVector2Array()
			for point in base:
				roof.append(point - lift)
				view.draw_line(point, point - lift, Color(color, 0.55), 1.0, true)
			view.draw_polyline(view.projection.closed_polygon(roof), Color(color, 0.65), 1.3, true)


func draw_bombs(view: MatchView) -> void:
	var cell_size := float(MatchView.PALETTE.CELL_SIZE) * MatchView.PALETTE.BOARD_ZOOM
	var live := {}
	for bomb in view._state.w_bombs:
		var center := view.projection.cell_rect(bomb.cell).get_center()
		if bomb.kind==0:
			live[bomb.bomb_id]=true
			if not view._w_mine_models.has(bomb.bomb_id):
				var model := OperatorSpineVisual.new()
				if not model.initialize("w_mine"):push_error(model.last_error);view.get_tree().quit(1);return
				view._w_mine_models[bomb.bomb_id]=model
			var model: OperatorSpineVisual=view._w_mine_models[bomb.bomb_id]
			var unit := UnitState.new(bomb.bomb_id,bomb.side,"w_mine",bomb.cell,1,0,0,bomb.facing)
			unit.deployed_tick=bomb.placed_tick
			unit.last_attack_tick=bomb.explode_tick-45 if bomb.explode_tick>=0 else -1
			if not model.prepare(unit,view._bone_tick,45):push_error(model.last_error);view.get_tree().quit(1);return
			var scale := model.scale_for_row(unit_row_width(view,unit))
			view.draw_set_transform(center+model.anchor_offset(scale),0,Vector2(-scale if view.mirror_board else scale,scale))
			if model.mesh.get_surface_count()>0:view.draw_mesh(model.mesh,model.texture)
			view.draw_set_transform(Vector2.ZERO)
		else:
			var left := maxf(0.0,bomb.explode_tick-view._bone_tick)
			view.draw_arc(center,cell_size*0.4,-PI/2,-PI/2+TAU*left/90.0,24,MatchView.PALETTE.RED,2.0,true)
			view._draw_text(center+Vector2(-5,-cell_size*0.3),"!",19,MatchView.PALETTE.ARROW)
	for id in view._w_mine_models.keys():
		if not live.has(id):view._w_mine_models.erase(id)
	for event in view._state.w_explosion_events:
		var age := view._bone_tick-event[4]
		if age<0.0 or age>8.0:continue
		var center := view.projection.cell_rect(Vector2i(event[1],event[2])).get_center()
		view.draw_arc(center,cell_size*(0.25+age*0.06),0,TAU,32,Color(MatchView.PALETTE.ARROW,1.0-age/8.0),3.0,true)
	for field in view._state.classic_attack_fields:
		var tint := Color(MatchView.PALETTE.BLUE,0.14) if field.kind==1 else Color(MatchView.PALETTE.HEAL_RANGE,0.14)
		if field.kind==1:
			for offset in field.offsets:
				var cell: Vector2i=field.cell+offset
				if cell.x>=0 and cell.x<MatchView.CONFIG.GRID_COLUMNS and cell.y>=0 and cell.y<MatchView.CONFIG.GRID_ROWS:view._draw_cell_color(cell,tint,0.08)
		else:view._draw_cell_color(field.cell,tint,0.08)
		var center := view.projection.cell_rect(field.cell).get_center()
		view.draw_arc(center,cell_size*(0.18+0.05*sin(view._bone_tick*0.4)),0,TAU,24,Color(tint,0.7),2.0,true)
	for source in view._state.units:
		if source.operator_id!="rosa" or source.skill_ticks_left<=0:continue
		for id in source.skill_hit_ids:
			var target := WArtilleryRules.owner(view._state,id)
			if target!=null:view.draw_line(view.projection.cell_rect(source.cell).get_center(),view.projection.cell_rect(target.cell).get_center(),Color(MatchView.PALETTE.BLUE,0.65),2.0,true)
	for field in view._state.lumen_rain_fields:
		view._draw_cell_color(field.cell,Color(MatchView.PALETTE.HEAL_RANGE,0.15),0.08)
	for bomb in view._state.champagne_bombs:
		var center := view.projection.cell_rect(bomb.cell).get_center()
		var radius := cell_size * 0.15
		if bomb.triggered_tick >= 0:
			var progress := clampf(float(view._state.tick-bomb.triggered_tick)/12.0,0.0,1.0)
			view.draw_arc(center,radius+progress*cell_size*0.45,0,TAU,24,Color(MatchView.PALETTE.ARROW,1.0-progress),2.0,true)
		else:
			view.draw_arc(center,radius*1.4,0,TAU,16,MatchView.PALETTE.BLUE if bomb.side==0 else MatchView.PALETTE.RED,1.0,true)


func draw_range(view: MatchView, operator: OperatorData, cell: Vector2i, facing: int) -> void:
	var selected := view._selected_unit()
	var skill := operator.skills[selected.skill_index if selected != null and selected.operator_id == operator.operator_id else view._state.carried_skill_index(view._local_input.side, operator.operator_id)]
	if skill.effect_type == "passive_heal":
		var radius := int(skill.effect_params["heal_radius"])
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var heal_cell := cell + Vector2i(x, y)
				if (x != 0 or y != 0) and view.projection.cell_is_inside(heal_cell):
					view._draw_cell_color(heal_cell, Color(MatchView.PALETTE.HEAL_RANGE, 0.22), 0.02)
					view.draw_polyline(view.projection.closed_polygon(view.projection.cell_polygon(heal_cell, 0.02)), Color(MatchView.PALETTE.HEAL_RANGE, 0.7), 1.0, true)
	if skill.effect_type == "champagne_traps":
		for offset in skill.burst_range_override:
			var bomb_cell := cell + offset
			if view.projection.cell_is_inside(bomb_cell): view._draw_cell_color(bomb_cell,Color(MatchView.PALETTE.ARROW,0.13),0.02)
	for offset in view._range_offsets(operator, cell):
		var range_cell := cell + MatchView.RANGE.rotate_offset(offset, facing)
		if view.projection.cell_is_inside(range_cell):
			var color := MatchView.PALETTE.HEAL_RANGE if operator.damage_type == "healing" else MatchView.PALETTE.ATTACK_RANGE
			view._draw_cell_color(range_cell, Color(color, 0.22), 0.02)
			view.draw_polyline(view.projection.closed_polygon(view.projection.cell_polygon(range_cell, 0.02)), Color(color, 0.7), 1.0, true)


func unit_row_width(view: MatchView, unit: UnitState) -> float:
	return (view.projection.board_point(Vector2(unit.cell) + Vector2(1.5, 0.5)) - view.projection.board_point(Vector2(unit.cell) + Vector2(0.5, 0.5))).length()


func unit_health_rect(view: MatchView, unit: UnitState) -> Rect2:
	var width := unit_row_width(view, unit)
	var foot := unit_screen_center(view, unit)
	if not OperatorSpineMap.has(unit.operator_id):
		foot.y += view.projection.cell_rect(unit.cell).size.y * 0.5 - MatchView.PALETTE.CELL_SIZE * MatchView.PALETTE.BOARD_ZOOM * MatchView.PALETTE.UNIT_INSET_RATIO
	return Rect2(foot + Vector2(-width * MatchView.PALETTE.UNIT_STATUS_WIDTH_RATIO * 0.5, width * MatchView.PALETTE.UNIT_STATUS_FOOT_GAP_RATIO), Vector2(width * MatchView.PALETTE.UNIT_STATUS_WIDTH_RATIO, MatchView.PALETTE.UNIT_STATUS_BAR_HEIGHT))


func skill_ready_rect(view: MatchView, unit: UnitState) -> Rect2:
	var width := unit_row_width(view, unit)
	var top := unit_screen_center(view, unit)
	if OperatorSpineMap.has(unit.operator_id):
		top.y -= width * OperatorSpineVisual.BODY_CELL_RATIO
	else:
		top.y -= view.projection.cell_rect(unit.cell).size.y * 0.5 - MatchView.PALETTE.CELL_SIZE * MatchView.PALETTE.BOARD_ZOOM * MatchView.PALETTE.UNIT_INSET_RATIO
	var icon_size := clampf(width * MatchView.PALETTE.UNIT_READY_SIZE_RATIO, 18.0, 26.0)
	var rect := Rect2(top + Vector2(-icon_size * 0.5, -width * MatchView.PALETTE.UNIT_READY_HEAD_GAP_RATIO - icon_size), Vector2.ONE * icon_size)
	if rect.position.y < 54:
		rect.position += Vector2(width * 0.55, 54 - rect.position.y)
	return rect


func draw_football(view: MatchView, ball_center: Vector2, roll: float) -> void:
	var cell_size := float(MatchView.PALETTE.CELL_SIZE) * MatchView.PALETTE.BOARD_ZOOM
	if view._state.ball.move_ticks_left > 0:
		view.draw_line(ball_center - view.projection.view_direction(Vector2(view._state.ball.move_direction), view._state.ball.cell) / MatchView.PALETTE.BOARD_ZOOM * cell_size * 0.25, ball_center, Color(MatchView.PALETTE.BALL, 0.18), cell_size * 0.32, true)
	view.draw_set_transform(ball_center+Vector2(1,cell_size*0.16),0,Vector2(1,0.35))
	view.draw_circle(Vector2.ZERO,cell_size*0.34,Color(MatchView.PALETTE.BACKGROUND,0.7))
	var ball_size := Vector2.ONE * cell_size * 0.72
	view.draw_set_transform(ball_center,roll)
	view.draw_texture_rect(MatchView.FOOTBALL_TEXTURE,Rect2(-ball_size*0.5,ball_size),false)
	view.draw_set_transform(Vector2.ZERO)


func unit_screen_center(view: MatchView, unit: UnitState) -> Vector2:
	var endpoint := view.projection.cell_rect(unit.cell).get_center()
	if unit.displacement_ticks_left == 0:
		return endpoint
	var fraction := view._simulation_fraction() if view._state.result == MatchState.RESULT_RUNNING and not view.get_tree().paused else 0.0
	var progress := clampf(1.0 - (unit.displacement_ticks_left - fraction) / unit.displacement_duration_ticks, 0.0, 1.0)
	return view.projection.cell_rect(unit.displacement_origin).get_center().lerp(endpoint, progress)


func draw_tactical_effects(view: MatchView, visual_tick: float) -> void:
	for unit in view._state.units:
		if unit.operator_id!="projekt_red" or unit.skill_index!=1 or unit.launch_started_tick<0:continue
		var age := visual_tick-unit.launch_started_tick
		if age<0.0 or age>=10.0:continue
		for offset in view._operator_data[unit.operator_id].skills[1].attack_range_override:
			var cell := unit.cell+AttackRange.rotate_offset(offset,unit.facing)
			if view.projection.cell_is_inside(cell):view._draw_cell_color(cell,Color(MatchView.PALETTE.HEAL_RANGE,0.3*(1.0-age/10.0)),0.07)
	for unit in view._state.units:
		var age := visual_tick-unit.texas_cast_tick
		if unit.texas_cast_tick<0 or age<0.0 or age>=10.0:continue
		var data: OperatorData=view._operator_data[unit.operator_id]
		for offset in data.skills[unit.skill_index].attack_range_override:
			var cell := unit.cell+AttackRange.rotate_offset(offset,unit.facing)
			if view.projection.cell_is_inside(cell):view._draw_cell_color(cell,Color(MatchView.PALETTE.HEAL_RANGE,0.3*(1.0-age/10.0)),0.07)

	var size := float(MatchView.PALETTE.CELL_SIZE) * MatchView.PALETTE.BOARD_ZOOM
	for effect in view._state.tactical_item_effects:
		var center := view.projection.cell_rect(effect.cell).get_center()
		var color := MatchView.PALETTE.BLUE if effect.side == 0 else MatchView.PALETTE.RED
		var progress := clampf((visual_tick - effect.effect_tick) / MatchView.CONFIG.ITEM_FEEDBACK_TICKS, 0.0, 1.0)
		var fade := 1.0 - progress
		if effect.item_kind == MatchView.CONFIG.TACTICAL_ITEM_SUPPORT_DRONE:
			for row in range(-2, 3):
				for column in range(-2, 3):
					var cell := effect.cell + Vector2i(column, row)
					if TacticalRules.support_covers(effect.cell, cell) and view.projection.cell_is_inside(cell):
						view._draw_cell_color(cell, Color(color, 0.12), 0.10)
			draw_support_drone(view, center - Vector2(0, size * MatchView.PALETTE.SUPPORT_DRONE_LIFT), size * 0.3, color)
			var seconds := ceili(maxf(0, effect.placed_tick + MatchView.CONFIG.ITEM_SUPPORT_DRONE_TICKS - visual_tick) / MatchView.CONFIG.TICK_RATE)
			view._draw_text(center + Vector2(-12, -size * 1.1), "%ds" % seconds, 12, color)
		elif effect.item_kind == MatchView.CONFIG.TACTICAL_ITEM_CRANE:
			var target := view.projection.cell_rect(effect.cell + MatchView.RANGE.rotate_offset(Vector2i.RIGHT, effect.facing)).get_center()
			var raised := target - Vector2(0, size * (0.2 + progress * 0.65))
			view.draw_line(center, center - Vector2(0, size * 0.7), Color(MatchView.PALETTE.ARROW, fade), 2.0, true)
			view.draw_line(center - Vector2(0, size * 0.7), raised, Color(MatchView.PALETTE.ARROW, fade), 2.0, true)
			view.draw_line(raised, raised + Vector2(0, size * 0.18), Color(MatchView.PALETTE.ARROW, fade), 2.0, true)
			view.draw_rect(Rect2(raised + Vector2(-size * 0.18, size * 0.18), Vector2.ONE * size * 0.36), Color(color, fade), false, 2.0)
		elif effect.item_kind == MatchView.CONFIG.TACTICAL_ITEM_PLATFORM:
			var raised := center + Vector2(0, size * (1.0 - progress) * 0.35)
			view.draw_line(raised - Vector2(size * 0.38, 0), raised + Vector2(size * 0.38, 0), Color(MatchView.PALETTE.ARROW, fade), 3.0, true)
			for side in [-1, 1]:
				view.draw_line(center + Vector2(side * size * 0.22, size * 0.35), raised + Vector2(side * size * 0.22, 0), Color(color, fade), 2.0, true)
			view.draw_polyline(view.projection.closed_polygon(view.projection.cell_polygon(effect.cell, 0.06)), Color(MatchView.PALETTE.ARROW, fade * 0.55), 2.0, true)
		elif not effect.activated:
			var windup := clampf((visual_tick - effect.placed_tick) / MatchView.CONFIG.ITEM_STUN_WINDUP_TICKS, 0.0, 1.0)
			var pulse := 0.65 + 0.25 * sin(windup * TAU * 4.0)
			view.draw_circle(center, size * 0.24, MatchView.PALETTE.HUD_SURFACE)
			view.draw_arc(center, size * 0.26, 0.0, TAU, 24, color, 2.0, true)
			view.draw_line(center - Vector2(0, size * 0.24), center - Vector2(0, size * 0.42), MatchView.PALETTE.ARROW, 2.0, true)
			view.draw_circle(center - Vector2(0, size * 0.42), size * 0.07, Color(MatchView.PALETTE.ARROW, pulse))
			view.draw_arc(center, size * 0.43, -PI * 0.5, -PI * 0.5 + TAU * windup, 32, MatchView.PALETTE.ARROW, 2.0, true)
			view._draw_text(center + Vector2(-size * 0.25, size * 0.46), "%.1fs" % (maxf(0.0, effect.effect_tick - visual_tick) / MatchView.CONFIG.TICK_RATE), 10, MatchView.PALETTE.ARROW)
		else:
			for offset in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
				var direction := view.projection.view_direction(Vector2(offset), effect.cell) / MatchView.PALETTE.BOARD_ZOOM
				var end := center + direction * size * (0.3 + progress * 0.8)
				view.draw_line(center + direction * size * 0.15, end, Color(MatchView.PALETTE.ARROW, fade * 0.8), size * 0.06, true)
				view.draw_circle(end, size * 0.08 * fade, Color(MatchView.PALETTE.BALL, fade))
			view.draw_arc(center, size * (0.2 + progress * 0.75), 0.0, TAU, 32, Color(MatchView.PALETTE.ARROW, fade), 2.0, true)


func draw_support_drone(view: MatchView, center: Vector2, radius: float, color: Color) -> void:
	view.draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), color, 2.0, true)
	for direction in [-1, 1]:
		view.draw_arc(center + Vector2(direction * radius, 0), radius * 0.45, 0, TAU, 16, color, 1.5, true)
	view.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius * 0.5), center + Vector2(radius * 0.45, 0), center + Vector2(0, radius * 0.6), center - Vector2(radius * 0.45, 0)]), color)


func draw_ball_feedback(view: MatchView, ball_center: Vector2, cell_size: float) -> void:
	if view._state.ball.accum != Vector2i.ZERO:
		var ratio := minf(1.0, sqrt(float(view._state.ball.accum.length_squared())) / MatchView.BALL_DATA.kick_threshold)
		var bar := Rect2(ball_center + Vector2(-cell_size * 0.5, cell_size * 0.45), Vector2(cell_size, 4))
		view.draw_rect(bar, MatchView.PALETTE.GROUND)
		view.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 4)), MatchView.PALETTE.ARROW)
	var arrow_direction := view._state.ball.move_direction
	if arrow_direction == Vector2i.ZERO and view._state.ball.accum != Vector2i.ZERO:
		arrow_direction = Vector2i(signi(view._state.ball.accum.x), 0) if absi(view._state.ball.accum.x) >= absi(view._state.ball.accum.y) else Vector2i(0, signi(view._state.ball.accum.y))
	if arrow_direction != Vector2i.ZERO:
		var forward := view.projection.view_direction(Vector2(arrow_direction), view._state.ball.cell) / MatchView.PALETTE.BOARD_ZOOM
		var side := Vector2(-forward.y, forward.x)
		var start := ball_center + forward * cell_size * 0.42
		var tip := ball_center + forward * cell_size * 0.9
		view.draw_line(start, tip, MatchView.PALETTE.BACKGROUND, 8.0, true)
		view.draw_line(start, tip, MatchView.PALETTE.ARROW, 4.0, true)
		view.draw_colored_polygon(PackedVector2Array([tip + forward * cell_size * 0.2, tip - forward * cell_size * 0.14 + side * cell_size * 0.2, tip - forward * cell_size * 0.14 - side * cell_size * 0.2]), MatchView.PALETTE.ARROW)


func draw_six_star_effects(view: MatchView,visual_tick: float) -> void:
	for source in view._state.units:
		if source.operator_id!="reed_alter" or source.hp<=0 or source.reed_fireball_carriers.is_empty():continue
		var skill: SkillResource=view._operator_data[source.operator_id].skills[source.skill_index]
		if skill.effect_type!="reed_fireballs" or source.skill_ticks_left<=0:continue
		for carrier_id in source.reed_fireball_carriers:
			var carrier := WArtilleryRules.owner(view._state,carrier_id)
			if carrier==null or carrier.hp<=0:continue
			for index in int(skill.effect_params["ball_count"]):
				var phase := fposmod(visual_tick-source.reed_fireball_started_tick+index*float(skill.effect_params["orbit_ticks"])/int(skill.effect_params["ball_count"]),float(skill.effect_params["orbit_ticks"]))
				var angle := phase*TAU/int(skill.effect_params["orbit_ticks"])
				var cell := Vector2(carrier.cell)+Vector2(cos(angle),sin(angle))*int(skill.effect_params["orbit_radius_milli"])/1000.0
				var point := view.projection.board_point(cell+Vector2(0.5,0.5))
				view.draw_circle(point,3.0,MatchView.PALETTE.ARROW)


func draw_m129_markers(view: MatchView) -> void:
	for unit in view._state.units:
		if unit.hp<=0:continue
		var cell := unit.monstr_origin_cell if MonstrMedicRules.transformed(unit) else unit.cell
		var point := unit.operator_id=="flowing_shape" and unit.flow_point_until_tick>0
		if not point and not MonstrMedicRules.transformed(unit):continue
		var tint := MatchView.PALETTE.BLUE if unit.side==view._local_input.side else MatchView.PALETTE.RED
		view._draw_cell_color(cell,Color(tint,0.16),0.15)
		view.draw_polyline(view.projection.closed_polygon(view.projection.cell_polygon(cell,0.15)),tint,2.0,true)
		var center := view.projection.cell_rect(cell).get_center()
		view._draw_text(center+Vector2(-18,4),"战术点" if point else "返回位",11,tint)


func draw_attack_projectiles(view: MatchView, visual_tick: float) -> void:
	for shot in view._state.attack_projectiles:
		if view.original_vfx.handles_projectile(shot):continue
		var start:=view.projection.cell_rect(shot.source_cell).get_center()
		var end:=view.projection.cell_rect(shot.target_cell).get_center()
		if shot.kind==AttackIntent.TargetKind.UNIT:
			var target:=WArtilleryRules.owner(view._state,shot.target_id)
			if target!=null:end=unit_screen_center(view,target)
		var progress:=clampf((view.attack_visual_tick()-shot.release_tick)/maxi(1,shot.arrival_tick-shot.release_tick),0.0,1.0)
		var head:=start.lerp(end,progress)
		var direction:=(end-start).normalized()
		view.draw_line(head-direction*7.0,head,ViewPalette.ARROW,2.5,true)
