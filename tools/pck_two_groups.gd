# 正式 PCK 外部图形验收（骨骼小人）。
#
# 由同版本工具引擎以 --main-pack 指向正式 PCK 执行，当前目录是独立解压的游戏包。
# 不依赖可能被发布模式剥离的 assert：全部使用显式条件与 quit(1)。
# 截图写入 E 盘证据目录，不写进交付 ZIP。
extends SceneTree

const CONFIG = preload("res://data/config.gd")
const EVIDENCE := "E:/Godot/RiftDuel/.godot/two-groups-20261018/pck"
const ALL_OPERATORS := ["flametail", "elysium", "mountain", "surtr", "mudrock", "gummy", "rosa", "jessica", "passenger", "haze", "warfarin", "sussurro", "shamare", "podenco", "mizuki", "feater", "curse_doll"]
# 抽查四种真实攻击结构：复合链、向下整段变体、近战单一整段、远程单一整段。
const ATTACK_SAMPLES := ["mountain","passenger","haze","mizuki","feater"]
const GROUND_X := 9
const HIGH_CELLS := [Vector2i(13, 2), Vector2i(7, 2)]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE)
	var data := {}
	for operator_id: String in ALL_OPERATORS:
		var resource := load("res://resources/%s/%s.tres" % ["summons" if operator_id=="curse_doll" else "operators",operator_id])
		if resource == null:
			return _fail("正式 PCK 缺少干员资源：" + operator_id)
		data[operator_id] = resource
	# 1) 本批17种人物／召唤物的骨架资源都在 PCK 内，且是已核定的 3.8 单页直通素材。
	for operator_id: String in ALL_OPERATORS:
		var entry: Dictionary = OperatorSpineMap.entry_for(operator_id)
		for view in 2:
			var skeleton: SpineSkeletonDataResource = OperatorSpineMap.source(entry, view)
			if skeleton == null:
				return _fail("%s 第%d面骨架资源缺失" % [operator_id, view])
			if not skeleton.ensure_loaded():
				return _fail("%s 第%d面骨架加载失败：%s" % [operator_id, view, skeleton.get_last_error()])
			if skeleton.get_page_count() != 1 or skeleton.is_page_pma(0):
				return _fail("%s 第%d面不是已核定的单页直通 alpha 素材" % [operator_id, view])
			var page: Texture2D = skeleton.get_page_texture(0)
			if page == null or page.get_width() <= 0:
				return _fail("%s 第%d面纹理页缺失" % [operator_id, view])
	print("PCK_ASSETS_OK operators=", ALL_OPERATORS.size())

	# 2) 每名干员在真实 MatchView 中渲染四朝向、双方、镜像，并保持模拟只读。
	for operator_id: String in ALL_OPERATORS:
		if not await _render_operator(operator_id, data):
			return
	# 3) 抽查真实攻击动作切换。
	for operator_id: String in ATTACK_SAMPLES:
		if not await _attack_sample(operator_id, data):
			return
	print("PCK_VISUAL_OK operators=", ALL_OPERATORS.size(), " attack_samples=", ATTACK_SAMPLES.size())
	quit(0)


func _cell_for(operator: OperatorData, side: int, facing: int) -> Vector2i:
	if operator.terrain_requirement == "high" or (operator.operator_id=="feater" and facing<2):
		return (Vector2i(13, 2) if side == 0 else Vector2i(7, 2)) + Vector2i(facing % 2, (facing / 2) * 6)
	return Vector2i(4 + facing * 4, 5)


func _render_operator(operator_id: String, data: Dictionary) -> bool:
	var operator: OperatorData = data[operator_id]
	for side in 2:
		for mirrored in [false, true]:
			var state := MatchState.new(172, data)
			state.tick = 180
			for facing in 4:
				state.units.append(UnitState.new(facing, side, operator_id,
						_cell_for(operator, side, facing), operator.max_health, 0, 30, facing))
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
			if view._bagpipe_models.size() != 4:
				return _fail("%s：四朝向未全部建立骨骼实例" % operator_id)
			if state.state_hash() != before:
				return _fail("%s：渲染回写了模拟" % operator_id)
			for facing in 4:
				var model: OperatorSpineVisual = view._bagpipe_models[facing]
				if model.mesh.get_surface_count() != 1:
					return _fail("%s：合批面数不为 1" % operator_id)
				if model.view_index != (1 if facing == 3 else 0):
					return _fail("%s：朝向 %d 的素材面选择不符（实得 %d）" % [operator_id, facing, model.view_index])
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var out := "%s/pck-%s-side%d-mirror%d.png" % [EVIDENCE, operator_id, side, int(mirrored)]
			if image.save_png(out) != OK:
				return _fail("截图写入失败：" + out)
			# 逐名抽样核对画面里确实存在该干员的非透明像素（不是空白/几何占位）。
			if not _has_sprite_pixels(view, state):
				return _fail("%s：棋盘上未找到骨骼小人的可见像素" % operator_id)
			view.free()
	return true


func _has_sprite_pixels(view: MatchView, state: MatchState) -> bool:
	var image := root.get_texture().get_image()
	for unit in state.units:
		var logical := view.projection.cell_rect(unit.cell)
		var rect := root.get_final_transform()*logical
		var top := Vector2i(int(rect.position.x), int(rect.position.y - rect.size.y * 0.9))
		for y in range(maxi(0, top.y), mini(image.get_height(), top.y + int(rect.size.y))):
			for x in range(maxi(0, top.x), mini(image.get_width(), top.x + int(rect.size.x))):
				var color := image.get_pixel(x, y)
				# 核对比暗色地砖明显明亮的原生纹理像素，兼容山的灰白服装。几何面数与攻击姿态另行核对。
				if color.a > 0.9 and maxf(color.r,maxf(color.g,color.b))>0.55:
					return true
	return false


func _attack_sample(operator_id: String, data: Dictionary) -> bool:
	var operator: OperatorData = data[operator_id]
	var entry: Dictionary = OperatorSpineMap.entry_for(operator_id)
	var state := MatchState.new(172, data)
	state.tick = 180
	state.units.append(UnitState.new(1, 0, operator_id, _cell_for(operator, 0, 1), operator.max_health, 0, 30, 1))
	var input := LocalInput.new(0)
	var view := MatchView.new()
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(view)
	view.bind(state, input, data)
	await process_frame
	await process_frame
	var model: OperatorSpineVisual = view._bagpipe_models[1]
	var idle: PackedVector2Array = model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	state.units[0].last_attack_tick = state.tick - 1
	var before := state.state_hash()
	await process_frame
	await process_frame
	var wanted: String = "Attack_Begin" if entry.has("chain_seconds") else str(entry["down_clip"] if entry.has("down_clip") else entry["attack_clip"])
	if model.clip != wanted:
		return _fail("%s：攻击动作不符，期望 %s 实得 %s" % [operator_id, wanted, model.clip])
	if model.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == idle:
		return _fail("%s：攻击未改变姿态" % operator_id)
	if state.state_hash() != before:
		return _fail("%s：攻击渲染回写模拟" % operator_id)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/pck-attack-%s.png" % [EVIDENCE, operator_id])
	print("PCK_ATTACK_OK ", operator_id, " clip=", model.clip)
	view.free()
	return true


func _fail(message: String) -> bool:
	_failures += 1
	push_error("PCK 验收失败：" + message)
	quit(1)
	return false
