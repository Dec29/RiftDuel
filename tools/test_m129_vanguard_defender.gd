extends SceneTree
var failures := 0
var data := {}
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func _initialize()->void:
	for id in ["wildmane","eunectes"]:
		data[id]=load("res://resources/operators/"+id+".tres");check(data[id].validation_error().is_empty(),id+" schema: "+data[id].validation_error())
	data.guard=(load("res://resources/operators/silverash.tres") as OperatorData).duplicate(true);data.guard.operator_id="guard"
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true)
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;data.target=dummy
	var s := fixture("wildmane",0);var u := deploy(s,"wildmane",Vector2i(12,5))
	check(u!=null and s.sides[0].cost==85,"Wildmane actual14fee deploy")
	check(u.skill_ticks_left==899 and SkillRules.attack_interval_ticks(u,data.wildmane)==13,"Wildmane passive30sec ASPD135")
	check(s.sides[0].wildmane_discounts.get("guard",0)==1 and DeployRules.actual_cost(data.guard,s.sides[0])==data.guard.deploy_cost-1,"Undeployed guard discount1")
	for i in 7:VanguardDefenderRules.deployed(s,u,data.wildmane)
	check(s.sides[0].wildmane_discounts.guard==5,"Guard discount capped5")
	var fake_guard := UnitState.new(99,0,"guard",Vector2i(15,5),1000,0,0)
	VanguardDefenderRules.deployed(s,fake_guard,data.guard)
	check(not s.sides[0].wildmane_discounts.has("guard"),"Guard successful deployment consumes discount")
	s=fixture("wildmane",1);u=deploy(s,"wildmane",Vector2i(12,5));u.sp=40;u.attack_ticks_left=1
	var e := enemy(s,Vector2i(13,5));s._operator_data.target=s._operator_data.target.duplicate(true);s._operator_data.target.profession_id="specialist";s._operator_data.target.branch_trait=load("res://resources/operators/phantom.tres").branch_trait
	s.step([InputCommand.new(s.tick,1,"",u.unit_id,Vector2i.ZERO,1)],[])
	check(u.skill_ticks_left==599 and u.sp==0 and SkillRules.attack_value(u,data.wildmane)==1004,"Wildmane S2 actual20sec ATK80%")
	check(e.cell==Vector2i(15,5),"Wildmane M125 moderate2 minus fast redeploy0 pushes2 cells")
	for index in 3:
		s=fixture("eunectes",index);u=deploy(s,"eunectes",Vector2i(12,5))
		check(s.sides[0].cost==66,"Eunectes actual33fee")
		if index==0:
			check(u.skill_ticks_left==-2 and SkillRules.attack_value(u,data.eunectes)==1259 and SkillRules.defense_value(u,data.eunectes)==769,"Eunectes passive25%ATK DEF")
			continue
		var initial := u.sp;u.attack_ticks_left=100000
		for t in 60:s.step([],[])
		check(u.sp==initial,"Duelist no natural SP without blocked enemy")
		e=enemy(s,Vector2i(13,5))
		for t in 150:s.step([],[])
		check(u.sp==initial+6,"Duelist blocked1.2 SP/s")
		u.sp=data.eunectes.skills[index].sp_required;u.attack_ticks_left=1;u.hp=2000
		s.step([InputCommand.new(s.tick,1,"",u.unit_id,Vector2i.ZERO,index)],[])
		check(u.sp==0,"Eunectes manual SP spent")
		if index==1:check(e.stun_ticks_left>0 and SkillRules.attack_interval_ticks(u,data.eunectes)==60,"S2 blocks stun and base interval+0.4s")
		else:
			check(SkillRules.block_count_value(u,data.eunectes)==3 and SkillRules.attack_value(u,data.eunectes)==3323 and SkillRules.defense_value(u,data.eunectes)==1599,"S3 ATK230% DEF160% block+2")
			var hp := u.hp;u.attack_ticks_left=100000
			for t in 30:s.step([],[])
			check(u.hp>hp,"S3 integer HP regen at existing50% heal coefficient")
			u.skill_ticks_left=1;s.step([],[]);check(u.stun_ticks_left>0 and u.skill_ticks_left==0,"S3 end self-stun150ticks")
		u.hp=2234;check(SkillRules.sanctuary_percent(u,data.eunectes)==20,"Exactly50%HP gets20% sanctuary")
		u.hp=2235;check(SkillRules.sanctuary_percent(u,data.eunectes)==0,"Above50%HP no sanctuary")
	var a := fixture("eunectes",1);var b := fixture("eunectes",1)
	for state in [a,b]:var actor := deploy(state,"eunectes",Vector2i(12,5));enemy(state,Vector2i(13,5));actor.sp=28
	for t in 900:
		var commands:Array[InputCommand]=[]
		if t==0:commands.append(InputCommand.new(a.tick,1,"",a.units[0].unit_id,Vector2i.ZERO,1))
		a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Everytick deterministic duel replay%d"%t)
	print("M129_SIMPLE_VANGUARD_DEFENDER_OK failures=",failures);quit(0 if failures==0 else 1)
func fixture(id:String,index:int)->MatchState:
	var s := MatchState.new(129,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[[id,"guard"],["target"]],[[index,0],[0]])
	s.sides[0].cost=99;return s
func deploy(s:MatchState,id:String,cell:Vector2i)->UnitState:
	s.step([InputCommand.new(s.tick,0,id,-1,cell,-1,0)],[]);s.ball.cell=Vector2i(5,5)
	for unit in s.units:
		if unit.operator_id==id:return unit
	return null
func enemy(s:MatchState,cell:Vector2i)->UnitState:
	var unit := UnitState.new(s.next_unit_id,1,"target",cell,100000,0,100000)
	s.next_unit_id+=1;s.units.append(unit);return unit
