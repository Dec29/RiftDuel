extends SceneTree
var peers: Array[NetSession]=[]
var deadline:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func poll() -> bool:
	await create_timer(0.03).timeout
	for p in peers:
		if not check(p.phase!="failed",p.status):return false
	return check(Time.get_ticks_msec()<deadline,"room start timeout")
func run() -> void:
	deadline=Time.get_ticks_msec()+60000
	var args:=OS.get_cmdline_user_args()
	var endpoint:=args[0] if not args.is_empty() else ""
	var output:="res://.ai/room-simplify"
	DirAccess.make_dir_recursive_absolute(output)
	for side in 2:
		var p: NetSession=NetSession.new(root.get_node("OperatorDB").network_content()) if endpoint.is_empty() else RelaySession.new(root.get_node("OperatorDB").network_content())
		root.add_child(p);peers.append(p)
	if endpoint.is_empty():
		peers[0].create_room(24967,"314159",24968)
		peers[1].join_address("127.0.0.1","314159",24967)
	else:
		peers[0].create_online(endpoint)
		while peers[0].phase!="hosting":
			if not await poll():return
		peers[1].join_online(endpoint,peers[0].room_code)
	while peers[0].phase!="room" or peers[1].phase!="room":
		if not await poll():return
	var lobby=load("res://lobby.tscn").instantiate();lobby.session=peers[0];root.add_child(lobby)
	var panel: Control=lobby.get_node("RoomView/Center/Panel")
	var start: Button=panel.get_node("Room/ReadyRow/Start")
	var toggle: CheckButton=panel.get_node("Room/Columns/Rules/Draft")
	await process_frame;await process_frame
	if not check(not panel.get_node("Room/ReadyRow/Ready").visible and start.disabled and start.text=="开始对局","host has no ready button, guest gates start"):return
	if not check(not panel.get_node("Room/Columns/Rules/Description").visible and not panel.get_node("Room/Summary").visible,"multiplayer hides redundant rules"):return
	if not check(toggle.get_theme_stylebox("normal") is StyleBoxEmpty and toggle.get_theme_stylebox("hover") is StyleBoxEmpty,"toggle has no frame"):return
	var rect:=toggle.get_global_rect()
	var move:=InputEventMouseMotion.new();move.position=rect.get_center();root.push_input(move,true)
	await create_timer(0.2).timeout
	if not check(toggle.get_global_rect()==rect and toggle.scale==Vector2.ONE,"hover does not enlarge toggle"):return
	peers[1].set_ready(true)
	while not peers[0].remote_ready:
		if not await poll():return
	if not check(not start.disabled and not peers[0].local_ready,"host can start with only guest ready"):return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/room-host"+("-lan" if endpoint.is_empty() else "-wss")+".png")
	start.pressed.emit();start.pressed.emit()
	while peers[0].phase!="draft" or peers[1].phase!="draft":
		if not await poll():return
	if not check(peers[0].local_ready and peers[1].remote_squad==peers[0].local_squad,"one click sends valid host squad and prepares before BP"):return
	peers[1].draft.request("cancel")
	while peers[0].phase!="room" or peers[1].phase!="room":
		if not await poll():return
	peers[0].set_rules(MatchRules.new("score",5,1,false).to_wire())
	while peers[0].rules_pending or peers[1].rules.draft_enabled:
		if not await poll():return
	# Keep this focused fixture in the room while testing the loading event.
	for connection in peers[0].get_signal_connection_list("match_requested"):peers[0].disconnect("match_requested",connection.callable)
	peers[1].set_ready(true)
	while not peers[0].remote_ready:
		if not await poll():return
	start.pressed.emit()
	while peers[0].phase!="loading" or peers[1].phase!="loading":
		if not await poll():return
	lobby.queue_free();peers[1].close();peers[1].queue_free()
	await process_frame
	var audio:=root.get_node_or_null("GameAudio")
	if audio!=null:audio.stop_menu()
	await create_timer(0.1).timeout
	print("ROOM_START_OK guest-only readiness, automatic host squad, double-click guard, BP on/off, cancel/restart, no-frame stable toggle, compact layout; ",endpoint)
	quit(0)
