extends "res://tools/test_m129_guard_specialists.gd"

func _initialize()->void:
	data.ling=load("res://resources/operators/ling.tres")
	data.bagpipe=load("res://resources/operators/bagpipe.tres")
	var dummy: OperatorData=data.bagpipe.duplicate(true);dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.profession_id="caster";dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	check(data.ling.validation_error().is_empty(),"Ling exact schema "+data.ling.validation_error())
	for id in LingRules.IDS:check((load("res://resources/summons/"+id+".tres") as OperatorData).validation_error().is_empty(),id+" strict schema")
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty()else "supply"
	if mode=="supply":supply()
	elif mode=="s1":wine()
	elif mode=="s2":chord()
	elif mode=="s3":thunder()
	elif mode=="merge":merge()
	elif mode=="edges":ling_edges()
	elif mode=="replay":ling_replay()
	print("M129_LING_OK ",mode," failures=",failures);quit(0 if failures==0 else 1)

func fixture(id: String,index: int)->MatchState:
	var state := MatchState.new(129,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["bagpipe",id],["target"]],[[2,index],[0]])
	check(state.sides[0].ling_stock==5,"Ling five stock initialized once in realMatchState")
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,id,-1,Vector2i(14,4),-1,2)],[])
	check(state.units.size()==1 and state.units[0].operator_id==id and state.units[0].skill_index==index,"ActuallegalhighLingdeploy withnonzero carriedskill")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=100000;return state

func soul(state: MatchState,index: int,cell: Vector2i,facing: int=2)->UnitState:
	var id: String=LingRules.IDS[index];state.sides[0].cost=99
	var next := state.next_unit_id;state.step([InputCommand.new(state.tick,0,id,-1,cell,-1,facing)],[])
	for unit in state.units:
		if unit.unit_id==next:return unit
	return null

func supply()->void:
	for index in 3:
		var state := fixture("ling",index);var source := state.units[0];var id: String=LingRules.IDS[index]
		check(state.carried_skill_index(0,id)==0,"Summononlypassiveskill remains0 whencarriedownerindex%d"%index)
		var cell := Vector2i(14,6) if index==1 else Vector2i(14,5)
		check(not state.can_deploy(0,LingRules.IDS[(index+1)%3],cell),"Wrongskillmodule rejected")
		state.sides[0].next_deploy_discount=7;var token := soul(state,index,cell)
		check(token!=null and token.ling_owner_id==source.unit_id and token.skill_index==0,"Actualsummondeploy ownerbinding")
		check(state.sides[0].cost==99-[12,9,23][index] and state.sides[0].next_deploy_discount==7 and state.sides[0].ling_stock==4,"Exactoriginalfee excludesordinaryoneuse discount, stock-1")
		check(state.sides[0].cooldowns[id]==[300,300,600][index],"Modulecooldown startsdeployment")
		state._retreat_unit(token);check(state.sides[0].ling_stock==4 and source.ling_recycle_stacks==0 and state.sides[0].cost==99-[12,9,23][index],"Manualsummonretreat no stock/refund/talentreward")
		state._retreat_unit(source);check(state.sides[0].ling_stock==4,"Ownerretreat stockpersists")
		state.sides[0].cooldowns["ling"]=0;state.sides[0].cost=99;state.step([InputCommand.new(state.tick,0,"ling",-1,Vector2i(14,4),-1,2)],[])
		check(state.units.size()==1 and state.sides[0].ling_stock==4 and state.units[0].ling_recycle_stacks==0,"Ownerredeploy doesnotrefillmatchstock andclearsperdeploystacks")
	var state := fixture("ling",0);var token := soul(state,0,Vector2i(14,5));state.units[0].sp=0;token.hp=0;state.step([],[])
	check(state.units[0].sp==3 and state.units[0].ling_recycle_stacks==1 and state.sides[0].cooldowns.ling_soul1==299,"Death rewards3SP andstack once, cooldownnotreset")

