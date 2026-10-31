class_name DraftRoom
extends RefCounted

var owner: NetSession
var state: DraftState
var draft_id := ""
var deadline_ms := 0
var completed := false
var _catalog: Dictionary


func _init(session: NetSession, catalog: Dictionary) -> void:
	owner = session
	_catalog = catalog.duplicate()


func reset() -> void:
	state = null
	draft_id = ""
	deadline_ms = 0
	completed = false


func begin() -> void:
	state = DraftState.new(_catalog)
	state.preferences = [owner.local_squad.duplicate(),owner.remote_squad.duplicate()]
	state.preferred_skills = [owner.local_skills.duplicate(),owner.remote_skills.duplicate()]
	draft_id = (str(Time.get_ticks_usec())+owner.room_code).sha256_text().substr(0,32)
	completed = false
	owner.phase = "draft"
	owner._deadline = 0
	deadline_ms = Time.get_ticks_msec()+state.duration_ms()
	_publish()


func poll() -> void:
	if owner.side == 0 and owner.phase == "draft" and state != null and Time.get_ticks_msec() >= deadline_ms:
		state.expire()
		deadline_ms = Time.get_ticks_msec()+state.duration_ms()
		_publish()


func request(action: String, operators: Array = [], skills: Array = [], id: String = "") -> void:
	if owner.phase != "draft" or state == null: return
	var message := {"type":"draft_"+action,"draft_id":draft_id,"stage":state.stage}
	if action == "ban": message.operator_id = id
	elif action in ["update","submit"]:
		message.operators = operators
		message.skills = skills
	elif action != "cancel": return
	if owner is RelaySession:
		message.room_id = owner._room_id
		owner._send(message)
	elif owner.side == 0:
		_accept(message,0)
	else: owner._send(message)


func receive(message: Dictionary) -> bool:
	if not message.type.begins_with("draft"): return false
	if message.type == "draft":
		if owner.side != 1 or owner.phase not in ["room","draft"] or message.size()!=2: owner._fail("禁选消息阶段无效"); return true
		apply_snapshot(message.draft)
	elif message.type == "draft_rejected":
		if message.size()!=3 or message.draft_id != draft_id or not message.reason is String: owner._fail("禁选回执无效"); return true
		owner.status = message.reason
		owner.changed.emit()
	elif message.type == "draft_cancelled":
		if message.size()!=2 or message.draft_id != draft_id: owner._fail("禁选取消消息无效"); return true
		_cancel_local()
	elif owner.side == 0 and owner.phase == "draft": _accept(message,1)
	elif owner.side == 0 and message.get("draft_id") == draft_id:
		owner._send({"type":"draft_rejected","draft_id":draft_id,"reason":"本次禁选已结束"})
	else: owner._fail("当前阶段不接受禁选操作")
	return true


func _accept(message: Dictionary, side: int) -> void:
	# Resolve authority time before handling a request delivered on the deadline.
	poll()
	if owner.phase != "draft": return
	var action: String = message.type.trim_prefix("draft_")
	if action not in ["ban","update","submit","cancel"]: owner._fail("未知禁选操作"); return
	var expected := 4 if action == "ban" else (5 if action in ["update","submit"] else 3)
	if message.size()!=expected or message.get("draft_id")!=draft_id or not CommandCodec.is_integer(message.get("stage"),0,4):
		owner._fail("禁选请求字段无效")
		return
	if action == "cancel":
		owner._send({"type":"draft_cancelled","draft_id":draft_id})
		_cancel_local()
		return
	var error := "本阶段已结束，请按最新阶段操作"
	var previous := state.stage
	if int(message.stage) == state.stage:
		if action == "ban" and message.get("operator_id") is String: error = state.ban(side,message.operator_id)
		elif action in ["update","submit"]: error = state.update_selection(side,message.get("operators"),message.get("skills"),action=="submit")
	if not error.is_empty():
		if side == 0:
			owner.status = error
			owner.changed.emit()
		else: owner._send({"type":"draft_rejected","draft_id":draft_id,"reason":error})
		return
	if previous != state.stage: deadline_ms = Time.get_ticks_msec()+state.duration_ms()
	if action != "update": _publish()


func _publish() -> void:
	state.serial += 1
	var value := state.snapshot()
	value.draft_id = draft_id
	value.remaining_ms = maxi(0,deadline_ms-Time.get_ticks_msec()) if state.stage<5 else 0
	owner._send({"type":"draft","draft":value})
	owner.status = DraftState.NAMES[state.stage]
	if state.stage == 5:
		_finish()
		owner.start_match.call_deferred()
	owner.changed.emit()


func apply_snapshot(value: Variant) -> void:
	if owner.phase not in ["room","starting","draft"]: owner._fail("当前阶段不接受禁选结果"); return
	if state == null:
		state = DraftState.new(_catalog)
		if not value is Dictionary or value.get("stage")!=0: owner._fail("禁选必须从首轮禁用开始"); return
	elif not value is Dictionary or value.get("draft_id") != draft_id:
		owner._fail("禁选标识不一致"); return
	var error := state.read_snapshot(value)
	if not error.is_empty(): owner._fail(error); return
	draft_id = value.draft_id
	deadline_ms = Time.get_ticks_msec()+int(value.remaining_ms)
	owner.phase = "draft"
	owner.status = DraftState.NAMES[state.stage]
	owner._deadline = deadline_ms+owner.CONNECT_TIMEOUT_MS
	if state.stage == 5: _finish()
	owner.changed.emit()


func _finish() -> void:
	completed = true
	owner.local_squad = state.picks[owner.side].duplicate()
	owner.remote_squad = state.picks[1-owner.side].duplicate()
	owner.local_skills = state.skills[owner.side].duplicate()
	owner.remote_skills = state.skills[1-owner.side].duplicate()
	owner.phase = "room"
	owner._deadline = Time.get_ticks_msec()+owner.CONNECT_TIMEOUT_MS


func _cancel_local() -> void:
	reset()
	owner.phase = "room"
	owner.local_ready = false
	owner.remote_ready = false
	owner._deadline = 0
	owner.status = "禁选已取消，双方请重新准备"
	owner.changed.emit()
