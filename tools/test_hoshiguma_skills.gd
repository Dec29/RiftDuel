extends SceneTree
var failures := 0
var data := {}
const RANGE := preload("res://sim/attack_range.gd")
func _initialize() -> void:
	for id in ["hoshiguma", "bagpipe", "exusiai"]: data[id] = load("res://resources/operators/%s.tres" % id)
	var op: OperatorData = data["hoshiguma"]
	check(op.skills.size() == 3 and op.skills[0].skill_name == "战意" and op.skills[1].parameters_are_valid() and op.skills[2].parameters_are_valid(), "All three named validated skills")
	var passive := fixture(1)
	passive.step([], [])
	check(SkillRules.defense_value(passive.units[0], op) == 983 and SkillRules.attack_value(passive.units[0], op) == 430 and passive.units[0].sp == 0, "Passive defense adds30% to6% aura, no attack/SP bonus")
	check(not SkillRules.can_manually_activate(passive.units[0], op.skills[1]), "Passive never opens a manual skill")
	var source := UnitState.new(1, 1, "exusiai", Vector2i(18, 5), 100000, 0, 10000)
	passive.units.append(source)
	var expected := Combat.calculate_damage(430, 161, 0, "physical", 0, RNG.new(1), "defender")
	passive._apply_damage(passive.units[0], op, 0, "magical", source)
	check(source.hp == 100000 - expected, "Zero damage attack still reflects to far enemy source, uses defender PvP")
	passive._apply_damage(passive.units[0], op, 10, "physical")
	check(source.hp == 100000 - expected, "Source-free damage never reflects")
	var mutual := fixture(1)
	mutual.units.append(UnitState.new(1, 1, "hoshiguma", Vector2i(13, 5), 3850, 0, 10000, 2, 1))
	AuraRules.refresh(mutual)
	mutual._apply_damage(mutual.units[0], op, 10, "physical", mutual.units[1])
	check(mutual.units[0].hp >= 3840 and mutual.units[1].hp >= 3840, "Thorns versus thorns terminates after one retaliation")
	# Real five-shot enemy attack; retaliation killing its source cancels later shots.
	var lethal := fixture(1)
	lethal.units.append(UnitState.new(1, 1, "exusiai", Vector2i(13, 5), 1, 30, 0, 2, 2))
	lethal.next_unit_id = 2
	lethal.step([], [])
	check(lethal.units.size() == 1 and lethal.sides[1].cooldowns.has("exusiai"), "Actual multi-shot source dies to first retaliation and receives cooldown")
	for facing in 4:
		var state := fixture(2, facing)
		var enemy_cell := state.units[0].cell + RANGE.rotate_offset(Vector2i.RIGHT, facing)
		state.units.append(UnitState.new(1, 1, "bagpipe", enemy_cell, 100000, 0, 10000))
		state.units[0].sp = 50
		state.units[0].attack_ticks_left = 0
		state.step([InputCommand.new(0, 1, "", 0, Vector2i.ZERO, 2)], [])
		var attacker := state.units[0]
		check(attacker.skill_ticks_left == 749 and attacker.sp == 0 and SkillRules.attack_value(attacker, op) == 1032 and SkillRules.defense_value(attacker, op) == 1417, "S3 real activation/duration/additive attributes")
		var damage := Combat.calculate_damage(1032, 382, 0, "physical", 0, RNG.new(1), "defender")
		check(state.units[1].hp == 100000-damage and RANGE.effective_offsets(attacker, op) == op.attack_range, "Exact two-cell rotation and actual S3 physical damage facing%d" % facing)
	var expanded: OperatorData = op.duplicate(true)
	expanded.attack_range = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(1,1), Vector2i(1,-1)]
	var wide := MatchState.new(123,{"hoshiguma":expanded,"bagpipe":data["bagpipe"]})
	wide.ball.cell = Vector2i(5,5)
	wide.units.append(UnitState.new(0,0,"hoshiguma",Vector2i(12,5),3850,50,0,0,2))
	for index in 3: wide.units.append(UnitState.new(index+1,1,"bagpipe",Vector2i(13,4+index),100000,0,10000))
	wide.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
	for index in 3: check(wide.units[index+1].hp < 100000,"S3 hits all targets, not just blocker capacity")
	var ball := fixture(2,2)
	ball.ball.cell = Vector2i(11,5)
	ball.units[0].sp = 50
	ball.units[0].attack_ticks_left = 0
	ball.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
	check(ball.ball.accum == Vector2i(-1032,0), "S3 ball receives one raw actual attack, no PvP reduction")
	var box := fixture(2,2)
	box.units[0].sp=50
	box.units[0].attack_ticks_left=0
	box.tactical_boxes.append(TacticalBox.new(0,Vector2i(11,5),3))
	box.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
	check(box.tactical_boxes[0].hits_left == 2,"S3 one box hit per attack action")
	var first := fixture(2)
	var second := fixture(2)
	first.units[0].sp=50
	second.units[0].sp=50
	for t in 900:
		var cmds: Array[InputCommand] = []
		if t==0: cmds.append(InputCommand.new(t,1,"",0,Vector2i.ZERO,2))
		first.step(cmds,[])
		second.step(cmds,[])
		check(first.state_hash()==second.state_hash(),"Continuous deterministic replay tick%d"%t)
		if t==748: check(first.units[0].skill_ticks_left==1 and first.units[0].sp==0,"No early expiry or active SP regeneration")
		if t==749: check(first.units[0].skill_ticks_left==0 and SkillRules.attack_value(first.units[0],op)==430 and SkillRules.defense_value(first.units[0],op)==766,"750tick expiration restores exact stats")
	var importer := GDScript.new()
	importer.source_code=FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	check(importer.reload()==OK,"Importer compiles")
	var imported := {}
	for file in DirAccess.get_files_at("res://resources/operators"):
		if file.ends_with(".tres"):
			var loaded: OperatorData=load("res://resources/operators/"+file)
			imported[loaded.operator_id]=loaded.duplicate(true)
			imported[loaded.operator_id].skills.resize(1)
	check(importer.new()._append_skills(imported),"All additional CSV skills import")
	for index in [1,2]: check(imported["hoshiguma"].skills[index].effect_params==op.skills[index].effect_params,"Typed CSV exact resource parity")
	var invalid: SkillResource=op.skills[1].duplicate(true)
	invalid.effect_params["reflect_attack_percent"]=0.5
	check(not invalid.parameters_are_valid(),"Reject fractional reflect parameter")
	print("Hoshiguma S2/S3: reflection/source death/no recursion, passive/active stats, range/all targets, ball/box, expiry, CSV, every-tick replay; failures=%d"%failures)
	quit(0 if failures==0 else 1)
func fixture(index:int,facing:int=0)->MatchState:
	var state := MatchState.new(123,data)
	state.ball.cell=Vector2i(5,5)
	state.units=[UnitState.new(0,0,"hoshiguma",Vector2i(12,5),3850,0,10000,facing,index)]
	state.next_unit_id=1
	return state
func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)
