class_name RelaySession
extends NetSession

const RELAY_DELAY := 6
const PROTOCOL_VERSION := 8
const EVENT_FIELDS := {
	"draft": ["room_id","draft"],
	"draft_rejected": ["room_id","draft_id","reason"],
	"draft_cancelled": ["room_id","draft_id"],
	"hello": [], "created": ["room_id", "code", "side", "rules", "revision"],
	"joined": ["room_id", "side", "rules", "revision"], "ready": ["room_id", "side", "ready", "revision"],
	"squad": ["room_id", "side", "operators", "skills", "revision"],
	"rules": ["room_id", "rules", "revision"],
	"load": ["room_id", "match_id", "seed", "input_delay", "rules", "revision", "round"],
	"begin": ["room_id", "match_id", "input_delay"],
	"input": ["room_id", "match_id", "side", "tick", "commands"],
	"ended": ["room_id", "match_id", "tick", "result"],
	"returned": ["room_id", "match_id", "side"],
	"room": ["room_id", "match_id"],
	"aborted": ["room_id", "reason"],
}

var _socket: WebSocketPeer
var _out_seq := 0
var _in_seq := 0
var _action := {}
var _match_id := ""
var _reported_tick := -1
var _reported_result := 0


func _init(content: Dictionary) -> void:
	super(content)
	bilateral_finish = true


func create_online(url: String) -> void:
	_connect_online(url, {"type": "create"})


func join_online(url: String, code: String) -> void:
	if not valid_code(code):
		_fail("请输入6位数字配对码")
		return
	_connect_online(url, {"type": "join", "code": code})


func _connect_online(url: String, action: Dictionary) -> void:
	close()
	var pattern := RegEx.new()
	pattern.compile("^wss://[A-Za-z0-9.-]+(:[0-9]{1,5})?/ws$")
	var local_pattern := RegEx.new()
	local_pattern.compile("^ws://127\\.0\\.0\\.1:[0-9]{1,5}/ws$")
	if pattern.search(url) == null and not ((OS.has_feature("editor") or OS.has_feature("qa")) and local_pattern.search(url) != null):
		_fail("公网连接必须使用有效证书的 wss://服务器/ws 地址")
		return
	_action = action
	_socket = WebSocketPeer.new()
	_socket.max_queued_packets = 128
	_socket.inbound_buffer_size = 131072
	_socket.outbound_buffer_size = 131072
	if _socket.connect_to_url(url) != OK:
		_fail("无法连接中继服务器")
		return
	phase = "connecting"
	status = "正在连接中继服务器"
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	changed.emit()


func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not _hello_sent:
			_hello_sent = true
			_send({"type": "hello", "build": build_id})
		while _socket != null and _socket.get_available_packet_count() > 0:
			var bytes := _socket.get_packet()
			var parser := JSON.new()
			if not _socket.was_string_packet() or bytes.size() > 32768 or parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
				_fail("中继消息格式无效")
				return
			_receive(parser.data)
	elif _socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_fail("中继连接已关闭，请检查服务器、版本和配对码，房间可能已满或不存在")
		return
	if _deadline > 0 and Time.get_ticks_msec() > _deadline:
		_fail("中继连接或对局等待超时")


func _send(message: Dictionary) -> void:
	_out_seq += 1
	message.v = PROTOCOL_VERSION
	message.seq = _out_seq
	if _socket.send_text(JSON.stringify(message)) != OK:
		call_deferred("_fail", "发送中继消息失败")


