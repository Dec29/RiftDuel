extends SceneTree

const ROTATE := preload("res://sim/attack_range.gd")
const CONFIG := preload("res://data/config.gd")
var _failures := 0


func _initialize() -> void:
	var data := {}
	for id in ["saileach","bagpipe","nightingale"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var sail: OperatorData = data["saileach"]
	_expect([sail.max_health,sail.attack,sail.defense,sail.magic_resist,sail.attack_interval,sail.block_count,sail.deploy_cost,sail.redeploy_time] == [1835,546,367,0,1.3,1,12,70.0], "Raw E2 without trust/potential/module")
	_expect(sail.profession_id == "vanguard" and sail.branch_trait.effect_type == "flag_bearer" and sail.skills[0].sp_required == 26 and sail.skills[0].initial_sp == 15 and sail.skills[0].duration == 8.0, "Flag bearer S1M3 initial15/required26/manual/time8s")
	for facing in 4:
		var state := _solo(data)
		state.units[0].facing = facing
		for y in range(-2,3):
			for x in range(-2,3):
				var offset := Vector2i(x,y)
				_expect(state._is_in_attack_range(state.units[0],state.units[0].cell+ROTATE.rotate_offset(offset,facing),sail.attack_range) == (offset in [Vector2i.ZERO,Vector2i.RIGHT]), "Facing%d offset%s range1-1 mismatch" % [facing,offset])
	_test_skill(data)
	_test_flag(data)
	_test_discount(data)
	_test_import(sail)
	_test_uncarried()
	var first := _solo(data)
	var second := _solo(data)
	for tick in 900:
		var commands: Array[InputCommand] = []
		if tick in [0,500]:
			first.units[0].sp = 26
			second.units[0].sp = 26
			commands = [InputCommand.new(tick,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,0)]
		first.step(commands,[])
		second.step(commands,[])
		_expect(first.state_hash() == second.state_hash(), "Cost/flag fixed-input replay mismatch tick%d" % tick)
	_expect(sail.deploy_cost == 12 and sail.block_count == 1 and sail.attack == 546, "Resources remain read-only")
	print("Saileach: E2/range4, 240tick18DP/natural8DP/stop/block, flag8/cooldown, discount/phantom/order/AI, CSV/hash/replay; failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _solo(data: Dictionary) -> MatchState:
	var state := MatchState.new(123,data)
	state.units = [UnitState.new(0,0,"saileach",Vector2i(12,5),1835,26,1,0)]
	state.ball.cell = Vector2i(5,5)
	state.next_unit_id = 1
	return state


func _test_skill(data: Dictionary) -> void:
	var state := _solo(data)
	state.units.append(UnitState.new(1,1,"bagpipe",Vector2i(13,5),5000,0,10000))
	for index in 240:
		var commands: Array[InputCommand] = []
		if index == 0:
			commands = [InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,0)]
		state.step(commands,[])
		var count := index+1
		_expect(state.sides[0].cost == 10+count/30+count*18/240 and state.units[0].skill_cost_accum == count*18%240, "Exact DP split and natural income at tick%d" % count)
		_expect(state.units[0].last_attack_tick == -1 and state.units[1].hp == 5000 and state.units[0].sp == 0 and state.units[0].attack_ticks_left == 1, "Skill freezes attacks/cooldown/SP throughout tick%d" % count)
		_expect(SkillRules.block_count_value(state.units[0],data["saileach"]) == (0 if count < 240 else 1), "Dynamic block restored after full240ticks")
	_expect(state.sides[0].cost == 36 and state.units[0].skill_ticks_left == 0 and state.units[0].skill_cost_accum == 0, "Complete18 skill DP plus8 independent natural DP")
	state.step([],[])
	_expect(state.units[0].last_attack_tick == 240 and state.units[1].hp == 4930, "Post-skill attack resumes at stored cooldown using vanguard25%")
	state.units[0].sp = 26
	state.step([InputCommand.new(state.tick,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,0)],[])
	_expect(state.units[0].skill_cost_accum == 18 and state.units[0].skill_ticks_left == 239, "New activation clears old remainder then processes first active tick")
	for field in ["skill_cost_accum"]:
		var before := state.state_hash()
		state.units[0].set(field,state.units[0].get(field)+1)
		_expect(before != state.state_hash(), "Cost remainder must hash")
		state.units[0].set(field,state.units[0].get(field)-1)
	var clone := (data["saileach"] as OperatorData).duplicate(true) as OperatorData
	clone.operator_id = "non_flag"
	clone.branch_trait.effect_type = "prioritize_blocked"
	clone.block_count = 3
	var custom := data.duplicate()
	custom["non_flag"] = clone
	var non_flag := MatchState.new(1,custom)
	non_flag.units = [UnitState.new(0,0,"non_flag",Vector2i(12,5),1835,26,1,0),UnitState.new(1,1,"bagpipe",Vector2i(13,5),5000,0,10000)]
	non_flag.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,0)],[])
	_expect(non_flag.units[0].last_attack_tick == 0 and non_flag.units[1].hp == 4930 and SkillRules.block_count_value(non_flag.units[0],clone) == 3, "Cost regeneration alone never implies flag-bearer stop/block0")
	clone.branch_trait.effect_type = "flag_bearer"
	non_flag.ball.cell = Vector2i(11,5)
	non_flag.ball.move_ticks_left = 2
	non_flag.ball.move_direction = Vector2i.RIGHT
	_expect(not non_flag.ball_move_is_blocked(), "Ball uses dynamic flag block0 even if base block3")
	non_flag.units[0].skill_ticks_left = 0
	_expect(non_flag.ball_move_is_blocked(), "Ball sees restored base block3")


