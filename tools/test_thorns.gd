extends SceneTree
var failures := 0
var data := {}
var op: OperatorData

func _initialize() -> void:
	op=load("res://resources/operators/thorns.tres");data.thorns=op
	var dummy := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;data.target=dummy
	check(op.validation_error().is_empty(),"Resource: "+op.validation_error())
	check(op.max_health==2612 and op.attack==711 and op.defense==402 and op.skills.size()==3,"E2 original stats and 3 actual skills")
	var first := fixture(0);var unit: UnitState=first.units[0]
	unit.sp=30;unit.attack_ticks_left=1;add_enemy(first,Vector2i(14,5))
	first.step([InputCommand.new(first.tick,1,"",unit.unit_id,Vector2i.ZERO,0)],[])
	check(unit.skill_ticks_left==899 and unit.sp==0 and SkillRules.attack_value(unit,op)==1422,"S1 actual activation/SP consumption/duration")
	check(first.units[1].hp==100000-damage(1138,"physical"),"S1 80% ranged multiplier and inherited guard coefficient")
	check(first.units[1].thorns_poison_damage==125,"Original125 poison")
	var melee := fixture(0);add_enemy(melee,Vector2i(13,5));melee.units[0].attack_ticks_left=1;melee.step([],[])
	check(melee.enemy_is_blocked(melee.units[1],melee.units[0].unit_id) and melee.units[1].hp==100000-damage(711,"physical"),"Own approved blocking removes normal ranged penalty")
	var poison := fixture(0);add_enemy(poison,Vector2i(14,5));poison.units[0].attack_ticks_left=1;poison.step([],[])
	var victim: UnitState=poison.units[1];var initial_hp := victim.hp;poison.units[0].attack_ticks_left=10000
	for t in 90:poison.step([],[])
	check(victim.hp==initial_hp-3*damage(125,"magical") and victim.thorns_poison_until_tick==0,"Exactly3 delayed poison pulses, clean expiry")
	var ranged := fixture(0);add_enemy(ranged,Vector2i(14,5));ranged._operator_data.target=ranged._operator_data.target.duplicate(true)
	ranged._operator_data.target.profession_id="caster";ranged.units[0].attack_ticks_left=1;ranged.step([],[])
	check(ranged.units[1].thorns_poison_damage==250,"Original250 against ranged enemy")
	var second := fixture(1);add_enemy(second,Vector2i(14,5));var defender: UnitState=second.units[0]
	defender.sp=25;defender.attack_ticks_left=1;defender.hp=1000
	second.step([InputCommand.new(second.tick,1,"",defender.unit_id,Vector2i.ZERO,1)],[])
	check(second.units[1].hp==100000 and defender.skill_ticks_left==1199 and SkillRules.defense_value(defender,op)==844,"S2 stops active attack, grants110%DEF, actual40seconds")
	var before := second.units[1].hp;second._apply_damage(defender,op,1,"physical",second.units[1])
	check(second.units[1].hp==before-damage(910,"physical") and defender.thorns_last_active_attack_tick==-1,"Counter retains80% and does not interrupt idle talent")
	before=second.units[1].hp;second._apply_damage(defender,op,1,"physical",second.units[1])
	check(second.units[1].hp==before,"Shared18tick counter cooldown")
	second.tick+=18;second._apply_damage(defender,op,1,"magical",second.units[1],false)
	check(second.units[1].hp==before,"DOT cannot trigger counter")
	var regen := fixture(1);regen.units[0].hp=1000
	for t in 59:regen.step([],[])
	check(regen.units[0].hp==1000,"No idle heal before2seconds")
	for t in 30:regen.step([],[])
	check(regen.units[0].hp==1045,"Original3.5%/s after existing50% heal factor with integer remainder")
	StatusRules.apply_silence(regen,regen.units[0],90);var hp := regen.units[0].hp
	for t in 30:regen.step([],[])
	check(regen.units[0].hp==hp,"Silence pauses self regeneration")
	for facing in 4:
		var third := fixture(2);var actor: UnitState=third.units[0];actor.facing=facing;actor.sp=15;actor.attack_ticks_left=1
		add_enemy(third,actor.cell+AttackRange.rotate_offset(Vector2i(2,0),facing))
		third.step([InputCommand.new(third.tick,1,"",actor.unit_id,Vector2i.ZERO,2)],[])
		check(actor.sp==0 and actor.skill_repeat_activation_count==1 and actor.skill_ticks_left==899,"S3 first actual cast facing%d"%facing)
		check(SkillRules.attack_value(actor,op)==1138 and SkillRules.attack_interval_ticks(actor,op)==31,"First ATK60% and ASPD25")
		actor.skill_ticks_left=1;third.step([],[]);actor.sp=15
		third.step([InputCommand.new(third.tick,1,"",actor.unit_id,Vector2i.ZERO,2)],[])
		check(actor.sp==0 and actor.skill_ticks_left==-2 and SkillRules.attack_value(actor,op)==1564 and SkillRules.attack_interval_ticks(actor,op)==26,"Second permanent stage facing%d"%facing)
		StatusRules.apply_silence(third,actor,60)
		check(SkillRules.attack_value(actor,op)==711 and SkillRules.attack_interval_ticks(actor,op)==39 and actor.skill_ticks_left==-2,"Silence pauses but preserves permanent stage")
	var objects := fixture(2);objects.units[0].attack_ticks_left=1;objects.ball.cell=Vector2i(14,5);objects.step([],[])
	check(objects.units[0].sp==1 and objects.units[0].last_attack_tick==1,"Ball attack grants actual SP")
	var boxes := fixture(2);boxes.units[0].attack_ticks_left=1;boxes.tactical_boxes=[TacticalBox.new(0,Vector2i(14,5),3)];boxes.step([],[])
	check(boxes.tactical_boxes[0].hits_left==2 and boxes.units[0].sp==1,"Box one hit, one SP")
	for index in 3:
		var a := fixture(index);var b := fixture(index)
		for state in [a,b]:add_enemy(state,Vector2i(14,5));state.units[0].sp=op.skills[index].sp_required;state.units[0].attack_ticks_left=1
		for t in 1000:
			var commands: Array[InputCommand]=[]
			if t==0:commands.append(InputCommand.new(a.tick,1,"",a.units[0].unit_id,Vector2i.ZERO,index))
			a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Everytick replay S%d tick%d"%[index+1,t])
	var hashed := fixture(0)
	for field in ["thorns_last_active_attack_tick","thorns_counter_ready_tick","thorns_regen_accum","thorns_poison_until_tick","thorns_poison_next_tick","thorns_poison_source_id","thorns_poison_damage"]:
		var old := hashed.state_hash();hashed.units[0].set(field,hashed.units[0].get(field)+1);check(old!=hashed.state_hash(),"Hash includes "+field)
	print("THORNS_OK all3 skills, actual deployment and costs, traits/talents, poison/control, 3x1000tick replay; failures=",failures)
	quit(0 if failures==0 else 1)

func damage(value: int, kind: String) -> int:
	return Combat.calculate_damage(value,0,0,kind,0,RNG.new(1),"guard")
func fixture(index: int) -> MatchState:
	var s := MatchState.new(307,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["thorns"],["target"]],[[index],[0]])
	s.sides[0].cost=99;s.step([InputCommand.new(0,0,"thorns",-1,Vector2i(12,5),-1,0)],[])
	check(s.units.size()==1 and s.units[0].operator_id=="thorns" and s.sides[0].cost==79,"Controlled99 actual legal deployment deducts20")
	s.ball.cell=Vector2i(5,5);s.units[0].attack_ticks_left=10000;return s
func add_enemy(s: MatchState, cell: Vector2i) -> void:
	s.units.append(UnitState.new(s.next_unit_id,1,"target",cell,100000,0,100000));s.next_unit_id+=1
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
