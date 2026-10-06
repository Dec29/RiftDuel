extends RefCounted

const DEFAULT_ENDPOINT := "wss://134.175.45.75/ws"
const FILE_PATH := "user://preferences.cfg"

var use_custom_server := false
var custom_endpoint := ""
var goal_position := "left"


func read(path: String = FILE_PATH) -> String:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return ""
	if error != OK:
		return "无法读取设置：" + error_string(error)
	var custom = config.get_value("connection", "use_custom_server", false)
	var endpoint = config.get_value("connection", "custom_endpoint", "")
	var position = config.get_value("display", "goal_position", "left")
	if typeof(custom) != TYPE_BOOL or typeof(endpoint) != TYPE_STRING or typeof(position) != TYPE_STRING:
		return "设置文件中的字段类型无效"
	if position not in ["left", "right"]:
		return "设置文件中的球门位置无效"
	if custom and not valid_endpoint(endpoint):
		return "自定义服务器地址无效，请在设置中填写 wss://服务器/ws"
	use_custom_server = custom
	custom_endpoint = endpoint
	goal_position = position
	return ""


func write(path: String = FILE_PATH) -> String:
	if use_custom_server and not valid_endpoint(custom_endpoint):
		return "请输入 wss://服务器/ws 地址（可指定端口）"
	if goal_position not in ["left", "right"]:
		return "请选择左侧或右侧球门"
	var config := ConfigFile.new()
	config.set_value("connection", "use_custom_server", use_custom_server)
	config.set_value("connection", "custom_endpoint", custom_endpoint)
	config.set_value("display", "goal_position", goal_position)
	var error := config.save(path)
	return "" if error == OK else "无法保存设置：" + error_string(error)


func endpoint() -> String:
	return custom_endpoint if use_custom_server else DEFAULT_ENDPOINT


static func valid_endpoint(url: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^wss://[A-Za-z0-9.-]+(:[0-9]{1,5})?/ws$")
	var loopback := RegEx.new()
	loopback.compile("^ws://127\\.0\\.0\\.1:[0-9]{1,5}/ws$")
	var valid := pattern.search(url) != null or ((OS.has_feature("editor") or OS.has_feature("qa")) and loopback.search(url) != null)
	if not valid:
		return false
	var authority := url.split("://")[1].trim_suffix("/ws")
	var parts := authority.split(":")
	return parts.size() == 1 or (int(parts[1]) >= 1 and int(parts[1]) <= 65535)
