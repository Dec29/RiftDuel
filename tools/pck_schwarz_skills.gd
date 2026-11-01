# 从独立解压的正式PCK执行；显式检查，不依赖发布assert。
extends SceneTree

const RANGE := preload("res://sim/attack_range.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not check(args.size() == 1, "Pass absolute E-drive evidence directory"): return
	DirAccess.make_dir_recursive_absolute(args[0])
	var data := {"schwarz":load("res://resources/operators/schwarz.tres")}
	var black: OperatorData = data["schwarz"]
	if not check(black.skills.size() == 3 and black.skills[1].skill_name == "暮眼锐瞳" and black.skills[2].skill_name == "战术的终结", "Packed skills/names"): return
	if not check(SquadConfig.validate_loadout(["schwarz"],[2]).is_empty(), "Packed S3 accepted by squad"): return
	var state := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["schwarz"],["schwarz"]],[[1],[2]])
	state.sides[0].cost = 99
	state.sides[1].cost = 99
	state.ball.cell = Vector2i(10,5)
	state.step([InputCommand.new(0,0,"schwarz",-1,Vector2i(12,2))],[InputCommand.new(0,0,"schwarz",-1,Vector2i(8,8))])
	if not check(state.units.size() == 2 and state.units[0].sp == 20 and state.units[1].sp == 12, "Packed per-side deployment SP"): return
	state.units[0].sp = 30
	state.units[1].sp = 25
	state.step([InputCommand.new(1,1,"",0,Vector2i.ZERO,1)],[InputCommand.new(1,1,"",1,Vector2i.ZERO,2)])
	if not check(state.units[0].skill_ticks_left == 1199 and state.units[1].skill_ticks_left == 749 and SkillRules.attack_value(state.units[0],black) == 1932 and SkillRules.attack_value(state.units[1],black) == 2352 and SkillRules.attack_interval_ticks(state.units[1],black) == 60, "Packed actual boosts/durations/interval"): return
	var line: Array[Vector2i] = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(4,0)]
	if not check(RANGE.effective_offsets(state.units[1],black) == line, "Packed five-cell active S3"): return
	var input := LocalInput.new(1)
	input.select_unit(1)
	var view := MatchView.new()
	view.bind(state,input,data)
	root.add_child(view)
	view._info_tab = view.InfoTab.COMMAND
	for mirrored in [false,true]:
		view.mirror_board = mirrored
		for facing in 4:
			state.units[1].facing = facing
			var before := state.state_hash()
			view.queue_redraw()
			await process_frame
			await process_frame
			if not check(before == state.state_hash() and view._range_offsets(black,state.units[1].cell) == line and view._bagpipe_models.size() == 2, "Packed read-only view/range/two skeletons"): return
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				if not check(root.get_texture().get_image().save_png(args[0]+"/pck-schwarz-mirror%d-facing%d.png" % [int(mirrored),facing]) == OK, "Packed screenshot"): return
	for ignored in 749:
		state.step([], [])
	if not check(state.units[1].skill_ticks_left == 0 and state.units[0].skill_ticks_left == 450 and RANGE.effective_offsets(state.units[1],black) == black.attack_range and SkillRules.attack_value(state.units[1],black) == 840, "Packed S3 expiry/restoration"): return
	for ignored in 450:
		state.step([], [])
	if not check(state.units[0].skill_ticks_left == 0 and SkillRules.attack_value(state.units[0],black) == 840, "Packed S2 expiry/restoration"): return
	view.queue_free()
	print("PCK Schwarz S2/S3 OK: runtime data, real activation/expiry, four directions/mirror, two skeletons and readonly rendering")
	quit(0)


func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
