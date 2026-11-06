extends VBoxContainer

const PALETTE := preload("res://view/palette.gd")
var _current: Label
var _latest: Label
var _status: Label
var _notes: Label
var _progress: ProgressBar
var _check: Button
var _download: Button
var _restart: Button
var _service: Node

func _ready() -> void:
	_service = get_tree().root.get_node("ClientUpdates")
	add_theme_constant_override("separation", 12)
	_current = _label("")
	_latest = _label("")
	_status = _label("")
	_status.custom_minimum_size.y = 50
	_notes = _label("")
	_notes.custom_minimum_size.y = 60
	_notes.max_lines_visible = 3
	_notes.clip_text = true
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 22
	_progress.show_percentage = false
	add_child(_progress)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	add_child(actions)
	_check = _button(actions, "检查更新", _service.check_updates)
	_download = _button(actions, "下载更新", _service.download_update)
	_restart = _button(actions, "重启并安装", _service.restart_and_install)
	_service.changed.connect(_refresh)
	_refresh()

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", PALETTE.MENU_TEXT_SIZE)
	add_child(label)
	return label

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", PALETTE.MENU_TEXT_SIZE)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _refresh() -> void:
	_current.text = "当前版本：M%d" % _service.current_version
	_latest.text = "最新版本：M%d" % _service.latest_version if _service.latest_version > 0 else "最新版本：待检查"
	_status.text = _service.message
	_notes.text = _service.notes
	_notes.tooltip_text = _service.notes
	_notes.visible = not _service.notes.is_empty()
	_check.disabled = _service.busy() or _service.phase == "ready"
	_download.visible = _service.phase == "available"
	_restart.visible = _service.phase == "ready"
	_progress.visible = _service.phase in ["downloading", "verifying", "ready"]
	_progress.max_value = maxf(1.0, _service.total)
	_progress.value = _service.downloaded
	if _service.phase == "ready": _progress.value = _progress.max_value
	if _service.phase == "available" and _service.total > 0:
		_status.text += " · 需下载 %.1f MiB" % (_service.total / 1048576.0)
	elif _service.phase == "downloading" and _service.total > 0:
		_status.text += " · %.1f / %.1f MiB" % [_service.downloaded / 1048576.0, _service.total / 1048576.0]
