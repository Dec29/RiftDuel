extends SceneTree
var failures := 0
var data := {}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for id in ["texas","lappland","ptilopsis","gravel"]:
		data[id]=load("res://resources/operators/%s.tres"%id)
		check(data[id].validation_error().is_empty() and data[id].skills.size()==2 and data[id].talent_2.effect_type=="none","Actual2skills/1talent "+id)
	var actor: OperatorData=load("res://resources/operators/bagpipe.tres");actor=actor.duplicate(true);actor.operator_id="fixture";actor.max_health=100000;actor.attack=0;actor.defense=0;actor.magic_resist=0;actor.talent_1.effect_type="none";actor.talent_2.effect_type="none";data.fixture=actor
	var init := MatchState.new(10,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[PackedStringArray(["texas"]),PackedStringArray(["gravel"])])
	check(init.sides[0].cost==12 and init.sides[1].cost==10,"Texas gives exactly2 initial DP to own squad before deployment")
	var cost := fixture("texas",0);cost.sides[0].cost=0;cost.units[0].sp=35;cost.step([],[])
	check(cost.sides[0].cost==12 and cost.units[0].skill_activation_count==1 and cost.units[0].sp==0,"TexasS1 automatic12DP")
	var rain := fixture("texas",1);var enemy := add(rain,"fixture",1,Vector2i(12,5),100000);var enemy2 := add(rain,"fixture",1,Vector2i(14,5),100000)
	rain.tactical_boxes.append(TacticalBox.new(0,Vector2i(13,4),3));rain.tactical_boxes.append(TacticalBox.new(1,Vector2i(14,4),3));rain.ball.cell=Vector2i(12,6);rain.sides[0].cost=0;rain.units[0].sp=40;rain.step([cast(rain)],[])
	check(enemy.hp==99574 and enemy2.hp==99574 and enemy.stun_ticks_left==90 and enemy2.stun_ticks_left==90,"Sword rain two213 magic hits to every enemy in same tick")
	check(rain.tactical_boxes[0].hits_left==1 and rain.tactical_boxes[1].hits_left==1 and rain.ball.accum==Vector2i(-1700,1700) and rain.sides[0].cost==12,"AOE simultaneously hits all boxes and ball even with enemies present")
	check(rain.units[0].texas_cast_tick==1 and rain.units[0].skill_activation_count==1,"Single actual visual event for entire AOE")
	var empty := fixture("texas",1);empty.units[0].sp=40;empty.sides[0].cost=0;empty.step([cast(empty)],[])
	check(empty.sides[0].cost==12 and empty.units[0].sp==0,"Empty-area manual skill still grants12DP")
	var lap := fixture("lappland",0);var victim := add(lap,"fixture",1,Vector2i(12,5),100000);lap.units[0].attack_ticks_left=0;lap.step([],[])
	check(victim.hp==99781 and victim.silence_ticks_left==150 and lap.units[0].sp==1,"Lappland80percent physical attack,5second silence and offensive SP")
	lap.units[0].sp=30;lap.step([],[])
	check(lap.units[0].skill_ticks_left==-2 and SkillRules.attack_value(lap.units[0],data.lappland)==1165,"Sundial infinite70percentATK")
	var blocked := 0
	for hit in 60:
		var hp := lap.units[0].hp
		if not lap._apply_damage(lap.units[0],data.lappland,1,"physical"):blocked+=1
		check(lap.units[0].hp in [hp,hp-1],"Physical block either whole hit or1HP")
	check(blocked>0 and blocked<60,"Sundial physical40percent block uses simulation RNG")
	var wolves := fixture("lappland",1);var first := add(wolves,"fixture",1,Vector2i(12,5),100000);var second := add(wolves,"fixture",1,Vector2i(11,5),100000);wolves.units[0].sp=17;wolves.units[0].attack_ticks_left=0;wolves.step([],[])
	check(first.hp==99397 and second.hp==99397 and first.silence_ticks_left==150 and second.silence_ticks_left==150,"Wolf Soul2targets603magic, no80percent penalty, both silenced")
	check(wolves.units[0].sp==0 and SkillRules.damage_type(wolves.units[0],data.lappland)=="magical","No offensiveSP while Wolf Soul active")
	var healer := fixture("ptilopsis",0);var patients: Array[UnitState]=[]
	for i in 4:patients.append(add(healer,"fixture",0,[Vector2i(12,1),Vector2i(12,2),Vector2i(13,1),Vector2i(13,3)][i],1000*(i+1)))
	healer.units[0].sp=30;healer.units[0].attack_ticks_left=0;healer.step([cast(healer)],[])
	check(patients[0].hp==1319 and patients[1].hp==2319 and patients[2].hp==3319 and patients[3].hp==4000,"PtilopsisS1 heals3 lowest HP-ratio targets319 each")
	var fast := fixture("ptilopsis",1);fast.units[0].sp=100;fast.step([cast(fast)],[])
	check(SkillRules.attack_interval_ticks(fast.units[0],data.ptilopsis)==23 and AttackRange.effective_offsets(fast.units[0],data.ptilopsis).size()>data.ptilopsis.attack_range.size(),"Enkephalin0.75second base interval and original expanded range")
	var sp := fixture("ptilopsis",0);sp.units[0].sp=0;sp.units[0].sp_regen_accum=0;sp.units[0].sp_regen_ticks=0;var on_hit := add(sp,"lappland",0,Vector2i(12,5),2350)
	for tick in 300:sp.step([],[])
	check(sp.units[0].sp==13 and on_hit.sp==0,"Global30percent naturalSP affects self but not offensiveSP")
	StatusRules.apply_silence(sp,sp.units[0],30);check(sp.units[0].sp_recharge_bonus_percent==0,"GlobalSP aura is suppressed by source silence")
	var defense := fixture("gravel",0)
	check(DeployRules.base_cost(data.gravel)==7 and defense.units[0].gravel_ticks_left==360 and SkillRules.defense_value(defense.units[0],data.gravel)==1695,"Gravel7DP and initial400percentDEF plus6percent own aura")
	for tick in 180:defense.step([],[])
	check(SkillRules.defense_value(defense.units[0],data.gravel)==1025,"Defense boost linearly decays to200percent at6seconds")
	StatusRules.apply_silence(defense,defense.units[0],1);check(SkillRules.defense_value(defense.units[0],data.gravel)==335,"Silence pauses defense boost and own6percent aura")
	var shield := fixture("gravel",1)
	check(shield.units[0].gravel_barrier_hp==3550,"S2 snapshot250percent maximumHP all-damage barrier")
	check(not shield._apply_damage(shield.units[0],data.gravel,1000,"true") and shield.units[0].hp==1420 and shield.units[0].gravel_barrier_hp==2550,"Barrier absorbs true damage before HP")
	for tick in 150:shield.step([],[])
	check(shield.units[0].gravel_barrier_hp==775,"Shield loses exactly half initial capacity after5seconds in addition to damage")
	shield._apply_damage(shield.units[0],data.gravel,800,"magical");check(shield.units[0].hp==1395 and shield.units[0].gravel_barrier_hp==0,"Barrier overflow reachesHP exactly once")
	shield._retreat_unit(shield.units[0]);check(shield.sides[0].cooldowns.gravel==540,"Gravel18second redeployment cooldown")
	for id in ["texas","lappland","ptilopsis","gravel"]:
		for index in 2:
			var a := fixture(id,index);var b := fixture(id,index)
			for state in [a,b]:
				state.units[0].sp=SkillRules.sp_limit(data[id].skills[index]);state.ball.cell=Vector2i(12,5);state.units[0].attack_ticks_left=0
			for tick in 480:
				var cmds: Array[InputCommand]=[]
				if tick==0 and not SkillRules.is_auto_trigger(data[id].skills[index]) and data[id].skills[index].trigger_type!="passive":cmds.append(cast(a))
				a.step(cmds,[]);b.step(cmds,[]);check(a.state_hash()==b.state_hash(),"8loadouts480tick deterministic replay")
	print("TEXAS_FOUR_CORE_OK" if failures==0 else "TEXAS_FOUR_FAILED %d"%failures);quit(0 if failures==0 else 1)
func fixture(id: String,index: int) -> MatchState:
	var ids := PackedStringArray([id]);var skills := PackedInt32Array([index]);var state := MatchState.new(14,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills]);state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=1000000000
	state.step([InputCommand.new(0,0,id,-1,Vector2i(13,2 if id=="ptilopsis" else 5),-1,2)],[]);state.units[0].attack_ticks_left=100000;return state
func add(state: MatchState,id: String,side: int,cell: Vector2i,hp: int) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,side,id,cell,hp,0,100000,2 if side==0 else 0);state.next_unit_id+=1;state.units.append(unit);return unit
func cast(state: MatchState) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
