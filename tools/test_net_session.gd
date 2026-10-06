extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var commands: Array[InputCommand] = [InputCommand.new(12, 0, "bagpipe", -1, Vector2i(11, 5), -1, 3), InputCommand.new(12, 1, "", 7, Vector2i.ZERO, 0), InputCommand.new(12, 2, "", 9)]
	var decoded := CommandCodec.decode(JSON.parse_string(JSON.stringify(CommandCodec.encode(commands))), 12)
	if not _check(decoded.has("commands") and decoded.commands.size() == 3 and decoded.commands[0].facing == 3 and decoded.commands[2].unit_id == 9, "Command roundtrip lost fields"):
		return
	var phantom: Array[InputCommand] = [InputCommand.new(12, InputCommand.Kind.DEPLOY, "nightingale_phantom", -1, Vector2i(11, 5), -1, 2)]
	decoded = CommandCodec.decode(JSON.parse_string(JSON.stringify(CommandCodec.encode(phantom))), 12)
	if not _check(decoded.has("commands") and decoded.commands[0].operator_id == "nightingale_phantom", "Phantom deployment must use the existing command schema"):
		return
	for invalid: Variant in [null, [[12, 0]], [[12.5, 0, "bagpipe", -1, 11, 5, -1, 2]], [[12, 0, "unknown", -1, 11, 5, -1, 2]], [[12, 1, "", 0, 0, 0, 4, -1]]]:
		if not _check(CommandCodec.decode(invalid, 12).has("error"), "Invalid packet accepted: " + str(invalid)):
			return
	var host := NetSession.new()
	var client := NetSession.new()
	root.add_child(host)
	root.add_child(client)
	var paths := PackedStringArray()
	host._collect_paths("res://resources", paths)
	if not _check(paths.size() >= 10 and host.build_id == client.build_id, "Build fingerprint must include runtime resources"):
		return
	host.create_room(24779, "123456")
	client.join_code("123456")
	var deadline := Time.get_ticks_msec() + 4000
	while client.phase in ["searching", "connecting"] and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(host.phase == "room" and client.phase == "room" and host.side == 0 and client.side == 1, "Local ENet handshake failed: %s / %s" % [host.status, client.status]):
		return
	var visitor := NetSession.new()
	root.add_child(visitor)
	visitor.join_code("123456")
	deadline = Time.get_ticks_msec() + 3000
	while visitor.phase == "searching" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(visitor.phase == "failed" and visitor.status.contains("已满"), "Full room must reject discovery join: " + visitor.status):
		return
	visitor.join_code("bad")
	if not _check(visitor.phase == "failed", "Invalid code must fail before discovery"):
		return
	visitor.join_code("000000")
	deadline = Time.get_ticks_msec() + 3000
	while visitor.phase == "searching" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(visitor.phase == "failed" and visitor.status.contains("未找到"), "Unknown code must give a discoverable error: " + visitor.status):
		return
	visitor.queue_free()
	host.set_ready(true)
	client.set_ready(true)
	deadline = Time.get_ticks_msec() + 2000
	while (not host.remote_ready or not client.remote_ready) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(host.remote_ready and client.remote_ready, "Ready state did not reach both players"):
		return
	host.start_match()
	deadline = Time.get_ticks_msec() + 2000
	while client.phase != "loading" and Time.get_ticks_msec() < deadline:
		await process_frame
	host.mark_loaded()
	if not _check(host.phase == "loading", "One loaded player must not start simulation"):
		return
	client.mark_loaded()
	while client.phase != "running" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(host.phase == "running" and client.phase == "running" and host.match_seed == client.match_seed, "Loaded barrier failed"):
		return
	var input := LocalInput.new(0)
	host.seal_frame(0, input)
	input.select_operator("bagpipe")
	input.queue_deploy(0, Vector2i(11, 5), 3)
	host.seal_frame(0, input)
	if not _check(host._local_frames[4].is_empty() and input._pending_commands.size() == 1, "Waiting must not reseal or drain later input"):
		return
	host.seal_frame(1, input)
	if not _check(host._local_frames[5].size() == 1 and host._local_frames[5][0].tick == 5, "Buffered input must enter next unsealed frame"):
		return
	client.close()
	deadline = Time.get_ticks_msec() + 4000
	while host.phase == "running" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(host.phase == "failed", "Host did not detect disconnection"):
		return
	host.create_room(24779, "123456")
	client.join_address("127.0.0.1", "999999", 24779)
	deadline = Time.get_ticks_msec() + 4000
	while client.phase == "connecting" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "failed" and client.status.contains("配对码"), "Wrong room code must fail handshake: " + client.status):
		return
	host.close()
	host.create_room(24779, "123456")
	client.build_id = "wrong-build"
	client.join_address("127.0.0.1", "123456", 24779)
	deadline = Time.get_ticks_msec() + 4000
	while client.phase == "connecting" and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(client.phase == "failed" and client.status.contains("不一致"), "Mismatched build was not rejected: " + client.status):
		return
	host.close()
	client.phase = "running"
	client._receive({"type": "frame", "tick": 5, "commands": []})
	if not _check(client.phase == "failed", "Out-of-order frame must fail at input boundary"):
		return
	host.queue_free()
	client.queue_free()
	print("Network OK: codec, malformed frames, discovery/full/unknown codes, handshake, loaded barrier, sealed input, disconnect, build mismatch")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
