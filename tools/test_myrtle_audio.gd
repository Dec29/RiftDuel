extends SceneTree

func _initialize() -> void:
	var audio_script := load("res://view/battle_audio.gd") as GDScript
	if audio_script==null or not audio_script.can_instantiate():quit(1);return
	var constants := audio_script.get_script_constant_map()
	if constants["SKILL_VOICE_TAGS"]["myrtle"] != ["025","026","027"]:push_error("Wrong original voice set");quit(1);return
	if constants["START_CUES"]["myrtle"] != [["b_char_tactboost"],["b_char_healboost"]]:push_error("Unverified skill-start mapping");quit(1);return
	var audio: Node=audio_script.new()
	var state := MatchState.new(151,{"myrtle":load("res://resources/operators/myrtle.tres")})
	var unit := UnitState.new(0,0,"myrtle",Vector2i(12,5),1565,0,30,0,1)
	state.units=[unit];state.next_unit_id=1
	var before := state.state_hash()
	unit.last_attack_tick=0;unit.last_attack_is_heal=true
	before=state.state_hash()
	audio._attack(unit,"myrtle",true,null)
	if audio._pending_sounds.size()!=2 or audio._pending_sounds[0].cue!="p_atk_heal_n" or audio._pending_sounds[1].cue!="p_imp_heal_n" or state.state_hash()!=before:push_error("Ordinary skill heal sound or readonly mismatch");audio.free();quit(1);return
	audio.free()
	print("Myrtle audio mapping/source-set/readonly OK; actual playback remains Windows validation")
	quit(0)
