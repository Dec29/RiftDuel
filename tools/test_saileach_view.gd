extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := {"saileach":load("res://resources/operators/saileach.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
	var state := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["saileach","bagpipe"],["bagpipe"]])
	state.units = [UnitState.new(0,0,"saileach",Vector2i(12,5),1835,0,1,0)]
	state.units[0].skill_ticks_left = 200
	state.sides[0].cost = 11
	state.sides[0].next_deploy_discount = 2
	var input := LocalInput.new(0)
	var view := MatchView.new()
	view.bind(state,input,data)
	root.add_child(view)
	input.select_unit(0)
	view.queue_redraw()
	var before := state.state_hash()
	await process_frame
	await process_frame
	if not _check(state.state_hash() == before and SkillRules.block_count_value(state.units[0],data["saileach"]) == 0 and view._operator_available(data["bagpipe"]) and DeployRules.actual_cost(data["bagpipe"],state.sides[0]) == 11, "Active flag block0, discounted available11 card and render read-only"):
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png("res://.godot/saileach-active-view.png") == OK, "Active flag screenshot save"):
			return
	input.select_operator("bagpipe")
	view.queue_redraw()
	await process_frame
	await process_frame
	if not _check(state.state_hash() == before and view._operator_available(data["bagpipe"]), "Discounted card remains available and inspectable without mutation"):
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png("res://.godot/saileach-discount-view.png") == OK, "Discounted card screenshot save"):
			return
	state.sides[0].next_deploy_discount = 0
	if not _check(not view._operator_available(data["bagpipe"]), "Card becomes unavailable at11 after coupon removed"):
		return
	print("Saileach view: dynamicblock0, actual11 cost card/availability/information, render preserves hash")
	quit(0)


func _check(condition: bool,message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
