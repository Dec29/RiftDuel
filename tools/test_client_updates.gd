extends SceneTree

func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> bool:
	if not ok:
		push_error(text)
		quit(1)
	return ok

func run() -> void:
	var service := root.get_node("ClientUpdates")
	var menu = load("res://view/settings_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var tabs: TabContainer = menu.get_node("Center/Panel/Tabs")
	var panel = tabs.get_node("Update")
	tabs.current_tab = panel.get_index()
	if not check(tabs.get_tab_title(panel.get_index()) == "更新" and not menu.get_node("Center/Panel/Actions/Save").visible and menu.get_node("Center/Panel/Actions/Cancel").text == "返回", "Update tab has coordinated immediate actions"): return
	service.current_version = 156
	service.latest_version = 157
	service.notes = "修复联机部署问题，并更新客户端。"
	service.total = 3145728
	service.message = "发现新版本 M157"
	service.phase = "available"
	service.changed.emit()
	if not check(panel._download.visible and not panel._restart.visible and not panel._check.disabled and "3.0 MiB" in panel._status.text, "Available update shows size and download action"): return
	for phase in ["checking", "downloading", "verifying"]:
		service.phase = phase
		service.downloaded = 1572864
		service.changed.emit()
		if not check(panel._check.disabled and not panel._download.visible, "In-flight update cannot duplicate requests"): return
	service.phase = "ready"
	service.message = "更新已下载，重启即可安装"
	service.changed.emit()
	if not check(panel._restart.visible and panel._check.disabled and not panel._download.visible, "Verified update offers restart"): return
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://.ai/updater-20261103"
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	await RenderingServer.frame_post_draw
	if not check(root.get_texture().get_image().save_png(output.path_join("settings-update.png")) == OK, "Update UI screenshot"): return
	service.phase = "error"
	service.message = "下载失败，当前版本未改变。"
	service.changed.emit()
	if not check(not panel._check.disabled and not panel._restart.visible and panel._status.text == service.message, "Failure offers retry without installation"): return
	service.phase = "idle"
	service._install_dir = ""
	panel._check.pressed.emit()
	if not check("开发环境" in panel._status.text and service._helper_pid < 0, "Editor cannot accidentally update itself"): return
	var status_file := output.path_join("receipt-test.json")
	var file := FileAccess.open(status_file, FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase": "installed", "message": "更新安装成功", "latest": 157}))
	file.close()
	service._status_file = ProjectSettings.globalize_path(status_file)
	service.phase = "installing"
	service._process(1.0)
	if not check(service.phase == "installed" and not panel._check.disabled, "Restarted client observes install receipt without owning helper process"): return
	DirAccess.remove_absolute(service._status_file)
	menu.queue_free()
	await process_frame
	print("CLIENT_UPDATES_UI_OK update tab, available/progress/restart/error, no duplicate actions, development guard")
	quit(0)
