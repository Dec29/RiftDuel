class_name OperatorCardVisual
extends RefCounted

const PALETTE := preload("res://view/palette.gd")

static var _portraits: Dictionary = {}
static var _avatars: Dictionary = {}
static var _profession_icons: Dictionary = {}


static func profession_texture(profession_id: String) -> Texture2D:
	if not _profession_icons.has(profession_id):
		var path := "res://assets/icons/professions/%s.png" % profession_id
		var image := load(path) as Texture2D
		if image == null:
			push_error(path + ": expected profession icon Texture2D")
			Engine.get_main_loop().quit(1)
			return null
		_profession_icons[profession_id] = image
	return _profession_icons[profession_id]


static func texture(operator_id: String, avatar: bool) -> Texture2D:
	var cache := _avatars if avatar else _portraits
	if not cache.has(operator_id):
		var path := "res://assets/cards/%s/%s.png" % [operator_id,"avatar" if avatar else "portrait"]
		var image := load(path) as Texture2D
		if image == null:
			push_error(path + ": expected operator card Texture2D")
			Engine.get_main_loop().quit(1)
			return null
		cache[operator_id] = image
	return cache[operator_id]


static func draw_squad(canvas: CanvasItem, rect: Rect2, operator: OperatorData, skill_index: int, number: String = "", assigned: bool = false) -> void:
	_draw_card(canvas,rect,operator,skill_index,DeployRules.base_cost(operator),false,assigned,false)
	if not number.is_empty():
		var order := Rect2(rect.position+Vector2(6,rect.size.y-67),Vector2(36,23))
		canvas.draw_rect(order,PALETTE.BLUE)
		_text(canvas,order,"序%02d"%int(number),12,PALETTE.TEXT)


static func draw_battle(canvas: CanvasItem, rect: Rect2, operator: OperatorData, skill_index: int, cost: int, selected: bool, cooldown_seconds: int, missing_cost: bool, stock_text: String) -> void:
	_draw_card(canvas,rect,operator,skill_index,cost,true,selected,missing_cost,not stock_text.is_empty())
	if cooldown_seconds>0:
		var timer := Rect2(rect.position+Vector2(13,49),Vector2(rect.size.x-26,25))
		canvas.draw_rect(timer,Color(PALETTE.HUD_SURFACE,0.9))
		_text(canvas,timer,"%ds"%cooldown_seconds,20,PALETTE.ARROW)
	if not stock_text.is_empty():
		_text(canvas,Rect2(rect.position+Vector2(4,rect.size.y-14),Vector2(rect.size.x-8,12)),stock_text,9,PALETTE.MUTED_TEXT)


static func _draw_card(canvas: CanvasItem, rect: Rect2, operator: OperatorData, skill_index: int, cost: int, battle: bool, selected: bool, missing_cost: bool, has_stock: bool = false) -> void:
	canvas.draw_rect(rect,PALETTE.HUD_INSET)
	var picture := texture(operator.operator_id,battle)
	var source := Rect2(0,0,180,180) if battle else Rect2(0,12,180,336)
	var size := Vector2(rect.size.x,rect.size.x*source.size.y/source.size.x)
	canvas.draw_texture_rect_region(picture,Rect2(rect.position+Vector2(0,3),size),source,PALETTE.CARD_UNAFFORDABLE_TINT if missing_cost else Color.WHITE)
	var band_height := (43 if has_stock else 32) if battle else 52
	var band := PackedVector2Array([rect.position+Vector2(0,rect.size.y-band_height-(10 if battle else 30)),rect.position+Vector2(rect.size.x,rect.size.y-band_height),rect.end,rect.position+Vector2(0,rect.size.y)])
	canvas.draw_colored_polygon(band,PALETTE.HUD_SURFACE)
	canvas.draw_line(band[0],band[1],Color(PALETTE.ARROW,0.7),1.5,true)
	canvas.draw_rect(rect,PALETTE.BLUE if selected else PALETTE.HUD_RULE,false,2 if selected else 1)
	var profession := Rect2(rect.position+Vector2(3,3),Vector2(22,22))
	canvas.draw_rect(profession,Color(PALETTE.BACKGROUND,0.8))
	if operator.profession_id=="summon":
		_text(canvas,profession,"召",13,PALETTE.TEXT)
	else:
		canvas.draw_texture_rect(profession_texture(operator.profession_id),profession.grow(-1),false,PALETTE.MUTED_TEXT if missing_cost else Color.WHITE)
	var price := Rect2(rect.position+Vector2(rect.size.x-33,3),Vector2(30,22))
	canvas.draw_rect(price,Color(PALETTE.BACKGROUND,0.65))
	_text(canvas,price,str(cost),18,PALETTE.TEXT)
	var tag := Rect2(rect.position+Vector2(rect.size.x-(21 if battle else 31),rect.size.y-(50 if battle else 76)),Vector2.ONE*(18 if battle else 26))
	canvas.draw_rect(tag,PALETTE.HUD_SURFACE)
	canvas.draw_rect(tag,PALETTE.BLUE,false,1)
	var icon := SkillIconVisual.texture(operator.operator_id,skill_index)
	if icon != null:
		canvas.draw_texture_rect(icon,tag.grow(-1),false)

	else:
		_text(canvas,tag,"召" if operator.skills[skill_index].effect_type=="no_skill" else "S%d"%(skill_index+1),10 if battle else 13,PALETTE.TEXT)
	var name := Rect2(rect.position+Vector2(4,rect.size.y-((43 if has_stock else 31) if battle else 36)),Vector2(rect.size.x-8,24 if has_stock else 30))
	_text(canvas,name,operator.display_name,13 if battle else 16,PALETTE.TEXT)


static func _text(canvas: CanvasItem, rect: Rect2, text: String, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var actual_size := mini(size,maxi(8,floori(size*rect.size.x/maxf(1,width))))
	var actual_width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,actual_size).x
	canvas.draw_string(font,rect.position+Vector2((rect.size.x-actual_width)*0.5,(rect.size.y+font.get_ascent(actual_size)-font.get_descent(actual_size))*0.5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,actual_size,color)
