extends SceneTree

var failures := 0
var data := {"myrtle":load("res://resources/operators/myrtle.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres"),"shining":load("res://resources/operators/shining.tres")}

func _initialize() -> void:
	var op: OperatorData=data.myrtle
	check(op.validation_error().is_empty(),"Myrtle resource: "+op.validation_error())
	check(op.skills.size()==2 and op.max_health==1565 and op.attack==520 and op.defense==300,"Raw E2max and two actual skills")
	var s := fixture(0)
	s.units[0].sp=22
	s.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,0)],[])
	check(s.units[0].skill_ticks_left==239 and SkillRules.block_count_value(s.units[0],op)==0,"S1 begins240tick, block0")
	for t in 239:s.step([],[])
	check(s.sides[0].cost==22 and s.units[0].skill_ticks_left==0 and SkillRules.block_count_value(s.units[0],op)==1,"S1 exactly14cost plus8natural, restore block")
	var regen := fixture(0)
	regen.units[0].hp=1000
	regen.units.append(UnitState.new(1,0,"bagpipe",Vector2i(13,5),1000,0,10000))
	regen.units.append(UnitState.new(2,0,"shining",Vector2i(14,5),1000,0,10000))
	regen.next_unit_id=3
	for t in 60:regen.step([],[])
	check(regen.units[0].hp==1025 and regen.units[1].hp==1025 and regen.units[2].hp==1000,"Talent global25HP/s *50%, self/vanguard only, remainder")
	StatusRules.apply_silence(regen,regen.units[0],60)
	for t in 30:regen.step([],[])
	check(regen.units[1].hp==1025,"Silence pauses talent")
	regen._retreat_unit(regen.units[0])
	for t in 30:regen.step([],[])
	check(regen.units[0].hp==1025,"Source exit removes global regeneration")
	for facing in 4:
		var heal := fixture(1)
		heal.units[0].facing=facing
		heal.units[0].attack_ticks_left=1
		var cell := heal.units[0].cell+AttackRange.rotate_offset(Vector2i(1,1),facing)
		heal.units.append(UnitState.new(1,0,"shining",cell,1000,0,10000))
		heal.units.append(UnitState.new(2,0,"shining",heal.units[0].cell+AttackRange.rotate_offset(Vector2i(-1,1),facing),1000,0,10000))
		heal.next_unit_id=3
		heal.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
		check(heal.units[1].hp==1130 and heal.units[2].hp==1000,"S2 ordinary heal130, IDtie, facing%d"%facing)
		check(heal.units[0].last_attack_is_heal and heal.units[0].skill_ticks_left==479,"S2 activation and ordinary heal event")
		heal.units[0].attack_speed_bonus=100
		check(SkillRules.attack_interval_ticks(heal.units[0],op)==30,"S2 ignores ASPD")
		for t in 29:heal.step([],[])
		check(heal.units[2].hp==1000,"No early heal before fixed1s")
		heal.step([],[])
		check(heal.units[2].hp==1130,"Next pulse chooses lower HP ratio")
		StatusRules.add_control(heal,heal.units[0],"bind",90)
		heal.units[0].attack_ticks_left=1
		var hp := heal.units[1].hp
		heal.step([],[])
		check(heal.units[1].hp==hp and heal.units[0].last_attack_tick==30,"Bind stops ordinary skill-heal, no new timer")
	var costs := fixture(1)
	costs.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	for t in 479:costs.step([],[])
	check(costs.sides[0].cost==32 and costs.units[0].skill_ticks_left==0,"S2 exact16cost+16natural, expiry")
	var self_heal := fixture(1)
	self_heal.units[0].hp=1000;self_heal.units[0].attack_ticks_left=1
	self_heal.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,1)],[])
	check(self_heal.units[0].hp==1130,"S2 can select itself")
	var first := fixture(1)
	var second := fixture(1)
	for t in 600:
		var commands: Array[InputCommand]=[]
		if t==0:commands=[InputCommand.new(0,1,"",0,Vector2i.ZERO,1)]
		first.step(commands,[]);second.step(commands,[])
		check(first.state_hash()==second.state_hash(),"Replay everytick %d"%t)
	var importer_script := GDScript.new()
	importer_script.source_code=FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	check(importer_script.reload()==OK,"Importer compiles")
	var imported := {}
	for f in DirAccess.get_files_at("res://resources/operators"):
		if f.ends_with(".tres"):
			var resource := load("res://resources/operators/"+f) as OperatorData
			imported[resource.operator_id]=resource.duplicate(true);imported[resource.operator_id].skills.resize(1)
	check(importer_script.new()._append_skills(imported),"All CSV additional skills import")
	check(imported.myrtle.skills[1].effect_params==op.skills[1].effect_params and imported.myrtle.skills[1].attack_range_override==op.skills[1].attack_range_override,"S2 CSV parity")
	print("Myrtle focused checks failures=",failures)
	quit(0 if failures==0 else 1)

func fixture(index: int) -> MatchState:
	var s := MatchState.new(151,data)
	s.ball.cell=Vector2i(5,5)
	s.sides[0].cost=0
	s.units=[UnitState.new(0,0,"myrtle",Vector2i(12,5),1565,24 if index==1 else 22,10000,0,index)]
	s.next_unit_id=1
	return s

func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
