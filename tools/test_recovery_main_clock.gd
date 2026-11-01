extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var error := change_scene_to_file("res://main.tscn")
	assert(error == OK)
	await process_frame
	await process_frame
	var battle = current_scene
	var deadline := Time.get_ticks_msec()+30000
	while battle.match_state.tick < 2 and Time.get_ticks_msec() < deadline: await process_frame
	if battle.match_state.tick < 2: push_error("main startup deadline"); quit(1); return
	# Concede a real step to the human side, without sending deployment input.
	battle.match_state.ball.cell.x = 20
	while battle.match_state.recovery_side < 0 and Time.get_ticks_msec() < deadline: await process_frame
	var state: MatchState = battle.match_state
	if state.recovery_side != 0: push_error("human recovery did not start"); quit(1); return
	var clock := state.tick
	var start := Time.get_ticks_msec()
	while state.recovery_side >= 0 and Time.get_ticks_msec() < deadline: await process_frame
	var elapsed := Time.get_ticks_msec()-start
	if elapsed < 14700 or elapsed > 16500 or state.tick > clock+1 or state.recovery_input_ticks != Config.GOAL_RECOVERY_INPUT_TICKS:
		push_error("real15-second recovery clock failed: elapsed=%d battle=%d/%d frames=%d" % [elapsed,state.tick,clock,state.recovery_input_ticks])
		quit(1)
		return
	print("RECOVERY_MAIN_CLOCK_OK actual_ms=%d frozen_battle_tick=%d paused_input_frames=%d" % [elapsed,clock,state.recovery_input_ticks])
	quit(0)
