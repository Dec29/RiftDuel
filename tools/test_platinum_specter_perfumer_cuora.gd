extends SceneTree
var failures := 0
var data := {}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for id in ["platinum","specter","perfumer","cuora"]:
		data[id]=load("res://resources/operators/%s.tres"%id)
		check(data[id].validation_error().is_empty() and data[id].skills.size()==2,"Original two skills and valid resource "+id)
	var actor: OperatorData=load("res://resources/operators/bagpipe.tres");actor=actor.duplicate(true);actor.operator_id="fixture";actor.max_health=100000;actor.attack=0;actor.defense=0;actor.magic_resist=0;actor.talent_1.effect_type="none";actor.talent_2.effect_type="none";data.fixture=actor
	var p := fixture("platinum",0);p.ball.cell=Vector2i(12,2);p.tick=75;p.units[0].attack_ticks_left=0;p.step([],[])
	check(p.ball.accum==Vector2i(-909,0),"Full charged stationary-ball push909 after75ticks")
	var half := fixture("platinum",0);var victim := add(half,"fixture",1,Vector2i(12,2),100000);half.tick=45;half.units[0].attack_ticks_left=0;half.step([],[])
	check(victim.hp==99840,"45tick charge rounds640 then sniper25percent=160")
	var early := fixture("platinum",0);early.ball.cell=Vector2i(12,2);early.tick=20;early.units[0].attack_ticks_left=0;early.step([],[]);check(early.ball.accum==Vector2i(-505,0),"Deployment first hit not instantly fully charged")
	var sight := fixture("platinum",1);sight.units[0].sp=50;sight.step([],[])
	check(sight.units[0].skill_ticks_left==-2 and SkillRules.attack_value(sight.units[0],data.platinum)==1010 and SkillRules.attack_interval_ticks(sight.units[0],data.platinum)==38,"Pegasian infinite ATK100percent and actualAS-20")
	check(AttackRange.effective_offsets(sight.units[0],data.platinum)==data.platinum.skills[1].attack_range_override,"Exact expanded range from table")
	data.skadi=load("res://resources/operators/skadi.tres");var team := fixture("specter",0);team.squad_ids[0].append("skadi");AuraRules.refresh(team);check(SkillRules.attack_value(team.units[0],data.specter)==827,"Specter inherits existing Abyssal14percent squad aura")
	var force := fixture("specter",0);force.units[0].sp=30;force.step([cast(force)],[]);check(SkillRules.attack_value(force.units[0],data.specter)==1450,"Specter S1 ATK100percent")
	sight.units[0].attack_speed_bonus=-90;check(SkillRules.attack_interval_ticks(sight.units[0],data.platinum)==3000,"AS reduction clamps final speed to1")
	sight.units[0].attack_speed_bonus=0;sight.units[0].critical_ticks_left=30;sight.units[0].critical_speed_percent=20;check(SkillRules.attack_interval_ticks(sight.units[0],data.platinum)==188,"Critical slowdown multiplies finalAS80to16")
	var sp := fixture("specter",1);var unit := sp.units[0];check(unit.hp==2893,"Specter talent adds10percent maxHP")
	unit.hp=1000;unit.skill_hp_regen_accum=0;StatusRules.regenerate(sp);for tick in 29:StatusRules.regenerate(sp)
	check(unit.hp==1028,"Specter2percent maxHP regen with50percent coefficient and integer carry")
	unit.sp=40;sp.step([cast(sp)],[]);unit.hp=100
	check(SkillRules.attack_value(unit,data.specter)==1885,"Specter S2 ATK160percent")
	sp._apply_damage(unit,data.specter,100000,"true");check(unit.hp==1,"S2 lethal true damage clamps1HP")
	data.saga=load("res://resources/operators/saga.tres");sp._operator_data.saga=data.saga;var saga := add(sp,"saga",1,Vector2i(12,5),2000);unit.hp=100;sp._apply_damage(unit,data.specter,100000,"physical",saga);check(unit.hp==1 and unit.critical_ticks_left==0,"Survival clamp precedes Saga lethal marking")
	sp._apply_skill_life_loss(unit,data.specter,10000);check(unit.hp==1,"S2 skill life loss also clamps1HP")
	unit.skill_ticks_left=1;sp.step([],[]);check(unit.stun_ticks_left==300 and unit.skill_ticks_left==0,"Actual S2 expiration causes10second stun")
	var muted := fixture("specter",1);muted.units[0].sp=40;muted.step([cast(muted)],[]);StatusRules.apply_silence(muted,muted.units[0],30);muted._apply_damage(muted.units[0],data.specter,100000,"true");check(muted.units[0].hp<=0,"Silence suspends skill lock per project rules")
	var heal := fixture("perfumer",0);var a := add(heal,"fixture",0,Vector2i(12,3),1000);var b := add(heal,"fixture",0,Vector2i(14,3),1000);var c := add(heal,"fixture",0,Vector2i(13,3),1000);heal.units[0].sp=30;heal.units[0].attack_ticks_left=0;heal.step([cast(heal)],[])
	check(a.hp==1272 and b.hp==1272 and c.hp==1272,"Perfumer S1 heals three272 using170percentATK")
	var blend := fixture("perfumer",1);var far := add(blend,"fixture",0,Vector2i(20,10),1000);blend.units[0].sp=60;blend.step([cast(blend)],[])
	check(SkillRules.attack_value(blend.units[0],data.perfumer)==1120 and SkillRules.attack_interval_ticks(blend.units[0],data.perfumer)==171,"Blend+250percent ATK / AS-50")
	far.hp=1000;far.skill_hp_regen_accum=0;for tick in 30:StatusRules.regenerate(blend)
	check(far.hp==1028,"Global lavender uses current ATK outside heal range")
	StatusRules.apply_silence(blend,blend.units[0],30);var old_hp := far.hp;for tick in 30:StatusRules.regenerate(blend)
	check(far.hp==old_hp,"Silence removes global source")
	var shell := fixture("cuora",1);var turtle := shell.units[0];check(SkillRules.defense_value(turtle,data.cuora)==773,"Cuora innateDEF12percent")
	turtle.sp=40;shell.ball.cell=Vector2i(12,5);turtle.attack_ticks_left=0;shell.step([cast(shell)],[])
	check(SkillRules.defense_value(turtle,data.cuora)==1670 and SkillRules.block_count_value(turtle,data.cuora)==4 and shell.ball.accum==Vector2i.ZERO and turtle.last_attack_tick==-1,"Shell DEF130plus12 / block4 / ceases ball attacks")
	turtle.hp=1000;turtle.skill_hp_regen_accum=0;for tick in 30:StatusRules.regenerate(shell)
	check(turtle.hp==1046,"Shell3percent HP regen with50percent coefficient")
	var defense := fixture("cuora",0);defense.units[0].sp=35;defense.step([cast(defense)],[]);check(SkillRules.defense_value(defense.units[0],data.cuora)==1325,"Cuora S1 DEF80plus12")
	for id in ["platinum","specter","perfumer","cuora"]:
		for index in 2:
			var first := fixture(id,index);var second := fixture(id,index)
			for state in [first,second]:state.units[0].sp=SkillRules.sp_limit(data[id].skills[index]);state.units[0].attack_ticks_left=0;state.ball.cell=Vector2i(12,2 if data[id].terrain_requirement=="high" else 5)
			for tick in 480:
				var commands: Array[InputCommand]=[]
				if tick==0 and data[id].skills[index].trigger_type=="manual":commands.append(cast(first))
				first.step(commands,[]);second.step(commands,[]);check(first.state_hash()==second.state_hash(),"Eight loadouts480tick identical seed replay")
	print("PLATINUM_FOUR_CORE_OK" if failures==0 else "PLATINUM_FOUR_FAILED%d"%failures);quit(0 if failures==0 else 1)
func fixture(id: String,index: int) -> MatchState:
	var ids := PackedStringArray([id]);var indices := PackedInt32Array([index]);var state := MatchState.new(14,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[indices,indices]);state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=1000000000
	state.step([InputCommand.new(0,0,id,-1,Vector2i(13,2 if data[id].terrain_requirement=="high" else 5),-1,2)],[]);state.units[0].attack_ticks_left=100000;return state
func add(state: MatchState,id: String,side: int,cell: Vector2i,hp: int) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,side,id,cell,hp,0,100000,2 if side==0 else 0);state.next_unit_id+=1;state.units.append(unit);return unit
func cast(state: MatchState) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,state.units[0].skill_index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
