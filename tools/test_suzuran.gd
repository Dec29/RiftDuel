extends SceneTree

const RANGE := [Vector2i(-1,-1),Vector2i(-1,0),Vector2i(-1,1),Vector2i(0,-1),Vector2i(0,0),Vector2i(0,1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(2,-1),Vector2i(2,0),Vector2i(2,1)]
const ROTATE := preload("res://sim/attack_range.gd")
const CONFIG := preload("res://data/config.gd")
var _failures := 0


func _initialize() -> void:
	var data := {}
	for id in ["suzuran","angelina","bagpipe"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var suzuran: OperatorData = data["suzuran"]
	_expect([suzuran.max_health,suzuran.attack,suzuran.defense,suzuran.magic_resist,suzuran.attack_interval,suzuran.block_count,suzuran.deploy_cost,suzuran.redeploy_time] == [1480,521,128,25,1.9,1,16,70.0], "Raw E2 values without trust/potential/module")
	_expect(suzuran.profession_id == "supporter" and suzuran.branch == "凝滞师" and suzuran.damage_type == "magical" and Array(suzuran.attack_range) == RANGE, "Decel binder exact3-13 range and magical damage")
	_expect(suzuran.skills[0].sp_required == 20 and suzuran.skills[0].initial_sp == 0 and suzuran.skills[0].duration == 30.0 and suzuran.skills[0].sp_recharge_type == "time", "S1M3 initial0/required20/time/30s")
	for facing in 4:
		var state := _solo(data)
		state.units[0].facing = facing
		for y in range(-4,5):
			for x in range(-4,5):
				var offset := Vector2i(x,y)
				_expect(state._is_in_attack_range(state.units[0],state.units[0].cell+ROTATE.rotate_offset(offset,facing),suzuran.attack_range) == (offset in RANGE), "Facing%d offset%s mismatch" % [facing,offset])
	_test_sp_and_skill(data)
	_test_aura(data)
	_test_slow_fragile(data)
	_test_order_and_angelina(data)
	_test_import(suzuran)
	_test_replay(data)
	_expect(suzuran.attack == 521 and suzuran.skills[0].effect_params["attack_mult"] == 1.8 and data["angelina"].branch_trait.effect_params["slow_duration"] == 0.8, "Resources remain read-only; Angelina trait unchanged")
	print("Suzuran: base/range4, autoS1, SP1.4/remainders/block, max aura, slow24/fragile/all damage, Angelina/order, ball, CSV/hash/replay; failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _solo(data: Dictionary) -> MatchState:
	var state := MatchState.new(123,data)
	state.units = [UnitState.new(0,0,"suzuran",Vector2i(12,5),1480,0,10000,0)]
	state.ball.cell = Vector2i(5,5)
	state.next_unit_id = 1
	return state


func _test_sp_and_skill(data: Dictionary) -> void:
	var state := _solo(data)
	for _tick in 21:
		state.step([],[])
	_expect(state.units[0].sp == 0 and state.units[0].sp_regen_ticks == 29 and state.units[0].sp_regen_accum == 40, "21ticks at1.4/s:29.4 equivalent ticks")
	state.step([],[])
	_expect(state.units[0].sp == 1 and state.units[0].sp_regen_ticks == 0 and state.units[0].sp_regen_accum == 80, "22ticks:1SP and0.8 equivalent tick")
	for _tick in 278:
		state.step([],[])
	_expect(state.units[0].sp == 14 and state.units[0].sp_regen_ticks == 0 and state.units[0].sp_regen_accum == 0, "10seconds precisely14SP without rounding loss")
	for _tick in 128:
		state.step([],[])
	_expect(state.units[0].sp == 19 and state.units[0].sp_regen_ticks == 29 and state.units[0].sp_regen_accum == 20 and state.units[0].skill_ticks_left == 0, "428ticks remains below20SP")
	state.step([],[])
	var suzuran: OperatorData = data["suzuran"]
	_expect(state.units[0].sp == 0 and state.units[0].skill_ticks_left == 899 and state.units[0].sp_regen_ticks == 0 and state.units[0].sp_regen_accum == 0, "429th tick autoactivates and clears progress")
	_expect(SkillRules.attack_value(state.units[0],suzuran) == 938 and SkillRules.attack_interval_ticks(state.units[0],suzuran) == 44 and not SkillRules.can_manually_activate(state.units[0],suzuran.skills[0]), "S1 ATK80%/AS30:938attack44ticks; automatic only")
	for _tick in 899:
		state.step([],[])
	_expect(state.units[0].skill_ticks_left == 0 and state.units[0].sp == 0 and state.units[0].sp_regen_ticks == 0 and state.units[0].sp_regen_accum == 0 and SkillRules.attack_interval_ticks(state.units[0],suzuran) == 57, "900 active ticks block natural SP; expiry restores57ticks")
	state.step([],[])
	_expect(state.units[0].sp_regen_ticks == 1 and state.units[0].sp_regen_accum == 40, "Natural recharge resumes after expiry")
	for field in ["slow_ticks_left","sp_regen_accum","sp_recharge_bonus_percent"]:
		var before := state.state_hash()
		state.units[0].set(field,state.units[0].get(field)+1)
		_expect(state.state_hash() != before, "New state must hash: " + field)
		state.units[0].set(field,state.units[0].get(field)-1)


func _test_aura(data: Dictionary) -> void:
	var receiver := (data["suzuran"] as OperatorData).duplicate(true) as OperatorData
	receiver.operator_id = "receiver"
	receiver.talent_1.effect_type = "attack_speed_buff"
	receiver.talent_1.effect_params = {"attack_speed_add":1}
	receiver.talent_2.effect_type = "reveal_invisible"
	receiver.talent_2.effect_params = {}
	receiver.skills[0].effect_type = "atk_spd_boost"
	receiver.skills[0].sp_required = 100
	var higher := (data["suzuran"] as OperatorData).duplicate(true) as OperatorData
	higher.operator_id = "higher"
	higher.talent_1.effect_params["sp_recharge_bonus_percent"] = 60
	var definitions := data.duplicate()
	definitions["receiver"] = receiver
	definitions["higher"] = higher
	var state := _solo(definitions)
	state.units.append(UnitState.new(1,0,"receiver",Vector2i(13,5),1480,0,10000))
	state.units.append(UnitState.new(2,0,"higher",Vector2i(14,5),1480,0,10000))
	state.units.append(UnitState.new(3,1,"receiver",Vector2i(8,5),1480,0,10000))
	state.units.append(UnitState.new(4,0,"bagpipe",Vector2i(15,5),2484,0,10000))
	AuraRules.refresh(state)
	_expect(state.units[0].sp_recharge_bonus_percent == 60 and state.units[1].sp_recharge_bonus_percent == 60 and state.units[3].sp_recharge_bonus_percent == 0 and state.units[4].sp_recharge_bonus_percent == 0, "Highest same-type aura, includes self, excludes enemy/non-supporter")
	state.units[2].hp = 0
	AuraRules.refresh(state)
	_expect(state.units[1].sp_recharge_bonus_percent == 40, "Dead higher source restores40% source")
	state.units[0].hp = 0
	AuraRules.refresh(state)
	_expect(state.units[1].sp_recharge_bonus_percent == 0, "No surviving source removes natural SP bonus")
	for recharge in ["on_hit","on_damaged"]:
		var custom := receiver.duplicate(true) as OperatorData
		custom.skills[0].sp_recharge_type = recharge
		var custom_data := data.duplicate()
		custom_data["receiver"] = custom
		var blocked := _solo(custom_data)
		blocked.units.append(UnitState.new(1,0,"receiver",Vector2i(13,5),1480,0,10000))
		for _tick in 300:
			blocked.step([],[])
		_expect(blocked.units[1].sp == 0 and blocked.units[1].sp_regen_ticks == 0 and blocked.units[1].sp_regen_accum == 0, "Natural aura cannot charge " + recharge)
	var active := _solo(definitions)
	active.units.append(UnitState.new(1,0,"receiver",Vector2i(13,5),1480,0,10000))
	active.units[1].skill_ticks_left = 500
	active.units[1].sp_regen_ticks = 4
	active.units[1].sp_regen_accum = 60
	for _tick in 300:
		active.step([],[])
	_expect(active.units[1].sp == 0 and active.units[1].sp_regen_ticks == 4 and active.units[1].sp_regen_accum == 60, "Active skill freezes all natural progress")


func _test_slow_fragile(data: Dictionary) -> void:
	var state := _solo(data)
	state.units[0].attack_ticks_left = 1
	state.units.append(UnitState.new(1,1,"bagpipe",Vector2i(13,5),5000,0,10000))
	state.step([],[])
	_expect(state.units[1].hp == 4896 and state.units[1].slow_ticks_left == 24 and state._fragile_damage_percent(state.units[1]) == 120, "First hit104 then slow24; first hit not amplified")
	var interval := SkillRules.attack_interval_ticks(state.units[1],data["bagpipe"])
	state.units[0].attack_ticks_left = 1
	state.step([],[])
	_expect(state.units[1].hp == 4771 and state.units[1].slow_ticks_left == 24 and SkillRules.attack_interval_ticks(state.units[1],data["bagpipe"]) == interval, "Next hit125 refreshes mark, never changes attack interval")
	for type in ["physical","magical","true"]:
		var normal := Combat.calculate_damage(500,100,20,type,0,RNG.new(1),"guard")
		var fragile := Combat.calculate_damage(500,100,20,type,0,RNG.new(1),"guard",state._fragile_damage_percent(state.units[1]))
		_expect([normal,fragile] == ({"physical":[172,206],"magical":[160,192],"true":[200,240]}[type]), "Fragile applies all damage with one final round: " + type)
	state.units[1].cell = Vector2i(15,5)
	_expect(state._fragile_damage_percent(state.units[1]) == 100, "Leaving independent3-13 range removes fragile immediately")
	state.units[1].cell = Vector2i(13,5)
	state.units[0].hp = 0
	_expect(state._fragile_damage_percent(state.units[1]) == 100, "Source death removes fragile immediately")
	state.units[0].hp = 1480
	state.units[0].attack_ticks_left = 10000
	for _tick in 23:
		state.step([],[])
	_expect(state.units[1].slow_ticks_left == 1 and state._fragile_damage_percent(state.units[1]) == 120, "Marker still active before24th following tick")
	state.step([],[])
	_expect(state.units[1].slow_ticks_left == 0 and state._fragile_damage_percent(state.units[1]) == 100, "Slow expiry removes fragile without separate timer")
	state.units[1].slow_ticks_left = 24
	state.step([InputCommand.new(state.tick,InputCommand.Kind.RETREAT,"",0)],[])
	_expect(state._fragile_damage_percent(state.units[0]) == 100, "Source retreat removes fragile")
	var ball_state := _solo(data)
	ball_state.ball.cell = Vector2i(13,5)
	ball_state.units[0].attack_ticks_left = 1
	ball_state.step([],[])
	_expect(ball_state.ball.accum == Vector2i(521,0), "Ball push521 ignores supporter damage coefficient/fragile")
	ball_state.units[0].sp = 20
	ball_state.units[0].attack_ticks_left = 1
	ball_state.step([],[])
	_expect(ball_state.ball.accum == Vector2i(1459,0), "S1 ball push938 adds raw skill output without fragile state")


func _test_order_and_angelina(data: Dictionary) -> void:
	var striker := (data["bagpipe"] as OperatorData).duplicate(true) as OperatorData
	striker.talent_1.effect_type = "attack_speed_buff"
	striker.talent_1.effect_params = {"attack_speed_add":1}
	var definitions := data.duplicate()
	definitions["striker"] = striker
	for first_is_slow in [true,false]:
		var state := _solo(definitions)
		var slow_id := 0 if first_is_slow else 1
		var strike_id := 1 if first_is_slow else 0
		state.units = [UnitState.new(0,0,"angelina" if first_is_slow else "striker",Vector2i(12,4),2484,0,1,0),UnitState.new(1,0,"striker" if first_is_slow else "angelina",Vector2i(12,5),2484,0,1,0),UnitState.new(2,0,"suzuran",Vector2i(12,6),1480,0,10000,0),UnitState.new(3,1,"bagpipe",Vector2i(13,5),5000,0,10000)]
		state.units[strike_id].cell = Vector2i(12,5)
		state.units[slow_id].cell = Vector2i(12,4)
		state.step([],[])
		_expect(state.units[3].hp == (4796 if first_is_slow else 4812) and state.units[3].slow_ticks_left == 24, "Angelina mark unifies branch; later striker benefits same tick iff lower-ID slow attacked first")
		_expect(state.units[slow_id].sp == 1 and state.units[slow_id].sp_regen_accum == 0, "Angelina attack recovery remains one SP, not natural aura")


func _test_import(suzuran: OperatorData) -> void:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	_expect(script.reload() == OK, "Importer compiles")
	var importer: RefCounted = script.new()
	var csv := FileAccess.open("res://import/operators.csv",FileAccess.READ)
	var header := csv.get_csv_line()
	var columns := {}
	for index in header.size():
		columns[header[index]] = index
	var found := false
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() == 1:
			continue
		_expect(importer._validate_row(row,columns), "CSV row remains importable: "+row[0])
		if row[0] == "铃兰":
			found = true
			var imported: OperatorData = importer._build_operator(row,columns)
			_expect(imported.attack == 521 and imported.magic_resist == 25 and imported.branch_trait.effect_params == suzuran.branch_trait.effect_params and imported.talent_1.effect_params == suzuran.talent_1.effect_params and imported.talent_2.effect_params == suzuran.talent_2.effect_params and imported.skills[0].effect_params == suzuran.skills[0].effect_params, "CSV preserves typed Suzuran params")
	_expect(found, "Suzuran CSV row required")


func _test_replay(data: Dictionary) -> void:
	var first := _solo(data)
	var second := _solo(data)
	for state in [first,second]:
		state.units.append(UnitState.new(1,1,"bagpipe",Vector2i(13,5),50000,0,10000))
		state.units[0].attack_ticks_left = 1
	for tick in 1800:
		var commands: Array[InputCommand] = []
		if tick == 1500:
			commands = [InputCommand.new(tick,InputCommand.Kind.RETREAT,"",0)]
		first.step(commands,[])
		second.step(commands,[])
		_expect(first.state_hash() == second.state_hash(), "Fixed-input slow/SP/autoS1/retreat replay mismatch tick%d" % tick)


func _expect(condition: bool,message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
