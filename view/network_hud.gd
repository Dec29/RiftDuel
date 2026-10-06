extends Control

signal leave_requested

const PALETTE := preload("res://view/palette.gd")

var _waiting_since := 0


func _ready() -> void:
	$Failure.color = Color(PALETTE.BACKGROUND, 0.92)
	$Leave.pressed.connect(func() -> void: leave_requested.emit())
	$Failure/Panel/Return.pressed.connect(func() -> void: leave_requested.emit())
	$Status.add_theme_color_override("font_color", PALETTE.MUTED_TEXT)
	$Failure/Panel/Message.add_theme_color_override("font_color", PALETTE.TEXT)


func set_waiting(waiting: bool, side: int) -> void:
	if not waiting:
		_waiting_since = 0
	elif _waiting_since == 0:
		_waiting_since = Time.get_ticks_msec()
	$Status.text = "等待对方输入…" if waiting and Time.get_ticks_msec() - _waiting_since > 400 else ("蓝方 · 己方" if side == 0 else "红方 · 己方")


func show_failure(message: String) -> void:
	$Failure.show()
	$Failure/Panel/Message.text = message
