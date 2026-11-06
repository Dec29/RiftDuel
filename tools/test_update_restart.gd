extends SceneTree

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not "/.godot/" in args[0].replace("\\", "/") or not "/.godot/" in args[1].replace("\\", "/"):
		push_error("Restart test requires two explicit isolated .godot fixture paths")
		quit(1)
		return
	var service := root.get_node("ClientUpdates")
	service._install_dir = args[0]
	service._job = args[1]
	service._status_file = args[1].path_join("status.json")
	service.current_version = 155
	service.latest_version = 156
	service.phase = "ready"
	service.message = "更新已下载，重启即可安装"
	DirAccess.make_dir_recursive_absolute(service._update_directory())
	var file := FileAccess.open(service._update_directory().path_join("last_job.txt"), FileAccess.WRITE)
	file.store_string(args[1])
	file.close()
	var menu = load("res://view/settings_menu.tscn").instantiate()
	root.add_child(menu)
	var tabs: TabContainer = menu.get_node("Center/Panel/Tabs")
	var panel = tabs.get_node("Update")
	tabs.current_tab = panel.get_index()
	await process_frame
	await process_frame
	if not panel._restart.visible:
		push_error("Real restart action unavailable")
		quit(1)
		return
	print("REAL_UPDATE_RESTART_CLICK waiting for signed installation and exported-game health")
	panel._restart.pressed.emit()
