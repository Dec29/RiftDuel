extends SceneTree

var peers: Array[NetSession]=[]
var deadline:=0
var output:="res://.ai/banpick-20261030"
var chosen:=PackedStringArray(["bagpipe","nightingale","blaze","myrtle","exusiai","saria","surtr","texas","silverash","kaltsit","ling","amiya"])

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok

func poll() -> bool:
	await create_timer(0.025).timeout
	for p in peers:
		if not check(p.phase!="failed",p.status): return false
	return check(Time.get_ticks_msec()<deadline,"draft view deadline")

func wait_stage(stage: int) -> bool:
	while peers[0].draft.state==null or peers[1].draft.state==null or peers[0].draft.state.stage!=stage or peers[1].draft.state.stage!=stage:
		if not await poll(): return false
	await process_frame
	await process_frame
	return true

func click_at(position: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.position=position; event.pressed=pressed
		root.push_input(event,true)
		await process_frame

func capture(name: String) -> bool:
	await RenderingServer.frame_post_draw
	return check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"save screenshot")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var original:=FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH) if FileAccess.file_exists(SquadConfig.FILE_PATH) else PackedByteArray()
	var existed:=FileAccess.file_exists(SquadConfig.FILE_PATH)
	deadline=Time.get_ticks_msec()+120000
	for role in 2:
		if not await exercise(role): return
	if not check(FileAccess.file_exists(SquadConfig.FILE_PATH)==existed and (not existed or FileAccess.get_file_as_bytes(SquadConfig.FILE_PATH)==original),"draft never overwrites persistent squad"): return
	var audio:=root.get_node_or_null("GameAudio")
	if audio!=null: audio.stop_menu()
	await create_timer(0.1).timeout
	print("DRAFT_VIEW_OK: both roles, default setting/guest lock, actual ban/pick/skill clicks, right-to-left two-row favorites, drag protection, private/public strips, cancel original room, unchanged saved squad; 1280x720")
	quit(0)

func exercise(role: int) -> bool:
	peers.clear()
	var db:=root.get_node("OperatorDB")
	for side in 2:
		var p:=NetSession.new(db.network_content()); root.add_child(p); peers.append(p)
	peers[0].create_room(24991+role,"231950",24994+role)
	peers[1].join_address("127.0.0.1","231950",24991+role)
	while peers[0].phase!="room" or peers[1].phase!="room":
		if not await poll(): return false
	var code:=peers[0].room_code
	var lobby=load("res://lobby.tscn").instantiate()
	lobby.session=peers[role]; root.add_child(lobby); current_scene=lobby
	await process_frame
	var setting: CheckButton=lobby.get_node("RoomView/Center/Panel/Room/Columns/Rules/Draft")
	if not check(setting.button_pressed and setting.disabled==(role==1),"default draft setting and guest lock"): return false
	if role==0:
		if not await capture("room-default"): return false
	for p in peers:
		p.local_squad=chosen.duplicate(); p.local_skills=PackedInt32Array([2,2,2,1,2,2,2,1,2,2,2,2]); p.set_ready(true)
	while not peers[0].remote_ready or not peers[1].remote_ready:
		if not await poll(): return false
	peers[0].start_match()
	if not await wait_stage(0): return false
	var view=lobby._draft_view
	if not check(view!=null and not lobby.get_node("RoomView").visible,"draft opens inside original room"): return false
	view._search.text="阿" # Exercise filtering without changing persistent roster.
	view._search.text=""
	await process_frame; await process_frame
	view._select("aak")
	await click_at(view._confirm.get_global_rect().get_center())
	while peers[1-role].draft.state.bans[role].size()!=1:
		if not await poll(): return false
	if not await capture("draft-ban-role%d"%role): return false
	for p in peers: p.draft.request("submit")
	if not await wait_stage(1): return false
	if not check(view.ordered_ids.slice(0,12)==chosen,"current squad appears first"): return false
	var first: Rect2=view._buttons[chosen[0]].get_global_rect()
	var second: Rect2=view._buttons[chosen[1]].get_global_rect()
	var third: Rect2=view._buttons[chosen[2]].get_global_rect()
	if not check(is_equal_approx(first.position.x,second.position.x) and first.position.y<second.position.y and third.position.x<first.position.x and is_equal_approx(third.position.y,first.position.y),"upper/lower then next column left"): return false
	if not check(view._scroll.get_global_rect().encloses(first) and root.get_visible_rect().encloses(view._confirm.get_global_rect()) and root.get_visible_rect().encloses(view._range.get_global_rect()),"roster, confirmation and range stay inside canvas"): return false
	# A horizontal drag must not toggle a card.
	var down:=InputEventMouseButton.new(); down.position=first.get_center(); down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
	view._input(down)
	var move:=InputEventMouseMotion.new(); move.position=down.position+Vector2(60,0); view._input(move)
	down.pressed=false; down.position=move.position; view._input(down)
	if not check(view._mine.is_empty(),"drag does not select operator"): return false
	view._scroll_to_start()
	await process_frame; await process_frame
	for index in 6:
		# Scroll just enough to expose each selected favorite.
		view._scroll.ensure_control_visible(view._buttons[chosen[index]])
		await process_frame
		await click_at(view._buttons[chosen[index]].get_global_rect().get_center())
	if not check(view._mine==chosen.slice(0,6) and not view._confirm.disabled,"six real card clicks select first half"): return false
	await click_at(view._confirm.get_global_rect().get_center())
	while not peers[1-role].draft.state.locked[role]:
		if not await poll(): return false
	if not check(peers[1-role].draft.state.picks[role].is_empty(),"opponent cannot see confirmed picks early"): return false
	if not await capture("draft-pick-role%d"%role): return false
	peers[1-role].draft.request("submit",Array(chosen.slice(0,6)))
	if not await wait_stage(2): return false
	view._select(chosen[0])
	if not check(view._confirm.disabled,"picked operator cannot be banned"): return false
	for p in peers: p.draft.request("submit")
	if not await wait_stage(3): return false
	view._select(chosen[0])
	if not check(view._mine==chosen.slice(0,6),"prior six picks cannot be removed"): return false
	for index in range(6,12): view._select(chosen[index])
	await click_at(view._confirm.get_global_rect().get_center())
	peers[1-role].draft.request("submit",Array(chosen))
	if not await wait_stage(4): return false
	view._inspect_slot(0,0)
	await click_at(view._skill_buttons[0].get_global_rect().get_center())
	if not check(view._skills[0]==0 and view._skills[1]==2,"skill click changes only selected operator"): return false
	if not await capture("draft-skills-role%d"%role): return false
	view._cancel_prompt.popup_centered()
	await process_frame
	view._cancel_prompt.confirmed.emit()
	while peers[0].phase!="room" or peers[1].phase!="room":
		if not await poll(): return false
	await process_frame
	if not check(lobby._draft_view==null and lobby.get_node("RoomView").visible and peers[role].room_code==code and not peers[role].local_ready,"cancel shows original connected room"): return false
	lobby.queue_free(); current_scene=null
	peers[1-role].close(); peers[1-role].queue_free()
	await process_frame
	return true
