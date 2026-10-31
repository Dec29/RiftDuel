extends SceneTree
# Real main loop with the locally saved squad; does not modify the saved squad.
# Device performance evidence, not a portable hardware speed guarantee.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1280,720)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline:=Time.get_ticks_msec()+30000
	while not game.is_physics_processing() and Time.get_ticks_msec()<deadline:await process_frame
	if not game.is_physics_processing():push_error("Battle preparation timed out");quit(1);return
	var frames: Array[float]=[]
	var begin:=Time.get_ticks_usec();var previous:=begin;var tick: int=game.match_state.tick
	while Time.get_ticks_usec()-begin<15000000:
		await process_frame
		var now:=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
	frames.sort()
	var seconds:=(Time.get_ticks_usec()-begin)/1000000.0
	var result:={"driver":RenderingServer.get_current_rendering_driver_name(),"seconds":seconds,"frames":frames.size(),"fps":frames.size()/seconds,"frame_ms_p95":frames[int(frames.size()*.95)],"frame_ms_max":frames[-1],"ticks":game.match_state.tick-tick,"units":game.match_state.units.size(),"squad":Array(game.match_state.squad_ids[0])}
	print("BATTLE_PERFORMANCE ",JSON.stringify(result))
	var passed: bool=result.fps>=45 and result.frame_ms_p95<50 and result.ticks>=300
	game.queue_free();await process_frame;await process_frame
	if not passed:push_error("Battle did not sustain playable frame rate and simulation throughput on this device")
	quit(0 if passed else 1)
