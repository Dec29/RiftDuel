extends RefCounted

const HOTKEYS := preload("res://hotkeys.gd")
const DEFAULT_ENDPOINT := "wss://114.132.252.252/ws"
const FILE_PATH := "user://preferences.cfg"
const WINDOW_MODES := ["windowed", "borderless", "fullscreen"]
const DEFAULT_VOLUME := 10
const VOICE_SIDES := ["both", "local"]
const WINDOW_RESOLUTIONS: Array[Vector2i] = [Vector2i(960,540), Vector2i(1280,720), Vector2i(1366,768), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440), Vector2i(3840,2160)]

var use_custom_server := false
var custom_endpoint := ""
var goal_position := "left"
var window_mode := "windowed"
var window_resolution := Vector2i(1600,900)
var music_volume := DEFAULT_VOLUME
var sfx_volume := DEFAULT_VOLUME
var voice_volume := DEFAULT_VOLUME
var voice_sides := "both"
var hotkeys: Dictionary=HOTKEYS.DEFAULT.duplicate()


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
	var mode = config.get_value("display", "window_mode", "windowed")
	var resolution = config.get_value("display", "window_resolution", Vector2i(1600,900))
	var music = config.get_value("audio","music_volume",DEFAULT_VOLUME)
	var sfx = config.get_value("audio","sfx_volume",DEFAULT_VOLUME)
	var voice = config.get_value("audio","voice_volume",DEFAULT_VOLUME)
	var sides = config.get_value("audio","voice_sides","both")
	var bindings = config.get_value("keys","bindings",HOTKEYS.DEFAULT.duplicate())
	var keys_error := HOTKEYS.validation_error(bindings)
	if not keys_error.is_empty():return keys_error
	if typeof(custom) != TYPE_BOOL or typeof(endpoint) != TYPE_STRING or typeof(position) != TYPE_STRING:
		return "设置文件中的字段类型无效"
	if position not in ["left", "right"]:
		return "设置文件中的球门位置无效"
	if custom and not valid_endpoint(endpoint):
		return "自定义服务器地址无效，请在设置中填写 wss://服务器/ws"
	if typeof(mode)!=TYPE_STRING or mode not in WINDOW_MODES:
		return "设置文件中的显示模式无效"
	if typeof(resolution)!=TYPE_VECTOR2I or resolution not in WINDOW_RESOLUTIONS:
		return "设置文件中的窗口分辨率无效"
	for volume in [music,sfx,voice]:
		if typeof(volume)!=TYPE_INT or volume<0 or volume>100:return "设置文件中的音量无效（0至100）"
	if typeof(sides)!=TYPE_STRING or sides not in VOICE_SIDES:
		return "设置文件中的干员语音范围无效"
	use_custom_server = custom
	custom_endpoint = endpoint
	goal_position = position
	window_mode = mode
	window_resolution = resolution
	music_volume=music
	sfx_volume=sfx
	voice_volume=voice
	voice_sides=sides
	hotkeys=bindings.duplicate()
	return ""


func write(path: String = FILE_PATH) -> String:
	var keys_error := HOTKEYS.validation_error(hotkeys)
	if not keys_error.is_empty():return keys_error
	if use_custom_server and not valid_endpoint(custom_endpoint):
		return "请输入 wss://服务器/ws 地址（可指定端口）"
	if goal_position not in ["left", "right"]:
		return "请选择左侧或右侧球门"
	if window_mode not in WINDOW_MODES or window_resolution not in WINDOW_RESOLUTIONS:
		return "请选择有效的显示模式和窗口分辨率"
	for volume in [music_volume,sfx_volume,voice_volume]:
		if volume<0 or volume>100:return "音量必须为0至100"
	if voice_sides not in VOICE_SIDES:return "请选择有效的干员语音范围"
	var config := ConfigFile.new()
	config.set_value("connection", "use_custom_server", use_custom_server)
	config.set_value("connection", "custom_endpoint", custom_endpoint)
	config.set_value("display", "goal_position", goal_position)
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "window_resolution", window_resolution)
	config.set_value("audio","music_volume",music_volume)
	config.set_value("audio","sfx_volume",sfx_volume)
	config.set_value("audio","voice_volume",voice_volume)
	config.set_value("audio","voice_sides",voice_sides)
	config.set_value("keys","bindings",hotkeys)
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
