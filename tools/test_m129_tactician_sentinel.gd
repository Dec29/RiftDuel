extends SceneTree

var failures := 0
var data := {}

func check(value: bool, label: String) -> void:
	if not value:failures+=1;push_error(label)

func _initialize() -> void:
	for id in ["muelsyse","jessica_alter","wildmane","eunectes","silverash","exusiai","saria","ptilopsis"]:data[id]=load("res://resources/operators/%s.tres"%id)
	var dummy: OperatorData=load("res://resources/operators/bagpipe.tres");dummy=dummy.duplicate(true);dummy.operator_id="target";dummy.max_health=1000000;dummy.attack=100;dummy.defense=200;dummy.magic_resist=0;data.target=dummy
	for id in ["muelsyse","jessica_alter"]:check(data[id].validation_error().is_empty(),id+" schema "+data[id].validation_error())
	for id in ["flowing_shape","jessica_shield"]:check((load("res://resources/summons/%s.tres"%id) as OperatorData).validation_error().is_empty(),id+" summon schema")
	check_flow_copy()
	check_flow_skills()
	check_shield_skills()
	check_melee_interaction()
	check_lifecycle_edges()
	check_replay()
	print("M129_TACTICIAN_SENTINEL_OK failures=",failures)
	quit(0 if failures==0 else 1)

func fixture(id: String, index: int) -> MatchState:
	var ids := PackedStringArray([id,"silverash","exusiai","saria","ptilopsis"])
	var indices := PackedInt32Array([index,0,0,0,0])
	var state := MatchState.new(1291,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,PackedStringArray(["target"])],[indices,PackedInt32Array([0])])
	state.sides[0].cost=99;state.ball.cell=Vector2i(5,5)
	return state

func deploy(state: MatchState, id: String, cell: Vector2i, facing: int=0) -> UnitState:
	state.step([InputCommand.new(state.tick,InputCommand.Kind.DEPLOY,id,-1,cell,-1,facing)],[])
	for unit in state.units:
		if unit.operator_id==id:return unit
	check(false,"Actual deploy failed "+id+str(cell));return null

func enemy(state: MatchState, cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,1,"target",cell,1000000,0,100000)
	state.next_unit_id+=1;state.units.append(unit);return unit

func open_copy(state: MatchState, flow: UnitState) -> void:
	flow.sp=100
	state.step([InputCommand.new(state.tick,InputCommand.Kind.SKILL,"",flow.unit_id,Vector2i.ZERO,0)],[])
	check(flow.skill_ticks_left==599 and flow.sp==0,"Flow actual20sec copy window")

func copy_card(state: MatchState, flow: UnitState, id: String) -> void:
	open_copy(state,flow)
	state.step([InputCommand.new(state.tick,InputCommand.Kind.COPY,id,flow.unit_id,Vector2i.ZERO,-1,0)],[])
	check(flow.flow_copy_id==id and flow.skill_ticks_left==0,"Actual COPY control "+id)

func cast(state: MatchState, unit: UnitState) -> void:
	var operator: OperatorData=state._operator_data[unit.operator_id]
	unit.sp=operator.skills[unit.skill_index].sp_required
	state.step([InputCommand.new(state.tick,InputCommand.Kind.SKILL,"",unit.unit_id,Vector2i.ZERO,unit.skill_index)],[])

