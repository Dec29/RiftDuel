# 能天使（exusiai）战斗骨骼专项验收。
#
# 覆盖：双方／镜像／四朝向、正背面选择、单页合批、真实攻击动作切换、暂停与结算
# 冻结、撤退释放，以及每次渲染／操作前后模拟 hash 不变。图形模式下另存棋盘截图。
extends SceneTree

const CONFIG = preload("res://data/config.gd")
const OPERATOR_ID := "exusiai"
# 能天使是狙击，只能站高台；这些格属于地图原有高台。
const FRONT_CELLS := [Vector2i(13, 2), Vector2i(13, 8)]
const BACK_CELLS := [Vector2i(7, 2), Vector2i(7, 8)]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {}
	for id in CONFIG.DEFAULT_SQUAD_IDS:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var operator: OperatorData = data[OPERATOR_ID]
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(172, data)
			state.tick = 180
			for facing in 4:
				var cell: Vector2i = FRONT_CELLS[side] if facing != 3 else BACK_CELLS[side]
				state.units.append(UnitState.new(facing, side, OPERATOR_ID, cell, operator.max_health, 0, 30, facing))
			var input := LocalInput.new(side)
			var view := MatchView.new()
			view.process_mode = Node.PROCESS_MODE_PAUSABLE
			root.add_child(view)
			view.bind(state, input, data)
			view.mirror_board = mirrored
			input.select_unit(1)
			var before := state.state_hash()
			await process_frame
			await process_frame
			if not _check(state.state_hash() == before and view._bagpipe_models.size() == 4, "四朝向都建立骨骼实例且渲染只读"): return
			for facing in 4:
				var model: OperatorSpineVisual = view._bagpipe_models[facing]
				if not _check(model.view_index == (1 if facing == 3 else 0), "北向用背面、其余用正面"): return
				if not _check(model.mesh.get_surface_count() == 1, "单页直通 alpha 合批为一个绘制面"): return
			# 攻击：能天使用单一整段 Attack，不是风笛的复合链。
			var model: OperatorSpineVisual = view._bagpipe_models[1]
			var idle_pose: PackedVector2Array = model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
			state.units[1].last_attack_tick = state.tick - 8
			state.units[1].last_attack_target_x = state.units[1].cell.x
			state.units[1].last_attack_target_y = state.units[1].cell.y + 1
			before = state.state_hash()
			await process_frame
			await process_frame
			if not _check(model.clip == "Attack", "实际播放该模型的 Attack 动作：%s" % model.clip): return
			if not _check(idle_pose != model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "攻击确实改变了姿态"): return
			if not _check(state.state_hash() == before, "攻击渲染不回写模拟"): return
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				if not _check(root.get_texture().get_image().save_png("res://.godot/exusiai-side%d-mirror%d.png" % [side, int(mirrored)]) == OK, "保存棋盘截图"): return
			paused = true
			var frozen: PackedVector2Array = model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
			await process_frame
			view.queue_redraw()
			await process_frame
			if not _check(frozen == model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "暂停冻结同一姿态"): return
			paused = false
			state.result = MatchState.RESULT_DRAW
			await process_frame
			frozen = model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
			await process_frame
			if not _check(frozen == model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "结算冻结动画"): return
			state.units.clear()
			view.queue_redraw()
			await process_frame
			await process_frame
			if not _check(view._bagpipe_models.is_empty(), "撤退释放骨骼实例"): return
			view.free()

	# 六分钟动作循环不得留下增长的混合链。
	var unit := UnitState.new(2, 1, OPERATOR_ID, Vector2i(13, 2), operator.max_health, 0, 30, 2)
	var model := OperatorSpineVisual.new()
	if not _check(model.initialize(OPERATOR_ID), "长寿命骨架初始化：%s" % model.last_error): return
	var state := MatchState.new(172, data)
	state.units.append(unit)
	var before := state.state_hash()
	var durations: Array[int] = []
	for batch in 8:
		var started := Time.get_ticks_usec()
		for frame in 480:
			var visual_tick := float(batch * 480 + frame) * 3.0
			unit.last_attack_tick = int(visual_tick) / 30 * 30
			before = state.state_hash()
			if not _check(model.prepare(unit, visual_tick, 30) and state.state_hash() == before, "六分钟动作循环保持只读"): return
			if not _check(model._source(model.view_index).drain_events(model._instances[model.view_index]).is_empty(), "原生动画事件队列已排空"): return
		durations.append(Time.get_ticks_usec() - started)
	var early := durations[1] + durations[2]
	var late := durations[6] + durations[7]
	if not _check(late < early * 3 + 20000, "动作更新时间不随历史增长：%s" % [durations]): return
	print("EXUSIAI_LONG_ACTION_US ", durations)
	print("EXUSIAI_VISUAL_OK")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