func wine()->void:
	var state := fixture("ling",0);var source := state.units[0];var token := soul(state,0,Vector2i(14,5));source.sp=25;cast(state)
	check(source.skill_ticks_left==749 and state.sides[0].ling_stock==5,"S1 real25SP25seconds +one stock capped5")
	check(SkillRules.attack_value(source,data.ling)==710 and SkillRules.attack_interval_ticks(source,data.ling)==32,"S1 ownerattack+50%AS+50")
	var td: OperatorData=state._operator_data[token.operator_id]
	check(SkillRules.attack_value(token,td)==824 and SkillRules.attack_interval_ticks(token,td)==25 and SkillRules.damage_type(token,td)=="magical","S1 soulATK+50AS+50 magicdamage")
	var target := enemy(state,Vector2i(13,5));token.attack_ticks_left=0;state.step([],[]);check(target.hp==99835,"Soul attackinherits support20%damage coefficient")
	token.hp=1000;var before := token.hp;LumenRules.treat_amount(state,token,1000,source);check(token.hp==before,"Ling summon notordinaryhealtarget")
	StatusRules.apply_silence(state,source,60);check(SkillRules.damage_type(token,td)=="physical" and SkillRules.attack_value(token,td)==549,"Ownersilence suspends active summonbuff")
	source.silence_ticks_left=0;source.skill_ticks_left=1;state.step([],[]);check(token in state.units and SkillRules.damage_type(token,td)=="physical","S1 expirationdoesnotMagallanrecall")

func chord()->void:
	var state := fixture("ling",1);var source := state.units[0];var token := soul(state,1,Vector2i(14,6));source.sp=26;token.hp=609
	var one := enemy(state,Vector2i(13,5));var two := enemy(state,Vector2i(12,5));var three := enemy(state,Vector2i(13,7));cast(state)
	check(source.sp==13 and source.skill_ticks_left==0 and token in state.units,"S2 two13SPcharges,instantend,strictbelowhalf excludes609/1217")
	check(one.hp==99209 and two.hp==99209 and three.hp==100000,"S2 owner andsoul independentlyselectmax2each450magic: %d %d %d"%[one.hp,two.hp,three.hp])
	check(one.bind_ticks_left==89 and two.bind_ticks_left==89,"S2 root3seconds shares commandphasecontroltick")
	token.hp=608;source.sp=13;cast(state)
	check(token not in state.units and state.sides[0].ling_stock==5 and source.sp==3 and source.ling_recycle_stacks==1,"S2 strictbelowhalf recoversone stock and afterend grants3SP+3%ATK")
	var empty := fixture("ling",1);source=empty.units[0];source.sp=26;cast(empty);check(source.sp==13,"S2 no enemy stillactivates and consumesonecharge")

func thunder()->void:
	var state := fixture("ling",2);var source := state.units[0];var token := soul(state,2,Vector2i(14,5));source.sp=40;cast(state)
	var td: OperatorData=state._operator_data[token.operator_id]
	check(source.skill_ticks_left==899 and SkillRules.attack_value(source,data.ling)==946 and SkillRules.defense_value(source,data.ling)==276,"S3 real40SP30sec owner100%ATKDEF")
	check(SkillRules.attack_value(token,td)==1646 and SkillRules.defense_value(token,td)==846,"S3 normaldragon100%ATKDEF")
	var target := enemy(state,Vector2i(15,5));var diagonal := enemy(state,Vector2i(15,6));var before := target.hp
	for tick in 14:state.step([],[])
	check(target.hp==before-38 and diagonal.hp==100000,"15effectiveticks fourneighbors20%LingcurrentATK atsupport20%factor")
	var phase := source.ling_pulse_ticks;StatusRules.apply_silence(state,source,30)
	for tick in 20:state.step([],[])
	check(source.ling_pulse_ticks==phase,"SuppressedS3 pauses effectivepulseticks")
	source.silence_ticks_left=0;source.skill_ticks_left=1;state.step([],[])
	check(state.sides[0].ling_stock==5 and token in state.units and SkillRules.attack_value(token,td)==823,"S3 naturalend addsstock andkeepsdragon insteadMagallanrecall")