func check_flow_copy() -> void:
	var s := fixture("muelsyse",0)
	check(DeployRules.actual_cost(data.muelsyse,s.sides[0])==12 and DeployRules.actual_cost(data.saria,s.sides[0])==data.saria.deploy_cost-3,"Rhine squad discount before first deployment")
	var u := deploy(s,"muelsyse",Vector2i(13,2))
	check(u!=null and s.sides[0].cost==87 and s.sides[0].rhine_first_discount_used,"Mue deployment applies and consumes firstRhine extra1")
	check(DeployRules.actual_cost(data.saria,s.sides[0])==data.saria.deploy_cost-2,"Remaining Rhine discount2")
	check(not s.can_deploy(0,"flowing_shape",Vector2i(19,5)),"Flow deployment restricted owner actual range")
	var f := deploy(s,"flowing_shape",Vector2i(13,3))
	check(f.sp==95 and SkillRules.block_count_value(f,s.FLOW_DATA)==1,"Uncopied flow95SP and block1")
	var hash_before := s.state_hash()
	check(not TacticianRules.copy(s,0,f.unit_id,"silverash",0) and s.state_hash()==hash_before,"COPY without window leaves state untouched")
	s.sides[0].cooldowns["silverash"]=2000
	copy_card(s,f,"silverash")
	check(f.flow_health==roundi(data.silverash.max_health*0.9) and f.flow_attack==roundi(data.silverash.attack*0.9) and f.flow_block==data.silverash.block_count,"90% stats, unscaled block, cooling card eligible")
	check(f.flow_range==data.silverash.attack_range and f.flow_melee and not f.flow_magical,"Ground physical profile and full exact range")
	check(SkillRules.damage_profession_id(s.FLOW_DATA)=="vanguard" and SkillRules.healing_received(f,s.FLOW_DATA,100)==0,"Flow source profession and no direct healing")
	var target := enemy(s,Vector2i(14,3));f.attack_ticks_left=1;s.step([],[])
	check(f.flow_stolen_attack==10 and f.flow_stolen_defense==10 and target.flow_attack_loss==10 and target.flow_defense_loss==10,"Melee hit steals10ATK/DEF")
	u.sp=28;cast(s,u)
	check(SkillRules.attack_value(f,s.FLOW_DATA)==roundi(f.flow_attack*1.5)+10,"Stolen10ATK is final flat addition, not amplified by owner50% buff")
	u.skill_ticks_left=0;AuraRules.refresh(s)
	open_copy(s,f)
	check(not TacticianRules.copy(s,1,f.unit_id,"exusiai",0) and not TacticianRules.copy(s,0,f.unit_id,"target",0),"COPY rejects wrong side and opponent card")
	check(TacticianRules.copy(s,0,f.unit_id,"exusiai",0),"Re-copy waiting ranged card")
	check(target.flow_attack_loss==0 and target.flow_defense_loss==0 and f.flow_stolen_attack==0,"Re-copy clears source theft and owned victim losses")
	for attack in 10:f.attack_ticks_left=1;s.step([],[])
	var split_count := 0
	for unit in s.units:
		if unit.flow_is_split:split_count+=1
	check(split_count==1 and f.flow_attack_count==0,"Ten actual ranged attacks create one legal split and reset counter")
	check(not TacticianRules.can_copy(s,0,s.units[-1].unit_id,"silverash"),"Split has no copy interaction")
	s._apply_damage(f,s.FLOW_DATA,1000000,"true")
	check(f.hp==1 and f.flow_point_until_tick==s.tick+750 and f.flow_copy_id=="exusiai" and SkillRules.block_count_value(f,s.FLOW_DATA)==0,"Fatal original flow becomes25sec point preserving copy")
	check(not s.enemy_is_targetable(1,f) and not s.can_deploy(0,"flowing_shape",Vector2i(14,4)),"Point invulnerable, untargetable and reserves unique token")
	var until := f.flow_point_until_tick
	while s.tick<=until:s.step([],[])
	check(f.flow_point_until_tick==0 and f.hp==SkillRules.max_health_value(f,s.FLOW_DATA),"Point restores full copied HP at25sec")
	s._retreat_unit(u)
	check(not s.units.any(func(unit:UnitState)->bool:return unit.flow_owner_id>=0),"Owner retreat removes original and split")
	check(s.sides[0].rhine_first_discount_used,"FirstRhine flag persists through retreat")

func check_flow_skills() -> void:
	for index in range(3):
		var s := fixture("muelsyse",index);var u := deploy(s,"muelsyse",Vector2i(13,2));var f := deploy(s,"flowing_shape",Vector2i(13,3))
		copy_card(s,f,"silverash" if index<2 else "exusiai")
		u.attack_ticks_left=100000;f.attack_ticks_left=100000
		s.sides[0].cost=0;s.sides[0].cost_regen_ticks=0;cast(s,u)
		check(u.skill_ticks_left==449 and u.sp==0 and f.flow_can_charge==false,"Mue S%d duration/SP/copy lock"%(index+1))
		check(SkillRules.attack_value(f,s.FLOW_DATA)==roundi(f.flow_attack*1.5),"Mue owner skill buffs flow attack50%")
		if index==0:
			check(SkillRules.attack_interval_ticks(f,s.FLOW_DATA)==roundi(f.flow_interval_ticks/1.5),"MueS1 flow attack speed+50")
			for tick in 449:s.step([],[])
			check(s.sides[0].cost==28 and u.skill_ticks_left==0,"MueS1 exact13 skill cost+15 natural after450ticks")
		elif index==1:
			check(s.sides[0].cost==15 and SkillRules.sanctuary_percent(f,s.FLOW_DATA)==25,"MueS2 immediate15cost and melee25sanctuary")
			f.hp=1000
			for tick in 30:s.step([],[])
			check(f.hp>1000,"MueS2 melee5%HP continuous regen under50% rule")
		else:
			check(s.sides[0].cost==15 and s.units.any(func(unit:UnitState)->bool:return unit.flow_is_split),"MueS3 immediate cost and legal neighboring ranged refresh")
			var e := enemy(s,Vector2i(14,3));f.attack_ticks_left=1;s.step([],[])
			check(e.bind_ticks_left==45,"MueS3 ranged hit binds1.5sec")

