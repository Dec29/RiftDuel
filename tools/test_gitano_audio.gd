extends SceneTree
func _initialize() -> void:
 var script := load("res://view/battle_audio.gd") as GDScript
 var audio: Node=script.new()
 var state := MatchState.new(109,{"gitano":load("res://resources/operators/gitano.tres")})
 var unit := UnitState.new(0,0,"gitano",Vector2i(14,4),1598,0,87,0,0)
 state.units=[unit];state.next_unit_id=1
 var before := state.state_hash();audio._attack(unit,"gitano",false,null)
 if audio._pending_sounds.size()!=2 or audio._pending_sounds[0].cue!="p_atk_anmag_n" or state.state_hash()!=before:push_error("Original normal cues/readonly");audio.free();quit(1);return
 audio._pending_sounds.clear();unit.skill_index=1;audio._attack(unit,"gitano",true,null)
 if not audio._pending_sounds.is_empty():push_error("Unverified variant must not fall back to normal cue");audio.free();quit(1);return
 audio.free();print("Gitano audio normal original cues, unresolved variant isolated, readonly OK");quit(0)
