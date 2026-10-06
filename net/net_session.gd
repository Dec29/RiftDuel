class_name NetSession
extends Node

signal changed
signal failed(message: String)
signal match_requested

const PROTOCOL := 1
const PORT := 24770
const CONNECT_TIMEOUT_MS := 8000
const DISCOVERY_PORT := 24771
const INPUT_DELAY := 4

var peer: ENetMultiplayerPeer
var side := 0
var phase := "idle"
var room_code := ""
var status := ""
var remote_id := 0
var build_id := ""
var local_ready := false
var remote_ready := false
var match_seed := 0
var announced_result := 0
var finish_tick := -1
var bilateral_finish := false
var discovery: PacketPeerUDP
var _host_port := PORT
var _discovery_port := DISCOVERY_PORT
var _room_id := ""
var _search_id := ""
var _offers := {}
var _search_until := 0
var _query_at := 0
var _local_loaded := false
var _remote_loaded := false
var _local_frames := {}
var _remote_frames := {}
var _sealed_through := INPUT_DELAY - 1
var _received_through := INPUT_DELAY - 1
var _consumed := 0
var _deadline := 0
var _hello_sent := false


func _ready() -> void:
	if not OS.has_feature("editor"):
		var package_path := OS.get_executable_path().get_basename() + ".pck"
		var package := FileAccess.get_file_as_bytes(package_path)
		if package.is_empty():
			push_error("Cannot fingerprint exported package: " + package_path)
			get_tree().quit(1)
			return
		var package_hash := HashingContext.new()
		package_hash.start(HashingContext.HASH_SHA256)
		package_hash.update(package)
		build_id = package_hash.finish().hex_encode()
		return
	var paths := PackedStringArray(["res://project.godot"])
	for file in DirAccess.get_files_at("res://"):
		if file.get_extension() in ["gd", "tscn"]:
			paths.append("res://" + file)
	for directory in ["res://data", "res://sim", "res://decision", "res://net", "res://view", "res://resources"]:
		_collect_paths(directory, paths)
	paths.sort()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for path in paths:
		hash.update(path.to_utf8_buffer())
		hash.update(FileAccess.get_file_as_bytes(path))
	build_id = hash.finish().hex_encode()


func create_room(port: int = PORT, code: String = "", discovery_port: int = DISCOVERY_PORT) -> void:
	close()
	side = 0
	var random := RNG.new(Time.get_ticks_usec())
	room_code = code if not code.is_empty() else "%06d" % (random.next_u32() % 1000000)
	_room_id = "%08x" % random.next_u32()
	_host_port = port
	_discovery_port = discovery_port
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 1)
	if error != OK:
		_fail("无法创建房间：端口被占用或网络不可用")
		return
	peer.peer_connected.connect(func(id: int) -> void:
		remote_id = id
		_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	)
	peer.peer_disconnected.connect(func(_id: int) -> void:
		if phase == "hosting":
			remote_id = 0
			_deadline = 0
			status = "等待另一位玩家加入"
			changed.emit()
		else:
			call_deferred("_fail", "对方已离开房间")
	)
	phase = "hosting"
	status = "等待另一位玩家加入"
	discovery = PacketPeerUDP.new()
	if discovery.bind(discovery_port, "0.0.0.0") != OK:
		discovery.close()
		discovery = null
		status += "（房间查询端口不可用，请使用地址加入）"
	changed.emit()


func join_address(address: String, code: String, port: int = PORT) -> void:
	close()
	if not address.is_valid_ip_address() or not valid_code(code) or port < 1024 or port > 65535:
		_fail("请输入有效地址和 6 位配对码")
		return
	side = 1
	room_code = code
	remote_id = 1
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		_fail("无法发起连接")
		return
	peer.peer_disconnected.connect(func(_id: int) -> void: call_deferred("_fail", "与房主的连接已断开"))
	phase = "connecting"
	status = "正在连接房主"
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	changed.emit()


static func valid_code(code: String) -> bool:
	return code.length() == 6 and code.is_valid_int() and str(int(code)).pad_zeros(6) == code


func join_code(code: String, discovery_port: int = DISCOVERY_PORT) -> void:
	close()
	if not valid_code(code):
		_fail("配对码必须是 6 位数字")
		return
	room_code = code
	side = 1
	_discovery_port = discovery_port
	_search_id = "%08x" % RNG.new(Time.get_ticks_usec()).next_u32()
	discovery = PacketPeerUDP.new()
	if discovery.bind(0, "0.0.0.0") != OK:
		_fail("无法查询局域网房间")
		return
	discovery.set_broadcast_enabled(true)
	phase = "searching"
	status = "正在局域网查找房间"
	_search_until = Time.get_ticks_msec() + 1800
	_query_at = 0
	changed.emit()


