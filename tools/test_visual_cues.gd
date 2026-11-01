extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var data := {}
	for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
	for side in 2:
		for mirrored in [false,true]:
			var state := MatchState.new(64,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["bagpipe","silverash"],["bagpipe","silverash"]],[[0,2],[0,2]])
			var own := UnitState.new(0,side,"bagpipe",Vector2i(14 if side==0 else 6,5),data.bagpipe.max_health,35,10000,0)
			var enemy := UnitState.new(1,1-side,"silverash",Vector2i(6 if side==0 else 14,5),data.silverash.max_health,90,10000,2,2)
			own.displacement_origin=own.cell
			own.displacement_duration_ticks=4
			state.units=[own,enemy]
			state.next_unit_id=2
			var view := MatchView.new()
			view.bind(state,LocalInput.new(side),data)
			view.mirror_board=mirrored
			root.add_child(view)
			view.set_process(false)
			var before := state.state_hash()
			if not await redraw(view):return
			if not check(state.state_hash()==before,"Drawing readiness and football stays read-only"):return
			if DisplayServer.get_name()!="headless":
				if not check(ready_pixels(view,own)>25 and ready_pixels(view,enemy)>25,"Both sides show equipped manual-ready marker"):return
				if not await capture("ready-%d-%s"%[side,str(mirrored)]):return
			for field in ["sp","skill_ticks_left","silence_ticks_left","stun_ticks_left","displacement_ticks_left"]:
				own.sp=34 if field=="sp" else 35
				own.set(field,34 if field=="sp" else 1)
				before=state.state_hash()
				if not await redraw(view):return
				if not check(state.state_hash()==before,"Invalid readiness drawing remains read-only"):return
				if DisplayServer.get_name()!="headless" and not check(ready_pixels(view,own)==0,"Unavailable manual skill has no ready marker: "+field):return
				own.set(field,35 if field=="sp" else 0)
			own.operator_id="exusiai"
			own.skill_index=2
			own.sp=30
			if not await redraw(view):return
			if DisplayServer.get_name()!="headless" and not check(ready_pixels(view,own)==0,"Automatic skill never gets manual-ready marker"):return
			own.operator_id="phantom"
			own.skill_index=0
			own.sp=0
			if not await redraw(view):return
			if DisplayServer.get_name()!="headless" and not check(ready_pixels(view,own)==0,"Passive skill never gets manual-ready marker"):return
			own.operator_id="bagpipe"
			own.sp=35
			own.cell.y=0
			if not await redraw(view):return
			if DisplayServer.get_name()!="headless" and not check(ready_pixels(view,own)>25,"Top-edge marker stays visible below the title"):return
			if not await capture("top-%d-%s"%[side,str(mirrored)]):return
			state.result=MatchState.RESULT_DRAW
			if not await redraw(view):return
			# The result overlay has yellow text over the enemy's central marker area.
			if DisplayServer.get_name()!="headless" and not check(ready_pixels(view,own)==0,"Finished battle clears the unobscured top-edge marker"):return
			state.result=MatchState.RESULT_RUNNING
			state.units.clear()
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				state.ball.move_direction=direction
				for remaining in [8,4,1]:
					state.ball.move_ticks_left=remaining
					before=state.state_hash()
					if not await redraw(view):return
					if not check(state.state_hash()==before,"Four-direction football drawing does not move logical ball"):return
			state.ball.move_direction=Vector2i.RIGHT
			state.ball.move_ticks_left=4
			state.platform_cells.append(Vector2i(11,5))
			before=state.state_hash()
			if not await redraw(view):return
			if not check(state.ball_move_is_blocked() and state.state_hash()==before,"Raised platform retains existing blocked-ball response"):return
			if not await capture("football-%d-%s"%[side,str(mirrored)]):return
			view.free()
	print("VISUAL_CUES_OK: manual-ready/auto/passive/active/silence/stun/displacement, both sides/mirror, four-direction football and blocked bounce; read-only hashes")
	quit(0)


func redraw(view: MatchView) -> bool:
	view.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	return true


func ready_pixels(view: MatchView,unit: UnitState) -> int:
	var rect := view.renderer.skill_ready_rect(view, unit)
	var area := Rect2i(Vector2i(rect.position),Vector2i(ceil(rect.size.x),ceil(rect.size.y)))
	var frame := root.get_texture().get_image()
	var count := 0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var color := frame.get_pixel(x,y)
			if color.r>0.7 and color.g>0.5 and color.b<0.6:count+=1
	return count


func capture(label: String) -> bool:
	if DisplayServer.get_name()=="headless":return true
	await RenderingServer.frame_post_draw
	return check(root.get_texture().get_image().save_png("res://.godot/visual-cues-%s.png"%label)==OK,"Save actual graphics evidence")


func check(ok: bool,message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
