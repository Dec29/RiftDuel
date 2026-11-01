extends SceneTree

const RANGE := preload("res://sim/attack_range.gd")
var failures := 0
var data := {}

func _initialize() -> void:
	for id in ["horn","bagpipe","hoshiguma","exusiai","nightingale"]:
		data[id] = load("res://resources/operators/%s.tres" % id)
	var horn: OperatorData = data["horn"]
	check([horn.max_health,horn.attack,horn.defense,horn.magic_resist,horn.attack_interval,horn.block_count,horn.deploy_cost,horn.redeploy_time] == [3067,936,620,0,2.8,3,28,70.0], "Horn E2 raw stats")
	check(horn.skills[0].initial_sp == 0 and horn.skills[0].sp_required == 5 and SkillRules.sp_limit(horn.skills[0]) == 10 and horn.talent_2.parameters_are_valid(), "S1M3 0/5 charge2 and typed bloodbath")
	for facing in 4:
		var state := solo()
		state.units[0].facing = facing
		for y in range(-2,3):
			for x in range(-1,7):
				var offset := Vector2i(x,y)
				check(state._is_in_attack_range(state.units[0],state.units[0].cell+RANGE.rotate_offset(offset,facing),RANGE.acquisition_offsets(horn)) == (offset == Vector2i.ZERO or offset in horn.attack_range), "Facing%d offset%s: 7 distant cells plus independent self" % [facing,offset])
	check(horn.attack_range.size() == 7 and Vector2i.ZERO not in horn.attack_range, "Strict 7-cell remote resource remains read-only")
	test_splash(false)
	test_splash(true)
	test_ball()
	test_melee()
	test_charge()
	test_aura()
	test_bloodbath()
	test_import()
	test_replay()
	print("Horn stats/range4/blind spots/AoE boundaries/sorted victims/ball/melee/charge/aura/bloodbath/CSV/hash/fixed replay: failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func solo() -> MatchState:
	var state := MatchState.new(93,data)
	state.units = [UnitState.new(0,0,"horn",Vector2i(12,5),3067,0,1,0)]
	state.ball.cell = Vector2i(5,5)
	state.next_unit_id = 1
	return state

func enemy(id: int, cell: Vector2i, op: String = "bagpipe") -> UnitState:
	return UnitState.new(id,1,op,cell,10000,0,10000,0)

func test_splash(charged: bool) -> void:
	var state := solo()
	var horn := state.units[0]
	horn.sp = 5 if charged else 0
	# Center in acquisition at (15,4); outer neighbor (14,4) in blind spot.
	state.units.append(enemy(1,Vector2i(15,4)))
	state.units.append(enemy(2,Vector2i(14,4)))
	state.units.append(enemy(3,Vector2i(14,3)))
	state.units.append(enemy(4,Vector2i(13,4)))
	var before := state.ball.accum
	state.step([],[])
	check(state.units[1].hp < 10000 and state.units[2].hp < 10000, "Cross boundary / outside acquisition damaged")
	check((state.units[3].hp < 10000) == charged and state.units[4].hp == 10000, "1.0 cross versus1.7 eight-neighbor Euclidean boundary")
	check(state.ball.accum == before and state.ball.move_ticks_left == 0, "Enemy-centered explosion never pushes ball")
	for target in state.units:
		check(target.bind_ticks_left == 0 and target.slow_ticks_left == 0, "Horn never applies Ceobe bind or slow")
	var phantom: OperatorData = load("res://resources/summons/nightingale_phantom.tres")
	state.units[3].operator_id = phantom.operator_id
	state.units[3].cell = Vector2i(15,4)
	horn.skill_ticks_left = -1
	var targets := FortressRules.targets(state, horn,data["horn"],state.units[3].cell)
	check(targets.size() == 3 and targets[0].unit_id == 1 and targets[1].unit_id == 2 and targets[2].unit_id == 3, "AoE victim order remains ascending even when center has highest ID")

func test_ball() -> void:
	var state := solo()
	state.ball.cell = Vector2i(17,5)
	state.units[0].sp = 5
	state.units.append(enemy(1,Vector2i(18,6)))
	state.units.append(enemy(2,Vector2i(19,5)))
	state.step([],[])
	check(state.units[0].last_attack_target_x == 17 and state.units[1].hp < 10000 and state.units[2].hp == 10000, "Ball main target remote blast damages neighboring enemy outside acquisition")
	check(state.ball.accum != Vector2i.ZERO or state.ball.move_ticks_left > 0, "Actual empowered ball attack pushes")
	check(state.units[0].sp == 0 and state.units[1].bind_ticks_left == 0, "Ball consumes only one charge; victims remain units")

func test_melee() -> void:
	for charged in [false,true]:
		var state := solo()
		state.units[0].sp = 5 if charged else 0
		state.units.append(enemy(1,Vector2i(12,5)))
		state.units.append(enemy(2,Vector2i(13,5)))
		state.step([],[])
		check(state.units[1].hp < 10000 and state.units[2].hp == 10000, "Self-cell normal/S1 melee single target")
		check(state.units[0].sp == 0, "Charged melee consumes one share")

func test_charge() -> void:
	var state := solo()
	for index in 330:
		state.step([],[])
	check(state.units[0].sp == 10 and state.units[0].last_attack_tick == -1, "Two charges accumulate and no target never spends")
	var unit := state.units[0]
	unit.sp_regen_ticks = 17
	unit.sp_regen_accum = 23
	state.units.append(enemy(1,Vector2i(15,5)))
	unit.attack_ticks_left = 1
	state.step([],[])
	check(unit.sp == 5 and unit.sp_regen_ticks == 17 and unit.sp_regen_accum == 23, "Charge consumption preserves natural SP remainder at cap")
	unit.attack_ticks_left = 1
	state.step([],[])
	check(unit.sp == 0 and unit.sp_regen_ticks == 18, "Second share consumes5 and continues time SP")

func test_aura() -> void:
	var state := solo()
	state.units.append(UnitState.new(1,0,"hoshiguma",Vector2i(13,5),3850,0,10000))
	state.units.append(UnitState.new(2,0,"bagpipe",Vector2i(14,5),2484,0,10000))
	state.units.append(enemy(3,Vector2i(3,5),"hoshiguma"))
	AuraRules.refresh(state)
	check(state.units[0].attack_bonus_percent == 20 and state.units[1].attack_bonus_percent == 20 and state.units[2].attack_bonus_percent == 0 and state.units[3].attack_bonus_percent == 0, "Alive same-side defender aura includes self")
	state.units[0].hp = 0
	AuraRules.refresh(state)
	check(state.units[1].attack_bonus_percent == 0, "Source defeat removes attack aura")

func test_bloodbath() -> void:
	var state := solo()
	var unit := state.units[0]
	state.units.append(UnitState.new(1,0,"hoshiguma",Vector2i(13,5),3850,0,10000))
	state.units.append(UnitState.new(2,0,"exusiai",Vector2i(14,5),1673,0,10000))
	state.units[2].blessing_target_id = 0
	AuraRules.refresh(state)
	var horn: OperatorData = data["horn"]
	var old_interval := SkillRules.attack_interval_ticks(unit,horn)
	unit.attack_ticks_left = 42
	check(SkillRules.max_health_value(unit,horn) == 3374, "Full HP blessing before bloodbath")
	state._apply_damage(unit,horn,100000,"physical")
	check(unit.bloodbath_used and unit.hp == 1687 and SkillRules.max_health_value(unit,horn) == 1687, "Final blessed maxHP times50 then full restore without healing scaling")
	check(unit.last_heal_tick == -1 and unit.last_bloodbath_tick == 0 and unit.last_damage_tick == 0, "Distinct revival event; no heal event")
	check(SkillRules.defense_value(unit,horn) == roundi(620*1.24), "Bloodbath18 plus Hoshiguma6 additive DEF")
	var new_interval := SkillRules.attack_interval_ticks(unit,horn)
	check(new_interval == 71 and unit.attack_ticks_left == ceili(42.0*new_interval/old_interval), "AS18 rescales existing cooldown once")
	var cooldown := unit.attack_ticks_left
	AuraRules.refresh(state)
	check(unit.attack_ticks_left == cooldown and unit.hp == 1687, "Refresh does not double rescale / halve HP")
	var hash_before := state.state_hash()
	unit.last_bloodbath_tick += 1
	check(hash_before != state.state_hash(), "Revival tick hashes")
	unit.last_bloodbath_tick -= 1
	unit.bloodbath_used = false
	check(hash_before != state.state_hash(), "Used flag hashes")
	unit.bloodbath_used = true
	state._apply_damage(unit,horn,100000,"physical")
	check(unit.hp <= 0, "Second lethal damage defeats")
	var reset := solo()
	reset.units[0].bloodbath_used = true
	reset.units[0].last_bloodbath_tick = 10
	reset.sides[0].cost = 99
	reset.step([InputCommand.new(0,InputCommand.Kind.RETREAT,"",0)],[])
	reset.sides[0].cooldowns.clear()
	reset.step([InputCommand.new(1,InputCommand.Kind.DEPLOY,"horn",-1,Vector2i(12,5),0,0)],[])
	check(reset.units.size() == 1 and not reset.units[0].bloodbath_used and reset.units[0].last_bloodbath_tick == -1 and reset.units[0].hp == 3067, "New deployment resets once-lethal state")

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
		if row[0] != "号角": continue
		check(importer._validate_row(row,columns), "Horn CSV valid")
		var imported: OperatorData = importer._build_operator(row,columns)
		check(imported.attack_range == (data["horn"] as OperatorData).attack_range and imported.talent_2.parameters_are_valid() and imported.skills[0].effect_params["charge_count"] is int and imported.skills[0].effect_params["splash_radius_squared"] is int and imported.branch_trait.effect_params["splash_radius_squared"] is int, "CSV runtime parameters typed and same range")

func test_replay() -> void:
	var first := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["horn"],["bagpipe"]])
	var second := MatchState.new(123,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[["horn"],["bagpipe"]])
	first.sides[0].cost = 99
	second.sides[0].cost = 99
	for tick in 900:
		var commands: Array[InputCommand] = []
		if tick == 0: commands = [InputCommand.new(tick,InputCommand.Kind.DEPLOY,"horn",-1,Vector2i(17,5),0,2)]
		first.step(commands,[])
		second.step(commands,[])
		check(first.state_hash() == second.state_hash(), "Fixed Horn commands dual replay tick%d" % tick)
	var old_db := {}
	for id in preload("res://data/config.gd").DEFAULT_SQUAD_IDS:
		old_db[id] = load("res://resources/operators/%s.tres" % id)
	var expanded := old_db.duplicate()
	expanded["horn"] = data["horn"]
	var legacy := MatchState.new(45,old_db,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[preload("res://data/config.gd").DEFAULT_SQUAD_IDS,preload("res://data/config.gd").DEFAULT_SQUAD_IDS])
	var extra := MatchState.new(45,expanded,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[preload("res://data/config.gd").DEFAULT_SQUAD_IDS,preload("res://data/config.gd").DEFAULT_SQUAD_IDS])
	for tick in 300:
		var commands: Array[InputCommand] = []
		if tick == 90: commands = [InputCommand.new(tick,InputCommand.Kind.DEPLOY,"bagpipe",-1,Vector2i(11,5))]
		if tick == 200: commands = [InputCommand.new(tick,InputCommand.Kind.RETREAT,"",0)]
		legacy.step(commands,[])
		extra.step(commands,[])
		check(legacy.state_hash() == extra.state_hash(), "Uncarried Horn does not alter legacy state")
