extends Node

var rules := MatchRules.new("score",5,1)
var _squad_editor: Control


func _ready() -> void:
	$RoomView.rules_requested.connect(func(value: Dictionary) -> void:
		rules = MatchRules.from_wire(value)
		_refresh()
	)
	$RoomView.start_requested.connect(_start)
	$RoomView.squad_requested.connect(_edit_squad)
	$RoomView.back_requested.connect(func() -> void:
		var error := get_tree().change_scene_to_file("res://view/start_menu.tscn")
		assert(error == OK, "Cannot open start menu")
	)
	_refresh()


func _refresh() -> void:
	var squad := SquadConfig.new()
	var error := squad.read(SquadConfig.FILE_PATH, true)
	if not error.is_empty():
		push_error(error)
		get_tree().quit(1)
		return
	$RoomView.update_solo(rules, "已编入 %d / %d 名干员" % [squad.operator_ids.size(), SquadConfig.MAX_OPERATORS])
	$RoomView/Center/Panel/Room/ReadyRow/Start.disabled = squad.operator_ids.is_empty()


func _edit_squad() -> void:
	if _squad_editor != null: return
	_squad_editor = preload("res://view/squad_menu.tscn").instantiate()
	_squad_editor.embedded = true
	$RoomView.hide()
	_squad_editor.closed.connect(func() -> void:
		_squad_editor = null
		$RoomView.show()
		_refresh()
	)
	add_child(_squad_editor)


func _start() -> void:
	var battle := preload("res://main.tscn").instantiate()
	battle.solo_rules = rules.copy()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	queue_free()
