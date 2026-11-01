extends SceneTree
const IDS := ["flametail","elysium","mountain","surtr","mudrock","gummy","rosa","jessica","passenger","haze","warfarin","sussurro","shamare","podenco","mizuki","feater"]
var data := {}
var failures := 0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var focus := "surtr" if "--surtr" in OS.get_cmdline_user_args() else ("jessica" if "--jessica" in OS.get_cmdline_user_args() else "")
	for id in IDS:
		if not focus.is_empty() and id!=focus:continue
		data[id]=load("res://resources/operators/"+id+".tres")
		check(data[id].validation_error().is_empty(),id+" exact resource valid")
	var dummy: OperatorData=load("res://resources/operators/bagpipe.tres").duplicate(true)
	dummy.operator_id="fixture";dummy.max_health=100000;dummy.attack=0;dummy.defense=0;dummy.magic_resist=0;dummy.initial_deploy_cost=1;dummy.talent_1.effect_type="none";dummy.talent_2.effect_type="none";data.fixture=dummy
	if not focus.is_empty():
		for index in data[focus].skills.size():
			var a:=fixture(focus,index);var b:=fixture(focus,index)
			for tick in 240:
				var commands: Array[InputCommand]=[]
				if tick==0 and data[focus].skills[index].trigger_type=="manual":commands.append(cast(a))
				a.step(commands,[]);b.step(commands,[])
				check(a.state_hash()==b.state_hash(),focus+" replay S%d tick%d"%[index+1,tick])
			check(a.units[0].skill_activation_count>0,focus+" actual S%d activation"%[index+1])
		if focus=="surtr":surtr_fatal()
		else:
			var actual:=fixture("jessica",1);actual.step([cast(actual)],[])
			check(SkillRules.attack_value(actual.units[0],data.jessica)==855 and SkillRules.dodge_chance(actual.units[0],data.jessica,"physical")==75 and SkillRules.dodge_chance(actual.units[0],data.jessica,"magical")==75,"Jessica S2 attack80/both dodge75")
		print("FOCUSED_OPERATOR_OK: ",focus," skills=",data[focus].skills.size()," replay ticks=",data[focus].skills.size()*240," failures=",failures)
		quit(0 if failures==0 else 1);return
	if "--final-edges" in OS.get_cmdline_user_args():
		final_edges();print("TWO_GROUPS_FINAL_EDGES failures=",failures);quit(0 if failures==0 else 1);return
	var checked := 0
	for id in IDS:
		for index in data[id].skills.size():
			checked+=1
			var a := fixture(id,index);var b := fixture(id,index)
			var skill: SkillResource=data[id].skills[index]
			for tick in 240:
				var commands: Array[InputCommand]=[]
				if tick==0 and skill.trigger_type=="manual":commands.append(cast(a))
				a.step(commands,[]);b.step(commands,[])
				check(a.state_hash()==b.state_hash(),id+"S%d deterministic tick%d"%[index+1,tick])
				if tick==0:check(a.units[0].skill_activation_count==(0 if id in AttackTimeline.IDS and skill.trigger_type=="attack" else 1),id+"S%d activation phase"%(index+1))
	check(checked==39,"39 actual skills, no fabricated third skills")
	var j := fixture("jessica",1);j.step([cast(j)],[])
	check(SkillRules.attack_value(j.units[0],data.jessica)==855 and SkillRules.dodge_chance(j.units[0],data.jessica,"physical")==75 and SkillRules.dodge_chance(j.units[0],data.jessica,"magical")==75,"JessicaS2 attack80 and both dodge75")
	var h := fixture("haze",1);h.step([cast(h)],[])
	check(SkillRules.max_health_value(h.units[0],data.haze)==355 and SkillRules.attack_value(h.units[0],data.haze)==933 and SkillRules.attack_interval_ticks(h.units[0],data.haze)==30,"Haze HP-75 ATK60 AS60")
	check(h.units[1].resist_remaining_percent==80,"Haze landed hit shared resist debuff")
	var su := fixture("sussurro",1);su.step([cast(su)],[]);var source := su.units[0]
	check(source.limited_skill_uses==1 and su.sides[0].sussurro_skill_uses==1,"Sussurro first whole-match use")
	source.skill_ticks_left=0;source.sp=15;su.step([cast(su)],[]);source.skill_ticks_left=0;source.sp=15
	check(not SkillRules.can_activate(source,data.sussurro.skills[1]),"Sussurro two-use limit")
	su._retreat_unit(source);su.sides[0].cooldowns.clear();su.sides[0].cost=99
	su.step([InputCommand.new(su.tick,0,"sussurro",-1,Vector2i(13,2),-1,2)],[])
	for unit in su.units:
		if unit.operator_id=="sussurro":check(unit.limited_skill_uses==2,"Sussurro redeploy does not reset usage")
	var mountain := fixture("mountain",1);mountain.step([cast(mountain)],[])
	check(SkillRules.attack_value(mountain.units[0],data.mountain)==1057 and SkillRules.block_count_value(mountain.units[0],data.mountain)==2 and SkillRules.defense_value(mountain.units[0],data.mountain)==321,"Mountain stance attack80 defense-20 plus talent10 block2")
	mountain.units[0].sp=5;mountain.step([cast(mountain)],[]);check(mountain.units[0].skill_ticks_left==0,"Mountain stance switches off")
	surtr_fatal()
	var mud := fixture("mudrock",0);source=mud.units[0];source.nian_shield_layers=1;source.hp=1000
	mud._apply_damage(source,data.mudrock,1000000,"true",mud.units[1]);check(source.hp==1393 and source.nian_shield_layers==0,"Mudrock shield blocks whole event and restores10percent after healing coefficient")
	for tick in 270:mud.step([],[])
	check(source.nian_shield_layers==1,"Mudrock regenerates shield after9seconds")
	check(SkillRules.healing_received(source,data.mudrock,1000,mud.units[4])==0,"Mudrock rejects external direct healing")
	var rest := fixture("mudrock",2);rest.step([cast(rest)],[]);source=rest.units[0]
	check(ClassicTacticalRules.is_resting(source,data.mudrock) and SkillRules.block_count_value(source,data.mudrock)==0 and not rest.enemy_is_targetable(1,source),"Mudrock initial rest invulnerable untargetable block0")
	var hp := source.hp;rest._apply_damage(source,data.mudrock,10000,"true",rest.units[1]);check(source.hp==hp,"Rest blocks damage")
	for tick in 300:rest.step([],[])
	check(not ClassicTacticalRules.is_resting(source,data.mudrock) and SkillRules.attack_value(source,data.mudrock)==2117 and SkillRules.defense_value(source,data.mudrock)==1084,"Mudrock awakening after10seconds")
	var flame := fixture("flametail",0);source=flame.units[0];flame.step([],[])
	check(source.dodge_next_physical,"Flametail auto guarantees next physical dodge")
	LaunchOperatorRules.hit(flame,flame.units[1],data.fixture,source,1000,"physical");check(not source.dodge_next_physical and source.dodge_attack_ready,"Actual dodge consumes guarantee and arms counter")
	var el := fixture("elysium",1);el.step([cast(el)],[])
	check(DeployRules.actual_cost(data.jessica,el.sides[0])==10,"Elysium in-field sniper deployment discount2")
	check(el.units[1].attack_speed_remaining_percent==40 and el.units[1].recon_defense_remaining_percent==65,"Elysium locked recon debuffs")
	el.units[1].cell=Vector2i(2,2);AuraRules.refresh(el);check(el.units[1].attack_speed_remaining_percent==40,"Recon retains marked target outside original range")
	var rosa := fixture("rosa",2);rosa.step([cast(rosa)],[]);check(rosa.units[3].bind_ticks_left>0,"Rosa uses common bind")
	rosa.units[0].stun_ticks_left=5;rosa.step([],[]);check(rosa.units[0].skill_ticks_left==0 and rosa.units[3].bind_ticks_left==0 and rosa.units[3].bind_immunity_ticks_left>0,"Rosa stun breaks owned links with immunity")
	var chain := fixture("passenger",0);source=chain.units[0];source.sp=0;source.attack_ticks_left=0;chain.step([],[])
	check(chain.units[1].hp<100000 and chain.units[2].hp<100000 and chain.units[3].hp<100000,"Passenger successive adjacent chain targets")
	var storm := fixture("passenger",2);storm.step([cast(storm)],[]);check(storm.classic_attack_fields.size()==1 and storm.classic_attack_fields[0].offsets.size()==13,"Storm original x-1 diamond13cells")
	storm._retreat_unit(storm.units[0]);storm.step([],[]);check(storm.classic_attack_fields.is_empty(),"Passenger exit removes storm")
	var doll := fixture("shamare",1);source=doll.units[0];doll.step([],[]);check(source.curse_doll_stock==1 and not SkillRules.can_gain_sp(source),"Shamare auto stock and full-stock recharge stop")
	doll.step([InputCommand.new(doll.tick,0,"curse_doll",-1,Vector2i(12,4),-1,2)],[])
	var token: UnitState
	for unit in doll.units:
		if unit.operator_id=="curse_doll":token=unit
	check(token!=null and source.curse_doll_stock==0 and SkillRules.can_gain_sp(source),"Doll actual deploy consumes stock and resumes owner recharge")
	check(doll.units[1].curse_attack_remaining_percent==50 and doll.units[1].curse_defense_remaining_percent==50,"Doll local attack and defense reduction")
	if token!=null:
		hp=token.hp;doll._apply_damage(token,MatchState.CURSE_DOLL_DATA,100000,"true",doll.units[1]);check(token.hp==hp,"Doll immune to damage")
	doll._retreat_unit(source);check(token not in doll.units,"Doll removed immediately with owner")
	var cloud := fixture("podenco",1);cloud.step([cast(cloud)],[]);check(cloud.classic_attack_fields.size()==1 and cloud.units[1].silence_ticks_left>0,"Podenco cloud immediately suppresses abilities")
	cloud.units[0].bind_ticks_left=90
	var old_hp := cloud.units[1].hp
	for tick in 31:cloud.step([],[])
	check(cloud.units[1].hp<old_hp,"Independent cloud pulses while source bound")
	var dodge := fixture("flametail",2);dodge.step([cast(dodge)],[])
	check(SkillRules.dodge_chance(dodge.units[0],data.flametail,"physical")==84 and SkillRules.dodge_chance(dodge.units[0],data.flametail,"magical")==80,"Flametail skill and faction dodge combine independently, rounded84percent")
	var mizu := fixture("mizuki",0);mizu.step([],[])
	check(mizu.units[1].hp==99026 and mizu.units[2].hp==99351,"Mizuki charged physical300percent and lowest-health talent150percent")
	var blood := fixture("warfarin",1);blood.units[4].hp=100000;blood.units[0].hp=1520;ClassicOperatorRules.cast(blood,blood.units[0],data.warfarin)
	for tick in 450:
		blood.tick=tick
		StatusRules.expire_before_commands(blood,{})
		ClassicOperatorRules.regenerate(blood)
	check(blood.units[4].hp==55000,"Warfarin fifteen independent loss pulses in15seconds")
	var push := fixture("feater",1);push.units=push.units.slice(0,1);push.ball.cell=Vector2i(12,5);push._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);push._ball_data.kick_threshold=1000000000
	push.step([cast(push)],[])
	check(push.ball.accum.x<0 or push.ball.move_direction.x<0,"FEater burst ball push follows actual source facing")
	var heal := fixture("warfarin",0);heal.units[4].hp=1000;heal.units[0].sp=16;heal.units[0].attack_ticks_left=0;heal.step([],[])
	check(heal.units[4].hp==13753 and heal.units[0].sp==12,"Warfarin quarter max-health bonus precedes ordinary heal, consumes one charge without SP gain")
	print("TWO_GROUPS_OPERATORS:39 actual skill activations and9360 per-tick deterministic checks; focused talent/control/lifetime/stock contracts; failures=",failures)
	quit(0 if failures==0 else 1)
