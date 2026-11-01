class_name DisplaySettings
extends RefCounted

const PREFERENCES := preload("res://preferences.gd")


static func window_resolutions() -> Array[Vector2i]:
	if DisplayServer.get_name()=="headless":
		return PREFERENCES.WINDOW_RESOLUTIONS.duplicate()
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size-Vector2i(32,64)
	var choices: Array[Vector2i]=[]
	for resolution in PREFERENCES.WINDOW_RESOLUTIONS:
		if resolution.x<=usable.x and resolution.y<=usable.y:
			choices.append(resolution)
	return choices


static func fitting_resolution(preferred: Vector2i) -> Vector2i:
	var choices := window_resolutions()
	if preferred in choices:return preferred
	# The display may have changed since the preferences were saved.
	if not choices.is_empty():return choices[-1]
	return Vector2i(960,540)


static func apply(preferences: RefCounted, window: Window) -> void:
	if DisplayServer.get_name()=="headless":return
	window.mode=Window.MODE_WINDOWED
	window.borderless=false
	if preferences.window_mode=="windowed":
		window.size=fitting_resolution(preferences.window_resolution)
		var area := DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position=area.position+(area.size-window.size)/2
	else:
		window.mode=Window.MODE_FULLSCREEN if preferences.window_mode=="borderless" else Window.MODE_EXCLUSIVE_FULLSCREEN
