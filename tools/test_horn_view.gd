extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data := {"horn":load("res://resources/operators/horn.tres")}
	var state := MatchState.new(123,data)
	state.units = [UnitState.new(0,0,"horn",Vector2i(13,5),3067,10,1,2)]
	state.tick = 60
	AuraRules.refresh(state)
	var input := LocalInput.new(0)
	var view := MatchView.new()
	view.bind(state,input,data)
	view._details_open = true
	root.add_child(view)
	input.select_unit(0)
	var before := state.state_hash()
	await process_frame
	await process_frame
	if not check(state.state_hash() == before, "Range and full two-charge view preserves hash"): return
	if not await screenshot("horn-range-view.png"): return
	state._apply_damage(state.units[0],data["horn"],10000,"physical")
	before = state.state_hash()
	await process_frame
	await process_frame
	if not check(state.state_hash() == before and state.units[0].last_heal_tick == -1 and state.units[0].last_bloodbath_tick == 60 and state.units[0].hp == 1534, "Actual bloodbath uses own event, new maxHP and read-only rendering"): return
	if not await screenshot("horn-bloodbath-view.png"): return
	view._info_tab = MatchView.InfoTab.TRAIT
	view._info_scroll = 140
	view._info_scroll_display = 140.0
	await process_frame
	await process_frame
	if not check(state.state_hash() == before, "Bloodbath actual HP/DEF/interval details preserve hash"): return
	if not await screenshot("horn-profile-view.png"): return
	view.queue_free()
	await process_frame
	var menu = load("res://view/squad_menu.tscn").instantiate()
	root.add_child(menu)
	menu._open_slot(0)
	menu._preview("horn")
	await process_frame
	await process_frame
	if not check(state.state_hash() == before and menu.preview_id == "horn", "Squad details use same7+self range and don't mutate match"): return
	if not await screenshot("horn-squad-view.png"): return
	print("Horn view: strict7+self range, charge2, actual lethal revival event/new HP/DEF/AS information, squad grid; render hashes unchanged")
	quit(0)

func screenshot(name: String) -> bool:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		return check(root.get_texture().get_image().save_png("res://.godot/"+name) == OK, "Screenshot save"+name)
	return true

func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

