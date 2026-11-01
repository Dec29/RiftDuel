extends SceneTree


class WaitingSession extends NetSession:
	var sent := 0
	func _send(_message: Dictionary) -> void:
		sent += 1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	if not check(Engine.physics_ticks_per_second == Config.PHYSICS_TICK_RATE and Engine.time_scale == 1.0, "Physics scheduling configured; UI retains normal speed"):return
	var data := {}
	for id in root.get_node("OperatorDB").all_ids(): data[id] = root.get_node("OperatorDB").get_data(id)
	var battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_physics_process(false)
	battle.match_view.set_process(false)
	battle.match_state = MatchState.new(42,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[[],[]])
	battle.ai_input = AIInput.new(1,{})
	battle.match_view.bind(battle.match_state,battle.local_input,data)
	var state: MatchState = battle.match_state
	await process_frame
	for frame in 300 * Config.PHYSICS_TICK_RATE - 1: battle._physics_process(1.0/Config.PHYSICS_TICK_RATE)
	if not check(state.tick==Config.MATCH_TICKS-1 and state.result==0, "Still running before five active real minutes"):return
	battle._physics_process(1.0/Config.PHYSICS_TICK_RATE)
	if not check(state.tick==6750 and state.result==0 and state.sides[0].cost==99, "Five minutes advances 225 combat seconds and enters overtime at center"):return
	for frame in 60 * Config.PHYSICS_TICK_RATE: battle._physics_process(1.0/Config.PHYSICS_TICK_RATE)
	if not check(state.tick==8100 and state.result==MatchState.RESULT_DRAW, "Overtime ends after one additional active real minute"):return
	var frozen := state.state_hash()
	for frame in 90: battle._physics_process(1.0/90)
	if not check(state.state_hash()==frozen, "Ended match stays frozen"):return
	battle.free()
	# Missing remote input freezes state and never creates a catch-up burst.
	battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.set_physics_process(false)
	battle.match_view.set_process(false)
	var waiting := WaitingSession.new(Engine.get_main_loop().root.get_node("OperatorDB").network_content())
	waiting.phase="running"
	waiting.side=0
	var empty: Array[InputCommand] = []
	waiting._local_frames[0]=empty
	battle.session=waiting
	await process_frame
	var before_wait: int = battle.match_state.state_hash()
	for frame in 40: battle._physics_process(1.0/90)
	if not check(battle.match_state.state_hash()==before_wait and waiting.sent==1 and battle.match_view.simulation_waiting and battle.match_view._simulation_fraction()==0.0,"Waiting seals once, freezes clock and leaves state unchanged"):return
	waiting._remote_frames[0]=empty
	for frame in 4: battle._physics_process(1.0/90)
	if not check(battle.match_state.tick==1 and not battle.match_view.simulation_waiting,"Input recovery advances one paced tick without catch-up"):return
	battle.session=null
	waiting.free()
	battle.free()
	# Real engine callbacks, without accelerating Engine.time_scale.
	battle = load("res://main.tscn").instantiate()
	root.add_child(battle)
	battle.match_state = MatchState.new(42,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[[],[]])
	battle.ai_input = AIInput.new(1,{})
	battle.match_view.bind(battle.match_state,battle.local_input,data)
	await create_timer(0.5).timeout
	var started_tick: int = battle.match_state.tick
	var started := Time.get_ticks_usec()
	await create_timer(4.0).timeout
	var real_seconds := (Time.get_ticks_usec()-started)/1000000.0
	var expected := real_seconds * Config.PHYSICS_TICK_RATE / Config.PHYSICS_TICKS_PER_SIMULATION_TICK
	if not check(absf(battle.match_state.tick-started_tick-expected)<3.0, "Actual callbacks maintain 22.5 simulation ticks per real second"):return
	print("PACE_REAL_CLOCK seconds=",real_seconds," ticks=",battle.match_state.tick-started_tick)
	var paused_hash: int = battle.match_state.state_hash()
	paused=true
	await create_timer(0.25,true).timeout
	if not check(battle.match_state.state_hash()==paused_hash,"Single-player pause freezes active time"):return
	paused=false
	battle.free()
	# AI decisions remain deterministic, delayed and read-only.
	state=MatchState.new(43,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["bagpipe"],["bagpipe"]],[[0],[0]])
	state.sides[0].cost=99
	var ai := AIInput.new(0,{"bagpipe":data.bagpipe})
	for tick in Config.AI_DECISION_INTERVAL_TICKS:
		var before := state.state_hash()
		if not check(ai.commands_for_tick(state).is_empty() and state.state_hash()==before,"AI deployment observes cadence without writing state"):return
		state.step([],[])
	var commands := ai.commands_for_tick(state)
	if not check(commands.size()==1 and commands[0].kind==InputCommand.Kind.DEPLOY and state.can_deploy(0,"bagpipe",commands[0].cell),"AI chooses legal deployment from current state"):return
	state.step(commands,[])
	var unit := state.units[0]
	unit.sp=35
	var ready_tick := state.tick
	for tick in Config.AI_SKILL_REACTION_TICKS:
		var before := state.state_hash()
		if not check(ai.commands_for_tick(state).is_empty() and state.state_hash()==before,"Ready manual skill waits full reaction time"):return
		state.step([],[])
	commands=ai.commands_for_tick(state)
	if not check(commands.size()==1 and commands[0].kind==InputCommand.Kind.SKILL and commands[0].tick==ready_tick+9,"AI skill emits after nine ticks"):return
	state.step(commands,[])
	unit.skill_ticks_left=0
	unit.sp=35
	ai.commands_for_tick(state)
	unit.silence_ticks_left=30
	if not check(ai.commands_for_tick(state).is_empty() and not ai._skill_ready_at.has(unit.unit_id),"Silence invalidates pending ready reaction"):return
	unit.silence_ticks_left=0
	ai.commands_for_tick(state)
	if not check(ai._skill_ready_at[unit.unit_id]==state.tick+9,"Re-enabled skill restarts reaction instead of firing stale intent"):return
	print("PACE_OK: 0.75 combat, five-minute deadline, one-minute overtime, normal UI speed, pause and delayed legal AI")
	quit(0)


func check(ok: bool,message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
