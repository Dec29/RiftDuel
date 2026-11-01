extends SceneTree

func _initialize() -> void:
	var audio_script := load("res://view/battle_audio.gd") as GDScript
	if audio_script==null or not audio_script.can_instantiate():quit(1);return
	var constants := audio_script.get_script_constant_map()
	if constants["START_CUES"]["nearl"].size()!=2:push_error("Two actual skills required");quit(1);return
	if constants["START_CUES"]["nearl"] != [[],["b_char_healboost"]]:push_error("Unverified skill-start mapping");quit(1);return
	var audio: Node=audio_script.new()
	var state := MatchState.new(151,{"nearl":load("res://resources/operators/nearl.tres")})
	var unit := UnitState.new(0,0,"nearl",Vector2i(12,5),2780,0,30,0,1)
	state.units=[unit];state.next_unit_id=1
	var before := state.state_hash()
	unit.last_attack_tick=0;unit.last_attack_is_heal=true
	before=state.state_hash()
	audio._attack(unit,"nearl",true,null)
	if audio._pending_sounds.size()!=2 or audio._pending_sounds[0].cue!="p_atk_heal_n" or audio._pending_sounds[1].cue!="p_imp_heal_n" or state.state_hash()!=before:push_error("Ordinary skill heal sound or readonly mismatch");audio.free();quit(1);return
	audio.free()
	print("Nearl audio mapping/source-set/readonly OK; actual playback remains Windows validation")
	quit(0)
