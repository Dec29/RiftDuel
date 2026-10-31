extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data := {}
	for profession in ["vanguard","guard","defender","sniper","caster","medic","supporter","specialist"]:
		if not check(OperatorCardVisual.profession_texture(profession).get_size()==Vector2(255,255),"Original profession texture: "+profession):return
	for id in root.get_node("OperatorDB").all_ids():
		data[id]=root.get_node("OperatorDB").get_data(id)
		for avatar in [false,true]:
			var image := OperatorCardVisual.texture(id,avatar)
			if not check(image.get_size()==Vector2(180,180 if avatar else 360),"Card image dimensions: "+id):return
	var squad := PackedStringArray(["bagpipe","exusiai","swire_alter","angelina","blaze","ceobe","eyjafjalla","horn","hoshiguma","nightingale","phantom","skadi"])
	var state := MatchState.new(117,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[squad,squad])
	state.sides[0].cost=20
	state.sides[0].tactical_items=[1,1,1]
	state.sides[0].cooldowns["exusiai"]=660
	var view := MatchView.new()
	view.bind(state,LocalInput.new(0),data)
	root.add_child(view)
	view.set_process(false)
	for summons in [false,true]:
		if summons:
			state.units=[UnitState.new(0,0,"nightingale",Vector2i(13,2),data.nightingale.max_health,0,10000),UnitState.new(1,0,"phantom",Vector2i(12,5),data.phantom.max_health,0,10000)]
			state.sides[0].phantom_count=1
		var before := state.state_hash()
		view.queue_redraw()
		await process_frame
		await process_frame
		if not check(state.state_hash()==before and view._tray_count()==15,"Maximum tray and summon replacements are read-only"):return
		var cards: Array[Rect2]=[]
		for index in 15:
			var rect := view._card_rect(index)
			if not check(rect.position.x>=30 and rect.end.x<=1250,"Maximum tray horizontal bounds"):return
			for prior in cards:
				if not check(not prior.intersects(rect),"Distinct card hit regions"):return
			cards.append(rect)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var args := OS.get_cmdline_user_args()
			var folder := args[0] if not args.is_empty() else "res://.godot"
			if not check(root.get_texture().get_image().save_png(folder.path_join("operator-cards-%s.png"%summons))==OK,"Graphics capture"):return
			if not summons:
				var dim_image := root.get_texture().get_image()
				state.sides[0].cost=100
				var funded_hash := state.state_hash()
				view.queue_redraw()
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var funded_image := root.get_texture().get_image()
				if not check(state.state_hash()==funded_hash,"Affordability redraw is read-only"):return
				var logical_face := Rect2(view._card_rect(7).position+Vector2(20,27),Vector2(view._card_rect(7).size.x-40,35))
				var face := Rect2i(root.get_final_transform()*logical_face)
				if not check(face_brightness(funded_image,face)>face_brightness(dim_image,face)*1.6,"Insufficient-cost portrait darkens and restores when funded"):return
				if not check(funded_image.save_png(folder.path_join("operator-cards-funded.png"))==OK,"Funded graphics capture"):return
				state.sides[0].cost=20
	view.free()
	print("OPERATOR_CARDS_OK: 56 portraits/avatars and8 profession icons, first3 and maximum12+3, actual cooldown/cost, affordability brightness recovery, summon card replacement and readonly hash")
	quit(0)

func face_brightness(image: Image, rect: Rect2i) -> float:
	var total := 0.0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var pixel := image.get_pixel(x,y)
			total+=pixel.r+pixel.g+pixel.b
	return total

func check(ok: bool,message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
