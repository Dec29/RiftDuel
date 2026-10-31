extends SceneTree

const RANGE := preload("res://sim/attack_range.gd")
var failures := 0
var data := {}

func _initialize() -> void:
	for id in ["schwarz","bagpipe","exusiai","hoshiguma","shining","suzuran"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var black: OperatorData = data["schwarz"]
	check([black.max_health,black.attack,black.defense,black.magic_resist,black.attack_interval,black.block_count,black.deploy_cost,black.redeploy_time] == [1833,840,225,0,1.6,1,20,70.0], "E2max no trust/potential/module base stats")
	check(black.skills[0].initial_sp == 0 and black.skills[0].sp_required == 3 and SkillRules.is_auto_trigger(black.skills[0]), "Automatic next attack 0/3 attack SP")
	check(black.talent_1.parameters_are_valid() and black.talent_2.parameters_are_valid(), "Typed talents")
	for facing in 4:
		var state := fixture(1)
		state.units[0].facing = facing
		for x in range(-2,5):
			for y in range(-3,4):
				var offset := Vector2i(x,y)
				check(state._is_in_attack_range(state.units[0],state.units[0].cell+RANGE.rotate_offset(offset,facing),RANGE.acquisition_offsets(black)) == (x >= 0 and x <= 2 and absi(y) <= 1), "Exact nine cells facing%d %s" % [facing,offset])
	check(black.attack_range.size() == 9 and black.branch_trait.effect_params.is_empty(), "No accuracy or heavy target invention")
	for seed in [1,2,3,4,5,7,13,41,93,123,8192]:
		for charged in [false,true]:
			test_attack(seed,charged,false)
			test_attack(seed,charged,true)
	test_timing()
	test_defense()
	test_aura()
	test_misses()
	test_sp()
	test_import()
	test_hash_replay()
	print("Schwarz base/range4/single RNG/proc20-80/damage/ball/SP/150tick/refresh/expiry/DEF final/aura/miss/CSV/hash: failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func fixture(seed: int, target: bool = true) -> MatchState:
	var state := MatchState.new(seed,data)
	state.units = [UnitState.new(0,0,"schwarz",Vector2i(12,5),1833,0,1,0)]
	if target:
		state.units.append(UnitState.new(1,1,"bagpipe",Vector2i(14,5),100000,0,100000,0))
	state.ball.cell = Vector2i(5,5)
	state.next_unit_id = state.units.size()
	return state

func test_attack(seed: int, charged: bool, ball_target: bool) -> void:
	var state := fixture(seed,not ball_target)
	var unit := state.units[0]
	unit.sp = 3 if charged else 0
	var expected_rng := RNG.new(seed)
	var proc := expected_rng.next_percent() < (80 if charged else 20)
	var attack := roundi(840 * (2.2 if charged else 1.0))
	if proc:
		attack = roundi(attack * 1.6)
	if ball_target:
		state.ball.cell = Vector2i(14,5)
	state.step([],[])
	check(state.rng.state == expected_rng.state, "Exactly one20/80 draw seed%d charged%s ball%s" % [seed,charged,ball_target])
	check(unit.sp == (0 if charged else 1) and unit.skill_ticks_left == 0, "Attack SP consumption once")
	if ball_target:
		check(state.ball.move_ticks_left > 0 if attack >= 2000 else state.ball.accum.x == attack, "Actual multiplier ball push")
		check(unit.armor_break_ticks_left == 0 and state.units.size() == 1, "No armor state assigned to ball or attacker")
	else:
		var expected := Combat.calculate_damage(attack,382,0,"physical",0,RNG.new(1),"sniper")
		check(state.units[1].hp == 100000-expected, "Trigger hit uses previous defense before armor break")
		check(state.units[1].armor_break_ticks_left == (150 if proc else 0), "Only successful proc assigns armor break")

func test_timing() -> void:
	var state := fixture(1)
	# Seed with a first roll below20, found deterministically without mutating match RNG.
	for seed in range(1,10000):
		var sample := RNG.new(seed)
		if sample.next_percent() < 20:
			state.rng = RNG.new(seed)
			break
	state.step([],[])
	var target := state.units[1]
	check(target.armor_break_ticks_left == 150 and SkillRules.defense_value(target,data["bagpipe"]) == 306, "150ticks after damage")
	state.units[0].attack_ticks_left = 100000
	for count in 149:
		state.step([],[])
	check(target.armor_break_ticks_left == 1 and target.armor_break_defense_percent == 80, "Independent timer149 elapsed")
	target.armor_break_ticks_left = 17
	state.units[0].attack_ticks_left = 1
	state.units[0].sp = 3
	state.rng = RNG.new(1)
	# First RNG draw seed1 may fail80; choose known roll below80.
	for seed in range(1,10000):
		if RNG.new(seed).next_percent() < 80:
			state.rng = RNG.new(seed)
			break
	var before := target.hp
	state.step([],[])
	check(target.armor_break_ticks_left == 150 and target.armor_break_defense_percent == 80, "Repeat refresh without stacking")
	check(before-target.hp == Combat.calculate_damage(2957,306,0,"physical",0,RNG.new(1),"sniper"), "Subsequent proc uses old reduced DEF")
	var retreat := InputCommand.new()
	retreat.tick = state.tick
	retreat.kind = InputCommand.Kind.RETREAT
	retreat.unit_id = 0
	state.step([retreat],[])
	check(target.armor_break_ticks_left == 149 and target.armor_break_defense_percent == 80, "Source retreat preserves debuff")
	for count in 149:
		state.step([],[])
	check(target.armor_break_ticks_left == 0 and target.armor_break_defense_percent == 100 and SkillRules.defense_value(target,data["bagpipe"]) == 382, "Expiry restores before attack processing")

func test_defense() -> void:
	var state := fixture(1)
	var target := state.units[1]
	target.operator_id = "hoshiguma"
	target.armor_break_ticks_left = 150
	target.armor_break_defense_percent = 80
	state.units.append(UnitState.new(2,1,"shining",Vector2i(15,5),1613,0,100000,2))
	AuraRules.refresh(state)
	check(target.defense_bonus_add == 60 and target.defense_bonus_percent == 6, "Existing flat and percent aura retained")
	target.skill_ticks_left = 30
	var expected := roundi((723+60)*(1.06+0.8)*0.8)
	check(SkillRules.defense_value(target,data["hoshiguma"]) == expected, "DEF flat plus additive positive bonuses then final0.8")
	state.units.append(UnitState.new(3,0,"suzuran",Vector2i(12,4),1480,0,100000,0))
	target.slow_ticks_left = 24
	check(state._fragile_damage_percent(target) == 120, "Fragile remains independent final damage modifier")

func test_aura() -> void:
	var state := fixture(1,false)
	var sniper: OperatorData = data["exusiai"].duplicate(true)
	sniper.talent_2.effect_type = "reveal_invisible"
	sniper.talent_2.effect_params = {}
	state._operator_data["exusiai"] = sniper
	AuraRules.refresh(state)
	check(state.units[0].attack_bonus_percent == 0, "Alone / undeployed second sniper no aura")
	state.units.append(UnitState.new(1,1,"exusiai",Vector2i(5,5),1573,0,100000))
	state.units.append(UnitState.new(2,0,"bagpipe",Vector2i(13,5),2484,0,100000))
	AuraRules.refresh(state)
	check(state.units[0].attack_bonus_percent == 0, "Enemy sniper or friendly different profession do not qualify")
	state.units.append(UnitState.new(3,0,"exusiai",Vector2i(13,4),1573,0,100000))
	AuraRules.refresh(state)
	check(state.units[0].attack_bonus_percent == 8 and state.units[3].attack_bonus_percent == 8 and state.units[2].attack_bonus_percent == 0 and state.units[1].attack_bonus_percent == 0, "All same-side snipers including source by profession")
	state.units[3].hp = 0
	AuraRules.refresh(state)
	check(state.units[0].attack_bonus_percent == 0, "Second sniper death removes condition")
	state.units[3].hp = 100
	state.units[0].hp = 0
	AuraRules.refresh(state)
	check(state.units[3].attack_bonus_percent == 0, "Source death immediately removes aura")

func test_misses() -> void:
	for blocked in [false,true]:
		var state := fixture(1)
		var target_data: OperatorData = data["bagpipe"].duplicate(true)
		if blocked:
			target_data.talent_1.effect_type = "damage_block"
			target_data.talent_1.effect_params = {"chance_percent":100}
		else:
			target_data.dodge_physical = 100
		state._operator_data["bagpipe"] = target_data
		state.units[0].sp = 3
		state.step([],[])
		check(state.units[1].hp == 100000 and state.units[1].armor_break_ticks_left == 0 and state.units[0].sp == 0, "Dodge/block never applies break; skill remains consumed")
		var sample := RNG.new(1)
		sample.next_percent()
		sample.next_percent()
		check(state.rng.state == sample.state, "Proc plus existing dodge/block draws; never silent reroll")

func test_sp() -> void:
	var state := fixture(1,false)
	state.step([],[])
	check(state.rng.state == 1 and state.units[0].sp == 0, "No target does not draw or charge")
	state.ball.cell = Vector2i(12,5)
	for count in 3:
		state.units[0].attack_ticks_left = 1
		state.step([],[])
	check(state.units[0].sp == 3, "Three normal attacks charge3")
	state.units[0].attack_ticks_left = 1
	state.ball.move_ticks_left = 0
	state.ball.cell = Vector2i(12,5)
	state.step([],[])
	check(state.units[0].sp == 0, "Fourth attack automatically consumes3")

func test_import() -> void:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	check(script.reload() == OK, "Importer compiles")
	var importer: RefCounted = script.new()
	var file := FileAccess.open("res://import/operators.csv",FileAccess.READ)
	var header := file.get_csv_line()
	var columns := {}
	for index in header.size(): columns[header[index]] = index
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row[0] != "黑": continue
		check(importer._validate_row(row,columns), "Normalized Schwarz CSV valid")
		var imported: OperatorData = importer._build_operator(row,columns)
		check(imported.talent_1.parameters_are_valid() and imported.talent_2.parameters_are_valid() and imported.skills[0].effect_params["talent_chance_percent"] is int and imported.attack_range == data["schwarz"].attack_range, "CSV builds integer talent/skill parameters and precise range")

func test_hash_replay() -> void:
	var state := fixture(1)
	var before := state.state_hash()
	state.units[1].armor_break_ticks_left = 150
	check(state.state_hash() != before, "TTL participates hash")
	before = state.state_hash()
	state.units[1].armor_break_defense_percent = 80
	check(state.state_hash() != before, "Multiplier participates hash")
	var first := fixture(93)
	var second := fixture(93)
	for count in 600:
		first.step([],[])
		second.step([],[])
		check(first.state_hash() == second.state_hash(), "Fixed replay tick%d" % count)
	var deployed_a := MatchState.new(93,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["schwarz"],["bagpipe"]])
	var deployed_b := MatchState.new(93,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["schwarz"],["bagpipe"]])
	deployed_a.sides[0].cost = 99
	deployed_b.sides[0].cost = 99
	for count in 600:
		var commands: Array[InputCommand] = []
		if count == 0: commands = [InputCommand.new(0,InputCommand.Kind.DEPLOY,"schwarz",-1,Vector2i(16,2),0,2)]
		deployed_a.step(commands,[])
		deployed_b.step(commands,[])
		check(deployed_a.state_hash() == deployed_b.state_hash(), "Fixed deployment input dual replay tick%d" % count)
	var without := {"bagpipe":data["bagpipe"]}
	var old := MatchState.new(1,without,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["bagpipe"],["bagpipe"]])
	var expanded := MatchState.new(1,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["bagpipe"],["bagpipe"]])
	for count in 60:
		old.step([],[])
		expanded.step([],[])
		check(old.state_hash() == expanded.state_hash(), "Uncarried Schwarz does not affect old input")
