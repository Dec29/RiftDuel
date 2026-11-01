extends SceneTree

class InspectView extends MatchView:
	var labels: Array[String]=[]
	func _draw() -> void:
		UnitInfo.draw(self,_selected_unit(),PALETTE.BLUE,PALETTE.RED)
		renderer.draw_m129_markers(self)
		var tray := _tray_operator_ids()
		for index in tray.size():
			var id := tray[index]
			OperatorCardVisual.draw_battle(self,_card_rect(index),_operator_data[id],_state.carried_skill_index(_local_input.side,id),_state.deploy_cost(_local_input.side,id),false,0,false,"")
	func _draw_text(position: Vector2,text: String,size: int,color: Color) -> void:
		labels.append(text);super._draw_text(position,text,size,color)

var failures := 0
func check(ok: bool,label: String)->void:
	if not ok:failures+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var db := root.get_node("OperatorDB");var data := {}
	for id in db.all_ids():data[id]=db.get_data(id)
	for side in 2:
		for module in 3:
			var ids := PackedStringArray(["mon3tr_operator","ling","stainless","exusiai"])
			var skills := PackedInt32Array([2,module,module,2])
			var state := MatchState.new(129,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
			state.ball.cell=Vector2i(10,10)
			for id in ["mon3tr_operator","ling","stainless"]:deploy(state,side,id)
			var input := LocalInput.new(side);var view := InspectView.new();view.bind(state,input,data);root.add_child(view)
			var tokens := ["mon3tr_reconstruction",LingRules.IDS[module],StainlessRules.IDS[module]]
			for id in tokens:
				check(id in view._tray_operator_ids(),"Owned new summon card "+id)
				check(state.carried_skill_index(side,id)==0,"Summon skill stays0 with last squad skill2: "+id)
				for mirror in [false,true]:
					view.mirror_board=mirror
					var hash_before := state.state_hash();view.queue_redraw();await process_frame;await process_frame
					check(state.state_hash()==hash_before,"Cards/markers are read-only "+id)
				var cell := legal_cell(state,side,id)
				check(cell.x>=0,"Actual summon has legal placement "+id)
				if cell.x<0:continue
				var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=view._card_rect(view._tray_operator_ids().find(id)).get_center();view._unhandled_input(click)
				check(input.selected_operator_id==id,"Real card click selects "+id)
				input.clear_selection();view._deploy_phase=MatchView.DeployPhase.IDLE
				deploy(state,side,id);input.select_unit(state.units[-1].unit_id)
				var before := state.state_hash();view.queue_redraw();await process_frame;await process_frame
				check(state.state_hash()==before,"Actual summon info draws read-only "+id)
			check(not "dusk_freeling" in view._tray_operator_ids(),"Automatic Freeling never becomes a manual card")
			view.queue_free();await process_frame
	print("M129_SUMMON_CARDS_OK failures=",failures);quit(0 if failures==0 else 1)
func legal_cell(state: MatchState,side: int,id: String)->Vector2i:
	state.sides[side].cost=99
	for y in state.CONFIG.GRID_ROWS:
		for x in state.CONFIG.GRID_COLUMNS:
			if state.can_deploy(side,id,Vector2i(x,y)):return Vector2i(x,y)
	return Vector2i(-1,-1)
func deploy(state: MatchState,side: int,id: String)->void:
	var cell := legal_cell(state,side,id);check(cell.x>=0,"Legal real deployment "+id)
	if cell.x<0:return
	var commands: Array[InputCommand]=[InputCommand.new(state.tick,0,id,-1,cell,-1,2 if side==0 else 0)]
	var empty: Array[InputCommand]=[]
	state.step(commands if side==0 else empty,commands if side==1 else empty)
