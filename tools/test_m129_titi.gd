extends "res://tools/test_m129_guard_specialists.gd"

func _initialize() -> void:
	data.titi=load("res://resources/operators/titi.tres")
	for id in ["bagpipe","carnelian","passenger","pozyomka","perfumer","pallas","lumen"]:data[id]=load("res://resources/operators/"+id+".tres")
	var dummy: OperatorData=data.bagpipe.duplicate(true);dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.profession_id="caster";dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	check(data.titi.validation_error().is_empty(),"Titi strict schema "+data.titi.validation_error())
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "basic"
	if mode=="basic":basic()
	elif mode=="s2":sanctuary()
	elif mode=="s3":bloom()
	elif mode=="edges":titi_edges()
	elif mode=="replay":replay("titi",3,900)
	print("M129_TITI_OK ",mode," failures=",failures);quit(0 if failures==0 else 1)

func fixture(id: String,index: int) -> MatchState:
	var state := MatchState.new(129,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[[id],["target"]],[[index],[0]])
	state.sides[0].cost=99;state.step([InputCommand.new(0,0,id,-1,Vector2i(14,4),-1,2)],[])
	check(state.units.size()==1 and state.units[0].operator_id==id,"Titi actual legal high terrain deployment")
	state.ball.cell=Vector2i(5,5);state.units[0].attack_ticks_left=100000;return state

func ally(state: MatchState,id: String,cell: Vector2i) -> UnitState:
	var op: OperatorData=data[id];var unit := UnitState.new(state.next_unit_id,0,id,cell,op.max_health,0,100000);state.next_unit_id+=1;state.units.append(unit);return unit

func basic() -> void:
	var state := fixture("titi",0);var source := state.units[0];var target := enemy(state,Vector2i(13,4));source.hp=1000;source.attack_ticks_left=0
	state.step([],[])
	check(target.hp==99811,"Titi base magic164 plus nonmovingextra25 at30percentmedic coefficient: %d"%target.hp)
	check(source.hp==1047,"Incantation heals50percent of actualdamage, then shared50percenthealing once: %d"%source.hp)
	source.attack_ticks_left=100000;target.sleep_ticks_left=60;target.cell=Vector2i(3,3);source.titi_dot_next_tick=state.tick
	var before := target.hp;state.step([],[]);check(target.hp==before-49,"Sleeping target takes global30%ATKdot outside range with no attack event")
	check(state.can_attack_sleeping(source),"Titi can select sleeping ordinaryenemy")
	StatusRules.apply_silence(state,source,60);before=target.hp;source.titi_dot_next_tick=state.tick;state.step([],[]);check(target.hp==before and not state.can_attack_sleeping(source),"Silence disables both sleepattack and globalDOTtalent")
	state=fixture("titi",0);source=state.units[0];source.sp=40;source.attack_ticks_left=0;target=enemy(state,Vector2i(13,4));cast(state)
	check(SkillRules.attack_value(source,data.titi)==1096 and source.skill_ticks_left==509,"S1 exact40SP17sec+100ATK")
	for tick in 40:
		source.attack_ticks_left=0;state.step([],[])
	check(target.sleep_ticks_left>0,"S1 actual50%RNGsleep3seconds occurs over deterministicseed")
	state=fixture("titi",0);source=state.units[0]
	for id in ["carnelian","passenger","pozyomka","perfumer","pallas"]:
		var unit := ally(state,id,Vector2i(15,4));AuraRules.refresh(state);check(unit.attack_speed_bonus>=20,id+" verified originalvisible/hiddenMinosSargongroup receivesvigor")
	var normal := ally(state,"bagpipe",Vector2i(15,5));AuraRules.refresh(state);check(normal.attack_speed_bonus==0,"Unrelatedfactionexcluded")
	source.hp=702;AuraRules.refresh(state);check(source.attack_speed_bonus==0,"HP below50% removesvigor");source.hp=703;AuraRules.refresh(state);check(source.attack_speed_bonus==20,"HP strictlyover50% grants20AS")