func _test_flag(data: Dictionary) -> void:
	var state := _solo(data)
	state.units = [state.units[0],UnitState.new(1,0,"bagpipe",Vector2i(13,4),2484,0,30),UnitState.new(2,1,"bagpipe",Vector2i(11,6),2484,0,30),UnitState.new(3,0,"bagpipe",Vector2i(14,5),2484,0,30)]
	AuraRules.refresh(state)
	_expect(state.units[0].attack_speed_bonus == 0 and state.units[1].attack_speed_bonus == 10 and state.units[2].attack_speed_bonus == -10 and state.units[3].attack_speed_bonus == 0, "Flag eight neighbors, self excluded, friend+10/enemy-10, boundary2 excluded")
	_expect(state.units[1].attack_ticks_left == 27 and state.units[2].attack_ticks_left == 33, "Flag adjusts residual attack cooldown by new/old interval")
	state.units[0].cell = Vector2i(13,5)
	AuraRules.refresh(state)
	_expect(state.units[3].attack_speed_bonus == 10 and state.units[2].attack_speed_bonus == 0, "Flag anchored to source position; live neighborhood updates")
	state.units[0].hp = 0
	AuraRules.refresh(state)
	_expect(state.units[1].attack_speed_bonus == 0 and state.units[3].attack_speed_bonus == 0 and state.units[1].attack_ticks_left == 30, "Dead flag removes aura and restores residual cooldown")


