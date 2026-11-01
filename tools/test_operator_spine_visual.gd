# 骨骼战斗小人共享专项验收：对每一名已接入 OperatorSpineMap 的干员，验证
# 双方／镜像／四朝向、正背面选择、单页合批、真实攻击动作切换、暂停与结算冻结、
# 撤退释放，以及每次渲染／操作前后模拟 hash 不变。
#
# 各干员的攻击结构不同（复合链 / 单一整段 / 向下变体），断言按该干员实际素材推导，
# 不写死某一名干员的数值。图形模式下每名干员另存棋盘截图。
extends SceneTree

const CONFIG = preload("res://data/config.gd")
const SKELETON_OPERATORS := ["bagpipe", "angelina", "blaze", "ceobe", "exusiai", "eyjafjalla",
	"horn", "hoshiguma", "nightingale", "phantom", "saileach", "schwarz", "shining",
	"silverash", "skadi", "typhon", "ifrit", "siege", "saria", "mostima", "weedy", "magallan", "suzuran", "swire_alter"]
const FACINGS := [0, 1, 2, 3]
# 地面职业与高台职业各用合法格，避免把非法地形当作表现问题。
const GROUND_X := 9
const HIGH_CELLS := [Vector2i(13, 2), Vector2i(7, 2)]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {}
	for operator_id: String in SKELETON_OPERATORS:
		data[operator_id] = load("res://resources/operators/%s.tres" % operator_id)
	# 对局需要完整编队数据，其余干员一并载入，避免用默认八人编队当全集。
	for id in CONFIG.DEFAULT_SQUAD_IDS:
		if not data.has(id):
			data[id] = load("res://resources/operators/%s.tres" % id)
	for operator_id: String in SKELETON_OPERATORS:
		if not OperatorSpineMap.has(operator_id):
			push_error("干员未登记在 OperatorSpineMap：" + operator_id)
			quit(1)
			return
		var operator: OperatorData = data[operator_id]
		if not await _cover_operator(operator_id, operator, data):
			return
		if not _cover_long_run(operator_id, operator, data):
			return
	print("OPERATOR_SPINE_VISUAL_OK models=", SKELETON_OPERATORS.size())
	quit(0)


func _cell_for(operator: OperatorData, side: int, facing: int) -> Vector2i:
	if operator.terrain_requirement == "high":
		return (Vector2i(13, 2) if side == 0 else Vector2i(7, 2)) + Vector2i(facing % 2, (facing / 2) * 6)
	return Vector2i(4 + facing * 4, 5)


