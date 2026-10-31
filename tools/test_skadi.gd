extends SceneTree

var data := {}
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id in root.get_node("OperatorDB").all_ids():data[id]=root.get_node("OperatorDB").get_data(id)
	var skadi: OperatorData=data.skadi
	check(skadi.validation_error().is_empty() and skadi.group_id=="abyssal" and skadi.profession_id=="guard" and skadi.branch=="无畏者","Validated dreadnought and Abyssal Hunter identity")
	check(skadi.max_health==3866 and skadi.attack==1015 and skadi.defense==263 and skadi.attack_interval==1.5 and skadi.deploy_cost==19 and skadi.redeploy_time==70.0,"Pinned E2 level90, no trust/potential/module, raw stats")
	check(skadi.attack_range==[Vector2i.ZERO,Vector2i.RIGHT] and skadi.block_count==1,"Exact range1-1 and block1")
	check(skadi.skills.size()==3 and skadi.skills[0].skill_name=="迅捷打击·γ型" and skadi.skills[1].skill_name=="跃浪击" and skadi.skills[2].skill_name=="涌潮悲歌","All three named M3 skills")
	var ordinary := fixture(0)
	var unit := ordinary.units[0]
	check(SkillRules.attack_value(unit,skadi)==1157 and unit.sp==15,"Squad attack14percent is additive and does not rewrite raw attack")
	for _tick in 599:ordinary.step([],[])
	check(unit.sp==35,"S1 initial15 naturally reaches35 in20 seconds")
	ordinary.step([skill(ordinary,unit,0)],[])
	check(unit.sp==0 and unit.skill_ticks_left==1049 and SkillRules.attack_value(unit,skadi)==1614 and SkillRules.attack_interval_ticks(unit,skadi)==31,"S1 attack45percent adds to talent and speed45,35seconds")
	for _tick in 1049:ordinary.step([],[])
	check(unit.skill_ticks_left==0 and SkillRules.attack_value(unit,skadi)==1157 and SkillRules.attack_interval_ticks(unit,skadi)==45,"S1 expiry restores raw attack period and talent")
	var leap := fixture(1)
	unit=leap.units[0]
	check(unit.skill_ticks_left==899 and SkillRules.attack_value(unit,skadi)==2883 and not SkillRules.can_manually_activate(unit,skadi.skills[1]),"S2 activates on successful deployment, not a manual command")
	for _tick in 899:leap.step([],[])
	check(unit.skill_ticks_left==0 and unit.sp==0 and SkillRules.attack_value(unit,skadi)==1157,"S2 expires exactly30 simulated seconds and cannot recharge")
	leap.step([InputCommand.new(leap.tick,InputCommand.Kind.RETREAT,"",unit.unit_id)],[])
	check(leap.sides[0].cooldowns.skadi==1800,"Own talent subtracts10 from raw70seconds on retreat")
	for _tick in 1800:leap.step([],[])
	leap.sides[0].cost=99
	leap.step([InputCommand.new(leap.tick,InputCommand.Kind.DEPLOY,"skadi",-1,Vector2i(13,5),-1,0)],[])
	check(leap.units.size()==1 and leap.units[0].skill_ticks_left==899,"Redeployment restarts S2 instead of retaining expired state")
	var tide := fixture(2)
	unit=tide.units[0]
	check(unit.sp==70,"S3 starts with70SP")
	for _tick in 599:tide.step([],[])
	check(unit.sp==90,"S3 naturally charges remaining20SP")
	unit.hp=1933
	tide.step([skill(tide,unit,2)],[])
	check(unit.skill_ticks_left==1499 and SkillRules.attack_value(unit,skadi)==2477 and SkillRules.defense_value(unit,skadi)==605 and SkillRules.max_health_value(unit,skadi)==8892 and unit.hp==4446,"S3 adds130percent attack/DEF/maxHP and preserves HP ratio, not healing")
	StatusRules.apply_silence(tide,unit,2)
	check(SkillRules.max_health_value(unit,skadi)==3866 and unit.hp==1933 and SkillRules.attack_value(unit,skadi)==1015,"Silence pauses skill maxHP and own squad talent without duplicate scaling")
	tide.step([],[]);tide.step([],[])
	check(SkillRules.max_health_value(unit,skadi)==8892 and unit.hp==4446 and SkillRules.attack_value(unit,skadi)==2477,"Silence expiry restores still-running skill and squad effect")
	unit.stun_ticks_left=2
	tide.step([],[])
	check(SkillRules.max_health_value(unit,skadi)==8892 and SkillRules.attack_value(unit,skadi)==2477,"Stun does not remove an already active stat skill")
	while unit.skill_ticks_left>0:tide.step([],[])
	check(SkillRules.max_health_value(unit,skadi)==3866 and unit.hp==1933 and SkillRules.defense_value(unit,skadi)==263,"S3 expiry restores maxHP ratio and defense without inflating HP")
	var hunter := (data.bagpipe as OperatorData).duplicate(true)
	hunter.operator_id="hunter_fixture";hunter.group_id="abyssal"
	data[hunter.operator_id]=hunter
	var group := MatchState.new(33,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[PackedStringArray(["skadi","hunter_fixture","bagpipe"]),PackedStringArray(["hunter_fixture"])])
	group.units.assign([UnitState.new(0,0,"hunter_fixture",Vector2i(13,5),hunter.max_health,0,10000),UnitState.new(1,0,"bagpipe",Vector2i(13,6),2484,0,10000),UnitState.new(2,1,"hunter_fixture",Vector2i(7,5),hunter.max_health,0,10000)])
	AuraRules.refresh(group)
	check(group.units[0].attack_bonus_percent==14 and group.units[1].attack_bonus_percent==0 and group.units[2].attack_bonus_percent==0,"Undeployed squad source buffs only allied group members, not other guards or enemies")
	group.units.append(UnitState.new(3,0,"skadi",Vector2i(14,5),3866,0,10000))
	StatusRules.apply_silence(group,group.units[3],5)
	check(group.units[0].attack_bonus_percent==0,"Existing squad talent silence rule applies to a deployed source")
	group.units.remove_at(3);AuraRules.refresh(group)
	check(group.units[0].attack_bonus_percent==14,"Retreat does not permanently remove a squad talent")
	var redeploy := fixture(0,PackedStringArray(["skadi","silverash"]))
	check(redeploy._redeploy_ticks(0,skadi)==1620,"Flat10seconds before SilverAsh10percent yields54seconds, not double deduction")
	var no_skadi := MatchState.new(1,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[PackedStringArray(["hunter_fixture"]),PackedStringArray(["hunter_fixture"])])
	no_skadi.units.assign([UnitState.new(0,0,"hunter_fixture",Vector2i(13,5),hunter.max_health,0,10000)])
	AuraRules.refresh(no_skadi);check(no_skadi.units[0].attack_bonus_percent==0,"Faction membership without the source does not grant a free buff")
	for facing in 4:
		var ball := fixture(1)
		unit=ball.units[0];unit.facing=facing;unit.attack_ticks_left=1
		ball._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);ball._ball_data.kick_threshold=10000
		ball.ball.cell=unit.cell+AttackRange.rotate_offset(Vector2i.RIGHT,facing)
		ball.step([],[])
		settle_strike(ball)
		check(ball.ball.accum==AttackRange.rotate_offset(Vector2i(2883,0),facing),"Raw single-target ball push, four facings%d"%facing)
		ball.ball.cell=unit.cell-Vector2i.RIGHT;ball.ball.move_direction=Vector2i.RIGHT;ball.ball.move_ticks_left=1
		check(not ball.ball_move_is_blocked(),"Block1 does not gain defender ball blocking")
	var replay_a := fixture(2)
	var replay_b := fixture(2)
	for tick in 2300:
		var commands: Array[InputCommand]=[]
		if tick==600:commands.append(skill(replay_a,replay_a.units[0],2))
		replay_a.step(commands,[]);replay_b.step(commands,[])
		check(replay_a.state_hash()==replay_b.state_hash(),"Per-tick replay mismatch%d"%tick)
	var target := (data.bagpipe as OperatorData).duplicate(true)
	target.operator_id="target_fixture";target.max_health=100000;target.defense=100
	data[target.operator_id]=target
	for index in 3:
		var damage := fixture(index)
		damage.units.append(UnitState.new(1,1,"target_fixture",Vector2i(14,5),100000,0,100000))
		if index!=1:
			damage.units[0].sp=skadi.skills[index].sp_required
			damage.step([skill(damage,damage.units[0],index)],[])
		damage.units[0].attack_ticks_left=1
		damage.step([],[])
		settle_strike(damage)
		var expected: int=[618,1125,963][index]
		check(damage.units[1].hp==100000-expected,"Single physical strike uses guard40percent and effectiveDEF70percent skill%d"%index)
		var box := fixture(index)
		if index!=1:
			box.units[0].sp=skadi.skills[index].sp_required
			box.step([skill(box,box.units[0],index)],[])
		box.units[0].attack_ticks_left=1
		box.tactical_boxes=[TacticalBox.new(0,Vector2i(14,5),3)]
		box.ball.cell=Vector2i(14,5)
		var rng_before := box.rng.state
		box.step([],[])
		settle_strike(box)
		check(box.tactical_boxes.size()==1 and box.tactical_boxes[0].hits_left==2 and box.ball.accum==Vector2i.ZERO and box.rng.state==rng_before,"One box hit takes priority over ball without RNG skill%d"%index)
	var invalid := skadi.duplicate(true) as OperatorData
	invalid.group_id="unknown"
	check(invalid.validation_error().contains("group_id"),"Unregistered group rejects")
	invalid=skadi.duplicate(true);invalid.talent_2.effect_params.reduction_seconds=70
	check(invalid.validation_error().contains("reduction_seconds"),"Flat redeploy cannot erase the base cooldown")
	invalid=skadi.duplicate(true);invalid.skills[1].duration=-1.0
	check(not invalid.validation_error().is_empty(),"Deployment attack skill cannot become infinite")
	var importer := GDScript.new()
	importer.source_code=FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	check(importer.reload()==OK,"CSV importer compiles")
	var parser=importer.new()
	var csv := FileAccess.open("res://import/operators.csv",FileAccess.READ)
	var columns := {};var header := csv.get_csv_line()
	for index in header.size():columns[header[index]]=index
	var imported := {}
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size()==1 and row[0].is_empty():continue
		check(parser._validate_row(row,columns),"CSV row validates")
		var operator: OperatorData=parser._build_operator(row,columns)
		imported[operator.operator_id]=operator
	check(parser._append_skills(imported),"Three skills import")
	check(imported.skadi.group_id==skadi.group_id and imported.skadi.attack==skadi.attack and imported.skadi.talent_1.effect_params==skadi.talent_1.effect_params,"CSV faction and raw data match runtime resource")
	for index in 3:
		var rebuilt: SkillResource=imported.skadi.skills[index]
		check(rebuilt.effect_type==skadi.skills[index].effect_type and rebuilt.effect_params==skadi.skills[index].effect_params and rebuilt.duration==skadi.skills[index].duration and rebuilt.initial_sp==skadi.skills[index].initial_sp and rebuilt.sp_required==skadi.skills[index].sp_required,"Typed CSV skill%d matches runtime"%index)
	check(skadi.attack==1015 and skadi.max_health==3866 and skadi.skills[2].effect_params.health_percent==130,"Runtime never changes read-only resources")
	print("SKADI_OK: all3 skills, raw data/range, squad faction filtering, deploy timer, natural SP, health ratio/silence/stun/expiry, redeploy,4-way ball and2300 per-tick replay" if failures==0 else "SKADI_FAILED")
	quit(0 if failures==0 else 1)

func fixture(index: int,ids: PackedStringArray=PackedStringArray(["skadi"])) -> MatchState:
	var skills := PackedInt32Array();skills.resize(ids.size());skills[0]=index
	var state := MatchState.new(17,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills])
	state.sides[0].cost=99;state.ball.cell=Vector2i(10,10)
	state.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"skadi",-1,Vector2i(13,5),-1,0)],[])
	state.units[0].attack_ticks_left=100000
	return state

func skill(state: MatchState,unit: UnitState,index: int) -> InputCommand:
	return InputCommand.new(state.tick,InputCommand.Kind.SKILL,"",unit.unit_id,Vector2i.ZERO,index)

func check(value: bool,message: String) -> void:
	if not value:failures+=1;push_error(message)


func settle_strike(state: MatchState) -> void:
	var deadline:=state.tick+120
	while state.units[0].last_attack_tick<0 and state.tick<deadline:state.step([],[])
	check(state.units[0].last_attack_tick>=0,"Skadi source windup reaches actual strike")
