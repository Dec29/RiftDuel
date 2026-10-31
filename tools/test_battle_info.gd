extends SceneTree

class InfoView extends MatchView:
	var labels := PackedStringArray()
	var positions := {}
	var sizes := {}
	func _draw_text(position: Vector2,text: String,font_size: int,color: Color) -> void:
		labels.append(text)
		positions[text]=position
		sizes[text]=font_size
		super._draw_text(position,text,font_size,color)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var data := {}
	for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
	for side in 2:
		for mirrored in [false,true]:
			var state := MatchState.new(64,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["nightingale","bagpipe"],["nightingale","bagpipe"]],[[2,0],[2,0]])
			var night := UnitState.new(0,side,"nightingale",Vector2i(12,2),1705,120,10000,0,2)
			var target := UnitState.new(1,side,"bagpipe",Vector2i(13,2),2000,35,10000,0)
			state.units=[night,target]
			state.next_unit_id=2
			var commands: Array[InputCommand] = [InputCommand.new(0,1,"",0,Vector2i.ZERO,2)]
			var empty: Array[InputCommand] = []
			state.step(commands if side==0 else empty,commands if side==1 else empty)
			if not check(target.dodge_magical_bonus==25,"Actual sanctuary grants magic dodge"):return
			var input := LocalInput.new(side)
			var view := InfoView.new()
			view.bind(state,input,data)
			view.mirror_board=mirrored
			root.add_child(view)
			view.set_process(false)
			view.simulation_waiting=true
			mouse(view,view.projection.cell_rect(target.cell).get_center())
			if not check(input.selected_unit_id==1 and view._info_tab==MatchView.InfoTab.SKILL,"Unit click defaults to skill page"):return
			for tab in [MatchView.InfoTab.SKILL,MatchView.InfoTab.TRAIT,MatchView.InfoTab.TALENT]:
				mouse(view,view._tab_rect(tab).get_center())
				var before := state.state_hash()
				view.labels.clear()
				await redraw(view)
				var fields := ["攻击 %d"%SkillRules.attack_value(target,data.bagpipe),"防御 %d"%SkillRules.defense_value(target,data.bagpipe),"法抗 %d%%"%SkillRules.magic_resist_value(target,data.bagpipe),"阻挡 %d"%SkillRules.block_count_value(target,data.bagpipe)]
				if not check(view.labels.has("技力  35 / 35") and view.labels.has("法术闪避 25%") and state.state_hash()==before,"SP and sanctuary live stats remain separate in every page"):return
				for i in fields.size():
					var field: String = fields[i]
					if not check(view.labels.has(field) and view.sizes[field]==12,"Four live attributes remain visible with compact type"):return
					if not check(view.positions[field].y==view.positions[fields[0]].y and view.positions[field].y>view._hud_origin().y+140 and view.positions[field].y<view._skill_rect().position.y,"Four stats share one row between SP and skill action"):return
					var end_x: float = view.positions[field].x+ThemeDB.fallback_font.get_string_size(field,HORIZONTAL_ALIGNMENT_LEFT,-1,view.sizes[field]).x
					if not check(end_x<(view.positions[fields[i+1]].x if i<3 else view._hud_rect().end.x-20),"Attribute text fits each column without overlap"):return
				if not check(view.positions["法术闪避 25%"].y!=view.positions["技力  35 / 35"].y,"Dodge still never replaces SP"):return
				if not check(view.labels.has("技能") and view.labels.has("特性") and view.labels.has("天赋") and not view.labels.has("作战") and not view.labels.has("干员") and not view.labels.has("被动"),"Only three visible tabs"):return
				if tab==MatchView.InfoTab.TRAIT:
					if not check(view._info_layout_paragraphs.has(data.bagpipe.branch_trait.description) and not view._info_layout_paragraphs.has(data.bagpipe.talent_1.description),"Trait page contains only branch information"):return
				elif tab==MatchView.InfoTab.TALENT:
					if not check(view._info_layout_paragraphs.has(data.bagpipe.talent_1.description) and view._info_layout_paragraphs.has(data.bagpipe.talent_2.description) and not view._info_layout_paragraphs.has(data.bagpipe.branch_trait.description),"Talent page contains both talents separately from trait"):return
				if not check(not view._hud_rect().intersects(view._cost_rect()) and view._hud_rect().end.y<=ViewPalette.CARD_ORIGIN.y,"Expanded panel avoids the cost and deployment tray"):return
				mouse(view,view._skill_rect().get_center())
				commands=input.take_commands()
				if not check(commands.size()==1 and commands[0].unit_id==1 and commands[0].skill_index==0 and state.state_hash()==before,"Manual activation remains available from every page and only queues an intent"):return
				if not await capture("%d-%s-%d"%[side,mirrored,tab]):return
			input.side=1-side
			view.labels.clear()
			await redraw(view)
			mouse(view,view._skill_rect().get_center())
			mouse(view,view._cancel_rect().get_center())
			if not check(input.take_commands().is_empty() and view.labels.has("敌方干员 · 仅查看"),"Enemy common actions remain read-only"):return
			input.side=side
			state.units=[UnitState.new(2,side,"silverash",Vector2i(13,6),2560,0,10000,0,2)]
			state.next_unit_id=3
			state.units[0].skill_ticks_left=300
			input.clear_selection()
			var before := state.state_hash()
			await redraw(view)
			if not check(state.state_hash()==before,"Active actor drawing remains read-only"):return
			if DisplayServer.get_name()!="headless":
				var rect := view.projection.cell_rect(state.units[0].cell).grow(-ViewPalette.CELL_SIZE*ViewPalette.BOARD_ZOOM*ViewPalette.UNIT_INSET_RATIO).grow(1)
				var frame := root.get_texture().get_image()
				var yellow := 0
				# The legitimate yellow SP strip is below the feet; inspect only
				# the former frame's vertical edges above the foot anchor.
				for y in range(int(rect.position.y),int(view.renderer.unit_screen_center(view, state.units[0]).y)-2):
					for x in [int(rect.position.x),int(rect.end.x)-1]:
						if frame.get_pixel(x,y).is_equal_approx(ViewPalette.ARROW):yellow+=1
				if not check(yellow<3,"Active skill has no persistent yellow tile frame"):return
			if not await capture("active-frame-%d-%s"%[side,mirrored]):return
			view.free()
	print("BATTLE_INFO_OK: actual sanctuary/SP coexistence, three tabs, common live stats/actions, cost avoidance, both sides/mirror/enemy, no active yellow frame; read-only")
	quit(0)


func redraw(view: MatchView) -> void:
	view.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw


func mouse(view: MatchView,point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	view._unhandled_input(event)


func capture(label: String) -> bool:
	if DisplayServer.get_name()=="headless":return true
	await RenderingServer.frame_post_draw
	return check(root.get_texture().get_image().save_png("res://.godot/battle-info-%s.png"%label)==OK,"Save actual graphics evidence")


func check(ok: bool,message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