func _cover_operator(operator_id: String, operator: OperatorData, data: Dictionary) -> bool:
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(172, data)
			state.tick = 180
			var facings: Array[int] = []
			for facing: int in FACINGS:
				var cell := _cell_for(operator, side, facing)
				state.units.append(UnitState.new(facing, side, operator_id, cell, operator.max_health, 0, 30, facing))
				facings.append(facing)
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
			if not _check(state.state_hash() == before and view._bagpipe_models.size() == 4,
					"%s：四朝向建立骨骼实例且渲染只读" % operator_id): return false
			for facing: int in FACINGS:
				var model: OperatorSpineVisual = view._bagpipe_models[facing]
				# 模拟朝向 0=右 1=下 2=左 3=上；北向背面，其余正面。
				if not _check(model.view_index == (1 if facing == 3 else 0),
						"%s：北向用背面、其余用正面" % operator_id): return false
				if not _check(model.mesh.get_surface_count() == 1,
						"%s：单页直通 alpha 合批为一个绘制面" % operator_id): return false
				if not _check(model.body_height > 1.0,
						"%s：按实际几何量得可见身体高度" % operator_id): return false
			# 攻击表现按该干员真实结构断言。facing 1 为向下（正面素材）。
			var model: OperatorSpineVisual = view._bagpipe_models[1]
			var entry: Dictionary = OperatorSpineMap.entry_for(operator_id)
			var expected: String = "Attack_Begin" if entry.has("chain_seconds") else str(entry["down_clip"] if entry.has("down_clip") else entry["attack_clip"])
			var idle_pose: PackedVector2Array = model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
			state.units[1].last_attack_tick = state.tick - 1
			state.units[1].last_attack_target_x = state.units[1].cell.x
			state.units[1].last_attack_target_y = state.units[1].cell.y + 1
			before = state.state_hash()
			await process_frame
			await process_frame
			if not _check(model.clip == expected,
					"%s：实际播放该模型的攻击动作，期望 %s 实得 %s" % [operator_id, expected, model.clip]): return false
			if not _check(idle_pose != model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
					"%s：攻击确实改变了姿态" % operator_id): return false
			if not _check(state.state_hash() == before, "%s：攻击渲染不回写模拟" % operator_id): return false
			# 向下攻击：只有素材真的有 Down 变体时才要求，且必须被用到。
			# 单位按 FACINGS 顺序追加：索引 0 右、1 下、2 左、3 上。
			# 复合链在攻击起点处于 Begin 段，因此把采样点放在归一化链条的三成处，
			# 才落在 Loop 段（单一整段动作则在任意点都是该动作）。
			if entry.has("down_clip"):
				var down_unit: UnitState = state.units[1]
				down_unit.last_attack_tick = state.tick - 9
				before = state.state_hash()
				await process_frame
				await process_frame
				var down_model: OperatorSpineVisual = view._bagpipe_models[1]
				var wanted: String = "Attack_Loop_Down" if entry.has("chain_seconds") else str(entry["down_clip"])
				if not _check(down_model.clip == wanted,
						"%s：向下攻击使用 %s，实得 %s" % [operator_id, wanted, down_model.clip]): return false
				if not _check(state.state_hash() == before, "%s：向下攻击渲染只读" % operator_id): return false
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				if not _check(root.get_texture().get_image().save_png(
						"res://.godot/spine-%s-side%d-mirror%d.png" % [operator_id, side, int(mirrored)]) == OK,
						"%s：保存棋盘截图" % operator_id): return false
			paused = true
			var frozen: PackedVector2Array = model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
			await process_frame
			view.queue_redraw()
			await process_frame
			if not _check(frozen == model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
					"%s：暂停冻结同一姿态" % operator_id): return false
			paused = false
			state.result = MatchState.RESULT_DRAW
			await process_frame
			frozen = model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
			await process_frame
			if not _check(frozen == model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
					"%s：结算冻结动画" % operator_id): return false
			state.units.clear()
			view.queue_redraw()
			await process_frame
			await process_frame
			if not _check(view._bagpipe_models.is_empty(), "%s：撤退释放骨骼实例" % operator_id): return false
			view.free()
	return true


func _cover_long_run(operator_id: String, operator: OperatorData, data: Dictionary) -> bool:
	var unit := UnitState.new(2, 1, operator_id, _cell_for(operator, 1, 2), operator.max_health, 0, 30, 2)
	var model := OperatorSpineVisual.new()
	if not _check(model.initialize(operator_id), "%s：长寿命骨架初始化：%s" % [operator_id, model.last_error]): return false
	var state := MatchState.new(172, data)
	state.units.append(unit)
	var durations: Array[int] = []
	for batch in 4:
		var started := Time.get_ticks_usec()
		for frame in 240:
			var visual_tick := float(batch * 240 + frame) * 3.0
			unit.last_attack_tick = int(visual_tick) / 30 * 30
			var before := state.state_hash()
			if not _check(model.prepare(unit, visual_tick, 30) and state.state_hash() == before,
					"%s：长时动作循环保持只读" % operator_id): return false
			if not _check(model._source(model.view_index).drain_events(model._instances[model.view_index]).is_empty(),
					"%s：原生动画事件队列已排空" % operator_id): return false
		durations.append(Time.get_ticks_usec() - started)
	var early := durations[0] + durations[1]
	var late := durations[2] + durations[3]
	if not _check(late < early * 3 + 20000, "%s：动作更新时间不随历史增长：%s" % [operator_id, durations]): return false
	return true


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
