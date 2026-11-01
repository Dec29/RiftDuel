extends SceneTree
class CaptureView extends MatchView:
	var labels := PackedStringArray()
	func _draw_text(position: Vector2,text: String,font_size: int,color: Color) -> void:
		labels.append(text)
		super(position,text,font_size,color)
var failures := 0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/pvp-view"))
	var room = load("res://view/room_view.tscn").instantiate()
	root.add_child(room)
	var rules := MatchRules.pvp_default()
	var info := {"rules":rules,"can_edit":true,"round":0,"pending":false,"phase":"room","online":true,"status":"双方已加入房间","side":0,"code":"000000","local_ready":true,"remote_ready":true,"local_returned":false,"remote_returned":false,"addresses":""}
	var requested: Array[Dictionary]=[]
	room.rules_requested.connect(func(value: Dictionary) -> void: requested.append(value))
	room.update_room(info)
	await frames()
	var panel: Control=room.get_node("Center/Panel")
	check(root.get_visible_rect().encloses(panel.get_global_rect()),"room fits logical viewport")
	check(not panel.get_node("Room/Columns/Members").get_global_rect().intersects(panel.get_node("Room/Columns/Rules").get_global_rect()),"two columns do not overlap")
	panel.get_node("Room/Columns/Rules/Mode/Score").button_pressed=false
	panel.get_node("Room/Columns/Rules/Mode/Score").pressed.emit()
	check(panel.get_node("Room/Columns/Rules/Mode/Score").button_pressed and requested.is_empty(),"same mode stays selected without invalidating ready")
	panel.get_node("Room/Columns/Rules/Mode/Single").pressed.emit()
	check(requested[-1].mode=="single","actual mode button signal")
	panel.get_node("Room/Columns/Rules/MinutesRow/Minutes").value=12
	check(requested[-1].minutes==12,"actual custom minute input")
	panel.get_node("Room/Columns/Rules/RoundsRow/Rounds").value=3
	check(requested[-1].rounds==3,"actual round input")
	info.rules=MatchRules.new("single",12,3);info.local_ready=false;info.remote_ready=false;room.update_room(info)
	await frames();save("room-host")
	info.side=1;info.can_edit=false;room.update_room(info)
	check(panel.get_node("Room/Columns/Rules/Mode/Score").disabled and not panel.get_node("Room/Columns/Rules/MinutesRow/Minutes").editable and not panel.get_node("Room/ReadyRow/Start").visible,"guest cannot edit or start")
	await frames();save("room-guest")
	info.side=0;info.round=2;room.update_room(info)
	check(panel.get_node("Room/Columns/Rules/Mode/Single").disabled,"series rules stay locked")
	room.free()
	var data := {"bagpipe":load("res://resources/operators/bagpipe.tres")}
	var state := MatchState.new(42,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[],[],MatchRules.new("score",5,3))
	state.goals=PackedInt32Array([2,1]);state.tick=100;state.last_goal_tick=80;state.last_goal_side=0
	state.units.append(UnitState.new(0,0,"bagpipe",Vector2i(13,5),data.bagpipe.max_health,0,30,2))
	var session := NetSession.new(root.get_node("OperatorDB").network_content())
	session.round_number=2;session.match_rules=state.rules.copy();session.series.results=PackedInt32Array([1])
	var view := CaptureView.new();root.add_child(view);view.bind(state,LocalInput.new(0),data);view.session=session;view.multiplayer_match=true
	for mirrored in [false,true]:
		view.mirror_board=mirrored;view.labels.clear();var before := state.state_hash();await frames()
		check(state.state_hash()==before,"HUD is read only")
		check(view._bagpipe_models.size()==1,"formal native operator model present")
		check(view.labels.has("蓝 2 : 1 红" if mirrored else "红 1 : 2 蓝"),"scores follow mirrored goal identities")
		save("score-mirror%d"%int(mirrored))
	state.result=2;session.round_number=3;session.series.results=PackedInt32Array([1,1,2]);view.result_confirmed=true;view.labels.clear();await frames()
	check(view.labels.has("蓝方整场胜利") and view.labels.has("返回房间"),"series winner differs from final round winner")
	save("series-final")
	session.round_number=2;session.series.results=PackedInt32Array([1,2]);view.labels.clear();await frames()
	check(view.labels.has("准备下一局"),"intermission action")
	save("intermission")
	view.free();session.free()
	print("PVP_VIEW_OK: actual rule controls, host/guest/lock, 1280x720 containment, mirrored score, final series verdict and read-only HUD; failures=",failures)
	quit(0 if failures==0 else 1)
func frames() -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func save(name: String) -> void:
	check(root.get_texture().get_image().save_png("res://.godot/pvp-view/"+name+".png")==OK,"save screenshot")
func check(value: bool,message: String) -> void:
	if not value:failures+=1;push_error(message)
