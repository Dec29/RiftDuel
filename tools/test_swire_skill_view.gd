extends SceneTree

var evidence_dir := "res://.godot"

class InspectView extends MatchView:
	var drawn_text: Array[String] = []
	func _draw() -> void:
		drawn_text.clear()
		super._draw()
	func _draw_text(position: Vector2, text: String, size: int, color: Color) -> void:
		drawn_text.append(text)
		super._draw_text(position,text,size,color)

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():evidence_dir=arguments[0]
	if DirAccess.make_dir_recursive_absolute(evidence_dir)!=OK:
		push_error("Cannot create graphics evidence directory: "+evidence_dir)
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var data := {"swire_alter":load("res://resources/operators/swire_alter.tres")}
	if not await check_bar_phases(data):return
	for side in 2:
		for mirrored in [false,true]:
			var state := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["swire_alter"],["swire_alter"]],[[1],[2]])
			state.sides[0].cost=99
			state.sides[1].cost=99
			state.ball.cell=Vector2i(10,10)
			state.step([InputCommand.new(0,0,"swire_alter",-1,Vector2i(12,5),-1,2)],[InputCommand.new(0,0,"swire_alter",-1,Vector2i(8,5),-1,0)])
			for i in 160: state.step([],[])
			if not check(state.units.size()==2 and not state.champagne_bombs.is_empty() and state.units[1].skill_ticks_left==-2,"Actual equipped deployments and autonomous effects"):return
			var input := LocalInput.new(side)
			var view := MatchView.new()
			view.bind(state,input,data)
			view.mirror_board=mirrored
			root.add_child(view)
			input.select_unit(side)
			view._info_tab=view.InfoTab.COMMAND
			view._details_open=true
			var before := state.state_hash()
			await process_frame
			await process_frame
			if not check(state.state_hash()==before,"Projected traps and coins are read-only"):return
			if DisplayServer.get_name()!="headless":
				if not check(root.get_texture().get_image().save_png(evidence_dir.path_join("swire-skills-%d-%s.png"%[side,mirrored]))==OK,"Screenshot"):return
			if side==1: state.units[1].coins=3
			view._activate_selected_skill()
			var commands := input.take_commands()
			if not check(commands.size()==(1 if side==1 else 0),"Passive trap has no button; active auto S3 can close"):return
			if side==1:
				state.step([],commands)
				if not check(state.units[1].skill_ticks_left==0 and state.units[1].coin_firing,"Actual button starts coin firing"):return
			view.queue_free()
			await process_frame
	print("Swire view: sides2/mirrors2, actual deployed traps/coin action and readonly projection OK")
	quit(0)

func check_bar_phases(data: Dictionary) -> bool:
	for index in 3:
		var state := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["swire_alter"],[]],[[index],[]])
		state.sides[0].cost=99
		state.ball.cell=Vector2i(10,10)
		state.step([InputCommand.new(0,0,"swire_alter",-1,Vector2i(12,5),-1,0)],[])
		for tick in 60:state.step([],[])
		var unit := state.units[0]
		unit.coins=2
		var input := LocalInput.new(0)
		var view := InspectView.new()
		view.bind(state,input,data)
		root.add_child(view)
		view.set_process(false)
		view.simulation_waiting=true
		input.select_unit(0)
		view._details_open=true
		var limit := int(data.swire_alter.skills[index].effect_params["coin_limit"])
		if not await check_bar_frame(view,state,"s%d-%s"%[index+1,"charging" if index==2 else "coins"],"技力  2 / 5" if index==2 else "金币  2 / %d"%limit,0.4 if index==2 else 2.0/limit,ViewPalette.SP_GREEN if index==2 else ViewPalette.ARROW):return false
		if index==2:
			for tick in 100:state.step([],[])
			if not check(unit.skill_ticks_left==-2,"S3 automatically switches from SP to coin capacity"):return false
			unit.coins=3
			if not await check_bar_frame(view,state,"s3-active","金币  3 / 10",0.3,ViewPalette.ARROW):return false
			view._activate_selected_skill()
			state.step(input.take_commands(),[])
			if not check(unit.coin_firing and unit.coins==2,"Manual close begins spending coins"):return false
			if not await check_bar_frame(view,state,"s3-firing","金币  2 / 10",0.2,ViewPalette.ARROW):return false
			StatusRules.apply_silence(state,unit,30)
			if not await check_bar_frame(view,state,"s3-silenced","金币  2 / 10",0.2,ViewPalette.SP_GREEN):return false
			for tick in 36:state.step([],[])
			if not check(not unit.coin_firing and unit.skill_ticks_left==0 and unit.sp==0,"Coin exhaustion returns to SP recovery"):return false
			if not await check_bar_frame(view,state,"s3-recharging","技力  0 / 5",0.0,ViewPalette.SP_GREEN):return false
		view.free()
	return true

func check_bar_frame(view: InspectView,state: MatchState,label: String,status: String,ratio: float,color: Color) -> bool:
	var before := state.state_hash()
	view.queue_redraw()
	await process_frame
	await process_frame
	if not check(state.state_hash()==before and view.drawn_text.has(status),"Read-only HUD phase: "+label):return false
	if DisplayServer.get_name()=="headless":return true
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var unit := state.units[0]
	var hp := view.renderer.unit_health_rect(view,unit)
	var sp := Rect2(hp.position+Vector2(0,4),hp.size)
	for bar in [sp,Rect2(view._hud_origin()+Vector2(20,136),Vector2(ViewPalette.HUD_WIDTH-40,4))]:
		if ratio>0 and not check(color_matches(frame,bar.position+Vector2(bar.size.x*ratio*0.5,2),color),"Actual active/charging bar color: "+label):return false
		if not check(color_matches(frame,bar.position+Vector2(bar.size.x*(ratio+(1-ratio)*0.5),2),ViewPalette.GROUND if bar==sp else ViewPalette.HUD_RULE),"Actual coin/SP capacity: "+label):return false
	var limit := int(view._operator_data.swire_alter.skills[unit.skill_index].effect_params["coin_limit"])
	for slot in limit:
		var former_coin := sp.position+Vector2((slot+0.5)*sp.size.x/limit,view.renderer.unit_row_width(view,unit)*0.20)
		if not check(not color_matches(frame,former_coin,ViewPalette.ARROW) and not color_matches(frame,former_coin,ViewPalette.DISABLED),"No duplicate coin row: "+label):return false
	return check(frame.save_png(evidence_dir.path_join("swire-bar-%s.png"%label))==OK,"Save bar graphics evidence")

func color_matches(frame: Image,position: Vector2,expected: Color) -> bool:
	var actual := frame.get_pixelv(Vector2i(position))
	return maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))<0.03

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
