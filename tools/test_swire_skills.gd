extends SceneTree

var failures := 0
var data: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var db := root.get_node("OperatorDB")
	data = {"swire_alter":db.get_data("swire_alter"),"bagpipe":db.get_data("bagpipe"),"phantom":db.get_data("phantom"),"shining":db.get_data("shining")}
	var swire: OperatorData = data.swire_alter
	check(swire.skills.size()==3 and swire.skills[1].parameters_are_valid() and swire.skills[2].parameters_are_valid(),"Three valid equipped skills")
	var importer_script := GDScript.new()
	importer_script.source_code = FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	check(importer_script.reload()==OK,"Importer compiles")
	var importer: RefCounted = importer_script.new()
	var imported := {}
	for id in db.all_ids():
		var item: OperatorData = db.get_data(id).duplicate(true)
		item.skills.resize(1)
		imported[id]=item
	if not importer._append_skills(imported):
		push_error("Normalized CSV rejected")
		quit(1)
		return
	for index in [1,2]:
		check(imported.swire_alter.skills[index].effect_params==swire.skills[index].effect_params and imported.swire_alter.skills[index].burst_range_override==swire.skills[index].burst_range_override,"CSV/runtime parity")
	var traps := fixture(1)
	var source := traps.units[0]
	for i in 45: traps.step([],[])
	check(traps.champagne_bombs.is_empty(),"No planting before1.5s")
	traps.step([],[])
	check(traps.champagne_bombs.size()==1 and source.coins==0,"First placement tick45")
	var bomb := traps.champagne_bombs[0]
	check((bomb.cell-source.cell).length_squared() in [1,4],"Cross footprint only")
	var victim := UnitState.new(1,1,"bagpipe",bomb.cell,10000,0,10000)
	traps.units.append(victim)
	StatusRules.apply_silence(traps, source,120)
	traps.step([],[])
	check(bomb.triggered_tick>=0 and victim.hp<10000 and victim.slow_ticks_left==60,"Existing bomb triggers while source silent")
	var mature := fixture(1)
	var old := ChampagneBomb.new(0,mature.units[0],Vector2i(13,5),-90,1620)
	mature.champagne_bombs.append(old)
	mature.units.append(UnitState.new(1,1,"bagpipe",old.cell,10000,0,10000))
	var expected := Combat.calculate_damage(1620,data.bagpipe.defense,0,"physical",0,RNG.new(1),"specialist")
	MerchantRules.trigger_bombs_at(mature, mature.units[1],old.cell)
	check(mature.units[1].hp==10000-expected*2,"Mature two separate physical hits")
	var custom := fixture(1)
	var custom_data := swire.duplicate(true) as OperatorData
	custom_data.skills[1].effect_params["mature_ticks"] = 120
	custom._operator_data["swire_alter"] = custom_data
	var custom_bomb := ChampagneBomb.new(0,custom.units[0],Vector2i(13,5),-90,1620)
	custom.champagne_bombs.append(custom_bomb)
	var custom_hash := custom.state_hash()
	check(not custom.bomb_is_mature(custom_bomb) and custom.state_hash()==custom_hash,"Maturity query reads resource duration without changing state")
	custom.units.append(UnitState.new(1,1,"bagpipe",custom_bomb.cell,10000,0,10000))
	MerchantRules.trigger_bombs_at(custom, custom.units[1],custom_bomb.cell)
	check(custom.units[1].hp==10000-expected,"Nondefault maturity duration also controls the number of damage hits")
	custom.tick = 30
	check(custom.bomb_is_mature(custom_bomb),"Resource maturity threshold applies at the exact tick")
	var crossing := fixture(1)
	crossing.champagne_bombs.append(ChampagneBomb.new(0,crossing.units[0],Vector2i(14,5),-90,1620))
	var pushed := UnitState.new(1,1,"phantom",Vector2i(13,5),10000,0,10000)
	crossing.units.append(pushed)
	DisplacementRules.apply_unit(crossing,crossing.units[0],pushed,Vector2i.RIGHT,3)
	check(pushed.cell==Vector2i(16,5) and pushed.hp<10000 and crossing.champagne_bombs[0].triggered_tick==0,"Traversed cell triggers even when endpoint elsewhere")
	crossing._retreat_unit(crossing.units[0])
	check(crossing.champagne_bombs.is_empty(),"Body retreat clears every owned bomb immediately")
	var blocked := fixture(1)
	check(not blocked.bomb_cell_is_available(blocked.units[0],Vector2i(10,5)),"Midline forbidden")
	blocked.platform_cells.append(Vector2i(13,5))
	check(not blocked.bomb_cell_is_available(blocked.units[0],Vector2i(13,5)),"Built platform forbidden")
	var active := fixture(2)
	active.units[0].sp=5
	active.units[0].attack_ticks_left=1
	active.units.append(UnitState.new(1,1,"bagpipe",Vector2i(13,5),10000,0,10000))
	active.step([],[])
	var ordinary := Combat.calculate_damage(810,data.bagpipe.defense,0,"physical",0,RNG.new(1),"specialist")
	check(active.units[0].skill_ticks_left==-2 and active.units[0].coins==1 and active.units[1].hp==10000-ordinary*2,"Auto start gains1coin; ordinary two hits")
	active.units[0].coins=3
	var victim_id := active.units[1].unit_id
	active.step([InputCommand.new(active.tick,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,2)],[])
	check(active.units[0].coin_firing and active.units[0].coins==2 and active.units[0].coin_target_ids.has(victim_id),"Manual close marks front ground enemy and spends first coin")
	active.units[1].cell=Vector2i(15,5)
	var hp := active.units[1].hp
	for i in 5: active.step([],[])
	check(active.units[1].hp==hp,"No early second coin")
	active.step([],[])
	check(active.units[1].hp<hp and active.units[0].coins==1,"Marked enemy outside range still hit at6ticks")
	StatusRules.apply_silence(active, active.units[0],30)
	for i in 29: active.step([],[])
	check(active.units[0].coins==1 and active.units[0].sp==0,"Silence pauses coin effects; firing blocksSP")
	active.step([],[])
	check(active.units[0].coins==0 and not active.units[0].coin_firing,"Resume spends one remaining coin")
	var box := fixture(2)
	box.units[0].sp=5
	box.units[0].attack_ticks_left=1
	box.tactical_boxes.append(TacticalBox.new(0,Vector2i(13,5),3))
	box.step([],[])
	check(box.tactical_boxes[0].hits_left==1,"Two-hit skill counts two crate strikes")
	var kill := fixture(2)
	kill.units[0].sp=5
	kill.units[0].attack_ticks_left=1
	kill.units.append(UnitState.new(1,1,"bagpipe",Vector2i(13,5),1,0,10000))
	kill.step([],[])
	check(kill.units[0].coins==2,"Single kill awards one coin; no dead-target second hit")
	var full := fixture(2)
	full.units[0].sp=5
	full.step([],[])
	full.units[0].coins=10
	full.units[0].cost_drain_ticks=89
	full.step([],[])
	check(full.units[0].coin_attack_stacks==1 and full.units[0].coins==10,"Full inventory still earns attack stack")
	var starved := fixture(1)
	starved.champagne_bombs.append(ChampagneBomb.new(0,starved.units[0],Vector2i(13,5),0,1620))
	starved.units[0].cost_drain_ticks=89
	starved.sides[0].cost=0
	starved.step([],[])
	check(starved.units.is_empty() and starved.champagne_bombs.is_empty(),"Fee starvation auto retreat clears bombs")
	var dead := fixture(1)
	dead.champagne_bombs.append(ChampagneBomb.new(0,dead.units[0],Vector2i(13,5),0,1620))
	dead.units[0].hp=0
	dead.step([],[])
	check(dead.champagne_bombs.is_empty(),"Death clears bombs")
	var aura := fixture(1)
	aura.champagne_bombs.append(ChampagneBomb.new(0,aura.units[0],Vector2i(13,5),0,1620))
	aura.units.append(UnitState.new(1,1,"bagpipe",Vector2i(13,5),10000,0,10000))
	aura.units.append(UnitState.new(2,1,"shining",Vector2i(15,5),1613,0,10000,2))
	aura.step([],[])
	var protected_hit := Combat.calculate_damage(1620,data.bagpipe.defense+60,0,"physical",0,RNG.new(1),"specialist")
	check(aura.units[1].hp==10000-protected_hit,"New unit receives current defense aura before existing bomb detonates")
	var silent := fixture(1)
	silent.units[0].silence_ticks_left=120
	for i in 60: silent.step([],[])
	check(silent.champagne_bombs.is_empty() and silent.units[0].coins==1,"Silence cannot plant a new bomb")
	var pushing := fixture(2)
	var huge_ball := MatchState.DEFAULT_BALL_DATA.duplicate(true) as BallData
	huge_ball.kick_threshold=100000
	pushing._ball_data=huge_ball
	pushing.ball.cell=Vector2i(13,5)
	pushing.units[0].sp=5
	pushing.units[0].attack_ticks_left=1
	pushing.step([],[])
	check(pushing.ball.accum.x==1620,"Two actual pushes against stationary ball")
	var moving := fixture(2)
	moving.units[0].sp=5
	moving.units[0].attack_ticks_left=10000
	moving.units.append(UnitState.new(1,1,"phantom",Vector2i(13,5),10000,0,10000))
	moving.step([],[])
	moving.units[0].coins=2
	moving.step([InputCommand.new(moving.tick,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,2)],[])
	check(moving.units[1].cell==Vector2i(14,5),"Coin uses actual force1-minus-weight0 displacement")
	var high := fixture(2)
	high.platform_cells.append(Vector2i(13,5))
	high.units[0].sp=5
	high.units.append(UnitState.new(1,1,"shining",Vector2i(13,5),10000,0,10000))
	high.step([],[])
	high.units[0].coins=2
	high.step([InputCommand.new(high.tick,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,2)],[])
	check(high.units[0].coin_target_ids.has(1) and high.units[1].hp<10000 and high.units[1].cell==Vector2i(13,5),"High-tile operator is nonair: coin damage applies, ground displacement does not")
	var first := fixture(1)
	var second := fixture(1)
	for tick in 600:
		first.step([],[])
		second.step([],[])
		check(first.state_hash()==second.state_hash(),"600tick bomb RNG replay")
	print("Swire skill checks; failures=%d"%failures)
	quit(0 if failures==0 else 1)

func fixture(index: int) -> MatchState:
	var state := MatchState.new(123,data)
	state.units.append(UnitState.new(0,0,"swire_alter",Vector2i(12,5),2360,0,10000,0,index))
	state.units[0].coins=1 if index==1 else 0
	state.units[0].bomb_next_tick=45
	state.next_unit_id=1
	state.sides[0].cost=99
	state.ball.cell=Vector2i(10,10)
	return state

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
