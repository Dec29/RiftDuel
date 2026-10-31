extends SceneTree

const RANGE := [Vector2i(0,-1),Vector2i(0,0),Vector2i(0,1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(2,0),Vector2i(3,0)]
const ROTATE := preload("res://sim/attack_range.gd")
const CONFIG := preload("res://data/config.gd")
var _failures := 0


func _initialize() -> void:
	var definitions := {}
	for id in ["silverash", "bagpipe", "swire_alter"]:
		definitions[id] = load("res://resources/operators/%s.tres" % id)
	var silverash: OperatorData = definitions["silverash"]
	_expect([silverash.max_health,silverash.attack,silverash.defense,silverash.magic_resist,silverash.attack_interval,silverash.block_count,silverash.deploy_cost,silverash.redeploy_time] == [2560,713,397,10,1.3,2,20,70.0], "E2 base excludes trust, potential, module and talent")
	_expect(silverash.profession_id == "guard" and silverash.branch == "领主" and Array(silverash.attack_range) == RANGE, "Lord must use exact 3-12 range")
	_expect(silverash.skills[0].sp_required == 2 and silverash.skills[0].initial_sp == 0 and silverash.skills[0].sp_recharge_type == "on_hit" and silverash.skills[0].duration == 0, "S1M3 attack recovery 2 / initial 0 / instant")
	_expect(not SkillRules.talent_is_active(silverash.talent_2) and silverash.talent_2.description.contains("无适用机制"), "Reveal talent must explicitly show unavailable without invisible objects")
	var state := _fixture(definitions, true)
	state.step([], [])
	_expect(state.units[0].attack_bonus_percent == 10 and SkillRules.attack_value(state.units[0], silverash) == 784, "Talent must add 10% to self, without rewriting raw attack")
	_expect(state.units[1].hp == 5000 - 144 and state.units[0].sp == 1, "Normal hit: round((627-382*0.7)*guard0.4)=144; +1 SP")
	state.units[0].attack_ticks_left = 1
	state.step([], [])
	_expect(state.units[1].hp == 5000 - 288 and state.units[0].sp == 2, "Second ordinary hit fills 2 SP")
	state.units[0].attack_ticks_left = 1
	state.step([], [])
	_expect(state.units[1].hp == 5000 - 288 - 803 and state.units[0].sp == 0 and state.units[0].skill_ticks_left == 0, "S1: round(713*1.1*2.9)=2274, damage803; consumes next hit and SP without 80% penalty")
	state.units[0].attack_ticks_left = 1
	state.step([], [])
	_expect(state.units[1].hp == 5000 - 288 - 803 - 144 and state.units[0].sp == 1, "Post S1 ordinary hit restores penalty")
	var ball_state := _fixture(definitions, false)
	ball_state.step([], [])
	_expect(ball_state.ball.accum == Vector2i(627,0) and ball_state.units[0].sp == 1, "Normal ball push uses 80% and no profession scaling")
	ball_state.units[0].attack_ticks_left = 1
	ball_state.step([], [])
	_expect(ball_state.ball.accum == Vector2i(1254,0) and ball_state.units[0].sp == 2, "Ball hit recovers attack SP")
	ball_state.ball.accum = Vector2i.ZERO
	ball_state.units[0].attack_ticks_left = 1
	ball_state.step([], [])
	_expect(ball_state.ball.move_ticks_left == 7 and ball_state.ball.move_direction == Vector2i.RIGHT and ball_state.units[0].sp == 0, "S1 ball push2274 crosses2000; no PvP or ranged penalty")
	for facing in 4:
		var range_state := _fixture(definitions, false)
		range_state.units[0].facing = facing
		for y in range(-4,5):
			for x in range(-4,5):
				var offset := Vector2i(x,y)
				var target := range_state.units[0].cell + ROTATE.rotate_offset(offset, facing)
				_expect(range_state._is_in_attack_range(range_state.units[0], target, silverash.attack_range) == (offset in RANGE), "Facing%d offset%s range mismatch" % [facing,offset])
		range_state.ball.cell = range_state.units[0].cell + ROTATE.rotate_offset(Vector2i(0,1), facing)
		range_state.step([], [])
		_expect(range_state.ball.accum == ROTATE.rotate_offset(Vector2i(0,627), facing), "Adjacent lateral target remains ranged for facing%d" % facing)
	_test_cooldowns(definitions)
	_test_import(silverash)
	var first := _fixture(definitions, true)
	var second := _fixture(definitions, true)
	for tick in 800:
		var commands: Array[InputCommand] = []
		if tick == 500:
			commands = [InputCommand.new(tick, InputCommand.Kind.RETREAT, "", 0)]
		first.step(commands, [])
		second.step(commands, [])
		_expect(first.state_hash() == second.state_hash(), "Replay divergence at tick%d" % tick)
	var old_data := {}
	for id in CONFIG.DEFAULT_SQUAD_IDS:
		old_data[id] = load("res://resources/operators/%s.tres" % id)
	var expanded := old_data.duplicate()
	expanded["silverash"] = silverash
	var old := MatchState.new(77, old_data, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [CONFIG.DEFAULT_SQUAD_IDS,CONFIG.DEFAULT_SQUAD_IDS])
	var added := MatchState.new(77, expanded, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [CONFIG.DEFAULT_SQUAD_IDS,CONFIG.DEFAULT_SQUAD_IDS])
	_expect(CONFIG.DEFAULT_SQUAD_IDS.size() == 8 and "silverash" not in CONFIG.DEFAULT_SQUAD_IDS, "Default eight must not grow with resource database")
	for tick in 120:
		var commands: Array[InputCommand] = []
		if tick == 0:
			commands = [InputCommand.new(tick, InputCommand.Kind.DEPLOY, "bagpipe", -1, Vector2i(11,5))]
			old.sides[0].cost = 99
			added.sides[0].cost = 99
		if tick == 80:
			commands = [InputCommand.new(tick, InputCommand.Kind.RETREAT, "", 0)]
		old.step(commands, [])
		added.step(commands, [])
		_expect(old.state_hash() == added.state_hash(), "Unselected SilverAsh must not alter original eight at tick%d" % tick)
	_expect(silverash.attack == 713 and silverash.redeploy_time == 70.0, "Runtime must leave resource raw values unchanged")
	print("SilverAsh: base, 3-12/four facings, unit/ball80%%, S1 exception, squad cooldown, import, replay800, original eight; failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


func _fixture(definitions: Dictionary, enemy: bool) -> MatchState:
	var state := MatchState.new(123, definitions, MatchState.DEFAULT_BALL_DATA, MatchState.DEFAULT_ARENA, [["silverash","bagpipe","swire_alter"],["bagpipe"]])
	state.units = [UnitState.new(0,0,"silverash",Vector2i(12,5),2560,0,1,0)]
	state.ball.cell = Vector2i(13,5) if not enemy else Vector2i(5,5)
	if enemy:
		state.units.append(UnitState.new(1,1,"bagpipe",Vector2i(13,5),5000,0,10000,2))
	state.next_unit_id = state.units.size()
	return state


func _test_cooldowns(definitions: Dictionary) -> void:
	var state := _fixture(definitions, false)
	state.units = [UnitState.new(0,0,"bagpipe",Vector2i(12,5),2484,0,10000)]
	state.step([InputCommand.new(0,InputCommand.Kind.RETREAT,"",0)],[])
	_expect(state.sides[0].cooldowns["bagpipe"] == 1890, "Squad source never deployed still reduces ally cooldown to63s")
	var removed := _fixture(definitions, false)
	removed.units.append(UnitState.new(1,0,"bagpipe",Vector2i(13,5),2484,0,10000))
	removed.step([InputCommand.new(0,InputCommand.Kind.RETREAT,"",0),InputCommand.new(0,InputCommand.Kind.RETREAT,"",1)],[])
	_expect(removed.sides[0].cooldowns["silverash"] == 1890 and removed.sides[0].cooldowns["bagpipe"] == 1890, "Retired source still reduces self and ally redeployment")
	var defeated := _fixture(definitions, false)
	defeated.units[0].hp = 0
	defeated.units.append(UnitState.new(1,0,"bagpipe",Vector2i(13,5),0,0,10000))
	defeated.units.append(UnitState.new(2,1,"bagpipe",Vector2i(9,5),0,0,10000))
	defeated.step([],[])
	_expect(defeated.sides[0].cooldowns["silverash"] == 1890 and defeated.sides[0].cooldowns["bagpipe"] == 1890 and defeated.sides[1].cooldowns["bagpipe"] == 2100, "Defeated source buff is squad-only; enemy cooldown remains70s")
	var merchant := _fixture(definitions, false)
	merchant.units = [UnitState.new(0,0,"swire_alter",Vector2i(12,5),2360,0,10000)]
	merchant.units[0].cost_drain_ticks = 89
	merchant.sides[0].cost = 0
	merchant.step([],[])
	_expect(merchant.units.is_empty() and merchant.sides[0].cooldowns["swire_alter"] == 675, "Merchant automatic retreat uses22.5s reduced redeploy")


func _test_import(silverash: OperatorData) -> void:
	# Run the unchanged importer methods without the editor-only EditorScript host.
	var importer_script := GDScript.new()
	importer_script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript", "extends RefCounted")
	_expect(importer_script.reload() == OK, "Importer must compile")
	var importer: RefCounted = importer_script.new()
	var csv := FileAccess.open("res://import/operators.csv", FileAccess.READ)
	var header := csv.get_csv_line()
	var columns := {}
	for index in header.size():
		columns[header[index]] = index
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() == 1:
			continue
		if row[0] != "银灰":
			continue
		_expect(importer._validate_row(row,columns), "SilverAsh CSV must pass importer")
		var imported: OperatorData = importer._build_operator(row,columns)
		_expect(imported.attack == silverash.attack and imported.magic_resist == 10 and imported.branch_trait.effect_params == silverash.branch_trait.effect_params and imported.talent_1.effect_params == silverash.talent_1.effect_params and imported.talent_2.effect_params == {} and imported.skills[0].effect_params == silverash.skills[0].effect_params, "Import must preserve typed trait/talent/skill parameters")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