func _receive(message: Dictionary) -> void:
	if not message.get("type") is String or not EVENT_FIELDS.has(message.type) or not CommandCodec.is_integer(message.get("v"), PROTOCOL_VERSION, PROTOCOL_VERSION) or not CommandCodec.is_integer(message.get("seq"), _in_seq + 1, _in_seq + 1):
		_fail("中继协议版本、类型或序号无效")
		return
	var fields: Array = EVENT_FIELDS[message.type]
	if message.size() != fields.size() + 3:
		_fail("中继消息字段无效")
		return
	for field in fields:
		if not message.has(field) or message[field] == null:
			_fail("中继消息缺少必要字段")
			return
	_in_seq += 1
	if message.has("room_id") and (not _valid_token(message.room_id) or (not _room_id.is_empty() and message.room_id != _room_id)):
		_fail("中继房间标识无效")
		return
	if message.has("match_id") and (not _valid_token(message.match_id) or (not _match_id.is_empty() and message.match_id != _match_id)):
		_fail("中继对局标识无效")
		return
	if message.type in ["created","joined","rules","load"]:
		if not MatchRules.validate(message.rules).is_empty() or not CommandCodec.is_integer(message.revision,1,1000000000):
			_fail("中继房间规则无效")
			return
	if message.type in ["ready","squad"]:
		if not CommandCodec.is_integer(message.revision,1,rules_revision):
			_fail("中继规则版本无效")
			return
		if int(message.revision)<rules_revision:return
	if message.type == "draft" and phase in ["room","starting","draft"]:
		draft.apply_snapshot(message.draft)
		return
	elif message.type == "draft_rejected":
		if message.draft_id != draft.draft_id or not message.reason is String:
			_fail("禁选回执无效"); return
		status = message.reason
	elif message.type == "draft_cancelled" and phase=="draft" and message.draft_id==draft.draft_id:
		draft._cancel_local()
		_deadline=Time.get_ticks_msec()+600000
		return
	elif message.type == "hello" and phase == "connecting":
		phase = "requesting"
		_send(_action.duplicate())
	elif message.type == "created" and phase == "requesting" and _action.type == "create" and message.code is String and valid_code(message.code) and CommandCodec.is_integer(message.side, 0, 0):
		_room_id = message.room_id
		room_code = message.code
		side = 0
		_apply_rules(message.rules,int(message.revision))
		phase = "hosting"
		status = "分享6位数字配对码；等待好友加入后才能准备"
		_deadline = Time.get_ticks_msec() + 600000
	elif message.type == "joined" and ((phase == "hosting" and CommandCodec.is_integer(message.side, 0, 0)) or (phase == "requesting" and _action.type == "join" and CommandCodec.is_integer(message.side, 1, 1))):
		_room_id = message.room_id
		side = int(message.side)
		if side == 1:
			room_code = _action.code
		_action.clear()
		_apply_rules(message.rules,int(message.revision))
		phase = "room"
		status = "双方已加入中继房间"
		_deadline = Time.get_ticks_msec() + 600000
	elif message.type=="rules" and phase in ["hosting","room"] and round_number==0 and int(message.revision)==rules_revision+1:
		_apply_rules(message.rules,int(message.revision))
	elif message.type == "squad" and phase == "room" and not remote_ready and CommandCodec.is_integer(message.side, 1 - side, 1 - side):
		var validation := SquadConfig.validate_loadout(message.operators, message.skills)
		if not validation.is_empty():
			_fail(validation)
			return
		remote_squad = PackedStringArray(message.operators)
		remote_skills = PackedInt32Array(message.skills)
	elif message.type == "ready" and phase in ["room", "starting"] and CommandCodec.is_integer(message.side, 0, 1) and message.ready is bool and (not message.ready or (not local_squad.is_empty() if int(message.side) == side else not remote_squad.is_empty())):
		if int(message.side) == side:
			local_ready = message.ready
		else:
			remote_ready = message.ready
	elif message.type == "load" and phase in ["room", "starting"] and local_ready and remote_ready and CommandCodec.is_integer(message.seed, 1, 2147483647) and CommandCodec.is_integer(message.input_delay, RELAY_DELAY, RELAY_DELAY):
		if int(message.revision)!=rules_revision or MatchRules.from_wire(message.rules).to_wire()!=rules.to_wire() or not CommandCodec.is_integer(message.round,round_number+1,round_number+1) or round_number>=rules.rounds:
			_fail("开局规则或局数不一致")
			return
		round_number=int(message.round)
		match_rules=rules.copy()
		_match_id = message.match_id
		match_seed = int(message.seed)
		phase = "loading"
		_deadline = Time.get_ticks_msec() + 30000
		match_requested.emit()
	elif message.type == "begin" and phase == "loading" and _local_loaded and CommandCodec.is_integer(message.input_delay, RELAY_DELAY, RELAY_DELAY):
		_begin()
	elif message.type == "input" and phase == "running" and CommandCodec.is_integer(message.side, 1 - side, 1 - side) and CommandCodec.is_integer(message.tick, _received_through + 1, _received_through + 1) and int(message.tick) <= _consumed + RELAY_DELAY * 2 + 1:
		var decoded := CommandCodec.decode(message.commands, int(message.tick), _command_ids, _copy_ids)
		if decoded.has("error"):
			_fail(decoded.error)
			return
		var squad_error := validate_squad_commands(decoded.commands)
		if not squad_error.is_empty():
			_fail(squad_error)
			return
		_received_through = int(message.tick)
		_remote_frames[_received_through] = decoded.commands
	elif message.type == "ended" and phase == "running" and _reported_tick > 0 and CommandCodec.is_integer(message.tick, _reported_tick, _reported_tick) and CommandCodec.is_integer(message.result, _reported_result, _reported_result):
		finish_tick = int(message.tick)
		announced_result = int(message.result)
		_deadline = 0
	elif message.type == "returned" and phase in ["running", "returning"] and finish_tick > 0 and CommandCodec.is_integer(message.side, 0, 1):
		if int(message.side) == side:
			if not local_returned:
				_fail("未请求返回房间却收到本方返回回执")
				return
		else:
			if remote_returned:
				_fail("重复的对方返回房间消息")
				return
			remote_returned = true
	elif message.type == "room" and phase == "returning" and local_returned and remote_returned and finish_tick > 0:
		_reset_match()
		_match_id = ""
		_reported_tick = -1
		_reported_result = 0
		_deadline = Time.get_ticks_msec() + 600000
	elif message.type == "aborted" and phase in ["hosting", "room", "draft", "loading", "running", "returning"] and message.reason == "peer_left":
		_fail("对方离开或中继终止了本次房间")
		return
	else:
		_fail("当前阶段不接受此中继消息：%s / %s" % [phase, message.type])
		return
	changed.emit()


