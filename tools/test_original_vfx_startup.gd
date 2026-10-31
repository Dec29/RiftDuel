extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 var session:=NetSession.new(root.get_node("OperatorDB").network_content())
 root.add_child(session)
 session.local_squad=PackedStringArray(["weedy","silverash","eyjafjalla"])
 session.remote_squad=session.local_squad.duplicate()
 session.local_skills=PackedInt32Array([2,2,2]);session.remote_skills=session.local_skills.duplicate()
 session.phase="loading";session._deadline=Time.get_ticks_msec()+15000
 var game=load("res://main.tscn").instantiate();game.session=session;root.add_child(game)
 var saw_warming:=false;var deadline:=Time.get_ticks_msec()+12000
 while not session._local_loaded and Time.get_ticks_msec()<deadline:
  saw_warming=saw_warming or game.match_view.original_vfx.warming
  if game.match_state.tick!=0 or game.is_physics_processing():push_error("Simulation advanced during original VFX preparation");quit(1);return
  await process_frame
 if not session._local_loaded or not saw_warming or game.match_view.original_vfx.warming:push_error("Loaded barrier preceded actual preparation completion");quit(1);return
 if game.match_state.tick!=0 or not game.match_view.is_processing_unhandled_input():push_error("Prepared match startup state");quit(1);return
 game.queue_free();await process_frame;await process_frame
 print("ORIGINAL_VFX_STARTUP_OK: actual main scene, simulation held at tick0, loaded only after native warmup; local control boundary only")
 quit(0)
