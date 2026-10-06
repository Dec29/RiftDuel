extends Node

const PREFERENCES := preload("res://preferences.gd")

var session: NetSession
var _transferring := false
var preferences := PREFERENCES.new()
var _preferences_error := ""


func _ready() -> void:
	_preferences_error = preferences.read()
	session = NetSession.new()
	get_tree().root.add_child(session)
	session.changed.connect(_refresh)
	session.match_requested.connect(func() -> void: _open_match.call_deferred())
	$RoomView.mode_requested.connect(func(online: bool) -> void:
		session.close()
		session.queue_free()
		session = RelaySession.new() if online else NetSession.new()
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
	$RoomView.online_join_requested.connect(func(code: String, invite: String) -> void:
		if not _preferences_error.is_empty():
			session._fail(_preferences_error)
			return
		(session as RelaySession).join_online(preferences.endpoint(), code, invite)
	)
	$RoomView.create_requested.connect(func() -> void: session.create_room())
	$RoomView.join_requested.connect(func(code: String) -> void: session.join_code(code))
	$RoomView.address_requested.connect(func(address: String, code: String, port: int) -> void: session.join_address(address, code, port))
	$RoomView.ready_requested.connect(func() -> void: session.set_ready(not session.local_ready))
	$RoomView.start_requested.connect(func() -> void: session.start_match())
	$RoomView.reset_requested.connect(func() -> void:
		session.leave()
		_refresh()
	)
	$RoomView.back_requested.connect(func() -> void:
		session.leave()
		var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
		assert(error == OK, "Cannot open start menu")
	)
	$RoomView/Center/Panel/Room/Copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(session.room_code + ":" + (session as RelaySession).invite if session is RelaySession else session.room_code)
	)
	_refresh()


func _refresh() -> void:
	var addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.is_valid_ip_address() and "." in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	addresses.sort()
	$RoomView.update_room({"phase": session.phase, "online": session is RelaySession, "status": session.status if not session.status.is_empty() else "创建房间，或输入好友的配对码加入", "side": session.side, "code": session.room_code, "local_ready": session.local_ready, "remote_ready": session.remote_ready, "addresses": "邀请仅可使用一次，请通过可信渠道分享" if session is RelaySession else (("备用地址：" + ", ".join(addresses) + " : %d" % NetSession.PORT) if session.side == 0 else "")})


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
