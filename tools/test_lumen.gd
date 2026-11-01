extends SceneTree
var failures := 0
var data := {"lumen":load("res://resources/operators/lumen.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.lumen
	check(op.validation_error().is_empty() and op.attack==540 and op.max_health==1825 and op.redeploy_time==80.0,"Lumen rawE2 no potential,3M3 skills")
	var ally: OperatorData=data.bagpipe.duplicate(true);ally.operator_id="ally_fixture";ally.max_health=10000;ally.talent_1.effect_type="none";ally.talent_2.effect_type="none";data.ally_fixture=ally
	var normal := fixture(0);var near := add_ally(normal,Vector2i(11,2));var far := add_ally(normal,Vector2i(9,2))
	LumenRules.treat(normal,normal.units[0],near,100);LumenRules.treat(normal,normal.units[0],far,100)
	check(near.hp==1270 and far.hp==1216,"540 direct healing gives270 near and216 far after50percent PvP")
	near.hp=7500;near.lumen_resistance_ticks=0;LumenRules.treat(normal,normal.units[0],near,100)
	check(near.lumen_resistance_ticks==120,"75percent pre-heal HP gets4seconds resistance")
	near.hp=7501;near.lumen_resistance_ticks=0;LumenRules.treat(normal,normal.units[0],near,100)
	check(near.lumen_resistance_ticks==180,"Strictly above75percent pre-heal HP gets6seconds")
	near.stun_ticks_left=60;near.lumen_resistance_ticks=0;LumenRules.treat(normal,normal.units[0],near,100)
	check(near.stun_ticks_left==60,"New resistance does not shorten existing stun")
	near.stun_ticks_left=0;normal.units[0].lumen_emergency_ready_tick=100000;SwordRules.stun(normal,near,60)
	check(near.stun_ticks_left==30,"New stun uses resistance50percent duration")
	var rain := fixture(0);var rain_target := add_ally(rain,Vector2i(11,2));var adjacent := add_ally(rain,Vector2i(11,3));rain.units[0].sp=10;rain.units[0].attack_ticks_left=0;rain.step([],[]);rain.units[0].attack_ticks_left=100000
	check(rain.lumen_rain_fields.size()==1 and rain_target.hp==1000 and rain.units[0].sp==0,"S1 replaces direct heal with5pulse rain field")
	for tick in 150:rain.step([],[])
	check(rain_target.hp==1745 and adjacent.hp==1745 and rain.lumen_rain_fields.is_empty(),"S1 five149 heals for center and eight-neighbor area")
	var uncharged := fixture(1);var hurt := add_ally(uncharged,Vector2i(11,2));set_controls(hurt);uncharged.units[0].sp=13;uncharged.step([cast(uncharged,1)],[])
	check(hurt.hp==1702 and LumenRules.has_control(hurt) and uncharged.units[0].sp==0,"S2 uncharged702 heal preserves controls and consumes allSP")
	var charged := fixture(1);var cleansing := add_ally(charged,Vector2i(11,2));set_controls(cleansing);charged.units[0].sp=26;charged.step([cast(charged,1)],[])
	check(cleansing.hp==1702 and not LumenRules.has_control(cleansing) and cleansing.displacement_ticks_left>0 and charged.units[0].sp==0,"ChargedS2 clears stun/silence/bind/slow, not displacement")
	var lamp := fixture(2);var patient := add_ally(lamp,Vector2i(11,2));set_controls(patient);lamp.units[0].sp=50;lamp.units[0].attack_ticks_left=0;lamp.step([cast(lamp,2)],[])
	check(patient.hp==1837 and not LumenRules.has_control(patient) and lamp.units[0].skill_ammo_left==7 and SkillRules.attack_interval_ticks(lamp.units[0],op)==66,"S3 boosted837 heal, consumes1 of8 and clears4statuses")
	lamp.units[0].attack_ticks_left=0;patient.displacement_ticks_left=0;lamp.step([],[])
	check(patient.hp==2256 and lamp.units[0].skill_ammo_left==7,"Ordinary419 heal duringS3 does not consume ammunition")
	for shot in 7:
		patient.hp=1000;patient.silence_ticks_left=60;lamp.units[0].attack_ticks_left=0;lamp.step([],[])
	check(lamp.units[0].skill_ticks_left==0 and lamp.units[0].skill_ammo_left==0,"Eight controlled treatments endS3")
	var manual := fixture(2);add_ally(manual,Vector2i(11,2));manual.units[0].sp=50;manual.step([cast(manual,2)],[]);var activations := manual.units[0].skill_activation_count;manual.step([cast(manual,2)],[])
	check(manual.units[0].skill_ticks_left==0 and manual.units[0].skill_activation_count==activations,"Manual stop works withoutSP or fake activation")
	var emergency := fixture(0);emergency.units[0].lumen_emergency_ready_tick=0;var emergency_target := add_ally(emergency,Vector2i(11,2));var cooldown := emergency.units[0].attack_ticks_left
	StatusRules.add_control(emergency,emergency_target,"bind",60)
	check(emergency_target.hp==1216 and emergency.units[0].lumen_emergency_ready_tick==emergency.tick+360 and emergency.units[0].attack_ticks_left==cooldown,"New bind immediately triggers216 heal and12s global cooldown, no attack reset")
	StatusRules.apply_silence(emergency,emergency_target,60)
	check(emergency_target.hp==1216,"Repeated control does not bypass emergency cooldown")
	emergency.tick=emergency.units[0].lumen_emergency_ready_tick;StatusRules.add_control(emergency,emergency_target,"slow",30)
	check(emergency_target.hp==1432,"Emergency available after12seconds for slow as approved")
	var a := fixture(0);var b := fixture(0)
	for state in [a,b]:add_ally(state,Vector2i(11,2));state.units[0].sp=10;state.units[0].attack_ticks_left=0
	for tick in 180:a.step([],[]);b.step([],[]);check(a.state_hash()==b.state_hash(),"Rain/resistance per-tick deterministic replay")
	print("LUMEN_CORE_OK" if failures==0 else "LUMEN_FAILED %d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["lumen"]);var skills := PackedInt32Array([index]);var state := MatchState.new(10,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills]);state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"lumen",-1,Vector2i(12,2),-1,2)],[]);state.units[0].attack_ticks_left=100000;state.units[0].lumen_emergency_ready_tick=100000;return state
func add_ally(state: MatchState,cell: Vector2i) -> UnitState:
	var unit := UnitState.new(state.units.size(),0,"ally_fixture",cell,1000,0,100000);state.units.append(unit);return unit
func set_controls(unit: UnitState) -> void:unit.stun_ticks_left=60;unit.silence_ticks_left=60;unit.bind_ticks_left=60;unit.slow_ticks_left=60;unit.displacement_ticks_left=10
func cast(state: MatchState,index: int) -> InputCommand:return InputCommand.new(state.tick,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