func _test_discount(data: Dictionary) -> void:
	var state := MatchState.new(1,data)
	state.sides[0].cost = 12
	state.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"saileach",-1,Vector2i(12,5),-1,0)],[])
	_expect(state.sides[0].cost == 0 and state.sides[0].next_deploy_discount == 2, "Successful Saileach grants next ordinary discount2")
	state.sides[0].cost = 11
	state.step([InputCommand.new(state.tick,InputCommand.Kind.DEPLOY,"bagpipe",-1,Vector2i(12,5))],[])
	_expect(state.units.size() == 1 and state.sides[0].cost == 11 and state.sides[0].next_deploy_discount == 2, "Invalid occupied deployment never consumes discount")
	var ai := AIInput.new(0,data)
	while state.tick < Config.AI_DECISION_INTERVAL_TICKS:
		_expect(ai.commands_for_tick(state).is_empty(), "AI discount deployment observes decision cadence")
		state.step([], [])
	var before := state.state_hash()
	var commands := ai.commands_for_tick(state)
	_expect(commands.size() == 1 and commands[0].kind == InputCommand.Kind.DEPLOY and commands[0].operator_id == "bagpipe" and state.state_hash() == before, "AI accepts reduced11 cost by read-only legality, without source changes")
	state.step([InputCommand.new(state.tick,InputCommand.Kind.DEPLOY,"bagpipe",-1,Vector2i(13,5))],[])
	_expect(state.units.size() == 2 and state.sides[0].cost == 0 and state.sides[0].next_deploy_discount == 0, "Exactly next ordinary deployment costs11, consumes2")
	state.step([InputCommand.new(state.tick,InputCommand.Kind.RETREAT,"",1)],[])
	_expect(state.sides[0].cost == 13, "Discount does not change Bagpipe existing full base-cost13 retreat refund despite paid11")
	var refresh := MatchState.new(1,data)
	refresh.sides[0].cost = 10
	refresh.sides[0].next_deploy_discount = 2
	var hash_before := refresh.state_hash()
	refresh.sides[0].next_deploy_discount = 1
	_expect(hash_before != refresh.state_hash(), "Pending discount must enter side hash")
	refresh.sides[0].next_deploy_discount = 2
	refresh.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"saileach",-1,Vector2i(12,5))],[])
	_expect(refresh.sides[0].cost == 0 and refresh.sides[0].next_deploy_discount == 2, "Saileach uses old reduction before refreshing2; does not stack4")
	refresh.step([InputCommand.new(refresh.tick,InputCommand.Kind.RETREAT,"",0)],[])
	for _tick in 2100:
		refresh.step([],[])
	refresh.sides[0].cost = 10
	refresh.step([InputCommand.new(refresh.tick,InputCommand.Kind.DEPLOY,"saileach",-1,Vector2i(12,5))],[])
	_expect(refresh.units.size() == 1 and refresh.units[0].unit_id == 1 and refresh.units[0].skill_cost_accum == 0 and refresh.sides[0].next_deploy_discount == 2, "Fresh deployment resets skill remainder and refreshes nonstacking discount")
	var phantom := MatchState.new(1,data)
	phantom.units = [UnitState.new(0,0,"nightingale",Vector2i(12,2),1705,0,10000)]
	phantom.next_unit_id = 1
	phantom.sides[0].phantom_count = 1
	phantom.sides[0].next_deploy_discount = 2
	phantom.sides[0].cost = 5
	phantom.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"nightingale_phantom",-1,Vector2i(12,5))],[])
	_expect(phantom.units.size() == 2 and phantom.sides[0].cost == 0 and phantom.sides[0].next_deploy_discount == 2 and DeployRules.actual_cost(MatchState.PHANTOM_DATA,phantom.sides[0]) == 5, "Birdcage pays5 and never uses/consumes ordinary coupon")
	for sail_first in [true,false]:
		var order := MatchState.new(1,data)
		order.sides[0].cost = 23 if sail_first else 25
		var sail_command := InputCommand.new(0,InputCommand.Kind.DEPLOY,"saileach",-1,Vector2i(12,5))
		var bag_command := InputCommand.new(0,InputCommand.Kind.DEPLOY,"bagpipe",-1,Vector2i(13,5))
		var ordered: Array[InputCommand] = [sail_command,bag_command]
		if not sail_first:
			ordered.reverse()
		order.step(ordered,[])
		_expect(order.units.size() == 2 and order.sides[0].cost == 0 and order.sides[0].next_deploy_discount == (0 if sail_first else 2), "Same-tick existing command order defines next coupon consumption")


func _test_import(sail: OperatorData) -> void:
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
		_expect(importer._validate_row(row,columns), "CSV remains importable: "+row[0])
		if row[0] == "琴柳":
			found = true
			var imported: OperatorData = importer._build_operator(row,columns)
			_expect(imported.attack == 546 and imported.skills[0].initial_sp == 15 and imported.talent_1.effect_params == sail.talent_1.effect_params and imported.talent_2.effect_params == sail.talent_2.effect_params and imported.skills[0].effect_params == sail.skills[0].effect_params, "Typed import equals flag/discount/DP resource")
	_expect(found, "Saileach CSV required")


func _test_uncarried() -> void:
	var old_data := {}
	for id in CONFIG.DEFAULT_SQUAD_IDS:
		old_data[id] = load("res://resources/operators/%s.tres" % id)
	var expanded := old_data.duplicate()
	expanded["saileach"] = load("res://resources/operators/saileach.tres")
	var first := MatchState.new(77,old_data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[CONFIG.DEFAULT_SQUAD_IDS,CONFIG.DEFAULT_SQUAD_IDS])
	var second := MatchState.new(77,expanded,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[CONFIG.DEFAULT_SQUAD_IDS,CONFIG.DEFAULT_SQUAD_IDS])
	_expect(CONFIG.DEFAULT_SQUAD_IDS.size() == 8 and "saileach" not in CONFIG.DEFAULT_SQUAD_IDS, "Original default eight unchanged")
	first.sides[0].cost = 99
	second.sides[0].cost = 99
	for tick in 120:
		var commands: Array[InputCommand] = []
		if tick == 0:
			commands = [InputCommand.new(0,InputCommand.Kind.DEPLOY,"bagpipe",-1,Vector2i(11,5))]
		if tick == 80:
			commands = [InputCommand.new(tick,InputCommand.Kind.RETREAT,"",0)]
		first.step(commands,[])
		second.step(commands,[])
		_expect(first.state_hash() == second.state_hash(), "Uncarried Saileach changes original eight tick%d" % tick)


func _expect(condition: bool,message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
