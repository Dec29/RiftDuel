extends SceneTree

class ProbeRenderer extends BattleRenderer:
	var hide_ball := false
	func draw_football(view: MatchView, center: Vector2, roll: float) -> void:
		if not hide_ball: super.draw_football(view,center,roll)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	# Pixel probes below use logical 1280x720 coordinates.
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	var data := {}
	for id in root.get_node("OperatorDB").all_ids(): data[id]=root.get_node("OperatorDB").get_data(id)
	for side in 2:
		for mirrored in [false,true]:
			var state := MatchState.new(64,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["bagpipe","suzuran"],["bagpipe","suzuran"]],[[0,1],[0,1]])
			var own := UnitState.new(0,side,"bagpipe",Vector2i(12,6),data.bagpipe.max_health/2,35,10000,0)
			var enemy := UnitState.new(1,1-side,"bagpipe",Vector2i(8,6),data.bagpipe.max_health/2,35,10000,0)
			state.units=[own,enemy]
			state.next_unit_id=2
			var view := MatchView.new()
			var probe := ProbeRenderer.new()
			view.renderer = probe
			view.bind(state,LocalInput.new(side),data)
			view.mirror_board=mirrored
			root.add_child(view)
			view.set_process(false)
			view.simulation_waiting=true
			var before := state.state_hash()
			await redraw(view)
			if not check(state.state_hash()==before,"Status overlays never write simulation state"):return
			for unit in [own,enemy]:
				var foot := view.renderer.unit_screen_center(view, unit)
				var hp := view.renderer.unit_health_rect(view, unit)
				if not check(hp.position.y>foot.y and hp.position.y-foot.y<7 and hp.size.x>35 and hp.size.x<50,"Health bar sits closely below the feet, with row-scaled width"):return
				var marker := view.renderer.skill_ready_rect(view, unit)
				var row_width := (view.projection.board_point(Vector2(unit.cell)+Vector2(1.5,0.5))-view.projection.board_point(Vector2(unit.cell)+Vector2(0.5,0.5))).length()
				var head_y := foot.y-row_width*1.2
				if not check(absf(marker.get_center().x-foot.x)<1 and head_y-marker.end.y>3 and head_y-marker.end.y<7,"Ready marker is directly above the body, not above the old elevated health bar"):return
				if DisplayServer.get_name()!="headless":
					var frame := root.get_texture().get_image()
					if not check(color_matches(frame,Vector2i(hp.position+Vector2(4,2)),ViewPalette.BLUE if unit.side==side else ViewPalette.RED),"Health color is relative to the local player"):return
					if not check(color_matches(frame,Vector2i(hp.position+Vector2(4,6)),ViewPalette.SP_GREEN),"Both sides charge with green SP touching health"):return
			if not await capture("bars-%d-%s"%[side,mirrored]):return
			own.skill_ticks_left=300
			enemy.skill_ticks_left=300
			before=state.state_hash()
			await redraw(view)
			if not check(state.state_hash()==before,"Active bars stay read-only"):return
			if DisplayServer.get_name()!="headless":
				for unit in [own,enemy]:
					if not check(color_matches(root.get_texture().get_image(),Vector2i(view.renderer.unit_health_rect(view, unit).position+Vector2(4,6)),ViewPalette.ARROW),"Both sides use yellow progress while releasing a skill"):return
			if not await capture("active-%d-%s"%[side,mirrored]):return
			own.operator_id="suzuran"
			own.skill_index=1
			own.skill_ticks_left=-2
			before=state.state_hash()
			await redraw(view)
			if not check(state.state_hash()==before,"Infinite active bars stay read-only"):return
			if DisplayServer.get_name()!="headless" and not check(color_matches(root.get_texture().get_image(),Vector2i(view.renderer.unit_health_rect(view, own).position+Vector2(4,6)),ViewPalette.ARROW),"Infinite active skill also has yellow progress"):return
			own.operator_id="bagpipe"
			own.skill_index=0
			own.sp=0
			own.skill_ticks_left=0
			state.units=[own]
			state.ball.cell=Vector2i(12,5)
			for moving in [false,true]:
				# During a push the logical endpoint is behind the ball, but the
				# visible feet start in front. Depth must follow the visible feet.
				own.cell=Vector2i(12,4) if moving else Vector2i(12,6)
				own.displacement_origin=Vector2i(12,6)
				own.displacement_duration_ticks=12 if moving else 0
				own.displacement_ticks_left=12 if moving else 0
				probe.hide_ball=true
				state.units.clear()
				await redraw(view)
				var background: Image
				if DisplayServer.get_name()!="headless":background=root.get_texture().get_image()
				state.units=[own]
				await redraw(view)
				var actor: Image
				if DisplayServer.get_name()!="headless":actor=root.get_texture().get_image()
				probe.hide_ball=false
				before=state.state_hash()
				await redraw(view)
				if not check(state.state_hash()==before,"Stationary and sliding depth sorting stays read-only"):return
				if DisplayServer.get_name()!="headless":
					var frame := root.get_texture().get_image()
					var ball := view.projection.cell_rect(state.ball.cell,false).get_center()
					var overlap := 0
					var preserved := 0
					for y in range(int(ball.y)-15,int(ball.y)+15):
						for x in range(int(ball.x)-15,int(ball.x)+15):
							var baseline := background.get_pixel(x,y)
							var body := actor.get_pixel(x,y)
							if color_distance(body,baseline)>0.35:
								overlap+=1
								if color_distance(frame.get_pixel(x,y),body)<0.025:preserved+=1
					if overlap<=70 or preserved<=overlap*0.85:
						background.save_png("res://.godot/depth-background.png")
						actor.save_png("res://.godot/depth-actor.png")
						frame.save_png("res://.godot/depth-failed.png")
					if not check(overlap>70 and preserved>overlap*0.85,"Foreground head pixels stay visible over the rear football, including a sliding unit: %d/%d side%d mirror%s moving%s"%[preserved,overlap,side,mirrored,moving]):return
				if not await capture("depth-%d-%s-%s"%[side,mirrored,moving]):return
			view.queue_free()
			await process_frame
	print("BATTLE_DEPTH_OK: foreground head/football occlusion, sliding feet depth, local-relative health, green charge/yellow active/infinite, touching foot bars/head cue; read-only")
	quit(0)


func redraw(view: MatchView) -> void:
	view.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless": RenderingServer.force_draw()


func color_distance(a: Color,b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))


func color_matches(frame: Image,point: Vector2i,expected: Color) -> bool:
	return color_distance(frame.get_pixelv(point),expected)<0.03


func capture(label: String) -> bool:
	if DisplayServer.get_name()=="headless":return true
	# Frozen views may leave no pending frame; force completion before reading pixels.
	RenderingServer.force_draw()
	return check(root.get_texture().get_image().save_png("res://.godot/battle-depth-%s.png"%label)==OK,"Save actual graphics evidence")


func check(ok: bool,message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
