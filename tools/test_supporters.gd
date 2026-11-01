extends SceneTree

var failures := 0
var data := {"gnosis":load("res://resources/operators/gnosis.tres"),"silence_alter":load("res://resources/operators/silence_alter.tres"),"lumen":load("res://resources/operators/lumen.tres"),"silverash":load("res://resources/operators/silverash.tres")}


func _initialize() -> void:
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.attack=100;dummy.defense=0;dummy.magic_resist=25;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	for id in ["gnosis","silence_alter"]:check(data[id].validation_error().is_empty(),id+" strict original data "+data[id].validation_error())
	check(MatchState.SILENCE_DRONE_DATA.validation_error().is_empty(),"Drone strict schema")
	var state := fixture("gnosis",0);var source := state.units[0];var target := add(state,1,"target",Vector2i(12,3));source.sp=4;source.attack_ticks_left=0
	state.step([],[])
	check(target.frozen_ticks_left==30 and target.cold_ticks_left==0 and source.sp==0 and source.skill_ticks_left==0,"S1 actual automatic double hit freezes and spends4SP")
	check(target.hp==100000-145-209,"First cold hit25%fragile, second frozen hit50% and RES15 reduction")
	check(SkillRules.block_count_value(target,dummy)==0 and SkillRules.magic_resist_value(target,dummy)==10,"Frozen has block0 and RES-15")
	target.sp=99;target.attack_ticks_left=0
	check(not SkillRules.can_activate(target,dummy.skills[0]) and not StatusRules.advance_basic_attack(target),"Frozen forbids new skill and ordinary attack")
	target.frozen_ticks_left=0;target.cold_ticks_left=30
	check(SkillRules.attack_interval_ticks(target,dummy)==43,"Cold AS-30 retains other clocks")
	var before := state.state_hash();target.cold_ticks_left+=1;check(before!=state.state_hash(),"Cold included in hash")
	before=state.state_hash();target.frozen_ticks_left+=1;check(before!=state.state_hash(),"Frozen included in hash")
	LumenRules.clear_controls(state,target)
	check(target.cold_ticks_left==0 and target.frozen_ticks_left==0,"Lumen explicitly clears cold and frozen")
	var second := fixture("gnosis",1);source=second.units[0];target=add(second,1,"target",Vector2i(12,3));source.sp=12;cast(second)
	check(target.frozen_ticks_left==120 and source.sp==0 and source.skill_ticks_left==0 and target.hp==100000-246,"S2 charged actual all-target freeze4s and200% magic")
	var uncharged := fixture("gnosis",1);source=uncharged.units[0];target=add(uncharged,1,"target",Vector2i(12,3));source.sp=6;cast(uncharged)
	check(target.cold_ticks_left==120 and target.frozen_ticks_left==0,"S2 normal produces one cold layer")
	var third := fixture("gnosis",2);source=third.units[0];target=add(third,1,"target",Vector2i(12,3));source.sp=40;cast(third)
	check(source.skill_ticks_left==389 and SkillRules.attack_interval_ticks(source,data.gnosis)==21,"S3 actual40SP13s and AS+130")
	StatusRules.add_control(third,target,"cold",30,source);StatusRules.add_control(third,target,"cold",30,source)
	check(target.frozen_ticks_left==389,"S3 new frozen immediately extends to remaining duration")
	var next := add(third,1,"target",Vector2i(13,3));next.cold_ticks_left=0;source.attack_ticks_left=0;third.step([],[])
	check(next.cold_ticks_left>0,"S3 two targets and unfrozen priority")
	target.frozen_ticks_left=20;source.skill_ticks_left=1;source.attack_ticks_left=100000;var hp := target.hp;third.step([],[])
	check(target.frozen_ticks_left==0 and target.hp==hp-737 and source.skill_ticks_left==0,"S3 final600% magic then clear freeze")
	var group := fixture("gnosis",0);source=group.units[0];var kjerag := add(group,0,"silverash",Vector2i(12,3));group.tick=source.deployed_tick+299
	check(not StatusRules.has_resistance(group,kjerag),"Kjerag resistance has exact10s warmup")
	group.tick+=1;check(StatusRules.has_resistance(group,kjerag),"Existing Kjerag group receives resistance")
	var normal := fixture("silence_alter",0);source=normal.units[0];var ally := add(normal,0,"target",Vector2i(12,3));ally.hp=100000
	check(SilenceAlterRules.protection(normal,ally)==10,"Full HP receives10% protection")
	ally.hp=30000;check(SilenceAlterRules.protection(normal,ally)==24,"30% HP receives24% protection")
	ally.hp=65000;check(SilenceAlterRules.protection(normal,ally)==17,"Protection interpolates from10 to24%")
	source.sp=30;source.attack_ticks_left=0;var oldhp := ally.hp;cast(normal)
	check(SkillRules.attack_value(source,data.silence_alter)==841 and ally.hp==oldhp+315 and source.last_attack_is_heal,"S1 actual +80% ATK and75% healing with common50% scaling")
	var drone := fixture("silence_alter",1);source=drone.units[0];source.sp=24;cast(drone)
	check(SilenceAlterRules.drone_available(drone,0) and source.silence_drone_stock==1 and SkillRules.attack_interval_ticks(source,data.silence_alter)==30,"S2 grants one drone card and60AS")
	var cost := drone.sides[0].cost;drone.step([InputCommand.new(drone.tick,0,"silence_alter_drone",-1,Vector2i(12,3),-1,0)],[])
	check(drone.units.size()==2 and drone.units[1].silence_drone_owner_id==source.unit_id and drone.sides[0].cost==cost,"Actual drone legal deployment spends0 and binds owner")
	check(not SilenceAlterRules.drone_available(drone,0) and not drone.enemy_is_targetable(1,drone.units[1]),"Drone is unique and invulnerable")
	ally=add(drone,0,"target",Vector2i(12,4));ally.hp=30000
	check(SilenceAlterRules.protection(drone,ally)==72,"Drone protection uses3x owner talent and its own cross range")
	source.skill_ticks_left=1;drone.step([],[]);check(drone.units.size()==2 and drone.units[1]==ally,"Skill expiry removes bound drone")
	var protocol := fixture("silence_alter",2);source=protocol.units[0];ally=add(protocol,0,"target",Vector2i(12,3));ally.hp=10;source.sp=30;cast(protocol)
	check(protocol.sides[0].silence_protocol_uses==1 and source.skill_ticks_left==1799,"S3 actual cast records persistent use")
	protocol._apply_damage(ally,dummy,10000,"true")
	check(ally.hp==1 and ally.silence_grave_until_tick==protocol.tick+300 and source.silence_grave_used,"S3 one ally lethal hit grants10s HP1 floor")
	protocol._apply_damage(ally,dummy,10000,"true");check(ally.hp==1,"Independent grave survives subsequent true hits")
	cast(protocol);check(source.skill_ticks_left==0,"S3 can be stopped manually without SP")
	protocol._apply_damage(ally,dummy,10000,"true");check(ally.hp==1,"Released10s protection continues after manual stop")
	ally.silence_grave_until_tick=protocol.tick;protocol._apply_damage(ally,dummy,10000,"true");check(ally.hp<=0,"HP floor expires at exact deadline")
	source.sp=30;cast(protocol);cast(protocol);source.sp=30;cast(protocol)
	check(protocol.sides[0].silence_protocol_uses==2 and source.skill_ticks_left==0 and source.sp==30,"Third cast rejected and SP preserved")
	for id in ["gnosis","silence_alter"]:
		for index in 3:
			var a := fixture(id,index);var b := fixture(id,index)
			for s in [a,b]:add(s,1,"target",Vector2i(12,3));s.units[0].sp=SkillRules.sp_limit(data[id].skills[index]);s.units[0].attack_ticks_left=0
			for tick in 500:
				var commands: Array[InputCommand]=[]
				if tick==0 and data[id].skills[index].trigger_type=="manual":commands.append(InputCommand.new(a.tick,1,"",0,Vector2i.ZERO,index))
				a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Replay %s.S%d tick%d"%[id,index+1,tick])
	print("SUPPORTERS_OK all6skills,cold/frozen,Lumen,Kjerag,protection,drone,grave,usecaps,6x500tick replay; failures=",failures)
	quit(0 if failures==0 else 1)


func fixture(id: String, index: int) -> MatchState:
	var state := MatchState.new(731,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[[id],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,id,-1,Vector2i(12,2),-1,0)],[])
	check(state.units.size()==1 and state.units[0].operator_id==id,"Actual legal high deployment "+id)
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=100000;return state


func add(state: MatchState, side: int, id: String, cell: Vector2i) -> UnitState:
	var target := UnitState.new(state.next_unit_id,side,id,cell,data[id].max_health,0,100000,0)
	state.next_unit_id+=1;state.units.append(target);return target


func cast(state: MatchState) -> void:
	state.step([InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)],[])


func check(ok: bool, label: String) -> void:
	if not ok:failures+=1;push_error(label)
