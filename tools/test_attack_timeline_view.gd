extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;push_error(label)
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	var out:="res://.ai/attack-timing-20261023/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var events: Array[Dictionary]=[]
	for id in ["surtr","exusiai","skadi","jessica"]:
		var data: Dictionary={id:load("res://resources/operators/"+id+".tres"),"bagpipe":load("res://resources/operators/bagpipe.tres").duplicate(true)}
		data.bagpipe.max_health=100000
		var index: int={"surtr":2,"exusiai":1,"skadi":0,"jessica":1}[id]
		var ids:=PackedStringArray([id]);var skills:=PackedInt32Array([index])
		var state:=MatchState.new(72,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
		state.ball.cell=Vector2i(10,10)
		state.units=[UnitState.new(0,0,id,Vector2i(11,5) if data[id].terrain_requirement=="ground" else Vector2i(12,2),data[id].max_health,data[id].skills[index].sp_required,0,2,index),UnitState.new(1,1,"bagpipe",(Vector2i(9,5) if id=="surtr" else Vector2i(10,5)) if data[id].terrain_requirement=="ground" else Vector2i(9,2),100000,0,99999,0)]
		state.next_unit_id=2
		var view:=MatchView.new();view.bind(state,LocalInput.new(0),data);root.add_child(view);view.set_process(false)
		for frame in 75:
			var before_hp: int=state.units[1].hp
			var commands: Array[InputCommand]=[]
			if frame==0:commands.append(InputCommand.new(0,1,"",0,Vector2i.ZERO,index))
			state.step(commands,[])
			view._bone_tick=float(state.tick);view.queue_redraw()
			var before:=state.state_hash()
			await process_frame;await process_frame;RenderingServer.force_draw()
			check(before==state.state_hash(),"Animation/projectile draw is read-only")
			var unit:=state.units[0];var model: OperatorSpineVisual=view._bagpipe_models[0]
			if unit.attack_started_tick>=0 and state.tick-1==unit.attack_started_tick:
				check(model.clip==("Skill_3_Loop" if id=="surtr" else "Attack") and model.pose_seconds<.04,"Actual source action begins at simulation start")
				root.get_texture().get_image().save_png(out+id+"-windup.png")
			if unit.last_attack_tick==state.tick-1:
				check(model.pose_seconds>=float(AttackActionData.profile(unit,SkillRules.active_ticks(unit)!=0).release_frame)/30.0-.04,"Source swing/fire pose reached when attack releases")
				root.get_texture().get_image().save_png(out+id+"-fire.png")
			if unit.attack_intent!=null:
				view._bone_tick=float(state.tick)+.75;view.queue_redraw()
				await process_frame;RenderingServer.force_draw()
				check(model.pose_seconds<unit.attack_intent.release_frame/30.0,"Late interpolation cannot show contact before actual release")
				check(before==state.state_hash(),"Late-frame interpolation remains read-only")
			if state.units[1].hp!=before_hp:
				events.append({"id":id,"tick":state.tick-1,"clip":model.clip,"source_seconds":model.pose_seconds,"damage":before_hp-state.units[1].hp,"started":unit.attack_started_tick,"released":unit.last_attack_tick})
				if id in ["exusiai","jessica"]:check(state.tick-1>unit.last_attack_tick,"Bullet impact occurs after the actual fire pose")
			if frame==35:
				view.simulation_waiting=true;var frozen:=model.pose_seconds;var frozen_clock:=view.attack_visual_tick()
				view._bone_tick=float(state.tick)
				for repeat in 3:view.queue_redraw();await process_frame;RenderingServer.force_draw()
				check(model.pose_seconds==frozen and view.attack_visual_tick()==frozen_clock,"Waiting removes interpolation without rewinding attack or projectile clock")
				view.simulation_waiting=false
		if id in ["surtr","skadi"]:
			var distance:=DisplacementRules.apply_unit(state,state.units[1],state.units[0],Vector2i.RIGHT,4)
			check(distance>0,"Actual ground displacement accepted for "+id)
			var before:=state.state_hash();view.queue_redraw();await process_frame;RenderingServer.force_draw()
			check(view._bagpipe_models[0].clip in ["Idle","Skill_3_Idle"] and before==state.state_hash(),"Displaced caster idles without replaying the interrupted swing")
		for facing in 4:
			state.units[0].facing=facing
			for mirror in [false,true]:
				view.mirror_board=mirror;var before:=state.state_hash();view.queue_redraw();await process_frame;RenderingServer.force_draw()
				check(before==state.state_hash(),"Four-facing mirrored animation remains read-only")
		view.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"timing-after.json",FileAccess.WRITE).store_string(JSON.stringify(events,"  "))
	print("ATTACK_TIMELINE_VIEW_OK: actual native SurtrS3/ExusiaiS2/SkadiS1/JessicaS2, begin/fire/impact, four facings and mirrors, wait/read-only; failures=",failures)
	quit(0 if failures==0 else 1)
