extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for folder in ["operators", "summons"]:
		for file in DirAccess.open("res://resources/" + folder).get_files():
			if not file.ends_with(".tres"): continue
			var data := load("res://resources/%s/%s" % [folder,file]) as OperatorData
			check(data.validation_error().is_empty(), "Existing resource " + file)
	var original := load("res://resources/operators/horn.tres") as OperatorData
	var invalid := original.duplicate(true) as OperatorData
	invalid.skills[1].effect_type = "unregistered_effect"
	check(invalid.validation_error().contains("skills[1].effect_type: unknown"), "Unknown effect reports skill position")
	invalid = original.duplicate(true)
	invalid.skills[0].effect_params.erase("charge_count")
	check(invalid.validation_error().contains("skills[0].effect_params.charge_count: required"), "Missing charge count rejects before SP calculation")
	invalid = original.duplicate(true)
	invalid.skills[1].effect_params["overload_ammo"] = invalid.skills[1].effect_params["ammo_count"]
	check(invalid.validation_error().contains("effect_params.overload_ammo"), "Overload relation reports field")
	invalid = (load("res://resources/operators/silverash.tres") as OperatorData).duplicate(true)
	invalid.branch_trait.effect_params.erase("attack_percent")
	check(invalid.validation_error().contains("branch_trait.effect_params.attack_percent"), "Missing trait parameter rejects")
	var importer := GDScript.new()
	importer.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	check(importer.reload() == OK, "Importer compiles")
	var parser: RefCounted = importer.new()
	check(parser._parameters_parse_error('{"charge_count":1.5}').contains("charge_count"), "CSV integer conversion cannot truncate")
	check(parser._parse_effect_params('{"charge_count":2,"attack_mult":1.45}')["charge_count"] is int, "CSV uses resource integer declarations")
	check(original.validation_error().is_empty(), "Validation never mutates original")
	check_content_registry()
	print("Resource validation OK" if failures == 0 else "Resource validation FAILED")
	quit(0 if failures == 0 else 1)

func check_content_registry() -> void:
	var db := root.get_node("OperatorDB")
	var content: Dictionary = db.network_content()
	var ids: PackedStringArray = content["ids"]
	check(ids.size() == db.all_ids().size() + content["summon_owners"].size(), "Network catalog includes ordinary operators and owned summons")
	for id in content["summon_owners"]:
		check(id in ids and id not in db.all_ids() and content["summon_owners"][id] in db.all_ids(), "Summon registration and owner: " + id)
	var row := [12, 0, "catalog_fixture", -1, 11, 5, -1, 0, -1]
	check(CommandCodec.decode([row], 12, ids).has("error"), "Unknown deployment ID rejects")
	var extended := ids.duplicate()
	extended.append("catalog_fixture")
	check(not CommandCodec.decode([row], 12, extended).has("error"), "Codec uses the supplied registration instead of a second manual list")
	var source := FileAccess.get_file_as_string("res://server/protocol.go")
	var table := RegEx.new()
	table.compile('ids := map\\[string\\]bool\\{([^}]+)\\}')
	var found := table.search(source)
	check(found != null, "Strict relay ID table found")
	if found == null: return
	var entry := RegEx.new()
	entry.compile('"([a-z][a-z0-9_]*)": true')
	var relay_ids := PackedStringArray()
	for value in entry.search_all(found.get_string(1)):
		relay_ids.append(value.get_string(1))
	relay_ids.sort()
	check(relay_ids == ids, "Strict Go deployment whitelist matches loaded resources")
	var draft_source := FileAccess.get_file_as_string("res://server/draft.go")
	var counts := RegEx.new()
	counts.compile('"([a-z][a-z0-9_]*)":\\s+([123]),')
	var draft_counts := {}
	for value in counts.search_all(draft_source): draft_counts[value.get_string(1)] = int(value.get_string(2))
	check(draft_counts == content.skill_counts, "Go draft ordinary pool and exact skill counts match loaded resources")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		print("FAIL: ", message)
