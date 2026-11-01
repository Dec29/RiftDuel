extends SceneTree

const RANGE := preload("res://sim/attack_range.gd")
var failures := 0
var data := {}
var clone: OperatorData = MatchState.CLONE_DATA

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for id in ["phantom","schwarz","bagpipe","silverash","saileach","shining","nightingale","swire_alter","angelina","exusiai","hoshiguma"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var body: OperatorData = data["phantom"]
	check([body.max_health,body.attack,body.defense,body.magic_resist,body.attack_interval,body.block_count,body.deploy_cost,body.redeploy_time] == [1645,558,322,0,0.93,1,10,18.0], "Body raw E2max")
	check([clone.max_health,clone.attack,clone.defense,clone.magic_resist,clone.attack_interval,clone.block_count,clone.deploy_cost,clone.redeploy_time] == [1416,548,268,0,0.93,1,5,45.0], "Clone raw token E2max no trust or modules")
	check(clone.profession_id == "summon" and SkillRules.damage_profession_id(clone) == "specialist", "Summon identity and damage-only source profession")
	check(clone.branch_trait.parameters_are_valid(), "Clone source profession whitelist")
	var bad := clone.branch_trait.duplicate(true) as TraitResource
	bad.effect_params["source_profession_id"] = "summon"
	check(not bad.parameters_are_valid(), "Only eight ordinary source professions allowed")
	check(root.get_node("OperatorDB").all_ids().size() == 24 and "phantom_clone" not in root.get_node("OperatorDB").all_ids() and "nightingale_phantom" not in root.get_node("OperatorDB").all_ids(), "24 ordinary operators, owned summons excluded")
	for operator in [body,clone]:
		check(operator.skills.size() == 3 and operator.skills[0].initial_sp == 0 and operator.skills[0].skill_name == "暗夜魅影" and operator.skills[0].sp_required == 0 and operator.skills[0].sp_recharge_type == "passive" and operator.skills[0].duration == 10.0, "S1 remains unchanged alongside three passive skills")
		for facing in 4:
			var unit := UnitState.new(0,0,operator.operator_id,Vector2i(12,5),100,0,1,facing)
			var state := fresh()
			for x in range(-2,3):
				for y in range(-2,3):
					check(state._is_in_attack_range(unit,unit.cell+RANGE.rotate_offset(Vector2i(x,y),facing),operator.attack_range) == (y == 0 and x in [0,1]), "Exact two cells facing%d" % facing)
	test_deploy()
	test_shield()
	test_combat()
	test_healing()
	test_ai()
	test_import()
	test_hash()
	print("Phantom raw/range4/qualification/cooldown35/refund0/discount/shield/dodge/type/regen/source/AI/CSV/hash failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func fresh(seed: int = 1, squads: Array = [["phantom"],["bagpipe"]]) -> MatchState:
	var state := MatchState.new(seed,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,squads)
	state.sides[0].cost = 99
	state.sides[1].cost = 99
	return state

func deploy(state: MatchState, id: String, cell: Vector2i, facing: int = 2, side: int = 0) -> void:
	var cmds: Array[InputCommand] = [InputCommand.new(state.tick,InputCommand.Kind.DEPLOY,id,-1,cell,0,facing)]
	if side == 0:
		state.step(cmds,[])
	else:
		state.step([],cmds)

func retreat(state: MatchState, id: int, side: int = 0) -> void:
	var cmds: Array[InputCommand] = [InputCommand.new(state.tick,InputCommand.Kind.RETREAT,"",id)]
	if side == 0:
		state.step(cmds,[])
	else:
		state.step([],cmds)

func test_deploy() -> void:
	var state := fresh()
	check(not state.clone_visible(0) and not state.clone_available(0), "Absent parent hides clone")
	deploy(state,"phantom_clone",Vector2i(12,5))
	check(state.units.is_empty() and state.sides[0].cost == 99, "Illegal parent-absent command rejects")
	deploy(state,"phantom",Vector2i(12,5))
	check(state.clone_visible(0) and state.clone_available(0) and not state.clone_available(1), "Parent same-side presence")
	check(not state.clone_can_deploy(0,Vector2i(10,5)) and not state.clone_can_deploy(0,Vector2i(9,5)) and not state.clone_can_deploy(0,Vector2i(12,2)) and not state.clone_can_deploy(0,Vector2i(12,5)) and not state.clone_can_deploy(0,Vector2i(-1,5)), "Center,line,high,occupied,outside reject")
	state.sides[0].cost = 4
	check(state.clone_visible(0) and not state.clone_available(0), "Insufficient funds visible but disabled")
	deploy(state,"phantom_clone",Vector2i(13,5))
	check(state.units.size() == 1 and state.sides[0].cost == 4, "Insufficient command rejects")
	state.sides[0].cost = 99
	state.sides[0].next_deploy_discount = 2
	deploy(state,"phantom_clone",Vector2i(13,5),3)
	check(state.units.size() == 2 and state.units[1].facing == 3 and state.sides[0].cost == 94 and state.sides[0].next_deploy_discount == 2 and state.sides[0].clone_cooldown_ticks == 1050, "Clone5 no discount consumption, direction, deploy-based35s")
	check(not state.clone_visible(0), "Single instance hides card")
	deploy(state,"phantom_clone",Vector2i(14,5))
	check(state.units.size() == 2, "Second clone forbidden")
	var cooldown := state.sides[0].clone_cooldown_ticks
	var cost := state.sides[0].cost
	retreat(state,1,1)
	check(state.units.size() == 2, "Opposing retreat rejects")
	retreat(state,0)
	check(state.units.size() == 1 and state.units[0].operator_id == "phantom_clone" and state.sides[0].cooldowns["phantom"] == 540 and state.sides[0].clone_cooldown_ticks == cooldown-2, "Parent exits clone persists, body18s independent")
	cost = state.sides[0].cost
	cooldown = state.sides[0].clone_cooldown_ticks
	retreat(state,1)
	check(state.units.is_empty() and state.sides[0].cost == cost and state.sides[0].clone_cooldown_ticks == cooldown-1 and not state.sides[0].cooldowns.has("phantom_clone"), "Clone retreat refund0, no cooldown restart")
	for i in 1100: state.step([],[])
	check(not state.clone_available(0) and not state.clone_visible(0), "Cooldown finish still requires parent")
	deploy(state,"phantom",Vector2i(12,5))
	deploy(state,"phantom_clone",Vector2i(13,5))
	retreat(state,2)
	for i in 550: state.step([],[])
	deploy(state,"phantom",Vector2i(12,5))
	check(state.units.size() == 2 and not state.clone_available(0), "Parent redeployment cannot make second living clone")
	state = fresh(1,[["bagpipe"],["phantom"]])
	state.units = [UnitState.new(0,0,"phantom",Vector2i(12,5),1645,0,100000)]
	deploy(state,"phantom_clone",Vector2i(13,5))
	check(state.units.size() == 1, "Parent not carried rejects even if fixture unit exists")
	state = fresh(1,[["phantom","silverash"],["bagpipe"]])
	deploy(state,"phantom",Vector2i(12,5))
	deploy(state,"phantom_clone",Vector2i(13,5))
	retreat(state,0)
	check(state.sides[0].cooldowns["phantom"] == 486 and state.sides[0].clone_cooldown_ticks == 1049, "SilverAsh only ordinary cooldown reduction")
	var remaining := state.sides[0].clone_cooldown_ticks
	cost = state.sides[0].cost
	state._apply_damage(state.units[0],clone,100000,"true")
	state.step([],[])
	check(state.units.is_empty() and state.sides[0].cost == cost and state.sides[0].clone_cooldown_ticks == remaining-1 and not state.sides[0].cooldowns.has("phantom_clone"), "Clone death zero refund and no cooldown restart")

func test_shield() -> void:
	var state := fresh()
	deploy(state,"phantom",Vector2i(12,5))
	deploy(state,"phantom_clone",Vector2i(13,5))
	var body := state.units[0]
	var twin := state.units[1]
	check(body.physical_shield_hp == 1316 and twin.physical_shield_hp == 1133 and twin.physical_guard_ticks_left == 300, "Own maxHP80 snapshot")
	check(state._apply_damage(twin,clone,100,"physical") and twin.hp == 1416 and twin.physical_shield_hp == 1033 and twin.last_damage_tick == -1, "Shield absorbs landed hit without HP/SP event")
	state._apply_damage(twin,clone,50,"magical")
	state._apply_damage(twin,clone,50,"true")
	check(twin.hp == 1316 and twin.physical_shield_hp == 1033, "Magic and true bypass physical shield")
	state._apply_damage(twin,clone,1100,"physical")
	check(twin.hp == 1249 and twin.physical_shield_hp == 0 and twin.physical_guard_ticks_left == 300 and SkillRules.dodge_chance(twin,clone,"physical") == 50 and SkillRules.dodge_chance(twin,clone,"magical") == 0, "Consumed shield leaves timed physical dodge")
	for i in 299: state.step([],[])
	check(twin.physical_guard_ticks_left == 1 and SkillRules.dodge_chance(twin,clone,"physical") == 50, "Full guard300 ticks")
	state.step([],[])
	check(twin.physical_guard_ticks_left == 0 and twin.physical_shield_hp == 0 and SkillRules.dodge_chance(twin,clone,"physical") == 0, "Guard expiry removes shield and dodge")
	state = fresh(1,[["phantom","exusiai"],["bagpipe"]])
	state.units = [UnitState.new(0,0,"exusiai",Vector2i(15,5),1673,0,100000)]
	state.next_unit_id = 1
	deploy(state,"phantom",Vector2i(12,5))
	body = state.units[1]
	check(body.max_health_bonus_percent == 10 and body.physical_shield_hp == roundi(SkillRules.max_health_value(body,data["phantom"])*0.8), "Blessing resolved before deploy shield snapshot")
	var snapshot := body.physical_shield_hp
	deploy(state,"phantom_clone",Vector2i(13,5))
	check(body.attack_bonus_percent == 6 and state.units[2].attack_bonus_percent == 0 and state.units[2].max_health_bonus_percent == 0 and state.units[2].physical_shield_hp == 1133, "Clone does not copy parent blessing or shield")
	retreat(state,0)
	check(body.max_health_bonus_percent == 0 and body.physical_shield_hp == snapshot, "Later maxHP change does not rebuild shield")

func test_combat() -> void:
	for dtype in ["physical","magical","true"]:
		for seed in [1,2,3,7,41,93,8192]:
			var state := fresh(seed)
			var enemy := (data["bagpipe"] as OperatorData).duplicate(true) as OperatorData
			enemy.damage_type = dtype
			enemy.talent_1 = clone.talent_1
			state._operator_data["bagpipe"] = enemy
			state.units = [UnitState.new(0,0,"phantom_clone",Vector2i(12,5),1416,0,100000,0),UnitState.new(1,1,"bagpipe",Vector2i(13,5),2484,0,1,2)]
			var twin := state.units[0]
			twin.physical_guard_ticks_left = 300
			twin.physical_shield_hp = 1133
			state.next_unit_id = 2
			var expected_rng := RNG.new(seed)
			var damage := Combat.calculate_damage(enemy.attack,268,0,dtype,50 if dtype == "physical" else 0,expected_rng,"vanguard")
			state.step([],[])
			check(state.rng.state == expected_rng.state, "Only sim RNG dodge seed%d/%s" % [seed,dtype])
			check(twin.hp == (1416 if dtype == "physical" else 1416-damage) and twin.physical_shield_hp == (1133-damage if dtype == "physical" else 1133), "Typed incoming damage seed%d/%s" % [seed,dtype])
	var state := fresh()
	state.units = [UnitState.new(0,0,"phantom_clone",Vector2i(12,5),1416,0,1,0),UnitState.new(1,1,"bagpipe",Vector2i(13,5),100000,0,100000,2)]
	state.next_unit_id = 2
	state.step([],[])
	check(state.units[1].hp == 100000-Combat.calculate_damage(548,382,0,"physical",0,RNG.new(1),"specialist") and state.units[0].last_attack_tick == 0, "Clone attacks using specialist25 percent")
	var special := (data["hoshiguma"] as OperatorData).duplicate(true) as OperatorData
	special.talent_2.effect_params = {"profession_id":"specialist","defense_percent":60}
	state._operator_data["hoshiguma"] = special
	state.units.append(UnitState.new(2,0,"hoshiguma",Vector2i(15,5),3850,0,100000))
	state.units.append(UnitState.new(3,0,"phantom",Vector2i(16,5),1645,0,100000))
	AuraRules.refresh(state)
	check(state.units[0].defense_bonus_percent == 0 and state.units[3].defense_bonus_percent == 60, "Damage origin does not widen specialist aura identity")
	# A fully absorbed hit still applies Schwarz armor break; no on_damaged SP.
	var target := (data["phantom"] as OperatorData).duplicate(true) as OperatorData
	target.skills[0].sp_recharge_type = "on_damaged"
	target.skills[0].sp_required = 3
	state = fresh()
	var unit := UnitState.new(0,0,"phantom",Vector2i(12,5),1645,0,100000)
	unit.physical_shield_hp = 1000
	unit.physical_guard_ticks_left = 300
	check(state._apply_damage(unit,target,100,"physical") and unit.sp == 0 and unit.hp == 1645, "Absorbed hit landed, no on_damaged SP")
	state._apply_damage(unit,target,950,"physical")
	check(unit.sp == 1 and unit.hp == 1595, "Only actual HP damage grants on_damaged SP")

	state = fresh()
	var black := (data["schwarz"] as OperatorData).duplicate(true) as OperatorData
	black.talent_1.effect_params["chance_percent"] = 100
	var twin_data := clone.duplicate(true) as OperatorData
	twin_data.skills[0].effect_params["dodge_physical_add"] = 0
	state._operator_data["schwarz"] = black
	state._operator_data["phantom_clone"] = twin_data
	state.units = [UnitState.new(0,0,"schwarz",Vector2i(12,5),1833,0,1,0),UnitState.new(1,1,"phantom_clone",Vector2i(13,5),1416,0,100000)]
	state.units[1].physical_shield_hp = 1133
	state.units[1].physical_guard_ticks_left = 300
	state.next_unit_id = 2
	state.step([],[])
	check(state.units[1].hp == 1416 and state.units[1].physical_shield_hp < 1133 and state.units[1].armor_break_ticks_left == 150 and state.units[1].armor_break_defense_percent == 80 and state.units[0].sp == 1, "Fully absorbed real hit still applies armor break and attacking SP")

func test_healing() -> void:
	for medic in ["shining","nightingale","swire_alter"]:
		var state := fresh(1,[["phantom",medic],["bagpipe"]])
		state.units = [UnitState.new(0,0,medic,Vector2i(12,5),data[medic].max_health,0,1,0),UnitState.new(1,0,"phantom_clone",Vector2i(13,5),500,0,100000,0)]
		state.units[0].coins = 3
		state.next_unit_id = 2
		state.ball.cell = Vector2i(10,9)
		state.step([],[])
		check(state.units[1].hp == 500 and state.units[1].last_heal_tick == -1 and state.units[0].coins == 3, "No ordinary/group/coin healing:"+medic)
	var state := fresh(1,[["phantom","angelina"],["bagpipe"]])
	state.units = [UnitState.new(0,0,"angelina",Vector2i(12,5),1385,0,100000),UnitState.new(1,0,"phantom_clone",Vector2i(13,5),500,0,100000)]
	state.next_unit_id = 2
	for i in 30: state.step([],[])
	check(state.units[1].hp == 510 and state.units[1].last_heal_tick >= 0, "Regen allowed despite healing immunity")

func test_ai() -> void:
	var state := fresh()
	deploy(state,"phantom",Vector2i(12,5))
	var ai := AIInput.new(0,{"phantom":data["phantom"]})
	while state.tick < Config.AI_DECISION_INTERVAL_TICKS:
		check(ai.commands_for_tick(state).is_empty(), "Clone AI observes its initial decision interval")
		state.step([],[])
	var before := state.state_hash()
	var commands := ai.commands_for_tick(state)
	check(state.state_hash() == before and commands.size() == 1 and commands[0].operator_id == "phantom_clone" and state.clone_can_deploy(0,commands[0].cell), "AI uses lawful clone command and remains read-only")
	state.step(commands,[])
	before = state.state_hash()
	ai.commands_for_tick(state)
	check(state.state_hash() == before and ai._operator_ids == PackedStringArray(["phantom"]) and ai._operator_data.has("phantom_clone"), "AI knows field clone without ordinary candidate roster pollution")

func test_import() -> void:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	check(script.reload() == OK, "Importer compiles")
	var importer: RefCounted = script.new()
	var file := FileAccess.open("res://import/operators.csv",FileAccess.READ)
	var header := file.get_csv_line()
	var columns := {}
	for index in header.size(): columns[header[index]] = index
	var found := false
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row[0] != "傀影": continue
		found = true
		check(importer._validate_row(row,columns), "Normalized CSV valid")
		var imported: OperatorData = importer._build_operator(row,columns)
		check(imported.talent_1.parameters_are_valid() and imported.talent_2.parameters_are_valid() and imported.skills[0].effect_params["dodge_physical_add"] is int and imported.attack_range == data["phantom"].attack_range and imported.redeploy_time == 18.0, "CSV typed fields and raw equality")
	check(found, "CSV body row exists")

func test_hash() -> void:
	var state := fresh()
	deploy(state,"phantom",Vector2i(12,5))
	for field in ["physical_shield_hp","physical_guard_ticks_left"]:
		var before := state.state_hash()
		state.units[0].set(field,state.units[0].get(field)+1)
		check(state.state_hash() != before, "Hashed unit field"+field)
	var before := state.state_hash()
	state.sides[0].clone_cooldown_ticks += 1
	check(state.state_hash() != before, "Hashed clone cooldown")
	var a := fresh(93)
	var b := fresh(93)
	for i in 1200:
		var blue: Array[InputCommand] = []
		var red: Array[InputCommand] = []
		if i == 0: blue = [InputCommand.new(i,InputCommand.Kind.DEPLOY,"phantom",-1,Vector2i(12,5),0,2)]
		if i == 1: blue = [InputCommand.new(i,InputCommand.Kind.DEPLOY,"phantom_clone",-1,Vector2i(13,5),0,2)]
		if i == 2: red = [InputCommand.new(i,InputCommand.Kind.DEPLOY,"bagpipe",-1,Vector2i(9,5),0,0)]
		if i == 20: blue = [InputCommand.new(i,InputCommand.Kind.RETREAT,"",0)]
		if i == 30: blue = [InputCommand.new(i,InputCommand.Kind.RETREAT,"",1)]
		a.step(blue,red)
		b.step(blue,red)
		check(a.state_hash() == b.state_hash(), "Fixed replay tick%d" % i)
