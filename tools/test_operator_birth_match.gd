extends SceneTree
# Accepted deployment commands and actual BattleRenderer; controlled initial fees/IDs only.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	if "soak" in OS.get_cmdline_user_args():
		await soak()
		return
	var content: Dictionary={}
	for id in root.get_node("OperatorDB").all_ids():content[id]=root.get_node("OperatorDB").get_data(id)
	var cases:=0
	for id in ["eyjafjalla_alter","lee","lin","pallas","pozyomka"]:
		for facing in [2,3]:
			for unit_id in [7,12]:
				var ids:=PackedStringArray([id])
				var state:=MatchState.new(136,content,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids])
				state.tick=100;state.next_unit_id=unit_id;state.sides[0].cost=99
				var cell:=Vector2i(11,5) if content[id].terrain_requirement=="ground" else Vector2i(12,2)
				state.step([InputCommand.new(100,0,id,-1,cell,-1,facing)],[])
				if state.units.size()!=1 or state.units[0].unit_id!=unit_id:
					push_error("Actual birth deployment was rejected "+id);quit(1);return
				var view:=MatchView.new();view.bind(state,LocalInput.new(0),content);root.add_child(view);view.set_process(false)
				for age in [0,1,6,31]:
					state.tick=101+age;view._bone_tick=100.0+age;view._attack_tick=100.0+age
					var before:=state.state_hash()
					view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
					var model: OperatorSpineVisual=view._bagpipe_models[unit_id]
					if state.state_hash()!=before or (age==0 and model.mesh.get_surface_count()!=0) or (age>=6 and model.mesh.get_surface_count()==0):
						push_error("Birth draw must be transparent then visible and read-only "+id);quit(1);return
					if id=="eyjafjalla_alter" and unit_id==7 and age==6:
						root.get_texture().get_image().save_png("res://.godot/crash-birth-face"+str(facing)+".png")
				view.queue_free();await process_frame
				cases+=1
	print("OPERATOR_BIRTH_MATCH_OK actual_deployments=",cases," draws=",cases*4," front_back_ids7_12 read_only")
	quit(0)
func soak() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline:=Time.get_ticks_msec()+30000
	while not game.is_physics_processing() and Time.get_ticks_msec()<deadline:await process_frame
	if not game.is_physics_processing():push_error("Battle preparation timeout");quit(1);return
	var state: MatchState=game.match_state
	# Exercise the reported birth on the player side immediately; normal AI continues.
	if "eyjafjalla_alter" not in state.squad_ids[0]:push_error("Saved squad no longer includes reported actor");quit(1);return
	state.sides[0].cost=99;state.next_unit_id=7
	game.local_input.select_operator("eyjafjalla_alter");game.local_input.queue_deploy(state.tick,Vector2i(12,2),2)
	var seen: Dictionary={};var frames:=0;var begin:=Time.get_ticks_msec();var start_tick:=state.tick
	while Time.get_ticks_msec()-begin<120000 and state.result==MatchState.RESULT_RUNNING:
		await process_frame;frames+=1
		for u in state.units:seen[u.operator_id]=true
	var seconds:=(Time.get_ticks_msec()-begin)/1000.0
	var valid:=seen.has("eyjafjalla_alter") and (state.tick-start_tick>=2400 or (state.result!=MatchState.RESULT_RUNNING and state.tick>start_tick))
	print("OPERATOR_BIRTH_SOAK ",JSON.stringify({"seconds":seconds,"ticks":state.tick-start_tick,"fps":frames/seconds,"seen":seen.keys(),"result":state.result,"controlled_initial_fee":99,"saved_squad":Array(state.squad_ids[0])}))
	game.queue_free();await process_frame;await process_frame
	if not valid:push_error("Single player soak did not exercise birth and sufficient simulation")
	quit(0 if valid else 1)
