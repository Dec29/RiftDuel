extends SceneTree
var failures := 0
var data := {}
const RANGE := preload("res://sim/attack_range.gd")
func _initialize() -> void:
	for id in ["nightingale","bagpipe","eyjafjalla"]: data[id] = load("res://resources/operators/%s.tres"%id)
	var op: OperatorData = data["nightingale"]
	check(op.skills.size() == 3 and op.skills[0].skill_name == "治疗强化·γ型" and op.skills[1].parameters_are_valid() and op.skills[2].parameters_are_valid(),"Named validated M3 skills")
	var state := fixture(1)
	state.units[0].sp = 24
	state.units[0].attack_ticks_left = 1
	for index in range(1,5): state.units[index].hp = 1000
	state.step([],[])
	check(state.units[0].sp == 16,"One charge consumed per three-target healing action")
	for index in range(1,4):
		check(state.units[index].hp == 1175 and state.units[index].barrier_hp == PackedInt32Array([315]) and state.units[index].barrier_ticks_left == PackedInt32Array([150]),"Heal175/shield315, no50% shield reduction")
		check(state.units[index].barrier_magic_only == PackedInt32Array([1]) and SkillRules.magic_resist_value(state.units[index],data["bagpipe"]) == 35,"Magic-only barrier adds20MR to15aura")
	check(state.units[4].hp == 1000 and state.units[4].barrier_hp.is_empty(),"Three lowest HP ratios, ID tie order")
	state.units[0].attack_ticks_left = 1
	state.step([],[])
	check(state.units[0].sp == 8 and state.units[4].barrier_hp.size() == 1,"Next action still one charge")
	for unit in state.units: unit.attack_ticks_left = 10000
	for t in 150: state.step([],[])
	for unit in state.units: check(unit.barrier_hp.is_empty(),"Each shield independently expires by150ticks")
	var healthy := fixture(1)
	healthy.units[0].sp = 24
	healthy.units[0].attack_ticks_left = 1
	healthy.step([],[])
	check(healthy.units[0].sp == 24 and healthy.units[1].barrier_hp.is_empty(),"FullHP allies preserve charges")
	for type in ["physical","true","magical"]:
		var hit := fixture(1)
		var target := hit.units[1]
		grant(target,315,150,1,20)
		var hp := target.hp
		var landed := hit._apply_damage(target,data["bagpipe"],100,type)
		check(landed == (type != "magical") and target.hp == hp-(0 if type == "magical" else 100) and target.barrier_hp[0] == (215 if type == "magical" else 315),"Only magic absorbed: "+type)
	var mixed := fixture(1)
	grant(mixed.units[1],100,90,0,0)
	grant(mixed.units[1],200,150,1,20)
	mixed._apply_damage(mixed.units[1],data["bagpipe"],150,"magical")
	check(mixed.units[1].barrier_hp == PackedInt32Array([0,150]),"Mixed shields absorb oldest eligible first")
	mixed._apply_damage(mixed.units[1],data["bagpipe"],150,"magical")
	check(SkillRules.magic_resist_value(mixed.units[1],data["bagpipe"]) == 35,"Depleted shield retains MR until original expiry")
	grant(mixed.units[1],200,150,1,20)
	check(SkillRules.magic_resist_value(mixed.units[1],data["bagpipe"]) == 35,"MR bonus does not stack")
	mixed.step([InputCommand.new(0,InputCommand.Kind.RETREAT,"",0)],[])
	check(SkillRules.magic_resist_value(mixed.units[0],data["bagpipe"]) == 20,"Caster retreat removes aura but retains granted shieldMR")
	for t in 149: mixed.step([],[])
	check(mixed.units[0].barrier_hp.is_empty() and SkillRules.magic_resist_value(mixed.units[0],data["bagpipe"]) == 0,"Full expiry restores MR and queues")
	var sanctuary := fixture(2)
	sanctuary.units[0].sp = 120
	sanctuary.units[1].cell = Vector2i(15,2)
	sanctuary.units[1].hp = 1000
	sanctuary.units[0].attack_ticks_left = 1
	sanctuary.step([InputCommand.new(0,1,"",0,Vector2i.ZERO,2)],[])
	check(sanctuary.units[0].skill_ticks_left == 1799 and sanctuary.units[0].sp == 0 and SkillRules.attack_value(sanctuary.units[0],op) == 630,"S3 exact1800ticks and80%ATK")
	check(sanctuary.units[1].hp == 1315 and SkillRules.magic_resist_value(sanctuary.units[1],data["bagpipe"]) == 38 and SkillRules.magic_resist_value(sanctuary.units[0],op) == 50,"Expanded heal315 and aura, MR multiplier includes flat15")
	check(SkillRules.dodge_chance(sanctuary.units[1],data["bagpipe"],"magical") == 25 and SkillRules.dodge_chance(sanctuary.units[1],data["bagpipe"],"physical") == 0,"Magic dodge only")
	for facing in 4:
		sanctuary.units[0].facing = facing
		var offsets := op.skills[2].attack_range_override
		check(offsets.size() == 19,"S3 exact19-cell range")
		for offset in offsets: check(sanctuary._is_in_attack_range(sanctuary.units[0],sanctuary.units[0].cell+RANGE.rotate_offset(offset,facing),RANGE.effective_offsets(sanctuary.units[0],op)),"Four-facing range")
	sanctuary.units[0].facing = 0
	sanctuary.units[0].skill_ticks_left = 1
	sanctuary.step([],[])
	check(sanctuary.units[1].magic_resist_bonus == 0 and sanctuary.units[1].magic_resist_bonus_percent == 0 and sanctuary.units[1].dodge_magical_bonus == 0,"Expiry immediately removes expanded talent and skill aura")
	sanctuary.units[0].sp = 120
	sanctuary.step([InputCommand.new(sanctuary.tick,1,"",0,Vector2i.ZERO,2)],[])
	sanctuary.step([InputCommand.new(sanctuary.tick,2,"",0)],[])
	check(sanctuary.units[0].magic_resist_bonus_percent == 0 and sanctuary.units[0].dodge_magical_bonus == 0,"Retreat removes skill aura")
	var hash_state := fixture(1)
	grant(hash_state.units[1],100,90,1,20)
	for field in ["barrier_magic_only","barrier_magic_resist_add"]:
		var before := hash_state.state_hash()
		var values: PackedInt32Array = hash_state.units[1].get(field)
		values[0] += 1
		hash_state.units[1].set(field,values)
		check(before != hash_state.state_hash(),"New queue participates in hash "+field)
	var first := fixture(2)
	var second := fixture(2)
	first.units[0].sp = 120
	second.units[0].sp = 120
	for t in 1900:
		var commands: Array[InputCommand] = []
		if t == 0: commands.append(InputCommand.new(t,1,"",0,Vector2i.ZERO,2))
		first.step(commands,[])
		second.step(commands,[])
		check(first.state_hash() == second.state_hash(),"Continuous replay")
		if t == 1799: check(first.units[0].skill_ticks_left == 0 and SkillRules.attack_value(first.units[0],op) == 350,"60s exact expiration")
	var importer := GDScript.new()
	importer.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	check(importer.reload() == OK,"Importer compiles")
	var imported := {}
	for file in DirAccess.get_files_at("res://resources/operators"):
		if file.ends_with(".tres"):
			var loaded: OperatorData = load("res://resources/operators/"+file)
			imported[loaded.operator_id] = loaded.duplicate(true)
			imported[loaded.operator_id].skills.resize(1)
	check(importer.new()._append_skills(imported),"All CSV skills import")
	for index in [1,2]: check(imported["nightingale"].skills[index].effect_params == op.skills[index].effect_params and imported["nightingale"].skills[index].attack_range_override == op.skills[index].attack_range_override,"CSV exact typed parity")
	print("Nightingale S2/S3: three-target one-charge, magic-only FIFO/MR/expiry, sanctuary range/healing/aura/dodge, retreat/hash, CSV and replay; failures=%d"%failures)
	quit(0 if failures == 0 else 1)
func fixture(index:int)->MatchState:
	var state := MatchState.new(123,data)
	state.ball.cell = Vector2i(5,5)
	state.units = [UnitState.new(0,0,"nightingale",Vector2i(12,2),1705,0,10000,0,index)]
	for cell in [Vector2i(13,2),Vector2i(14,2),Vector2i(13,3),Vector2i(11,2)]: state.units.append(UnitState.new(state.units.size(),0,"bagpipe",cell,2484,0,10000))
	state.next_unit_id = 5
	AuraRules.refresh(state)
	return state
func grant(unit:UnitState,hp:int,ticks:int,magic:int,mr:int)->void:
	unit.barrier_hp.append(hp)
	unit.barrier_ticks_left.append(ticks)
	unit.barrier_defense_percent.append(0)
	unit.barrier_magic_only.append(magic)
	unit.barrier_magic_resist_add.append(mr)
func check(ok:bool,message:String)->void:
	if not ok:
		failures += 1
		push_error(message)

