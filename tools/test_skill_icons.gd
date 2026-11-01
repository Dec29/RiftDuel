extends SceneTree
var output:="res://.ai/skill-icons-20261031"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
func capture(name: String) -> bool:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"screenshot")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():output=args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var db:=root.get_node("OperatorDB")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/icons/skills/source_manifest.json"))
	var count:=0
	for id in db.all_ids():
		var data: OperatorData=db.get_data(id)
		if not check(SkillIconVisual.ICON_IDS.has(id) and SkillIconVisual.ICON_IDS[id].size()==data.skills.size(),id+" all skill slots"):return
		for index in data.skills.size():
			var tex:=SkillIconVisual.texture(id,index)
			if not check(tex!=null and tex.get_width()==tex.get_height() and tex.get_width()>=32,id+" decoded original icon"):return
			count+=1
	for file in manifest.files:
		if not check(FileAccess.get_sha256("res://"+file.path)==file.sha256,"unmodified PNG SHA "+file.path):return
	if not check(count==279 and manifest.bindings.size()==279 and manifest.files.size()==263,"104 operators 279 slots 263 original assets"):return
	if not check(SkillIconVisual.ICON_IDS.bagpipe[0]=="skcom_quickattack[3]" and SkillIconVisual.ICON_IDS.exusiai[2]=="skchr_angel_3","generic skill and dedicated S3 anchors"):return
	var ids: PackedStringArray=db.all_ids();ids.sort()
	for page in 4:
		var canvas:=Control.new();canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(canvas)
		canvas.draw.connect(func() -> void:
			canvas.draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)),ViewPalette.BACKGROUND)
			for slot in 26:
				var index:=page*26+slot
				if index>=ids.size():break
				var data: OperatorData=db.get_data(ids[index]);var origin:=Vector2(12+(slot/13)*635,12+(slot%13)*53)
				canvas.draw_string(ThemeDB.fallback_font,origin+Vector2(0,30),data.display_name,HORIZONTAL_ALIGNMENT_LEFT,125,15,Color.WHITE)
				for skill in data.skills.size():
					canvas.draw_texture_rect(SkillIconVisual.texture(data.operator_id,skill),Rect2(origin+Vector2(130+skill*155,0),Vector2.ONE*46),false)
					canvas.draw_string(ThemeDB.fallback_font,origin+Vector2(180+skill*155,20),"S%d"%(skill+1),HORIZONTAL_ALIGNMENT_LEFT,95,12,Color.WHITE)
					canvas.draw_string(ThemeDB.fallback_font,origin+Vector2(180+skill*155,39),data.skills[skill].skill_name,HORIZONTAL_ALIGNMENT_LEFT,95,12,Color.WHITE)
		)
		if not await capture("catalog-%d"%page):return
		canvas.queue_free();await process_frame
	var menu=load("res://view/squad_menu.tscn").instantiate();menu.embedded=true;root.add_child(menu)
	menu.quick_button.pressed.emit()
	menu._preview("bagpipe")
	var buttons: HBoxContainer=menu.get_node("Margin/Layout/Body/Picker/Details/Content/Skills")
	for index in 3:
		if not check(buttons.get_child(index).icon==SkillIconVisual.texture("bagpipe",index),"squad buttons map exact selected operator"):return
	if not await capture("squad-icons"):return
	menu._preview("myrtle")
	if not check(buttons.get_child(2).disabled and buttons.get_child(2).icon==null,"two-skill operators clear stale S3 icon"):return
	menu.queue_free();await process_frame
	print("SKILL_ICONS_OK 104 operators,279 skill slots,263 decoded/hash-verified original PNGs, generic/dedicated anchors, squad preview and absent S3")
	quit(0)
