extends SceneTree

var failures := 0
var data := {}
var op: OperatorData

func _initialize() -> void:
	op=load("res://resources/operators/dusk.tres");data.dusk=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.attack=1;dummy.defense=0;dummy.magic_resist=0;data.target=dummy
	var state := fixture(0);var actor := state.units[0];var foe := enemy(state,Vector2i(14,3))
	actor.sp=15;actor.attack_ticks_left=0;state.step([],[])
	var token := freeling(state)
	check(actor.sp==10 and actor.skill_activation_count==1 and actor.skill_ticks_left==0,"S1 three stored charges, exactlyone spent per actual attack")
	check(foe.hp==100000-magic(2295),"S1 actual250percent magic")
	check(token!=null and token.cell!=foe.cell and state.terrain_at(token.cell)=="ground" and state._is_in_attack_range(actor,token.cell,op.attack_range),"First actual enemy attack spawns nearest own legal free ground cell")
	check(token.dusk_expiry_tick==751 and token.hp==1997 and SkillRules.damage_profession_id(state._operator_data.dusk_freeling)=="caster","Exact token25sec and source caster coefficient")
	check(not state.can_deploy(0,"dusk_freeling",Vector2i(16,3)),"Automatic token rejects direct DEPLOY")
	check(SkillRules.healing_received(token,state._operator_data.dusk_freeling,500,actor)==0,"Freeling excludes normal treatment")
	var hash_before := state.state_hash();token.dusk_expiry_tick+=1;check(hash_before!=state.state_hash(),"Token expiry is hashed");token.dusk_expiry_tick-=1
	actor.attack_ticks_left=100000;state.tick=751;DuskRules.maintain(state)
	check(freeling(state)==null,"Exact token expiry removes occupancy")
	var full := fixture(0);actor=full.units[0];foe=enemy(full,Vector2i(14,3))
	for offset in op.attack_range:
		var cell := actor.cell+offset
		if cell!=actor.cell and cell!=foe.cell:enemy(full,cell)
	actor.attack_ticks_left=0;full.step([],[])
	check(actor.dusk_first_attack_used and freeling(full)==null,"No legal cell consumes one-time first attack without overlap")
	full.units=full.units.slice(0,2);actor.attack_ticks_left=0;full.step([],[])
	check(freeling(full)==null,"Failed first spawn cannot retry on later basic attacks")
	var ink := fixture(1);actor=ink.units[0];foe=enemy(ink,Vector2i(14,3));var low := enemy(ink,Vector2i(15,2));low.hp=49999
	actor.sp=38;actor.attack_ticks_left=0;cast(ink)
	check(actor.skill_ticks_left==599 and SkillRules.attack_value(actor,op)==1423 and SkillRules.attack_interval_ticks(actor,op)==56,"S2 actual20sec ATK55 AS55")
	check(foe.hp==100000-magic(1423) and low.hp==49999-magic(1423,130),"S2 attacks allrange with strictly below-half130percent damage")
	var free := fixture(2);actor=free.units[0];foe=enemy(free,Vector2i(14,3));actor.sp=100;actor.attack_ticks_left=0;cast(free)
	token=freeling(free)
	check(actor.skill_ticks_left==1799 and SkillRules.attack_interval_ticks(actor,op)==122,"S3 actual60sec and interval2.9x1.4")
	check(token!=null,"S3 first actual attack generates freeling")
	token.hp=500;actor.attack_ticks_left=0;free.step([],[])
	check(freeling(free)==token and token.hp==1499 and token.dusk_expiry_tick==752,"S3 refreshes nearby token:25sec and original100percent heal through50percent coefficient")
	for index in 20:DuskRules.reward_kill(free,token,foe)
	check(actor.dusk_kill_stacks==15 and SkillRules.attack_value(actor,op)==2295,"Owned summon kills grant2percent up to15 additive stacks")
	free._retreat_unit(actor);check(freeling(free)==null,"Owner manual exit removes token same tick")
	var death := fixture(2);actor=death.units[0];foe=enemy(death,Vector2i(14,3));actor.sp=100;actor.attack_ticks_left=0;cast(death);actor.hp=0;death.step([],[])
	check(freeling(death)==null,"Owner defeat removes token same tick")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for replay in [a,b]:enemy(replay,Vector2i(14,3));replay.units[0].sp=SkillRules.sp_limit(op.skills[index]);replay.units[0].attack_ticks_left=0
		for tick in 800:
			var commands:Array[InputCommand]=[]
			if tick==0 and index>0:commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Dusk replay S%d tick%d"%[index+1,tick])
	print("DUSK_OK all3skills, charged AoE/allrange/HPthreshold, fixedstation auto summon/failedspawn/refresh/expiry/ownership/death, strict treatment and stacking,3x800tick replay; failures=",failures)
	quit(0 if failures==0 else 1)

func fixture(index:int) -> MatchState:
	var state := MatchState.new(129,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["dusk"],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,"dusk",-1,Vector2i(13,2),-1,0)],[])
	check(state.units.size()==1 and state.sides[0].cost==65,"Actual34cost legal high deployment")
	state.ball.cell=Vector2i(10,5);state.units[0].attack_ticks_left=100000;return state

func freeling(state:MatchState) -> UnitState:
	for unit in state.units:
		if unit.operator_id=="dusk_freeling":return unit
	return null

func enemy(state:MatchState,cell:Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,100000,0,100000)
	state.units.append(unit);state.next_unit_id+=1;return unit

func cast(state:MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)],[])

func magic(power:int,scale:int=100) -> int:
	return Combat.calculate_damage(power,0,0,"magical",0,RNG.new(1),"caster",scale)

func check(condition:bool,message:String) -> void:
	if not condition:failures+=1;push_error(message)