func set_ready(ready: bool) -> void:
	assert(phase == "room")
	local_ready = ready
	_send({"type": "ready", "ready": ready})
	changed.emit()


func start_match() -> void:
	assert(side == 0 and phase == "room" and local_ready and remote_ready)
	match_seed = RNG.new(Time.get_ticks_usec()).next_u32()
	_send({"type": "start", "seed": match_seed})
	phase = "loading"
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	match_requested.emit()
	changed.emit()


func mark_loaded() -> void:
	assert(phase == "loading")
	_local_loaded = true
	if side == 1:
		_send({"type": "loaded"})
	elif _remote_loaded:
		_begin()


func seal_frame(tick: int, input: LocalInput) -> void:
	var target := tick + INPUT_DELAY
	if _sealed_through >= target:
		return
	assert(phase == "running" and target == _sealed_through + 1)
	var commands := input.take_commands()
	for command in commands:
		command.tick = target
	_local_frames[target] = commands
	_sealed_through = target
	_send({"type": "frame", "tick": target, "commands": CommandCodec.encode(commands)})


func take_frame(tick: int) -> Array:
	assert(tick == _consumed)
	if not _local_frames.has(tick) or not _remote_frames.has(tick):
		return []
	var local: Array[InputCommand] = _local_frames[tick]
	var remote: Array[InputCommand] = _remote_frames[tick]
	_local_frames.erase(tick)
	_remote_frames.erase(tick)
	_consumed += 1
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	return [local, remote] if side == 0 else [remote, local]


func announce_finish(tick: int, result: int) -> void:
	assert(side == 0)
	announced_result = result
	finish_tick = tick
	_send({"type": "finish", "tick": tick, "result": result})


func completed() -> void:
	_deadline = 0


func _process(_delta: float) -> void:
	if discovery != null:
		_poll_discovery()
	if peer == null:
		return
	peer.poll()
	if peer == null:
		return
	if phase == "connecting" and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and not _hello_sent:
		_hello_sent = true
		_send({"type": "hello", "protocol": PROTOCOL, "build": build_id, "code": room_code})
	while peer != null and peer.get_available_packet_count() > 0:
		var sender := peer.get_packet_peer()
		var bytes := peer.get_packet()
		if sender != remote_id or bytes.size() > 32768:
			_fail("收到无效网络数据")
			return
		var parser := JSON.new()
		if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
			_fail("收到无效网络消息")
			return
		_receive(parser.data)
	if _deadline > 0 and Time.get_ticks_msec() > _deadline:
		_fail("连接超时，请检查地址、房间码和防火墙")


func _receive(message: Dictionary) -> void:
	if not message.get("type") is String:
		_fail("网络消息类型无效")
		return
	if message.type == "hello" and phase == "hosting":
		if message.get("protocol") != PROTOCOL or message.get("build") != build_id or message.get("code") != room_code:
			_send({"type": "reject", "reason": "版本、数据或配对码不一致"})
			_deadline = 0
			status = "拒绝加入：版本、数据或配对码不一致"
			changed.emit()
			return
		_send({"type": "welcome", "protocol": PROTOCOL, "build": build_id})
		phase = "room"
		status = "玩家已加入"
		_deadline = 0
		changed.emit()
	elif message.type == "welcome" and phase == "connecting":
		if message.get("protocol") != PROTOCOL or message.get("build") != build_id:
			_fail("房主版本或数据不一致")
			return
		phase = "room"
		status = "已加入房间"
		_deadline = 0
		changed.emit()
	elif message.type == "reject" and message.get("reason") is String:
		_fail(message.reason)
	elif message.type == "ready" and phase == "room" and message.get("ready") is bool:
		remote_ready = message.ready
		changed.emit()
	elif message.type == "start" and phase == "room" and side == 1 and local_ready and remote_ready and CommandCodec.is_integer(message.get("seed"), 0, 4294967295):
		match_seed = int(message.seed)
		phase = "loading"
		_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
		match_requested.emit()
		changed.emit()
	elif message.type == "loaded" and phase == "loading" and side == 0:
		_remote_loaded = true
		if _local_loaded:
			_begin()
	elif message.type == "begin" and phase == "loading" and side == 1 and _local_loaded:
		_begin()
	elif message.type == "frame" and phase == "running":
		if not CommandCodec.is_integer(message.get("tick"), _received_through + 1, _received_through + 1) or int(message.tick) > _consumed + INPUT_DELAY * 2 + 1:
			_fail("输入帧重复、过期或超出缓冲")
			return
		var decoded := CommandCodec.decode(message.get("commands"), int(message.tick))
		if decoded.has("error"):
			_fail(decoded.error)
			return
		_received_through = int(message.tick)
		_remote_frames[_received_through] = decoded.commands
	elif message.type == "finish" and phase == "running" and side == 1 and CommandCodec.is_integer(message.get("tick"), 1, 1000000000) and CommandCodec.is_integer(message.get("result"), 1, 3) and finish_tick == -1:
		finish_tick = int(message.tick)
		announced_result = int(message.result)
	elif message.type == "leave":
		_fail("对方已离开对局")
	else:
		_fail("当前阶段不接受该网络消息")


