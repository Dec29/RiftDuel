extends SceneTree
var failures := 0
func _initialize() -> void:
	check_attack_clock()
	check_cost_distribution()
	check_independent_actions()
	print("SHARED_EFFECTS_OK: ordinary clock freeze/countdown, actual cost skills exact totals/cap/remainders, bound W mine and sleeping independent field; failures=",failures)
	quit(0 if failures==0 else 1)
func check_attack_clock() -> void:
	# Initial cooldown, sleep, displacement, stun, bind, expected cooldown, may act.
	for row in [[2,0,0,0,0,1,false],[1,0,0,0,0,0,true],[2,1,0,0,0,2,false],[2,0,1,0,0,2,false],[2,0,0,1,0,1,false],[1,0,0,1,0,0,false],[1,0,0,0,1,0,false],[2,1,0,0,1,2,false]]:
		var unit := UnitState.new(0,0,"bagpipe",Vector2i(14,5),1000,0,row[0])
		unit.sleep_ticks_left=row[1];unit.displacement_ticks_left=row[2];unit.stun_ticks_left=row[3];unit.bind_ticks_left=row[4]
		var ready := StatusRules.advance_basic_attack(unit)
		check(unit.attack_ticks_left==row[5] and ready==row[6],"Ordinary control/cooldown contract "+str(row))
	var silenced := UnitState.new(0,0,"bagpipe",Vector2i(14,5),1000,0,1);silenced.silence_ticks_left=30;silenced.bind_immunity_ticks_left=30
	check(StatusRules.advance_basic_attack(silenced),"Silence and bind immunity do not prohibit a ready ordinary attack")
func check_cost_distribution() -> void:
	for selection in [["myrtle",0],["myrtle",1],["saileach",0],["saileach",1],["zima",1]]:
		var id: String=selection[0];var data: OperatorData=load("res://resources/operators/"+id+".tres");var skill := data.skills[selection[1]]
		var ticks := roundi(skill.duration*30);var amount := int(skill.effect_params["total_cost"])
		for initial in [0,98]:
			var state := MatchState.new(19,{id:data});var unit := UnitState.new(0,0,id,Vector2i(14,5),1000,0,20)
			state.sides[0].cost=initial
			for elapsed in range(1,ticks+1):
				SkillRules.advance_cost_regen(state,unit,skill)
				check(state.sides[0].cost==mini(99,initial+(amount*elapsed)/ticks),"Exact cumulative cost "+id+str(selection[1])+" tick"+str(elapsed))
			check(unit.skill_cost_accum==0 and unit.attack_ticks_left==20,"Full duration leaves no lost fraction and does not alter action clock")
func check_independent_actions() -> void:
	var w: OperatorData=load("res://resources/operators/w.tres");var state := MatchState.new(31,{"w":w})
	var unit := UnitState.new(0,0,"w",Vector2i(14,2),w.max_health,SkillRules.sp_limit(w.skills[1]),1,2,1);unit.bind_ticks_left=60
	state.units=[unit];state.next_unit_id=1;state.ball.cell=Vector2i(10,10)
	AttackRules.resolve(state)
	check(state.w_bombs.size()==1 and unit.w_action_kind==1,"Bind permits W's independent mine placement before ordinary attack gate")
	var ifrit: OperatorData=load("res://resources/operators/ifrit.tres");var target_data: OperatorData=load("res://resources/operators/bagpipe.tres")
	state=MatchState.new(32,{"ifrit":ifrit,"bagpipe":target_data});unit=UnitState.new(0,0,"ifrit",Vector2i(14,5),ifrit.max_health,0,77,2,2)
	unit.skill_ticks_left=300;unit.skill_elapsed_ticks=29;unit.sleep_ticks_left=60;unit.bind_ticks_left=60
	var target := UnitState.new(1,1,"bagpipe",Vector2i(13,5),target_data.max_health,0,10000);state.units=[unit,target];state.next_unit_id=2;state.ball.cell=Vector2i(10,10)
	AttackRules.resolve(state)
	check(target.hp<target_data.max_health and unit.attack_ticks_left==77,"Released ground effect continues while ordinary attack clock is frozen")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
