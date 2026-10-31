extends "res://tools/test_monstr_medic.gd"
func _initialize()->void:
	operators[ID]=load("res://resources/operators/mon3tr_operator.tres")
	var ally := (load("res://resources/operators/bagpipe.tres") as OperatorData).duplicate(true);ally.operator_id="ally";ally.max_health=10000;ally.attack=0;ally.terrain_requirement="both";operators.ally=ally
	var foe := ally.duplicate(true);foe.operator_id="foe";foe.max_health=100000;operators.foe=foe
	var s:=fixture(2);var actor:=s.units[0];deploy_token(s);actor.sp=15;var origin:=actor.cell
	s.step([InputCommand.new(s.tick,1,"",actor.unit_id,Vector2i.ZERO,2)],[])
	s._apply_skill_life_loss(actor,operators[ID],SkillRules.max_health_value(actor,operators[ID]))
	print("REVIEW_LIFE_LOSS transformed=",MonstrMedicRules.transformed(actor)," HP=",actor.hp," cell=",actor.cell," origin=",origin)
	check(actor.hp==1 and actor.cell==origin and not MonstrMedicRules.transformed(actor),"Fatal independent life loss must finish transformed Monstr and return alive")
	s=fixture(2);actor=s.units[0];deploy_token(s);actor.sp=15;s.step([InputCommand.new(s.tick,1,"",actor.unit_id,Vector2i.ZERO,2)],[])
	s._apply_damage(actor,operators[ID],99999,"true")
	s._apply_skill_life_loss(actor,operators[ID],1)
	print("REVIEW_RETURN_GUARD HP=",actor.hp," guard=",actor.monstr_return_guard_ticks)
	check(actor.hp==1,"One-second return undying guard must cover life loss")
	# Last selected squad member carries S3; reconstruction has only one passive skill.
	var state:=MatchState.new(129,operators,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["ally",ID],["foe"]],[[0,2],[0]])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state.step([InputCommand.new(0,0,ID,-1,Vector2i(13,2),-1,2)],[])
	var token:=deploy_token(state);check(token!=null and token.skill_index==0,"Reconstruction passive index0 when owner is last carriedS3")
	s=fixture(2);actor=s.units[0];deploy_token(s);actor.sp=15;s.step([InputCommand.new(s.tick,1,"",actor.unit_id,Vector2i.ZERO,2)],[])
	actor.hp=1;actor.monstr_loss_accum=0;actor.blood_buff_until_tick=s.tick+90;actor.blood_buff_next_tick=s.tick;actor.blood_buff_loss_percent=3;actor.attack_ticks_left=100000;s.step([],[])
	print("REVIEW_REAL_BLOOD_BUFF alive=",actor in s.units," HP=",actor.hp," transformed=",MonstrMedicRules.transformed(actor))
	check(actor.hp==1 and actor in s.units and not MonstrMedicRules.transformed(actor),"Actual blood-buff tick must respect meltdown undying and return")
	s=fixture(2);actor=s.units[0];deploy_token(s);actor.sp=15;s.step([InputCommand.new(s.tick,1,"",actor.unit_id,Vector2i.ZERO,2)],[])
	for cell in [Vector2i(12,2),Vector2i(14,2),Vector2i(12,4)]:add(s,"foe",1,cell,100000)
	var blocked:Array[UnitState]=[]
	for cell in [Vector2i(12,3),Vector2i(14,3),Vector2i(13,4)]:blocked.append(add(s,"foe",1,cell,100000))
	actor.attack_ticks_left=0;s.step([],[])
	print("REVIEW_S3_BLOCKED hp=",blocked[0].hp,",",blocked[1].hp,",",blocked[2].hp)
	for unit in blocked:check(unit.hp<100000,"S3 should prioritize own three blocked neighbors over diagonal targets")
	s=fixture(2);actor=s.units[0];deploy_token(s);actor.sp=15;s.step([InputCommand.new(s.tick,1,"",actor.unit_id,Vector2i.ZERO,2)],[])
	actor.hp=1;s._apply_skill_life_loss(actor,operators[ID],1)
	check(actor.hp==1 and not MonstrMedicRules.transformed(actor),"Generic lethal life loss at1HP returns even when clampedloss iszero")
	ClassicOperatorRules.lose_health(s,actor,99999);check(actor.hp==1,"Returned1secondguard also protects classic life loss")
	actor.attack_ticks_left=100000
	for tick in 30:s.step([],[])
	check(actor.monstr_return_guard_ticks==0,"Returnguardexpires after30simulatedticks")
	ClassicOperatorRules.lose_health(s,actor,1);check(actor.hp==0,"Afterguardexpiry ordinaryclassicloss cankill")
	s=fixture(2);actor=s.units[0];actor.hp=1;s._apply_skill_life_loss(actor,operators[ID],1)
	check(actor.hp==0 and not MonstrMedicRules.transformed(actor),"OrdinaryuntransformedMonstr gains no global deathprotection")
	for index in [1,2]:
		var p:OperatorData=load("res://resources/operators/pozyomka.tres")
		var pool:={"pozyomka":p}
		var carried:=MatchState.new(129,pool,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["pozyomka"],["pozyomka"]],[[index],[index]])
		check(carried.carried_skill_index(0,"pozyomka_typewriter")==index,"Typewriter continues carrying owner real skill%d"%index)
	print("MONSTR_REVIEW_CHECKS failures=",failures);quit(0 if failures==0 else 1)
