extends SceneTree
var failures := 0
var data := {}
func _initialize() -> void:
	for id in ["stainless","titi","ling","jessica_alter","muelsyse","mon3tr_operator","mlynar","wildmane"]:data[id]=load("res://resources/operators/"+id+".tres")
	var target := (data.wildmane as OperatorData).duplicate(true) as OperatorData;target.operator_id="target";target.max_health=100000;target.defense=0;target.magic_resist=0;data.target=target
	var s := fixture();var c := s.units[1]
	s=fixture();c=s.units[1];var ling := add(s,"ling",Vector2i(17,5),0,2);ling.skill_ticks_left=900
	var soul := add(s,"ling_soul3",Vector2i(13,5),0,0);soul.ling_owner_id=ling.unit_id
	ling.ling_pulse_ticks=int(data.ling.skills[2].effect_params.pulse_ticks)-1
	var foe := add(s,"target",Vector2i(13,6),1,0)
	LingRules.advance(s)
	print("LING_FOE_DAMAGE=",100000-foe.hp)
	record("LING_S3_ADJACENT_PULSE",c.sp,1)
	s=fixture();c=s.units[1];var jess := add(s,"jessica_alter",Vector2i(11,5),0,2);jess.skill_ticks_left=900
	var distance := 0
	for offset in AttackRange.effective_offsets(jess,data.jessica_alter):
		if offset.y==0:distance=maxi(distance,offset.x)
	var center := jess.cell+Vector2i.RIGHT*distance;c.cell=center+Vector2i.DOWN
	foe=add(s,"target",center,1,0)
	SentinelRules.fire_bomb(s,jess,data.jessica_alter)
	print("JESSICA_FOE_DAMAGE=",100000-foe.hp," center=",center)
	record("JESSICA_S3_BOMB_AOE",c.sp,1)
	s=fixture();c=s.units[1];var m := add(s,"mon3tr_operator",Vector2i(13,5),0,2);m.monstr_origin_cell=Vector2i(17,5);m.skill_ticks_left=900
	MonstrMedicRules.attack(s,m,data.mon3tr_operator)
	record("MONSTR_S3_ACTUAL_HIT",c.sp,1)
	s=fixture();c=s.units[1];var mu := add(s,"muelsyse",Vector2i(17,5),0,1);mu.skill_ticks_left=900
	var flow := add(s,"flowing_shape",Vector2i(13,5),0,0);flow.flow_owner_id=mu.unit_id;flow.flow_copy_id="titi";flow.flow_health=1000;flow.flow_attack=500;flow.flow_interval_ticks=30;flow.flow_range=[Vector2i.RIGHT,Vector2i.UP];flow.flow_melee=false
	foe=add(s,"target",Vector2i(13,4),1,0);s.rng=RNG.new(129)
	TacticianRules.attack(s,flow,s._operator_data.flowing_shape)
	print("FLOW_FOE_DAMAGE=",100000-foe.hp)
	record("FLOW_S2_ENEMY_PRIORITY",c.sp,0)
	foe.hp=0;flow.attack_ticks_left=0;s.tick+=1;TacticianRules.attack(s,flow,s._operator_data.flowing_shape)
	record("FLOW_S2_NO_ENEMY_FALLBACK",c.sp,2)
	s=fixture();c=s.units[1]
	for control in ["cold","frozen","stun","bind","slow","sleep"]:StatusRules.add_control(s,c,control,100,s.units[0])
	StatusRules.apply_silence(s,c,100)
	record("DEVICE_CONTROLS",c.cold_ticks_left+c.frozen_ticks_left+c.stun_ticks_left+c.bind_ticks_left+c.slow_ticks_left+c.sleep_ticks_left+c.silence_ticks_left,0)
	var stock := s.sides[0].stainless_stock;var rng_before := s.rng.state;s._retreat_unit(s.units[0])
	record("OWNER_RETREAT_TOKEN_PRESENT",int(c in s.units),0);record("OWNER_RETREAT_STOCK",s.sides[0].stainless_stock,stock);record("OWNER_RETREAT_RNG",s.rng.state,rng_before)
	s=fixture();c=s.units[1];stock=s.sides[0].stainless_stock;s.units[0].hp=0;s.step([],[])
	record("OWNER_DEATH_TOKEN_PRESENT",int(c in s.units),0);record("OWNER_DEATH_STOCK",s.sides[0].stainless_stock,stock)
	print("STAINLESS_SHARED_FAILURES=",failures)
	quit(1 if failures>0 else 0)
func fixture() -> MatchState:
	var s := MatchState.new(129,data)
	var owner := add(s,"stainless",Vector2i(18,9),0,2)
	var c := add(s,"stainless_cannon",Vector2i(14,5),0,0);StainlessRules.deployed(s,c)
	return s
func add(s: MatchState,id: String,cell: Vector2i,side: int,index: int) -> UnitState:
	var d: OperatorData=s._operator_data[id];var u := UnitState.new(s.next_unit_id,side,id,cell,d.max_health,0,0,0,index)
	s.next_unit_id+=1;s.units.append(u);return u
func record(label: String,actual: int,expected: int) -> void:
	print(label," actual=",actual," expected=",expected)
	if actual!=expected:failures+=1
