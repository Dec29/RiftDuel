extends SceneTree
class IdleAI extends AIInput:
	func _init() -> void:super(1,{"bagpipe":load("res://resources/operators/bagpipe.tres")})
	func commands_for_tick(_state: MatchState) -> Array[InputCommand]:return []
class GateSession extends NetSession:
	func _init(content: Dictionary) -> void:super(content)
	# Local readiness gate only; no sockets or editor-only source fingerprint in a packed QA run.
	func _ready() -> void:pass
var failures:=0
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	var session:=GateSession.new(root.get_node("OperatorDB").network_content());root.add_child(session)
	session.local_squad=PackedStringArray(["exusiai"]);session.remote_squad=PackedStringArray(["bagpipe"])
	session.local_skills=PackedInt32Array([1]);session.remote_skills=PackedInt32Array([0])
	session.phase="loading";session._deadline=Time.get_ticks_msec()+15000
	var game=load("res://main.tscn").instantiate();game.session=session;root.add_child(game)
	while not session._local_loaded:await process_frame
	game.session=null;game.match_view.session=null;game.match_view.multiplayer_match=false
	game.match_view.result_confirmed=true;game.get_node("NetworkLayer/NetworkHUD").hide()
	game.ai_input=IdleAI.new();game._simulation_phase=0
	var state: MatchState=game.match_state;var view: MatchView=game.match_view
	var victim_data: OperatorData=state._operator_data.bagpipe.duplicate(true);victim_data.max_health=100000
	state._operator_data.bagpipe=victim_data;view._operator_data.bagpipe=victim_data
	var actor:=UnitState.new(0,0,"exusiai",Vector2i(12,2),state._operator_data.exusiai.max_health,35,0,2,1)
	var victim:=UnitState.new(1,1,"bagpipe",Vector2i(9,2),100000,0,99999,0)
	state.units=[actor,victim];state.next_unit_id=2;state.ball.cell=Vector2i(10,10)
	game.local_input.queue_skill(0,0,1)
	var samples: Array[Dictionary]=[];var ahead:=false;var future_clock:=false;var fired_pose:=false;var hit:=false
	var deadline:=Time.get_ticks_msec()+15000
	while state.tick<30 and Time.get_ticks_msec()<deadline:
		await process_frame;await RenderingServer.frame_post_draw
		if not view._bagpipe_models.has(0):continue
		var model: OperatorSpineVisual=view._bagpipe_models[0]
		var event_seconds:=.3
		if view._attack_tick>maxf(0.0,float(state.tick)):future_clock=true
		if actor.attack_intent!=null and model.clip==actor.attack_action_clip and model.pose_seconds>=event_seconds:
			ahead=true
		if actor.last_attack_tick>=0 and model.clip=="Attack" and model._prepared_time>=event_seconds-.000001:fired_pose=true
		if victim.hp<100000:hit=true
		samples.append({"tick":state.tick,"physics_phase":view.simulation_phase,"bone_tick":view._bone_tick,"attack_tick":view._attack_tick,"clip":model.clip,"source_seconds":model.pose_seconds,"native_sample":model._prepared_time,"pending":actor.attack_intent!=null,"released":actor.last_attack_tick,"target_hp":victim.hp})
	var folder:="res://.ai/attack-timing-20261023/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	FileAccess.open(folder+"actual-main-clock.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))
	if future_clock:failures+=1;push_error("Actual attack clock extrapolated past the next simulation tick")
	if ahead:failures+=1;push_error("Actual main interpolation displayed source fire pose before simulation release")
	if not fired_pose or not hit or state.tick<30:failures+=1;push_error("Actual main did not show both authored firing pose and later independent impact")
	game.queue_free();await process_frame;await process_frame;session.queue_free();await process_frame
	print("ATTACK_ACTUAL_MAIN_CLOCK: source cue cannot precede authoritative release; normal main physics/process/render, controlled units/SP and idle QA AI, no live network; failures=",failures)
	quit(0 if failures==0 else 1)