func check_shield_skills() -> void:
	for index in range(3):
		var s := fixture("jessica_alter",index);var u := deploy(s,"jessica_alter",Vector2i(12,5))
		check(not s.can_deploy(0,"jessica_shield",Vector2i(13,4)),"Shield diagonal rejected")
		var cost := s.sides[0].cost;var sh := deploy(s,"jessica_shield",Vector2i(12,4))
		check(sh!=null and s.sides[0].cost==cost-5 and s.sides[0].cooldowns.jessica_shield==900 and u.facing==3,"Shield actual5cost30sec cooldown and turnNorth")
		check(sh.jessica_expiry_tick==sh.deployed_tick+1500 and SkillRules.taunt_level(sh,s.JESSICA_SHIELD_DATA)==1,"Shield50sec and taunt1")
		check(SkillRules.healing_received(sh,s.JESSICA_SHIELD_DATA,100)==0,"Shield forbidden direct heal")
		u.attack_ticks_left=100000
		if index==0:
			u.sp=70;s.step([],[])
			check(u.skill_ticks_left==-2 and sh.jessica_expiry_tick==sh.deployed_tick+2400,"JessicaS1 infinite, shield lifetime+30sec")
			check(SkillRules.defense_value(sh,s.JESSICA_SHIELD_DATA)==1284,"JessicaS1 shield DEF+70%")
		elif index==1:
			cast(s,u)
			check(SkillRules.attack_interval_ticks(u,data.jessica_alter)==9 and SkillRules.dodge_chance(u,data.jessica_alter,"physical")==75 and SkillRules.dodge_chance(u,data.jessica_alter,"magical")==75,"JessicaS2 0.3sec interval and75% both dodge")
			check(AttackRange.effective_offsets(u,data.jessica_alter).has(Vector2i(2,1)),"JessicaS2 independent2-5 range")
		else:
			var target := enemy(s,Vector2i(12,3));cast(s,u)
			check(u.skill_ticks_left==-2 and u.skill_ammo_left==20 and u.jessica_bomb_tick==s.tick-1 and target.stun_ticks_left==180,"JessicaS3 shield triggers one free250% bomb/6sec stun")
			check(SkillRules.defense_value(sh,s.JESSICA_SHIELD_DATA)==2039 and AttackRange.effective_offsets(u,data.jessica_alter).has(Vector2i(3,0)),"JessicaS3 shield+170%DEF and distance+1")
			var last_bomb := u.jessica_bomb_tick
			s._retreat_unit(sh);s.sides[0].cooldowns.erase("jessica_shield");sh=deploy(s,"jessica_shield",Vector2i(12,4))
			check(u.jessica_bomb_tick>last_bomb and u.skill_ammo_left==20,"Each shield deployed duringS3 triggers one new free bomb without ammo")
			u.attack_ticks_left=1;s.step([],[]);check(u.skill_ammo_left==19,"Jessica ordinary attack consumes one ammo")
			u.skill_ammo_left=1;u.attack_ticks_left=1;s.step([],[]);check(u.skill_ticks_left==0,"Jessica final ammo closes skill")
			cast(s,u);s.step([InputCommand.new(s.tick,1,"",u.unit_id,Vector2i.ZERO,2)],[]);check(u.skill_ticks_left==0 and u.skill_ammo_left==0,"JessicaS3 manual close")
		s._retreat_unit(sh);check(u.facing==0 and sh not in s.units,"Shield retreat restores original facing without ordinary refund")
		s.sides[0].cooldowns.erase("jessica_shield");sh=deploy(s,"jessica_shield",Vector2i(12,4));s._retreat_unit(u)
		check(sh not in s.units,"Jessica exit removes bound shield")

