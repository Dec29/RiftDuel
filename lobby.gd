extends Node

const PREFERENCES := preload("res://preferences.gd")

var session: NetSession
var _transferring := false
var _starting := false
var preferences := PREFERENCES.new()
var _preferences_error := ""
var _squad_editor: Control
var _draft_view: Control


func _ready() -> void:
	_preferences_error = preferences.read()
	if session == null:
		session = RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
		get_tree().root.add_child(session)
	$RoomView/Center/Panel/Mode.select(0 if session is RelaySession else 1)
	session.changed.connect(_refresh)
	session.match_requested.connect(func() -> void: _open_match.call_deferred())
	$RoomView.mode_requested.connect(func(online: bool) -> void:
		session.close()
		session.queue_free()
		session = RelaySession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content()) if online else NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
		get_tree().root.add_child(session)
		session.changed.connect(_refresh)
		session.match_requested.connect(func() -> void: _open_match.call_deferred())
		_refresh()
	)
	$RoomView.online_create_requested.connect(func() -> void:
		if not _preferences_error.is_empty():
			session._fail(_preferences_error)
			return
		(session as RelaySession).create_online(preferences.endpoint())
	)
	$RoomView.online_join_requested.connect(func(code: String) -> void:
		if not _preferences_error.is_empty():
			session._fail(_preferences_error)
			return
		(session as RelaySession).join_online(preferences.endpoint(), code)
	)
	$RoomView.create_requested.connect(func() -> void: session.create_room())
	$RoomView.join_requested.connect(func(code: String) -> void: session.join_code(code))
	$RoomView.address_requested.connect(func(address: String, code: String, port: int) -> void: session.join_address(address, code, port))
	$RoomView.rules_requested.connect(func(value: Dictionary) -> void: session.set_rules(value))
	$RoomView.ready_requested.connect(func() -> void:
		if not session.local_ready:
			var squad := SquadConfig.new()
			var error := squad.read()
			if not error.is_empty():
				session._fail(error)
				return
			session.local_squad = squad.operator_ids
			session.local_skills = squad.skill_indices
		session.set_ready(not session.local_ready)
	)
	$RoomView.squad_requested.connect(_edit_squad)
	$RoomView.start_requested.connect(_request_start)
	$RoomView.reset_requested.connect(func() -> void:
		session.leave()
		_refresh()
	)
	$RoomView.back_requested.connect(func() -> void:
		session.leave()
		var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
		assert(error == OK, "Cannot open start menu")
	)
	$RoomView/Center/Panel/Room/Header/Copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(session.room_code)
	)
	_refresh()
	_start_room_audio.call_deferred()


func _start_room_audio() -> void:
	if AudioServer.get_driver_name()!="Dummy":GameAudio.instance(get_tree()).start_menu()


func _refresh() -> void:
	if session.phase != "room" or not session.remote_ready: _starting = false
	if _starting and session.local_ready: _try_start.call_deferred()
	if session.phase == "draft":
		if _draft_view == null:
			_draft_view = preload("res://view/draft_view.tscn").instantiate()
			_draft_view.session = session
			add_child(_draft_view)
		$RoomView.hide()
		return
	if _draft_view != null:
		_draft_view.queue_free()
		_draft_view = null
	if _squad_editor == null: $RoomView.show()
	var addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.is_valid_ip_address() and "." in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	addresses.sort()
	$RoomView.update_room({"rules":session.rules,"can_edit":session.can_edit_rules(),"round":session.round_number,"pending":session.rules_pending,"phase": session.phase, "online": session is RelaySession, "status": session.status if not session.status.is_empty() else "创建房间，或输入好友的配对码加入", "side": session.side, "code": session.room_code, "local_ready": session.local_ready, "remote_ready": session.remote_ready, "local_returned": session.local_returned, "remote_returned": session.remote_returned, "addresses": "房间仅允许两人；双方准备后由房主开始" if session is RelaySession else (("备用地址：" + ", ".join(addresses) + " : %d" % NetSession.PORT) if session.side == 0 else "")})

	if _starting: $RoomView/Center/Panel/Room/ReadyRow/Start.disabled = true


func _request_start() -> void:
	if _starting or session.side!=0 or session.phase!="room" or not session.remote_ready or session.rules_pending or _squad_editor!=null: return
	_starting = true
	if not session.local_ready:
		var squad := SquadConfig.new()
		var error := squad.read()
		if not error.is_empty():
			_starting = false
			session._fail(error)
			return
		session.local_squad = squad.operator_ids
		session.local_skills = squad.skill_indices
		session.set_ready(true)
	_try_start.call_deferred()


func _try_start() -> void:
	if not _starting or session.phase!="room" or not session.local_ready or not session.remote_ready or session.rules_pending: return
	_starting = false
	session.start_match()


func _edit_squad() -> void:
	if _squad_editor != null or session.phase not in ["hosting", "room"] or session.round_number > 0 or session.rules_pending: return
	if session.local_ready: session.set_ready(false)
	_squad_editor = preload("res://view/squad_menu.tscn").instantiate()
	_squad_editor.embedded = true
	$RoomView.hide()
	_squad_editor.closed.connect(func() -> void:
		_squad_editor = null
		$RoomView.show()
		_refresh()
	)
	add_child(_squad_editor)


func _open_match() -> void:
	var battle := preload("res://main.tscn").instantiate()
	_transferring = true
	battle.session = session
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	queue_free()


func _exit_tree() -> void:
	if not _transferring:
		session.close()
		session.queue_free()
