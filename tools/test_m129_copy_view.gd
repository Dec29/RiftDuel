extends SceneTree

class InspectView extends MatchView:
	var labels: Array[String] = []
	func _draw() -> void:
		UnitInfo.draw(self,_selected_unit(),PALETTE.BLUE,PALETTE.RED)
	func _draw_text(position: Vector2,text: String,font_size: int,color: Color) -> void:
		labels.append(text)
		super._draw_text(position,text,font_size,color)

var failures := 0
var empty: Array[InputCommand] = []
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var data := {}
	for id in ["muelsyse","jessica_alter","silverash","exusiai"]:data[id]=load("res://resources/operators/%s.tres"%id)
	for side in 2:
		var ids := PackedStringArray(["muelsyse","jessica_alter","silverash","exusiai"])
		var state := MatchState.new(129,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[PackedInt32Array([0,2,0,0]),PackedInt32Array([0,2,0,0])])
		state.sides[side].cost=99;state.ball.cell=Vector2i(10,10)
		var commands: Array[InputCommand]=[InputCommand.new(state.tick,0,"muelsyse",-1,Vector2i(13,2) if side==0 else Vector2i(7,2),-1,2 if side==0 else 0)]
		state.step(commands if side==0 else empty,commands if side==1 else empty)
		var input := LocalInput.new(side);var view := InspectView.new();view.bind(state,input,data);root.add_child(view)
		check("flowing_shape" in view._tray_operator_ids() and view._operator_available(MatchState.FLOW_DATA),"Owned original flow card available")
		commands=[InputCommand.new(state.tick,0,"flowing_shape",-1,Vector2i(13,3) if side==0 else Vector2i(7,3),-1,2 if side==0 else 0)]
		state.step(commands if side==0 else empty,commands if side==1 else empty)
		var flow := state.units[-1];input.select_unit(flow.unit_id)
		check("flowing_shape" not in view._tray_operator_ids(),"Original present removes duplicate card")
		for mirrored in [false,true]:
			view.mirror_board=mirrored;flow.sp=100;view._activate_selected_skill();commands=input.take_commands()
			check(commands.size()==1 and commands[0].kind==InputCommand.Kind.SKILL,"Flow button queues actual opening skill")
			state.step(commands if side==0 else empty,commands if side==1 else empty)
			view.labels.clear();var before := state.state_hash();view.queue_redraw();await process_frame;await process_frame
			check(before==state.state_hash() and view.labels.any(func(label:String)->bool:return "复制窗口" in label) and view.labels.any(func(label:String)->bool:return "点击本方未在场卡片复制" in label),"Copy hint draws read-only")
			state.sides[side].cooldowns["exusiai"]=500
			var tray := view._tray_operator_ids();var card := view._card_rect(tray.find("exusiai"))
			var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=card.get_center();view._unhandled_input(click)
			commands=input.take_commands()
			check(commands.size()==1 and commands[0].kind==InputCommand.Kind.COPY and commands[0].operator_id=="exusiai" and commands[0].unit_id==flow.unit_id and commands[0].facing==flow.facing,"User clicked cooling own card produces exact COPY preserving facing")
			check(view._deploy_phase==MatchView.DeployPhase.IDLE and flow.flow_copy_id!="exusiai" if not mirrored else view._deploy_phase==MatchView.DeployPhase.IDLE,"COPY queue does not enter deployment")
			state.step(commands if side==0 else empty,commands if side==1 else empty);check(flow.flow_copy_id=="exusiai" and flow.skill_ticks_left==0,"Queued actual COPY accepted by simulation")
		flow.flow_is_split=true;input.select_unit(flow.unit_id);view.labels.clear();view.queue_redraw();await process_frame;await process_frame
		check(not view.labels.any(func(label:String)->bool:return "开启复制窗口" in label),"Split has no copy action")
		view._activate_selected_skill();check(input.take_commands().is_empty(),"Split cannot queue opening skill")
		flow.flow_is_split=false;TacticianRules.point(state,flow);view._activate_selected_skill();check(input.take_commands().is_empty(),"Point cannot queue opening skill")
		state.sides[side].cost=99
		commands=[InputCommand.new(state.tick,0,"jessica_alter",-1,Vector2i(12,5) if side==0 else Vector2i(8,5),-1,0)]
		state.step(commands if side==0 else empty,commands if side==1 else empty)
		check("jessica_shield" in view._tray_operator_ids() and view._operator_available(MatchState.JESSICA_SHIELD_DATA),"Owned Jessica shield card and legal tile query")
		commands=[InputCommand.new(state.tick,0,"jessica_shield",-1,Vector2i(12,4) if side==0 else Vector2i(8,4),-1,0)]
		state.step(commands if side==0 else empty,commands if side==1 else empty)
		var shield := state.units[-1];input.select_unit(shield.unit_id);view.labels.clear();var before := state.state_hash();view.queue_redraw();await process_frame;await process_frame
		check(before==state.state_hash() and view.labels.any(func(label:String)->bool:return "盾牌寿命" in label),"Shield lifetime draws read-only")
		view.queue_free();await process_frame
	print("M129_COPY_VIEW_OK failures=",failures);quit(0 if failures==0 else 1)