func sanctuary() -> void:
	var state := fixture("titi",1);var source := state.units[0];var friend := ally(state,"bagpipe",Vector2i(13,4));friend.hp=100;var target := enemy(state,Vector2i(12,4));source.sp=20;cast(state)
	check(source.titi_doze_mode==2 and friend.titi_doze_mode==2 and source.skill_ticks_left==449,"S2 actual20SP15sec and self+lowestHPratio doze")
	check(target.sleep_ticks_left>0 and source.last_attack_tick<0,"S2 anchor1.5radius sleep and no ordinaryattack")
	check(SkillRules.block_count_value(friend,data.bagpipe)==0 and not state.enemy_is_targetable(1,friend),"Small sleep is zero block and untargetable")
	var before := friend.hp;state._apply_damage(friend,data.bagpipe,999999,"true",target,false);check(friend.hp==before,"Small sleep blocks incoming true damage")
	StatusRules.add_control(state,friend,"stun",90);StatusRules.apply_silence(state,friend,90);check(friend.stun_ticks_left==0 and friend.silence_ticks_left==0,"Small sleep immunizes control and silence")
	LumenRules.clear_controls(state,friend);check(friend.titi_doze_owner_id<0,"Lumen can cleanse friendly smallsleep")
	for tick in 3:state.step([],[])
	check(target.sleep_ticks_left>0,"Cleansing smallsleep does not cancel existinganchor aura")
	source.titi_dot_next_tick=state.tick;before=target.hp;state.step([],[]);check(target.hp==before-456,"S2 global30percentDOTx3.3 with180percentATK: loss%d"%(before-target.hp))
	cast(state);check(source.skill_ticks_left==0 and source.titi_doze_owner_id<0 and friend.titi_doze_owner_id<0 and source.titi_sanctuary_target_id==-1,"Owner may manuallycloseS2 whiledozed; allowneddozeandanchorsclear")

func bloom() -> void:
	var state := fixture("titi",2);var source := state.units[0];source.sp=37;source.attack_ticks_left=0;var first := enemy(state,Vector2i(13,4));var second := enemy(state,Vector2i(12,4));cast(state)
	check(source.skill_ticks_left==749 and first.sleep_ticks_left==150 and second.sleep_ticks_left==150,"S3 actual37SP25sec: twoordinaryPvPenemies hitthenputtosleep5sec")
	check(source.titi_sleep_ids.size()==2,"S3 tracks futureaffecting sleep duration for both targets")
	first.sleep_ticks_left=0;source.titi_sleep_elapsed[source.titi_sleep_ids.find(first.unit_id)]=150;source.attack_ticks_left=100000;source.titi_dot_next_tick=100000;var before := first.hp;state.step([],[])
	check(first.hp==before-2117 and second.sleep_ticks_left==150,"Max5sec awakeexplosion460percentcurrentATK and5sec sleeptransfer: loss%d sleep%d"%[before-first.hp,second.sleep_ticks_left])
	var friend := ally(state,"bagpipe",Vector2i(13,4));friend.hp=100;state._apply_damage(friend,data.bagpipe,1000,"true",first,false)
	check(friend.hp==1 and friend.titi_doze_mode==3,"Fatalordinaryallydamageclamps1HP and separatefriendlydoze")
	check(not SkillRules.can_manually_activate(friend,data.bagpipe.skills[0]),"Protecteddozedally cannotstartskill")
	LumenRules.treat_amount(state,friend,999999,source);check(friend.hp==data.bagpipe.max_health and friend.titi_doze_owner_id<0,"S3 fullhealing immediatelywakes")
	friend.hp=100;state._apply_damage(friend,data.bagpipe,1000,"true",first,false);check(friend.hp==1 and friend.titi_doze_mode==3,"Protectioncantriggeragain afterwaking")
	source.skill_ticks_left=1;state.step([],[]);check(friend.titi_doze_owner_id<0 and source.titi_sleep_ids.is_empty(),"S3 naturalend clearsdoze andsleepmarks")

func titi_edges() -> void:
	var state := fixture("titi",2);var source := state.units[0];source.sp=37;cast(state);var target := enemy(state,Vector2i(12,4));var next := enemy(state,Vector2i(11,4));target.sleep_ticks_left=150;TitiRules.note_sleep(source,target);target.hp=0
	var before := next.hp;TitiRules.on_death(state,target);check(next.hp==before and next.sleep_ticks_left==150 and source.titi_sleep_ids.is_empty(),"Sleepdeath transfers sleep without explodingdamage")
	var friend := ally(state,"bagpipe",Vector2i(13,4));friend.hp=1;state._apply_skill_life_loss(friend,data.bagpipe,1);check(friend.hp==1 and friend.titi_doze_mode==3,"S3 protectionalsohandles lethalindependentLifeloss")
	state.step([InputCommand.new(state.tick,2,"",source.unit_id)],[]);check(friend.titi_doze_owner_id<0 and source.titi_sleep_ids.is_empty(),"Source retreat clears allowned state")
