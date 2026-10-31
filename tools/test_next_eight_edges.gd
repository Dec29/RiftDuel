extends SceneTree
var failures := 0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var data := {}
	for id in ["silence","ifrit","bagpipe","typhon","meteorite","gitano"]:data[id]=load("res://resources/operators/"+id+".tres")
	# Sleep cancels a pending ordinary volley but preserves a separately active ground skill.
	var state := MatchState.new(9,data);state.ball.cell=Vector2i(10,10)
	var flame := UnitState.new(0,0,"ifrit",Vector2i(13,2),1000,0,99,2,2)
	var victim := UnitState.new(1,1,"bagpipe",Vector2i(12,2),2484,0,9999)
	flame.skill_ticks_left=300;flame.skill_elapsed_ticks=29;state.units=[flame,victim];state.next_unit_id=2
	StatusRules.add_control(state,flame,"sleep",90)
	var hp := victim.hp;state.step([],[])
	check(victim.hp<hp and flame.skill_ticks_left==299 and flame.attack_ticks_left>0,"Independent flame ground continues under sleep; ordinary cooldown stays frozen")
	var archer := UnitState.new(2,0,"typhon",Vector2i(13,3),1000,0,0,2,2);state.units.append(archer)
	archer.skill_ticks_left=-1;archer.skill_ammo_left=1;archer.rain_arrows_left=4
	StatusRules.add_control(state,archer,"sleep",90)
	check(archer.rain_arrows_left==0 and archer.last_basic_interrupt_tick==state.tick,"Sleep cancels queued enhanced basic arrows")
	# AOE reaches all target categories in the same packet, even while an enemy exists.
	for id in ["meteorite","gitano"]:
		var s := MatchState.new(1,data);s.ball.cell=Vector2i(12,2);s._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);s._ball_data.kick_threshold=1000000
		var unit := UnitState.new(0,0,id,Vector2i(13,2),1000,0,1,2,0)
		var target := UnitState.new(1,1,"bagpipe",Vector2i(12,2),2484,0,9999)
		s.units=[unit,target];s.next_unit_id=2;s.tactical_boxes=[TacticalBox.new(0,Vector2i(12,2),3)]
		s.step([],[])
		check(target.hp<2484 and s.tactical_boxes[0].hits_left==2 and s.ball.accum!=Vector2i.ZERO,id+" independent enemy/box/ball AOE")
	# Deploy the medical device through the real command boundary, then draw both facings.
	state=MatchState.new(7,{"silence":data.silence},MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[PackedStringArray(["silence"]),PackedStringArray(["silence"])],[PackedInt32Array([1]),PackedInt32Array([1])]);state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
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
	actual.save_png("res://.godot/next-eight-view-evidence/medical-drone.png")
	view.queue_free();await process_frame
	print("NEXT_EIGHT_EDGES: sleep/volley/independent effect, AOE categories, real device/native model, full-frame blend parity max_delta=",max_delta," failures=",failures)
	quit(0 if failures==0 else 1)
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
