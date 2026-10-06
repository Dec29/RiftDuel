extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var driver = load("res://tools/net_peer_driver.gd").new()
	root.add_child(driver)
	driver.call_deferred("start", OS.get_cmdline_user_args())
