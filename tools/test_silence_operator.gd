extends SceneTree
var failures := 0
var data := {}
func _initialize() -> void:
	data.silence=load("res://resources/operators/silence.tres")
	data.saria=load("res://resources/operators/saria.tres")
	data.hellagur=load("res://resources/operators/hellagur.tres")
	data.myrtle=load("res://resources/operators/myrtle.tres")
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="patient";dummy.max_health=10000;data.patient=dummy
	var op: OperatorData=data.silence
	check(op.validation_error().is_empty() and op.skills.size()==2 and op.attack==482 and op.max_health==1595,"Original E2/M3 two skills "+op.validation_error())
	check(MatchState.MEDICAL_DRONE_DATA.validation_error().is_empty(),"Original device profile "+MatchState.MEDICAL_DRONE_DATA.validation_error())
	var aura := fixture(0);var source := aura.units[0]
	aura.units.append(UnitState.new(1,0,"patient",Vector2i(16,4),5000,0,100000,0));aura.next_unit_id=2
	source.sp=30;source.attack_ticks_left=1;aura.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,0)],[])
	check(aura.units[1].hp==5458 and SkillRules.attack_value(source,op)==916,"S1 ATK1.9 then heal50% =458")
	check(source.attack_speed_bonus==12 and SkillRules.attack_interval_ticks(source,op)==76 and aura.units[1].attack_speed_bonus==0,"Global medic ASPD12 includes source only matching profession")
	StatusRules.apply_silence(aura,source,30);check(source.attack_speed_bonus==0,"Silence removes own global talent")
	var stock := fixture(1)
	for t in 540:stock.step([],[])
	check(stock.units[0].medical_drone_stock==1 and stock.units[0].sp==0 and stock.units[0].skill_activation_count==1,"S2 auto18SP creates one stock with instant end")
	for t in 90:stock.step([],[])
	SagaRules.reward(stock,stock.units[0],9)
	var saria := UnitState.new(1,0,"saria",Vector2i(15,4),2780,0,0,0,0);stock.units.append(saria);stock.next_unit_id=2
	GuardianRules.heal_targets(stock,saria,data.saria,[stock.units[0]])
	check(stock.units[0].sp==0 and stock.units[0].sp_regen_ticks==0,"Full stock blocks natural and external SP (Saga/Saria)")
	stock.sides[0].cost=99
	stock.step([InputCommand.new(stock.tick,InputCommand.Kind.DEPLOY,"medical_drone",-1,Vector2i(15,5),0)],[])
	var device := find_device(stock)
	check(device!=null and stock.units[0].medical_drone_stock==0 and stock.sides[0].cost==94 and device.medical_drone_owner_id==0,"Deploy consumes own stock and5cost with independent owner ID")
	check(not MedicalDroneRules.available(stock,0) and not stock.enemy_is_targetable(1,device),"Deployed device not targetable, no stock duplication")
	for kind in ["physical","magical","true"]:check(not stock._apply_damage(device,MatchState.MEDICAL_DRONE_DATA,99999,kind) and device.hp==1000,"Device immune "+kind)
	StatusRules.add_control(stock,device,"bind",99);StatusRules.add_control(stock,device,"slow",99);StatusRules.add_control(stock,device,"stun",99);StatusRules.apply_silence(stock,device,99)
	check(device.bind_ticks_left==0 and device.slow_ticks_left==0 and device.stun_ticks_left==0 and device.silence_ticks_left==0,"Device immune to regular control/silence without changing public timing")
	var pulse := fixture(1);pulse.units[0].attack_ticks_left=100000;pulse.units[0].medical_drone_stock=1;pulse.sides[0].cost=99
	pulse.units.append(UnitState.new(1,0,"patient",Vector2i(16,4),5000,0,100000,0));pulse.units.append(UnitState.new(2,0,"patient",Vector2i(16,5),5000,0,100000,0));pulse.units.append(UnitState.new(3,0,"hellagur",Vector2i(15,4),1000,0,100000,0));pulse.units.append(UnitState.new(4,0,"patient",Vector2i(17,5),5000,0,100000,0));pulse.units[3].silence_ticks_left=10000;pulse.next_unit_id=5
	pulse.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"medical_drone",-1,Vector2i(15,5),0)],[])
	device=find_device(pulse)
	for t in 13:pulse.step([],[])
	check(pulse.units[1].hp==5000,"First pulse not inserted at deployment")
	pulse.step([],[])
	check(pulse.units[1].hp==5063 and pulse.units[2].hp==5063 and pulse.units[3].hp==1000 and pulse.units[4].hp==5000,"Pulse125 ->63, all allies in nine cells, excludes musha/outside")
	var time := pulse.tick;pulse.step([InputCommand.new(time,InputCommand.Kind.RETREAT,"",0)],[])
	check(find_device(pulse)!=null,"Device survives Silence retreat")
	while pulse.tick<300:pulse.step([],[])
	check(find_device(pulse)!=null and patient_hp(pulse,1)==6260 and patient_hp(pulse,2)==6260,"Exactly20 pulses over300ticks even owner gone")
	pulse.step([],[]);check(find_device(pulse)==null,"Lifetime300 removes without death rewards or refunded stock")
	var ai_state := fixture(1);ai_state.units[0].medical_drone_stock=1;ai_state.sides[0].cost=99;ai_state.tick=1000
	var before := ai_state.state_hash();var ai := AIInput.new(0,data);var commands := ai.commands_for_tick(ai_state);var deploy_found := false
	for c in commands:if c.kind==InputCommand.Kind.DEPLOY and c.operator_id=="medical_drone":deploy_found=true
	check(deploy_found and ai_state.state_hash()==before,"AI emits existing deployment command without changing simulation")
	var mixed_data := data.duplicate();mixed_data.magallan=load("res://resources/operators/magallan.tres")
	var mixed := MatchState.new(9,mixed_data);mixed.ball.cell=Vector2i(5,5);mixed.sides[0].cost=99
	mixed.units=[UnitState.new(0,0,"silence",Vector2i(14,4),1595,0,10000,0,1),UnitState.new(1,0,"magallan",Vector2i(17,4),1403,0,10000,0,0)];mixed.next_unit_id=2;mixed.units[0].medical_drone_stock=1
	var magallan_stock := mixed.sides[0].drone_stock
	mixed.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"medical_drone",-1,Vector2i(15,5),0)],[])
	check(find_device(mixed)!=null and mixed.sides[0].drone_stock==magallan_stock and mixed.sides[0].drone_cooldown_ticks==0,"Medical device and Magallan stock/cooldown stay independent")
	var a := fixture(1);var b := fixture(1)
	for t in 1200:a.step([],[]);b.step([],[]);check(a.state_hash()==b.state_hash(),"Per-tick same-input replay%d"%t)
	before=a.state_hash();a.units[0].medical_drone_stock+=1;check(a.state_hash()!=before,"Stock hashed");before=a.state_hash();a.units[0].medical_drone_owner_id+=1;check(a.state_hash()!=before,"Owner ID hashed")
	print("Silence skills, medic aura, SP lock, independent device,20 pulses, immunity, lifetime, readonly AI and replay; failures=%d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var s := MatchState.new(108,data);s.ball.cell=Vector2i(5,5);s.units=[UnitState.new(0,0,"silence",Vector2i(14,4),1595,0,0,0,index)];s.next_unit_id=1;return s
func find_device(s: MatchState) -> UnitState:
	for u in s.units:if u.operator_id=="medical_drone":return u
	return null
func patient_hp(s: MatchState,id: int) -> int:
	for u in s.units:if u.unit_id==id:return u.hp
	return -1
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