func _send(message: Dictionary) -> void:
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.set_target_peer(remote_id)
	var error := peer.put_packet(JSON.stringify(message).to_utf8_buffer())
	if error != OK:
		call_deferred("_fail", "发送网络消息失败")


func close() -> void:
	if peer != null:
		peer.close()
	peer = null
	if discovery != null:
		discovery.close()
	discovery = null
	phase = "idle"
	status = ""
	room_code = ""
	match_seed = 0
	remote_id = 0
	_deadline = 0
	_hello_sent = false
	local_ready = false
	remote_ready = false
	_local_loaded = false
	_remote_loaded = false
	_local_frames.clear()
	_remote_frames.clear()
	_offers.clear()
	_sealed_through = INPUT_DELAY - 1
	_received_through = INPUT_DELAY - 1
	_consumed = 0
	announced_result = 0
	finish_tick = -1


func leave() -> void:
	if peer != null and remote_id > 0 and phase in ["room", "loading", "running"]:
		_send({"type": "leave"})
		peer.poll()
	close()


func _begin() -> void:
	if side == 0:
		_send({"type": "begin"})
	for tick in INPUT_DELAY:
		var empty_local: Array[InputCommand] = []
		var empty_remote: Array[InputCommand] = []
		_local_frames[tick] = empty_local
		_remote_frames[tick] = empty_remote
	phase = "running"
	status = "对局进行中"
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	changed.emit()


func _poll_discovery() -> void:
	var now := Time.get_ticks_msec()
	if phase == "searching" and now >= _query_at:
		for address in ["255.255.255.255", "127.0.0.1"]:
			if discovery.set_dest_address(address, _discovery_port) == OK:
				discovery.put_packet(JSON.stringify({"game": "rift_duel", "type": "query", "code": room_code, "query": _search_id}).to_utf8_buffer())
		_query_at = now + 400
	while discovery != null and discovery.get_available_packet_count() > 0:
		var bytes := discovery.get_packet()
		var address := discovery.get_packet_ip()
		var port := discovery.get_packet_port()
		if bytes.size() > 1024:
			continue
		var parser := JSON.new()
		if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
			continue
		var message: Dictionary = parser.data
		if message.get("game") != "rift_duel" or message.get("code") != room_code:
			continue
		if side == 0 and message.get("type") == "query" and message.get("query") is String and message.query.length() <= 32:
			discovery.set_dest_address(address, port)
			discovery.put_packet(JSON.stringify({"game": "rift_duel", "type": "offer", "code": room_code, "query": message.query, "room": _room_id, "port": _host_port, "available": phase == "hosting" and remote_id == 0}).to_utf8_buffer())
		elif phase == "searching" and message.get("type") == "offer" and message.get("query") == _search_id and message.get("room") is String and message.room.length() <= 32 and CommandCodec.is_integer(message.get("port"), 1024, 65535) and message.get("available") is bool:
			_offers[message.room] = {"address": address, "port": int(message.port), "available": message.available}
	if phase == "searching" and now >= _search_until:
		if _offers.size() == 0:
			_fail("未找到房间，请确认同一局域网、配对码和防火墙；也可使用地址加入")
		elif _offers.size() > 1:
			_fail("配对码对应多个房间，请让房主重新创建或使用地址加入")
		else:
			var offer: Dictionary = _offers.values()[0]
			if not offer.available:
				_fail("该房间已满或已开始对局")
			else:
				join_address(offer.address, room_code, offer.port)


func _fail(message: String) -> void:
	close()
	phase = "failed"
	status = message
	changed.emit()
	failed.emit(message)


func _exit_tree() -> void:
	close()


func _collect_paths(directory: String, paths: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(directory):
		if file.get_extension() in ["gd", "tscn", "tres"]:
			paths.append(directory.path_join(file))
	for child in DirAccess.get_directories_at(directory):
		_collect_paths(directory.path_join(child), paths)
