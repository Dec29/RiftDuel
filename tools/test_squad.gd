extends SceneTree


class CaptureLan extends NetSession:
	var messages: Array[Dictionary] = []

	func _send(message: Dictionary) -> void:
		messages.append(message)

class CaptureRelay extends RelaySession:
	var messages: Array[Dictionary] = []

	func _send(message: Dictionary) -> void:
		messages.append(message)

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var db := root.get_node("OperatorDB")
	var config := SquadConfig.new()
	var test_path := "user://squad-validation-test.cfg"
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)
	if not _check(config.read(test_path).is_empty() and config.operator_ids == PackedStringArray(preload("res://data/config.gd").DEFAULT_SQUAD_IDS), "Missing squad must use the approved default squad without growing beyond its limit"):
		return
	config.operator_ids = PackedStringArray(["nightingale", "bagpipe"])
	config.skill_indices = PackedInt32Array()
	config.skill_indices.resize(config.operator_ids.size())
	if not _check(config.write(test_path).is_empty(), "Cannot persist selected squad"):
		return
	var restored := SquadConfig.new()
	if not _check(restored.read(test_path).is_empty() and restored.operator_ids == config.operator_ids, "Saved squad and slot order must survive reload"):
		return
	for invalid in [[], ["bagpipe", "bagpipe"], ["missing"], [0], null, "bagpipe"]:
		if not _check(not SquadConfig.validate_ids(invalid).is_empty(), "Invalid squad accepted: %s" % str(invalid)):
			return
	config.operator_ids.clear()
	config.skill_indices.clear()
	if not _check(config.write(test_path, true).is_empty() and restored.read(test_path, true).is_empty() and restored.operator_ids.is_empty() and not restored.read(test_path).is_empty(), "Empty edit storage must survive reload without relaxing battle validation"):
		return
	var malformed := ConfigFile.new()
	malformed.set_value("squad", "operators", ["missing"])
	malformed.save(test_path)
	if not _check(not restored.read(test_path).is_empty(), "Malformed saved squad must fail without a silent default"):
		return
	DirAccess.remove_absolute(test_path)
	var definitions := {}
	for id in db.all_ids():
		definitions[id] = db.get_data(id)
	var squads: Array = [PackedStringArray(["swire_alter"]), PackedStringArray(["bagpipe"])]
	var state := MatchState.new(123, definitions, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, squads)
	state.sides[0].cost = 99
	var forbidden: Array[InputCommand] = [InputCommand.new(0, InputCommand.Kind.DEPLOY, "bagpipe", -1, Vector2i(11, 5))]
	state.step(forbidden, [])
	if not _check(state.units.is_empty() and state.sides[0].cost == 99, "Simulation must not deploy an operator outside that side's squad"):
		return
	var boundary := NetSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	boundary.phase = "room"
	boundary._receive({"type": "ready", "ready": true})
	if not _check(boundary.phase == "failed", "Readiness without squad configuration must fail"):
		return
	boundary.remote_squad = PackedStringArray(["swire_alter"])
	if not _check(not boundary.validate_squad_commands(forbidden).is_empty(), "Remote deployment must be checked against the sender squad"):
		return
	boundary.free()
	var extra_ids := PackedStringArray()
	for index in maxi(1, 12 - db.all_ids().size()):
		var operator := (definitions["bagpipe"] as OperatorData).duplicate(true) as OperatorData
		operator.operator_id = "squad_test_%d" % index
		operator.display_name = "测试干员%d" % index
		operator.talent_2.effect_type = "none"
		operator.talent_2.effect_params = {}
		definitions[operator.operator_id] = operator
		db._operators[operator.operator_id] = operator
		extra_ids.append(operator.operator_id)
	var lan := CaptureLan.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	var relay := CaptureRelay.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	relay._room_id = "a".repeat(32)
	for session in [lan, relay]:
		session.phase = "room"
		session.set_ready(true)
		if not _check(db.all_ids().size() > 12 and session.local_ready and session.local_squad == PackedStringArray(preload("res://data/config.gd").DEFAULT_SQUAD_IDS) and session.messages.size() == 2 and session.messages[0].type == "squad" and session.messages[0].operators == Array(session.local_squad), "Empty network squad must remain valid and transmit the default eight with more than twelve registered operators"):
			return
		session.set_ready(false)
		session.messages.clear()
		session.local_squad = PackedStringArray(["suzuran", "bagpipe"])
		session.local_skills = PackedInt32Array()
		session.local_skills.resize(session.local_squad.size())
		session.set_ready(true)
		if not _check(session.local_squad == PackedStringArray(["suzuran", "bagpipe"]) and session.messages[0].operators == ["suzuran", "bagpipe"], "Explicit network squad and slot order must remain unchanged"):
			return
		session.set_ready(false)
		session.messages.clear()
		session.local_squad = PackedStringArray(["missing"])
		session.local_skills = PackedInt32Array()
		session.local_skills.resize(session.local_squad.size())
		session.set_ready(true)
		if not _check(session.phase == "failed" and session.messages.is_empty(), "Invalid explicit squad must fail rather than silently use the default"):
			return
		session.free()
	var twelve: PackedStringArray = db.all_ids().slice(0, 12)
	if not _check(twelve.size() == 12 and SquadConfig.validate_ids(twelve).is_empty(), "Twelve distinct known operators must be permitted"):
		return
	var thirteen := twelve.duplicate()
	thirteen.append("bagpipe")
	if not _check(not SquadConfig.validate_ids(thirteen).is_empty(), "Thirteenth slot must be rejected"):
		return
	state = MatchState.new(123, definitions, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [twelve, twelve])
	var input := LocalInput.new(0)
	var view := MatchView.new()
	view.bind(state, input, definitions)
	root.add_child(view)
	for index in 12:
		var rect := view._card_rect(index)
		if not _check(Rect2(Vector2.ZERO, Vector2(ViewPalette.SCREEN_SIZE)).encloses(rect) and rect.position.y == ViewPalette.CARD_ORIGIN.y and rect.size.y == ViewPalette.CARD_SIZE.y and rect.position.y > ViewPalette.BOARD_ORIGIN.y + ViewPalette.BOARD_SIZE.y and not rect.intersects(view._cost_rect()), "Twelve-card tray must remain one horizontal row without overlapping board/cost: %s" % rect):
			return
		for other in index:
			if not _check(not rect.intersects(view._card_rect(other)), "Tray cards must not overlap"):
				return
	var before := state.state_hash()
	await process_frame
	await process_frame
	if not _check(state.state_hash() == before, "Twelve-card rendering must preserve simulation state"):
		return
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(args[0]) == OK, "Cannot capture twelve-card tray"):
			return
	var isolated := MatchState.new(123, definitions, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [PackedStringArray([extra_ids[0]]), PackedStringArray(["bagpipe"])])
	isolated.sides[0].cost = 99
	var deploy: Array[InputCommand] = [InputCommand.new(0, InputCommand.Kind.DEPLOY, extra_ids[0], -1, Vector2i(11, 5))]
	isolated.step(deploy, [])
	if not _check(isolated.units.size() == 1 and isolated.units[0].sp == definitions[extra_ids[0]].skills[0].initial_sp, "Opposing/unselected Bagpipe must not grant the squad initial-SP talent"):
		return
	for id in extra_ids:
		db._operators.erase(id)
	print("Squad OK: persistence/order, invalid input, side membership, readiness barrier, 12-slot read-only tray and initial-SP isolation")
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
