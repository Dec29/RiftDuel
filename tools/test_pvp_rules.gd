extends SceneTree
var failures := 0
func _initialize() -> void:
	var data := {"bagpipe":load("res://resources/operators/bagpipe.tres")}
	var rules := MatchRules.new("score",1,3)
	check(MatchRules.validate({"mode":"score","minutes":30,"rounds":9,"draft_enabled":false}).is_empty(),"maximum settings")
	for invalid in [{"mode":"bad","minutes":5,"rounds":1,"draft_enabled":false},{"mode":"score","minutes":0,"rounds":1,"draft_enabled":false},{"mode":"score","minutes":31,"rounds":1,"draft_enabled":false},{"mode":"score","minutes":5,"rounds":10,"draft_enabled":false},{"mode":"score","minutes":1.5,"rounds":1,"draft_enabled":false},{"mode":"score","minutes":5,"rounds":1,"draft_enabled":false,"extra":0}]:check(not MatchRules.validate(invalid).is_empty(),"reject invalid rules")
	var state := MatchState.new(31,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[],[],rules)
	rules.minutes=30
	check(state.rules.minutes==1,"immutable copied rules")
	var unit := UnitState.new(0,0,"bagpipe",Vector2i(18,5),1000,0,30,2)
	unit.skill_ticks_left=100;unit.mark_kind=2;unit.mark_cell=Vector2i(0,5)
	state.units.append(unit);state.sides[0].cost=99;state.sides[0].cooldowns["exusiai"]=50
	state.ball.cell=Vector2i(0,5);state.ball.accum=Vector2i(150,70);state.ball.displacement_steps_left=3
	var bomb := WExplosive.new();bomb.kind=3;bomb.side=0;bomb.source_id=0;bomb.cell=Vector2i(0,5);bomb.explode_tick=100;bomb.expire_tick=200
	state.w_bombs.append(bomb)
	state.step([],[])
	check(state.result==0 and state.goals==PackedInt32Array([1,0]),"goal increments without ending")
	check(state.ball.cell==Config.BALL_START_CELL and state.ball.accum==Vector2i.ZERO and state.ball.move_ticks_left==0 and state.ball.displacement_steps_left==0,"fresh stationary center ball")
	check(state.units.size()==1 and state.units[0]==unit and unit.hp==1000 and unit.skill_ticks_left==99 and state.sides[0].cost==99 and state.sides[0].cooldowns.exusiai==49,"units HP SP timers cost cooldown preserved")
	check(unit.mark_kind==3 and bomb.kind==4 and bomb.cell==Vector2i(0,5),"old ball marks detach at old position")
	state.step([],[InputCommand.new(state.input_tick,InputCommand.Kind.SKIP_RECOVERY)])
	state.ball.cell.x=20;state.step([],[])
	check(state.goals==PackedInt32Array([1,1]) and state.result==0,"opponent goal and continuous clock")
	state.tick=1349;state.ball.cell.x=0;state.step([],[])
	check(state.result==1 and state.goals[0]==2,"last settled goal counts before timeout")
	var frozen := state.state_hash();state.step([],[]);check(frozen==state.state_hash(),"completed state frozen")
	var draw := MatchState.new(32,{},MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[],[],MatchRules.new("score",1,1))
	draw.tick=1349;draw.ball.cell.x=2;draw.step([],[]);check(draw.result==3,"tied score independent of ball position, no overtime")
	var moving := MatchState.new(32,{},MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[],[],MatchRules.new("score",1,1))
	moving.tick=1349;moving.ball.cell.x=1;moving.ball.move_direction=Vector2i.LEFT;moving.ball.move_ticks_left=2;moving.step([],[]);check(moving.result==3 and moving.goals[0]==0,"unfinished goal not counted")
	var single := MatchState.new(32,{},MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[],[],MatchRules.new("single",2,1))
	single.tick=2699;single.step([],[]);check(single.result==0,"custom single-goal overtime")
	single.tick=4049;single.step([],[]);check(single.result==3,"single-goal maximum overtime")
	var first := MatchState.new(42,{},MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[],[],MatchRules.new("score",1,2))
	var second := MatchState.new(42,{},MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[],[],MatchRules.new("score",1,2))
	for tick in 1350:
		if tick in [20,200,400]:first.ball.cell.x=0;second.ball.cell.x=0
		if tick==900:first.ball.cell.x=20;second.ball.cell.x=20
		first.step([],[]);second.step([],[]);check(first.state_hash()==second.state_hash(),"score replay tick%d"%tick)
	check(first.goals==PackedInt32Array([3,1]) and first.result==1,"full timed round")
	check(MatchRules.new("score",30,9).max_ticks()==40500 and MatchRules.new("single",30,9).max_ticks()==41850,"dynamic tick caps")
	print("PVP_RULES_OK goals, state preservation, marks, bounds, deadlines, custom single-goal and 1350-tick deterministic replay; failures=",failures)
	quit(0 if failures==0 else 1)
func check(value: bool,message: String) -> void:
	if not value:failures+=1;push_error(message)
