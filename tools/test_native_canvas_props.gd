extends SceneTree
var failures := 0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	var data := {"silence":load("res://resources/operators/silence.tres")}
	# Deploy the medical device through the real command boundary, then draw both facings.
	var state:=MatchState.new(7,{"silence":data.silence},MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[PackedStringArray(["silence"]),PackedStringArray(["silence"])],[PackedInt32Array([1]),PackedInt32Array([1])]);state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state.step([InputCommand.new(0,0,"silence",-1,Vector2i(13,2),-1,2)],[])
	state.units[0].medical_drone_stock=1
	state.step([InputCommand.new(state.tick,0,"medical_drone",-1,Vector2i(15,5),-1,2)],[])
	if not (state.units.size()==2 and state.units[1].operator_id=="medical_drone"):push_error("Legal independent device deployment");quit(1);return
	state.tick=120
	var input := LocalInput.new(0);var view := MatchView.new();view.bind(state,input,state._operator_data);root.add_child(view);view.set_process(false)
	await process_frame;await process_frame
	var before := state.state_hash()
	for facing in [2,3]:
		state.units[1].facing=facing;view.queue_redraw();await process_frame;await process_frame
		check(view._bagpipe_models[1].mesh.get_surface_count()==1,"Medical device single native model for facing"+str(facing))
	before=state.state_hash()
	var native_material: Material=view.material
	# Compare the same premultiplied rendering pipeline against its frozen pre-VFX shader.
	# The built-in straight-alpha pipeline has separate GPU rounding (unchanged baseline
	# reproduces delta4 / 56 channels on D3D12); it is not an exact regression oracle.
	var legacy_material := ShaderMaterial.new()
	legacy_material.shader=preload("res://tools/fixtures/native_canvas_before_original_vfx.gdshader")
	view.material=legacy_material;view.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var baseline := root.get_texture().get_image()
	view.material=native_material;view.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var actual := root.get_texture().get_image()
	var a := baseline.get_data();var b := actual.get_data();var max_delta := 0;var changed := 0
	for i in a.size():
		var delta := absi(a[i]-b[i]);max_delta=maxi(max_delta,delta)
		if delta>0:changed+=1
	check(changed==0,"Ordinary pre-VFX shader exact parity, max_delta%d changed_channels=%d"%[max_delta,changed])
	check(before==state.state_hash(),"Device and shared material rendering read-only")
	DirAccess.make_dir_recursive_absolute("res://.ai/menu-summons-20261027/parity/")
	actual.save_png("res://.ai/menu-summons-20261027/parity/medical-drone.png")
	view.queue_free();await process_frame
	print("NATIVE_CANVAS_PROPS: real device/native model, full-frame blend parity max_delta=",max_delta," failures=",failures)
	quit(0 if failures==0 else 1)
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
