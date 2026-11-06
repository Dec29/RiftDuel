extends Node

signal changed

const DEVELOPMENT_VERSION := 156
const REPOSITORY_URL := "https://github.com/Dec29/RiftDuel/releases"
var current_version := DEVELOPMENT_VERSION
var latest_version := 0
var phase := "idle"
var message := "启动时会自动检查，也可手动检查更新。"
var notes := ""
var downloaded := 0
var total := 0
var _install_dir := ""
var _job := ""
var _status_file := ""
var _helper_pid := -1
var _poll_elapsed := 0.0
var _last_status := ""
var _restarting := false
var _startup_checked := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("editor"):
		message = "开发环境不安装更新，请使用发布客户端。"
		return
	_install_dir = OS.get_executable_path().get_base_dir()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_install_dir.path_join("client_version.json")))
	current_version = int(data.get("version", 0)) if data is Dictionary else 0
	var pointer := _update_directory().path_join("last_job.txt")
	if FileAccess.file_exists(pointer):
		var candidate := FileAccess.get_file_as_string(pointer).strip_edges()
		if candidate.get_base_dir() == _update_directory() and candidate.get_file().begins_with("job-"):
			_job = candidate
			_status_file = _job.path_join("status.json")
			_read_status()
			if phase not in ["ready", "installed", "error"] and not (phase == "installing" and "--riftduel-update-health" in OS.get_cmdline_user_args()):
				phase = "idle"
				message = "上次更新未完成，可以重新检查。"

func startup() -> void:
	if _startup_checked: return
	_startup_checked = true
	if "--riftduel-update-health" in OS.get_cmdline_user_args():
		var health := _install_dir.path_join(".riftduel-update/health.json")
		if DirAccess.dir_exists_absolute(health.get_base_dir()):
			var file := FileAccess.open(health, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify({"version": current_version}))
		return
	if not _install_dir.is_empty() and phase != "ready": check_updates()

func _update_directory() -> String:
	return ProjectSettings.globalize_path("user://updates/" + _install_dir.sha256_text().substr(0, 16))

func busy() -> bool:
	return phase in ["checking", "downloading", "verifying", "installing"] or _restarting

func check_updates() -> void:
	if busy() or phase == "ready": return
	if _install_dir.is_empty():
		message = "开发环境不安装更新，请使用发布客户端。"
		changed.emit()
		return
	_job = _update_directory().path_join("job-%d-%d" % [Time.get_unix_time_from_system(), OS.get_process_id()])
	var error := DirAccess.make_dir_recursive_absolute(_job)
	if error != OK:
		_fail("无法创建更新目录：%d" % error)
		return
	_status_file = _job.path_join("status.json")
	var pointer := FileAccess.open(_update_directory().path_join("last_job.txt"), FileAccess.WRITE)
	if pointer == null:
		_fail("无法保存更新进度位置。")
		return
	pointer.store_string(_job)
	pointer.close()
	latest_version = 0
	notes = ""
	total = 0
	downloaded = 0
	_begin("check", "checking", "正在检查新版本…")

func download_update() -> void:
	if phase != "available": return
	_begin("stage", "downloading", "正在准备下载…")

func _begin(command: String, next_phase: String, text: String) -> void:
	var helper := _install_dir.path_join("RiftDuelUpdater.exe")
	if not FileAccess.file_exists(helper):
		_fail("缺少更新程序，请重新解压完整客户端。")
		return
	if FileAccess.file_exists(_status_file): DirAccess.remove_absolute(_status_file)
	_last_status = ""
	phase = next_phase
	message = text
	_helper_pid = OS.create_process(helper, PackedStringArray([command, "--install-dir", _install_dir, "--job", _job, "--status", _status_file]))
	if _helper_pid < 0: _fail("无法启动更新程序。")
	changed.emit()

func restart_and_install() -> void:
	if phase != "ready" or _install_dir.is_empty(): return
	var source := _install_dir.path_join("RiftDuelUpdater.exe")
	var copy := _job.path_join("apply-helper.exe")
	var error := DirAccess.copy_absolute(source, copy)
	if error != OK:
		_fail("无法准备安装程序：%d" % error)
		return
	var pid := OS.create_process(copy, PackedStringArray(["apply", "--install-dir", _install_dir, "--job", _job, "--status", _status_file, "--parent", str(OS.get_process_id())]))
	if pid < 0:
		_fail("无法启动安装程序，当前版本未改变。")
		return
	_restarting = true
	get_tree().quit()

func _process(delta: float) -> void:
	if _helper_pid < 0 and phase != "installing": return
	_poll_elapsed += delta
	if _poll_elapsed < 0.2: return
	_poll_elapsed = 0.0
	_read_status()
	if _helper_pid < 0: return
	if not OS.is_process_running(_helper_pid):
		_helper_pid = -1
		_read_status()
		if busy(): _fail("更新程序未完成操作，请重试。")

func _read_status() -> void:
	if _status_file.is_empty() or not FileAccess.file_exists(_status_file): return
	var text := FileAccess.get_file_as_string(_status_file)
	if text == _last_status or text.length() > 65536: return
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or not data.get("phase") is String: return
	if data.phase not in ["checking", "available", "current", "downloading", "verifying", "ready", "installing", "installed", "error"]: return
	_last_status = text
	phase = data.phase
	message = str(data.get("message", "")).left(500)
	notes = str(data.get("notes", "")).left(10000)
	latest_version = int(data.get("latest", 0))
	downloaded = maxi(0, int(data.get("downloaded", 0)))
	total = maxi(0, int(data.get("total", 0)))
	changed.emit()

func _fail(text: String) -> void:
	phase = "error"
	message = text
	changed.emit()

func _exit_tree() -> void:
	if not _restarting and _helper_pid > 0 and OS.is_process_running(_helper_pid): OS.kill(_helper_pid)