func check_replay() -> void:
	var a := fixture("muelsyse",2);var b := fixture("muelsyse",2)
	for state in [a,b]:
		var owner := deploy(state,"muelsyse",Vector2i(13,2));var flow := deploy(state,"flowing_shape",Vector2i(13,3));copy_card(state,flow,"exusiai");enemy(state,Vector2i(14,3));owner.sp=35
	for tick in 900:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(InputCommand.new(a.tick,1,"",a.units[0].unit_id,Vector2i.ZERO,2))
		a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Flow900tick deterministic replay "+str(tick))

func check_lifecycle_edges() -> void:
	var s := fixture("jessica_alter",2)
	var u := deploy(s,"jessica_alter",Vector2i(12,5))
	var sh := deploy(s,"jessica_shield",Vector2i(12,4))
	for tick in 30:s.step([],[])
	var behind := UnitState.new(s.next_unit_id,0,"silverash",Vector2i(12,6),1000,0,100000)
	s.next_unit_id+=1;s.units.append(behind);AuraRules.refresh(s)
	check(SkillRules.defense_value(behind,data.silverash)==roundi(data.silverash.defense*1.15),"Approved shield aura reaches current rear tile")
	var remaining: int=s.sides[0].cooldowns.jessica_shield
	s._apply_damage(sh,s.JESSICA_SHIELD_DATA,1000000,"true")
	s.step([],[])
	check(SkillRules.defense_value(behind,data.silverash)==data.silverash.defense,"Shield exit removes rear defense aura")
	check(sh not in s.units and u.facing==0 and s.sides[0].cooldowns.jessica_shield==remaining-1,"Shield killed: original facing restored, deployment cooldown not restarted")
	s.sides[0].cooldowns.erase("jessica_shield")
	sh=deploy(s,"jessica_shield",Vector2i(12,4))
	var talent: TalentResource=data.jessica_alter.talent_2
	var old_chance: int=talent.effect_params.chance_percent
	talent.effect_params.chance_percent=100
	u.sp=0;s._apply_damage(sh,s.JESSICA_SHIELD_DATA,1,"true")
	check(u.sp==1,"Shield actual positive damage grants ownerSP on successful talent proc")
	u.silence_ticks_left=10;s._apply_damage(sh,s.JESSICA_SHIELD_DATA,1,"true")
	check(u.sp==1,"Owner silence suppresses shieldSP talent")
	u.silence_ticks_left=0;cast(s,u)
	s._apply_damage(sh,s.JESSICA_SHIELD_DATA,1,"true")
	check(u.sp==0,"Shield damage does not charge active Jessica skill")
	talent.effect_params.chance_percent=old_chance
	var m := fixture("muelsyse",1)
	var owner := deploy(m,"muelsyse",Vector2i(13,2))
	var flow := deploy(m,"flowing_shape",Vector2i(13,3))
	copy_card(m,flow,"exusiai")
	var target := enemy(m,Vector2i(14,3))
	cast(m,owner)
	flow.attack_ticks_left=1
	var before := target.hp
	m.step([],[])
	var two_hits := before-target.hp
	owner.skill_ticks_left=0;AuraRules.refresh(m)
	flow.attack_ticks_left=1;before=target.hp;m.step([],[])
	check(two_hits>before-target.hp and flow.flow_attack_count==2,"RangedS2 fires two hits but advances split counter once per attack action")
	open_copy(m,flow)
	flow.skill_ticks_left=1;m.step([],[])
	check(not TacticianRules.can_copy(m,0,flow.unit_id,"silverash"),"Expired20sec copy window rejects card")

func check_melee_interaction() -> void:
	var s := fixture("muelsyse",2)
	var u := deploy(s,"muelsyse",Vector2i(13,2))
	var f := deploy(s,"flowing_shape",Vector2i(13,3))
	copy_card(s,f,"silverash")
	var target := enemy(s,Vector2i(14,3))
	cast(s,u)
	check(target.stun_ticks_left==2,"MeleeS3 applies continuous stun to actually blocked target")
	for tick in 10:s.step([],[]);check(target.stun_ticks_left==2,"MeleeS3 maintains stun while blocked")
	u.skill_ticks_left=0;AuraRules.refresh(s)
	for tick in 3:s.step([],[])
	check(target.stun_ticks_left==0,"MeleeS3 releases its maintained stun when skill ends")