func merge()->void:
	var state := fixture("ling",2);var source := state.units[0];var old := soul(state,2,Vector2i(13,5),0);old.hp=1;state.sides[0].cooldowns.ling_soul3=0
	var absorbed_id := state.next_unit_id;var newer := soul(state,2,Vector2i(14,5),2)
	check(newer==null and state.units.size()==2 and old.ling_advanced and old.cell==Vector2i(13,5) and old.facing==0,"Newrangecontainsold: newconsumed oldretainscellfacing")
	check(state.next_unit_id==absorbed_id+1 and state.sides[0].ling_stock==3 and LingRules.weighted_count(state,0)==2 and source.ling_recycle_stacks==1,"Merge consumesstock/unitID exactlyonce, advancedweight2 andone talentstack")
	var td: OperatorData=state._operator_data[old.operator_id]
	check(old.hp==7214 and SkillRules.max_health_value(old,td)==7214 and SkillRules.attack_value(old,td)==1481 and SkillRules.defense_value(old,td)==761 and SkillRules.magic_resist_value(old,td)==20 and SkillRules.attack_interval_ticks(old,td)==69 and SkillRules.block_count_value(old,td)==4 and SkillRules.damage_type(old,td)=="magical","ExactadvancedfullHP HP%d max%d ATK%d DEF%d RES%d interval%d block%d type%s"%[old.hp,SkillRules.max_health_value(old,td),SkillRules.attack_value(old,td),SkillRules.defense_value(old,td),SkillRules.magic_resist_value(old,td),SkillRules.attack_interval_ticks(old,td),SkillRules.block_count_value(old,td),SkillRules.damage_type(old,td)])
	source.sp=40;cast(state);check(SkillRules.attack_value(old,td)==2304 and SkillRules.defense_value(old,td)==1184,"Advanced80%plusS3 100% additive ratherthanmultiplicative")
	var fronts: Array[UnitState]=[]
	for cell in [Vector2i(12,5),Vector2i(14,5),Vector2i(13,4),Vector2i(13,6)]:fronts.append(enemy(state,cell))
	old.attack_ticks_left=0;state.step([],[])
	for target in fronts:check(target.hp<100000,"Advanceddragon attacksall4ownblockedneighbors")
	state.sides[0].cooldowns.ling_soul3=0;soul(state,2,Vector2i(16,5),2);state.sides[0].cooldowns.ling_soul3=0;check(LingRules.weighted_count(state,0)==3 and not state.can_deploy(0,"ling_soul3",Vector2i(17,5)),"Weightedcap3 blocks fourthquota")
	state=fixture("ling",2);old=soul(state,2,Vector2i(13,5),0);state.sides[0].cooldowns.ling_soul3=0;newer=soul(state,2,Vector2i(14,5),0)
	check(newer!=null and newer.ling_advanced and old not in state.units and newer.cell==Vector2i(14,5),"Onlyoldrangecontainsnew: oldconsumed newadvanced retainsfacing")

	state=fixture("ling",2)
	var earlier := soul(state,2,Vector2i(15,5),0);state.sides[0].cooldowns.ling_soul3=0
	var latest := soul(state,2,Vector2i(16,6),3);state.sides[0].cooldowns.ling_soul3=0
	newer=soul(state,2,Vector2i(16,5),0)
	check(newer!=null and newer.ling_advanced and earlier in state.units and latest not in state.units,"Multipleoldranges containingnew consumehighestID mostrecentdeployment")


func ling_edges()->void:
	var state := fixture("ling",0);var source := state.units[0];source.sp=25;cast(state);var token := soul(state,0,Vector2i(14,5));token.hp=0;state.step([],[])
	check(source.sp==0 and source.ling_recycle_stacks==1,"Deathduringactiveskill stacksATK but doesnotbypassSPlock")
	for tick in 7:LingRules.reward(state,source)
	AuraRules.refresh(state);check(source.ling_recycle_stacks==5 and SkillRules.attack_value(source,data.ling)==780,"Talentstackcaps5 additive15%withskill50%")
	state.sides[0].cooldowns.ling_soul1=0;token=soul(state,0,Vector2i(14,5));state._retreat_unit(source);check(token not in state.units and state.sides[0].ling_stock==3,"Ownerretreatcleanssummons withoutstockrefund")
	state=fixture("ling",2);source=state.units[0];token=soul(state,2,Vector2i(14,5));source.hp=0;state.step([],[]);check(state.units.is_empty(),"Ownerdeathcleansownedtokens")

func ling_replay()->void:
	for index in 3:
		var a := fixture("ling",index);var b := fixture("ling",index)
		for state in [a,b]:soul(state,index,Vector2i(14,6)if index==1 else Vector2i(14,5));state.units[0].sp=data.ling.skills[index].sp_required;enemy(state,Vector2i(13,5))
		for tick in 1000:
			var commands: Array[InputCommand]=[]
			if tick==0:commands.append(InputCommand.new(a.tick,1,"",a.units[0].unit_id,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[])
			if a.state_hash()!=b.state_hash():check(false,"Lingpairreplay firstdivergence S%d tick%d"%[index,tick]);break
		# A newround reconstructs sidestock instead ofcarrying lastmatch's consumables.
		var next_round := fixture("ling",index);check(next_round.sides[0].ling_stock==5,"Newround resetsmatchstock")
