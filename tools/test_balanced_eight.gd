extends SceneTree
var data := {}
var failures := 0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for id in LaunchOperatorRules.IDS:
		data[id]=load("res://resources/operators/%s.tres"%id)
		check(data[id].validation_error().is_empty(),"Valid original resource "+id)
	var actor: OperatorData=load("res://resources/operators/bagpipe.tres");actor=actor.duplicate(true);actor.operator_id="fixture";actor.max_health=100000;actor.attack=0;actor.defense=0;actor.magic_resist=0;actor.talent_1.effect_type="none";actor.talent_2.effect_type="none";data.fixture=actor
	var z := fixture("zima",0);check(DeployRules.actual_cost(data.zima,z.sides[0])==12,"Zima squad vanguard DP-1 before deployment")
	z.sides[0].cost=20;z.units[0].sp=35;z.step([],[]);check(z.sides[0].cost==32,"Zima S1 auto12DP")
	z._retreat_unit(z.units[0]);check(z.sides[0].cost==38,"Permanent vanguard DP reduction also yields6DP retreat refund")
	var war := fixture("zima",1);war.units[0].sp=35;war.sides[0].cost=20;war.step([cast(war)],[])
	check(SkillRules.attack_value(war.units[0],data.zima)==752 and SkillRules.defense_value(war.units[0],data.zima)==560,"Warcry vanguard attack/defense60percent")
	for tick in 299:war.step([],[])
	check(war.sides[0].cost==42,"10seconds12skillDP plus10naturalDP")
	var li := fixture("liskarm",0);li._apply_damage(li.units[0],data.liskarm,10,"physical");check(li.units[0].sp==3,"Liskarm ordinary受击+1, own talent+1, self random+1")
	check(SkillRules.magic_resist_value(li.units[0],data.liskarm)==10,"Liskarm MR talent10")
	li.units[0].sp=18;li.step([],[]);var before := li.units[0].hp
	check(li.units[0].liskarm_shield_ready and SkillRules.defense_value(li.units[0],data.liskarm)==1420,"Liskarm guard8seconds DEF100percent")
	li._apply_damage(li.units[0],data.liskarm,10000,"true");check(li.units[0].hp==before and not li.units[0].liskarm_shield_ready and li.units[0].sp==0,"Next whole damage blocked without SP")
	var dot_sp := fixture("liskarm",0);dot_sp._apply_damage(dot_sp.units[0],data.liskarm,10,"magical",null,false);check(dot_sp.units[0].sp==0,"Poison damage is not an attack and grants no受击SP")
	var arc := fixture("liskarm",1);arc.units[0].sp=34;arc.step([cast(arc)],[]);check(SkillRules.attack_value(arc.units[0],data.liskarm)==1275 and SkillRules.attack_interval_ticks(arc.units[0],data.liskarm)==61,"Arc ATK200percent and interval70percent longer")
	arc.units[0].skill_ticks_left=1;arc.step([],[]);check(arc.units[0].stun_ticks_left==150,"Arc expires into5second stun")
	var poison := fixture("blue_poison",0);var victim := add(poison,"fixture",1,Vector2i(12,2),100000);poison.units[0].attack_ticks_left=0;poison.step([],[])
	check(victim.hp==99866 and victim.poison_until_tick>0,"Blue normal shot134 and poison application")
	var first_pulse := victim.poison_next_tick
	for tick in 3:poison.tick=first_pulse+tick*30;LaunchOperatorRules.poison(poison)
	check(victim.hp==99809 and victim.poison_until_tick==0,"Three19magic poison pulses, no stacking")
	var double := fixture("blue_poison",0);var d1 := add(double,"fixture",1,Vector2i(12,2),100000);var d2 := add(double,"fixture",1,Vector2i(12,3),100000);double.units[0].sp=2;double.units[0].attack_ticks_left=0;double.step([],[])
	check(d1.hp==99732 and d2.hp==99732,"BlueS1 two distinct268hits")
	var venom := fixture("blue_poison",1);var v1 := add(venom,"fixture",1,Vector2i(12,2),100000);var v2 := add(venom,"fixture",1,Vector2i(12,3),100000);var v3 := add(venom,"fixture",1,Vector2i(11,2),100000);venom.units[0].sp=40;venom.units[0].attack_ticks_left=0;venom.step([cast(venom)],[])
	check(v1.hp==99598 and v2.hp==99799 and v3.hp==99799,"Venom primary two201hits, additional targets once")
	data.hoshiguma=load("res://resources/operators/hoshiguma.tres");var reflect := fixture("blue_poison",0);var attacker := reflect.units[0];attacker.hp=1;attacker.sp=2;attacker.attack_ticks_left=0;var thorns := add(reflect,"hoshiguma",1,Vector2i(12,2),100000);thorns.skill_index=1;var secondary := add(reflect,"fixture",1,Vector2i(12,3),100000);reflect.step([],[]);check(attacker.hp<=0 and secondary.hp==100000,"Reflected fatal hit stops remaining multi-target shots")
	var red := fixture("projekt_red",0);check(SkillRules.attack_value(red.units[0],data.projekt_red)==954 and SkillRules.dodge_chance(red.units[0],data.projekt_red,"magical")==50,"Red deployment ATK80 and both dodge50")
	var armor: OperatorData=actor.duplicate(true);armor.operator_id="armor";armor.defense=100000;red._operator_data.armor=armor;var tough := add(red,"armor",1,Vector2i(12,5),100000);LaunchOperatorRules.hit(red,red.units[0],data.projekt_red,tough,530,"physical");check(tough.hp==99960,"Red30percent floor then specialist25percent")
	var wolf := fixture("projekt_red",1,false);var foe := add(wolf,"fixture",1,Vector2i(12,5),100000);wolf.tactical_boxes.append(TacticalBox.new(0,Vector2i(14,5),3));wolf.ball.cell=Vector2i(13,6);wolf.step([InputCommand.new(0,0,"projekt_red",-1,Vector2i(13,5),-1,2)],[])
	check(foe.hp==99669 and foe.stun_ticks_left==90 and wolf.tactical_boxes[0].hits_left==2 and wolf.ball.accum==Vector2i(0,1325),"Red deploymentAOE enemy box ball simultaneous")
	var a := fixture("amiya",0);var av := add(a,"fixture",1,Vector2i(12,2),100000);a.units[0].sp=0;a.units[0].attack_ticks_left=0;a.step([],[]);check(a.units[0].sp==2,"Amiya basic extra2SP once")
	a.units[0].sp=30;a.step([cast(a)],[]);check(SkillRules.attack_interval_ticks(a.units[0],data.amiya)==25,"AmiyaS1 AS90")
	var burst := fixture("amiya",1);var bv := add(burst,"fixture",1,Vector2i(12,2),100000);burst.units[0].sp=100;burst.units[0].attack_ticks_left=0;burst.step([],[]);check(bv.hp==99120 and burst.units[0].sp==0,"Burst eight110magic shots no SP during skill")
	burst.units[0].skill_ticks_left=1;burst.step([],[]);check(burst.units[0].stun_ticks_left==300,"Burst end10second stun")
	var chimera := fixture("amiya",2);chimera.units[0].sp=120;chimera.sides[0].cost=20;chimera.step([cast(chimera)],[]);check(SkillRules.max_health_value(chimera.units[0],data.amiya)==2960 and SkillRules.attack_value(chimera.units[0],data.amiya)==2020,"Chimera ATK230 HP100percent")
	chimera.units[0].skill_ticks_left=1;chimera.step([],[]);check(chimera.units.is_empty() and chimera.sides[0].cost==20 and chimera.sides[0].cooldowns.amiya==2100,"Chimera forced retreat no refund and ordinary70seconds cooldown")
	var fire := fixture("skyfire",1);var fv := add(fire,"fixture",1,Vector2i(12,2),100000);var blocker := add(fire,"fixture",0,Vector2i(12,3),100000);check(fire.enemy_is_blocked(fv) and fire._magical_damage_taken_percent(fv)==115,"Approved adjacency blocking and global Arts15percent")
	blocker.stun_ticks_left=30;check(not fire.enemy_is_blocked(fv) and fire._magical_damage_taken_percent(fv)==100,"Stunned blocker disqualifies")
	blocker.stun_ticks_left=0;fire.units[0].sp=25;fire.units[0].attack_ticks_left=0;fire.step([cast(fire)],[]);check(fv.hp==99351 and fv.stun_ticks_left==30 and SkillRules.attack_interval_ticks(fire.units[0],data.skyfire)==148,"Meteor240percent AoE, Arts15percent,1second stun")
	var ist := fixture("istina",0);check(SkillRules.defense_value(ist.units[0],data.istina)==68 and SkillRules.attack_interval_ticks(ist.units[0],data.istina)==48,"Istina DEF-35 AS18")
	ist.units[0].sp=40;ist.step([cast(ist)],[]);check(SkillRules.attack_interval_ticks(ist.units[0],data.istina)==20,"Focus interval reduction before AS")
	var storm := fixture("istina",1);storm.units[0].sp=50;storm.step([cast(storm)],[]);check(SkillRules.attack_value(storm.units[0],data.istina)==907 and AttackRange.effective_offsets(storm.units[0],data.istina)==data.istina.skills[1].attack_range_override,"Literature storm ATK75 and exact range")
	var pr := fixture("pramanix",1);var weak := add(pr,"liskarm",1,Vector2i(12,2),1295);weak.max_health_bonus_percent=0;pr.units[0].sp=40;pr.step([cast(pr)],[])
	check(SkillRules.defense_value(weak,data.liskarm)==284 and SkillRules.magic_resist_value(weak,data.liskarm)==7,"Weaken DEF60 MR30percent and Liskarm MR10")
	check(pr._fragile_damage_percent(weak)==130,"LowHP strictly below40percent gives30fragile")
	var echo := fixture("pramanix",0);var slowed := add(echo,"fixture",1,Vector2i(12,2),100000);echo.units[0].sp=40;echo.step([cast(echo)],[]);check(slowed.attack_speed_bonus==-60,"Echo enemy AS-60 aura")
	for id in LaunchOperatorRules.IDS:
		for index in data[id].skills.size():
			var one := fixture(id,index);var two := fixture(id,index)
			for state in [one,two]:state.units[0].sp=SkillRules.sp_limit(data[id].skills[index]);state.units[0].attack_ticks_left=0;state.ball.cell=Vector2i(12,2 if data[id].terrain_requirement=="high" else 5)
			for tick in 480:
				var commands: Array[InputCommand]=[]
				if tick==0 and data[id].skills[index].trigger_type=="manual":commands.append(cast(one))
				one.step(commands,[]);two.step(commands,[]);check(one.state_hash()==two.state_hash(),"All17loadouts480tick deterministic replay")
	print("BALANCED_EIGHT_CORE_OK" if failures==0 else "BALANCED_EIGHT_FAILED%d"%failures);quit(0 if failures==0 else 1)
func fixture(id: String,index: int,deploy: bool=true) -> MatchState:
	var ids := PackedStringArray([id]);var indices := PackedInt32Array([index]);var state := MatchState.new(14,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[indices,indices]);state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=1000000000
	if deploy:state.step([InputCommand.new(0,0,id,-1,Vector2i(13,2 if data[id].terrain_requirement=="high" else 5),-1,2)],[]);state.units[0].attack_ticks_left=100000
	return state
func add(state: MatchState,id: String,side: int,cell: Vector2i,hp: int) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,side,id,cell,hp,0,100000,2 if side==0 else 0);state.next_unit_id+=1;state.units.append(unit);return unit
func cast(state: MatchState) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
