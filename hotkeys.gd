class_name Hotkeys
extends RefCounted

const DEFAULT := {"skill": KEY_SPACE, "retreat": -MOUSE_BUTTON_RIGHT, "cancel": KEY_ESCAPE}
const LABELS := {"skill": "释放所选干员技能", "retreat": "撤退／取消部署", "cancel": "取消当前选择"}
const MOUSE_BUTTONS := [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]

static func event_code(event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.keycode if event.keycode!=KEY_NONE else event.physical_keycode
		if key in [KEY_NONE,KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]:return 0
		return key | (KEY_MASK_CTRL if event.ctrl_pressed else 0) | (KEY_MASK_ALT if event.alt_pressed else 0) | (KEY_MASK_SHIFT if event.shift_pressed else 0) | (KEY_MASK_META if event.meta_pressed else 0)
	if event is InputEventMouseButton and event.pressed and event.button_index in MOUSE_BUTTONS:
		if not event.ctrl_pressed and not event.alt_pressed and not event.shift_pressed and not event.meta_pressed:return -event.button_index
	return 0

static func label(code: int) -> String:
	if code<0:return {MOUSE_BUTTON_RIGHT:"鼠标右键",MOUSE_BUTTON_MIDDLE:"鼠标中键",MOUSE_BUTTON_XBUTTON1:"鼠标侧键1",MOUSE_BUTTON_XBUTTON2:"鼠标侧键2"}.get(-code, "无效按键")
	return "空格" if code==KEY_SPACE else OS.get_keycode_string(code)

static func validation_error(bindings: Variant) -> String:
	if not bindings is Dictionary or bindings.size()!=DEFAULT.size():return "按键设置字段无效"
	var seen: Array[int]=[]
	for action in DEFAULT:
		if not bindings.has(action) or not bindings[action] is int:return "按键设置类型无效"
		var code: int=bindings[action]
		var key := code & KEY_CODE_MASK
		if code==0 or (code<0 and -code not in MOUSE_BUTTONS):return "不支持该鼠标按键"
		if code>0 and (key in [KEY_NONE,KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META] or code & ~(KEY_CODE_MASK | KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_SHIFT | KEY_MASK_META) != 0 or OS.find_keycode_from_string(OS.get_keycode_string(key))!=key):return "不支持该快捷键"
		if key==KEY_ESCAPE and action!="cancel":return "Esc保留用于取消操作"
		if code in seen:return "快捷键重复，请选择不同按键"
		seen.append(code)
	return ""

static func matches(event: InputEvent, bindings: Dictionary, action: String) -> bool:
	return event_code(event)==bindings[action]