func fixture(id: String,index: int) -> MatchState:
	var state := MatchState.new(9871,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[PackedStringArray([id]),PackedStringArray(["fixture"])],[PackedInt32Array([index]),PackedInt32Array([0])])
	state.next_box_spawn_tick=100000;state.sides[0].cost=99
	var op: OperatorData=data[id]
	state.units.append(UnitState.new(0,0,id,Vector2i(13,5),op.max_health/2,SkillRules.sp_limit(op.skills[index]),0,2,index))
	for cell in [Vector2i(12,5),Vector2i(11,5),Vector2i(10,5)]:state.units.append(UnitState.new(state.units.size(),1,"fixture",cell,100000,0,100000,0))
	state.units.append(UnitState.new(4,0,"fixture",Vector2i(13,4),1000,0,100000,2));state.next_unit_id=5
	AuraRules.refresh(state)
	return state
func cast(state: MatchState) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)

func final_edges() -> void:
	var mountain := fixture("mountain",1);mountain.step([cast(mountain)],[])
	for tick in 149:mountain.step([],[])
	check(mountain.units[0].sp==5 and SkillRules.can_manually_activate(mountain.units[0],data.mountain.skills[1]),"Stance naturally restores five SP in5seconds")
	mountain.step([cast(mountain)],[]);check(mountain.units[0].skill_ticks_left==0,"Natural-SP stance off")
	var high := fixture("feater",0);high.units=high.units.slice(0,1);high.units[0].cell=Vector2i(13,2)
	high.units.append(UnitState.new(1,1,"fixture",Vector2i(13,3),100000,0,100000))
	check(data.feater.terrain_requirement=="both" and high.terrain_at(high.units[0].cell)=="high","FEater original high/ground deployment")
	check(not high.enemy_is_blocked(high.units[1],0),"High-platform pusher cannot qualify as a ground blocker")
	high.units[0].cell=Vector2i(13,5);high.units[1].cell=Vector2i(12,5)
	check(high.enemy_is_blocked(high.units[1],0),"Ground pusher uses shared adjacency blocking")
	var deploy := MatchState.new(1,data);deploy.sides[0].cost=99
	deploy.step([InputCommand.new(0,0,"feater",-1,Vector2i(13,2),-1,2)],[])
	check(deploy.units.size()==1 and deploy.units[0].operator_id=="feater","Actual high-platform FEater deployment command")
	var live := MatchState.new(1,data);live.sides[0].cost=99
	live.step([InputCommand.new(0,0,"elysium",-1,Vector2i(13,5),-1,2),InputCommand.new(0,0,"jessica",-1,Vector2i(13,2),-1,2)],[])
	check(live.sides[0].cost==78,"Elysium discount is immediate for next deployment in same ordered batch")
	live._retreat_unit(live.units[0]);check(DeployRules.actual_cost(data.jessica,live.sides[0])==12,"Retreat immediately removes Elysium live discount")
	var mizu := fixture("mizuki",0);mizu.units[1].hp=50001;mizu.units[0].attack_ticks_left=0
	mizu._apply_damage(mizu.units[1],data.fixture,2,"true",mizu.units[2]);mizu.step([],[])
	check(mizu.units[0].attack_bonus_percent==10,"Wounded-enemy talent samples current HP before the actual attack")


func surtr_fatal() -> void:
	var surtr := fixture("surtr",2);surtr.step([cast(surtr)],[]);var source:=surtr.units[0]
	check(SkillRules.max_health_value(source,data.surtr)==7916 and SkillRules.attack_value(source,data.surtr)==2890,"Surtr twilight flat5000 HP and330percent attack")
	surtr._apply_damage(source,data.surtr,1000000,"true",surtr.units[1]);check(source.hp==1 and source.fatal_until_tick==surtr.tick+240,"Surtr fatal delay8seconds")
	surtr._apply_damage(source,data.surtr,1000000,"true",surtr.units[1]);check(source.hp==1,"Surtr subsequent damage clamped")
	surtr.tick=source.fatal_until_tick;surtr.step([],[]);check(source.hp==0 and source not in surtr.units,"Surtr forced exit at deadline")