func set_rules(value: Dictionary) -> void:
	assert(can_edit_rules())
	var error := MatchRules.validate(value)
	if not error.is_empty():
		_fail(error)
		return
	rules_pending=true
	local_ready=false
	remote_ready=false
	_send({"type":"rules","room_id":_room_id,"rules":value,"revision":rules_revision+1})
	changed.emit()


func set_ready(ready: bool) -> void:
	assert(phase == "room" and round_number==0 and not rules_pending)
	if ready:
		if local_squad.is_empty():
			local_squad = PackedStringArray(preload("res://data/config.gd").DEFAULT_SQUAD_IDS)
			local_skills.resize(local_squad.size())
		var validation := SquadConfig.validate_loadout(local_squad, local_skills)
		if not validation.is_empty():
			_fail(validation)
			return
		_send({"type": "squad", "room_id": _room_id, "operators": Array(local_squad), "skills": Array(local_skills),"revision":rules_revision})
	local_ready = ready
	_send({"type": "ready", "room_id": _room_id, "ready": ready,"revision":rules_revision})
	changed.emit()


func start_match() -> void:
	assert(side == 0 and phase == "room" and local_ready and remote_ready and not rules_pending and not remote_squad.is_empty())
	_send({"type": "start", "room_id": _room_id,"revision":rules_revision})
	phase = "starting"
	status = "等待中继确认开局"
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	changed.emit()


func mark_loaded() -> void:
	assert(phase == "loading")
	_local_loaded = true
	_send({"type": "loaded", "room_id": _room_id, "match_id": _match_id})


func _begin() -> void:
	for tick in RELAY_DELAY:
		var local: Array[InputCommand] = []
		var remote: Array[InputCommand] = []
		_local_frames[tick] = local
		_remote_frames[tick] = remote
	_sealed_through = RELAY_DELAY - 1
	_received_through = RELAY_DELAY - 1
	phase = "running"
	status = "中继对局进行中"
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS


func seal_frame(tick: int, input: LocalInput) -> void:
	var target := tick + RELAY_DELAY
	if _sealed_through >= target:
		return
	assert(phase == "running" and target == _sealed_through + 1)
	var commands := input.take_commands()
	for command in commands:
		command.tick = target
	_local_frames[target] = commands
	_sealed_through = target
	_send({"type": "input", "room_id": _room_id, "match_id": _match_id, "tick": target, "commands": CommandCodec.encode(commands)})


func announce_finish(tick: int, result: int) -> void:
	assert(_reported_tick == -1)
	_reported_tick = tick
	_reported_result = result
	_send({"type": "finish", "room_id": _room_id, "match_id": _match_id, "tick": tick, "result": result})
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS


func return_to_room() -> void:
	assert(phase == "running" and finish_tick > 0 and not local_returned)
	local_returned = true
	phase = "returning"
	status = "已返回原房间，等待对方结束结算"
	_send({"type": "return_room", "room_id": _room_id, "match_id": _match_id})
	_deadline = Time.get_ticks_msec() + 600000
	changed.emit()


func leave() -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and not _room_id.is_empty():
		_send({"type": "leave", "room_id": _room_id})
		_socket.poll()
	close()


func close() -> void:
	if _socket != null:
		_socket.close(-1)
	_socket = null
	super.close()
	_room_id = ""
	_match_id = ""
	_action.clear()
	_out_seq = 0
	_in_seq = 0
	_reported_tick = -1
	_reported_result = 0


static func _valid_token(value: Variant) -> bool:
	return value is String and value.length() == 32 and value == value.to_lower() and value.is_valid_hex_number(false)
