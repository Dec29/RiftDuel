extends SceneTree
func _initialize() -> void:
 var script := load("res://view/battle_audio.gd") as GDScript
 var audio: Node=script.new()
 var state := MatchState.new(108,{"silence":load("res://resources/operators/silence.tres")})
 var unit := UnitState.new(0,0,"silence",Vector2i(14,4),1595,0,87,0,0)
 state.units=[unit];state.next_unit_id=1;unit.last_attack_is_heal=true
 var before := state.state_hash();audio._attack(unit,"silence",false,null)
 if audio._pending_sounds.size()!=1 or audio._pending_sounds[0].cue!="p_atk_bottle_n" or state.state_hash()!=before:push_error("Silence original bottle healing cue and readonly");audio.free();quit(1);return
 if script.START_CUES["silence"][1]!=["b_char_botready"]:push_error("Original supply-ready event");audio.free();quit(1);return
 audio.free();print("Silence verified bottle healing/supply cue and readonly OK");quit(0)
